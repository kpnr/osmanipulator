unit uMultipoly;

interface
uses uInterfaces, uOSMCommon, uModule, Math, SysUtils, Classes, Variants, uDataStructures;

const
  //threshold for 'same node' detection in getIntersection routines.
  minPtDist = 0.1; //0.1 meter=10 cm

type
  TGTShape = class(TObject)
  protected
    function clone: TGTShape; virtual; abstract;
  end;

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
    // angle should be in [-pi/2...pi/2]
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
    function hasSameCoords(pt: TGTPoint): boolean;
    procedure assignNode(aNode: OleVariant);
    procedure midPoint(pt: TGTPoint);
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
    procedure resetBounds(); virtual;
  public
    constructor create();
    function clone: TGTShape; override;
    function canIntersects(const r: TGTRect): boolean;
    //isIn returns:
    //0 - pt outside
    //1 - pt is on bound
    //2 - pt is inside
    function isIn(const pt: TGTPoint): integer; virtual;
    procedure updateBoundRect(const pt: TGTPoint); virtual;
    property left: integer read fLeft write fLeft;
    property right: integer read fRight write fRight;
    property top: integer read fTop write fTop;
    property bottom: integer read fBottom write fBottom;
    property width: cardinal read get_width;
    property height: cardinal read get_height;
  end;

  TStripeRec = record
    segList: array of integer;
    max: integer;
  end;
  PStripeRec = ^TStripeRec;
  TStripeRecArray = array of TStripeRec;

  TGTPointArray = array of TGTPoint;

  TGTPoly = class(TGTRect)
  protected
    fStripesValid: boolean;
    fStripes: TStripeRecArray;
    fPoints: TGTPointArray;
    fCount: integer;
    function get_capacity: integer;
    procedure set_capacity(const Value: integer);
    procedure addExtraNode();
    procedure resetBounds(); override;
    procedure regenStripes();
  public
    destructor destroy; override;
    function clone(): TGTShape; override;
    function isIn(const pt: TGTPoint): integer; override;
    //returns signed area of polygon in square meters
    function getArea(): double;
    procedure addNode(const aNode: OleVariant);
    procedure updateBoundRect(const pt: TGTPoint); override;
    property count: integer read fCount;
    property capacity: integer read get_capacity write set_capacity;
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

  TIsInTestProc = function(const pt: TGTPoint): integer of object;

  TPolyOrientation = (poUnknown, poMixed, poCW, poCCW);

  TMultiPoly = class(TOSManObject, IMultiPoly)
  protected
    srcList, //parentIdx ignored
    relationList, //parentIdx=parent_relation_relationList_idx or (-1-parent_relation_srcList_idx)
    wayList, //parentIdx=parent_relation_relationList_idx or (-1-parent_relation_srcList_idx)
    nodeList //parentIdx=parent_way_wayList_idx
    : TMultiPolyList;
    simplePolyList: array of TGTPoly;
    fNotResolved, fNotClosed: TRefList;
    fArea: double;
    fOrientation: TPolyOrientation;

    class function getSegmentIntersection(const pt1, pt2, ptA, ptB: TGTPoint): TGTPoint;
    class function includes(greater, less: TGTPoly): boolean;
    class function triangleTest(pt1, pt2, pt3, workingPoint: TGTPoint; LessTest, GreaterTest:
      TIsInTestProc): integer;

    function cmpWayList(i, j: integer): integer;
    procedure swpWayList(i, j: integer);

    function isAllResolved(): boolean;

    function getLineIntersection(const aMap, aNodeArray: OleVariant; newNodeId: int64): OleVariant;
    function getPolyIntersection(const aMap, aNodeArray: OleVariant; newNodeId: int64): OleVariant;

    procedure growList(var list: TMultiPolyList; delta: integer = 1);
    procedure clearList(var list: TMultiPolyList);
    procedure putList(var list: TMultiPolyList; const obj: OleVariant; parent: integer);

    procedure createNotResolved();
    procedure createNotClosed();

    procedure clearInternalLists();

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
    function getPolygons(): OleVariant;
    function getIntersection(const aMap, anObj: OleVariant; newNodeId: int64): OleVariant;
    //returns true if node is in poly (including border)
    function isIn(const aNode: OleVariant): boolean;
    //returns multipoly area in square meters
    //if poly not resolved then exception raised
    function getArea(): double;
    //returns polygon orientation
    //0 - for mixed orientation, 1 - clockwise, 2 - contraclockwise
    //if poly not resolved then exception raised
    function getOrientation(): integer;
    //returns bounding box for poly. Returns SafeArray of four double variants
    // for N,E,S and W bounds respectively. If poly is not resolved then
    // exception raised.
    function getBBox: OleVariant;
  end;

implementation

type
  TSegFlags = set of (sfOnBound1, sfOnBound2, sfVisited);
  TSegDesc = record
    pNode1, pNode2: POleVariant;
    pPoint1, pPoint2: TGTPoint;
    bbox: TGTRect;
    flags: TSegFlags;
  end;
  PSegDesc = ^TSegDesc;

  TPolyBuilder = class
  protected
    first1, first2, last1, last2: int64;
    bmFirst: pointer;
    fIsEmpty: boolean;
    dst: TDualLinkedRing;
  public
    constructor create(destList: TDualLinkedRing);
    //segment moved from src to dest.
    //src position changed to next segment.
    //returns true if we can add next segment(poly is not closed)
    //Example:
    //before: dst=((a,b),(b,c),[c,d]) src=((z,x),[d,e],(e,f))
    //after:  dst=((a,b),(b,c),(c,d),[d,e]) src=((z,x),[e,f]) result=true
    function addSeg(src: TDualLinkedRing): boolean;
    function isClosedPoly(): boolean;
    procedure deleteChain(); //delete all segments from last to first inclusive
    property first: int64 read first1;
    property last: int64 read last2;
    property beforeLast: int64 read last1;
    property isEmpty: boolean read fIsEmpty;
  end;

procedure freeSeg(pSeg: PSegDesc);
begin
  if not assigned(pSeg) then
    exit;
  freeAndNil(pSeg.bbox);
  dispose(pSeg);
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

function TGTPoint.hasSameCoords(pt: TGTPoint): boolean;
begin
  result := (fx = pt.fx) and (fy = pt.fy);
