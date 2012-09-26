//settings
var regionListFileName='regionlist.cfg';
var srcMapName='F:\\db\\osm\\sql\\route.db3';
var dstDir='F:\\db\\osm\\rf_regions\\route';
var boundBackupDir='';
var cDegToInt=1e7;
//end settings

var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}};

var h=new (include('helpers.js'))();
var echo=h.echo;
function echot(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
}

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
		r.hMap.close();
		echot('	Attach to small db');
		hMap.exec('COMMIT');
		hMap.exec('ATTACH "'+h.fso.buildPath(dstDir, r.name+'.db3')+'" AS smalldb');
		hMap.exec('PRAGMA smalldb.journal_mode=off');
		hMap.exec('BEGIN');
		echot('	Build way list');
		hMap.exec('INSERT OR IGNORE INTO '+r.silWays.tableName+' (id) SELECT wayid FROM waynodes WHERE nodeid IN (SELECT id FROM '+r.silNodes.tableName+')');
		echot('	Build relation list');
		hMap.exec('INSERT OR IGNORE INTO '+r.silRelations.tableName+'(id) SELECT relationid FROM relationmembers WHERE (memberid IN (SELECT id FROM '+r.silNodes.tableName+') AND memberidxtype&3=0) OR (memberid IN (SELECT id FROM '+r.silWays.tableName+') AND memberidxtype&3=1 )');
		echot('	completing relation list');
		var objCnt,qobj,addList=hMap.map.storage.createIdList();
		do{
			hMap.exec('INSERT OR IGNORE INTO ' + addList.tableName + '(id) SELECT relationid FROM relationmembers WHERE memberid IN (SELECT id FROM ' + r.silRelations.tableName + ') AND (memberidxtype & 3)=2');
			hMap.exec('DELETE FROM ' + addList.tableName + ' WHERE id IN (SELECT id FROM ' + r.silRelations.tableName + ')');
			hMap.exec('INSERT INTO '+r.silRelations.tableName+'(id) SELECT id FROM '+addList.tableName);
			qobj=hMap.exec('SELECT count(1) FROM '+addList.tableName);
			objCnt=qobj.read(1).toArray()[0];
			echot('	added '+objCnt+' relations');
		}while(objCnt>0);
		hMap.exec('DELETE FROM ' + addList.tableName);
		echot('	exporting nodes attrs...');
		hMap.exec('INSERT INTO smalldb.nodes_attr (id,version,timestamp,userId,changeset) SELECT id,version,timestamp,userId,changeset FROM nodes_attr WHERE id IN (SELECT id FROM '+r.silNodes.tableName+')');
		echot('	exporting ways...');
		hMap.exec('INSERT INTO smalldb.ways (id,version,timestamp,userId,changeset) SELECT id,version,timestamp,userId,changeset FROM ways WHERE id IN (SELECT id FROM '+r.silWays.tableName+')');
		echot('	exporting way nodes');
		hMap.exec('INSERT INTO smalldb.waynodes (wayid,nodeidx,nodeid) SELECT wayid,nodeidx,nodeid FROM waynodes WHERE wayid IN (SELECT id FROM '+r.silWays.tableName+')');
		echot('	exporting relations...');
		hMap.exec('INSERT INTO smalldb.relations (id,version,timestamp,userId,changeset) SELECT id,version,timestamp,userId,changeset FROM relations WHERE id IN (SELECT id FROM '+r.silRelations.tableName+')');
		echot('	exporting relation members...');
		hMap.exec('INSERT INTO smalldb.relationmembers (relationid,memberidxtype,memberid,memberrole) SELECT relationid,memberidxtype,memberid,memberrole FROM relationmembers WHERE relationid IN (SELECT id FROM '+r.silRelations.tableName+')');
		echot('	exporting node tags...');
		hMap.exec('INSERT INTO smalldb.objtags (objid,tagid) SELECT objid,tagid FROM objtags WHERE objid IN(SELECT id*4 FROM '+r.silNodes.tableName+')');
		echot('	exporting way tags...');
		hMap.exec('INSERT INTO smalldb.objtags (objid,tagid) SELECT objid,tagid FROM objtags WHERE objid IN(SELECT id*4+1 FROM '+r.silWays.tableName+')');
		echot('	exporting relation tags...');
		hMap.exec('INSERT INTO smalldb.objtags (objid,tagid) SELECT objid,tagid FROM objtags WHERE objid IN(SELECT id*4+2 FROM '+r.silRelations.tableName+')');
		echot('	exporting tag values...');
		hMap.exec('INSERT INTO smalldb.tags (id,tagname,tagvalue) SELECT id,tagname,tagvalue FROM tags WHERE id IN (SELECT tagid FROM smalldb.objtags)');
		echot('	exporting users...');
		hMap.exec('INSERT OR IGNORE INTO '+addList.tableName+' (id) SELECT userId FROM smalldb.relations');
		hMap.exec('INSERT OR IGNORE INTO '+addList.tableName+' (id) SELECT userId FROM smalldb.ways');
		hMap.exec('INSERT OR IGNORE INTO '+addList.tableName+' (id) SELECT userId FROM smalldb.nodes_attr');
		hMap.exec('INSERT INTO smalldb.users (id,name) SELECT id,name FROM users WHERE id IN (SELECT id FROM '+addList.tableName+')');
		hMap.exec('COMMIT');
		hMap.exec('DETACH smalldb');
		hMap.exec('BEGIN');
		echot('	exporting boundary...');
		r.hMap.open(h.fso.buildPath(dstDir, r.name+'.db3'));
		if(boundBackupDir){
			var bbhm=h.mapHelper();
			bbhm.open(h.fso.buildPath(boundBackupDir,r.name+'.db3'),false,true);
			bbhm.exportMultiPoly(r.hMap.map,r.ref);
			bbhm.close();
		};
		hMap.exportMultiPoly(r.hMap.map,r.ref);
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
			b.silNodes=hMap.map.storage.createIdList();
			b.silWays=hMap.map.storage.createIdList();
			b.silRelations=hMap.map.storage.createIdList();
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
		}else throw 'Invalid action '+a.act;
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
		echo('hit enter');
		WScript.stdIn.read(1);
		return;
	};
	echot('opening src map '+srcMapName);
	var srcMap=h.mapHelper();
	srcMap.open(srcMapName);
	srcMap.exec('PRAGMA locking_mode=NORMAL');
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
			if(typeof(bs.ref)=='string')bs.ref=bs.ref.split(',');
			var mpr=h.getMultiPoly(bs.ref,srcMap.map,(boundBackupDir)?(bbkMap.map):(false));
			if(boundBackupDir)bbkMap.close();
			if(!mpr.poly){
				echo('	'+bs.name+' boundary not resolved. Skipped.');
				continue;
			};
			echo('	'+bs.name+' boundary resolved from '+mpr.usedMap.storage.dbName);
			bs.bpoly=mpr.poly;
			bs.bbox=mpr.poly.getBBox().toArray();
			bounds.push(bs);
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
