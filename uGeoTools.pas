unit uGeoTools;

interface
uses Math, SysUtils, Variants, uInterfaces, uOSMCommon, uModule, uDataStructures;

type
  TGTShape = class(TObject)
  protected
    function clone: TGTShape; virtual; abstract;
  end;

  TGTShapeArray = array of TGTShape;

  TGTPoint = class(TGTShape)
  protected
    fx, fy: integer;
    function get_lat: double;
    function get_lon: double;
    procedure set_lat(const aLat: double);
    procedure set_lon(const aLon: double);
    //special call conversion!!! argument is in st(0)!
    // angle should be in [-pi/2...pi/2]
    // accuracy about 0.00015 in worst case
    class function _fastCosRad(): double;
    //special call conversion!!! argument is in st(0),
    //result cos in st(0), sin in st(1) as after fsincos instruction!
    // angle should be in [-pi/2...pi/2]
    // accuracy about 0.00015 in worst case
    class function _fastSinCosRad(): double;
    //special call conversion!!! argument is in st(0)!
    // angle should be in [-90E7...+90E7]
    // accuracy about 0.00015 in worst case
    class function _fastCosDegScaled(): double;
    //special call conversion!!! argument is in st(0)!
    // angle should be in [-90E7...+90E7]
    // accuracy about 0.00015 in worst case
    class function _fastSinDegScaled(): double;
    //special call conversion!!! argument is in st(0),
    //result cos in st(0), sin in st(1) as after fsincos instruction!
    // angle should be in [-90E7...+90E7]
    // accuracy about 0.00015 in worst case
    class function _fastSinCosDegScaled(): double;
  public
    function clone(): TGTShape; override;
    //return true if pt is about DistM meters from this point
    function distTest(pt: TGTPoint; const DistM: single): boolean;
    function fastDistM(pt: TGTPoint): double; //returns sqrt(fastDistSqrM)
    function fastDistSqrM(pt: TGTPoint): double; //returns dist^2.
    procedure assignNode(aNode: OleVariant);
    property x: integer read fx write fx;
    property y: integer read fy write fy;
    property lat: double read get_lat write set_lat;
    property lon: double read get_lon write set_lon;
  end;

  TGTRect = class(TGTShape)
  protected
    fLeft, fRight, fTop, fBottom: integer;
    //returns:
    //0 - v outside (min,max)
    //1 - (v = min) or (v=max)
    //2 - min<v<max
    class function between(const v, min, max: integer): integer;
    function get_height: cardinal;
    function get_width: cardinal;
    procedure resetBounds();
  public
    constructor create();
    function clone: TGTShape; override;
    function canInterserts(const r: TGTRect): boolean;
    //isIn returns:
    //0 - pt outside
    //1 - pt is on bound
    //2 - pt is inside
    function isIn(const pt: TGTPoint): integer; virtual;
    procedure updateBoundRect(const pt: TGTPoint);
    property left: integer read fLeft write fLeft;
    property right: integer read fRight write fRight;
    property top: integer read fTop write fTop;
    property bottom: integer read fBottom write fBottom;
    property width: cardinal read get_width;
    property height: cardinal read get_height;
  end;

implementation

uses Classes;

const
  geoToolsClassGUID: TGUID = '{DF3ADB6E-3168-4C6B-9775-BA46C638E1A2}';
  //constants for TMultiPoly bbox hashing
  hashBits = 9;
  hashSize = 1 shl hashBits;
  //threshold for 'same node' detection in getIntersection routines.
  minPtDist = 0.1; //0.1 meter=10 cm

type

  TGTRefItem = record
    RefId: int64;
    RefRole: WideString;
    RefType: TRefType;
  end;

  TGTPointArray = array of TGTPoint;

  TGTPoly = class(TGTRect)
  protected
    fPoints: TGTPointArray;
    fCount: integer;
    function get_capacity: integer;
    procedure set_capacity(const Value: integer);
    procedure addExtraNode();
  public
    destructor destroy; override;
    function clone(): TGTShape; override;
    function isIn(const pt: TGTPoint): integer; override;
    //returns unsigned area of polygon in square meters
    function getArea(): double;
    //if x outside poly nil returned, else returns right half of poly
    function splitX(x: integer): TGTPoly;
    //if y outside poly nil returned, else returns top half of poly
    function splitY(y: integer): TGTPoly;
    procedure addNode(const aNode: OleVariant);
    property count: integer read fCount;
    property capacity: integer read get_capacity write set_capacity;
  end;

  PGTRefItem = ^TGTRefItem;

  TGTRefs = class(TGTShape)
  protected
    fId: int64;
    fRefList: array of TGTRefItem;
    function get_item(const idx: integer): TGTRefItem;
    function get_count: integer;
    function get_id: int64;
    function clone(): TGTShape; override;
  public
    property item[const i: integer]: TGTRefItem read get_item; default;
    property count: integer read get_count;
    property id: int64 read get_id;
  end;

  TGTWay = class(TGTRefs)
  public
    function merge(const segment: TGTWay): boolean;
    procedure AddWay(const osmWay: OleVariant);
    function firstId: int64;
    function lastId: int64;
  end;

  TGTRelation = class(TGTRefs)
  public
    procedure AddRelation(OSMRelation: OleVariant);
  end;

  TGeoTools = class(TOSManObject, IGeoTools)
  protected
    pt1, pt2: TGTPoint;
  public
    destructor destroy; override;
  published
    function createPoly(): OleVariant;
    function distance(const node1, node2: OleVariant): double;
    procedure bitRound(aNode: OleVariant; aBitLevel: integer);
    function wayToNodeArray(aMap, aWayOrWayId: OleVariant): OleVariant;
  end;

  TMultiPolyListItem = record
    obj: OleVariant;
    parentIdx: integer;
  end;

  PMultiPolyListItem = ^TMultiPolyListItem;

  TMultiPolyList = record
    items: array of TMultiPolyListItem;
    count: integer;
  end;

  TMultiPoly = class(TOSManObject, IMultiPoly)
  protected
    srcList, //parentIdx ignored
    relationList, //parentIdx=parent_relation_relationList_idx or (-1-parent_relation_srcList_idx)
    wayList, //parentIdx=parent_relation_relationList_idx or (-1-parent_relation_srcList_idx)
    nodeList //parentIdx=parent_way_wayList_idx
    : TMultiPolyList;
    simplePolyList, optimizedPolyList: array of TGTPoly;
    optimizedPolyParent: array of integer;
    optimizedPolyHash: array of array of array of integer;
    fNotResolved, fNotClosed: TRefList;
    fArea: double;

    class function getSegmentIntersection(const pt1, pt2, ptA, ptB: TGTPoint): TGTPoint;

    function isAllResolved(): boolean;

    function getLineIntersection(const aMap, aNodeArray: OleVariant; newNodeId: int64): OleVariant;
    function getPolyIntersection(const aMap, aNodeArray: OleVariant; newNodeId: int64): OleVariant;

    procedure growList(var list: TMultiPolyList; delta: integer = 1);
    procedure clearList(var list: TMultiPolyList);
    procedure putList(var list: TMultiPolyList; const obj: OleVariant; parent: integer);

    procedure createNotResolved();
    procedure createNotClosed();

    procedure clearInternalLists();

    procedure buildOptimizedPolyList();
    procedure buildOptimizedPolyHash();
    class function intToHash(i: integer): cardinal;
  public
    destructor destroy; override;
    function isInInt(const pt: TGTPoint): integer; //0-out, 2-in, 1-onbound
  published
    //add MapObject to polygon. Nodes not allowed,
    //node-members in Relation are ignored
    procedure addObject(const aMapObject: OleVariant);
    //returns true if all relations/way/nodes resolved, false otherwise
    function resolve(const srcMap: OleVariant): boolean;
    //IRefList of not resolved references
    function getNotResolved(): OleVariant;
    //IRefList of not closed nodes.
    function getNotClosed(): OleVariant;
    function getIntersection(const aMap, anObj: OleVariant; newNodeId: int64): OleVariant;
    //returns true if node is in poly (including border)
    function isIn(const aNode: OleVariant): boolean;
    //returns multipoly area in square meters
    //if poly not resolved then exception raised
    function getArea(): double;
    //returns bounding box for poly. Returns SafeArray of four double variants
    // for N,E,S and W bounds respectively. If poly is not resolved then
    // exception raised.
    function getBBox: OleVariant;
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
  inherited;
end;

function TGeoTools.distance(const node1, node2: OleVariant): double;
begin
  if not assigned(pt1) then pt1 := TGTPoint.create();
  if not assigned(pt2) then pt2 := TGTPoint.create();
  pt1.assignNode(node1);
  pt2.assignNode(node2);
  result := pt1.fastDistM(pt2);
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
    varArrayUnlock(result);
    varArrayUnlock(aWayOrWayId);
  end;
end;

{ TGTRefs }

function TGTRefs.clone: TGTShape;
begin
  raise EInvalidOp.create(className() + '.clone: not implemented');
end;

function TGTRefs.get_count: integer;
begin
  result := length(fRefList);
end;

function TGTRefs.get_id: int64;
begin
  result := fId;
end;

function TGTRefs.get_item(const idx: integer): TGTRefItem;
begin
  result := fRefList[idx];
end;

{ TGTWay }

procedure TGTWay.AddWay(const osmWay: OleVariant);
var
  members: OleVariant;
  n, i: integer;
  pv: PVariant;
  pr: PGTRefItem;
begin
  fId := osmWay.id;
  members := osmWay.nodes;
  n := varArrayHighBound(members, 1) - varArrayLowBound(members, 1) + 1;
  if n <= 1 then
    exit;
  i := length(fRefList);
  setLength(fRefList, i + n);
  pv := VarArrayLock(members);
  pr := @fRefList[i];
  try
    while n > 0 do begin
      pr.RefType := rtNode;
      pr.RefId := pv^;
      inc(pv);
      pr.RefRole := '';
      inc(pr);
      dec(n);
    end;
  finally
    varArrayUnlock(members);
  end;
end;

function TGTWay.firstId: int64;
begin
  result := fRefList[0].RefId;
end;

function TGTWay.lastId: int64;
begin
  result := fRefList[length(fRefList) - 1].RefId;
end;

function TGTWay.merge(const segment: TGTWay): boolean;
var
  i, j: integer;

  procedure grow();
  begin
    setLength(fRefList, i + j - 1);
  end;
begin
  i := length(fRefList);
  j := length(segment.fRefList);
  result := true;
  if (j = 0) then
    exit;
  if (i = 0) then begin
    fRefList := Copy(segment.fRefList, 0, j);
    exit;
  end;
  if firstId = segment.firstId then begin
    //new=reverse(segment)+old
    grow();
    dec(j);
    move(fRefList[0], fRefList[j], i * sizeof(fRefList[0]));
    i := 0;
    while j >= 1 do begin
      fRefList[i] := segment.fRefList[j];
      inc(i);
      dec(j);
    end;
  end
  else if lastId = segment.firstId then begin
    //new=old+segment
    grow();
    move(segment.fRefList[1], fRefList[i], (j - 1) * sizeof(fRefList[0]));
  end
  else if firstId = segment.lastId then begin
    //new=segment+old
    grow();
    move(fRefList[0], fRefList[j - 1], i * sizeof(fRefList[0]));
    move(segment.fRefList[0], fRefList[0], (j - 1) * sizeof(fRefList[0]));
  end
  else if lastId = segment.lastId then begin
    //new=old+reverse(segment)
    grow();
    dec(j, 2);
    while j >= 0 do begin
      fRefList[i] := segment.fRefList[j];
      inc(i);
      dec(j);
    end;
  end
  else
    result := false;
end;

{ TGTRelation }

