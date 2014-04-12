/*
globals:
	noHostCheck - if true then ScriptHost windowness and bitness are not checked.
		if false then script restarted in 32bit console host.
Hlp members:
	man - OSMan application
	gt - OSMan GeoTools module
	fso - filesystem object
	defaultStorage - default storage class name ('Storage')
	defaultMap - default map class name ('Map');
	bindFunc(obj,func,staticArguments) - bind function func to object obj with optional static arguments. Usage example:
		f=bindFunc(myObj,myFunc,'test',1);
		.....
		f('tree',2) - equivalent with myObj.myFunc('test',1,'tree',2)
	dumpMapObject(mapObj) - returns array of string with all map object properties
	echo(msg,noLF,noCR) - write msg to stdout. Without line feed and carriage return if needed.
	echot(msg,noLF,noCR) - write msg with timestamp to stdout. Without line feed and carriage return if needed.
	indexOf(arr,elm) - returns index of element `elm` in array `arr`. If element not found then -1 returned.
	mapHelper() - create MapHelper object
	getMultiPoly(refs,srcMaps,backupMap) - get Multipoly from multiple sources or from backup. Updates backup if necessary.
		returns object{poly,usedMap,notFoundRefs,notClosedRefs}
			poly - MuliPoly object if refs is valid multipolygon, <false> if all sources and even backup failed
			usedMap - map object used for multipolygon resolution. If all map failed to resolve then false returned.
			notFoundRefs - array of strings with not found objects references. On success it is empty array. Example:
				['node:12','way:11']
			notClosedRefs - array of string with not-closed objects references. On success it is empty array. Example:
				['node:1','node:10']
		refs - string or array of strings with references to multipoly members. Example:
			'relation:11'
			['way:10','way:22']
		srcMaps - map or array of maps used for multipolygon resolving.
		backupMap - map used for multipolygon resolving if srcMaps failed. backupMap
			updated with successfully resolved multipolygon objects.
	polyIntersector(srcMapHelper,dstMapHelper,boundMultiPoly) - create PolyIntersector object

MapHelper members:
	open(dbName,forceReCreate,readOnly) - open file dbName using class names from Hlp.
	close() - close map and storage
	importXML(xmlName) - import XML (OSM or OSC) file. BZ2 and GZ compression supported.
	exportXML(dstFileName,exportFilter) - export to osm-file with optional filtering
	exportDB(dstMap,exportFilter) - export to database with optional filtering
	exportRecurcive(dstMap,refs) - export all referenced objects and all children recurcively.
		Not found objects silently skipped.
		dstMap - map for exporting objects
		refs - array of object reference strings or comma separated reference string . Example:
			['way:1','node:11','relation:111']
			'way:1,node:11,relation:111'
	exportMultiPoly(dstMap,refs) - same as exportRecurcive, but skips all "non-polygon" members of relations.
		This function doesn`t check polygon consistency and integrity, but do not export duplicated ways.
	completeWayNodes(bigMap) - import from 'bigMap' nodes which used in 'map' ways.
		Returns array of not found nodes ids. If all nodes found in 'bigMap' then empty array returned
	completeRelationNodes(bigMap) - import from 'bigMap' nodes which used in 'map' relations.
		Returns array of not found nodes ids. If all nodes found in 'bigMap' then empty array returned
	completeRelationWays - import from 'bigMap' ways which used in 'map' relations.
		Returns array of not found ways ids. If all ways found in 'bigMap' then empty array returned
	completeRelationRelations(bigMap) - import from 'bigMap' relations which used in 'map' relations.
		Returns array of not found relations ids. If all relations found in 'bigMap' then empty array returned
	exec(sqlStr,params,values) - execute sql statement with optional parameters and values.
		Returns IQueryResult object.
	findOrStore(newNode,tagPolicy) - find node on map with same coords and returns it. If no node in this coords
		then newNode stored and returned.
		newNode - node to find-store operation
		tagPolicy - applied if node found in this coords
			0(default) - tags merged and stored
			1 - new tags replaced with old
			2 - old tags replaced with new
	fixIncompleteRelations() - remove from relations members all members, which are not in map. If result relation has no members it removed from map too.
	fixIncompleteWays() - remove from ways all nodes which are not in map. If result way has less then two nodes it removed from map too.
	getNextNodeId() - get next available node id. result<0.
	getNextWayId() - get next available way id. result<0.
	getNextRelationId() - get next available relation id. result<0.
	getObject(strObj) - get object from map. If no object found return false.
		strObj - string of Type and Id delimited by ':'. Example:
			'node:123' - get Node with Id=123
			'way:456' - get Way with Id=456
			'relation:789' - get Relation with Id=789
	getObjectChildren(obj,notFoundPolicy) - returns 1-dimensional array of objects, used by `obj`. For Way it will be composing Nodes, for Relation its members, for Node - [].
		obj - object for children search.
		notFoundPolicy:
			empty or 0 - return only found chilren. Example: [obj1,obj2]
			1 - return string reference instead of not found object. Example: [obj1,'node:188','way:545','relation:7',obj2]
			2 - return false instead of not found object.Example: [obj1,false,false,false,obj2]
			3 - return only not found children references. Example: ['node:188','way:545','relation:7']
	h - Hlp object
	map - OSMan object
	renumberNewObjects() - assign positive id for all objects with negative id. All references to renumbered objects updated.
	replaceObject(oldObject,newObjects){
		//replaces all `oldObject`s on map with `newObject`s.
		//newObjects is array of object of same class. It can be empty. If so then oldObject and all references to it deleted from map.
		//If after replacement we have empty(no members) relation or too short (one or zero nodes) way then such empty objects deleted recurcively.
	wayToNodeArray(wayOrWayId) - see GeoTools.wayToNodeArray
	
PolyIntersector members:
	buildWayList(relation,objOrId) - convert Relation into one-dimension Way objects or Way ID array.
		objOrId - optional argument. If skipped then false assumed.
			if it is true then array of ids returned.
			if it is false then array of Way objects returned with 'osman:parent' tag filled with parent relation id.
		Subrelations recursively proccessed too. 'Subarea' relations skipped.
		If some way or subrelation missed in map then empty array returned.
		Duplicated ways eliminated from output.
	buildNodeListArray(wayList) - returns 2-dimensional NodeList=[[way1 nodes],[way2 nodes]...]
		'osman:parent' tag filled with parent way id
		wayList - 1-dimensional Way objects array [Way1,Way2....]. This array can be a buildWayList function result.
	clearParents(intersection) - deletes 'osman:parent' tag from all nodes.
		intersection - 2-dimensional array of nodes with 'osman:parent' tag.
		Call this function to prevent side effects for common nodes of boundary poly and several intersecting multipolygons.
	mergeNodeLists(nodeList) - convert two-dimensional Nodes array  into 1-dimensional polygon list.
		nodeList - 2-dimesional Node objects array. It can be buildNodeListArray function result.
		'osman:parent' tag for common nodes are merged. [n1(parent:1), n2(parent:1)],[n2(parent:2), n3(parent:2)] => [n1(parent:1), n2(parent:1;2), n3(parent:2)]
		Example: [[1,2],[2,3],[3,1],[5,6,7,5]] => [[1,2,3,1],[5,6,7,5]]
		If any polygon not closed then <false> returned.
	mergeWayList(wayList) - convert one-dimensional Way array into one-dimensional array of cluster objects.
		All polygon clusters are at beginning of the array and linear(non-closed) clusters are at end.
		cluster object is {id1,idn,ways} where:
			id1 - id of first node in cluster
			idn - id of last node in cluster. For closed polygon idn==id1
			ways - array of way objects for this cluster.
	findNodeParents(intersection,nodeLists) - replaces every node in intersection with object{node,parent} where node is Node object from original intersection and parent is array of parent way Ids. Tag 'osman:parent' deleted from all nodes. Returns true if all nodes processed sucessfully.
		intersection - 2-dimensional array of nodes with 'osman:parent' tag. It can be result of MultiPoly.getIntersection() function.
		nodeLists - 2-dimensional array of nodes with 'osman:parent' tag. This argument represents original multipoly.
			This argument used if parents can`t be determined using only intersection argument. This argument is optional.
	parseParents(obj) - convert string value of 'osman:parent' tag of object `obj` into numeric array or `false`. Example:
		'osman:parent=12' => [12];
		'osman:parent=1;2' => [1,2];
		'osman:parent=apple' => false;
		'osman:parent=' => false;
	waysFromNodeLists(intersection,processingWayIds,nextWayId) - returns array of arrays of way Objects as follows:
		intersection[a,b,c]=>[[a_way1,a_way2],[b_way],[]]
		modifies processingWayIds. Returned array of wayIds which are in processingWayIds, but not used in resulting 'ways'
		If new way requred, then it created via dstMap.createNode(), new Id is dstMap.getNextWayId() or nextWayId argument
		nextWayId is optional. Use it for speedup (avoid getNextWayId()) call.
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
	var t=this,m=t.h.man,ow;
	var fw=m.createObject('FileWriter');
	fw.open(dstFileName);
	if(exportFilter){
		ow=m.createObject('OSMWriter');
	}else{
		exportFilter='';
		ow=m.createObject('FastOSMWriter');
	};
	ow.setOutputStream(fw);
	ow.setInputMap(t.map);
	ow.write(exportFilter);
};

MapHelper.prototype.exportDB=function(dstMap,exportFilter){
	var m=this.map;
	//var ncnt=0,wcnt=0,rcnt=0;
	var ss=m.getObjects(exportFilter?(exportFilter):(''));
	while(!ss.eos){
		var obj=ss.read(1000).toArray();
		for(var i=0;i<obj.length;i++){
			dstMap.putObject(obj[i]);
			//(obj[i].getClassName()=='Node')?(ncnt++):((obj[i].getClassName=='Way')?(wcnt++):(rcnt++));
		};
		//this.h.echo('n='+ncnt+' w='+wcnt+' r='+rcnt,true);
	};
	//this.h.echo('');
};

MapHelper.prototype.exportMultiPoly=function(dstMap,refs){
	var t=this,h=t.h,c=t.h.polyIntersector(t,t,false);
	function saveSub(rel){
		var rm=rel.members.getAll().toArray();
		for(var i=0;i<rm.length;i+=3){
			if((rm[i]=='relation')&&(h.indexOf(['','outer','inner','enclave','exclave'],rm[i+2])>=0)){
				//process subrelations
				rel=t.map.getRelation(rm[i+1]);
				if(!rel || !saveSub(rel)) return false;
			};
		};
		return true;
	};
	var rel=t.map.createRelation();
	if(typeof(refs)=='string')refs=refs.split(',');
	for(var i=0;i<refs.length;i++){
		var robj=t.getObject(refs[i]);
		if(!robj) return false;
		if(robj.getClassName()=='Node')continue;
		dstMap.putObject(robj);
		if(robj.getClassName()=='Relation'){
			if(!saveSub(robj))return false;
		}
		rel.members.insertBefore(0,robj.getClassName().toLowerCase(),robj.id,'');
	};
	var widl=c.buildWayList(rel,true), i;
	for(i=widl.length-1; i>=0; i--){
		widl[i]='way:'+widl[i];
	}
	t.exportRecurcive(dstMap,widl);
	return true;
};

MapHelper.prototype.exportRecurcive=function(dstMap,refs){
	var q=[],t=this;
	if(typeof(refs)=='string')refs=refs.split(',');
	for(var i=0;i<refs.length;i++){
		var o=t.getObject(refs[i]);
		if(o)q.push(o);
	};
	while(q.length>0){
		var obj=q.pop();
		if(obj.getClassName()!='Node')q=q.concat(t.getObjectChildren(obj));
		dstMap.putObject(obj);
	};
};

MapHelper.prototype.completeWayNodes=function(bigMap){
	//medium select distinct nodeid from waynodes where not exists( select id from nodes where waynodes.nodeid=nodes.id)
	// 800ms	15200ms
	//fast select distinct nodeid from waynodes where nodeid not in (select id from nodes)
	// 600ms	12900ms
	var m=this.map;
	var rs=[];
	var nidl=this.exec('select distinct nodeid from waynodes where nodeid not in (select id from nodes_attr)');
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
	var nidl=this.exec("select distinct(memberid) from relationmembers where memberidxtype&3=0 and (memberid not in (select id from nodes_attr))");
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
	var nidl=this.exec("select memberid from relationmembers where memberidxtype&3=1  and (memberid not in (select id from ways))");
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
	var nidl=this.exec("select memberid from relationmembers where memberidxtype&3=2  and (memberid not in (select id from relations))");
	while(!nidl.eos){
		var nid=nidl.read(1).toArray()[0];
		var n=bigMap.getRelation(nid);
		if(!n)rs.push(nid);else m.putObject(n);
	};
	return rs;
};

MapHelper.prototype.findOrStore=function(newNode,tagPolicy){
	var t=this,q=t.qFindOrStore,m=t.map,s=m.storage;
	if(!q){
		q=s.sqlPrepare('SELECT id FROM nodes WHERE lat=round(:lat*1e7) AND lon=round(:lon*1e7)');
		t.qFindOrStore=q;
	};
	q=s.sqlExec(q,[':lat',':lon'],[newNode.lat,newNode.lon]).read(1).toArray();
	if(q.length){
		//dbg echo('node found at lat='+newNode.lat+' lon='+newNode.lon);
		var oldNode=m.getNode(q[0]),storeNode=false;
		tagPolicy=tagPolicy||0;
		switch(tagPolicy){
		case 0:
			for(var i=0;i<newNode.tags.count-1;i++){
				oldNode.tags.setByKey(newNode.tags.getKey(i),newNode.tags.getValue(i));
				storeNode=true;
			};
		case 1:
			break;
		case 2:
			oldNode.tags.setAll(newNode.tags.getAll());
			storeNode=true;
			break;
		};
		m.putNode(oldNode);
		return oldNode;
	}else{
		//dbg echo('node not found at lat='+newNode.lat+' lon='+newNode.lon);
		m.putNode(newNode);
		return newNode;
	};
}

MapHelper.prototype.fixIncompleteRelations=function(){
	var t=this,m=t.map,sil=m.storage.createIdList();
	t.exec('INSERT OR IGNORE INTO '+sil.tableName+'(id) SELECT memberid FROM relationmembers WHERE memberidxtype&3=0 AND memberid NOT IN (SELECT id FROM nodes_attr)');
	t.exec('DELETE FROM relationmembers WHERE memberidxtype&3=0 AND memberid IN (SELECT id FROM '+sil.tableName+')');

	t.exec('DELETE FROM '+sil.tableName);
	t.exec('INSERT OR IGNORE INTO '+sil.tableName+'(id) SELECT memberid FROM relationmembers WHERE memberid NOT IN (SELECT id FROM ways) AND memberidxtype&3=1');
	t.exec('DELETE FROM relationmembers WHERE memberidxtype&3=1 AND memberid IN (SELECT id FROM '+sil.tableName+')');

	t.exec('DELETE FROM '+sil.tableName);
	t.exec('INSERT OR IGNORE INTO '+sil.tableName+'(id) SELECT memberid FROM relationmembers WHERE memberidxtype&3=2 and memberid NOT IN (SELECT id FROM relations)');
	t.exec('DELETE FROM relationmembers WHERE memberidxtype&3=2 AND memberid IN (SELECT id FROM '+sil.tableName+')');
	
	t.exec('DELETE FROM '+sil.tableName);
	
	t.exec('INSERT INTO '+sil.tableName+'(id) SELECT id FROM relations WHERE (SELECT ((MAX(memberidxtype)>>2)+1) FROM relationmembers WHERE relationid=relations.id)<>(SELECT COUNT(1) FROM relationmembers WHERE relationid=relations.id)');
	t.exec('INSERT OR IGNORE INTO '+sil.tableName+'(id) SELECT id FROM relations WHERE id NOT IN (SELECT relationid FROM relationmembers)');
	var ril=t.exec('SELECT id FROM '+sil.tableName);
	while(!ril.eos){
		var ids=ril.read(1000).toArray();
		for(var i=0;i<ids.length;i++){
			var r=m.getRelation(ids[i]);
			if(!r)continue;
			if(r.members.count>0){
				m.putRelation(r);
			}else{
				t.replaceObject(r,[]);
			};
		};
	};
};

MapHelper.prototype.fixIncompleteWays=function(){
	var t=this,m=t.map,sil=m.storage.createIdList();
	t.exec('INSERT OR IGNORE INTO '+sil.tableName+'(id) SELECT wayid FROM waynodes WHERE nodeid NOT IN (SELECT id FROM nodes_attr)');
	t.exec('DELETE FROM waynodes WHERE nodeid IN (SELECT id FROM '+sil.tableName+')');

	t.exec('DELETE FROM '+sil.tableName);
	
	t.exec('INSERT INTO '+sil.tableName+'(id) SELECT id FROM ways WHERE (SELECT (MAX(nodeidx)+1) FROM waynodes WHERE wayid=id)<>(SELECT COUNT(1) FROM waynodes WHERE wayid=id)');
	var ril=t.exec('SELECT id FROM '+sil.tableName);
	while(!ril.eos){
		var ids=ril.read(1000).toArray();
		for(var i=0;i<ids.length;i++){
			var r=m.getWay(ids[i]);
			if(!r)continue;
			if(r.nodes.toArray().length>1){
				m.putWay(r);
			}else{
				t.replaceObject(r,[]);
			};
		};
	};
};

MapHelper.prototype.renumberNewObjects=function(){
	var t=this,q=t.exec('SELECT max(id) FROM nodes_attr');
	q=q.read(1).toArray()[0];
	if(q<0)q=0;
	var u=t.exec('SELECT min(id) FROM users');
	u=u.read(1).toArray()[0];
	//renumber nodes
	t.exec('UPDATE nodes SET version=1,timestamp=20000101000000,userId='+u+',changeset=1,id='+q+'-id WHERE id<=0');
	t.exec('UPDATE waynodes SET nodeid='+q+'-nodeid WHERE nodeid<=0');
	t.exec('UPDATE relationmembers SET memberid='+q+'-memberid WHERE (memberid<=0) AND (memberidxtype&3=0)');
	//renumber ways
	var q=t.exec('SELECT max(id) FROM ways');
	q=q.read(1).toArray()[0];
	if(q<0)q=0;
	t.exec('UPDATE ways SET version=1,timestamp=20000101000000,userId='+u+',changeset=1,id='+q+'-id WHERE id<=0');
	t.exec('UPDATE relationmembers SET memberid='+q+'-memberid WHERE (memberid<=0) AND (memberidxtype&3=1)');
	//renumber relations
	q=t.exec('SELECT max(id) FROM relations');
	q=q.read(1).toArray()[0];
	if(q<0)q=0;
	t.exec('UPDATE relations SET version=1,timestamp=20000101000000,userId='+u+',changeset=1,id='+q+'-id WHERE id<=0');
	t.exec('UPDATE relationmembers SET memberid='+q+'-memberid WHERE (memberid<=0) AND (memberidxtype&3=2)');
};

MapHelper.prototype.replaceObject=function(oldObject,newObjects){
	//replaces all `oldObject`s on map with `newObject`s.
	//newObjects is array of object of same class. It can be empty. If so then oldObject just deleted from map and from any dependent object.
	//If after replacement we have empty(no members) relation or too short (one or zero nodes) way then such empty objects deleted recurcively.
	var t=this,m=t.map,echo=t.h.echo;
	function getObjIntType(obj){
		//returns 0 for Nodes, 1 for Ways ,2 for Relations and -1 for other classes
		switch(obj.getClassName()){
		case 'Node':return 0;
		case 'Way':return 1;
		case 'Relation':return 2;
		};
		return -1;
	};
	function getObjStrType(objIntType){
		switch(objIntType){
			case 0:return 'node';
			case 1:return 'way';
			case 2:return 'relation';
			default:return '';
		}
	};
	function replaceInRelation(oldObj,oldObjIntType,newObjs){
		if(!t.qDepRels){
			t.qDepRels=m.storage.sqlPrepare('SELECT distinct(relationid) FROM relationmembers WHERE memberid=:id AND memberidxtype&3=:objtype');
		};
		var oldId=oldObject.id,oldObjStrType=getObjStrType(oldObjIntType);
		var relList=m.storage.sqlExec(t.qDepRels,[':id',':objtype'],[oldId,oldObjIntType]),killRelList=[];
		while(!relList.eos){
			var id=relList.read(1).toArray()[0];
			var rel=m.getRelation(id);
			if(!rel)continue;
			var mbrs=rel.members.getAll().toArray(),newmbrs=[];
			for(var i=0;i<mbrs.length;i+=3){
				if((mbrs[i+1]==oldId)&&(mbrs[i]==oldObjStrType)){
					for(var j=0;j<newObjs.length;j++)newmbrs.push(oldObjStrType,newObjs[j].id,mbrs[i+2]);
				}else{
					newmbrs.push(mbrs[i],mbrs[i+1],mbrs[i+2]);
				};
			};
			rel.members.setAll(newmbrs);
			m.putRelation(rel);
			if(newmbrs.length==0)killRelList.push(rel);
			//dbg echo('		Replace in relation['+rel.id+']. Old len='+(mbrs.length/3)+' new len='+(newmbrs.length/3));
		};
		for(var i=0;i<killRelList.length;i++)t.replaceObject(killRelList[i],[]);
	};
	function replaceInWay(oldObj,newObjs){
		if(!t.qDepWays){
			t.qDepWays=m.storage.sqlPrepare('SELECT distinct(wayid) FROM waynodes WHERE nodeid=:id');
		}
		var oldId=oldObject.id;
		var wayList=m.storage.sqlExec(t.qDepWays,':id',oldId),killWayList=[];
		while(!wayList.eos){
			var way=m.getWay(wayList.read(1).toArray()[0]);
			if(!way)continue;
			var nodes=way.nodes.toArray(),newnodes=[];
			for(var i=0;i<nodes.length;i++){
				if(nodes[i]==oldId){
					for(var j=0;j<newObjs.length;j++)newnodes.push(newObjs[j].id);
				}else{
					newnodes.push(nodes[i]);
				};
			};
			way.nodes=newnodes;
			m.putWay(way);
			if(newnodes.length<2)killWayList.push(way);
			//dbg echo('Replace in way['+way.id+']. Old len='+nodes.length+' new len='+newnodes.length);
		};
		for(var i=0;i<killWayList.length;i++)t.replaceObject(killWayList[i],[]);
	};
	var objIntType=getObjIntType(oldObject);
	//dbg echo('	Replace object['+oldObject.id+'] with [',true,true);for(var i=0;i<newObjects.length;i++)echo(((i>0)?(','):(''))+newObjects[i].id,true,true);echo(']');
	if(objIntType<0)throw {name:'MapHelper',description:'Invalid object. ClassName='+oldObject.getClassName()};
	for(var i=0;i<newObjects.length;i++)if(getObjIntType(newObjects[i])!=objIntType) throw {name:'MapHelper',description:'Can`t replace '+oldObject.getClassName()+' with '+newObjects[i].getClassName()};
	replaceInRelation(oldObject,objIntType,newObjects);
	switch(objIntType){
		case 0:replaceInWay(oldObject,newObjects);
			//dbg t.h.echo('		replaceObject. Delete node['+oldObject.id+']');
			m.deleteNode(oldObject.id);
			break;
		case 1:m.deleteWay(oldObject.id);
			//dbg echo('		replaceObject. Delete way['+oldObject.id+']');
			break;
		case 2:m.deleteRelation(oldObject.id);
			break;
	};
	for(var i=0;i<newObjects.length;i++){
		//dbg echo('		replaceObject. Store object['+newObjects[i].id+']');
		m.putObject(newObjects[i]);
	};
};

MapHelper.prototype.wayToNodeArray=function(wayOrWayId){
	var t=this;
	return t.h.gt.wayToNodeArray(t.map,wayOrWayId);
};

MapHelper.prototype.getObject=function(strObj){
	var funcName='helpers.MapHelper.getObject: ';
	var t=this;
	if(!t.map)throw {name:'MapHelper',description:funcName+'no map opened'};
	strObj=strObj.split(':');
	if((strObj.length!=2))throw {name:'MapHelper',description:funcName+'invalid object specifier='+strObj};
	var objId=parseFloat(strObj[1]);
	if(isNaN(objId))throw {name:'MapHelper',description:funcName+'invalid object id='+strObj[1]};
	switch(strObj[0]){
	case 'node':
		return t.map.getNode(objId);
		break;
	case 'way':
		return t.map.getWay(objId);
		break;
	case 'relation':
		return t.map.getRelation(objId);
		break;
	default:
		throw {name:'MapHelper',description:funcName+'invalid object type='+strObj[0]};
		break;
	};
};

MapHelper.prototype.getObjectChildren=function(obj,policy){
	var t=this,m=t.map,r=[],fn='MapHelper.getObjectChildren: ';
	function applyPolicy(o,t,i){
		switch(policy){
		case 0:
			if(o)r.push(o);
			break;
		case 1:
			if(o)r.push(o);else r.push(t+':'+i);
			break;
		case 2:
			r.push(o);
			break;
		case 3:
			if(!o)r.push(t+':'+i);
			break;
		default:
			throw {name:'MapHelper',description:fn+'invalid policy <'+policy+'>'};
		};
	};
	policy=(policy)?(policy):(0);
	switch(obj.getClassName()){
	case 'Node':
		break;
	case 'Way':
		var nids=obj.nodes.toArray();
		for(var i=0;i<nids.length;i++){
			var id=nids[i];
			applyPolicy(m.getNode(id),'node',id);
		};
		break;
	case 'Relation':
		var mbrs=obj.members.getAll().toArray();
		for(var i=0;i<mbrs.length;i+=3){
			var id=mbrs[i+1],typ=mbrs[i];
			applyPolicy(t.getObject(typ+':'+id),typ,id);
		};
		break;
	default:
		throw {name:'MapHelper',description:fn+'invalid object class <'+obj.getClassName+'>'};
	};
	return r;
};

MapHelper.prototype.exec=function(sqlStr,params,values){
	var stg=this.map.storage;
	var qry=stg.sqlPrepare(sqlStr);
	return stg.sqlExec(qry,params||'',values||'');
};

MapHelper.prototype.getNextNodeId=function(){
	var rslt=this.exec('select min(id) from nodes_attr')
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

function PolyIntersector(hlpRef,srcMapHelper,dstMapHelper,boundMultiPoly){
	var t=this;
	t.srcMapHelper=srcMapHelper;
	t.dstMapHelper=dstMapHelper;
	t.bPoly=boundMultiPoly;
	t.h=hlpRef;
};

PolyIntersector.prototype.buildWayList=function(relation,objOrId){
	//convert Relation into one-dimension Way object array.
	//Subrelations recursively proccessed too.
	//If some way or subrelation missed in map then empty array returned
	var t=this,map=t.srcMapHelper.map,echo=t.h.echo;
	function getRaw(r){
		var rs=[],rm=r.members.getAll().toArray();
		for(var i=0;i<rm.length;i+=3){
			//skip nodes - they not processed at all
			if(rm[i]=='way'){
				//process way
				var way;
				if(objOrId){
					way=rm[i+1];
				}else{
					way=map.getWay(rm[i+1]);
					if(!way){
							echo('Relation '+r.id+' missed way '+rm[i+1]);
							return [];
					};
					way.tags.setByKey('osman:parent',r.id);
				};
				rs.push(way);
			}else if((rm[i]=='relation')&&(t.h.indexOf(['','outer','inner','enclave','exclave'],rm[i+2])>=0)){
				//process subrelations
				var sr=map.getRelation(rm[i+1]);
				if(!sr){
					echo('Relation '+r.id+' missed relation '+rm[i+1]);
					return [];
				}else{
					var st=sr.tags.getByKey('type');
					if((st!='multipolygon')&&(st!='boundary')){
						//dbg echo('	relation '+(rm[i+1])+' of type '+st+' skipped');
						continue;
					}
					sr=getRaw(sr);
					if(!sr.length)return [];
					rs=rs.concat(sr);
				}
			}
		};
		return rs;
	};
	var rs=getRaw(relation),cf=(objOrId)?(function(a,b){return (a-b)}):(function(a,b){return (a.id-b.id)});
	//do duplicate test & removal.
	rs.sort(cf);
	for(var i=rs.length-1;i>0;i--){
		if(!cf(rs[i],rs[i-1])){
			i--;
			rs.splice(i,2);
		};
	};
	return rs;
};

PolyIntersector.prototype.buildNodeListArray=function (wayList){
	//wayList - 1-dimensional Way object list[Way1,Way2....]
	//returns 2-dimensional NodeList=[[way1 nodes],[way2 nodes]...]
	var rs=[],t=this;
	for(var i=0;i<wayList.length;i++){
		var na=t.h.gt.wayToNodeArray(t.srcMapHelper.map,wayList[i]).toArray();
		rs.push(na);
		for(var ni=0;ni<na.length;ni++){
			na[ni].tags.setByKey('osman:parent',wayList[i].id);
		};
	};
	return rs;
};

PolyIntersector.prototype.clearParents=function (multiPolyNodes){
	for(var i=0;i<multiPolyNodes.length;i++){
		var pn=multiPolyNodes[i];
		for(var j=0;j<pn.length;j++){
			pn[j].tags.deleteByKey('osman:parent');
		};
	};
};

PolyIntersector.prototype.findNodeParents=function(intersection,nodeLists){
	var resultValid=true,t=this,echo=t.h.echo,indexOf=t.h.indexOf;
	function findUsingNodeLists(poly){
		var curNode,gt=t.h.gt;
		//dbg echo('using node list');
		for(var i=0;i<poly.length;i++){
			curNode=poly[i];
			if(!curNode.parent.length)break;
		};
		if(!curNode)return false;
		var minDist=Number.MAX_VALUE,minIdx=[];
		for(var i=0;i<nodeLists.length;i++){
			var pp=nodeLists[i];
			for(var j=1;j<pp.length;j++){
				if(!pp[j].tags.getByKey('osman:parent'))continue;
				var d=gt.distance(curNode.node,[pp[j-1],pp[j]]);
				if(d<minDist){
					minIdx=[i,j];
					minDist=d;
					if(minDist==0)break;
				};
			};
			if(minDist==0)break;
		};
		if(minDist<Number.MAX_VALUE){
			curNode.parent=t.parseParents(nodeLists[minIdx[0]][minIdx[1]])||[];
			//dbg echo('minDist='+minDist.toFixed(2)+' node id='+nodeLists[minIdx[0]][minIdx[1]].id+' parents='+nodeLists[minIdx[0]][minIdx[1]].tags.getByKey('osman:parent'));
		return true;
		}else{
			return false;
		};
	};
	//dbg echo('findNodeParents');
	//convert 'osman:parent' tag into 'parents' property of node
	for(var j=0;j<intersection.length;j++){
		var ij=intersection[j];
		for(var i=0;i<ij.length;i++){
			ij[i]={parent:t.parseParents(ij[i])||[],node:ij[i]};
		};
	}
	for(var j=0;(j<intersection.length)&&resultValid;j++){
		//check all sub-poly
		var curWayId=[], hasChanges=2,hasAmbiguities, step=-1;
		//dbg echo(' process '+j+'-th intersection');
		do{
			hasChanges--;
			hasAmbiguities=false;
			step=-step;
			for(var k=(step==1)?(0):(intersection[j].length-1), icnt=0;icnt<intersection[j].length;k+=step, icnt++){
				//find parent way for nodes.
				var curNode=intersection[j][k],isEndNode=(k==0)||(k==intersection[j].length-1);
				var parents=curNode.parent;
				//dbg echo('['+j+'.'+k+'] id='+curNode.node.id+' pnts(l='+parents.length+')='+parents);
				switch(curWayId.length){
					case 0:
						if(parents.length){
							curWayId=parents;
						}else{
							//dbg echo('ambigous 4');
							hasAmbiguities=true;
						}
						break;
					case 1:
						switch(parents.length){
							case 0://single curWayId, no parent => assign curWayId to parent
								curNode.parent=[curWayId[0]];
								hasChanges=2;
								break;
							case 1://single curWayId, single parent
								if(curWayId[0]!=parents[0]){
									//common point for curWayId and parent
									curNode.parent=[curWayId[0],parents[0]];
									curWayId=parents;
									hasChanges=2;
								};
								break;
							case 2://single curWayId, dual parents
								if(isEndNode){
									curNode.parent=curWayId;
									hasChanges=2;
								}else if(curWayId[0]==parents[0]){
									//(way1),(way1,way2)
									curWayId=[parents[1]];
								}else if(curWayId[0]==parents[1]){
									//(way1),(way2,way1)
									curWayId=[parents[0]];
								}else{
									//(way1),(way2,way3)
									var nextNode=intersection[j][k-step],npnt=nextNode.parent;//not end node, so need no range check
									var idx=indexOf(npnt,curWayId[0])
									if(idx>=0){
										//next node in same way as previous.(way1),(way2,way3),(way1,xxx) => (way1),(way1),(way1,xxx)
										curNode.parent=curWayId;
										hasChanges=2;
									}else{
										idx=indexOf(npnt,parents[0]);
										if(idx<0)idx=indexOf(npnt,parents[1]);
										if(idx>=0){
											//we have (way1),(way2,way3),(way2,xxx) => (way1),(way1,way2),(way2,xxx)
											curNode.parent=[curWayId[0],npnt[idx]];
											hasChanges=2;
										}else{
											hasAmbiguities=true;
											echo('ambigous 3 at ['+j+'.'+k+']');
											curWayId=parents;
										};
									};
								}
								break;
							default:
								echo('invalid parents: '+parents);
						};
						break;
					case 2:
						switch(parents.length){
							case 0://dual curWayId, no parent
								//dbg echo('ambigous 0');
								curNode.parent=curWayId;
								hasChanges=2;
								hasAmbiguities=true;
								break;
							case 1://dual curWayId, single parent
								if((curWayId[0]==parents[0])||(curWayId[1]==parents[0])){
									curNode.parent=[curWayId[0],curWayId[1]];
									curWayId=parents;
									hasChanges=2;
									//dbg echo('Start of way '+curWayId+' at node '+curNode.node.id);
								}else{
									hasAmbiguities=true;
									if(intersection[j][k-step].parent[0]==parents[0]){
										curWayId=parents;
									};
									echo('ambigous 1');
								};
								break;
							case 2://dual curWayId, dual parent
								if((parents[0]==curWayId[0])||(parents[0]==curWayId[1])){
									curWayId=[parents[1]];
								}else if((parents[1]==curWayId[0])||(parents[1]==curWayId[1])){
									curWayId=[parents[0]];
								}else{
									echo('ambigous 2');
									intersection[j][k-step].parent=[];
									curWayId=curNode.parent;
									hasAmbiguities=true;
								};
								break;
							default:
								echo('invalid parents: '+parents);
						};
						break;
					default:
						echo('invalid curWayId='+curWayId);
				};
				//dbg echo('	pnts(l='+curNode.parent.length+')='+curNode.parent+' CurWayId (l='+curWayId.length+')='+curWayId);
			};
			if(hasAmbiguities&&(hasChanges==0)){
				//we have no parents for this polygon
				//dbg echo('no parents at all');
				hasChanges=(findUsingNodeLists(intersection[j]))?(2):(0);
			};
		}while(hasAmbiguities&&(hasChanges>0));
		resultValid=resultValid&&!hasAmbiguities;
	};
	for(var j=0;j<intersection.length;j++){
		var ij=intersection[j];
		for(var i=0;i<ij.length;i++){
			ij[i].node.tags.deleteByKey('osman:parent');
		};
	}
	return resultValid;
};

PolyIntersector.prototype.mergeNodeLists=function(nodeList){
	//convert two-dimensional NodeList into simple polygon list.
	//Example: [[1,2],[2,3],[3,1],[5,6,7,5]] => [[1,2,3,1],[5,6,7,5]]
	//If any polygon not closed then <false> returned.
	var t=this,echo=t.h.echo;
	function merge2(l1,l2){
		//l1=l1 merged with l2
		//return [] if l1 and l2 not merged
		var l10=l1[0].id,l20=l2[0].id,l11=l1[l1.length-1].id,l21=l2[l2.length-1].id;
		var s;
		if(l10==l20){
			//new=reverse(old)+segment
			s=l1[0].tags.getByKey('osman:parent');
			s+=';'+l2[0].tags.getByKey('osman:parent');
			l1[0].tags.setByKey('osman:parent',s);
			l2.shift();
			l1.reverse();
			l1=l1.concat(l2);
			return l1;
		}else if(l11==l20){
			//new=old+segment
			s=l1[l1.length-1].tags.getByKey('osman:parent');
			s+=';'+l2[0].tags.getByKey('osman:parent');
			l1[l1.length-1].tags.setByKey('osman:parent',s);
			l2.shift();
			l1=l1.concat(l2);
			return l1;
		}else if(l10==l21){
			//new=segment+old
			s=l1[0].tags.getByKey('osman:parent');
			s+=';'+l2[l2.length-1].tags.getByKey('osman:parent');
			l1[0].tags.setByKey('osman:parent',s);
			l2.pop();
			l1=l2.concat(l1);
			return l1;
		}else if(l11==l21){
			//new=segment+reverse(old)
			s=l1[l1.length-1].tags.getByKey('osman:parent');
			s+=';'+l2[l2.length-1].tags.getByKey('osman:parent');
			l1[l1.length-1].tags.setByKey('osman:parent',s);
			l2.pop();
			l1.reverse();
			l1=l2.concat(l1);
			return l1;
		}else{
			return [];
		};
	};
	function mergeParents(node1,node2){
		var p1=(t.parseParents(node1)||[]).concat(t.parseParents(node2)||[]),s='';
		for(var i=0;i<p1.length;i++){
			s=s+((s.length)?(';'):(''))+p1[i];
			for(var j=1;j<p1.length;j++){
				if(p1[i]==p1[j]){
					p1.splice(j,1);
					j--;
				}
			};
		};
		node1.tags.setByKey('osman:parent',s);
		node2.tags.setByKey('osman:parent',s);
	};
	var doRepeat,activeList=[];
	for(var i=nodeList.length-1;i>=0;i--){
		if(nodeList[i][0].id!=nodeList[i][nodeList[i].length-1].id){
			//nodeList[i] is not polygon already, so include it into merging list
			activeList.push(nodeList[i]);
			nodeList.splice(i,1);
		};
	};
	do{
		doRepeat=false;
		for(var i=0;i<activeList.length;i++){
			for(var j=i+1;j<activeList.length;j++){
				var merged=merge2(activeList[i],activeList[j]);
				if(merged.length){
					activeList[i]=merged;
					doRepeat=true;
					activeList.splice(j,1);
					j--;
				}
			}
			if((activeList[i].length>2)&&(activeList[i][0].id==activeList[i][activeList[i].length-1].id)){
				//got a new poly. Fix parents for first and last node
				mergeParents(activeList[i][0],activeList[i][activeList[i].length-1]);
				nodeList.push(activeList[i]);
				activeList.splice(i,1);
				i--;
			};
		};
	}while(doRepeat);
	var rs=activeList.length==0;
	while(activeList.length>0)nodeList.push(activeList.pop());
	return rs;
};

PolyIntersector.prototype.mergeWayList=function(wayList){
/*
convert one-dimensional Way array into one-dimensional array of cluster objects.
All polygon clusters are at beginning of the array and linear(non-closed) clusters are at end.
	cluster object is {id1,idn,ways} where:
		id1 - id of first node in cluster
		idn - id of last node in cluster. For closed polygon idn==id1
		ways - array of way objects for this cluster.
*/
	var mw=[],clusters=[];
	for(var i=0;i<wayList.length;i++){
		var w=wayList[i],n=w.nodes.toArray();
		mw.push({id1:n[0],idn:n.slice(-1)[0],ways:[w]});
	};
	var i=mw.length;
	while(i>0){
		i--;
		var mwi=mw[i];
		if(mwi.id1==mwi.idn){
			clusters.push(mwi);
			mw.splice(i,1);
			continue;
		};
		for(var j=i-1;j>=0;j--){
			var mwj=mw[j];
			if(mwi.id1==mwj.id1){
				mwj.id1=mwi.idn;
				mwi.ways.reverse();
				mwj.ways=mwi.ways.concat(mwj.ways);
			}else if(mwi.id1==mwj.idn){
				mwj.idn=mwi.idn;
				mwj.ways=mwj.ways.concat(mwi.ways);
			}else if(mwi.idn==mwj.id1){
				mwj.id1=mwi.id1;
				mwj.ways=mwi.ways.concat(mwj.ways);
			}else if(mwi.idn==mwj.idn){
				mwj.idn=mwi.id1;
				mwi.ways.reverse();
				mwj.ways=mwj.ways.concat(mwi.ways);
			}else{
				continue;
			};
			mw.splice(i,1);
			break;
		};
	};
	clusters=clusters.concat(mw);
	return clusters;
};

