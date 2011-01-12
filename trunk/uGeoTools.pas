unit uGeoTools;

interface
uses Math, SysUtils, Variants, uInterfaces, uOSMCommon, uModule;

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
  public
    class function degToInt(const deg: double): integer;
    class function IntToDeg(const i: integer): double;
    class function fastCosDeg(const degAngle:double):double;
    function clone(): TGTShape; override;
    function fastDistM(pt:TGTPoint):double;
    function fastDistSqrM(pt:TGTPoint):double;
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
    //returns:
    //0 - pt outside
    //1 - pt is on bound
    //2 - pt is inside
    function clone: TGTShape; override;
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

const
  geoToolsClassGUID: TGUID = '{DF3ADB6E-3168-4C6B-9775-BA46C638E1A2}';
  //constants for TMultiPoly bbox hashing
  hashBits = 8;
  hashSize = 1 shl hashBits;

type

  TGTRefItem = record
    RefId: int64;
    RefRole: WideString;
    RefType: TRefType;
  end;

  TGTPoly = class(TGTRect)
  protected
    fPoints: array of TGTPoint;
    fCount: integer;
    function get_capacity: integer;
    procedure set_capacity(const Value: integer);
    procedure addExtraNode();
  public
    destructor destroy; override;
    function clone(): TGTShape; override;
    function isIn(const pt: TGTPoint): integer; override;
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
    pt1,pt2:TGTPoint;
  public
    destructor destroy;override;
  published
    function createPoly(): OleVariant;
    function distance(const node1,node2:OleVariant):double;
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

    function isAllResolved(): boolean;

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
    function getIntersection(const aMap, aWay: OleVariant): OleVariant;
    //returns true if node is in poly (including border)
    function isIn(const aNode: OleVariant): boolean;
    //returns bounding box for poly. Returns SafeArray of four double variants
    // for N,E,S and W bounds respectively. If poly is not resolved then
    // exception raised.
    function getBBox: OleVariant;
  end;

  { TGeoTools }

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
  if not assigned(pt1) then pt1:=TGTPoint.Create();
  if not assigned(pt2) then pt2:=TGTPoint.Create();
  pt1.assignNode(node1);
  pt2.assignNode(node2);
  result:=pt1.fastDistM(pt2);
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
  setlength(fRefList, i + n);
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
    VarArrayUnlock(members);
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
    setlength(fRefList, i + j - 1);
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
  setlength(fRefList, i + n);
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
    VarArrayUnlock(members);
  end;
end;

{ TGTPoint }
const
  degint = -256; //we need to add/subtract latitudes, so degint must be less then -180

class function TGTPoint.degToInt(const deg: double): integer;
const
  mply: double = low(integer) / degint;
asm
  fld deg
  push eax
  fmul mply
  fistp dword[esp]
  pop eax
end;

class function TGTPoint.IntToDeg(const i: integer): double;
const
  mply: double = degint / low(integer);
asm
  push i
  fild dword[esp]
  fmul mply
  pop eax
end;

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

class function TGTPoint.fastCosDeg(const degAngle: double): double;
const
//cos(x)=2.656575016·10^(-9)·x^4 + 1.267593379·10^(-7)·x^3 - 0.0001570353458·x^2 + 6.299155612·10^(-5)·x + 0.9998189607
//
  a4:single=2.656575016E-9;
  a3:single=1.267593379E-7;
  a2:single=-0.0001570353458;
  a1:single=6.299155612E-5;
  a0:single=0.9998189607;
asm
  fld degAngle     //x
  fabs
  fld a4           //x a4
  fmul st(0),st(1) //x x*a4
  fadd a3          //x x*a4+a3
  fmul st(0),st(1) //x x^2*a4+x*a3
  fadd a2
  fmul st(0),st(1)
  fadd a1
  fmulp st(1),st(0)
  fadd a0
end;

