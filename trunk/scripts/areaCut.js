//settings start
var bigMapFile='';
var smallMapFile='';
var exportFileName='';
var cutBound='';
var noImport=true;

var testDistance=1;//in meters
var testCloseSegmentsWarning=100;//in sq meters
var minPolyIntersetionArea=1;//in sq meters
var minPolySideRatio=0.001;//ratio=Area/(Perimeter^2)*16. Ratios for different shapes are:
	//sqare r=1
	//circle r=1.27
	//equal side triangle r=0.77
	//rectangle a=1m, b=2m r=0.89
	//rectangle a=1m, b=1km r=0.004
	//rectangle a=1m, b=4km r=0.001
//settings end
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

//global variables
var h=new (include('helpers.js'))();
var echo=h.echo;
var echot=h.bindFunc(h,h.echot);
//end global variables
//helpers part
//end of helpers part
function checkArgs(){
	function help(){
	echo('Command line options:\n\
 /src:"source_file_name.db3"\n\
 /dst:"dest_file_name.db3"\n\
 /xml:"dest_osm_file.osm" Make it empty string if need no export.\n\
 /bound:"way:1,relation:18"\n\
 /alreadyimported - do not import objects. Just cut map.');
	};
	var ar=WScript.arguments;
	if(!ar.length){
		help();
		return false;
	};
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('src'))bigMapFile=ar.item('src');
	if(ar.exists('dst'))smallMapFile=ar.item('dst');
	if(ar.exists('xml'))exportFileName=ar.item('xml')||'';
	if(ar.exists('bound'))cutBound=ar.item('bound');
	noImport=ar.exists('alreadyimported');
	echo('Use config:\nsrc='+bigMapFile+'\ndst='+smallMapFile+'\nxml='+exportFileName+'\nbound='+cutBound+'\nalreadyimported='+noImport);
	if(!(bigMapFile && smallMapFile && cutBound)){
		help();
		echo('\nInvalid arguments. Exiting');
		return false;
	};
	return true;
};

function IdIndexer(){
	var t=this;
	t.idHash={};
	t.data=undefined;
};

IdIndexer.prototype.reindex=function(){
	throw {name:'developer',message:'IdIndexer.reindex must be overriden'};
};

IdIndexer.prototype.nextIndex=function(idx){
	var t=this,b=idx.slice(0,-1),e=idx.slice(-1)[0]+1,a=t.indexToObject(b);
	if(e>=a.length)return false;
	//idx.splice(-1,1,e); modify argument
	b.push(e);
	return b;
};

//id, key, index, object conversions
IdIndexer.prototype.idToIndex=function(id){
	var t=this;
	return t.keyToIndex(t.idToKey(id));
};

IdIndexer.prototype.idToKey=function(id){
	return (''+id);
};

IdIndexer.prototype.indexToObject=function(index){
	var curD=this.data;
	for(var i=0; i<index.length; i++){
		curD=curD[index[i]];
	};
	return curD;
};

IdIndexer.prototype.keyToIndex=function(key){
	return this.idHash[key];
};

IdIndexer.prototype.keyToObject=function(key){
	var t=this,idx=t.keyToIndex(key),obj,okey,reindex=false;
	while(idx){
		obj=t.indexToObject(idx);
		okey=t.objectToKey(obj);
		reindex=reindex || (okey!=key);
		if(reindex)t.idHash[okey]=idx;
		if(okey==key){
			break;
		};
		idx=t.nextIndex(idx);
	};
	if(!idx)throw {name:'user', message:'IdIndexer.keyToObject: no such object'};
	return obj;
};

IdIndexer.prototype.objectToKey=function(obj){
	return this.idToKey(obj.id);
};

function BoundIndexer(osmanPoly){
	var t=this;
	t.constructor();
	if(arguments.length==0)return;
	t.poly=osmanPoly;
	t.data=osmanPoly.getPolygons().toArray();//[outers,inners]
	for(var i=0;i<t.data.length;i++){
		var s=t.data[i].toArray();
		t.data[i]=s;//[poly1,poly2,poly3,...]
		for(var j=0;j<s.length;j++){
			var p=s[j].toArray();//[node1,node2,node3,...]
			s[j]=p;
		};
	};
	t.reindex();
};

BoundIndexer.prototype=new IdIndexer();

BoundIndexer.prototype.reindex=function(){
	//index end downto start for correct boundWays indexing
	var t=this,d=t.data,h={};
	for(var i=d.length-1;i>=0;i--){
		var io=d[i];
		for(var j=io.length-1;j>=0;j--){
			var p=io[j];
			for(var k=p.length-1;k>=0;k--){
				var n=p[k];
				h[t.objectToKey(n)]=[i,j,k];
			};
		};
	};
	t.idHash=h;
};

BoundIndexer.prototype.insertAfter=function(idx,obj){
	var t=this,oli=idx.slice(0,-1),ol=t.indexToObject(oli),noi=idx.slice(-1)[0]+1;
	ol.splice(noi,0,obj);
	oli.push(noi);
	t.idHash[t.objectToKey(obj)]=oli;
	return oli;
};

function IONodeIndexer(ioNodes){
	this.constructor();
	for(var i=0;i<ioNodes.length;i++){
		this.add(ioNodes[i]);
	};
};

IONodeIndexer.prototype=new IdIndexer();

IONodeIndexer.prototype.add=function(ioNode){
	var t=this,key=t.idToKey(ioNode.node.id);
	if(key in t.idHash)t.idHash[key]++;else t.idHash[key]=1;
};

IONodeIndexer.prototype.remove=function(ioNode){
	var t=this,key=t.idToKey(ioNode.node.id);
	if(!(--t.idHash[key]))delete t.idHash[key];
};

IONodeIndexer.prototype.isIn=function(nodeId){
	var t=this,key=t.idToKey(nodeId);
	return (t.idHash[key]>0);
};

function removeChildPoly(icptRelList,hDstMap,hSrcMap){
	//icptRelList - StoredIdList with multipoly relations ids. Linked to hDstMap
	//hDstMap - MapHelper linked to icptRelList
	//hSrcMap - relation source map MapHelper.
	var rlist=hDstMap.exec('SELECT id FROM '+icptRelList.tableName);
	while(!rlist.eos){
		var rstack=rlist.read(1).toArray()[0];
		while(rstack.length){
			var rid=rstack.pop();
			var rel=hSrcMap.map.getRelation(rid);
			if(!rel)continue;
			var rmem=rel.members.getAll().toArray();
			for(var rmemi=0;rmemi<rmem.length;rmemi+=3){
				if(rmem[rmemi]!='relation')continue;//non-relation member can`t be a multipoly
				if(h.indexOf(['','outer','inner','enclave','exclave'],rmem[rmemi+2])<0)continue;//not geometry entity, skip it
				rid=rmem[rmemi+1];
				icptRelList.remove(rid);
				rstack.push(rid);
			};
		};
	};
};

function dualResolve(ipoly,hSmallMap,hBigMap){
	if(!ipoly.resolve(hSmallMap.map)){
		var nrl=ipoly.getNotResolved().getAll().toArray();
		for(var i=0;i<nrl.length;i+=3){
			var oid=nrl[i]+':'+nrl[i+1];
			var obj=hBigMap.getObject(oid);
			if(obj)hSmallMap.map.putObject(obj);
			//dbg echo('	copy obj '+oid+' to small map');
		};
		return ipoly.resolve(hSmallMap.map);
	}else{
		return true;
	};
};