PolyIntersector.prototype.parseParents=function (obj){
	//parse 'osman:parent' tag into array of ids of false.
	//'osman:parent=12' => [12];
	//'osman:parent=1;2' => [1,2];
	//'osman:parent=apple' => false;
	//'osman:parent=' => false;
	var parents=obj.tags.getByKey('osman:parent');
	if(parents){
		parents=parents.split(';');
		for(var np=0;np<parents.length;np++)parents[np]=parseFloat(parents[np]);
		return (parents.length>0)?(parents):(false);
	}
	return false;
};

PolyIntersector.prototype.waysFromNodeLists=function(intersection,processingWayIds,nextWayId){
	//returns array of arrays of way Objects as follows:
	//intersection[a,b,c]=>[[a_way1,a_way2],[b_way],[]]
	//modifies processingWayIds. On return it is array of wayIds which are in processingWayIds, but not used in resulting 'ways'
	//If new way requred, then it created with Id from dstMap.getNextWayId() or nextWayId argument
	//nextWayId is optional. Use it for speedup (avoid getNextWayId()) call.
	function isSameArrays(a1,a2){
		var l1=a1.length,l2=a2.length;
		if(l1!=l2){
			return false;
		}
		var i2=0,step=1;
		if((l1>1)&&(a1[0]==a1[l1-1])){
			//poly
			l1--;
			for(i2=0;i2<l1;i2++){
				if(a1[0]==a2[i2])break;
			};
			if(i2>=l1){
				echo('different');
				return false;
			};
			//i2<l1
			if(a1[1]==a2[i2+1]){
			}else if(a1[l1-1]==a2[i2+1]){
				step=l1-1;
				echo('antipoly');
			}else{
				return false;
			};
		}else if(l1 && (a1[0]!=a2[0])){
			i2=l1-1;
			step=-1;
		};
		for(var i=0;i<l1;i++,i2=(i2+step)%l1){
			if(a1[i]!=a2[i2]){
				return false;
			};
		};
		return true;
	};
	var t=this,emptyNode=t.dstMapHelper.map.createNode(),echo=t.h.echo,indexOf=t.h.indexOf;
	emptyNode.userId=-1;
	if(!nextWayId)nextWayId=t.dstMapHelper.getNextWayId();
	
	function detectWayDirection(intersectionNodes,curIntersectionIdx,wayNodeIds,nodeId){
		//check that we have same node in old way and in new intersection
		var nIdIdx=indexOf(wayNodeIds,nodeId);
		if(nIdIdx<0)return 0;//nodeId not found, so no direction detected
		var wstep=(nIdIdx>0)?(-1):(1);
		var nId2=wayNodeIds[nIdIdx+wstep];
		curIntersectionIdx+=wstep;
		if((curIntersectionIdx>=0)&&(curIntersectionIdx<intersectionNodes.length)&&(intersectionNodes[curIntersectionIdx].node.id==nId2)){
			//forward direction
			return 1;
		}else{
			curIntersectionIdx-=wstep*2;
			if((curIntersectionIdx>=0)&&(curIntersectionIdx<intersectionNodes.length)&&(intersectionNodes[curIntersectionIdx].node.id==nId2))return -1;//reverse direction
		};
		//undefined direction
		return 0;
	};
	
	function getNewWayNodeIds(shouldBePoly,nodes,midIdx,dir,curWayId){
		var newWayNIds=[],wStartIdx=-1,wEndIdx=-1,curNode=nodes[midIdx],parents,pIdx;
		//dbg echo('poly='+shouldBePoly+' mid='+midIdx);
		if(shouldBePoly){
			wStartIdx=0;
			wEndIdx=nodes.length-1;
			for(midIdx=0;midIdx<nodes.length;midIdx++)newWayNIds.push(nodes[midIdx].node.id);//make a copy
		}else{
			for(wEndIdx=midIdx;wEndIdx<nodes.length;wEndIdx++){//copy from middle to end
				curNode=nodes[wEndIdx];
				parents=curNode.parent;
				pIdx=indexOf(parents,curWayId);
				//dbg echo('node '+wEndIdx+' parents='+parents+' pidx='+pIdx);
				if(pIdx<0){//end of way
					wEndIdx--;
					break;
				}
				if(dir>0)newWayNIds.push(curNode.node.id);else newWayNIds.unshift(curNode.node.id);
			};
			wEndIdx=(wEndIdx<nodes.length)?(wEndIdx):(nodes.length-1);
			for(wStartIdx=midIdx-1;wStartIdx>=0;wStartIdx--){//copy from middle to start
				curNode=nodes[wStartIdx];
				parents=curNode.parent;
				pIdx=indexOf(parents,curWayId);
				//dbg echo('node '+wStartIdx+' parents='+parents+' pidx='+pIdx);
				if(pIdx<0){//end of way
					wStartIdx++;
					break;
				};
				if(dir>0)newWayNIds.unshift(curNode.node.id);else newWayNIds.push(curNode.node.id);
			};
			wStartIdx=(wStartIdx>0)?(wStartIdx):(0);
		};
		return {newWayNIds:newWayNIds,start:wStartIdx,end:wEndIdx};
	};

	function shrinkNodes(nodes,wStartIdx,wEndIdx,wayId){
		function removeParentAndIsEmpty(node,id){
		//retuns true if parents is empty
			var p=node.parent;
			var idx=indexOf(p,id);
			if(idx>=0){
				p.splice(idx,1);
			};
			return (p.length==0);
		};
		//remove wayId from parents of ending nodes
		//dbg echo('shrinkNodes start='+wStartIdx+' end='+wEndIdx);
		if((wStartIdx==0)||(removeParentAndIsEmpty(nodes[wStartIdx],wayId)))wStartIdx--;
		if((wEndIdx+1==nodes.length)||(removeParentAndIsEmpty(nodes[wEndIdx],wayId)))wEndIdx++;
		//wStartIdx and wEndIdx preserved. Nodes between them are replaced with one emptyNode
		var l=wEndIdx-wStartIdx-1;
		var needEmptyNodeIns=(wStartIdx>0)&&(wEndIdx<nodes.length)&&(l>0);
		//remove nodes, used in way
		//dbg echo('shrinkNodes2 start='+wStartIdx+' end='+wEndIdx+' insert='+needEmptyNodeIns+' l='+l);
		wStartIdx++;
		if(needEmptyNodeIns)nodes.splice(wStartIdx,l,{node:emptyNode,parent:[]});else nodes.splice(wStartIdx,l);
		//remove duplicated empty nodes
		l=nodes.length;
		if(l){
			//dbg echo('shrinkNodes3 start='+wStartIdx+' nn='+l);
			wEndIdx=wStartIdx;
			for(wStartIdx=(wStartIdx>=l)?(l-1):(wStartIdx);(wStartIdx>=0)&&(nodes[wStartIdx].node.id==0);wStartIdx--);
			//dbg echo('shrinkNodes4 start='+wStartIdx);
			for(;(wEndIdx<nodes.length)&&(nodes[wEndIdx].node.id==0);wEndIdx++);
			//dbg echo('shrinkNodes4 end='+wEndIdx);
			if(wStartIdx<0)wStartIdx=0;
			if(wEndIdx>=nodes.length)wEndIdx=nodes.length-1;
			if(nodes[wStartIdx].node.id!=0)wStartIdx++;
			if(nodes[wEndIdx].node.id!=0)wEndIdx--;
			//dbg echo('shrinkNodes5 start='+wStartIdx+' end='+wEndIdx);
			if((wEndIdx==(l-1))||(wStartIdx==0))wEndIdx++;
			if(wEndIdx>wStartIdx){
				//dbg echo('kill '+(wEndIdx-wStartIdx)+' empty nodes from '+wStartIdx+' to '+wEndIdx);
				nodes.splice(wStartIdx,wEndIdx-wStartIdx);
			};
		};
		if(nodes.length<2)nodes.splice(0,nodes.length);//[],[a]=>[]
	};
	
	function arrangeNodesToWays(nodes,pwi){
		var oldWay=false,oldWayNIds=[],r=[];
		for(var i=0;i<nodes.length;i++){
			var curNode=nodes[i];
			//dbg if(curNode.node.id==0){
			//dbg 	echo('i='+i+'/'+nodes.length+' zero id at '+curNode.node.lat+','+curNode.node.lon);
			//dbg };
			var parents=curNode.parent;
			var wIdIdx=-1;
			//check that we should process this way(s)
			for(var j=0;(j<parents.length)&&(wIdIdx<0);j++)wIdIdx=indexOf(pwi,parents[j]);
			if(wIdIdx<0){
				continue;
			}
			var curWayId=pwi[wIdIdx];
			//dbg echo('wIdIdx='+wIdIdx+' id='+curWayId+' i='+i+' Nid='+curNode.node.id+' pnts='+parents);
			var oldWayIsPoly;
			if((!oldWay)||oldWay.id!=curWayId){
				//dbg echo('get way['+curWayId+'] from map');
				oldWay=t.srcMapHelper.map.getWay(curWayId);
				oldWayNIds=oldWay.nodes.toArray();
				oldWayIsPoly=(oldWayNIds.length>2)?(oldWayNIds[0]==oldWayNIds[oldWayNIds.length-1]):(false);
			};
			if(oldWayNIds.length<2)continue;
			//determine direction
			var dir=detectWayDirection(nodes,i,oldWayNIds,curNode.node.id);
			if(dir==0){
				if(i==nodes.length-1){
					dir=1;//force forward direction for last node
				}else{
					continue;//can`t find direction - try next node
				};
			};
			var nwis=getNewWayNodeIds(oldWayIsPoly,nodes,i,dir,curWayId),newWayNIds=nwis.newWayNIds;
			i=nwis.start-1;
			//dbg echo(' new way['+curWayId+'] start='+nwis.start+'@'+newWayNIds[0]+' end='+nwis.end+'@'+newWayNIds[newWayNIds.length-1]+' len='+newWayNIds.length+' nn='+nodes.length+' dir='+dir);
			if(oldWayIsPoly&&(newWayNIds[0]!=newWayNIds[newWayNIds.length-1]))throw {name:'MapHelper',description:'Line result in poly intersection'};
			shrinkNodes(nodes,nwis.start,nwis.end,curWayId);
			if((newWayNIds.length==1)&&(i==nodes.length)&&(i>0)){
				var pidx=indexOf(nodes[0].parent,curWayId);
				if(pidx>=0){
					//dbg echo('appending 0. way=['+curWayId+']:');
					newWayNIds.push(nodes[0].node.id);
					for(pidx=0;pidx<newWayNIds.length;pidx++)echo(newWayNIds[pidx]);
					shrinkNodes(nodes,0,0,curWayId);
				};
			}
			if(newWayNIds.length>1){
				pwi.splice(wIdIdx,1);
				oldWay.nodes=newWayNIds;
				r.push(oldWay);
			}else{
				//dbg echo('i='+i+' wlen='+newWayNIds.length);
				//dbg for(var j=0;j<nodes.length;j++){
				//dbg 	curNode=nodes[j];
				//dbg 	echo('idx='+j+' id='+curNode.node.id+' parents='+curNode.parent);
				//dbg };
				//dbg WScript.sleep(100);
			};
		};
		return r;
	};
	
	var map=t.dstMapHelper,wl=[],nwl,processedWayIds=[];
	var pwi=processingWayIds.concat([]);
	for(var i=0;i<intersection.length;i++){
		var spoly=intersection[i].concat([]);//make a copy
		//prepare spoly
		if((spoly.length>0)&&(spoly[0].node.id == spoly[spoly.length-1].node.id)&& isSameArrays(spoly[0].parent,spoly[spoly.length-1].parent)){
			//spoly is polygon
			spoly.pop();//remove extra node
			//seek to ways "junction" point
			for(var j=spoly.length; (j>0)&&(spoly[0].parent)&&(spoly[0].parent.length==1);j--){
				spoly.unshift(spoly.pop());
			};
			//is it really junction?
			if(spoly[0].parent && (spoly[0].parent.length>1)&&(spoly.length>1)){
				//now add extra node and fix parent array for first and last node
				for(var j=0;j<spoly[0].parent.length;j++){
					var pIdx=indexOf(spoly[1].parent,spoly[0].parent[j]);
					if(pIdx>=0){
						spoly[0].parent.splice(j,1);
						spoly.push({node:spoly[0].node,parent:spoly[0].parent});
						spoly[0].parent=[spoly[1].parent[pIdx]];
						break;
					};
				}
			};
		};
		//dbg echo(''+i+'-th intersection nnodes='+spoly.length);
		//dbg for(var j=0;j<spoly.length;j++)echo('	n['+spoly[j].node.id+']/'+j+' pr='+spoly[j].parent);
		var oldPolyLen=0;
		var pwl=[];
		while((spoly.length>0)&&(spoly.length!=oldPolyLen)){//have nodes to process or change in last cycle
			oldPolyLen=spoly.length;
			//build list of wayIds to process
			pwi=processingWayIds.concat([]);
			for(var j=0;j<spoly.length;j++){
				var parents=spoly[j].parent;
				if(!parents.length)continue;
				for(var k=0;k<parents.length;k++){
					if(indexOf(pwi,parents[k])<0){
						pwi.unshift(parents[k]);
					}
				};
			};
			nwl=arrangeNodesToWays(spoly,pwi);
			for(var j=0;j<nwl.length;j++){
				var w=nwl[j],oldw=map.map.getWay(w.id);
				processedWayIds.push(w.id);
				if(!oldw){
					oldw=t.srcMapHelper.map.getWay(w.id);
					oldw.nodes=[];
				};
				if(!isSameArrays(w.nodes.toArray(),oldw.nodes.toArray())){
					//dbg echo('	way['+w.id+'] has different nodes. fork.');
					w.tags.setAll(oldw.tags.getAll());
					w.tags.setByKey('osman:parent',w.id);
					w.id=nextWayId; w.changeset=0;
					nextWayId--;
				}
			};
			pwl=pwl.concat(nwl);
		};
		wl.push(pwl);
		if(spoly.length>0)echo('\n'+i+'-th intersection '+spoly.length+' nodes not processed');
	};
	for(var i=0;i<processingWayIds.length;){
		if(indexOf(processedWayIds,processingWayIds[i])<0){
			//dbg echo('Way['+processingWayIds[i]+'] not in processed list');
			i++;
		}else{
			processingWayIds.splice(i,1);
		}
	};
	return wl;
};

