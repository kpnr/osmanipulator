//settings begin
var resolveObjects='way:104,way:112,relation:126,relation:130,relation:128';
var srcMapNames=['f:\\db\\osm\\testdata\\polyclip.db3'];
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;

var src=[];
for(var i=0;i<srcMapNames.length;i++){
	var mh=h.mapHelper();
	echo('opening '+srcMapNames[i]);
	mh.open(srcMapNames[i],false,true);
	//mh.renumberNewObjects();
	src[i]=mh.map;
}
resolveObjects=resolveObjects.split(',');
for(var i=0;i<resolveObjects.length;i++){
	var rs=h.getMultiPoly(resolveObjects[i],src);
	var s=resolveObjects[i]+((!rs.poly)?(' not'):(''))+' resolved';
	if(rs.poly){
		s+=' src='+rs.usedMap.storage.dbName;
		s+='\n	S='+(rs.poly.getArea()/1e6).toFixed(3)+' km2';
		s+='\n	orientation='+['mixed','CW','CCW'][rs.poly.getOrientation()];
	}else{
		s+='\n	not found='+rs.notFoundRefs+'\n	not closed='+rs.notClosedRefs;
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
