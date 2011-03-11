unit uInterfaces;

interface

type
  //Base interface for all objects
  IOSManAll = interface
    //String id of object. By default (in TOSManObject) returns "ModuleName.ClassName.InstanceAddress"
    function toString(): WideString;
    // Class name of object
    function getClassName(): WideString;
  end;

  //logger interface
  ILogger = interface(IOSManAll)
    procedure log(const logMessage:WideString);
  end;

  //Read only byte stream interface
  IInputStream = interface(IOSManAll)
    //maxBufSize: read buffer size
    //Readed data in zero-based one dimensional SafeArray of bytes (VT_ARRAY | VT_UI1)
    function read(const maxBufSize: integer): OleVariant;
    function get_eos(): WordBool;
    //"true" if end of stream reached, "false" otherwise
    property eos: WordBool read get_eos;
  end;

  IResourceInputStream = interface(IInputStream)
    //URL: String representation of resource address (web-address, local FS file name, etc).
    procedure open(const URL: WideString);
  end;

  //Interface for read transform filters (decompressors, parsers, decrypters, etc).
  ITransformInputStream = interface(IInputStream)
    //input stream for transformation
    procedure setInputStream(const inStream: OleVariant);
  end;

  //Write only byte stream interface
  IOutputStream=interface(IOSManAll)
    //Write data from zero-based one dimensional SafeArray of bytes (VT_ARRAY | VT_UI1)
    procedure write(const aBuf:OleVariant);
    procedure set_eos(const aEOS:WordBool);
    function get_eos:WordBool;
    //write "true" if all data stored and stream should to release system resources
    //once set to "true" no write oprerations allowed on stream
    property eos: WordBool read get_eos write set_eos;
  end;

  //Interface for output transform filters (compressors, exporters, ecrypters, etc).
  ITransformOutputStream = interface(IOutputStream)
    //output IOutputStream for transformed data
    procedure setOutputStream(const outStream: OleVariant);
  end;

  IResourceOutputStream = interface(IOutputStream)
    //URL: String representation of resource address (web-address, local FS file name, etc).
    procedure open(const URL: WideString);
  end;

  //Interface for Objects that stores results to IMap
  IMapWriter = interface(IOSManAll)
    //Map for storing results
    procedure setOutputMap(const outMap: OleVariant);
  end;

  IMapReader = interface(IOSManAll)
    //Map for storing results
    procedure setInputMap(const inMap: OleVariant);
  end;

  //interface for list of (key,value) string pairs.
  IKeyList = interface(IOSManAll)
    //delete item by key. If no such key, no actions performed
    procedure deleteByKey(const key: WideString);
    //delete item by index in list. If index out of bounds then exception raised
    procedure deleteById(const id: integer);
    //get all keys in list. Result is SafeArray of string variants.
    //Keys and Values interlived - [0]=key[0],[1]=value[0]...[10]=key[5],[11]=value[5],...
    function getAll: OleVariant;
    //replaces old list with new one. All old items deleted, new items added
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

    function get_count: integer;

    //returns number of pairs in list
    property count: integer read get_count;
  end;

  //List of references to objects. Used in IRelation.members
  IRefList = interface(IOSManAll)
    //idx - index in list. If idx out of bounds exception raised
    //refType  - type of referenced object. One of 'Node','Way','Relation'
    //refID - OSM ID of referenced object
    //refRrole - role in relation
    procedure getByIdx(idx: integer; out refType: WideString; out refId: Int64; out refRole:
      WideString);
    procedure setByIdx(idx: integer; const refType: WideString; refId: Int64; const refRole:
      WideString);
    procedure deleteByIdx(idx: integer);
    //returns interlived SafeArray of variants
    //[0]-refType[0](string), [1]-refId[0](int64), [2]-refRole[0](string), [3]-refType[1]....
    function getAll:OleVariant;
    //replace old list with new one. Deletes all old items then adds new 
    //See getAll() result description for refTypesIdsRoles layout
    procedure setAll(refTypesIdsRoles: OleVariant);
    //idx - if idx => count then item appended to end of list, if idx<0 exception raised
    procedure insertBefore(idx: integer; const refType: WideString; refId: int64; const refRole:
      WideString);

    function get_count: integer;
    //returns number of list items
    property count: integer read get_count;
  end;

  //base interface for all map objects (nodes, ways, relations)
  IMapObject = interface(IOSManAll)
    function get_tags: OleVariant;
    procedure set_tags(const newTags: OleVariant);
    function get_id: Int64;
    procedure set_id(const newId: Int64);
    function get_version: integer;
    procedure set_version(const newVersion: integer);
    function get_userId: integer;
    procedure set_userId(const newUserId: integer);
    function get_userName: WideString;
    procedure set_userName(const newUserName: WideString);
    function get_changeset: Int64;
    procedure set_changeset(const newChangeset: Int64);
    function get_timestamp: WideString;
    procedure set_timestamp(const newTimeStamp: WideString);

    //tags, associated with object. Supports IKeyList
    property tags: OleVariant read get_tags write set_tags;
    //OSM object ID.
    property id: Int64 read get_id write set_id;
    //OSM object version
    property version: integer read get_version write set_version;
    //OSM object userID
    property userId: integer read get_userId write set_userId;
    //OSM object userName
    property userName: WideString read get_userName write set_userName;
    //OSM object changeset
    property changeset: Int64 read get_changeset write set_changeset;
    //OSM object timestamp. Format "yyyy-mm-ddThh:nn:ssZ" like in OSM files
    property timestamp: WideString read get_timestamp write set_timestamp;
  end;

  INode = interface(IMapObject)
    function get_lat: Double;
    procedure set_lat(const value: Double);
    function get_lon: Double;
    procedure set_lon(const value: Double);
    //node latitude. If out of bounds [-90...+90] exception raised
    property lat: Double read get_lat write set_lat;
    //node longitude. If out of bounds [-180...180] exception raised
    property lon: Double read get_lon write set_lon;
  end;

  IWay = interface(IMapObject)
    function get_nodes: OleVariant;
    procedure set_nodes(const newNodes: OleVariant);
    //array of node OSM IDs. SafeArray of Int64 variants
    property nodes: OleVariant read get_nodes write set_nodes;
  end;

  IRelation = interface(IMapObject)
    function get_members: OleVariant;
    procedure set_members(const newMembers: OleVariant);
    //list of relation members. Supports IRefList
    property members: OleVariant read get_members write set_members;
  end;

  //filter called before put objects into strorage.
  //if result of filter function is true, then object stored,
  // otherwise object ignored.
  //onPutObject called before any other function.
  // If onPutObject returns false, then other filter functions(onPutNode, etc.)
  //  not called for this object.
  IMapOnPutFilter=interface
    function onPutObject(const mapObject:OleVariant):boolean;
    function onPutNode(const node:OleVariant):boolean;
    function onPutWay(const way:OleVariant):boolean;
    function onPutRealtion(const relation:OleVariant):boolean;
  end;

  //responce for http-requests
  //Use IInputStream to read responce body.
  IHTTPResponce=interface(IInputStream)
    //get state of operation.
    //  0 - waiting for connect
    //  1 - connected
    //  2 - sending data to server
    //  3 - receiving data from server
    //  4 - transfer complete. Success/fail determined by getStatus() call.
    function getState():integer;
    //get HTTP-status. It implemented as follows:
    // 1.If connection broken or not established in state < 3 then status '503 Service Unavailable' set;
    // 2.If connection broken in state=3 then status '504 Gateway Time-out' set;
    // 3.If state=3 (transfer operation pending) then status '206 Partial Content' set;
    // 4.If state=4 then status set to server-returned status
    function getStatus():integer;
    //wait for tranfer completition. On function exit all pending
    //  data send/receive completed and connection closed.
    procedure fetchAll();
  end;

  //HTTP storage for NetMap
  IHTTPStorage=interface(IOSManAll)
    //property setters-getters
    function get_hostName():WideString;
    procedure set_hostName(const aName:WideString);
    function get_timeout():integer;
    procedure set_timeout(const aTimeout:integer);
    function get_maxRetry():integer;
    procedure set_maxRetry(const aMaxRetry:integer);

    //returns IHTTPResponce for request 'GET http://hostName/location'
    function get(const location:WideString):OleVariant;
    //hostname for OSM-API server. Official server is api.openstreetmap.org
    property hostName:WideString read get_hostName write set_hostName;
    //timeout for network operations (in ms). By default 20000ms (20 sec)
    property timeOut:integer read get_timeout write set_timeout;
    //max retries for connection/DNS requests. By default 3.
    property maxRetry:integer read get_maxRetry write set_maxRetry;
  end;

  //SQL storage for map data
  IStorage = interface(IOSManAll)
    function get_dbName(): WideString;
    procedure set_dbName(const newName: WideString);
    function get_readOnly():boolean;
    procedure set_readOnly(roFlag:boolean);

    //returns opaque Query object
    function sqlPrepare(const sqlProc: WideString): OleVariant;
    //sqlQuery - opaque Query object
    //paramsNames,paramValues - query parameters. SafeArray of variants.
    //returns IQueryResult object
    //It can do batch execution if length(ParamValues)==k*length(paramsNames) and k>=1.
    //In such case only last resultset returned
    function sqlExec(const sqlQuery: OleVariant; const paramNames,paramValues: OleVariant):
      OleVariant;
    //creates IStoredIdList object
    function createIdList():OleVariant;
    //initialize new storage - create database schema (tables, indexes, triggers...)
    procedure initSchema();
    //set this property before open to use db in readonly mode
    property readOnly:boolean read get_readOnly write set_readOnly;
    //database resource locator (file name, server name, etc).
    property dbName: WideString read get_dbName write set_dbName;
  end;

  IStorageUser=interface(IOSManAll)
    function get_storage:OleVariant;
    procedure set_storage(const newStorage:OleVariant);
    //IStorage object
    property storage:OleVariant read get_storage write set_storage;
  end;

  IStoredIdList=interface(IStorageUser)
    function get_tableName:wideString; 

    //returns true if `id` is in list
    function isIn(const id: int64): boolean;
    //add `id` into list. If `id` already in list do nothing.
    procedure add(const id: int64);
    //deletes `id from list. If `id` not in list do nothing.
    procedure delete(const id: int64);
    //read-only temporary table name. Use it in SQL-queries.
    property tableName: WideString read get_tableName;
  end;

  IMap = interface(IStorageUser)
    //create epmty node
    function createNode(): IDispatch;
    //create epmty way
    function createWay(): IDispatch;
    //create epmty relation
    function createRelation(): IDispatch;

    //store Node into Storage
    procedure putNode(const aNode: OleVariant);
    //store Way into Storage
    procedure putWay(const aWay: OleVariant);
    //store Relation into Storage
    procedure putRelation(const aRelation: OleVariant);
    //store MapObject (Node,Way or Relation) into Store
    procedure putObject(const aObj: OleVariant);

    //delete Node and its tags from Storage. Ways and Relations is not updated.
    procedure deleteNode(const nodeId:int64);
    //delete Way, its tags and node-list from Storage. Relations is not updated.
    procedure deleteWay(const wayId:int64);
    //delete Relation, its tags and ref-list from Storage. Parent and child Relations is not updated.
    procedure deleteRelation(const relationId:int64);

    //get node by ID. If no node found returns false
    function getNode(const id: Int64): OleVariant;
    //get way by ID. If no way found returns false
    function getWay(const id: Int64): OleVariant;
    //get relation by ID. If no relation found returns false
    function getRelation(const id: Int64): OleVariant;

    //get filtered object set
    //returns IInputStream of MapObjects
    //filterOptions - SafeArray of variant in form [0]=OptName1,[1]=OptParam1,..[k]=OptParam[k],[k+1]=OptName2,....
    //  OptName must starts with ':' characher.
    //supported options:
    //  :bbox - select only objects within bounding box. If there are several bboxes
    //    specified then objects exported for all this boxes.
    //     Params:
    //     n,e,s,w - four floating values for north, east, south and west bounds
    //  :bpoly - select objects in multipolygon. Objects selected after :bbox
    //    filter passed. If there are several :bpoly specified then objects exported
    //    for all this multipolygons ('concatination').
    //     Params:
    //     mpoly - bounding IMultiPoly object.
    //  :clipIncompleteWays - delete references to not-exported nodes from way node-list.
    //    By default (without this option) full node-list exported.
    //     Params: none.
    //  :customFilter - user-defined filter. See IMapOnPutFilter interface.
    //     Filter interface can be partially implemented. For not implemented method
    //     <true> result assumed. If there are several :customFilters specified then
    //     filters are called in ascending order. If filter returns <false> then
    //     subsequent filters not called and object not passed (short AND evaluation).
    //    Params:
    //     cFilter - IMapOnPutFilter object.
    function getObjects(const filterOptions:OleVariant):OleVariant;
    function get_onPutFilter:OleVariant;
    procedure set_onPutFilter(const aFilter:OleVariant);
    //IMapOnPutFilter
    property onPutFilter:Olevariant read get_onPutFilter write set_onPutFilter;
  end;

  //results of query
  //read function maxBufSize argument is number of rows to read
  //returns SafeArray of variants in form (r1c1,r1c2,r1c3,...,r99c8,r99c9,r99c10)
  IQueryResult = interface(IInputStream)
    //returns SafeArray of string variants
    function getColNames(): OleVariant;
  end;

  IGeoTools=interface(IOSManAll)
    //returns multipolygon Object
    function createPoly():OleVariant;
    //returns distance in meters
    function distance(const node1,node2:OleVariant):double;
    //returns node rounded to certain bit level.
    //aBitLevel should be between 2 and 31.
    //Suitable for mp-format convertion
    procedure bitRound(aNode:OleVariant;aBitLevel:integer);
    //returns array of Nodes of way.
    //if some objects not found in aMap then exception raised
    //aMap - source of Nodes and Way
    //aWayOrWayId - Way object or id of way.
    function wayToNodeArray(aMap,aWayOrWayId:OleVariant):OleVariant;
  end;

  IMultiPoly=interface(IOSManAll)
    //add MapObject to polygon. Nodes not allowed,
    //node-members in Relation are ignored
    procedure addObject(const aMapObject:OleVariant);
    //returns true if all relations/way/nodes resolved, false otherwise
    function resolve(const srcMap:OleVariant):boolean;
    //IRefList of not resolved references
    function getNotResolved():OleVariant;
    //IRefList of not closed nodes.
    function getNotClosed():OleVariant;
    //returns intersection of Poly boundary and NodeArray.
    //Result is array of arrrays of Node`s. Tag 'osman:note' filled with
    //'boundary' value for nodes layed on-bound.
    //If NodeArray and Poly has no intersection zero-length
    // array [] returned.
    //New Nodes in result has id=newNodeId,newNodeId-1,...,newNodeId-k
    //Example:
    // NodeArray=[n1(0,1) , n2(2,1) , n3(4,1)]
    // poly=(1,0) - (3,0) - (3,2) - (1,2) - (1,0)
    // newNodeId=-11
    // result=[nA(1,1, id=-11, osman:note=boundary), n2(2,1), nB(3,1, id=-12, osman:note=boundary)]
    function getIntersection(const aMap,aNodeArray:OleVariant; newNodeId:int64):OleVariant;
    //returns true if node is in poly (including border)
    function isIn(const aNode:OleVariant):boolean;
    //returns multipoly area in square meters
    //if poly not resolved then exception raised
    function getArea():double;
    //returns bounding box for poly. Returns SafeArray of four double variants
    // for N,E,S and W bounds respectively. If poly not resolved then
    // exception raised.
    function getBBox:OleVariant;
  end;

implementation

end.

