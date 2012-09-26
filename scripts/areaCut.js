//settings start
var bigMapFile='';
var smallMapFile='';
var exportFileName='';
var cutBound='';
var noImport=true;

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
function echot(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
}
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
			//$$$dbg echo('	copy obj '+oid+' to small map');
		};
		return ipoly.resolve(hSmallMap.map);
	}else{
		return true;
	};
};

function intersectMultipoly(rel,cutter,usedWayList,notUsedWayList,incompleteWayList){
	echo('rel['+rel.id+']w',true,true);
	var wl=cutter.buildWayList(rel),hSmallMap=cutter.dstMapHelper,hBigMap=cutter.srcMapHelper,bPoly=cutter.bPoly,rid=rel.id;

	function buildRelList(rel){
		//convert Relation into one-dimension Relation object array.
		//Subrelations recursively proccessed too.
		//If some subrelation missed in map then empty array returned
		var rs=[],r=rel,rm=r.members.getAll().toArray(),map=hSmallMap.map;
		for(var i=0;i<rm.length;i+=3){
			//skip nodes and ways
			if((rm[i]=='relation')&&(h.indexOf(['','outer','inner','enclave','exclave'],rm[i+2])>=0)){
				//process subrelations
				var sr=map.getRelation(rm[i+1]);
				if(!sr){
					echo('Relation '+r.id+' missed relation '+rm[i+1]);
					return [];
				}else{
					var st=sr.tags.getByKey('type');
					if((st!='multipolygon')&&(st!='boundary')){
						//$$$dbg echo('	relation '+(rm[i+1])+' of type '+st+' skipped');
						continue;
					}
					rs=rs.concat(buildRelList(sr));
				}
			}
		};
		return rs;
	};
	
	if(!intersectMultipoly.nextNodeId)intersectMultipoly.nextNodeId=hSmallMap.getNextNodeId();
	if(!intersectMultipoly.nextWayId)intersectMultipoly.nextWayId=hSmallMap.getNextWayId();	
	if(!wl.length){
		echo('	relation '+rid+' has empty way list. Deleted.');
		hSmallMap.replaceObject(rel,[]);
		return;
	};
	//Way in area test - skip relations without ways in target area
	var hasWayInSmallMap=false;
	//$$$dbg echo('waylist:');
	echo('u',true,true);
	for(var i=0;i<wl.length;i++){
		var id=wl[i].id
		//$$$dbg echo('	'+id);
		hasWayInSmallMap=hasWayInSmallMap||((hSmallMap.map.getWay(id))&&true);
		if(incompleteWayList.isIn(id)){
			notUsedWayList.add(id);
		};
	};
	if(!hasWayInSmallMap){
		echo('d   ',true);
		hSmallMap.replaceObject(rel,[]);
		return;
	};
	//end of Way in area test
	var nl;
	try{
		echo('n',true,true);
		nl=cutter.buildNodeListArray(wl);
	}catch(e){
		echo('\ncutter.buildNodeListArray:'+e.message);
		echo('	deleted.');
		hSmallMap.replaceObject(rel,[]);
		return;
	};
	echo('m',true,true);
	if(!cutter.mergeNodeLists(nl)){
		hSmallMap.replaceObject(rel,[]);
		echo(' has not-closed polygons. Deleted.');
		return;
	};
	var nncnt=0,icarea=0;
	echo('c',true,true);
	var ipoly=h.gt.createPoly(),perimeter=0;
	var newNodeIdStart=intersectMultipoly.nextNodeId,newNodeIdEnd=newNodeIdStart+1,impoly=[];
	//nl is array of array of nodes - represents several simple poly in one multipoly
	for(var i=0;i<nl.length;i++){
		//intersecting one of simple poly and boundary
		//$$$dbg echo('bp.getIntersection['+i+'] npt='+nl[i].length);//$$$dbg 
		var intersection=bPoly.getIntersection(hBigMap.map,nl[i],intersectMultipoly.nextNodeId).toArray();
		//intersection is array of array of nodes - represents several simple poly in multipoly(in general case) result
		//$$$dbg echo('ok. nipoly='+intersection.length);//$$$dbg 
		for(var j=0;j<intersection.length;j++){
			//check every simple poly in result
			impoly.push(intersection[j].toArray());
			intersection[j]=impoly[impoly.length-1];
			//$$$dbg echo('	check impoly '+j+' npt='+intersection[j].length);//$$$dbg 
			//creating temporary Way
			var cluster=hSmallMap.map.createWay(),nids=[],prevNode=false;
			for(var k=0;k<intersection[j].length;k++){
				var curNode=intersection[j][k];
				var nid=curNode.id;
				if(nid<=newNodeIdStart){
					//store new node to map
					curNode=hSmallMap.findOrStore(curNode);
					intersection[j][k]=curNode;
					nid=curNode.id;
					nncnt++;
					if(nid<newNodeIdEnd){
						newNodeIdEnd=nid;
					};
				};
				nids.push(nid);
				if(prevNode){
					perimeter+=h.gt.distance(prevNode,curNode);
					//$$$dbg echo('		p='+perimeter+' cNid='+nid);
				};
				prevNode=curNode;
			};
			cluster.nodes=nids;
			ipoly.addObject(cluster);
		};
		intersectMultipoly.nextNodeId=newNodeIdEnd-1;
	};
	//now ipoly is resulting multipoly. Trying to resolve it.
	if(dualResolve(ipoly,hSmallMap,hBigMap)){
		icarea=ipoly.getArea();
	}else{
		//not resolved - we have incomplete map or empty intersection, icarea==0 => relation would be deleted.
		var nr=ipoly.getNotResolved().getAll().toArray();
		if(nr.length>0)echo('\n	not resolved list:');
		for(var i=0;i<nr.length;i+=3){
			echo('		'+nr[i]+'['+nr[i+1]+']');
		};
	};
	var ratio=(perimeter>0)?(icarea/(perimeter*perimeter)*16):(0);
	echo(' S='+(icarea/1e6).toFixed(3)+'km2 P='+(perimeter/1e3).toFixed(3)+' R='+ratio.toFixed(4),true,true);//+' new_nodes='+nncnt);//$$$dbg 
	if((icarea<minPolyIntersetionArea)||((icarea+minPolyIntersetionArea)>=bPoly.getArea())||(ratio<minPolySideRatio)){
		//intersection area==0 => empty intersection => delete multipoly
		//intersection area==boundary area => boundary fully covered by multipoly => delete multipoly
		echo('d  ',true);
		hSmallMap.replaceObject(rel,[]);
		//delete all new nodes created by this intersection
		hSmallMap.exec('DELETE FROM nodes WHERE id BETWEEN '+newNodeIdEnd+' AND '+newNodeIdStart);
		intersectMultipoly.nextNodeId=newNodeIdStart;
		//$$$dbg echo('	too small or too big intersection. Deleted.');
		return;
	};
	echo('p',true,true);
	if(!cutter.findNodeParents(impoly,nl)){
		echo(' fail to find all parents');
		return;
	};
	var oldWayIds=[];
	for(var i=0;i<wl.length;i++){
		var id=wl[i].id;
		if(incompleteWayList.isIn(id)){
			oldWayIds.push(id);
//			incompleteWayList.remove(id);
		}else{
			//detect fully completed relation ways and add it to process list
			var wayNodeIds=wl[i].nodes.toArray();
			if((wayNodeIds.length>1)&&(hSmallMap.map.getNode(wayNodeIds[0]))){
				//fully complete
				oldWayIds.push(id);
			}else{
				//fully incomplete
				notUsedWayList.add(id);
			};
		};
	};
	//$$$dbg echo('\n		parent ways ok. '+oldWayIds.length+' way(s) to process');//$$$dbg 
	echo('w',true,true);
	var nwl=cutter.waysFromNodeLists(impoly,oldWayIds,intersectMultipoly.nextWayId,usedWayList),nwcnt=0,replacement=[];
	//$$$dbg echo('Intersection distributed into '+nwl.length+' polies');//$$$dbg
	echo('s',true,true);
	for(var i=0;i<nwl.length;i++){
		for(var j=0;j<nwl[i].length;j++){
			//add id into 'way used' list
			var newWay=nwl[i][j];
			var oldWayId=cutter.parseParents(newWay);
			if(oldWayId){
				replacement.push([oldWayId[0],newWay.id]);
//				newWay.tags.deleteByKey('osman:parent');
				//$$$dbg echo('way fork:['+oldWayId+']=>['+oldWayId+','+newWay.id+']');
				hSmallMap.map.putWay(newWay);
				if(newWay.id<=intersectMultipoly.nextWayId)intersectMultipoly.nextWayId=newWay.id-1;
				nwcnt++;
			}else{
				replacement.push([newWay.id,newWay.id]);
				usedWayList.add(newWay.id);
			};
		};
	};
	echo('r',true,true);
	replacement.sort(function(a,b){return (a[0]==b[0])?(a[1]-b[1]):(a[0]-b[0])});
	for(var i=0;i<replacement.length-1;i++){
		if(replacement[i][0]==replacement[i+1][0]){
			replacement[i]=replacement[i].concat(replacement[i+1].slice(1));
			replacement.splice(i+1,1);
			i--;
		};
	};
	//$$$dbg if(rid==1672786)echo('replacement=\n'+replacement);//$$$dbg 
	var rl=buildRelList(rel); rl.push(rel);
	function search(id){
		//$$$dbg echo('search '+id);
		var s=0,e=replacement.length-1,m=-1;
		while(s<e){
			m=(s+e)>>1;
			//$$$dbg echo('s='+s+' e='+e+' m='+m);
			if(replacement[m][0]<id)s=m+1;else if(id<replacement[m][0])e=m-1;else s=e=m;
		};
		if((e>=0)&&(replacement[e][0]==id))return e;
		//$$$dbg echo('not found');
		return -1;
	};
	for(var i=0;i<rl.length;i++){
		var r=rl[i],m=r.members.getAll().toArray(),nm=[];
		//$$$dbg echo('replace in rel['+r.id+']');
		for(var j=0;j<m.length;j+=3){
			if(m[j]=='way'){
				var idx=search(m[j+1]);
				if(idx>=0){
					var rp=replacement[idx];
					for(var k=1;k<rp.length;k++){
						//$$$dbg if(rid==1672786) echo('way['+m[j+1]+']=>['+rp[k]+']');//$$$dbg
						nm.push('way',rp[k],m[j+2]);
					};
				};
			}else{
				nm.push(m[j],m[j+1],m[j+2]);
			};
		};
		r.members.setAll(nm);
		hSmallMap.map.putRelation(r);
	};
	//$$$dbg echo('		'+nwcnt+' processed '+oldWayIds.length+' to delete');//$$$dbg 
	//now in oldWayIds only not used in intersection ways
	//we can add it to 'way not used' list
	for(var i=0;i<oldWayIds.length;i++){
		notUsedWayList.add(oldWayIds[i])
	};
	echo('n   ',true);
};

