/*
 * SMCryptoFile.c
 *
 * Copyright 2014 Avérous Julien-Pierre
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


#include <CommonCrypto/CommonCrypto.h>

#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>

#include <sys/mman.h>
#include <libkern/OSByteOrder.h>

#include "SMCryptoFile.h"



/*
** Defines
*/
#pragma mark - Defines

#define kCFMagicValue			0xC3160FF4
#define kCFCheckValue			0xB4D9E5AC

#define kCFCurrentVersion		1

#define kCFSaltSize				16

#define kCFFileBlockSize		(16 * kCCBlockSizeAES128)	// 256 bytes.
#define kCFFileCacheSize		(16 * kCFFileBlockSize)		// 4096 bytes.

#define kCFFilePrefixOffset		0
#define kCFFileHeaderOffset		(kCFFilePrefixOffset + sizeof(SMCryptoFilePrefix))
#define kCFFileDataOffset		(kCFFileHeaderOffset + sizeof(SMCryptoFileHeader))



/*
** Macros
*/
#pragma mark - Macros

// Debug log.
#if DEBUG_LOG
#	define SMCryptoDebugLog(Str, Arg...) fprintf(stderr, Str, ## Arg)
#else
#	define SMCryptoDebugLog(Str, Arg...) ((void)0)
#endif

// Round up or down. Round should be a power of 2.
#define SMRoundUp(Value, Round)		(((Value) + ((Round) - 1)) & ~((Round) - 1))
#define SMRoundDown(Value, Round)	((Value) & ~((Round) - 1))



/*
** Types
*/
#pragma mark - Types

typedef struct SMCryptoFilePrefix
{
	uint32_t	magic;							// Magic value to verify that the file is a crypto-file.
	
	uint8_t		version;						// Version of the structure.
	
	uint8_t		keySize;						// Key size (SMCryptoKeySize)
		
	uint8_t		passwordSalt[kCFSaltSize];		// Salt used to derivate the password to the header key.
	uint32_t	passwordRounds;					// Number of round to derivate the password to header key.
	
	uint8_t		headerIV[kCCBlockSizeAES128];	// Initial vector used to crypt / decrypt the header.
	
} __attribute__ ((packed)) SMCryptoFilePrefix;

typedef struct SMCryptoFileHeader
{
	uint32_t	check;							// Contain kCFCheckValue. Used to validate the password.
	uint32_t	crc32;							// Contain the CRC32 of xtsKey + xtsTweak to prevent key corruption.
	
	uint64_t	dataLen;						// Real data size, as written by user.
	
	uint8_t		xtsKey[kCCKeySizeAES256];		// Crypt key used to crypt / decrypt XTS data.
	uint8_t		xtsTweak[kCCKeySizeAES256];		// Crypt key used to crypt / decrypt XTS data.
	
} __attribute__ ((packed)) SMCryptoFileHeader;	// 80 bytes = 640 bits = 5 AES block

struct SMCryptoFile
{
	// -- Internal --
	// > Back file.
	int fd; // File descriptor.
	
	uint64_t fileDataLen;	// Concrete len of data on disk (including padding, but not header)
	
	// > Flags.
	bool readonly;
	
	// > Cryptors.
	CCCryptorRef dataEncrypt;
	CCCryptorRef dataDecrypt;
	
	// > Position.
	uint64_t currentOffset;	// Current position in file (used for read / write).

	// > Cache.
	uint8_t		cachedData[kCFFileCacheSize]; // Clear data cache.
	uint64_t	cachedDataOffset;	// Cache offset in the file.
	uint64_t	cachedDataSize;		// Amount of data in the cache buffer. [0; kCFFileCacheSize]
	bool		cachedDataDirty;	// Data in the cache is not synced with data in the file.
	
	// > Header crypt key.
	uint8_t		headerKey[kCCKeySizeAES256]; // Header crypt key.
	
	// -- Prefix (File - Clear on file) --
	SMCryptoFilePrefix	prefix;
	
	// -- Header (File - Crypted on file) --
	SMCryptoFileHeader	header;
	bool				headerDirty; // Header not synced with data in the file.
};

typedef struct
{
	uint64_t location;
	uint64_t length;
} SMCryptoRange;



/*
** Prototypes
*/
#pragma mark - Prototypes

// -- Helpers --
static unsigned SMCryptoFileRealKeySize(SMCryptoFile *obj);

static bool SMCryptoFileFillGapToLength(SMCryptoFile *obj, uint64_t length, SMCryptoFileError *error);

static int SMCryptoFileTemporaryFile(char *pathBuffer, size_t pathBufferSize);

// > Instance.
static SMCryptoFile *	SMCryptoFileAlloc(void);
static bool				SMCryptoFileFree(SMCryptoFile *obj);

// > Prefix.
static bool SMCryptoFilePrefixRead(SMCryptoFile *obj, SMCryptoFileError *error);
static bool SMCryptoFilePrefixWrite(SMCryptoFile *obj, SMCryptoFileError *error);

// > Headers.
static bool SMCryptoFileHeaderSetDataLen(SMCryptoFile *obj, uint64_t len, bool flushNow, SMCryptoFileError *error);
static bool SMCryptoFileHeaderFlush(SMCryptoFile *obj, SMCryptoFileError *error);

static bool SMCryptoFileHeaderRead(SMCryptoFile *obj, SMCryptoFileError *error);
static bool SMCryptoFileHeaderWrite(SMCryptoFile *obj, SMCryptoFileError *error);

// > Cache.
static bool SMCryptoFileCacheFlush(SMCryptoFile *obj, SMCryptoFileError *error);

static bool SMCryptoFileCachePrepareReadingAtCurrentOffset(SMCryptoFile *obj, SMCryptoFileError *error);
static bool SMCryptoFileCachePrepareWritingAtCurrentOffset(SMCryptoFile *obj, SMCryptoFileError *error);

// > Crypt / decrypt.
static bool SMCryptoFileBlockCrypt(SMCryptoFile *obj, const void *block, uint64_t blocknum, void *output);
static bool SMCryptoFileBlockDecrypt(SMCryptoFile *obj, const void *block, uint64_t blocknum, void *output);

// > Ranges.
static inline SMCryptoRange SMCryptoMakeRange(uint64_t location, uint64_t length);
static inline uint64_t		SMCryptoMaxRange(SMCryptoRange range);
static SMCryptoRange		SMCryptoIntersectionRange(SMCryptoRange r1, SMCryptoRange r2);

// > CRC32
static uint32_t SMCryptoCRC32(uint32_t crc, const void *buf, size_t size);

// SPI Header, needed for XTS.
extern CCCryptorStatus CCCryptorEncryptDataBlock(CCCryptorRef cryptorRef, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0);
extern CCCryptorStatus CCCryptorDecryptDataBlock(CCCryptorRef cryptorRef, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0);


