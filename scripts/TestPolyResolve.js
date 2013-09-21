//settings begin
var resolveObjects='relation:2800681,relation:364171,relation:364165,relation:365306,relation:365299,relation:365302,relation:364543,relation:364545,relation:364548,relation:365231,relation:365233,relation:364169,relation:364123,relation:365308,relation:364156,relation:364150,relation:269701,relation:364116,relation:365309,relation:365311,relation:371561,relation:365303,relation:365144,relation:365147,relation:365168,way:83806526,way:218559335';
var srcMapNames=['f:\\db\\osm\\regions\\yufo_w.db3 ']//,'f:\\db\\osm\\sql\\rf.db3'];
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;

var src=[];
for(var i=0;i<srcMapNames.length;i++){
	var mh=h.mapHelper();
	echo('opening '+srcMapNames[i]);
	mh.open(srcMapNames[i],false,true);
	src[i]=mh.map;
}
resolveObjects=resolveObjects.split(',');
resolveObjects=[resolveObjects];
for(var i=0;i<resolveObjects.length;i++){
	var rs=h.getMultiPoly(resolveObjects[i],src);
	var s=resolveObjects[i]+((!rs.poly)?(' not'):(''))+' resolved';
	if(rs.poly){
		s+=' src='+rs.usedMap.storage.dbName;
	}else{
		s+='not found='+rs.notFoundRefs+' not closed='+rs.notClosedRefs;
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
