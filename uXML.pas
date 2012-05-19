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
  osmFastWriterClassGUID: TGUID = '{73D595DA-2EDB-4A6F-8370-30E0834E2D63}';

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
    procedure startElement(const uri, localName, qName: SAXString; const atts: IAttributes);
      override;
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

  TUTF8Writer = class(TOSManObject, ITransformOutputStream)
  private
    //transfrom UTF16 strings into UFT8 byteArray variant stream
  protected
    oStream: OleVariant;
    fBuf: array[Word] of byte;
    fNextAvail: integer;
    fEOS: boolean;
    constructor create(); override;
    destructor destroy(); override;
    function quote(const ws: WideString): WideString;
    procedure flush();
    procedure CRLF();
    procedure writeUTF8(pc:PAnsiChar;l:integer);overload;
    procedure writeUTF8(const s:UTF8String);overload;
    procedure writeUTF16(pc:PWideChar);overload;
    procedure writeUTF16(const w: WideString);overload;
    procedure writeLineUTF16(const w: WideString);
    procedure writeLineUTF8(const s: UTF8String; const indent: integer = 0);
  published
    //aBuf - unicode string variant
    procedure write(const aBuf: OleVariant);
    procedure set_eos(const aEOS: WordBool);virtual;
    function get_eos: WordBool;
    //set pipelined output stream
    procedure setOutputStream(const outStream: OleVariant);
    //write "true" if all data stored and stream should release system resources
    //once set to "true" no write oprerations allowed on stream
    property eos: WordBool read get_eos write set_eos;
  end;

  TOSMWriter = class(TUTF8Writer, IMapReader)
  protected
    inMap: Variant;
    fShouldWriteHeader: boolean;
    function getObjAtts(const mapObject: OleVariant): UTF8String;
    procedure writeHeader();
    procedure writeFooter();
    procedure writeNode(const node: OleVariant);
    procedure writeWay(const way: OleVariant);
    procedure writeRelation(const relation: OleVariant);
    procedure writeTags(const tagsArray: OleVariant);
  public
    constructor create(); override;
  published
    //Map for storing results
    procedure setInputMap(const inputMap: OleVariant);

    //Write data from map to outStream in OSM-XML format
    //aBuf can hold exporting options. List of available options see in Map.getObjects
    procedure write(const exportOptions: OleVariant);
    procedure set_eos(const aEOS: WordBool);override;
  end;

  TFastOSMWriter = class(TUTF8Writer, IMapReader)
  protected
    inMap,inStg: Variant;
    procedure writeHeader();
    procedure writeNodes();
    procedure writeWays();
    procedure writeRelations();
    procedure writeFooter();
  published
    //Map for storing results
    procedure setInputMap(const inputMap: OleVariant);

    //Write data from map to outStream in OSM-XML format
    //no filtering supported
    procedure write(const dummy: OleVariant);
    procedure set_eos(const aEOS: WordBool);override;
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
  if VarIsType(oMap, varDispatch) then
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
      fParent.endElement(uri, localName, qName);
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
  else if qName = 'osmChange' then
    TOSCHandler.create(fReader, uri, localName, qName, atts)
  else
    raiseError('TDocHandler.startElement: unexpected element <' + qName + '>');
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
  if (qName = 'modify') or (qName = 'create') then
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
  id: int64;
begin
  inherited;
  if fNestedCount > 2 then
    //ignore tags,references,members
    exit;
  id := WideStrToInt64(atts.getValue('id'));
  if qName = 'node' then
    fReader.oMap.deleteNode(id)
  else if qName = 'way' then
    fReader.oMap.deleteWay(id)
  else if qName = 'relation' then
    fReader.oMap.deleteRelation(id)
  else
    raiseInvalidTag(qName);
end;

{ TOSMWriter }

constructor TOSMWriter.create;
begin
  inherited;
  fShouldWriteHeader := true;
end;

function TOSMWriter.getObjAtts(const mapObject: OleVariant): UTF8String;
begin
  result := 'id="' + IntToStr(mapObject.id) + '" version="' + IntToStr(mapObject.version) +
    '" timestamp="' + mapObject.timestamp + '" uid="' + IntToStr(mapObject.userId) +
    '" user="' + UTF8Encode(quote(mapObject.userName)) + '" changeset="' +
    IntToStr(mapObject.changeset) + '"';
end;

