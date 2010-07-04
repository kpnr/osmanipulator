unit SQLiteObj;

interface

uses
  SysUtils, SQLite3;

type
  ESQLite = class(Exception)
  public
    SQLiteCode: integer;
    WideMessage: WideString;
    constructor Create(const ws: WideString; Code: integer);
  end;

  TSQLiteStmt = class(TObject)
  protected
    hStmt: SQLite3.TSQLiteStmt;
    EOF: boolean;
    fColCount: integer;
    function GetHasNext(): boolean;
    function GetColumn(i: integer): Variant;
    function getColName(i:integer):WideString;
    procedure CheckColCount();
  public
    constructor Create();
    destructor Destroy; override;
    procedure Bind(ParIds, ParValues: array of const);
    procedure Exec;
    procedure Next;
    procedure Reset;
    property HasNext: boolean read GetHasNext;
    property Column[i: integer]: Variant read GetColumn;
    property ColCount:integer read fColCount;
    property ColName[i:integer]:WideString read getColName;
  end;

  TSQLiteDB = class(TObject)
  protected
    hDB: SQLite3.TSQLiteDB;
    stmtCommit,stmtRollback,stmtStartTrans:TSQLiteStmt;
    function GetIsInTransaction():boolean;
  public
    destructor Destroy; override;
    function CreateStmt(const SQL: WideString): TSQLiteStmt;
    procedure Close();
    procedure Open(const FileName: WideString);
    procedure StartTransaction();
    procedure Commit();
    procedure Rollback();
    property IsInTransaction:boolean read GetIsInTransaction;
  end;

implementation

uses Variants, Math;

{ TSQLiteDB }

procedure TSQLiteDB.Close;
begin
  if assigned(hDB) then begin
    SQLite3_Close(hDB);
    hDB := nil;
  end;
end;

procedure TSQLiteDB.Commit;
begin
  if not assigned(stmtCommit) then begin
    stmtCommit:=CreateStmt('COMMIT;');
  end;
  stmtCommit.Exec();
end;

function TSQLiteDB.CreateStmt(const SQL: WideString): TSQLiteStmt;
var
  hStmt: SQLite3.TSQLiteStmt;
  pWC: pWideChar;
  r: integer;
