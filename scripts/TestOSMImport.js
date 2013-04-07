//settings
var srcOSMName='f:\\db\\osm\\sql\\debug_o.osm';
var destDBName='f:\\db\\osm\\sql\\debug_o.db3';
//settings end
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

function echo(s){
	WScript.Echo(s);
};

var man=WScript.createObject('OSMan.Application');
var fso=WScript.createObject('Scripting.FileSystemObject');

var dummymap={
	createNode:function(){return this.node},
	createRelation:function(){return this.relation},
	createWay:function(){return this.way},
	putNode:function(node){},
	putRelation:function(relation){},
	putWay:function(way){},
	putObject:function(obj){}
};

function importFile(fileName,destMap){
	WScript.Echo(''+(new Date())+' importing '+fileName);
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
	dummymap.node=destMap.createNode();
	dummymap.way=destMap.createWay();
	dummymap.relation=destMap.createRelation();
	osmr.setOutputMap(destMap);
	osmr.read(0);
	fs.open('');
	fs=ds=osmr=0;
	WScript.Echo(''+(new Date())+' import done');
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
	var q=stg.sqlPrepare('PRAGMA cache_size=300000');
	stg.sqlExec(q,0,0);
	return map;
};

//echo('hit enter');
//WScript.stdIn.read(1);
var map=openMap(destDBName);
importFile(srcOSMName,map);
