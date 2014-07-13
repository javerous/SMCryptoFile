/*
 * CryptoSQLiteTest.m
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

#include <sqlite3.h>

#import "SMSQLiteCryptoVFS.h"

#import "TestHelper.h"


/*
** Logs
*/
#pragma mark - Logs

static void shellLog(void *pArg, int iErrCode, const char *zMsg)
{
	fprintf(stderr, "SQLite Log: (%d) %s\n", iErrCode, zMsg);
}



/*
** CryptoSQLiteTest - Interface
*/
#pragma mark - CryptoSQLiteTest - Interface

@interface CryptoSQLiteTest : XCTestCase

@end



/*
** CryptoSQLiteTest
*/
#pragma mark - CryptoSQLiteTest

@implementation CryptoSQLiteTest


/*
** CryptoSQLiteTest - XCTestCase
*/
#pragma mark - CryptoSQLiteTest - XCTestCase

- (void)setUp
{
    [super setUp];
	
	sqlite3_config(SQLITE_CONFIG_LOG, shellLog, NULL);
	
	SMSQLiteCryptoVFSRegister();
	SMSQLiteCryptoVFSDefaultsSetKeySize(SMCryptoFileKeySize256);
}



/*
** CryptoSQLiteTest - Tests
*/
#pragma mark - CryptoSQLiteTest - Tests

- (void)testCreateTable
{
	NSString	*tempPath = [TestHelper generateTempPath];

	const char	*uuid = SMSQLiteCryptoVFSSettingsAdd("my_password", SMCryptoFileKeySize192);
	const char	*path = [tempPath UTF8String];
	const char	*uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", tempPath, uuid] UTF8String];
	
	sqlite3		*dtb = NULL;
	sqlite3_stmt *stmt = NULL;
	
	int			result;
	
	// Create database.
	result = sqlite3_open_v2(uriPath, &dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create sqlite base (%i)", result);
		goto clean;
	}
	
	// Create table.
	result = sqlite3_exec(dtb, "CREATE TABLE toto (truc TEXT)", NULL, NULL, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create table (%i)", result);
		goto clean;
	}
	
	// Close.
	result = sqlite3_close(dtb);

	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't close sqlite base (%i)", result);
		dtb = NULL;
		goto clean;
	}
	
	// Re-Open with create.
	result = sqlite3_open_v2(uriPath, &dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't open sqlite base (%i)", result);
		goto clean;
	}
	
	// Create statement.
	result = sqlite3_prepare_v2(dtb, "SELECT * FROM sqlite_master WHERE type='table'", -1, &stmt, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create sqlite statement (%i)", result);
		goto clean;
	}
	
	// Check that our test table exist.
	BOOL found = NO;
	
	while (sqlite3_step(stmt) == SQLITE_ROW)
	{
		int i, cnt = sqlite3_column_count(stmt);
	
		for (i = 0; i < cnt; i++)
		{
			const char	*name = sqlite3_column_name(stmt, i);
			const char	*content = (const char *)sqlite3_column_text(stmt, i);
			
			if (strcmp(name, "name") == 0 && strcmp(content, "toto") == 0)
			{
				found = YES;
				break;
			}
		}
	}
	
	if (!found)
	{
		XCTFail(@"Can't find the created table");
		goto clean;
	}
	
	sqlite3_finalize(stmt);
	stmt = NULL;
	
	// Close.
	result = sqlite3_close(dtb);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't close sqlite base (%i)", result);
		dtb = NULL;
		goto clean;
	}
	
	// Re-Open without create.
	result = sqlite3_open_v2(uriPath, &dtb, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't re-open sqlite base (%i)", result);
		goto clean;
	}
	
	// Close.
	result = sqlite3_close(dtb);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't close sqlite base (%i)", result);
		dtb = NULL;
		goto clean;
	}
	
	// Re-open without password.
	SMSQLiteCryptoVFSSettingsRemove(uuid);
	
	uuid = NULL;

	result = sqlite3_open_v2(uriPath, &dtb, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
		
	if (result != SQLITE_MISUSE)
	{
		XCTFail(@"Bad result on open when password is not defined (%i)", result);
		goto clean;
	}
	
clean:
	
	if (stmt)
		sqlite3_finalize(stmt);
	
	if (dtb)
	{
		// Close.
		result = sqlite3_close(dtb);
		
		if (result != SQLITE_OK)
			XCTFail(@"Can't close sqlite base (%i)", result);
	}
	
	if (uuid)
		SMSQLiteCryptoVFSSettingsRemove(uuid);
	
	// Remove.
	unlink(path);
}

