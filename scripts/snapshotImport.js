//settings begin
var scriptIniFile='F:\\db\\osm\\snapdl.ini';
var scriptCfgFile='F:\\db\\osm\\snapdl.cfg';
//settings end

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

function echo(s){
	WScript.Echo(''+s);
};

var man=WScript.createObject('OSMan.Application');
var fso=WScript.createObject('Scripting.FileSystemObject');
var gtls=man.createObject('GeoTools');
var Ini=include('inifile.js');

function importFile(fileName,destMap){
	echo(''+(new Date())+' importing '+fileName);
	var ext=fso.getExtensionName(fileName);
	var ds=0;
	switch(ext){
		case 'bz2':
			ds=man.createObject('UnBZ2');
			break;
		case 'gz':
			ds=man.createObject('UnGZ');
			break;
	};
	var fs=man.createObject('FileReader');
	fs.open(fileName);
	if (ds) {
		ds.setInputStream(fs);
	}else{
		ds=fs;
	};
	var osmr=man.createObject('OSMReader');
	osmr.setInputStream(ds);
	osmr.setOutputMap(destMap);
	osmr.read(0);
	fs.open('');
	fs=ds=osmr=0;
	echo(''+(new Date())+' import done');
};

//copy from snapshotExportDB.js begin
	function completeWayNodes(srcMap,dstMap){
		echo('Completing way nodes...		');
		var d=new Date();
		var rslt=[];
		//medium select distinct nodeid from waynodes where not exists( select id from nodes where waynodes.nodeid=nodes.id)
		// 800ms	15200ms
		//fast select distinct nodeid from waynodes where nodeid not in (select id from nodes)
		// 600ms	12900ms
		var nidl=dstMap.storage.sqlPrepare('select distinct nodeid from waynodes where nodeid not in (select id from nodes)');
		nidl=dstMap.storage.sqlExec(nidl,0,0);
		var tot=0,nf=0;
		while(!nidl.eos){
			var nid=nidl.read(1000).toArray();
			for(var i=0;i<nid.length;i++){
				var n=srcMap.getNode(nid[i]);
				tot++;
				if(!n){
					nf++;
					rslt.push(nid[i]);
				}else dstMap.putObject(n);
			};
			WScript.stdOut.write('	not_found/total='+nf+'/'+tot+'          \r');
		};
		d=(new Date())-d;
		echo('\r\n	done in '+d+'ms');
		return rslt;
	};

	function completeRelationNodes(srcMap,dstMap){
		echo('Completing relation nodes...		');
		var d=new Date();
		var rslt=[];
		var nidl=dstMap.storage.sqlPrepare("select distinct memberid from strrelationmembers where membertype='node'  and (memberid not in (select id from nodes))");
		nidl=dstMap.storage.sqlExec(nidl,0,0);
		var tot=0,nf=0;
		while(!nidl.eos){
			var nid=nidl.read(1000).toArray();
			for(var i=0;i<nid.length;i++){
				var n=srcMap.getNode(nid[i]);
				tot++;
				if(!n){
					nf++;
					rslt.push(nid[i]);
				}else dstMap.putObject(n);
			}
			WScript.stdOut.write('	not_found/total='+nf+'/'+tot+'          \r');
		};
		d=(new Date())-d;
		echo('\r\n	done in '+d+'ms');
		return rslt;
	};

	function completeRelationWays(srcMap,dstMap){
		echo('Completing relation ways...		');
		var d=new Date();
		var rslt=[];
		var nidl=dstMap.storage.sqlPrepare("select distinct memberid from strrelationmembers where membertype='way'  and (memberid not in (select id from ways))");
		nidl=dstMap.storage.sqlExec(nidl,0,0);
		var tot=0,nf=0;
		while(!nidl.eos){
			var nid=nidl.read(1000).toArray();
			for(var i=0;i<nid.length;i++){
				var n=srcMap.getWay(nid[i]);
				tot++;
				if(!n){
					nf++;
					rslt.push(nid[i]);
				}else dstMap.putObject(n);
			}
			WScript.stdOut.write('	not_found/total='+nf+'/'+tot+'          \r');
		};
		d=(new Date())-d;
		echo('\r\n	done in '+d+'ms');
		return rslt;
	};
//copy from snapshotExportDB.js end

