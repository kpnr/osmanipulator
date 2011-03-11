unit uDB;

interface
uses
  Windows, uOSMCommon, Variants, SysUtils, Classes, Contnrs, uInterfaces,
  uModule, SQLite3, SQLiteObj, DBF;

implementation

uses Math;

const
  storageClassGUID: TGUID = '{91D72ED8-8FB3-4F62-A87C-650DFA1B9432}';
  dbfReaderClassGUID: TGUID = '{616CDC46-28E6-46FB-876F-623C867011D7}';

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
    function get_storage(): OleVariant;
    procedure set_storage(const aStorage: OleVariant);
  published
    function isIn(const id: int64): boolean;
    procedure add(const id: int64);
    procedure delete(const id: int64);
    property tableName: WideString read get_tableName;
    property storage: OleVariant read get_storage write set_storage;
  end;

  TStorage = class(TOSManObject, IStorage)
  protected
    fDBName: WideString;
    fDB: TSQLiteDB;
    fQryList: TObjectList;
    fReadOnly: boolean;
    procedure exec(const sql: WideString);
    procedure onCloseQuery(query: TObject);
    procedure initDBMode();
    procedure close();
  public
    function get_dbName(): WideString;
    procedure set_dbName(const newName: WideString);
    function get_readOnly(): boolean;
    procedure set_readOnly(roFlag: boolean);

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
    function createIdList(): OleVariant;
    //initialize new storage - create database schema (tables, indexes, triggers...)
    procedure initSchema();

    //set this property before open to use db in readonly mode
    property readOnly: boolean read get_readOnly write set_readOnly;
    //database resource locator (file name, server name, etc).
    property dbName: WideString read get_dbName write set_dbName;
  end;

  TDBFReader = class(TOSManObject, IResourceInputStream, IStorageUser)
  protected
    fStorage: OleVariant;
    fDBF: TDBF;
  public
    function get_storage: OleVariant;
    procedure set_storage(const newStorage: OleVariant);
  published
    //URL - fs file name
    procedure open(const URL: WideString);

    //maxBufSize - file codepage
    //result undefined
    function read(const maxBufSize: integer): OleVariant;
    function get_eos(): WordBool;
    //"true" if end of stream reached, "false" otherwise
    property eos: WordBool read get_eos;

    property storage: OleVariant read get_storage write set_storage;
  end;
  { TStorage }

procedure TStorage.close;
begin
  if assigned(fQryList) then begin
    while (fQryList.Count > 0) do
      TQueryResult(fQryList[fQryList.Count - 1]).close();
  end;
  if assigned(fDB) then begin
    if fDB.IsInTransaction then
      fDB.Commit();
    FreeAndNil(fDB);
  end;
end;

function TStorage.createIdList: OleVariant;
var
  sil: TStoredIdList;
begin
  sil := TStoredIdList.Create();
  sil.storage := self as IDispatch;
  result := sil as IDispatch;
end;

destructor TStorage.destroy;
begin
  if assigned(fDB) then begin
    close();
  end;
  inherited;
end;

procedure TStorage.exec(const sql: WideString);
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

function TStorage.get_dbName: WideString;
begin
  result := fDBName;
end;

function TStorage.get_readOnly: boolean;
begin
  result := fReadOnly;
end;

procedure TStorage.initDBMode;
begin
  exec('PRAGMA page_size=4096');
  exec('PRAGMA encoding="UTF-8";');
  exec('PRAGMA journal_mode=off;');
  exec('PRAGMA synchronous=0 ;');
  if not readOnly then begin
    exec('PRAGMA locking_mode=exclusive ;');
    exec('PRAGMA default_cache_size = 32768');
  end;
  exec('PRAGMA temp_store=1;');
  exec('PRAGMA fullfsync=0;');
  exec('PRAGMA recursive_triggers = 0');
  exec('PRAGMA cache_size = 32768');
  fDB.StartTransaction;
end;

