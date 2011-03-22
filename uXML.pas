unit uXML;

interface
uses uInterfaces, Variants, uOSMCommon, uModule, SysUtils, Classes, SAX, SAXHelpers, SAXMS;

type
  TMyXMLReader = class(TSAXMSXMLReader)
  public
    procedure setContentHandler(const handler: IContentHandler); override;
    function getContentHandler(): IContentHandler; override;
  end;

  TOSMReader = class(TOSManObject, ITransformInputStream, IMapWriter)
  protected
    inStreamAdaptor: TInputStreamAdaptor;
    fSAXReader: TMyXMLReader;
    fSAXError: WideString;
    //IMap
    oMap: OleVariant;
    function get_eos: WordBool;
  public
    destructor destroy; override;
  published
    //IInputStream
    function read(const maxBufSize: integer): OleVariant;
    property eos: WordBool read get_eos;
    //ITransformInputStream
    procedure setInputStream(const inStream: OleVariant);
    //IMapWriter
    procedure setOutputMap(const outMap: OleVariant);
  end;


implementation

uses Math, ConvUtils;

const
  osmReaderClassGUID: TGUID = '{1028B33B-C674-47F7-B032-4ADDF4B695D4}';
  osmWriterClassGUID: TGUID = '{8DB21D39-DC59-49B8-B22B-43CBC064271F}';

type
  TBaseHandler = class(TDefaultHandler)
  protected
    fParent: IContentHandler;
    fReader: TOSMReader;
    fNestedCount: integer;
    fOnDone: TNotifyEvent;
    procedure startElement(const uri, localName, qName: SAXString; const atts: IAttributes);
      override;
    procedure endElement(const uri, localName, qName: SAXString); override;

    procedure doOnDone(); virtual;

    procedure fatalError(const e: ISAXParseError); override;
    procedure raiseError(const msg: WideString);
    procedure raiseInvalidTag(const tag: WideString);
  public
    constructor create(reader: TOSMReader; const uri, localName, qName: SAXString; const atts:
      IAttributes; onDone: TNotifyEvent = nil); reintroduce; virtual;
    destructor destroy; override;
  end;

  TDocHandler = class(TBaseHandler)
  protected
    procedure startElement(const uri, localName, qName: SAXString; const atts: IAttributes);
      override;
  end;

  TOSCHandler = class(TBaseHandler)
  protected
    procedure startElement(const uri, localName, qName: SAXString; const atts: IAttributes);
      override;
  end;

  TDeleteHandler = class(TBaseHandler)
  protected
    procedure startElement(const uri, localName, qName: SAXString; const atts: IAttributes);override;
  end;

  TMapObjHandler = class(TBaseHandler)
  protected
    //IMapObject
    mapObj: OleVariant;
    //IKeyList
    objTags: OleVariant;
    procedure startElement(const uri, localName, qName: SAXString; const atts: IAttributes);
      override;

    procedure readObjAttributes(atts: IAttributes); virtual;
  public
    constructor create(reader: TOSMReader; const uri, localName, qName: SAXString; const atts:
      IAttributes; onDone: TNotifyEvent = nil); override;
  end;

  TOSMHandler = class(TBaseHandler)
  protected
    //TMapObjHandler.onDone event handler
    procedure onDoneAdd(sender: TObject);
    procedure startElement(const uri, localName, qName: SAXString; const atts: IAttributes);
      override;
  end;

  TNodeHandler = class(TMapObjHandler)
  protected
    procedure readObjAttributes(atts: IAttributes); override;
  public
    constructor create(reader: TOSMReader; const uri, localName, qName: SAXString; const atts:
      IAttributes; onDone: TNotifyEvent = nil); override;
  end;

  TWayHandler = class(TMapObjHandler)
  protected
    ndList: array of int64;
    ndCount: integer;
    procedure startElement(const uri, localName, qName: SAXString; const atts: IAttributes);
      override;
    procedure endElement(const uri, localName, qName: SAXString); override;

    procedure grow();
  public
    constructor create(reader: TOSMReader; const uri, localName, qName: SAXString; const atts:
      IAttributes; onDone: TNotifyEvent = nil); override;
  end;

  TRelationHandler = class(TMapObjHandler)
  protected
    //IRefList
    fRefList: OleVariant;
    procedure startElement(const uri, localName, qName: SAXString; const atts: IAttributes);
      override;
  public
    constructor create(reader: TOSMReader; const uri, localName, qName: SAXString; const atts:
      IAttributes; onDone: TNotifyEvent = nil); override;
  end;

  TOSMWriter=class(TOSManObject,ITransformOutputStream,IMapReader)
  protected
    inMap,oStream:OleVariant;
    fEOS,fShouldWriteHeader:boolean;
    fBuf:array [Word] of byte;
    fNextAvail:integer;
    procedure flush();
    function getObjAtts(const mapObject:OleVariant):WideString;
    function quote(const ws:WideString):WideString;
    procedure writeLine(const ws:WideString;const indent:integer=0);
    procedure writeHeader();
    procedure writeFooter();
    procedure writeNode(const node:OleVariant);
    procedure writeWay(const way:OleVariant);
    procedure writeRelation(const relation:OleVariant);
    procedure writeTags(const tagsArray:OleVariant);
  public
    constructor Create();override;
  published
    //Map for storing results
    procedure setInputMap(const inputMap: OleVariant);

    //output IOutputStream for transformed data
    procedure setOutputStream(const outStream: OleVariant);

    //Write data from map to outStream in OSM-XML format
    //aBuf can hold exporting options. List of available options see in Map.getObjects
    procedure write(const exportOptions:OleVariant);
    procedure set_eos(const aEOS:WordBool);
    function get_eos:WordBool;
    //write "true" if all data stored and stream should to release system resources
    //once set to "true" no write oprerations allowed on stream
    property eos: WordBool read get_eos write set_eos;

  end;

  { TOSMReader }

