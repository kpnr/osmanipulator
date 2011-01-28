unit uDB;

interface
uses
  Windows,uOSMCommon, Variants, SysUtils, Classes, Contnrs, uInterfaces, uModule, SQLiteObj,DBF;

implementation

const
  storageClassGUID: TGUID = '{91D72ED8-8FB3-4F62-A87C-650DFA1B9432}';
  dbfReaderClassGUID:TGUID= '{616CDC46-28E6-46FB-876F-623C867011D7}';

type
  TQueryResult = class(TOSManObject, IQueryResult)
  protected
    fQry: TSQLiteStmt;
    fOnClose: TNotifyEvent;
    procedure close();
  public
    function get_eos(): WordBool;
    destructor destroy; override;
  published
    //maxBufSize - number of rows to read
    function read(const maxBufSize: integer): OleVariant;
    //"true" if end of stream reached, "false" otherwise
    property eos: WordBool read get_eos;
    //returns SafeArray of string variants
    function getColNames(): OleVariant;
    //internal proc. Do not use
    procedure sqlExecInt(const paramNames, paramValues: OleVariant);
  end;

  TStoredIdList = class(TOSManObject, IStoredIdList)
  protected
    fStorage: OleVariant;
    fQryAdd: OleVariant;
    fQryIsIn: OleVariant;
    fQryDelete: OleVariant;
    fTableName: WideString;
    fTableCreated: boolean;
    function get_tableName: WideString;
    procedure createTable();
    procedure deleteTable();
  public
    destructor destroy; override;
    function get_storage():OleVariant;
    procedure set_storage(const aStorage:OleVariant);
  published
    function isIn(const id: int64): boolean;
    procedure add(const id: int64);
    procedure delete(const id: int64);
    property tableName: WideString read get_tableName;
    property storage:OleVariant read get_storage write set_storage;
  end;


  TStorage = class(TOSManObject, IStorage)
  protected
    fDBName: WideString;
    fDB: TSQLiteDB;
    fQryList:TObjectList;
    procedure onCloseQuery(query:TObject);
    procedure initDBMode();
    procedure close();
  public
    function get_dbName(): WideString;
    procedure set_dbName(const newName: WideString);
    destructor destroy; override;
  published
    //returns opaque Query object
    function sqlPrepare(const sqlProc: WideString): OleVariant;
    //sqlQuery - opaque Query object
    //paramsNames,paramValues - query parameters. SafeArray of variants.
    //returns IQueryResult object
    //It can do batch execution if length(ParamValues)==k*length(paramsNames) and k>=1.
    //In such case only last resultset returned
    function sqlExec(const sqlQuery: OleVariant; const paramNames, paramValues: OleVariant):
      OleVariant;
    //creates IStoredIdList object
    function createIdList():OleVariant;

    //database resource locator (file name, server name, etc).
    property dbName: WideString read get_dbName write set_dbName;
  end;

  TDBFReader=class(TOSManObject, IResourceInputStream,IStorageUser)
  protected
    fStorage:OleVariant;
    fDBF:TDBF;
  public
    function get_storage:OleVariant;
    procedure set_storage(const newStorage:OleVariant);
  published
    //URL - fs file name
    procedure open(const URL: WideString);

    //maxBufSize - file codepage
    //result undefined
    function read(const maxBufSize: integer): OleVariant;
    function get_eos(): WordBool;
    //"true" if end of stream reached, "false" otherwise
    property eos: WordBool read get_eos;

    property storage:OleVariant read get_storage write set_storage;
  end;
  { TStorage }

procedure TStorage.close;
begin
  if assigned(fQryList) then begin
    while(fQryList.Count>0)do
      TQueryResult(fQryList[fQryList.Count-1]).close();
  end;
  if assigned(fDB) then begin
    if fDB.IsInTransaction then
      fDB.Commit();
    FreeAndNil(fDB);
  end;
end;

function TStorage.createIdList: OleVariant;
var
  sil:TStoredIdList;
begin
  sil:=TStoredIdList.Create();
  sil.storage:=self as IDispatch;
  result:=sil as IDispatch;
