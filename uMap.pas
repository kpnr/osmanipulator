unit uMap;
interface
uses SysUtils, Variants, uGeoTools, ActiveX, uModule, uOSMCommon, uInterfaces;

type
  TAbstractMap = class(TOSManObject, IMap)
  protected
    fStorage: OleVariant;
  public
    function get_storage: OleVariant; virtual;
    procedure set_storage(const newStorage: OleVariant); virtual;
    function get_onPutFilter: OleVariant; virtual; abstract;
    procedure set_onPutFilter(const aFilter: OleVariant); virtual; abstract;
  published
    //create epmty node
    function createNode(): IDispatch; virtual;
    //create epmty way
    function createWay(): IDispatch; virtual;
    //create epmty relation
    function createRelation(): IDispatch; virtual;

    //store Node into Storage
    procedure putNode(const aNode: OleVariant); virtual; abstract;
    //store Way into Storage
    procedure putWay(const aWay: OleVariant); virtual; abstract;
    //store Relation into Storage
    procedure putRelation(const aRelation: OleVariant); virtual; abstract;
    //store MapObject (Node,Way or Relation) into Store
    procedure putObject(const aObj: OleVariant); virtual;

    //delete Node and its tags from Storage
    procedure deleteNode(const nodeId: int64); virtual; abstract;
    //delete Way, its tags and node-list from Storage
    procedure deleteWay(const wayId: int64); virtual; abstract;
    //delete Relation, its tags and ref-list from Storage
    procedure deleteRelation(const relationId: int64); virtual; abstract;

    //get node by ID. If no node found returns false
    function getNode(const id: int64): OleVariant; virtual; abstract;
    //get way by ID. If no way found returns false
    function getWay(const id: int64): OleVariant; virtual; abstract;
    //get relation by ID. If no relation found returns false
    function getRelation(const id: int64): OleVariant; virtual; abstract;

    //get filtered object set
    function getObjects(const filterOptions: OleVariant): OleVariant; virtual; abstract;

    //IMapOnPutFilter
    property onPutFilter: OleVariant read get_onPutFilter write set_onPutFilter;

    //initialize new storage - drop and create tables
    procedure initStorage(); virtual; abstract;

    //set storage. Suppoted storage interface see in descendants. To free
    //  system resource set storage to unassigned.
    property storage: OleVariant read get_storage write set_storage;
  end;
implementation

const
  mapClassGuid: TGuid = '{7B3FBE69-1232-4C22-AAF5-C649EFB89981}';