destructor TOSMReader.destroy;
begin
  if assigned(inStreamAdaptor) then
    FreeAndNil(inStreamAdaptor);
  oMap := Unassigned;
  inherited;
end;

function TOSMReader.get_eos: WordBool;
begin
  result := assigned(inStreamAdaptor) and inStreamAdaptor.eos;
end;

function TOSMReader.read(const maxBufSize: integer): OleVariant;
begin
  fSAXReader := nil;
  fSAXError := '';
  try
    try
      fSAXReader := TMyXMLReader.create();
      fSAXReader.setContentHandler(TDocHandler.create(self, '', '', '', nil));
      fSAXReader.ParseInput(TStreamInputSource.create(inStreamAdaptor, soReference));
    finally
      if assigned(fSAXReader) then
        FreeAndNil(fSAXReader);
    end;
  except
    on e: Exception do begin
      if fSAXError <> '' then begin
        raise ESAXException.create(fSAXError);
      end
      else begin
        raise;
      end;
    end;
  end;
end;

procedure TOSMReader.setInputStream(const inStream: OleVariant);
begin
  if assigned(inStreamAdaptor) then
    raise EInOutError.create(toString() + ': input stream already assigned');
  inStreamAdaptor := TInputStreamAdaptor.create(inStream);
end;

procedure TOSMReader.setOutputMap(const outMap: OleVariant);
begin
  if VarIsType(oMap,varDispatch) then
    raise EInOutError.create(toString() + ': output map already assigned');
  oMap := outMap;
end;

{ TBaseHandler }

constructor TBaseHandler.create(reader: TOSMReader; const uri, localName, qName: SAXString; const
  atts: IAttributes; onDone: TNotifyEvent = nil);
begin
  fReader := reader;
  fParent := reader.fSAXReader.getContentHandler();
  fNestedCount := 1;
  fOnDone := onDone;
  reader.fSAXReader.setContentHandler(self);
end;

destructor TBaseHandler.destroy;
begin
  fParent := nil;
  fReader := nil;
  inherited;
end;

procedure TBaseHandler.doOnDone;
begin
  if assigned(fOnDone) then
    fOnDone(self);
end;

procedure TBaseHandler.endElement(const uri, localName, qName: SAXString);
begin
  dec(fNestedCount);
  if fNestedCount = 0 then begin
    try
      doOnDone();
    finally
      fReader.fSAXReader.setContentHandler(fParent);
      fParent.endElement(uri,localName,qName);
    end;
  end;
end;

procedure TBaseHandler.fatalError(const e: ISAXParseError);
begin
  fReader.fSAXError := e.getMessage();
end;

procedure TBaseHandler.raiseError(const msg: WideString);
begin
  fReader.fSAXError := msg;
  raise ESAXParseException.create(msg);
end;

procedure TBaseHandler.raiseInvalidTag(const tag: WideString);
begin
  raiseError(ClassName() + ': invalid <' + tag + '> tag');
end;

procedure TBaseHandler.startElement(const uri, localName, qName: SAXString;
  const atts: IAttributes);
