//settings begin
var srcMapName='';
var dstOSMName='';
var intToDeg=1e-7,degToInt=1/intToDeg;
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

//global variables
var h=new (include('helpers.js'))();
var echo=h.echo;
function echot(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
}
//end global variables
function checkArgs(){
	function help(){
	echo('Fast map database export to OSM format. No filtering supported.\n\
  Command line options:\n\
    /src:"src_file_name.db3"\n\
    /dst:"dest_file_name.osm"');
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('src'))srcMapName=ar.item('src')||srcMapName;
	if(ar.exists('dst'))dstOSMName=ar.item('dst')||dstOSMName;
	if(srcMapName && dstOSMName){
		echo('Use config:\n');
		echo('src='+srcMapName);
		echo('dst='+dstOSMName);
		return true;
	}
	help();
	return false;
};


function main(){
	if(!checkArgs())return;
	echot('Opening map');
	var src=h.mapHelper();
	src.open(srcMapName);
	echot('Exporting...');
	src.exportXML(dstOSMName);
	src.close();
	echot('All done.');
}

try{
main();
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
