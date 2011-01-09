//settings
var boundaryRelationId=60189;
var nodeFilter=[':bbox',75,-168,58,-180,':bbox',86,180,40,17];
var srcMapName='F:\\db\\osm\\testdata\\rf.db3';
var dstMapName='F:\\db\\osm\\rf_clipped.db3';
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
		map.initStorage();
	};
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
		for(var i=0;i<url.length;i+=3){
			echo('	'+url[i]+'	'+url[i+1]+'	'+url[i+2]);
		};
		return false;
	}
}

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
	var chunkSize=10000;
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
}