function intersectWay(way,cutter,usedWayList,notUsedWayList){
	echo('way['+way.id+']r',true,true);
	var hSmallMap=cutter.dstMapHelper,hBigMap=cutter.srcMapHelper,bPoly=cutter.bPoly,wid=way.id;
	if(usedWayList.isIn(wid)){
		echo('i',true);
	};
	var nl=cutter.buildNodeListArray([way])[0];
	echo('c',true,true);
	if(!intersectWay.nextNodeId)intersectWay.nextNodeId=hSmallMap.getNextNodeId();
	if(!intersectWay.nextWayId)intersectWay.nextWayId=hSmallMap.getNextWayId();
	var newNodeIdStart=intersectWay.nextNodeId,newNodeIdEnd=newNodeIdStart+1;
	//nl is array of nodes
	var isPoly=(nl.length>2)&&(nl[0].id==nl[nl.length-1].id);
	var intersection=bPoly.getIntersection(hBigMap.map,nl,newNodeIdStart).toArray();
	var replacement=[],icarea=0,perimeter=0,tags=way.tags;
	echo('s',true,true);
	//intersection is array of array of nodes - represents several simple poly in multipoly(in general case) result
	for(var j=0;j<intersection.length;j++){
		//check every simple poly in result
		var interPoly=intersection[j].toArray();
		//$$$dbg echo('	intersection '+j+' nn='+interPoly.length);
		var nids=[],prevNode=false;
		for(var k=0;k<interPoly.length;k++){
			var curNode=interPoly[k];
			curNode.tags.deletebyKey('osman:parent');
			var nid=curNode.id;
			if(nid<=newNodeIdStart){
				//store new node to map
				curNode=hSmallMap.findOrStore(curNode);
				interPoly[k]=curNode;
				nid=curNode.id;
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
		if(nids.length)way.nodes=nids;else continue;
		if(isPoly){
			//all polies in intersection are outer, so we can check them one by one
			var ipoly=h.gt.createPoly();
			ipoly.addObject(way);
			if(dualResolve(ipoly,hSmallMap,hBigMap)){
				icarea+=ipoly.getArea();
			}else{
				//not resolved - we have incomplete map or empty intersection, icarea==0 => way would be deleted.
				var nr=ipoly.getNotResolved().getAll().toArray();
				if(nr.length>0)echo('\n	not resolved list:');else echo(' empty way',true);
				for(var i=0;i<nr.length;i+=3){
					echo('		'+nr[i]+'['+nr[i+1]+']');
				};
				continue;
			};
			//$$$dbg echo(' ipoly '+j+'/'+intersection.length+' S='+(icarea/1e6)+'km2');//$$$dbg 
		}else{
			var notFoundRefs=hSmallMap.getObjectChildren(way,3);
			for(var k=0;k<notFoundRefs.length;k++){
				var nd=hBigMap.getObject(notFoundRefs[k]);
				if(nd)hSmallMap.map.putObject(nd);
			};
		};
		replacement.push(way);
		if(way.id<=intersectWay.nextWayId)intersectWay.nextWayId=way.id-1;
		way=hSmallMap.map.createWay();
		way.tags=tags;
		way.id=intersectWay.nextWayId;
	};
	var ratio=(isPoly && (perimeter>0))?(icarea/(perimeter*perimeter)*16):(0);
	echo(' P='+(perimeter/1e3).toFixed(3)+((isPoly)?(' S='+(icarea/1e6).toFixed(3)+'km2 R='+ratio.toFixed(4)):('')),true,true);
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
		//$$$dbg echo('	too small or too big. delete it');//$$$dbg 
	};
	way=(replacement.length>0)?(replacement[0]):(way);
	intersectWay.nextNodeId=newNodeIdEnd-1;
	echo('r',true,true);
	switch(replacement.length){
		case 0://way should be deleted
			notUsedWayList.add(way.id);
			//$$$dbg echo('nodes '+newNodeIdEnd+'...'+newNodeIdStart+' deleted');//$$$dbg 
			hSmallMap.exec('DELETE FROM nodes WHERE id BETWEEN '+newNodeIdEnd+' AND '+newNodeIdStart);
			intersectWay.nextNodeId=newNodeIdStart;
			if(!usedWayList.isIn(wid)){
				way.id=wid;
				hSmallMap.replaceObject(way,[]);
				//$$$dbg echo(' deleted '+way.id);//$$$dbg 
			}else{
				echo('\n In used list. Not deleted way id='+way.id);//$$$dbg 
			};
			break;
		case 1://no changes in referers. Just store way into map
			hSmallMap.map.putWay(way);
			usedWayList.add(wid);
			break;
		default:
			hSmallMap.replaceObject(way,replacement);
			usedWayList.add(wid);
			//$$$dbg echo('	multiplicated');
			break;
	};
	echo('n   ',true);
	//$$$dbg echo(' replace with '+replacement.length+' way(s)');//$$$dbg 
};

function main(){
	h.man.logger={log:function(s){echo('OSMan: '+s)}};
	var funcName='areaCut.main: ';
	if(!checkArgs())return;
	cutBound=cutBound.split(',');
	if(!cutBound.length)throw funcName+'empty bounds';
	/*create/restore backup DB if map created elsewhere 
	if(noImport){
		if(h.fso.fileExists(smallMapFile+'.bak')){
				echot('Copy file from backup');
				h.fso.copyFile(smallMapFile+'.bak',smallMapFile,true);
		}else{
				echot('Copy file to backup');
				h.fso.copyFile(smallMapFile,smallMapFile+'.bak',true);
		};
	};*/
	var hBigMap=h.mapHelper(),hSmallMap=h.mapHelper();
	hBigMap.open(bigMapFile,false,true);//no recreation, read-only
	var mpr=h.getMultiPoly(cutBound,hBigMap.map);
	var bPoly=h.gt.createPoly();
	for(var i=0;i<cutBound.length;i++){
		var bound=hBigMap.getObject(cutBound[i]);
		if(!bound) throw funcName+'boundary object not found='+cutBound[i];
		bPoly.addObject(bound);
	}
	echot('resolving boundary');
	if(!bPoly.resolve(hBigMap.map)){
		throw funcName+'boundary object '+cutBound+' not resolved';
	};
	echo('	cut area is '+(bPoly.getArea()/1e6).toFixed(3)+' km2');
	if(noImport){
		hSmallMap.open(smallMapFile);
	}else{
		hSmallMap.open(smallMapFile,true,false);//force recreate, read-write
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
	var usedWayList=hSmallMap.map.storage.createIdList();
	var notUsedWayList=hSmallMap.map.storage.createIdList();
	//add boundary to `used` list
	for(var i=0;i<cutBound.length;i++){
		var bound=hBigMap.getObject(cutBound[i]);
		if(bound.getClassName()=='Way'){
			usedWayList.add(bound.id)
		}else{//bound is relation
			var wl=(h.polyIntersector(hBigMap,hSmallMap,bPoly)).buildWayList(bound);
			for(var j=0;j<wl.length;j++){
				usedWayList.add(wl[j].id);
			};
		};
	}
	//remove child polygon-relations from relation processing list. Children will processed in parent-relation procedure
	echot('Removing child relations');
	removeChildPoly(icptRelList,hSmallMap,hBigMap);
	echot('Intersecting multipolygons');
	var rlist=hSmallMap.exec('SELECT id FROM '+icptRelList.tableName);
	var cutter=h.polyIntersector(hBigMap,hSmallMap,bPoly);
	while(!rlist.eos){
		var rid=rlist.read(1).toArray()[0],rel=hBigMap.map.getRelation(rid);
		if(rid!=151234)continue;//$$$
		if(!rel){
			echo('	relation '+rid+' not found. Deleted.');
			rel=hSmallMap.map.createRelation();
			rel.id=rid;
			hSmallMap.replaceObject(rel,[]);
			continue;
		};
		intersectMultipoly(rel,cutter,usedWayList,notUsedWayList,icptWayList);
	};
	icptRelList=0;
	echo('');echot('Intersecting ways');
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
		intersectWay(way,cutter,usedWayList,notUsedWayList);
	};
	icptWayList=0;
	echo('');echot('Deleting not used ways.');
	//now analize 'way used' and 'way not used' lists. We can safely delete way in ('way not used'-'way used') set
	//hSmallMap.exec('DELETE FROM '+icptWayList.tableName+' WHERE id IN (SELECT id FROM '+usedWayList.tableName+')');
	var qKillWays=hSmallMap.exec('SELECT id FROM '+notUsedWayList.tableName+' WHERE id not in (SELECT id FROM '+usedWayList.tableName+')');
	var wdel=0;
	for(var kway=hSmallMap.map.createWay();!qKillWays.eos;){
		kway.id=qKillWays.read(1).toArray()[0];
		//$$$dbg echo('	request to delete way['+kway.id+']'); //$$$dbg
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
main();
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
