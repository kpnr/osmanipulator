//setting start
var srcDBName='f:\\db\\osm\\sql\\rf_old.db3';
var dstDBName='f:\\rf_new.db3';
//settings end
var srcDB=false,dstDB=false,man=false;

function echo(s){
	WScript.StdOut.write(s+'\n');
};

function exec(sqlstr,db){
	db=db?db:dstDB;
	var q=db.sqlPrepare(sqlstr);
	db.sqlExec(q,'','');
}

function initNewDB(){
  exec('DROP TABLE IF EXISTS nodes_attr');
  exec('CREATE TABLE IF NOT EXISTS nodes_attr (' +
 'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
 'version INTEGER DEFAULT 1 NOT NULL,' +
 'timestamp VARCHAR(20),' +
 'userId INTEGER DEFAULT 0,' +
 'changeset BIGINT)');

  exec('DROP TABLE IF EXISTS nodes_latlon');
	exec('CREATE VIRTUAL TABLE nodes_latlon USING rtree_i32(id,minlat,maxlat,minlon,maxlon)');
	
	exec('DROP VIEW IF EXISTS nodes');
	exec('CREATE VIEW IF NOT EXISTS nodes AS SELECT nodes_latlon.id as id,nodes_latlon.minlat as lat, nodes_latlon.minlon as lon, nodes_attr.version as version, nodes_attr.timestamp as timestamp, nodes_attr.userId as userId, nodes_attr.changeset as changeset FROM nodes_attr, nodes_latlon WHERE nodes_attr.id=nodes_latlon.id');
	
	exec('DROP TRIGGER IF EXISTS nodes_ii');
	exec('CREATE TRIGGER IF NOT EXISTS nodes_ii INSTEAD OF INSERT ON nodes BEGIN ' + 
		'INSERT INTO nodes_attr (id, version, timestamp, userId, changeset) ' + 
		'VALUES (NEW.id,NEW.version, NEW.timestamp, NEW.userId, NEW.changeset);' +
		'INSERT INTO nodes_latlon(id,minlat,maxlat,minlon,maxlon)' +
		'VALUES (NEW.id, NEW.lat, NEW.lat, NEW.lon, NEW.lon);' +
		'END;');
	
	exec('DROP TRIGGER IF EXISTS nodes_iu');
	exec('CREATE TRIGGER IF NOT EXISTS nodes_iu INSTEAD OF UPDATE ON nodes BEGIN ' + 
		'UPDATE nodes_attr SET id=NEW.id, version=NEW.version, timestamp=NEW.timestamp, userId=NEW.userID, changeset=NEW.changeset WHERE id=OLD.id;' +
		'UPDATE nodes_latlon SET id=NEW.id,minlat=NEW.lat,maxlat=NEW.lat,minlon=NEW.lon,maxlon=NEW.lon WHERE id=NEW.id;' +
		'DELETE FROM objtags WHERE objid=4*OLD.id;'+
		'END;');

	exec('DROP TRIGGER IF EXISTS nodes_id');
	exec('CREATE TRIGGER IF NOT EXISTS nodes_id INSTEAD OF DELETE ON nodes BEGIN ' + 
		'DELETE FROM nodes_attr WHERE id=OLD.id;' +
		'DELETE FROM nodes_latlon WHERE id=OLD.id;' +
		'DELETE FROM objtags WHERE objid=4*OLD.id;'+
		'END;');
 
  exec('DROP TABLE IF EXISTS users');
  exec('CREATE TABLE IF NOT EXISTS users (' +
 'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
 'name VARCHAR(40) NOT NULL)');

  exec('DROP TABLE IF EXISTS tags');
  exec('CREATE TABLE IF NOT EXISTS tags(' +
 'id INTEGER NOT NULL CONSTRAINT tags_pk PRIMARY KEY AUTOINCREMENT,' +
 'tagname VARCHAR(50) CONSTRAINT tags_tagname_c COLLATE BINARY,' +
 'tagvalue VARCHAR(150) CONSTRAINT tags_tagvalue_c COLLATE BINARY' +
 ')');
  exec('CREATE UNIQUE INDEX IF NOT EXISTS tags_tagname_tagvalue_i ' +
 'ON tags(tagname,tagvalue)');

  exec('DROP TABLE IF EXISTS objtags');
  exec('CREATE TABLE IF NOT EXISTS objtags(' +
 'objid BIGINT NOT NULL /* =id*4 + (0 for node, 1 for way, 2 for relation) */,' +
 'tagid BIGINT NOT NULL,' +
 'CONSTRAINT objtags_pk PRIMARY KEY (objid,tagid)' +
 ')');

  exec('DROP TABLE IF EXISTS ways');
  exec('CREATE TABLE IF NOT EXISTS ways (' + 'id INTEGER PRIMARY KEY AUTOINCREMENT,' + 'version INTEGER DEFAULT 1 NOT NULL,' + 'timestamp VARCHAR(20),' + 'userId INTEGER DEFAULT 0,' + 'changeset BIGINT)');

  exec('DROP TABLE IF EXISTS waynodes');
  exec('CREATE TABLE IF NOT EXISTS waynodes (' + 'wayid INTEGER NOT NULL,' + 'nodeidx INTEGER NOT NULL,' + 'nodeid INTEGER NOT NULL,' + 'PRIMARY KEY (wayid,nodeidx))');

  exec('DROP TABLE IF EXISTS relations');
  exec('CREATE TABLE IF NOT EXISTS relations (' + 'id INTEGER PRIMARY KEY AUTOINCREMENT,' + 'version INTEGER DEFAULT 1 NOT NULL,' + 'timestamp VARCHAR(20),' + 'userId INTEGER DEFAULT 0,' + 'changeset BIGINT)');

  exec('DROP TABLE IF EXISTS relationmembers');
  exec('CREATE TABLE IF NOT EXISTS relationmembers(' + 'relationid INTEGER NOT NULL,' + 'memberidxtype INTEGER NOT NULL,/*=index*4+(0 for node, 1 for way, 2 for relation)*/' + 'memberid INTEGER NOT NULL,' + 'memberrole VARCHAR(20) DEFAUlT \'\',' + 'PRIMARY KEY (relationid,memberidxtype))');

	exec('PRAGMA cache_size=100000');
};