procedure TGTRelation.AddRelation(OSMRelation: OleVariant);
var
  members: OleVariant;
  n, i: integer;
  pv: PVariant;
  pr: PGTRefItem;
begin
  fId := OSMRelation.id;
  members := OSMRelation.members.getAll;
  n := (varArrayHighBound(members, 1) - varArrayLowBound(members, 1) + 1) div 3;
  if n <= 0 then
    exit;
  i := length(fRefList);
  setLength(fRefList, i + n);
  pv := VarArrayLock(members);
  pr := @fRefList[i];
  try
    while n > 0 do begin
      pr.RefType := strToRefType(pv^);
      inc(pv);
      pr.RefId := pv^;
      inc(pv);
      pr.RefRole := pv^;
      inc(pv);
      inc(pr);
      dec(n);
    end;
  finally
    varArrayUnlock(members);
  end;
end;

{ TGTPoint }

function TGTPoint.get_lat: double;
begin
  result := IntToDeg(y);
end;

function TGTPoint.get_lon: double;
begin
  result := IntToDeg(x);
end;

procedure TGTPoint.set_lat(const aLat: double);
begin
  y := degToInt(aLat);
end;

procedure TGTPoint.set_lon(const aLon: double);
begin
  x := degToInt(aLon);
end;

function TGTPoint.clone: TGTShape;
var
  p: TGTPoint;
begin
  p := TGTPoint.create();
  p.fx := fx;
  p.fy := fy;
  result := p;
end;

procedure TGTPoint.assignNode(aNode: OleVariant);
begin
  lat := aNode.lat;
  lon := aNode.lon;
end;

function TGTPoint.fastDistSqrM(pt: TGTPoint): double;
const
  half: single = 1 / 2;
  intToM_sqr: single = cIntToM * cIntToM;
  //var
  //  la1,la2,lo1,lo2:single;
  //  d:double;
  //begin
  //  la1:=degToRad(lat);
  //  la2:=degToRad(pt.lat);
  //  lo1:=degToRad(lon);
  //  lo2:=degToRad(pt.lon);
  //  result:=sqrt( sqr( (lo1-lo2)*fastCosDeg((la1+la2)/2) ) + sqr(la1-la2) )*degToM;
asm //about 30 cycles in Intel core
  fild TGTPoint(eax).fy //[y1]
  fild TGTPoint(edx).fy //[y1] [y2]
  fld st(1)             //[y1] [y2] [y1]
  fadd st(0),st(1)      //[y1] [y2] [y1+y2]
  fmul half             //[y1] [y2] [(y1+y2)/2]
  call _fastCosDegScaled//[y1] [y2] [cos((y1+y2)/2)]
  fxch st(2)            //[cos((y1+y2)/2)] [y2] [y1]
  fsubrp st(1),st(0)    //[cos((y1+y2)/2)] [y1-y2]
  fmul st(0),st(0)      //[cos((y1+y2)/2)] [(y1-y2)^2]
  fxch st(1)            //[(y1-y2)^2] [cos((y1+y2)/2)]
  fild TGTPoint(eax).fx //[(y1-y2)^2] [cos((y1+y2)/2)] [x1]
  fisub TGTPoint(edx).fx //[(y1-y2)^2] [cos((y1+y2)/2)] [x1-x2]
  fmulp st(1),st(0)     //[(y1-y2)^2] [cos((y1+y2)/2)*x1-x2]
  fmul st(0),st(0)      //[(y1-y2)^2] [cos(...)*...^2]
  faddp st(1),st(0)
  fmul IntToM_sqr
end;

function TGTPoint.fastDistM(pt: TGTPoint): double;
asm //about 25+fastDistSqrM cycles
  call TGTPoint.fastDistSqrM
  fsqrt
end;

function TGTPoint.distTest(pt: TGTPoint; const DistM: single): boolean;
begin //about 24 cycles on Intel core
  //0.75~~cos(40deg)
  result := DistM > (cIntToM * (abs(pt.y - y) + abs(pt.x - x) * 0.75));
end;

const //constants for _fastCos and _fastSinCos
  //cos(x+pi/4)=0.02858459580·x^4 + 0.1135350382·x^3 - 0.3533604496·x^2 - 0.7064928688·x + 0.7071007326
  a4 = 0.02851732610; //0.02858459580;// 1/(24*sqrt2);
  a3 = 0.1132388311; //0.1135350382;// 1/(6*sqrt2);
  a2 = -0.3533288887; //0.3533604496;// -1/(2*sqrt2);
  a1 = -0.7064030649; //0.7064928688;// -1/sqrt2;
  a0 = 0.7070991491; //0.7071007326;// 1/sqrt2;
  deltaRad = -PI / 4;
  //constants for radian arguments
  a4_sgl: single = a4;
  a3_sgl: single = a3;
  a2_sgl: single = a2;
  a1_sgl: single = a1;
  a0_sgl: single = a0;
  deltaRad_sgl: single = deltaRad;

  //constants for scaled degrees arguments
  ds4_sgl: single = a4 * cIntToRad * cIntToRad * cIntToRad * cIntToRad;
  ds3_sgl: single = a3 * cIntToRad * cIntToRad * cIntToRad;
  ds2_sgl: single = a2 * cIntToRad * cIntToRad;
  ds1_sgl: single = a1 * cIntToRad;
  ds0_sgl: single = a0;
  deltaDegScaled_sgl: single = deltaRad / cIntToRad;

class function TGTPoint._fastCosRad: double;
asm
//fastCos is about 31 cycles on Intel Core
//fcos is about 100 cycles on Intel Core
  fabs             //[|x|]
  fadd deltaRad_sgl//[y=|x|-pi/4]
  fld st(0)        //[y] [y]
  fmul st(0),st(0) //[y] [y2]
  fld a4_sgl       //[y] [y2] [a4]
  fmul st(0),st(1) //[y] [y2] [a4 y2]
  fadd a2_sgl      //[y] [y2] [a4 y2 + a2]
  fmul st(0),st(1) //[y] [y2] [a4 y4 + a2 y2]
  fxch st(1)       //[y] [a4 y4 + a2 y2] [y2]
  fmul a3_sgl      //[y] [a4 y4 + a2 y2] [a3 y2]
  fadd a1_sgl      //[y] [a4 y4 + a2 y2] [a3 y2 + a1]
  fmulp st(2),st(0)//[a3 y3 + a1 y] [a4 y4 + a2 y2]
  fadd a0_sgl      //[a3 y3 + a1 y] [a4 y4 + a2 y2 + a0]
  faddp st(1),st(0)//cos
end;

class function TGTPoint._fastSinCosRad: double;
asm
//fastSinCos is about 34 cycles on Intel Core
//fsincos is about 105 cycles in Intel Core
  fldz
  fcomip st(0),st(1)//set cf if st(1)>0, clear otherwise
  fabs               //[|x|]
  fadd deltaRad_sgl  //[x-pi/4=y]
  //
  fld st(0)          //[y] [y]
  fmul st(0),st(0)   //[y] [y2]
  fld a4_sgl         //[y] [y2] [a4]
  fmul st(0),st(1)   //[y] [y2] [a4 y2]
  fadd a2_sgl        //[y] [y2] [a4 y2 + a2]
  fmul st(0),st(1)   //[y] [y2] [a4 y4 + a2 y2]
  fadd a0_sgl        //[y] [y2] [a4 y4 + a2 y2 + a0]
  fxch st(1)         //[y] [a4 y4 + a2 y2 + a0] [y2]
  fmul a3_sgl        //[y] [a4 y4 + a2 y2 + a0] [a3 y2]
  fadd a1_sgl        //[y] [a4 y4 + a2 y2 + a0] [a3 y2 + a1]
  fmulp st(2),st(0)  //[a3 y3 + a1 y] [a4 y4 + a2 y2 + a0]
  fld st(0)          //[a3 y3 + a1 y] [a4 y4 + a2 y2 + a0] [a4 y4 + a2 y2 + a0]
  fsub st(0),st(2)   //[a3 y3 + a1 y] [a4 y4 + a2 y2 + a0] [sin]
  jc @@pos_sin
  fchs
@@pos_sin:
  fxch st(2)         //[sin] [a4y^4+a2y^2+a0] [a3y3+a1y]
  faddp st(1),st(0)  //[sin] [cos]
end;

class function TGTPoint._fastCosDegScaled: double;
asm
//fastCos is about 31 cycles on Intel Core
//fcos is about 100 cycles on Intel Core
  fabs             //[|x|]
  fadd deltaDegScaled_sgl//[y=|x|-pi/4]
  fld st(0)        //[y] [y]
  fmul st(0),st(0) //[y] [y2]
  fld ds4_sgl       //[y] [y2] [a4]
  fmul st(0),st(1) //[y] [y2] [a4 y2]
  fadd ds2_sgl      //[y] [y2] [a4 y2 + a2]
  fmul st(0),st(1) //[y] [y2] [a4 y4 + a2 y2]
  fxch st(1)       //[y] [a4 y4 + a2 y2] [y2]
  fmul ds3_sgl      //[y] [a4 y4 + a2 y2] [a3 y2]
  fadd ds1_sgl      //[y] [a4 y4 + a2 y2] [a3 y2 + a1]
  fmulp st(2),st(0)//[a3 y3 + a1 y] [a4 y4 + a2 y2]
  fadd ds0_sgl      //[a3 y3 + a1 y] [a4 y4 + a2 y2 + a0]
  faddp st(1),st(0)//cos
end;

class function TGTPoint._fastSinCosDegScaled: double;
asm
//fastSinCos is about 34 cycles on Intel Core
//fsincos is about 105 cycles in Intel Core
  fldz
  fcomip st(0),st(1)//set cf if st(1)>0, clear otherwise
  fabs               //[|x|]
  fadd deltaDegScaled_sgl  //[x-pi/4=y]
  fld st(0)          //[y] [y]
  fmul st(0),st(0)   //[y] [y2]
  fld ds4_sgl         //[y] [y2] [a4]
  fmul st(0),st(1)   //[y] [y2] [a4 y2]
  fadd ds2_sgl        //[y] [y2] [a4 y2 + a2]
  fmul st(0),st(1)   //[y] [y2] [a4 y4 + a2 y2]
  fadd ds0_sgl        //[y] [y2] [a4 y4 + a2 y2 + a0]
  fxch st(1)         //[y] [a4 y4 + a2 y2 + a0] [y2]
  fmul ds3_sgl        //[y] [a4 y4 + a2 y2 + a0] [a3 y2]
  fadd ds1_sgl        //[y] [a4 y4 + a2 y2 + a0] [a3 y2 + a1]
  fmulp st(2),st(0)  //[a3 y3 + a1 y] [a4 y4 + a2 y2 + a0]
  fld st(0)          //[a3 y3 + a1 y] [a4 y4 + a2 y2 + a0] [a4 y4 + a2 y2 + a0]
  fsub st(0),st(2)   //[a3 y3 + a1 y] [a4 y4 + a2 y2 + a0] [sin]
  jc @@pos_sin
  fchs
@@pos_sin:
  fxch st(2)         //[sin] [a4y^4+a2y^2+a0] [a3y3+a1y]
  faddp st(1),st(0)  //[sin] [cos]
end;

