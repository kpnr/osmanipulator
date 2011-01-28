//settings start
var scriptIniFile='F:\\db\\osm\\snapdl.ini';
var osm2mpScriptName='osm2mp.pl';
var deleteOsmAfterConvert=false;
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var osmExportDir,osm2mpDir,mpExportDir,Ini=include('inifile.js');

function echo(s){
	WScript.Echo(''+s);
};

function main(){
	var ini=new Ini();
	ini.read(scriptIniFile);
	osmExportDir=ini.data['osmExportDir'];
	osm2mpDir=ini.data['osm2mpDir'];
	mpExportDir=ini.data['mpExportDir'];
	var fso=WScript.createObject('Scripting.FileSystemObject');
	function convert(file){
		var osmFullName=fso.buildPath(osmExportDir,file.name);
		var baseName=fso.getBaseName(file);
		//echo('	->	'+fso.buildPath(mpExportDir,fso.getBaseName(file)+'.mp'));
		var wsh=WScript.createObject('WScript.Shell');
		wsh.currentDirectory=osm2mpDir;
		var cl='%ComSpec% /C '+osm2mpScriptName+' --config="navitel.yml" --navitel --disableuturns --nodestsigns --poiregion --defaultcountry=RU --defaultregion="'+baseName+'" "'+osmFullName+'" >"'+fso.buildPath(mpExportDir,baseName+'.mp')+'"';
		//echo(cl);
		wsh.run(cl,10,true);
	};
	var files=new Enumerator(fso.getFolder(osmExportDir).files);
	for(;!files.atEnd();files.moveNext()){
		var file=files.item();
		if (!(/.*\.osm/i).test(file.name)) continue;/**/
		convert(file);
	};
};

main();