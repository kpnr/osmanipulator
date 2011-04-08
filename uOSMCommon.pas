unit uOSMCommon;
interface

uses ActiveX, Windows, SysConst, uModule, uInterfaces, SysUtils, Classes, Variants;

const
  cDegToInt = 10000000;
  cIntToDeg = 1 / cDegToInt;
  cIntToRad = cIntToDeg * PI / 180;
  cDegToM = 111120;
  cIntToM = cIntToDeg * cDegToM;
  cRadToM = cDegToM * 180 / PI;
  cRadToInt = 1 / cIntToRad;

  cDegToInt_int: integer = cDegToInt;
  cIntToDeg_dbl: double = cIntToDeg;
  cIntToRad_dbl: double = cIntToRad;

type
  TRefType = (rtNode, rtWay, rtRelation);

  TRefList = class(TOSManObject, IRefList)
  protected
    fRefTypes: array of TRefType;
    fRefIds: array of int64;
    fRefRoles: array of WideString;
    fCount: integer;
    procedure grow();
  public
    function get_count: integer;
  published
    procedure getByIdx(idx: integer; out refType: WideString; out refId: int64; out refRole:
      WideString);
    procedure setByIdx(idx: integer; const refType: WideString; refId: int64; const refRole:
      WideString);
    procedure deleteByIdx(idx: integer);
    function getAll(): OleVariant;
    procedure setAll(refTypesIdsRoles: OleVariant);
    //idx - if idx => count then item appended to end of list.
    procedure insertBefore(idx: integer; const refType: WideString; refId: int64; const refRole:
      WideString);

    //returns number of list items
    property count: integer read get_count;
  end;

  TInputStreamAdaptor = class(TStream)
  protected
    oleStream: OleVariant;
    readCount: int64;
  public
    constructor Create(_IInputStream: IDispatch);
    function Write(const Buffer; count: Longint): Longint; override;
    function Read(var Buffer; count: Longint): Longint; override;
    function Seek(const Offset: int64; Origin: TSeekOrigin): int64; override;
    function EOS: boolean;
  end;

  TOSMDecompressStream = class(TOSManObject, ITransformInputStream)
  protected
    zStream: TStream;
    inStreamAdaptor: TInputStreamAdaptor;
    fEOS: boolean;
    function get_eos: WordBool;
    function createzStream: TStream; virtual; abstract;
  public
    destructor destroy; override;
  published
    function Read(const maxBufSize: integer): OleVariant;
    property EOS: WordBool read get_eos;

    procedure setInputStream(const inStream: OleVariant);
  end;

  TVarRecArray = array of TVarRec;

  TPutFilterAdaptor = class
  protected
    fFilter: OleVariant;
    canCallOnPutObject, canCallOnPutNode, canCallOnPutWay, canCallOnPutRelation: boolean;
  public
    constructor Create(const aFilter: Variant); reintroduce;
    function getFilter(): OleVariant;
    function onPutNode(const node: OleVariant): boolean;
    function onPutWay(const way: OleVariant): boolean;
    function onPutRelation(const relation: OleVariant): boolean;
  end;

function VarArrayLockVarRec(const VarArray: OleVariant): TVarRecArray;
procedure VarArrayUnlockVarRec(const VarArray: OleVariant; const VarRecArray: TVarRecArray);

//supports only 10-base
function WideStrToInt64(const ws: WideString): int64; register;
//supports only 10-base
function WideStrToInt(const ws: WideString): integer; register;

//TRefType conversion functions
function refTypeToStr(const rt: TRefType): WideString;
function strToRefType(const rt: WideString): TRefType;

//returns session unique ID
function getUID: int64;

//returns true if method/property exists in IDispatch
function isDispNameExists(const disp: IDispatch; const aName: WideString): boolean;

//converts jsObject into OleVariant. If jsObj already OleVariant then returns unchanged jsObj
function varFromJsObject(const jsObj: OleVariant): OleVariant;
//returns length of fisrt dimension of variant array
function varArrayLength(const vArr: Variant): integer;

//convert floating Degrees into WideString
function degToStr(const deg: double): WideString;

//convert float-point Degrees into scaled integers and vice versa
function degToInt(const deg: double): integer;
function IntToDeg(const i: integer): double;

