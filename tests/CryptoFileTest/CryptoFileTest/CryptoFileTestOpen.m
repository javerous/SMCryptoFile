/*
 * CryptoFileTestOpen.m
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
** CryptoFileTestOpen - Interface
*/
#pragma mark - CryptoFileTestOpen - Interface

@interface CryptoFileTestOpen : XCTestCase

@end



/*
** CryptoFileTestOpen
*/
#pragma mark - CryptoFileTestOpen

@implementation CryptoFileTestOpen


/*
** CryptoFileTestOpen - Tests
*/
#pragma mark - CryptoFileTestOpen - Tests

#pragma mark Arguments

- (void)testOpen_BadArgumentPath
{
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	// Null.
	file = SMCryptoFileOpen(NULL, "azerty", false, &error);
	
	if (file)
	{
		XCTFail(@"Can open a file with a NULL path");
		goto clean;
	}
	else if (error != SMCryptoFileErrorArguments)
	{
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	SMCryptoFileClose(file, NULL);
	file = NULL;
	
	// Empty.
	file = SMCryptoFileOpen("", "azerty", false, &error);
	
	if (file)
	{
		XCTFail(@"Can open a file with an empty path");
		goto clean;
	}
	else if (error != SMCryptoFileErrorArguments)
	{
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
}

- (void)testOpen_BadArgumentPassword
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	// Create temp file.
	file = SMCryptoFileCreate(path, "azerty", SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	SMCryptoFileClose(file, NULL);
	file = NULL;
	
	// Null.
	file = SMCryptoFileOpen(path, NULL, false, &error);
	
	if (file)
	{
		XCTFail(@"Can open a file with a NULL password");
		goto clean;
	}
	else if (error != SMCryptoFileErrorArguments)
	{
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	SMCryptoFileClose(file, NULL);
	file = NULL;
	
	// Empty.
	file = SMCryptoFileOpen(path, "", false, &error);
	
	if (file)
	{
		XCTFail(@"Can open a file with an empty path");
		goto clean;
	}
	else if (error != SMCryptoFileErrorArguments)
	{
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}


#pragma mark Operations

- (void)testOpen_ReadOnly
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file;
	
	const char			*pass = "azerty";
	
	// Create a file.
	file = SMCryptoFileCreate(path, pass, SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	SMCryptoFileClose(file, NULL);
	file = NULL;
	
	// Open the file.
	file = SMCryptoFileOpen(path, pass, true, &error);
	
	if (!file)
	{
		XCTFail(@"Can't open file in read-only (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

- (void)testOpen_ReadWrite
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file;
	
	const char			*pass = "azerty";
	
	// Create a file.
	file = SMCryptoFileCreate(path, pass, SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	SMCryptoFileClose(file, NULL);
	file = NULL;
	
	// Open the file.
	file = SMCryptoFileOpen(path, pass, false, &error);
	
	if (!file)
	{
		XCTFail(@"Can't open file in read-write (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

- (void)testOpen_BadPassword
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file;
	
	const char			*pass = "azerty";
	const char			*wpass = "poifsdi";

	// Create a file.
	file = SMCryptoFileCreate(path, pass, SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	SMCryptoFileClose(file, NULL);
	file = NULL;
	
	// Open the file.
	file = SMCryptoFileOpen(path, wpass, false, &error);
	
	if (file)
	{
		XCTFail(@"Can open a file with bad password (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	if (error != SMCryptoFileErrorPassword)
	{
		XCTFail(@"The error returned should be SMCryptoFileErrorPassword (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

- (void)testOpen_BadFormat
{
	// Generate temp path.
	const char *path = [[TestHelper generateTempPath] UTF8String];
	
	if (!path)
	{
		XCTFail(@"Can't generate a temporary path.");
		goto clean;
	}
	
	// Create a random file.
	FILE *rfile = fopen(path, "w+");
	
	if (!rfile)
	{
		XCTFail(@"Can't create a bad file.");
		goto clean;
	}
	
	// Write bytes.
	uint8_t buffer[500];
	
	memset(buffer, 0xed, sizeof(buffer));
	
	if (fwrite(buffer, sizeof(buffer), 1, rfile) != 1)
	{
		XCTFail(@"Can't create a random file.");
		goto clean;
	}
	
	fclose(rfile);
	rfile = NULL;
	
	// Test open.
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	file = SMCryptoFileOpen(path, "azerty", false, &error);
	
	if (file)
	{
		XCTFail(@"Bad file format can be opened.");
		goto clean;
	}
	
	if (error != SMCryptoFileErrorFormat)
	{
		XCTFail(@"The error returned should be SMCryptoFileErrorFormat (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	if (rfile) fclose(rfile);
	SMCryptoFileClose(file, NULL);
	if (path) unlink(path);
}



@end
