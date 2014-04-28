/*
 * SMCryptoFileHandle.m
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


#import "SMCryptoFileHandle.h"


#if !__has_feature(objc_arc)
# error This class uses ARC, but it's not activated on your project. Using it is likely to produce leaks. Use -fobjc-arc to enable ARC only on this file.
#endif


/*
** Constants
*/
#pragma mark - Constants

NSString * const SMCryptoFileHandleErrorDomain = @"com.sourcemac.smcryptofilehandle.error";



/*
** SMCryptoFileHandle - Private
*/
#pragma mark - SMCryptoFileHandle - Private

@interface SMCryptoFileHandle ()
{
	SMCryptoFile *_file;
}

@end



/*
** SMCryptoFileHandle
*/
#pragma mark - SMCryptoFileHandle

@implementation SMCryptoFileHandle


/*
** SMCryptoFileHandle - Instance
*/
#pragma mark - SMCryptoFileHandle - Instance

// -- Getting a Crypto File Handle --
+ (instancetype)cryptoFileHandleByCreatingFileAtPath:(NSString *)path password:(NSString *)password keySize:(SMCryptoFileKeySize)keySize error:(NSError **)error
{
	// Create a file.
	SMCryptoFileError	fileError;
	SMCryptoFile		*file = SMCryptoFileCreate([path UTF8String], [password UTF8String], keySize, &fileError);
	
	if (!file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
		
		return nil;
	}
	
	// Create and return a file handle.
	return [[SMCryptoFileHandle alloc] initWithCryptoFile:file];
}

+ (instancetype)cryptoFileHandleByOpeningFileAtPath:(NSString *)path password:(NSString *)password readOnly:(BOOL)readOnly error:(NSError **)error
{
	// Open a file.
	SMCryptoFileError	fileError;
	SMCryptoFile		*file = SMCryptoFileOpen([path UTF8String], [password UTF8String], readOnly, &fileError);
	
	if (!file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
		
		return nil;
	}
	
	// Create and return a file handle.
	return [[SMCryptoFileHandle alloc] initWithCryptoFile:file];
}

- (id)initWithCryptoFile:(SMCryptoFile *)file
{
	self = [super init];
	
	if (self)
	{
		_file = file;
	}
	
	return self;
}

- (void)dealloc
{
    SMCryptoFileClose(_file, NULL);
}



/*
** SMCryptoFileHandle - Properties
*/
#pragma mark - SMCryptoFileHandle - Properties

// -- Changing a Crypto File settings --
- (BOOL)changePassword:(NSString *)newPassword error:(NSError **)error
{
	// Check file.
	if (!_file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:-1 userInfo:nil];
		
		return NO;
	}
	
	// Change password.
	SMCryptoFileError	fileError;
	BOOL				result;
	
	result = SMCryptoFileChangePassword(_file, [newPassword UTF8String], &fileError);
	
	if (!result && error)
		*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
	
	// Result.
	return result;
}

// -- Getting a Crypto File properties --
- (uint64_t)fileSize
{
	return SMCryptoFileSize(_file);
}



/*
** SMCryptoFileHandle - I/O
*/
#pragma mark - SMCryptoFileHandle - I/O

// -- Reading from a Crypto File Handle --
- (NSData *)readDataToEndOfFileAndReturnError:(NSError **)error
{
	// Check file.
	if (!_file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:-1 userInfo:nil];
		
		return nil;
	}
	
	// Compute size.
	uint64_t size = SMCryptoFileSize(_file) - SMCryptoFileTell(_file);
	
	if (size == 0)
		return [NSData data];
	
	// Create buffer.
	void *bytes = malloc((size_t)size);

	if (!bytes)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:SMCryptoFileErrorMemory userInfo:nil];
		
		return nil;
	}
	
	// Read data.
	SMCryptoFileError	fileError;
	int64_t				rsize;
	
	rsize = SMCryptoFileRead(_file, bytes, size, &fileError);
	
	if (rsize < 0)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
		
		return nil;
	}
	else if (rsize == 0)
	{
		free(bytes);
		
		return [NSData data];
	}
	else
	{
		return [NSData dataWithBytesNoCopy:bytes length:(NSUInteger)rsize freeWhenDone:YES];
	}
}

