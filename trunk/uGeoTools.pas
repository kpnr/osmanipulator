unit uGeoTools;

interface
uses SysUtils,Variants, uInterfaces, uOSMCommon, uModule;

type
  TGTShape = class(TObject)
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
    property x: integer read fx write fx;
    property y: integer read fy write fy;
    property lat: double read get_lat write set_lat;
    property lon: double read get_lon write set_lon;
  end;

  TGTRect = class(TGTShape)
  protected
    fLeft, fRight, fTop, fBottom: integer;
    class function between(const v, min, max: integer): boolean;
    function get_height:cardinal;
    function get_width:cardinal;
    procedure resetBounds();
  public
    constructor create();
    function isIn(const pt: TGTPoint): boolean; virtual;
    property left: integer read fLeft write fLeft;
    property right: integer read fRight write fRight;
    property top: integer read fTop write fTop;
    property bottom: integer read fBottom write fBottom;
    property width:cardinal read get_width;
    property height:cardinal read get_height;
  end;

implementation

const
  geoToolsClassGUID: TGUID = '{DF3ADB6E-3168-4C6B-9775-BA46C638E1A2}';
  //constants for TMultiPoly bbox hashing
  hashBits=8;
  hashSize=1 shl hashBits;

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
    hasExtraNode: boolean;
    function get_capacity: integer;
    procedure set_capacity(const Value: integer);
    procedure addExtraNode();
    procedure updateBoundRect(const pt:TGTPoint);
  public
    destructor destroy; override;
    function isIn(const pt: TGTPoint): boolean; override;
    //if x outside poly nil returned, else returns right half of poly
    function splitX(x:integer):TGTPoly;
    //if y outside poly nil returned, else returns top half of poly
    function splitY(y:integer):TGTPoly;
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
  published
    function createPoly(): OleVariant;
  end;

  TMultiPoly = class(TOSManObject, IMultiPoly)
  protected
    inList: TGTShapeArray;
    hash:array of array of TGTShapeArray;
    fUnResolved: TRefList;
    allResolved: boolean;
    class function intToHash(i:integer):cardinal;
    procedure putRelation(const OSMRelation: OleVariant);
    procedure putWay(const osmWay: OleVariant);
    procedure clearInList();
    procedure createUnresolved();
    procedure optimize();
    procedure buildHash();
  public
    destructor destroy; override;
  published
    //add MapObject to polygon. Nodes not allowed,
    //in Relation node-members ignored
    procedure addObject(const aMapObject: OleVariant);
    //returns true if all relations/way/nodes resolved, false otherwise
    function resolve(const srcMap:OleVariant): boolean;
    //IRefList of unresolved references
    function getUnresolved(): OleVariant;
    //returns true if node is in poly (including border)
    function isIn(const aNode: OleVariant): boolean;
    function getBBox():OleVariant;
  end;

  { TGeoTools }

function TGeoTools.createPoly: OleVariant;
begin
  result := TMultiPoly.create() as IDispatch;
end;

{ TMultiPoly }

procedure TMultiPoly.addObject(const aMapObject: OleVariant);
var
  s: WideString;
begin
  //add object to inList
  if varIsType(aMapObject, varDispatch) then begin
    s := aMapObject.getClassName;
    if (s = 'Relation') then begin
      putRelation(aMapObject);
      exit;
    end
    else if s = 'Way' then begin
      putWay(aMapObject);
      exit;
    end;
  end;
  raise EConvertError.create(toString() + 'addObject: invalid object');
end;

function TMultiPoly.getBBox: OleVariant;
var
  n,e,s,w,t:integer;
  i:integer;
  poly:TGTPoly;
begin
  if not allResolved then
    raise EConvertError.Create(toString()+'.bbox: polygon must be resolved');
  if length(inList)>0 then begin
    n:=low(integer);
    s:=high(integer);
    e:=low(integer);
    w:=high(integer);
    for i:=0 to high(inList) do begin
      poly:=TGTPoly(inList[i]);
      t:=poly.left;
      if t<w then w:=t;
      t:=poly.right;
      if e<t then e:=t;
      t:=poly.top;
      if n<t then n:=t;
      t:=poly.bottom;
      if t<s then s:=t;
    end;
  end
  else begin
    n:=0;e:=0;s:=0;w:=0;
  end;
  result:=VarArrayOf([TGTPoint.intToDeg(n),TGTPoint.intToDeg(e),TGTPoint.intToDeg(s),TGTPoint.intToDeg(w)]);
