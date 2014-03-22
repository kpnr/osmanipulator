//settings begin
var exportObjects='relation:253256,relation:108082,way:83806526,way:218559335,way:238797487,relation:2800681,relation:364171,relation:364165,relation:365306,relation:365299,relation:365302,relation:364543,relation:364545,relation:364548,relation:365231,relation:365233,relation:371561,relation:365303,way:83806526,way:218559335,way:238797487,relation:365311,relation:365309,relation:365308,relation:364123,relation:364116,relation:269701,relation:364169,relation:364156,relation:364150,relation:365144,relation:365147,relation:365168,relation:365297,relation:371579,relation:371580,relation:371621,relation:371614,relation:371607,relation:918967,relation:918974,relation:919000,relation:919011,relation:918999,relation:919005,relation:918986,relation:919004,relation:918994,relation:918989,relation:918995,relation:371571,relation:371556,relation:371552,relation:253256,relation:2050901';
var srcMapName='e:\\db\\osm\\sql\\world.db3';
var dstMapName='e:\\db\\osm\\sql\\cut_test.db3';
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