- (void)testCreateInserts
{
	NSString	*tempPath = [TestHelper generateTempPath];
	
	const char	*uuid = SMSQLiteCryptoVFSSettingsAdd("my_password", SMCryptoFileKeySize192);
	const char	*path = [tempPath UTF8String];
	const char	*uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", tempPath, uuid] UTF8String];
	
	sqlite3			*dtb = NULL;
	sqlite3_stmt	*stmt = NULL;
	int				result;
	
	// Create database.
	result = sqlite3_open_v2(uriPath, &dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create sqlite base (%i)", result);
		goto clean;
	}
	
	// Create table.
	result = sqlite3_exec(dtb, "CREATE TABLE table1 (id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT, place INTEGER)", NULL, NULL, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create table (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Create index.
	result = sqlite3_exec(dtb, "CREATE INDEX table1_idx ON table1 (place ASC)", NULL, NULL, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create table (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Create statement.
	result = sqlite3_prepare_v2(dtb, "INSERT INTO table1 (content, place) VALUES (?, ?)", -1, &stmt, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create sqlite statement (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Add values.
	for (unsigned i = 0; i < 5000; i++)
	{
		NSString *txt = [NSString stringWithFormat:@"text %i", i];
		
		sqlite3_bind_text(stmt, 1, [txt UTF8String], -1, SQLITE_STATIC);
		sqlite3_bind_int(stmt, 2, i);
		
		result = sqlite3_step(stmt);
		
		if (result != SQLITE_DONE)
		{
			XCTFail(@"Can't insert row (%i - %s)", result, sqlite3_errmsg(dtb));
			goto clean;
		}
		
		sqlite3_reset(stmt);
	}
	
	sqlite3_finalize(stmt);
	stmt = NULL;
	
	// Create statement.
	result = sqlite3_prepare_v2(dtb, "SELECT content, place FROM table1 ORDER BY place ASC", -1, &stmt, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create sqlite statement (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Select row.
	for (unsigned i = 0; i < 5000; i++)
	{
		result = sqlite3_step(stmt);
		
		if (result == SQLITE_ROW)
		{
			const char *content = (const char *)sqlite3_column_text(stmt, 0);
			int			place = sqlite3_column_int(stmt, 1);
			
			if (place != i && strcmp(content, [[NSString stringWithFormat:@"text %i", place] UTF8String]) == 0)
			{
				XCTFail(@"Bad row content - content: '%s'; place: %i", content, place);
				goto clean;
			}
		}
		else if (result == SQLITE_DONE)
		{
			break;
		}
		else
		{
			XCTFail(@"Can't select row (%i - %s)", result, sqlite3_errmsg(dtb));
			goto clean;
		}
	}
	
	sqlite3_finalize(stmt);
	stmt = NULL;

	// Create table.
	result = sqlite3_exec(dtb, "CREATE TABLE table2 (id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT, place INTEGER)", NULL, NULL, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create table (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Create index.
	result = sqlite3_exec(dtb, "CREATE INDEX table2_idx ON table2 (place ASC)", NULL, NULL, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create table (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	
	// Create statement.
	result = sqlite3_prepare_v2(dtb, "INSERT INTO table2 (content, place) VALUES (?, ?)", -1, &stmt, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create sqlite statement (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Start transaction.
	result = sqlite3_exec(dtb, "BEGIN", NULL, NULL, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't begin transaction (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Add values.
	for (unsigned i = 0; i < 10000; i++)
	{
		NSString *txt = [NSString stringWithFormat:@"toto %i", i];
		
		sqlite3_bind_text(stmt, 1, [txt UTF8String], -1, SQLITE_STATIC);
		sqlite3_bind_int(stmt, 2, i);
		
		result = sqlite3_step(stmt);
		
		if (result != SQLITE_DONE)
		{
			XCTFail(@"Can't insert row (%i - %s)", result, sqlite3_errmsg(dtb));
			goto clean;
		}
		
		sqlite3_reset(stmt);
	}
	
	sqlite3_finalize(stmt);
	stmt = NULL;
	
	// End transaction.
	result = sqlite3_exec(dtb, "END", NULL, NULL, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't end transaction (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}

	// Create statement.
	result = sqlite3_prepare_v2(dtb, "SELECT content, place FROM table2 ORDER BY place ASC", -1, &stmt, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create sqlite statement (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Select row.
	for (unsigned i = 0; i < 10000; i++)
	{
		result = sqlite3_step(stmt);
		
		if (result == SQLITE_ROW)
		{
			const char *content = (const char *)sqlite3_column_text(stmt, 0);
			int			place = sqlite3_column_int(stmt, 1);
			
			if (place != i && strcmp(content, [[NSString stringWithFormat:@"toto %i", place] UTF8String]) == 0)
			{
				XCTFail(@"Bad row content - content: '%s'; place: %i", content, place);
				goto clean;
			}
		}
		else if (result == SQLITE_DONE)
		{
			break;
		}
		else
		{
			XCTFail(@"Can't select row (%i - %s)", result, sqlite3_errmsg(dtb));
			goto clean;
		}
	}
	
	sqlite3_finalize(stmt);
	stmt = NULL;
	
	// Stat #1.
	struct stat st1;
	
	if (stat(path, &st1) != 0)
	{
		XCTFail(@"Can't stat file");
		goto clean;
	}
	
	NSLog(@"size: %llu", st1.st_size);
	
	// Delete all.
	result = sqlite3_exec(dtb, "DELETE FROM table1; DELETE FROM table2;", NULL, NULL, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't delete rows from table1 (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Vacuum.
	result = sqlite3_exec(dtb, "VACUUM", NULL, NULL, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't vacuum database (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Stat #2.
	struct stat st2;
	
	if (stat(path, &st2) != 0)
	{
		XCTFail(@"Can't stat file.");
		goto clean;
	}
	
	// Compare stat.
	if (st2.st_size >= st1.st_size)
	{
		XCTFail(@"File is not smaller after a vacuum - size_before: %llu; size_after: %llu", st1.st_size, st2.st_size);
		goto clean;
	}
	
	// Close base.
	result = sqlite3_close(dtb);
		
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't close sqlite base (%i - %s)", result, sqlite3_errmsg(dtb));
		goto clean;
	}
	
	// Re-open database.
	result = sqlite3_open_v2(uriPath, &dtb, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't re-open sqlite base (%i)", result);
		goto clean;
	}
	
	
	// Create statement.
	result = sqlite3_prepare_v2(dtb, "SELECT * FROM sqlite_master WHERE type='table'", -1, &stmt, NULL);
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create sqlite statement (%i)", result);
		goto clean;
	}
	
	// Check that our tables exist.
	BOOL found1 = NO;
	BOOL found2 = NO;

	while (sqlite3_step(stmt) == SQLITE_ROW)
	{
		int i, cnt = sqlite3_column_count(stmt);
		
		for (i = 0; i < cnt; i++)
		{
			const char	*name = sqlite3_column_name(stmt, i);
			const char	*content = (const char *)sqlite3_column_text(stmt, i);
			
			if (strcmp(name, "name") == 0)
			{
				if (strcmp(content, "table1") == 0)
					found1 = YES;
				else if (strcmp(content, "table2") == 0)
					found2 = YES;
			}
		}
	}
	
	if (!found1 || !found2)
	{
		if (!found1)
			XCTFail(@"Can't find table1 after re-open");
		else
			XCTFail(@"Can't find table2 after re-open");

		goto clean;
	}
	
	sqlite3_finalize(stmt);
	stmt = NULL;
	
clean:
	
	if (stmt)
		sqlite3_finalize(stmt);
	
	if (dtb)
		sqlite3_close(dtb);
	
	if (uuid)
		SMSQLiteCryptoVFSSettingsRemove(uuid);
	
	unlink(path);
}

- (void)testChangePassword
{
	NSString	*tempPath = [TestHelper generateTempPath];
	
	const char	*uuid = SMSQLiteCryptoVFSSettingsAdd("my_password", SMCryptoFileKeySize192);
	const char	*path = [tempPath UTF8String];
	const char	*uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", tempPath, uuid] UTF8String];
	
	sqlite3		*dtb = NULL;
	int			result;
	
	// Create database.
	result = sqlite3_open_v2(uriPath, &dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
	
	if (result != SQLITE_OK)
	{
		XCTFail(@"Can't create sqlite base (%i)", result);
		goto clean;
	}
	
	// Change password.
	SMCryptoFileError error;
	
	if (SMSQLiteCryptoVFSChangePassword(dtb, "azerty", &error) == false)
	{
		XCTFail(@"Can't change password (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
	// Close.
	sqlite3_close(dtb);
	dtb = NULL;
	
	// Try to re-open with same password.
	result = sqlite3_open_v2(uriPath, &dtb, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
	
	if (result == SQLITE_OK)
	{
		XCTFail(@"Can open database with old password (%i)", result);
		goto clean;
	}
	
	if (SMSQLiteCryptoVFSLastFileCryptoError() != SMCryptoFileErrorPassword)
	{
		XCTFail(@"The last error should be SMCryptoFileErrorArguments (%@)", [TestHelper stringWithError:error]);
		goto clean;
	}
	
clean:
	
	if (dtb)
		sqlite3_close(dtb);
	
	if (uuid)
		SMSQLiteCryptoVFSSettingsRemove(uuid);
	
	unlink(path);
}

@end
