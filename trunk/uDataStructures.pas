unit uDataStructures;

interface

type

  PsllItem = ^TsllItem;
  TsllItem = record
    next: PsllItem;
    data: pointer
  end;

  PdllItem = ^TdllItem;
  TdllItem = record
    next, prev: PdllItem;
    data: pointer
  end;

  TSingleLinkedList = class
  protected
    fCur, fRoot: PsllItem;
    function getBookmark: pointer;
    procedure setBookmark(const value: pointer);
    function getData: pointer;
    procedure setData(const value: pointer);
  public
    destructor destroy; override;
    function hasNext(): boolean;
    function isEmpty(): boolean;
    function next(): pointer;
    function first(): pointer;
    procedure clear();
    //current element not changed
    procedure insertAfter(aData: pointer);
    procedure insertFirst(aData: pointer);
    procedure reverse();
    //next after delete element become current
    function deleteFirst(): pointer;
    function deleteNext(): pointer;
    property data: pointer read getData write setData;
    property bookmark: pointer read getBookmark write setBookmark;
  end;

  TDualLinkedRing = class
  private
    function getBookmark: pointer;
    procedure setBookmark(const value: pointer);
  protected
    fCur, fRoot: PdllItem;
    function getData: pointer;
    procedure setData(const value: pointer);
  public
    destructor destroy; override;
    function hasNext(): boolean;
    function hasPrev(): boolean;
    function isEmpty(): boolean;
    function next(): pointer;
    function prev(): pointer;
    function first(): pointer;
    //append list A before current element.
    //Example:
    //self=(a,b,C,d) C-current a-first
    //A=(e,F,g) F-current d-first
    //result=(a,b,f,g,e,C,d) C-current a-first
    //List A after appending cleared and freed.
    procedure appendBefore(var a:TDualLinkedRing);
    procedure clear();
    procedure insertAfter(aData: pointer);
    procedure insertBefore(aData: pointer);
    procedure insertFirst(aData: pointer);
    procedure insertLast(aData: pointer);
    function deleteFirst(): pointer;
    function deleteLast(): pointer;
    function delete(): pointer;
    property data: pointer read getData write setData;
    property bookmark: pointer read getBookmark write setBookmark;
  end;

implementation

{ TSingleLinkedList }

procedure TSingleLinkedList.clear;
begin
  while assigned(fRoot) do
    deleteFirst();
end;

function TSingleLinkedList.deleteNext: pointer;
var
  p: PsllItem;
begin
  result := nil;
  if assigned(fCur) then begin
    p := fCur.next;
    if assigned(p) then begin
      result := p.data;
      fCur.next := p.next;
      dispose(p);
    end;
  end;
end;

function TSingleLinkedList.deleteFirst: pointer;
var
  p: PsllItem;
begin
  p := fRoot;
  if fCur = p then
    fCur := p.next;
  fRoot := p.next;
  result := p.data;
  dispose(p);
end;

destructor TSingleLinkedList.destroy;
begin
  clear();
  inherited;
end;

function TSingleLinkedList.getData: pointer;
begin
  result := fCur.data;
end;

function TSingleLinkedList.hasNext: boolean;
begin
  result := assigned(fCur) and assigned(fCur.next);
end;

procedure TSingleLinkedList.insertAfter(aData: pointer);
var
  p: PsllItem;
begin
  new(p);
  p.data := aData;
  if not assigned(fRoot) then begin
    fRoot := p;
    fCur := p;
    p.next := nil;
  end
  else begin
    p.next := fCur.next;
    fCur.next := p;
  end;
end;

procedure TSingleLinkedList.insertFirst(aData: pointer);
var
  p: PsllItem;
begin
  new(p);
  p.next := fRoot;
  fRoot := p;
  if not assigned(fCur) then
    fCur := p;
end;

function TSingleLinkedList.next: pointer;
begin
  fCur := fCur.next;
  if assigned(fCur) then
    result := fCur.data
  else
    result := nil;
end;

function TSingleLinkedList.first: pointer;
begin
  fCur := fRoot;
  if assigned(fRoot) then
    result := fRoot.data
  else
    result := nil;
end;

procedure TSingleLinkedList.reverse;
var
  p, c, n: PsllItem;
begin
  c := fRoot;
  p := nil;
  while assigned(c) do begin
    n := p.next;
    c.next := p;

    p := c;
    c := n;
  end;
  fRoot := p;
end;

procedure TSingleLinkedList.setData(const value: pointer);
begin
  fCur.data := value;
end;

function TSingleLinkedList.isEmpty: boolean;
begin
  result := not assigned(fRoot);
end;

function TSingleLinkedList.getBookmark: pointer;
begin
  result := fCur;
end;

procedure TSingleLinkedList.setBookmark(const value: pointer);
begin
  fCur := value;
