unit SQLite3;
{
  Simplified interface for SQLite.
  Updated for Sqlite 3 by Tim Anderson (tim@itwriting.com)
  Note: NOT COMPLETE for version 3, just minimal functionality
  Adapted from file created by Pablo Pissanetzky (pablo@myhtpc.net)
  which was based on SQLite.pas by Ben Hochstrasser (bhoc@surfeu.ch)
  changes by hkm:
  SQLite3_get_autocommit added
  SQLite3_open_v2 and vfs-flags added
  SQLite3_load_extension added
  SQLite3_enable_load_extension added
  SQLite3_clear_bindings added
}
{$IFDEF FPC}
{$MODE DELPHI}
{$H+} (* use AnsiString *)
{$PACKENUM 4} (* use 4-byte enums *)
{$PACKRECORDS C} (* C/C++-compatible record packing *)
{$ELSE}
{$MINENUMSIZE 4} (* use 4-byte enums *)
{$ENDIF}
interface
const
  {$IF Defined(MSWINDOWS)}
  SQLiteDLL = 'sqlite3.dll';
  {$ELSEIF Defined(DARWIN)}
  SQLiteDLL = 'libsqlite3.dylib';
  {$LINKLIB libsqlite3}
  {$ELSEIF Defined(UNIX)}
  SQLiteDLL = 'sqlite3.so';
  {$IFEND}
  // Return values for sqlite3_exec() and sqlite3_step()
const
  SQLITE_OK = 0; // Successful result
  (* beginning-of-error-codes *)
  SQLITE_ERROR = 1; // SQL error or missing database
  SQLITE_INTERNAL = 2; // An internal logic error in SQLite
  SQLITE_PERM = 3; // Access permission denied
  SQLITE_ABORT = 4; // Callback routine requested an abort
  SQLITE_BUSY = 5; // The database file is locked
  SQLITE_LOCKED = 6; // A table in the database is locked
  SQLITE_NOMEM = 7; // A malloc() failed
  SQLITE_READONLY = 8; // Attempt to write a readonly database
  SQLITE_INTERRUPT = 9; // Operation terminated by sqlite3_interrupt()
  SQLITE_IOERR = 10; // Some kind of disk I/O error occurred
  SQLITE_CORRUPT = 11; // The database disk image is malformed
  SQLITE_NOTFOUND = 12; // (Internal Only) Table or record not found
  SQLITE_FULL = 13; // Insertion failed because database is full
  SQLITE_CANTOPEN = 14; // Unable to open the database file
  SQLITE_PROTOCOL = 15; // Database lock protocol error
  SQLITE_EMPTY = 16; // Database is empty
  SQLITE_SCHEMA = 17; // The database schema changed
  SQLITE_TOOBIG = 18; // Too much data for one row of a table
  SQLITE_CONSTRAINT = 19; // Abort due to contraint violation
  SQLITE_MISMATCH = 20; // Data type mismatch
  SQLITE_MISUSE = 21; // Library used incorrectly
  SQLITE_NOLFS = 22; // Uses OS features not supported on host
  SQLITE_AUTH = 23; // Authorization denied
  SQLITE_FORMAT = 24; // Auxiliary database format error
  SQLITE_RANGE = 25; // 2nd parameter to sqlite3_bind out of range
  SQLITE_NOTADB = 26; // File opened that is not a database file
  SQLITE_ROW = 100; // sqlite3_step() has another row ready
  SQLITE_DONE = 101; // sqlite3_step() has finished executing
  SQLITE_INTEGER = 1;
  SQLITE_FLOAT = 2;
  SQLITE_TEXT = 3;
  SQLITE_BLOB = 4;
  SQLITE_NULL = 5;
  SQLITE_UTF8 = 1;
  SQLITE_UTF16 = 2;
  SQLITE_UTF16BE = 3;
  SQLITE_UTF16LE = 4;
  SQLITE_ANY = 5;
  SQLITE_STATIC {: TSQLite3Destructor} = Pointer(0);
  SQLITE_TRANSIENT {: TSQLite3Destructor} = Pointer(-1);
  {+ hkm start}
  SQLITE_OPEN_READONLY = $00000001; // Ok for sqlite3_open_v2()
  SQLITE_OPEN_READWRITE = $00000002; // Ok for sqlite3_open_v2()
  SQLITE_OPEN_CREATE = $00000004; // Ok for sqlite3_open_v2()
  SQLITE_OPEN_DELETEONCLOSE = $00000008; // VFS only
  SQLITE_OPEN_EXCLUSIVE = $00000010; // VFS only
  SQLITE_OPEN_MAIN_DB = $00000100; // VFS only
  SQLITE_OPEN_TEMP_DB = $00000200; // VFS only
  SQLITE_OPEN_TRANSIENT_DB = $00000400; // VFS only
  SQLITE_OPEN_MAIN_JOURNAL = $00000800; // VFS only
  SQLITE_OPEN_TEMP_JOURNAL = $00001000; // VFS only
  SQLITE_OPEN_SUBJOURNAL = $00002000; // VFS only
  SQLITE_OPEN_MASTER_JOURNAL = $00004000; // VFS only
  SQLITE_OPEN_NOMUTEX = $00008000; // Ok for sqlite3_open_v2()
  SQLITE_OPEN_FULLMUTEX = $00010000; // Ok for sqlite3_open_v2()
  SQLITE_OPEN_SHAREDCACHE = $00020000; // Ok for sqlite3_open_v2()
  SQLITE_OPEN_PRIVATECACHE = $00040000; // Ok for sqlite3_open_v2()
  {+hkm end}