begin
  inc(fNestedCount);
end;

{ TMyXMLReader }

function TMyXMLReader.getContentHandler: IContentHandler;
begin
  result := inherited getContentHandler();
end;

procedure TMyXMLReader.setContentHandler(const handler: IContentHandler);
begin
  inherited;
end;

{ TDocHandler }

procedure TDocHandler.startElement(const uri, localName, qName: SAXString;
  const atts: IAttributes);
begin
  inherited;
  if qName = 'osm' then
    TOSMHandler.create(fReader, uri, localName, qName, atts)
  else if qName= 'osmChange' then
    TOSCHandler.create(fReader,uri,localName,qName,atts)
  else
    raiseError('TDocHandler.startElement: unexpected element <'+qName+'>');
end;

{ TOSMHandler }

procedure TOSMHandler.onDoneAdd(sender: TObject);
var
  mo: TMapObjHandler;
begin
  mo := sender as TMapObjHandler;
  fReader.oMap.putObject(mo.mapObj);
end;

procedure TOSMHandler.startElement(const uri, localName, qName: SAXString;
  const atts: IAttributes);
begin
  inherited;
  if qName = 'node' then
    TNodeHandler.create(fReader, uri, localName, qName, atts, onDoneAdd)
  else if qName = 'way' then
    TWayHandler.create(fReader, uri, localName, qName, atts, onDoneAdd)
  else if qName = 'relation' then
    TRelationHandler.create(fReader, uri, localName, qName, atts, onDoneAdd)
  else if (qName = 'bound') or (qName = 'bounds') then
    TBaseHandler.create(fReader, uri, localName, qName, atts)
  else
    raiseInvalidTag(qName);
end;

{ TMapObjHandler }

constructor TMapObjHandler.create(reader: TOSMReader; const uri, localName,
  qName: SAXString; const atts: IAttributes; onDone: TNotifyEvent);
begin
  inherited;
  objTags := Unassigned;
end;

procedure TMapObjHandler.readObjAttributes(atts: IAttributes);

  function readDef(const aName, defVal: WideString): WideString;
  begin
    result := atts.getValue(aName);
    if result = '' then begin
      result := defVal;
    end;
  end;

begin
  mapObj.id := WideStrToInt64(atts.getValue('id'));
  mapObj.version := WideStrToInt(readDef('version', '0'));
  mapObj.userId := WideStrToInt(readDef('uid', '0'));
  mapObj.userName := atts.getValue('user');
  mapObj.changeset := WideStrToInt64(readDef('changeset', '0'));
  mapObj.timestamp := atts.getValue('timestamp');
end;

procedure TMapObjHandler.startElement(const uri, localName,
  qName: SAXString; const atts: IAttributes);
begin
  inherited;
  if qName <> 'tag' then exit;
  if VarIsEmpty(objTags) then begin
    objTags := mapObj.tags;
  end;
  objTags.setByKey(atts.getValue('k'), atts.getValue('v'));
end;

{ TNodeHandler }

constructor TNodeHandler.create(reader: TOSMReader; const uri, localName,
  qName: SAXString; const atts: IAttributes; onDone: TNotifyEvent);
begin
  inherited;
  mapObj := fReader.oMap.createNode;
  readObjAttributes(atts);
end;

procedure TNodeHandler.readObjAttributes(atts: IAttributes);
begin
  inherited;
  mapObj.lat := StrToFloat(atts.getValue('lat'));
  mapObj.lon := StrToFloat(atts.getValue('lon'));
end;

{ TWayHandler }

constructor TWayHandler.create(reader: TOSMReader; const uri, localName,
  qName: SAXString; const atts: IAttributes; onDone: TNotifyEvent);
begin
  inherited;
  mapObj := fReader.oMap.createWay;
  readObjAttributes(atts);
  ndCount := 0;
  setLength(ndList, 14);
end;

procedure TWayHandler.endElement(const uri, localName, qName: SAXString);
var
  v: Variant;
  i: integer;
  pv: PVarData;
begin
  if (fNestedCount = 1) and (ndCount > 0) then begin
    v := VarArrayCreate([0, ndCount - 1], varVariant);
    pv := VarArrayLock(v);
    try
      for i := 0 to ndCount - 1 do begin
        pv.VType := varInt64;
        pv.VInt64 := ndList[i];
        inc(pv);
      end;
    finally
      VarArrayUnlock(v);
    end;
    mapObj.nodes := v;
  end;
  inherited;
