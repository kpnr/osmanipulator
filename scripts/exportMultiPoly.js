//settings begin
var exportObjects='';
var srcMapName='';
var dstMapName='';
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;

function checkArgs(){
	function help(){
	echo('Multipolygon export\n\
  Command line options:\n\
    /src:"src_file_name.db3"\n\
    /dst:"dest_file_name.db3"\n\
    /refs:"relation:18,way:12"');
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('dst'))dstMapName=ar.item('dst')||dstMapName;
	if(ar.exists('src'))srcMapName=ar.item('src')||srcMapName;
	if(ar.exists('refs'))exportObjects=ar.item('refs')||exportObjects;
	if(dstMapName && srcMapName && exportObjects){
		echo('Use config:\nsrc='+srcMapName);
		echo('dst='+dstMapName);
		echo('refs='+exportObjects);
		return true;
	};
	help();
	return false;
};

function main(){
	if(!checkArgs())return;
	var src=h.mapHelper();
	echo('opening source map');
	src.open(srcMapName,false,true);
	var dst=h.mapHelper();
	echo('creating destination map');
	dst.open(dstMapName,true,false);
	exportObjects=exportObjects.split(',');
	echo('exporting objects');
	src.exportMultiPoly(dst.map,exportObjects);
	src.close();
	dst.close();
	echo('all done.');
};
main();