function TGTPoint.fastDistSqrM(pt: TGTPoint): double;
const
  degToM2:single=1852.0*60*1852.0*60;
//var
//  la1,la2,lo1,lo2:single;
//  d:double;
//begin
//  la1:=lat;
//  la2:=pt.lat;
//  lo1:=lon;
//  lo2:=pt.lon;
//  result:=sqrt( sqr( (lo1-lo2)*fastCosDeg((la1+la2)/2) ) + sqr(la1-la2) )*degToM;
asm
  push esi
  push edi
  mov esi,eax
  mov edi,edx

  mov edx,TGTPoint(esi).fx
  sub edx,TGTPoint(edi).fx
  call TGTPoint.IntToDeg//lo1-lo2

  mov esi,TGTPoint(esi).fy
  mov edi,TGTPoint(edi).fy
  mov edx,edi
  add edx,esi
  rcr edx,1
  call TGTPoint.IntToDeg//lo1-lo2 la1+la2/2

  sub esp,8
  fstp qword ptr [esp]
  call TGTPoint.fastCosDeg//lo1-lo2 cos(...)
  fmulp st(1),st(0)     //(lo1-lo2)*cos(..)
  mov edx,edi
  fmul st(0),st(0)      //sqr(cos...)
  sub edx,esi
  call TGTPoint.IntToDeg//sqr(cos..) la1-la2
  fmul st(0),st(0)      //sqr(cos) sqr(la)
  pop edi
  faddp st(1),st(0)     //sqr+sqr
  pop esi
  fmul degToM2
end;

function TGTPoint.fastDistM(pt: TGTPoint): double;
asm
  call TGTPoint.fastDistSqrM
  fsqrt
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

function TGTPoly.clone: TGTShape;
var
  i: integer;
  p: TGTPoly;
begin
  p := TGTPoly.create();
  p.fCount := fCount;
  setlength(p.fPoints, fCount);
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
  setlength(fPoints, Value);
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
  setlength(newPoints, count * 2);
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
  setlength(newPoints, count * 2);
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

function TGTRect.clone: TGTShape;
var
  r:TGTRect;
begin
  r:=TGTRect.create();
  r.left:=left;
  r.right:=right;
  r.top:=top;
  r.bottom:=bottom;
  result:=r;
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
begin
  //add object to inList
  if varIsType(aMapObject, varDispatch) then begin
    s := aMapObject.getClassName();
    if (s = 'Relation') or (s = 'Way') then begin
      putList(srcList, VarAsType(aMapObject, varDispatch), -1);
      clearInternalLists();
    end
    else begin
      raise EConvertError.create(toString() + 'addObject: invalid object');
    end;
  end;
end;

procedure TMultiPoly.clearList(var list: TMultiPolyList);
begin
  setlength(list.items, 0);
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
  setlength(simplePolyList, 0);
  for i := 0 to high(optimizedPolyList) do begin
    if assigned(optimizedPolyList[i]) then
      freeAndNil(optimizedPolyList[i]);
  end;
  setlength(optimizedPolyList, 0);
  setlength(optimizedPolyParent, 0);
  setlength(optimizedPolyHash, 0);
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
      if not assigned(poly) then
        continue;
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
  result := VarArrayOf([TGTPoint.IntToDeg(n), TGTPoint.IntToDeg(e), TGTPoint.IntToDeg(s),
    TGTPoint.IntToDeg(w)]);
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
    setlength(list.items, nl);
  end;
end;

function TMultiPoly.isIn(const aNode: OleVariant): boolean;
var
  xhash, yhash: cardinal;
  i: integer;
  pt: TGTPoint;
  p: TGTPoly;
  oplen: integer;
  popi: pinteger;
begin
  if not isAllResolved() then
    raise EConvertError.create(toString() +
      '.isIn : not all references resolved or polygons closed.');
  result := false;
  pt := TGTPoint.create();
  try
    pt.assignNode(aNode);
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
                  result := true;
                  break;
                end;
              2: begin
                  result := not result;
                end;
            end;
          end;
        2: result := not result;
      end;
      inc(popi);
    end;
  finally
    freeAndNil(pt);
  end;