end;

procedure TWayHandler.grow;
begin
  if ndCount >= length(ndList) then begin
    setLength(ndList, ndCount * 2);
  end;
end;

procedure TWayHandler.startElement(const uri, localName, qName: SAXString;
  const atts: IAttributes);
var
  i64: int64;
begin
  inherited;
  if qName <> 'nd' then exit;
  i64 := StrToInt64(atts.getValue('ref'));
  inc(ndCount);
  grow();
  ndList[ndCount - 1] := i64;
end;

{ TRelationHandler }

constructor TRelationHandler.create(reader: TOSMReader; const uri,
  localName, qName: SAXString; const atts: IAttributes;
  onDone: TNotifyEvent);
begin
  inherited;
  mapObj := fReader.oMap.createRelation;
  fRefList := Unassigned;
  readObjAttributes(atts);
end;

procedure TRelationHandler.startElement(const uri, localName,
  qName: SAXString; const atts: IAttributes);
begin
  inherited;
  if qName <> 'member' then exit;
  if VarIsEmpty(fRefList) then
    fRefList := mapObj.members;
  fRefList.insertBefore(maxInt, atts.getValue('type'), StrToInt64(atts.getValue('ref')),
    atts.getValue('role'));
end;

{ TOSCHandler }

procedure TOSCHandler.startElement(const uri, localName, qName: SAXString;
  const atts: IAttributes);
begin
  inherited;
  if (qName ='modify') or (qName= 'create') then
    TOSMHandler.create(fReader, uri, localName, qName, atts)
  else if qName = 'delete' then
    TDeleteHandler.create(fReader, uri, localName, qName, atts)
  else
    raiseInvalidTag(qName);
end;

{ TDeleteHandler }

procedure TDeleteHandler.startElement(const uri, localName,
  qName: SAXString; const atts: IAttributes);
var
  id:int64;
begin
  inherited;
  if fNestedCount>2 then
    //ignore tags,references,members
    exit;
  id:=WideStrToInt64(atts.getValue('id'));
  if qName='node' then
    fReader.oMap.deleteNode(id)
  else if qName='way' then
    fReader.oMap.deleteWay(id)
  else if qName='relation' then
    fReader.oMap.deleteRelation(id)
  else
    raiseInvalidTag(qName);
end;

{ TOSMWriter }

constructor TOSMWriter.Create;
begin
  inherited;
  fShouldWriteHeader:=true;
end;

procedure TOSMWriter.flush;
var
  v:OleVariant;
  p:PByte;
begin
  if not varIsType(oStream,varDispatch) then
    raise EInOutError.Create(toString()+'.flush: out stream not assigned');
  v:=varArrayCreate([0,fNextAvail-1],varByte);
  p:=varArrayLock(v);
  try
    move(fBuf,p^,fNextAvail);
  finally
    varArrayUnlock(v);
  end;
  oStream.write(v);
  fNextAvail:=0;
end;

function TOSMWriter.getObjAtts(const mapObject: OleVariant): WideString;
begin
  result:=WideString('id="')+IntToStr(MapObject.id)+'" version="'+inttostr(MapObject.version)+
    '" timestamp="'+MapObject.timestamp+'" uid="'+inttostr(MapObject.userId)+
    '" user="'+quote(MapObject.userName)+'" changeset="'+inttostr(MapObject.changeset)+'"';
end;

function TOSMWriter.get_eos: WordBool;
begin
  result:=fEOS;
end;

function TOSMWriter.quote(const ws: WideString): WideString;
//As stated in http://www.w3.org/TR/2008/REC-xml-20081126/#syntax
// & < > ' " should be quoted
const
  amp:WideString='&amp;';
  lt:WideString='&lt;';
  gt:WideString='&gt;';
  apos:WideString='&apos;';
  quot:WideString='&quot;';
var
  ol,nl,i:integer;
  pwc,pwc1:PWideChar;
