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

function deleteFile(n){
	var fn=fso.buildPath(scriptDir,n);
	try{
	if(fso.fileExists(fn))fso.deleteFile(fn);
	}catch(e){
	};
};

if(sh.popup('This script will unregister OSManipulator objects in Registry and delete all files and folders in OSManipulator folder.\n\
Continue with uninstall?',0,'OSManipulator uninstall script',4+32)!=6){
	WScript.quit(1);
};
var osmanName=fso.buildPath(scriptDir,'OSMan.omm');
if(fso.fileExists(osmanName)){
	var winSh=WScript.CreateObject('Shell.Application');
	var folder=winSh.NameSpace(fso.buildPath(env('WINDIR'),'system32'));
	var reg32=folder.ParseName('regsvr32.exe');
	if(parseFloat(WScript.Version)>5.6){
		reg32.invokeVerbEx('runas',osmanName);
	}else{
		reg32.invokeVerbEx('run',osmanName);
	}
	WScript.sleep(30000);
}
deleteFile('OSman.omm');
deleteFile('OSManPack.omm');
deleteFile('SQLite3.dll');
deleteFile('install.js');
deleteFile('uninstall.js');
var fldr=fso.getFolder(scriptDir);
var fc = new Enumerator(fldr.files);
try{
	if(fc.atEnd())fso.deleteFolder(scriptDir);
}catch(e){
};
sh.popup('OSManipulator uninstall comleted.',0,'OSManipulator uninstall script',0+32);