type

  TTags = class(TOSManObject, IKeyList)
  protected
    fKeys, fValues: array of WideString;
    fCount: integer;
    procedure grow();
  public
    function get_count: integer;
  published
    //delete item by key. If no such key, no actions performed
    procedure deleteByKey(const key: WideString);
    //delete item by index in list. If index out of bounds then exception raised
    procedure deleteById(const id: integer);
    //get all keys in list. Result is SafeArray of string variants.
    //Keys and Values interlived - [0]=key[0],[1]=value[0]...[10]=key[5],[11]=value[5],...
    function getAll: OleVariant;
    //add items to list. On key conflict replaces old value with new one.
    //kvArray interlived as in getAll() method
    procedure setAll(const kvArray: OleVariant);
    //returns true if key exists in list.
    function hasKey(const key: WideString): WordBool;
    //returns value assiciated with key. If no such key empty string('') returned
    function getByKey(const key: WideString): WideString;
    //add or replace key-value pair
    procedure setByKey(const key: WideString; const value: WideString);
    //returns value by index. If index out of bounds [0..count-1] exception raised
    function getValue(const id: integer): WideString;
    //sets value by index. If index out of bounds [0..count-1] exception raised
    procedure setValue(const id: integer; const value: WideString);
    //returns key by index. If index out of bounds [0..count-1] exception raised
    function getKey(const id: integer): WideString;
    //sets key by index. If index out of bounds [0..count-1] exception raised
    procedure setKey(const id: integer; const key: WideString);

    //returns number of pairs in list
    property count: integer read get_count;
  end;

  TMapObject = class(TOSManObject, IMapObject)
  protected
    //IKeyList
    fTags: OleVariant;
    fId, fChangeset: int64;
    fVersion, fUserId: integer;
    fUserName, fTimeStamp: WideString;
  public
    function get_tags: OleVariant;
    procedure set_tags(const newTags: OleVariant);
    function get_id: int64;
    procedure set_id(const newId: int64);
    function get_version: integer;
    procedure set_version(const newVersion: integer);
    function get_userId: integer;
    procedure set_userId(const newUserId: integer);
    function get_userName: WideString;
    procedure set_userName(const newUserName: WideString);
    function get_changeset: int64;
    procedure set_changeset(const newChangeset: int64);
    function get_timestamp: WideString;
    procedure set_timestamp(const newTimeStamp: WideString);
  published
    //tags, associated with object. Supports IKeyList
    property tags: OleVariant read get_tags write set_tags;
    //OSM object ID.
    property id: int64 read get_id write set_id;
    //OSM object version
    property version: integer read get_version write set_version;
    //OSM object userID
    property userId: integer read get_userId write set_userId;
    //OSM object userName
    property userName: WideString read get_userName write set_userName;
    //OSM object changeset
    property changeset: int64 read get_changeset write set_changeset;
    //OSM object timestamp. Format "yyyy-mm-ddThh:nn:ssZ" like in OSM files
    property timestamp: WideString read get_timestamp write set_timestamp;
  end;

  TNode = class(TMapObject, INode)
  protected
    fLat, fLon: integer;
  public
    function get_lat: double;
    procedure set_lat(const value: double);
    function get_lon: double;
    procedure set_lon(const value: double);
  published
    //node latitude. If out of bounds [-90...+90] exception raised
    property lat: double read get_lat write set_lat;
    //node longitude. If out of bounds [-180...180] exception raised
    property lon: double read get_lon write set_lon;
  end;

  TWay = class(TMapObject, IWay)
  protected
    fNodes: array of int64;
  public
    function get_nodes: OleVariant;
    procedure set_nodes(const newNodes: OleVariant);

  published
    //array of node OSM IDs. SafeArray of Int64 variants
    property nodes: OleVariant read get_nodes write set_nodes;
  end;

  TRelation = class(TMapObject, IRelation)
  protected
    fMembers: OleVariant;
  public
    function get_members: OleVariant;
    procedure set_members(const newMembers: OleVariant);
    constructor create(); override;
  published
    //list of relation members. Supports IRefList
    property members: OleVariant read get_members write set_members;
  end;

  TMap = class(TAbstractMap)
  protected
    fQryPutNode,
      fQryPutWay, fQryPutWayNode,
      fQryPutRelation, fQryPutRelationMember,
      fQryPutObjTag,
      fQryDeleteNode, fQryDeleteWay, fQryDeleteRelation,
      fQryGetNode,
      fQryGetWay, fQryGetWayNodes,
      fQryGetRelation, fQryGetRelationMembers: OleVariant;
    fOnPutFilter: TPutFilterAdaptor;
    procedure putTags(const objId: int64; const objType: byte {0-node,1-way,2-relation};
      const tagNamesValuesInterlived: OleVariant);
    function doOnPutNode(const aNode: OleVariant): boolean;
    function doOnPutWay(const aWay: OleVariant): boolean;
    function doOnPutRelation(const aRelation: OleVariant): boolean;
  public
    procedure set_storage(const newStorage: OleVariant); override;
    function get_onPutFilter: OleVariant; override;
    procedure set_onPutFilter(const aFilter: OleVariant); override;
    destructor destroy; override;
  published

    //store Node into Storage
    procedure putNode(const aNode: OleVariant); override;
    //store Way into Storage
    procedure putWay(const aWay: OleVariant); override;
    //store Relation into Storage
    procedure putRelation(const aRelation: OleVariant); override;

    //delete Node and its tags from Storage
    procedure deleteNode(const nodeId: int64); override;
    //delete Way, its tags and node-list from Storage
    procedure deleteWay(const wayId: int64); override;
    //delete Relation, its tags and ref-list from Storage
    procedure deleteRelation(const relationId: int64); override;

    //get node by ID. If no node found returns false
    function getNode(const id: int64): OleVariant; override;
    //get way by ID. If no way found returns false
    function getWay(const id: int64): OleVariant; override;
    //get relation by ID. If no relation found returns false
    function getRelation(const id: int64): OleVariant; override;

    //get filtered object set
    function getObjects(const filterOptions: OleVariant): OleVariant; override;

    //IMapOnPutFilter
    property onPutFilter: OleVariant read get_onPutFilter write set_onPutFilter;

    //set SQL-storage (IStorage). To free system resource set storage to unassigned
    //property storage:OleVariant read get_storage write set_storage;
  end;

  TMapObjectStream = class(TOSManObject, IInputStream)
  protected
    fMap: TMap;
    fStorage, fQry: OleVariant;
    fBPolies: array of OleVariant;
    fCustomFilters: array of TPutFilterAdaptor;
    fNodeList, fWayList, fRelList, fToDoRelList: OleVariant;
    fNodeSelectCondition: WideString;
    fOutMode: TRefType;
    fEOS: boolean;
    fClipIncompleteWays: boolean;
    //read one object
    function read1: OleVariant;
    procedure set_eos(const aEOS: boolean);
  public
    procedure initialize(const aMap: TMap; const aStorage, aFilter: OleVariant);
    constructor create(); override;
    destructor destroy(); override;
  published
    //maxBufSize: read buffer size
    //Readed data in zero-based one dimensional SafeArray of MapObjects
    function read(const maxBufSize: integer): OleVariant;
    function get_eos(): WordBool;
    //"true" if end of stream reached, "false" otherwise
    property eos: WordBool read get_eos;
  end;

  { TMap }

procedure TMap.deleteNode(const nodeId: int64);
begin
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.deleteNode: storage not assigned');
  if VarIsEmpty(fQryDeleteNode) then begin
    fQryDeleteNode := fStorage.sqlPrepare(
      'DELETE FROM nodes WHERE id=:id');
  end;
  fStorage.sqlExec(fQryDeleteNode, VarArrayOf([':id']),
    VarArrayOf([nodeId]));
end;

procedure TMap.deleteRelation(const relationId: int64);
begin
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.deleteRelation: storage not assigned');
  if VarIsEmpty(fQryDeleteRelation) then begin
    fQryDeleteRelation := fStorage.sqlPrepare(
      'DELETE FROM relations WHERE id=:id');
  end;
  fStorage.sqlExec(fQryDeleteRelation, VarArrayOf([':id']),
    VarArrayOf([relationId]));
end;

procedure TMap.deleteWay(const wayId: int64);
begin
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.deleteWay: storage not assigned');
  if VarIsEmpty(fQryDeleteWay) then begin
    fQryDeleteWay := fStorage.sqlPrepare(
      'DELETE FROM ways WHERE id=:id');
  end;
  fStorage.sqlExec(fQryDeleteWay, VarArrayOf([':id']),
    VarArrayOf([wayId]));
end;

destructor TMap.destroy;
begin
  FreeAndNil(fOnPutFilter);
  inherited;
end;

function TMap.doOnPutNode(const aNode: OleVariant): boolean;
begin
  if assigned(fOnPutFilter) then
    result := fOnPutFilter.onPutNode(aNode)
  else
    result := true;
end;

function TMap.doOnPutRelation(const aRelation: OleVariant): boolean;
begin
  if assigned(fOnPutFilter) then
    result := fOnPutFilter.onPutRelation(aRelation)
  else
    result := true;
end;

function TMap.doOnPutWay(const aWay: OleVariant): boolean;
begin
  if assigned(fOnPutFilter) then
    result := fOnPutFilter.onPutWay(aWay)
  else
    result := true;
end;