type
  TSQLiteDB = type Pointer;
  TSQLiteResult = ^PAnsiChar;
  TSQLiteStmt = type Pointer;
type
  PPAnsiCharArray = ^TPAnsiCharArray;
  TPAnsiCharArray = array[0..(MaxInt div SizeOf(PAnsiChar)) - 1] of PAnsiChar;
type
  TSQLiteExecCallback = function(UserData: Pointer; NumCols: integer; ColValues:
    PPAnsiCharArray; ColNames: PPAnsiCharArray): integer; cdecl;
  TSQLiteBusyHandlerCallback = function(UserData: Pointer; P2: integer): integer; cdecl;
  //function prototype for define own collate
  TCollateXCompare = function(UserData: Pointer; Buf1Len: integer; Buf1: Pointer;
    Buf2Len: integer; Buf2: Pointer): integer; cdecl;
{+ hkm start}
function SQLite3_get_autocommit(db: TSQLiteDB): integer; cdecl; external SQLiteDLL name
  'sqlite3_get_autocommit';
{+ hkm end}
function SQLite3_Open(filename: PAnsiChar; var db: TSQLiteDB): integer; cdecl; external SQLiteDLL
  name 'sqlite3_open';
{+ hkm start}
function SQLite3_Open_v2(filename: PAnsiChar; var db: TSQLiteDB; flags: integer; zVfs: PAnsiChar):
  integer; cdecl; external SQLiteDLL name 'sqlite3_open_v2';
function SQLite3_load_extension(
  db:TSQLiteDB;                // Load the extension into this database connection
  zFile:PAnsiChar;             // Name of the shared library containing extension
  zProc:PAnsiChar;             // Entry point.  Derived from zFile if 0
  var pzErrMsg:PAnsiChar       // Put error message here if not 0
):integer;cdecl;external SQLiteDLL name 'sqlite3_load_extension';
function SQLite3_enable_load_extension(db:TSQLiteDB; onoff:integer):integer;cdecl;external SQLiteDLL name 'sqlite3_enable_load_extension';
function SQLite3_clear_bindings(hStmt: TSQLiteStmt): integer; cdecl; external SQLiteDLL name
  'sqlite3_clear_bindings';
{+ hkm end}
function SQLite3_Close(db: TSQLiteDB): integer; cdecl; external SQLiteDLL name 'sqlite3_close';
function SQLite3_Exec(db: TSQLiteDB; SQLStatement: PAnsiChar; CallbackPtr: TSQLiteExecCallback;
  UserData: Pointer; var ErrMsg: PAnsiChar): integer; cdecl; external SQLiteDLL name 'sqlite3_exec';
