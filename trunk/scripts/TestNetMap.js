//settings
//Relation[60189] - RF boundary
var testObjId=60189;//node 767959370; way 4473554; relation 60189
var testObjType='relation';//may be 'node','way' or 'relation'
//end settings
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

var man=0,fso=0;

function echo(s){
	WScript.Echo(s);
};

function testNetMap(){
	var d=new Date();
	var map=man.createObject('NetMap');
	echo('Map='+map.toString());
	var stg=man.createObject('HTTPStorage');
	echo('Storage='+stg.toString());
	map.storage=stg;
	var testObj=false;
	switch(testObjType){
	case 'node':
		testObj=map.getNode(testObjId);
		break;
	case 'way':
		testObj=map.getWay(testObjId);
		break;
	case 'relation':
		testObj=map.getRelation(testObjId);
		break;
	};
	echo('testObj='+testObj);
	if(testObj){
		echo('Object='+testObj.toString());
		echo('	ver='+testObj.version);
		echo('	user='+testObj.userName);
	}else{
		echo(testObjType+'['+testObjId+'] not found');
	}
	map.storage=0;
	d=(new Date())-d;
	echo('Test time: '+d+'ms');
}

//---===   main   ===---//

fso=WScript.CreateObject('Scripting.FileSystemObject');
man=WScript.CreateObject("OSMan.Application");
echo("App="+man.toString());
testNetMap();echo('');

echo('\r\npress `Enter`');
WScript.StdIn.Read(1);