end;

procedure TMultiPoly.buildHash;
  procedure putPoly(const x,y:cardinal;const p:TGTPoly);
  var
    l:integer;
  begin
    if cardinal(length(hash[x]))<=y then
      setlength(hash[x],y+1);
    l:=length(hash[x][y]);
    setLength(hash[x][y],l+1);
    hash[x][y][l]:=p;
  end;
var
  xidx,yidx,polyidx:integer;
  poly:TGTPoly;
  xminhash,xmaxhash,yminhash,ymaxhash:cardinal;
begin
  //hash clean up
  setLength(hash,0);
  setLength(hash,hashSize);
  for polyidx:=0 to high(inList) do begin
    poly:=TGTPoly(inList[polyidx]);
    xminhash:=intToHash(poly.left);
    xmaxhash:=intToHash(poly.right);
    yminhash:=intToHash(poly.bottom);
    ymaxhash:=intToHash(poly.top);
    for xidx:=xminhash to xmaxhash do begin
      for yidx:=yminhash to ymaxhash do begin
        putPoly(xidx,yidx,poly);
      end;
    end;
  end;
end;

procedure TMultiPoly.clearInList;
var
  i: integer;
begin
  for i := 0 to high(inList) do begin
    freeAndNil(inList[i]);
  end;
  setLength(inList, 0);
end;

procedure TMultiPoly.createUnresolved;
begin
  if not assigned(fUnResolved) then begin
    fUnResolved := TRefList.create();
    (fUnResolved as IDispatch)._AddRef();
  end;
end;

destructor TMultiPoly.destroy;
begin
  clearInList();
  if assigned(fUnResolved) then begin
    (fUnResolved as IDispatch)._Release();
    fUnResolved:=nil;
  end;
  inherited;
end;

function TMultiPoly.getUnresolved: OleVariant;
begin
  createUnresolved();
  result := fUnResolved as IDispatch;
end;

class function TMultiPoly.intToHash(i: integer): cardinal;
begin
  i:=i div (1 shl (32-hashBits));
  inc(i,hashSize div 2);
  result:=cardinal(i);
end;

function TMultiPoly.isIn(const aNode: OleVariant): boolean;
var
  i,xhash,yhash: integer;
  pt: TGTPoint;
  pl:TGTShapeArray;
  p:TGTPoly;
{$WARNINGS OFF}
begin
  if not allResolved then
    raise EConvertError.create(toString() + '.isIn : not all references resolved');
  result := false;
  pt := TGTPoint.create();
  try
    pt.lat := aNode.lat;
    pt.lon := aNode.lon;
    xhash:=intToHash(pt.fx);
    yhash:=intToHash(pt.fy);
    if length(hash[xhash])<=yhash then
      exit;
    pl:=hash[xhash][yhash];
    for i := 0 to high(pl) do begin
      //all refernces resolved, so all objects in list is TGTPoly
      p:=TGTPoly(pl[i]);
      result := result xor p.isIn(pt);
    end;
  finally
    freeAndNil(pt);
  end;
end;
{$WARNINGS ON}

procedure TMultiPoly.optimize;
var
  nCnt,nOpt,pCnt,i:integer;
  newInList:TGTShapeArray;

  procedure split(const pl:TGTPoly);
  begin
    if pl.width>pl.height then
      newInList[pCnt]:=pl.splitX(pl.left+integer(pl.width shr 1))
    else
      newInList[pCnt]:=pl.splitY(pl.bottom+integer(pl.height shr 1));
    if assigned(newInList[pCnt]) then
      inc(pCnt);
  end;

var
  maxCnt,maxIdx:integer;
