//settings begin
var scriptIniFile='F:\\db\\osm\\snapdl.ini';
var scriptCfgFile='F:\\db\\osm\\snapdl.cfg';
//settings end

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new (include('helpers.js'))();
var echo=h.echo;
var Ini=include('inifile.js');

function completeFromNet(strObjType,objIds,dstMap){
	echo('Completing '+objIds.length+' '+strObjType+'s');
	var netmap=h.man.createObject('NetMap');
	netmap.storage=h.man.createObject('HTTPStorage');
	for(var i=0;i<objIds.length;){
		var obj=false;
		switch(strObjType){
			case 'node':
				obj=netmap.getNode(objIds[i]);
				break;
			case 'way':
				obj=netmap.getWay(objIds[i]);
				break;
			case 'relation':
				obj=netmap.getRelation(objIds[i]);
				break;
		};
		if(obj)dstMap.putObject(obj);
		i++;
		WScript.stdOut.write('	'+i+'/'+objIds.length+strObjType+'          \r');
	};
	echo('');
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
	echo((new Date()).toLocaleString()+' Clipping map...');
	var startTime=new Date();
	var clipPoly=h.gt.createPoly();
	var clipPoly=h.gt.createPoly();
	var srcMapFileName=cfg.data['destDBName'];
	var src=openMap(src.mapFileName);
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
		if(!clipPoly.resolve(src.map)){
			return false;
		};
	}finally{
		src.close();
	};
	h.fso.copyFile(srcMapFileName,cfg.data['mapClipTempFile'],true);
	h.fso.deleteFile(srcMapFileName);
	var dst=openMap(srcMapFileName,200000);
	src.map=openMap(cfg.data['mapClipTempFile'],50000);
	var mapClipFilter=cfg.data['mapClipFilter'].split(',').concat(':bpoly',clipPoly);
	var objCnt=0;
	var chunkSize=1000;
	var srcStream=src.map.getObjects(mapClipFilter);
	while(!srcStream.eos){
		var objs=srcStream.read(chunkSize).toArray();
		for(var i=0;i<objs.length;i++)dst.map.putObject(objs[i]);
		var dt=(new Date())-startTime;
		objCnt+=chunkSize;
		echo('	nObj='+objCnt+'	Speed='+Math.round(objCnt/dt*1000)+' obj/sec          \r',true);
	};
	echo('');
	var objids=dst.completeRelationNodes(src.map);
	if(objids.length){
		completeFromNet('node',objids,dst.map);
	};
	objids=dst.completeRelationWays(src.map);
	if(objids.length){
		completeFromNet('way',objids,dst.map);
	};
	objids=dst.completeWayNodes(src.map);
	if(objids.length){
		completeFromNet('node',objids,dst.map);
	};
	src.close();
	dst.close();
	echo((new Date()).toLocaleString()+' ...map clipped');
	return true;
};

function clipMapForce(){
	return false;
	var netMap=man.createObject('NetMap');
	netMap.storage=man.createObject('HTTPStorage');
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