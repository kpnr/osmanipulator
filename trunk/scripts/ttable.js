var dbName='F:\\db\\osm\\sql\\rf.db3';
var diffFile='F:\\db\\osm\\sql\\tranlated.txt';
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var ttf=include('utf2win1251.inc');

var h=new(include('helpers.js'))();
var echo=h.echo;
function toCharCode(s){
	var r=''
	for(var i=0;i<s.length;i++){
		var c=s.charCodeAt(i).toString(16);
		while(c.length<4)c='0'+c;
		r+=' '+c;
	};
	return r;
};
var mh=h.mapHelper();
mh.open(dbName,false,true);
var f=h.fso.openTextFile(diffFile,2,true,-1);
var q=mh.exec('SELECT tagvalue FROM tags ORDER BY tagvalue'),cnt=0;//LIMIT 100000000 OFFSET 820000
while(!q.eos){
	var s=q.read(1).toArray()[0];
	cnt++;
	var ss=ttf(s);
	if(ss!=s){
	//	f.writeLine(s+'=>'+ss);
	//	f.writeLine(toCharCode(s)+'\r\n');
	};
	if(ss.indexOf('_[')>=0){
		echo('#'+cnt+' '+s+' => '+ss);
	}else if((cnt&1023)==0)echo('#'+cnt,true);
};
mh.close();
f.close();
echo('done');