end;

procedure TGTPoint.midPoint(pt: TGTPoint);
const
  oneHalf: double = 0.5;
asm
  //eax=self, edx=pt
  //fy:=round(0.5*(fy+pt.fy));
  fld oneHalf
  fild TGTPoint(eax).fy
  fiadd TGTPoint(edx).fy
  fmul st(0),st(1)
  fistp TGTPoint(eax).fy
  //fx:=round(0.5*(fx+pt.fx));
  fild TGTPoint(eax).fx
  fiadd TGTPoint(edx).fx
  fmulp st(1),st(0)
  fistp TGTPoint(eax).fx
end;

{ TGTRect }

class function TGTRect.between(const v, min, max: integer): integer;
begin
  result := 2 * ord((v > min) and (v < max)) + ord((v = min) or (v = max));
end;

function TGTRect.canIntersects(const r: TGTRect): boolean;
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

{ TGTPoly }
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

procedure TGTPoly.set_capacity(const Value: integer);
begin
  if Value <= count then exit;
  setLength(fPoints, Value);
end;

procedure TGTPoly.resetBounds;
begin
  inherited;
  fStripesValid := false;
end;

type
  TStripeSortRec = record
    idxAndAction, y: integer;
  end;
  PStripeSortRec = ^TStripeSortRec;

function regenStripescmp(r1, r2: pointer): integer;
begin
  if (PStripeSortRec(r1).y > PStripeSortRec(r2).y) then
    result := 1
  else if (PStripeSortRec(r1).y < PStripeSortRec(r2).y) then
    result := -1
  else
    result := (PStripeSortRec(r1).idxAndAction and 1) - (PStripeSortRec(r2).idxAndAction and 1);
end;

procedure TGTPoly.regenStripes;
const
  cStripeBreak = 20;
var
  stripeEnd, stripeCnt: integer;
  sa: TStripeRecArray;

  procedure makeStripe(stripeList, activeList: TList);
  var
    i: integer;
    p: PStripeRec;
  begin
    if (stripeList.count = 0) then
      raise EInvalidArgument.create('TGTPoly.regenStripes.makeStripe: empty stripe list');
    if (stripeCnt >= length(sa)) then
      setLength(sa, length(sa) + count div cStripeBreak + 1);
    p := @sa[stripeCnt];
    inc(stripeCnt);
    setLength(p.segList, stripeList.count);
    for i := 0 to stripeList.count - 1 do
      p.segList[i] := integer(stripeList[i]);
    p.max := stripeEnd;
    //    OSManLog('Stripe ?...'+FloatToStrF(stripeEnd/1e7,ffFixed,9,7)+' nSegs='+inttostr(stripeList.Count));
    stripeList.Assign(activeList);
  end;
var
  sra: array of TStripeSortRec;
  list, activeSegs, curStripeSegs: TList;
  i, mx, mn, curStripeAdded, curStripeRemoved, idx: integer;
  canBreakStripe: boolean;
  p, p1: PStripeSortRec;
begin
  fStripesValid := true;
  setLength(fStripes, 0);
  if (count < 2) then
    exit;
  activeSegs := nil;
  list := TList.create();
  try
    list.capacity := (count - 1) * 2;
    setLength(sra, (count - 1) * 2);
    p := @sra[0];
    for i := 0 to count - 2 do begin
      p.idxAndAction := i * 2;
      mx := fPoints[i].fy;
      mn := fPoints[i + 1].fy;
      if (mx < mn) then begin
        idx := mx;
        mx := mn;
        mn := idx;
      end;
      p.y := mn;
      list.Add(p);
      inc(p);
      p.idxAndAction := i * 2 + 1;
      p.y := mx;
      list.Add(p);
      inc(p);
    end;
    list.Sort(regenStripescmp);
    curStripeAdded := 0;
    curStripeRemoved := 0;
    stripeCnt := 0;
    activeSegs := TList.create();
    curStripeSegs := TList.create();
    for i := 0 to list.count - 1 do begin
      p := list[i];
      idx := p.idxAndAction shr 1;
      if odd(p.idxAndAction) then begin
        activeSegs.Remove(pointer(idx));
        inc(curStripeRemoved);
      end else begin
        canBreakStripe := fPoints[idx].fy <> fPoints[idx + 1].fy;
        canBreakStripe := canBreakStripe and (stripeEnd <> p.y);
        if (curStripeRemoved >= cStripeBreak) and (curStripeAdded >= cStripeBreak) and
          (canBreakStripe) then begin
          makeStripe(curStripeSegs, activeSegs);
          curStripeAdded := 0;
          curStripeRemoved := 0;
        end;
        p1 := pointer(idx);
        activeSegs.Add(p1);
        curStripeSegs.Add(p1);
        inc(curStripeAdded);
      end;
      stripeEnd := p.y;
    end;
    if (curStripeSegs.count > 0) then
      makeStripe(curStripeSegs, activeSegs);
    //    OSManLog(' ptcnt='+ inttostr(count)+' refcnt='+inttostr(cnt));
    setLength(sa, stripeCnt);
    fStripes := sa;
  finally
    freeAndNil(list);
    freeAndNil(activeSegs);
    freeAndNil(curStripeSegs);
  end;
end;

procedure TGTPoly.updateBoundRect;
begin
  inherited;
  fStripesValid := false;
end;

function TGTPoly.isIn(const pt: TGTPoint): integer;

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
  i, j, k: integer;
  xcase, ycase: byte;
  b1, b2: TGTPoint;
