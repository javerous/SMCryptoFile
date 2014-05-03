/*
 * SMCryptoFile.h
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


/*
 * -- Informations --
 *
 * This code use AES-XTS to crypt / decrypt data.
 *
 */


#ifndef SMCRYPTOFILE_H_
# define SMCRYPTOFILE_H_

# include <stdint.h>
# include <stdbool.h>


/*
** Types
*/
#pragma mark - Types

typedef struct SMCryptoFile SMCryptoFile;

typedef enum
{
	SMCryptoFileErrorNo = 0,

	SMCryptoFileErrorArguments,	// Bad arguments passed to the function.
	SMCryptoFileErrorFormat,	// The file is not a crypto-file.
	SMCryptoFileErrorVersion,	// The file version is not compatible with this code.
	SMCryptoFileErrorPassword,	// Bad password used when opening a file.
	SMCryptoFileErrorCorrupted, // The header is corrupted.
	SMCryptoFileErrorCrypto,	// Problem with crypto engine on crypt / decrypt.
	SMCryptoFileErrorReadOnly,	// Tried to do a write operation on a read-only file.
	SMCryptoFileErrorIO,		// Problem with Input / Output subsytem.
	SMCryptoFileErrorMemory,	// Problem with memory allocation.
	SMCryptoFileErrorUnknown	// Unknown error.
} SMCryptoFileError;

typedef enum
{
	SMCryptoFileKeySize128 = 0,	// AES 128
	SMCryptoFileKeySize192 = 1,	// AES 192
	SMCryptoFileKeySize256 = 2,	// AES 256
} SMCryptoFileKeySize;

typedef enum
{
	SMCryptoFileSyncNo,		// Simply write data in cache to file.
	SMCryptoFileSyncNormal,	// . + synchronize the file in-core state with that on disk.
	SMCryptoFileSyncFull	// . . + ask the drive to flush all buffered data to permanent storage.
} SMCryptoFileSyncType;

typedef enum
{
	SMCryptoFileSeekSet,
	SMCryptoFileSeekCurrent,
	SMCryptoFileSeekEnd
} SMCryptoFileSeekWhence;



/*
** Functions
*/
#pragma mark - Functions

// -- Helpers --
bool			SMCryptoFileCanOpen(const char *path);

// -- Instance --
SMCryptoFile *	SMCryptoFileCreate(const char *path, const char *password, SMCryptoFileKeySize keySize, SMCryptoFileError *error);
SMCryptoFile *	SMCryptoFileCreateImpersonated(SMCryptoFile *original, const char *path, SMCryptoFileError *error);		// Impersonate a crypto file by copying its prefix (header and datas are NOT copied). The impersonation itself is thread safe.
SMCryptoFile *	SMCryptoFileCreateVolatile(const char *path, SMCryptoFileKeySize keySize, SMCryptoFileError *error);	// Create a crypto file with a one-time random password. Usefull to have a temporary crypted cache.

SMCryptoFile *	SMCryptoFileOpen(const char *path, const char *password, bool readOnly, SMCryptoFileError *error);

bool			SMCryptoFileClose(SMCryptoFile *file, SMCryptoFileError *error);

// -- Tools --
bool			SMCryptoFileChangePassword(SMCryptoFile *file, const char *newPassword, SMCryptoFileError *error);

// -- Properties --
uint64_t		SMCryptoFileSize(SMCryptoFile *file);

// -- I/O --
bool			SMCryptoFileTruncate(SMCryptoFile *file, uint64_t length, SMCryptoFileError *error);

bool			SMCryptoFileSeek(SMCryptoFile *obj, int64_t offset, SMCryptoFileSeekWhence whence, SMCryptoFileError *error);
uint64_t		SMCryptoFileTell(SMCryptoFile *file);

int64_t			SMCryptoFileRead(SMCryptoFile *file, void *ptr, uint64_t size, SMCryptoFileError *error); // -1 -> error; 0 -> eof
bool			SMCryptoFileWrite(SMCryptoFile *file, const void *ptr, uint64_t size, SMCryptoFileError *error);

bool			SMCryptoFileFlush(SMCryptoFile *file, SMCryptoFileSyncType sync, SMCryptoFileError *error);

#endif