procedure TOSMWriter.setInputMap(const inputMap: OleVariant);
begin
  varCopyNoInd(inMap, inputMap);
end;

procedure TOSMWriter.set_eos(const aEOS: WordBool);
begin
  if (not eos) and aEOS then begin
    writeFooter();
  end;
  inherited set_eos(aEOS);
end;

procedure TOSMWriter.write(const exportOptions: OleVariant);
var
  //IQueryResult
  allObjects: OleVariant;
  //IMapObject
  mo: OleVariant;
  pv: POleVariant;
  s: WideString;
  l: integer;
begin
  if not VarIsType(oStream, varDispatch) then
    raise EInOutError.create(toString() + '.write: out stream not assigned');
  if not VarIsType(inMap, varDispatch) then
    raise EInOutError.create(toString() + '.write: input map not assigned');
  if fShouldWriteHeader then
    writeHeader();
  fShouldWriteHeader := false;
  allObjects := inMap.getObjects(exportOptions);
  while not allObjects.eos do begin
    mo := allObjects.read(1000);
    if not VarIsArray(mo) or (VarArrayDimCount(mo) <> 1) then
      raise EInOutError.create(toString() + '.write: result of Map.getObjects.Read is not array');
    l := varArrayLength(mo);
    pv := VarArrayLock(mo);
    try
      while (l > 0) do begin
        if not VarIsType(pv^, varDispatch) then begin
          if not allObjects.eos then
            raise EInOutError.create(toString() +
              '.write: unexpected result of Map.getObjects.Read')
          else begin
            eos := true;
            break;
          end;
        end;
        s := pv^.getClassName;
        if s = 'Node' then
          writeNode(pv^)
        else if s = 'Way' then
          writeWay(pv^)
        else if s = 'Relation' then
          writeRelation(pv^)
        else
          raise EInOutError.create(toString() + '.write: illegal object type <' + s + '>');
        inc(pv);
        dec(l);
      end;
    finally
      VarArrayUnlock(mo);
    end;
  end;
  eos := true;
end;

procedure TOSMWriter.writeFooter;
begin
  writeLineUTF8('</osm>');
end;

procedure TOSMWriter.writeHeader;
begin
  writeLineUTF8('<?xml version="1.0" encoding="UTF-8" ?>');
  writeLineUTF8('<osm version="0.6" generator="Osman ' + getClassName() + '">');
end;

procedure TOSMWriter.writeNode(const node: OleVariant);
var
  s: UTF8String;
  v: OleVariant;
begin
  s := '<node '+getObjAtts(node)+' lat="' + degToStr(node.lat) +
    '" lon="' + degToStr(node.lon) + '"';
  v := node.tags.getAll;
  if (VarArrayDimCount(v) = 1) and (varArrayLength(v) > 0) then begin
    //object has tags
    writeLineUTF8(s + '>', 1);
    writeTags(v);
    writeLineUTF8('</node>', 1);
  end
  else begin
    writeLineUTF8(s + '/>', 1);
  end;
end;

procedure TOSMWriter.writeRelation(const relation: OleVariant);
var
  s: UTF8String;
  t, m: OleVariant;
  pv, pv1, pv2: PVarData;
  emptyRelation: boolean;
  i: integer;
  i64: int64;
begin
  s := '<relation ' + getObjAtts(relation);
  t := relation.tags.getAll;
  m := relation.members.getAll;
  emptyRelation := true;
  if not VarIsType(m, varArray or varVariant) then
    raise EInOutError.create(toString() + '.writeRelation: invalid member ref');
  if (VarArrayDimCount(t) = 1) and (varArrayLength(t) > 0) then begin
    //object has tags
    if emptyRelation then begin
      writeLineUTF8(s + '>', 1);
      emptyRelation := false;
    end;
    writeTags(t);
  end;
  if (VarArrayDimCount(m) = 1) and (VarArrayLength(m)> 0) then
    begin
    //write members
    i := VarArrayLength(m);
    if (i mod 3) <> 0 then
      raise EInOutError.create(toString() + '.writeRelation: invalid member count');
    if emptyRelation then begin
      emptyRelation := false;
      writeLineUTF8(s + '>', 1);
    end;
    pv := VarArrayLock(m);
    try
      pv1 := pv;
      inc(pv1);
      pv2 := pv;
      inc(pv2, 2);
      while i > 0 do begin
        i64 := PVariant(pv1)^;
        writeLineUTF8('<member type="' + PVariant(pv)^ + '" ref="' + IntToStr(i64) + '" role="' +
          UTF8Encode(quote(PVariant(pv2)^)) + '"/>', 2);
        inc(pv, 3);
        inc(pv1, 3);
        inc(pv2, 3);
        dec(i, 3);
      end;
    finally
      VarArrayUnlock(m);
    end;
  end;
  if emptyRelation then
    writeLineUTF8(s + '/>')
  else
    writeLineUTF8('</relation>', 1);
