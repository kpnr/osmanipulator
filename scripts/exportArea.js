//settings begin
var boundaryObject='';
var srcMapName='';
var dstMapName='';
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;
function echot(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
}

function checkArgs(){
	function help(){
	echo('Export objects within bounds from one database to another.\n\
  Command line options:\n\
    /bound:"relation:1,relation:12,relation:123" Optional argument. If ommitted then entire map processed.\n\
    /src:"src_file_name.db3"\n\
    /dst:"dest_file_name.db3"\n');
		return false;
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('src'))srcMapName=ar.item('src')||srcMapName;
	if(ar.exists('dst'))dstMapName=ar.item('dst')||dstMapName;
	if(ar.exists('bound'))boundaryObject=ar.item('bound')||boundaryObject;
	if(srcMapName && dstMapName){
		echo('Use config:\n');
		echo('bound='+boundaryObject);
		echo('src='+srcMapName);
		echo('dst='+dstMapName);
		return true;
	}
	help();
	return false;
};

function main(){
	if(!checkArgs())return false;
	var dst=h.mapHelper();
	dst.open(dstMapName,true);
	var src=h.mapHelper();
	src.open(srcMapName,false,true);
	var bpoly=false;
	if(boundaryObject){
		echot('Resolving boundary');
		var bpoly=h.getMultiPoly(boundaryObject.split(','),src.map).poly;
		if(!bpoly){
			echot('	fail');
			return false;
		}else{
			echot(' done S='+(bpoly.getArea()/1e6).toFixed(3)+' km2');
		};
	};
	echot('Export started');
	var flt=[];
	if(bpoly){
		flt=[':bpoly',bpoly,':bbox'].concat(bpoly.getBBox().toArray());
	};
	src.exportDB(dst.map,flt);
	src.close();
	dst.close();
	src=0;
	dst=0;
	echot('all done.');
	return true;
};

try{
main();
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