function Hlp(){
	var t=this;
	t.man=WScript.createObject('OSMan.Application');
	t.gt=t.man.createObject('GeoTools');
	t.fso=WScript.CreateObject('Scripting.FileSystemObject');
	t.defaultStorage='Storage';
	t.defaultMap='Map';
};

Hlp.prototype.dumpMapObject=function(mapObj){
	var r=[];
	function dumpTags(){
		r.push('id='+mapObj.id+'	ver='+mapObj.version+'	user='+mapObj.userName+'['+mapObj.userId+']	chset='+mapObj.changeset+'	time='+mapObj.timestamp);
		var tg=mapObj.tags.getAll().toArray();
		r.push('tags:');
		for(var i=0;i<tg.length;i+=2){
			r.push('	'+tg[i]+'	='+tg[i+1]);
		};
	};
	var cl=mapObj.getClassName();
	r.push('ClassName= '+cl+' toString='+mapObj.toString());
	switch(cl){
	case 'Node':
		dumpTags();
		r.push('lat='+mapObj.lat+' lon='+mapObj.lon);
		break;
	case 'Way':
		dumpTags();
		var nidl=mapObj.nodes.toArray();
		var s='Nodes:';
		for(var i=0;i<nidl.length;i++){
			s+='	'+nidl[i];
		};
		r.push(s);
		break;
	case 'Relation':
		dumpTags();
		var rml=mapObj.members.getAll().toArray();
		r.push('Members:');
		for(var i=0;i<rml.length;i+=3){
			r.push('	'+rml[i]+'	'+rml[i+1]+'	'+rml[i+2]);
		};
		break;
	default:
		r.push('dump not implemented yet');
	};
	var s='';
	for(var i=0;i<r.length;i++)s+=r[i]+'\r\n';
	return s;
};

