/*
 * TestHelper.m
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


#import "TestHelper.h"


/*
** TestHelper
*/
#pragma mark - TestHelper

@implementation TestHelper

+ (NSString *)generateTempPath
{
	NSString	*template = [NSTemporaryDirectory() stringByAppendingPathComponent:@"crypto_test_file_XXXXX"];
	char		*ctemplate = strdup([template UTF8String]);
	
	// Create temp path.
	if (mktemp(ctemplate) == NULL)
	{
		free(ctemplate);
		return nil;
	}
	
	// Return string.
	return [[NSString alloc] initWithBytesNoCopy:ctemplate length:strlen(ctemplate) encoding:NSUTF8StringEncoding freeWhenDone:YES];
}

+ (NSString *)stringWithError:(SMCryptoFileError)error
{
	switch (error)
	{
		case SMCryptoFileErrorNo:			return @"SMCryptoFileErrorNo";
		case SMCryptoFileErrorArguments:	return @"SMCryptoFileErrorArguments";
		case SMCryptoFileErrorFormat:		return @"SMCryptoFileErrorFormat";
		case SMCryptoFileErrorVersion:		return @"SMCryptoFileErrorVersion";
		case SMCryptoFileErrorPassword:		return @"SMCryptoFileErrorPassword";
		case SMCryptoFileErrorCorrupted:	return @"SMCryptoFileErrorCorrupted";
		case SMCryptoFileErrorMemory:		return @"SMCryptoFileErrorMemory";
		case SMCryptoFileErrorCrypto:		return @"SMCryptoFileErrorCrypto";
		case SMCryptoFileErrorReadOnly:		return @"SMCryptoFileErrorReadOnly";
		case SMCryptoFileErrorIO:			return @"SMCryptoFileErrorIO";
		case SMCryptoFileErrorUnknown:		return @"SMCryptoFileErrorUnknown";
	}
	
	return @"-";
}

@end



/*
** TestCleaner
*/
#pragma mark - TestCleaner

@interface TestCleaner ()
{
	dispatch_queue_t	_localQueue;
	NSMutableArray		*_blocks;
}

@end

@implementation TestCleaner

- (id)init
{
    self = [super init];
	
    if (self)
	{
        _localQueue = dispatch_queue_create("com.sourcemac.testhelper.local", DISPATCH_QUEUE_SERIAL);
		_blocks = [[NSMutableArray alloc] init];
    }
	
    return self;
}

- (void)dealloc
{
	for (dispatch_block_t block in _blocks)
		block();
}

- (void)postponeBlock:(dispatch_block_t)block
{
	if (!block)
		return;
	
	dispatch_async(_localQueue, ^{
		[_blocks addObject:block];
	});
}

@end