procedure TStorage.initSchema;
begin
  exec('DROP TABLE IF EXISTS users');
  exec('CREATE TABLE IF NOT EXISTS users (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'name VARCHAR(40) NOT NULL)');

  exec('DROP TABLE IF EXISTS nodes_attr');
  exec('CREATE TABLE IF NOT EXISTS nodes_attr (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'version INTEGER DEFAULT 1 NOT NULL,' +
    'timestamp VARCHAR(20),' +
    'userId INTEGER DEFAULT 0,' +
    'changeset BIGINT)');

  exec('DROP TABLE IF EXISTS nodes_latlon');
  exec('CREATE VIRTUAL TABLE nodes_latlon USING rtree_i32(id,minlat,maxlat,minlon,maxlon)');

  exec('DROP VIEW IF EXISTS nodes');
  exec('CREATE VIEW IF NOT EXISTS nodes AS SELECT nodes_latlon.id as id,' +
    'nodes_latlon.minlat as lat, nodes_latlon.minlon as lon,' +
    'nodes_attr.version as version, nodes_attr.timestamp as timestamp,' +
    'nodes_attr.userId as userId, nodes_attr.changeset as changeset ' +
    'FROM nodes_attr, nodes_latlon WHERE nodes_attr.id=nodes_latlon.id');

  exec('DROP TRIGGER IF EXISTS nodes_ii');
  exec('CREATE TRIGGER IF NOT EXISTS nodes_ii INSTEAD OF INSERT ON nodes BEGIN ' +
    'INSERT INTO nodes_attr (id, version, timestamp, userId, changeset) ' +
    'VALUES (NEW.id,NEW.version, NEW.timestamp, NEW.userId, NEW.changeset);' +
    'INSERT INTO nodes_latlon(id,minlat,maxlat,minlon,maxlon)' +
    'VALUES (NEW.id, NEW.lat, NEW.lat, NEW.lon, NEW.lon);' +
    'END;');

  exec('DROP TRIGGER IF EXISTS nodes_iu');
  exec('CREATE TRIGGER IF NOT EXISTS nodes_iu INSTEAD OF UPDATE ON nodes BEGIN ' +
    'UPDATE nodes_attr SET id=NEW.id, version=NEW.version, timestamp=NEW.timestamp, userId=NEW.userID, changeset=NEW.changeset WHERE id=OLD.id;' +
    'UPDATE nodes_latlon SET id=NEW.id,minlat=NEW.lat,maxlat=NEW.lat,minlon=NEW.lon,maxlon=NEW.lon WHERE id=NEW.id;' +
    'UPDATE objtags SET objid=NEW.id*4 WHERE objid=4*OLD.id;' +
    'END;');

  exec('DROP TRIGGER IF EXISTS nodes_id');
  exec('CREATE TRIGGER IF NOT EXISTS nodes_id INSTEAD OF DELETE ON nodes BEGIN ' +
    'DELETE FROM nodes_attr WHERE id=OLD.id;' +
    'DELETE FROM nodes_latlon WHERE id=OLD.id;' +
    'DELETE FROM objtags WHERE objid=4*OLD.id;' +
    'END;');

  exec('DROP VIEW IF EXISTS strnodes');
  exec('CREATE VIEW IF NOT EXISTS strnodes AS ' +
    'SELECT nodes_attr.id AS id, minlat AS lat, minlon AS lon, version AS version, ' +
    'timestamp AS timestamp, userId as userId, users.name AS userName, changeset as changeset ' +
    'FROM nodes_attr,nodes_latlon,users ' +
    'WHERE nodes_attr.id=nodes_latlon.id AND nodes_attr.userId=users.id');
  exec('CREATE TRIGGER IF NOT EXISTS strnodes_ii INSTEAD OF INSERT ON strnodes BEGIN ' +
    'DELETE FROM nodes_latlon WHERE id=NEW.id;'+
    'DELETE FROM objtags WHERE objid=0+NEW.id*4;'+
    'INSERT OR IGNORE INTO users (id, name) VALUES (NEW.userID, NEW.userName);' +
    'INSERT OR REPLACE INTO nodes_attr (id,version,timestamp,userId,changeset) ' +
    'VALUES (NEW.id,NEW.version,NEW.timestamp,NEW.userId,NEW.changeset);' +
    'INSERT INTO nodes_latlon(id,minlat,maxlat,minlon,maxlon)' +
    'VALUES (NEW.id,NEW.lat,NEW.lat,NEW.lon,NEW.lon);' +
    'END;');

  exec('DROP TABLE IF EXISTS tags');
  exec('CREATE TABLE IF NOT EXISTS tags(' +
    'id INTEGER NOT NULL CONSTRAINT tags_pk PRIMARY KEY AUTOINCREMENT,' +
    'tagname VARCHAR(50) CONSTRAINT tags_tagname_c COLLATE BINARY,' +
    'tagvalue VARCHAR(150) CONSTRAINT tags_tagvalue_c COLLATE BINARY' +
    ')');
  exec('CREATE UNIQUE INDEX IF NOT EXISTS tags_tagname_tagvalue_i ' +
    'ON tags(tagname,tagvalue)');

  exec('DROP TABLE IF EXISTS objtags');
  exec('CREATE TABLE IF NOT EXISTS objtags(' +
    'objid BIGINT NOT NULL /* =id*4 + (0 for node, 1 for way, 2 for relation) */,' +
    'tagid BIGINT NOT NULL,' +
    'CONSTRAINT objtags_pk PRIMARY KEY (objid,tagid)' +
    ')');
  exec('CREATE INDEX objtags_tagid_i ON objtags(tagid)');

  exec('DROP VIEW IF EXISTS strobjtags');
  exec('CREATE VIEW strobjtags AS ' +
    'SELECT objid AS ''objid'',tagname AS ''tagname'',tagvalue AS ''tagvalue'' ' +
    'FROM objtags,tags WHERE objtags.tagid=tags.id');
  exec('CREATE TRIGGER strobjtags_ii INSTEAD OF INSERT ON strobjtags BEGIN ' +
    'INSERT OR IGNORE INTO tags (tagname, tagvalue) ' +
    'VALUES (NEW.tagname,NEW.tagvalue);' +
    'INSERT OR IGNORE INTO objtags(objid,tagid) ' +
    'VALUES (NEW.objid,(SELECT id FROM tags WHERE tags.tagname=NEW.tagname AND tags.tagvalue=NEW.tagvalue));' +
    'END;');

  exec('DROP TABLE IF EXISTS waynodes');
  exec('CREATE TABLE IF NOT EXISTS waynodes (' +
    'wayid INTEGER NOT NULL,' +
    'nodeidx INTEGER NOT NULL,' +
    'nodeid INTEGER NOT NULL,' +
    'PRIMARY KEY (wayid,nodeidx))');
  exec('CREATE INDEX IF NOT EXISTS waynodes_nodeid_i ON waynodes (nodeid)');

  exec('DROP TABLE IF EXISTS ways');
  exec('CREATE TABLE IF NOT EXISTS ways (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'version INTEGER DEFAULT 1 NOT NULL,' +
    'timestamp VARCHAR(20),' +
    'userId INTEGER DEFAULT 0,' +
    'changeset BIGINT)');
  exec('CREATE TRIGGER IF NOT EXISTS ways_bu BEFORE UPDATE ON ways BEGIN ' +
    'UPDATE objtags SET objid=1+4*NEW.id WHERE objid=1+4*OLD.id;' +
    'UPDATE waynodes SET wayid=NEW.id WHERE wayid=OLD.id;' +
    'END');
  exec('CREATE TRIGGER ways_bd BEFORE DELETE ON ways BEGIN ' +
    'DELETE FROM objtags WHERE objid=1+4*OLD.id;' +
    'DELETE FROM waynodes WHERE wayid=OLD.id;' +
    'END');

  exec('DROP VIEW IF EXISTS strways');
  exec('CREATE VIEW IF NOT EXISTS strways AS ' +
    'SELECT ways.id AS id, version AS version, ' +
    'timestamp AS timestamp, userId as userId, users.name AS userName, changeset as changeset ' +
    'FROM ways,users WHERE ways.userId=users.id');
  exec('CREATE TRIGGER IF NOT EXISTS strways_ii INSTEAD OF INSERT ON strways BEGIN ' +
    'DELETE FROM objtags WHERE objid=1+NEW.id*4;'+
    'DELETE FROM waynodes WHERE wayid=NEW.id;'+
    'INSERT OR IGNORE INTO users (id, name) VALUES (NEW.userId, NEW.userName);' +
    'INSERT OR REPLACE INTO ways (id,version,timestamp,userId,changeset) ' +
    'VALUES(NEW.id,NEW.version,NEW.timestamp,NEW.userId,NEW.changeset);' +
    'END;');

  exec('DROP TABLE IF EXISTS relationmembers');
  exec('CREATE TABLE IF NOT EXISTS relationmembers(' +
    'relationid INTEGER NOT NULL,' +
    'memberidxtype INTEGER NOT NULL,/*=index*4+(0 for node, 1 for way, 2 for relation)*/' +
    'memberid INTEGER NOT NULL,' +
    'memberrole VARCHAR(20) DEFAUlT '''',' +
    'PRIMARY KEY (relationid,memberidxtype))');
  exec('CREATE INDEX IF NOT EXISTS relationmembers_memberid_i ON relationmembers(memberid)');

  exec('DROP VIEW IF EXISTS strrelationmembers');
  exec('CREATE VIEW IF NOT EXISTS strrelationmembers AS ' +
    'SELECT relationid AS relationid, ' +
    '(memberidxtype>>2) AS memberidx,' +
    '(CASE (memberidxtype & 3) WHEN 0 THEN ''node'' WHEN 1 THEN ''way'' WHEN 2 THEN ''relation'' ELSE '''' END) AS membertype,' +
    'memberid AS memberid,' +
    'memberrole AS memberrole ' +
    'FROM relationmembers');
  exec('CREATE TRIGGER IF NOT EXISTS strrelationmembers_ii INSTEAD OF INSERT ON strrelationmembers BEGIN '
    +
    'INSERT OR REPLACE INTO relationmembers (relationid,memberidxtype,memberid,memberrole) ' +
    'VALUES(NEW.relationid,' +
    'NEW.memberidx*4+(CASE NEW.membertype WHEN ''node'' THEN 0 WHEN ''way'' THEN 1 WHEN ''relation'' THEN 2 ELSE 3 END),' +
    'NEW.memberid,' +
    'NEW.memberrole);' +
    'END;');

  exec('DROP TABLE IF EXISTS relations');
  exec('CREATE TABLE IF NOT EXISTS relations (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'version INTEGER DEFAULT 1 NOT NULL,' +
    'timestamp VARCHAR(20),' +
    'userId INTEGER DEFAULT 0,' +
    'changeset BIGINT)');
  exec('CREATE TRIGGER IF NOT EXISTS relations_bu BEFORE UPDATE ON relations BEGIN ' +
    'UPDATE objtags SET objid=2+4*NEW.id WHERE objid=2+4*OLD.id;' +
    'UPDATE relationmembers SET relationid=NEW.id WHERE relationid=OLD.id;' +
    'END');
  exec('CREATE TRIGGER relations_bd BEFORE DELETE ON relations BEGIN ' +
    'DELETE FROM objtags WHERE objid=2+4*OLD.id;' +
    'DELETE FROM relationmembers WHERE relationid=OLD.id;' +
    'END');

  exec('DROP VIEW IF EXISTS strrelations');
  exec('CREATE VIEW IF NOT EXISTS strrelations AS ' +
    'SELECT relations.id AS id, version AS version, ' +
    'timestamp AS timestamp, userId as userId, users.name AS userName, changeset as changeset ' +
    'FROM relations,users WHERE relations.userId=users.id');
  exec('CREATE TRIGGER IF NOT EXISTS strrelations_ii INSTEAD OF INSERT ON strrelations BEGIN ' +
    'DELETE FROM objtags WHERE objid=2+NEW.id*4;'+
    'DELETE FROM relationmembers WHERE relationid=NEW.id;'+
    'INSERT OR IGNORE INTO users (id, name) VALUES (NEW.userId, NEW.userName);' +
    'INSERT OR REPLACE INTO relations (id,version,timestamp,userId,changeset) ' +
    'VALUES(NEW.id,NEW.version,NEW.timestamp,NEW.userId,NEW.changeset);' +
    'END;');
