//settings begin
var dstMapName='';
var noAddr=false;
var noTTable=false;
var bitLevel=0;
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

function yaml(){};
yaml.load=function(fName){
	var f=h.fso.OpenTextFile(fName,1,false,-1);//forReading,dontCreate,UTF16
	var t=f.readAll();
	f.close();
	t=h.gt.utf8to16(t);
	var a=t.match(/^([^#\r\n].*)$/gm);
	if(a)for(var i=0;i<a.length;i++)h.man.log('<'+a[i]+'>');
};

function log(s){echo(s)};

//end global variables
function main(){
	h.man.logger={log:log};
	var addrCfg=yaml.load('f:\\db\\cvt\\addressing.yml');
}

try{
WScript.Sleep(1000);
main();
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