class function TGTPoint._fastSinDegScaled: double;
asm
  fldz
  fcomip st(0),st(1)//set cf if st(1)>0, clear otherwise
  fabs             //[|x|]
  fadd deltaDegScaled_sgl//[y=|x|-pi/4]
  fld st(0)        //[y] [y]
  fmul st(0),st(0) //[y] [y2]
  fld ds4_sgl       //[y] [y2] [a4]
  fmul st(0),st(1) //[y] [y2] [a4 y2]
  fadd ds2_sgl      //[y] [y2] [a4 y2 + a2]
  fmul st(0),st(1) //[y] [y2] [a4 y4 + a2 y2]
  fxch st(1)       //[y] [a4 y4 + a2 y2] [y2]
  fmul ds3_sgl      //[y] [a4 y4 + a2 y2] [a3 y2]
  fadd ds1_sgl      //[y] [a4 y4 + a2 y2] [a3 y2 + a1]
  fmulp st(2),st(0)//[a3 y3 + a1 y] [a4 y4 + a2 y2]
  fadd ds0_sgl      //[a3 y3 + a1 y] [a4 y4 + a2 y2 + a0]
  fsubrp st(1),st(0)//sin
  jc @@pos_sin
  fchs
@@pos_sin:
end;

{ TGTPoly }

procedure TGTPoly.addExtraNode;
begin
  if (count > 0) and ((fPoints[0].x <> fPoints[count - 1].x) or (fPoints[0].y <> fPoints[count -
    1].y)) then begin
    //close poly
    capacity := count + 1;
    fPoints[count] := TGTPoint.create();
    fPoints[count].x := fPoints[0].x;
    fPoints[count].y := fPoints[0].y;
    inc(fCount);
  end;
end;

procedure TGTPoly.addNode(const aNode: OleVariant);

  procedure grow();
  begin
    if capacity <= count then
      capacity := count * 2 or 4;
  end;
var
  pt: TGTPoint;
begin
  grow();
  pt := TGTPoint.create;
  pt.assignNode(aNode);
  fPoints[fCount] := pt;
  inc(fCount);
  updateBoundRect(pt);
end;

function TGTPoly.getArea: double;
const
  half: single = 1 / 2;
  cInt2ToM2_sgl: single = cIntToRad * cRadToM * cRadToM;
asm
//eax -> self
  push ebx
  push esi
  mov esi,TGTPoly(eax).fCount
  cmp esi,3
  fldz                 //0
  jc @@done
  dec esi
  mov ebx,TGTPoly(eax).fPoints//ebx=>fPoints[0]
  mov edx,[ebx]//edx=>TGTpoint0
  fild TGTPoint(edx).fx//0 x0
  fild TGTPoint(edx).fy//0 x0 y0
  add ebx,4
  fmul half            //0 x0 y0/2
@@loop:
    mov edx,[ebx]
    fild TGTPoint(edx).fy//A0 x0 y0/2 y1
    add ebx,4
    fmul half            //A0 x0 y0/2 y1/2
    fxch st(1)           //A0 x0 y1/2 y0/2
    fadd st(0),st(1)     //A0 x0 y1/2 (y0+y1)/2
    call TGTPoint._fastSinDegScaled//A0 x0 y1/2 sin((y0+y1)/2)
    fild TGTPoint(edx).fx//A0 x0 y1/2 sin(...) x1
    dec esi
    fxch st(3)           //A0 x1 y1/2 sin(...) x0
    fsubr st(0),st(3)    //A0 x1 y1/2 sin(...) x1-x0
    fmulp st(1),st(0)    //A0 x1 y1/2 sin(...)*x1-x0
    faddp st(3),st(0)    //A1 x1 y1/2
  jnz @@loop
  fstp st(0)           //A1 xn
  fstp st(0)           //A1
@@done:
  fmul cInt2ToM2_sgl   //S1
  pop esi
  pop ebx
  fabs                 //|S1|
end;

function TGTPoly.clone: TGTShape;
var
  i: integer;
  p: TGTPoly;
begin
  p := TGTPoly.create();
  p.fCount := fCount;
  setLength(p.fPoints, fCount);
  for i := 0 to fCount - 1 do begin
    p.fPoints[i] := TGTPoint(fPoints[i].clone());
  end;
  p.fLeft := fLeft;
  p.fRight := fRight;
  p.fTop := fTop;
  p.fBottom := fBottom;
  result := p;
end;

destructor TGTPoly.destroy;
var
  i: integer;
begin
  for i := 0 to count - 1 do
    freeAndNil(fPoints[i]);
  inherited;
end;

function TGTPoly.get_capacity: integer;
begin
  result := length(fPoints);
end;

function TGTPoly.isIn(const pt: TGTPoint): integer;
//returns 0 if edge(e1,e2) not intersects edge(a,pt(+inf,a.y))
//returns 1 if point a lay on edge(e1,e2)
//returns 2 if edge(e1,e2) intersects edge(a,pt(+inf,a.y))

  function intersects(const a, e1, e2: TGTPoint): integer;
    //precondition: (a.x between e1.x and e2.x) & (a.y between e1.y and e2.y)
  var
    k: double;
    x: integer;
  begin
    //line equation x=k*y+b
    //k=dx/dy
    //b=x1-k*y1
    k := e1.fx;
    k := (k - e2.fx) / (e1.fy - e2.fy); //we can add/subtract fy
    //b:=;
    x := round(k * a.fy + e1.fx - k * e1.fy);
    result := ord(a.fx = x) + 2 * ord(a.fx < x);
  end;
var
  i: integer;
  xcase, ycase: byte;
  b1, b2: TGTPoint;
begin
  result := inherited isIn(pt);
  if result = 0 then exit;
  result := 0;
  i := count;
  while (i > 1) do begin
    dec(i);
    b1 := fPoints[i];
    b2 := fPoints[i - 1];
    asm
      mov eax,pt;
      mov eax,TGTPoint(eax).fx;
      mov ecx,b1;
      cmp eax,TGTPoint(ecx).fx;
      setg cl;
      setl dl;
      lea ecx,[ecx+edx*4];
      mov edx,b2;
      cmp eax,TGTPoint(edx).fx;
      setg dl;
      setl al;
      lea ecx,[ecx+edx*2];
      lea ecx,[ecx+eax*8];
      mov xcase,cl;
    end;
    //    xcase := ord(b1.fx < pt.fx) + 2 * ord(b2.fx < pt.fx) +
    // 4 * ord(b1.fx > pt.fx) +  8 * ord(b2.fx > pt.fx);
    asm mov eax,pt; mov eax,TGTPoint(eax).fy; mov ecx,b1; cmp eax,TGTPoint(ecx).fy; setg cl; setl dl; lea ecx,[ecx+edx*4]; mov edx,b2; cmp eax,TGTPoint(edx).fy; setg dl; setl al; lea ecx,[ecx+edx*2]; lea ecx,[ecx+eax*8]; mov ycase,cl;
    end;
    //    ycase := ord(b1.fy < pt.fy) + 2 * ord(b2.fy < pt.fy) +
    //      4 * ord(b1.fy > pt.fy) + 8 * ord(b2.fy > pt.fy);
        //cases 5,7,10,11,13,14,15 are impossible
        //case 3 - no intersection
        //ycase=12 - no intersection
    case ycase of
      0: {y1==y==y2}
        case xcase of
          0, 1, 2, 4, 6, 8, 9: begin
              result := 1;
              break;
            end;
        end;
      1: {y1<y==y2}
        case xcase of
          0, 1, 4: begin
              result := 1;
              break;
            end;
          8, 9, 12: result := 2 - result;
        end;
      2: {y2<y==y1}
        case xcase of
          0, 2, 8: begin
              result := 1;
              break;
            end;
          4, 6, 12: result := 2 - result;
        end;
      4: {y1>y=y2}
        case xcase of
          0, 1, 4: begin
              result := 1;
              break;
            end;
        end;
      6, {y2<y<y1}
      9: {y1<y<y2}
        case xcase of
          0: begin
              result := 1;
              break;
            end;
          4, 8, 12: begin
              result := 2 - result;
            end;
          6, 9:
            case intersects(pt, b1, b2) of
              0: {no intersection};
              1: {on edge} begin
                  result := 1;
                  break;
                end;
              2: {intersects}
                result := 2 - result;
            end;
        end;
      8: {y1=y<y2}
        case xcase of
          0, 2, 8: begin
              result := 1;
              break;
            end;
        end;
    end;
  end;
end;

procedure TGTPoly.set_capacity(const Value: integer);
begin
  if Value <= count then exit;
  setLength(fPoints, Value);
end;

function approx(const x1, y1, x2, y2, x: integer): integer;
begin
  result := round((1.0 * y2 - y1) / (1.0 * x2 - x1) * (1.0 * x - x1) + y1);
end;

function TGTPoly.splitX(x: integer): TGTPoly;
var
  i, li, ri: integer;
  xcase: byte;
  rightPoly: TGTPoly;
  pt1, pt2, pt1b, pt2b: TGTPoint;
  newPoints: array of TGTPoint;

  procedure saveRight(const pt: TGTPoint);
  begin
    rightPoly.fPoints[ri] := pt;
    rightPoly.updateBoundRect(pt);
    inc(ri);
  end;

  procedure saveLeft(const pt: TGTPoint);
  begin
    newPoints[li] := pt;
    updateBoundRect(pt);
    inc(li);
  end;
begin
  result := nil;
  if (x <= left) or (x >= right) then exit;
  result := TGTPoly.create();
  result.capacity := count * 2;
  rightPoly := result;
  setLength(newPoints, count * 2);
  li := 0;
  ri := 0;
  resetBounds();
  for i := 0 to count - 2 do begin
    pt1 := fPoints[i];
    pt2 := fPoints[i + 1];
    xcase := ord(pt1.fx <= x) + 2 * ord(pt2.fx <= x);
    case xcase of
      0: {this point goes right poly}
        saveRight(pt1);
      1: {pt1 on left, pt2 on right} begin
          pt1b := TGTPoint.create();
          pt1b.fx := x;
          pt1b.fy := approx(pt1.fx, pt1.fy, pt2.fx, pt2.fy, x);
          pt2b := TGTPoint.create();
          pt2b.fx := x + 1;
          pt2b.fy := approx(pt1.fx, pt1.fy, pt2.fx, pt2.fy, x + 1);
          saveLeft(pt1);
          saveLeft(pt1b);
          saveRight(pt2b);
        end;
      2: {pt1 on right, pt2 on left} begin
          pt1b := TGTPoint.create();
          pt1b.fx := x + 1;
          pt1b.fy := approx(pt1.fx, pt1.fy, pt2.fx, pt2.fy, x + 1);
          pt2b := TGTPoint.create();
          pt2b.fx := x;
          pt2b.fy := approx(pt1.fx, pt1.fy, pt2.fx, pt2.fy, x);
          saveRight(pt1);
          saveRight(pt1b);
          saveLeft(pt2b);
        end;
      3: {keep this point left}
        saveLeft(pt1);
    end;
  end;
  fCount := li;
  capacity := li + 1;
  move(newPoints[0], fPoints[0], sizeof(fPoints[0]) * li);
  result.fCount := ri;
  result.capacity := ri + 1;
  result.addExtraNode();
  addExtraNode();
end;

function TGTPoly.splitY(y: integer): TGTPoly;
var
  i, ti, bi: integer;
  ycase: byte;
  topPoly: TGTPoly;
  pt1, pt2, pt1b, pt2b: TGTPoint;
  newPoints: array of TGTPoint;

  procedure saveTop(const pt: TGTPoint);
  begin
    topPoly.fPoints[ti] := pt;
    topPoly.updateBoundRect(pt);
    inc(ti);
  end;

  procedure saveBottom(const pt: TGTPoint);
  begin
    newPoints[bi] := pt;
    updateBoundRect(pt);
    inc(bi);
  end;
