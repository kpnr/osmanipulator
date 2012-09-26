var src='s:\\db\\osm\\sql\\rf.db3';
var dst='f:\\db\\osm\\sql\\rf.db3';
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;

var srcDB=h.man.createObject('Storage');
var dstDB=h.man.createObject('Storage');
srcDB.dbName=src;
if(h.fso.fileExists(dst)){
	h.fso.deleteFile(dst);
};
dstDB.dbName=dst;
echo('Creating db objects')
srcDB.sqlExec(srcDB.sqlPrepare('PRAGMA locking_mode=NORMAL'),0,0);
var q=srcDB.sqlPrepare("SELECT type,name,sql FROM sqlite_master WHERE NOT(type='table' AND name='sqlite_sequence') AND length(sql)>0");
var qr=srcDB.sqlExec(q,0,0);
var dataTables=[];
while(!qr.eos){
	var row=qr.read(1).toArray();
	if(!row[2].length)continue;
	echo('	'+row[1]+':'+row[0]);
	try{
		q=dstDB.sqlPrepare(row[2]);
		dstDB.sqlExec(q,0,0);
		if(row[0]=='table')dataTables.push(row[1]);
	}catch(e){
		echo('		Exception: '+e.description);
	}
};
dstDB.dbName='';
echo('Importing tables');
srcDB.sqlExec(srcDB.sqlPrepare('COMMIT'),0,0);
srcDB.sqlExec(srcDB.sqlPrepare('ATTACH "'+dst+'" AS dst'),0,0);
srcDB.sqlExec(srcDB.sqlPrepare('PRAGMA dst.journal_mode=off'),0,0);
for(var i=dataTables.length-1;i>=0;i--){
	srcDB.sqlExec(srcDB.sqlPrepare('BEGIN'),0,0);
	echo('	Importing '+dataTables[i]);
	q='INSERT INTO dst."'+dataTables[i]+'" SELECT * FROM "'+dataTables[i]+'"';
	srcDB.sqlExec(srcDB.sqlPrepare(q),0,0);
	srcDB.sqlExec(srcDB.sqlPrepare('COMMIT'),0,0);
};
srcDB.sqlExec(srcDB.sqlPrepare('DETACH dst'),0,0);
srcDB.dbName='';