function SQLite3_Version(): PAnsiChar; cdecl; external SQLiteDLL name 'sqlite3_libversion';
function SQLite3_ErrMsg(db: TSQLiteDB): PAnsiChar; cdecl; external SQLiteDLL name 'sqlite3_errmsg';
function SQLite3_ErrCode(db: TSQLiteDB): integer; cdecl; external SQLiteDLL name 'sqlite3_errcode';
procedure SQlite3_Free(P: PAnsiChar); cdecl; external SQLiteDLL name 'sqlite3_free';
function SQLite3_GetTable(db: TSQLiteDB; SQLStatement: PAnsiChar; var ResultPtr: TSQLiteResult; var
  RowCount: Cardinal; var ColCount: Cardinal; var ErrMsg: PAnsiChar): integer; cdecl; external
  SQLiteDLL name 'sqlite3_get_table';
procedure SQLite3_FreeTable(Table: TSQLiteResult); cdecl; external SQLiteDLL name
  'sqlite3_free_table';
function SQLite3_Complete(P: PAnsiChar): boolean; cdecl; external SQLiteDLL name
  'sqlite3_complete';
function SQLite3_LastInsertRowID(db: TSQLiteDB): int64; cdecl; external SQLiteDLL name
  'sqlite3_last_insert_rowid';
procedure SQLite3_Interrupt(db: TSQLiteDB); cdecl; external SQLiteDLL name 'sqlite3_interrupt';
procedure SQLite3_BusyHandler(db: TSQLiteDB; CallbackPtr: TSQLiteBusyHandlerCallback; UserData:
  Pointer); cdecl; external SQLiteDLL name 'sqlite3_busy_handler';
procedure SQLite3_BusyTimeout(db: TSQLiteDB; TimeOut: integer); cdecl; external SQLiteDLL name
  'sqlite3_busy_timeout';
function SQLite3_Changes(db: TSQLiteDB): integer; cdecl; external SQLiteDLL name 'sqlite3_changes';
function SQLite3_TotalChanges(db: TSQLiteDB): integer; cdecl; external SQLiteDLL name
  'sqlite3_total_changes';
function SQLite3_Prepare(db: TSQLiteDB; SQLStatement: PAnsiChar; nBytes: integer; var hStmt:
  TSQLiteStmt; var pzTail: PAnsiChar): integer; cdecl; external SQLiteDLL name 'sqlite3_prepare';
function SQLite3_Prepare_v2(db: TSQLiteDB; SQLStatement: PAnsiChar; nBytes: integer; var hStmt:
  TSQLiteStmt; var pzTail: PAnsiChar): integer; cdecl; external SQLiteDLL name 'sqlite3_prepare_v2';
function SQLite3_Prepare16(db: TSQLiteDB; SQLStatement: PWideChar; nBytes: integer; var hStmt:
  TSQLiteStmt; var pzTail: PWideChar): integer; cdecl; external SQLiteDLL name 'sqlite3_prepare16';
function SQLite3_Prepare16_v2(db: TSQLiteDB; SQLStatement: PWideChar; nBytes: integer; var hStmt:
  TSQLiteStmt; var pzTail: PWideChar): integer; cdecl; external SQLiteDLL name
  'sqlite3_prepare16_v2';
function SQLite3_ColumnCount(hStmt: TSQLiteStmt): integer; cdecl; external SQLiteDLL name
  'sqlite3_column_count';
function SQLite3_ColumnName(hStmt: TSQLiteStmt; ColNum: integer): PAnsiChar; cdecl; external
  SQLiteDLL name 'sqlite3_column_name';
function SQLite3_ColumnDeclType(hStmt: TSQLiteStmt; ColNum: integer): PAnsiChar; cdecl; external
  SQLiteDLL name 'sqlite3_column_decltype';
function SQLite3_Step(hStmt: TSQLiteStmt): integer; cdecl; external SQLiteDLL name 'sqlite3_step';
function SQLite3_DataCount(hStmt: TSQLiteStmt): integer; cdecl; external SQLiteDLL name
  'sqlite3_data_count';
function SQLite3_ColumnBlob(hStmt: TSQLiteStmt; ColNum: integer): Pointer; cdecl; external SQLiteDLL
  name 'sqlite3_column_blob';