begin
  nCnt:=0;
  for i:=0 to high(inList) do begin
    inc(nCnt,TGTPoly(inList[i]).count);
  end;
  nOpt:=round(sqrt(nCnt));
  pCnt:=length(inList);
  if (nCnt<100)or(pCnt>=nOpt) then
    //no optimization needed
    exit;
  setlength(newInList,nOpt);
  move(inList[0],newInList[0],pCnt*sizeof(newInList[0]));
  while (pCnt<nOpt) do begin
    maxCnt:=0;
    maxIdx:=0;
    for i:=0 to pCnt-1 do begin
      if maxCnt<TGTPoly(newInList[i]).count then begin
        maxCnt:=TGTPoly(newInList[i]).count;
        maxIdx:=i;
      end;
    end;
    split(TGTPoly(newInList[maxIdx]));
  end;
  setlength(newInList,pCnt);
  inList:=newInList;
end;

procedure TMultiPoly.putRelation(const OSMRelation: OleVariant);
var
  gr: TGTRelation;
begin
  //obj checked in addObject. obj is Relation
  gr := TGTRelation.create();
  gr.AddRelation(OSMRelation);
  setLength(inList, length(inList) + 1);
  inList[length(inList) - 1] := gr;
  allResolved := false;
end;

procedure TMultiPoly.putWay(const osmWay: OleVariant);
var
  gp: TGTWay;
begin
  //obj checked in addObject. obj is Way
  gp := TGTWay.create();
  gp.AddWay(osmWay);
  setLength(inList, length(inList) + 1);
  inList[length(inList) - 1] := gp;
  allResolved := false;
end;

function TMultiPoly.resolve(const srcMap:OleVariant): boolean;
var
  nn: integer;
  newInList: TGTShapeArray;

  procedure grow(const delta: cardinal);
  begin
    while cardinal(nn) + delta >= cardinal(length(newInList)) do
      setLength(newInList, length(newInList) * 2);
  end;

  procedure clearNotResolved();
  var
    v: OleVariant;
  begin
    //clear not resolved references list
    createUnresolved();
    v := VarArrayCreate([0, -1], varVariant);
    fUnResolved.setAll(v, v, v);
  end;

  procedure addNotResolved(const m: TGTRefItem);
  begin
    //add not resolved reference to list
    createUnresolved();
    fUnResolved.insertBefore(maxInt, refTypeToStr(m.RefType), m.RefId, m.RefRole);
  end;

  procedure resolveToWays();
  var
    doRepeat: boolean;
    m: TGTRefItem;
    gr: TGTRelation;
    gs: TGTShape;
    gw: TGTWay;
    v: OleVariant;
    i, j: integer;
  begin
    doRepeat := false;
    repeat
      clearNotResolved();
      for i := 0 to high(inList) do begin
        gs := inList[i];
        if gs is TGTRelation then begin
          //resolve relation to members
          gr := TGTRelation(gs);
          grow(gr.count);
          for j := 0 to gr.count - 1 do begin
            m := gr[j];
            case m.RefType of
              rtNode: ;
              rtWay: begin
                  //resolve way ref into way
                  v := srcMap.getWay(m.RefId);
                  if varIsType(v, varDispatch) then begin
                    gw := TGTWay.create();
                    gw.AddWay(v);
                    newInList[nn] := gw;
                    inc(nn);
                  end
                  else begin
                    addNotResolved(m);
                    allResolved := false;
                  end;
                end;
              rtRelation: begin
                  //resolve relation ref into relation
                  v := srcMap.getRelation(m.RefId);
                  if varIsType(v,varDispatch)then begin
                    if (v.tags.getByKey('type')<>'collection') then begin
                      grow(1);
                      gr := TGTRelation.create();
                      gr.AddRelation(v);
                      newInList[nn] := gr;
                      inc(nn);
                      doRepeat := true;
                    end;
                  end
                  else begin
                    addNotResolved(m);
                    allResolved := false;
                  end;
                end;
            else
              raise ERangeError.create(toString() + '.resolve: unknown ref type');
            end;
          end;
        end
        else begin
          //just copy
          grow(1);
          newInList[nn] := inList[i];
          inList[i] := nil;
          inc(nn);
        end;
      end;
    until not doRepeat;
  end;

  procedure mergeWays();
  var
    idx1, idx2: integer; //indexes of mergeing ways
    gs1, gs2: TGTShape;
    doRepeat: boolean;
  begin
    repeat
      idx1 := 0;
      doRepeat := false;
      while idx1 < nn - 1 do begin
        gs1 := newInList[idx1];
        if not (gs1 is TGTWay) then begin
          //it is not Way, try next
          inc(idx1);
          continue;
        end;
        idx2 := idx1 + 1;
        while idx2 < nn do begin
          gs2 := newInList[idx2];
          if not (gs2 is TGTWay) then begin
            inc(idx2);
            continue;
          end
          else begin
            //try to merge
            if TGTWay(gs1).merge(TGTWay(gs2)) then begin
              //gs1 now is old-gs1 + gs2, so delete gs2
              freeAndNil(gs2);
              newInList[idx2] := newInList[nn - 1];
              dec(nn);
              doRepeat := true;
            end
            else begin
              //gs1 and gs2 not "mergeable", try next
              inc(idx2);
            end;
          end;
        end;
        inc(idx1);
      end;
    until not doRepeat;
  end;

  procedure resolveToPoly();
  var
    i, j: integer;
    gp: TGTPoly;
    gw: TGTWay;
    vn: OleVariant;
    isResolved: boolean;
    m:TGTRefItem;
  begin
    gp := nil;
    try
      for i := 0 to nn - 1 do begin
        if not (newInList[i] is TGTWay) then
          continue;
        gw := TGTWay(newInList[i]);
        if gw.firstId <> gw.lastId then begin
        //not closed way - so not resolved
          allResolved:=false;
          m.RefId:=gw.id;
          m.RefRole:='not closed polygon';
          m.RefType:=rtWay;
          addNotResolved(m);
        end;
        gp := TGTPoly.create();
        gp.capacity := gw.count;
        isResolved := true;
        for j := 0 to gw.count - 1 do begin
          vn := srcMap.getNode(gw[j].RefId);
          if varIsType(vn, varDispatch) then begin
            if isResolved then
              gp.addNode(vn);
          end
          else begin
            isResolved := false;
            addNotResolved(gw[j]);
          end;
        end;
        if isResolved then begin
          freeAndNil(newInList[i]);
          newInList[i] := gp;
          gp := nil;
        end
        else begin
          allResolved := allResolved and isResolved;
          freeAndNil(gp);
        end;
      end;
    finally
      freeAndNil(gp);
    end;
  end;

