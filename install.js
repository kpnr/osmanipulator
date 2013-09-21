var sh=WScript.CreateObject('WScript.Shell'),env=sh.Environment('Process'),fso=WScript.CreateObject('Scripting.FileSystemObject'),exe;
var scriptDir=fso.getParentFolderName(WScript.ScriptFullName);
if ((/cscript\.exe$/i).test(WScript.FullName)){
	exe=fso.buildPath(fso.buildPath(env('WINDIR'),'system32'),'wscript.exe');
}
var pf86=env('PROGRAMFILES(X86)');
if(pf86){
	//we in Win64
	if(pf86!=env('PROGRAMFILES')){
		//our host in 64-bit
		exe=fso.buildPath(fso.buildPath(env('WINDIR'),'SysWOW64'),'wscript.exe');
	};
};
if(exe){
	sh.Run('"'+exe+'" "'+WScript.ScriptFullName+'"',1,false);
	WScript.Quit(0);
};
var osmanName='"'+fso.buildPath(scriptDir,'OSMan.omm')+'"';
var msgBoxTitle='OSManipulator install script';
if(sh.popup('This script will register OSManipulator objects in Registry.\n\
Continue with install?',0,msgBoxTitle,4+32)!=6){
	WScript.quit(1);
};
var winSh=WScript.CreateObject('Shell.Application');
var folder=winSh.NameSpace(fso.buildPath(env('WINDIR'),'system32'));
var reg32=folder.ParseName('regsvr32.exe');
if(parseFloat(WScript.Version)>5.6){
	reg32.invokeVerbEx('runas',osmanName);
}else{
	reg32.invokeVerbEx('run',osmanName);
};
sh.popup('If you want to set console version of scripting executive as default then run commannd\n\
"cscript //H:CScript" from command prompt',0,msgBoxTitle,64);