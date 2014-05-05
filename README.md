SMCryptoFile
============

This project is split in three parts: 
- SMCryptoFile (the core code)
- SMCryptoFileHandle (a wrapper for Objective-C)
- SMSQLiteCryptoVFS (a VFS for SQLite)

The sources are currently not encapsulated inside a library: simply include the sources in your project. You can find a lot of examples on how to use these APIs in the unit tests projects. 

The sources are available under Apache v2 license.


## SMCryptoFile ##

**Sources**  
*/sources/SMCryptoFile.h*  
*/sources/SMCryptoFile.c*  
*/tests/CryptoFileTest/*

**About**  
SMCryptoFile is the core of the project. It allows you to randomly read/write an encrypted file.

Use standard and robust encryption algorithms:
- Header is encrypted with AES-CBC with 128 / 192 / 256 keys. The encryption key is derived and salted from the user password with PBKDF2 (calibrated for a 100 ms delay) using HMac - SHA256 pseudo-random algorithm.
- Data is encrypted with AES-XTS with 128 / 192 / 256 keys. The encryption key is generated randomly and stored in an encrypted header.

Crypto work is done with the OS X/iOS CommonCrypto fast system library.

Support standard file operations:
- Create/Open.
- Seek.
- Read/Write (cached to limit syscall).
- Flush.
- Truncate.

Plus some specific operations:
- Fast password change (header re-encryption with the new derived key).
- Impersonated file: create new files by copying the crypto material from another unlocked file, to use the same password. As there is no password derivation, the creation is fast.
- Volatile file: create a new file with random key, for a one-time usage (for temporary cache, by example). As there is no password derivation, the creation is fast. Once closed, the file can't be re-opened.

SMCryptoFile is compatible with OS X 10.7 and later and iOS 5 or later.

## SMCryptoFileHandle ##

**Sources**  
*/sources/extra/objective-c/SMCryptoFileHandle.h*  
*/sources/extra/objective-c/SMCryptoFileHandle.m*  
*/tests/CryptoFileHandleTest/*

**About**  
SMCryptoFileHandle is an Objective-C wrapper for SMCryptoFile. It adopts the broad outlines of NSFileHandle interface, but uses NSError instead of NSException.


## SMSQLiteCryptoVFS ##

**Sources**  
*/sources/extra/sqlite/SMSQLiteCryptoVFS.h*  
*/sources/extra/sqlite/SMSQLiteCryptoVFS.c*  
*/tests/CryptoSQLiteTest/*

**About**  
SMSQLiteCryptoVFS is an SQLite VFS which use SMCryptoFile as the I/O back-end.

With this VFS:
- Your database is entirely encrypted (header + data). Without the password, nobody can know that the file contains SQLite data.
- The journal and wal files are entirely encrypted with the same password as your main database (crash resistant).
- The temporary files (created when you execute "VACUMM" command by example) are encrypted with a one-time random password.
- You can change the password when your encrypted database is opened/in use.

Advantages of a VFS:
- You can continue to use your current SQLite library: no hack, no need to patch SQlite, no need to compile SQlite, no work needed to use new SQLite versions. Simply register your VFS and use it when opening/attaching a database.
- You can work with encrypted databases and standard databases at the same time without any problem.

Disadvantages of a VFS *(linked to some API imperfections from my point of view)*:
- We need to encrypt wal and journal files with the same keys as the main database, to be crash/close resilient. The problem is that when SQlite creates them, it doesn't give any strong link to the main database, nor it passes through the main database URI parameters. Because of this, when one of this files is created, we have to search the related main database by playing with file path, which is not perfect. This doesn't introduce security weakness, but can lead to use a journal/wal file encrypted with a one-time random password (so not resilient to a crash / close), specially on 8.3 naming file system (very rare on OS X / iOS). Because of this path play, you can't open the same path multiple times at the same time.
- SQLite doesn't have a strong mechanism to return custom error code from a VFS (no error range dedicated, and logs are not very practical on a deployed application). To obtain SMCryptoFile error, there is a global last error (like errno) which contains last SMCryptoFile error. This limits (but does not prohibit) multi-thread usage.

Current limitations:
- Because SMCryptoFile doesn't support concurrent access to the same file across multiple applications, file locking and shared memory are disabled on this VFS. So you have to be sure that your database is used only by your application. Note also that you will have to activate exclusive mode ("PRAGMA locking_mode=EXCLUSIVE") to use Write-Ahead Logging (WAL) mode.

A modified version of the official sqlite3 shell is provided to facilitate management of encrypted databases (dump, backup / restor to / from standard or encrypted database, etc.).