//emit message to debugger
procedure debugPrint(const msg:WideString);

implementation

procedure debugPrint(const msg:WideString);
begin
  OutputDebugStringW(PWideChar(msg));
end;

function degToInt(const deg: double): integer;
asm
  fld deg
  push eax
  fimul cDegToInt_int
  fistp dword[esp]
  pop eax
end;

function IntToDeg(const i: integer): double;
asm
  push i
  fild dword[esp]
  fmul cIntToDeg_dbl
  pop eax
end;

function varArrayLength(const vArr: Variant): integer;
begin
  result := varArrayHighBound(vArr, 1) - varArrayLowBound(vArr, 1) + 1;
end;

function degToStr(const deg: double): WideString;
begin
  result := FormatFloat('###0.#######', deg);
end;

function varFromJsObject(const jsObj: OleVariant): OleVariant;
var
  l: integer;
  arrCopy: OleVariant;
  pv: POleVariant;
begin
  if VarIsType(jsObj, varDispatch) then begin
    if isDispNameExists(jsObj, 'pop') then begin
      //array object
      arrCopy := jsObj.slice(0);
      l := arrCopy.length;
      result := VarArrayCreate([0, l - 1], varVariant);
      pv := varArrayLock(result);
      try
        inc(pv, l - 1);
        while (l > 0) do begin
          pv^ := varFromJsObject(arrCopy.pop());
          dec(pv);
          dec(l);
        end;
      finally
        varArrayUnlock(result);
      end;
    end
    else if isDispNameExists(jsObj, 'toUpperCase') then begin
      //String object
      result := jsObj.valueOf();
    end
    else if isDispNameExists(jsObj, 'NaN') then begin
      //Number object
      result := jsObj.valueOf();
    end
    else begin
      //unknow object. just copy
      result := jsObj;
    end;
  end
  else
    result := jsObj;
end;

function isDispNameExists(const disp: IDispatch; const aName: WideString): boolean;
begin
  result := succeeded(disp.GetIDsOfNames(GUID_NULL, @aName, 1, 0
    {SORT_DEFAULT,LANG_NEUTRAL,SUBLANG_NEUTRAL}, @result));
end;

function getUID: int64;
begin
  AllocateLocallyUniqueId(result);
end;

function refTypeToStr(const rt: TRefType): WideString;
begin
  case rt of
    rtNode: result := 'node';
    rtWay: result := 'way';
    rtRelation: result := 'relation';
  else
    raise ERangeError.Create('refTypeToStr: unknown ref type');
  end;
end;

function strToRefType(const rt: WideString): TRefType;
begin
  if rt = 'node' then
    result := rtNode
  else if rt = 'way' then
    result := rtWay
  else if rt = 'relation' then
    result := rtRelation
  else
    raise ERangeError.Create('strToRefType: unknown ref type "' + rt + '"');
end;

//used in WideStrToInt functions

procedure RaiseEConvert(const s: WideString); register;
begin
  raise EConvertError.CreateFmt(SInvalidInteger, [s])
end;

function WideStrToInt64(const ws: WideString): int64;
//if ws not valid integer then result undefined
asm
  test eax,eax
  mov edx,eax
  jz @@exit//nil ptr
  push esi
  push edi
  mov esi,eax
  xor ecx,ecx
  push eax//store string address
  xor edx,edx
  xor eax,eax
  or cx,[esi]
  jnz @@checksign
  push esi//empty string
  jmp @@error
@@checksign:
  cmp ecx,'-'
  pushfd
  jz @@nextchar
  cmp ecx,'+'
  jz @@nextchar
@@transform:
  sub ecx,'0'
  jc @@error
  cmp ecx,10
  jnc @@error
  //mul by 10
  shld edx,eax,1
  js @@error
  shl eax,1//edx:eax=2x
  xor edi,edi
  add ecx,eax
  adc edi,edx//edi:ecx=2x+c
  shld edx,eax,2
  jc @@error
  js @@error
  shl eax,2//edx:eax=8x
  add eax,ecx
  adc edx,edi//edx:eax=8x+2x+c=10x+c
  js @@error
@@nextchar:
  xor ecx,ecx
  add esi,2
  or cx,[esi]
  jnz @@transform
  popfd
  jz @@negative
  jmp @@pozitive
