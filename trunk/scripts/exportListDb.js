//settings
var regionListFileName='regionlist.cfg';
var srcMapName='F:\\db\\osm\\sql\\route.db3';
var dstDir='F:\\db\\osm\\rf_regions\\route';
var boundBackupDir='';
var cDegToInt=1e7;
//end settings

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}};

var h=new (include('helpers.js'))();
var echo=h.echo;
var echot=h.bindFunc(h,h.echot);

function checkArgs(){
	function help(){
	echo('Command line options:\n\
 /src:"source_file_name.db3"\n\
 /dst:"dest_directory"\n\
 /bbakdir:"boundary_backup_directory". This argument is optional.\n\
 /lst:"list_file_name.js" - should be in json format');
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
	if(ar.exists('src'))srcMapName=ar.item('src')||'';
	if(ar.exists('dst'))dstDir=ar.item('dst')||'';
	if(ar.exists('lst'))regionListFileName=ar.item('lst')||'';
	if(ar.exists('bbakdir'))boundBackupDir=ar.item('bbakdir')||'';
	echo('Use config:\nsrc='+srcMapName+'\ndst='+dstDir+'\nlst='+regionListFileName+'\nbbakdir='+boundBackupDir);
	if(!(srcMapName && dstDir && regionListFileName)){
		help();
		echo('\nInvalid arguments. Exiting');
		return false;
	};
	return true;
};

function exportMaps(hMap,bounds){
	function deactivateRegion(r){
		delete r.qPutn;
		echot('	Attach small & big db');
		r.hMap.exec('COMMIT');
		r.hMap.exec('ATTACH "'+hMap.map.storage.dbName+'" AS bigdb');
		r.hMap.exec('PRAGMA bigdb.journal_mode=off');
		r.hMap.exec('BEGIN');
		echot('	Build way list');
		r.hMap.exec('INSERT OR IGNORE INTO '+r.silWays.tableName+' (id) SELECT wayid FROM bigdb.waynodes WHERE nodeid IN (SELECT id FROM '+r.silNodes.tableName+')');
		echot('	Build relation list');
		r.hMap.exec('INSERT OR IGNORE INTO '+r.silRelations.tableName+'(id) SELECT relationid FROM bigdb.relationmembers WHERE (memberid IN (SELECT id FROM '+r.silNodes.tableName+') AND memberidxtype&3=0) OR (memberid IN (SELECT id FROM '+r.silWays.tableName+') AND memberidxtype&3=1 )');
		echot('	completing relation list');
		var objCnt,qobj,addList=r.hMap.map.storage.createIdList();
		do{
			r.hMap.exec('INSERT OR IGNORE INTO ' + addList.tableName + '(id) SELECT relationid FROM bigdb.relationmembers WHERE memberid IN (SELECT id FROM ' + r.silRelations.tableName + ') AND (memberidxtype & 3)=2');
			r.hMap.exec('DELETE FROM ' + addList.tableName + ' WHERE id IN (SELECT id FROM ' + r.silRelations.tableName + ')');
			r.hMap.exec('INSERT INTO '+r.silRelations.tableName+'(id) SELECT id FROM '+addList.tableName);
			qobj=r.hMap.exec('SELECT count(1) FROM '+addList.tableName);
			objCnt=qobj.read(1).toArray()[0];
			echot('	added '+objCnt+' relations');
		}while(objCnt>0);
		r.hMap.exec('DELETE FROM ' + addList.tableName);
		echot('	exporting nodes attrs...');
		r.hMap.exec('INSERT INTO nodes_attr (id,version,timestamp,userId,changeset) SELECT id,version,timestamp,userId,changeset FROM bigdb.nodes_attr WHERE id IN (SELECT id FROM '+r.silNodes.tableName+')');
		echot('	exporting ways...');
		r.hMap.exec('INSERT INTO ways (id,version,timestamp,userId,changeset) SELECT id,version,timestamp,userId,changeset FROM bigdb.ways WHERE id IN (SELECT id FROM '+r.silWays.tableName+')');
		echot('	exporting way nodes');
		r.hMap.exec('INSERT INTO waynodes (wayid,nodeidx,nodeid) SELECT wayid,nodeidx,nodeid FROM bigdb.waynodes WHERE wayid IN (SELECT id FROM '+r.silWays.tableName+')');
		echot('	exporting relations...');
		r.hMap.exec('INSERT INTO relations (id,version,timestamp,userId,changeset) SELECT id,version,timestamp,userId,changeset FROM bigdb.relations WHERE id IN (SELECT id FROM '+r.silRelations.tableName+')');
		echot('	exporting relation members...');
		r.hMap.exec('INSERT INTO relationmembers (relationid,memberidxtype,memberid,memberrole) SELECT relationid,memberidxtype,memberid,memberrole FROM bigdb.relationmembers WHERE relationid IN (SELECT id FROM '+r.silRelations.tableName+')');
		echot('	exporting node tags...');
		r.hMap.exec('INSERT INTO objtags (objid,tagid) SELECT objid,tagid FROM bigdb.objtags WHERE objid IN(SELECT id*4 FROM '+r.silNodes.tableName+')');
		echot('	exporting way tags...');
		r.hMap.exec('INSERT INTO objtags (objid,tagid) SELECT objid,tagid FROM bigdb.objtags WHERE objid IN(SELECT id*4+1 FROM '+r.silWays.tableName+')');
		echot('	exporting relation tags...');
		r.hMap.exec('INSERT INTO objtags (objid,tagid) SELECT objid,tagid FROM bigdb.objtags WHERE objid IN(SELECT id*4+2 FROM '+r.silRelations.tableName+')');
		echot('	exporting tag values...');
		r.hMap.exec('INSERT INTO tags (id,tagname,tagvalue) SELECT id,tagname,tagvalue FROM bigdb.tags WHERE id IN (SELECT tagid FROM objtags)');
		echot('	exporting users...');
		r.hMap.exec('INSERT OR IGNORE INTO '+addList.tableName+' (id) SELECT userId FROM relations');
		r.hMap.exec('INSERT OR IGNORE INTO '+addList.tableName+' (id) SELECT userId FROM ways');
		r.hMap.exec('INSERT OR IGNORE INTO '+addList.tableName+' (id) SELECT userId FROM nodes_attr');
		r.hMap.exec('INSERT INTO users (id,name) SELECT id,name FROM bigdb.users WHERE id IN (SELECT id FROM '+addList.tableName+')');
		echot('	exporting boundary...');
		if(r.useBackup){
			echo('from backup');
			var bbhm=h.mapHelper();
			bbhm.open(h.fso.buildPath(boundBackupDir,r.name+'.db3'),false,true);
			bbhm.exportMultiPoly(r.hMap.map,r.bound);
			bbhm.close();
		}else{
			echo('from main');
			hMap.exportMultiPoly(r.hMap.map,r.bound);
		};
		echo('done');
		r.hMap.exec('COMMIT');
		r.hMap.exec('DETACH bigdb');
		delete r.silNodes;
		delete r.silWays;
		delete r.silRelations;
		r.hMap.close();
		delete r.hMap;
		echot('region deactivated');
	};
	echot('Sorting bounds');
	var actions=[],actRgn=[],latRange={min:90,max:-90};
	function execAction(a){
		echot('exec action '+a.act+bounds[a.idx].name);
		if(a.act=='+'){
			var b=bounds[a.idx];
			b.idx=a.idx;
			actRgn.push(b);
			if(b.bbox[0]>latRange.max)latRange.max=b.bbox[0];
			if(b.bbox[2]<latRange.min)latRange.min=b.bbox[2];
			b.hMap=h.mapHelper();
			b.hMap.open(h.fso.buildPath(dstDir, b.name+'.db3'),true);
			b.silNodes=b.hMap.map.storage.createIdList();
			b.silWays=b.hMap.map.storage.createIdList();
			b.silRelations=b.hMap.map.storage.createIdList();
			//ignore insertion in case of "shared in several bounds" node
			b.qPutn=b.hMap.map.storage.sqlPrepare('INSERT OR IGNORE INTO nodes_latlon(id,minlat,maxlat,minlon,maxlon)VALUES(:id,:lat,:lat,:lon,:lon)');
		}else if(a.act=='-'){
			for(var i=0;i<actRgn.length;i++){
				var r=actRgn[i];
				if(a.idx==r.idx){
					var b=bounds[a.idx];
					var tgtBase=h.fso.buildPath(dstDir, b.name);
					echot('Deactivating region '+r.name);
					deactivateRegion(r);
					actRgn.splice(i,1);
					break;
				};
			};
			latRange={min:90,max:-90};
			for(var i=0;i<actRgn.length;i++){
				var b=actRgn[i];
				if(b.bbox[0]>latRange.max)latRange.max=b.bbox[0];
				if(b.bbox[2]<latRange.min)latRange.min=b.bbox[2];
			};
		}else throw {name:'dev',description:'Invalid action '+a.act};
	};
	for(var i=0;i<bounds.length;i++){
		actions.push({act:'+',lon:bounds[i].bbox[3],idx:i});
		actions.push({act:'-',lon:bounds[i].bbox[1],idx:i});
	};
	actions.sort(function(a,b){return a.lon-b.lon;});
	var qGetNodes=hMap.map.storage.sqlPrepare('SELECT id, minlat*'+(1/cDegToInt)+',minlon*'+(1/cDegToInt)+',minlat,minlon FROM nodes_latlon WHERE minlon BETWEEN :minlon*'+cDegToInt+' AND :maxlon*'+cDegToInt+' AND minlat BETWEEN :minlat*'+cDegToInt+' AND :maxlat*'+cDegToInt);
	var ndcnt=0,bchkcnt=0;
	echot('Executing export actions');
	for(var i=0;i<actions.length-1;i++){
		var lonRange={min:actions[i].lon,max:actions[i+1].lon};
		execAction(actions[i]);
		if(!actRgn.length)continue;
		var sNids=hMap.map.storage.sqlExec(qGetNodes,[':minlon',':maxlon',':minlat',':maxlat'],[lonRange.min,lonRange.max,latRange.min,latRange.max]);
		var testNode=hMap.map.createNode();
		while(!sNids.eos){
			var nids=sNids.read(300).toArray();
			for(var j=0;j<nids.length;j+=5){
				testNode.lat=nids[j+1];
				testNode.lon=nids[j+2];
				//try{
				for(var k=0;k<actRgn.length;k++){
					var r=actRgn[k];
					if(k>0){
						actRgn[k]=actRgn[0];actRgn[0]=r;
					};
					bchkcnt++;
					if(r.bpoly.isIn(testNode)){
						r.silNodes.add(nids[j]);
						r.hMap.map.storage.sqlExec(r.qPutn,[':id',':lat',':lon'],[nids[j],nids[j+3],nids[j+4]]);
						ndcnt++;
						break;
					};
				};
				//}catch(e){
				//	echo ('exception region='+actRgn[0].name+' nodeid='+nids[j]+' msg='+e.description);
				//	throw e
				//}
			};
		};
		echo('n='+ndcnt+' c='+bchkcnt+' r='+(bchkcnt/ndcnt).toFixed(3));
	};
	execAction(actions.pop());
};

function main(){
	if(!checkArgs()){
		return;
	};
	echot('opening src map '+srcMapName);
	var srcMap=h.mapHelper();
	srcMap.open(srcMapName,false,true);
	srcMap.exec('COMMIT');
	srcMap.exec('PRAGMA locking_mode=NORMAL');
	srcMap.exec('BEGIN');
	try{
		echot('reading region list');
		var boundsCollection=include(regionListFileName);
		if(!boundsCollection){
			echot('boundary collection not found');
			return;
		};
		var bounds=[];
		for(var i=0;i<boundsCollection.length;i++){
			var bs=boundsCollection[i],bo=[];
			var bbkMap=h.mapHelper();
			if (boundBackupDir) bbkMap.open(h.fso.buildPath(boundBackupDir,bs.name+'.db3'));
			if(typeof(bs.bound)=='string')bs.bound=bs.bound.split(',');
			var mpr=h.getMultiPoly(bs.bound,srcMap.map,(boundBackupDir)?(bbkMap.map):(false));
			if(!mpr.poly){
				echo('	'+bs.name+' boundary not resolved. Skipped.');
			}else{
				echo('	'+bs.name+' boundary resolved from '+mpr.usedMap.storage.dbName);
				bs.bpoly=mpr.poly;
				bs.bbox=mpr.poly.getBBox().toArray();
				bs.useBackup=boundBackupDir && (mpr.usedMap.storage.dbName==bbkMap.map.storage.dbName);
				bounds.push(bs);
			};
			if(boundBackupDir)bbkMap.close();
		};
		exportMaps(srcMap,bounds);
	}finally{
		srcMap.close();
	}
};

try{
	main();
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
