/*
Hlp members:
	man - OSMan application
	gt - OSMan GeoTools module
	fso - filesystem object
	defaultStorage - default storage class name ('Storage')
	defaultMap - default map class name ('Map');
	echo(msg,noLF,noCR) - write msg to stdout. Without line feed and carriage return if needed.
	mapHelper() - create MapHelper object

MapHelper members:
	open(dbName,forceReCreate,readOnly) - open file dbName using class names from Hlp.
	close() - close map and storage
	importXML(xmlName) - import XML (OSM or OSC) file. BZ2 and GZ compression supported.
	exportXML(dstFileName,exportFilter) - export to osm-file with optional filtering
	exportDB(dstMap,exportFilter) - export to database with optional filtering
	completeWayNodes(bigMap) - import from 'bigMap' nodes which used in 'map' ways.
		Returns array of not found nodes ids. If all nodes found in 'bigMap' then empty array returned
	completeRelationNodes(bigMap) - import from 'bigMap' nodes which used in 'map' relations.
		Returns array of not found nodes ids. If all nodes found in 'bigMap' then empty array returned
	completeRelationWays=function(bigMap) - import from 'bigMap' ways which used in 'map' relations.
		Returns array of not found ways ids. If all ways found in 'bigMap' then empty array returned
	completeRelationRelations(bigMap) - import from 'bigMap' relations which used in 'map' relations.
		Returns array of not found relations ids. If all relations found in 'bigMap' then empty array returned
	wayToNodeArray(wayOrWayId) - see GeoTools.wayToNodeArray
	getNextNodeId() - get next available node id. result<0.
	getNextWayId() - get next available way id. result<0.
	getNextRelationId() - get next available relation id. result<0.
	exec(sqlStr) - execute sql statement
	map - OSMan object
*/

function MapHelper(hlpRef){
	this.h=hlpRef;
	this.map=false;
};

MapHelper.prototype.open=function(dbName,forceReCreate,readOnly){
	var t=this,h=t.h,m=h.man;
	if(t.map)t.close();
	var alreadyExists=h.fso.fileExists(dbName);
	if(alreadyExists && forceReCreate){
		h.fso.deleteFile(dbName);
		alreadyExists=false;
	};
	var stg=m.createObject(h.defaultStorage);
	stg.readOnly=!!readOnly;
	stg.dbName=dbName;
	if(!alreadyExists)stg.initSchema();
	t.map=m.createObject(h.defaultMap);
	t.map.storage=stg;
};

MapHelper.prototype.close=function(){
	var t=this;
	if(!t.map)return;
	var stg=t.map.storage;
	t.map.storage=false;
	t.map=false;
	stg.dbName='';
};

MapHelper.prototype.importXML=function(xmlName){
	var t=this,h=t.h,m=h.man;
	var ext=h.fso.getExtensionName(xmlName);
	var ds=0;
	switch(ext){
		case 'bz2':
			ds=m.createObject('UnBZ2');
			break;
		case 'gz':
			ds=m.createObject('UnGZ');
			break;
	};
	var fs=m.createObject('FileReader');
	fs.open(xmlName);
	if (ds) {
		ds.setInputStream(fs);
	}else{
		ds=fs;
	};
	var osmr=m.createObject('OSMReader');
	osmr.setInputStream(ds);
	osmr.setOutputMap(t.map);
	osmr.read(0);
	fs.open('');
	fs=ds=osmr=0;
};

MapHelper.prototype.exportXML=function(dstFileName,exportFilter){
	var t=this,m=t.h.man;
	var fw=m.createObject('FileWriter');
	fw.open(dstFileName);
	var ow=m.createObject('OSMWriter');
	ow.setOutputStream(fw);
	ow.setInputMap(t.map);
	ow.write(exportFilter?(exportFilter):(''));
};

MapHelper.prototype.exportDB=function(dstMap,exportFilter){
	var m=this.map;
	var ss=m.getObjects(exportFilter?(exportFilter):(''));
	while(!ss.eos){
		var obj=ss.read(1000).toArray();
		for(var i=0;i<obj.length;i++){
			dstMap.putObject(obj[i]);
		};
	};
};