end;

procedure TMultiPoly.putList(var list: TMultiPolyList;
  const obj: OleVariant; parent: integer);
var
  pi: PMultiPolyListItem;
begin
  growList(list);
  pi := @list.items[list.count];
  pi.obj := obj;
  pi.parentIdx := parent;
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
    v, ml, newObj: OleVariant;
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
              newObj := srcMap.getRelation(id);
              if varIsType(newObj, varDispatch) then
                putList(relationList, VarAsType(newObj, varDispatch), i)
              else begin
                addNotResolved('relation', id);
                result := false;
              end;
            end
            else if (s = 'way') then begin
              newObj := srcMap.getWay(id);
              if varIsType(newObj, varDispatch) then
                putList(wayList, VarAsType(newObj, varDispatch), i)
              else begin
                addNotResolved('way', id);
                result := false;
              end;
            end
          end;
        finally
          VarArrayUnlock(ml);
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
    v, ml, newObj: OleVariant;
    pv: POleVariant;
    id: int64;
    pwd: PWayDescItem;
  begin
    result := true;
    setlength(wayMergeList.items, wayList.count);
    wayMergeList.count := 0;
    pwd := @wayMergeList.items[0];
    //resolve ways into nodes.
    for i := 0 to wayList.count - 1 do begin
      v := wayList.items[i].obj;
      ml := v.nodes;
      mlen := varArrayLength(ml);
      if mlen < 2 then continue; //skip zero- or one-node ways
      pwd.way.count := 0;
      pv := VarArrayLock(ml);
      try
        pwd.id0 := pv^;
        inc(wayMergeList.count);
        while (mlen > 0) do begin
          id := pv^;
          inc(pv);
          dec(mlen);
          newObj := srcMap.getNode(id);
          if varIsType(newObj, varDispatch) then
            putList(pwd^.way, VarAsType(newObj, varDispatch), i)
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
        VarArrayUnlock(ml);
      end;
    end;
  end;

  function mergeWays(): boolean;

    function merge(pwd1, pwd2: PWayDescItem): boolean; //returns true if ways merged
      //merge & reorder nodeList.
      //Duplicates are preserved (0,1,2)+(2,3,0)=>(0,1,2,2,3,0)

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
        setlength(pwd1.way.items, pwd1.way.count);
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
    setlength(simplePolyList, wayMergeList.count);
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
    setlength(nodeList.items, sz);
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
    fNotResolved.setAll(v, v, v);
    createNotClosed();
    fNotClosed.setAll(v, v, v);
  end;

begin
  clearInternalLists();
  InitErrorLists();
  sortSrcObjByType();
  result := resolveRelations();
  if not result then
    exit;
  result := resolveWays();
  if not result then
    exit;
  result := mergeWays(); //do not merge ways if some nodes not resolved!
  if not result then
    exit;
  makeNodeList();
  buildOptimizedPolyList();
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
  nCnt, nOpt, maxCnt, maxIdx, i: integer;
begin
  nCnt := 0;
  for i := 0 to high(simplePolyList) do begin
    inc(nCnt, simplePolyList[i].count);
  end;
  nOpt := round(sqrt(nCnt));
  pCnt := length(simplePolyList);
  if (nOpt < pCnt)or(nCnt<100) then
    nOpt := pCnt;
  setlength(optimizedPolyList, nOpt);
  setlength(optimizedPolyParent, nOpt);
  for i := 0 to pCnt - 1 do begin
    optimizedPolyList[i] := simplePolyList[i].clone() as TGTPoly;
    optimizedPolyParent[i] := i;
  end;
  if (nOpt=pCnt) then
    //no optimization needed
    exit;
  while (pCnt < nOpt) do begin
    maxCnt := 0;
    maxIdx := 0;
    for i := 0 to pCnt - 1 do begin
      if maxCnt < optimizedPolyList[i].count then begin
        maxCnt := optimizedPolyList[i].count;
        maxIdx := i;
      end;
    end;
    split(maxIdx);
  end;
