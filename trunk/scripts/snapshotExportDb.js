//settings
var regionBoundaryCollectionRelationId=184217;
var srcMapName='F:\\db\\osm\\sql\\rf.db3';
var dstDir='F:\\db\\osm\\rf_regions';
var minNodeDist=0.1;//0.1 meter
//end settings

//boundary Russia relation = 60189
//boundary Алтай relation = 145194
//boundary Московская область relation =51490
//субъекты РФ relation=184217
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

var man=WScript.createObject('OSMan.Application');
var gt=man.createObject('GeoTools');
var fso=WScript.createObject('Scripting.FileSystemObject');

function echo(s){
	WScript.StdOut.write(s+'\n');
};

function openMap(storageName){
	var stg=man.createObject('Storage');
	var map=man.createObject('Map');
	var initStg=!fso.fileExists(storageName);
	stg.dbName=storageName;
	map.storage=stg;
	if (initStg){
		map.initStorage();
	};
	return map;
};

function createPoly(boundObject,aMap){
	var mp=gt.createPoly();
	mp.addObject(boundObject);
	if(mp.resolve(aMap)){
		return mp;
	}else {
		echo('Not resolved refs:');
		var url=mp.getNotResolved().getAll().toArray();
		for(var i=0;i<url.length;i+=3){
			echo('	'+url[i]+'	'+url[i+1]+'	'+url[i+2]);
		};
		return false;
	}
}

function exportDB(srcMap,exportFilter,dstMap){
	echo('Exporting '+dstMap.storage.dbName+' ...');
	var d=new Date();
	var ss=srcMap.getObjects(exportFilter);
	while(!ss.eos){
		var obj=ss.read(1000).toArray();
		for(var i=0;i<obj.length;i++){
			dstMap.putObject(obj[i]);
		};
	};
	d=(new Date())-d;
	echo('	done in '+d+'ms');
}

function exportOSM(srcMap,exportFilter,dstFileName){
	echo('Exporting '+dstFileName+' ...');
	var d=new Date();
	var fw=man.createObject('FileWriter');
	fw.open(dstFileName);
	var ow=man.createObject('OSMWriter');
	ow.setOutputStream(fw);
	ow.setInputMap(srcMap);
	ow.write(exportFilter);
	d=(new Date())-d;
	echo('	done in '+d+'ms');
}

function completeWayNodes(srcMap,dstMap){
	echo('Competing ways...');
	var d=new Date();
	//medium select distinct nodeid from waynodes where not exists( select id from nodes where waynodes.nodeid=nodes.id)
	// 800ms	15200ms
	//fast select distinct nodeid from waynodes where nodeid not in (select id from nodes)
	// 600ms	12900ms
	var nidl=dstMap.storage.sqlPrepare('select distinct nodeid from waynodes where nodeid not in (select id from nodes)');
	nidl=dstMap.storage.sqlExec(nidl,0,0);
	while(!nidl.eos){
		var nid=nidl.read(1).toArray()[0];
		var n=srcMap.getNode(nid);
		if(!n)echo('Node '+nid+' not found');else dstMap.putObject(n);
	};
	d=(new Date())-d;
	echo('	done in '+d+'ms');
};

function completeRelationNodes(srcMap,dstMap){
	echo('Competing relation nodes...');
	var d=new Date();
	var nidl=dstMap.storage.sqlPrepare("select memberid from strrelationmembers where membertype='node'  and (memberid not in (select id from nodes))");
	nidl=dstMap.storage.sqlExec(nidl,0,0);
	while(!nidl.eos){
		var nid=nidl.read(1).toArray()[0];
		var n=srcMap.getNode(nid);
		if(!n)echo('Node '+nid+' not found');else dstMap.putObject(n);
	};
	d=(new Date())-d;
	echo('	done in '+d+'ms');
};

function completeRelationWays(srcMap,dstMap){
	echo('Competing relation ways...');
	var d=new Date();
	var nidl=dstMap.storage.sqlPrepare("select memberid from strrelationmembers where membertype='way'  and (memberid not in (select id from ways))");
	nidl=dstMap.storage.sqlExec(nidl,0,0);
	while(!nidl.eos){
		var nid=nidl.read(1).toArray()[0];
		var n=srcMap.getWay(nid);
		if(!n)echo('Way '+nid+' not found');else dstMap.putObject(n);
	};
	d=(new Date())-d;
	echo('	done in '+d+'ms');
};