@@error:
  pop ecx//remove flags
  pop eax//restore string address
  pop edi
  pop esi
  jmp RaiseEConvert
@@negative:
  not eax
  not edx
  add eax,1
  adc edx,0
@@pozitive:
  pop ecx //remove string address
  pop edi
  pop esi
@@exit:
end;

function WideStrToInt(const ws: WideString): integer;
asm
  push eax
  call WideStrToInt64
  mov ecx,edx
  rol edx,1
  cmp edx,ecx
  jnz @@error
  xor ecx,eax
@@error:
  js RaiseEConvert
@@ok:
  pop ecx
end;

function VarArrayLockVarRec(const VarArray: OleVariant): TVarRecArray;
var
  pVar, pLockedVariantArray: PVarData;
  pVR: PVarRec;
  nItems, i, nDim: integer;
begin
  nDim := VarArrayDimCount(VarArray);
  if nDim > 0 then begin
    nItems := 1;
    for i := 1 to nDim do begin
      nItems := nItems * (varArrayHighBound(VarArray, i) - varArrayLowBound(VarArray, i) + 1);
    end;
  end
  else
    nItems := 0;
  pLockedVariantArray := varArrayLock(VarArray);
  setLength(result, nItems);
  pVR := @result[0];
  while nItems > 0 do begin
    pVar := pLockedVariantArray;
    while (pVar.VType and varByRef) <> 0 do
      pVar := pVar.VPointer;
    case pVar.VType of
      varSmallInt: begin
          pVR.VType := vtInteger;
          pVR.VInteger := pVar.VSmallInt;
        end;
      varInteger, varError, varLongWord: begin
          pVR.VType := vtInteger;
          pVR.VInteger := pVar.VInteger;
        end;
      varSingle: begin
          pVR.VType := vtExtended;
          getMem(pVR.VExtended, sizeof(pVR.VExtended^));
          pVR.VExtended^ := pVar.VSingle;
        end;
      varDouble, varDate: begin
          pVR.VType := vtExtended;
          getMem(pVR.VExtended, sizeof(pVR.VExtended^));
          pVR.VExtended^ := pVar.VDouble;
        end;
      varCurrency: begin
          pVR.VType := vtCurrency;
          pVR.VCurrency := @pVar.VCurrency;
        end;
      varOleStr: begin
          pVR.VType := vtWideString;
          pVR.VWideString := pVar.VOleStr;
        end;
      varDispatch: begin
          pVR.VType := vtInterface;
          pVR.VInterface := pVar.VDispatch;
        end;
      varBoolean: begin
          pVR.VType := vtBoolean;
          pVR.VBoolean := pVar.VBoolean;
        end;
      varShortInt: begin
          pVR.VType := vtInteger;
          pVR.VInteger := pVar.VShortInt;
        end;
      varByte: begin
          pVR.VType := vtInteger;
          pVR.VInteger := pVar.VByte;
        end;
      varWord: begin
          pVR.VType := vtInteger;
          pVR.VInteger := pVar.VWord;
        end;
      varInt64: begin
          pVR.VType := vtInt64;
          pVR.VInt64 := @pVar.VInt64;
        end;
      varString: begin
          pVR.VType := vtString;
          pVR.VString := pVar.VString;
        end;
      varUnknown, varAny: begin
          pVR.VType := vtPointer;
          pVR.VPointer := pVar.VAny;
        end;
      varEmpty, varNull: begin
          pVR.VType := vtPointer;
          pVR.VPointer := nil;
        end;
    else begin
        pVR.VType := vtVariant;
        pVR.VVariant := pointer(pVar);
      end;
    end;
    inc(pLockedVariantArray);
    inc(pVR);
    dec(nItems);
  end;
end;

procedure VarArrayUnlockVarRec(const VarArray: OleVariant; const VarRecArray: TVarRecArray);
var
  pVR: PVarRec;
  i: integer;
begin
  i := length(VarRecArray);
  pVR := @VarRecArray[0];
  while i > 0 do begin
    case pVR.VType of
      vtExtended:
        FreeMem(pVR.VExtended);
    end;
    inc(pVR);
    dec(i);
  end;
  varArrayUnlock(VarArray);
end;

{ TInputStreamAdaptor }

