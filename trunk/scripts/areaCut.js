//settings start
var bigMapFile='f:\\db\\osm\\sql\\rf.db3';
var smallMapFile='f:\\db\\osm\\sql\\krr.db3';
var exportFileName='f:\\db\\osm\\sql\\krr.osm';
var cutBound='relation:269701';
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
	echo(''+(new Date()).toLocaleString()+' '+s,l,r);
}

//end global variables
//helpers part
function PolyIntersector(srcMap,dstMap,boundMultiPoly,h){//$$$ remove h from visible arguments
	var t=this;
	t.srcMap=srcMap;
	t.dstMap=dstMap;
	t.bPoly=boundMultiPoly;
	t.h=h;
};

PolyIntersector.prototype.buildWayList=function(relation){
	//convert Relation into one-dimension Way object array.
	//Subrelations recursively proccessed too.
	//If some way or subrelation missed in map then empty array returned
	var rs=[],t=this,r=relation,rm=r.members.getAll().toArray(),map=t.srcMap;
	for(var i=0;i<rm.length;i+=3){
		//skip nodes - they not processed at all
		if(rm[i]=='way'){
			//process way
			var way=map.getWay(rm[i+1]);
			if(!way){
				echo('Relation '+r.id+' missed way '+rm[i+1]);
				return [];
			};
			way.tags.setByKey('osman:parent',r.id);
			rs.push(way);
		}else if((rm[i]=='relation')&&(rm[i+2]!='subarea')){
			//process subrelations
			var sr=map.getRelation(rm[i+1]);
			if(!sr){
				echo('Relation '+r.id+' missed relation '+rm[i+1]);
				return [];
			}else{
				var st=sr.tags.getByKey('type');
				if((st!='multipolygon')&&(st!='boundary')){
					echo('	relation '+(rm[i+1])+' of type '+st+' skipped');
					continue;
				}
				sr=t.buildWayList(sr);
				if(!sr.length)return [];
				rs=rs.concat(sr);
			}
		}
	};
	return rs;
};

PolyIntersector.prototype.buildNodeListArray=function (wayList){
	//wayList - 1-dimensional Way object list[Way1,Way2....]
	//returns 2-dimensional NodeList=[[way1 nodes],[way2 nodes]...]
	var rs=[],t=this;
	for(var i=0;i<wayList.length;i++){
		var na=t.h.gt.wayToNodeArray(t.srcMap,wayList[i]).toArray();
		rs.push(na);
		for(var ni=0;ni<na.length;ni++){
			na[ni].tags.setByKey('osman:parent',wayList[i].id);
		};
	};
	return rs;
};

PolyIntersector.prototype.mergeNodeLists=function(nodeList){
	//convert two-dimensional NodeList into simple polygon list.
	//Examle: [[1,2],[2,3],[3,1],[5,6,7,5]] => [[1,2,3,1],[5,6,7,5]]
	//If any polygon not closed then <false> returned.
	function merge2(l1,l2){
		//l1=l1 merged with l2
		//return [] if l1 and l2 not merged
		var l10=l1[0].id,l20=l2[0].id,l11=l1[l1.length-1].id,l21=l2[l2.length-1].id;
		var s;
		if(l10==l20){
			//new=reverse(old)+segment
			s=l1[0].tags.getByKey('osman:parent');
			s+=';'+l2[0].tags.getByKey('osman:parent');
			l1[0].tags.setByKey('osman:parent',s);
			l2.shift();
			l1.reverse();
			l1=l1.concat(l2);
			return l1;
		}else if(l11==l20){
			//new=old+segment
			s=l1[l1.length-1].tags.getByKey('osman:parent');
			s+=';'+l2[0].tags.getByKey('osman:parent');
			l1[l1.length-1].tags.setByKey('osman:parent',s);
			l2.shift();
			l1=l1.concat(l2);
			return l1;
		}else if(l10==l21){
			//new=segment+old
			s=l1[0].tags.getByKey('osman:parent');
			s+=';'+l2[l2.length-1].tags.getByKey('osman:parent');
			l1[0].tags.setByKey('osman:parent',s);
			l2.pop();
			l1=l2.concat(l1);
			return l1;
		}else if(l11==l21){
			//new=segment+reverse(old)
			s=l1[l1.length-1].tags.getByKey('osman:parent');
			s+=';'+l2[l2.length-1].tags.getByKey('osman:parent');
			l1[l1.length-1].tags.setByKey('osman:parent',s);
			l2.pop();
			l1.reverse();
			l1=l2.concat(l1);
			return l1;
		}else{
			return [];
		};
	};
	var doRepeat,rs;
	do{
		doRepeat=false;
		rs=true;
		for(var i=0;i<nodeList.length;i++){
			if(nodeList[i][0].id==nodeList[i][nodeList[i].length-1].id)continue;//nodeList[i] is polygon already
			rs=false;
			for(var j=i+1;j<nodeList.length;j++){
				var merged=merge2(nodeList[i],nodeList[j]);
				if(merged.length){
					nodeList[i]=merged;
					doRepeat=true;
					nodeList.splice(j,1);
					j--;
				}
			}
		};
	}while(doRepeat);
	return rs;
};