var
  i: integer;
begin
  //resolve all dependencies
  allResolved := true;
  nn := 0;
  setLength(newInList, 4);
  try
    //recursive replace relations with ways
    resolveToWays();
    //now concat all posible ways
    mergeWays();
    //resolve node ref into nodes
    resolveToPoly();
    clearInList();
    setLength(newInList, nn);
    inList := newInList;
    setLength(newInList, 0);
    nn := -1;
  finally
    for i := 0 to nn do
      freeAndNil(newInList[i]);
    for i := 0 to high(inList) do
      allResolved := allResolved and (inList[i] is TGTPoly);
    result := allResolved;
  end;
  if allResolved then begin
    optimize();
    buildHash();
  end;
end;

{ TGTRefs }

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

{ TGTPoly }

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
  if hasExtraNode then begin
    //remove extra node
    dec(fCount);
    freeAndNil(fPoints[count]);
    hasExtraNode:=false;
  end;
  pt := TGTPoint.create;
  pt.lat := aNode.lat;
  pt.lon := aNode.lon;
  fPoints[fCount] := pt;
  inc(fCount);
  updateBoundRect(pt);
end;

procedure TGTPoly.addExtraNode;
begin
  hasExtraNode := true;
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

function TGTPoly.isIn(const pt: TGTPoint): boolean;
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
  xcase, ycase:byte;
  b1, b2: TGTPoint;
begin
  if not hasExtraNode then begin
    addExtraNode();
  end;
  result := inherited isIn(pt);
  if not result then exit;
  result := false;
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
    asm mov eax,pt; mov eax,TGTPoint(eax).fy; mov ecx,b1; cmp eax,TGTPoint(ecx).fy; setg cl; setl dl; lea ecx,[ecx+edx*4]; mov edx,b2; cmp eax,TGTPoint(edx).fy; setg dl; setl al; lea ecx,[ecx+edx*2]; lea ecx,[ecx+eax*8]; mov ycase,cl; end;