end;

procedure TOSMWriter.writeTags(const tagsArray: OleVariant);
var
  pv, pk: PVariant;
  n: integer;
begin
  n := VarArrayLength(tagsArray) div 2;
  pk := VarArrayLock(tagsArray);
  pv := pk;
  inc(pv);
  try
    while n > 0 do begin
      writeLineUTF8('<tag k="' + UTF8Encode(quote(pk^)) + '" v="' + UTF8Encode(quote(pv^)) + '"/>',
        2);
      dec(n);
      inc(pk, 2);
      inc(pv, 2);
    end;
  finally
    VarArrayUnlock(tagsArray);
  end;
end;

procedure TOSMWriter.writeWay(const way: OleVariant);
var
  s: UTF8String;
  t, n: OleVariant;
  pv: PVarData;
  emptyWay: boolean;
  i: integer;
  i64: int64;
begin
  s := '<way ' + getObjAtts(way);
  t := way.tags.getAll;
  n := way.nodes;
  emptyWay := true;
  if not VarIsType(n, varArray or varVariant) then
    raise EInOutError.create(toString() + '.writeWay: invalid node ref');
  if (VarArrayDimCount(t) = 1) and (varArrayLength(t) > 0) then begin
    //object has tags
    emptyWay:=false;
    writeLineUTF8(s + '>', 1);
    writeTags(t);
  end;
  if (VarArrayDimCount(n) = 1) and (varArrayLength(n) > 0) then begin
    if emptyWay then begin
      emptyWay := false;
      writeLineUTF8(s + '>', 1);
    end;
    i := varArrayLength(n);
    pv := VarArrayLock(n);
    try
      while i > 0 do begin
        i64 := PVariant(pv)^;
        writeLineUTF8('<nd ref="' + IntToStr(i64) + '"/>', 2);
        inc(pv);
        dec(i);
      end;
    finally
      VarArrayUnlock(n);
    end;
  end;
  if emptyWay then
    writeLineUTF8(s + '/>')
  else
    writeLineUTF8('</way>', 1);
end;

{ TUTF8Writer }

constructor TUTF8Writer.create;
begin
  inherited;
  fEOS := true;
end;

destructor TUTF8Writer.destroy;
begin
  eos := true;
  inherited;
end;

procedure TUTF8Writer.flush;
var
  v: OleVariant;
  p: PByte;
begin
  if not VarIsType(oStream, varDispatch) then
    raise EInOutError.create(toString() + '.flush: out stream not assigned');
  v := VarArrayCreate([0, fNextAvail - 1], varByte);
  p := VarArrayLock(v);
  try
    move(fBuf, p^, fNextAvail);
  finally
    VarArrayUnlock(v);
  end;
  oStream.write(v);
  fNextAvail := 0;
end;

function TUTF8Writer.get_eos: WordBool;
begin
  result := fEOS;
end;

procedure TUTF8Writer.set_eos(const aEOS: WordBool);
begin
  if (not eos) and aEOS then begin
    flush();
  end;
  fEOS := eos or aEOS;
  if VarIsType(oStream, varDispatch) then
    oStream.eos := fEOS;
end;

procedure TUTF8Writer.setOutputStream(const outStream: OleVariant);
begin
  if VarIsType(oStream, varDispatch) then
    flush();
  oStream := outStream;
  fEOS := outStream.eos;
end;

procedure TUTF8Writer.write(const aBuf: OleVariant);
var
  p: PVarData;
begin
  p := @aBuf;
  while (p.VType and varByRef) <> 0 do p := p.VPointer;
  if (p.VType = varOleStr) then begin
    writeLineUTF16(p.VOleStr);
  end
  else begin
    writeLineUTF16(aBuf);
  end;
end;

procedure TUTF8Writer.writeLineUTF16(const w: WideString);
begin
  writeUTF16(w);
  CRLF();
end;