function TMap.getNode(const id: int64): OleVariant;
const
  sQry = 'SELECT nodes.id AS id,' +
    'nodes.version AS version,' +
    'nodes.userId as userId,' +
    'nodes.name as userName,' +
    'nodes.changeset AS changeset,' +
    'nodes.timestamp as timestamp,' +
    'nodes.lat as lat,' +
    'nodes.lon as lon,' +
    'tags.tagname as k,' +
    'tags.tagvalue as v ' +
    'FROM (SELECT * FROM nodes,users WHERE nodes.id=:id AND nodes.userId=users.id)AS nodes ' +
    'LEFT JOIN objtags ON nodes.id*4=objtags.objid ' +
    'LEFT JOIN tags ON objtags.tagid=tags.id ' +
    'ORDER BY tags.tagname ';
var
  //IQueryResult
  qr, row, t: OleVariant;
begin
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.getNode: storage not assigned');
  if VarIsEmpty(fQryGetNode) then begin
    fQryGetNode := fStorage.sqlPrepare(sQry);
  end;
  qr := fStorage.sqlExec(fQryGetNode, VarArrayOf([':id']), VarArrayOf([id]));
  result := false;
  if qr.eos then exit;
  row := qr.read(1);
  result := createNode;
  result.id := row[0];
  result.version := row[1];
  result.userId := row[2];
  result.userName := row[3];
  result.changeset := row[4];
  result.timestamp := row[5];
  result.lat := intToDeg(row[6]);
  result.lon := intToDeg(row[7]);
  if VarIsNull(row[8]) then
    //no tags
    exit;
  t := result.tags;
  t.setByKey(row[8], row[9]);
  while not qr.eos do begin
    row := qr.read(1);
    if VarIsArray(row) then
      t.setByKey(row[8], row[9]);
  end;
end;

function TMap.getObjects(const filterOptions: OleVariant): OleVariant;
var
  os: TMapObjectStream;
begin
  os := TMapObjectStream.create();
  os.initialize(self, fStorage, varFromJsObject(filterOptions));
  result := os as IDispatch;
end;

function TMap.getRelation(const id: int64): OleVariant;
const
  sQry = 'SELECT relations.id AS id, ' +
    'relations.version AS version, ' +
    'relations.userId as userId, ' +
    'relations.name as userName, ' +
    'relations.changeset AS changeset, ' +
    'relations.timestamp as timestamp, ' +
    'tags.tagname as k, ' +
    'tags.tagvalue as v ' +
    'FROM (SELECT * FROM relations,users WHERE relations.id=:id AND relations.userId=users.id)AS relations ' +
    'LEFT JOIN objtags ON relations.id*4+2=objtags.objid ' +
    'LEFT JOIN tags ON objtags.tagid=tags.id ' +
    'ORDER BY tags.tagname';
  sQryMembers = 'SELECT membertype as membertype, ' +
    'memberid as memberid, ' +
    'memberrole as memberrole ' +
    'FROM strrelationmembers ' +
    'WHERE relationid=:id ' +
    'ORDER BY memberidx';
var
  //IQueryResult
  qr, row, t: OleVariant;
begin
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.getRelation: storage not assigned');
  if VarIsEmpty(fQryGetRelation) then begin
    fQryGetRelation := fStorage.sqlPrepare(sQry);
  end;
  qr := fStorage.sqlExec(fQryGetRelation, VarArrayOf([':id']), VarArrayOf([id]));
  result := false;
  if qr.eos then exit;
  row := qr.read(1);
  result := createRelation;
  result.id := row[0];
  result.version := row[1];
  result.userId := row[2];
  result.userName := row[3];
  result.changeset := row[4];
  result.timestamp := row[5];
  if not VarIsNull(row[6]) then begin
    //relation has tags
    t := result.tags;
    t.setByKey(row[6], row[7]);
    while not qr.eos do begin
      row := qr.read(1);
      if VarIsArray(row) then
        t.setByKey(row[6], row[7]);
    end;
  end;
  if VarIsEmpty(fQryGetRelationMembers) then begin
    fQryGetRelationMembers := fStorage.sqlPrepare(sQryMembers);
  end;
  qr := fStorage.sqlExec(fQryGetRelationMembers, VarArrayOf([':id']), VarArrayOf([id]));
  if not qr.eos then begin
    //relation has members
    t := result.members;
    while not qr.eos do begin
      row := qr.read(1);
      t.insertBefore(MaxInt, row[0], row[1], row[2]);
    end;
  end;
end;

function TMap.getWay(const id: int64): OleVariant;
const
  sQry = 'SELECT ways.id AS id, ' +
    'ways.version AS version, ' +
    'ways.userId as userId, ' +
    'ways.name as userName, ' +
    'ways.changeset AS changeset, ' +
    'ways.timestamp as timestamp, ' +
    'tags.tagname as k, ' +
    'tags.tagvalue as v ' +
    'FROM (SELECT * FROM ways,users WHERE ways.id=:id AND ways.userId=users.id)AS ways ' +
    'LEFT JOIN objtags ON ways.id*4+1=objtags.objid ' +
    'LEFT JOIN tags ON objtags.tagid=tags.id ' +
    'ORDER BY tags.tagname';
  sQryNodes = 'SELECT nodeid AS nodeid ' +
    'FROM waynodes ' +
    'WHERE wayid=:id ORDER BY nodeidx';
var
  ndList: array of int64;
  ndCount: integer;

  procedure grow();
  begin
    if length(ndList) <= ndCount then
      setLength(ndList, ndCount * 2);
  end;
var
  //IQueryResult
  qr, row, t: OleVariant;
  pv: PVarData;
  pi64: PInt64;