begin
  result := inherited isIn(pt);
  if result = 0 then exit;
  if (not fStripesValid) then begin
    regenStripes();
  end;
  i := 0;
  j := high(fStripes);
  k := j;
  while (j - i > 2) do begin
    k := (i + j + 1) shr 1;
    if (fStripes[k].max < pt.y) then
      i := k
    else
      j := k;
  end;
  while (k > 0) and (pt.y <= fStripes[k].max) do
    dec(k);
  j := high(fStripes);
  while (k < j) and (fStripes[k].max < pt.y) do
    inc(k);
  result := 0;
  i := length(fStripes[k].segList);
  while (i > 0) do begin
    dec(i);
    j := fStripes[k].segList[i];
    b1 := fPoints[j];
    b2 := fPoints[j + 1];
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
  fArea := -1;
  fOrientation := poUnknown;
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

  procedure removeWayDups();
  var
    i: integer;
  begin
    //sort way list (1,5,3,2,4)=>(1,2,3,4,5)
    Sort(0, wayList.count - 1, cmpWayList, swpWayList);
    //start from tail to head
    i := wayList.count - 1;
    while i > 0 do begin
      //$$$dbg OSManLog(inttostr(wayList.items[i].obj.id));
      //duplicate found
      if (wayList.items[i].obj.id = wayList.items[i - 1].obj.id) then begin
        //move ways from tail to middle and replace dups
        //only even number of dups deleted, so (1,2,2,2,3,3,4)=>(1,2,4)
        //which is compatible to isIn test and other polygon operations
        dec(wayList.count);
        wayList.items[i] := wayList.items[wayList.count];
        dec(wayList.count);
        dec(i);
        wayList.items[i] := wayList.items[wayList.count];
        //(1,2,3,_3_,4,5,6,7)=>(1,2,_6_,7,4,5)
        //all ids before Current is less then Current and all after, so
        //all duplicates should be detected.
      end;
      dec(i);
    end;
  end;

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
    s, role: WideString;
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
            inc(pv);
            role := pv^;
            inc(pv);
            dec(mlen, 3);
            //skip invalid roles
            if not ((role = '') or (role = 'inner') or (role = 'outer') or (role = 'enclave') or
              (role = 'exclave')) then continue;
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
        fOrientation := poMixed;
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

      procedure Add(pwd1, pwd2: PWayDescItem);
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
        Add(pwd1, pwd2);
      end
      else if pwd1.id1 = pwd2.id0 then begin
        //new=old+segment
        Add(pwd1, pwd2);
      end
      else if pwd1.id0 = pwd2.id1 then begin
        //new=segment+old
        Add(pwd2, pwd1);
        //exchange description 1 & 2
        move(pwd1^, tempWayDesc, sizeof(pwd1^));
        move(pwd2^, pwd1^, sizeof(pwd1^));
        move(tempWayDesc, pwd2^, sizeof(pwd1^));
      end
      else if pwd1.id1 = pwd2.id1 then begin
        //new=old+reverse(segment)
        reverse(pwd2);
        Add(pwd1, pwd2);
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
  //In case of "touching" bounds remove dupliceted ways.
  removeWayDups();
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
  result := isAllResolved();
end;

function TMultiPoly.isAllResolved: boolean;
begin
  result := nodeList.count > 0;
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

  function makeNewNode(pt: TGTPoint): OleVariant;
  begin
    result := aMap.createNode();
    result.lat := pt.lat;
    result.lon := pt.lon;
    result.id := newNodeId;
    dec(newNodeId);
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
          pv^ := pWND1.node;
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
  simplePolyIdx, polySegmentIdx, i, nWayNodes, nodeListIdx: integer;
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
    nodeListIdx := 0;
    for simplePolyIdx := 0 to high(simplePolyList) do begin
      if simplePolyIdx > 0 then inc(nodeListIdx, simplePolyList[simplePolyIdx - 1].count);
      if not wayBRect.canIntersects(simplePolyList[simplePolyIdx]) or
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
        if not wayBRect.canIntersects(polySegmentBRect) then
          continue;
        pWND := wayPoints;
        while assigned(pWND) do begin
          pWND2 := pWND;
          pWND := pWND.pNextNode;
          if not (assigned(pWND) and polySegmentBRect.canIntersects(pWND.bRect)) then
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
                node := makeNewNode(i0);
                node.tags.setByKey('osman:node1', nodeList.items
                  [nodeListIdx + polySegmentIdx - 1].obj.id);
                node.tags.setByKey('osman:node2', nodeList.items
                  [nodeListIdx + polySegmentIdx].obj.id);
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
            i0.x := pWND.point.x;
            i0.y := pWND.point.y;
            i0.midPoint(pWND2.point);
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
  i: integer;
  p: TGTPoly;
begin
  result := 0;
  for i := 0 to high(simplePolyList) do begin
    p := simplePolyList[i];
    case p.isIn(pt) of
      0: ;
      1: begin
          result := 1;
          break;
        end;
      2: result := 2 - result;
    end;
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

  procedure freeAndNilSeg(var pSeg: PSegDesc);
  begin
    freeSeg(pSeg);
    pSeg := nil;
  end;
var
  newNodeCount: integer;
  newNodes: array of POleVariant;
  newPoints: array of TGTPoint;

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
          if bboxB.canIntersects(p.bbox) then begin
            result.insertLast(p);
            p := nil;
          end;
        end;
        if not result.isEmpty() then
          result.first();
      finally
        freeAndNilSeg(p);
      end;
    except
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

    new(newNodes[newNodeCount]);
    newNodes[newNodeCount]^ := aMap.createNode();
    pNewNode := newNodes[newNodeCount];
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
    doSplitA, doSplitB, isSameSeg: boolean;
  begin
    crossPt := nil;
    try
      pSegB := slB.first();
      while assigned(pSegB) and not slA.isEmpty() do begin
        pSegA := slA.first();
        while assigned(pSegA) and assigned(pSegB) do begin
          if not pSegA.bbox.canIntersects(pSegB.bbox) then begin
            //try next segment pair
            if (slA.hasNext()) then
              pSegA := slA.next()
            else
              pSegA := nil;
            continue;
          end;
          //find (one of) cross point(s)
