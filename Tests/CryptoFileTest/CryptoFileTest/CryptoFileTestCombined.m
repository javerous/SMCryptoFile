/*
 * CryptoFileTestCombined.m
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

#import "SMCryptoFile.h"
#import "TestHelper.h"


/*
** CryptoFileTestCombined - Interface
*/
#pragma mark - CryptoFileTestCombined - Interface

@interface CryptoFileTestCombined : XCTestCase

@end



/*
** CryptoFileTestCombined
*/
#pragma mark - CryptoFileTestCombined

@implementation CryptoFileTestCombined


/*
** CryptoFileTestCombined - Tests
*/
#pragma mark - CryptoFileTestCombined - Tests

#pragma mark Combined gapped read / write

// -- Count = 1
- (void)testCombined_ChunkCount1_ChunkSize1_ChunkGap0
{
	[self doTestWriteReadForChunkCount:1 chunkSize:1 chunkGap:0];
}

- (void)testCombined_ChunkCount1_ChunkSize1_ChunkGap1
{
	[self doTestWriteReadForChunkCount:1 chunkSize:1 chunkGap:1];
}

- (void)testCombined_ChunkCount1_ChunkSize1_ChunkGap100
{
	[self doTestWriteReadForChunkCount:1 chunkSize:1 chunkGap:100];
}

- (void)testCombined_ChunkCount1_ChunkSize100_ChunkGap1
{
	[self doTestWriteReadForChunkCount:1 chunkSize:100 chunkGap:1];
}

// -- Count = 7
- (void)testCombined_ChunkCount7_ChunkSize150_ChunkGap35
{
	[self doTestWriteReadForChunkCount:7 chunkSize:150 chunkGap:35];
}

// -- Count = 10
- (void)testCombined_ChunkCount10_ChunkSize5000_ChunkGap7
{
	[self doTestWriteReadForChunkCount:10 chunkSize:5000 chunkGap:7];
}

// -- Count = 97
- (void)testCombined_ChunkCount97_ChunkSize3_ChunkGap51
{
	[self doTestWriteReadForChunkCount:97 chunkSize:3 chunkGap:51];
}

- (void)testCombined_ChunkCount97_ChunkSize357_ChunkGap27
{
	[self doTestWriteReadForChunkCount:97 chunkSize:357 chunkGap:27];
}

// -- Count = 100
- (void)testCombined_ChunkCount100_ChunkSize1_ChunkGap0
{
	[self doTestWriteReadForChunkCount:100 chunkSize:1 chunkGap:0];
}

- (void)testCombined_ChunkCount100_ChunkSize1_ChunkGap1
{
	[self doTestWriteReadForChunkCount:100 chunkSize:1 chunkGap:1];
}

// -- Count = 5000
- (void)testCombined_ChunkCount5000_ChunkSize1_ChunkGap0
{
	[self doTestWriteReadForChunkCount:5000 chunkSize:1 chunkGap:0];
}

- (void)testCombined_ChunkCount5000_ChunkSize357_ChunkGap27
{
	[self doTestWriteReadForChunkCount:5000 chunkSize:357 chunkGap:27];
}

// -- Count = 4000
- (void)testCombined_ChunkCount4000_ChunkSize2_ChunkGap10
{
	[self doTestWriteReadForChunkCount:4000 chunkSize:2 chunkGap:10];
}

// -- Count = 10000
- (void)testCombined_ChunkCount10000_ChunkSize1_ChunkGap11
{
	[self doTestWriteReadForChunkCount:10000 chunkSize:1 chunkGap:11];
}

- (void)testCombined_ChunkCount10000_ChunkSize249_ChunkGap43
{
	[self doTestWriteReadForChunkCount:10000 chunkSize:249 chunkGap:43];
}


#pragma mark Combined write / read

// -- Offset = 10
- (void)testCombined_Seek10_Write20_Rewind0_Read50
{
	[self doTestWriteRewindReadWithSeek:10 chunkSize:20 rewindOffset:0 readSize:50];
}

- (void)testCombined_Seek10_Write1000_Rewind0_Read30
{
	[self doTestWriteRewindReadWithSeek:10 chunkSize:1000 rewindOffset:0 readSize:30];
}

- (void)testCombined_Seek10_Write1000_Rewind0_Read3000
{
	[self doTestWriteRewindReadWithSeek:10 chunkSize:1000 rewindOffset:0 readSize:3000];
}

- (void)testCombined_Seek10_Write6000_Rewind0_Read3000
{
	[self doTestWriteRewindReadWithSeek:10 chunkSize:6000 rewindOffset:0 readSize:3000];
}