begin
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.getWay: storage not assigned');
  if VarIsEmpty(fQryGetWay) then begin
    fQryGetWay := fStorage.sqlPrepare(sQry);
  end;
  qr := fStorage.sqlExec(fQryGetWay, VarArrayOf([':id']), VarArrayOf([id]));
  result := false;
  if qr.eos then exit;
  row := qr.read(1);
  result := createWay;
  result.id := row[0];
  result.version := row[1];
  result.userId := row[2];
  result.userName := row[3];
  result.changeset := row[4];
  result.timestamp := row[5];
  if not VarIsNull(row[6]) then begin
    //way has tags
    t := result.tags;
    t.setByKey(row[6], row[7]);
    while not qr.eos do begin
      row := qr.read(1);
      if VarIsArray(row) then
        t.setByKey(row[6], row[7]);
    end;
  end;
  if VarIsEmpty(fQryGetWayNodes) then begin
    fQryGetWayNodes := fStorage.sqlPrepare(sQryNodes);
  end;
  qr := fStorage.sqlExec(fQryGetWayNodes, VarArrayOf([':id']), VarArrayOf([id]));
  if not qr.eos then begin
    //way has nodes
    ndCount := 0;
    setLength(ndList, 4);
    while not qr.eos do begin
      row := qr.read(1);
      inc(ndCount);
      grow();
      ndList[ndCount - 1] := row[0];
    end;
    t := VarArrayCreate([0, ndCount - 1], varVariant);
    if ndCount > 0 then begin
      pi64 := @ndList[0];
      pv := VarArrayLock(t);
      try
        while ndCount > 0 do begin
          pv^.VType := varInt64;
          pv^.VInt64 := pi64^;
          inc(pv);
          inc(pi64);
          dec(ndCount);
        end;
      finally
        VarArrayUnlock(t);
      end;
      result.nodes := t;
    end;
  end;
end;

function TMap.get_onPutFilter: OleVariant;
begin
  if assigned(fOnPutFilter) then
    result := fOnPutFilter.getFilter()
  else
    result := unassigned;
end;

procedure TMap.putNode(const aNode: OleVariant);
var
  id: int64;
  k: OleVariant;
begin
  if not doOnPutNode(aNode) then
    exit;
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.putNode: storage not assigned');
  id := aNode.id;
  if VarIsEmpty(fQryPutNode) then begin
    fQryPutNode := fStorage.sqlPrepare(
      'INSERT INTO strnodes' +
      '(id,   lat,  lon , version , timestamp , userId , userName,  changeset ) VALUES ' +
      '(:id, :lat, :lon, :version, :timestamp, :userId, :userName, :changeset);'
      );
  end;
  fStorage.sqlExec(fQryPutNode, VarArrayOf([':id', ':lat', ':lon', ':version', ':timestamp',
    ':userId', ':userName', ':changeset']),
      VarArrayOf([id, degToInt(aNode.lat), degToInt(aNode.lon), aNode.version, aNode.timestamp,
        aNode.userId,
    aNode.userName, aNode.changeset]));
  k := aNode.tags;
  putTags(id, 0, k.getAll);
end;

procedure TMap.putRelation(const aRelation: OleVariant);
var
  id, memberid: int64;
  t, r: WideString;
  n, i: integer;
  k: OleVariant;
  pv: PVariant;
begin
  if not doOnPutRelation(aRelation) then
    exit;
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.putRelation: storage not assigned');
  id := aRelation.id;
  if VarIsEmpty(fQryPutRelation) then begin
    fQryPutRelation := fStorage.sqlPrepare(
      'INSERT INTO strrelations' +
      '(id,   version , timestamp , userId , userName,  changeset ) VALUES ' +
      '(:id, :version, :timestamp, :userId, :userName, :changeset);'
      );
  end;
  fStorage.sqlExec(fQryPutRelation, VarArrayOf([':id', ':version', ':timestamp', ':userId',
    ':userName', ':changeset']),
      VarArrayOf([id, aRelation.version, aRelation.timestamp, aRelation.userId, aRelation.userName,
    aRelation.changeset]));
  k := aRelation.tags;
  putTags(id, 2, k.getAll);
  k := aRelation.members.getAll;
  if (VarArrayDimCount(k) <> 1) or ((VarType(k) and varTypeMask) <> varVariant) then
    raise EInOutError.create(toString() + '.putRelation: illegal members set');
  n := (VarArrayHighBound(k, 1) - VarArrayLowBound(k, 1) + 1) div 3;
  if n <= 0 then
    exit;
  if VarIsEmpty(fQryPutRelationMember) then begin
    fQryPutRelationMember := fStorage.sqlPrepare(
      'INSERT INTO strrelationmembers' +
      '(relationid,  memberidx, membertype, memberid, memberrole) VALUES ' +
      '(:relationid,:memberidx,:membertype,:memberid,:memberrole)');
  end;
  i := 0;
  pv := VarArrayLock(k);
  try
    while i < n do begin
      t := pv^;
      inc(pv);
      memberid := pv^;
      inc(pv);
      r := pv^;
      inc(pv);
      fStorage.sqlExec(fQryPutRelationMember,
        VarArrayOf([':relationid', ':memberidx', ':membertype', ':memberid', ':memberrole']),
        VarArrayOf([id, i, t, memberid, r]));
      inc(i);
    end;
  finally
    VarArrayUnlock(k);
  end;
end;

procedure TMap.putTags(const objId: int64; const objType: byte;
  const tagNamesValuesInterlived: OleVariant);
var
  objIdType: int64;
  i, nTags: integer;
  pnvi, pqp: PVariant;
  vQryParams: OleVariant;
begin
  nTags := (VarArrayHighBound(tagNamesValuesInterlived, 1) -
    VarArrayLowBound(tagNamesValuesInterlived, 1) + 1) div 2;
  if nTags <= 0 then
    exit;
  if VarIsEmpty(fQryPutObjTag) then begin
    fQryPutObjTag := fStorage.sqlPrepare(
      'INSERT OR IGNORE INTO strobjtags (objid,tagname,tagvalue) ' +
      'VALUES(:objid, :tagname, :tagvalue)'
      );
  end;
  vQryParams := VarArrayCreate([0, nTags * 3 - 1], varVariant);
  pnvi := VarArrayLock(tagNamesValuesInterlived);
  pqp := VarArrayLock(vQryParams);
  objIdType := objId * 4 + objType;
  try
    for i := 0 to nTags - 1 do begin
      //prepare parameters
      pqp^ := objIdType;
      inc(pqp);
      pqp^ := pnvi^; //copy name
      inc(pqp);
      inc(pnvi);
      pqp^ := pnvi^; //copy value
      inc(pqp);
      inc(pnvi);
    end;
  finally
    VarArrayUnlock(vQryParams);
    VarArrayUnlock(tagNamesValuesInterlived);
  end;
  fStorage.sqlExec(fQryPutObjTag, VarArrayOf([':objid', ':tagname', ':tagvalue']), vQryParams);
end;