function getTestNode(testPoly,testWays,map){
	var gt=h.gt,result=map.createNode(),n1,n2;
	for(var j=0;j<testWays.length;j++){
		var testNodes=h.gt.wayToNodeArray(map,testWays[j]).toArray();
		for(var i=1;i<testNodes.length;i++){
			n1=testNodes[i-1];
			n2=testNodes[i];
			var d=gt.distance(n1,n2);
			if(d<testDistance){
				continue;
			};
			var midlat=(n1.lat+n2.lat)/2,midlon=(n1.lon+n2.lon)/2,dlat=(n2.lat-n1.lat)/d*testDistance,dlon=(n2.lon-n1.lon)/d*testDistance;
			result.lat=midlat - dlon;
			result.lon=midlon + dlat;
			if(testPoly.isIn(result))return result;
			result.lat=midlat + dlon;
			result.lon=midlon - dlat;
			if(testPoly.isIn(result))return result;
		};
	};
	var tpa=testPoly.getArea();
	if(tpa>testCloseSegmentsWarning)echo(' \n	Warning: too close segments S='+tpa+'m2 n1='+n1.id+' n2='+n2.id);
	result.lat=n1.lat;
	result.lon=n1.lon;
	return result;
};

function getWayKey(relId,wayId){return (''+relId+','+wayId)};

function putIONode(node,ntype,idx,ioNodes,boundIndex){
	var n=node;
	if(!n){
		echo('\n	Warning: node not found');
		return false;
	};
	var tn1=n.tags.getByKey('osman:node1');
	var tn2=n.tags.getByKey('osman:node2');
	if(!tn1){
		//intersection may be exactly on boundary node
		if((n.tags.getByKey('osman:note')=='boundary')||(boundIndex.idToIndex(n.id))){
			tn1=n.id;
			tn2=tn1;
		}else{
			//something goes wrong...
			echo ('  Not closed line detected near node['+n.id+'] tags='+n.tags.getAll().toArray().join(', '));
			return false;
		}
	}else{
		tn1=parseFloat(tn1);
		if(!tn2)throw {name:'user',message:'No osman:node2 tag found'};
		tn2=parseFloat(tn2);
		//make tn1 less then tn2
		if(tn1>tn2){
			var tn=tn1;
			tn1=tn2;tn2=tn;
		};
	};
	ioNodes.push({clusterIdx:idx,ndType:ntype,nid1:tn1,nid2:tn2,node:n});//we should use push - caller rely on it on fail condition 
	return true;
};
	
function findIONodeOnBound(ioNode,boundIndex){
	var r=2,nid1=ioNode.nid1,nid2=ioNode.nid2,bi=boundIndex;
	var idx1=bi.idToIndex(nid1),idx2=bi.idToIndex(nid2);
	if(!idx2){
		r--;
	};
	if(!idx1){
		idx1=idx2;
		r--;
	};
	if(r==0)return false;//no such nodes in hash
	//find minimal index
	for(var i=0;(r>1) && (i<idx1.length);i++){
		if(idx1[i]>idx2[i]){
			idx1=idx2;
			break;
		};
	};
	var reindex=false;
	r=false;
	idx1=idx1.slice(0);//make a copy
	for(var i=idx1[0];(i<bi.data.length)&& !r;i++){
		for(var p=idx1[1];(p<bi.data[i].length)&& !r;p++){
			var curnl=bi.data[i][p];
			for(var n=idx1[2];n<curnl.length;n++){
				var cid=curnl[n].id;
				if(reindex)bi.idHash[bi.idToKey(cid)]=[i,p,n];
				if((cid==nid1)||(cid==nid2)){
					r=[i,p,n];
					break;
				};
				reindex=true;
			};
			idx1[2]=0;
		};
		idx1[1]=0;
	};
	return r;
};

function mergeIONodesAndBound(ioNodes,boundIndex,boundWays){
	function insertIOs(ios){
		function insertSimple(ioNode,bs){//bs[2] incremented!
			var node=ioNode.node,ioId=node.id;
			ioNode.nid1=ioId;
			ioNode.nid2=ioId;
			if(boundIndex.idToIndex(ioId))return;//node already merged
			bs[2]=boundIndex.insertAfter(bs,node)[2];
		};
		
		if((ios[0].nid1==ios[0].nid2)){
			//can check only ios[0] because all nid1 are same and all nid2 are same
			//node(s) is already boundary node, so we need no actions
			return;
		};
		var bs=findIONodeOnBound(ios[0],boundIndex);
		if(!bs)throw {name:'user',message:'Bound segment ['+ios[0].nid1+','+ios[0].nid2+'] not found'};
		if(ios.length==1){
			insertSimple(ios[0],bs);
			return;
		};
		//hard case - several ios on same segment :-()
		var testNode=boundIndex.indexToObject(bs);
		ios.sort(function(a,b){return h.gt.distance(testNode,a.node)-h.gt.distance(testNode,b.node)});
		for(var i=0;i<ios.length;i++){
			insertSimple(ios[i],bs);//bs[2] incremented!
		};
	};
	ioNodes.sort(function(a,b){return (a.nid1!=b.nid1)?(a.nid1-b.nid1):(a.nid2-b.nid2)});
	var ios=[],lastIO;
	for(var i=ioNodes.length-1;i>=0;i--){
		var io=ioNodes[i];
		if(boundIndex.idToIndex(io.node.id)){
			//this node already inserted and indexed in boundIndex
			io.nid1=io.node.id;//just mark it as bound node
			io.nid2=io.nid1;
			continue;
		};
		if(lastIO && (lastIO.nid1==io.nid1) && (lastIO.nid2==io.nid2)){
			//we find collision - several IO on same bound segment
			ios.push(io);
		}else{
			if(ios.length)insertIOs(ios);
			ios=[io];
			lastIO=io;
		};
	};
	if(ios.length)insertIOs(ios);
	boundWays.sort(function(a,b){return a.id-b.id});
	
	for(var i=boundWays.length-1;i>=0;i--){
		if(i && (boundWays[i].id==boundWays[i-1].id)){
			boundWays.splice(i-1,2);
			i--;
			continue;
		};
		var w=boundWays[i],nids=w.nodes.toArray(),idx1=nids[0];
		boundIndex.keyToObject(boundIndex.idToKey(idx1));//force local reindex
		idx1=boundIndex.idToIndex(idx1);
		if(idx1 && (idx1.length==3)){
			boundWays[i]={way:w,idx1:idx1};
		}else{
			boundWays.splice(i,1);
		};
	};
	boundWays.sort(
		function(a,b){
			if(a.idx1[0]!=b.idx1[0]){
				return a.idx1[0]-b.idx1[0];
			}else if(a.idx1[1]!=b.idx1[1]){
				return a.idx1[1]-b.idx1[1];
			}else{
				return a.idx1[2]-b.idx1[2];
			};
		}
	);
	for(var i=boundWays.length-1;i>=0;i--){
		var cur=boundWays[i],w=cur.way,wn=w.nodes.toArray(),wn2=wn[1],step=0,bs={poly:boundIndex.indexToObject(cur.idx1.slice(0,2)), idx:cur.idx1[2]}, delta=1;
		if(!bs.poly.ways)bs.poly.ways=[];
		bs.poly.ways.push(w.id);//used in addExtCluster routine
		while(!step){
			if(delta>=bs.poly.length)throw {name:'developer',message:'invalid boundary near node['+wn2+'] ?'}
			segStep(bs,delta);
			if(bs.poly[bs.idx].id==wn2){
				step=1;
			};
			segStep(bs,-2*delta);
			if(bs.poly[bs.idx].id==wn2){
				step=-1;
			};
			segStep(bs,delta);
			delta++;
		};
		var newwn=[wn[0]],lastId=wn.slice(-1)[0],curId;
		do{
			segStep(bs,step);
			curId=bs.poly[bs.idx].id;
			newwn.push(curId);
		}while(lastId!=curId);
		if(newwn.length==wn.length){
			//no IO inserted
			boundWays.splice(i,1);
		}else{
			w.nodes=newwn;
			boundWays[i]=w;
		};
	};
};

