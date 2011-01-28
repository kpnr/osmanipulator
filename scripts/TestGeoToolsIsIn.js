//settings start
var testFileDir='F:\\db\\osm\\sql';
var testFileName='rf.db3';
//Relation[60189] - RF boundary
//Relation[140337] - Архангельская область
var testRelationId=60189;
//settings end
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

var man=0,fso=0;

function echo(s){
	WScript.Echo(s);
};

function testIsIn(map,stg,mpoly){
	var q=stg.sqlPrepare('select lat,lon from nodes limit 10000');
	var r=stg.sqlExec(q,'','');
	var inc=0,exc=0;
	var d=new Date();
	var nd=map.createNode();
	while(!r.eos){
		var ill=r.read(1000).toArray();
		WScript.stdOut.write('+'+inc+' -'+exc+'\r');
		for(var i=0;i<ill.length;i+=2){
			nd.lat=ill[i];
			nd.lon=ill[i+1];
			mpoly.isIn(nd)?(inc++):(exc++);
		};
	};
	d=(new Date())-d;
	echo('included:'+inc+'	excluded:'+exc+'	total:'+(inc+exc)+'	time(ms):'+d);
}

function testGeoTools(){
	var d=new Date();
	var map=man.createObject('Map');
	echo('Map='+map.toString());
	var stg=man.createObject('Storage');
	echo('Storage='+stg.toString());
	stg.dbName=fso.buildPath(testFileDir,testFileName);
	map.storage=stg;
	var gtls=man.createObject('GeoTools');
	echo('GeoTools='+gtls.toString());
	var rel=map.getRelation(testRelationId);
	if(rel){
		echo('Relation='+rel.toString());
		var mpoly=gtls.createPoly();
		echo('Multipolygon='+mpoly.toString());
		mpoly.addObject(rel);
		if(mpoly.resolve(map)){
			echo('All refs are resolved, all polygons are closed');
			testIsIn(map,stg,mpoly);
		}else{
			echo('Not resolved refs:');
			var url=mpoly.getNotResolved().getAll().toArray();
			for(var i=0;i<url.length;i+=3){
				echo('	'+url[i]+'	'+url[i+1]+'	'+url[i+2]);
			}
			echo('Not closed nodes:');
			var url=mpoly.getNotClosed().getAll().toArray();
			for(var i=0;i<url.length;i+=3){
				echo('	'+url[i]+'	'+url[i+1]+'	'+url[i+2]);
			}
		}
		mpoly=0;
	};
	rel=0;
	gtls=0;
	map.storage=0;
	stg.dbName='';
	d=(new Date())-d;
	echo('Test time: '+d+'ms');
}

//---===   main   ===---//

fso=WScript.CreateObject('Scripting.FileSystemObject');
try{
	man=WScript.CreateObject("OSMan.Application");
	echo("App="+man.toString());
	man.logger=
		{
			log:function(msg){
				WScript.Echo(msg);
			}
		};
	testGeoTools();echo('');
	}catch(e){
	echo('Unexpected exception '+e.description+' '+e.number);
}

echo('\r\npress `Enter`');
WScript.StdIn.ReadLine();