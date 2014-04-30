#!/bin/sh

# Resolve base project path.
base=$(cd "`dirname "$0"`"; pwd -P)

# Build.
clang "${base}/shell.c" "${base}/../SMSQLiteCryptoVFS.c" "${base}/../../../SMCryptoFile.c" -lsqlite3 -lz -lreadline -framework Security -I"${base}/../../../" -I"${base}/../" -DSQLITE_OMIT_LOAD_EXTENSION=1 -DSQLITE_OMIT_MEMORYDB=1 -DHAVE_READLINE=1 -o sqlite3
