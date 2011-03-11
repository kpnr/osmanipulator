//settings
var regionBoundaryCollectionRelationId=184217;
var srcMapName='F:\\db\\osm\\sql\\rf.db3';
var dstDir='F:\\db\\osm\\rf_regions';
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

var h=new (include('helpers.js'))();
var echo=h.echo;

function createPoly(boundObject,aMap){
	var mp=h.gt.createPoly();
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

function cutWays(bigMap,bpoly,dstMap){$$$ replace with map helper
	echo('Cutting ways...');
	var d=new Date();
	var qway=dstMap.storage.sqlPrepare('select distinct (wayid) from waynodes where nodeid not in (select id from nodes)');
	var qway=dstMap.storage.sqlExec(qway,0,0);
	var way,wayId;
	
	function updateRelDeps(relId,newRelIds){
		if((newRelIds.length==1)&&(relId==newRelIds[0])){//we need no modification
			return;
		};
		//update relations with this relation-member
		var qrels=dstMap.storage.sqlPrepare('select distinct relationid from relationmembers where memberid=:relid');
		qrels=dstMap.storage.sqlExec(qrels,':relid',relId);
		while(!qrels.eos){
			var relId=qrels.read(1).toArray()[0];
			var rel=dstMap.getRelation(relId);
			var members=rel.members.getAll().toArray();
			var relModified=false;
			for(var i=0;i<members.length;i+=3){
				if((members[i]=='relation')&&(members[i+1]==relId)){
					var role=members[i+2];
					members.splice(i,3);//delete old relation-member
					for(var j=0;j<newRelIds.length;j++){
						//add new way-members
						members.splice(i,0,'relation',newRelIds[j],role);
						i+=3;
						relModified=true;
					};
				};
			};
			if(relModified){
				if(members.length>0){
					rel.members.setAll(members);
					dstMap.putRelation(rel);
				}else{
					dstMap.deleteRelation(relId);
					updateRelDeps(relId,[]);
				}
			};
		};
	};
	
	function updateWayDeps(wayId,newWaysIds){
		if((newWaysIds.length==1)&&(wayId==newWaysIds[0])){//we need no modification
			return;
		};
		//update relations with this way
		var qrels=dstMap.storage.sqlPrepare('select distinct relationid from relationmembers where memberid=:wayid');
		qrels=dstMap.storage.sqlExec(qrels,':wayid',wayId);
		while(!qrels.eos){
			var relId=qrels.read(1).toArray()[0];
			var rel=dstMap.getRelation(relId);
			var members=rel.members.getAll().toArray();
			var relModified=false;

			for(var i=0;i<members.length;i+=3){
				if((members[i]=='way')&&(members[i+1]==wayId)){
					var role=members[i+2];
					members.splice(i,3);//delete old way-member
					for(var j=0;j<newWaysIds.length;j++){
						//add new way-members
						members.splice(i,0,'way',newWaysIds[j],role);
						i+=3;
						relModified=true;
					};
				};
			};
			if(relModified){
				if(members.length>0){
					rel.members.setAll(members);
					dstMap.putRelation(rel);
				}else{
					dstMap.deleteRelation(relId);
					updateRelDeps(relId,[]);
				}
			};
		};
	};

	while(!qway.eos){
		wayId=qway.read(1).toArray()[0];
		way=dstMap.getWay(wayId);
		if(!way)continue;
		var ipt=[];
		var wns=h.gt.wayToNodeArray(bigMap,way);//we can optimize speed by skipping 'out-of-bound' nodes
		var nextNodeId=dstMap.getNextNodeId();
		try{
			ipt=bpoly.getIntersection(bigMap,wns,nextNodeId).toArray();
		}catch(e){
			echo(''+e.message);
		}
		var nextWayId=dstMap.getNextWayId();
		var wayTags=way.tags;
		var wayIds=[];
		for(var i=0;i<ipt.length;i++){
			var seg=ipt[i].toArray();
			for(var j=0;j<seg.length;j++){
				if((seg[j].id<=nextNodeId)||(seg[j].tags.getByKey('osman:note')=='boundary')){
					dstMap.putNode(seg[j]);
				};
				seg[j]=seg[j].id;
			};
			way.nodes=seg;
			dstMap.putWay(way);
			wayIds.push(way.id);
			way=dstMap.createWay();
			way.id=nextWayId;
			way.tags=wayTags;
			nextWayId--;
		};
		if(ipt.length==0){
			dstMap.deleteWay(wayId);
		};
		updateWayDeps(wayId,wayIds);
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
var srcMap=h.mapHelper();
srcMap.open(srcMapName);
srcMap.map.storage.sqlExec(srcMap.map.storage.sqlPrepare('PRAGMA cache_size=150000'),0,0);
var bound=srcMap.map.getRelation(145194);
if(!bound){
	echo('	not found');
};
echo('	name='+bound.tags.getByKey('name'));
var bp=h.gt.createPoly();
bp.addObject(bound);
var retryResolve=true;
while(retryResolve && !bp.resolve(srcMap.map)){
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
				srcMap.map.putObject(obj);
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
	echo('	Area='+Math.round(bp.getArea()/1000000)+' km2');
	var flt=[':bpoly',bp,':bbox'].concat(bp.getBBox().toArray());
	var dstMap=h.mapHelper();
	dstMap.open(h.fso.buildPath(dstDir, bound.tags.getByKey('name')+'.db3'),true);
	srcMap.exportDB(dstMap.map,flt);
	//dstMap.completeWayNodes(srcMap.map);
	//dstMap.completeRelationNodes(srcMap.map);
	//dstMap.completeRelationWays(srcMap.map);
	cutWays(srcMap.map,bp,dstMap.map);
	dstMap.exportXML(h.fso.buildPath(dstDir, bound.tags.getByKey('name')+'_clipped.osm'));
};