procedure TMap.putWay(const aWay: OleVariant);
var
  id: int64;
  k, vQryParams: OleVariant;
  pv, pp: PVariant;
  i, n: integer;
begin
  if not doOnPutWay(aWay) then
    exit;
  if not varIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.putWay: storage not assigned');
  id := aWay.id;
  if VarIsEmpty(fQryPutWay) then begin
    fQryPutWay := fStorage.sqlPrepare(
      'INSERT INTO strways' +
      '(id,   version , timestamp , userId , userName,  changeset ) VALUES ' +
      '(:id, :version, :timestamp, :userId, :userName, :changeset);'
      );
  end;
  fStorage.sqlExec(fQryPutWay, VarArrayOf([':id', ':version', ':timestamp', ':userId', ':userName',
    ':changeset']),
      VarArrayOf([id, aWay.version, aWay.timestamp, aWay.userId, aWay.userName, aWay.changeset]));
  k := aWay.tags;
  putTags(id, 1, k.getAll);
  k := aWay.nodes;
  if (VarArrayDimCount(k) <> 1) or ((VarType(k) and varTypeMask) <> varVariant) then
    raise EInOutError(toString() + '.putWay: illegal nodes set');
  n := VarArrayHighBound(k, 1) - VarArrayLowBound(k, 1) + 1;
  if n <= 0 then
    exit;
  if VarIsEmpty(fQryPutWayNode) then begin
    fQryPutWayNode := fStorage.sqlPrepare(
      'INSERT INTO waynodes' +
      '(wayid,  nodeidx, nodeid) VALUES ' +
      '(:wayid,:nodeidx,:nodeid)');
  end;

  vQryParams := VarArrayCreate([0, n * 3 - 1], varVariant);
  pv := VarArrayLock(k);
  pp := VarArrayLock(vQryParams);
  try
    for i := 0 to n - 1 do begin
      //prepare parameters
      pp^ := id; //wayid
      inc(pp);
      pp^ := i; //nodeidx
      inc(pp);
      pp^ := pv^; //nodeid
      inc(pp);
      inc(pv);
    end;
  finally
    VarArrayUnlock(vQryParams);
    VarArrayUnlock(k);
  end;
  fStorage.sqlExec(fQryPutWayNode, VarArrayOf([':wayid', ':nodeidx', ':nodeid']), vQryParams);
end;

procedure TMap.set_onPutFilter(const aFilter: OleVariant);
begin
  FreeAndNil(fOnPutFilter);
  fOnPutFilter := TPutFilterAdaptor.create(aFilter);
end;

procedure TMap.set_storage(const newStorage: OleVariant);
begin
  fQryPutNode := unassigned;
  fQryPutWay := unassigned;
  fQryPutWayNode := unassigned;
  fQryPutRelation := unassigned;
  fQryPutRelationMember := unassigned;
  fQryPutObjTag := unassigned;
  fQryDeleteNode := unassigned;
  fQryDeleteWay := unassigned;
  fQryDeleteRelation := unassigned;
  fQryGetNode := unassigned;
  fQryGetWay := unassigned;
  fQryGetWayNodes := unassigned;
  fQryGetRelation := unassigned;
  fQryGetRelationMembers := unassigned;
  inherited set_storage(newStorage);
end;

{ TMapObject }

function TMapObject.get_changeset: int64;
begin
  result := fChangeset;
end;

function TMapObject.get_id: int64;
begin
  result := fId;
end;

function TMapObject.get_tags: OleVariant;
begin
  if VarIsEmpty(fTags) then
    fTags := TTags.create() as IDispatch;
  result := fTags;
end;

function TMapObject.get_timestamp: WideString;
begin
  result := fTimeStamp;
end;

function TMapObject.get_userId: integer;
begin
  result := fUserId;
end;

function TMapObject.get_userName: WideString;
begin
  result := fUserName;
end;

function TMapObject.get_version: integer;
begin
  result := fVersion;
end;

procedure TMapObject.set_changeset(const newChangeset: int64);
begin
  fChangeset := newChangeset;
end;

procedure TMapObject.set_id(const newId: int64);
begin
  fId := newId;
end;

procedure TMapObject.set_tags(const newTags: OleVariant);
begin
  fTags := newTags;
end;

procedure TMapObject.set_timestamp(const newTimeStamp: WideString);
begin
  fTimeStamp := newTimeStamp;
end;

procedure TMapObject.set_userId(const newUserId: integer);
begin
  fUserId := newUserId;
end;

procedure TMapObject.set_userName(const newUserName: WideString);
begin
  fUserName := newUserName;
end;

procedure TMapObject.set_version(const newVersion: integer);
begin
  fVersion := newVersion;
end;

{ TTags }

procedure TTags.deleteByKey(const key: WideString);
var
  i: integer;
begin
  for i := 0 to count - 1 do
    if fKeys[i] = key then begin
      deleteById(i);
      break;
    end;
end;

procedure TTags.deleteById(const id: integer);
var
  i: integer;
begin
  if (id < 0) or (id >= count) then
    raise ERangeError.create(toString() + '.deteteById: id out of bounds');
  for i := id to count - 2 do begin
    fKeys[i] := fKeys[i + 1];
    fValues[i] := fValues[i + 1];
  end;
  dec(fCount);
end;

function TTags.get_count: integer;
begin
  result := fCount;
end;

function TTags.getAll: OleVariant;
var
  pk, pv: PVariant;
  i: integer;
begin
  result := VarArrayCreate([0, count * 2 - 1], varVariant);
  pk := VarArrayLock(result);
  pv := pk;
  inc(pv);
  try
    for i := 0 to count - 1 do begin
      pk^ := fKeys[i];
      pv^ := fValues[i];
      inc(pk, 2);
      inc(pv, 2);
    end;
  finally
    VarArrayUnlock(result);
  end;
end;

function TTags.getByKey(const key: WideString): WideString;
var
  i: integer;
begin
  result := '';
  for i := 0 to count - 1 do begin
    if key = fKeys[i] then begin
      result := fValues[i];
      break;
    end;
  end;
end;