function segStep(bSeg,step){//bSeg modified!
	//bSeg={poly:array of Nodes, idx:integer in [0..poly.length-1]}
	bSeg.idx+=step;
	while(bSeg.idx>=bSeg.poly.length-1){
		bSeg.idx-=bSeg.poly.length-1;
	};
	while(bSeg.idx<0){
		bSeg.idx+=bSeg.poly.length-1;
	};
	return bSeg.idx;
};

function osmanPolyFromWayList(ways,map){
	var res=h.gt.createPoly();
	for(var i=0;i<ways.length;i++)res.addObject(ways[i]);
	if(!res.resolve(map)){
		var nf=res.getNotResolved().count,nc=res.getNotClosed().count;
		if((nf+nc)>0)echo('\n	Warning: osmanPolyFromWayList failed.'+((nf)?(' '+nf+'not found'):(''))+((nc)?(' '+nc+' not closed'):('')));
		return;//return undefined
	};
	return res;
};

function wayFromNodeList(nl,cutter){
	var ww=cutter.dstMapHelper.map.createWay(),wwnid=[];
	for(var n=0;n<nl.length;n++)wwnid.push(nl[n].id);
	ww.nodes=wwnid;
	return ww;
};

function osmanPolyFromNodeList(nl,cutter){
	var r=h.gt.createPoly(),ww=wayFromNodeList(nl,cutter);
	r.addObject(ww);
	if(!dualResolve(r,cutter.dstMapHelper,cutter.srcMapHelper)){
		echo('osmanPolyFromNodeList.resolve failed');
		echo('Not resolved:');
		var nr=r.getNotResolved().getAll().toArray();
		for(var i=0;i<nr.length;i+=3){
			echo(nr[i]+'['+nr[i+1]+']');
		};
		echo('Not closed:');
		var nr=r.getNotClosed().getAll().toArray();
		for(var i=0;i<nr.length;i+=3){
			echo(nr[i]+'['+nr[i+1]+']');
		};
		
	};
	return r;
};

function orderClusters(cls,map){
	function insertClusterIntoTree(tree,cl){
		for(var i=0;i<tree.length;i++){
			if(cl.osmanPoly.isIn(tree[i].testNode)){
				//tree-poly included into new cl-poly. Store treetpoly as subpoly of new and replace in tree.
				var t=tree[i];
				tree[i]=cl;
				if(!cl.subPolies)cl.subPolies=[];
				cl.subPolies.push(t);
			}else if(tree[i].osmanPoly.isIn(cl.testNode)){
				//new poly included into tree poly.
				if(!tree[i].subPolies)tree[i].subPolies=[];
				if(insertClusterIntoTree(tree[i].subPolies,cl)){
					//new poly is subsubpoly and stored somewhere deeper in tree.
					return true;
				}else{
					//new poly is not subsub, but simple sub, so store it and return
					tree[i].subPolies.push(cl);
					return true;
				}
			};
		};
		return false;
	};
	var r=[];
	while(cls.length){
		var c=cls.pop();
		c.osmanPoly=osmanPolyFromWayList(c.ways,map);
		if((!c.osmanPoly)||(c.osmanPoly.getArea()<minPolyIntersetionArea)){
			var sp=c.srcPtr;
			if(sp)sp[0].clusters[sp[1]]=false;//remove cluster from parsed relation structure
			continue;//and block insertion into tree
		};
		c.testNode=getTestNode(c.osmanPoly,c.ways,map);
		if(!insertClusterIntoTree(r,c))r.push(c);
	};
	return r;
};

function rightAngle(A,B,C){
//CCW angle between AB and BC. Result in range (0...2*PI]
	var XA=B.lon,YA=B.lat,XC=C.lon-XA,YC=C.lat-YA,r=Math.atan2(YC,XC),pi2=Math.PI*2;
	XA=A.lon-XA;YA=A.lat-YA;
	r-=Math.atan2(YA,XA);
	if(r<=0)r+=pi2;
	if(r>pi2)r-=pi2;
	return r;
};

function getClusterBeforeLastNode(clust,map){
	var lastId=clust.idn;
	for(var i=clust.ways.length-1;i>=0;i--){
		var w=clust.ways[i],wn=w.nodes.toArray();
		if(wn[0]==lastId)return map.getNode(wn[1]);
		if(wn.slice(-1)[0]==lastId)return map.getNode(wn.slice(-2)[0]);
	};
	throw {name:'user',message:'no prev node['+lastId+']'};
};