begin
  result:='';
  ol:=length(ws);
  if ol=0 then
    exit;
  nl:=ol;
  pwc:=PWideChar(ws);
  for i:=1 to ol do begin
    case pwc^ of
    '&':inc(nl,length(amp)-1);
    '<':inc(nl,length(lt)-1);
    '>':inc(nl,length(gt)-1);
    '''':inc(nl,length(apos)-1);
    '"':inc(nl,length(quot)-1);
    end;
    inc(pwc);
  end;
  if nl=ol then begin
    result:=ws;
    exit;
  end;
  setLength(result,nl);
  pwc:=PWideChar(ws);
  pwc1:=PWideChar(result);
  for i:=1 to ol do begin
    case pwc^ of
    '&':begin
        move(amp[1],pwc1^,length(amp)*sizeof(WideChar));
        inc(pwc1,length(amp)-1);
      end;
    '<':begin
        move(lt[1],pwc1^,length(lt)*sizeof(WideChar));
        inc(pwc1,length(lt)-1);
      end;
    '>':begin
        move(gt[1],pwc1^,length(gt)*sizeof(WideChar));
        inc(pwc1,length(gt)-1);
      end;
    '''':begin
        move(apos[1],pwc1^,length(apos)*sizeof(WideChar));
        inc(pwc1,length(apos)-1);
      end;
    '"':begin
        move(quot[1],pwc1^,length(quot)*sizeof(WideChar));
        inc(pwc1,length(quot)-1);
      end;
    else
      pwc1^:=pwc^;
    end;
    inc(pwc);
    inc(pwc1);
  end;
end;

procedure TOSMWriter.setInputMap(const inputMap: OleVariant);
begin
  inMap:=inputMap;
end;

procedure TOSMWriter.setOutputStream(const outStream: OleVariant);
begin
  if VarIsType(oStream,varDispatch) then
    flush();
  oStream:=outStream;
end;

procedure TOSMWriter.set_eos(const aEOS: WordBool);
begin
  if (not eos) and aEOS then begin
    writeFooter();
    flush();
  end;
  fEOS:=eos or aEOS;
  if VarIsType(oStream,varDispatch) then
    oStream.eos:=fEOS;
end;

procedure TOSMWriter.write(const exportOptions: OleVariant);
var
  //IQueryResult
  allObjects:OleVariant;
  //IMapObject
  mo:OleVariant;
  s:WideString;
begin
  if not varIsType(oStream,varDispatch) then
    raise EInOutError.Create(toString()+'.write: out stream not assigned');
  if not varIsType(inMap,varDispatch) then
    raise EInOutError.Create(toString()+'.write: input map not assigned');
  if fShouldWriteHeader then
    writeHeader();
  fShouldWriteHeader:=false;
  allObjects:=inMap.getObjects(exportOptions);
  while not allObjects.eos do begin
    mo:=allObjects.read(1);
    if not VarIsType(mo,varDispatch) then begin
      if not allObjects.eos then
        raise  EInOutError.Create(toString()+'.write: unexpected result of Map.getObjects.Read')
      else begin
        eos:=true;
        break;
      end;
    end;
    s:=mo.getClassName;
    if s='Node' then
      writeNode(mo)
    else if s='Way' then
      writeWay(mo)
    else if s='Relation' then
      writeRelation(mo)
    else
      raise EInOutError.Create(toString()+'.write: illegal object type <'+s+'>');
  end;
  eos:=true;
end;

procedure TOSMWriter.writeFooter;
begin
  writeLine('</osm>');
end;

procedure TOSMWriter.writeHeader;
begin
  writeLine('<?xml version="1.0" encoding="UTF-8" ?>');
  writeLine('<osm version="0.6" generator="Osman '+getClassName()+'">');
end;

procedure TOSMWriter.writeLine(const ws: WideString;
  const indent: integer);
var
  u8s:Utf8String;
  i,l:integer;
  pb,pc:PByte;
begin
  u8s:=UTF8Encode(ws)+#13#10;
  pb:=@fBuf[fNextAvail];
  for i:=1 to indent*2 do begin
    pb^:=ord(' ');
    inc(pb);
    inc(fNextAvail);
    if fNextAvail=SizeOf(fBuf) then begin
      flush();
      pb:=@fBuf[0];
    end;
  end;
  l:=length(u8s);
  pc:=@u8s[1];
  for i:=1 to l do begin
    pb^:=pc^;
    inc(pb);
    inc(pc);
    inc(fNextAvail);
    if fNextAvail=SizeOf(fBuf) then begin
      flush();
      pb:=@fBuf[0];
    end;
  end;
end;

procedure TOSMWriter.writeNode(const node: OleVariant);
var
  s:WideString;
  v:OleVariant;
begin
  s:=WideString('<node ')+getObjAtts(node)+' lat="'+degToStr(node.lat)+
    '" lon="'+degToStr(node.lon)+'"';
  v:=node.tags.getAll;
  if (VarArrayDimCount(v)=1)and (VarArrayHighBound(v,1)-VarArrayLowBound(v,1)>=0) then begin
  //object has tags
    writeLine(s+'>',1);
    writeTags(v);
    writeLine('</node>',1);
  end
  else begin
    writeLine(s+'/>',1);
  end;