procedure TUTF8Writer.writeLineUTF8(const s: UTF8String;
  const indent: integer);
var
  pb: PByte;
  i, l: integer;
begin
  pb := @fBuf[fNextAvail];
  l := indent * 2;
  while l > 0 do begin
    i := sizeof(fBuf) - fNextAvail;
    if (i > l) then
      i := l;
    fillchar(pb^, i, ' ');
    inc(fNextAvail, i);
    inc(pb, i);
    dec(l, i);
    if (fNextAvail = sizeof(fBuf)) then begin
      flush();
      pb := @fBuf[0];
    end;
  end;
  writeUTF8(PAnsiChar(s), length(s));
  CRLF();
end;

procedure TUTF8Writer.CRLF();
begin
  if((fNextAvail+2)>sizeOf(fBuf)) then
    flush();
  fBuf[fNextAvail] := 13;
  inc(fNextAvail);
  fBuf[fNextAvail] := 10;
  inc(fNextAvail);
  if (fNextAvail >= sizeof(fBuf)) then flush();
end;

procedure TUTF8Writer.writeUTF8(pc: PAnsiChar; l: integer);
var
  i: integer;
  pb: PByte;
begin
  pb:=@fBuf[fNextAvail];
  while l > 0 do begin
    i := sizeof(fBuf) - fNextAvail;
    if (i > l) then
      i := l;
    move(pc^, pb^, i);
    inc(fNextAvail, i);
    inc(pc, i);
    inc(pb, i);
    dec(l, i);
    if (fNextAvail = sizeof(fBuf)) then begin
      flush();
      pb := @fBuf[0];
    end;
  end;
end;

procedure TUTF8Writer.writeUTF16(pc: PWideChar);
var
  cnt: integer;
begin
  if(fNextAvail*2>=sizeOf(fBuf)) then
    flush();
  cnt := UnicodeToUtf8(@fBuf[fNextAvail], pc,sizeof(fBuf) - fNextAvail);
  if (cnt + fNextAvail) >= sizeof(fBuf) then begin
    flush();
    cnt := UnicodeToUtf8(@fBuf[fNextAvail], pc, sizeof(fBuf) - fNextAvail);
    if (cnt + fNextAvail) >= sizeof(fBuf) then
      raise EConvertError.create(toString() + '.writeUTF16: too long string');
  end;
  inc(fNextAvail, cnt - 1);
end;

procedure TUTF8Writer.writeUTF8(const s: UTF8String);
begin
  writeUTF8(pAnsiChar(s),length(s));
end;

procedure TUTF8Writer.writeUTF16(const w: WideString);
begin
  writeUTF16(pWideChar(w));
end;

function TUTF8Writer.quote(const ws: WideString): WideString;
//As stated in http://www.w3.org/TR/2008/REC-xml-20081126/#syntax
// & < > ' " should be quoted
const
  amp: WideString = '&amp;';
  lt: WideString = '&lt;';
  gt: WideString = '&gt;';
  apos: WideString = '&apos;';
  quot: WideString = '&quot;';
var
  ol, nl, i: integer;
  pwc, pwc1: PWideChar;
begin
  result := '';
  ol := length(ws);
  if ol = 0 then
    exit;
  nl := ol;
  pwc := PWideChar(ws);
  for i := 1 to ol do begin
    case pwc^ of
      '&': inc(nl, length(amp) - 1);
      '<': inc(nl, length(lt) - 1);
      '>': inc(nl, length(gt) - 1);
      '''': inc(nl, length(apos) - 1);
      '"': inc(nl, length(quot) - 1);
    end;
    inc(pwc);
  end;
  if nl = ol then begin
    result := ws;
    exit;
  end;
  setLength(result, nl);
  pwc := PWideChar(ws);
  pwc1 := PWideChar(result);
  for i := 1 to ol do begin
    case pwc^ of
      '&': begin
          move(amp[1], pwc1^, length(amp) * sizeof(WideChar));
          inc(pwc1, length(amp) - 1);
        end;
      '<': begin
          move(lt[1], pwc1^, length(lt) * sizeof(WideChar));
          inc(pwc1, length(lt) - 1);
        end;
      '>': begin
          move(gt[1], pwc1^, length(gt) * sizeof(WideChar));
          inc(pwc1, length(gt) - 1);
        end;
      '''': begin
          move(apos[1], pwc1^, length(apos) * sizeof(WideChar));
          inc(pwc1, length(apos) - 1);
        end;
      '"': begin
          move(quot[1], pwc1^, length(quot) * sizeof(WideChar));
          inc(pwc1, length(quot) - 1);
        end;
    else
      pwc1^ := pwc^;
    end;
    inc(pwc);
    inc(pwc1);
  end;
