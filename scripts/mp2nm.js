//settings begin
var srcMpName='';
var boundMpName='';
var dstNMName='';
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
	echo('Polish mp-file to navitel nm2 format conversion via GPSMapEdit.\n\
  Command line options:\n\
    /src:"src_file_name.mp"\n\
    /bound:"boundary_file_name.mp\n\
    /dst:"dest_file_name.nm2"');
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('src'))srcMpName=ar.item('src')||srcMpName;
	if(ar.exists('bound'))boundMpName=ar.item('bound')||boundMpName;
	if(ar.exists('dst'))dstNMName=ar.item('dst')||dstNMName;
	if(srcMpName && dstNMName){
		echo('Use config:\n');
		echo('src='+srcMpName);
		echo('bound='+boundMpName);
		echo('dst='+dstNMName);
		return true;
	}
	help();
	return false;
};


function main(){
	if(!checkArgs())return;
	echot('Starting GPSMapEdit');
	var gme=WScript.createObject('GPSMapEdit.Application');
	echot('	ok. GME version '+gme.version+((gme.isRegistered)?(' full'):(' demo')));
	//gme.visible=true;
	echot('Opening mp...');
	gme.open(srcMpName,false,true);
	echo(gme.messageLog);
	if(boundMpName){
		echot('Loading boundary...');
		gme.open(boundMpName,true,true);
		echo(gme.messageLog);
//		echot('Saving mp...');
//		gme.saveAs(srcMpName,'polish');
//		echo(gme.messageLog);
	};
	echot('Saving nm2...');
	gme.saveAs(dstNMName,'navitel-nm2');
	echo(gme.messageLog);
	//var edit=gme.edit;
	//edit.GeneralizeNodesOfPolylinesAndPolygons();
	gme.exit();
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