end;

procedure TOSMWriter.writeRelation(const relation: OleVariant);
var
  s:WideString;
  t,m:OleVariant;
  pv,pv1,pv2:PVarData;
  emptyRelation:boolean;
  i:integer;
  i64:int64;
begin
  s:=WideString('<relation ')+getObjAtts(relation);
  t:=relation.tags.getAll;
  m:=relation.members.getAll;
  emptyRelation:=true;
  if not VarIsType(m,varArray or varVariant) then
    raise EInOutError.Create(toString()+'.writeRelation: invalid member ref');
  if (VarArrayDimCount(m)=1)and (VarArrayHighBound(m,1)-VarArrayLowBound(m,1)>=0) then begin
    //write members
    i:=VarArrayHighBound(m,1)-VarArrayLowBound(m,1)+1;
    if (i mod 3)<>0 then
      raise EInOutError.Create(toString()+'.writeRelation: invalid member count');
    emptyRelation:=false;
    writeLine(s+'>',1);
    pv:=VarArrayLock(m);
    try
      pv1:=pv;
      inc(pv1);
      pv2:=pv;
      inc(pv2,2);
    while i>0 do begin
      i64:=PVariant(pv1)^;
      writeLine(WideString('<member type="')+PVariant(pv)^+'" ref="'+inttostr(i64)+'" role="'+quote(PVariant(pv2)^)+'"/>',2);
      inc(pv,3);
      inc(pv1,3);
      inc(pv2,3);
      dec(i,3);
    end;
    finally
      VarArrayUnlock(m);
    end;
  end;
  if (VarArrayDimCount(t)=1)and (VarArrayHighBound(t,1)-VarArrayLowBound(t,1)>=0) then begin
  //object has tags
    if emptyRelation then
      writeLine(s+'>',1);
    writeTags(t);
    emptyRelation:=false;
  end;
  if emptyRelation then
    writeLine(s+'/>')
  else
    writeLine('</relation>',1);
end;

procedure TOSMWriter.writeTags(const tagsArray: OleVariant);
var
  pv,pk:PVariant;
  n:integer;
begin
  n:=(VarArrayHighBound(tagsArray,1)-VarArrayLowBound(tagsArray,1)+1)div 2;
  pk:=VarArrayLock(tagsArray);
  pv:=pk;
  inc(pv);
  try
    while n>0 do begin
      writeLine(WideString('<tag k="')+quote(pk^)+'" v="'+quote(pv^)+'"/>',2);
      dec(n);
      inc(pk,2);
      inc(pv,2);
    end;
  finally
    VarArrayUnlock(tagsArray);
  end;
end;

procedure TOSMWriter.writeWay(const way: OleVariant);
var
  s:WideString;
  t,n:OleVariant;
  pv:PVarData;
  emptyWay:boolean;
  i:integer;
  i64:int64;
begin
  s:=WideString('<way ')+getObjAtts(way);
  t:=way.tags.getAll;
  n:=way.nodes;
  emptyWay:=true;
  if not VarIsType(n,varArray or varVariant) then
    raise EInOutError.Create(toString()+'.writeWay: invalid node ref');
  if (VarArrayDimCount(n)=1)and (VarArrayHighBound(n,1)-VarArrayLowBound(n,1)>=0) then begin
    emptyWay:=false;
    writeLine(s+'>',1);
    i:=VarArrayHighBound(n,1)-VarArrayLowBound(n,1)+1;
    pv:=VarArrayLock(n);
    try
    while i>0 do begin
      i64:=pVariant(pv)^;
      writeLine('<nd ref="'+inttostr(i64)+'"/>',2);
      inc(pv);
      dec(i);
    end;
    finally
    VarArrayUnlock(n);
    end;
  end;
  if (VarArrayDimCount(t)=1)and (VarArrayHighBound(t,1)-VarArrayLowBound(t,1)>=0) then begin
  //object has tags
    if emptyWay then
      writeLine(s+'>',1);
    writeTags(t);
    emptyWay:=false;
  end;
  if emptyWay then
    writeLine(s+'/>')
  else
    writeLine('</way>',1);
end;

initialization
  uModule.OSManRegister(TOSMReader, osmReaderClassGUID);
  uModule.OSManRegister(TOSMWriter, osmWriterClassGUID);
end.

