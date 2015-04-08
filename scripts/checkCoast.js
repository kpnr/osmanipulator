//settings begin
var worldMapName='';
var coastMapName='';
//settings end
var MAX_INT=(-1>>>1);
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

//global variables
var h=new (include('helpers.js'))();
var echo=h.echo,indexOf=h.indexOf;
function echot(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
}
//end global variables
function read(){
	return WScript.stdIn.readLine();
};

function checkArgs(){
	function help(){
	echo('Global coastline checker.\n\
  Command line options:\n\
    /world:"world_file_name.db3" - world map for check\n\
    /coast:"coast_file_name.db3" - coast check internal db');
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('world'))worldMapName=ar.item('world')||worldMapName;
	if(ar.exists('coast'))coastMapName=ar.item('coast')||coastMapName;
	if(worldMapName && coastMapName){
		echo('Use config:');
		echo('world='+worldMapName);
		echo('coast='+coastMapName);
		return true;
	}
	help();
	return false;
};

function resolvePoly(mp,rel,map){
	var nWays=0, nNodes=0;
	mp.addObject(rel);
	return mp.resolve({
		getNode:function(id){
			var n=map.getNode(id)
			n.tags.setAll([]);
			n.username='';
			n.userid=0;
			nNodes++;
			if(!(nNodes&1023)){
				echo('RelId='+rel.id+' Ways='+nWays+' Nodes='+nNodes+' ',1);
			}
			return n;
		},
		getWay:function(id){
			var w=map.getWay(id);
			w.tags.setAll([]);
			w.username='';
			w.userid=0;
			nWays++;
			if(!(nWays&1023)){
				echo('RelId='+rel.id+' Ways='+nWays+' Nodes='+nNodes+' ',1);
			}
			return w;
		}
		})
};