Hlp.prototype.indexOf=function(arr,elm){
	for(var i=0;i<arr.length;i++)if(arr[i]==elm)return i;
	return -1;
};

Hlp.prototype.getMultiPoly=function(refs,srcMaps,backupMap){
	var t=this;
	function updateBackup(src){
		if((!backupMap)||(backupMap.storage.dbName==src.storage.dbName))return;
		var hSrc=t.mapHelper();
		hSrc.map=src;
		hSrc.exportMultiPoly(backupMap,refs);
	};
	function refListToRefArray(iRefList){
		var a=iRefList.getAll().toArray();
		var r=[];
		for(var i=0;i<a.length;i+=3){
			r.push(a[i]+':'+a[i+1]);
		};
		return r;
	};
	if(!(srcMaps instanceof Array)){
		srcMaps=[srcMaps]
	};
	if(!(refs instanceof Array))refs=[refs];
	if(backupMap){
		srcMaps.push(backupMap);
	};
	var rs={poly:false,usedMap:false,notFoundRefs:[],notClosedRefs:[]};
	if((srcMaps.length<1)||!(refs.length>0))return rs;
	for(var i=0;i<srcMaps.length;i++){
		var mp=t.gt.createPoly();
		var hMap=t.mapHelper();
		hMap.map=srcMaps[i];
		rs.notFoundRefs=[];
		for(var j=0;j<refs.length;j++){
			var mo=hMap.getObject(refs[j]);
			if(!mo){
				rs.notFoundRefs.push(refs[j]);
			}else{
				mp.addObject(mo);
			};
		};
		if(rs.notFoundRefs.length>0)continue;
		if(!mp.resolve(hMap.map)){
			rs.notFoundRefs=refListToRefArray(mp.getNotResolved());
			rs.notClosedRefs=refListToRefArray(mp.getNotClosed());
		}else{
			rs.notClosedRefs=[];
			rs.poly=mp;
			rs.usedMap=hMap.map;
			updateBackup(hMap.map);
			break;
		};
	};
	return rs;
};