begin
  result := nil;
  if (y <= bottom) or (y >= top) then exit;
  result := TGTPoly.create();
  result.capacity := count * 2;
  topPoly := result;
  setLength(newPoints, count * 2);
  bi := 0;
  ti := 0;
  resetBounds();
  for i := 0 to count - 2 do begin
    pt1 := fPoints[i];
    pt2 := fPoints[i + 1];
    ycase := ord(pt1.fy <= y) + 2 * ord(pt2.fy <= y);
    case ycase of
      0: {this point goes top poly}
        saveTop(pt1);
      1: {pt1 on bottom, pt2 on top} begin
          pt1b := TGTPoint.create();
          pt1b.fy := y;
          pt1b.fx := approx(pt1.fy, pt1.fx, pt2.fy, pt2.fx, y);
          pt2b := TGTPoint.create();
          pt2b.fy := y + 1;
          pt2b.fx := approx(pt1.fy, pt1.fx, pt2.fy, pt2.fx, y + 1);
          saveBottom(pt1);
          saveBottom(pt1b);
          saveTop(pt2b);
        end;
      2: {pt1 on top, pt2 on bottom} begin
          pt1b := TGTPoint.create();
          pt1b.fy := y + 1;
          pt1b.fx := approx(pt1.fy, pt1.fx, pt2.fy, pt2.fx, y + 1);
          pt2b := TGTPoint.create();
          pt2b.fy := y;
          pt2b.fx := approx(pt1.fy, pt1.fx, pt2.fy, pt2.fx, y);
          saveTop(pt1);
          saveTop(pt1b);
          saveBottom(pt2b);
        end;
      3: {keep this point bottom}
        saveBottom(pt1);
    end;
  end;
  fCount := bi;
  capacity := bi + 1;
  move(newPoints[0], fPoints[0], sizeof(fPoints[0]) * bi);
  result.fCount := ti;
  result.capacity := ti + 1;
  result.addExtraNode();
  addExtraNode();
end;

{ TGTRect }

class function TGTRect.between(const v, min, max: integer): integer;
begin
  result := 2 * ord((v > min) and (v < max)) + ord((v = min) or (v = max));
end;

function TGTRect.canInterserts(const r: TGTRect): boolean;
begin
  result := (left <= r.right) and (right >= r.left) and
    (bottom <= r.top) and (top >= r.bottom);
end;

function TGTRect.clone: TGTShape;
var
  r: TGTRect;
begin
  r := TGTRect.create();
  r.left := left;
  r.right := right;
  r.top := top;
  r.bottom := bottom;
  result := r;
end;

constructor TGTRect.create;
begin
  resetBounds();
  inherited;
end;

function TGTRect.get_height: cardinal;
begin
  {$R-}
  result := cardinal(fTop) - cardinal(fBottom)
end;

function TGTRect.get_width: cardinal;
begin
  {$R-}
  result := cardinal(fRight) - cardinal(fLeft);
end;

function TGTRect.isIn(const pt: TGTPoint): integer;
begin
  result := min(between(pt.x, left, right), between(pt.y, bottom, top));
end;

procedure TGTRect.resetBounds;
begin
  left := high(left);
  right := low(right);
  top := low(top);
  bottom := high(bottom);
end;

procedure TGTRect.updateBoundRect(const pt: TGTPoint);
begin
  with pt do begin
    if left > x then
      left := x;
    if x > right then
      right := x;
    if y < bottom then
      bottom := y;
    if top < y then
      top := y;
  end;
end;

{ TMultiPoly }

procedure TMultiPoly.addObject(const aMapObject: OleVariant);
var
  s: WideString;
  o: Variant;
begin
  //add object to inList
  varCopyNoInd(o, aMapObject);
  if VarIsType(o, varDispatch) then begin
    s := o.getClassName();
    if (s = 'Relation') or (s = 'Way') then begin
      putList(srcList, o, -1);
      clearInternalLists();
    end
    else begin
      raise EConvertError.create(toString() + 'addObject: invalid object');
    end;
  end;
end;

procedure TMultiPoly.clearList(var list: TMultiPolyList);
begin
  setLength(list.items, 0);
  list.count := 0;
end;

procedure TMultiPoly.clearInternalLists();
var
  i: integer;
begin
  clearList(relationList);
  clearList(wayList);
  clearList(nodeList);
  if assigned(fNotResolved) then begin
    (fNotResolved as IDispatch)._Release();
    fNotResolved := nil;
  end;
  if assigned(fNotClosed) then begin
    (fNotClosed as IDispatch)._Release();
    fNotClosed := nil;
  end;
  for i := 0 to high(simplePolyList) do begin
    if assigned(simplePolyList[i]) then
      freeAndNil(simplePolyList[i]);
  end;
  setLength(simplePolyList, 0);
  for i := 0 to high(optimizedPolyList) do begin
    if assigned(optimizedPolyList[i]) then
      freeAndNil(optimizedPolyList[i]);
  end;
  setLength(optimizedPolyList, 0);
  setLength(optimizedPolyParent, 0);
  setLength(optimizedPolyHash, 0);
  fArea := -1;
end;

procedure TMultiPoly.createNotClosed;
begin
  if not assigned(fNotClosed) then begin
    fNotClosed := TRefList.create();
    (fNotClosed as IDispatch)._AddRef();
  end;
end;

procedure TMultiPoly.createNotResolved;
begin
  if not assigned(fNotResolved) then begin
    fNotResolved := TRefList.create();
    (fNotResolved as IDispatch)._AddRef();
  end;
end;

destructor TMultiPoly.destroy;
begin
  clearInternalLists();
  inherited;
end;

function TMultiPoly.getBBox: OleVariant;
var
  n, e, s, w, t: integer;
  i: integer;
  poly: TGTPoly;
begin
  if not isAllResolved() then
    raise EConvertError.create(toString() + '.bbox: polygon must be resolved');
  if nodeList.count > 0 then begin
    n := low(integer);
    s := high(integer);
    e := low(integer);
    w := high(integer);
    for i := 0 to high(simplePolyList) do begin
      poly := simplePolyList[i];
      t := poly.left;
      if t < w then w := t;
      t := poly.right;
      if e < t then e := t;
      t := poly.top;
      if n < t then n := t;
      t := poly.bottom;
      if t < s then s := t;
    end;
  end
  else begin
    n := 0;
    e := 0;
    s := 0;
    w := 0;
  end;
  result := VarArrayOf([IntToDeg(n), IntToDeg(e), IntToDeg(s), IntToDeg(w)]);
end;

function TMultiPoly.getNotClosed: OleVariant;
begin
  createNotClosed();
  result := fNotClosed as IDispatch;
end;

function TMultiPoly.getNotResolved: OleVariant;
begin
  createNotResolved();
  result := fNotResolved as IDispatch;
end;

procedure TMultiPoly.growList(var list: TMultiPolyList; delta: integer);
var
  l, nl: integer;
begin
  l := length(list.items);
  nl := list.count + delta;
  if (nl > l) then begin
    nl := (nl or 15) + 1;
    setLength(list.items, nl);
  end;
end;

function TMultiPoly.isIn(const aNode: OleVariant): boolean;
var
  pt: TGTPoint;
begin
  if not isAllResolved() then
    raise EConvertError.create(toString() +
      '.isIn : not all references resolved or polygons closed.');
  pt := TGTPoint.create();
  try
    pt.assignNode(aNode);
    result := isInInt(pt) > 0;
  finally
    freeAndNil(pt);
  end;
end;

procedure TMultiPoly.putList(var list: TMultiPolyList;
  const obj: OleVariant; parent: integer);
var
  PI: PMultiPolyListItem;
begin
  growList(list);
  PI := @list.items[list.count];
  PI.obj := obj;
  PI.parentIdx := parent;
  inc(list.count);
end;

function TMultiPoly.resolve(const srcMap: OleVariant): boolean;

  procedure addNotResolved(const RefType: WideString; const RefId: int64);
  begin
    //add not resolved reference to list
    fNotResolved.insertBefore(maxInt, RefType, RefId, '');
  end;

  procedure sortSrcObjByType();
  var
    i: integer;
    s: WideString;
    v: OleVariant;
  begin
    //put relations into relationList, put ways into wayList
    for i := 0 to srcList.count - 1 do begin
      v := srcList.items[i].obj;
      s := v.getClassName();
      if s = 'Relation' then
        putList(relationList, v, -1 - i)
      else
        putList(wayList, v, -1 - i);
    end;
  end;

  function resolveRelations(): boolean; //true if all relations and members resolved
  var
    i, mlen: integer;
    v, ml, newObj: Variant;
    pv: POleVariant;
    s: WideString;
    id: int64;
  begin
    //resolve relations into child-relations and ways
    result := true;
    i := 0;
    while (i < relationList.count) do begin
      v := relationList.items[i].obj;
      if (v.tags.getByKey('type') <> 'collection') then begin
        //process non-collection relation
        ml := v.members.getAll();
        mlen := varArrayLength(ml);
        pv := VarArrayLock(ml);
        try
          while mlen > 0 do begin
            s := pv^;
            inc(pv);
            id := pv^;
            inc(pv, 2);
            dec(mlen, 3);
            if (s = 'relation') then begin
              varCopyNoInd(newObj, srcMap.getRelation(id));
              if VarIsType(newObj, varDispatch) then
                putList(relationList, newObj, i)
              else begin
                addNotResolved('relation', id);
                result := false;
              end;
            end
            else if (s = 'way') then begin
              varCopyNoInd(newObj, srcMap.getWay(id));
              if VarIsType(newObj, varDispatch) then
                putList(wayList, newObj, i)
              else begin
                addNotResolved('way', id);
                result := false;
              end;
            end
          end;
        finally
          varArrayUnlock(ml);
        end;
      end;
      inc(i);
    end;
  end;

type
  TWayDescItem = record
    way: TMultiPolyList;
    id0, id1: int64;
  end;

  PWayDescItem = ^TWayDescItem;

  TWayDescList = record
    items: array of TWayDescItem;
    count: integer;
  end;

