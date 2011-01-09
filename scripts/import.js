//settings begin
var destDBName='F:\\db\\osm\\sql\\rf.db3';
var srcOSMName=[
'F:\\db\\osm\\100805rus.osm'
];
var bpolyRelationId=false;//60189;//set to false if no bpoly needed
//settings end

var man=WScript.createObject('OSMan.Application');
var fso=WScript.createObject('Scripting.FileSystemObject');

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
	osmr.setOutputMap(destMap);
	osmr.read(0);
	fs.open('');
	fs=ds=osmr=0;
	WScript.Echo(''+(new Date())+'import done');
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
	var q=stg.sqlPrepare('PRAGMA cache_size=90000');
	stg.sqlExec(q,'','');
	return map;
};

var map=openMap(destDBName);
if(bpolyRelationId){
	var rel=map.getRelation(bpolyRelationId);
	if(rel){
		var gt=man.createObject('GeoTools');
		var mpoly=gt.createPoly();
		mpoly.addObject(rel);
		if(mpoly.resolve(map)){
			WScript.Echo('bpoly resolved. Filtering enabled');
			map.onPutFilter={
				onPutNode:function(aNode){
					return mpoly.isIn(aNode);
				}
			};
		};
	};
};
if(srcOSMName.length){
	for(var i=0;i<srcOSMName.length;i++){
		importFile(srcOSMName[i],map)
	}
}else{
	importFile(srcOSMName,map);
}