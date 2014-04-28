/*
 * CryptoFileTestRead.m
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
** CryptoFileTestRead - Interface
*/
#pragma mark - CryptoFileTestRead - Interface

@interface CryptoFileTestRead : XCTestCase

@end



/*
** CryptoFileTestRead
*/
#pragma mark - CryptoFileTestRead

@implementation CryptoFileTestRead


/*
** CryptoFileTestRead - Tests
*/
#pragma mark - CryptoFileTestRead - Tests

#pragma mark - Arguments

- (void)testRead_BadArgumentFile
{
	SMCryptoFileError error;
	
	// Null.
	uint8_t buffer[10];
	int64_t size = SMCryptoFileRead(NULL, buffer, sizeof(buffer), &error);
	
	if (size != -1)
		XCTFail(@"Can read a NULL file");
	else if (error != SMCryptoFileErrorArguments)
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
}

- (void)testRead_BadArgumentBuffer
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	// Create file.
	file = SMCryptoFileCreate(path, "azerty", SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Read.
	int64_t size = SMCryptoFileRead(file, NULL, 0, &error);
	
	if (size != -1)
		XCTFail(@"Can read to a NULL buffer");
	else if (error != SMCryptoFileErrorArguments)
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}


#pragma mark Reopen

- (void)testRead_Reopen_FileSize10_ChunkSize1
{
	[self doTestReadForFileSize:10 chunkSize:1 reopen:YES];
}

- (void)testRead_Reopen_FileSize10C_hunkSize10
{
	[self doTestReadForFileSize:10 chunkSize:10 reopen:YES];
}

- (void)testRead_Reopen_FileSize100_ChunkSize1
{
	[self doTestReadForFileSize:100 chunkSize:1 reopen:YES];
}

- (void)testRead_Reopen_FileSize100_ChunkSize10
{
	[self doTestReadForFileSize:100 chunkSize:10 reopen:YES];
}

- (void)testRead_Reopen_FileSize100_ChunkSize100
{
	[self doTestReadForFileSize:100 chunkSize:100 reopen:YES];
}

- (void)testRead_Reopen_FileSize10000_ChunkSize1
{
	[self doTestReadForFileSize:10000 chunkSize:1 reopen:YES];
}

- (void)testRead_Reopen_FileSize10000_ChunkSize10
{
	[self doTestReadForFileSize:10000 chunkSize:10 reopen:YES];
}

- (void)testRead_Reopen_FileSize10000_ChunkSize5000
{
	[self doTestReadForFileSize:10000 chunkSize:5000 reopen:YES];
}

- (void)testRead_Reopen_FileSize10000_ChunkSize10000
{
	[self doTestReadForFileSize:10000 chunkSize:10000 reopen:YES];
}


#pragma mark Seek

- (void)testRead_Seek_FileSize10_ChunkSize1
{
	[self doTestReadForFileSize:10 chunkSize:1 reopen:NO];
}

- (void)testRead_Seek_FileSize10_ChunkSize10
{
	[self doTestReadForFileSize:10 chunkSize:10 reopen:NO];
}

- (void)testRead_Seek_FileSize100_ChunkSize1
{
	[self doTestReadForFileSize:100 chunkSize:1 reopen:NO];
}

- (void)testRead_Seek_FileSize100_ChunkSize10
{
	[self doTestReadForFileSize:100 chunkSize:10 reopen:NO];
}

- (void)testRead_Seek_FileSize100_ChunkSize100
{
	[self doTestReadForFileSize:100 chunkSize:100 reopen:NO];
}

- (void)testRead_Seek_FileSize10000_ChunkSize1
{
	[self doTestReadForFileSize:10000 chunkSize:1 reopen:NO];
}

- (void)testRead_Seek_FileSize10000_ChunkSize10
{
	[self doTestReadForFileSize:10000 chunkSize:10 reopen:NO];
}

- (void)testRead_Seek_FileSize10000_ChunkSize5000
{
	[self doTestReadForFileSize:10000 chunkSize:5000 reopen:NO];
}

- (void)testRead_Seek_FileSize10000_ChunkSize10000
{
	[self doTestReadForFileSize:10000 chunkSize:10000 reopen:NO];
}


#pragma mark End-of-File

