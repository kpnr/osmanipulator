unit uNetMap;

interface

uses uInterfaces, WinInet, SysUtils, Variants, uModule, uOSMCommon, uMap, uXML;

implementation

const

  netMapClassGUID:TGUID='{A3BB0528-D4AB-493E-A6E3-6B229EBD65F6}';
  httpStorageClassGUID:TGUID='{1C648623-9D76-47AB-88EF-B7000735DC6A}';

type
{$WARNINGS OFF}
  THTTPResponce=class(TOSManObject,IHTTPResponce)
  protected
    fState,fStatus:integer;
    fConn:HInternet;
    fReadBuf:array of byte;
    fReadBufSize:integer;
    procedure grow(const delta:cardinal);
  public
    constructor create();override;
    destructor destroy();override;
    procedure setStates(const aState,aStatus:integer);
    procedure setConnection(const hConnection:HInternet);
  published
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
    //wait for tranfer completition. On fuction exit all pending
    //  data send/receive completed and connection closed.
    procedure fetchAll();

    //maxBufSize: read buffer size
    //Readed data in zero-based one dimensional SafeArray of bytes (VT_ARRAY | VT_UI1)
    function read(const maxBufSize: integer): OleVariant;
    function get_eos(): WordBool;
    //"true" if end of stream reached, "false" otherwise
    property eos: WordBool read get_eos;
  end;
{$WARNINGS ON}

  THTTPStorage = class(TOSManObject, IHTTPStorage)
  protected
    fHostName:WideString;
    fTimeout,fMaxRetry:integer;
    fInet:HInternet;
  public
    //property setters-getters
    function get_hostName():WideString;
    procedure set_hostName(const aName:WideString);
    function get_timeout():integer;
    procedure set_timeout(const aTimeout:integer);
    function get_maxRetry():integer;
    procedure set_maxRetry(const aMaxRetry:integer);

    constructor create();override;
    destructor destroy();override;
  published
    //returns IHTTPResponce for request 'GET http://hostName/location'
    function get(const location:WideString):OleVariant;
    //hostname for OSM-API server. Official server is api.openstreetmap.org
    property hostName:WideString read get_hostName write set_hostName;
    //timeout for network operations (in ms). By default 20000ms (20 sec)
    property timeout:integer read get_timeout write set_timeout;
    //max retries for connection/DNS requests. By default 3.
    property maxRetry:integer read get_maxRetry write set_maxRetry;

  end;

  TNetMap = class(TAbstractMap)
  protected
    fFetchingResult: boolean;
    fResultObj: OleVariant;
    function fetchObject(const objLocation: WideString): OleVariant;
  published
    //get node by ID. If no node found returns false
    function getNode(const id: int64): OleVariant; override;
    //get way by ID. If no way found returns false
    function getWay(const id: int64): OleVariant; override;
    //get relation by ID. If no relation found returns false
    function getRelation(const id: int64): OleVariant; override;

    //store Node into Storage
    procedure putNode(const aNode: OleVariant); override;
    //store Way into Storage
    procedure putWay(const aWay: OleVariant); override;
    //store Relation into Storage
    procedure putRelation(const aRelation: OleVariant); override;

    //set HTTP-storage (IHTTPStorage). To free system resource set storage to unassigned
    //property storage:OleVariant read get_storage write set_storage;
  end;

  { TNetMap }

function TNetMap.fetchObject(const objLocation: WideString): OleVariant;
  procedure raiseError();
  begin
    raise EInOutError.create(toString() + '.fetchObject: network problem');
  end;
var
  hr: OleVariant;
  rdr: TOSMReader;
begin
  hr := fStorage.get(objLocation);
  hr.fetchAll();
  fResultObj := false;
  if (hr.getState() <> 4)then begin
    raiseError();
  end
  else
    //state=4
    case(hr.getStatus()) of
    404:exit;//not found
    410:exit;//deleted
    200:;//continue operation
    else
      raiseError();
    end;
  rdr := TOSMReader.create;
  try
    rdr.setInputStream(hr);
    rdr.setOutputMap(self as IDispatch);
    fFetchingResult := true;
    rdr.read(1);
  finally
    fFetchingResult := false;
  end;
  result := fResultObj;