Hlp.prototype.mapHelper=function(){
	return (new MapHelper(this));
};

Hlp.prototype.polyIntersector=function(srcMapHelper,dstMapHelper,boundMultiPoly){
	return (new PolyIntersector(this,srcMapHelper,dstMapHelper,boundMultiPoly));
};

Hlp.prototype.bindFunc=function(obj,func,staticArguments){
  var ars=[];
  for(var i=2;i<arguments.length;i++){
    ars.push(arguments[i]);
  };
  return function(){
    var ar=ars.slice(0);
    for(var i=0;i<arguments.length;i++)ar.push(arguments[i]);
    return func.apply(obj,ar);
  }
}

Hlp.prototype.echo=function(s,noLF,noCR){
	WScript.stdOut.write(s+(noCR?(''):('\r'))+(noLF?(''):('\n')));
};

Hlp.prototype.echot=function(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	this.echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
};

if((typeof(noHostCheck)=='undefined') || (!noHostCheck)){
	//check window/console
	var host=WScript.FullName,exe='',sh=WScript.CreateObject('WScript.Shell'),env=sh.Environment('Process'),fso=WScript.CreateObject('Scripting.FileSystemObject');
	if ((/wscript\.exe$/i).test(host)){
		exe=fso.buildPath(fso.buildPath(env('WINDIR'),'system32'),'cscript.exe');
	}else if(!(/cscript\.exe$/i).test(host)){
		WScript.echo('Warning: Can`t detect script host windowness for <'+host+'>');
	};
	//check bitness
	var pf86=env('PROGRAMFILES(X86)');
	if(pf86){
		//we in Win64
		if(pf86!=env('PROGRAMFILES')){
			//our host in 64-bit
			exe=fso.buildPath(fso.buildPath(env('WINDIR'),'SysWOW64'),'cscript.exe');
		};
	};
	if(exe){
		var args='"'+WScript.ScriptFullName+'"',a=WScript.arguments;
		for(var i=0;i<a.length;i++)args+=' "'+a(i)+'"';
		WScript.Quit(sh.Run('"'+exe+'" '+args,1,true));
	};
};

Hlp;