end;

{ TFastOSMWriter }

procedure TFastOSMWriter.set_eos(const aEOS: WordBool);
begin
  inherited;

end;

procedure TFastOSMWriter.setInputMap(const inputMap: OleVariant);
begin
  if(varIsType(inputMap,varDispatch)) then begin
    varCopyNoInd(inMap,inputMap);
  end
  else
    inMap:=0;
end;

procedure TFastOSMWriter.write(const dummy: OleVariant);
begin
  if not VarIsType(oStream, varDispatch) then
    raise EInOutError.create(toString() + '.write: out stream not assigned');
  if not VarIsType(inMap, varDispatch) or not VarIsType(inMap.storage, varDispatch) then
    raise EInOutError.create(toString() + '.write: input map not assigned');
  inStg:=inMap.storage;
  try
    writeHeader();
    writeNodes();
    writeWays();
    writeRelations();
    writeFooter();
  finally
    inStg:=0;
  end;
end;

procedure TFastOSMWriter.writeHeader;
begin
  writeLineUTF8('<?xml version="1.0" encoding="UTF-8" ?>');
  writeUTF8('<osm version="0.6" generator="Osman ');
  writeUTF16( getClassName());
  writeLineUTF8('">');
end;

procedure TFastOSMWriter.writeNodes;
var
  qAtt,qTgs,sAtt,sTgs,aAtt,aTgs:Variant;
  pV,pVt:PVariant;
  n,l:integer;
  i64:int64;
  su8:UTF8String;
  hasTags:boolean;
begin
  qAtt:=inStg.sqlPrepare('SELECT nodes.id,version,timestamp,userid,users.name,changeset,lat,lon FROM nodes,users WHERE nodes.userid=users.id');
  qTgs:=inStg.sqlPrepare('SELECT tagname,tagvalue FROM objtags,tags WHERE :id*4+0=objid AND tagid=tags.id');
  sAtt:=inStg.sqlExec(qAtt,0,0);
  while not sAtt.eos do begin
    aAtt:=sAtt.read(100);
    if (not varIsArray(aAtt))or(VarArrayDimCount(aAtt)<>1) then
      raise EConvertError.Create(toString()+'.writeNodes: unexpected attribute array');
    n:=varArrayLength(aAtt) div 8;
    pV:=VarArrayLock(aAtt);
    pVt:=nil;
    try
      while(n>0)do begin
        dec(n);
        writeUTF8('  <node id="');
        i64:=pV^;
        writeUTF8(inttostr(i64)+'" version="');
        inc(pV);
        writeUTF8(inttostr(pV^)+'" timestamp="');
        inc(pV);
        writeUTF16(pWideChar(wideString(pV^)));
        inc(pV);
        writeUTF8('" uid="'+inttostr(pV^)+'" user="');
        inc(pV);
        writeUTF16(quote(pV^));
        inc(pV);
        writeUTF8('" changeset="'+inttostr(pV^)+'" lat="');
        inc(pV);su8:=inttostr(pV^);l:=length(su8);
        writeUTF8(copy(su8,1,l-7)+'.'+copy(su8,l-7+1,7)+'" lon="');
        inc(pV);su8:=inttostr(pV^);l:=length(su8);
        writeUTF8(copy(su8,1,l-7)+'.'+copy(su8,l-7+1,7)+'"');
        inc(pV);
        hasTags:=false;
        sTgs:=inStg.sqlExec(qTgs,':id',i64);
        while not sTgs.eos do begin
          aTgs:=sTgs.read(30);
          if (not varIsArray(aTgs))or(VarArrayDimCount(aTgs)<>1) then
            raise EConvertError.Create(toString()+'.writeNodes: unexpected tags array');
          l:=varArrayLength(aTgs) div 2;
          if(not hasTags) then begin
            hasTags:=true;
            writeLineUTF8('>');
          end;
          pVt:=varArrayLock(aTgs);
          while(l>0)do begin
            dec(l);
            writeUTF8('    <tag k="');
            writeUTF16(quote(pVt^));
            inc(pVt);
            writeUTF8('" v="');
            writeUTF16(quote(pVt^));
            inc(pVt);
            writeLineUTF8('"/>');
          end;
          varArrayUnlock(aTgs);
          pVt:=nil;
        end;
        if(hasTags)then
          writeLineUTF8('  </node>')
        else
          writeLineUTF8('/>');
      end;
    finally
      if assigned(pVt) then varArrayUnlock(aTgs);
      varArrayUnlock(aAtt);
    end;
  end;