function createIndexes(){
  exec('DROP VIEW IF EXISTS strrelations');
  exec('CREATE VIEW IF NOT EXISTS strrelations AS ' + 'SELECT relations.id AS id, version AS version, ' + 'timestamp AS timestamp, userId as userId, users.name AS userName, changeset as changeset ' + 'FROM relations,users WHERE relations.userId=users.id');

  exec('DROP VIEW IF EXISTS strobjtags');
  exec('CREATE VIEW strobjtags AS ' + 'SELECT objid AS \'objid\',tagname AS \'tagname\',tagvalue AS \'tagvalue\' ' + 'FROM objtags,tags WHERE objtags.tagid=tags.id');

  exec('DROP VIEW IF EXISTS strways');
  exec('CREATE VIEW IF NOT EXISTS strways AS ' + 'SELECT ways.id AS id, version AS version, ' + 'timestamp AS timestamp, userId as userId, users.name AS userName, changeset as changeset ' + 'FROM ways,users WHERE ways.userId=users.id');

  exec('DROP VIEW IF EXISTS strrelationmembers');
  exec('CREATE VIEW IF NOT EXISTS strrelationmembers AS ' + 'SELECT relationid AS relationid, ' + '(memberidxtype>>2) AS memberidx,' + '(CASE (memberidxtype & 3) WHEN 0 THEN \'node\' WHEN 1 THEN \'way\' WHEN 2 THEN \'relation\' ELSE \'\' END) AS membertype,' + 'memberid AS memberid,' + 'memberrole AS memberrole ' + 'FROM relationmembers');

  exec('DROP VIEW IF EXISTS strnodes');
  exec('CREATE VIEW IF NOT EXISTS strnodes AS ' +
 'SELECT nodes.id AS id, lat AS lat, lon AS lon, version AS version, ' +
 'timestamp AS timestamp, userId as userId, users.name AS userName, changeset as changeset ' +
 'FROM nodes,users WHERE nodes.userId=users.id');
  exec('CREATE TRIGGER IF NOT EXISTS strnodes_ii INSTEAD OF INSERT ON strnodes BEGIN ' +
 'INSERT OR IGNORE INTO users (id, name) VALUES (NEW.userID, NEW.userName);' +
 'INSERT OR REPLACE INTO nodes (id,lat,lon,version,timestamp,userId,changeset) ' +
 'VALUES(NEW.id,NEW.lat,NEW.lon,NEW.version,NEW.timestamp,NEW.userId,NEW.changeset);' +
 'END;');

  exec('CREATE INDEX objtags_tagid_i ON objtags(tagid)');
  exec('CREATE TRIGGER IF NOT EXISTS ways_bi BEFORE INSERT ON ways BEGIN ' + 'DELETE FROM objtags WHERE objid=1+4*NEW.id;' + 'DELETE FROM waynodes WHERE wayid=NEW.id;' + 'END');
  exec('CREATE TRIGGER IF NOT EXISTS ways_bu BEFORE UPDATE ON ways BEGIN ' + 'DELETE FROM objtags WHERE objid=1+4*NEW.id;' + 'DELETE FROM waynodes WHERE wayid=NEW.id;' + 'END');
  exec('CREATE TRIGGER was_bd BEFORE DELETE ON ways BEGIN ' + 'DELETE FROM objtags WHERE objid=1+4*OLD.id;' + 'DELETE FROM waynodes WHERE wayid=OLD.id;' + 'END');
  exec('CREATE TRIGGER strobjtags_ii INSTEAD OF INSERT ON strobjtags BEGIN ' + 'INSERT OR IGNORE INTO tags (tagname, tagvalue) ' + 'VALUES (NEW.tagname,NEW.tagvalue);' + 'INSERT OR IGNORE INTO objtags(objid,tagid) ' + 'VALUES (NEW.objid,(SELECT id FROM tags WHERE tags.tagname=NEW.tagname AND tags.tagvalue=NEW.tagvalue));' + 'END;');
	exec('DROP TRIGGER IF EXISTS strways_ii');	
  exec('CREATE TRIGGER IF NOT EXISTS strways_ii INSTEAD OF INSERT ON strways BEGIN ' + 'INSERT OR IGNORE INTO users (id, name) VALUES (NEW.userId, NEW.userName);' + 'INSERT OR REPLACE INTO ways (id,version,timestamp,userId,changeset) ' + 'VALUES(NEW.id,NEW.version,NEW.timestamp,NEW.userId,NEW.changeset);' + 'END;');
  exec('CREATE INDEX IF NOT EXISTS waynodes_nodeid_i ON waynodes (nodeid)');
  exec('CREATE TRIGGER IF NOT EXISTS relations_bi BEFORE INSERT ON relations BEGIN ' + 'DELETE FROM objtags WHERE objid=2+4*NEW.id;' + 'DELETE FROM relationmembers WHERE relationid=NEW.id;' + 'END');
  exec('CREATE TRIGGER IF NOT EXISTS relations_bu BEFORE UPDATE ON relations BEGIN ' + 'DELETE FROM objtags WHERE objid=2+4*NEW.id;' + 'DELETE FROM relationmembers WHERE relationid=NEW.id;' + 'END');
  exec('CREATE TRIGGER relations_bd BEFORE DELETE ON relations BEGIN ' + 'DELETE FROM objtags WHERE objid=2+4*OLD.id;' + 'DELETE FROM relationmembers WHERE relationid=OLD.id;' + 'END');
  exec('CREATE TRIGGER IF NOT EXISTS strrelations_ii INSTEAD OF INSERT ON strrelations BEGIN ' + 'INSERT OR IGNORE INTO users (id, name) VALUES (NEW.userId, NEW.userName);' + 'INSERT OR REPLACE INTO relations (id,version,timestamp,userId,changeset) ' + 'VALUES(NEW.id,NEW.version,NEW.timestamp,NEW.userId,NEW.changeset);' + 'END;');
  exec('CREATE INDEX IF NOT EXISTS relationmembers_memberid_i ON relationmembers(memberid)');
  exec('CREATE TRIGGER IF NOT EXISTS strrelationmembers_ii INSTEAD OF INSERT ON strrelationmembers BEGIN ' + 'INSERT OR REPLACE INTO relationmembers (relationid,memberidxtype,memberid,memberrole) ' + 'VALUES(NEW.relationid,' + 'NEW.memberidx*4+(CASE NEW.membertype WHEN \'node\' THEN 0 WHEN \'way\' THEN 1 WHEN \'relation\' THEN 2 ELSE 3 END),' + 'NEW.memberid,' + 'NEW.memberrole);' + 'END;');
};