//    ycase := ord(b1.fy < pt.fy) + 2 * ord(b2.fy < pt.fy) +
//      4 * ord(b1.fy > pt.fy) + 8 * ord(b2.fy > pt.fy);
    //cases 5,7,10,11,13,14,15 are impossible
    //case 3 - no intersection
    //ycase=12 - no intersection
    case ycase of
      0: {y1==y==y2}
        case xcase of
          0, 1, 2, 4, 6, 8, 9: begin
              result := true;
              break;
            end;
        end;
      1: {y1<y==y2}
        case xcase of
          0, 1, 4: begin
              result := true;
              break;
            end;
          8, 9, 12: result := not result;
        end;
      2: {y2<y==y1}
        case xcase of
          0, 2, 8: begin
              result := true;
              break;
            end;
          4, 6, 12: result := not result;
        end;
      4: {y1>y=y2}
        case xcase of
          0, 1, 4: begin
              result := true;
              break;
            end;
        end;
      6, {y2<y<y1}
      9: {y1<y<y2}
        case xcase of
          0: begin
              result := true;
              break;
            end;
          4, 8, 12: begin
            result := not result;
          end;
          6, 9:
            case intersects(pt, b1, b2) of
              0: {no intersection};
              1: {on edge} begin
                  result := true;
                  break;
                end;
              2: {intersects}
                result := not result;
            end;
        end;
      8: {y1=y<y2}
        case xcase of
          0, 2, 8: begin
              result := true;
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

function approx(const x1,y1,x2,y2,x:integer):integer;
begin
  result:=round((1.0*y2-y1)/(1.0*x2-x1)*(1.0*x-x1)+y1);
end;

function TGTPoly.splitX(x: integer): TGTPoly;
var
  i,li,ri:integer;
  xcase:byte;
  rightPoly:TGTPoly;
  pt1,pt2,pt1b,pt2b:TGTPoint;
  newPoints:array of TGTPoint;
  procedure saveRight(const pt:TGTPoint);
  begin
    rightPoly.fPoints[ri]:=pt;
    rightPoly.updateBoundRect(pt);
    inc(ri);
  end;

  procedure saveLeft(const pt:TGTPoint);
  begin
    newPoints[li]:=pt;
    updateBoundRect(pt);
    inc(li);
  end;
begin
  result:=nil;
  if(x<=left)or(x>=right) then exit;
  if not hasExtraNode then
    addExtraNode;
  result:=TGTPoly.create();
  result.capacity:=count*2;
  rightPoly:=result;
  setLength(newPoints,count*2);
  li:=0;
  ri:=0;
  resetBounds();
  for i:=0 to count-2 do begin
    pt1:=fPoints[i];
    pt2:=fPoints[i+1];
    xcase:=ord(pt1.fx<=x)+2*ord(pt2.fx<=x);
    case xcase of
    0:{this point goes right poly}
      saveRight(pt1);
    1:{pt1 on left, pt2 on right}
      begin
        pt1b:=TGTPoint.Create();
        pt1b.fx:=x;
        pt1b.fy:=approx(pt1.fx,pt1.fy,pt2.fx,pt2.fy,x);
        pt2b:=TGTPoint.Create();
        pt2b.fx:=x+1;
        pt2b.fy:=approx(pt1.fx,pt1.fy,pt2.fx,pt2.fy,x+1);
        saveLeft(pt1);
        saveLeft(pt1b);
        saveRight(pt2b);
      end;
    2:{pt1 on right, pt2 on left}
      begin
        pt1b:=TGTPoint.Create();
        pt1b.fx:=x+1;
        pt1b.fy:=approx(pt1.fx,pt1.fy,pt2.fx,pt2.fy,x+1);
        pt2b:=TGTPoint.Create();
        pt2b.fx:=x;
        pt2b.fy:=approx(pt1.fx,pt1.fy,pt2.fx,pt2.fy,x);
        saveRight(pt1);
        saveRight(pt1b);
        saveLeft(pt2b);
      end;
    3:{keep this point left}
      saveLeft(pt1);
    end;
  end;
  fCount:=li;
  capacity:=li+1;
  move(newPoints[0],fPoints[0],sizeof(fPoints[0])*li);
  result.fCount:=ri;
  result.capacity:=ri+1;
  result.hasExtraNode:=false;
  hasExtraNode:=false;
