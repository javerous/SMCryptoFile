/*
 * CryptoFileTestCreate.m
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
** CryptoFileTestCreate - Interface
*/
#pragma mark - CryptoFileTestCreate - Interface

@interface CryptoFileTestCreate : XCTestCase

@end



/*
** CryptoFileTestCreate
*/
#pragma mark - CryptoFileTestCreate

@implementation CryptoFileTestCreate


/*
** CryptoFileTestCreate - Tests
*/
#pragma mark - CryptoFileTestCreate - Tests

#pragma mark Arguments

- (void)testCreate_BadArgumentPath
{
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	// Null.
	file = SMCryptoFileCreate(NULL, "azerty", SMCryptoFileKeySize256, &error);
	
	if (file)
	{
		XCTFail(@"Can create a file with a NULL path");
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
	file = SMCryptoFileCreate("", "azerty", SMCryptoFileKeySize256, &error);
	
	if (file)
	{
		XCTFail(@"Can create a file with an empty path");
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

- (void)testCreate_BadArgumentPassword
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	// Null.
	file = SMCryptoFileCreate(path, NULL, SMCryptoFileKeySize256, &error);
	
	if (file)
	{
		XCTFail(@"Can create a file with a NULL password");
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
	file = SMCryptoFileCreate(path, "", SMCryptoFileKeySize256, &error);
	
	if (file)
	{
		XCTFail(@"Can create a file with an empty path");
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

- (void)testCreate_BadArgumentKeySize
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	file = SMCryptoFileCreate(path, "azerty", -1, &error);
	
	if (file)
	{
		XCTFail(@"Can create a file with a bad keysize");
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

- (void)testCreate_AES128
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file;
	
	// Create file.
	file = SMCryptoFileCreate(path, "mlkezldkqs654qs8", SMCryptoFileKeySize128, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 128 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check that the file exist.
	if (access(path, F_OK) != 0)
	{
		XCTFail(@"File doesn't exist at path");
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

- (void)testCreate_AES192
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file;
	
	// Create file.
	file = SMCryptoFileCreate(path, "mlkezldkqs654qs8", SMCryptoFileKeySize192, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 192 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check that the file exist.
	if (access(path, F_OK) != 0)
	{
		XCTFail(@"File doesn't exist at path");
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

- (void)testCreate_AES256
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	// Create file.
	file = SMCryptoFileCreate(path, "mlkezldkqs654qs8", SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check that the file exist.
	if (access(path, F_OK) != 0)
	{
		XCTFail(@"File doesn't exist at path");
		goto clean;
	}

clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

- (void)testCreate_Impersonated
{
	const char			*password = "mlkezldkqs654qs8";
	SMCryptoFileError	error;

	// Create standard crypto file.
	const char		*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFile	*file = SMCryptoFileCreate(path, password, SMCryptoFileKeySize128, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 128 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Impersonate this file.
	const char		*npath = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFile	*nfile = SMCryptoFileCreateImpersonated(file, npath, &error);
	
	if (!nfile)
	{
		XCTFail(@"Can't create impersonated file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Close files.
	// > Standard file.
	if (SMCryptoFileClose(file, &error) == false)
	{
		XCTFail(@"Can't close standard file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	file = NULL;
	
	// > Impersonated file.
	if (SMCryptoFileClose(nfile, &error) == false)
	{
		XCTFail(@"Can't close standard file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	nfile = NULL;
	
	// Re-open impersonated file with standard file password.
	nfile = SMCryptoFileOpen(npath, password, false, &error);
	
	if (!nfile)
	{
		XCTFail(@"Can't open impersonated file with standard file password (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
		
clean:
	SMCryptoFileClose(file, NULL);
	SMCryptoFileClose(nfile, NULL);

	unlink(path);
	unlink(npath);
}

- (void)testCreate_VolatileNoPath
{
	SMCryptoFileError	error;
	SMCryptoFile		*file;
	
	// Create file.
	file = SMCryptoFileCreateVolatile(NULL, SMCryptoFileKeySize128, &error);

	if (!file)
	{
		XCTFail(@"Can't create volatile file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Write 1.
	uint8_t buffer1[700];
	
	arc4random_buf(buffer1, sizeof(buffer1));
	
	if (SMCryptoFileWrite(file, buffer1, sizeof(buffer1), &error) == false)
	{
		XCTFail(@"Can't write bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Seek.
	if (SMCryptoFileSeek(file, 10000, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek in file(%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Write 2.
	uint8_t buffer2[700];
	
	arc4random_buf(buffer2, sizeof(buffer2));
	
	if (SMCryptoFileWrite(file, buffer2, sizeof(buffer2), &error) == false)
	{
		XCTFail(@"Can't write bytes (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Seek.
	if (SMCryptoFileSeek(file, 0, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek in file(%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	uint8_t	bfread[700];
	int64_t	size;
	
	// Read 1.
	memset(bfread, 0x11, sizeof(bfread));
	
	size = SMCryptoFileRead(file, bfread, sizeof(bfread), &error);
	
	if (size != sizeof(bfread))
	{
		if (size == -1)
			XCTFail(@"Can't read bytes (%@)", [TestHelper stringWithError:error]);
		else
			XCTFail(@"No enough bytes to read");

		goto clean;
	}
	
	// Compare.
	if (memcmp(bfread, buffer1, sizeof(bfread)) != 0)
	{
		XCTFail(@"Bytes are not the same");
		goto clean;
	}
	
	// Seek.
	if (SMCryptoFileSeek(file, 10000, SEEK_SET, &error) == false)
	{
		XCTFail(@"Can't seek in file(%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Read 2.
	memset(bfread, 0x22, sizeof(bfread));
	
	size = SMCryptoFileRead(file, bfread, sizeof(bfread), &error);
	
	if (size != sizeof(bfread))
	{
		if (size == -1)
			XCTFail(@"Can't read bytes (%@)", [TestHelper stringWithError:error]);
		else
			XCTFail(@"No enough bytes to read");
		
		goto clean;
	}
	
	// Compare.
	if (memcmp(bfread, buffer2, sizeof(bfread)) != 0)
	{
		XCTFail(@"Bytes are not the same");
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
}

- (void)testCreate_VolatilePath
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	// Create file.
	file = SMCryptoFileCreateVolatile(path, SMCryptoFileKeySize128, &error);

	if (!file)
	{
		XCTFail(@"Can't create volatile file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Check that the file exist.
	if (access(path, F_OK) != 0)
	{
		XCTFail(@"File doesn't exist at path");
		goto clean;
	}
	
	// Close file.
	if (SMCryptoFileClose(file, &error) == false)
	{
		XCTFail(@"Can't close volatile file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	file = NULL;
	
	// Check that the file still exist.
	if (access(path, F_OK) != 0)
	{
		XCTFail(@"File doesn't exist at path after close");
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	
	unlink(path);
}

@end