end;

procedure TFastOSMWriter.writeRelations;
var
  qAtt,qTgs,qMembers,sAtt,sTgs,aAtt,aTgs:Variant;
  pV,pVt:PVariant;
  n,l:integer;
  i64:int64;
  hasTags:boolean;
begin
  qAtt:=inStg.sqlPrepare('SELECT relations.id,version,timestamp,userid,users.name,changeset FROM relations,users WHERE relations.userid=users.id');
  qTgs:=inStg.sqlPrepare('SELECT tagname,tagvalue FROM objtags,tags WHERE :id*4+2=objid AND tagid=tags.id');
  qMembers:=inStg.sqlPrepare('SELECT memberidxtype & 3,memberid, memberrole FROM relationmembers WHERE relationid=:id ORDER BY memberidxtype');
  sAtt:=inStg.sqlExec(qAtt,0,0);
  while not sAtt.eos do begin
    aAtt:=sAtt.read(100);
    if (not varIsArray(aAtt))or(VarArrayDimCount(aAtt)<>1) then
      raise EConvertError.Create(toString()+'.writeRelations: unexpected attribute array');
    n:=varArrayLength(aAtt) div 6;
    pV:=VarArrayLock(aAtt);
    pVt:=nil;
    try
      while(n>0)do begin
        dec(n);
        writeUTF8('  <relation id="');
        i64:=pV^;
        writeUTF8(inttostr(i64)+'" version="');
        inc(pV);
        writeUTF8(inttostr(pV^)+'" timestamp="');
        inc(pV);
        writeUTF16(pWideChar(wideString(pV^)));
        inc(pV);
        writeUTF8('" uid="'+inttostr(pV^)+'" user="');
        inc(pV);
        writeUTF16(quote(pV^));
        inc(pV);
        writeUTF8('" changeset="'+inttostr(pV^)+'"');
        inc(pV);
        hasTags:=false;
        sTgs:=inStg.sqlExec(qTgs,':id',i64);
        while not sTgs.eos do begin
          aTgs:=sTgs.read(30);
          if (not varIsArray(aTgs))or(VarArrayDimCount(aTgs)<>1) then
            raise EConvertError.Create(toString()+'.writeRelations: unexpected tags array');
          l:=varArrayLength(aTgs) div 2;
          if(not hasTags) then begin
            hasTags:=true;
            writeLineUTF8('>');
          end;
          pVt:=varArrayLock(aTgs);
          while(l>0)do begin
            dec(l);
            writeUTF8('    <tag k="');
            writeUTF16(quote(pVt^));
            inc(pVt);
            writeUTF8('" v="');
            writeUTF16(quote(pVt^));
            inc(pVt);
            writeLineUTF8('"/>');
          end;
          varArrayUnlock(aTgs);
          pVt:=nil;
        end;
        sTgs:=inStg.sqlExec(qMembers,':id',i64);
        while not sTgs.eos do begin
          aTgs:=sTgs.read(30);
          if (not varIsArray(aTgs))or(VarArrayDimCount(aTgs)<>1) then
            raise EConvertError.Create(toString()+'.writeRelations: unexpected members array');
          l:=varArrayLength(aTgs) div 3;
          if(not hasTags) then begin
            hasTags:=true;
            writeLineUTF8('>');
          end;
          pVt:=varArrayLock(aTgs);
          while(l>0)do begin
            dec(l);
            i64:=pVt^;
            case i64 of
              0:writeUTF8('    <member type="node" ref="');
              1:writeUTF8('    <member type="way" ref="');
              2:writeUTF8('    <member type="relation" ref="');
            end;
            inc(pVt);
            i64:=pVt^;
            writeUTF8(inttostr(i64)+'" role="');
            inc(pVt);
            writeUTF16(quote(pVt^));
            writeLineUTF8('"/>');
            inc(pVt);
          end;
          varArrayUnlock(aTgs);
          pVt:=nil;
        end;
        if(hasTags)then
          writeLineUTF8('  </relation>')
        else
          writeLineUTF8('/>');
      end;
    finally
      if assigned(pVt) then varArrayUnlock(aTgs);
      varArrayUnlock(aAtt);
    end;
  end;