- (NSData *)readDataOfLength:(NSUInteger)length error:(NSError **)error
{
	// Check file.
	if (!_file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:-1 userInfo:nil];
		
		return nil;
	}
	
	// Check length.
	if (length == 0)
		return [NSData data];
	
	// Create buffer.
	void *bytes = malloc(length);
	
	if (!bytes)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:SMCryptoFileErrorMemory userInfo:nil];
		
		return nil;
	}
	
	// Read data.
	SMCryptoFileError	fileError;
	int64_t				rsize;
	
	rsize = SMCryptoFileRead(_file, bytes, length, &fileError);
	
	if (rsize < 0)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
		
		return nil;
	}
	else if (rsize == 0)
	{
		free(bytes);
		
		return [NSData data];
	}
	else
	{
		return [NSData dataWithBytesNoCopy:bytes length:(NSUInteger)rsize freeWhenDone:YES];
	}
}

// -- Writing to a Crypto File Handle --
- (BOOL)writeData:(NSData *)data error:(NSError **)error
{
	// Check file.
	if (!_file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:-1 userInfo:nil];
		
		return NO;
	}
	
	// Check parameters.
	if (!data)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:SMCryptoFileErrorArguments userInfo:nil];
		
		return NO;
	}
	
	if ([data length] == 0)
		return YES;
	
	// Write.
	SMCryptoFileError	fileError;
	bool				result;
	
	result = SMCryptoFileWrite(_file, [data bytes], [data length], &fileError);
	
	if (!result && error)
		*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
	
	// Result.
	return result;
}

// -- Seeking Within a Crypto File --
- (uint64_t)offsetInFile
{
	return SMCryptoFileTell(_file);
}

- (BOOL)seekToEndOfFile
{
	return SMCryptoFileSeek(_file, 0, SEEK_END, NULL);
}

- (BOOL)seekToFileOffset:(uint64_t)fileOffset error:(NSError **)error
{
	// Check file.
	if (!_file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:-1 userInfo:nil];
		
		return NO;
	}
	
	// Seek.
	SMCryptoFileError	fileError;
	bool				result;

	result = SMCryptoFileSeek(_file, fileOffset, SEEK_SET, &fileError);
	
	if (!result && error)
		*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];

	// Result.
	return result;
}

// -- Operating on a Crypto File --
- (BOOL)closeFileAndReturnError:(NSError **)error
{
	// Check file.
	if (!_file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:-1 userInfo:nil];
		
		return NO;
	}
	
	// Close.
	SMCryptoFileError	fileError;
	bool				result;
	
	result = SMCryptoFileClose(_file, &fileError);
	
	if (result)
		_file = NULL;
	else if (error)
		*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
	
	// Result.
	return result;
}

- (BOOL)synchronizeFileAndReturnError:(NSError **)error
{
	// Check file.
	if (!_file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:-1 userInfo:nil];
		
		return NO;
	}
	
	// Flush.
	SMCryptoFileError	fileError;
	bool				result;
	
	result = SMCryptoFileFlush(_file, SMCryptoFileSyncNo, &fileError);
	
	if (!result && error)
		*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
	
	// Result.
	return result;
}

- (BOOL)truncateFileAtOffset:(uint64_t)offset error:(NSError **)error
{
	// Check file.
	if (!_file)
	{
		if (error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:-1 userInfo:nil];
		
		return NO;
	}
	
	// Truncate.
	SMCryptoFileError	fileError;
	bool				result;
	
	result = SMCryptoFileTruncate(_file, offset, &fileError);
	
	if (result)
	{
		// Seek.
		result = SMCryptoFileSeek(_file, 0, SEEK_END, &fileError);
		
		if (!result && error)
			*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
	}
	else if (error)
		*error = [NSError errorWithDomain:SMCryptoFileHandleErrorDomain code:fileError userInfo:nil];
	
	// Result.
	return result;
}

@end