end;

function TNetMap.getNode(const id: int64): OleVariant;
begin
  if not VarIsType(fStorage, varDispatch) then
    raise EInOutError.create(toString() + '.getNode: storage not assigned');
  result := fetchObject('/api/0.6/node/' + inttostr(id));
end;

function TNetMap.getRelation(const id: int64): OleVariant;
begin
  result := fetchObject('/api/0.6/relation/' + inttostr(id));
end;

function TNetMap.getWay(const id: int64): OleVariant;
begin
  result := fetchObject('/api/0.6/way/' + inttostr(id));
end;

procedure TNetMap.putNode(const aNode: OleVariant);
begin
  if not fFetchingResult then
    raise EInOutError.create(toString() + ': put operations not supported');
  fResultObj:=VarAsType(aNode,varDispatch);
end;

procedure TNetMap.putRelation(const aRelation: OleVariant);
begin
  if not fFetchingResult then
    raise EInOutError.create(toString() + ': put operations not supported');
  fResultObj := VarAsType(aRelation,varDispatch);
end;

procedure TNetMap.putWay(const aWay: OleVariant);
begin
  if not fFetchingResult then
    raise EInOutError.create(toString() + ': put operations not supported');
  fResultObj := VarAsType(aWay,varDispatch);;
end;

{ THTTPStorage }

constructor THTTPStorage.create;
begin
  inherited;
  maxRetry:=3;
  timeout:=20000;
  fInet:=nil;
  hostName:='api.openstreetmap.org';
end;

destructor THTTPStorage.destroy;
begin
  if assigned(fInet) then begin
    InternetCloseHandle(fInet);
    fInet:=nil;
  end;
  inherited;
end;

function THTTPStorage.get(const location: WideString): OleVariant;
var
  rCnt:integer;
  hConn:HInternet;
  resp:THTTPResponce;
begin
  rCnt:=maxRetry;
  resp:=THTTPResponce.Create();
  result:=resp as IDispatch;
  while (not assigned(fInet))and(rCnt>0) do begin
    fInet:=InternetOpen('OSMan.HTTPStorage.1',INTERNET_OPEN_TYPE_PRECONFIG, nil, nil,0);
    dec(rCnt);
    if (not assigned(fInet))and(rCnt>0) then
      sleep(fTimeout);
  end;
  if(not assigned(fInet))then begin
    resp.setStates(4,503);
    exit;
  end;
  hConn:=nil;
  rCnt:=maxRetry;
  while (not assigned(hConn))and(rCnt>0) do begin
    hConn:=InternetOpenUrlA(fInet,pAnsiChar(AnsiString('http://'+hostName+location)),nil,0,INTERNET_FLAG_NO_CACHE_WRITE or INTERNET_FLAG_NO_UI,0);
    dec(rCnt);
    if (not assigned(hConn))and(rCnt>0) then
      sleep(fTimeout);
  end;
  if(not assigned(hConn))then begin
    resp.setStates(4,504);
    exit;
  end;
  resp.setConnection(hConn);
end;

function THTTPStorage.get_hostName: WideString;
begin
  result:=fHostName;
end;

function THTTPStorage.get_maxRetry: integer;
begin
  result:=fMaxRetry;
end;

function THTTPStorage.get_timeout: integer;
begin
  result:=fTimeout;
end;

procedure THTTPStorage.set_hostName(const aName: WideString);
begin
  fHostName:=aName;
end;

procedure THTTPStorage.set_maxRetry(const aMaxRetry: integer);
begin
  if aMaxRetry<1 then
    fMaxRetry:=1
  else
    fMaxRetry:=aMaxRetry;
end;

procedure THTTPStorage.set_timeout(const aTimeout: integer);
begin
  if aTimeout<0 then
    fTimeout:=0
  else
    fTimeout:=aTimeout;
  
end;

{ THTTPResponce }

procedure THTTPResponce.fetchAll;
var
  ba,rd,stt:cardinal;
