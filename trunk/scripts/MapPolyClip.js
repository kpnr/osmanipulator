//settings
var boundaryRelationId=60189;
var nodeFilter=[':bbox',90,-165,55,-180,':bbox',90,180,40,15];
var srcMapName='S:\\db\\osm\\sql\\rf.db3';
var dstMapName='F:\\db\\osm\\sql\\rf.db3';
//end settings

//boundary Russia relation = 60189
//boundary Московская область relation =51490
//субъекты РФ relation=184217
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

var man=WScript.createObject('OSMan.Application');
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
		stg.initSchema();
	};
	var q=stg.sqlPrepare('PRAGMA cache_size=200000');
	stg.sqlExec(q,'',''); 
	return map;
};

function createPoly(boundObject,aMap){
	var gt=man.createObject('GeoTools');
	var mp=gt.createPoly();
	mp.addObject(boundObject);
	if(mp.resolve(aMap)){
		return mp;
	}else {
		echo('Not resolved refs:');
		var url=mp.getNotResolved().getAll().toArray();
		var netmap=man.createObject('NetMap');
		netmap.storage=man.createObject('HTTPStorage');
		for(var i=0;i<url.length;i+=3){
			if(url[i]=='node')aMap.putObject(netmap.getNode(url[i+1]));
			if(url[i]=='way')aMap.putObject(netmap.getWay(url[i+1]));
			if(url[i]=='relation')aMap.putObject(netmap.getRelation(url[i+1]));
			echo('	'+url[i]+'	'+url[i+1]+'	'+url[i+2]);
		};
		return false;
	}
}
//copy from snapshotExportDB.js begin
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
//copy from snapshotExportDB.js begin


if(fso.fileExists(dstMapName)){
	fso.deleteFile(dstMapName);
};
var srcMap=openMap(srcMapName);
var dstMap=openMap(dstMapName);
var bpoly=createPoly(srcMap.getRelation(boundaryRelationId),srcMap);
if(bpoly){
	echo('bpoly resolved');
	var dstStg=dstMap.storage;
	var srcStream=srcMap.getObjects(nodeFilter.concat(':bpoly',bpoly));
	echo('');
	var chunkSize=1000;
	var startTime=new Date();
	var objCnt=0;
	while(!srcStream.eos){
		var objs=srcStream.read(chunkSize).toArray();
		for(var i=0;i<objs.length;i++)dstMap.putObject(objs[i]);
		var dt=(new Date())-startTime;
		objCnt+=chunkSize;
		WScript.stdOut.write('nObj='+objCnt+'	Speed='+Math.round(objCnt/dt*1000)+' obj/sec          \r');
	};
	echo('');
	completeRelationNodes(srcMap,dstMap);
	completeWayNodes(srcMap,dstMap);
	completeRelationWays(srcMap,dstMap);
}