function clustersToPolys(params){
	var boundIndex;
	function fillIOTags(n){
		n.tags.setByKey('osman:note','boundary');
		n.tags.deleteByKey('osman:node1');
		n.tags.deleteByKey('osman:node2');
		if(!boundIndex.idToIndex(n.id)){
			//rare case: node is exactly on bound & not part of bound & end node of way
			//need to find nearest bound segment and insert node into it
			var b=boundIndex.data,minIdx,minDist=20e6;
			for(var i=0;(i<b.length)&&(minDist>0);i++){
				var p=b[i];
				for(var j=0;(j<p.length)&&(minDist>0);j++){
					var nl=p[j],n2=nl[0];
					for(var k=1;k<nl.length;k++){
						var n1=n2;
						n2=nl[k];
						var d=h.gt.distance(n,[n1,n2]);
						if(d<minDist){
							minDist=d;
							minIdx=[i,j,k];
							if(minDist<=0)break;
						};
					};
				};
			};
			minIdx[2]--;
			boundIndex.insertAfter(minIdx,n);
			echo('a',true,true);
		};
	};
var defparams={
	clusters:[],
	map:{},
	boundIndex:{},
	roleDetector:function(){return false},
	directionDetector:{},
	strictIOType:false,
	nextWayId:-1,
	newWayTags:['osman:note','clustersToPolys defaults']
};
	for(var i in defparams)if(!(i in params))params[i]=defparams[i];
	var clusters=params.clusters,map=params.map;
	boundIndex=params.boundIndex;
	var roleDetector=params.roleDetector,directionDetector=params.directionDetector;
	var strictIOType=params.strictIOType,nextWayId=params.nextWayId,newWayTags=params.newWayTags;
	var r=[],g=[];
	for(var i=clusters.length-1; i>=0; i--){
		var cc=clusters[i];
		if(cc.id1==cc.idn){//don`t glue - already poly
			if(!cc.role)roleDetector(cc);
			r.push(cc);
		}else{
			g.push(cc);
		};
	};
	//now all polygons in r and all linears in g
	//make IONodes array
	var ioNodes=[];
	for(var i=0;i<g.length; i++){
		var nd1=map.getNode(g[i].id1),nd2=map.getNode(g[i].idn);
		if(!(nd1 && nd2))continue;
		fillIOTags(nd1);
		fillIOTags(nd2);
		if(!putIONode(nd1,'i',i,ioNodes,boundIndex)){
			g.splice(i,1);
			i--;
		}else if(!putIONode(nd2,'o',i,ioNodes,boundIndex)){
			g.splice(i,1);
			i--;
			ioNodes.pop();
		};
	};
	var ioNodeIndex=new IONodeIndexer(ioNodes);
	var node_plus,node_minus,role;
	while(ioNodes.length){
		//merge g into polies
		var curIO=false;
		for(var i=0;i<ioNodes.length;i++){//search for incoming IONode
			curIO=ioNodes[i];
			if(curIO.ndType=='i'){//IONode must be 'i' type for correct cluster_is_poly test
				role=g[curIO.clusterIdx].role;
				if((role=='inner')||(role=='outer')){
					ioNodes.splice(i,1);
					ioNodeIndex.remove(curIO);
					break;
				};
			};
			curIO=false;
			role=false;
		};
		if(!role){//try to detect cluster role
			for(var i=0;i<ioNodes.length;i++){
				curIO=ioNodes[i];
				if(roleDetector(g[curIO.clusterIdx]))break;
				curIO=false;
			};
			if(curIO)continue;
		};
		if(!curIO){
			curIO=ioNodes.shift();
			g[curIO.clusterIdx].role='outer';//lets throw a coin
			ioNodes.push(curIO);
			curIO=curIO.node;
			echo(' \n	Warning: can`t detect cluster role near '+curIO.lat.toFixed(7)+' '+curIO.lon.toFixed(7)+'. <outer> assumed');
			continue;
		};
		var curClustIdx=curIO.clusterIdx,curClust=g[curClustIdx];
		while(curClust.id1!=curClust.idn){
			curIO=false;
			for(var i=0;i<ioNodes.length;i++){//search for outgoing IONode
				if(ioNodes[i].clusterIdx==curClustIdx){
					curIO=ioNodes[i];
					ioNodes.splice(i,1);
					ioNodeIndex.remove(curIO);
					break;
				};
			};
			if(!curIO)throw {name:'user',message:'No outgoing ioNode found'};
			//cluster and bound intersects exactly in node because IONodes merged into boundary
			var bs=boundIndex.keyToObject(boundIndex.idToKey(curIO.nid1));//force local reindex
			bs=boundIndex.idToIndex(curIO.nid1);//now have valid index
			bs={poly:boundIndex.data[bs[0]][bs[1]],idx:bs[2]};
			node_plus=bs.poly[segStep(bs,1)];
			node_minus=bs.poly[segStep(bs,-2)];
			segStep(bs,1);//return to start position
			var step=directionDetector(curClust,curIO,ioNodes,node_plus,node_minus);
			if(!step){
				//delete this cluster. I don`t know how handle it anyway :-(
				curClust=false;
				break;
			};
			var wnds=[curIO.node.id],i=bs.poly.length;
			//store bound nodes till (next IO-node) or (end of poly)
			curIO=false;
			while(i-- > 0){
				var idx=segStep(bs,step);
				var nd=bs.poly[idx];
				wnds.push(nd.id);
				if(ioNodeIndex.isIn(nd.id)){
					//got next ionode
					for(var j=0;j<ioNodes.length;j++){
						curIO=ioNodes[j];
						if((curIO.node.id==nd.id)&&((!strictIOType) || (curIO.ndType=='i'))){
							ioNodes.splice(j,1);
							ioNodeIndex.remove(curIO);
							break;
						};
						curIO=false;
					};
				};
				if(curIO || (nd.id==curClust.id1))break;
			};
			//store on-bound nodes into new way
			var w=map.createWay();
			w.id=nextWayId;nextWayId--;
			w.nodes=wnds;
			w.tags.setAll(newWayTags);
			curClust.ways.push(w);
			curClust.idn=nd.id;
			if(curIO){
				//append next cluster to curClust
				curClustIdx=curIO.clusterIdx;
				var addend=g[curClustIdx];
				if(curClust.idn==addend.id1){
					curClust.idn=addend.idn;
				}else if((curClust.idn==addend.idn)&&(!strictIOType)){
					curClust.idn=addend.id1;
				}else throw {name:'debug',message:'invalid cluster ioNodes'};
				curClust.ways=curClust.ways.concat(addend.ways);
			}else{
				//it is last node - now cluster is poly
			};
		};
		if(curClust)r.push(curClust);
	};
	params.nextWayId=nextWayId;
	return r;
};