begin
  while true do begin
    if not InternetQueryDataAvailable(fConn,ba,0,0) then begin
      setStates(4,504);
      break;
    end;
    grow(ba);
    if not InternetReadFile(fConn,@fReadBuf[fReadBufSize],ba,rd) then begin
      setStates(4,504);
      break;
    end;
    inc(fReadBufSize,rd);
    if rd=0 then begin
      ba:=sizeof(stt);
      if HttpQueryInfoA(fConn,HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER,@stt,ba,rd) then
        setStates(4,stt)
      else
        setStates(4,504);
      break;
    end;
  end;
  InternetCloseHandle(fConn);
  fConn:=nil;
end;

function THTTPResponce.get_eos: WordBool;
begin
  result:=(fReadBufSize=0) and not assigned(fConn);
end;

function THTTPResponce.getState: integer;
var
  ba:cardinal;
begin
  result:=fState;
  if fState<>3 then
    exit;
  if InternetQueryDataAvailable(fConn,ba,0,0) then begin
    if ba>0 then fState:=3 else fState:=4;
  end
  else begin
    setStates(4,504);
  end;
  result:=fState;
end;

function THTTPResponce.getStatus: integer;
begin
  result:=fStatus;
end;

function THTTPResponce.read(const maxBufSize: integer): OleVariant;
  function min(const a,b:cardinal):cardinal;
  begin
    if a<b then result:=a
    else result:=b;
  end;
var
  p: pByte;
  reslen,ba,rd: cardinal;
  stt:integer;
begin
  if not((fState=3)or( (fState=4)and(fStatus=200)  )) then begin
    raise EInOutError.Create(toString()+': HTTP-connection error');
  end;
  result := VarArrayCreate([0, maxBufSize - 1], varByte);
  p := VarArrayLock(result);
  reslen:=0;
  try
    if fReadBufSize>0 then begin
      reslen:=min(maxBufSize,fReadBufSize);
      move(fReadBuf[0],p^,reslen);
      move(fReadBuf[reslen],fReadBuf[0],fReadBufSize-integer(reslen));
      dec(fReadBufSize,reslen);
      inc(p,reslen);
    end;
    while (integer(reslen)<maxBufSize) and not eos do begin
      if not InternetQueryDataAvailable(fConn,ba,0,0) then begin
        setStates(4,504);
        break;
      end;
      ba:=min(maxBufSize-integer(reslen),ba);
      if not InternetReadFile(fConn,p,ba,rd) then begin
        setStates(4,504);
        break;
      end;
      inc(reslen,rd);
      inc(p,rd);
      if rd=0 then begin
        ba:=sizeof(stt);
        if HttpQueryInfoA(fConn,HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER,@stt,ba,rd) then
          setStates(4,stt)
        else
          setStates(4,504);
        break;
      end;
    end;
    if (fState=4)and(assigned(fConn)) then begin
      InternetCloseHandle(fConn);
      fConn:=nil;
    end;
  finally
    VarArrayUnlock(result);
  end;
  if Integer(reslen) < maxBufSize then
    VarArrayRedim(result, Integer(reslen) - 1);
end;

constructor THTTPResponce.create;
begin
  inherited;
  fState:=0;
  fStatus:=100;
end;

procedure THTTPResponce.setConnection(const hConnection: HInternet);
begin
  fConn:=hConnection;
  setStates(3,206);
end;

procedure THTTPResponce.setStates(const aState, aStatus: integer);
begin
  fState:=aState;
  fStatus:=aStatus;
end;

destructor THTTPResponce.destroy;
begin
  if assigned(fConn) then
    InternetCloseHandle(fConn);
  inherited;
end;

procedure THTTPResponce.grow(const delta: cardinal);
begin
  if (fReadBufSize+integer(delta))>length(fReadBuf) then
    setLength(fReadBuf,(fReadBufSize+integer(delta)+4*1024-1)and (-4*1024));
end;

initialization
  OSManRegister(TNetMap,netMapClassGUID);
  OSManRegister(THTTPStorage,httpStorageClassGUID);
end.

