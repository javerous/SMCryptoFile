/*
 * SMSQLiteCryptoVFS.c
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


#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include <stdio.h>

#include <libkern/OSAtomic.h>

#include <dispatch/dispatch.h>

#include <uuid/uuid.h>

#include <sys/stat.h>
#include <sys/syslimits.h>

#include "SMSQLiteCryptoVFS.h"

#include "SMCryptoFile.h"


/*
** Types
*/
#pragma mark - Types

// -- SQLite --
typedef struct VFSCryptFile
{
	// Super (must be first).
	sqlite3_file	base;
	
	// vfscrypt.
	char			*path;
	SMCryptoFile	*file;
	
	
} VFSCryptFile;

// -- Settings --
typedef struct VFSCryptSetting
{
	uuid_string_t		uuid;
	
	char				*password;
	SMCryptoFileKeySize	keySize;
} VFSCryptSetting;

// -- List --
typedef struct VFSCryptListItem VFSCryptListItem;

typedef struct VFSCryptList
{
	VFSCryptListItem *first;
	VFSCryptListItem *last;
} VFSCryptList;

struct VFSCryptListItem
{
	char	*key;
	size_t	keyLen;
	
	void	*content;
	
	VFSCryptListItem *next;
};



/*
** Globals
*/
#pragma mark - Globals

static dispatch_queue_t	gSettingsQueue = NULL;
static dispatch_queue_t	gMainBasesQueue = NULL;

static VFSCryptList		*gSettingsList = NULL;
static VFSCryptList		*gMainBasesList = NULL;

static sig_atomic_t		gKeySize = SMCryptoFileKeySize128;

static sig_atomic_t		gCryptoFileError  = SMCryptoFileErrorNo;



/*
** Prototypes
*/
#pragma mark - Prototypes

// -- Settings --
static bool	SMSLiteCryptoVFSSettingsGet(const char *uuid, void (^foundBlock)(const char *password, SMCryptoFileKeySize keySize));

// -- Defaults --
static SMCryptoFileKeySize SMSQLiteCryptoVFSDefaultsGetKeySize(void);

// -- Errors ---
static void SMSQLiteCryptoVFSSetFileCryptoError(SMCryptoFileError error);

// -- List --
static VFSCryptList *	VFSCryptListCreate(void);
static void				VFSCryptListAddItem(VFSCryptList *list, const char *key, void *content);
static void *			VFSCryptListGetItem(VFSCryptList *list, const char *key);
static void				VFSCryptListRemoteItem(VFSCryptList *list, const char *key, void (^freeBlock)(void *content));

// -- Helpers --
static char *	VFSCryptMainDatabasePath(const char *subFilePath);

// -- sqlite3_vfs --
static int VFSCryptOpen(sqlite3_vfs *pVfs, const char *zName, sqlite3_file *pFile, int flags, int *pOutFlags);

// -- sqlite3_file --
static int VFSCryptClose(sqlite3_file *pFile);
static int VFSCryptRead(sqlite3_file *pFile, void *zBuf, int iAmt, sqlite_int64 iOfst);
static int VFSCryptWrite(sqlite3_file *pFile, const void *zBuf, int iAmt, sqlite_int64 iOfst);

static int VFSCryptTruncate(sqlite3_file *pFile, sqlite_int64 size);
static int VFSCryptSync(sqlite3_file *pFile, int flags);
static int VFSCryptFileSize(sqlite3_file *pFile, sqlite_int64 *pSize);
static int VFSCryptLock(sqlite3_file *pFile, int eLock);
static int VFSCryptUnlock(sqlite3_file *pFile, int eLock);
static int VFSCryptCheckReservedLock(sqlite3_file *pFile, int *pResOut);
static int VFSCryptFileControl(sqlite3_file *pFile, int op, void *pArg);
static int VFSCryptSectorSize(sqlite3_file *pFile);
static int VFSCryptDeviceCharacteristics(sqlite3_file *pFile);



/*
** Properties
*/
#pragma mark - Properties

const char *SMSQLiteCryptoVFSName()
{
	return "SMSQLiteCryptoVFS";
}



/*
** Register
*/
#pragma mark - Register

