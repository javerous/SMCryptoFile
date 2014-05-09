/*
 * SMCryptoFileHandle.h
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


#import <Foundation/Foundation.h>

#import "SMCryptoFile.h"


/*
** Constants
*/
#pragma mark - Constants

NSString * const SMCryptoFileHandleErrorDomain;



/*
** SMCryptoFileHandle
*/
#pragma mark - SMCryptoFileHandle

@interface SMCryptoFileHandle : NSObject

// -- Getting a Crypto File Handle --
+ (instancetype)cryptoFileHandleByCreatingFileAtPath:(NSString *)path password:(NSString *)password keySize:(SMCryptoFileKeySize)keySize error:(NSError **)error;
+ (instancetype)cryptoFileHandleByImpersonatingFileHandle:(SMCryptoFileHandle *)handle path:(NSString *)path error:(NSError **)error;		// Impersonate a crypto file by copying its prefix (header and datas are NOT copied). The impersonation itself is thread safe.
+ (instancetype)cryptoFileHandleByCreatingVolatileFileAtPath:(NSString *)path keySize:(SMCryptoFileKeySize)keySize error:(NSError **)error;	// Create a crypto file with a one-time random password. Usefull to have a temporary crypted cache. If path is nil, a temporary path is generated.

+ (instancetype)cryptoFileHandleByOpeningFileAtPath:(NSString *)path password:(NSString *)password readOnly:(BOOL)readOnly error:(NSError **)error;

// -- Changing a Crypto File settings --
- (BOOL)changePassword:(NSString *)newPassword error:(NSError **)error;

// -- Getting a Crypto File properties --
- (uint64_t)fileSize;

// -- Reading from a Crypto File Handle --
- (NSData *)readDataToEndOfFileAndReturnError:(NSError **)error;
- (NSData *)readDataOfLength:(NSUInteger)length error:(NSError **)error;

// -- Writing to a Crypto File Handle --
- (BOOL)writeData:(NSData *)data error:(NSError **)error;

// -- Seeking Within a Crypto File --
- (uint64_t)offsetInFile;
- (BOOL)seekToEndOfFile;
- (BOOL)seekToFileOffset:(uint64_t)fileOffset error:(NSError **)error;

// -- Operating on a Crypto File --
- (BOOL)closeFileAndReturnError:(NSError **)error;
- (BOOL)synchronizeFileAndReturnError:(NSError **)error;
- (BOOL)truncateFileAtOffset:(uint64_t)offset error:(NSError **)error;

@end