end;

destructor TStorage.destroy;
begin
  if assigned(fDB) then begin
    close();
  end;
  inherited;
end;

function TStorage.get_dbName: WideString;
begin
  result := fDBName;
end;

procedure TStorage.initDBMode;

  procedure exec(const sql: WideString);
  var
    q: TSQLiteStmt;
  begin
    q := nil;
    try
      q := fDB.CreateStmt(sql);
      q.exec();
    finally
      if assigned(q) then
        FreeAndNil(q);
    end;
  end;
begin
  exec('PRAGMA page_size=4096');
  exec('PRAGMA encoding="UTF-8";');
  exec('PRAGMA journal_mode=off;');
  exec('PRAGMA synchronous=0 ;');
  exec('PRAGMA locking_mode=exclusive ;');
  exec('PRAGMA temp_store=1;');
  exec('PRAGMA fullfsync=0;');
  exec('PRAGMA recursive_triggers = 0');
  exec('PRAGMA cache_size = 32768');
  exec('PRAGMA default_cache_size = 32768');
  fDB.StartTransaction;
end;

procedure TStorage.onCloseQuery(query: TObject);
begin
  fQryList.Remove(query);
end;

procedure TStorage.set_dbName(const newName: WideString);
var
  newDB: TSQLiteDB;
begin
  if newName='' then begin
    close();
    fDBName := newName;
    exit;
  end;
  newDB := TSQLiteDB.Create();
  try
    newDB.Open(newName);
  except
    FreeAndNil(newDB);
    raise;
  end;
  if assigned(fDB) then
    close();
  fDB := newDB;
  fDBName := newName;
  initDBMode();
end;

function TStorage.sqlExec(const sqlQuery: OleVariant; const paramNames,
  paramValues: OleVariant): OleVariant;
begin
  sqlQuery.sqlExecInt(paramNames, paramValues);
  result := sqlQuery;
end;

function TStorage.sqlPrepare(const sqlProc: WideString): OleVariant;
var
  q: TSQLiteStmt;
  qr: TQueryResult;
begin
  q := fDB.CreateStmt(sqlProc);
  qr := TQueryResult.Create();
  qr.fQry := q;
  qr.fOnClose:=onCloseQuery;
  result := qr as IDispatch;
  if not assigned(fQryList) then
    fQryList:=TObjectList.Create(false);
  fQryList.Add(qr);
end;

{ TQueryResult }

destructor TQueryResult.destroy;
begin
  close();
  inherited;
end;

function TQueryResult.get_eos: WordBool;
begin
  result := (not assigned(fQry)) or (not fQry.HasNext);
end;

function TQueryResult.getColNames: OleVariant;
var
  i: integer;
begin
  result := VarArrayCreate([0, fQry.ColCount - 1], varVariant);
  for i := 0 to fQry.ColCount - 1 do begin
    VarArrayPut(Variant(result), fQry.ColName[i], [i]);
  end;
end;

function TQueryResult.read(const maxBufSize: integer): OleVariant;
var
  nc, rc, ci, ib: integer;
begin
  if assigned(fQry) then
    nc := fQry.ColCount
  else
    nc := 0;
  result := VarArrayCreate([0, nc * maxBufSize - 1], varVariant);
  if not assigned(fQry) then exit;
  rc := 0;
  ib := 0;
  while fQry.HasNext and (rc < maxBufSize) do begin
    for ci := 0 to nc - 1 do begin
      VarArrayPut(Variant(result), fQry.Column[ci], [ci + ib]);
    end;
    fQry.Next();
    inc(rc);
    inc(ib, nc);
  end;
  if rc < maxBufSize then
    VarArrayRedim(result, nc * rc - 1);
end;

procedure TQueryResult.sqlExecInt(const paramNames, paramValues: OleVariant);
var
  nLock, vLock: boolean;
  n, v: TVarRecArray;
  nl, vl, k, i: integer;