function openDB(dbName,ro){
	var r=man.createObject('Storage');
	ro?(r.readOnly=true):(r.readOnly=false);
	r.dbName=dbName;
	return r;
};

function importTable(tName){
	echo('import table '+tName);
	var d=new Date();
	var n=0;
	var rq=srcDB.sqlPrepare('SELECT * FROM '+tName);
	rq=srcDB.sqlExec(rq,'','');
	var colNames=rq.getColNames().toArray();
	echo('Col names=['+colNames+']');
	var s1='INSERT INTO '+tName,s2=' VALUES ',delim='( ';
	for(var i=0;i<colNames.length;i++){
		if(tName=='nodes' && (colNames[i]=='lat')||(colNames[i]=='lon')){
			s2+=delim+'round(:'+colNames[i]+'*10000000)';
		}else{
			s2+=delim+':'+colNames[i];
		};
		s1+=delim+colNames[i];
		colNames[i]=':'+colNames[i];
		delim=', ';
	};
	s1+=')'+s2+')';
	var wq=dstDB.sqlPrepare(s1);
	while(!rq.eos){
		var rows=rq.read(512);
		dstDB.sqlExec(wq,colNames,rows);
		WScript.stdOut.write('\r'+n+' speed='+Math.round(n/(new Date()-d+1)*1000)+'	');
		n+=512;
	};
	d=new Date()-d;
	echo('\n\rtable '+tName+' imported in '+d+' ms speed='+Math.round(n/d*1000)+' row/s');
};

function importDB(){
	importTable('waynodes');
	importTable('nodes');
	importTable('users');
	importTable('tags');
	importTable('ways');
	importTable('relations');
	importTable('relationmembers');
	importTable('objtags');
};

function main(){
	man=WScript.createObject('OSMan.Application');
	srcDB=openDB(srcDBName,true);
	dstDB=openDB(dstDBName);
	initNewDB();
	importDB();
	createIndexes();
};

main();