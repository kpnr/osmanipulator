unit uGeoTools;

interface
uses Math, SysUtils, Variants, uInterfaces, uOSMCommon, uModule, uMultipoly, ShellApi, Windows;

implementation

uses Classes;

const
  geoToolsClassGUID: TGUID = '{DF3ADB6E-3168-4C6B-9775-BA46C638E1A2}';

type

  TGeoTools = class(TOSManObject, IGeoTools)
  protected
    pt1, pt2, pt3: TGTPoint;
  public
    destructor destroy; override;
  published
    function createPoly(): OleVariant;
    function distance(const node, nodeOrNodes: OleVariant): double;
    function exec(const cmdLine: WideString): OleVariant;
    function wayToNodeArray(aMap, aWayOrWayId: OleVariant): OleVariant;
    procedure bitRound(aNode: OleVariant; aBitLevel: integer);
    function utf8to16(const U8:WideString):WideString;
  end;

  TAppExec = class(TOSManObject, IAppExec)
  protected
    hProcess: THandle;
  public
    constructor create(); override;
    destructor destroy(); override;
    function get_exitCode(): integer;
    function get_processId(): integer;
    function get_status(): integer;
  published
    procedure terminate();
    property exitCode: integer read get_exitCode;
    property processId: integer read get_processId;
    property status: integer read get_status;
  end;
  { TGeoTools }

procedure TGeoTools.bitRound(aNode: OleVariant; aBitLevel: integer);
var
  l, k: double;
begin
  if aBitLevel > 31 then
    //no conversion needed
    exit;
  if aBitLevel < 2 then
    aBitLevel := 2;
  l := aNode.lat;
  k := 360 / (cardinal(1) shl aBitLevel); //k*(2^bitLevel)==360
  aNode.lat := round(l / k) * k;
  l := aNode.lon;
  aNode.lon := round(l / k) * k;
end;

function TGeoTools.createPoly: OleVariant;
begin
  result := TMultiPoly.create() as IDispatch;
end;

destructor TGeoTools.destroy;
begin
  freeAndNil(pt1);
  freeAndNil(pt2);
  freeAndNil(pt3);
  inherited;
end;

function TGeoTools.distance(const node, nodeOrNodes: OleVariant): double;
var
  non: OleVariant;
  pv: POleVariant;
  i: integer;
  d: double;
begin
  if not assigned(pt1) then pt1 := TGTPoint.create();
  if not assigned(pt2) then pt2 := TGTPoint.create();
  pt1.assignNode(node);
  non := varFromJsObject(nodeOrNodes);
  if VarIsArray(non) then
    i := varArrayLength(non)
  else
    i := 1;
  if i = 1 then begin
    if VarIsArray(non) then non := non[0];
    pt2.assignNode(non);
    result := pt1.fastDistM(pt2);
  end
  else begin
    if not assigned(pt3) then pt3 := TGTPoint.create();
    result := MaxDouble;
    pv := VarArrayLock(non);
    try
      i := varArrayLength(non);
      while (i > 1) and (result > 0) do begin
        pt2.assignNode(pv^);
        inc(pv);
        pt3.assignNode(pv^);
        dec(i);
        d:=pt1.fastDistSqrM(pt2,pt3);
        if (d < result) then result := d;
      end;
      result := sqrt(result);
    finally
      VarArrayUnlock(non);
    end;
  end;
end;

function TGeoTools.exec(const cmdLine: WideString): OleVariant;
var
  pei: TShellExecuteInfoW;
  ae: TAppExec;
  le: dword;
  app, cmdl: WideString;
  i, j: integer;