begin
  nLock := false;
  vLock := false;
  setLength(n, 0);
  setLength(v, 0);
  try
    if (VarArrayDimCount(paramNames) = 1) or (VarArrayDimCount(paramValues) = 1) then begin
      //bind parameters before exec
      if ((varType(paramNames) and varTypeMask) <> varVariant) or
        ((varType(paramValues) and varTypeMask) <> varVariant) then
        raise EConvertError.Create(toString() + '._sqlExec: array of variants expected');
      n := VarArrayLockVarRec(paramNames);
      nLock := true;
      v := VarArrayLockVarRec(paramValues);
      vLock := true;
      nl := length(n);
      vl := length(v);
      if not ((nl = vl) or //same size or empty
        ((nl > 0) and ((vl mod nl) = 0)) //not empty and vl=k*nl
        ) then
        raise ERangeError.Create(toString() + '._sqlExec: invalid arrays lengths');
      if nl = vl then begin
        //simple params. one call.
        fQry.Bind(n, v);
        fQry.exec();
      end
      else begin
        //batch query
        k := vl div nl;
        for i := 0 to k - 1 do begin
          fQry.Bind(n, copy(v, i * nl, nl));
          fQry.exec();
        end;
      end;
    end
    else
      //empty params, no bind
      fQry.exec();
  finally
    if nLock then
      VarArrayUnlockVarRec(paramNames, n);
    if vLock then
      VarArrayUnlockVarRec(paramValues, v);
  end;
end;

procedure TQueryResult.close;
begin
  if assigned(fQry) then
    FreeAndNil(fQry);
  if assigned(fOnClose) then
    fOnClose(self);
end;

{ TDBFReader }

function TDBFReader.get_storage: OleVariant;
begin
  result:=fStorage;
end;

function TDBFReader.get_eos: WordBool;
begin
  result:=not assigned(fDBF);
end;

procedure TDBFReader.open(const URL: WideString);
begin
  if assigned(fDBF) then
    raise EInOutError.Create(toString() + ': Open must be called only once');
  fDBF:=TDBF.Create(nil);
  fDBF.TableName:=URL;//bug - not Unicode aware
  fDBF.Open;
  fDBF.CodePage:=NONE;
end;

function TDBFReader.read(const maxBufSize: integer): OleVariant;
var
  nCol,i:integer;
  sAnsi:AnsiString;
  sQry,sInsQry,sTableName,sFieldName,sWide:WideString;
  vQry,vParNames,vParValues:OleVariant;
begin
  if not assigned(fDBF) then begin
    raise EInOutError.Create(toString()+': file must be opened before read');
  end;
  if not varIsType(fStorage,varDispatch) then
    raise EInOutError.Create(toString()+': storage not assigned');
  nCol:=fDBF.FieldCount;
  sTableName:=ChangeFileExt(ExtractFileName(fDBF.TableName),'');
  sQry:='DROP TABLE IF EXISTS "'+sTableName+'"';
  vQry:=fStorage.sqlPrepare(sQry);
  fStorage.sqlExec(vQry,0,0);
  sQry:='CREATE TABLE "'+sTableName+'" (';
  sInsQry:='INSERT INTO "'+sTableName+'" (';
  for i:=1 to nCol do begin
    sFieldName:=fDBF.GetFieldName(i);
    sQry:=sQry+'"'+sFieldName+'" ';
    case fDBF.GetFieldType(i) of
    bfBoolean,bfNumber: sQry:=sQry+'INTEGER';
    bfDate, bfFloat: sQry:=sQry+'FLOAT';
    bfString: sQry:=sQry+'TEXT';
    bfUnkown: sQry:=sQry+'BLOB';
    end;
    sInsQry:=sInsQry+'"'+sFieldName+'"';
    if i<nCol then begin
      sQry:=sQry+',';
      sInsQry:=sInsQry+',';
    end
    else begin
      sQry:=sQry+')';
      sInsQry:=sInsQry+')'
    end;
  end;
  vParNames:=VarArrayCreate([0,nCol-1],varVariant);
  vParValues:=VarArrayCreate([0,nCol-1],varVariant);
  sInsQry:=sInsQry+' VALUES (';
  for i:=1 to nCol do begin
    sInsQry:=sInsQry+':field'+inttostr(i-1);
    vParNames[i-1]:=':field'+inttostr(i-1);
    if i<nCol then begin
      sInsQry:=sInsQry+',';
    end
    else begin
      sInsQry:=sInsQry+')'
    end;
  end;
  vQry:=fStorage.sqlPrepare(sQry);
  fStorage.sqlExec(vQry,0,0);
  vQry:=fStorage.sqlPrepare(sInsQry);
  fDBF.First;
  while not fDBF.Eof do begin
    for i:=1 to nCol do begin
      sAnsi:=fDBF.GetFieldData(i);
      setlength(sWide,length(sAnsi)+1);
      setLength(sWide,MultiByteToWideChar(maxBufSize,0,pchar(sAnsi),length(sAnsi),PWideChar(sWide),length(sWide)));
      vParValues[i-1]:=sWide;
    end;
    fStorage.sqlExec(vQry,vParNames,vParValues);
    fDBF.Next;
  end;
  FreeAndNil(fDBF);