function SQLite3_ColumnBytes(hStmt: TSQLiteStmt; ColNum: integer): integer; cdecl; external
  SQLiteDLL name 'sqlite3_column_bytes';
function SQLite3_ColumnDouble(hStmt: TSQLiteStmt; ColNum: integer): double; cdecl; external
  SQLiteDLL name 'sqlite3_column_double';
function SQLite3_ColumnInt(hStmt: TSQLiteStmt; ColNum: integer): integer; cdecl; external SQLiteDLL
  name 'sqlite3_column_int';
function SQLite3_ColumnText(hStmt: TSQLiteStmt; ColNum: integer): PAnsiChar; cdecl; external
  SQLiteDLL name 'sqlite3_column_text';
function SQLite3_ColumnText16(hStmt: TSQLiteStmt; ColNum: integer): PWideChar; cdecl; external
  SQLiteDLL name 'sqlite3_column_text16';
function SQLite3_ColumnType(hStmt: TSQLiteStmt; ColNum: integer): integer; cdecl; external SQLiteDLL
  name 'sqlite3_column_type';
function SQLite3_ColumnInt64(hStmt: TSQLiteStmt; ColNum: integer): int64; cdecl; external SQLiteDLL
  name 'sqlite3_column_int64';
function SQLite3_Finalize(hStmt: TSQLiteStmt): integer; cdecl; external SQLiteDLL name
  'sqlite3_finalize';
function SQLite3_Reset(hStmt: TSQLiteStmt): integer; cdecl; external SQLiteDLL name
  'sqlite3_reset';
//
// In the SQL strings input to sqlite3_prepare() and sqlite3_prepare16(),
// one or more literals can be replace by a wildcard "?" or ":N:" where
// N is an integer.  These value of these wildcard literals can be set
// using the routines listed below.
//
// In every case, the first parameter is a pointer to the sqlite3_stmt
// structure returned from sqlite3_prepare().  The second parameter is the
// index of the wildcard.  The first "?" has an index of 1.  ":N:" wildcards
// use the index N.
//
// The fifth parameter to sqlite3_bind_blob(), sqlite3_bind_text(), and
//sqlite3_bind_text16() is a destructor used to dispose of the BLOB or
//text after SQLite has finished with it.  If the fifth argument is the
// special value SQLITE_STATIC, then the library assumes that the information
// is in static, unmanaged space and does not need to be freed.  If the
// fifth argument has the value SQLITE_TRANSIENT, then SQLite makes its
// own private copy of the data.
//
// The sqlite3_bind_* routine must be called before sqlite3_step() after
// an sqlite3_prepare() or sqlite3_reset().  Unbound wildcards are interpreted
// as NULL.
//
type
  TSQLite3Destructor = procedure(Ptr: Pointer); cdecl;
function sqlite3_bind_blob(hStmt: TSQLiteStmt; ParamNum: integer;
  ptrData: Pointer; numBytes: integer; ptrDestructor: TSQLite3Destructor): integer;
cdecl; external SQLiteDLL name 'sqlite3_bind_blob';
function sqlite3_bind_text(hStmt: TSQLiteStmt; ParamNum: integer;
  Text: PAnsiChar; numBytes: integer; ptrDestructor: TSQLite3Destructor): integer;
cdecl; external SQLiteDLL name 'sqlite3_bind_text';
function sqlite3_bind_text16(hStmt: TSQLiteStmt; ParamNum: integer;
  Text: PWideChar; numBytes: integer; ptrDestructor: TSQLite3Destructor): integer;
cdecl; external SQLiteDLL name 'sqlite3_bind_text16';
function sqlite3_bind_double(hStmt: TSQLiteStmt; ParamNum: integer; Data: double): integer;
cdecl; external SQLiteDLL name 'sqlite3_bind_double';
function sqlite3_bind_int(hStmt: TSQLiteStmt; ParamNum: integer; Data: integer): integer;
cdecl; external SQLiteDLL name 'sqlite3_bind_int';
function sqlite3_bind_int64(hStmt: TSQLiteStmt; ParamNum: integer; Data: int64): integer;
cdecl; external SQLiteDLL name 'sqlite3_bind_int64';
function sqlite3_bind_null(hStmt: TSQLiteStmt; ParamNum: integer): integer;
cdecl; external SQLiteDLL name 'sqlite3_bind_null';
function sqlite3_bind_parameter_index(hStmt: TSQLiteStmt; zName: PAnsiChar): integer;
cdecl; external SQLiteDLL name 'sqlite3_bind_parameter_index';
function sqlite3_enable_shared_cache(Value: integer): integer; cdecl; external SQLiteDLL name
  'sqlite3_enable_shared_cache';