function intersectMultipoly(relId,cutter,boundIndex){
	echo('rel['+relId+']',true,true);
	//nr* variables - new relation variables, or* variables - old relation
	var hSmallMap=cutter.dstMapHelper,hBigMap=cutter.srcMapHelper;

	function removeRelation(rid){
		echo('d',true,true);
		var rel=hSmallMap.map.createRelation();
		rel.id=rid;
		hSmallMap.replaceObject(rel,[]);
	};

	function parseRel(rid,parsed,map){
		var nrObj=map.getRelation(rid);
		if(!nrObj){
			removeRelation(rid);
			return false;
		};
		parsed.obj=nrObj;
		var m=nrObj.members.getAll().toArray();
		parsed.members=m;
		for(var i=m.length-3;i>=0;i-=3){
			if(h.indexOf(['','outer','inner','enclave','exclave'],m[i+2])<0)continue;
			switch(m[i]){
				case 'relation':
					var pr={members:[],ways:[],subPoly:[],obj:0,clusters:[]};
					if(parseRel(m[i+1],pr,map))parsed.subPoly.push(pr);
					m.splice(i,3);
					break;
				case 'way':
					var w=map.getWay(m[i+1]);
					m.splice(i,3);
					if(w){
						parsed.ways.push(w);
					};
					break;
				case 'node':
					break;
				default:
					throw {name:'intersectMultipoly/parseRel',message:'unknown object type <'+m[i]+'>'};
			};
		};
		if((parsed.ways.length+parsed.subPoly.length)==0){
			removeRelation(rid);
			return false;
		}else{
			return true;
		};
	};

	function mergeWays(pr){
		//returns true if all clusters and subclusters are polygons
		var mw=[];
		for(var i=0;i<pr.ways.length;i++){
			var w=pr.ways[i],n=w.nodes.toArray();
			mw.push({id1:n[0],idn:n.slice(-1)[0],ways:[w]});
		};
		pr.clusters=cutter.mergeWayList(pr.ways);
		delete pr.ways;
		var res=pr.clusters.length==0;
		if(!res){
			var c=pr.clusters.slice(-1)[0];
			res=c.id1==c.idn;//all clusters are closed poly
		};
		for(var i=pr.subPoly.length-1;i>=0;i--)res=mergeWays(pr.subPoly[i]) && res;
		return res;
	};
	
	function indexWays(pr,widx,testPoly,map){
		
		function markCluster(cluster,role){
			for(var i=cluster.ways.length-1;i>=0;i--){
				var idx=getWayKey(pr.obj.id,cluster.ways[i].id);
				var oldRole=widx[idx];
				if(oldRole==role)continue;
				role=( (!oldRole) || (oldRole=='') ) ? (role) : ('mixed');
				widx[idx]=role;
				cluster.role=role;
			};
		};
		
		for(var i=pr.clusters.length-1;i>=0;i--){
			var cluster=pr.clusters[i];
			var cObj=osmanPolyFromWayList(cluster.ways,map);
			if(!cObj){
				pr.clusters.splice(i,1);
				echo('\n	Warning: indexWays failed with relId='+pr.obj.id);
				continue;
			};
			var nds=cluster.ways[0].nodes.toArray();
			var testNode=getTestNode(cObj,cluster.ways,map);
			markCluster(cluster,(testPoly.isIn(testNode)? ('outer') : ('inner')));
		};
		for(var i=pr.subPoly.length-1;i>=0;i--)indexWays(pr.subPoly[i],widx,testPoly,map);
	};
	
	function detectClusterRole(pr,widx){
		for(var i=0;i<pr.clusters.length;i++){
			var cluster=pr.clusters[i],ways=cluster.ways;
			for(var j=0;(j<ways.length)&&(!cluster.role);j++){
				var idx=getWayKey(pr.obj.id,ways[j].id);
				switch (widx[idx]){
					case 'inner':
						cluster.role='inner';
						break;
					case 'outer':
						cluster.role='outer';
						break;
				};
			};
		};
		for(var i=0;i<pr.subPoly.length;i++)detectClusterRole(pr.subPoly[i],widx);
	};
	
	function glueClusters(pr,map,testPoly,orParsedRel,orNodeIndex){//orNodeIndex used only in recursive calls. Do not use it in ordinal calls!
		function tryToDetectRole(curClust){
			function indexNodes(pr){
				echo('i',true,true);
				var i,j,k,cl,oldRole,newRole,nids,key;
				for(i=0;i<pr.clusters.length;i++){
					cl=pr.clusters[i];
					newRole=cl.role;
					for(j=0;j<cl.ways.length;j++){
						nids=cl.ways[j].nodes.toArray();
						for(k=0;k<nids.length;k++){
							key=orNodeIndex.idToKey(nids[k]);
							oldRole=orNodeIndex.idHash[key];
							if((oldRole==newRole)||(oldRole=='mixed'))continue;
							orNodeIndex.idHash[key]=( (!oldRole) || (oldRole=='') ) ? (newRole) : ('mixed');
						};
					};
				};
				for(i=0;i<pr.subPoly.length;i++)indexNodes(pr.subPoly[i]);
			};
			if(!orNodeIndex){
				orNodeIndex=new IdIndexer();
				indexNodes(orParsedRel);
			}
			var i,j,nids,w,role;
			for(i=0;i<curClust.ways.length;i++){
				w=curClust.ways[i];
				nids=w.nodes.toArray();
				for(j=0;j<nids.length;j++){
					role=orNodeIndex.idToIndex(nids[j]);
					if((role=='inner')||(role=='outer')){
						curClust.role=role;
						return true;
					};
				};
			};
			return false;
		};
		function detectDir(clust,curIO,ioNodes,nplus,nminus){
			var isInInverted=clust.role=='inner',p=1,m=1,step,testPlus,testMinus,bothOut=false;
			do{
				testPlus={
					lat:nplus.lat*p+curIO.node.lat*(1-p),
					lon:nplus.lon*p+curIO.node.lon*(1-p)
					};
				testMinus={
					lat:nminus.lat*m+curIO.node.lat*(1-m),
					lon:nminus.lon*m+curIO.node.lon*(1-m)
					};
				step=((testPoly.isIn(testPlus))?(2):(0))+((testPoly.isIn(testMinus))?(1):(0));
				var dp=h.gt.distance(curIO.node,testPlus),dm=h.gt.distance(curIO.node,testMinus);
				if(dp>dm)p/=2;else m/=2;
				switch(step){
					case 0:
						bothOut=true;
						break;
					case 1:step=-1;break;
					case 2:step=1;break;
					case 3://hard case - both nodes is in or on bound
						step=0;
						//try intermediate test
						if((dp>testDistance)&&(dm>testDistance))break;
						if(bothOut){
							echo(' \nCan`t detect direction. Both are in bound. -0+='+nminus.id+','+curIO.node.id+','+nplus.id+'. Press Enter to continue.');
							WScript.stdIn.readLine();
							return 0;
						};
						//harder case - both intermediate nodes is in
						var ndc1=getClusterBeforeLastNode(clust,map),rap=rightAngle(ndc1,curIO.node,testPlus),ram=rightAngle(ndc1,curIO.node,testMinus);
						rap=Math.cos(rap);ram=Math.cos(ram);//now value about 1 is backstep direction, about -1 is forward
						//select min and treat it as direction
						step=(rap<ram)?(1):(-1);
						if(isInInverted)step=-step;//pre-invert direction
						break;
				};
				if((!step)&&((dp<testDistance)||(dm<testDistance))){
					echo(' \nCan`t detect direction. -0+='+nminus.id+','+curIO.node.id+','+nplus.id+'. Press Enter to continue.');
					WScript.stdIn.readLine();
					return 0;
				};
			}while(step==0);
			if(isInInverted){
				step=-step;//invert direction for inners
			};
			return step;
		};
		var ctpp={
			clusters:pr.clusters,
			map:map,
			boundIndex:boundIndex,
			roleDetector:tryToDetectRole,
			directionDetector:detectDir,
			nextWayId:intersectMultipoly.nextWayId,
			newWayTags:['osman:note','generated by areaCut/intersectMultipoly/'+pr.obj.id]
		};
		pr.clusters=clustersToPolys(ctpp);
		intersectMultipoly.nextWayId=ctpp.nextWayId;
		//proccess subPoly
		for(var i=0;i<pr.subPoly.length;i++){
			glueClusters(pr.subPoly[i],map,testPoly,orParsedRel,orNodeIndex);
		};
	};
	
	function filterClusters(pr,map){
		function makeClusterArray(pr,cls){
			for(var i=0;i<pr.clusters.length;i++){
				var cl=pr.clusters[i];
				cl.srcPtr=[pr,i];
				cls.push(cl);
			};
			for(var i=0;i<pr.subPoly.length;i++){
				makeClusterArray(pr.subPoly[i],cls);
			};
		};
		
		function getClusterPerimeterAndBoundFlag(c){
		//returns {perimeter:length_in_meters, boundFlag: all_cluster_nodes_are_on_bound}
			var d=0,fl=true;
			for(var i=0;i<c.ways.length;i++){
				var wn=c.ways[i].nodes.toArray(),id=wn[0];
				fl=fl && (boundIndex.idToKey(id) in boundIndex.idHash);
				var n1=map.getNode(id);
				for(var n=1;n<wn.length;n++){
					id=wn[n];
					fl=fl && (boundIndex.idToKey(id) in boundIndex.idHash);
					var n2=map.getNode(id);
					d+=h.gt.distance(n1,n2);
					n1=n2;
				};
			};
			return {perimeter:d,boundFlag:fl};
		};
		
		function filterByMinRatioAndBoundCover(tree){
			for(var i=tree.length-1;i>=0;i--){
				var cl=tree[i];
				if(cl.subPolies){
					filterByMinRatioAndBoundCover(cl.subPolies);
					if(!cl.subPolies.length)delete cl.subPolies;
				};
				if(!cl.subPolies){
					var p=getClusterPerimeterAndBoundFlag(cl),ratio=(p.perimeter>0)?(cl.osmanPoly.getArea()/(p.perimeter*p.perimeter)*16):(0);
					if((ratio<minPolySideRatio)||(p.boundFlag)){
						var sp=cl.srcPtr;
						sp[0].clusters[sp[1]]=false;//remove cluster from parsed relation structure
						tree.splice(i,1);
					};
				};
			};
		};
		
		function addExtCluster(c){
			var ob=boundIndex.data[0];//use only outer bounds
			echo(' \nAdd extra for relation['+c.srcPtr[0].obj.id+']');
			for(var i=0;i<ob.length;i++){
				var p=ob[i];
				if(!p.osmanPoly)p.osmanPoly=osmanPolyFromNodeList(p,cutter);
				if(p.usedInRel)continue;
				if(p.osmanPoly.isIn(c.testNode)){
					p.usedInRel=true;
					var sp=c.srcPtr[0];
					for(var j=0;j<p.ways.length;j++){
						sp.members.push('way',p.ways[j],'outer');
					};
					break;
				};
			};
		};
		
		var clusters=[];
		makeClusterArray(pr,clusters);
		var clustTree=orderClusters(clusters,map),defRole,i;
		filterByMinRatioAndBoundCover(clustTree);
		for(i=0;(i<clustTree.length)&&(!defRole);i++){
			defRole=clustTree[i].role;
		};
		for(i=0;i<clustTree.length;i++){
			var c=clustTree[i];
			if(!c.role)c.role=defRole;
			if(c.role!='outer'){
				if(c.role=='inner'){
					addExtCluster(c);
				}else{
					var relId=c.srcPtr[0].obj.id;
					echo('\nCluster with role<'+c.role+'> found in relation['+relId+'] in polygon with way['+c.ways[0].id+']\nPress enter to continue.');
					WScript.stdIn.readLine();
					var sp=c.srcPtr;
					sp[0].clusters[sp[1]]=false;//remove cluster from parsed relation structure
					clustTree.splice(i,1);
					i--;
				};
			};
		};
	};
	
	function saveRelation(pr,map,newWayIdStart){
		var saveIt=false;
		if(pr.subPoly){
			for(var i=0;i<pr.subPoly.length;i++){
				if(saveRelation(pr.subPoly[i],map,newWayIdStart)){
					saveIt=true;
					pr.members.push('relation',pr.subPoly[i].obj.id,'');
				};
			};
		};
		for(var i=pr.clusters.length-1;i>=0;i--){
			var c=pr.clusters[i];
			if(!c)continue;
			saveIt=true;
			for(var j=0;j<c.ways.length;j++){
				var w=c.ways[j];
				if(w.id<=newWayIdStart){
					map.putWay(w);
				};
				pr.members.push('way',w.id,(c.role)?(c.role):(''));
			};
		};
		if(saveIt){
			pr.obj.members.setAll(pr.members);
			map.putRelation(pr.obj);
		}else{
			removeRelation(pr.obj.id);
		};
		return saveIt;
	};
	
	function clearBoundFlags(){
		var ob=boundIndex.data[0];//use only outer bounds
		for(var i=0;i<ob.length;i++){
			delete ob[i].usedInRel;
		};
	};
	
	echo('p',true,true);//parse new relation
	var nrParsedRel={members:[],ways:[],subPoly:[],obj:0,clusters:[]};
	if(!parseRel(relId,nrParsedRel,hSmallMap.map)){
		return;
	};
	echo('P',true,true);//parse old relation
	var orParsedRel={members:[],ways:[],subPoly:[],obj:0,clusters:[]};
	if(!parseRel(relId,orParsedRel,hBigMap.map)){
		return;
	};
	echo('M',true,true);//merge old relation ways into clusters
	if(!mergeWays(orParsedRel)){
		removeRelation(relId);
		return;
	};
	echo('O',true,true);//get OSMan MultiPoly object for old relation
	var orPoly=h.getMultiPoly('relation:'+relId,hBigMap.map).poly;
	if(!orPoly){
		removeRelation(relId);
		return;
	};
	echo('I',true,true);//detect roles for old relation clusters and make way index - [relId,wayId]=>(inner|outer|mixed)
	var orWayIdx={};
	indexWays(orParsedRel,orWayIdx,orPoly,hBigMap.map);
	//convert ways array into clusters
	echo('m',true,true);//merge new relation ways into clusters
	mergeWays(nrParsedRel);
	echo('c',true,true);//detect roles for new clusters
	detectClusterRole(nrParsedRel,orWayIdx);
	echo('g',true,true);//glue clusters into polygons
	if(!intersectMultipoly.nextWayId){
		intersectMultipoly.nextWayId=hSmallMap.getNextWayId();
	};
	var newWayIdStart=intersectMultipoly.nextWayId;
	glueClusters(nrParsedRel,hSmallMap.map,orPoly,orParsedRel);
	echo('f',true,true);//filter clusters by area and ratio
	filterClusters(nrParsedRel,hSmallMap.map);
	echo('s',true,true);
	saveRelation(nrParsedRel,hSmallMap.map,newWayIdStart);
	clearBoundFlags();
	echo(' ',true);
};

