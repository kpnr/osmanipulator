unit uFileIO;

interface

uses uInterfaces,Variants, SysUtils, Windows, ComObj, OSMan_TLB, uModule;

implementation
const
  fileReaderClassGUID: TGUID = '{6917C025-0890-4754-BB71-25C16552E15D}';
  fileWriterClassGUID: TGUID = '{1B3AE666-0897-44A4-BBE0-C0C87BC8A32B}';

type
  TFileReader = class(TOSManObject,IResourceInputStream)
  protected
    hFile: THandle;
    fEOS: WordBool;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function get_eos:WordBool;
  published
    //URL: String representation of resource address (web-address, local FS file name, etc).
    procedure open(const URL: WideString);

    function read(const maxBufSize: Integer): OleVariant;

    property eos: WordBool read get_eos;
  end;

  TFileWriter = class (TOSManObject,IResourceOutputStream)
  protected
    fEOS:boolean;
    hFile:THandle;
    constructor Create(); override;
    destructor Destroy(); override;
  published
    //URL: String representation of resource address (web-address, local FS file name, etc).
    procedure open(const URL: WideString);

    //Write data from zero-based one dimensional SafeArray of bytes (VT_ARRAY | VT_UI1)
    procedure write(const aBuf:OleVariant);
    procedure set_eos(const aEOS:WordBool);
    function get_eos:WordBool;
    //write "true" if all data stored and stream should to release system resources
    //once set to "true" no write oprerations allowed on stream
    property eos: WordBool read get_eos write set_eos;
  end;

  { TFileReader }

procedure TFileReader.open(const URL: WideString);
var
  hr:DWord;
begin
  if (URL='') then begin
    if hFile<> INVALID_HANDLE_VALUE then begin
      CloseHandle(hFile);
      hFile:=INVALID_HANDLE_VALUE;
      fEOS:=true;
    end;
    exit;
  end;
  if (hFile <> INVALID_HANDLE_VALUE) then
    raise EInOutError.Create(toString() + ': Open must be called only once');
  hFile := CreateFileW(pWideChar(URL), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL or
    FILE_FLAG_SEQUENTIAL_SCAN, 0);
  if hFile = INVALID_HANDLE_VALUE then begin
    hr:=GetLastError();
    raise EInOutError.Create(toString() + ': ' + SysErrorMessage(hr));
  end;
  fEOS := false;
end;

function TFileReader.read(const maxBufSize: Integer): OleVariant;
var
  p: pointer;
  c: DWord;
begin
  if hFile=INVALID_HANDLE_VALUE then begin
    raise EInOutError.Create(toString()+': file must be opened before read');
  end;
  result := VarArrayCreate([0, maxBufSize - 1], varByte);
  p := VarArrayLock(result);
  c := 0;
  try
    if not ReadFile(hFile, p^, maxBufSize, c, nil) then
      raise EInOutError.Create(toString() + ' :' + SysErrorMessage(GetLastError()));
  finally
    VarArrayUnlock(result);
  end;
  if Integer(c) < maxBufSize then
    VarArrayRedim(result, Integer(c) - 1);
  if integer(c) < maxBufSize then
    fEOS := true;
end;

constructor TFileReader.Create;
begin
  inherited;
  hFile := INVALID_HANDLE_VALUE;
  fEOS := true;
end;

destructor TFileReader.Destroy;
begin
  if hFile <> INVALID_HANDLE_VALUE then
    CloseHandle(hFile);
  hFile := INVALID_HANDLE_VALUE;
  fEOS:=true;
  inherited;
end;

function TFileReader.get_eos: WordBool;
begin
  result:=fEOS;
end;

{ TFileWriter }

constructor TFileWriter.Create;
begin
  inherited;
  hFile:=INVALID_HANDLE_VALUE;
  fEOS:=true;
end;

destructor TFileWriter.Destroy;
begin
  if not eos then
    eos:=true;
  inherited;
end;

function TFileWriter.get_eos: WordBool;
begin
  result:=fEOS;
end;

procedure TFileWriter.open(const URL: WideString);
var
  hr:DWord;
begin
  if (URL='') then begin
    eos:=true;
    exit;
  end;
  if hFile <> INVALID_HANDLE_VALUE then
    raise EInOutError.Create(toString() + ': Open must be called only once');
  hFile := CreateFileW(pWideChar(URL), GENERIC_WRITE, FILE_SHARE_READ, nil, CREATE_ALWAYS,
    FILE_ATTRIBUTE_NORMAL or
    FILE_FLAG_SEQUENTIAL_SCAN, 0);
  if hFile = INVALID_HANDLE_VALUE then begin
    hr:=GetLastError();
    raise EInOutError.Create(toString() + ': ' + SysErrorMessage(hr));
  end;
  fEOS := false;
end;

procedure TFileWriter.set_eos(const aEOS: WordBool);
begin
  if aEOS and (hFile<>INVALID_HANDLE_VALUE) then begin
    CloseHandle(hFile);
    hFile:=INVALID_HANDLE_VALUE;
    fEOS:=true;
  end;
  fEOS:=fEOS or aEOS;
end;

procedure TFileWriter.write(const aBuf: OleVariant);
var
  pb:pByte;
  pv:PVariant;
  cnt:integer;
  hr,wrtn:DWord;
begin
  pv:=@aBuf;
  while(VarIsByRef(pv^){(PVarData(pv).VType and varByRef)<>0}) do
    pv:=pVarData(pv)^.VPointer;
  if ((VarType(pv^) and VarTypeMask)<>varByte) or (VarArrayDimCount(pv^)<>1) then
    raise EInOutError.Create(toString()+'.write: array of bytes expected');
  if hFile=INVALID_HANDLE_VALUE then
    raise EInOutError.Create(toString()+'.write: file must be opened before write');
  cnt:=VarArrayHighBound(pv^,1)-VarArrayLowBound(pv^,1)+1;
  if cnt<=0 then
    exit;
  pb:=VarArrayLock(pv^);
  try
    if not WriteFile(hFile,pb^,cnt,wrtn,nil) or (wrtn<>DWord(cnt)) then begin
      hr:=GetLastError();
      raise EInOutError.Create(toString()+'.write: '+SysErrorMessage(hr));
    end;
  finally
    VarArrayUnlock(pv^);
  end;
end;

initialization
  uModule.OSManRegister(TFileReader, fileReaderClassGUID);
  uModule.OSManRegister(TFileWriter, fileWriterClassGUID);
end.