//          debugPrint('('+inttostr(pSegA.pNode1^.id)+'-'+inttostr(pSegA.pNode2^.id)+')*('+inttostr(pSegB.pNode1^.id)+'-'+inttostr(pSegB.pNode2^.id)+')');//$$$
          crossPt := getSegmentIntersection(pSegA.pPoint1, pSegA.pPoint2, pSegB.pPoint1,
            pSegB.pPoint2);
          if assigned(crossPt) then begin
            //segments are crossed
            pNewNode := nil;
            pNewPoint := nil;

            //test distance between cross-point and segA end-points
            //segA must be checked before segB to keep tags of polygonA nodes
            doSplitA := true;
            if (crossPt.hasSameCoords(pSegA.pPoint1)) then begin
              //crossed at SegA start
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
            else if (crossPt.hasSameCoords(pSegA.pPoint2)) then begin
              //crossed at SegA end
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

            //test distance between cross-point and SegB end-points
            doSplitB := true;
            if (crossPt.hasSameCoords(pSegB.pPoint1)) then begin
              //crossed at SegB start
              include(pSegB.flags, sfOnBound1);
              doSplitB := false;
              if not assigned(pNewNode) then begin
                pNewNode := pSegB.pNode1;
                pNewPoint := pSegB.pPoint1;
              end
              else begin
                pSegB.pNode1 := pNewNode;
                pSegB.pPoint1 := pNewPoint;
              end;
            end
            else if (crossPt.hasSameCoords(pSegB.pPoint2)) then begin
              //crossed at SegB end
              include(pSegB.flags, sfOnBound2);
              doSplitB := false;
              if not assigned(pNewNode) then begin
                pNewNode := pSegB.pNode2;
                pNewPoint := pSegB.pPoint2;
              end
              else begin
                pSegB.pNode2 := pNewNode;
                pSegB.pPoint2 := pNewPoint;
              end;
            end;

            if not assigned(pNewNode) then begin
              //cross in middle of both segments, so we need new point and node
              createNewPoint(pNewNode, pNewPoint, crossPt);
            end;
            if doSplitA then begin
              splitAndStore(slA, pNewNode, pNewPoint);
              pSegA := nil; //check pSegA agane - it may be same as SegB
            end;
            if doSplitB then
              splitAndStore(slB, pNewNode, pNewPoint);
            if (not doSplitA) and (not doSplitB) then begin
              isSameSeg := false;
              if ((pSegA.pNode1^.id = pSegB.pNode1^.id) and
                (pSegA.pNode2^.id = pSegB.pNode2^.id)) then begin
                isSameSeg := true;
              end
              else if ((pSegA.pNode1^.id = pSegB.pNode2^.id) and
                (pSegA.pNode2^.id = pSegB.pNode1^.id)) then begin
                isSameSeg := true;
              end;
              if isSameSeg then begin
                //pSegA and pSegB is same
                //mark segment as it was visited and marked in buildIntersection
                //we can leave both copies of segment in both list because
                //segment source list switched only if there is no next segment
                //in current(active) list.
                pSegA.flags := [sfOnBound1, sfOnBound2, sfVisited];
                pSegB.flags := [sfOnBound1, sfOnBound2, sfVisited];
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
          else if not slA.isEmpty() then
            pSegA := slA.data;
        end;
        if assigned(pSegB) then begin
          if slB.hasNext() then
            pSegB := slB.next()
          else
            pSegB := nil;
        end
        else if not slB.isEmpty() then
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
      bmReverseSeg: pointer;

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
        bmReverseSeg := nil;
      end;

      procedure deleteSeg();
      begin
        //debugPrint('del seg ('+inttostr(pSeg.pNode1^.id)+'-'+inttostr(pSeg.pNode2^.id)+')');//$$$
        assert(pSeg = curList.data, '{5F0D288C-F5F7-485C-BB60-14C3B4F88D69}');
        freeAndNilSeg(pSeg);
        if (curList.bookmark = bmReverseSeg) then
          bmReverseSeg := nil;
        curList.delete();
      end;

      procedure freeReverseSeg();
      var
        bm: pointer;
      begin
        if not assigned(bmReverseSeg) then
          exit;
        bm := curList.bookmark;
        assert(bm <> bmReverseSeg, '{018D7BAB-065A-44D4-87E3-8A9C26778A2F}');
        curList.bookmark := bmReverseSeg;
        freeSeg(curList.delete());
        curList.bookmark := bm;
        bmReverseSeg := nil;
      end;

    var
      i641, i642: int64;
      pt: TGTPoint;
      pb: TPolyBuilder;
      bm: pointer;
      i: integer;
    begin
      pt := nil;
      pb := nil;
      curList := slA;
      resList := slB;
      curTest := isInInt;
      resTest := polyA.isIn;
      bmReverseSeg := nil;
      if curList.isEmpty() then
        swapLists();
      pb := TPolyBuilder.create(r);
      pb.addSeg(curList);
      //debugPrint('add first seg ('+inttostr(pSeg.pNode1^.id)+'-'+inttostr(pSeg.pNode2^.id)+')');//$$$
      try
        while not (pb.isClosedPoly) do begin
          if curList.isEmpty() then
            if resList.isEmpty() then begin
              //both lists empty, but no poly build
              pb.deleteChain();
              break;
            end
            else
              swapLists();
          pSeg := curList.data;
          if not (sfVisited in pSeg.flags) then begin
            i := ord(sfOnBound1 in pSeg.flags) + 2 * ord(sfOnBound2 in pSeg.flags);
            //debugPrint('('+inttostr(pSeg.pNode1^.id)+'-'+inttostr(pSeg.pNode2^.id)+')');//$$$
            case i of
              0, 2:
                case curTest(pSeg.pPoint1) of
                  0: deleteSeg();
                  1: begin
                      include(pSeg.flags, sfOnBound1);
                      continue;
                    end;
                  2: include(pSeg.flags, sfVisited);
                end;
              1:
                case curTest(pSeg.pPoint2) of
                  0: deleteSeg();
                  1: begin
                      include(pSeg.flags, sfOnBound2);
                      continue;
                    end;
                  2: include(pSeg.flags, sfVisited);
                end;
              3: begin
                  if not assigned(pt) then
                    pt := TGTPoint.create();
                  pt.x := pSeg.pPoint1.x;
                  pt.y := pSeg.pPoint1.y;
                  pt.midPoint(pSeg.pPoint2);
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
          if (i641 = pb.last) then begin
            freeReverseSeg();
            pb.addSeg(curList);
          end
          else if (i642 = pb.last) then begin
            reverseSeg(pSeg);
            freeReverseSeg();
            pb.addSeg(curList);
            if not curList.isEmpty() then
              curList.prev();
          end
          else begin
            //current seg is not continue of prev segment
            if not resList.isEmpty() then
              swapLists();
            i := 0;
            bm := nil;
            repeat
              pSeg := curList.data;
              if not (sfVisited in pSeg.flags) then
                break;
              i641 := pSeg.pNode1^.id;
              i642 := pSeg.pNode2^.id;
              if (i641 = pb.last) or (i642 = pb.last) then begin
                if ((i641 = pb.last) and (i642 = pb.beforeLast)) or
                  ((i642 = pb.last) and (i641 = pb.beforeLast)) then begin
                  bmReverseSeg := curList.bookmark;
                end
                else begin
                  freeReverseSeg();
                  break;
                end;
              end;
              if (bm = curList.bookmark) then begin
                if assigned(bmReverseSeg) then begin
                  //we find nothing except reverse seg, so try it :-(
                  curList.bookmark := bmReverseSeg;
                  bmReverseSeg := nil;
                  break;
                end;
                inc(i);
                if not resList.isEmpty() then
                  swapLists()
                else begin
                  inc(i); //we have only one list - count it twice(to remove non-poly tail from r)
                  break;
                end;
                bm := nil;
                bmReverseSeg := nil;
              end
              else begin
                if not assigned(bm) then
                  bm := curList.bookmark;
                curList.next();
              end;
            until (i > 1);
            if (i > 1) then begin
              //both list have no next segment for polygon.
              //We should delete all segments to Seg.pNode1.id==firstId
              pb.deleteChain();
              break; //we can`t build poly, so stop and exit
            end;
          end;
        end;
        if not (r.isEmpty) then
          r.next();
      finally
        freeAndNil(pt);
        freeAndNil(pb);
      end;
    end;
  var
    pSeg: PSegDesc;
    pt: TGTPoint;
    bm: pointer;
    action: (acDel, acBuild, acNone);
    sw: integer;
  begin
    result := TDualLinkedRing.create();
    assert(not slA.isEmpty(), '{B96A48BE-A404-460A-8D66-7D047D11D79F}');
    bm := nil;
    while not (slA.isEmpty()) and (slA.bookmark <> bm) do begin
      pSeg := slA.data;
      if not assigned(bm) then
        bm := slA.bookmark;
      sw := ord(sfOnBound1 in pSeg.flags) + 2 * ord(sfOnBound2 in pSeg.flags);
      action := acNone;
      case sw of
        0:
          case isInInt(pSeg.pPoint1) of
            0: action := acDel;
            1:
              case isInInt(pSeg.pPoint2) of
                0: action := acDel;
                2: action := acBuild;
              end;
            2: action := acBuild;
          end;
        1:
          case isInInt(pSeg.pPoint2) of
            0: action := acDel;
            2: action := acBuild;
          end;
        2:
          case isInInt(pSeg.pPoint1) of
            0: action := acDel;
            2: action := acBuild;
          end;
        3:
          if sfVisited in pSeg.flags then
            action := acBuild;
      end;
      if action = acBuild then begin
        include(pSeg.flags, sfVisited);
        if not result.isEmpty then
          result.prev();
        buildPolygon(result);
      end
      else if action = acDel then begin
        freeAndNilSeg(pSeg);
        slA.delete();
      end;
      if action <> acNone then
        bm := nil
      else
        slA.next();
    end;
    bm := nil;
    pt := TGTPoint.create();
    try
      while not (slA.isEmpty()) and (slA.bookmark <> bm) do begin
        pSeg := slA.data;
        if not assigned(bm) then
          bm := slA.bookmark;
        if [sfOnBound1, sfOnBound2] = pSeg.flags then begin
          pt.x := pSeg.pPoint1.x;
          pt.y := pSeg.pPoint1.y;
          pt.midPoint(pSeg.pPoint2);
          if isInInt(pt) > 0 then begin
            include(pSeg.flags, sfVisited);
            buildPolygon(result);
            bm := nil;
            continue;
          end
          else begin
            freeAndNilSeg(pSeg);
            slA.delete();
          end;
        end
        else
          slA.next();
      end;
    finally
      freeAndNil(pt);
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
    pSeg := sl.data;
    nPolygons := 0;
    while assigned(pSeg) do begin
      firstId := pSeg.pNode1^.id;
      lastId := pSeg.pNode2^.id;
      nPolyNodes := 2;
      while firstId <> lastId do begin
        pSeg := sl.next();
        assert(lastId = pSeg.pNode1^.id, '{A688E5BD-6396-47C5-97CF-E7BD1EAC5A80}');
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
        freeAndNilSeg(pSeg);
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

  function buildExtremeIntersection(slA: TDualLinkedRing; TestA, TestB: TIsInTestProc):
      TDualLinkedRing;
    //build intersection in extreme case - A fully in/out of B, so intersection
    // is empty or same as A

    procedure delPoly(src: TDualLinkedRing);
    var
      firstId, lastId: int64;
      pSeg: PSegDesc;
    begin
      pSeg := src.delete();
      firstId := pSeg.pNode1^.id;
      lastId := pSeg.pNode2^.id;
      freeAndNilSeg(pSeg);
      while not src.isEmpty() do begin
        pSeg := src.data;
        if (pSeg.pNode1^.id <> lastId) then
          break;
        lastId := pSeg.pNode2^.id;
        freeAndNilSeg(pSeg);
        src.delete();
      end;
      while not src.isEmpty() do begin
        pSeg := src.prev();
        if (pSeg.pNode2^.id <> firstId) then begin
          src.next();
          break;
        end;
        firstId := pSeg.pNode1^.id;
        freeAndNilSeg(pSeg);
        src.delete();
      end;
      if not src.isEmpty() then
        src.prev(); //point to last segment of prev poly
    end;

    procedure movePoly(src, dst: TDualLinkedRing);

      procedure killTail(r: TDualLinkedRing; firstId: int64);
      var
        pSeg: PSegDesc;
      begin
        while true do begin //we can skip IsEmpty check - r has at least one segment
          pSeg := r.delete();
          if (pSeg.pNode1^.id = firstId) then
            break //we find the beginning
          else
            freeAndNilSeg(pSeg); //delete and try prev
          r.prev(); //if pSeg.pNode1^.id<>firstId then we have at least one segment in list
        end;
        freeAndNilSeg(pSeg); //pSeg is valid in any case
        if not r.isEmpty() then begin
          r.prev();
        end;
      end;
    var
      firstId, lastId: int64;
      pSeg: PSegDesc;
      bmdst, bmsrc: pointer;
    begin
      src.prev();
      bmsrc := src.bookmark;
      src.next();
      pSeg := src.delete();
      firstId := pSeg.pNode1^.id;
      lastId := pSeg.pNode2^.id;
      dst.insertAfter(pSeg);
      dst.next();
      bmdst := dst.bookmark;
      while (not src.isEmpty()) do begin
        pSeg := src.data;
        if (pSeg.pNode1^.id <> lastId) then
          break;
        dst.insertAfter(pSeg);
        dst.next();
        lastId := pSeg.pNode2^.id;
        src.delete();
        if (lastId = firstId) then
          exit;
      end;
      if not src.isEmpty() then begin
        src.bookmark := bmsrc;
        src.next();
        bmsrc := dst.bookmark;
        dst.bookmark := bmdst;
        dst.prev();
      end
      else begin
        bmsrc := nil;
      end;
      while (not src.isEmpty()) do begin
        pSeg := src.prev();
        if (pSeg.pNode2^.id <> firstId) then begin
          src.next();
          break;
        end;
        dst.insertAfter(pSeg);
        firstId := pSeg.pNode1^.id;
        src.delete();
        if (lastId = firstId) then begin
          break;
        end;
      end;
      if assigned(bmsrc) then
        dst.bookmark := bmsrc;
      if (lastId <> firstId) then
        killTail(dst, firstId);
    end;

  var
    pSeg1, pSeg2: PSegDesc;
    midPoint: TGTPoint;
    tst: integer;
    action: (acNone, acDel, acBuild);
    bm: pointer;
  begin
    result := TDualLinkedRing.create();
    if slA.isEmpty then exit;
    midPoint := TGTPoint.create();
    bm := nil;
    try
      pSeg1 := slA.data;
      while not slA.isEmpty() do begin
        pSeg2 := slA.next();
        action := acNone;
        case TestB(pSeg1.pPoint1) of
          0: action := acDel;
          1: if (sfVisited in pSeg1.flags) then
              action := acBuild
            else begin
              tst := triangleTest(pSeg1.pPoint1, pSeg1.pPoint2, pSeg2.pPoint2, midPoint, TestA,
                TestB);
              case tst of
                0: begin
                    action := acDel;
                  end;
                1: ;
                2: begin
                    action := acBuild;
                  end;
              else
                assert(false, '{84DA2DA8-1178-48B1-B2A9-84BAD0623692}');
              end;
            end;
          2: action := acBuild;
        else
          assert(false, '{F5842433-1FD9-4196-94B9-DFC2F3A21393}');
        end;
        if (action = acNone) and (bm = slA.bookmark) then
          //we check whole slA, but no actions performed
          action := acDel;
        if action = acDel then begin
          slA.prev();
          //cur Item in slA==first segment of deleting poly
          delPoly(slA);
          //cur Item in slA==segment before deleted poly
          if not slA.isEmpty() then
            slA.next; //check next segment
        end
        else if action = acBuild then begin
          slA.prev();
          //cur Item in slA==first segment of inserting poly
          //cur Item in result==last segment of last inserted poly
          movePoly(slA, result);
          //cur Item in slA==first not inserted segment
          //cur Item in result==last segment of inserted poly
        end;
        if not slA.isEmpty() then
          pSeg1 := slA.data;
        if action <> acNone then
          //some action. Reset bookmark.
          bm := nil;
        if not assigned(bm) then
          //no bookmark. Set it.
          bm := slA.bookmark;
      end;
      if not result.isEmpty() then
        result.next();
      //move to segment, next after last inserted. It should be first segment of first poly
    finally
      freeAndNil(midPoint);
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
    if not polyA.canIntersects(bboxB) then
      exit;
    //check (segments from A) and (boundbox(B))
    dec(pNodeVar, nWayNodes);
    segListA := sortSeg(pNodeVar, sizeof(pNodeVar^), polyA, bboxB);
    //check (segments from B) and (boundbox(A))
    k := 0;
    segListB := TDualLinkedRing.create();
    for i := 0 to high(simplePolyList) do begin
      tmpList := sortSeg(@nodeList.items[k].obj, sizeof(nodeList.items[0]), simplePolyList[i],
        polyA);
      segListB.appendBefore(tmpList);
      inc(k, simplePolyList[i].count);
    end;
    if not (segListA.isEmpty() or segListB.isEmpty()) then begin
      //both lists not empty, split intersecting segments
      splitSegments(segListA, segListB);
    end;
    //handle intersection type cases
    i := ord(segListA.isEmpty()) + 2 * ord(segListB.isEmpty);
    if i = 0 then begin
      //both lists not empty - polygons intersects in usual way
      segListR := buildIntersection(segListA, segListB, polyA);
      //we have extreme case. ListA and ListB modified by
      //  buildIntersection routine, so we can re-check intersection case
      i := ord(segListA.isEmpty()) + 2 * ord(segListB.isEmpty);
    end
    else begin
      segListR := TDualLinkedRing.create();
    end;
    case i of
      0: {already intersected, nothing to do};
      1: begin
          //listA is empty, listB is filled.
          //No A-segments intersects B-bbox and B-bound => all A-segments outside B
          //No B-segments intersects A-bound and some of them inside A-bbox =>
          //  case 1. B outside A, but intersects A-bbox => empty intersection
          //  case 2. B fully inside A => intersection is B itself
          //B can be multipoly, so we need check every simple polygon.
          freeAndNil(segListA);
          segListA := buildExtremeIntersection(segListB, isInInt, polyA.isIn);
          segListR.appendBefore(segListA);
        end;
      2: begin
          //listA is filled, listB is empty.
          //No B-segments intersects A-bbox and A-bound => all B-segments outside A
          //No A-segments intersects B-bound and some of them inside B-bbox =>
          //  case 1. A outside B, but intersects B-bbox => empty intersection
          //  case 2. A fully inside B => intersection is A itself
          freeAndNil(segListB);
          segListB := buildExtremeIntersection(segListA, polyA.isIn, isInInt);
          segListR.appendBefore(segListB);
        end;
      3: begin
          //both lists is empty. No more intersections
        end;
    end;

    if assigned(segListR) and not (segListR.isEmpty()) then
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
      VarClear(newNodes[i]^);
      dispose(newNodes[i]);
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

