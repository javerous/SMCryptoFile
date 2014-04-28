/*
 * CryptoFileTestTruncate.m
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


#import <XCTest/XCTest.h>

#include <sys/stat.h>

#import "SMCryptoFile.h"
#import "TestHelper.h"


/*
** CryptoFileTestTruncate - Interface
*/
#pragma mark - CryptoFileTestTruncate - Interface

@interface CryptoFileTestTruncate : XCTestCase

@end



/*
** CryptoFileTestTruncate
*/
#pragma mark - CryptoFileTestTruncate

@implementation CryptoFileTestTruncate


/*
** CryptoFileTestTruncate - Tests
*/
#pragma mark - CryptoFileTestTruncate - Tests

#pragma mark Arguments

- (void)testTruncate_BadArgumentFile
{
	SMCryptoFileError error;
	
	// Null.
	if (SMCryptoFileTruncate(NULL, 0, &error) == true)
		XCTFail(@"Can truncate a NULL file");
	else if (error != SMCryptoFileErrorArguments)
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
}

#pragma mark Operations

- (void)testTruncate_Truncate0
{
	[self doTestTruncateForSize:0];
}

- (void)testTruncate_Truncate1
{
	[self doTestTruncateForSize:1];
}

- (void)testTruncate_Truncate50
{
	[self doTestTruncateForSize:50];
}

- (void)testTruncate_Truncate500
{
	[self doTestTruncateForSize:500];
}

- (void)testTruncate_Truncate5000
{
	[self doTestTruncateForSize:5000];
}

- (void)testTruncate_Truncate10000
{
	[self doTestTruncateForSize:10000];
}

- (void)testTruncate_ReadOnly
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	const char			*pass = "azerty";

	// Create file.
	file = SMCryptoFileCreate(path, pass, SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Close and reopen.
	SMCryptoFileClose(file, NULL);
	
	file = SMCryptoFileOpen(path, pass, true, &error);
	
	if (!file)
	{
		XCTFail(@"Can't open file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Try to truncate.
	if (SMCryptoFileTruncate(file, 50, &error) == true)
	{
		XCTFail(@"Can truncate a file opened in read-only mode.");
		goto clean;
	}
	
	if (error != SMCryptoFileErrorReadOnly)
	{
		XCTFail(@"The error returned should be SMCryptoFileErrorReadOnly (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}


/*
** CryptoFileTestTruncate - Helper
*/
#pragma mark - CryptoFileTestTruncate - Helper

- (void)doTestTruncateForSize:(unsigned)fileSize
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	const char			*pass = "azerty";
		
	// Create file.
	file = SMCryptoFileCreate(path, pass, SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Truncate up the file.
	if (SMCryptoFileTruncate(file, fileSize, &error) == false)
	{
		XCTFail(@"Can't truncate to %u bytes (%@)", fileSize, [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check size.
	if (SMCryptoFileSize(file) != fileSize)
	{
		XCTFail(@"The truncate was not effective (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Close and reopen.
	SMCryptoFileClose(file, NULL);
	
	file = SMCryptoFileOpen(path, pass, false, &error);
	
	if (!file)
	{
		XCTFail(@"Can't open truncated file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Re-check size.
	if (SMCryptoFileSize(file) != fileSize)
	{
		XCTFail(@"The truncate was not effective after re-open (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Read content.
	uint8_t *buffer = alloca(fileSize);
	int64_t size;
	
	memset(buffer, 0xab, fileSize);
	
	error = SMCryptoFileErrorNo;
	size = SMCryptoFileRead(file, buffer, fileSize, &error);
	
	if (size < fileSize)
	{
		XCTFail(@"Can't read truncated bytes - size: %lld (%@)", size, [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check content.
	for (unsigned i = 0; i < fileSize; i++)
	{
		if (buffer[i] != 0)
		{
			XCTFail(@"A non-zero byte was read after truncate - offset: %u", i);
			goto clean;
		}
	}
	
	// Check concrete size.
	struct stat st1;
	
	if (stat(path, &st1) != 0)
	{
		XCTFail(@"Can't stat the file");
		goto clean;
	}
	
	if (st1.st_size < fileSize)
	{
		XCTFail(@"Size on disk not coherent after truncate");
		goto clean;
	}
	
	// Truncate down the file.
	unsigned bufferSizeHalf = fileSize / 2;

	if (SMCryptoFileTruncate(file, bufferSizeHalf, &error) == false)
	{
		XCTFail(@"Can't truncate to %u bytes (%@)", bufferSizeHalf, [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check size.
	if (SMCryptoFileSize(file) != bufferSizeHalf)
	{
		XCTFail(@"The re-truncate was not effective (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Close and re-open.
	SMCryptoFileClose(file, NULL);
	
	file = SMCryptoFileOpen(path, pass, false, &error);
	
	if (!file)
	{
		XCTFail(@"Can't open re-truncated file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Re-check size.
	if (SMCryptoFileSize(file) != bufferSizeHalf)
	{
		XCTFail(@"The re-truncate was not effective after re-open (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Re-read content.
	memset(buffer, 0xab, bufferSizeHalf);
	
	error = SMCryptoFileErrorNo;
	size = SMCryptoFileRead(file, buffer, bufferSizeHalf, &error);
	
	if (size < bufferSizeHalf)
	{
		XCTFail(@"Can't read re-truncated bytes - size: %lld (%@)", size, [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Re-check content.
	for (unsigned i = 0; i < bufferSizeHalf; i++)
	{
		if (buffer[i] != 0)
		{
			XCTFail(@"A non-zero byte was read after re-truncate - offset: %u", i);
			goto clean;
		}
	}
	
	// Re-check concrete size.
	struct stat st2;
	
	if (stat(path, &st2) != 0)
	{
		XCTFail(@"Can't re-stat the file");
		goto clean;
	}
	
	if (fileSize > 500 && st2.st_size >= st1.st_size)
	{
		XCTFail(@"Size on disk not coherent after re-truncate - oldSize: %llu; newSize: %llu", st1.st_size, st2.st_size);
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

@end