int SMSQLiteCryptoVFSRegister()
{
	static dispatch_once_t	onceToken;
	static sqlite3_vfs		vfscrypt;

	__block int result = SQLITE_OK;
	
	dispatch_once(&onceToken, ^{
		
		sqlite3_vfs *rootvfs;
		
		// Search default VFS.
		rootvfs = sqlite3_vfs_find(NULL);
		
		if (!rootvfs)
		{
			result = SQLITE_NOTFOUND;
			return;
		}
		
		// Convigure crypt VFS.
		vfscrypt = *rootvfs;
		
		vfscrypt.szOsFile = sizeof(VFSCryptFile);
		vfscrypt.zName = SMSQLiteCryptoVFSName();
		
		vfscrypt.xOpen = VFSCryptOpen;
		
		// Register.
		result = sqlite3_vfs_register(&vfscrypt, 0);
		
		// Create queues.
		gSettingsQueue = dispatch_queue_create("com.sourcemac.sqlitecryptovfs.settings", DISPATCH_QUEUE_CONCURRENT);
		gMainBasesQueue = dispatch_queue_create("com.sourcemac.sqlitecryptovfs.main_bases", DISPATCH_QUEUE_CONCURRENT);

		// Create lists.
		gSettingsList = VFSCryptListCreate();
		gMainBasesList = VFSCryptListCreate();
	});
	
	return result;
}



/*
** Settings
*/
#pragma mark - Settings

const char *SMSQLiteCryptoVFSSettingsAdd(const char *password, SMCryptoFileKeySize keySize)
{
	// Check settings.
	if (!password || strlen(password) == 0)
		return NULL;
	
	// Create setting object.
	VFSCryptSetting *setting = malloc(sizeof(VFSCryptSetting));
	
	setting->password = strdup(password);
	setting->keySize = keySize;
	
	// Generate UUID.
	uuid_t uuid;
	
	uuid_generate(uuid);
	uuid_unparse(uuid, setting->uuid);
	
	// Store this setting.
	dispatch_barrier_async(gSettingsQueue, ^{
		VFSCryptListAddItem(gSettingsList, setting->uuid, setting);
	});
	
	// Return UUID.
	return setting->uuid;
}

void SMSQLiteCryptoVFSSettingsRemove(const char *uuid)
{
	if (!uuid)
		return;
	
	dispatch_barrier_async(gSettingsQueue, ^{
		VFSCryptListRemoteItem(gSettingsList, uuid, ^(void *content) {
			
			VFSCryptSetting *setting = content;
			
			free(setting->password);
			free(setting);
		});
	});
}

static bool SMSLiteCryptoVFSSettingsGet(const char *uuid, void (^foundBlock)(const char *password, SMCryptoFileKeySize keySize))
{
	if (!uuid || !foundBlock)
		return false;
	
	__block bool found = false;
	
	dispatch_sync(gSettingsQueue, ^{
		
		VFSCryptSetting *setting = VFSCryptListGetItem(gSettingsList, uuid);
		
		if (setting)
		{
			foundBlock(setting->password, setting->keySize);
			
			found = true;
		}
	});
	
	return found;
}



/*
** Defaults
*/
#pragma mark - Defaults

void SMSQLiteCryptoVFSDefaultsSetKeySize(SMCryptoFileKeySize keySize)
{
	switch (keySize)
	{
		case SMCryptoFileKeySize128:
		case SMCryptoFileKeySize192:
		case SMCryptoFileKeySize256:
		{
			gKeySize = keySize;
			OSMemoryBarrier();
			break;
		}
	}
}

static SMCryptoFileKeySize SMSQLiteCryptoVFSDefaultsGetKeySize(void)
{
	OSMemoryBarrier();
	return gKeySize;
}



/*
** Tools
*/
#pragma mark - Tools

bool SMSQLiteCryptoVFSChangePassword(sqlite3 *cryptedBase, const char *newPassword, SMCryptoFileError *error)
{
	// Parameters.
	SMCryptoFileError berror;
	
	if (!error)
		error = &berror;
	
	if (!cryptedBase || !newPassword)
	{
		*error = SMCryptoFileErrorArguments;
		return false;
	}
	
	// Path.
	const char *path = sqlite3_db_filename(cryptedBase, "main");
	
	if (!path)
	{
		*error = SMCryptoFileErrorArguments;
		return false;
	}
	
	// Get file.
	__block SMCryptoFile *file = NULL;
	
	dispatch_sync(gMainBasesQueue, ^{
		file = VFSCryptListGetItem(gMainBasesList, path);
	});
	
	if (!file)
	{
		*error = SMCryptoFileErrorArguments;
		return false;
	}
	
	// Chnage password.
	return SMCryptoFileChangePassword(file, newPassword, error);
}



/*
** Errors
*/
#pragma mark - Errors