function TMultiPoly.getArea(): double;
type
  TListItem = record
    area: double;
    poly: TGTPoly;
  end;
  TList = array of TListItem;

var
  polyList: TList;
  li: TListItem;
  i, j: integer;
  d: double;
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
    d := simplePolyList[i].getArea();
    if (fOrientation <> poMixed) then begin
      if (d > 0) then begin
        if (fOrientation <> poCCW) then
          fOrientation := poCW
        else
          fOrientation := poMixed;
      end
      else if (d < 0) then begin
        if (fOrientation <> poCW) then
          fOrientation := poCCW
        else
          fOrientation := poMixed;
      end;
    end;
    polyList[i].area := abs(d);
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
  if (fOrientation = poUnknown) then
    fOrientation := poMixed;
end;

class function TMultiPoly.triangleTest(pt1, pt2, pt3, workingPoint: TGTPoint; LessTest,
  GreaterTest: TIsInTestProc): integer;
//result is:
//0 - center point inside A but outside B => A outside B
//1 - can`t determine A and B layout => we should continue checking
//2 - center point inside A and inside B => A inside B

  function getP(pt1, pt2, pt3: TGTPoint): double;
  asm
    //P=|x1-x2|+|y1-y2|+|x1-x3|+|y1-y3|+|x2-x3|+|y2-y3|;
    fild TGTPoint(eax).fx  //x1
    fisub TGTPoint(edx).fx //x1-x2
    fabs                   //|x1-x2|
    fild TGTPoint(eax).fy  //|x1-x2| y1
    fisub TGTPoint(edx).fy //|x1-x2| y1-y2
    fabs                   //|x1-x2| |y1-y2|
    faddp st(1),st(0)      //l(p1,p2)
    fild TGTPoint(eax).fx  //l(p1,p2) x1
    fisub TGTPoint(ecx).fx //l(p1,p2) x1-x3
    fabs                   //l(p1,p2) |x1-x3|
    faddp st(1),st(0)      //l12+dx13
    fild TGTPoint(eax).fy  //l(p1,p2)+dx13 y1
    fisub TGTPoint(ecx).fy //l(p1,p2)+dx13 y1-y3
    fabs                   //l(p1,p2)+dx13 |y1-y3|
    faddp st(1),st(0)      //l12+l13
    fild TGTPoint(edx).fx  //l12+l13 x2
    fisub TGTPoint(ecx).fx //l12+l13 x2-x3
    fabs                   //l12+l13 |x2-x3|
    faddp st(1),st(0)      //l12+l13+dx23
    fild TGTPoint(edx).fy  //l12+l13 y2
    fisub TGTPoint(ecx).fy //l12+l13 y2-y3
    fabs                   //l12+l13 |y2-y3|
    faddp st(1),st(0)      //l12+l13+l23=P
  end;

  function getS(pt1, pt2, pt3: TGTPoint): double;
  const
    half: single = 1 / 2;
    //S=|x1(y3-y2)+x2(y1-y3)+x3(y2-y1)|/2
  asm
    fild TGTPoint(eax).fy //y1
    fild TGTPoint(edx).fy //y1 y2
    fild TGTPoint(ecx).fy //y1 y2 y3
    fld st(2)             //y1 y2 y3 y1
    fld st(2)             //y1 y2 y3 y1 y2
    fld st(2)             //y1 y2 y3 y1 y2 y3
    fsubp st(5),st(0)     //y1-y3 y2 y3 y1 y2
    fsubp st(2),st(0)     //y1-y3 y2 y3-y2 y1
    fsubp st(2),st(0)     //y1-y3 y2-y1 y3-y2
    fimul TGTPoint(eax).fx//y1-y3 y2-y1 x1(y3-y2)
    fild TGTPoint(edx).fx //y1-y3 y2-y1 x1(y3-y2) x2
    fild TGTPoint(edx).fx //y1-y3 y2-y1 x1(y3-y2) x2 x3
    fmulp st(3),st(0)     //y1-y3 x3(y2-y1) x1(y3-y2) x2
    fmulp st(3),st(0)     //x2(y1-y3) x3(y2-y1) x1(y3-y2)
    faddp st(1),st(0)     //x2(y1-y3) x3(y2-y1)+x1(y3-y2)
    faddp st(1),st(0)     //x2(y1-y3)+x3(y2-y1)+x1(y3-y2)
    fmul half
    fabs
  end;

  function avg3(i, j, k: integer): integer;
  const
    third: double = 1 / 3;
  asm
    push eax
    fild dword[esp]
    mov [esp],edx
    fiadd dword[esp]
    mov [esp],ecx
    fiadd dword[esp]
    fmul third
    fistp dword[esp]
    pop eax
    //result:=i div 3 + j div 3 + k div 3;
  end;
