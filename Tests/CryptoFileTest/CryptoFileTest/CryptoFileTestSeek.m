/*
 * CryptoFileTestSeek.m
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
** CryptoFileTestSeek - Interface
*/
#pragma mark - CryptoFileTestSeek - Interface

@interface CryptoFileTestSeek : XCTestCase
{
	NSString		*_path;
	SMCryptoFile	*_file;
}

@end



/*
** CryptoFileTestSeek
*/
#pragma mark - CryptoFileTestSeek

@implementation CryptoFileTestSeek


/*
** CryptoFileTestSeek - XCTestCase
*/
#pragma mark - CryptoFileTestSeek - XCTestCase

- (void)setUp
{
    [super setUp];
	
	// Create path.
	_path = [TestHelper generateTempPath];
	
	// Create a file.
	SMCryptoFileError error;

	_file = SMCryptoFileCreate([_path UTF8String], "azerty", SMCryptoFileKeySize256, &error);
	
	if (!_file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		return;
	}
	
	// Truncate.
	if (SMCryptoFileTruncate(_file, 50, &error) == false)
	{
		XCTFail(@"Can't truncate to 50 (%@)", [TestHelper stringWithError:error]);
		return;
	}
}

- (void)tearDown
{
	if (_file)
	{
		SMCryptoFileClose(_file, NULL);
		_file = NULL;
	}
	
	if (_path)
	{
		unlink([_path UTF8String]);
		_path = nil;
	}
	
	[super tearDown];
}



/*
** CryptoFileTestSeek - Tests
*/
#pragma mark - CryptoFileTestSeek - Tests

#pragma mark Arguments

- (void)testSeek_BadArgumentFile
{
	SMCryptoFileError error;
	
	// Seek end.
	if (SMCryptoFileSeek(NULL, 0, SEEK_SET, &error) == true)
		XCTFail(@"Can seek in a NULL file");
	else if (error != SMCryptoFileErrorArguments)
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
}

- (void)testSeek_BadArgumentWhence
{
	SMCryptoFileError error;
	
	// Seek end.
	if (SMCryptoFileSeek(_file, 0, -1, &error) == true)
		XCTFail(@"Can seek with a bad whence");
	else if (error != SMCryptoFileErrorArguments)
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
}


#pragma mark Operations

- (void)testSeek_SeekSet
{
	SMCryptoFileError error;
	
	// Seek set.
	if (SMCryptoFileSeek(_file, 20, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek to 20 (%@)", [TestHelper stringWithError:error]);
		return;
	}
	
	// Check offset.
	if (SMCryptoFileTell(_file) != 20)
	{
		XCTFail(@"Current file offset is not 20");
		return;
	}
}

- (void)testSeek_SeekCurrent
{
	SMCryptoFileError error;
	
	// Init offset.
	if (SMCryptoFileSeek(_file, 20, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek to 20 (%@)", [TestHelper stringWithError:error]);
		return;
	}
	
	// Seek current.
	if (SMCryptoFileSeek(_file, 20, SEEK_CUR, &error) == false)
	{
		XCTFail(@"Can't seek to +20 (%@)", [TestHelper stringWithError:error]);
		return;
	}
	
	// Check offset.
	if (SMCryptoFileTell(_file) != 40)
	{
		XCTFail(@"Current file offset is not 40");
		return;
	}
	
	// Seek current.
	if (SMCryptoFileSeek(_file, -30, SEEK_CUR, &error) == false)
	{
		XCTFail(@"Can't seek to -30 (%@)", [TestHelper stringWithError:error]);
		return;
	}
	
	// Check offset.
	if (SMCryptoFileTell(_file) != 10)
	{
		XCTFail(@"Current file offset is not 10");
		return;
	}
	
	// Seek current (bad).
	if (SMCryptoFileSeek(_file, -50, SEEK_CUR, &error) == true)
	{
		XCTFail(@"Can seek to -50");
		return;
	}
	
	// Seek current (ok)
	if (SMCryptoFileSeek(_file, -10, SEEK_CUR, &error) == false)
	{
		XCTFail(@"Can't seek to -10 (%@)", [TestHelper stringWithError:error]);
		return;
	}
	
	// Check offset.
	if (SMCryptoFileTell(_file) != 0)
	{
		XCTFail(@"Current file offset is not 0");
		return;
	}
}

- (void)testSeek_SeekEnd
{
	SMCryptoFileError error;
	
	// Seek end.
	if (SMCryptoFileSeek(_file, 0, SEEK_END, &error) == false)
	{
		XCTFail(@"Can't seek to end 0 (%@)", [TestHelper stringWithError:error]);
		return;
	}
	
	// Check offset.
	if (SMCryptoFileTell(_file) != 50)
	{
		XCTFail(@"Current file offset is not 50");
		return;
	}
	
	// Seek end.
	if (SMCryptoFileSeek(_file, 10, SEEK_END, &error) == false)
	{
		XCTFail(@"Can't seek to end 10 (%@)", [TestHelper stringWithError:error]);
		return;
	}
	
	// Check offset.
	if (SMCryptoFileTell(_file) != 60)
	{
		XCTFail(@"Current file offset is not 60");
		return;
	}
	
	// Seek end (bad).
	if (SMCryptoFileSeek(_file, -100, SEEK_END, &error) == true)
	{
		XCTFail(@"Can seek to end -100");
		return;
	}
	
	// Seek end (ok).
	if (SMCryptoFileSeek(_file, -50, SEEK_END, &error) == false)
	{
		XCTFail(@"Can't seek to end -50 (%@)", [TestHelper stringWithError:error]);
		return;
	}
	
	// Check offset.
	if (SMCryptoFileTell(_file) != 0)
	{
		XCTFail(@"Current file offset is not 0");
		return;
	}
}

@end
