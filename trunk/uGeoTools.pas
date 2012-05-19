unit uGeoTools;

interface
uses Math, SysUtils, Variants, uInterfaces, uOSMCommon, uModule, uMultipoly;

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
    procedure bitRound(aNode: OleVariant; aBitLevel: integer);
    function wayToNodeArray(aMap, aWayOrWayId: OleVariant): OleVariant;
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
  d12_2, d13_2, d23_2, d2, d: double;
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
        d12_2 := pt2.fastDistSqrM(pt1);
        d13_2 := pt1.fastDistSqrM(pt3);
        d23_2 := pt2.fastDistSqrM(pt3);
        d2 := d13_2 - d12_2;
        if (d23_2 <= d2) then
          d := d12_2
        else if (d23_2 <= -d2) then
          d := d13_2
        else if (d23_2 < 1E-4) then
          d := d12_2
        else begin
          d := (d23_2 - d2) / (2 * sqrt(d23_2));
          d := abs(d12_2 - d * d);
        end;
        if (d < result) then result := d;
      end;
      result := sqrt(result);
    finally
      VarArrayUnlock(non);
    end;
  end;
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
      if not VarIsType(pNd^, varDispatch) then
        raise EReadError.create(toString() + '.wayToNodeArray: node ' + inttostr(pId^) +
          ' not found');
      inc(pNd);
      inc(pId);
    end;
  finally
    VarArrayUnlock(result);
    VarArrayUnlock(aWayOrWayId);
  end;
end;

initialization
  uModule.OSManRegister(TGeoTools, geoToolsClassGUID);
  //  test();
end.

