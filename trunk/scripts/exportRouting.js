//settings begin
var boundaryObject='';
var srcMapName='';
var dstMapName='';
var intToDeg=1e-7;
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;
function echot(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
}

function checkArgs(){
	function help(){
	echo('Export routing only objects (ways, places, restrictions...) from one database to another.\n\
  Command line options:\n\
    /bound:"relation:1,relation:12,relation:123" Optional argument. If ommitted then entire map processed.\n\
    /src:"src_file_name.db3"\n\
    /dst:"dest_file_name.db3"');
		return false;
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('src'))srcMapName=ar.item('src')||srcMapName;
	if(ar.exists('dst'))dstMapName=ar.item('dst')||dstMapName;
	if(ar.exists('bound'))boundaryObject=ar.item('bound')||boundaryObject;
	if(srcMapName && dstMapName){
		echo('Use config:\n');
		echo('bound='+boundaryObject);
		echo('src='+srcMapName);
		echo('dst='+dstMapName);
		return true;
	}
	help();
	return false;
};

function main(){
	if(!checkArgs())return false;
	var dst=h.mapHelper();
	dst.open(dstMapName,true);
	var src=h.mapHelper();
	src.open(srcMapName);
	src.exec('PRAGMA locking_mode=NORMAL');
	var bpoly=false;
	if(boundaryObject){
		echot('Resolving boundary');
		var mpr=h.getMultiPoly(boundaryObject.split(','),src.map);
		if(!mpr.poly){
			echot('	fail');
			return false;
		}else{
			echot(' done');
		};
		var bpoly=mpr.bpoly;
	};
	echot('Export started');
	var stg=src.map.storage;
	var exportWays=stg.createIdList(),exportNodes=stg.createIdList();
	var qAllWays=src.exec('\
	SELECT hways.wayid,nodeid FROM\
		(SELECT objid>>2 AS wayid FROM objtags WHERE tagid IN (SELECT id FROM tags WHERE tagname IN(\'highway\',\'place\')) AND objid&3=1) AS hways,waynodes as wn\
	WHERE hways.wayid=wn.wayid AND nodeidx=0\
	UNION ALL\
	SELECT bways.wayid, nodeid FROM\
		(SELECT memberid AS wayid FROM\
			relationmembers\
		WHERE relationid IN \
			(SELECT objid>>2 FROM objtags\
				WHERE objid IN (SELECT objid FROM objtags WHERE tagid IN (SELECT id FROM tags WHERE tagname=\'place\') AND objid&3=2)\
					AND tagid IN (SELECT id FROM tags WHERE tagname=\'type\' AND tagvalue IN (\'boundary\',\'multipolygon\')))\
			AND memberidxtype&3=1) AS bways,waynodes AS wn\
	WHERE bways.wayid=wn.wayid AND wn.nodeidx=0');
	var qGetNodeLL=stg.sqlPrepare('SELECT minlat*'+intToDeg+',minlon*'+intToDeg+',minlat,minlon FROM nodes_latlon WHERE id=:id');
	var dstg=dst.map.storage, qPutn=dstg.sqlPrepare('INSERT OR IGNORE INTO nodes_latlon(id,minlat,maxlat,minlon,maxlon)VALUES (:id,:lat,:lat,:lon,:lon)');
	var testNode={lat:0,lon:0},totcnt=0,incnt=0;
	while(!qAllWays.eos){
		var aAllWays=qAllWays.read(1000).toArray();
		for(var i=0;i<aAllWays.length;i+=2){
			totcnt++;
			if(bpoly){
				var nId=aAllWays[i+1];
				var ll=stg.sqlExec(qGetNodeLL,':id',nId).read(1).toArray();
				if(!ll.length)continue;
				testNode.lat=ll[0]; testNode.lon=ll[1];
				if(!bpoly.isIn(testNode))continue;
				exportNodes.add(nId);
				dstg.sqlExec(qPutn,[':id',':lat',':lon'],[nId,ll[2],ll[3]]);
			}
			exportWays.add(aAllWays[i]);
			incnt++;
		};
		echo('Added '+incnt+' of '+totcnt,true);
	};
	echo('');
	qAllWays=0;
	echot('Complete highways...');
	src.exec('INSERT OR IGNORE INTO '+exportWays.tableName+'(id) SELECT wayid FROM waynodes WHERE nodeid IN (SELECT id FROM '+exportNodes.tableName+') AND wayid IN (SELECT objid>>2 FROM objtags WHERE tagid IN (SELECT id FROM tags WHERE tagname IN(\'highway\',\'place\')) AND objid=waynodes.wayid*4+1)');
	echot(' Build node list');
	qGetNodeLL=src.exec('SELECT id,minlat*'+intToDeg+',minlon*'+intToDeg+',minlat,minlon FROM nodes_latlon WHERE id IN(SELECT nodeid FROM waynodes WHERE wayid IN (SELECT id FROM '+exportWays.tableName+'))');
	incnt=0; totcnt=0;
	while(!qGetNodeLL.eos){
		var aNodes=qGetNodeLL.read(1000).toArray();
		for(var i=0;i<aNodes.length;i+=5){
			totcnt++;
			var nId=aNodes[i];
			if(bpoly){
				testNode.lat=aNodes[i+1]; testNode.lon=aNodes[i+2];
				if(!bpoly.isIn(testNode))continue;
			};
			exportNodes.add(nId);
			dstg.sqlExec(qPutn,[':id',':lat',':lon'],[nId,aNodes[i+3],aNodes[i+4]]);
			incnt++;
		};
		echo('Added '+incnt+' of '+totcnt,true);
	};
	echo('');
	qPutn=0;
	dstg=0;
	dst.close();
	dst=0;
	echot('	Attach to small db');
	src.exec('COMMIT');
	src.exec('ATTACH "'+dstMapName+'" AS smalldb');
	src.exec('PRAGMA smalldb.journal_mode=off');
	src.exec('BEGIN');
	echot('	Build relation list');
	var exportRelations=stg.createIdList();
	src.exec('INSERT OR IGNORE INTO '+exportRelations.tableName+'(id) SELECT relationid FROM relationmembers WHERE (memberid IN (SELECT id FROM '+exportNodes.tableName+') AND memberidxtype&3=0) OR (memberid IN (SELECT id FROM '+exportWays.tableName+') AND memberidxtype&3=1 )');
	src.exec('INSERT OR IGNORE INTO '+exportRelations.tableName+'(id) SELECT relationid FROM relationmembers WHERE (memberid IN (SELECT id FROM '+exportNodes.tableName+') AND memberidxtype&3=0) OR (memberid IN (SELECT id FROM '+exportWays.tableName+') AND memberidxtype&3=1 )');
	echot('	completing relation list');
	var objCnt,qobj,addList=stg.createIdList();
	do{
		src.exec('INSERT OR IGNORE INTO ' + addList.tableName + '(id) SELECT relationid FROM relationmembers WHERE memberid IN (SELECT id FROM ' + exportRelations.tableName + ') AND (memberidxtype & 3)=2');
		src.exec('DELETE FROM ' + addList.tableName + ' WHERE id IN (SELECT id FROM ' + exportRelations.tableName + ')');
		src.exec('INSERT INTO '+exportRelations.tableName+'(id) SELECT id FROM '+addList.tableName);
		qobj=src.exec('SELECT count(1) FROM '+addList.tableName);
		objCnt=qobj.read(1).toArray()[0];
		echot('	added '+objCnt+' relations');
	}while(objCnt>0);
	src.exec('DELETE FROM ' + addList.tableName);
	echot('	exporting nodes attrs...');
	src.exec('INSERT INTO smalldb.nodes_attr (id,version,timestamp,userId,changeset) SELECT id,version,timestamp,userId,changeset FROM nodes_attr WHERE id IN (SELECT id FROM '+exportNodes.tableName+')');
	echot('	exporting ways...');
	src.exec('INSERT INTO smalldb.ways (id,version,timestamp,userId,changeset) SELECT id,version,timestamp,userId,changeset FROM ways WHERE id IN (SELECT id FROM '+exportWays.tableName+')');
	echot('	exporting way nodes');
	src.exec('INSERT INTO smalldb.waynodes (wayid,nodeidx,nodeid) SELECT wayid,nodeidx,nodeid FROM waynodes WHERE wayid IN (SELECT id FROM '+exportWays.tableName+')');
	echot('	exporting relations...');
	src.exec('INSERT INTO smalldb.relations (id,version,timestamp,userId,changeset) SELECT id,version,timestamp,userId,changeset FROM relations WHERE id IN (SELECT id FROM '+exportRelations.tableName+')');
	echot('	exporting relation members...');
	src.exec('INSERT INTO smalldb.relationmembers (relationid,memberidxtype,memberid,memberrole) SELECT relationid,memberidxtype,memberid,memberrole FROM relationmembers WHERE relationid IN (SELECT id FROM '+exportRelations.tableName+')');
	echot('	exporting node tags...');
	src.exec('INSERT INTO smalldb.objtags (objid,tagid) SELECT objid,tagid FROM objtags WHERE objid IN(SELECT id*4 FROM '+exportNodes.tableName+')');
	echot('	exporting way tags...');
	src.exec('INSERT INTO smalldb.objtags (objid,tagid) SELECT objid,tagid FROM objtags WHERE objid IN(SELECT id*4+1 FROM '+exportWays.tableName+')');
	echot('	exporting relation tags...');
	src.exec('INSERT INTO smalldb.objtags (objid,tagid) SELECT objid,tagid FROM objtags WHERE objid IN(SELECT id*4+2 FROM '+exportRelations.tableName+')');
	echot('	exporting tag values...');
	src.exec('INSERT INTO smalldb.tags (id,tagname,tagvalue) SELECT id,tagname,tagvalue FROM tags WHERE id IN (SELECT tagid FROM smalldb.objtags)');
	echot('	exporting users...');
	src.exec('INSERT OR IGNORE INTO '+addList.tableName+' (id) SELECT userId FROM smalldb.relations');
	src.exec('INSERT OR IGNORE INTO '+addList.tableName+' (id) SELECT userId FROM smalldb.ways');
	src.exec('INSERT OR IGNORE INTO '+addList.tableName+' (id) SELECT userId FROM smalldb.nodes_attr');
	src.exec('INSERT INTO smalldb.users (id,name) SELECT id,name FROM users WHERE id IN (SELECT id FROM '+addList.tableName+')');
	echot('	marking external nodes...');
	src.exec("INSERT OR IGNORE INTO smalldb.tags (tagname,tagvalue) VALUES ('garmin:extnode','yes')");
	src.exec("UPDATE smalldb.objtags SET tagid=(SELECT id FROM smalldb.tags WHERE tagname='garmin:extnode' AND tagvalue='yes') WHERE tagid IN (SELECT id FROM smalldb.tags WHERE tagname='osman:note' AND tagvalue='boundary')");
	src.exec('COMMIT');
	src.exec('DETACH smalldb');
	src.exec('BEGIN');
	src.close();
	src=0;
	echot('all done.');
	return true;
};

try{
main();
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