end;

procedure TStorage.onCloseQuery(query: TObject);
begin
  fQryList.Remove(query);
end;

procedure TStorage.set_dbName(const newName: WideString);
var
  newDB: TSQLiteDB;
begin
  if newName = '' then begin
    close();
    fDBName := newName;
    exit;
  end;
  newDB := TSQLiteDB.Create();
  try
    if readOnly then
      newDB.open(newName, SQLITE_OPEN_READONLY)
    else
      newDB.open(newName);
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

procedure TStorage.set_readOnly(roFlag: boolean);
begin
  if (roFlag <> fReadOnly) and assigned(fDB) then begin
    raise EInOutError.Create(toString + '.set_readOnly: can not change on opened database');
  end;
  fReadOnly := roFlag;
end;

function TStorage.sqlExec(const sqlQuery: OleVariant; const paramNames,
  paramValues: OleVariant): OleVariant;
var
  n, v: OleVariant;
begin
  n := varFromJsObject(paramNames);
  v := varFromJsObject(paramValues);
  if (not VarIsArray(n)) and VarIsStr(n) and ('' <> n) then begin
    n := VarArrayOf([n]);
    if not VarIsArray(v) then begin
      v := VarArrayOf([v]);
    end;
  end;
  sqlQuery.sqlExecInt(n, v);
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
  qr.fOnClose := onCloseQuery;
  result := qr as IDispatch;
  if not assigned(fQryList) then
    fQryList := TObjectList.Create(false);
  fQryList.add(qr);
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
  nc, rc, ci: integer;
  pv: POleVariant;
