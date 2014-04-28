/*
 * CryptoFileTestPassword.m
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
** CryptoFileTestPassword - Interface
*/
#pragma mark - CryptoFileTestPassword - Interface

@interface CryptoFileTestPassword : XCTestCase

@end



/*
** CryptoFileTestPassword
*/
#pragma mark - CryptoFileTestPassword

@implementation CryptoFileTestPassword


/*
** CryptoFileTestPassword - Tests
*/
#pragma mark - CryptoFileTestPassword - Tests

#pragma mark Arguments

- (void)testPassword_BadArgumentFile
{
	SMCryptoFileError error;
	
	// Null file.
	if (SMCryptoFileChangePassword(NULL, "azerty", &error) == true)
		XCTFail(@"Can change the password of a NULL file");
	else if (error != SMCryptoFileErrorArguments)
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
}

- (void)testPassword_BadArgumentPassword
{
	SMCryptoFileError	error;
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFile		*file = NULL;
	
	// Create file.
	file = SMCryptoFileCreate(path, "azerty", SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Null.
	if (SMCryptoFileChangePassword(file, NULL, &error) == true)
	{
		XCTFail(@"Can set a NULL password");
		goto clean;
	}
	else if (error != SMCryptoFileErrorArguments)
	{
		XCTFail(@"The error returned should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Empty.
	if (SMCryptoFileChangePassword(file, "", &error) == true)
	{
		XCTFail(@"Can set an empty password");
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

- (void)testPassword_Change
{
	const char			*path = [[TestHelper generateTempPath] UTF8String];
	SMCryptoFileError	error;
	SMCryptoFile		*file = NULL;
	
	const char			*pass1 = "azerty";
	const char			*pass2 = "poiuyt";
	
	// Create file.
	file = SMCryptoFileCreate(path, pass1, SMCryptoFileKeySize256, &error);
	
	if (!file)
	{
		XCTFail(@"Can't create AES 256 file (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Change password.
	if (SMCryptoFileChangePassword(file, pass2, &error) == false)
	{
		XCTFail(@"Can't change password (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	SMCryptoFileClose(file, NULL);
	file = NULL;
	
	// Try to open with old password.
	file = SMCryptoFileOpen(path, pass1, false, &error);
	
	if (file)
	{
		XCTFail(@"The password was not changed or the password is not checked (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	if (error != SMCryptoFileErrorPassword)
	{
		XCTFail(@"The error returned should be SMCryptoFileErrorPassword (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Try to open with new password.
	file = SMCryptoFileOpen(path, pass2, false, &error);
	
	if (!file)
	{
		XCTFail(@"Can't open with new password (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	SMCryptoFileClose(file, NULL);
	unlink(path);
}

@end