// -- Offset = 256
- (void)testCombined_Seek256_Write20_Rewind103_Read154
{
	[self doTestWriteRewindReadWithSeek:256 chunkSize:20 rewindOffset:103 readSize:154];
}

- (void)testCombined_Seek256_Write1000_Rewind255_Read30
{
	[self doTestWriteRewindReadWithSeek:256 chunkSize:1000 rewindOffset:255 readSize:30];
}

- (void)testCombined_Seek256_Write1000_Rewind253_Read1004
{
	[self doTestWriteRewindReadWithSeek:256 chunkSize:1000 rewindOffset:253 readSize:1004];
}

- (void)testCombined_Seek256_Write6000_Rewind103_Read20000
{
	[self doTestWriteRewindReadWithSeek:256 chunkSize:6000 rewindOffset:103 readSize:20000];
}


// -- Offset = 6000
- (void)testCombined_Seek6000_Write20_Rewind103_Read50
{
	[self doTestWriteRewindReadWithSeek:6000 chunkSize:20 rewindOffset:103 readSize:50];
}

- (void)testCombined_Seek6000_Write1000_Rewind5570_Read30
{
	[self doTestWriteRewindReadWithSeek:6000 chunkSize:1000 rewindOffset:5570 readSize:30];
}

- (void)testCombined_Seek6000_Write1000_Rewind5570_Read7000
{
	[self doTestWriteRewindReadWithSeek:6000 chunkSize:1000 rewindOffset:5570 readSize:7000];
}

- (void)testCombined_Seek6000_Write6000_Rewind8246_Read10000
{
	[self doTestWriteRewindReadWithSeek:6000 chunkSize:6000 rewindOffset:8246 readSize:10000];
}

// -- Offset = 10000
- (void)testCombined_Seek10000_Write20_Rewind997_Read50
{
	[self doTestWriteRewindReadWithSeek:10000 chunkSize:20 rewindOffset:9997 readSize:50];
}

- (void)testCombined_Seek10000_Write1000_Rewind10000_Read30
{
	[self doTestWriteRewindReadWithSeek:10000 chunkSize:1000 rewindOffset:10000 readSize:30];
}

- (void)testCombined_Seek10000_Write1000_Rewind10000_Read1000
{
	[self doTestWriteRewindReadWithSeek:10000 chunkSize:1000 rewindOffset:10000 readSize:1000];
}

- (void)testCombined_Seek10000_Write6000_Rewind10000_Read6001
{
	[self doTestWriteRewindReadWithSeek:10000 chunkSize:6000 rewindOffset:10000 readSize:6001];
}


#pragma mark Combined write / flush / read

- (void)testCombined_SeekNo_Write280_Flush_ReadAll
{
	[self doTestWriteFlushReadWithSeek:-1 writeSize:280];
}

- (void)testCombined_SeekNo_Write7000_Flush_ReadAll
{
	[self doTestWriteFlushReadWithSeek:-1 writeSize:7000];
}

- (void)testCombined_Seek100_Write280_Flush_ReadAll
{
	[self doTestWriteFlushReadWithSeek:100 writeSize:280];
}

- (void)testCombined_Seek5000_Write257_Flush_ReadAll
{
	[self doTestWriteFlushReadWithSeek:5000 writeSize:257];
}



#pragma mark Combined write / read / truncate

// - Mixing write / truncate lower / read
- (void)testCombined_SeekNo_Write1655_Truncate1385_ReadAll
{
	[self doTestWriteTruncateReadWithSeek:-1 writeSize:1655 truncateSize:1385];
}

- (void)testCombined_Seek4080_Write1655_Truncate1385_ReadAll
{
	[self doTestWriteTruncateReadWithSeek:4080 writeSize:1655 truncateSize:1385];
}

- (void)testCombined_SeekNo_Write1655_Truncate3000_ReadAll
{
	[self doTestWriteTruncateReadWithSeek:-1 writeSize:1655 truncateSize:3000];
}

- (void)testCombined_Seek4080_Write1655_Truncate7600_ReadAll
{
	[self doTestWriteTruncateReadWithSeek:4080 writeSize:1655 truncateSize:7600];
}

// - Mixing write / truncate lower / write upper / read
- (void)testCombined_Seek0_Write200_FlushNo_Truncate150_Seek250_Write3_FlushNo_ReadAll
{
	[self doTestWriteTruncateWriteReadWithSeek1:0 writeSize1:200 flush1:NO truncateSize:150 seek2:250 writeSize2:3 flush2:NO];
}

- (void)testCombined_Seek0_Write200_FlushYes_Truncate150_Seek250_Write3_FlushYes_ReadAll
{
	[self doTestWriteTruncateWriteReadWithSeek1:0 writeSize1:200 flush1:YES truncateSize:150 seek2:250 writeSize2:3 flush2:YES];
}