//user collate definiton
function SQLite3_create_collation(db: TSQLiteDB; name: PAnsiChar; eTextRep: integer;
  UserData: Pointer; xCompare: TCollateXCompare): integer; cdecl; external SQLiteDLL name
    'sqlite3_create_collation';
function SQLiteFieldType(SQLiteFieldTypeCode: integer): AnsiString;
function SQLiteErrorStr(SQLiteErrorCode: integer): AnsiString;
implementation
uses
  SysUtils;

function SQLiteFieldType(SQLiteFieldTypeCode: integer): AnsiString;
begin
  case SQLiteFieldTypeCode of
    SQLITE_INTEGER: Result := 'Integer';
    SQLITE_FLOAT: Result := 'Float';
    SQLITE_TEXT: Result := 'Text';
    SQLITE_BLOB: Result := 'Blob';
    SQLITE_NULL: Result := 'Null';
  else
    Result := 'Unknown SQLite Field Type Code "' + IntToStr(SQLiteFieldTypeCode) + '"';
  end;
end;

function SQLiteErrorStr(SQLiteErrorCode: integer): AnsiString;
begin
  case SQLiteErrorCode of
    SQLITE_OK: Result := 'Successful result';
    SQLITE_ERROR: Result := 'SQL error or missing database';
    SQLITE_INTERNAL: Result := 'An internal logic error in SQLite';
    SQLITE_PERM: Result := 'Access permission denied';
    SQLITE_ABORT: Result := 'Callback routine requested an abort';
    SQLITE_BUSY: Result := 'The database file is locked';
    SQLITE_LOCKED: Result := 'A table in the database is locked';
    SQLITE_NOMEM: Result := 'A malloc() failed';
    SQLITE_READONLY: Result := 'Attempt to write a readonly database';
    SQLITE_INTERRUPT: Result := 'Operation terminated by sqlite3_interrupt()';
    SQLITE_IOERR: Result := 'Some kind of disk I/O error occurred';
    SQLITE_CORRUPT: Result := 'The database disk image is malformed';
    SQLITE_NOTFOUND: Result := '(Internal Only) Table or record not found';
    SQLITE_FULL: Result := 'Insertion failed because database is full';
    SQLITE_CANTOPEN: Result := 'Unable to open the database file';
    SQLITE_PROTOCOL: Result := 'Database lock protocol error';
    SQLITE_EMPTY: Result := 'Database is empty';
    SQLITE_SCHEMA: Result := 'The database schema changed';
    SQLITE_TOOBIG: Result := 'Too much data for one row of a table';
    SQLITE_CONSTRAINT: Result := 'Abort due to contraint violation';
    SQLITE_MISMATCH: Result := 'Data type mismatch';
    SQLITE_MISUSE: Result := 'Library used incorrectly';
    SQLITE_NOLFS: Result := 'Uses OS features not supported on host';
    SQLITE_AUTH: Result := 'Authorization denied';
    SQLITE_FORMAT: Result := 'Auxiliary database format error';
    SQLITE_RANGE: Result := '2nd parameter to sqlite3_bind out of range';
    SQLITE_NOTADB: Result := 'File opened that is not a database file';
    SQLITE_ROW: Result := 'sqlite3_step() has another row ready';
    SQLITE_DONE: Result := 'sqlite3_step() has finished executing';
  else
    Result := 'Unknown SQLite Error Code "' + IntToStr(SQLiteErrorCode) + '"';
  end;
end;

function ColValueToStr(Value: PAnsiChar): AnsiString;
begin
  if (Value = nil) then
    Result := 'NULL'
  else
    Result := Value;
end;

end.