function main(){
	if(!checkArgs())return 2;
	echot('Opening map');
	var src=h.mapHelper(),dst=h.mapHelper();
	src.open(worldMapName,false,true);
	src.exec('PRAGMA cache_size=1000');
	dst.open(coastMapName);
	dst.exec('PRAGMA cache_size=1000');
	dst.exec('COMMIT');dst.exec('ATTACH "'+worldMapName+'" AS world');dst.exec('BEGIN');
	var dstg=dst.map.storage,sstg=src.map.storage;
	var relData=dst.exec('SELECT OBJID>>2 FROM objtags WHERE tagid IN (\
		SELECT id FROM tags WHERE tagname="type" and tagvalue="osman:metadata") AND objid&3=2').read(1).toArray();
	if(!(relData && relData.length)){
		relData=dst.map.createRelation();
		relData.id=dst.getNextRelationId();
		relData.tags.setByKey('type','osman:metadata');
		relData.tags.setByKey('lastTimestamp','10001231235959');
	}else{
		relData=dst.map.getRelation(relData[0]);
	};
	var minTime=relData.tags.getByKey('lastTimestamp'),maxTime=parseFloat(minTime);
	echot('Searching deleted ways');
	var ilWays=dst.map.storage.createIdList(), ilRelations=dst.map.storage.createIdList();
	//search deleted ways
	dst.exec('INSERT INTO '+ilWays.tableName+' SELECT id FROM ways WHERE id+0 NOT IN(SELECT id FROM world.ways)');
	echot('Searching modified ways');
	dst.exec('INSERT OR IGNORE INTO '+ilWays.tableName+' SELECT id FROM world.ways WHERE id IN (SELECT id FROM ways) AND timestamp>=:checkTime',':checkTime',maxTime);
	echot('DB cleanup');
	//search affected  relations
	dst.exec('INSERT OR IGNORE INTO '+ilRelations.tableName+'(id) SELECT relationid FROM relationmembers WHERE memberid IN (SELECT id FROM '+ilWays.tableName+') AND memberidxtype&3=1');
	//delete relations
	dst.exec('DELETE FROM objtags WHERE objid IN (SELECT id*4+2 FROM '+ilRelations.tableName+')');
	dst.exec('DELETE FROM relationmembers WHERE relationid IN  (SELECT id FROM '+ilRelations.tableName+')');
	dst.exec('DELETE FROM relations WHERE id IN (SELECT id FROM '+ilRelations.tableName+')');
	//search for not-in-relation ways
	dst.exec('INSERT OR IGNORE INTO '+ilWays.tableName+' SELECT id FROM ways WHERE id NOT IN (SELECT memberid FROM relationmembers WHERE memberidxtype&3=1)');
	//delete ways not in relations
	dst.exec('DELETE FROM objtags WHERE objid IN (SELECT id*4+1 FROM '+ilWays.tableName+')');
	//waynodes are not stored in coast db, so not need to delete
	dst.exec('DELETE FROM ways WHERE id IN (SELECT id FROM '+ilWays.tableName+')');
	//clear idlists
	dst.exec('DELETE FROM '+ilWays.tableName);
	dst.exec('DELETE FROM '+ilRelations.tableName);
	dst.exec('COMMIT');
	try{
		dst.exec('DETACH world');
	}catch(e){
		echo('world db not detached.'+e.message);
	};
	dst.exec('BEGIN');
	echot('Searching coastlines...');
	var nRings=0,nWays=0,nNodes=0;
	var qCoastIds=src.exec('SELECT OBJID>>2 FROM objtags WHERE tagid IN (\
		SELECT id FROM tags WHERE tagname="natural" AND tagvalue="coastline") AND objid&3=1');
	var qDstCoastIdExist=dstg.sqlPrepare('SELECT EXISTS(SELECT id FROM ways WHERE id=:id)'),
		qPutWayAttr=dstg.sqlPrepare('INSERT OR REPLACE INTO strways (id,version,timestamp,userid,username,changeset) VALUES(:id,:version,:timestamp,:userid,:username,:changeset)');
		qGetWayAttr=sstg.sqlPrepare('SELECT id, version, timestamp, userid, username, changeset FROM strways WHERE id=:id');
		qGetWayNodes=sstg.sqlPrepare('SELECT nodeid FROM waynodes WHERE wayid=:id AND nodeidx IN ((SELECT min(nodeidx) FROM waynodes WHERE wayid=:id),(SELECT max(nodeidx) FROM waynodes WHERE wayid=:id)) ORDER BY nodeidx ');
		qGetWayNodeCnt=sstg.sqlPrepare('SELECT count(0) FROM waynodes WHERE wayid=:id');
		qGetNextWayAndNode=sstg.sqlPrepare(
			'SELECT wayid,(SELECT nodeid FROM waynodes as wn WHERE wn.wayid=waynodes.wayid \
			AND wn.nodeidx=(SELECT max(nodeidx) FROM waynodes as wn WHERE wayid=waynodes.wayid)) as lastId \
			FROM waynodes WHERE nodeid=:firstId AND nodeidx=0 \
			AND exists(SELECT * FROM objtags WHERE tagid IN (SELECT id FROM tags WHERE tagname="natural" AND tagvalue="coastline") \
			AND objid=wayid*4+1)');
	while(!qCoastIds.eos){
		var wid=qCoastIds.read(1).toArray()[0];
		if(dstg.sqlExec(qDstCoastIdExist,':id',wid).read(1).toArray()[0]){
			//already checked
			continue;
		};
		var relRing=dst.map.createRelation(),ncnt=0;
		relRing.id=dst.getNextRelationId();
		relRing.tags.setByKey('type','multipolygon');
		relRing.tags.setByKey('natural','coastline');
		relRing.tags.setByKey('source','osman:coastchecker');
		relRing.members.insertBefore(MAX_INT,'way',wid,'');
		var wayAttrs=sstg.sqlExec(qGetWayAttr,':id',wid).read(1).toArray(),wnodes=sstg.sqlExec(qGetWayNodes,':id',wid).read(2).toArray();
		var firstId=wnodes[0],lastId=wnodes[1];
		ncnt+=sstg.sqlExec(qGetWayNodeCnt,':id',wid).read(1).toArray()[0];
		dstg.sqlExec(qPutWayAttr,[':id',':version',':timestamp',':userid',':username',':changeset'],wayAttrs);
		if(wayAttrs[2]>maxTime)maxTime=wayAttrs[2];
		nWays++;
		while(firstId!=lastId){
			var nw=sstg.sqlExec(qGetNextWayAndNode,':firstId',lastId).read(1).toArray();
			if(!(nw && nw.length)){
				relRing.tags.setByKey('osman:orientation','none');
				echo('Broken coastline near node['+lastId+']');
				break;
			};
			wid=nw[0];
			lastId=nw[1];
			relRing.members.insertBefore(MAX_INT,'way',wid,'');
			wayAttrs=sstg.sqlExec(qGetWayAttr,':id',wid).read(1).toArray();
			ncnt+=sstg.sqlExec(qGetWayNodeCnt,':id',wid).read(1).toArray()[0];
			dstg.sqlExec(qPutWayAttr,[':id',':version',':timestamp',':userid',':username',':changeset'],wayAttrs);
			if(wayAttrs[2]>maxTime)maxTime=wayAttrs[2];
			nWays++;
			if(!(nWays&15))echo('Ways='+nWays+' Rings='+nRings,1);
		};
		relRing.tags.setByKey('osman:nodecount',''+ncnt);
		dst.map.putRelation(relRing);
		nRings++;
		echo('Ways='+nWays+' Rings='+nRings,1);
	};
	echo('');
	relData.tags.setByKey('lastTimestamp',''+maxTime);
	dst.map.putRelation(relData);
	echot('Computing area, orientation and bbox...');
	dst.exec('INSERT INTO '+ilRelations.tableName+' (id) SELECT objid>>2 FROM objtags WHERE tagid IN (SELECT id FROM tags WHERE tagname="source" AND tagvalue="osman:coastchecker") AND objid&3=2 AND NOT EXISTS(SELECT ot.objid FROM objtags AS ot WHERE ot.objid=objtags.objid AND tagid IN (SELECT id FROM tags WHERE tagname="osman:orientation"))');
	var qRelIds=dst.exec('SELECT id FROM '+ilRelations.tableName);
	while(!qRelIds.eos){
		var relation=dst.map.getRelation(qRelIds.read(1).toArray()[0]);
		var mpoly=h.gt.createPoly();
		nWays=0;nNodes=0;
		echo('RelId='+relation.id+' Ways='+nWays+' Nodes='+nNodes+' ',1);
		if(!resolvePoly(mpoly,relation,src.map)){
			echo('Can`t resolve relation['+relation.id+']');
			continue;
		};
		relation.tags.setByKey('osman:area',(mpoly.getArea()/1e6).toFixed(3));
		relation.tags.setByKey('osman:orientation',['mixed','cc','ccw'][mpoly.getOrientation()]);
		var bbox=mpoly.getBBox().toArray();
		relation.tags.setByKey('osman:bbox',bbox[0].toFixed(7)+','+bbox[1].toFixed(7)+','+bbox[2].toFixed(7)+','+bbox[3].toFixed(7));
		dst.map.putRelation(relation);
	};
	echo('');echot('Renumbering objects...');
	dst.exec('DELETE FROM '+ilRelations.tableName);
	dst.renumberNewObjects();
	dst.exec('COMMIT');dst.exec('BEGIN');
	echot('Building bbox R-Tree...');
	try{
		dst.exec('CREATE VIRTUAL TABLE bboxes USING crtree_i32(objid,minlat,maxlat,minlon,maxlon)');
	}catch(e){};
	dst.exec('DELETE FROM bboxes');
	dst.exec('INSERT INTO '+ilRelations.tableName+' SELECT objid>>2 FROM objtags WHERE tagid IN (SELECT id FROM tags WHERE tagname="osman:bbox") AND objid&3=2');
	qRelIds=dst.exec('SELECT id*4+2 FROM '+ilRelations.tableName);
	var qGetObjBBox=dstg.sqlPrepare('SELECT tagvalue FROM tags WHERE id IN (SELECT tagid FROM objtags WHERE objid=:objid) AND tagname="osman:bbox"'),
		qSetBBox=dstg.sqlPrepare('INSERT INTO bboxes(objid,minlat,maxlat,minlon,maxlon) VALUES (:objid,:minlat,:maxlat,:minlon,;maxlon)');
	while(!qRelIds.eos){
		var objId=qRelIds.read(1).toArray()[0], bbox=dstg.sqlExec(qGetObjBBox,':objid',objId).read(1).toArray().split(',');
		for(var i=0;i<4;i++)bbox[i]=Math.round(parseFloat(bbox[i])*cDegToInt);
		bbox.push(objId);
		dstg.sqlExec(qSetBBox,[':minlat',':maxlon',':maxlat',':minlon',':objid'],bbox);
	};
	echot('Sorting bboxes...');
	var qGetRelIdByArea=dst.exec('SELECT objid>>2, CAST(tagvalue AS REAL) AS area FROM strobjtags WHERE tagname="osman:area" AND objid&3=2 ORDER BY area'),
		qGetChildBoxes=dstg.sqlPrepare('SELECT objid>>2,minlat,maxlat,minlon,maxlon FROM bboxes WHERE minlat>=:minlat AND maxlat<=:maxlat AND minlon>=minlon AND maxlon<=:maxlon AND objid<>:objid AND objid&3=2');
	qGetObjBBox=dstg.sqlPrepare('SELECT objid,minlat,maxlat,minlon,maxlon FROM bboxes WHERE objid=:objid');
	while(!qGetRelIdByArea.eos){
		var relId=qGetRelIdByArea.read(1).toArray();
		echo('rel/area='+relId[0]+'/'+relId[1],1);
		relId=relId[0];
		var bbox=dstg.sqlExec(qGetObjBBox,':objid',relId*4+2),
			mpoly=h.gt.createPoly(),
			relation=dst.map.getRelation(relId);
		if(!resolvePoly(mpoly,relation,src.map))continue;
		var sChildBoxes=dstg.sqlExec(qGetChildBoxes,[':objid',':minlat',':maxlat',':minlon',':maxlon'],bbox);
		while(!sChildBoxes.eos){
			var childBox=sChildBoxes.read(1).toArray();
			var childRel=dst.map.getRelation(childBox[0]), i=childRel.members.count-1,mtype,mid,mrole;
			while(i>=0){
				childRel.members.getByIdx(i,mtype,mid,mrole);
				if((mrole=='') && (mtype=='way'))break;
				i--;
			};
			if(!((mrole=='') && (mtype=='way')))continue;
			var node=src.map.getNode(src.map.getWay(mid).nodes.toArray()[0]);
			if(mpoly.isIn(node)){
				childRel.members.insertBefore(MAX_INT,'relation',relId,'parent');
			};
		};
	};
	dst.close();
	src.close();
	echot('All done.');
	return 0;
}

try{
var ec=main();
WScript.quit(ec);
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
