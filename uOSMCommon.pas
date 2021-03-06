unit uOSMCommon;
interface

uses ActiveX, Windows, SysConst, uModule, uInterfaces, SysUtils, Classes, Variants, ComObj,
TntSysUtils;

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
  TWideStringArray = array of WideString;
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

//returns path to OSMan. E.g. c:\osman\
function getOSManPath: WideString;

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

//convert TimeStamp from WideString to Int64 and vice versa
function wideStringToTimeStamp(const w: WideString): int64;
function timeStampToWideString(const i64: int64): WideString;

//extended version of pos procedure
function PosEx(const SubStr, Str: WideString; FromPos, ToPos: integer): integer;

//emit message to debugger
procedure debugPrint(const msg: WideString);

implementation

function wideStringToTimeStamp(const w: WideString): int64;
var
  pWCh: pWideChar;
  i: integer;
  flipFlop: boolean;
  b: array[0..9] of byte;
  pB: pByte;
begin
  //12345678901234567890
  //2005-07-05T07:18:37Z
  pWCh := pWideChar(w) - 1;
  if (length(w) <> 20) or
    ((pWCh + 5)^ <> '-') or
    ((pWCh + 8)^ <> '-') or
    ((pWCh + 11)^ <> 'T') or
    ((pWCh + 14)^ <> ':') or
    ((pWCh + 17)^ <> ':') or
    ((pWCh + 20)^ <> 'Z') then begin
    result := 20000101000000;
    exit;
  end;
  pB := @b[6];
  pDWORD(pB)^ := 0; //clear not used digits and sign
  flipFlop := false;
  for i := 1 to 19 do begin
    inc(pWCh);
    if (i in [5, 8, 11, 14, 17]) then continue;
    if ((pWCh^ < '0') or (pWCh^ > '9')) then begin
      result := 20000101000001;
      exit;
    end;
    if (flipFlop) then begin
      inc(pB^, (ord(pWCh^) - ord('0')));
      dec(pB);
    end
    else begin
      pB^ := byte((ord(pWCh^) - ord('0')) shl 4);
    end;
    flipFlop := not flipFlop;
  end;
  asm
    FBLD b
    FISTP result
  end;
end;

function timeStampToWideString(const i64: int64): WideString;
var
  s: array[0..9] of byte;
  pWCh: pWideChar;
  pB: pByte;
  i: integer;
  flipFlop: boolean;
begin
  //12345678901234
  //20050705071837

  //12345678901234567890
  //2005-07-05T07:18:37Z

  // s index is ___________ 0  1  2  3  4  5  6  7  8  9
  //store BCD in LE format [37,18,07,05,07,05,20,00,00,00]
  asm
    FILD i64
    FBSTP s
  end;
  setlength(result, 20);
  flipFlop := false;
  pB := @s[6];
  pWCh := pWideChar(result);
  for i := 1 to 19 do begin
    case i of
      5, 8: begin
          pWCh^ := '-';
        end;
      11: begin
          pWCh^ := 'T';
        end;
      14, 17: begin
          pWCh^ := ':';
        end;
    else begin
        if flipFlop then begin
          pWCh^ := WideChar((pB^ and $F) + ord('0'));
          dec(pB);
        end
        else begin
          pWCh^ := WideChar((pB^ shr 4) + ord('0'));
        end;
        flipFlop := not flipFlop;
      end;
    end;
    inc(pWCh);
  end;
  pWCh^ := 'Z';
end;

function PosEx(const SubStr, Str: WideString; FromPos, ToPos: integer): integer;
var
  StrLength: integer;
begin
  result := 0;
  StrLength := length(Str);
  if (FromPos > StrLength) or (SubStr = '') or (FromPos <= 0) or (ToPos <= 0) then exit;
  if ToPos > StrLength then ToPos := StrLength;
  StrLength := length(SubStr);
  dec(ToPos, StrLength - 1);
  while FromPos <= ToPos do begin
    if (Str[FromPos] = SubStr[1]) and
      CompareMem(@SubStr[1], @Str[FromPos], StrLength * sizeof(Str[1])) then begin
      result := FromPos;
      exit;
    end;
    inc(FromPos);
  end;
end;

procedure debugPrint(const msg: WideString);
begin
  OutputDebugStringW(pWideChar(msg));
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
  pv: POleVariant;

  disp: IDispatchEx;
  DispParams: TDispParams;
  sItem: WideString;
  ExcepInfo: TExcepInfo;
  itemiid: TDispID;