var
  wayMergeList: TWayDescList;

  function resolveWays(): boolean; //returns true if all node refs resolved
  var
    i, mlen: integer;
    v, ml, newObj: Variant;
    pv: POleVariant;
    id: int64;
    pwd: PWayDescItem;
  begin
    result := true;
    setLength(wayMergeList.items, wayList.count);
    wayMergeList.count := 0;
    pwd := @wayMergeList.items[0];
    //resolve ways into nodes.
    for i := 0 to wayList.count - 1 do begin
      v := wayList.items[i].obj;
      ml := v.nodes;
      mlen := varArrayLength(ml);
      if mlen < 2 then continue; //skip zero- or one-node ways
      pwd.way.count := 0;
      setLength(pwd.way.items, mlen);
      pv := VarArrayLock(ml);
      try
        pwd.id0 := pv^;
        inc(wayMergeList.count);
        while (mlen > 0) do begin
          id := pv^;
          inc(pv);
          dec(mlen);
          varCopyNoInd(newObj, srcMap.getNode(id));
          if VarIsType(newObj, varDispatch) then
            putList(pwd^.way, newObj, i)
          else begin
            addNotResolved('node', id);
            result := false;
          end;
          if (mlen = 0) then begin //last node of way
            pwd.id1 := id;
            inc(pwd);
          end;
        end;
      finally
        varArrayUnlock(ml);
      end;
    end;
  end;

  function mergeWays(): boolean;

    function merge(pwd1, pwd2: PWayDescItem): boolean; //returns true if ways merged
      //merge & reorder ways.
      //Duplicates are not preserved (0,1,2)+(2,3,0)=>(0,1,2,3,0)

      procedure reverse(pwd: PWayDescItem);
      var
        id: int64;
        i0, i1: integer;
        pNode0, pNode1: PMultiPolyListItem;
        nodeTemp: array[0..sizeof(pNode0^) - 1] of byte;
      begin
        //swap id0 & id1
        id := pwd.id0;
        pwd.id0 := pwd.id1;
        pwd.id1 := id;
        //swap nodes
        i0 := 0;
        i1 := pwd.way.count - 1;
        pNode0 := @pwd.way.items[i0];
        pNode1 := @pwd.way.items[i1];
        while i0 < i1 do begin
          move(pNode0^, nodeTemp, sizeof(pNode0^));
          move(pNode1^, pNode0^, sizeof(pNode0^));
          move(nodeTemp, pNode1^, sizeof(pNode0^));
          inc(i0);
          inc(pNode0);
          dec(i1);
          dec(pNode1);
        end;
      end;

      procedure add(pwd1, pwd2: PWayDescItem);
      var
        startIdx, len, sz: integer;
      begin
        startIdx := pwd1.way.count - 1;
        pwd1.way.items[startIdx].obj := Unassigned;
        len := pwd2.way.count;
        pwd1.way.count := startIdx + len;
        setLength(pwd1.way.items, pwd1.way.count);
        pwd1.id1 := pwd2.id1;
        sz := len * sizeof(pwd2.way.items[0]);
        move(pwd2.way.items[0], pwd1.way.items[startIdx], sz);
        //prevent variant auto-finalization
        fillchar(pwd2.way.items[0], sz, 0);
        clearList(pwd2.way);
      end;

    var
      tempWayDesc: array[0..sizeof(pwd1^) - 1] of byte;
    begin
      result := true;
      if pwd1.id0 = pwd2.id0 then begin
        //new=reverse(old)+segment
        reverse(pwd1);
        add(pwd1, pwd2);
      end
      else if pwd1.id1 = pwd2.id0 then begin
        //new=old+segment
        add(pwd1, pwd2);
      end
      else if pwd1.id0 = pwd2.id1 then begin
        //new=segment+old
        add(pwd2, pwd1);
        //exchange description 1 & 2
        move(pwd1^, tempWayDesc, sizeof(pwd1^));
        move(pwd2^, pwd1^, sizeof(pwd1^));
        move(tempWayDesc, pwd2^, sizeof(pwd1^));
      end
      else if pwd1.id1 = pwd2.id1 then begin
        //new=old+reverse(segment)
        reverse(pwd2);
        add(pwd1, pwd2);
      end
      else
        result := false;
    end;

    procedure addNotClosed(aWay: TMultiPolyList);

      procedure addNode(n: TMultiPolyListItem);

        function getnoderole(n: TMultiPolyListItem): WideString;

          function getwayrole(n: TMultiPolyListItem): WideString;
          var
            id: int64;
          begin
            n := relationList.items[n.parentIdx];
            id := n.obj.id;
            result := 'relation:' + inttostr(id);
            if (n.parentIdx >= 0) then result := result + ';' + getwayrole(n);
          end;
        var
          id: int64;
        begin
          n := wayList.items[n.parentIdx];
          id := n.obj.id;
          result := 'way:' + inttostr(id);
          if (n.parentIdx >= 0) then result := result + ';' + getwayrole(n);
        end;
      begin
        fNotClosed.insertBefore(maxInt, 'node', n.obj.id, getnoderole(n));
      end;
    var
      n: TMultiPolyListItem;
    begin
      n := aWay.items[0];
      addNode(n);
      n := aWay.items[aWay.count - 1];
      addNode(n);
    end;
  var
    idx1, idx2: integer; //indexes of mergeing ways in wayMergeList
    pwd1, pwd2: PWayDescItem;
    doRepeat: boolean;
  begin
    repeat
      idx1 := 0;
      doRepeat := false;
      while idx1 < wayMergeList.count - 1 do begin
        pwd1 := @wayMergeList.items[idx1];
        if (pwd1.id0 <> pwd1.id1) then begin
          //pwd1 is not closed way (polygon)
          idx2 := idx1 + 1;
          while idx2 < wayMergeList.count do begin
            pwd2 := @wayMergeList.items[idx2];
            //try to merge
            if (pwd2.id0 <> pwd2.id1) and merge(pwd1, pwd2) then begin
              //new_pwd1 = pwd1 + pwd2
              pwd2^ := wayMergeList.items[wayMergeList.count - 1];
              dec(wayMergeList.count);
              doRepeat := true;
            end
            else begin
              //pwd1 and pwd2 not "mergeable", try next
              inc(idx2);
            end;
          end;
        end;
        inc(idx1);
      end;
    until not doRepeat;
    result := true;
    pwd1 := @wayMergeList.items[0];
    for idx1 := 0 to wayMergeList.count - 1 do begin
      if pwd1.id0 <> pwd1.id1 then begin
        result := false;
        addNotClosed(pwd1.way);
      end;
      inc(pwd1);
    end;
  end;

  procedure makeNodeList();
  var
    sz, i, j: integer;
    pli: PMultiPolyListItem;
    pWDI: PWayDescItem;
    sPoly: TGTPoly;
  begin
    sz := 0;
    setLength(simplePolyList, wayMergeList.count);
    for i := 0 to wayMergeList.count - 1 do begin
      pWDI := @wayMergeList.items[i];
      inc(sz, pWDI.way.count);
      sPoly := TGTPoly.create();
      simplePolyList[i] := sPoly;
      sPoly.capacity := pWDI.way.count;
      for j := 0 to pWDI.way.count - 1 do begin
        sPoly.addNode(pWDI.way.items[j].obj);
      end;
    end;
    setLength(nodeList.items, sz);
    nodeList.count := 0;
    for i := 0 to wayMergeList.count - 1 do begin
      pli := @wayMergeList.items[i].way.items[0];
      for j := 0 to wayMergeList.items[i].way.count - 1 do begin
        putList(nodeList, pli^.obj, pli^.parentIdx);
        inc(pli);
      end;
      clearList(wayMergeList.items[i].way);
    end;
  end;

  procedure InitErrorLists();
  var
    v: OleVariant;
  begin
    createNotResolved();
    v := VarArrayCreate([0, -1], varVariant);
    fNotResolved.setAll(v);
    createNotClosed();
    fNotClosed.setAll(v);
  end;

begin
  clearInternalLists();
  InitErrorLists();
  //sort objects from srcList: put relations into relationList,
  // put ways into wayList
  sortSrcObjByType();
  //resolve relationList members into child relations (fully recurcive) and
  // ways. Child relations are stored in relationList, ways are stored in
  // wayList.
  //WARNING: relations with 'type=collection' are skipped.
  //result = all relations and ways found in Map.
  // if result==false see getNotResolved() for not-found object list
  result := resolveRelations();
  if not result then
    exit;
  //resolve ways(node-ids) from wayList into nodes(Node objects) and store
  // nodes in wayMergeList 2-D array
  //result==all nodes found in Map
  // if result==false see getNotResolved() for not-found object list
  result := resolveWays();
  if not result then
    exit;
  //merge ways & nodes in wayMergeList into polygons.
  //result==all non-closed ways are merged into one or more polygons.
  // if result==false see getNotClosed() for not-closed nodes & ways
  result := mergeWays(); //do not merge ways if some nodes not resolved!
  if not result then
    exit;
  //initialize simplePolyList and fill NodeList.
  makeNodeList();
  //split large polygons into small if needed and fill optimizedPolyList with
  // small ones. optimizedPolyList used for faster IsIn tests
  buildOptimizedPolyList();
  //build hash-grid for fast point-to-polygon_list translation
  buildOptimizedPolyHash();
end;

function TMultiPoly.isAllResolved: boolean;
begin
  result := nodeList.count > 0;
end;

procedure TMultiPoly.buildOptimizedPolyList();
var
  pCnt: integer;

  procedure split(pgIdx: integer);
  var
    pl: TGTPoly;
  begin
    pl := optimizedPolyList[pgIdx];
    if pl.width > pl.height then
      optimizedPolyList[pCnt] := pl.splitX(pl.left + integer(pl.width shr 1))
    else
      optimizedPolyList[pCnt] := pl.splitY(pl.bottom + integer(pl.height shr 1));
    if assigned(optimizedPolyList[pCnt]) then begin
      optimizedPolyParent[pCnt] := optimizedPolyParent[pgIdx];
      inc(pCnt);
    end;
  end;

var
  nCnt, nOpt, maxCnt, maxIdx, i, maxSplitCnt: integer;
begin
  nCnt := 0;
  for i := 0 to high(simplePolyList) do begin
    inc(nCnt, simplePolyList[i].count);
  end;
  nOpt := round(sqrt(nCnt));
  pCnt := length(simplePolyList);
  if (nOpt < pCnt) or (nCnt < 100) then
    nOpt := pCnt;
  setLength(optimizedPolyList, nOpt);
  setLength(optimizedPolyParent, nOpt);
  for i := 0 to pCnt - 1 do begin
    optimizedPolyList[i] := simplePolyList[i].clone() as TGTPoly;
    optimizedPolyParent[i] := i;
  end;
  if (nOpt = pCnt) then
    //no optimization needed
    exit;
  maxSplitCnt := nOpt * 2; //prevent infinite loop on "non-splittable" poly
  while (pCnt < nOpt) and (maxSplitCnt > 0) do begin
    maxCnt := 0;
    maxIdx := 0;
    for i := 0 to pCnt - 1 do begin
      if maxCnt < optimizedPolyList[i].count then begin
        maxCnt := optimizedPolyList[i].count;
        maxIdx := i;
      end;
    end;
    split(maxIdx);
    dec(maxSplitCnt);
  end;
end;

procedure TMultiPoly.buildOptimizedPolyHash;

  procedure putPoly(const x, y, p: cardinal);
  var
    l: integer;
  begin
    if cardinal(length(optimizedPolyHash[x])) <= y then
      setLength(optimizedPolyHash[x], y + 1);
    l := length(optimizedPolyHash[x][y]);
    setLength(optimizedPolyHash[x][y], l + 1);
    optimizedPolyHash[x][y][l] := p;
  end;
var
  xidx, yidx, polyidx: integer;
  poly: TGTPoly;
  xminhash, xmaxhash, yminhash, ymaxhash: cardinal;
begin
  //hash clean up
  setLength(optimizedPolyHash, 0);
  setLength(optimizedPolyHash, hashSize);
  for polyidx := 0 to high(optimizedPolyList) do begin
    poly := optimizedPolyList[polyidx];
    xminhash := intToHash(poly.left);
    xmaxhash := intToHash(poly.right);
    yminhash := intToHash(poly.bottom);
    ymaxhash := intToHash(poly.top);
    for xidx := xminhash to xmaxhash do begin
      for yidx := yminhash to ymaxhash do begin
        putPoly(xidx, yidx, polyidx);
      end;
    end;
  end;
end;

class function TMultiPoly.intToHash(i: integer): cardinal;
begin
  i := i div (1 shl (32 - hashBits));
  inc(i, hashSize div 2);
  result := cardinal(i);
end;

function TMultiPoly.getLineIntersection(const aMap,
  aNodeArray: OleVariant; newNodeId: int64): OleVariant;

type
  PWayNodeDesc = ^TWayNodeDesc;

  TWayNodeDesc = record
    node: OleVariant;
    point: TGTPoint;
    bRect: TGTRect;
    pNextNode: PWayNodeDesc;
    isIn: Shortint;
  end;

  TWayNodeDescArray = array of TWayNodeDesc;