var
  p: double;
begin
  result := 1;
  p := getP(pt1, pt2, pt3);
  if (p < 100) then exit;
  //$$$ test triangle 16S/P^2 ratio. setpoint is 0.03(all angles greater 1 deg), min P=100(~1m)
  if (getS(pt1, pt2, pt3) / (p * p) * 16) < 0.03 then exit;
  workingPoint.x := avg3(pt1.x, pt2.x, pt3.x);
  workingPoint.y := avg3(pt1.y, pt2.y, pt3.y);
  if LessTest(workingPoint) = 2 then
    result := GreaterTest(workingPoint);
end;

function TMultiPoly.cmpWayList(i, j: integer): integer;
var
  iid, jid: int64;
begin
  iid := wayList.items[i].obj.id;
  jid := wayList.items[j].obj.id;
  if (iid < jid) then result := -1 else if (jid < iid) then result := 1 else result := 0;
end;

procedure TMultiPoly.swpWayList(i, j: integer);
var
  t: TMultiPolyListItem;
begin
  t := wayList.items[i];
  wayList.items[i] := wayList.items[j];
  wayList.items[j] := t;
end;

function TMultiPoly.getPolygons: OleVariant;
var
  ni: integer;

  function copyPoly(pidx: integer): OleVariant;
  var
    i: integer;
  begin
    result := VarArrayCreate([0, simplePolyList[pidx].count - 1], varVariant);
    for i := 0 to simplePolyList[pidx].count - 1 do begin
      result[i] := nodeList.items[ni].obj;
      inc(ni);
    end;
  end;
