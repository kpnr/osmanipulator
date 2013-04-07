//settings begin
var resolveObjects='relation:60189';//,relation:389344,relation:1221185,relation:1075831,relation:1216601,relation:1221148,relation:1113276,relation:1029256,relation:1059500,\
//relation:253252,relation:394235,relation:190911,relation:253256,relation:190090,relation:274048,relation:191706,relation:289998,relation:393980,relation:337422,relation:145194,relation:77677,relation:145729,relation:109876,relation:109879,relation:109878,relation:115136,relation:115114,relation:72196,relation:110032,relation:79374,relation:145195,relation:115134,relation:109877,relation:80513,relation:144764,relation:145730,relation:108082,relation:115135,relation:108081,relation:151223,relation:147166,relation:140337,relation:112819,relation:81997,relation:72197,relation:77665,relation:115106,relation:72181,relation:85617,relation:145454,relation:103906,relation:81995,relation:144763,relation:115100,relation:85963,relation:176095,relation:72169,relation:51490,relation:72195,relation:89331,relation:140294,relation:77669,relation:72224,relation:72182,relation:155262,relation:85606,relation:71950,relation:72194,relation:72193,relation:79379,relation:81996,relation:72180,relation:178005,relation:140295,relation:81993,relation:140291,relation:77687,relation:81994,relation:147167,relation:102269,relation:140296,relation:72192,relation:151234,relation:151231,relation:151225,relation:151228,relation:151233,relation:108083,relation:72223,relation:140290,relation:140292,relation:83184';
var srcMapNames=['f:\\db\\osm\\sql\\rf.db3']//,'f:\\db\\osm\\sql\\rf.db3'];
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