function getNextNodeId(aMap){
	var stg=aMap.storage;
	var qry=stg.sqlPrepare('select min(id) from nodes;');
	var rslt=stg.sqlExec(qry,'','');
	if(rslt.eos)return 1;
	return Math.min(0,rslt.read(1).toArray()[0])-1;
};

function getNextWayId(aMap){
	var stg=aMap.storage;
	var qry=stg.sqlPrepare('select min(id) from ways;');
	var rslt=stg.sqlExec(qry,'','');
	if(rslt.eos)return 1;
	return Math.min(0,rslt.read(1).toArray()[0])-1;
};

function cutWays(bigMap,bpoly,dstMap){
	echo('Cutting ways...');
	var d=new Date();
	var qway=dstMap.storage.sqlPrepare('select distinct (wayid) from waynodes where nodeid not in (select id from nodes)');
	var qway=dstMap.storage.sqlExec(qway,0,0);
	var oldWay,wayId;
	
	function putNewWays(metaWay,metaIsIn){
		var metaId=[metaWay[0].id];
		for(var i=1;i<metaWay.length;i++){
		//merge too close new nodes
			var curNode=metaWay[i];
			metaId[i]=curNode.id;
			if(((metaId[i]<0)||(metaId[i-1]<0))&&(gt.distance(metaWay[i-1],curNode)<minNodeDist)){
				var delNodeIdx=i-1;copyNodeIdx=i;
				if(metaId[i]<0){
					delNodeIdx=i;copyNodeIdx=i-1;
				};
				metaWay.splice(delNodeIdx,1);
				metaIsIn[copyNodeIdx]=metaIsIn[delNodeIdx]||metaIsIn[copyNodeIdx];
				metaIsIn.splice(delNodeIdx,1);
				metaId.splice(delNodeIdx,1);
				i--;
			}
		};
		//add extra `fake` node to store way `tail` as regular case
		metaIsIn.push(false);
		metaWay.push(false);
		metaId.push(0);
		var newIds=[];
		var nextWayId=getNextWayId(dstMap);
		var wayStart=-1;
		for(var i=0;i<metaWay.length;i++){
			if(metaId[i]<0)dstMap.putObject(metaWay[i]);
			if(metaIsIn[i] && (wayStart<0))wayStart=i;
			if((!metaIsIn[i]) && (wayStart>=0)){
				var newWayObj,newWayNodes=metaId.slice(wayStart,i);
				if(newWayNodes.length>1){
					//store only 2- and more- node ways
					if(!newIds.length){
						newWayObj=oldWay;
					}else{
						newWayObj=dstMap.createWay();
						newWayObj.id=nextWayId;nextWayId--;
						newWayObj.tags=oldWay.tags;
					};
					newIds.push(newWayObj.id);
					newWayObj.nodes=newWayNodes;
					dstMap.putWay(newWayObj);
				}else{
					dstMap.deleteWay(wayId);
				}
				wayStart=-1;
			}
		};
		//update relations with this way
		var qrels=dstMap.storage.sqlPrepare('select distinct relationid from relationmembers where memberid=:wayid');
		qrels=dstMap.storage.sqlExec(qrels,':wayid',wayId);
		while(!qrels.eos){
			var rel=dstMap.getRelation(qrels.read(1).toArray()[0]);
			var members=rel.members.getAll().toArray();
			var relModified=false;
			for(var i=0;i<members.length;i+=3){
				if((members[i]=='way')&&(members[i+1]==wayId)){
					var role=members[i+2];
					for(var j=1;j<newIds.length;j++){
						i+=3;
						members.splice(i,0,'way',newIds[j],role);
						relModified=true;
					};
					if(newIds.length==0){
						members.splice(i,3);
						i-=3;
						relModified=true;
					};
				};
			};
			if(relModified){
				rel.members.setAll(members);
				dstMap.putRelation(rel);
			};
		};
	};
	
	while(!qway.eos){
		wayId=qway.read(1).toArray()[0];
		oldWay=dstMap.getWay(wayId);
		if(!oldWay)continue;
		var wns=oldWay.nodes.toArray();
		if(wns[0]==wns[wns.length-1])continue;//skip polygons
		var ipt=[];
		try{
			ipt=bpoly.getIntersection(bigMap,oldWay).toArray();
		}catch(e){
			echo(''+e.message);
		}
		if(ipt.length>0){
			var isInTrigger=bpoly.isIn(bigMap.getNode(wns[0]));
			var metaWay=[];
			var metaWayIsIn=[];
			var wnsIdx=0;
			var nextNodeId=getNextNodeId(dstMap);
			for(var i=0;i<ipt.length;i++){
				var nd=ipt[i];
				nd.id=nextNodeId;nextNodeId--;
				var oi=parseInt(nd.tags.getByKey('osman:idx'));
				nd.tags.deleteByKey('osman:idx');
				for(;wnsIdx<=oi;wnsIdx++){
					metaWay.push(bigMap.getNode(wns[wnsIdx]));
					metaWayIsIn.push(isInTrigger);
				};
				metaWay.push(nd);
				metaWayIsIn.push(true);//intersection nodes are always threated as 'in-bound'
				isInTrigger=!isInTrigger;
			};
			for(;wnsIdx<wns.length;wnsIdx++){
				metaWay.push(bigMap.getNode(wns[wnsIdx]));
				metaWayIsIn.push(isInTrigger);
			};
			putNewWays(metaWay,metaWayIsIn);
		};
	};
	d=(new Date())-d;
	echo('	done in '+d+'ms');
};
/*
find imcomplete ways (with empty nodes)
	select distinct (wayid) from waynodes where nodeid not in (select id from nodes)
find areas (polygons) query:
	select wn1.wayid 
	from waynodes as wn1,waynodes as wn2 
	where wn1.wayid=wn2.wayid
	 and wn1.nodeid=wn2.nodeid 
	 and wn1.nodeidx=0
	 and wn2.nodeidx=(select max(nodeidx) from waynodes where waynodes.wayid=wn2.wayid)

find multipolygon relations
	select (objid >>2)as id 
	from objtags 
	where tagid in (select id 
	from tags where tagname='type' and (tagvalue='multipolygon' or tagvalue='boundary'))
	 and (objid & 3=2)
*/
var srcMap=openMap(srcMapName);
srcMap.storage.sqlExec(srcMap.storage.sqlPrepare('PRAGMA cache_size=150000'),0,0);
var bound=srcMap.getRelation(145194);
if(!bound){
	echo('	not found');
};
echo('	name='+bound.tags.getByKey('name'));
var bp=gt.createPoly();
bp.addObject(bound);
var retryResolve=true;
while(retryResolve && !bp.resolve(srcMap)){
	var ul=bp.getNotResolved().getAll().toArray();
	echo('	Resolving objects:');
	echo('l='+bp.getNotResolved().count);
	retryResolve=false;
	for(var j=0;j<ul.length;j+=3){
		WScript.stdOut.write('		('+(j/3+1)+'/'+(ul.length/3)+')'+ul[j]+'	id='+ul[j+1]);
		try{
			var obj=false;
			switch(ul[j]){
				case 'node':obj=netmap.getNode(ul[j+1]);break;
				case 'way':obj=netmap.getWay(ul[j+1]);break;
				case 'relation':obj=netmap.getRelation(ul[j+1]);break;
			};
			if(obj){
				srcMap.putObject(obj);
				retryResolve=true;
				WScript.stdOut.write(' resolved	\r');
			}else{
				echo(' not found');
			};
		}catch(e){
			echo(' failed with exception');
			continue;
		}
	};
	echo('');
};
if((bp.getNotResolved().count>0)){
	echo('	Poly not resolved. Skipped.');
}else if (bp.getNotClosed().count>0){
	echo('	Poly not closed. Skipped.');
}else{
	var flt=[':bpoly',bp,':bbox'].concat(bp.getBBox().toArray());
	var dstFileName=fso.buildPath(dstDir, bound.tags.getByKey('name')+'.db3');
	if(fso.fileExists(dstFileName))fso.deleteFile(dstFileName);
	var dstMap=openMap(dstFileName);
	exportDB(srcMap,flt,dstMap);
	//completeWayNodes(srcMap,dstMap);
	//completeRelationNodes(srcMap,dstMap);
	//completeRelationWays(srcMap,dstMap);
	cutWays(srcMap,bp,dstMap);
	exportOSM(dstMap,'',fso.buildPath(dstDir, bound.tags.getByKey('name')+'_clipped.osm'));
};