begin
  fillchar(pei, sizeof(pei), 0);
  pei.cbSize := sizeof(pei);
  pei.fMask := SEE_MASK_DOENVSUBST or SEE_MASK_FLAG_DDEWAIT or
    SEE_MASK_FLAG_NO_UI or SEE_MASK_NOCLOSEPROCESS or SEE_MASK_UNICODE;
  if (length(cmdLine) > 0) then begin
    if (cmdLine[1] = '"') then begin
      i := posEx('"', cmdLine, 2, high(integer));
      app := copy(cmdLine, 2, i - 2);
      cmdl := copy(cmdLine, i + 1, high(integer));
    end
    else begin
      i := posEx(' ', cmdLine, 2, high(integer));
      j := posEx('/', cmdLine, 2, high(integer));
      if ((j > 0) and (j < i)) then i := j;
      if (i < 1) then i := length(cmdLine) + 1;
      app := copy(cmdLine, 1, i - 1);
      cmdl := copy(cmdLine, i, high(integer));
    end;
  end;
  pei.lpFile := pWideChar(app);
  pei.lpParameters := pWideChar(cmdl);
  pei.nShow := SW_SHOW;
  if not ShellExecuteExW(@pei) then begin
    le := GetLastError();
    raise EInOutError.create(toString() + '.exec: ' + SysErrorMessage(le));
  end;
  ae := TAppExec.create();
  if (pei.hProcess <> 0) then
    ae.hProcess := pei.hProcess;
  result := ae as IDispatch;
end;

function TGeoTools.utf8to16(const U8: WideString): WideString;
begin
  setlength(result,length(U8)*2);
  if(length(U8)=0)then exit;
  setlength(result,Utf8ToUnicode(pWidechar(result),pAnsiChar(@U8[1]),length(result)+1)-1);
end;

function TGeoTools.wayToNodeArray(aMap,
  aWayOrWayId: OleVariant): OleVariant;
var
  h, i: integer;
  pId, pNd: POleVariant;
  i64: int64;
begin
  aWayOrWayId := varFromJsObject(aWayOrWayId);
  if not VarIsType(aWayOrWayId, varDispatch) then begin
    //not object, so treat it as Id
    i64 := aWayOrWayId;
    aWayOrWayId := aMap.getWay(i64);
  end;
  if not VarIsType(aWayOrWayId, varDispatch) then
    raise EReadError.create(toString() + '.wayToNodeArray: way ' + inttostr(i64) + ' not found');
  aWayOrWayId := aWayOrWayId.nodes;
  h := varArrayLength(aWayOrWayId) - 1;
  result := VarArrayCreate([0, h], varVariant);
  pNd := VarArrayLock(result);
  pId := VarArrayLock(aWayOrWayId);
  try
    for i := 0 to h do begin
      pNd^ := aMap.getNode(pId^);
      if not VarIsType(pNd^, varDispatch) then begin
        i64:=pId^;
        raise EReadError.create(toString() + '.wayToNodeArray: node ' + inttostr(i64) +
          ' not found');
      end;
      inc(pNd);
      inc(pId);
    end;
  finally
    VarArrayUnlock(result);
    VarArrayUnlock(aWayOrWayId);
  end;
end;

{ TAppExec }

constructor TAppExec.create;
begin
  inherited;
  hProcess := INVALID_HANDLE_VALUE;
end;

destructor TAppExec.destroy;
begin
  if (hProcess <> INVALID_HANDLE_VALUE) then
    closeHandle(hProcess);
  inherited;
end;

function TAppExec.get_exitCode: integer;
var
  ec: dword;
begin
  if (hProcess = INVALID_HANDLE_VALUE) then
    result := 0
  else if (GetExitCodeProcess(hProcess, ec)) and (ec = STILL_ACTIVE) then begin
    result := 0;
  end
  else begin
    result := integer(ec);
  end;
end;

function TAppExec.get_processId: integer;
begin
  result := hProcess;
end;

function TAppExec.get_status: integer;
var
  ec: dword;
begin
  if (hProcess = INVALID_HANDLE_VALUE) then
    result := 1
  else if (GetExitCodeProcess(hProcess, ec)) and (ec = STILL_ACTIVE) then begin
    result := 0;
  end
  else begin
    result := 1;
  end;
end;

procedure TAppExec.terminate;
begin
  TerminateProcess(hProcess, dword(-1));
end;

initialization
  uModule.OSManRegister(TGeoTools, geoToolsClassGUID);
end.