function intersectWay(way,cutter,usedWayList,notUsedWayList,boundIndex){
	echo('way['+way.id+']r',true,true);
	var hSmallMap=cutter.dstMapHelper,hBigMap=cutter.srcMapHelper,bPoly=cutter.bPoly,wid=way.id;
	if(usedWayList.isIn(wid)){
		echo('i',true);
	};
	var nl;
	try{
		nl=cutter.buildNodeListArray([way])[0];
	}catch(e){
		echo('\ncutter.buildNodeListArray: '+e.message);
		echo('	deleted.');
		hSmallMap.replaceObject(way,[]);
		return [];
	};
	echo('c',true,true);
	if(!intersectWay.nextNodeId)intersectWay.nextNodeId=hSmallMap.getNextNodeId();
	if(!intersectWay.nextWayId)intersectWay.nextWayId=hSmallMap.getNextWayId();
	var newNodeIdStart=intersectWay.nextNodeId,newNodeIdEnd=newNodeIdStart+1;
	//nl is array of nodes
	var isPoly=(nl.length>2)&&(nl[0].id==nl[nl.length-1].id);
	var intersection=bPoly.getIntersection(hBigMap.map,nl,newNodeIdStart).toArray();
	var replacement=[],icarea=0,perimeter=0,tags=way.tags,ioNodes=[];
	echo('s',true,true);
	//intersection is array of array of nodes - represents several simple poly in multi way(in general case) result
	for(var j=0;j<intersection.length;j++){
		//check every simple poly in result
		var interPoly=intersection[j].toArray();
		//dbg echo('	intersection '+j+' nn='+interPoly.length);
		var nids=[],prevNode=false;
		for(var k=0;k<interPoly.length;k++){
			var curNode=interPoly[k];
			curNode.tags.deletebyKey('osman:parent');
			var nid=curNode.id,ntags=curNode.tags.getAll();
			if((nid<=newNodeIdStart)||(curNode.tags.getByKey('osman:note')=='boundary')){
				//store new/modified node to map
				curNode.tags.deletebyKey('osman:note');
				curNode.tags.deletebyKey('osman:node1');
				curNode.tags.deletebyKey('osman:node2');
				curNode=hSmallMap.findOrStore(curNode);//node could be replaced with old one from map
				nid=curNode.id;//so reread id
				interPoly[k]=curNode;
				if((!isPoly)&&((k==0)||(k==interPoly.length-1))){
					//store ioNodes only for first and last node of linear objects
					curNode.tags.setAll(ntags);
					putIONode(curNode,'_',0,ioNodes,boundIndex);
				};
				if(nid<newNodeIdEnd){
					newNodeIdEnd=nid;
				};
			};
			if(prevNode){
				perimeter+=h.gt.distance(prevNode,curNode);
			};
			prevNode=curNode;
			nids.push(nid);
		};
		if(nids.length>1)way.nodes=nids;else continue;
		if(isPoly){
			//all polies in intersection are outer, so we can check them one by one
			var ipoly=h.gt.createPoly();
			ipoly.addObject(way);
			if(dualResolve(ipoly,hSmallMap,hBigMap)){
				icarea+=ipoly.getArea();
			}else{
				//not resolved - we have incomplete big map or empty intersection, icarea==0 => way would be deleted.
				var nr=ipoly.getNotResolved().getAll().toArray();
				if(nr.length>0)echo('\n	not resolved list:');else echo(' empty way',true);
				for(var i=0;i<nr.length;i+=3){
					echo('		'+nr[i]+'['+nr[i+1]+']');
				};
				continue;
			};
			//dbg echo(' ipoly '+j+'/'+intersection.length+' S='+(icarea/1e6)+'km2');
		}else{
			var notFoundRefs=hSmallMap.getObjectChildren(way,3);
			for(var k=0;k<notFoundRefs.length;k++){
				var nd=hBigMap.getObject(notFoundRefs[k]);
				if(nd)hSmallMap.map.putObject(nd);
			};
		};
		//add current way to replacement array
		replacement.push(way);
		//create way object for next iteration
		if(way.id<=intersectWay.nextWayId)intersectWay.nextWayId=way.id-1;
		way=hSmallMap.map.createWay();
		way.tags=tags;
		way.id=intersectWay.nextWayId;
	};
	var ratio=(isPoly && (perimeter>0))?(icarea/(perimeter*perimeter)*16):(0);
	//dbg echo(' P='+(perimeter/1e3).toFixed(3)+((isPoly)?(' S='+(icarea/1e6).toFixed(3)+'km2 R='+ratio.toFixed(4)):('')),true,true);
	if(isPoly && (
		(icarea<minPolyIntersetionArea)||
		((icarea+minPolyIntersetionArea)>=bPoly.getArea())||
		(ratio<minPolySideRatio))
		){
		//intersection area==0 => empty intersection => delete poly
		//intersection area==boundary area => boundary fully covered by multipoly => delete multipoly
		//delete all new nodes created by this intersection
		replacement=[];
		echo('d',true,true);
		//dbg echo('	too small or too big. delete it');
	};
	way=(replacement.length>0)?(replacement[0]):(way);
	intersectWay.nextNodeId=newNodeIdEnd-1;
	switch(replacement.length){
		case 0://way should be deleted
			echo('d',true,true);
			notUsedWayList.add(way.id);
			//dbg echo('nodes '+newNodeIdEnd+'...'+newNodeIdStart+' deleted');
			if(newNodeIdEnd<=newNodeIdStart){//have at least one new node
				hSmallMap.exec('DELETE FROM nodes WHERE id BETWEEN '+newNodeIdEnd+' AND '+newNodeIdStart);
			};
			intersectWay.nextNodeId=newNodeIdStart;
			if(!usedWayList.isIn(wid)){
				way.id=wid;
				hSmallMap.replaceObject(way,[]);
				//dbg echo(' deleted '+way.id); 
			}else{
				echo('\n In used list. Not deleted way id='+way.id);//dbg 
			};
			ioNodes=[];
			break;
		case 1://no changes in referers. Just store modified version into map
			echo('u',true,true);
			hSmallMap.map.putWay(way);
			usedWayList.add(wid);
			break;
		default:
			echo('m',true,true);
			hSmallMap.replaceObject(way,replacement);
			usedWayList.add(wid);
			//dbg echo('	multiplicated');
			break;
	};
	echo('   ',true);
	return ioNodes;
	//dbg echo(' replace with '+replacement.length+' way(s)');
};