begin
  if VarIsType(jsObj, varDispatch) then begin
    if isDispNameExists(jsObj, 'pop') then begin
      //array object
      disp := IDispatch(jsObj) as IDispatchEx;
      DispParams.cArgs := 0;
      DispParams.rgvarg := nil;
      DispParams.cNamedArgs := 0;
      DispParams.rgdispidNamedArgs := nil;
      //end;}
      l := jsObj.length - 1;
      result := VarArrayCreate([0, l], varVariant);
      pv := varArrayLock(result);
      try
        inc(pv, l);
        while (l >= 0) do begin
          sItem := inttostr(l);
          if succeeded(disp.GetIDsOfNames(GUID_NULL, @sItem, 1, 0, @itemiid)) and
            succeeded(disp.Invoke(itemiid, GUID_NULL, 0, DISPATCH_PROPERTYGET, DispParams, pv,
              @ExcepInfo, nil)) then begin
            pv^ := varFromJsObject(pv^);
            dec(pv);
            dec(l);
          end
          else begin
            raise EConvertError.Create('varFromJsObject : can`t get element ' + inttostr(l));
          end;
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
var
  did: integer;
begin
  result := succeeded(disp.GetIDsOfNames(GUID_NULL, @aName, 1, 0
    {SORT_DEFAULT,LANG_NEUTRAL,SUBLANG_NEUTRAL}, @did));
end;

function getUID: int64;
begin
  AllocateLocallyUniqueId(result);
end;

//returns path to OSMan. E.g. c:\osman

function getOSManPath(): WideString;
var
  pwc: pWideChar;
  l: DWORD;
begin
  getmem(pwc, sizeof(WideChar) * MAX_PATH);
  try
    l := getModuleFileNameW(HInstance, pwc, MAX_PATH);
    if l = 0 then raise EOleError.Create('getOSManPath: ' + sysErrorMessage(getLastError()));
    result := WideExtractFilePath(pwc);
  finally
    freemem(pwc);
  end;
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
  vType: TVarType;
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
  setlength(result, nItems);
  pVR := @result[0];
  while nItems > 0 do begin
    pVar := pLockedVariantArray;
    while (pVar.vType = varByRef or varVariant) do
      pVar := pVar.VPointer;
    vType := pVar.vType and varTypeMask;
    if (pVar.vType and varByRef <> 0) then begin
      pVar := pVar.VPointer;
      dec(pByte(pVar), cardinal(@pVar.VPointer) - cardinal(pVar));
    end;
    case vType of
      varSmallInt: begin
          pVR.vType := vtInteger;
          pVR.VInteger := pVar.VSmallInt;
        end;
      varInteger, varError, varLongWord: begin
          pVR.vType := vtInteger;
          pVR.VInteger := pVar.VInteger;
        end;
      varSingle: begin
          pVR.vType := vtExtended;
          getmem(pVR.VExtended, sizeof(pVR.VExtended^));
          pVR.VExtended^ := pVar.VSingle;
        end;
      varDouble, varDate: begin
          pVR.vType := vtExtended;
          getmem(pVR.VExtended, sizeof(pVR.VExtended^));
          pVR.VExtended^ := pVar.VDouble;
        end;
      varCurrency: begin
          pVR.vType := vtCurrency;
          pVR.VCurrency := @pVar.VCurrency;
        end;
      varOleStr: begin
          pVR.vType := vtWideString;
          pVR.VWideString := pVar.VOleStr;
        end;
      varDispatch: begin
          pVR.vType := vtInterface;
          pVR.VInterface := pVar.VDispatch;
        end;
      varBoolean: begin
          pVR.vType := vtBoolean;
          pVR.VBoolean := pVar.VBoolean;
        end;
      varShortInt: begin
          pVR.vType := vtInteger;
          pVR.VInteger := pVar.VShortInt;
        end;
      varByte: begin
          pVR.vType := vtInteger;
          pVR.VInteger := pVar.VByte;
        end;
      varWord: begin
          pVR.vType := vtInteger;
          pVR.VInteger := pVar.VWord;
        end;
      varInt64: begin
          pVR.vType := vtInt64;
          pVR.VInt64 := @pVar.VInt64;
        end;
      varString: begin
          pVR.vType := vtString;
          pVR.VString := pVar.VString;
        end;
      varUnknown, varAny: begin
          pVR.vType := vtPointer;
          pVR.VPointer := pVar.VAny;
        end;
      varEmpty, varNull: begin
          pVR.vType := vtPointer;
          pVR.VPointer := nil;
        end;
    else begin
        pVR.vType := vtVariant;
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
    case pVR.vType of
      vtExtended:
        freemem(pVR.VExtended);
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
    setlength(fRefTypes, i);
    setlength(fRefIds, i);
    setlength(fRefRoles, i);
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

