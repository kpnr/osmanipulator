//settings begin
var exportObjects='relation:151234,relation:1221185,relation:189815,relation:190089,relation:1399817,relation:1399819,relation:1399820,relation:1399823,relation:1399824,relation:1399825,relation:1399826,relation:1399827,relation:1399828,relation:1399830,relation:1399831,relation:1399832,relation:1399834,relation:1399835,relation:1399836,relation:1399837,relation:1399838,relation:1399839,relation:1399840,relation:1399841,relation:1444344';
//nizhniy novgorod 'relation:72195,relation:1709973'
//ivanovo 'relation:85617,relation:1672786'
//bryansk'relation:81995,relation:902019'
//leningrad 'relation:176095,relation:60189'
//caliningrad 'relation:103906,relation:372877,way:113555466,relation:72596'
//pskov'relation:155262,way:75048467'//,way:141895072';
//sbp 'relation:337422,relation:1783782,relation:1783818'//relation:1652937'//,way:125832934'//,relation:1783788'//,relation:1373385,way:51423335,relation:391133,relation:1130269,way:125623243,relation:1560853,relation:1560855,relation:1117549,relation:1119501,relation:962380,relation:176095,relation:1162549';
var srcMapName='f:\\db\\osm\\sql\\rf.db3';
var dstMapName='f:\\db\\osm\\sql\\yakut.db3';
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;

var src=h.mapHelper();
src.open(srcMapName,false,true);
var dst=h.mapHelper();
dst.open(dstMapName,true,false);
src.exportRecurcive(dst.map,exportObjects.split(','));
src.close(dst);
dst.exportXML(dstMapName+'.osm');
dst.close(src);
echo('press Enter');
WScript.stdIn.readLine();