end;

procedure TDBFReader.set_storage(const newStorage: OleVariant);
begin
  fStorage:=newStorage;
end;

{ TStoredIdList }

procedure TStoredIdList.add(const id: int64);
begin
  if VarIsEmpty(fQryAdd) then begin
    createTable();
    fQryAdd := fStorage.sqlPrepare(
      'INSERT INTO ' + tableName + '(id) VALUES (:id)');
  end;
  fStorage.sqlExec(fQryAdd, VarArrayOf([':id']), VarArrayOf([id]));
end;

procedure TStoredIdList.createTable;
var
  q: OleVariant;
begin
  if fTableCreated then
    exit;
  q := fStorage.sqlPrepare(
    'CREATE TEMPORARY TABLE ' + tableName +
    '(id INTEGER PRIMARY KEY ON CONFLICT IGNORE)');
  fStorage.sqlExec(q, 0, 0);
  fTableCreated := true;
end;

procedure TStoredIdList.delete(const id: int64);
begin
  if VarIsEmpty(fQryDelete) then begin
    createTable();
    fQryDelete := fStorage.sqlPrepare(
      'DELETE FROM ' + tableName + ' WHERE id=:id');
  end;
  fStorage.sqlExec(fQryDelete, VarArrayOf([':id']), VarArrayOf([id]));
end;

procedure TStoredIdList.deleteTable;
var
  q: OleVariant;
begin
  if not fTableCreated then exit;
  q := fStorage.sqlPrepare('DROP TABLE ' + tableName);
  fStorage.sqlExec(q, 0, 0);
  fTableCreated := false;
end;

destructor TStoredIdList.destroy;
begin
  storage:=unassigned;
  inherited;
end;

function TStoredIdList.get_storage: OleVariant;
begin
  result:=fStorage;
end;

function TStoredIdList.get_tableName: WideString;
begin
  if fTableName = '' then
    fTableName := 'idlist' + IntToStr(getUID);
  result := fTableName;
end;

function TStoredIdList.isIn(const id: int64): boolean;
var
  i: integer;
begin
  if VarIsEmpty(fQryIsIn) then begin
    createTable();
    fQryIsIn := fStorage.sqlPrepare('SELECT COUNT(1) FROM ' + tableName +
      ' WHERE id=:id');
  end;
  i := fStorage.sqlExec(fQryIsIn, VarArrayOf([':id']), VarArrayOf([id])).read(1)[0];
  result := i > 0;
end;

procedure TStoredIdList.set_storage(const aStorage: OleVariant);
begin
  fQryAdd := unassigned;
  fQryIsIn := unassigned;
  deleteTable();
  fQryDelete := unassigned;
  fStorage := aStorage;
  if VarIsType(fStorage,varDispatch) then begin
    createTable();
  end;
end;

initialization
  OSManRegister(TStorage, storageClassGUID);
  OSManRegister(TDBFReader,dbfReaderClassGUID);
end.