end;

procedure TMultiPoly.buildOptimizedPolyHash;

  procedure putPoly(const x, y, p: cardinal);
  var
    l: integer;
  begin
    if cardinal(length(optimizedPolyHash[x])) <= y then
      setlength(optimizedPolyHash[x], y + 1);
    l := length(optimizedPolyHash[x][y]);
    setlength(optimizedPolyHash[x][y], l + 1);
    optimizedPolyHash[x][y][l] := p;
  end;
var
  xidx, yidx, polyidx: integer;
  poly: TGTPoly;
  xminhash, xmaxhash, yminhash, ymaxhash: cardinal;
begin
  //hash clean up
  setlength(optimizedPolyHash, 0);
  setlength(optimizedPolyHash, hashSize);
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

function TMultiPoly.getIntersection(const aMap,
  aWay: OleVariant): OleVariant;
var
  wayPoints: array of TGTPoint;
  wayIndexes: array of integer;
  kArray:array of double;
  nk:integer;

  procedure findIntersection(const node1, node2: OleVariant; idx1: integer);
  var
    i,isIn1,isIn2: integer;
    dx21,dxba,dy21,dyba,dx1a,dy1a,sa2b1,k,t:double;
    gtp: TGTPoly;
    pt1, pt2,ptA,ptB,ptX: TGTPoint;
    bRect1,bRectA:TGTRect;
  begin
    gtp := nil;
    bRect1:=nil;
    bRectA:=nil;
    ptX:= nil;
    isIn1:=0;
    isIn2:=0;
    pt1 := TGTPoint.create();
    pt2 := TGTPoint.create();
    try
      pt1.assignNode(node1);
      pt2.assignNode(node2);
      for i := 0 to high(simplePolyList) do begin
        gtp := simplePolyList[i];
        isIn1:=gtp.isIn(pt1);
        isIn2:=gtp.isIn(pt2);
        if (isIn1 = 0) xor (isIn2 = 0) then
          break;
        gtp := nil;
      end;
      if not assigned(gtp) or (gtp.count<2) then exit;
      bRect1:=TGTRect.create();
      bRect1.updateBoundRect(pt1);
      bRect1.updateBoundRect(pt2);
      dx21:=pt2.x-pt1.x;
      dy21:=pt2.y-pt1.y;
      bRectA:=TGTRect.create();
      ptB:=gtp.fPoints[gtp.count-1];
      setlength(kArray,4);
      nk:=0;
      if(isIn1=1)and(isIn2=0)then begin
        kArray[nk]:=0;inc(nk);
      end else if(isIn1=0)and(IsIn2=1) then begin
        kArray[nk]:=1;inc(nk);
      end;
      for i:=gtp.count-2 downto 0 do begin
        ptA:=gtp.fPoints[i];
        bRectA.resetBounds();
        bRectA.updateBoundRect(ptA);
        bRectA.updateBoundRect(ptB);
        if (bRect1.left<=brecta.right) and (brecta.left<=brect1.right) and
         (bRect1.bottom<=brecta.top) and (brecta.bottom<=brect1.top) then begin
          //find point
          dxba:=ptB.x-ptA.x;
          dyba:=ptB.y-ptA.y;
          sa2b1:=dyba*dx21-dxba*dy21;
          if round(sa2b1)<>0 then begin
            dx1a:=pt1.x-ptA.x;
            dy1a:=pt1.y-ptA.y;
            sa2b1:=1/sa2b1;
            k:=(dxba*dy1a-dyba*dx1a)*sa2b1;
            t:=(dx21*dy1a-dy21*dx1a)*sa2b1;
            if (k>=0)and(k<=1)and(t>=0)and(t<=1) then begin
              if length(kArray)<=nk then setlength(kArray,nk*2);
              kArray[nk]:=k;
              inc(nk);
            end;
          end;
        end;
        ptB:=ptA;
      end;
      while nk>0 do begin
        k:=kArray[0];
        for i:=1 to nk-1 do begin
          if k>=kArray[i] then begin
            k:=kArray[i];
          end
          else begin
            kArray[i-1]:=kArray[i];
            kArray[i]:=k;
          end;
        end;
        dec(nk);
        ptX:=TGTPoint.Create();
        ptX.x:=pt1.x+round(k*dx21);
        ptX.y:=pt1.y+round(k*dy21);
        setlength(wayPoints,length(wayPoints)+1);
        setlength(wayIndexes,length(wayPoints));
        wayPoints[high(wayPoints)]:=ptX;
        wayIndexes[high(wayPoints)]:=idx1;
        ptX:=nil;
      end;
    finally
      freeAndNil(pt1);
      freeAndNil(pt2);
      freeAndNil(ptX);
      freeAndNil(bRect1);
      freeAndNil(bRectA);
    end;
  end;