SMCryptoFileError SMSQLiteCryptoVFSLastFileCryptoError(void)
{
	OSMemoryBarrier();
	return (SMCryptoFileError)gCryptoFileError;
}

static void SMSQLiteCryptoVFSSetFileCryptoError(SMCryptoFileError error)
{
	gCryptoFileError = error;
	OSMemoryBarrier();
}



/*
** List
*/
#pragma mark - List

VFSCryptList *VFSCryptListCreate(void)
{
	return calloc(1, sizeof(VFSCryptList));
}

void VFSCryptListAddItem(VFSCryptList *list, const char *key, void *content)
{
	if (!list || !key)
		return;
	
	VFSCryptListItem *item = malloc(sizeof(VFSCryptListItem));
	
	item->key = strdup(key);
	item->keyLen = strlen(key);
	
	item->content = content;
	item->next = NULL;
	
	if (!list->first || !list->last)
	{
		list->first = item;
		list->last = item;
	}
	else
	{
		list->last->next = item;
		list->last = item;
	}
}

void * VFSCryptListGetItem(VFSCryptList *list, const char *key)
{
	if (!list || !key)
		return NULL;
	
	size_t		keyLen = strlen(key);
	VFSCryptListItem	*item = list->first;
	
	while (item)
	{
		if (keyLen == item->keyLen && memcmp(key, item->key, keyLen) == 0)
			return item->content;
		
		item = item->next;
	}
	
	return NULL;
}

void VFSCryptListRemoteItem(VFSCryptList *list, const char *key, void (^freeBlock)(void *content))
{
	if (!list || !key)
		return;
	
	size_t		keyLen = strlen(key);
	VFSCryptListItem	*pItem = NULL;
	VFSCryptListItem	*item = list->first;
	
	while (item)
	{
		if (keyLen == item->keyLen && memcmp(key, item->key, keyLen) == 0)
		{
			if (item == list->first)
				list->first = item->next;
			
			if (item == list->last)
				list->last = pItem;
			
			if (pItem)
				pItem->next = item->next;
			
			if (freeBlock)
				freeBlock(item->content);
			
			free(item->key);
			free(item);
			
			break;
		}
		
		pItem = item;
		item = item->next;
	}
}



/*
** Helpers
*/
#pragma mark - Helpers

static char *VFSCryptMainDatabasePath(const char *subFilePath)
{
	// This function try to find the main base associated with a sub file (journal, WAL).
	// This is a little bit ugly but :
	// - The code is inspired from the official sources (and so they do that too).
	// - The VFS API is weak : there is no way to know officialy to wich base a journal or WAL is associated.
	// - The URI arguments used for the main base are not passed to the journal or WAL URI.
	
	if (!subFilePath)
		return NULL;
	
	// Get size.
	ssize_t size = strlen(subFilePath);
	
	if (size == 0)
		return NULL;
	
	// Search for the char '-' which is appended to sub files.
	for (size_t offset = size; offset > 0; offset--)
	{
		if (subFilePath[offset - 1] == '-')
		{
			char *result = malloc(offset);
			
			memcpy(result, subFilePath, offset - 1);
			
			result[offset - 1] = '\0';
			
			return result;
		}
    }
	
	return NULL;
}



/*
** sqlite3_vfs
*/
#pragma mark - sqlite3_vfs

