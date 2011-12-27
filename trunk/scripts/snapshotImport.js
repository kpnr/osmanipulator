//settings begin
var scriptIniFile='F:\\db\\osm\\snapdl.ini';
var scriptCfgFile='F:\\db\\osm\\snapdl.cfg';
var cDegToInt=10000000;
var cIntToDeg=1/cDegToInt;
//settings end

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new (include('helpers.js'))();
var echo=h.echo;
var Ini=include('inifile.js');

function curTime(){
	return (new Date()).toLocaleString();
};

function openMap(storageName,cacheSize){
	var map=h.mapHelper();
	map.open(storageName);
	cacheSize=(cacheSize)?(parseInt(cacheSize)):(false);
	cacheSize=(isNaN(cacheSize))?(false):cacheSize;
	if(cacheSize){
		map.exec('PRAGMA cache_size='+cacheSize);
	};
	return map;
};

function clipMap(cfg){
	echo(curTime()+' Clipping map...');
	var startTime=new Date();
	var chunkSize=1000,netChunkSize=100;
	var clipPoly=h.gt.createPoly();
	var srcMapFileName=cfg.data['destDBName'];
	var src=openMap(srcMapFileName);
	try{
		var clipStr=cfg.data['mapClipPoly'].split(':');
		switch(clipStr[0]){
			case 'relation':
				clipObj=src.map.getRelation(clipStr[1]);
				break;
			case 'way':
				clipObj=src.map.getWay(clipStr[1]);
				break;
			default:
				return false;
		};
		if(!clipObj)return false;
		clipPoly.addObject(clipObj);
		echo(curTime()+' resolving boundary...');
		if(!clipPoly.resolve(src.map)){
			echo('	...failed');
			return false;
		};
		echo('	...done');
	}finally{
		src.close();
	};
	echo('	copy old map...');
	h.fso.copyFile(srcMapFileName,cfg.data['mapClipTempFile'],true);
	h.fso.deleteFile(srcMapFileName);
	echo('	done');
	var dst=openMap(srcMapFileName,50000);
	src=openMap(cfg.data['mapClipTempFile'],200000);
	var netMap=h.man.createObject('NetMap');
	netMap.storage=h.man.createObject('HTTPStorage');
	var nodeList=src.map.storage.createIdList();
	var wayList=src.map.storage.createIdList();
	var relList=src.map.storage.createIdList();
	var addList=src.map.storage.createIdList();
	var bbox=clipPoly.getBBox().toArray();
	var qobj=src.exec('SELECT id, minlat as lat ,minlon as lon FROM nodes_latlon WHERE '+cfg.data['mapClipFilter']+' AND ((lat BETWEEN '+(bbox[2]*cDegToInt)+' AND '+(bbox[0]*cDegToInt)+') AND (lon BETWEEN '+(bbox[3]*cDegToInt)+' AND '+(bbox[1]*cDegToInt)+'))');
	var objCnt=0,qryCnt=0;
	var testNode=src.map.createNode();
	echo(curTime()+' building node list');
	while(!qobj.eos){
		var nodes=qobj.read(chunkSize).toArray();
		for(var i=0;i<nodes.length;i+=3){
			testNode.lat=nodes[i+1]*cIntToDeg;
			testNode.lon=nodes[i+2]*cIntToDeg;
			if(clipPoly.isIn(testNode)){
				nodeList.add(nodes[i]);
				objCnt++;
			}
			qryCnt++;
		}
		echo(curTime()+' '+objCnt+' of '+qryCnt+' nodes added.',true);
	}
	echo('');
	echo(curTime()+' building way list');
	src.exec('INSERT OR IGNORE INTO '+wayList.tableName+'(id) SELECT wayid FROM waynodes WHERE nodeid IN (SELECT id FROM '+nodeList.tableName+')');
	echo(curTime()+' building relation list');
	src.exec('INSERT OR IGNORE INTO '+relList.tableName+'(id) SELECT relationid FROM relationmembers WHERE (memberid IN (SELECT id FROM '+nodeList.tableName+') AND memberidxtype&3=0) OR (memberid IN (SELECT id FROM '+wayList.tableName+') AND memberidxtype&3=1 )');
	echo(curTime()+' completing relation list');
	do{
		src.exec('INSERT OR IGNORE INTO ' + addList.tableName + '(id) SELECT relationid FROM relationmembers WHERE memberid IN (SELECT id FROM ' + relList.tableName + ') AND (memberidxtype & 3)=2');
		src.exec('DELETE FROM ' + addList.tableName + ' WHERE id IN (SELECT id FROM ' + relList.tableName + ')');
		src.exec('INSERT INTO '+relList.tableName+'(id) SELECT id FROM '+addList.tableName);
		qobj=src.exec('SELECT count(1) FROM '+addList.tableName);
		objCnt=qobj.read(1).toArray()[0];
		echo(curTime()+' added '+objCnt+' relations');
	}while(objCnt>0);
	echo(curTime()+' completing way list');
	src.exec('INSERT OR IGNORE INTO '+wayList.tableName+'(id) SELECT memberid FROM relationmembers WHERE (relationid IN (SELECT id FROM '+relList.tableName+')) AND memberidxtype&3=1');
	echo(curTime()+' completing node list (relations)');
	src.exec('INSERT OR IGNORE INTO '+nodeList.tableName+'(id) SELECT memberid FROM relationmembers WHERE (relationid IN (SELECT id FROM '+relList.tableName+')) AND memberidxtype&3=0');
	echo(curTime()+' completing node list (ways)');
	src.exec('INSERT OR IGNORE INTO '+nodeList.tableName+'(id) SELECT nodeid FROM waynodes WHERE (wayid IN (SELECT id FROM '+wayList.tableName+'))');
	echo(curTime()+' Exporting objects...');
	
	echo(curTime()+'  Exporting nodes...');
	qobj=src.exec('SELECT id FROM '+nodeList.tableName);
	objCnt=0;qryCnt=0;
	var notFoundObj=[];
	while(!qobj.eos){
		var objs=qobj.read(chunkSize).toArray();
		for(var i=0;i<objs.length;i++){
			var obj=src.map.getNode(objs[i]);
			if(obj){
				dst.map.putObject(obj);
				objCnt++;
			}else{
				notFoundObj.push(objs[i]);
			};
			qryCnt++;
		};
		echo(curTime()+' '+objCnt+' of '+qryCnt+' nodes exported',true);
	};
	echo('');
	
	echo(curTime()+'  Getting nodes from net...');
	objCnt=0;qryCnt=0;
	try{
		while(notFoundObj.length>0){
			objs=netMap.getNodes(notFoundObj.splice(0,netChunkSize)).toArray();
			for(var i=0;i<objs.length;i++){
				dst.map.putObject(objs[i]);
				objCnt++;
			}
			qryCnt+=netChunkSize;
			echo(curTime()+' '+objCnt+' of '+qryCnt+' nodes exported',true);
		};
	}catch(e){
		echo(curTime()+' Exception'+e.message);
	};
	echo('');
	
	echo(curTime()+'  Exporting ways...');
	qobj=src.exec('SELECT id FROM '+wayList.tableName);
	objCnt=0;qryCnt=0;notFoundObj=[];
	while(!qobj.eos){
		var objs=qobj.read(chunkSize).toArray();
		for(var i=0;i<objs.length;i++){
			var obj=src.map.getWay(objs[i]);
			if(obj){
				dst.map.putObject(obj);
				objCnt++;
			}else{
				notFoundObj.push(objs[i]);
			}
			qryCnt++;
		};
		echo(curTime()+' '+objCnt+' of '+qryCnt+' ways exported',true);
	};
	echo('');

	echo(curTime()+'  Getting ways from net...');
	objCnt=0;qryCnt=0;
	try{
		while(notFoundObj.length>0){
			objs=netMap.getWays(notFoundObj.splice(0,netChunkSize)).toArray();
			for(var i=0;i<objs.length;i++){
				dst.map.putObject(objs[i]);
				objCnt++;
			}
			qryCnt+=netChunkSize;
			echo(curTime()+' '+objCnt+' of '+qryCnt+' ways exported',true);
		};
	}catch(e){
		echo(curTime()+' Exception'+e.message);
	};
	echo('');

	qobj=src.exec('SELECT id FROM '+relList.tableName);
	objCnt=0;qryCnt=0;notFoundObj=[];
	while(!qobj.eos){
		var objs=qobj.read(chunkSize).toArray();
		for(var i=0;i<objs.length;i++){
			var obj=src.map.getRelation(objs[i]);
			if(obj){
				dst.map.putObject(obj);
				objCnt++;
			}else{
				notFoundObj.push(objs[i]);
			}
			qryCnt++;
		};
		echo(curTime()+' '+objCnt+' of '+qryCnt+' relations exported',true);
	};
	echo('');

	echo(curTime()+'  Getting relations from net...');
	objCnt=0;qryCnt=0;
	try{
		while(notFoundObj.length>0){
			objs=netMap.getRelations(notFoundObj.splice(0,netChunkSize)).toArray();
			for(var i=0;i<objs.length;i++){
				dst.map.putObject(objs[i]);
				objCnt++;
			}
			qryCnt+=netChunkSize;
			echo(curTime()+' '+objCnt+' of '+qryCnt+' relations exported',true);
		};
	}catch(e){
		echo(curTime()+' Exception'+e.message);
	};
	echo('');

	//cleanup db objects
	qobj='';
	src.close();
	dst.close();
	echo(curTime()+'... clipping finished');
	return true;
};