function completeFromNet(strObjType,objIds,dstMap){
	echo('Completing '+objIds.length+' '+strObjType+'s');
	var netmap=man.createObject('NetMap');
	netmap.storage=man.createObject('HTTPStorage');
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
	var stg=man.createObject('Storage');
	var map=man.createObject('Map');
	var initStg=!fso.fileExists(storageName);
	stg.dbName=storageName;
	map.storage=stg;
	if (initStg){
		map.initStorage();
	};
	cacheSize=(cacheSize)?(parseInt(cacheSize)):(false);
	cacheSize=(isNaN(cacheSize))?(false):cacheSize;
	if(cacheSize){
		var q=stg.sqlPrepare('PRAGMA cache_size='+cacheSize);
		stg.sqlExec(q,'','');
		q=false;
	};
	return map;
};

function closeMap(map){
	var stg=map.storage;
	map.storage=false;
	stg.dbName='';
};

function clipMap(cfg){
	echo('Clipping map...');
	var startTime=new Date();
	var clipPoly=gtls.createPoly();
	var clipPoly=gtls.createPoly();
	var srcMapFileName=cfg.data['destDBName'];
	var srcMap=openMap(srcMapFileName);
	try{
		var clipStr=cfg.data['mapClipPoly'].split(':');
		switch(clipStr[0]){
			case 'relation':
				clipObj=srcMap.getRelation(clipStr[1]);
				break;
			case 'way':
				clipObj=srcMap.getWay(clipStr[1]);
				break;
			default:
				return false;
		};
		if(!clipObj)return false;
		clipPoly.addObject(clipObj);
		if(!clipPoly.resolve(srcMap)){
			return false;
		};
	}finally{
		closeMap(srcMap);
	};
	fso.copyFile(srcMapFileName,cfg.data['mapClipTempFile'],true);
	fso.deleteFile(srcMapFileName);
	var dstMap=openMap(srcMapFileName,200000);
	srcMap=openMap(cfg.data['mapClipTempFile'],50000);
	var mapClipFilter=cfg.data['mapClipFilter'].split(',').concat(':bpoly',clipPoly);
	var objCnt=0;
	var chunkSize=1000;
	var srcStream=srcMap.getObjects(mapClipFilter);
	while(!srcStream.eos){
		var objs=srcStream.read(chunkSize).toArray();
		for(var i=0;i<objs.length;i++)dstMap.putObject(objs[i]);
		var dt=(new Date())-startTime;
		objCnt+=chunkSize;
		WScript.stdOut.write('	nObj='+objCnt+'	Speed='+Math.round(objCnt/dt*1000)+' obj/sec          \r');
	};
	echo('');
	var objids=completeRelationNodes(srcMap,dstMap);
	if(objids.length){
		completeFromNet('node',objids,dstMap);
	};
	objids=completeRelationWays(srcMap,dstMap);
	if(objids.length){
		completeFromNet('way',objids,dstMap);
	};
	objids=completeWayNodes(srcMap,dstMap);
	if(objids.length){
		completeFromNet('node',objids,dstMap);
	};
	closeMap(srcMap);
	closeMap(dstMap);
	echo('Map clipped in '+((new Date())-startTime)+'ms');
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
	var mapsz=fso.getFile(cfg.data['destDBName']).size;
	var needMapClip=mapsz>parseFloat(cfg.data['destDBClipSz']);
	var needMapClipForce=mapsz>parseFloat(cfg.data['destDBForceClipSz']);
	var map=false;
	do{
		if(!map)map=openMap(cfg.data['destDBName'],200000);
		var srcOSMName=''+nextImportNumber;
		while(srcOSMName.length<9)srcOSMName='0'+srcOSMName;
		srcOSMName=cfg.data['snapshotDir']+srcOSMName+'.osc.gz';
		if(!fso.fileExists(srcOSMName)){
			echo('File '+srcOSMName+' not found');
			break;
		};
		importFile(srcOSMName,map);
		nextImportNumber++;
		ini.read();
		ini.data['nextImportNumber']=nextImportNumber;
		ini.write();
		if(needMapClip){
			closeMap(map);
			map=false;
			needMapClip=!clipMap(cfg);
			needMapClipForce=needMapClipForce && needMapClip;
		};
		if(needMapClipForce){
			closeMap(map);
			map=false;
			needMapClip=!clipMapForce();
			needMapClipForce=needMapClipForce && needMapClip;
		};
	}while(true);
	if(map)closeMap(map);
	echo('Import done.');
};

main();