//settings
var testOSMOutFile='F:\\db\\osm\\testdata\\testOutFiltered.osm';
var testMapFile='F:\\db\\osm\\testdata\\test.db3';
var useBPolyFilter=true;
var useBBoxFilter=true;
var clipIncompleteWays=true;
var useCustomFilter=true;
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
		flt=flt.concat(':bbox',70.4077993,31.141223,70.357201,31.0114736,
		':bbox',70.3604353,31.0487785,70.3507815,31.0366968);
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
			var ul=mpoly.getUnresolved().getAll().toArray();
			echo('Unresolved list:');
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