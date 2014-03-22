unit uOSManApplication;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  uModule, TntClasses, TntSysUtils, Windows, ComServ, ComObj, ActiveX, OSMan_TLB,
  SysUtils, StdVcl, Variants, uOSMCommon;

implementation
type
  TModuleClassList = class(TTNTStringList)
  protected
    hModule: hModule;
    iModule: IOSManModule;
  public
    constructor create();
    destructor destroy; override;
  end;

  TApplication = class(TAutoObject, IOSManApplication)
  protected
    appPath: WideString;
    moduleList: TTNTStringList;
    fLogger:OleVariant;
    fZeroCnt:integer;
    function createObject(const ObjClassName: WideString): IDispatch;
      safecall;
    function getModuleClasses(const ModuleName: WideString): OleVariant;
      safecall;
    function ObjRelease: Integer; override;
    function getModules: OleVariant; safecall;
    function toString: WideString; safecall;
    function getClassName: WideString; safecall;
    procedure onModuleUnload(const iModSelfPtr: IUnknown); safecall;
    function Get_logger: OleVariant; safecall;
    procedure Set_logger(Value: OleVariant); safecall;
    procedure log(const msg: WideString); safecall;
    property logger: OleVariant read Get_logger write Set_logger;
  public
    destructor destroy(); override;
    procedure initialize(); override;
  end;

function TApplication.createObject(
  const ObjClassName: WideString): IDispatch;

  function getModule(const modName: WideString): TModuleClassList;
  var
    i: integer;
  begin
    result := nil;
    i := moduleList.IndexOf(modName);
    if i < 0 then exit;
    result := moduleList.Objects[i] as TModuleClassList;
  end;

var
  i, j: integer;
  ws, wsClass: WideString;
  cl: TModuleClassList;
  oGUID: TGUID;
begin
  result := nil;
  cl := nil;
  i := posEx('.', ObjClassName, 2,high(integer));
  if i > 0 then begin
    //full name 'module.class'
    ws := copy(ObjClassName, 1, i - 1);
    cl := getModule(ws);
    if not assigned(cl) then
      raise EOleError.create('TApplication.createObjectByName: module "' + ws + '" not found');
    wsClass := copy(ObjClassName, i + 1, length(ObjClassName));
    try
      oGUID := StringToGUID(cl.Values[wsClass]);
    except
      on E: Exception do
        E.Message := 'TApplication.createObjectByName: class "' + wsClass + '" not found';
    end;
  end
  else begin
    //short name 'class'
    wsClass := ObjClassName;
    j := -1;
    for i := 0 to moduleList.Count - 1 do begin
      cl := moduleList.Objects[i] as TModuleClassList;
      j := cl.IndexOfName(wsClass);
      if j < 0 then continue;
      break;
    end;
    if j >= 0 then
      oGUID := StringToGUID(cl.ValueFromIndex[j])
    else
      raise EOleError.create('TApplication.createObjectByName: class "' + wsClass + '" not found');
  end;
  OleCheck(cl.iModule.createObjectByCLSID(oGUID, result));
end;

function TApplication.getModuleClasses(
  const ModuleName: WideString): OleVariant;
var
  i, l: integer;
  clist: TTntStrings;
begin
  i := moduleList.IndexOf(ModuleName);
  l := 0;
  clist := nil;
  if (i >= 0) then begin
    clist := moduleList.Objects[i] as TTntStrings;
    if assigned(clist) then l := clist.Count;
  end;
  result := VarArrayCreate([0, l - 1], varVariant);
  for i := 0 to l - 1 do begin
    VarArrayPut(Variant(result), clist.Names[i], [i]);
  end;
end;

function TApplication.getModules: OleVariant;
var
  l, i: integer;
begin
  l := moduleList.Count;
  result := VarArrayCreate([0, l - 1], varVariant);
  for i := 0 to l - 1 do begin
    VarArrayPut(Variant(result), moduleList[i], [i]);
  end;
end;

function TApplication.toString: WideString;
begin
  result := Format('OSMan.Application.%p', [pointer(self)]);
end;

function TApplication.getClassName: WideString;
begin
  result := 'OSManApplication';
end;