MapHelper.prototype.completeWayNodes=function(bigMap){
	//medium select distinct nodeid from waynodes where not exists( select id from nodes where waynodes.nodeid=nodes.id)
	// 800ms	15200ms
	//fast select distinct nodeid from waynodes where nodeid not in (select id from nodes)
	// 600ms	12900ms
	var m=this.map;
	var rs=[];
	var nidl=m.storage.sqlPrepare('select distinct nodeid from waynodes where nodeid not in (select id from nodes)');
	nidl=m.storage.sqlExec(nidl,0,0);
	while(!nidl.eos){
		var nid=nidl.read(1).toArray()[0];
		var n=bigMap.getNode(nid);
		if(!n)rs.push(nid);else m.putObject(n);
	};
	return rs;
};

MapHelper.prototype.completeRelationNodes=function(bigMap){
	var m=this.map;
	var rs=[];
	var nidl=m.storage.sqlPrepare("select distinct(memberid) from relationmembers where memberidxtype&3=0  and (memberid not in (select id from nodes))");
	nidl=m.storage.sqlExec(nidl,0,0);
	while(!nidl.eos){
		var nid=nidl.read(1).toArray()[0];
		var n=bigMap.getNode(nid);
		if(!n)rs.push(nid);else m.putObject(n);
	};
	return rs;
};

MapHelper.prototype.completeRelationWays=function(bigMap){
	var m=this.map;
	var rs=[];
	var nidl=m.storage.sqlPrepare("select memberid from relationmembers where memberidxtype&3=1  and (memberid not in (select id from ways))");
	nidl=m.storage.sqlExec(nidl,0,0);
	while(!nidl.eos){
		var nid=nidl.read(1).toArray()[0];
		var n=bigMap.getWay(nid);
		if(!n)rs.push(nid);else m.putObject(n);
	};
	return rs;
};

MapHelper.prototype.completeRelationRelations=function(bigMap){
	var m=this.map;
	var rs=[];
	var nidl=m.storage.sqlPrepare("select memberid from relationmembers where memberidxtype&3=2  and (memberid not in (select id from relations))");
	nidl=m.storage.sqlExec(nidl,0,0);
	while(!nidl.eos){
		var nid=nidl.read(1).toArray()[0];
		var n=bigMap.getRelation(nid);
		if(!n)rs.push(nid);else m.putObject(n);
	};
	return rs;
};

MapHelper.prototype.wayToNodeArray=function(wayOrWayId){
	var t=this;
	return t.h.gt.wayToNodeArray(t.map,wayOrWayId);
};

MapHelper.prototype.exec=function(sqlStr){
	var stg=this.map.storage;
	var qry=stg.sqlPrepare(sqlStr);
	return stg.sqlExec(qry,'','');
};

MapHelper.prototype.getNextNodeId=function(){
	var rslt=this.exec('select min(id) from nodes;')
	if(rslt.eos)return -1;
	return Math.min(0,rslt.read(1).toArray()[0])-1;
};

MapHelper.prototype.getNextWayId=function(){
	var rslt=this.exec('select min(id) from ways;');
	if(rslt.eos)return -1;
	return Math.min(0,rslt.read(1).toArray()[0])-1;
};

MapHelper.prototype.getNextRelationId=function(){
	var rslt=this.exec('select min(id) from relations;');
	if(rslt.eos)return -1;
	return Math.min(0,rslt.read(1).toArray()[0])-1;
};

function Hlp(){
	var t=this;
	t.man=WScript.createObject('OSMan.Application');
	t.gt=t.man.createObject('GeoTools');
	t.fso=WScript.CreateObject('Scripting.FileSystemObject');
	t.defaultStorage='Storage';
	t.defaultMap='Map';
};

Hlp.prototype.mapHelper=function(){
	return (new MapHelper(this));
};

Hlp.prototype.echo=function(s,noLF,noCR){
	WScript.stdOut.write(s+(noCR?(''):('\r'))+(noLF?(''):('\n')));
};

Hlp;