static int VFSCryptOpen(sqlite3_vfs *pVfs, const char *zName, sqlite3_file *pFile, int flags, int *pOutFlags)
{
	VFSCryptFile		*p = (VFSCryptFile *)pFile;
	
	SMCryptoFile		*file = NULL;
	SMCryptoFileError	error;
	
	SMSQLiteCryptoVFSSetFileCryptoError(SMCryptoFileErrorNo);
	
	if (!zName)
	{
		// No name: temporary file.
		
		file = SMCryptoFileCreateVolatile(NULL, SMSQLiteCryptoVFSDefaultsGetKeySize(), &error);

		if (!file)
		{
			SMSQLiteCryptoVFSSetFileCryptoError(error);
			sqlite3_log(SQLITE_CANTOPEN, "Crypto file error (SMCryptoFileCreateVolatile / VFSCryptOpen) - error %d", error);
			return SQLITE_CANTOPEN;
		}
	}
	else
	{
		// Open / create file.
		
		if ((flags & SQLITE_OPEN_MAIN_DB) == SQLITE_OPEN_MAIN_DB)
		{
			// Get UUID.
			const char *uuid = sqlite3_uri_parameter(zName, "crypto-uuid");
			
			if (!uuid)
			{
				sqlite3_log(SQLITE_MISUSE, "VFS error (VFSCryptOpen) - can't found 'crypto-uuid' in URI");
				return SQLITE_MISUSE;
			}
			
			// Get crypto file settings.
			__block char				*password = NULL;
			__block SMCryptoFileKeySize keySize = 0;
			
			SMSLiteCryptoVFSSettingsGet(uuid, ^(const char *sPassword, SMCryptoFileKeySize sKeySize) {
				password = strdup(sPassword);
				keySize = sKeySize;
			});
			
			if (!password)
			{
				sqlite3_log(SQLITE_MISUSE, "VFS error (VFSCryptOpen) - password not found");
				return SQLITE_MISUSE;
			}
			
			// Create / open crypto file.
			bool shouldCreate = (access(zName, R_OK) != 0 && ((flags & SQLITE_OPEN_CREATE) == SQLITE_OPEN_CREATE));
			
			if (shouldCreate)
				file = SMCryptoFileCreate(zName, password, keySize, &error);
			else
				file = SMCryptoFileOpen(zName, password, ((flags & SQLITE_OPEN_READONLY) == SQLITE_OPEN_READONLY), &error);
			
			free(password);
			
			// Error.
			if (!file)
			{
				SMSQLiteCryptoVFSSetFileCryptoError(error);

				if (shouldCreate)
					sqlite3_log(SQLITE_CANTOPEN, "Crypto file error (SMCryptoFileCreate / VFSCryptOpen) - error %d", error);
				else
					sqlite3_log(SQLITE_CANTOPEN, "Crypto file error (SMCryptoFileOpen / VFSCryptOpen) - error %d", error);
				
				return SQLITE_CANTOPEN;
			}
			
			// Store file for sub file impersonation.
			dispatch_barrier_async(gMainBasesQueue, ^{
				VFSCryptListAddItem(gMainBasesList, zName, file);
			});
		}
		else
		{
			// Search for the main crypto file.
			char *mainPath = VFSCryptMainDatabasePath(zName);
			
			__block SMCryptoFile *mainFile = NULL;
			
			if (mainPath)
			{
				// > Get crypto object.
				dispatch_sync(gMainBasesQueue, ^{
					mainFile = VFSCryptListGetItem(gMainBasesList, mainPath);
				});
			}
			
			// Create sub crypto file.
			if (mainFile)
			{
				// Assertion: mainFile is valid there, as sub-files are never opened after its related base is closed.
				// This assertion prevent us to block the gMainBasesQueue while crypto file close, or crypto file impersonation.
				
				// Create file.
				file = SMCryptoFileCreateImpersonated(mainFile, zName, &error);
				
				if (!file)
				{
					SMSQLiteCryptoVFSSetFileCryptoError(error);

					if (mainPath)
						free(mainPath);
					
					sqlite3_log(SQLITE_CANTOPEN, "Crypto file error (SMCryptoFileCreateImpersonated / VFSCryptOpen) - error %d", error);
					
					return SQLITE_CANTOPEN;
				}
				
				// Fix uid / gid (useful if we are root opening a base created by a standard user).
				struct stat st;
				
				if (stat(mainPath, &st) == 0)
					chown(zName, st.st_uid, st.st_gid);
			}
			else
			{
				// No crypto file associated with main file. Use a volatile crypto file.
				
				file = SMCryptoFileCreateVolatile(zName, SMSQLiteCryptoVFSDefaultsGetKeySize(), &error);
				
				if (!file)
				{
					SMSQLiteCryptoVFSSetFileCryptoError(error);

					if (mainPath)
						free(mainPath);
					
					sqlite3_log(SQLITE_CANTOPEN, "Crypto file error (SMCryptoFileCreateVolatile / VFSCryptOpen) - error %d", error);
					
					return SQLITE_CANTOPEN;
				}
			}

			// Clean.
			if (mainPath)
				free(mainPath);
		}
		
		// Delete on close.
		if ((flags & SQLITE_OPEN_DELETEONCLOSE) == SQLITE_OPEN_DELETEONCLOSE)
			unlink(zName);
	}
	
	// Hold info.
	p->file = file;
	
	if (zName)
		p->path = strdup(zName);
	else
		p->path = NULL;

	// Set I/O.
	static sqlite3_io_methods	ioMethods;
	static dispatch_once_t		onceToken;
	
	dispatch_once(&onceToken, ^{
		
		memset(&ioMethods, 0, sizeof(ioMethods));
		
		ioMethods.iVersion = 1; // no shared memory.
		
		ioMethods.xClose = VFSCryptClose;
		ioMethods.xRead = VFSCryptRead;
		ioMethods.xWrite = VFSCryptWrite;
		ioMethods.xTruncate = VFSCryptTruncate;
		ioMethods.xSync = VFSCryptSync;
		ioMethods.xFileSize = VFSCryptFileSize;
		ioMethods.xLock = VFSCryptLock;
		ioMethods.xUnlock = VFSCryptUnlock;
		ioMethods.xCheckReservedLock = VFSCryptCheckReservedLock;
		ioMethods.xFileControl = VFSCryptFileControl;
		ioMethods.xSectorSize = VFSCryptSectorSize;
		ioMethods.xDeviceCharacteristics = VFSCryptDeviceCharacteristics;
	});
		
	pFile->pMethods = &ioMethods;

	return SQLITE_OK;
}



