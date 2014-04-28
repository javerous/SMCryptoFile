SMCryptoFile
============

The project contain three API : SMCryptoFile (the base code), SMCryptoFileHandle and SMSQLiteCryptoVFS.

All sources are under Apache v2 license.

You can find a lot of example on how to use this APIs in unit tests projects.

There is currently no library. You will have to include files in your project.


## SMCryptoFile ##

*/sources/SMCryptoFile.h*  
*/sources/SMCryptoFile.c*
*/tests/CryptoFileTest/*

This is the main code. This allow you to do random read / write in a crypted file.

* The encryption use AES-XTS with 128 / 192 / 256 keys.
* The header key is derived from the user password with PBKDF2 calibrated for 100 ms. The crypted header contain the data encryption keys.
* Fast password change (only the header is re-encrypted, not the datas).
* File truncation is supported.
* You can create impersonated files (by copying crypto material of another unlocked crypto file) and volatile files (one-time file using a random key).
* The read / write are buffered to speed up operations by limiting syscall.
* Use OS X / iOS CommonCrypto fast system library.

Compatible OS X 10.7.0 minimum and iOS 5.0 minimum.

## SMCryptoFileHandle ##

*/sources/extra/objective-c/SMCryptoFileHandle.h*  
*/sources/extra/objective-c/SMCryptoFileHandle.m*
*/tests/CryptoFileHandleTest/*

This is an Objective-C wrapper for SMCryptoFile. It adopt the broad outlines of NSFileHandle interface.


## SMSQLiteCryptoVFS ##

*/sources/extra/sqlite/SMSQLiteCryptoVFS.h*  
*/sources/extra/sqlite/SMSQLiteCryptoVFS.c*
*/tests/CryptoSQLiteTest/*

This is an SQLite VFS using SMCryptoFile as I/O back-end.

By using this VFS :

* Your base is entirely crypted (header + data). Without password, impossible to know that a file contain SQlite datas.
* The journal and wal files are entirely crypted with the same password than your main database.
* The temporary files (created when you execute "VACUMM" command by example) are crypted with a one-time random password.
* You can change the password when your crypted database is opened / in use.

**Advantage of a VFS :**

* You can continue to use your current SQLite library : no hack, no need to patch SQlite, no need to compile SQlite, no new work on new versions. Simply register your VFS and use it at open / attach.  
* You can work without problem with crypted database / clear database at the same time.

**Disadvantage of a VFS** *(linked to some API inperfections from my point of view)* :

* SQlite doesn't permit us to find the main file related to a wal / journal file, and doesn't pass through URI parameters. So to crypt this files, we have to search the related main base, which is not perfect. This doesn't introduce security weakness, but can lead to use a journal / wal file crypted with a one-time random password (so not resiliant to a close / crash), specially on 8.3 naming file system (very rare on OS X / iOS). To workaround this limitation, path are You can't open the same path multiple time at the same time, because path are used to bypass this VFS limitation.
* SQLite doesn't give us strong mechanisme to return custom error code (no error range dedicated to VFS, and logs are not very practical on a deployed application). To obtain SMCryptoFile error, there is a global last error which contain last SMCryptoFile error, limiting (but not prohibiting) multi-thread usage.

**Current limitations :**

* Because SMCryptoFile doesn't support concurent access to the same file accroch multiple applications, file locking and shared memory are disabled. So you have to be sure that your base is used only by your application, and you will have to activate exclusive mode ("PRAGMA locking_mode=EXCLUSIVE") to use Write-Ahead Logging (WAL) mode.

A modified version of the official sqlite3 shell is provided to facilitate management of crypted bases (dump, backup / restor to / from clear or crypted base, etc.). Simply build it by calling "build.sh"