begin
  if assigned(fQry) then
    nc := fQry.ColCount
  else
    nc := 0;
  result := VarArrayCreate([0, nc * maxBufSize - 1], varVariant);
  if not assigned(fQry) then exit;
  rc := 0;
  pv := VarArrayLock(result);
  try
    while fQry.HasNext and (rc < maxBufSize) do begin
      for ci := 0 to nc - 1 do begin
        pv^ := fQry.Column[ci];
        inc(pv);
      end;
      fQry.Next();
      inc(rc);
    end;
  finally
    varArrayUnlock(result);
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
  result := fStorage;
end;

function TDBFReader.get_eos: WordBool;
begin
  result := not assigned(fDBF);
end;

procedure TDBFReader.open(const URL: WideString);
begin
  if assigned(fDBF) then
    raise EInOutError.Create(toString() + ': Open must be called only once');
  fDBF := TDBF.Create(nil);
  fDBF.tableName := URL; //bug - not Unicode aware
  fDBF.open;
  fDBF.CodePage := NONE;
end;

function TDBFReader.read(const maxBufSize: integer): OleVariant;
var
  nCol, i: integer;
  sAnsi: AnsiString;
  sQry, sInsQry, sTableName, sFieldName, sWide: WideString;
  vQry, vParNames, vParValues: OleVariant;
