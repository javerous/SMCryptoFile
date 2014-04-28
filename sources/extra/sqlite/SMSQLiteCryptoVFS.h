/*
 * SMSQLiteCryptoVFS.h
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
 * This VFS :
 * - Doesn't manage file locking. Locking are not-ops, like the "unix-none" vfs. Just be sure that your application is the only one accessing your base.
 * - Doesn't manage shared memory. If you want to use Write-Ahead Logging (WAL), you have to use EXCLUSIVE locking_mode.
 *
 */


#ifndef SMSQLITECRYPTOVFS_H_
# define SMSQLITECRYPTOVFS_H_

# include <sqlite3.h>

# include "SMCryptoFile.h"

// -- Properties --
const char *	SMSQLiteCryptoVFSName(); // Return this VFS name. Should be used with sqlite3_open_v2 and ATTACH.

// -- Register --
int				SMSQLiteCryptoVFSRegister(); // Register this VFS to SQLite. Should be done before any other SMSQLiteCrypto* call.

// -- Settings --
const char *	SMSQLiteCryptoVFSSettingsAdd(const char *password, SMCryptoFileKeySize keySize); // Return an uuid that you should use with "crypto-uuid" URI parameter. The uuid pointer is no valid anymore after a settings remove. keySize is ignored when opening an existing crypted base.
void			SMSQLiteCryptoVFSSettingsRemove(const char *uuid);

// -- Defaults --
void			SMSQLiteCryptoVFSDefaultsSetKeySize(SMCryptoFileKeySize keySize); // Define the key size to use when creating temporary crypted file.

// -- Tools --
bool			SMSQLiteCryptoVFSChangePassword(sqlite3 *cryptedBase, const char *newPassword, SMCryptoFileError *error); // Change the password of the crypted file currently in use by the cryptedBase.

// -- Errors --
SMCryptoFileError SMSQLiteCryptoVFSLastFileCryptoError(void); // Return last SMCryptoFile error.

#endif