begin
  if not assigned(hDB) then
    raise ESQLite.Create('TSQLiteDB.CreateStmt: DB not opened', SQLITE_ERROR);
  r := SQLite3_Prepare16_v2(hDB, pWideChar(SQL), length(SQL) * sizeof(SQL[1]),
    hStmt, pWC);
  if (r <> SQLITE_OK) then begin
    raise ESQLite.Create('TSQLiteDB.CreateStmt: Prepare failed', r);
  end;
  if assigned(pWC) and (pWC^<>#0) then
    raise ESQLite.Create('TSQLiteDB.CreateStmt: Multi-statement SQL not supported',SQLITE_TOOBIG);
  result := TSQLiteStmt.Create();
  result.hStmt := hStmt;
end;

destructor TSQLiteDB.Destroy;
begin
  if assigned(stmtCommit) then
    FreeAndNil(stmtCommit);
  if assigned(stmtRollback) then
    FreeAndNil(stmtRollback);
  if assigned(stmtStartTrans) then
    FreeAndNil(stmtStartTrans);
  if (assigned(hDB)) then Close();
  inherited;
end;

function TSQLiteDB.GetIsInTransaction: boolean;
begin
  result := assigned(hDB) and (sqlite3_get_autocommit(hDB)=0);
end;

procedure TSQLiteDB.Open(const FileName: WideString);
var
  ec: integer;
begin
  if (assigned(hDB)) then
    raise ESQLite.Create('TSQLiteDB.Open: already opened', SQLITE_ERROR);
  ec := SQLite3_Open(pAnsiChar(UTF8Encode(FileName)), hDB);
  if (ec <> SQLITE_OK) then
    raise ESQLite.Create('TSQLiteDB.Open: can`t open ' + FileName, ec);
end;

procedure TSQLiteDB.Rollback;
begin
  if not assigned(stmtRollback) then begin
    stmtRollback:=CreateStmt('ROLLBACK;');
  end;
  stmtRollback.Exec();
end;

procedure TSQLiteDB.StartTransaction;
begin
  if not assigned(stmtStartTrans) then begin
    stmtStartTrans:=CreateStmt('BEGIN;');
  end;
  stmtStartTrans.Exec();
end;

{ ESQLite }

constructor ESQLite.Create(const ws: WideString; Code: integer);
begin
  inherited Create(ws);
  WideMessage := ws;
  SQLiteCode := Code;
end;

{ TSQLiteStmt }

procedure TSQLiteStmt.Bind(ParIds, ParValues: array of const);
var
  len, i, idx: integer;
begin
  len := length(ParIds);
  if (len <> length(ParValues)) then
    raise
      ESQLite.Create('TSQLiteStmt.Bind: Ids[] and values[] must be same length.',
      SQLITE_ERROR);
  if HasNext then
    Reset();
  for i := low(ParIds) to high(ParIds) do begin
    case ParIds[i].VType of
      vtAnsiString: begin
          idx := sqlite3_bind_parameter_index(hStmt, pAnsiChar(AnsiToUtf8(AnsiString(ParIds[i].VAnsiString))));
        end;
      vtInteger: idx := ParIds[i].VInteger;
      vtWideString: begin
           idx:=sqlite3_bind_parameter_index(hStmt,pAnsiChar(UTF8Encode(WideString(ParIds[i].VWideString))));
        end;
    else
      raise ESQLite.Create('TSQLiteStmt.Bind: Id has invalid type',
        SQLITE_ERROR);
    end;
    if (idx <= 0) then
      raise ESQLite.Create('TSQLiteStmt.Bind: Id not found',
        SQLITE_ERROR);
    case ParValues[i].VType of
      vtInteger: sqlite3_bind_int(hStmt, idx, ParValues[i].VInteger);
      vtInt64: sqlite3_bind_int64(hStmt, idx, ParValues[i].VInt64^);
      vtExtended: sqlite3_bind_double(hStmt, idx, ParValues[i].VExtended^);
      vtAnsiString: sqlite3_bind_text(hStmt, idx, ParValues[i].VAnsiString,
          length(AnsiString(ParValues[i].VAnsiString)), SQLITE_TRANSIENT);
      vtWideString: sqlite3_bind_text16(hStmt, idx, ParValues[i].VWideString,
          length(WideString(ParValues[i].VWideString)) * sizeof(WideChar),
          SQLITE_TRANSIENT);
    else
      raise ESQLite.Create('TSQLiteStmt.Bind: Value has invalid type',
        SQLITE_ERROR);
    end;
  end;
end;

procedure TSQLiteStmt.CheckColCount;
begin
  fColCount := SQLite3_ColumnCount(hStmt);
end;

constructor TSQLiteStmt.Create();
begin
  inherited;
  hStmt := nil;
  EOF := true;
  fColCount := 0;
end;

destructor TSQLiteStmt.Destroy;
begin
  if assigned(hStmt) then
    SQLite3_Finalize(hStmt);
  hStmt := nil;
  inherited Destroy;
end;

procedure TSQLiteStmt.Exec;
var
  r: integer;
begin
  if not EOF then
    raise ESQLite.Create('TSQLiteStmt.Exec: Pending query', SQLITE_ERROR);
  r := SQLite3_Step(hStmt);
  case r of
    SQLITE_DONE: begin
      Reset();
      fColCount:=0;
    end;
    SQLITE_ROW: begin
      EOF := false;
      CheckColCount();
    end;
  else
    raise ESQLite.Create('TSQLiteStmt.Exec', r);
  end;
end;

function TSQLiteStmt.getColName(i: integer): WideString;
begin
  CheckColCount();
  if (i<0) or (i>=ColCount) then
    raise ESQLite.Create('TSQLiteStmt.getColName: index out of bounds',SQLITE_ERROR);
  result:=UTF8Decode(SQLite3_ColumnName(hStmt,i));
end;

function TSQLiteStmt.GetColumn(i: integer): Variant;
var
  ct, ds: integer;
  pb, pb2: PByte;
  ws:WideString;
begin
  if (i >= fColCount) then
    raise ESQLite.Create('TSQLiteStmt.GetColumn: index out of bounds', SQLITE_ERROR);
  ct := SQLite3_ColumnType(hStmt, i);
    case ct of
    SQLITE_INTEGER: result := SQLite3_ColumnInt64(hStmt, i);
    SQLITE_FLOAT: result := SQLite3_ColumnDouble(hStmt, i);
    SQLITE_BLOB: begin
        ds := SQLite3_ColumnBytes(hStmt, i);
        result := VarArrayCreate([0, ds - 1], varByte);
        pb2 := SQLite3_ColumnBlob(hStmt, i);
        try
          pb := VarArrayLock(result);
          if ds > 0 then
            move(pb2^, pb^, ds);
        finally
          VarArrayUnlock(result);
        end;
      end;
    SQLITE_NULL: result := Null;
  else
    //SQLITE_TEXT and all other datatypes
    ws:=SQLite3_ColumnText16(hStmt, i);
    result :=ws;
  end;
end;

function TSQLiteStmt.GetHasNext: boolean;
begin
  result := not EOF;
end;

procedure TSQLiteStmt.Next;
var
  r: integer;
begin
  if EOF then
    raise ESQLite.Create('TSQLiteStmt.Next: no more data', SQLITE_ERROR);
  r := SQLite3_Step(hStmt);
  case r of
    SQLITE_DONE: begin
      Reset();
    end;
    SQLITE_ROW: EOF:=false;
  else
    raise ESQLite.Create('TSQLiteStmt.Next: step fail', r);
  end;
end;

procedure TSQLiteStmt.Reset;
begin
  SQLite3_Reset(hStmt);
  EOF:=true;
end;

end.