function intersectCoastLines(cutter,boundIndex){
	function isPoly(cluster){
		return cluster.id1==cluster.idn;//one node cluster is polygon too
	};
	var nextWayId,newWayIdStart;
	var hSmallMap=cutter.dstMapHelper,hBigMap=cutter.srcMapHelper,bPoly=cutter.bPoly;
	function addExtCoast(island,bounds){
		echo(' \nAdd extra for coast way['+island.ways[0].id+']');
		var testNode=island.testNode,tbn=bounds[0]/*check only outer polygons*/;
		for(var i=0;i<tbn.length;i++){
			if(!tbn[i].osmanPoly){
				tbn[i].osmanPoly=osmanPolyFromNodeList(tbn[i],cutter);
			};
			if(tbn[i].osmanPoly.isIn(testNode)){
				if(!tbn[i].usedInCoast){
					var wn=tbn[i];
					if(wn.osmanPoly.getOrientation()==2){
						wn=wn.slice(0).reverse();
					};
					var w=wayFromNodeList(wn,cutter);
					w.id=nextWayId;nextWayId--;
					w.tags.setAll(['natural','coastline','osman:note','generated by areaCut/addExtCoast for way:'+island.ways[0].id]);
					hSmallMap.map.putWay(w);
					tbn[i].usedInCoast=true;
				};
				return;
			};
		};
		echo('	can`t find boundary for island. FirstNodeId='+island.id1);
	};
	function processCoastLines(coastClusters){
		//all linear(non-poly) intersections are in coastClusters list
		//first Node is always in-node (from outside to inside bound)
		//last Node is always out-node (from inside to outside bound).
		//make in-out nodes list
		function roleDetector(c){c.role='outer';return true};
		function dirDetector(curClust,curIO,ioNodes,np,nm){
			var ndc1=getClusterBeforeLastNode(curClust,hSmallMap.map);
			if(rightAngle(ndc1,curIO.node,nm)<rightAngle(ndc1,curIO.node,np)){
				//reverse direction
				return -1;
			}else{
				return 1;
			};
		};
		var ctpp={
			clusters:coastClusters,
			map:hSmallMap.map,
			boundIndex:boundIndex,
			roleDetector:roleDetector,
			directionDetector:dirDetector,
			strictIOType:true,
			nextWayId:nextWayId,
			newWayTags:['osman:note','generated by areaCut/intersectCoastLines','natural','coastline']
			};
		var cpolys=clustersToPolys(ctpp);
		nextWayId=ctpp.nextWayId;
		return cpolys;
	};

	function saveCluster(cluster,idLimit){
		for(var j=0,ws=cluster.ways;j<ws.length;j++){
			var w=ws[j];
			if(w.id<=idLimit){
				hSmallMap.map.putWay(w);
			};
		};
		if(cluster.subPolies){
			for(var j=0;j<cluster.subPolies.length;j++)saveCluster(cluster.subPolies[j],idLimit);
		};
	};
	nextWayId=hSmallMap.getNextWayId();
	newWayIdStart=nextWayId;
	var qcl=hSmallMap.exec("SELECT objid>>2 FROM strobjtags WHERE tagname='natural' and tagvalue='coastline' and objid&3=1"),clines=[];
	while(!qcl.eos){
		clines=clines.concat(qcl.read(1000).toArray());
	};
	echot('n_clines='+clines.length+'. Reading ways.');
	for(var i=clines.length-1;i>=0;i--){
		var w=hSmallMap.map.getWay(clines[i]);
		if(!w){
			echo('\nWay['+clines[i]+'] not found');
			clines.splice(i,1);
		}else{
			clines[i]=w;
		};
	};
	echot('Merging ways');
	var clusters=cutter.mergeWayList(clines);
	echot('Total '+clusters.length+' coastline clusters found. Processing...');
	clusters=processCoastLines(clusters);
	echot('Sorting '+clusters.length+' clusters');
	clusters=orderClusters(clusters,hSmallMap.map);
	//dbg-start
/*	function dumpP(pl,s){
		for(var i=0;i<pl.length;i++){
			echo(s+'FirstId='+pl[i].nodes[0].id+' orent='+pl[i].orientation);
			if(pl[i].subpolies)dumpP(pl[i].subpolies,s+'	');
		};
	};
	dumpP(cpoly,'');*/
	//dbg-end
	for(var i=0;i<clusters.length;i++){
		switch(clusters[i].osmanPoly.getOrientation()){
		case 1://CW - lake
			break;
		case 2://CCW - island
			addExtCoast(clusters[i],boundIndex.data);
			break;
		default:
			echo('	something wrong ?');
		};
		saveCluster(clusters[i],newWayIdStart);
	};
	echot('Coastlines done.');
};

