//settings start
var testNode={lat:1,lon:1};
var testArray=[
	{lat:0,lon:0},
	{lat:2,lon:0},
	{lat:1,lon:0},
	{lat:0,lon:1},
	{lat:1,lon:1},
	[{lat:0,lon:0},{lat:-1,lon:0}],
	[{lat:3,lon:0},{lat:2,lon:0}],
	[{lat:2,lon:0},{lat:2,lon:0}],
	[{lat:0,lon:0},{lat:2,lon:0}],
	[{lat:0,lon:0},{lat:0,lon:2}]
];
//settings end
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

var man=0;

function echo(s){
	WScript.Echo(s);
};

function testGeoTools(){
	var d=new Date();
	var gtls=man.createObject('GeoTools');
	for(var i=0;i<testArray.length;i++){
		echo('Test '+i+'. Distance='+gtls.distance(testNode,testArray[i])+' m');
	};
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