/*
** sqlite3_file
*/
#pragma mark - sqlite3_file

static int VFSCryptClose(sqlite3_file *pFile)
{
	VFSCryptFile *p = (VFSCryptFile *)pFile;
	
	SMSQLiteCryptoVFSSetFileCryptoError(SMCryptoFileErrorNo);

	// Check structure.
	if (p->file == NULL)
	{
		sqlite3_log(SQLITE_INTERNAL, "VFS error (VFSCryptClose): NULL file");
		return SQLITE_INTERNAL;
	}
	
	// Remote the main base path -> main base cryptor file association.
	if (p->path)
	{
		dispatch_barrier_sync(gMainBasesQueue, ^{
			VFSCryptListRemoteItem(gMainBasesList, p->path, NULL);
		});
		
		free(p->path);
		p->path = NULL;
	}
	
	// Close.
	SMCryptoFileError error;
		
	if (SMCryptoFileClose(p->file, &error) == false)
	{
		SMSQLiteCryptoVFSSetFileCryptoError(error);
		sqlite3_log(SQLITE_IOERR_CLOSE, "Crypto file error (SMCryptoFileClose / VFSCryptClose) - error %d", error);
		return SQLITE_IOERR_CLOSE;
	}
	
	p->file = NULL;
	
	return SQLITE_OK;
}

static int VFSCryptRead(sqlite3_file *pFile, void *zBuf, int iAmt, sqlite_int64 iOfst)
{
	VFSCryptFile *p = (VFSCryptFile *)pFile;

	SMSQLiteCryptoVFSSetFileCryptoError(SMCryptoFileErrorNo);
	
	// Check file.
	if (p->file == NULL)
	{
		sqlite3_log(SQLITE_INTERNAL, "VFS error (VFSCryptClose): NULL file");
		return SQLITE_INTERNAL;
	}
	
	SMCryptoFileError error;

	// Seek.
	if (SMCryptoFileSeek(p->file, iOfst, SEEK_SET, &error) == false)
	{
		SMSQLiteCryptoVFSSetFileCryptoError(error);
		sqlite3_log(SQLITE_IOERR_SEEK, "Crypto file error (SMCryptoFileSeek / VFSCryptRead) - error %d", error);
		return SQLITE_IOERR_SEEK;
	}
	
	// Read.
	int64_t size;
	
	size = SMCryptoFileRead(p->file, zBuf, iAmt, &error);
	
	if (size == -1)
	{
		SMSQLiteCryptoVFSSetFileCryptoError(error);
		sqlite3_log(SQLITE_IOERR_READ, "Crypto file error (SMCryptoFileRead / VFSCryptRead) - error %d", error);
		return SQLITE_IOERR_READ;
	}
	else if (size == iAmt)
	{
		return SQLITE_OK;
	}
	else
	{
		memset((char *)zBuf + size, 0, (size_t)(iAmt - size));
		
		return SQLITE_IOERR_SHORT_READ;
	}
}