procedure TApplication.initialize();
var
  ws: WideString;
  i: integer;
  sr: TSearchRecW;
  hMod: hModule;
  pModuleFunc: TOSManModuleFunc;
  clist: TModuleClassList;
  iu: IUnknown;
  idi:IDispatch;
  cnames, cids: OleVariant;

begin
  inherited;
  fLogger:=Unassigned;
  try
    idi:=self;
    fZeroCnt:=RefCount;
    appPath := getOSManPath();
    ws := appPath + '*.omm';
    moduleList := TTNTStringList.create();
    moduleList.CaseSensitive := true;
    i := WideFindFirst(ws, faReadOnly or faHidden or faSysFile or faArchive, sr);
    while i = 0 do begin
      hMod := loadLibraryW(PWideChar(appPath + sr.Name));
      if hMod <> 0 then begin
        pModuleFunc := getProcAddress(hMod, 'OSManModule');
        if assigned(pModuleFunc) then begin
          if succeeded(pModuleFunc(idi,IID_IOSManModule, iu)) and
            succeeded((iu as IOSManModule).getClasses(cnames, cids)) then begin
            clist := nil;
            try
              clist := TModuleClassList.create();
              clist.CaseSensitive := true;
              for i := VarArrayLowBound(cnames, 1) to VarArrayHighBound(cnames, 1) do begin
                clist.Values[cnames[i]] := cids[i];
              end;
              clist.Sorted := true;
              clist.hModule := hMod;
              clist.iModule := iu as IOSManModule;
              iu := nil;
              hMod := 0;
            except
              if assigned(clist) then FreeAndNil(clist);
            end;
            cnames := Null;
            cids := Null;
            moduleList.AddObject(WideChangeFileExt(WideExtractFileName(sr.Name), ''), clist);
          end;
        end;
      end;
      if hMod <> 0 then
        freeLibrary(hMod);
      i := WideFindNext(sr);
    end;
    WideFindClose(sr);
  finally
    //compare fZeroCnt and RefCount before Release call, so add 1
    fZeroCnt:=RefCount-fZeroCnt+1;
  end;
end;

destructor TApplication.destroy;
var
  i: integer;
  o: TObject;
begin
  fZeroCnt:=-1;
  fLogger:=Unassigned;
  if assigned(moduleList) then
    for i := moduleList.Count - 1 downto 0 do begin
      o := moduleList.Objects[i];
      if assigned(o) then begin
        o.Free;
        moduleList.Objects[i] := nil;
      end;
    end;
  FreeAndNil(moduleList);
  inherited;
end;

{ TModuleClassList }

constructor TModuleClassList.create;
begin
  hModule := 0;
end;

destructor TModuleClassList.destroy;
begin
  if assigned(iModule) then begin
    iModule.appRef:=nil;
    iModule := nil;
  end;
  if hModule <> 0 then
    freeLibrary(hModule);
  hModule := 0;
  inherited;
end;

function TApplication.Get_logger: OleVariant;
begin
  result:=fLogger;
end;

procedure TApplication.log(const msg: WideString);
begin
  if not VarIsType(fLogger,varDispatch) then
    debugPrint(msg)
  else
    try
      fLogger.log(msg);
    except
      logger:=0;
    end;
end;

procedure TApplication.Set_logger(Value: OleVariant);
begin
  fLogger:=Value;
end;

function TApplication.ObjRelease: Integer;
begin
  if (RefCount<=fZeroCnt) then begin
    if RefCount=fZeroCnt then
      destroy();
    result:=0;
  end
  else
    result:=inherited ObjRelease();
end;

procedure TApplication.onModuleUnload(const iModSelfPtr: IUnknown);
var
  i:integer;
  clist:TModuleClassList;
  intf:IOSManModule;
begin
  for i:=0 to moduleList.Count-1 do begin
    clist:=moduleList.Objects[i] as TModuleClassList;
    intf:=iModSelfPtr as IOSManModule;
    if(clist.iModule=intf) then begin
      moduleList.Objects[i]:=nil;
      clist.Free();
      moduleList.Delete(i);
      break;
    end;
  end;
end;

initialization
  TAutoObjectFactory.create(ComServer, TApplication, Class_Application,
    ciMultiInstance, tmApartment);
end.

