//settings begin
var destDBName='f:\\db\\osm\\sql\\world.db3';
var srcOSMName=[
'f:\\db\\planet-120920.osm.bz2'
];
var bpolyRelationId=60189;//set to false if no bpoly needed
var bpolyDBName='f:\\db\\osm\\sql\\rfbound121002.db3';
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
	/*var c=0;var fw=man.createObject('FileWriter');
	fw.open(destDBName);
	while(!ds.eos){
		var q=ds.read(1024*1024);
		WScript.StdOut.write((c++)%9);
		fw.write(q);
	};
	fw.open('');*/
	var osmr=man.createObject('OSMReader');
	osmr.setInputStream(ds);
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
	var q=stg.sqlPrepare('PRAGMA cache_size=350000');
	stg.sqlExec(q,'','');
	return map;
};

var map=openMap(destDBName);
if(bpolyRelationId){
	var bm=openMap(bpolyDBName);
	var rel=bm.getRelation(bpolyRelationId);
	if(rel){
		var gt=man.createObject('GeoTools');
		var mpoly=gt.createPoly();
		mpoly.addObject(rel);
		if(mpoly.resolve(bm)){
			WScript.Echo('bpoly resolved. Filtering enabled');
			var qCanPutWay=false;
			var cnt={ni:0,no:0,wi:0,wo:0,ri:0,ro:0,t:0};
			function countIt(cName,condition){
				cnt[cName+((condition)?('i'):('o'))]++;
				cnt.t++;
				if(!(cnt.t & 0xFFF))WScript.stdOut.Write('\rn='+cnt.ni+'/'+(cnt.ni+cnt.no)+'	w='+cnt.wi+'/'+(cnt.wi+cnt.wo)+'	r='+cnt.ri+'/'+(cnt.ri+cnt.ro));
				return condition;
			};
			map.onPutFilter={
				onPutNode:function(aNode){
					return countIt('n',mpoly.isIn(aNode));
				},
				onPutWay:function(aWay){
					var nds=aWay.nodes.toArray();
					if(nds.length<1)return countIt('w',false);
					if(!qCanPutWay)qCanPutWay=map.storage.sqlPrepare('select exists(select id from nodes_attr where id in (:node1,:node2))');
					var f=map.storage.sqlExec(qCanPutWay,[':node1',':node2'],[nds[0],nds[nds.length-1]]);
					return countIt('w',(f.read(1).toArray()[0]==1));
				},
				onPutRelation:function(aRelation){
					return countIt('r',true);
				}
			};
		};
	};
	bm.storage.dbName='';
	bm.storage=0;
	bm=0;
};

if(srcOSMName.length){
	for(var i=0;i<srcOSMName.length;i++){
		importFile(srcOSMName[i],map)
	}
}else{
	importFile(srcOSMName,map);
}