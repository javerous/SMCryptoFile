/*
 * CryptoFileHandleTest.m
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
 * Note: we do there only trivial tests around the objective-c wrapper. The core exhaustive tests cases are done in CryptoFileTest.
 */


#import <XCTest/XCTest.h>

#import "SMCryptoFileHandle.h"
#import "TestHelper.h"


/*
** CryptoFileHandleTest - Interface
*/
#pragma mark - CryptoFileHandleTest - Interface

@interface CryptoFileHandleTest : XCTestCase

@end



/*
** CryptoFileHandleTest
*/
#pragma mark - CryptoFileHandleTest

@implementation CryptoFileHandleTest

- (void)testGeneralAPI
{
	NSString	*cryptoPath = [TestHelper generateTempPath];
	NSString	*stdPath = [TestHelper generateTempPath];
	
	NSString	*password1 = @"azerty";
	NSString	*password2 = @"qwerty";

	NSError		*error;
	
	SMCryptoFileHandle	*cryptoHandle = nil;
	NSFileHandle		*stdHandle = nil;

	// Install cleaner.
	TestCleaner *cleaner = [[TestCleaner alloc] init];
	
	[cleaner postponeBlock:^{
		
		[cryptoHandle closeFileAndReturnError:nil];
		[stdHandle closeFile];
		
		[[NSFileManager defaultManager] removeItemAtPath:cryptoPath error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:stdPath error:nil];
	}];
	
	// Create crypto file.
	cryptoHandle = [SMCryptoFileHandle cryptoFileHandleByCreatingFileAtPath:cryptoPath password:password1 keySize:SMCryptoFileKeySize128 error:&error];
	
	if (!cryptoHandle)
	{
		XCTFail(@"Can't create a crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// Create standard file.
	[[NSFileManager defaultManager] createFileAtPath:stdPath contents:[NSData data] attributes:nil];
	
	stdHandle = [NSFileHandle fileHandleForUpdatingAtPath:stdPath];
	
	if (!stdHandle)
	{
		XCTFail(@"Can't create a standard file handle");
		return;
	}
	
	// Generate data.
	NSMutableData *randomData = [[NSMutableData alloc] initWithLength:10000];
	
	arc4random_buf([randomData mutableBytes], [randomData length]);
	
	// Write data to crypto file.
	if ([cryptoHandle writeData:randomData error:&error] == NO)
	{
		XCTFail(@"Can't write random data to crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// Write data to standard file.
	@try {
		[stdHandle writeData:randomData];
	}
	@catch (NSException *exception) {
		XCTFail(@"Can't write random data to standard file handle (%@)", exception);
		return;
	}
	
	// Synchronize data.
	if ([cryptoHandle synchronizeFileAndReturnError:&error] == NO)
	{
		XCTFail(@"Can't synchronize crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// Change password.
	if ([cryptoHandle changePassword:password2 error:&error] == NO)
	{
		XCTFail(@"Can't change password of crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// Close files.
	if ([cryptoHandle closeFileAndReturnError:&error] == NO)
	{
		XCTFail(@"Can't close crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	[stdHandle closeFile];
	
	// Re-open files.
	cryptoHandle = [SMCryptoFileHandle cryptoFileHandleByOpeningFileAtPath:cryptoPath password:password2 readOnly:NO error:&error];
	
	if (!cryptoHandle)
	{
		XCTFail(@"Can't re-open crypto file (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	stdHandle = [NSFileHandle fileHandleForUpdatingAtPath:stdPath];
	
	if (!stdHandle)
	{
		XCTFail(@"Can't re-open standard file");
		return;
	}
	
	// Read chunk.
	NSData *cryptoChunk;
	NSData *stdChunk;

	// > Crypto file.
	cryptoChunk = [cryptoHandle readDataOfLength:1024 error:&error];
	
	if (!cryptoChunk)
	{
		XCTFail(@"Can't read a chunk of data in crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// > Standard file.
	@try {
		stdChunk = [stdHandle readDataOfLength:1024];
	}
	@catch (NSException *exception) {
		XCTFail(@"Can't read a chunk of data in standard file handle (%@)", exception);
		return;
	}
	
	// Compare chunk.
	if ([cryptoChunk isEqualToData:stdChunk] == NO)
	{
		XCTFail(@"Chunks are not the sames");
		return;
	}
	
	// Compare offset.
	if ([cryptoHandle offsetInFile] != [stdHandle offsetInFile])
	{
		XCTFail(@"Offset are not the sames");
		return;
	}
	
	// Read rest of the file.
	// > Crypto file.
	cryptoChunk = [cryptoHandle readDataToEndOfFileAndReturnError:&error];
	
	if (!cryptoChunk)
	{
		XCTFail(@"Can't read rest of data in crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// > Standard file.
	@try {
		stdChunk = [stdHandle readDataToEndOfFile];
	}
	@catch (NSException *exception) {
		XCTFail(@"Can't read rest of data in standard file handle (%@)", exception);
		return;
	}
	
	// Compare chunk.
	if ([cryptoChunk isEqualToData:stdChunk] == NO)
	{
		XCTFail(@"Chunks are not the sames");
		return;
	}
	
	// Compare offset.
	if ([cryptoHandle offsetInFile] != [stdHandle offsetInFile])
	{
		XCTFail(@"Offset are not the sames");
		return;
	}
	
	// Compare size.
	if ([cryptoHandle fileSize] != [stdHandle offsetInFile])
	{
		XCTFail(@"Crypto file size is not coherent");
		return;
	}
	
	// Truncate lower.
	// > Crypto file.
	if ([cryptoHandle truncateFileAtOffset:3000 error:&error] == NO)
	{
		XCTFail(@"Can't truncate crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}

	// > Standard file.
	[stdHandle truncateFileAtOffset:3000];
	
	// Seek in file.
	// > Crypto file.
	if ([cryptoHandle seekToFileOffset:50 error:&error] == NO)
	{
		XCTFail(@"Can't seek in crypto file (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// > Standard file.
	[stdHandle seekToFileOffset:50];
	
	// Compare offset.
	if ([cryptoHandle offsetInFile] != [stdHandle offsetInFile])
	{
		XCTFail(@"Offset are not the sames");
		return;
	}
	
	// Read.
	// > Crypto file.
	cryptoChunk = [cryptoHandle readDataToEndOfFileAndReturnError:&error];
	
	if (!cryptoChunk)
	{
		XCTFail(@"Can't read crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// > Standard file.
	@try {
		stdChunk = [stdHandle readDataToEndOfFile];
	}
	@catch (NSException *exception) {
		XCTFail(@"Can't read standard file handle (%@)", exception);
		return;
	}
	
	// Compare chunk.
	if ([cryptoChunk isEqualToData:stdChunk] == NO)
	{
		NSLog(@"stdChunk: %@", stdChunk);
		NSLog(@"cryptoChunk: %@", cryptoChunk);
		
		XCTFail(@"Chunks are not the sames");
		return;
	}
	
	// Truncate upper.
	// > Crypto file.
	if ([cryptoHandle truncateFileAtOffset:20000 error:&error] == NO)
	{
		XCTFail(@"Can't truncate crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// > Standard file.
	[stdHandle truncateFileAtOffset:20000];
	
	// Seek in file.
	// > Crypto file.
	if ([cryptoHandle seekToFileOffset:0 error:&error] == NO)
	{
		XCTFail(@"Can't seek in crypto file (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// > Standard file.
	[stdHandle seekToFileOffset:0];
	
	// Read.
	// > Crypto file.
	cryptoChunk = [cryptoHandle readDataToEndOfFileAndReturnError:&error];
	
	if (!cryptoChunk)
	{
		XCTFail(@"Can't read crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// > Standard file.
	@try {
		stdChunk = [stdHandle readDataToEndOfFile];
	}
	@catch (NSException *exception) {
		XCTFail(@"Can't read standard file handle (%@)", exception);
		return;
	}
	
	// Compare chunk.
	if ([cryptoChunk isEqualToData:stdChunk] == NO)
	{
		XCTFail(@"Chunks are not the sames");
		return;
	}
	
	// Quick test impersonation.
	SMCryptoFileHandle	*cryptoHandleImpersonated = nil;
	NSString			*cryptoPathImpersonated = [TestHelper generateTempPath];

	[cleaner postponeBlock:^{
		[cryptoHandleImpersonated closeFileAndReturnError:nil];
		[[NSFileManager defaultManager] removeItemAtPath:cryptoPathImpersonated error:nil];
	}];
	
	cryptoHandleImpersonated = [SMCryptoFileHandle cryptoFileHandleByImpersonatingFileHandle:cryptoHandle path:cryptoPathImpersonated error:&error];

	if (!cryptoHandleImpersonated)
	{
		XCTFail(@"Can't create a crypto file handle by impersonation (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}
	
	// Quick test volatile.
	SMCryptoFileHandle	*cryptoHandleVolatile = nil;
	
	[cleaner postponeBlock:^{
		[cryptoHandleVolatile closeFileAndReturnError:nil];
	}];
	
	cryptoHandleVolatile = [SMCryptoFileHandle cryptoFileHandleByCreatingVolatileFileAtPath:nil keySize:SMCryptoFileKeySize128 error:&error];
	
	if (!cryptoHandleVolatile)
	{
		XCTFail(@"Can't create a volatile crypto file handle (%@)", [TestHelper stringWithError:(SMCryptoFileError)error.code]);
		return;
	}

	// Keep cleaner alive up there.
	[cleaner self];
}

@end
