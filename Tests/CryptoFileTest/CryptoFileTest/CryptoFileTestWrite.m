/*
 * CryptoFileTestWrite.m
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
** CryptoFileTestWrite - Interface
*/
#pragma mark - CryptoFileTestWrite - Interface

@interface CryptoFileTestWrite : XCTestCase

@end



/*
** CryptoFileTestWrite
*/
#pragma mark - CryptoFileTestWrite

@implementation CryptoFileTestWrite


/*
** CryptoFileTestWrite - Tests
*/
#pragma mark - CryptoFileTestWrite - Tests

#pragma mark Arguments

- (void)testWrite_BadArgumentFile
{
	SMCryptoFileError error;
	
	// Null.
	uint8_t buffer[10];
	
	memset(buffer, 0xad, sizeof(buffer));
	
	if (SMCryptoFileWrite(NULL, buffer, sizeof(buffer), &error) == true)
		XCTFail(@"Can write a NULL file");
	else if (error != SMCryptoFileErrorArguments)
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
}

- (void)testWrite_BadArgumentBuffer
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
	
	// Write.
	if (SMCryptoFileWrite(file, NULL, 0, &error) == true)
		XCTFail(@"Can write to a NULL buffer");
	else if (error != SMCryptoFileErrorArguments)
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}


#pragma mark Reopen

- (void)testWrite_Reopen_FileSize10_ChunkSize1
{
	[self doTestWriteForFileSize:10 chunkSize:1 reopen:YES];
}

- (void)testWrite_Reopen_FileSize10_ChunkSize10
{
	[self doTestWriteForFileSize:10 chunkSize:10 reopen:YES];
}

- (void)testWrite_Reopen_FileSize100_ChunkSize1
{
	[self doTestWriteForFileSize:100 chunkSize:1 reopen:YES];
}

- (void)testWrite_Reopen_FileSize100_ChunkSize10
{
	[self doTestWriteForFileSize:100 chunkSize:10 reopen:YES];
}

- (void)testWrite_Reopen_FileSize100_ChunkSize100
{
	[self doTestWriteForFileSize:100 chunkSize:100 reopen:YES];
}

- (void)testWrite_Reopen_FileSize10000_ChunkSize1
{
	[self doTestWriteForFileSize:10000 chunkSize:1 reopen:YES];
}

- (void)testWrite_Reopen_FileSize10000_ChunkSize10
{
	[self doTestWriteForFileSize:10000 chunkSize:10 reopen:YES];
}

- (void)testWrite_Reopen_FileSize10000_ChunkSize5000
{
	[self doTestWriteForFileSize:10000 chunkSize:5000 reopen:YES];
}

- (void)testWrite_Reopen_FileSize10000_ChunkSize10000
{
	[self doTestWriteForFileSize:10000 chunkSize:10000 reopen:YES];
}


#pragma mark Seek

- (void)testWrite_Seek_FileSize10_ChunkSize1
{
	[self doTestWriteForFileSize:10 chunkSize:1 reopen:NO];
}

- (void)testWrite_Seek_FileSize10_ChunkSize10
{
	[self doTestWriteForFileSize:10 chunkSize:10 reopen:NO];
}

- (void)testWrite_Seek_FileSize100_ChunkSize1
{
	[self doTestWriteForFileSize:100 chunkSize:1 reopen:NO];
}

- (void)testWrite_Seek_FileSize100_ChunkSize10
{
	[self doTestWriteForFileSize:100 chunkSize:10 reopen:NO];
}

- (void)testWrite_Seek_FileSize100_ChunkSize100
{
	[self doTestWriteForFileSize:100 chunkSize:100 reopen:NO];
}

- (void)testWrite_Seek_FileSize10000_ChunkSize1
{
	[self doTestWriteForFileSize:10000 chunkSize:1 reopen:NO];
}

- (void)testWrite_Seek_FileSize10000_ChunkSize10
{
	[self doTestWriteForFileSize:10000 chunkSize:10 reopen:NO];
}

- (void)testWrite_Seek_FileSize10000_ChunkSize5000
{
	[self doTestWriteForFileSize:10000 chunkSize:5000 reopen:NO];
}

- (void)testWrite_Seek_FileSize10000_ChunkSize10000
{
	[self doTestWriteForFileSize:10000 chunkSize:10000 reopen:NO];
}


#pragma mark Others

- (void)testWrite_ReadOnly
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
	
	// Re-open with read-only mode.
	SMCryptoFileClose(file, NULL);
	
	file = SMCryptoFileOpen(path, pass, true, &error);
	
	if (!file)
	{
		XCTFail(@"Can't open file in read-only (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Try to write.
	char buffer[10];
	
	if (SMCryptoFileWrite(file, buffer, sizeof(buffer), &error) == true)
	{
		XCTFail(@"Can write on a read-only file");
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
** CryptoFileTestWrite - Helper
*/
#pragma mark - CryptoFileTestWrite - Helper

- (void)doTestWriteForFileSize:(unsigned)fileSize chunkSize:(unsigned)chunkSize reopen:(BOOL)reopen
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
	unsigned leftSize = fileSize;
	
	chunk = [[NSMutableData alloc] initWithLength:chunkSize];
	originalData = [[NSMutableData alloc] init];
	
	while (leftSize > 0)
	{
		unsigned wsize = chunkSize;
		
		if (leftSize < wsize)
			wsize = leftSize;
		
		arc4random_buf([chunk mutableBytes], wsize);

		if (SMCryptoFileWrite(file, [chunk bytes], wsize, &error) == false)
		{
			XCTFail(@"Can't write bytes (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
		
		[originalData appendBytes:[chunk bytes] length:wsize];
		
		leftSize -= wsize;
	}
	
	if (reopen)
	{
		// Close and reopen.
		
		SMCryptoFileClose(file, NULL);
		
		file = SMCryptoFileOpen(path, pass, false, &error);
		
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
	error = SMCryptoFileErrorNo;
	readData = [[NSMutableData alloc] initWithLength:fileSize];
	
	int64_t size = SMCryptoFileRead(file, [readData mutableBytes], [readData length], &error);
	
	if (size != fileSize)
	{
		XCTFail(@"Read error (%@)", [TestHelper stringWithError:error]);
		goto clean;
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