function TTags.getKey(const id: integer): WideString;
begin
  if (id >= count) or (id < 0) then
    raise ERangeError.create(toString() + '.getKey: index out of range');
  result := fKeys[id];
end;

function TTags.getValue(const id: integer): WideString;
begin
  if (id >= count) or (id < 0) then
    raise ERangeError.create(toString() + '.getValue: index out of range');
  result := fValues[id];
end;

function TTags.hasKey(const key: WideString): WordBool;
var
  i: integer;
begin
  result := false;
  for i := 0 to count - 1 do
    if key = fKeys[i] then begin
      result := true;
      break;
    end;
end;

procedure TTags.setAll(const kvArray: OleVariant);
var
  i, l: integer;
  a: OleVariant;
  pv1, pv2: POleVariant;
begin
  a := varFromJsObject(kvArray);
  if (VarArrayDimCount(a) <> 1) or odd(varArrayLength(a)) then
    raise ERangeError.create(toString() + '.setAll: need even-length array');
  l := varArrayLength(a) div 2;
  pv1 := VarArrayLock(a);
  try
    pv2 := pv1;
    inc(pv2);
    fCount:=0;
    for i := 0 to l - 1 do begin
      setByKey(pv1^, pv2^);
      inc(pv1,2);
      inc(pv2,2);
    end;
  finally
    VarArrayUnlock(a);
  end;
end;

procedure TTags.setByKey(const key, value: WideString);
var
  i: integer;
begin
  for i := 0 to count - 1 do begin
    if key = fKeys[i] then begin
      fValues[i] := value;
      exit;
    end;
  end;
  inc(fCount);
  grow();
  fKeys[count - 1] := key;
  fValues[count - 1] := value;
end;

procedure TTags.setKey(const id: integer; const key: WideString);
begin
  if (id >= count) or (id < 0) then
    raise ERangeError.create(toString() + '.setKey: index out of range');
  fKeys[id] := key;
end;

procedure TTags.setValue(const id: integer; const value: WideString);
begin
  if (id >= count) or (id < 0) then
    raise ERangeError.create(toString() + '.setValue: index out of range');
  fValues[id] := value;
end;

procedure TTags.grow;
var
  i: integer;
begin
  if count >= length(fKeys) then begin
    i := (count or 3) + 1;
    setLength(fKeys, i);
    setLength(fValues, i);
  end;
end;

{ TNode }

function TNode.get_lat: double;
begin
  result := intToDeg(fLat);
end;

function TNode.get_lon: double;
begin
  result := intToDeg(fLon);
end;

procedure TNode.set_lat(const value: double);
begin
  if (value > 90) or (value < -90) then
    raise ERangeError.create(toString() + '.set_lat: lat out of range');
  fLat := degToInt(value);
end;

procedure TNode.set_lon(const value: double);
begin
  if (value > 180) or (value < -180) then
    raise ERangeError.create(toString() + '.set_lon: lon out of range');
  fLon := degToInt(value);
end;

{ TWay }

function TWay.get_nodes: OleVariant;
var
  i: integer;
  pv: PVarData;
  pi: PInt64;
begin
  i := length(fNodes);
  result := VarArrayCreate([0, i - 1], varVariant);
  if i > 0 then begin
    pi := @fNodes[0];
    pv := VarArrayLock(result);
    try
      while i > 0 do begin
        pv^.VType := varInt64;
        pv^.VInt64 := pi^;
        inc(pi);
        inc(pv);
        dec(i);
      end;
    finally
      VarArrayUnlock(result);
    end;
  end;
end;

procedure TWay.set_nodes(const newNodes: OleVariant);
var
  i: integer;
  pv: PVarData;
  pi: PInt64;
  v: OleVariant;
begin
  v := varFromJsObject(newNodes);
  if (VarArrayDimCount(v) <> 1) or ((VarType(v) and varTypeMask) <> varVariant) then
    raise EConvertError.create(toString() + '.set_nodes: array of variants expected');
  i := VarArrayHighBound(v, 1) - VarArrayLowBound(v, 1) + 1;
  setLength(fNodes, i);
  if i > 0 then begin
    pi := @fNodes[0];
    pv := VarArrayLock(v);
    try
      while i > 0 do begin
        pi^ := PVariant(pv)^;
        inc(pi);
        inc(pv);
        dec(i);
      end;
    finally
      VarArrayUnlock(v);
    end;
  end;
end;

{ TRelation }

constructor TRelation.create;
begin
  inherited;
  fMembers := unassigned;
end;

function TRelation.get_members: OleVariant;
begin
  if VarIsEmpty(fMembers) then
    fMembers := TRefList.create() as IDispatch;
  result := fMembers;
end;

procedure TRelation.set_members(const newMembers: OleVariant);
begin
  fMembers := newMembers;
end;

{ TMapObjectStream }

constructor TMapObjectStream.create;
begin
  inherited;
  fOutMode := rtNode;
end;

destructor TMapObjectStream.destroy;
begin
  set_eos(true);
  inherited;
end;

function TMapObjectStream.get_eos: WordBool;
begin
  result := fEOS;
end;

procedure TMapObjectStream.initialize(const aMap: TMap; const aStorage, aFilter: OleVariant);

  procedure parseBox(var pv: POleVariant; var idx: integer; cnt: integer);
  const
    bboxextra = 2E-7;
  var
    n, e, s, w: double;
  begin
    if ((idx + 4) >= cnt) then exit;
    //set pv to north
    inc(pv);
    inc(idx);
    n := pv^ + bboxextra;
    inc(pv);
    inc(idx);
    e := pv^ + bboxextra;
    inc(pv);
    inc(idx);
    s := pv^ - bboxextra;
    inc(pv);
    inc(idx);
    w := pv^ - bboxextra;
    if fNodeSelectCondition <> '' then
      fNodeSelectCondition := fNodeSelectCondition + ' OR '
    else
      fNodeSelectCondition := ' WHERE ';
    fNodeSelectCondition := fNodeSelectCondition +
      '( (lat BETWEEN ' + intToStr(degToInt(s)) + ' AND ' +
      intToStr(degToInt(n)) + ') AND ' +
      '(lon BETWEEN ' + intToStr(degToInt(w)) + ' AND ' +
      intToStr(degToInt(e)) + ') )';
  end;

  procedure parsePoly(var pv: POleVariant; var idx: integer; cnt: integer);
  var
    l: integer;
  begin
    if (idx + 1) >= cnt then
      exit;
    inc(pv);
    inc(idx);
    if varIsType(pv^, varDispatch) and isDispNameExists(pv^, 'isIn') then begin
      l := length(fBPolies);
      setLength(fBPolies, l + 1);
      fBPolies[l] := pv^;
    end;
  end;

  procedure parseClipIncompleteWays(var pv: POleVariant; var idx: integer; cnt: integer);
  begin
    fClipIncompleteWays := true;
  end;

  procedure parseCustomFilter(var pv: POleVariant; var idx: integer; cnt: integer);
  var
    l: integer;
  begin
    if (idx + 1) >= cnt then
      exit;
    inc(pv);
    inc(idx);
    if varIsType(pv^, varDispatch) then begin
      l := length(fCustomFilters);
      setLength(fCustomFilters, l + 1);
      fCustomFilters[l] := TPutFilterAdaptor.create(pv^);
    end;
  end;