var
  ioTag: array of integer;
  i, j, o: integer;
  oa, ia: OleVariant;
begin
  if not isAllResolved() then
    raise EConvertError.create(toString() + '.getPolygons: polygon must be resolved');
  result := VarArrayCreate([0, 1], varVariant);
  setLength(ioTag, length(simplePolyList));
  for i := 0 to high(ioTag) do ioTag[i] := 0;
  for i := 0 to high(ioTag) - 1 do begin
    for j := i + 1 to high(ioTag) do begin
      if includes(simplePolyList[i], simplePolyList[j]) then inc(ioTag[j])
      else if includes(simplePolyList[j], simplePolyList[i]) then inc(ioTag[i])
    end;
  end;
  i := 0;
  o := 0;
  for j := 0 to high(ioTag) do
    if (odd(ioTag[j])) then inc(i) else inc(o);
  oa := VarArrayCreate([0, o - 1], varVariant);
  ia := VarArrayCreate([0, i - 1], varVariant);
  i := 0;
  o := 0;
  ni := 0;
  for j := 0 to high(ioTag) do begin
    if (odd(ioTag[j])) then begin
      ia[i] := copyPoly(j);
      inc(i);
    end
    else begin
      oa[o] := copyPoly(j);
      inc(o);
    end;
  end;
  result[0] := oa;
  result[1] := ia;