constructor TInputStreamAdaptor.Create(_IInputStream: IDispatch);
begin
  oleStream := _IInputStream;
  readCount := 0;
end;

function TInputStreamAdaptor.EOS: boolean;
begin
  result := oleStream.EOS;
end;

function TInputStreamAdaptor.Read(var Buffer; count: integer): Longint;
var
  vBuf: OleVariant;
  p: pointer;
begin
  vBuf := oleStream.Read(count);
  if not VarIsType(vBuf, VarArray or varByte) then
    raise EInOutError.Create('TInputStreamAdaptor.Read: invalid result type');
  result := varArrayHighBound(vBuf, 1) + 1;
  p := varArrayLock(vBuf);
  try
    move(p^, Buffer, result);
  finally
    varArrayUnlock(vBuf);
  end;
  inc(readCount, result);
end;

function TInputStreamAdaptor.Seek(const Offset: int64;
  Origin: TSeekOrigin): int64;
begin
  if (Offset = 0) then begin
    if Origin = soCurrent then
      result := readCount
    else if Origin = soEnd then begin
      result := readCount;
      if not EOS then inc(result);
    end
    else
      result := 0;
  end
  else if (Origin = soBeginning) and (Offset = readCount) then
    result := readCount
  else
    raise EInOutError.Create('TInputStreamAdaptor.Seek: Invalid origin or offset');
end;

function TInputStreamAdaptor.Write(const Buffer; count: integer): Longint;
begin
  raise EInOutError.Create('TInputStreamAdaptor.Write: unsupported call');
end;

{ TOSMDecompressStream }

destructor TOSMDecompressStream.destroy;
begin
  if assigned(zStream) then
    FreeAndNil(zStream);
  if assigned(inStreamAdaptor) then
    FreeAndNil(inStreamAdaptor);
  inherited;
end;

function TOSMDecompressStream.get_eos: WordBool;
begin
  result := inStreamAdaptor.EOS or fEOS;
end;

function TOSMDecompressStream.Read(const maxBufSize: integer): OleVariant;
var
  p: pointer;
  l: integer;
begin
  if not assigned(inStreamAdaptor) then
    raise EInOutError.Create(toString() + ': Input stream not assigned');
  result := VarArrayCreate([0, maxBufSize - 1], varByte);
  p := varArrayLock(result);
  try
    l := zStream.Read(p^, maxBufSize);
  finally
    varArrayUnlock(result);
  end;
  if l < maxBufSize then begin
    VarArrayRedim(result, l - 1);
    fEOS := true;
  end
  else
    fEOS := false;
end;

procedure TOSMDecompressStream.setInputStream(const inStream: OleVariant);
begin
  if assigned(inStreamAdaptor) then
    raise EInOutError.Create(toString() + ': input stream already assigned');
  inStreamAdaptor := TInputStreamAdaptor.Create(inStream);
  zStream := createzStream();
end;

{ TRefList }

procedure TRefList.deleteByIdx(idx: integer);
var
  i: integer;
begin
  if (idx < 0) or (idx >= count) then
    raise ERangeError.Create(toString() + '.setByIdx: index out of range');
  for i := idx to count - 2 do begin
    fRefTypes[i] := fRefTypes[i + 1];
    fRefIds[i] := fRefIds[i + 1];
    fRefRoles[i] := fRefRoles[i + 1];
  end;
end;

function TRefList.get_count: integer;
begin
  result := fCount;
end;

function TRefList.getAll(): OleVariant;
var
  i: integer;
  pv: PVariant;
begin
  result := VarArrayCreate([0, count * 3 - 1], varVariant);
  pv := varArrayLock(result);
  try
    for i := 0 to count - 1 do begin
      pv^ := refTypeToStr(fRefTypes[i]);
      inc(pv);
      pv^ := fRefIds[i];
      inc(pv);
      pv^ := fRefRoles[i];
      inc(pv);
    end;
  finally
    varArrayUnlock(result);
  end;
end;

procedure TRefList.getByIdx(idx: integer; out refType: WideString;
  out refId: int64; out refRole: WideString);
begin
  if (idx < 0) or (idx >= count) then
    raise ERangeError.Create(toString() + '.getByIdx: index out of range');
  refType := refTypeToStr(fRefTypes[idx]);
  refId := fRefIds[idx];
  refRole := fRefRoles[idx];