extern int CCRandomCopyBytes(const void *rnd, void *bytes, size_t count) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0);

extern const void * kCCRandomDefault __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0);



/*
** Helpers
*/
#pragma mark - Helpers

bool SMCryptoFileCanOpen(const char *path)
{
	bool result = false;
	
	if (!path)
		return false;
		
	// Open file.
	int fd = open(path, O_RDONLY);
	
	if (fd == -1)
		return false;
	
	// Try to read prefix.
	SMCryptoFilePrefix	prefix;
	
	if (pread(fd, &prefix, sizeof(prefix), kCFFilePrefixOffset) != sizeof(prefix))
		goto clean;
	
	// Check prefix.
	if (prefix.magic != kCFMagicValue)
		goto clean;
	
	// Try to read header.
	SMCryptoFileHeader	header;
	
	if (pread(fd, &header, sizeof(header), kCFFileHeaderOffset) != sizeof(header))
		goto clean;

	// File is openable.
	result = true;
	
clean:
	if (fd != -1)
		close(fd);
	
	return result;
}



/*
** Instance
*/
#pragma mark - Instance

SMCryptoFile * SMCryptoFileCreate(const char *path, const char *password, SMCryptoFileKeySize keySizeValue, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	// > Check pointers.
	if (!password || !path)
	{
		*error = SMCryptoFileErrorArguments;
		return NULL;
	}
	
	// > Check len.
	size_t passwordLen = strlen(password);

	if (passwordLen == 0 || strlen(path) == 0)
	{
		*error = SMCryptoFileErrorArguments;
		return NULL;
	}
	
	// > Check keysize.
	switch (keySizeValue)
	{
		case SMCryptoFileKeySize128:
		case SMCryptoFileKeySize192:
		case SMCryptoFileKeySize256:
			break;
		default:
			*error = SMCryptoFileErrorArguments;
			return NULL;
	}
	
	// Create structure.
	SMCryptoFile *result = SMCryptoFileAlloc();
		
	if (!result)
	{
		*error = SMCryptoFileErrorMemory;
		return NULL;
	}
	
	
	// Create a new file.
	int fd = open(path, O_RDWR | O_CREAT, (S_IRUSR | S_IWUSR) | (S_IRGRP | S_IWGRP) | (S_IROTH | S_IWOTH)); // mode masked by umask.
	
	if (fd == -1)
	{
		*error = SMCryptoFileErrorIO;
		goto fail;
	}

	result->fd = fd;
	
	// Hold key size.
	result->prefix.keySize = keySizeValue;
	
	// -- Generate crypto material --
	int			status;
	unsigned	keySize = SMCryptoFileRealKeySize(result);
		
	// Prefix
	// > Generate password salt.
	if (CCRandomCopyBytes(kCCRandomDefault, result->prefix.passwordSalt, sizeof(result->prefix.passwordSalt)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate password salt.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Calibrate password round count.
	result->prefix.passwordRounds = CCCalibratePBKDF(kCCPBKDF2, passwordLen, sizeof(result->prefix.passwordSalt), kCCPRFHmacAlgSHA256, keySize, 100); // 1/10 sec
	
	if (result->prefix.passwordRounds == 0)
	{
		SMCryptoDebugLog("Error: Can't calibrate PBKDF2.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Generate header IV.
	if (CCRandomCopyBytes(kCCRandomDefault, result->prefix.headerIV, sizeof(result->prefix.headerIV)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate header IV.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Derivate password to header key.
	status = CCKeyDerivationPBKDF(kCCPBKDF2, password, passwordLen, result->prefix.passwordSalt, sizeof(result->prefix.passwordSalt), kCCPRFHmacAlgSHA256, result->prefix.passwordRounds, result->headerKey, keySize);
	
    if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't derivate password (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
    }
	
	// Header
	// > Generate XTS keys.
	if (CCRandomCopyBytes(kCCRandomDefault, result->header.xtsKey, sizeof(result->header.xtsKey)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate key.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	if (CCRandomCopyBytes(kCCRandomDefault, result->header.xtsTweak, sizeof(result->header.xtsTweak)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate tweak.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Generate CRC32.
	uint32_t crc = 0;
	
	crc = SMCryptoCRC32(crc, result->header.xtsKey, sizeof(result->header.xtsKey));
	crc = SMCryptoCRC32(crc, result->header.xtsTweak, sizeof(result->header.xtsTweak));

	result->header.crc32 = (uint32_t)crc;
	
	// Create data cryptor.
	// > Encryptor.
    status = CCCryptorCreateWithMode(kCCEncrypt, kCCModeXTS, kCCAlgorithmAES, ccNoPadding, NULL, result->header.xtsKey, keySize, result->header.xtsTweak, keySize, 0, 0, &result->dataEncrypt);
    
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't create encrypt engine (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Decryptor.
	status = CCCryptorCreateWithMode(kCCDecrypt, kCCModeXTS, kCCAlgorithmAES, ccNoPadding, NULL, result->header.xtsKey, keySize, result->header.xtsTweak, keySize, 0, 0, &result->dataDecrypt);
    
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't create decrypt engine (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Write prefix.
	if (SMCryptoFilePrefixWrite(result, error) == false)
	{
		SMCryptoDebugLog("Error: Can't write prefix.\n");
		goto fail;
	}
	
	// >  Write header.
	if (SMCryptoFileHeaderWrite(result, error) == false)
	{
		SMCryptoDebugLog("Error: Can't write header.\n");
		goto fail;
	}
	
	// Return.
	return result;
	
fail:
	
	SMCryptoFileClose(result, NULL);
	unlink(path);

	return NULL;
}

SMCryptoFile *	SMCryptoFileCreateImpersonated(SMCryptoFile *original, const char *path, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	// > Check pointers.
	if (!original || !path)
	{
		*error = SMCryptoFileErrorArguments;
		return NULL;
	}
	
	// Create structure.
	SMCryptoFile *result = SMCryptoFileAlloc();
	
	if (!result)
	{
		*error = SMCryptoFileErrorMemory;
		return NULL;
	}
	
	// Create a new file.
	int fd = open(path, O_RDWR | O_CREAT, (S_IRUSR | S_IWUSR) | (S_IRGRP | S_IWGRP) | (S_IROTH | S_IWOTH)); // mode masked by umask.
	
	if (fd == -1)
	{
		*error = SMCryptoFileErrorIO;
		goto fail;
	}

	result->fd = fd;
		
	// -- Generate crypto material --
	// Prefix.
	memcpy(&result->prefix, &original->prefix, sizeof(SMCryptoFilePrefix));
	
	memcpy(result->headerKey, original->headerKey, sizeof(result->headerKey));
	
	// Header
	// > Generate XTS keys.
	if (CCRandomCopyBytes(kCCRandomDefault, result->header.xtsKey, sizeof(result->header.xtsKey)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate key.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	if (CCRandomCopyBytes(kCCRandomDefault, result->header.xtsTweak, sizeof(result->header.xtsTweak)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate tweak.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Generate CRC32.
	uint32_t crc = 0;
	
	crc = SMCryptoCRC32(crc, result->header.xtsKey, sizeof(result->header.xtsKey));
	crc = SMCryptoCRC32(crc, result->header.xtsTweak, sizeof(result->header.xtsTweak));
	
	result->header.crc32 = (uint32_t)crc;
	
	// Create data cryptor.
	int			status;
	unsigned	keySize = SMCryptoFileRealKeySize(result);
	
	// > Encryptor.
    status = CCCryptorCreateWithMode(kCCEncrypt, kCCModeXTS, kCCAlgorithmAES, ccNoPadding, NULL, result->header.xtsKey, keySize, result->header.xtsTweak, keySize, 0, 0, &result->dataEncrypt);
    
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't create encrypt engine (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Decryptor.
	status = CCCryptorCreateWithMode(kCCDecrypt, kCCModeXTS, kCCAlgorithmAES, ccNoPadding, NULL, result->header.xtsKey, keySize, result->header.xtsTweak, keySize, 0, 0, &result->dataDecrypt);
    
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't create decrypt engine (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Write prefix.
	if (SMCryptoFilePrefixWrite(result, error) == false)
	{
		SMCryptoDebugLog("Error: Can't write prefix.\n");
		goto fail;
	}
	
	// >  Write header.
	if (SMCryptoFileHeaderWrite(result, error) == false)
	{
		SMCryptoDebugLog("Error: Can't write header.\n");
		goto fail;
	}
	
	// Return.
	return result;
	
fail:
	
	SMCryptoFileClose(result, NULL);
	unlink(path);
	
	return NULL;
}

SMCryptoFile * SMCryptoFileCreateVolatile(const char *path, SMCryptoFileKeySize keySizeValue, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	// > Check keysize.
	switch (keySizeValue)
	{
		case SMCryptoFileKeySize128:
		case SMCryptoFileKeySize192:
		case SMCryptoFileKeySize256:
			break;
		default:
			*error = SMCryptoFileErrorArguments;
			return NULL;
	}
	
	// Create structure.
	SMCryptoFile *result = SMCryptoFileAlloc();
	
	if (!result)
	{
		*error = SMCryptoFileErrorMemory;
		return NULL;
	}
	
	// Try to create a new file.
	int fd;
	
	if (path)
	{
		fd = open(path, O_RDWR | O_CREAT, (S_IRUSR | S_IWUSR) | (S_IRGRP | S_IWGRP) | (S_IROTH | S_IWOTH)); // mode masked by umask.
		
		if (fd == -1)
		{
			*error = SMCryptoFileErrorIO;
			goto fail;
		}
	}
	else
	{
		char buffer[PATH_MAX];
		
		fd = SMCryptoFileTemporaryFile(buffer, sizeof(buffer));
		
		if (fd == -1)
		{
			*error = SMCryptoFileErrorIO;
			goto fail;
		}

		unlink(buffer); // unlinking an opened file give an delete-on-close behavior.
	}
	
	result->fd = fd;

	// Hold key size.
	result->prefix.keySize = keySizeValue;
	
	// -- Generate crypto material --
	// Prefix.
	memset(&result->prefix.passwordSalt, 0, sizeof(result->prefix.passwordSalt));
	
	result->prefix.passwordRounds = 0;
	
	// > Generate header IV.
	if (CCRandomCopyBytes(kCCRandomDefault, result->prefix.headerIV, sizeof(result->prefix.headerIV)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate header IV.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Generate header key.
	if (CCRandomCopyBytes(kCCRandomDefault, result->headerKey, sizeof(result->headerKey)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate password salt.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// Header
	// > Generate XTS keys.
	if (CCRandomCopyBytes(kCCRandomDefault, result->header.xtsKey, sizeof(result->header.xtsKey)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate key.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	if (CCRandomCopyBytes(kCCRandomDefault, result->header.xtsTweak, sizeof(result->header.xtsTweak)) != 0)
	{
		SMCryptoDebugLog("Error: Can't generate tweak.\n");
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// Create data cryptor.
	int			status;
	unsigned	keySize = SMCryptoFileRealKeySize(result);

	// > Encryptor.
    status = CCCryptorCreateWithMode(kCCEncrypt, kCCModeXTS, kCCAlgorithmAES, ccNoPadding, NULL, result->header.xtsKey, keySize, result->header.xtsTweak, keySize, 0, 0, &result->dataEncrypt);
    
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't create encrypt engine (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Decryptor.
	status = CCCryptorCreateWithMode(kCCDecrypt, kCCModeXTS, kCCAlgorithmAES, ccNoPadding, NULL, result->header.xtsKey, keySize, result->header.xtsTweak, keySize, 0, 0, &result->dataDecrypt);
    
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't create decrypt engine (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Write prefix.
	if (SMCryptoFilePrefixWrite(result, error) == false)
	{
		SMCryptoDebugLog("Error: Can't write prefix.\n");
		goto fail;
	}
	
	// >  Write header.
	if (SMCryptoFileHeaderWrite(result, error) == false)
	{
		SMCryptoDebugLog("Error: Can't write header.\n");
		goto fail;
	}
	
	// Return.
	return result;

fail:
	
	SMCryptoFileClose(result, NULL);
	
	if (path)
		unlink(path);
	
	return NULL;
}

SMCryptoFile * SMCryptoFileOpen(const char *path, const char *password, bool readOnly, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	// > Check pointers.
	if (!password || !path)
	{
		*error = SMCryptoFileErrorArguments;
		return NULL;
	}
	
	// > Check len.
	size_t passwordLen = strlen(password);

	if (passwordLen == 0 || strlen(path) == 0)
	{
		*error = SMCryptoFileErrorArguments;
		return NULL;
	}
	
	// Create structure.
	SMCryptoFile *result = SMCryptoFileAlloc();
	
	if (!result)
	{
		*error = SMCryptoFileErrorMemory;
		return NULL;
	}
	
	result->readonly = readOnly;
	
	// Try to open the file.
	int openFlag;
	int fd;
	
	if (readOnly)
		openFlag = O_RDONLY;
	else
		openFlag = O_RDWR;
	
	fd = open(path, openFlag);

	if (fd == -1)
	{
		*error = SMCryptoFileErrorIO;
		SMCryptoFileClose(result, NULL);
		
		return NULL;
	}
	
	result->fd = fd;
	
	// -- Load crypto material --
	int			status;
	unsigned	keySize;
	
	// Prefix.
	// > Read.
	if (SMCryptoFilePrefixRead(result, error) == false)
	{
		SMCryptoDebugLog("Error: Can't read prefix.\n");
		*error = SMCryptoFileErrorIO;
		goto fail;
	}

	// > Check.
	if (result->prefix.magic != kCFMagicValue)
	{
		SMCryptoDebugLog("Error: Not a crypto-file.\n");
		*error = SMCryptoFileErrorFormat;
		goto fail;
	}
	
	if (result->prefix.version != kCFCurrentVersion)
	{
		SMCryptoDebugLog("Error: Incompatible version.\n");
		*error = SMCryptoFileErrorVersion;
		goto fail;
	}
	
	switch (result->prefix.keySize)
	{
		case SMCryptoFileKeySize128:
		case SMCryptoFileKeySize192:
		case SMCryptoFileKeySize256:
			break;
			
		default:
			*error = SMCryptoFileErrorArguments;
			goto fail;
	}
	
	// > Get values.
	keySize = SMCryptoFileRealKeySize(result);
	
	// > Derivate password to header key.
	status = CCKeyDerivationPBKDF(kCCPBKDF2, password, passwordLen, result->prefix.passwordSalt, sizeof(result->prefix.passwordSalt), kCCPRFHmacAlgSHA256, result->prefix.passwordRounds, result->headerKey, keySize);
	
    if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't derivate password (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
    }
	
	// Header.
	// > Read header.
	if (SMCryptoFileHeaderRead(result, error) == false)
	{
		SMCryptoDebugLog("Error: Can't read header.\n");
		goto fail;
	}
	
	// > Check magic.
	if (result->header.check != kCFCheckValue)
	{
		SMCryptoDebugLog("Error: Bad password or header corrupted.\n");
		*error = SMCryptoFileErrorPassword;
		goto fail;
	}
	
	// > Check CRC32.
	uint32_t crc = 0;
	
	crc = SMCryptoCRC32(crc, result->header.xtsKey, sizeof(result->header.xtsKey));
	crc = SMCryptoCRC32(crc, result->header.xtsTweak, sizeof(result->header.xtsTweak));
	
	if (result->header.crc32 != crc)
	{
		*error = SMCryptoFileErrorCorrupted;
		goto fail;
	}
	
	// > Get values.
	result->fileDataLen = SMRoundUp(result->header.dataLen, kCFFileBlockSize);
	
	// Create data cryptor.
	// > Encryptor.
    status = CCCryptorCreateWithMode(kCCEncrypt, kCCModeXTS, kCCAlgorithmAES, ccNoPadding, NULL, result->header.xtsKey, keySize, result->header.xtsTweak, keySize, 0, 0, &result->dataEncrypt);
    
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't create encrypt engine (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// > Decryptor.
	status = CCCryptorCreateWithMode(kCCDecrypt, kCCModeXTS, kCCAlgorithmAES, ccNoPadding, NULL, result->header.xtsKey, keySize, result->header.xtsTweak, keySize, 0, 0, &result->dataDecrypt);
    
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't create decrypt engine (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		goto fail;
	}
	
	// Return.
	return result;
	
fail:
	SMCryptoFileClose(result, NULL);
	
	return NULL;
}

bool SMCryptoFileClose(SMCryptoFile *obj, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	if (!obj)
	{
		*error = SMCryptoFileErrorArguments;
		return false;
	}

	// Flush.
	if (SMCryptoFileFlush(obj, SMCryptoFileSyncNormal, error) == false)
		return false;

	// Clean.
	if (obj->fd > 0)
		close(obj->fd);

	if (obj->dataEncrypt)
		CCCryptorRelease(obj->dataEncrypt);
	
	if (obj->dataDecrypt)
		CCCryptorRelease(obj->dataDecrypt);
	
	SMCryptoFileFree(obj);
	
	// Return.
	return true;
}



/*
** Tools
*/
#pragma mark - Tools

bool SMCryptoFileChangePassword(SMCryptoFile *obj, const char *newPassword, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	if (!obj || !newPassword)
	{
		*error = SMCryptoFileErrorArguments;
		return false;
	}
	
	size_t newPasswordLen = strlen(newPassword);

	if (newPasswordLen == 0)
	{
		*error = SMCryptoFileErrorArguments;
		return NULL;
	}
		
	// Derivate new password to header key.
	unsigned	keySize = SMCryptoFileRealKeySize(obj);
	int			result = CCKeyDerivationPBKDF(kCCPBKDF2, newPassword, newPasswordLen, obj->prefix.passwordSalt, sizeof(obj->prefix.passwordSalt), kCCPRFHmacAlgSHA256, obj->prefix.passwordRounds, obj->headerKey, keySize);
	
    if (result != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't derivate new password (%d).\n", result);
		*error = SMCryptoFileErrorCrypto;
		return false;
    }

	// Re-write header with new header key.
	if (SMCryptoFileHeaderWrite(obj, error) == false)
	{
		SMCryptoDebugLog("Error: Can't write header.\n");
		return false;
	}
	
	// Done.
	return true;
}



/*
** Properties
*/
#pragma mark - Properties

uint64_t SMCryptoFileSize(SMCryptoFile *obj)
{
	if (!obj)
		return 0;
	
	return obj->header.dataLen;
}



/*
** I/O
*/
#pragma mark - I/O

bool SMCryptoFileSeek(SMCryptoFile *obj, int64_t offset, SMCryptoFileSeekWhence whence, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	// > Check pointers.
	if (!obj)
	{
		*error = SMCryptoFileErrorArguments;
		return false;
	}
	
	// Compute new offset.
	switch (whence)
	{
		case SMCryptoFileSeekSet:
		{
			// > Check negative offset.
			if (offset < 0)
			{
				*error = SMCryptoFileErrorArguments;
				return false;
			}
			
			// > Set current position to offset.
			obj->currentOffset = offset;
			
			return true;
		}
			
		case SMCryptoFileSeekCurrent:
		{
			// > Check integer overflow.
			if (offset > 0 && obj->currentOffset > LLONG_MAX - offset)
			{
				*error = SMCryptoFileErrorArguments;
				return false;
			}
			
			// > Add current offset.
			offset += obj->currentOffset;
			
			// > Check if we are less than 0.
			if (offset < 0)
			{
				*error = SMCryptoFileErrorArguments;
				return false;
			}
			
			// > Set current position to offset.
			obj->currentOffset = offset;

			return true;
		}
			
		case SMCryptoFileSeekEnd:
		{
			// > Check integer overflow.
			if (offset > 0 && obj->header.dataLen > LLONG_MAX - offset)
			{
				*error = SMCryptoFileErrorArguments;
				return false;
			}

			// > Compute offset.
			offset += obj->header.dataLen;
			
			// > Check if we are less than 0.
			if (offset < 0)
			{
				*error = SMCryptoFileErrorArguments;
				return false;
			}

			// > Set current position to offset.
			obj->currentOffset = offset;
	
			return true;
		}
	}
	
	// Error.
	*error = SMCryptoFileErrorArguments;

	return false;
}

uint64_t SMCryptoFileTell(SMCryptoFile *obj)
{
	if (!obj)
		return 0;
	
	return obj->currentOffset;
}

bool SMCryptoFileTruncate(SMCryptoFile *obj, uint64_t length, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	// > Check pointers.
	if (!obj)
	{
		*error = SMCryptoFileErrorArguments;
		return false;
	}
	
	// Read-only.
	if (obj->readonly)
	{
		*error = SMCryptoFileErrorReadOnly;
		return false;
	}
	
	// Fast path.
	if (length == obj->header.dataLen)
		return true;
	
	
	// Resize the file.
	uint64_t roundLength = SMRoundUp(length, kCFFileBlockSize);

	if (roundLength < obj->fileDataLen)
	{
		// > Truncate file.
		
		if (ftruncate(obj->fd, kCFFileDataOffset + roundLength) != 0)
		{
			*error = SMCryptoFileErrorIO;
			return false;
		}
		
		// > Update file len.
		obj->fileDataLen = roundLength;
	}
	else
	{
		// > Expand file.
		
		if (SMCryptoFileFillGapToLength(obj, roundLength, error) == false)
			return false;
	}
	
	// Truncate last file block if necessary, end pad it with zeroes.
	if (length < obj->fileDataLen)
	{
		uint64_t truncateOffset = SMRoundDown(length, kCFFileBlockSize);
		
		if (truncateOffset != length)
		{
			uint64_t blockNumber = truncateOffset / kCFFileBlockSize;

			// > Read block.
			uint8_t fileBlock[kCFFileBlockSize];

			if (pread(obj->fd, fileBlock, sizeof(fileBlock), kCFFileDataOffset + truncateOffset) != sizeof(fileBlock))
			{
				*error = SMCryptoFileErrorIO;
				return false;
			}
			
			// > Decrypt block.
			uint8_t clearBlock[kCFFileBlockSize];

			if (SMCryptoFileBlockDecrypt(obj, fileBlock, blockNumber, clearBlock) == false)
			{
				*error = SMCryptoFileErrorCrypto;
				return false;
			}
			
			// > Truncate the block.
			uint64_t blockOffset = length - truncateOffset;
			
			memset(clearBlock + blockOffset, 0, (size_t)(sizeof(fileBlock) - blockOffset));
			
			// > Re-crypt the block.
			if (SMCryptoFileBlockCrypt(obj, clearBlock, blockNumber, fileBlock) == false)
			{
				*error = SMCryptoFileErrorCrypto;
				return false;
			}
			
			// > Write block back.
			if (pwrite(obj->fd, fileBlock, sizeof(fileBlock), kCFFileDataOffset + truncateOffset) != sizeof(fileBlock))
			{
				*error = SMCryptoFileErrorIO;
				return false;
			}
		}
	}

	// Truncate cache if needed.
	if (length < obj->header.dataLen)
	{
		if (obj->cachedDataOffset >= length)
		{
			obj->cachedDataDirty = false;
			obj->cachedDataSize = 0;
		}
		else if (obj->cachedDataOffset + obj->cachedDataSize > length)
		{
			obj->cachedDataSize = (length - obj->cachedDataOffset);
		}
	}
	 
	// Update header.
	if (SMCryptoFileHeaderSetDataLen(obj, length, true, error) == false)
		return false;

	return true;
}

int64_t SMCryptoFileRead(SMCryptoFile *obj, void *ptr, uint64_t size, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	// > Check pointers.
	if (!obj || !ptr)
	{
		*error = SMCryptoFileErrorArguments;
		return -1;
	}

	// > Refine size.
	if (obj->currentOffset >= obj->header.dataLen)
		size = 0;
	else if (obj->currentOffset + size > obj->header.dataLen)
		size = obj->header.dataLen - obj->currentOffset;
	
	// > Fast path.
	if (size == 0)
		return 0;
		
	// Backup values
	uint64_t	currentOffset = obj->currentOffset;
	uint64_t	requestSize = size;
	
	// Read blocks.
	while (size)
	{
		// > Prepare cache to be read at currentOffset.
		if (SMCryptoFileCachePrepareReadingAtCurrentOffset(obj, error) == false)
		{
			obj->currentOffset = currentOffset;
			return -1;
		}
		
		// > Compute amount of data usable in cache.
		SMCryptoRange cacheRange = SMCryptoMakeRange(obj->cachedDataOffset, obj->cachedDataSize);
		SMCryptoRange readRange = SMCryptoMakeRange(obj->currentOffset, size);
		SMCryptoRange range = SMCryptoIntersectionRange(readRange, cacheRange);

		// > Check the amount of data usable (not supposed to happen).
		if (range.length == 0)
		{
			*error = SMCryptoFileErrorUnknown;
			obj->currentOffset = currentOffset;

			return -1;
		}
		
		// > Copy cache to output buffer.
		memcpy(ptr, obj->cachedData + (range.location - obj->cachedDataOffset), (size_t)(range.length));
		
		// > Update vars.
		ptr += range.length;
		size -= range.length;
		obj->currentOffset += range.length;
	}
	
	return (int64_t)requestSize;
}

bool SMCryptoFileWrite(SMCryptoFile *obj, const void *ptr, uint64_t size, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	// > Check pointers.
	if (!obj || !ptr)
	{
		*error = SMCryptoFileErrorArguments;
		return false;
	}
	
	// Read-only.
	if (obj->readonly)
	{
		*error = SMCryptoFileErrorReadOnly;
		return false;
	}
	
	// > Fast path.
	if (size == 0)
		return true;
	
	// Backup for error.
	uint64_t currentOffset = obj->currentOffset;
		
	// Write blocks.
	while (size)
	{
		// > Prepare cache to be written at currentOffset.
		if (SMCryptoFileCachePrepareWritingAtCurrentOffset(obj, error) == false)
		{
			obj->currentOffset = currentOffset;
			return false;
		}

		// > Compute positions and size.
		uint64_t delta = obj->currentOffset - obj->cachedDataOffset;
		uint64_t copySize = kCFFileCacheSize - delta;
		
		if (size < copySize)
			copySize = size;
				
		// > Copy data.
		memcpy(obj->cachedData + delta, ptr, (size_t)copySize);
		
		obj->cachedDataDirty = true;
		
		// > Update values.
		size -= copySize;
		ptr += copySize;
		obj->currentOffset += copySize;
		obj->cachedDataSize = MAX(obj->cachedDataSize, delta + copySize);
		
		if (obj->currentOffset > obj->header.dataLen)
			SMCryptoFileHeaderSetDataLen(obj, obj->currentOffset, false, NULL);
	}

	return true;
}

bool SMCryptoFileFlush(SMCryptoFile *obj, SMCryptoFileSyncType sync, SMCryptoFileError *error)
{
	// Check arguments.
	SMCryptoFileError terror;
	
	if (!error)
		error = &terror;
	
	// Check pointers.
	if (!obj)
	{
		*error = SMCryptoFileErrorArguments;
		return false;
	}
	
	// Flush cache.
	if (SMCryptoFileCacheFlush(obj, error) == false)
		return false;
	
	// Flush header.
	if (SMCryptoFileHeaderFlush(obj, error) == false)
		return false;
	
	// Sync.
	switch (sync)
	{
		case SMCryptoFileSyncFull:
		{
			if (fcntl(obj->fd, F_FULLFSYNC) != -1)
				break;
			
			// In case of error, fallback to standard sync.
		}
		
		case SMCryptoFileSyncNormal:
		{
			if (fsync(obj->fd) != 0)
			{
				*error = SMCryptoFileErrorIO;
				return false;
			}
			
			break;
		}
			
		case SMCryptoFileSyncNo:
			
			break;
	}
	
	return true;
}



/*
** Helpers
*/
#pragma mark - Helpers

static unsigned SMCryptoFileRealKeySize(SMCryptoFile *obj)
{
	switch (obj->prefix.keySize)
	{
		case SMCryptoFileKeySize128:
			return 16;
			
		case SMCryptoFileKeySize192:
			return 24;
			
		case SMCryptoFileKeySize256:
			return 32;
	}
	
	return 0;
}

static bool SMCryptoFileFillGapToLength(SMCryptoFile *obj, uint64_t length, SMCryptoFileError *error)
{
	// Note: length should be a multiple of kCFFileBlockSize.
	
	if (obj->fileDataLen >= length)
		return true;
			
	// Zero bytes buffer.
	uint8_t zeroCache[kCFFileBlockSize];
	
	memset(zeroCache, 0, sizeof(zeroCache));
	
	// Write crypted zeros.
	uint8_t fileCache[kCFFileBlockSize];

	for (uint64_t offset = obj->fileDataLen; offset < length; offset += kCFFileBlockSize)
	{
		uint64_t blockNumber = offset / kCFFileBlockSize;

		// > Crypt zero byte according to current block number.
		if (SMCryptoFileBlockCrypt(obj, zeroCache, blockNumber, fileCache) == false)
		{
			*error = SMCryptoFileErrorCrypto;
			return false;
		}
		
		// > Write crypte zero bytes.
		if (pwrite(obj->fd, fileCache, sizeof(fileCache), kCFFileDataOffset + offset) != sizeof(fileCache))
		{
			*error = SMCryptoFileErrorIO;
			return false;
		}
		
		obj->fileDataLen += sizeof(fileCache);
	}
	
	// Return.
	return true;
}

static int SMCryptoFileTemporaryFile(char *pathBuffer, size_t pathBufferSize)
{
	char tmp[PATH_MAX];
	char *f;
	
	// Build template.
	if (confstr(_CS_DARWIN_USER_TEMP_DIR, tmp, sizeof(tmp)) != 0)
	{
		snprintf(pathBuffer, pathBufferSize, "%s/cryptofile_XXXXXXXX", tmp);
	}
	else if (issetugid() == 0 && (f = getenv("TMPDIR")))
	{
		snprintf(pathBuffer, pathBufferSize, "%s/cryptofile_XXXXXXXX", f);
	}
	else
	{
		strlcpy(pathBuffer, "/tmp/cryptofile_XXXXXXXX", pathBufferSize);
	}
	
	// Create unique file.
	return mkstemp(pathBuffer);
}

#pragma mark > Instance

static SMCryptoFile * SMCryptoFileAlloc(void)
{
	// Alloc space.
	size_t	allocSize = SMRoundUp(sizeof(SMCryptoFile), getpagesize());
	void	*memory = NULL;
	
	if (posix_memalign(&memory, getpagesize(), allocSize) != 0)
		return NULL;
		
	// Lock space to prevent swap to disk (our structure contain key and cache which should not be written on disk).
	if (mlock(memory, allocSize) != 0)
	{
		free(memory);
		return NULL;
	}
	
	// Initialize to 0.
	memset(memory, 0, allocSize);
	
	// Initialize common fields.
	SMCryptoFile *result = (SMCryptoFile *)memory;

	result->prefix.magic = kCFMagicValue;
	result->prefix.version = kCFCurrentVersion;
	
	result->header.check = kCFCheckValue;
	result->header.dataLen = 0;
	
	// Return object.
	return (SMCryptoFile *)memory;
}

static bool SMCryptoFileFree(SMCryptoFile *obj)
{
	size_t allocSize = SMRoundUp(sizeof(SMCryptoFile), getpagesize());

	// Set to 0 before unlocking.
	memset(obj, 0, allocSize);
	
	// Unlock.
	munlock(obj, allocSize);
	
	// Free.
	free(obj);
	
	return true;
}


#pragma mark > Prefix read / write

static bool SMCryptoFilePrefixRead(SMCryptoFile *obj, SMCryptoFileError *error)
{
	if (pread(obj->fd, &obj->prefix, sizeof(obj->prefix), kCFFilePrefixOffset) != sizeof(obj->prefix))
	{
		*error = SMCryptoFileErrorIO;
		return false;
	}
	
	return true;
}

static bool SMCryptoFilePrefixWrite(SMCryptoFile *obj, SMCryptoFileError *error)
{
	if (pwrite(obj->fd, &obj->prefix, sizeof(obj->prefix), kCFFilePrefixOffset) != sizeof(obj->prefix))
	{
		*error = SMCryptoFileErrorIO;
		return false;
	}

	return true;
}


#pragma mark > Header

static bool SMCryptoFileHeaderSetDataLen(SMCryptoFile *obj, uint64_t len, bool flushNow, SMCryptoFileError *error)
{
	if (obj->header.dataLen == len)
		return true;
	
	obj->header.dataLen = len;
	obj->headerDirty = true;
	
	if (flushNow)
		return SMCryptoFileHeaderFlush(obj, error);
	
	return true;
}

static bool SMCryptoFileHeaderFlush(SMCryptoFile *obj, SMCryptoFileError *error)
{
	if (obj->headerDirty == false)
		return true;
	
	if (SMCryptoFileHeaderWrite(obj, error) == false)
		return false;
	
	obj->headerDirty = false;
		
	return true;
}

static bool SMCryptoFileHeaderRead(SMCryptoFile *obj, SMCryptoFileError *error)
{
	// Read crypted header.
	char cryptedHeader[sizeof(obj->header)];

	if (pread(obj->fd, cryptedHeader, sizeof(cryptedHeader), kCFFileHeaderOffset) != sizeof(cryptedHeader))
	{
		*error = SMCryptoFileErrorIO;
		return false;
	}
	
	// Decrypt header.
	CCCryptorStatus	status;
	unsigned		keySize = SMCryptoFileRealKeySize(obj);

	status = CCCrypt(kCCDecrypt, kCCAlgorithmAES, 0, obj->headerKey, keySize, obj->prefix.headerIV, cryptedHeader, sizeof(cryptedHeader), &obj->header, sizeof(obj->header), NULL);
	
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't decrypt header (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		return false;
	}
	
	return true;
}

static bool SMCryptoFileHeaderWrite(SMCryptoFile *obj, SMCryptoFileError *error)
{
	// Crypt header with header key.
	CCCryptorStatus	status;
	unsigned		keySize = SMCryptoFileRealKeySize(obj);
	char			cryptedHeader[sizeof(obj->header)];

	status = CCCrypt(kCCEncrypt, kCCAlgorithmAES, 0, obj->headerKey, keySize, obj->prefix.headerIV, &obj->header, sizeof(obj->header), cryptedHeader, sizeof(cryptedHeader), NULL);
	
	if (status != kCCSuccess)
	{
		SMCryptoDebugLog("Error: Can't crypt header (%d).\n", status);
		*error = SMCryptoFileErrorCrypto;
		return false;
	}

	// Write crypted header.
	if (pwrite(obj->fd, cryptedHeader, sizeof(cryptedHeader), kCFFileHeaderOffset) != sizeof(cryptedHeader))
	{
		*error = SMCryptoFileErrorIO;
		return false;
	}

	return true;
}


#pragma mark > Cache

static bool SMCryptoFileCacheFlush(SMCryptoFile *obj, SMCryptoFileError *error)
{
	// Fast path.
	if (obj->cachedDataDirty == false || obj->cachedDataSize == 0)
		return true;
	
	uint8_t		tempCache[kCFFileCacheSize + kCFFileBlockSize];
	uint64_t	offset = 0;
	uint64_t	fullSize = 0;
	
	// Encrypt inner cache.
	uint64_t innerSize = SMRoundDown(obj->cachedDataSize, kCFFileBlockSize);
	
	for (offset = 0; offset < innerSize; offset += kCFFileBlockSize)
	{
		uint64_t blockNumber = (obj->cachedDataOffset + offset) / kCFFileBlockSize;

		// > Crypt block.
		if (SMCryptoFileBlockCrypt(obj, obj->cachedData + offset, blockNumber, tempCache + offset) == false)
		{
			*error = SMCryptoFileErrorCrypto;
			return false;
		}
	}
	
	fullSize += innerSize;
	
	// Encrypt suffix cache.
	uint64_t suffixSize = obj->cachedDataSize - innerSize;

	if (suffixSize > 0)
	{
		uint64_t blockNumber = (obj->cachedDataOffset + offset) / kCFFileBlockSize;
		
		// > Read block at suffix.
		uint8_t clearBlock[kCFFileBlockSize];

		if (obj->cachedDataOffset + offset + sizeof(clearBlock) > obj->fileDataLen)
		{
			// > End-Of-File: use 0 allocated buffer.

			memset(clearBlock, 0, sizeof(clearBlock));
		}
		else
		{
			uint8_t fileBlock[kCFFileBlockSize];

			// > Read.
			if (pread(obj->fd, fileBlock, sizeof(fileBlock), kCFFileDataOffset + obj->cachedDataOffset + offset) != sizeof(fileBlock))
			{
				*error = SMCryptoFileErrorIO;
				return false;
			}
			
			// > Decrypt.
			if (SMCryptoFileBlockDecrypt(obj, fileBlock, blockNumber, clearBlock) == false)
			{
				*error = SMCryptoFileErrorCrypto;
				return false;
			}
		}
		
		// > Overwrite block with cache.
		memcpy(clearBlock, obj->cachedData + offset, (size_t)suffixSize);
		
		// > Crypt block.
		if (SMCryptoFileBlockCrypt(obj, clearBlock, blockNumber, tempCache + offset) == false)
		{
			*error = SMCryptoFileErrorCrypto;
			return false;
		}
		
		fullSize += sizeof(clearBlock);
	}

	// Write padding zero (if necessary) betwen current concrete length and offset.
	if (SMCryptoFileFillGapToLength(obj, obj->cachedDataOffset, error) == false)
		return false;
	
	// Write tempCache on disk.
	if (pwrite(obj->fd, tempCache, (size_t)fullSize, kCFFileDataOffset +  obj->cachedDataOffset) != fullSize)
	{
		*error = SMCryptoFileErrorIO;
		return false;
	}
	
	// Update  data file len.
	obj->fileDataLen = MAX(obj->fileDataLen, obj->cachedDataOffset + fullSize);
	
	// Clean dirty flag.
	obj->cachedDataDirty = false;
	
	// Return.
	return true;
}

static bool SMCryptoFileCachePrepareReadingAtCurrentOffset(SMCryptoFile *obj, SMCryptoFileError *error)
{
	// Do nothing if cache is already on the right place.
	if ((obj->currentOffset >= obj->cachedDataOffset) && (obj->currentOffset < obj->cachedDataOffset + obj->cachedDataSize))
		return true;
	
	// Flush current data in cache (+ possible header changes) before read a new chunk
	if (SMCryptoFileFlush(obj, SMCryptoFileSyncNo, error) == false)
		return false;
	
	uint64_t currentOffset = SMRoundDown(obj->currentOffset, kCFFileBlockSize);
	
	// Read wanted offset.
	// > Compute cache size.
	uint64_t dataSize = SMRoundUp(obj->header.dataLen, kCFFileBlockSize);
	uint64_t cacheSize;
	
	if (currentOffset + kCFFileCacheSize > dataSize)
		cacheSize = dataSize - currentOffset;
	else
		cacheSize = kCFFileCacheSize;
	
	if (cacheSize == 0)
	{
		obj->cachedDataOffset = currentOffset;
		obj->cachedDataSize = 0;
		
		return true;
	}
	
	// > Read blocks.
	if (currentOffset + cacheSize > obj->fileDataLen)
	{
		// > End-Of-File: use 0 allocated buffer.

		memset(obj->cachedData, 0, (size_t)cacheSize);
	}
	else
	{
		uint8_t fileCache[kCFFileCacheSize];

		// > Read.
		if (pread(obj->fd, fileCache, (size_t)cacheSize, kCFFileDataOffset + currentOffset) != cacheSize)
		{
			*error = SMCryptoFileErrorIO;
			return false;
		}
		
		// > Decrypt.
		for (uint64_t cacheOffset = 0; cacheOffset < cacheSize; cacheOffset += kCFFileBlockSize)
		{
			uint64_t blockNumber = (currentOffset + cacheOffset) / kCFFileBlockSize;
			
			if (SMCryptoFileBlockDecrypt(obj, fileCache + cacheOffset, blockNumber, obj->cachedData + cacheOffset) == false)
			{
				*error = SMCryptoFileErrorCrypto;
				obj->cachedDataSize = 0;
				
				return false;
			}
		}
	}
	
	// > Update cache info.
	obj->cachedDataOffset = currentOffset;
	obj->cachedDataSize = cacheSize;
	
	// Done.
	return true;
}

static bool SMCryptoFileCachePrepareWritingAtCurrentOffset(SMCryptoFile *obj, SMCryptoFileError *error)
{
	// Do nothing if it's already possible to write in the cache.
	if ((obj->currentOffset >= obj->cachedDataOffset) && (obj->currentOffset <= obj->cachedDataOffset + obj->cachedDataSize) && (obj->cachedDataSize < kCFFileCacheSize))
		return true;
	
	// Flush current data in cache (+ flush possible header changes) before prepare cache for currentOffset.
	if (SMCryptoFileFlush(obj, SMCryptoFileSyncNo, error) == false)
		return false;

	// Prepare the cache for currentOffset.
	uint64_t	currentOffset = SMRoundDown(obj->currentOffset, kCFFileBlockSize);
	size_t		prefixSize = (size_t)(obj->currentOffset - currentOffset);

	if (prefixSize > 0)
	{
		// currentOffset is misaligned : align it by reading the block where the offset is.
		
		uint64_t blockNumber = currentOffset / kCFFileBlockSize;
		
		// > Read crypted blocks.
		if (currentOffset + kCFFileBlockSize > obj->fileDataLen)
		{
			// > End-Of-File: use 0 allocated buffer.
			memset(obj->cachedData, 0, kCFFileBlockSize);
		}
		else
		{
			uint8_t fileBlock[kCFFileBlockSize];

			// > Read.
			if (pread(obj->fd, fileBlock, sizeof(fileBlock), kCFFileDataOffset + currentOffset) != sizeof(fileBlock))
			{
				*error = SMCryptoFileErrorIO;
				return false;
			}
			
			// > Decrypt.
			if (SMCryptoFileBlockDecrypt(obj, fileBlock, blockNumber, obj->cachedData) == false)
			{
				obj->cachedDataOffset = 0;
				obj->cachedDataSize = 0;
				
				*error = SMCryptoFileErrorCrypto;
				
				return false;
			}
		}

		// > Set values.
		obj->cachedDataOffset = currentOffset;
		obj->cachedDataSize = kCFFileBlockSize;
	}
	else
	{
		// currentOffset is aligned: just reset the cache.
		
		// > Set values.
		obj->cachedDataOffset = currentOffset;
		obj->cachedDataSize = 0;
	}
	
	return true;
}


#pragma mark > Block crypt / decrypt

static bool SMCryptoFileBlockCrypt(SMCryptoFile *obj, const void *block, uint64_t blocknum, void *output)
{
	// Generate block tweak.
	uint8_t		iv_tweak[kCCBlockSizeAES128];
	uint64_t	*tw_int = (uint64_t *)iv_tweak;
	
	// XXX There is any norm defined somewhere to generate the block number tweak ?
	tw_int[0] = OSSwapHostToBigInt64(blocknum);
	tw_int[1] = OSSwapHostToLittleInt64(blocknum);
	
	// Crypt.
	CCCryptorStatus status = CCCryptorEncryptDataBlock(obj->dataEncrypt, iv_tweak, block, kCFFileBlockSize, output);
	
	return (status == kCCSuccess);
}

static bool SMCryptoFileBlockDecrypt(SMCryptoFile *obj, const void *block, uint64_t blocknum, void *output)
{
	// Generate block tweak.
	uint8_t		iv_tweak[kCCBlockSizeAES128];
	uint64_t	*tw_int = (uint64_t *)iv_tweak;
	
	// XXX There is any norm defined somewhere to generate the block number tweak ?
	tw_int[0] = OSSwapHostToBigInt64(blocknum);
	tw_int[1] = OSSwapHostToLittleInt64(blocknum);
	
	// Decrypt.
	CCCryptorStatus status = CCCryptorDecryptDataBlock(obj->dataDecrypt, iv_tweak, block, kCFFileBlockSize, output);
	
	return (status == kCCSuccess);
}


#pragma mark > Ranges

static SMCryptoRange SMCryptoMakeRange(uint64_t location, uint64_t length)
{
	SMCryptoRange result = { .location = location, .length = length} ;
	
	return result;
}

static uint64_t SMCryptoMaxRange(SMCryptoRange range)
{
	return range.location + range.length;
}

static SMCryptoRange SMCryptoIntersectionRange(SMCryptoRange r1, SMCryptoRange r2)
{
	uint64_t min, loc;
	uint64_t max1 = SMCryptoMaxRange(r1);
	uint64_t max2 = SMCryptoMaxRange(r2);
	SMCryptoRange result;
	
	min = (max1 < max2) ? max1 : max2;
	loc = (r1.location > r2.location) ? r1.location:r2.location;
	
	if (min < loc)
	{
		result.location = 0;
		result.length = 0;
	}
	else
	{
		result.location = loc;
		result.length = min - loc;
	}
	
	return result;
}


#pragma mark > CRC32

// CRC32 - COPYRIGHT (C) 1986 Gary S. Brown (crc32.c / libkern / xnu).

static uint32_t crc32_tab[] = {
	0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
	0xe963a535, 0x9e6495a3,	0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
	0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,
	0xf3b97148, 0x84be41de,	0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
	0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,	0x14015c4f, 0x63066cd9,
	0xfa0f3d63, 0x8d080df5,	0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
	0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,	0x35b5a8fa, 0x42b2986c,
	0xdbbbc9d6, 0xacbcf940,	0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
	0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
	0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
	0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,	0x76dc4190, 0x01db7106,
	0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
	0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
	0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
	0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
	0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
	0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
	0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
	0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
	0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
	0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
	0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
	0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
	0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
	0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
	0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
	0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
	0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
	0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
	0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
	0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
	0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
	0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
	0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
	0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
	0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
	0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
	0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
	0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
	0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
	0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
	0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
	0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
};

static uint32_t SMCryptoCRC32(uint32_t crc, const void *buf, size_t size)
{
	const uint8_t *p;
	
	p = buf;
	crc = crc ^ ~0U;
	
	while (size--)
		crc = crc32_tab[(crc ^ *p++) & 0xFF] ^ (crc >> 8);
	
	return crc ^ ~0U;
}
