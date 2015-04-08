var dbName='e:\\db\\osm\\sql\\world.db3';
var diffFile='e:\\db\\osm\\sql\\tranlated.txt';
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var ttf=include('fin2win1251.js');

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
var q=mh.exec('SELECT tagvalue,id FROM tags'),cnt=0;//LIMIT 100000000 OFFSET 820000
while(!q.eos && (cnt<20)){
	var s=q.read(1).toArray();
	var ss=ttf(s[0]);
	if(ss!=s[0]){
	//	f.writeLine(s+'=>'+ss);
	//	f.writeLine(toCharCode(s)+'\r\n');
	};
	if(ss.indexOf('_[')>=0){
		echo('#'+s[1]+' '+s[0]+' => '+ss);
		f.writeLine(s[1])
		f.writeLine(s[0]);
		f.writeLine(ss);
		f.writeLine('---');
		cnt++;
	}else if((cnt&1023)==0)echo('#'+cnt,true);
};
mh.close();
f.close();
echo('done');
