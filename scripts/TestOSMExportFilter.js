//settings
var testOSMOutFile='e:\\db\\osm\\sql\\debug.osm';
var testMapFile='e:\\db\\osm\\sql\\world.db3';
var useBPolyFilter=false;
var useBBoxFilter=true;
var bBoxFilter=[':bbox',45.25,39.75,44.75,39.0];
var clipIncompleteWays=false;
var useCustomFilter=false;
//see line 'var cf={' for filter conditions
//settings end
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

function echo(s){
	WScript.stdOut.write(s+'\n');
};

function testFileWriter(){
	var d=new Date();
	echo('Test FileWriter');
	var fw=man.createObject('FileWriter');
	echo('FileWriter='+fw.toString());
	fw.open(testOSMOutFile);
	var ow=man.createObject('OSMWriter');
	echo('OSMWriter='+ow.toString());
	ow.setOutputStream(fw);
	var map=man.createObject('Map');
	echo('Map='+map.toString());
	ow.setInputMap(map);
	var stg=man.createObject('Storage');
	echo('Storage='+stg.toString());
	stg.dbName=testMapFile;
	map.storage=stg;
	var flt=[];
	if(useBBoxFilter){
		flt=flt.concat(bBoxFilter);
	};
	if(useBPolyFilter){
		var gt=man.createObject('GeoTools');
		echo('GeoTools='+gt.toString());
		var mpoly=gt.createPoly();
		mpoly.addObject(map.getWay(5961574));
		if(mpoly.resolve(map)){
			flt=flt.concat(':bpoly',mpoly);
			echo('MPoly='+mpoly.toString());
		}
		else{
			var ul=mpoly.getNotResolved().getAll().toArray();
			echo('NotResolved list:');
			for(var j=0;j<ul.length;j+=3){
				echo('	'+ul[j]+'	id='+ul[j+1]);
			};
		}
	};
	if(clipIncompleteWays){
		flt=flt.concat(':clipIncompleteWays');
	};
	if(useCustomFilter){
		var f1=false,f2=false,f3=false;
		var cf={
			onPutObject:function(aObj){WScript.stdOut.write('.');return true;},
			onPutNode:function(aNode){if(!f1){WScript.stdOut.write('\nnodes');f1=true;};return true;},
			onPutWay:function(aWay){if(!f2){WScript.stdOut.write('\nways');f2=true;};return true;},
			onPutRelation:function(aRelation){if(!f3){WScript.stdOut.write('\nrelations');f3=true;};return true;}
		};
		flt=flt.concat(':customFilter',cf);
	};
	ow.write(flt);
	echo('');
	map.storage=0;
	stg.dbName='';
	fw=ow=map=stg=0;
	d=(new Date())-d;
	echo('File exported in '+d+'ms');
}

//---===   main   ===---//

try{
	var man=WScript.CreateObject("OSMan.Application");
	echo(" App="+man.toString());
	testFileWriter();echo('');
}catch(e){
	echo('Unexpected exception '+e.description+' '+e.number);
}

echo('\r\npress `Enter`');
WScript.StdIn.Read(1);