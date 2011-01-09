//settings
var storageName='F:\\db\\osm\\testdata\\test.db3';
var boundaryFileName='F:\\db\\osm\\testdata\\20100608rf_boundary.osm.bz2';
var boundaryRelationId=60189;
var osmDataFileName='F:\\db\\osm\\testdata\\20100608-20100609.osc.gz';
//end settings
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
	echo(''+(new Date())+'import done');
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


var map=openMap(storageName);
importFile(boundaryFileName,map);
var inc=0,exc=0;
var gt=man.createObject('GeoTools');
echo('GeoTools='+gt.toString());
var mpoly=gt.createPoly();
echo('Multipolygon='+mpoly.toString());
var rel=map.getRelation(boundaryRelationId);
if(rel){
	mpoly.addObject(rel);
	if(mpoly.resolve(map)){
		echo('All refs are resolved');
		var inc=0,exc=0;
    var d=new Date();
		map.onPutFilter={
			onPutNode:function(aNode){
				var ii=mpoly.isIn(aNode);
				ii?(inc++):(exc++);
				return false;
			},
			onPutWay:function(aWay){
				return false;
			},
			onPutRelation:function(aRelation){
				return false;
			}
		};
		importFile(osmDataFileName,map);
		d=(new Date())-d;
		echo('included:'+inc+'	excluded:'+exc+'	total:'+(inc+exc)+'	time(ms):'+d);
		map.onPutFilter=0;
	}else{
		echo('Not resolved refs:');
		var url=mpoly.getNotResolved().getAll().toArray();
		for(var i=0;i<url.length;i+=3){
			echo('	'+url[i]+'	'+url[i+1]+'	'+url[i+2]);
		}
	}
};
rel=0;
mpoly=0;
map=0;
echo('\r\npress `Enter`');
WScript.StdIn.Read(1);