const
  minPtDist=0.1;
  minPtDistSqr=minPtDist*minPtDist;
var
  wayNodes, curNode, prevNode: OleVariant;
  pv: PVariant;
  prevIsIn, curIsIn: boolean;
  i,j, nWayNodes: integer;
  p1,p2:TGTPoint;
begin
  wayNodes := aWay.nodes;
  if (not varIsType(wayNodes, varVariant or varArray)) or (VarArrayDimCount(wayNodes) <> 1) then
    raise EConvertError.create(toString() + '.getIntersection: invalid way');
  nWayNodes := varArrayLength(wayNodes);
  result := VarArrayCreate([0, -1], varVariant);
  if (nWayNodes < 2) then begin
    exit;
  end;
  nk:=0;
  setlength(kArray,8);
  try
    pv := VarArrayLock(wayNodes);
    prevIsIn := false;
    for i := 0 to nWayNodes - 1 do begin
      curNode := aMap.getNode(pv^);
      if not varIsType(curNode, varDispatch) then
        raise EInOutError.create(toString() + '.getIntersection: node ' + inttostr(pv^) +
          ' not found');
      inc(pv);
      if i = 0 then begin
        prevIsIn := isIn(curNode);
        prevNode := curNode;
        continue;
      end;
      curIsIn := isIn(curNode);
      if curIsIn xor prevIsIn then
        findIntersection(prevNode, curNode, i - 1);
      prevIsIn := curIsIn;
      prevNode := curNode;
    end;
    j:=high(wayPoints);
    for i:=1 to high(wayPoints) do begin
      p1:=wayPoints[i-1];
      p2:=wayPoints[i];
      if not (assigned(p1) and assigned(p2)) then continue;
      if p1.fastDistSqrM(p2)<minPtDistSqr then begin
        freeandnil(wayPoints[i-1]);
        freeandnil(wayPoints[i]);
        dec(j,2);
      end;
    end;
    result:=VarArrayCreate([0,j],varVariant);
    j:=0;
    for i:=0 to high(wayPoints) do begin
      p1:=wayPoints[i];
      if not assigned(p1) then continue;
      curNode:=aMap.createNode();
      curNode.lat:=p1.lat;
      curNode.lon:=p1.lon;
      curNode.tags.setByKey('osman:idx',wayIndexes[i]);
      result[j]:=curNode;
      inc(j);
    end;
  finally
    VarArrayUnlock(wayNodes);
    for i := 0 to high(wayPoints) do
      if assigned(wayPoints[i]) then
        freeAndNil(wayPoints[i])
      else
        break;
  end;
end;

initialization
  uModule.OSManRegister(TGeoTools, geoToolsClassGUID);
end.