static int VFSCryptWrite(sqlite3_file *pFile, const void *zBuf, int iAmt, sqlite_int64 iOfst)
{
	VFSCryptFile *p = (VFSCryptFile *)pFile;
	
	SMSQLiteCryptoVFSSetFileCryptoError(SMCryptoFileErrorNo);

	// Check file.
	if (p->file == NULL)
	{
		sqlite3_log(SQLITE_INTERNAL, "VFS error (VFSCryptWrite): NULL file");
		return SQLITE_INTERNAL;
	}
	
	SMCryptoFileError error;
	
	// Seek.
	if (SMCryptoFileSeek(p->file, iOfst, SEEK_SET, &error) == false)
	{
		SMSQLiteCryptoVFSSetFileCryptoError(error);
		sqlite3_log(SQLITE_IOERR_SEEK, "Crypto file error (SMCryptoFileSeek / VFSCryptWrite) - error %d", error);
		return SQLITE_IOERR_SEEK;
	}
	
	// Write.
	if (SMCryptoFileWrite(p->file, zBuf, iAmt, &error) == false)
	{
		SMSQLiteCryptoVFSSetFileCryptoError(error);
		sqlite3_log(SQLITE_IOERR_WRITE, "Crypto file error (SMCryptoFileWrite / VFSCryptWrite) - error %d", error);
		return SQLITE_IOERR_WRITE;
	}
	
	return SQLITE_OK;
}

static int VFSCryptTruncate(sqlite3_file *pFile, sqlite_int64 size)
{
	VFSCryptFile *p = (VFSCryptFile *)pFile;
	
	SMSQLiteCryptoVFSSetFileCryptoError(SMCryptoFileErrorNo);

	// Check file.
	if (p->file == NULL)
	{
		sqlite3_log(SQLITE_INTERNAL, "VFS error (VFSCryptTruncate): NULL file");
		return SQLITE_INTERNAL;
	}
	
	// Truncate.
	SMCryptoFileError error;

	if  (SMCryptoFileTruncate(p->file, size, &error) == false)
	{
		SMSQLiteCryptoVFSSetFileCryptoError(error);
		sqlite3_log(SQLITE_IOERR_TRUNCATE, "Crypto file error (SMCryptoFileTruncate / VFSCryptTruncate) - error %d", error);
		return SQLITE_IOERR_TRUNCATE;
	}
	
	return SQLITE_OK;
}

static int VFSCryptSync(sqlite3_file *pFile, int flags)
{
	VFSCryptFile *p = (VFSCryptFile *)pFile;
	
	SMSQLiteCryptoVFSSetFileCryptoError(SMCryptoFileErrorNo);

	// Check file.
	if (p->file == NULL)
	{
		sqlite3_log(SQLITE_INTERNAL, "VFS error (VFSCryptSync): NULL file");
		return SQLITE_INTERNAL;
	}
	
	// Handle flags.
	SMCryptoFileSyncType syncType = SMCryptoFileSyncNormal;

	if ((flags & SQLITE_SYNC_FULL) == SQLITE_SYNC_FULL)
		syncType = SMCryptoFileSyncFull;
	
	// Sync.
	SMCryptoFileError error;

	if (SMCryptoFileFlush(p->file, syncType, &error) == false)
	{
		SMSQLiteCryptoVFSSetFileCryptoError(error);
		sqlite3_log(SQLITE_IOERR_TRUNCATE, "Crypto file error (SMCryptoFileFlush / VFSCryptSync) - error %d", error);
		return SQLITE_IOERR_FSYNC;
	}

	return SQLITE_OK;
}

static int VFSCryptFileSize(sqlite3_file *pFile, sqlite_int64 *pSize)
{
	VFSCryptFile *p = (VFSCryptFile *)pFile;
	
	SMSQLiteCryptoVFSSetFileCryptoError(SMCryptoFileErrorNo);

	// Check file.
	if (p->file == NULL)
	{
		sqlite3_log(SQLITE_INTERNAL, "VFS error (VFSCryptFileSize): NULL file");
		return SQLITE_INTERNAL;
	}
	
	*pSize = SMCryptoFileSize(p->file);
	
	return SQLITE_OK;
}

static int VFSCryptLock(sqlite3_file *pFile, int eLock)
{
	return SQLITE_OK;
}

static int VFSCryptUnlock(sqlite3_file *pFile, int eLock)
{
	return SQLITE_OK;
}

static int VFSCryptCheckReservedLock(sqlite3_file *pFile, int *pResOut)
{
	*pResOut = 0;
	
	return SQLITE_OK;
}

static int VFSCryptFileControl(sqlite3_file *pFile, int op, void *pArg)
{
	return SQLITE_NOTFOUND;
}

static int VFSCryptSectorSize(sqlite3_file *pFile)
{
	return 512;
}

static int VFSCryptDeviceCharacteristics(sqlite3_file *pFile)
{
	return SQLITE_IOCAP_POWERSAFE_OVERWRITE;
}