var
  pv: POleVariant;
  ws: WideString;
  i, n: integer;
begin
  if assigned(fMap) then fMap._Release();
  fMap := aMap;
  if assigned(fMap) then fMap._AddRef();
  fStorage := aStorage;
  fClipIncompleteWays := false;
  //parse filter options
  if (VarArrayDimCount(aFilter) <> 1) then
    //no multi-dim or scalar options support
    exit;
  n := VarArrayHighBound(aFilter, 1) - VarArrayLowBound(aFilter, 1) + 1;
  i := 0;
  pv := VarArrayLock(aFilter);
  try
    while (i < n) do begin
      if varIsType(pv^, varOleStr) then begin
        ws := pv^;
        if (ws <> '') and (ws[1] = ':') then begin
          if (ws = ':bbox') then begin
            //parse bbox n,e,s,w parameters
            parseBox(pv, i, n);
          end
          else if (ws = ':bpoly') then begin
            parsePoly(pv, i, n);
          end
          else if (ws = ':clipIncompleteWays') then begin
            parseClipIncompleteWays(pv, i, n);
          end
          else if (ws = ':customFilter') then begin
            parseCustomFilter(pv, i, n);
          end;
        end;
      end;
      inc(pv);
      inc(i);
    end;
  finally
    VarArrayUnlock(aFilter)
  end;
end;

function TMapObjectStream.read(const maxBufSize: integer): OleVariant;
var
  i: integer;
  pv: PVariant;
begin
  if (maxBufSize <= 0) or eos then
    result := unassigned
  else if maxBufSize = 1 then
    result := read1
  else begin
    result := VarArrayCreate([0, maxBufSize - 1], varVariant);
    pv := VarArrayLock(result);
    i := 0;
    try
      while (i < maxBufSize) and not eos do begin
        pv^ := read1;
        if varIsType(pv^, varDispatch) then begin
          inc(pv);
          inc(i);
        end;
      end;
    finally
      VarArrayUnlock(result);
    end;
    if i < maxBufSize then
      VarArrayRedim(result, i - 1);
  end;
end;

function TMapObjectStream.read1: OleVariant;

  procedure addNodeToList(const nodeId: int64);
  begin
    fNodeList.add(nodeId);
  end;

  procedure addWayToList(const wayId: int64);
  begin
    fWayList.add(wayId);
  end;

  procedure addRelToList(const relId: int64);
  begin
    fRelList.add(relId);
  end;

  procedure addToDoList(const memArray: OleVariant);
  var
    pv: POleVariant;
    n: integer;
    id: int64;
  begin
    n := varArrayLength(memArray) div 3;
    pv := VarArrayLock(memArray);
    try
      while (n > 0) do begin
        dec(n);
        if pv^ <> 'relation' then begin
          inc(pv, 3);
          continue;
        end;
        inc(pv);
        id := pv^;
        inc(pv, 2);
        fToDoRelList.add(id);
      end;
    finally
      VarArrayUnlock(memArray);
    end;
  end;

  function checkNodeFilter(aNode: OleVariant): boolean;
  var
    i, l: integer;
    v: OleVariant;
  begin
    l := length(fBPolies);
    result := l = 0;
    //check bpolies (OR short eval)
    for i := 0 to l - 1 do begin
      if fBPolies[i].isIn(aNode) then begin
        if (i > 0) then begin
          v := fBPolies[i];
          fBPolies[i] := fBPolies[i - 1];
          fBPolies[i - 1] := v;
        end;
        result := true;
        break;
      end;
    end;
    if not result then
      exit;
    //check custom filters (AND short eval)
    l := length(fCustomFilters);
    for i := 0 to l - 1 do begin
      if not fCustomFilters[i].onPutNode(aNode) then begin
        result := false;
        break;
      end;
    end;
  end;

  function checkWayFilter(const aWay: Variant): boolean;

    //returns true if length(node-list)>=2

    function clipWay(const aWay: Variant): boolean;
    var
      nodes: Variant;
      pvs, pvt: PVariant;
      n, i, cnt: integer;
      nid: int64;
    begin
      nodes := aWay.nodes;
      n := varArrayLength(nodes);
      cnt := 0;
      i := n;
      pvs := VarArrayLock(nodes);
      pvt := pvs;
      try
        while i > 0 do begin
          nid := pvs^;
          if fNodeList.isIn(nid) then begin
            if pvt <> pvs then
              pvt^ := pvs^;
            inc(pvt);
            inc(cnt);
          end;
          inc(pvs);
          dec(i);
        end;
      finally
        VarArrayUnlock(nodes);
      end;
      if n <> cnt then begin
        VarArrayRedim(nodes, cnt - 1);
        aWay.nodes := nodes;
      end;
      result := cnt >= 2;
    end;
  var
    i: integer;
  begin
    if fClipIncompleteWays then
      result := clipWay(aWay)
    else
      result := true;
    if not result then
      exit;
    for i := 0 to high(fCustomFilters) do begin
      if not fCustomFilters[i].onPutWay(aWay) then begin
        result := false;
        break;
      end;
    end;
  end;

  function checkRelationFilter(aRelation: OleVariant): boolean;
  var
    i, l: integer;
  begin
    result := true;
    //check custom filters (AND short eval)
    l := length(fCustomFilters);
    for i := 0 to l - 1 do begin
      if not fCustomFilters[i].onPutRelation(aRelation) then begin
        result := false;
        break;
      end;
    end;
  end;