function main(){
	var ini=new Ini();
	ini.read(scriptIniFile);
	var cfg=new Ini();
	cfg.read(scriptCfgFile);
	var nextImportNumber=parseInt(ini.data['nextImportNumber']);
	if(isNaN(nextImportNumber)){
		echo('Can`t read next import number. Exiting...');
		return;
	};
	var mapsz=h.fso.getFile(cfg.data['destDBName']).size;
	var needMapClip=mapsz>parseFloat(cfg.data['destDBClipSz']);
	var map=false;
	do{
		if(!map)map=openMap(cfg.data['destDBName'],200000);
		var srcOSMName=''+nextImportNumber;
		while(srcOSMName.length<9)srcOSMName='0'+srcOSMName;
		srcOSMName=cfg.data['snapshotDir']+srcOSMName+'.osc.gz';
		if(!h.fso.fileExists(srcOSMName)){
			echo('File '+srcOSMName+' not found');
			break;
		};
		echo((new Date()).toLocaleString()+' Importing '+srcOSMName);
		map.importXML(srcOSMName);
		nextImportNumber++;
		ini.read();
		ini.data['nextImportNumber']=nextImportNumber;
		ini.write();
		if(needMapClip){
			map.close();
			map=false;
			needMapClip=!clipMap(cfg);
		};
	}while(true);
	if(map)map.close();
	echo((new Date()).toLocaleString()+' Import done.');
};

main();