end;

procedure TRefList.insertBefore(idx: integer; const refType: WideString;
  refId: int64; const refRole: WideString);
var
  i: integer;
  rt: TRefType;
begin
  if idx < 0 then
    raise ERangeError(toString() + '.insertBefore: non negative index expected');
  rt := strToRefType(refType);
  if idx > count then idx := count;
  inc(fCount);
  grow();
  for i := count - 2 downto idx do begin
    fRefTypes[i + 1] := fRefTypes[i];
    fRefIds[i + 1] := fRefIds[i];
    fRefRoles[i + 1] := fRefRoles[i];
  end;
  fRefTypes[idx] := rt;
  fRefIds[idx] := refId;
  fRefRoles[idx] := refRole;
end;

procedure TRefList.setAll(refTypesIdsRoles: OleVariant);
var
  i, cnt: integer;
  pv: POleVariant;
begin
  refTypesIdsRoles := varFromJsObject(refTypesIdsRoles);
  if not ((VarArrayDimCount(refTypesIdsRoles) = 1) and
    ((VarType(refTypesIdsRoles) and varTypeMask) = varVariant)) then
    raise EConvertError.Create(toString() + '.setAll : array argument expected');
  cnt := varArrayLength(refTypesIdsRoles);
  if not ((cnt mod 3) = 0) then
    raise ERangeError.Create(toString() +
      '.setAll: argument length must be zero or multiply of 3');
  fCount := cnt div 3;
  grow();
  pv := varArrayLock(refTypesIdsRoles);
  try
    for i := 0 to fCount - 1 do begin
      fRefTypes[i] := strToRefType(pv^);
      inc(pv);
      fRefIds[i] := pv^;
      inc(pv);
      fRefRoles[i] := pv^;
      inc(pv);
    end;
  finally
    varArrayUnlock(refTypesIdsRoles);
  end;
end;

procedure TRefList.setByIdx(idx: integer; const refType: WideString;
  refId: int64; const refRole: WideString);
begin
  if (idx < 0) or (idx >= count) then
    raise ERangeError.Create(toString() + '.setByIdx: index out of range');
  fRefTypes[idx] := strToRefType(refType);
  fRefIds[idx] := refId;
  fRefRoles[idx] := refRole;
end;

procedure TRefList.grow;
var
  i: integer;
begin
  if count >= length(fRefIds) then begin
    i := (count or 3) + 1;
    setLength(fRefTypes, i);
    setLength(fRefIds, i);
    setLength(fRefRoles, i);
  end;
end;

{ TPutFilterAdaptor }

constructor TPutFilterAdaptor.Create(const aFilter: Variant);
var
  disp: IDispatch;
begin
  inherited Create();
  canCallOnPutObject := false;
  canCallOnPutNode := false;
  canCallOnPutWay := false;
  canCallOnPutRelation := false;
  fFilter := aFilter;
  if VarIsType(fFilter, varDispatch) then begin
    disp := fFilter;
    canCallOnPutObject := isDispNameExists(disp, 'onPutObject');
    canCallOnPutNode := isDispNameExists(disp, 'onPutNode');
    canCallOnPutWay := isDispNameExists(disp, 'onPutWay');
    canCallOnPutRelation := isDispNameExists(disp, 'onPutRelation');
  end;
end;

function TPutFilterAdaptor.getFilter: OleVariant;
begin
  result := fFilter;
end;

function TPutFilterAdaptor.onPutNode(const node: OleVariant): boolean;
begin
  result := true;
  if canCallOnPutObject then
    result := fFilter.onPutObject(node);
  if result and canCallOnPutNode then
    result := fFilter.onPutNode(node);
end;

function TPutFilterAdaptor.onPutRelation(
  const relation: OleVariant): boolean;
begin
  result := true;
  if canCallOnPutObject then
    result := fFilter.onPutObject(relation);
  if result and canCallOnPutRelation then
    result := fFilter.onPutRelation(relation);
end;

function TPutFilterAdaptor.onPutWay(const way: OleVariant): boolean;
begin
  result := true;
  if canCallOnPutObject then
    result := fFilter.onPutObject(way);
  if result and canCallOnPutWay then
    result := fFilter.onPutWay(way);
end;

end.

