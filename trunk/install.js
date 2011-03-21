var re=/cscript/i;
var sh=WScript.CreateObject('WScript.Shell');
if (WScript.FullName.search(re)>=0){
	WScript.Quit(sh.Run('WScript "'+WScript.ScriptFullName+'"',1,true));
};

var fso=WScript.CreateObject('Scripting.FileSystemObject');
var scriptDir=fso.getParentFolderName(WScript.ScriptFullName);
var r=sh.Run('regsvr32 "'+fso.buildPath(scriptDir,'OSMan.omm')+'"',1,true);
WScript.echo('Install completed '+((r)?('with errors'):('successfully')));