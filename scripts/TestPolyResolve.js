//settings begin
var resolveObjects='way:96104168,way:96165571,relation:1329568,relation:1330723,relation:1330718,relation:3360603,relation:1330775,relation:1330715,way:99136248,way:99136246,way:112226356,relation:1330721,relation:1330728';
var srcMapNames=['d:\\work\\osm2russa\\OSMan\\scripts\\yufow.db3']//,'f:\\db\\osm\\sql\\rf.db3'];
var useOnlineMap=false;
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;

var src=[];
if(useOnlineMap){
	var map=h.man.createObject('NetMap');
	var stg=h.man.createObject('HTTPStorage');
	map.storage=stg;
	src.push(map);
}else{
	for(var i=0;i<srcMapNames.length;i++){
		var mh=h.mapHelper();
		echo('opening '+srcMapNames[i]);
		mh.open(srcMapNames[i],false,true);
		src[i]=mh.map;
	}
}
resolveObjects=resolveObjects.split(',');
resolveObjects=[resolveObjects];
for(var i=0;i<resolveObjects.length;i++){
	var rs=h.getMultiPoly(resolveObjects[i],src);
	var s=resolveObjects[i]+((!rs.poly)?(' not'):(''))+' resolved';
	if(rs.poly){
		s+='\nsrc='+rs.usedMap.storage.dbName;
	}else{
		s+='\nnot found='+rs.notFoundRefs+'\nnot closed='+rs.notClosedRefs;
	};
	echo(s);
};
for(var i=0;i<src.length;i++){
	var s=src[i].storage;
	src[i].storage=0;
	s.dbName='';
}
echo('press Enter');
WScript.stdIn.readLine();