end;

{ TDualLinkedRing }

procedure TDualLinkedRing.clear;
begin
  while assigned(fRoot) do
    deleteFirst();
end;

function TDualLinkedRing.delete: pointer;
var
  p: PdllItem;
begin
  p := fCur;
  if p = fRoot then begin
    result := deleteFirst();
  end
  else begin
    result := p.data;
    fCur := p.next;
    p.next.prev := p.prev;
    p.prev.next := p.next;
    dispose(p);
  end;
end;

function TDualLinkedRing.deleteFirst: pointer;
var
  p: PdllItem;
begin
  p := fRoot;
  if fCur = p then
    fCur := p.next;
  if p.next = p then begin
    //one-item list
    fRoot := nil;
    fCur := nil;
  end
  else begin
    //move to second item
    if fCur = p then
      fCur := p.next;
    //remove from list
    p.next.prev := p.prev;
    p.prev.next := p.next;
    fRoot := p.next;
  end;
  result := p.data;
  dispose(p);
end;

function TDualLinkedRing.deleteLast: pointer;
begin
  fRoot := fRoot.prev;
  result := deleteFirst();
end;

destructor TDualLinkedRing.destroy;
begin
  clear();
  inherited;
end;

function TDualLinkedRing.getBookmark: pointer;
begin
  result := fCur;
end;

function TDualLinkedRing.getData: pointer;
begin
  result := fCur.data;
end;

function TDualLinkedRing.hasNext: boolean;
begin
  result := assigned(fCur) and (fCur.next <> fRoot);
end;

function TDualLinkedRing.hasPrev: boolean;
begin
  result := assigned(fCur) and (fCur <> fRoot);
end;

procedure TDualLinkedRing.insertAfter(aData: pointer);
var
  p: PdllItem;
begin
  new(p);
  p.data := aData;
  if not assigned(fRoot) then
    fRoot := p;
  if not assigned(fCur) then begin
    fCur := p;
    p.next := p;
  end;
  p.prev := fCur;
  p.next := fCur.next;
  p.next.prev := p;
  p.prev.next := p;
end;

procedure TDualLinkedRing.insertBefore(aData: pointer);
var
  p: PdllItem;
begin
  new(p);
  p.data := aData;
  if not assigned(fRoot) then
    fRoot := p;
  if not assigned(fCur) then begin
    fCur := p;
    p.prev := p;
  end;
  p.next := fCur;
  p.prev := fCur.prev;
  p.next.prev := p;
  p.prev.next := p;
end;

procedure TDualLinkedRing.insertFirst(aData: pointer);
var
  p: PdllItem;
begin
  new(p);
  p.data := aData;
  if not assigned(fRoot) then begin
    fRoot := p;
    p.next := p;
    p.prev := p;
  end;
  if not assigned(fCur) then
    fCur := p;
  p.next := fRoot.next;
  p.prev := fRoot.prev;
  p.next.prev := p;
  p.prev.next := p;
end;

procedure TDualLinkedRing.insertLast(aData: pointer);
begin
  insertFirst(aData);
  fRoot := fRoot.next;
end;

function TDualLinkedRing.isEmpty: boolean;
begin
  result := not assigned(fRoot);
end;

function TDualLinkedRing.next: pointer;
begin
  fCur := fCur.next;
  result := fCur.data;
end;

function TDualLinkedRing.prev: pointer;
begin
  fCur := fCur.prev;
  result := fCur.data;
end;

function TDualLinkedRing.first: pointer;
begin
  fCur := fRoot;
  result := fRoot.data;
end;

procedure TDualLinkedRing.setBookmark(const value: pointer);
begin
  fCur := value;
end;

procedure TDualLinkedRing.setData(const value: pointer);
begin
  fCur.data := value;
end;

procedure TDualLinkedRing.appendBefore(var a: TDualLinkedRing);
var
  selfPrev,aPrev:PdllItem;
begin
  if not assigned(fCur) then
    fCur:=fRoot;
  if not assigned(fCur) then begin
    //empty self-list. append a-list at root
    fRoot:=a.fRoot;
    fCur:=a.fCur;
    a.fRoot:=nil;
  end
  else begin
    //self not empty
    if not assigned(a.fCur) then
      a.fCur:=a.fRoot;
    if assigned(a.fCur) then begin
      //a-list not empty.
      aPrev:=a.fCur.prev;
      selfPrev:=fCur.prev;
      //update forward-direction links
      selfPrev.next:=a.fCur;
      aPrev.next:=fCur;
      //update backward-direction links
      fCur.prev:=aPrev;
      a.fCur.prev:=selfPrev;
    end;
    a.fRoot:=nil;
  end;
  a.free;
  a:=nil;
end;

end.