end;

procedure TFastOSMWriter.writeWays;
var
  qAtt,qTgs,qNodes,sAtt,sTgs,aAtt,aTgs:Variant;
  pV,pVt:PVariant;
  n,l:integer;
  i64:int64;
  hasTags:boolean;
begin
  qAtt:=inStg.sqlPrepare('SELECT ways.id,version,timestamp,userid,users.name,changeset FROM ways,users WHERE ways.userid=users.id');
  qTgs:=inStg.sqlPrepare('SELECT tagname,tagvalue FROM objtags,tags WHERE :id*4+1=objid AND tagid=tags.id');
  qNodes:=inStg.sqlPrepare('SELECT nodeid FROM waynodes WHERE wayid=:id ORDER BY nodeidx');
  sAtt:=inStg.sqlExec(qAtt,0,0);
  while not sAtt.eos do begin
    aAtt:=sAtt.read(100);
    if (not varIsArray(aAtt))or(VarArrayDimCount(aAtt)<>1) then
      raise EConvertError.Create(toString()+'.writeWays: unexpected attribute array');
    n:=varArrayLength(aAtt) div 6;
    pV:=VarArrayLock(aAtt);
    pVt:=nil;
    try
      while(n>0)do begin
        dec(n);
        writeUTF8('  <way id="');
        i64:=pV^;
        writeUTF8(inttostr(i64)+'" version="');
        inc(pV);
        writeUTF8(inttostr(pV^)+'" timestamp="');
        inc(pV);
        writeUTF16(pWideChar(wideString(pV^)));
        inc(pV);
        writeUTF8('" uid="'+inttostr(pV^)+'" user="');
        inc(pV);
        writeUTF16(quote(pV^));
        inc(pV);
        writeUTF8('" changeset="'+inttostr(pV^)+'"');
        inc(pV);
        hasTags:=false;
        sTgs:=inStg.sqlExec(qTgs,':id',i64);
        while not sTgs.eos do begin
          aTgs:=sTgs.read(30);
          if (not varIsArray(aTgs))or(VarArrayDimCount(aTgs)<>1) then
            raise EConvertError.Create(toString()+'.writeWays: unexpected tags array');
          l:=varArrayLength(aTgs) div 2;
          if(not hasTags) then begin
            hasTags:=true;
            writeLineUTF8('>');
          end;
          pVt:=varArrayLock(aTgs);
          while(l>0)do begin
            dec(l);
            writeUTF8('    <tag k="');
            writeUTF16(quote(pVt^));
            inc(pVt);
            writeUTF8('" v="');
            writeUTF16(quote(pVt^));
            inc(pVt);
            writeLineUTF8('"/>');
          end;
          varArrayUnlock(aTgs);
          pVt:=nil;
        end;
        sTgs:=inStg.sqlExec(qNodes,':id',i64);
        while not sTgs.eos do begin
          aTgs:=sTgs.read(30);
          if (not varIsArray(aTgs))or(VarArrayDimCount(aTgs)<>1) then
            raise EConvertError.Create(toString()+'.writeWays: unexpected nodes array');
          l:=varArrayLength(aTgs);
          if(not hasTags) then begin
            hasTags:=true;
            writeLineUTF8('>');
          end;
          pVt:=varArrayLock(aTgs);
          while(l>0)do begin
            dec(l);
            i64:=pVt^;
            writeLineUTF8('    <nd ref="'+inttostr(i64)+'"/>');
            inc(pVt);
          end;
          varArrayUnlock(aTgs);
          pVt:=nil;
        end;
        if(hasTags)then
          writeLineUTF8('  </way>')
        else
          writeLineUTF8('/>');
      end;
    finally
      if assigned(pVt) then varArrayUnlock(aTgs);
      varArrayUnlock(aAtt);
    end;
  end;
end;

procedure TFastOSMWriter.writeFooter;
begin
  writeLineUTF8('</osm>');
end;

initialization
  uModule.OSManRegister(TOSMReader, osmReaderClassGUID);
  uModule.OSManRegister(TOSMWriter, osmWriterClassGUID);
  uModule.OSManRegister(TFastOSMWriter,osmFastWriterClassGUID);
end.