begin
  if not assigned(fDBF) then begin
    raise EInOutError.Create(toString() + ': file must be opened before read');
  end;
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.Create(toString() + ': storage not assigned');
  nCol := fDBF.FieldCount;
  sTableName := ChangeFileExt(ExtractFileName(fDBF.tableName), '');
  sQry := 'DROP TABLE IF EXISTS "' + sTableName + '"';
  vQry := fStorage.sqlPrepare(sQry);
  fStorage.sqlExec(vQry, 0, 0);
  sQry := 'CREATE TABLE "' + sTableName + '" (';
  sInsQry := 'INSERT INTO "' + sTableName + '" (';
  for i := 1 to nCol do begin
    sFieldName := fDBF.GetFieldName(i);
    sQry := sQry + '"' + sFieldName + '" ';
    case fDBF.GetFieldType(i) of
      bfBoolean, bfNumber: sQry := sQry + 'INTEGER';
      bfDate, bfFloat: sQry := sQry + 'FLOAT';
      bfString: sQry := sQry + 'TEXT';
      bfUnkown: sQry := sQry + 'BLOB';
    end;
    sInsQry := sInsQry + '"' + sFieldName + '"';
    if i < nCol then begin
      sQry := sQry + ',';
      sInsQry := sInsQry + ',';
    end
    else begin
      sQry := sQry + ')';
      sInsQry := sInsQry + ')'
    end;
  end;
  vParNames := VarArrayCreate([0, nCol - 1], varVariant);
  vParValues := VarArrayCreate([0, nCol - 1], varVariant);
  sInsQry := sInsQry + ' VALUES (';
  for i := 1 to nCol do begin
    sInsQry := sInsQry + ':field' + inttostr(i - 1);
    vParNames[i - 1] := ':field' + inttostr(i - 1);
    if i < nCol then begin
      sInsQry := sInsQry + ',';
    end
    else begin
      sInsQry := sInsQry + ')'
    end;
  end;
  vQry := fStorage.sqlPrepare(sQry);
  fStorage.sqlExec(vQry, 0, 0);
  vQry := fStorage.sqlPrepare(sInsQry);
  fDBF.First;
  while not fDBF.Eof do begin
    for i := 1 to nCol do begin
      sAnsi := fDBF.GetFieldData(i);
      setLength(sWide, length(sAnsi) + 1);
      setLength(sWide, MultiByteToWideChar(maxBufSize, 0, pchar(sAnsi), length(sAnsi),
        PWideChar(sWide), length(sWide)));
      vParValues[i - 1] := sWide;
    end;
    fStorage.sqlExec(vQry, vParNames, vParValues);
    fDBF.Next;
  end;
  FreeAndNil(fDBF);
end;

procedure TDBFReader.set_storage(const newStorage: OleVariant);
begin
  fStorage := newStorage;
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
  storage := unassigned;
  inherited;
end;

function TStoredIdList.get_storage: OleVariant;
begin
  result := fStorage;
end;

function TStoredIdList.get_tableName: WideString;
begin
  if fTableName = '' then
    fTableName := 'idlist' + inttostr(getUID);
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
  if varIsType(fStorage, varDispatch) then begin
    createTable();
  end;
end;

initialization
  OSManRegister(TStorage, storageClassGUID);
  OSManRegister(TDBFReader, dbfReaderClassGUID);
end.