end;

function TGTPoly.splitY(y: integer): TGTPoly;
var
  i,ti,bi:integer;
  ycase:byte;
  topPoly:TGTPoly;
  pt1,pt2,pt1b,pt2b:TGTPoint;
  newPoints:array of TGTPoint;
  procedure saveTop(const pt:TGTPoint);
  begin
    topPoly.fPoints[ti]:=pt;
    topPoly.updateBoundRect(pt);
    inc(ti);
  end;

  procedure saveBottom(const pt:TGTPoint);
  begin
    newPoints[bi]:=pt;
    updateBoundRect(pt);
    inc(bi);
  end;
begin
  result:=nil;
  if(y<=bottom)or(y>=top) then exit;
  if not hasExtraNode then
    addExtraNode;
  result:=TGTPoly.create();
  result.capacity:=count*2;
  topPoly:=result;
  setLength(newPoints,count*2);
  bi:=0;
  ti:=0;
  resetBounds();
  for i:=0 to count-2 do begin
    pt1:=fPoints[i];
    pt2:=fPoints[i+1];
    ycase:=ord(pt1.fy<=y)+2*ord(pt2.fy<=y);
    case ycase of
    0:{this point goes top poly}
      saveTop(pt1);
    1:{pt1 on bottom, pt2 on top}
      begin
        pt1b:=TGTPoint.Create();
        pt1b.fy:=y;
        pt1b.fx:=approx(pt1.fy,pt1.fx,pt2.fy,pt2.fx,y);
        pt2b:=TGTPoint.Create();
        pt2b.fy:=y+1;
        pt2b.fx:=approx(pt1.fy,pt1.fx,pt2.fy,pt2.fx,y+1);
        saveBottom(pt1);
        saveBottom(pt1b);
        saveTop(pt2b);
      end;
    2:{pt1 on top, pt2 on bottom}
      begin
        pt1b:=TGTPoint.Create();
        pt1b.fy:=y+1;
        pt1b.fx:=approx(pt1.fy,pt1.fx,pt2.fy,pt2.fx,y+1);
        pt2b:=TGTPoint.Create();
        pt2b.fy:=y;
        pt2b.fx:=approx(pt1.fy,pt1.fx,pt2.fy,pt2.fx,y);
        saveTop(pt1);
        saveTop(pt1b);
        saveBottom(pt2b);
      end;
    3:{keep this point bottom}
      saveBottom(pt1);
    end;
  end;
  fCount:=bi;
  capacity:=bi+1;
  move(newPoints[0],fPoints[0],sizeof(fPoints[0])*bi);
  result.fCount:=ti;
  result.capacity:=ti+1;
  result.hasExtraNode:=false;
  hasExtraNode:=false;
end;

procedure TGTPoly.updateBoundRect(const pt: TGTPoint);
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

{ TGTRect }

class function TGTRect.between(const v, min, max: integer): boolean;
begin
  result := (v >= min) and (v <= max);
end;

constructor TGTRect.create;
begin
  resetBounds();
  inherited;
end;

function TGTRect.get_height: cardinal;
begin
{$R-}
  result:=cardinal(fTop)-cardinal(fBottom)
end;

function TGTRect.get_width: cardinal;
begin
{$R-}
  result:=cardinal(fRight)-cardinal(fLeft);
end;

function TGTRect.isIn(const pt: TGTPoint): boolean;
begin
  result := between(pt.x, left, right) and between(pt.y, bottom, top);
end;

procedure TGTRect.resetBounds;
begin
  left := high(left);
  right := low(right);
  top := low(top);
  bottom := high(bottom);
end;

initialization
  uModule.OSManRegister(TGeoTools, geoToolsClassGUID);
end.