var
  waySegList: array of PWayNodeDesc;
  waySegLength: array of integer;
  iWaySeg: integer;

  procedure includeSegment(pWND1: PWayNodeDesc);
    //segment = (pWND1.point, pWND1.pNextNode.point)
  var
    pWND: PWayNodeDesc;
  begin
    pWND := waySegList[iWaySeg];
    if not assigned(pWND) then begin
      //new empty segment
      //add first node
      new(pWND);
      pWND^ := pWND1^;
      waySegList[iWaySeg] := pWND;
      pWND.pNextNode := pWND;
      //add second node
      new(pWND);
      pWND^ := pWND1.pNextNode^;
      pWND.pNextNode := waySegList[iWaySeg].pNextNode;
      waySegList[iWaySeg].pNextNode := pWND;
      waySegList[iWaySeg] := pWND;
      waySegLength[iWaySeg] := 2;
    end
    else if (pWND.point = pWND1.point) then begin
      //append next point - (n1,n2)+(n2,n3)=>(n1,n2,n3)
      pWND1 := pWND1.pNextNode;
      new(pWND);
      pWND^ := pWND1^;
      pWND.pNextNode := waySegList[iWaySeg].pNextNode;
      waySegList[iWaySeg].pNextNode := pWND;
      waySegList[iWaySeg] := pWND;
      inc(waySegLength[iWaySeg]);
    end
    else begin
      //start new segment
      inc(iWaySeg);
      if (iWaySeg > high(waySegList)) then begin
        setLength(waySegList, iWaySeg + 4);
        setLength(waySegLength, iWaySeg + 4);
      end;
      includeSegment(pWND1);
    end;
  end;

  procedure freeWaySeg();
  var
    i: integer;
    pWND, pWND1, pWND2: PWayNodeDesc;
  begin
    for i := 0 to iWaySeg do begin
      pWND2 := waySegList[i];
      if not assigned(pWND2) then continue;
      pWND := pWND2.pNextNode;
      while (pWND <> pWND2) do begin
        pWND1 := pWND.pNextNode;
        dispose(pWND);
        pWND := pWND1;
      end;
      dispose(pWND);
      iWaySeg := 0;
    end;
  end;

  function makeResult(): OleVariant;
  var
    i, j: integer;
    ws: OleVariant;
    pv: POleVariant;
    pWND, pWND1: PWayNodeDesc;
  begin
    if (iWaySeg = 0) and (not assigned(waySegList[0])) then
      dec(iWaySeg);
    result := VarArrayCreate([0, iWaySeg], varVariant);
    for i := 0 to iWaySeg do begin
      j := waySegLength[i];
      ws := VarArrayCreate([0, j - 1], varVariant);
      pWND := waySegList[i];
      pWND1 := pWND.pNextNode;
      pv := VarArrayLock(ws);
      try
        while j > 0 do begin
          if VarIsEmpty(pWND1.node) then begin
            pv^ := aMap.createNode();
            pv^.lat := pWND1.point.lat;
            pv^.lon := pWND1.point.lon;
            pv^.id := newNodeId;
            dec(newNodeId);
          end
          else begin
            pv^ := pWND1.node;
          end;
          if (pWND1.isIn = 1) and (
            (pWND1 = pWND) {last segment node} or
            (pWND1 = pWND.pNextNode) {first segment node}
            ) then begin
            pv^.tags.setByKey('osman:note', 'boundary');
          end;
          pWND1 := pWND1.pNextNode;
          inc(pv);
          dec(j);
        end;
      finally
        varArrayUnlock(ws);
      end;
      result[i] := ws;
    end;
  end;

  procedure markNode(const pN: PWayNodeDesc; const isInState: Shortint);
  begin
    if pN.isIn < isInState then pN.isIn := isInState;
  end;

var
  prevIsIn: Shortint;
  simplePolyIdx, polySegmentIdx, i, nWayNodes: integer;
  p1, p2, i0: TGTPoint;
  polyPoints: TGTPointArray;
  wayPoints, pWND, pWND2: PWayNodeDesc;
  wayBRect, polySegmentBRect: TGTRect;
  v: OleVariant;
begin
  polyPoints := nil;
  nWayNodes := varArrayLength(aNodeArray);
  result := VarArrayCreate([0, -1], varVariant);
  if (nWayNodes < 2) then begin
    exit;
  end;
  //init subroutine data
  setLength(waySegList, 4);
  setLength(waySegLength, 4);
  iWaySeg := 0;
  //end init
  polySegmentBRect := nil;
  wayBRect := TGTRect.create();
  wayPoints := nil;
  i0 := nil;
  try
    polySegmentBRect := TGTRect.create();
    for i := nWayNodes - 1 downto 0 do begin
      new(pWND);
      fillchar(pWND^, sizeof(pWND^), 0);
      pWND.pNextNode := wayPoints;
      wayPoints := pWND;
      p1 := TGTPoint.create();
      wayPoints.point := p1;
      v := aNodeArray[i];
      p1.assignNode(v);
      wayPoints.node := v;
      wayPoints.isIn := -1;
      wayBRect.updateBoundRect(p1);
      //first segment index is 1!
      if (assigned(wayPoints.pNextNode)) then with wayPoints.pNextNode^ do begin
          bRect := TGTRect.create();
          bRect.updateBoundRect(wayPoints.point);
          bRect.updateBoundRect(point);
        end;
    end;
    for simplePolyIdx := 0 to high(simplePolyList) do begin
      if not wayBRect.canInterserts(simplePolyList[simplePolyIdx]) or
        (simplePolyList[simplePolyIdx].count < 3) then
        continue;
      polyPoints := simplePolyList[simplePolyIdx].fPoints;
      p2 := polyPoints[0];
      for polySegmentIdx := 1 to simplePolyList[simplePolyIdx].count - 1 do begin
        p1 := p2;
        p2 := polyPoints[polySegmentIdx];
        polySegmentBRect.resetBounds();
        polySegmentBRect.updateBoundRect(p1);
        polySegmentBRect.updateBoundRect(p2);
        if not wayBRect.canInterserts(polySegmentBRect) then
          continue;
        pWND := wayPoints;
        while assigned(pWND) do begin
          pWND2 := pWND;
          pWND := pWND.pNextNode;
          if not (assigned(pWND) and polySegmentBRect.canInterserts(pWND.bRect)) then
            continue;
          //find and store intersection point
          i0 := getSegmentIntersection(p1, p2, pWND2.point, pWND.point);
          if assigned(i0) then begin
            //test for distance and store point between pWND2 and pWND
            if (i0.distTest(pWND2.point, minPtDist)) then begin
              markNode(pWND2, 1);
              freeAndNil(i0);
            end
            else if (i0.distTest(pWND.point, minPtDist)) then begin
              markNode(pWND, 1);
              freeAndNil(i0);
            end
            else begin
              new(pWND2.pNextNode);
              fillchar(pWND2.pNextNode^, sizeof(pWND^), 0);
              with pWND2.pNextNode^ do begin
                pNextNode := pWND;
                node := Unassigned;
                point := i0;
                i0 := nil;
                bRect := TGTRect.create();
                isIn := 1; //new node, so we can mark it directly
                bRect.updateBoundRect(pWND2.point);
                bRect.updateBoundRect(point);
                pWND.bRect.resetBounds();
                pWND.bRect.updateBoundRect(point);
                pWND.bRect.updateBoundRect(pWND.point);
              end;
              pWND := pWND2.pNextNode;
            end;
          end;
        end;
      end;
    end;
    //now wayPoints contains new way segments
    //test segments if they is in or is out of boundary
    pWND := wayPoints;
    prevIsIn := -1;
    while assigned(pWND) do begin
      if (pWND.isIn = -1) then begin
        case prevIsIn of
          -1, 1:
            pWND.isIn := isInInt(pWND.point); //pWND.isIn==-1, so mark it directly
          //all boundary points marked with IsIn=1, so pWND can not be on-bound
          0, 2: pWND.isIn := prevIsIn; //pWND.isIn==-1, so mark it directly
        else
          raise EIntOverflow.create(toString() + '.getIntersection: invalid isin=' +
            inttostr(prevIsIn));
        end;
      end;
      prevIsIn := pWND.isIn;
      pWND := pWND.pNextNode;
    end;
    pWND := wayPoints;
    pWND2 := pWND.pNextNode;
    while assigned(pWND2) do begin
      i := pWND.isIn * 4 + pWND2.isIn;
      case i of
        0, 1, 4 {'out-bound' segment}: {do not include this segment};
        5 {'bound-bound' segments}: begin
            if not assigned(i0) then
              i0 := TGTPoint.create();
            i0.x := (pWND.point.x div 2) + (pWND2.point.x div 2);
            i0.y := (pWND.point.y div 2) + (pWND2.point.y div 2);
            if isInInt(i0) > 0 then
              includeSegment(pWND);
          end;
        6, 9, 10 {'bound-in' or 'in-in' segments}: includeSegment(pWND);
      else
        //2, 8, {'out-in' - get a bug???}
        raise EIntOverflow.create(toString() + '.getIntersection: invalid case=' + inttostr(i));
      end;
      pWND := pWND2;
      pWND2 := pWND2.pNextNode;
    end;
    result := makeResult();
  finally
    freeAndNil(wayBRect);
    freeAndNil(polySegmentBRect);
    freeAndNil(i0);
    pWND := wayPoints;
    while assigned(pWND) do begin
      wayPoints := pWND;
      pWND := pWND.pNextNode;
      freeAndNil(wayPoints.point);
      freeAndNil(wayPoints.bRect);
      dispose(wayPoints);
    end;
    freeWaySeg();
  end;
end;

function TMultiPoly.isInInt(const pt: TGTPoint): integer;
var
  xhash, yhash: cardinal;
  i: integer;
  p: TGTPoly;
  oplen: integer;
  popi: pinteger;
begin
  result := 0;
  xhash := intToHash(pt.fx);
  yhash := intToHash(pt.fy);
  if cardinal(length(optimizedPolyHash[xhash])) <= yhash then
    exit;
  oplen := length(optimizedPolyHash[xhash][yhash]);
  popi := @optimizedPolyHash[xhash][yhash][0];
  for i := 0 to oplen - 1 do begin
    p := optimizedPolyList[popi^];
    case p.isIn(pt) of
      0: ;
      1: begin
          //on optimized boundary. We need test 'original' poly.
          p := simplePolyList[optimizedPolyParent[popi^]];
          case p.isIn(pt) of
            0: ;
            1: begin
                result := 1;
                break;
              end;
            2: begin
                result := 2 - result;
              end;
          end;
        end;
      2: result := 2 - result;
    end;
    inc(popi);
  end;
end;

function TMultiPoly.getIntersection(const aMap,
  anObj: OleVariant; newNodeId: int64): OleVariant;
var
  cvtObj: OleVariant;
  l: integer;
begin
  if not isAllResolved() then
    if not resolve(aMap) then
      raise EConvertError.create(toString() +
        '.getIntersection: not all references resolved or polygons closed.');
  cvtObj := varFromJsObject(anObj);
  if (VarIsType(cvtObj, varVariant or varArray)) and (VarArrayDimCount(cvtObj) = 1) then begin
    l := varArrayLength(cvtObj);
    if (l < 3) or (cvtObj[0].id <> cvtObj[l - 1].id) then
      result := getLineIntersection(aMap, cvtObj, newNodeId)
    else
      result := getPolyIntersection(aMap, cvtObj, newNodeId)
  end
  else
    raise EConvertError.create(toString() + '.getIntersection: invalid nodeArray');
end;

function TMultiPoly.getPolyIntersection(const aMap,
  aNodeArray: OleVariant; newNodeId: int64): OleVariant;
type
  TSegFlags = set of (sfOnBound1, sfOnBound2, sfVisited);
  TSegDesc = record
    pNode1, pNode2: POleVariant;
    pPoint1, pPoint2: TGTPoint;
    bbox: TGTRect;
    flags: TSegFlags;
  end;
  PSegDesc = ^TSegDesc;

  TIsInTestProc = function(const pt: TGTPoint): integer of object;