- (void)testCombined_Seek0_Write768_FlushYes_Truncate384_Seek400_Write200_FlushYes_ReadAll
{
	[self doTestWriteTruncateWriteReadWithSeek1:0 writeSize1:768 flush1:YES truncateSize:384 seek2:400 writeSize2:200 flush2:YES];
}



/*
** CryptoFileTestCombined - Helpers
*/
#pragma mark - CryptoFileTestCombined - Helpers

- (void)doTestWriteReadForChunkCount:(unsigned)chunkCount chunkSize:(unsigned)chunkSize chunkGap:(unsigned)chunkGap
{
	const char			*cryptoPath = [[TestHelper generateTempPath] UTF8String];
	const char			*stdPath = [[TestHelper generateTempPath] UTF8String];

	SMCryptoFile		*cryptoFile = NULL;
	FILE				*stdFile = NULL;

	SMCryptoFileError	error;
	const char			*pass = "azerty";
	
	// Create crypto file.
	cryptoFile = SMCryptoFileCreate(cryptoPath, pass, SMCryptoFileKeySize256, &error);
	
	if (!cryptoFile)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Create std file.
	stdFile = fopen(stdPath, "w+");
	
	if (!stdFile)
	{
		XCTFail(@"Can't create standard file (%i)", errno);
		goto clean;
	}
	
	// -- Write chunks --
	uint8_t *buffer = alloca(chunkSize);
	
	for (unsigned i = 1; i <= chunkCount; i++)
	{
		// Write chunk.
		arc4random_buf(buffer, chunkSize);

		// > Seek.
		if (SMCryptoFileSeek(cryptoFile, SMCryptoFileSize(cryptoFile) + chunkGap, SEEK_SET, &error) == false)
		{
			XCTFail(@"Can't seek in crypto file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
		
		fseek(stdFile, SMCryptoFileSize(cryptoFile) + chunkGap, SEEK_SET);
		
		// > Write.
		if (SMCryptoFileWrite(cryptoFile, buffer, chunkSize, &error) == false)
		{
			XCTFail(@"Can't write chunk in crypto file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
		
		if (fwrite(buffer, chunkSize, 1, stdFile) != 1)
		{
			XCTFail(@"Can't write chunk in standard file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
		
		// Over-write chunk.
		off_t delta = 20;
		
		if (delta > SMCryptoFileTell(cryptoFile))
			delta = SMCryptoFileTell(cryptoFile);
		
		arc4random_buf(buffer, chunkSize);

		// > Seek.
		if (SMCryptoFileSeek(cryptoFile, -delta, SEEK_CUR, &error) == false)
		{
			XCTFail(@"Can't seek in crypto file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
		
		fseek(stdFile, -delta, SEEK_CUR);

		// > Write.
		if (SMCryptoFileWrite(cryptoFile, buffer, chunkSize, &error) == false)
		{
			XCTFail(@"Can't write chunk in crypto file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
		
		if (fwrite(buffer, chunkSize, 1, stdFile) != 1)
		{
			XCTFail(@"Can't write chunk in standard file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
		
		// Compare position.
		if (SMCryptoFileTell(cryptoFile) != ftell(stdFile))
		{
			XCTFail(@"Crypto and standard file position are different - cryptoPosition: %llu; stdPosition: %ld", SMCryptoFileTell(cryptoFile), ftell(stdFile));
			goto clean;
		}
		
		// Compare size.
		fseek(stdFile, 0, SEEK_END);

		if (SMCryptoFileSize(cryptoFile) != ftell(stdFile))
		{
			XCTFail(@"Crypto and standard file size are different - cryptoSize: %llu; stdSize: %ld", SMCryptoFileSize(cryptoFile), ftell(stdFile));
			goto clean;
		}
	}
	
	// -- Read all chunks --
	size_t	readSize = chunkSize * 3;
	uint8_t *cryptoBuf = alloca(readSize);
	uint8_t *stdBuf = alloca(readSize);
	
	for (unsigned op = 1; op <= 2; op++)
	{
		SMCryptoFileSeek(cryptoFile, 0, SEEK_SET, NULL);
		fseek(stdFile, 0, SEEK_SET);
				
		while (1)
		{
			memset(cryptoBuf, 0xab, readSize);
			memset(stdBuf, 0xcd, readSize);
			
			// > Read.
			int64_t cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuf, readSize, &error);
			
			if (cryptoSize == -1)
			{
				XCTFail(@"Can't read a chunk of crypto file (%@)", [TestHelper stringWithError:error]);
				goto clean;
			}
			
			int64_t stdSize = fread(stdBuf, 1, readSize, stdFile);
			
			// > Compare size.
			if (cryptoSize != stdSize)
			{
				XCTFail(@"Read size are not the same - cryptoSize: %lld; stdSize: %lld", cryptoSize, stdSize);
				goto clean;
			}
			
			if (cryptoSize == 0)
				break;
			
			// > Compare bytes.
			if (memcmp(cryptoBuf, stdBuf, cryptoSize) != 0)
			{
				XCTFail(@"Bytes are not the same - position: %llu; size: %llu", SMCryptoFileTell(cryptoFile), SMCryptoFileSize(cryptoFile));
				goto clean;
			}
		}
		
		// Re-open file.
		SMCryptoFileClose(cryptoFile, NULL);
		
		cryptoFile = SMCryptoFileOpen(cryptoPath, pass, true, &error);
		
		if (!cryptoFile)
		{
			XCTFail(@"Can't re-open crypto file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
	}
	
	// -- Read distant chunk --
	int64_t cryptoSize;
	int64_t stdSize;
	
	// Position 1
	SMCryptoFileSeek(cryptoFile, 0, SEEK_SET, NULL);
	fseek(stdFile, 0, SEEK_SET);
	
	memset(cryptoBuf, 0xab, readSize);
	memset(stdBuf, 0xcd, readSize);
	
	// > Read.
	cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuf, readSize, &error);
	
	if (cryptoSize == -1)
	{
		XCTFail(@"Can't read a chunk of crypto file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	stdSize = fread(stdBuf, 1, readSize, stdFile);

	// > Compare size.
	if (cryptoSize != stdSize)
	{
		XCTFail(@"Read size are not the same - cryptoSize: %lld; stdSize: %lld", cryptoSize, stdSize);
		goto clean;
	}
	
	// > Compare bytes.
	if (memcmp(cryptoBuf, stdBuf, cryptoSize) != 0)
	{
		XCTFail(@"Bytes are not the same");
		goto clean;
	}
	
	fseek(stdFile, 0, SEEK_END);
	
	// Position 2
	SMCryptoFileSeek(cryptoFile, 10, SEEK_END, NULL);
	fseek(stdFile, 10, SEEK_END);

	memset(cryptoBuf, 0xab, readSize);
	memset(stdBuf, 0xcd, readSize);
	
	// > Read.
	cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuf, readSize, &error);
	
	if (cryptoSize == -1)
	{
		XCTFail(@"Can't read a chunk of crypto file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	stdSize = fread(stdBuf, 1, readSize, stdFile);
	
	// > Compare size.
	if (cryptoSize != stdSize)
	{
		XCTFail(@"Read size are not the same - cryptoSize: %lld; stdSize: %lld", cryptoSize, stdSize);
		goto clean;
	}
	
	// > Compare bytes.
	if (memcmp(cryptoBuf, stdBuf, cryptoSize) != 0)
	{
		XCTFail(@"Bytes are not the same");
		goto clean;
	}
	
	// Position 3.
	SMCryptoFileSeek(cryptoFile, SMCryptoFileSize(cryptoFile) / 2, SEEK_SET, NULL);
	fseek(stdFile, SMCryptoFileSize(cryptoFile) / 2, SEEK_SET);
	
	memset(cryptoBuf, 0xab, readSize);
	memset(stdBuf, 0xcd, readSize);
	
	// > Read.
	cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuf, readSize, &error);
	
	if (cryptoSize == -1)
	{
		XCTFail(@"Can't read a chunk of crypto file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	stdSize = fread(stdBuf, 1, readSize, stdFile);
	
	// > Compare size.
	if (cryptoSize != stdSize)
	{
		XCTFail(@"Read size are not the same - cryptoSize: %lld; stdSize: %lld", cryptoSize, stdSize);
		goto clean;
	}
	
	// > Compare bytes.
	if (memcmp(cryptoBuf, stdBuf, cryptoSize) != 0)
	{
		XCTFail(@"Bytes are not the same");
		goto clean;
	}
	
	// Position 4.
	SMCryptoFileSeek(cryptoFile, readSize, SEEK_CUR, NULL);
	fseek(stdFile, readSize, SEEK_CUR);
	
	memset(cryptoBuf, 0xab, readSize);
	memset(stdBuf, 0xcd, readSize);
	
	// > Read.
	cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuf, readSize, &error);
	
	if (cryptoSize == -1)
	{
		XCTFail(@"Can't read a chunk of crypto file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	stdSize = fread(stdBuf, 1, readSize, stdFile);
	
	// > Compare size.
	if (cryptoSize != stdSize)
	{
		XCTFail(@"Read size are not the same - cryptoSize: %lld; stdSize: %lld", cryptoSize, stdSize);
		goto clean;
	}
	
	// > Compare bytes.
	if (memcmp(cryptoBuf, stdBuf, cryptoSize) != 0)
	{
		XCTFail(@"Bytes are not the same");
		goto clean;
	}
	
clean:
	SMCryptoFileClose(cryptoFile, NULL);
	if (stdFile) fclose(stdFile);
	
	unlink(cryptoPath);
	unlink(stdPath);
}

- (void)doTestWriteRewindReadWithSeek:(unsigned)chunkOffset chunkSize:(unsigned)chunkSize rewindOffset:(unsigned)rewindOffset readSize:(unsigned)readSize
{
	const char			*cryptoPath = [[TestHelper generateTempPath] UTF8String];
	const char			*stdPath = [[TestHelper generateTempPath] UTF8String];
	
	SMCryptoFile		*cryptoFile = NULL;
	FILE				*stdFile = NULL;
	
	SMCryptoFileError	error;
	
	uint8_t				*chunkBuffer = malloc(chunkSize);
	
	uint8_t				*stdRead = malloc(readSize);
	uint8_t				*cryptoRead = malloc(readSize);
	
	
	// Create crypto file.
	cryptoFile = SMCryptoFileCreate(cryptoPath, "azerty", SMCryptoFileKeySize256, &error);
	
	if (!cryptoFile)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Create std file.
	stdFile = fopen(stdPath, "w+");
	
	if (!stdFile)
	{
		XCTFail(@"Can't create standard file (%i)", errno);
		goto clean;
	}
	
	// Seek.
	fseek(stdFile, chunkOffset, SEEK_SET);
	
	if (SMCryptoFileSeek(cryptoFile, chunkOffset, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek to offset %u (%@)", chunkOffset, [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Write.
	arc4random_buf(chunkBuffer, chunkSize);
	
	fwrite(chunkBuffer, chunkSize, 1, stdFile);
	
	if (SMCryptoFileWrite(cryptoFile, chunkBuffer, chunkSize, &error) == false)
	{
		XCTFail(@"Can't write bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Seek back.
	fseek(stdFile, rewindOffset, SEEK_SET);
	
	if (SMCryptoFileSeek(cryptoFile, rewindOffset, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Read.
	int64_t stdSize;
	int64_t cryptoSize;
	
	memset(stdRead, 0x11, readSize);
	memset(cryptoRead, 0x22, readSize);
	
	stdSize = fread(stdRead, 1, readSize, stdFile);
	cryptoSize = SMCryptoFileRead(cryptoFile, cryptoRead, readSize, &error);
	
	if (cryptoSize == -1)
	{
		XCTFail(@"Can't read bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	if (stdSize != cryptoSize)
	{
		XCTFail(@"Not at the same offset after read");
		goto clean;
	}
	
	// Compare size.
	fseek(stdFile, 0, SEEK_END);
	
	if (ftell(stdFile) != SMCryptoFileSize(cryptoFile))
	{
		XCTFail(@"Files are not the same size");
		goto clean;
	}
	
	// Compare bytes.
	if (memcmp(stdRead, cryptoRead, cryptoSize) != 0)
	{
		XCTFail(@"Bytes are not the same.");
		goto clean;
	}
	
clean:
	SMCryptoFileClose(cryptoFile, NULL);
	if (stdFile) fclose(stdFile);
	
	unlink(cryptoPath);
	unlink(stdPath);
	
	if (chunkBuffer)
		free(chunkBuffer);
	
	if (stdRead)
		free(stdRead);
	
	if (cryptoRead)
		free(cryptoRead);
}

- (void)doTestWriteFlushReadWithSeek:(int)seekOffset writeSize:(unsigned)writeSize
{
	const char			*cryptoPath = [[TestHelper generateTempPath] UTF8String];
	const char			*stdPath = [[TestHelper generateTempPath] UTF8String];
	
	SMCryptoFile		*cryptoFile = NULL;
	FILE				*stdFile = NULL;
	
	SMCryptoFileError	error;
	
	// Create crypto file.
	cryptoFile = SMCryptoFileCreate(cryptoPath, "azerty", SMCryptoFileKeySize256, &error);
	
	if (!cryptoFile)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Create std file.
	stdFile = fopen(stdPath, "w+");
	
	if (!stdFile)
	{
		XCTFail(@"Can't create standard file (%i)", errno);
		goto clean;
	}
	
	// Seek.
	if (seekOffset >= 0)
	{
		fseek(stdFile, seekOffset, SEEK_SET);
		
		if (SMCryptoFileSeek(cryptoFile, seekOffset, SEEK_SET, &error) == false)
		{
			XCTFail(@"Can't seek in file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
	}
	
	// Write.
	uint8_t *chunk = alloca(writeSize);
	
	arc4random_buf(chunk, writeSize);
	
	fwrite(chunk, writeSize, 1, stdFile);
	
	if (SMCryptoFileWrite(cryptoFile, chunk, writeSize, &error) == false)
	{
		XCTFail(@"Can't write bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Flush.
	if (SMCryptoFileFlush(cryptoFile, SMCryptoFileSyncNo, &error) == false)
	{
		XCTFail(@"Can't flush file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Read.
	uint8_t stdBuffer[1024];
	uint8_t cryptoBuffer[1024];
	
	int64_t stdSize;
	int64_t cryptoSize;
	
	//> Read 1.
	memset(stdBuffer, 0x11, sizeof(stdBuffer));
	memset(cryptoBuffer, 0x22, sizeof(cryptoBuffer));
	
	stdSize = fread(stdBuffer, 1, sizeof(stdBuffer), stdFile);
	cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuffer, sizeof(cryptoBuffer), &error);
	
	if (stdSize != cryptoSize)
	{
		if (cryptoSize == -1)
			XCTFail(@"Can't read the file (%@)", [TestHelper stringWithError:error]);
		else
			XCTFail(@"Can't read the same size - stdSize: %lld; cryptoSize: %lld", stdSize, cryptoSize);
		
		goto clean;
	}
	
	if (memcmp(stdBuffer, cryptoBuffer, cryptoSize) != 0)
	{
		XCTFail(@"Bytes are not the sames");
		goto clean;
	}
	
	// > Read 2.
	fseek(stdFile, 0, SEEK_SET);
	
	if (SMCryptoFileSeek(cryptoFile, 0, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek in file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	while (1)
	{
		memset(stdBuffer, 0x11, sizeof(stdBuffer));
		memset(cryptoBuffer, 0x22, sizeof(cryptoBuffer));
		
		stdSize = fread(stdBuffer, 1, sizeof(stdBuffer), stdFile);
		cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuffer, sizeof(cryptoBuffer), &error);
		
		if (stdSize != cryptoSize)
		{
			if (cryptoSize == -1)
				XCTFail(@"Can't read the file (%@)", [TestHelper stringWithError:error]);
			else
				XCTFail(@"Can't read the same size - stdSize: %lld; cryptoSize: %lld", stdSize, cryptoSize);
			
			goto clean;
		}
		
		if (cryptoSize == 0)
			break;
		
		if (memcmp(stdBuffer, cryptoBuffer, cryptoSize) != 0)
		{
			XCTFail(@"Bytes are not the sames");
			goto clean;
		}
	}
	
clean:
	SMCryptoFileClose(cryptoFile, NULL);
	if (stdFile) fclose(stdFile);
	
	unlink(cryptoPath);
	unlink(stdPath);
}

- (void)doTestWriteTruncateReadWithSeek:(int)seekOffset writeSize:(unsigned)writeSize truncateSize:(unsigned)truncateSize
{
	const char			*cryptoPath = [[TestHelper generateTempPath] UTF8String];
	const char			*stdPath = [[TestHelper generateTempPath] UTF8String];
	
	SMCryptoFile		*cryptoFile = NULL;
	FILE				*stdFile = NULL;
	
	SMCryptoFileError	error;
	
	// Create crypto file.
	cryptoFile = SMCryptoFileCreate(cryptoPath, "azerty", SMCryptoFileKeySize256, &error);
	
	if (!cryptoFile)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Create std file.
	stdFile = fopen(stdPath, "w+");
	
	if (!stdFile)
	{
		XCTFail(@"Can't create standard file (%i)", errno);
		goto clean;
	}
	
	// Seek.
	if (seekOffset >= 0)
	{
		fseek(stdFile, seekOffset, SEEK_SET);
		
		if (SMCryptoFileSeek(cryptoFile, seekOffset, SEEK_SET, &error) == false)
		{
			XCTFail(@"Can't seek in file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
	}
	
	// Write.
	uint8_t *chunk = alloca(writeSize);
	
	arc4random_buf(chunk, writeSize);
	
	fwrite(chunk, writeSize, 1, stdFile);
	
	if (SMCryptoFileWrite(cryptoFile, chunk, writeSize, &error) == false)
	{
		XCTFail(@"Can't write bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
		
	// Truncate
	// > StdFile : close, truncate, re-open.
	long stdOffset = ftell(stdFile);
	
	fclose(stdFile);
	
	truncate(stdPath, truncateSize);
	
	stdFile = fopen(stdPath, "r+");
	
	fseek(stdFile, stdOffset, SEEK_SET);
		
	// > CryptoFile.
	if (SMCryptoFileTruncate(cryptoFile, truncateSize, &error) == false)
	{
		XCTFail(@"Can't truncate to %u bytes (%@)", truncateSize, [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Flush.
	if (SMCryptoFileFlush(cryptoFile, SMCryptoFileSyncNo, &error) == false)
	{
		XCTFail(@"Can't flush the crypto file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check offset.
	if (ftell(stdFile) != SMCryptoFileTell(cryptoFile))
	{
		XCTFail(@"Files are not at the same offset - stdOffset: %ld; cryptoOffset: %llu", ftell(stdFile), SMCryptoFileTell(cryptoFile));
		goto clean;
	}
	
	// Read.
	uint8_t stdBuffer[1024];
	uint8_t cryptoBuffer[1024];
	
	int64_t stdSize;
	int64_t cryptoSize;
	
	//> Read 1.
	memset(stdBuffer, 0x11, sizeof(stdBuffer));
	memset(cryptoBuffer, 0x22, sizeof(cryptoBuffer));
	
	stdSize = fread(stdBuffer, 1, sizeof(stdBuffer), stdFile);
	cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuffer, sizeof(cryptoBuffer), &error);

	if (stdSize != cryptoSize)
	{
		if (cryptoSize == -1)
			XCTFail(@"Can't read the file (%@)", [TestHelper stringWithError:error]);
		else
			XCTFail(@"Can't read the same size - stdSize: %lld; cryptoSize: %lld", stdSize, cryptoSize);
		
		goto clean;
	}
	
	if (memcmp(stdBuffer, cryptoBuffer, cryptoSize) != 0)
	{
		XCTFail(@"Bytes are not the sames");
		goto clean;
	}
	
	// > Read 2.
	fseek(stdFile, 0, SEEK_SET);
	
	if (SMCryptoFileSeek(cryptoFile, 0, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek in file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	while (1)
	{
		memset(stdBuffer, 0x11, sizeof(stdBuffer));
		memset(cryptoBuffer, 0x22, sizeof(cryptoBuffer));
		
		stdSize = fread(stdBuffer, 1, sizeof(stdBuffer), stdFile);
		cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuffer, sizeof(cryptoBuffer), &error);
		
		if (stdSize != cryptoSize)
		{
			if (cryptoSize == -1)
				XCTFail(@"Can't read the file (%@)", [TestHelper stringWithError:error]);
			else
				XCTFail(@"Can't read the same size - stdSize: %lld; cryptoSize: %lld", stdSize, cryptoSize);
			
			goto clean;
		}
		
		if (cryptoSize == 0)
			break;
		
		if (memcmp(stdBuffer, cryptoBuffer, cryptoSize) != 0)
		{
			XCTFail(@"Bytes are not the sames");
			goto clean;
		}
	}
	
clean:
	SMCryptoFileClose(cryptoFile, NULL);
	if (stdFile) fclose(stdFile);
	
	unlink(cryptoPath);
	unlink(stdPath);
}

- (void)doTestWriteTruncateWriteReadWithSeek1:(int)seekOffset1 writeSize1:(unsigned)writeSize1 flush1:(BOOL)flush1 truncateSize:(unsigned)truncateSize seek2:(int)seekOffset2 writeSize2:(unsigned)writeSize2 flush2:(BOOL)flush2
{
	const char			*cryptoPath = [[TestHelper generateTempPath] UTF8String];
	const char			*stdPath = [[TestHelper generateTempPath] UTF8String];
	
	SMCryptoFile		*cryptoFile = NULL;
	FILE				*stdFile = NULL;
	
	SMCryptoFileError	error;
	
	// Create crypto file.
	cryptoFile = SMCryptoFileCreate(cryptoPath, "azerty", SMCryptoFileKeySize256, &error);
	
	if (!cryptoFile)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Create std file.
	stdFile = fopen(stdPath, "w+");
	
	if (!stdFile)
	{
		XCTFail(@"Can't create standard file (%i)", errno);
		goto clean;
	}
	
	// Seek 1.
	if (seekOffset1 >= 0)
	{
		fseek(stdFile, seekOffset1, SEEK_SET);
		
		if (SMCryptoFileSeek(cryptoFile, seekOffset1, SEEK_SET, &error) == false)
		{
			XCTFail(@"Can't seek in file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
	}
	
	// Write 1.
	uint8_t *chunk1 = alloca(writeSize1);
	
	arc4random_buf(chunk1, writeSize1);
	
	fwrite(chunk1, writeSize1, 1, stdFile);
	
	if (SMCryptoFileWrite(cryptoFile, chunk1, writeSize1, &error) == false)
	{
		XCTFail(@"Can't write bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	if (flush1)
	{
		if (SMCryptoFileFlush(cryptoFile, SMCryptoFileSyncNo, &error) == false)
		{
			XCTFail(@"Can't flush file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
	}
	
	// Truncate
	// > StdFile : close, truncate, re-open.
	long stdOffset = ftell(stdFile);
	
	fclose(stdFile);
	
	truncate(stdPath, truncateSize);
	
	stdFile = fopen(stdPath, "r+");
	
	fseek(stdFile, stdOffset, SEEK_SET);
	
	// > CryptoFile.
	if (SMCryptoFileTruncate(cryptoFile, truncateSize, &error) == false)
	{
		XCTFail(@"Can't truncate to %u bytes (%@)", truncateSize, [TestHelper stringWithError:error]);
		goto clean;
	}

	// Check offset 1.
	if (ftell(stdFile) != SMCryptoFileTell(cryptoFile))
	{
		XCTFail(@"Files are not at the same offset - stdOffset: %ld; cryptoOffset: %llu", ftell(stdFile), SMCryptoFileTell(cryptoFile));
		goto clean;
	}
	
	// Seek 2.
	if (seekOffset2 >= 0)
	{
		fseek(stdFile, seekOffset2, SEEK_SET);
		
		if (SMCryptoFileSeek(cryptoFile, seekOffset2, SEEK_SET, &error) == false)
		{
			XCTFail(@"Can't seek in file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
	}
	
	// Write 2.
	uint8_t *chunk2 = alloca(writeSize2);
	
	arc4random_buf(chunk2, writeSize2);
	
	fwrite(chunk2, writeSize2, 1, stdFile);
	
	if (SMCryptoFileWrite(cryptoFile, chunk2, writeSize2, &error) == false)
	{
		XCTFail(@"Can't write bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check offset 2.
	if (ftell(stdFile) != SMCryptoFileTell(cryptoFile))
	{
		XCTFail(@"Files are not at the same offset - stdOffset: %ld; cryptoOffset: %llu", ftell(stdFile), SMCryptoFileTell(cryptoFile));
		goto clean;
	}
	
	if (flush2)
	{
		if (SMCryptoFileFlush(cryptoFile, SMCryptoFileSyncNo, &error) == false)
		{
			XCTFail(@"Can't flush file (%@)", [TestHelper stringWithError:error]);
			goto clean;
		}
	}
	
	// Read.
	uint8_t stdBuffer[1024];
	uint8_t cryptoBuffer[1024];
	
	int64_t stdSize;
	int64_t cryptoSize;
	
	//> Read 1.
	memset(stdBuffer, 0x11, sizeof(stdBuffer));
	memset(cryptoBuffer, 0x22, sizeof(cryptoBuffer));
	
	stdSize = fread(stdBuffer, 1, sizeof(stdBuffer), stdFile);
	cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuffer, sizeof(cryptoBuffer), &error);
	
	if (stdSize != cryptoSize)
	{
		if (cryptoSize == -1)
			XCTFail(@"Can't read the file (%@)", [TestHelper stringWithError:error]);
		else
			XCTFail(@"Can't read the same size - stdSize: %lld; cryptoSize: %lld", stdSize, cryptoSize);
		
		goto clean;
	}
	
	if (memcmp(stdBuffer, cryptoBuffer, cryptoSize) != 0)
	{
		XCTFail(@"Bytes are not the sames");
		goto clean;
	}
	
	// > Read 2.
	fseek(stdFile, 0, SEEK_SET);
	
	if (SMCryptoFileSeek(cryptoFile, 0, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek in file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	while (1)
	{
		memset(stdBuffer, 0x11, sizeof(stdBuffer));
		memset(cryptoBuffer, 0x22, sizeof(cryptoBuffer));
		
		stdSize = fread(stdBuffer, 1, sizeof(stdBuffer), stdFile);
		cryptoSize = SMCryptoFileRead(cryptoFile, cryptoBuffer, sizeof(cryptoBuffer), &error);
		
		if (stdSize != cryptoSize)
		{
			if (cryptoSize == -1)
				XCTFail(@"Can't read the file (%@)", [TestHelper stringWithError:error]);
			else
				XCTFail(@"Can't read the same size - stdSize: %lld; cryptoSize: %lld", stdSize, cryptoSize);
			
			goto clean;
		}
		
		if (cryptoSize == 0)
			break;
		
		if (memcmp(stdBuffer, cryptoBuffer, cryptoSize) != 0)
		{
			XCTFail(@"Bytes are not the sames");
			goto clean;
		}
	}
	
clean:
	SMCryptoFileClose(cryptoFile, NULL);
	if (stdFile) fclose(stdFile);
	
	unlink(cryptoPath);
	unlink(stdPath);
}

@end
