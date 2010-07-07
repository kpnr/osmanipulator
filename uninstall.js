var re=/cscript/i;
var sh=WScript.CreateObject('WScript.Shell');
var fso=WScript.CreateObject('Scripting.FileSystemObject');
var scriptDir=fso.getParentFolderName(WScript.ScriptFullName);
if (WScript.FullName.search(re)>=0){
	WScript.Quit(sh.Run('WScript "'+WScript.ScriptFullName+'"',1,true));
};

function deleteFile(n){
	var fn=fso.buildPath(scriptDir,n);
	try{
	if(fso.fileExists(fn))fso.deleteFile(fn);
	}catch(e){
	};
};

var osmanName=fso.buildPath(scriptDir,'OSMan.omm');
var r=0;
if(fso.fileExists(osmanName))r=sh.Run('regsvr32 /u "'+osmanName+'"',1,true);
if(!r){
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
};
WScript.echo('Uninstall comleted '+((r)?('with errors'):('successfully. Now you can delete all OSMan-related files and folders')));