//settings begin
var exportObjects='relation:1949879';
var srcMapName='c:\\tmp\\htc\\chkt_e.db3';
var dstMapName='c:\\tmp\\htc\\chkt_e1.db3';
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;

var src=h.mapHelper();
//src.open(filename,forceRecreate,readOnly);
src.open(srcMapName,false,true);
var dst=h.mapHelper();
dst.open(dstMapName,false,false);
src.exportRecurcive(dst.map,exportObjects.split(','));
src.close(dst);
dst.exportXML(dstMapName+'.osm');
dst.close(src);
echo('press Enter');
WScript.stdIn.readLine();