function main(){
	h.man.logger={log:function(s){echo('OSMan: '+s)}};
	var funcName='areaCut.main: ';
	if(!checkArgs())return;
	cutBound=cutBound.split(',');
	if(!cutBound.length)throw {name:'user',message:funcName+'empty bounds'};
	/*create/restore backup DB if map created elsewhere */
	if(noImport){
		if(h.fso.fileExists(smallMapFile+'.bak')){
				echot('Copy file from backup');
				h.fso.copyFile(smallMapFile+'.bak',smallMapFile,true);
		}else{
				echot('Copy file to backup');
				h.fso.copyFile(smallMapFile,smallMapFile+'.bak',true);
		};
	};
	//open maps
	var hBigMap=h.mapHelper(),hSmallMap=h.mapHelper(),bPoly;
	hBigMap.open(bigMapFile,false,true);//no recreation, read-only
	echot('resolving boundary');
	if(noImport){
		hSmallMap.open(smallMapFile);
		bPoly=h.getMultiPoly(cutBound,[hBigMap.map,hSmallMap.map]);
	}else{
		hSmallMap.open(smallMapFile,true,false);//force recreate, read-write
		bPoly=h.getMultiPoly(cutBound,hBigMap.map);
	};
	if(!bPoly.poly){
		if(bPoly.notFoundRefs.length){
			echo('Not found objects:');
			for(var i=0,nf=bPoly.notFoundRefs;i<nf.length;nf++){
				echo('	'+nf[i]);
			};
		};
		if(bPoly.notClosedRefs.length){
			echo('Not closed poly:');
			for(var i=0,nf=bPoly.notClosedRefs;i<nf.length;nf++){
				echo('	'+nf[i]);
			};
		};
		throw {name:'user',message:funcName+'boundary not resolved'};
	};
	echot('indexing boundary');
	var boundIndex=new BoundIndexer(bPoly.poly);
	//add boundary to `used` list
	var usedWayList=hSmallMap.map.storage.createIdList();
	var boundWays=[],hBoundMap=h.mapHelper();
	hBoundMap.map=bPoly.usedMap;
	for(var i=0;i<cutBound.length;i++){
		var bound=hBoundMap.getObject(cutBound[i]);
		if(bound.getClassName()=='Way'){
			usedWayList.add(bound.id);
			boundWays.push(bound);
		}else{//bound is relation
			var wl=(h.polyIntersector(hBoundMap,hSmallMap,boundIndex.poly)).buildWayList(bound);
			for(var j=0;j<wl.length;j++){
				bound=wl[j];
				bound.tags.deleteByKey('osman:parent');
				usedWayList.add(bound.id);
				boundWays.push(bound);
			};
		};
	};
	hBoundMap=0;
	bPoly=bPoly.poly;
	echo('	cut area is '+(bPoly.getArea()/1e6).toFixed(3)+' km2');
	if(!noImport){
		bbox=bPoly.getBBox().toArray();
		echot('exporting small map');
		hBigMap.exportDB(hSmallMap.map,[':bpoly',bPoly,':bbox'].concat(bbox));
	};
	echot('building incomplete ways');
	var icptWayList=hSmallMap.map.storage.createIdList();
	hSmallMap.exec('INSERT OR IGNORE INTO '+icptWayList.tableName+'(id) SELECT wayid FROM waynodes WHERE nodeid NOT IN (SELECT id FROM NODES)');

	echot('building incomplete multipolygons');
	var icptRelList=hSmallMap.map.storage.createIdList();
	//get all multipolys with (absent or incomplete way members) or (absent relation members)
	hSmallMap.exec('INSERT OR IGNORE INTO '+icptRelList.tableName+'(id) SELECT relationid FROM relationmembers WHERE relationid IN (SELECT objid>>2 FROM objtags WHERE tagid IN (SELECT id FROM tags WHERE tagname=\'type\' AND tagvalue IN (\'boundary\',\'multipolygon\')) AND (objid&3)=2) AND((memberidxtype&3=1 AND (memberid NOT IN (SELECT id FROM ways) OR memberid IN (SELECT id FROM '+icptWayList.tableName+'))) OR (memberidxtype&3=2 AND memberid NOT IN (SELECT id FROM relations)))');
	var notUsedWayList=hSmallMap.map.storage.createIdList();
	var cutter=h.polyIntersector(hBigMap,hSmallMap,boundIndex.poly),ioNodes=[];
	echot('Intersecting ways');
	rlist=hSmallMap.exec('SELECT id FROM '+icptWayList.tableName);
	while(!rlist.eos){
		var wid=rlist.read(1).toArray()[0],way=hBigMap.map.getWay(wid);
		if(!way){
			echo('	Way '+wid+' not found. Deleted.');
			way=hSmallMap.map.createWay();
			way.id=wid;
			hSmallMap.replaceObject(way,[]);
			continue;
		};
		var wn=way.nodes.toArray();
		if(wn.length<2){
			echo('	Way '+wid+' too short. Deleted.');
			hSmallMap.replaceObject(way,[]);
			continue;
		};
		ioNodes=ioNodes.concat(intersectWay(way,cutter,usedWayList,notUsedWayList,boundIndex));
		echo(' ',true,true);
		};
	echo('',true);
	echot('Merging '+ioNodes.length+' cut nodes and bound');
	mergeIONodesAndBound(ioNodes,boundIndex,boundWays);
	for(var i=0;i<boundWays.length;i++){
		hSmallMap.map.putWay(boundWays[i]);
	};
	boundWays=0;ioNodes=0;
	echot('Processing coastlines');
	intersectCoastLines(cutter,boundIndex);
	//dbg echo('	Incomplete way list length='+hSmallMap.exec('SELECT count(1) FROM '+icptWayList.tableName+' WHERE id NOT IN (SELECT id FROM '+usedWayList.tableName+')').read(1).toArray()[0]);
	icptWayList=0;
	//remove child polygon-relations from relation processing list. Children will processed in parent-relation procedure
	echot('Removing child relations');
	removeChildPoly(icptRelList,hSmallMap,hBigMap);
	echot('Intersecting multipolygons');
	var rlist=hSmallMap.exec('SELECT id FROM '+icptRelList.tableName);
	while(!rlist.eos){
		var rid=rlist.read(1).toArray()[0];
		intersectMultipoly(rid,cutter,boundIndex);
		echo(' ',true);
	};
	icptRelList=0;
	echot('Deleting not used ways.');
	//now analize 'way used' and 'way not used' lists. We can safely delete way in ('way not used'-'way used') set
	var qKillWays=hSmallMap.exec('SELECT id FROM '+notUsedWayList.tableName+' WHERE id not in (SELECT id FROM '+usedWayList.tableName+')');
	var wdel=0;
	for(var kway=hSmallMap.map.createWay();!qKillWays.eos;){
		kway.id=qKillWays.read(1).toArray()[0];
		//dbg echo('	request to delete way['+kway.id+']');
		hSmallMap.replaceObject(kway,[]);
		wdel++;
	};
	usedWayList=0;
	notUsedWayList=0;
	echot(''+wdel+' ways deleted. Fixing relations');
	hSmallMap.fixIncompleteRelations();
	echot('Renumbering new objects');
	hSmallMap.renumberNewObjects();
	if(exportFileName.length){
		echot('Exporting map');
		hSmallMap.exportXML(exportFileName);
	};
	echot('closing maps');
	hBigMap.close();
	hSmallMap.close();
	echot('all done.');
	h.man.logger=0;
};

try{
WScript.sleep(10000);
main();
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