end;

class function TMultiPoly.includes(greater, less: TGTPoly): boolean;
var
  i: integer;
  midPoint: TGTPoint;
begin
  result := false;
  midPoint := TGTPoint.create();
  try
    for i := 0 to less.count - 1 do begin
      case greater.isIn(less.fPoints[i]) of
        0: begin
            exit;
          end;
        1: if i = 2 then
            case triangleTest(less.fPoints[i - 2], less.fPoints[i - 1], less.fPoints[i],
              midPoint, less.isIn, greater.isIn) of
              0: begin
                  exit;
                end;
              2: begin
                  result := true;
                  exit;
                end;
            end;
        2: begin
            result := true;
            exit;
          end;
      end;
    end;
  finally
    freeAndNil(midPoint);
  end;
  assert(false, '{2F825152-F046-4E07-973B-FF03C209ECA6}');
end;

function TMultiPoly.getOrientation: integer;
begin
  if (fOrientation = poUnknown) then getArea();
  case fOrientation of
    poCW: result := 1;
    poCCW: result := 2;
  else
    result := 0;
  end;
end;

{ TPolyBuilder }

function TPolyBuilder.addSeg(src: TDualLinkedRing): boolean;
var
  id1, id2: int64;
  pSeg: PSegDesc;

  procedure fillIds();
  begin
    id1 := pSeg.pNode1^.id;
    id2 := pSeg.pNode2^.id;
  end;
var
  bmLast: pointer;
begin
  pSeg := src.delete();
  fillIds();
  if isEmpty then begin
    //first segment
    dst.insert(pSeg);
    first1 := id1;
    first2 := id2;
    last1 := first1;
    last2 := first2;
    bmFirst := dst.bookmark;
    fIsEmpty := false;
  end
  else begin
    //not first segment
    assert(last2 = id1, '{7F1F3C12-023C-4AC9-B82E-C8F25037AC59}');
    if last1 = id2 then begin
      //Poly=....(a,b) and adding segment (b,a)
      freeSeg(pSeg);
      pSeg := dst.delete();
      //debugPrint('rem seg ('+inttostr(pSeg.pNode1^.id)+'-'+inttostr(pSeg.pNode2^.id)+')');//$$$
      freeSeg(pSeg);
      if not dst.isEmpty() then
        dst.prev();
      if first1 <> last1 then begin
        //not first segment of poly
        last2 := last1;
        last1 := PSegDesc(dst.data).pNode1^.id;
      end
      else begin
        //we reach first segment of poly
        last2 := first1;
        fIsEmpty := true;
      end;
    end
    else if (first1 = id2) then begin
      //last segment of poly
      bmLast := dst.bookmark;
      while (first2 = id1) do begin
        //handle case (a,b),(b,c),(c,d),[d,b] + [b,a] => (b,c),(c,d),[d,b]
        freeSeg(pSeg);
        dst.bookmark := bmFirst;
        pSeg := dst.delete();
        freeSeg(pSeg);
        if (bmFirst = bmLast) then begin
          fIsEmpty := true;
          break;
        end;
        bmFirst := dst.bookmark;
        pSeg := dst.data;
        fillIds();
        first1 := id1;
        first2 := id2;
        dst.bookmark := bmLast;
        pSeg := dst.delete();
        fillIds();
        dst.prev();
        bmLast := dst.bookmark;
      end;
      if not isEmpty then begin
        dst.insert(pSeg);
        last1 := id1;
        last2 := id2;
      end;
    end
    else begin
      //not first and not last
      //debugPrint('add seg ('+inttostr(pSeg.pNode1^.id)+'-'+inttostr(pSeg.pNode2^.id)+')');//$$$
      dst.insert(pSeg);
      last1 := id1;
      last2 := id2;
    end;
  end;
  result := (not isClosedPoly) or isEmpty;
end;

constructor TPolyBuilder.create(destList: TDualLinkedRing);
begin
  fIsEmpty := true;
  dst := destList;
  bmFirst := nil;
end;

procedure TPolyBuilder.deleteChain;
var
  pSeg: PSegDesc;
begin
  if isEmpty then
    exit;
  pSeg := nil;
  while true do begin //we can skip IsEmpty check - r has at least one segment
    pSeg := dst.delete();
    if (pSeg.pNode1^.id = first1) then
      break //we find the beginning
    else
      freeSeg(pSeg); //delete and try prev
    dst.prev(); //if pSeg.pNode1^.id<>firstId then we have at least one segment in list
  end;
  freeSeg(pSeg);
  if not dst.isEmpty() then begin
    dst.prev();
  end;
end;

function TPolyBuilder.isClosedPoly: boolean;
begin
  result := (not isEmpty) and (first1 = last2);
end;

end.

