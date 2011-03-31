unit uModule;

interface

uses uInterfaces, ComObj, Windows, TntSysUtils, ObjComAuto, SysUtils, Variants;

const
  IID_IOSManModule: TGUID = '{E5B171BA-F29C-45E2-BDDA-51F2C0651A5D}';

type
  IOSManModule = interface(IUnknown)
    ['{E5B171BA-F29C-45E2-BDDA-51F2C0651A5D}']
    function getClasses(out ClassNames: OleVariant; out ClassGUIDS: OleVariant): HResult; stdcall;
    function createObjectByCLSID(ClassGUID: TGUID; out rslt: IDispatch): HResult; stdcall;
    function Get_appRef: IDispatch; stdcall;
    procedure Set_appRef(Value: IDispatch); stdcall;
    function Get_logger: OleVariant; safecall;
    procedure Set_logger(Value: OleVariant); safecall;
    property appRef: IDispatch read Get_appRef write Set_appRef;
    property logger: OleVariant read Get_logger write Set_logger;
  end;

  {$TYPEINFO ON}
  {$METHODINFO ON}
  {$WARNINGS OFF}
  TOSManObject = class(TObjectDispatch, IOSManAll)
  protected
    function getModuleName: WideString;
  public
    constructor Create; reintroduce; virtual;
    destructor Destroy; override;
  published
    function toString: WideString; virtual;
    //class
    function getClassName: WideString; virtual;
  end;
  {$WARNINGS ON}
  {$METHODINFO OFF}
  {$TYPEINFO OFF}

  TOSManClass = class of TOSManObject;
  TOSManModuleFunc = function(const osmanApp:IDispatch;const IID: TGUID; out Module: IUnknown): HResult; stdcall;

function OSManModule(const osmanApp:IDispatch;const IID: TGUID; out Module: IUnknown): HResult; stdcall;

procedure OSManRegister(myClass: TOSManClass; const myClassGUID: TGUID);

procedure OSManLog(const msg: WideString);

procedure AppAddRef();
procedure AppRelease();

exports OSManModule;

implementation

type
  TOSManModule = class(TInterfacedObject, IOSManModule)
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    function getClasses(out ClassNames: OleVariant; out ClassGUIDS: OleVariant): HResult; stdcall;
    function createObjectByCLSID(ClassGUID: TGUID; out rslt: IDispatch): HResult; stdcall;
    function Get_appRef: IDispatch; stdcall;
    procedure Set_appRef(Value: IDispatch); stdcall;
    function Get_logger: OleVariant; safecall;
    procedure Set_logger(Value: OleVariant); safecall;
    property appRef: IDispatch read Get_appRef write Set_appRef;
    property logger: OleVariant read Get_logger write Set_logger;
  public
    destructor Destroy; override;
  end;

  TOSManRegInfo = record
    name: WideString;
    id: TGUID;
    classRef: TOSManClass;
  end;

var
  regInfo: array of TOSManRegInfo;
  fLogger: OleVariant;
  gAppRef:IDispatch;
  AppRefCount:integer;


procedure AppAddRef();
begin
  if (AppRefCount=0) and assigned(gAppRef) then
    gAppRef._AddRef();
  inc(AppRefCount);
end;

procedure AppRelease();
begin
  dec(AppRefCount);
  if (AppRefCount=0) and assigned(gAppRef) then
    gAppRef._Release();
end;

procedure OSManLog(const msg: WideString);
begin
  if not varIsType(fLogger, varDispatch) then
    exit;
  fLogger.log(msg);
end;

function OSManModule(const osmanApp:IDispatch;const IID: TGUID; out Module: IUnknown): HResult;
begin
  result := E_NOINTERFACE;
  if IsEqualGUID(IID, IID_IOSManModule) then begin
    try
      Module := TOSManModule.Create();
      (Module as IOSManModule).appRef:=osmanApp;
      result := S_OK;
    except
      result := E_UNEXPECTED;
    end;
  end;
end;

procedure OSManRegister(myClass: TOSManClass; const myClassGUID: TGUID);
var
  i: Integer;
begin
  i := length(regInfo);
  setLength(regInfo, i + 1);
  regInfo[i].name := copy(myClass.ClassName(), 2, maxint);
  regInfo[i].id := myClassGUID;
  regInfo[i].classRef := myClass;
end;

{ TOSManModule }

function TOSManModule.createObjectByCLSID(ClassGUID: TGUID;
  out rslt: IDispatch): HResult;
var
  i: Integer;
begin
  rslt := nil;
  result := E_NOTIMPL;
  try
    for i := 0 to high(regInfo) do begin
      if IsEqualGUID(ClassGUID, regInfo[i].id) then begin
        rslt := regInfo[i].classRef.Create();
        result := S_OK;
        break;
      end;
    end;
  except
    rslt := nil;
    result := E_UNEXPECTED;
  end;
end;

destructor TOSManModule.Destroy;
begin
  OutputDebugStringW('TOSManModule.destroy');//$$$debug
  fLogger := unassigned;
  inherited;
end;

function TOSManModule.getClasses(out ClassNames,
  ClassGUIDS: OleVariant): HResult;
var
  i: Integer;
begin
  ClassNames := VarArrayCreate([low(regInfo), high(regInfo)], varVariant);
  ClassGUIDS := VarArrayCreate([low(regInfo), high(regInfo)], varVariant);
  for i := 0 to high(regInfo) do begin
    VarArrayPut(Variant(ClassNames), regInfo[i].name, [i]);
    VarArrayPut(Variant(ClassGUIDS), WideString(GUIDToString(regInfo[i].id)), [i]);
  end;
  result := S_OK;
end;

function TOSManModule.Get_appRef: IDispatch;
begin
  result:=gAppRef;
end;

function TOSManModule.Get_logger: OleVariant;
begin
  result := fLogger;
end;

procedure TOSManModule.Set_appRef(Value: IDispatch);
begin
  gAppRef:=Value;
end;

procedure TOSManModule.Set_logger(Value: OleVariant);
begin
  fLogger := Value;
end;

function TOSManModule._AddRef: Integer;
begin
  result := inherited _AddRef;
end;

function TOSManModule._Release: Integer;
begin
  result := inherited _Release;
end;

{ TOSManObject }

constructor TOSManObject.Create;
begin
  AppAddRef();
  inherited Create(self, false);
end;

destructor TOSManObject.Destroy;
begin
  inherited;
  AppRelease();
end;

function TOSManObject.getClassName: WideString;
begin
  result := copy(ClassName, 2, maxint);
end;

function TOSManObject.getModuleName: WideString;
var
  l: DWord;
  pwc: PWideChar;
begin
  getmem(pwc, sizeof(WideChar) * MAX_PATH);
  try
    l := getModuleFileNameW(HInstance, pwc, MAX_PATH);
    if l = 0 then
      raise EOleError.Create('TOSManObject.getModuleName: ' + sysErrorMessage(getLastError()));
    result := WideChangeFileExt(wideExtractFileName(pwc), '');
  finally
    freemem(pwc);
  end;
end;

function TOSManObject.toString: WideString;
begin
  result := Format('%s.%s.%p', [getModuleName(), getClassName(), pointer(self)]);
end;

initialization
  DecimalSeparator := '.';
  AppRefCount:=0;
end.