//end of helpers part

function deleteRelAndSubrels(map,rel){
//delete multipoly relation rel and of its sub-multipoly relations (recurcive).
	var rstack=[rel];
	while(rstack.length){
		rel=rstack.pop();
		map.deleteRelation(rel.id);
		var rmem=rel.members.getAll().toArray();
		for(var rmemi=0;rmemi<rmem.length;rmemi+=3){
			//skip non-relation members
			if(rmem[rmemi]!='relation')continue;
			//skip subarea - it`s not a part of poly. It`s administrative subunit
			if(rmem[rmemi+2]=='subarea')continue;
			var rid=rmem[rmemi+1];
			rel=map.getRelation(rid);
			//delete relation on map and add it for child-checking stack
			if(rel){
				rstack.push(rel);
			};
		};
	};
};

function main(){
	var funcName='areaCut.main: ';
	var hBigMap=h.mapHelper(),hSmallMap=h.mapHelper();
	hBigMap.open(bigMapFile,false,true);
	hBigMap.exec('PRAGMA cache_size=128000');
	var bound=hBigMap.getObject(cutBound);
	if(!bound) throw funcName+'boundary object not found='+cutBound;
	var bPoly=h.gt.createPoly();
	bPoly.addObject(bound);
	echot('resolving boundary')
	if(!bPoly.resolve(hBigMap.map)){
		throw funcName+'boundary object '+cutBound+' not resolved';
	};
	echo('	cut area is '+Math.round(bPoly.getArea()/1000000)+' km2');
	hSmallMap.open(smallMapFile,true,false);
	bbox=bPoly.getBBox().toArray();
	echot('exporting small map');
	hBigMap.exportDB(hSmallMap.map,[':bpoly',bPoly,':bbox'].concat(bbox));
	echot('building incomplete ways');
	var icptWayList=hSmallMap.map.storage.createIdList();
	hSmallMap.exec('INSERT OR IGNORE INTO '+icptWayList.tableName+'(id) SELECT wayid FROM waynodes WHERE nodeid NOT IN (SELECT id FROM NODES)');
	echot('building incomplete relations');
	var icptRelList=hSmallMap.map.storage.createIdList();
	hSmallMap.exec('INSERT OR IGNORE INTO '+icptRelList.tableName+'(id) SELECT relationid FROM relationmembers WHERE relationid IN (SELECT objid>>2 FROM objtags WHERE tagid IN (SELECT id FROM tags WHERE tagname=\'type\' AND tagvalue IN (\'boundary\',\'multipolygon\')) AND (objid&3)=2) AND((memberidxtype&3=1 AND memberid NOT IN (SELECT id FROM ways)) OR (memberidxtype&3=2 AND memberid NOT IN (SELECT id FROM relations)))');
	echot('Removing child relations');
	var rlist=hSmallMap.exec('SELECT id FROM '+icptRelList.tableName);
	var rtot=0,rdel=0;
	while(!rlist.eos){
		var rstack=rlist.read(1).toArray()[0];
		rtot++;
		while(rstack.length){
			var rid=rstack.pop();
			var rel=hBigMap.map.getRelation(rid);
			if(!rel)continue;
			var rmem=rel.members.getAll().toArray();
			for(var rmemi=0;rmemi<rmem.length;rmemi+=3){
				if(rmem[rmemi]!='relation')continue;
				if(rmem[rmemi+2]=='subarea')continue;
				rid=rmem[rmemi+1];
				rstack.push(rid);
				rdel++;
				hSmallMap.deleteRelation(rid);
			};
		};
	};
	echo('	'+rdel+' of '+rtot+' relations deleted');
	echot('Intersecting multipolygons');
	rlist=hSmallMap.exec('SELECT id FROM '+icptRelList.tableName);
	var cutter=new PolyIntersector(hBigMap.map,hSmallMap.map,bPoly,h);//$$$ remove h from visible arguments
	rtot=0;rdel=0;
	while(!rlist.eos){
		var rid=rlist.read(1).toArray()[0],rel=hBigMap.map.getRelation(rid);
		rtot++;
		if(!rel){
			echo('	relation '+rid+' not found. Deleted.');
			hSmallMap.map.deleteRelation(rid);
			rdel++;
			continue;
		};
		var wl=cutter.buildWayList(rel);
		if(!wl.length){
			echo('	relation '+rid+' has empty way list. Deleted.');
			hSmallMap.map.deleteRelation(rid);
			rdel++;
			continue;
		};
		//Way in area test - skip relations without ways in target area
		var hasWayInSmallMap=false;
		for(var i=0;i<wl.length;i++){
			hasWayInSmallMap=(hSmallMap.map.getWay(wl[i].id))?(true):(false);
			if(hasWayInSmallMap)break;
		};
		if(!hasWayInSmallMap){
			rdel++;
			hSmallMap.map.deleteRelation(rid);
			continue;
		};
		//end of Way in area test
		var nl=cutter.buildNodeListArray(wl);
		if(!cutter.mergeNodeLists(nl)){
			rdel++;
			hSmallMap.map.deleteRelation(rid);
			echo('	relation '+rid+' has not-closed polygons. Skipped.');
			continue;
		};
		var icnt=0,nncnt=0,icarea=0;
		echo('	r'+rid+'('+rel.tags.getByKey('name')+')',true,true);
		var ipoly=h.gt.createPoly();
		var newNodeIdStart=hSmallMap.getNextNodeId();
		for(var i=0;i<nl.length;i++){
			var intersection=bPoly.getIntersection(hBigMap.map,nl[i],hSmallMap.getNextNodeId()).toArray();
			icnt+=intersection.length;
			for(var j=0;j<intersection.length;j++){
				intersection[j]=intersection[j].toArray();
				var cluster=hSmallMap.map.createWay(),nids=[];
				for(var k=0;k<intersection[j].length;k++){
					var nid=intersection[j][k].id;
					if(nid<0){
						nncnt++;
						hSmallMap.map.putNode(intersection[j][k]);
					};
					nids.push(nid);
				};
				cluster.nodes=nids;
				ipoly.addObject(cluster);
			};
		};
		if(ipoly.resolve(hSmallMap.map)){
			icarea=ipoly.getArea();
		}else{
			var nr=ipoly.getNotResolved().getAll().toArray();
			if(nr.length>0)echo('\n	not resolved list:');else echo(' empty poly',true,true);
			for(var i=0;i<nr.length;nr+=3){
				echo('		'+nr[i]+'['+nr[i+1]+']');
			};
		};
		var ncnt=0;
		for(var i=0;i<nl.length;i++){
			ncnt+=nl[i].length;
		};
		echo(' poly='+nl.length+' nodes='+ncnt+' ipoly='+icnt+' S='+Math.round(icarea/1e6)+'km2 new_nodes='+nncnt);
		if((icarea==0)||(icarea==bPoly.getArea())){
			deleteRelAndSubrels(hSmallMap.map,rel);
			rdel++;
			echo('	deleted');
		};
	};
	echot(''+rdel+' of '+rtot+' deleted');
	echot('Exporting map');
	hSmallMap.exportXML(exportFileName);
	echot('closing maps');
	hBigMap.close();
	hSmallMap.close();
	echot('all done');
};

main();