var
  id: int64;
  resultValid: boolean;
begin
  result := unassigned;
  resultValid := false;
  if VarIsEmpty(fNodeList) then
    fNodeList := fStorage.createIdList();
  if VarIsEmpty(fWayList) then
    fWayList := fStorage.createIdList();
  if VarIsEmpty(fRelList) then
    fRelList := fStorage.createIdList();
  if VarIsEmpty(fToDoRelList) then
    fToDoRelList := fStorage.createIdList();
  repeat
    case fOutMode of
      rtNode: begin
          if VarIsEmpty(fQry) then begin
            fQry := fStorage.sqlPrepare('SELECT id AS id FROM nodes ' + fNodeSelectCondition);
            fQry := fStorage.sqlExec(fQry, 0, 0);
          end;
          if not fQry.eos then begin
            id := fQry.read(1)[0];
            result := fMap.getNode(id);
            if checkNodeFilter(result) then begin
              addNodeToList(id);
              resultValid := true;
            end;
          end
          else begin
            fQry := fStorage.sqlPrepare(
              'INSERT OR IGNORE INTO ' + fToDoRelList.tableName + '(id) ' +
              'SELECT relationid FROM relationmembers ' +
              'WHERE memberid IN (SELECT id FROM ' + fNodeList.tableName + ') AND ' +
              '(memberidxtype & 3)=0'
              );
            fStorage.sqlExec(fQry, 0, 0);
            fQry := unassigned;
            fOutMode := rtWay;
          end;
        end;
      rtWay: begin
          if VarIsEmpty(fQry) then begin
            fQry := fStorage.sqlPrepare('SELECT DISTINCT(wayid) AS id FROM waynodes ' +
              'WHERE waynodes.nodeid IN (' +
              'SELECT id FROM ' + fNodeList.tableName +
              ')');
            fQry := fStorage.sqlExec(fQry, 0, 0);
          end;
          if not fQry.eos then begin
            id := fQry.read(1)[0];
            result := fMap.getWay(id);
            if checkWayFilter(result) then begin
              addWayToList(id);
              resultValid := true;
            end;
          end
          else begin
            fQry := fStorage.sqlPrepare(
              'INSERT OR IGNORE INTO ' + fToDoRelList.tableName + '(id) ' +
              'SELECT relationid FROM relationmembers ' +
              'WHERE memberid IN (SELECT id FROM ' + fWayList.tableName + ') AND ' +
              '(memberidxtype & 3)=1'
              );
            fStorage.sqlExec(fQry, 0, 0);
            fQry := unassigned;
            fOutMode := rtRelation;
          end;
        end;
      rtRelation: begin
          if VarIsEmpty(fQry) then begin
            fQry := fStorage.sqlPrepare('SELECT id FROM ' + fToDoRelList.tableName + ' ');
            fQry := fStorage.sqlExec(fQry, 0, 0);
          end;
          if not fQry.eos then begin
            id := fQry.read(1)[0];
            result := fMap.getRelation(id);
            addRelToList(id);
            if varIsType(result, varDispatch) and checkRelationFilter(result) then begin
              addToDoList(result.members.getAll);
              resultValid := true;
            end;
            if fQry.eos then begin
              fQry := fStorage.sqlPrepare(
                'INSERT OR IGNORE INTO ' + fToDoRelList.tableName + '(id) ' +
                'SELECT relationid FROM relationmembers ' +
                'WHERE memberid IN (SELECT id FROM ' + fRelList.tableName + ') AND ' +
                '(memberidxtype & 3)=2'
                );
              fStorage.sqlExec(fQry, 0, 0);
              fQry := fStorage.sqlPrepare('DELETE FROM ' + fToDoRelList.tableName +
                ' WHERE id IN (SELECT id FROM ' + fRelList.tableName + ')');
              fStorage.sqlExec(fQry, 0, 0);
              fQry := unassigned;
            end;
          end
          else begin
            fOutMode := rtNode;
            set_eos(true);
            resultValid := true;
          end;
        end;
    else
      raise EInOutError.create(toString() + '.read1: unknown output mode');
    end;
  until resultValid;
end;

procedure TMapObjectStream.set_eos(const aEOS: boolean);
var
  i: integer;
begin
  if aEOS and not fEOS then begin
    fNodeList := unassigned;
    fWayList := unassigned;
    fRelList := unassigned;
    fToDoRelList := unassigned;
    for i := 0 to high(fCustomFilters) do
      FreeAndNil(fCustomFilters[i]);
    setLength(fCustomFilters, 0);
    setLength(fBPolies, 0);
    fQry := unassigned;
    fStorage := unassigned;
    if assigned(fMap) then
      fMap._Release();
    fMap := nil;
  end;
  fEOS := fEOS or aEOS;
end;

{ TAbstractMap }

function TAbstractMap.createNode: IDispatch;
begin
  result := TNode.create();
end;

function TAbstractMap.createRelation: IDispatch;
begin
  result := TRelation.create();
end;

function TAbstractMap.createWay: IDispatch;
begin
  result := TWay.create();
end;

function TAbstractMap.get_storage: OleVariant;
begin
  result := fStorage;
end;

procedure TAbstractMap.putObject(const aObj: OleVariant);
var
  s: WideString;
begin
  s := aObj.getClassName();
  if s = 'Node' then
    putNode(aObj)
  else if s = 'Way' then
    putWay(aObj)
  else if s = 'Relation' then
    putRelation(aObj)
  else
    raise EConvertError.create(toString() + '.putObject: unknown class "' + s + '"');
end;

procedure TAbstractMap.set_storage(const newStorage: OleVariant);
begin
  fStorage := newStorage;
end;

initialization
  uModule.OSManRegister(TMap, mapClassGuid);
end.

