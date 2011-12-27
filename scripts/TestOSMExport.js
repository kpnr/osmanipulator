//settings
var testOSMOutFile='F:\\db\\osm\\sql\\testOut.osm';
var testMapFile='F:\\db\\osm\\sql\\test.db3';
//settings end
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

function echo(s){
	WScript.Echo(s);
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
	ow.write(0);
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