- (void)testRead_EmptyFile_EOF
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	// Create file.
	file = SMCryptoFileCreate(path, "azerty", SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	uint8_t buffer[10];
	int64_t size;
	
	// Try to read.
	size = SMCryptoFileRead(file, buffer, sizeof(buffer), &error);
	
	if (size > 0)
	{
		XCTFail(@"Can read bytes on an empty file");
		goto clean;
	}
	else if (size < 0)
	{
		XCTFail(@"Get an error when trying to read EOF (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Seek out-of-bound.
	if (SMCryptoFileSeek(file, 50, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek");
		goto clean;
	}
	
	// Try to read.
	size = SMCryptoFileRead(file, buffer, sizeof(buffer), &error);
	
	if (size > 0)
	{
		XCTFail(@"Can read bytes on an empty file");
		goto clean;
	}
	else if (size < 0)
	{
		XCTFail(@"Get an error when trying to read EOF after seek (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

- (void)testRead_FilledFile_EOF
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	// Create file.
	file = SMCryptoFileCreate(path, "azerty", SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Truncate to 50.
	if (SMCryptoFileTruncate(file, 50, &error) == false)
	{
		XCTFail(@"Can't truncate file to 50 bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check size.
	if (SMCryptoFileSize(file) != 50)
	{
		XCTFail(@"Wrong file size after truncate.");
		goto clean;
	}
	
	// Seek to 40.
	if (SMCryptoFileSeek(file, 40, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek to offset 40 (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	uint8_t buffer[20];
	int64_t size;
	
	// Read 20.
	size = SMCryptoFileRead(file, buffer, sizeof(buffer), &error);
	
	if (size != 10)
	{
		if (size == -1)
			XCTFail(@"Error on read (%@)", [TestHelper stringWithError:error]);
		else
			XCTFail(@"Wrong read size (%lld)", size);
		
		goto clean;
	}
	
	// Read 20 again.
	size = SMCryptoFileRead(file, buffer, sizeof(buffer), &error);
	
	if (size != 0)
	{
		if (size == -1)
			XCTFail(@"Error on read (%@)", [TestHelper stringWithError:error]);
		else
			XCTFail(@"Wrong read size (%lld)", size);
		
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
	// truncate to 50, seek to 40, read 20 : size should be 10, then read 20 : should be EOF
}



/*
** CryptoFileTestRead - Helper
*/
#pragma mark - CryptoFileTestRead - Helper

- (void)doTestReadForFileSize:(unsigned)fileSize chunkSize:(unsigned)chunkSize reopen:(BOOL)reopen
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	const char			*pass = "azerty";
	
	NSMutableData		*originalData;
	NSMutableData		*readData;
	NSMutableData		*chunk;
	
	// Create file.
	file = SMCryptoFileCreate(path, pass, SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Write.
	originalData = [[NSMutableData alloc] initWithLength:fileSize];
	
	arc4random_buf([originalData mutableBytes], [originalData length]);
	
	if (SMCryptoFileWrite(file, [originalData bytes], [originalData length], &error) == false)
	{
		XCTFail(@"Can't write bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	if (reopen)
	{
		// Close and reopen.
		
		SMCryptoFileClose(file, NULL);
		
		file = SMCryptoFileOpen(path, pass, true, &error);
		
		if (!file)
		{
			XCTFail(@"Can't re-open file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
	}
	else
	{
		// Seek.
		
		if (SMCryptoFileSeek(file, 0, SEEK_SET, &error) == false)
		{
			XCTFail(@"Can't seek (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
	}
	
	// Check size.
	if (SMCryptoFileSize(file) != fileSize)
	{
		XCTFail(@"Wrong file size - currentSize: %llu, wantedSize: %u", SMCryptoFileSize(file), fileSize);
		goto clean;
	}
	
	// Read.
	readData = [[NSMutableData alloc] init];
	chunk = [[NSMutableData alloc] initWithLength:chunkSize];
	
	while (1)
	{
		int64_t size = SMCryptoFileRead(file, [chunk mutableBytes], [chunk length], &error);
		
		if (size <= 0)
		{
			if (size == -1)
			{
				XCTFail(@"Read error (%@)", [TestHelper stringWithError:error]);
				goto clean;
			}
			
			break;
		}
		
		[readData appendData:chunk];
	}
	
	// Compare.
	if ([originalData isEqualToData:readData] == NO)
	{
		XCTFail(@"Write and read data are not the same.");
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

@end