var
  newNodeCount: integer;
  newNodes: array of OleVariant;
  newPoints: array of TGTPoint;

  procedure freeAndNilSeg(var pSeg: PSegDesc);
  begin
    if not assigned(pSeg) then
      exit;
    freeAndNil(pSeg.bbox);
    dispose(pSeg);
    pSeg := nil;
  end;

  procedure freeAndNilSegList(var sl: TDualLinkedRing);
  var
    p: PSegDesc;
  begin
    if not assigned(sl) then
      exit;
    while not sl.isEmpty() do begin
      p := sl.delete();
      freeAndNilSeg(p);
    end;
    freeAndNil(sl);
  end;

  function sortSeg(pNodeVar: POleVariant; iNodeVarStep: integer; polyA: TGTPoly; bboxB: TGTRect):
      TDualLinkedRing;
  var
    i, l: integer;
    p: PSegDesc;
  begin
    i := 0;
    p := nil;
    l := polyA.count - 1;
    result := TDualLinkedRing.create();
    try
      while i < l do begin
        if not assigned(p) then begin
          new(p);
          p.bbox := TGTRect.create();
        end
        else
          p.bbox.resetBounds();
        p.pNode1 := pNodeVar;
        p.pPoint1 := polyA.fPoints[i];
        inc(pbyte(pNodeVar), iNodeVarStep);
        inc(i);
        p.pNode2 := pNodeVar;
        p.pPoint2 := polyA.fPoints[i];
        p.bbox.updateBoundRect(p.pPoint1);
        p.bbox.updateBoundRect(p.pPoint2);
        p.flags := [];
        if bboxB.canInterserts(p.bbox) then begin
          result.insertAfter(p);
          if result.hasNext() then
            result.next();
          p := nil;
        end;
      end;
      if not result.isEmpty() then
        result.first();
    except
      freeAndNilSeg(p);
      freeAndNilSegList(result);
      raise;
    end;
  end;

  procedure splitAndStore(segList: TDualLinkedRing; pMidNode: POleVariant; pMidPoint: TGTPoint);
  var
    pSeg1, pSeg2: PSegDesc;
  begin
    pSeg1 := segList.data;
    //create segment2
    new(pSeg2);
    //copy point2
    pSeg2.pPoint2 := pSeg1.pPoint2;
    pSeg2.pNode2 := pSeg1.pNode2;
    //create point1 in segment2
    pSeg2.pPoint1 := pMidPoint;
    pSeg2.pNode1 := pMidNode;
    //init bbox in segment2
    pSeg2.bbox := TGTRect.create();
    pSeg2.bbox.updateBoundRect(pMidPoint);
    pSeg2.bbox.updateBoundRect(pSeg1.pPoint2);
    //init flags in segment2
    pSeg2.flags := pSeg1.flags;
    include(pSeg2.flags, sfOnBound1);
    //store segment2
    segList.insertAfter(pSeg2);
    //adjust segment1
    //create point2
    pSeg1.pPoint2 := pMidPoint;
    pSeg1.pNode2 := pMidNode;
    //update bbox
    pSeg1.bbox.resetBounds();
    pSeg1.bbox.updateBoundRect(pSeg1.pPoint1);
    pSeg1.bbox.updateBoundRect(pMidPoint);
    //adjust flags
    include(pSeg1.flags, sfOnBound2);
  end;

  procedure createNewPoint(var pNewNode: POleVariant; var pNewPoint, crossPt: TGTPoint);
  begin
    if length(newNodes) <= newNodeCount then begin
      setLength(newNodes, newNodeCount * 2 + 4);
      setLength(newPoints, newNodeCount * 2 + 4);
    end;

    newNodes[newNodeCount] := aMap.createNode();
    pNewNode := @newNodes[newNodeCount];
    pNewNode^.id := newNodeId;
    pNewNode^.lat := crossPt.lat;
    pNewNode^.lon := crossPt.lon;
    newPoints[newNodeCount] := crossPt;
    pNewPoint := crossPt;

    dec(newNodeId);
    inc(newNodeCount);
    crossPt := nil;
  end;

  procedure splitSegments(slA, slB: TDualLinkedRing);
  var
    pSegB, pSegA: PSegDesc;
    crossPt, pNewPoint: TGTPoint;
    pNewNode: POleVariant;
    doSplitA, doSplitB: boolean;
  begin
    crossPt := nil;
    try
      pSegB := slB.first();
      while assigned(pSegB) do begin
        pSegA := slA.first();
        while assigned(pSegA) and assigned(pSegB) do begin
          if not pSegA.bbox.canInterserts(pSegB.bbox) then begin
            if (slA.hasNext()) then
              pSegA := slA.next()
            else
              pSegA := nil;
            continue;
          end;
          crossPt := getSegmentIntersection(pSegA.pPoint1, pSegA.pPoint2, pSegB.pPoint1,
            pSegB.pPoint2);
          if assigned(crossPt) then begin
            pNewNode := nil;
            pNewPoint := nil;
            //test distance between cross-point and SegB end-points
            doSplitB := true;
            if (crossPt.distTest(pSegB.pPoint1, minPtDist)) then begin
              include(pSegB.flags, sfOnBound1);
              doSplitB := false;
              pNewNode := pSegB.pNode1;
              pNewPoint := pSegB.pPoint1;
            end
            else if (crossPt.distTest(pSegB.pPoint2, minPtDist)) then begin
              include(pSegB.flags, sfOnBound2);
              doSplitB := false;
              pNewNode := pSegB.pNode2;
              pNewPoint := pSegB.pPoint2;
            end;

            //test distance between cross-point and segA end-points
            doSplitA := true;
            if (crossPt.distTest(pSegA.pPoint1, minPtDist)) then begin
              include(pSegA.flags, sfOnBound1);
              doSplitA := false;
              if not assigned(pNewNode) then begin
                pNewNode := pSegA.pNode1;
                pNewPoint := pSegA.pPoint1;
              end
              else begin
                pSegA.pNode1 := pNewNode;
                pSegA.pPoint1 := pNewPoint;
              end;
            end
            else if (crossPt.distTest(pSegA.pPoint2, minPtDist)) then begin
              include(pSegA.flags, sfOnBound2);
              doSplitA := false;
              if not assigned(pNewNode) then begin
                pNewNode := pSegA.pNode2;
                pNewPoint := pSegA.pPoint2;
              end
              else begin
                pSegA.pNode2 := pNewNode;
                pSegA.pPoint2 := pNewPoint;
              end;
            end;

            if not assigned(pNewNode) then begin
              createNewPoint(pNewNode, pNewPoint, crossPt);
            end;
            if doSplitA then begin
              splitAndStore(slA, pNewNode, pNewPoint);
              pSegA := nil; //check pSegA agane
            end;
            if doSplitB then
              splitAndStore(slB, pNewNode, pNewPoint);
            if not (doSplitA or doSplitB) then begin
              if ((pSegA.pNode1^.id = pSegB.pNode1^.id) and
                (pSegA.pNode2^.id = pSegB.pNode2^.id)) or
                ((pSegA.pNode1^.id = pSegB.pNode2^.id) and
                (pSegA.pNode2^.id = pSegB.pNode1^.id)) then begin
                //pSegA and pSegB is same
                //mark segment as it was visited and marked in buildIntersection
                pSegB.flags := pSegB.flags - [sfOnBound1, sfOnBound2] + [sfVisited];
                freeAndNilSeg(pSegA);
                slA.delete();
              end;
            end;
          end;
          freeAndNil(crossPt);
          if assigned(pSegA) then begin
            if slA.hasNext() then
              pSegA := slA.next()
            else
              pSegA := nil;
          end
          else
            pSegA := slA.data;
        end;
        if assigned(pSegB) then begin
          if slB.hasNext() then
            pSegB := slB.next()
          else
            pSegB := nil;
        end
        else if slB.isEmpty() then
          pSegB := nil
        else
          pSegB := slB.data;
      end;
    finally
      freeAndNil(crossPt);
    end;
  end;

  function buildIntersection(slA, slB: TDualLinkedRing; polyA: TGTPoly): TDualLinkedRing;

    procedure reverseSeg(pSeg: PSegDesc);
    var
      v: POleVariant;
      p: TGTPoint;
      f: TSegFlags;
    begin
      v := pSeg.pNode1;
      pSeg.pNode1 := pSeg.pNode2;
      pSeg.pNode2 := v;
      p := pSeg.pPoint1;
      pSeg.pPoint1 := pSeg.pPoint2;
      pSeg.pPoint2 := p;
      f := pSeg.flags;
      if (sfOnBound1 in f) then
        include(pSeg.flags, sfOnBound2)
      else
        exclude(pSeg.flags, sfOnBound2);
      if (sfOnBound2 in f) then
        include(pSeg.flags, sfOnBound1)
      else
        exclude(pSeg.flags, sfOnBound1);
    end;

    procedure buildPolygon(r: TDualLinkedRing);
    var
      curList, resList: TDualLinkedRing;
      curTest, resTest: TIsInTestProc;
      pSeg: PSegDesc;

      procedure swapLists();
      var
        tmpList: TDualLinkedRing;
        tmpTest: TIsInTestProc;
      begin
        tmpList := curList;
        curList := resList;
        resList := tmpList;
        tmpTest := curTest;
        curTest := resTest;
        resTest := tmpTest;
      end;

      procedure deleteSeg();
      begin
        assert(pSeg = curList.data, '{5F0D288C-F5F7-485C-BB60-14C3B4F88D69}');
        freeAndNilSeg(pSeg);
        curList.delete();
      end;
    var
      firstId, lastId, i641, i642: int64;
      pt: TGTPoint;
      bm: pointer;
      i: integer;
    begin
      pt := nil;
      curList := slA;
      resList := slB;
      curTest := isInInt;
      resTest := polyA.isIn;
      pSeg := curList.data;
      firstId := pSeg.pNode1^.id;
      lastId := pSeg.pNode2^.id;
      r.insertAfter(pSeg);
      r.next();
      curList.delete();
      try
        while firstId <> lastId do begin
          if curList.isEmpty() then
            swapLists();
          assert(not curList.isEmpty(), '{0A55EB07-09F5-401C-A312-9DC6E573B28C}');
          pSeg := curList.data;
          if not (sfVisited in pSeg.flags) then begin
            i := ord(sfOnBound1 in pSeg.flags) + 2 * ord(sfOnBound2 in pSeg.flags);
            case i of
              0, 2:
                case curTest(pSeg.pPoint1) of
                  0: deleteSeg();
                  1: assert(false, '{1646E1B7-E4DB-4DF0-BCDD-B4D95D344818}');
                  2: include(pSeg.flags, sfVisited);
                end;
              1:
                case curTest(pSeg.pPoint2) of
                  0: deleteSeg();
                  1: assert(false, '{1646E1B7-E4DB-4DF0-BCDD-B4D95D344818}');
                  2: include(pSeg.flags, sfVisited);
                end;
              3: begin
                  if not assigned(pt) then
                    pt := TGTPoint.create();
                  pt.x := (pSeg.pPoint1.x div 2) + (pSeg.pPoint2.x div 2);
                  pt.y := (pSeg.pPoint1.y div 2) + (pSeg.pPoint2.y div 2);
                  if curTest(pt) = 0 then
                    deleteSeg()
                  else
                    include(pSeg.flags, sfVisited);
                end;
            end;
          end;
          if not assigned(pSeg) then
            continue;
          i641 := pSeg.pNode1^.id;
          i642 := pSeg.pNode2^.id;
          if (i641 = lastId) then begin
            r.insertAfter(pSeg);
            r.next();
            curList.delete();
            lastId := i642;
          end
          else if (i642 = lastId) then begin
            reverseSeg(pSeg);
            r.insertAfter(pSeg);
            r.next();
            curList.delete();
            if not curList.isEmpty() then
              curList.prev();
            lastId := i641;
          end
          else begin
            bm := curList.bookmark;
            repeat
              pSeg := curList.next();
              if not (sfVisited in pSeg.flags) then
                break;
              i641 := pSeg.pNode1^.id;
              i642 := pSeg.pNode2^.id;
            until (bm = curList.bookmark) or (i641 = lastId) or (i642 = lastId);
            if bm = curList.bookmark then
              swapLists();
          end;
        end;
      finally
        freeAndNil(pt);
      end;
    end;
  var
    pSeg: PSegDesc;
    pt: TGTPoint;
  begin
    result := TDualLinkedRing.create();
    slA.first();
    while not slA.isEmpty() do begin
      pSeg := slA.data;
      if ((not (sfOnBound1 in pSeg.flags)) and (isInInt(pSeg.pPoint1) = 2)) or
        ((not (sfOnBound2 in pSeg.flags)) and (isInInt(pSeg.pPoint2) = 2)) then begin
        //segment A is in B
        buildPolygon(result);
        continue;
      end;
      if (sfOnBound1 in pSeg.flags) and (sfOnBound2 in pSeg.flags) then begin
        pt := TGTPoint.create();
        pt.x := (pSeg.pPoint1.x div 2) + (pSeg.pPoint2.x div 2);
        pt.y := (pSeg.pPoint1.y div 2) + (pSeg.pPoint2.y div 2);
        if isInInt(pt) > 0 then
          buildPolygon(result);
        freeAndNil(pt);
        continue;
      end;
      freeAndNilSeg(pSeg);
      slA.delete();
    end;
  end;

  function buildResult(sl: TDualLinkedRing): OleVariant;
  var
    firstId, lastId: int64;
    nPolyNodes, nPolygons: integer;
    varArrPoly: OleVariant;
    pv: POleVariant;
    pSeg: PSegDesc;
  begin
    result := VarArrayCreate([0, -1], varVariant);
    pSeg := sl.first();
    nPolygons := 0;
    while assigned(pSeg) do begin
      firstId := pSeg.pNode1^.id;
      lastId := pSeg.pNode2^.id;
      nPolyNodes := 2;
      while firstId <> lastId do begin
        pSeg := sl.next();
        lastId := pSeg.pNode2^.id;
        inc(nPolyNodes);
      end;
      varArrPoly := VarArrayCreate([0, nPolyNodes - 1], varVariant);
      pv := VarArrayLock(varArrPoly);
      inc(pv, nPolyNodes - 1);
      firstId := pSeg.pNode1^.id;
      pv^ := pSeg.pNode2^;
      if (sfOnBound2 in pSeg.flags) then
        pv^.tags.setByKey('osman:note', 'boundary');
      while firstId <> lastId do begin
        dec(pv);
        pSeg := sl.delete();
        if not sl.isEmpty() then
          sl.prev();
        pv^ := pSeg.pNode1^;
        if (sfOnBound1 in pSeg.flags) then
          pv^.tags.setByKey('osman:note', 'boundary');
        firstId := pv^.id;
      end;

      if not (sl.isEmpty()) then
        pSeg := sl.next()
      else
        pSeg := nil;
      varArrayUnlock(varArrPoly);
      inc(nPolygons);
      VarArrayRedim(result, nPolygons - 1);
      result[nPolygons - 1] := varArrPoly;
    end;
  end;

