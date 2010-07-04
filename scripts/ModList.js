var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

function echo(s){
	WScript.Echo(s);
};


//---===   main   ===---//

try{
	var man=WScript.CreateObject("OSMan.Application");
	echo(" App="+man.toString());
	var mods=man.getModules().toArray();
	echo('Module list:');
	for(var i=0;i<mods.length;i++){
		echo('	'+mods[i]);
		var cls=man.getModuleClasses(mods[i]).toArray();
		for(var j=0;j<cls.length;j++){
			echo('		'+cls[j]);
		};
	};
	echo('');

	}catch(e){
	echo('Unexpected exception '+e.description+' '+e.number);
}

echo('\r\npress `Enter`');
WScript.StdIn.Read(1);