var
  polyA: TGTPoly;
  bboxB: TGTRect;
  crossPt: TGTPoint;
  i, k, nWayNodes: integer;
  pNodeVar: POleVariant;
  bboxVar: OleVariant;
  segListA, segListB, segListR, tmpList: TDualLinkedRing;
begin
  result := VarArrayCreate([0, -1], varVariant);
  nWayNodes := varArrayLength(aNodeArray);
  if (aNodeArray[0].id <> aNodeArray[nWayNodes - 1].id) then
    raise EConvertError.create(toString() + '.getPolyIntersection: node array is not closed.');
  pNodeVar := nil;
  bboxB := nil;
  crossPt := nil;
  segListA := nil;
  segListB := nil;
  segListR := nil;
  newNodeCount := 0;
  polyA := TGTPoly.create();
  try
    pNodeVar := VarArrayLock(aNodeArray);
    for i := 0 to nWayNodes - 1 do begin
      polyA.addNode(pNodeVar^);
      inc(pNodeVar);
    end;
    bboxVar := getBBox(); //[n,e,s,w] in deg
    bboxB := TGTRect.create();
    bboxB.top := degToInt(bboxVar[0]);
    bboxB.right := degToInt(bboxVar[1]);
    bboxB.bottom := degToInt(bboxVar[2]);
    bboxB.left := degToInt(bboxVar[3]);
    if not polyA.canInterserts(bboxB) then
      exit;
    //check (segments from A) and (boundbox(B))
    dec(pNodeVar, nWayNodes);
    segListA := sortSeg(pNodeVar, sizeof(pNodeVar^), polyA, bboxB);
    if segListA.isEmpty() then
      exit;
    //check (segments from B) and (boundbox(A))
    k := 0;
    segListB := TDualLinkedRing.create();
    for i := 0 to high(simplePolyList) do begin
      tmpList := sortSeg(@nodeList.items[k].obj, sizeof(nodeList.items[0]), simplePolyList[i],
        polyA);
      segListB.appendBefore(tmpList);
      inc(k, simplePolyList[i].count);
    end;
    splitSegments(segListA, segListB);

    segListR := buildIntersection(segListA, segListB, polyA);

    if not (segListR.isEmpty()) then
      result := buildResult(segListR);
  finally
    freeAndNilSegList(segListA);
    freeAndNilSegList(segListB);
    freeAndNilSegList(segListR);
    freeAndNil(polyA);
    freeAndNil(bboxB);
    freeAndNil(crossPt);
    if (assigned(pNodeVar)) then
      varArrayUnlock(aNodeArray);
    for i := 0 to newNodeCount - 1 do begin
      freeAndNil(newPoints[i]);
    end;
  end;
end;

class function TMultiPoly.getSegmentIntersection(const pt1, pt2, ptA,
  ptB: TGTPoint): TGTPoint;
var
  dx21, dxba, dy21, dyba, dx1a, dy1a, sa2b1, k, t: double;
begin
  result := nil;
  dx21 := pt2.x - pt1.x;
  dy21 := pt2.y - pt1.y;
  dxba := ptB.x - ptA.x;
  dyba := ptB.y - ptA.y;
  dx1a := pt1.x - ptA.x;
  dy1a := pt1.y - ptA.y;
  sa2b1 := dyba * dx21 - dxba * dy21;
  if sa2b1 <> 0 then begin
    sa2b1 := 1 / sa2b1;
    k := (dxba * dy1a - dyba * dx1a) * sa2b1;
    t := (dx21 * dy1a - dy21 * dx1a) * sa2b1;
    if (k >= 0) and (k <= 1) and (t >= 0) and (t <= 1) then begin
      result := TGTPoint.create();
      result.x := pt1.x + round(k * dx21);
      result.y := pt1.y + round(k * dy21);
    end;
  end
  else begin
    //parallel segments
    k := (dxba * dy1a - dyba * dx1a);
    if (k = 0) then begin
      //segments are on one line
      dxba := abs(dxba);
      dyba := abs(dyba);
      if (dxba = (abs(ptB.x - pt1.x) + abs(dx1a))) and
        (dyba = (abs(ptB.y - pt1.y) + abs(dy1a))) then
        //l(ba)==l(b1)+l(1a) => 1
        result := pt1
      else if (dxba = (abs(ptB.x - pt2.x) + abs(pt2.x - ptA.x))) and
        (dyba = (abs(ptB.y - pt2.y) + abs(pt2.y - ptA.y))) then
        //l(ba)==l(b2)+l(2a) => 2
        result := pt2
      else if (abs(dx21) = (abs(pt2.x - ptA.x) + abs(ptA.x - pt1.x))) and
        (abs(dy21) = (abs(pt2.y - ptA.y) + abs(ptA.y - pt1.y))) then
        //l(21)==l(2a)+l(a1) => a
        result := ptA;
      if assigned(result) then
        result := TGTPoint(result.clone());
    end;
  end;
end;
{
procedure test();
var
p1,p2:TGTPoint;
d,md:double;
i64:int64;
i,mi:integer;
begin
p1:=TGTPoint.Create();
p2:=TGTPoint.Create();
p1.lat:=45;
p1.lon:=46;
p2.lat:=45.1;
p2.lon:=46.1;
d:=1;
p1.fastDistM(p2);
asm
  push esi
  push edi
  push ebx
  mov eax,p1
  push eax
  mov eax,p2
  push eax

  mov ebx,100000000
//    fld d
  fldz
  rdtsc
  mov esi,eax
  mov edi,edx
@@loop:
  mov edx,[esp]
  mov eax,[esp+4]
  call TGTPoint.fastDistSqrM
  faddp st(1),st(0)
  sub ebx,1
  jnz @@loop
  rdtsc
  fstp st(0)
  add esp,8
  sub eax,esi
  sbb edx,edi
  pop edi
  pop esi
  mov dword[i64],eax
  mov dword[i64+4],edx
end;
d:=i64/100000000;
asm
  mov eax,dword(d)
end;
end;
 }

function TMultiPoly.getArea(): double;
type
  TListItem = record
    area: double;
    poly: TGTPoly;
  end;
  TList = array of TListItem;

  function includes(greater, less: TGTPoly): boolean;
  var
    i: integer;
    p: TGTPoint;
  begin
    for i := 0 to less.count - 1 do begin
      case greater.isIn(less.fPoints[i]) of
        0: begin
            result := false;
            exit;
          end;
        2: begin
            result := true;
            exit;
          end;
      end;
    end;
    //all less-poly bound points are on greater-poly bound
    //check "middle" point of less-poly
    i := less.count div 2;
    p := TGTPoint.create();
    p.lat := (less.fPoints[0].lat + less.fPoints[i].lat) / 2;
    p.lon := (less.fPoints[0].lon + less.fPoints[i].lon) / 2;
    result := greater.isIn(p) > 0;
    freeAndNil(p);
  end;

var
  polyList: TList;
  li: TListItem;
  i, j: integer;
begin
  if not isAllResolved() then
    raise EConvertError.create(toString() +
      '.getArea : not all references resolved or polygons closed.');
  if fArea >= 0 then begin
    result := fArea;
    exit;
  end;
  setLength(polyList, length(simplePolyList));
  //fill polyList in area descending order
  for i := 0 to high(simplePolyList) do begin
    polyList[i].poly := simplePolyList[i];
    polyList[i].area := simplePolyList[i].getArea();
    j := i;
    while (j > 0) and (polyList[j - 1].area < polyList[j].area) do begin
      li := polyList[j - 1];
      polyList[j - 1] := polyList[j];
      polyList[j] := li;
      dec(j);
    end;
  end;
  //now set area sign. Positive for outer, negative for inner
  //index 0, largest polygon always outer, so start with index 1.
  for i := 1 to high(polyList) do begin
    //check all greater polygons
    for j := i - 1 downto 0 do begin
      if includes(polyList[j].poly, polyList[i].poly) then begin
        if polyList[j].area > 0 then
          polyList[i].area := -abs(polyList[i].area)
        else
          polyList[i].area := abs(polyList[i].area);
        break;
      end;
    end;
  end;
  result := 0;
  for i := 0 to high(polyList) do
    result := result + polyList[i].area;
  fArea := result;
end;

initialization
  uModule.OSManRegister(TGeoTools, geoToolsClassGUID);
  //  test();
end.

