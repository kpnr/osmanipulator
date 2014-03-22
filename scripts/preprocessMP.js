//settings begin
var dstMapName='';
var noAddr=false;
var noTTable=false;
var bitLevel=0;
var dstLang='ru';
var intToDeg=1e-7,degToInt=1/intToDeg;
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

//global variables
var h=new (include('helpers.js'))();
var echo=h.echo;
function echot(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
}
//end global variables
function checkArgs(){
	function help(){
	echo('Preprocessing map database before export to OSM format\n for MP(Polish format) convertion\n\
  Command line options:\n\
    /dst:"dest_file_name.db3"\n\
    /bitlevel:nn round all coordinates up to nn bit level. nn must be\n\
      between 8 and 32 inclusive.\n\
    /lng:us set language for `name` and `addr:*` tags.\n\
      Copy/translate `name:us` values to `name` and `addr:*` tags\n\
    /noaddr remove address info\n\
    /nottable do not translate tag values from UTF8');
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('dst'))dstMapName=ar.item('dst')||dstMapName;
	if(ar.exists('noaddr'))noAddr=true;
	if(ar.exists('nottable'))noTTable=true;
	if(ar.exists('lng'))dstLang=ar.item('lng');
	if(ar.exists('bitlevel')){
		bitLevel=parseInt(ar.item('bitlevel'));
		if((!bitLevel)||(isNaN(bitLevel))||!((8<=bitLevel)&&(bitLevel<=32)))bitLevel=0;
	};
	if(dstMapName){
		echo('Use config:\ndst='+dstMapName);
		echo('bitLevel='+(bitLevel||'none'));
		echo('noaddr='+noAddr);
		echo('nottable='+noTTable);
		echo('lng='+dstLang);
		return true;
	}
	help();
	return false;
};

function mergeDupNodes(hMap){
//12:51
	var stg=hMap.map.storage;
	var minId=hMap.getNextNodeId();
	var qNextDup=stg.sqlPrepare('SELECT nc1.id,nc1.minlat,nc1.minlon FROM nodes_attr as na, nodes_latlon as nc1, nodes_latlon as nc2 WHERE na.id>:minId AND nc1.id=na.id AND nc1.minlon=nc2.minlon AND nc1.minlat=nc2.minlat AND nc1.id<nc2.id ORDER BY na.id LIMIT 1');
	var qCoordToIds=stg.sqlPrepare('SELECT id FROM nodes_latlon WHERE minlat=:ilat AND minlon=:ilon AND id>:minId');
	while(1){
		var sNextDup=stg.sqlExec(qNextDup,':minId',minId);
		if(sNextDup.eos)break;
		var aIdLatLon=sNextDup.read(1).toArray();
		minId=aIdLatLon[0];
		var sCoordToIds=stg.sqlExec(qCoordToIds,[':minId',':ilat',':ilon'],aIdLatLon);
		var saIds=[minId];
		while(!sCoordToIds.eos){
			saIds=saIds.concat(sCoordToIds.read(1000).toArray());
		};
		if(saIds.length<2)continue;
		for(var i=saIds.length-1;i>=0;i--){
			saIds[i]=hMap.map.getNode(saIds[i]);
			if(!saIds[i])saIds.splice(i,1);
		};
		if(saIds.length<2)continue;
		var tags=saIds[0].tags;
		echo('\r'+saIds[0].id+' x '+saIds.length+'   ',true,true);
		for(var i=saIds.length-1;i>0;i--){
			var tags2=saIds[i];
			for(var j=tags2.count-1;j>=0;j--){
				tags.setByKey(tags2.getKey(j),tags2.getValue(j));
			};
			hMap.replaceObject(saIds[i],[saIds[0]]);
		};
	};
	echo('');

	/*12:55 var stg=hMap.map.storage;
	var sids=hMap.exec('SELECT id FROM nodes_attr ORDER BY id');
	var dupIdList=stg.createIdList(),noCheckList=stg.createIdList();
	var qCoordToIds=stg.sqlPrepare('SELECT id FROM nodes_latlon WHERE minlat=:ilat AND minlon=:ilon AND id>:minid AND NOT id IN(SELECT id FROM '+noCheckList.tableName+')');
	var qIdToCoord=stg.sqlPrepare('SELECT minlat,minlon FROM nodes_latlon WHERE id=:id');
	while(!sids.eos){
		var asids=sids.read(1000).toArray();
		for(var i=0;i<asids.length;i++){
			var nid=asids[i];
			var nca=stg.sqlExec(qIdToCoord,':id',nid).read(1).toArray();
			nca.push(nid);
			var sCoordToIds=stg.sqlExec(qCoordToIds,[':ilat',':ilon',':minid'],nca);
			if(!sCoordToIds.eos){
				dupIdList.add(nid);
				echo(nid+'  ',true);
			};
			while(!sCoordToIds.eos){
				var saIds=sCoordToIds.read(1000).toArray();
				for(var j=0;j<saIds.length;j++){
					noCheckList.add(saIds[j]);
				};
			};
		};
	};
	noCheckList=0;
	
	sids=hMap.exec('SELECT id FROM '+dupIdList.tableName);
	var qdup=stg.sqlPrepare('SELECT id FROM nodes_latlon WHERE minlat=:lat AND minlon=:lon');
	while(!sids.eos){
		var nc=stg.sqlExec(qIdToCoord,':id',sids.read(1)).read(1);
		var qnids=stg.sqlExec(qdup,[':lat',':lon'],nc),nds=[];
		while(!qnids.eos)nds=nds.concat(qnids.read(1000).toArray());
		if(nds.length<2)continue;
		for(var i=nds.length-1;i>=0;i--){
			nds[i]=hMap.map.getNode(nds[i]);
			if(!nds[i])nds.splice(i,1);
		};
		if(nds.length<2)continue;
		var tags=nds[0].tags;
		echo('['+nds.length+'] => '+nds[0].id+'   ',true);
		for(var i=nds.length-1;i>0;i--){
			var tags2=nds[i];
			for(var j=tags2.count-1;j>=0;j--){
				tags.setByKey(tags2.getKey(j),tags2.getValue(j));
			};
			hMap.replaceObject(nds[i],[nds[0]]);
		};
	};
	echo('');
	*/
	/*12:20 var stg=hMap.map.storage;
	var qcoord=stg.sqlPrepare('SELECT n1.minlat,n1.minlon FROM nodes_latlon AS n1,nodes_latlon AS n2 WHERE n1.minlat=n2.minlat AND n1.minlon=n2.minlon AND n1.id<>n2.id LIMIT 1');
	var qdup=stg.sqlPrepare('SELECT id FROM nodes_latlon WHERE minlat=:lat AND minlon=:lon');
	do{
		var nc=stg.sqlExec(qcoord,0,0).read(1).toArray();
		if(!nc.length)break;
		var qnids=stg.sqlExec(qdup,[':lat',':lon'],nc),nds=[];
		while(!qnids.eos)nds=nds.concat(qnids.read(1000).toArray());
		if(nds.length<2)continue;
		for(var i=nds.length-1;i>=0;i--){
			nds[i]=hMap.map.getNode(nds[i]);
			if(!nds[i])nds.splice(i,1);
		};
		if(nds.length<2)continue;
		var tags=nds[0].tags;
		echo('['+nds.length+'] => '+nds[0].id+'   ',true);
		for(var i=nds.length-1;i>0;i--){
			var tags2=nds[i];
			for(var j=tags2.count-1;j>=0;j--){
				tags.setByKey(tags2.getKey(j),tags2.getValue(j));
			};
			hMap.replaceObject(nds[i],[nds[0]]);
		};
	}while (true)
	echo('');
	*/
};

function ttable(hMap){
	var ttf=include('utf2win1251.js');
	var stg=hMap.map.storage;
	var qtgs=stg.sqlPrepare('SELECT id,tagname,tagvalue from tags WHERE \
  tagname BETWEEN "addr" AND "adds" or\
  tagname BETWEEN "alt_" AND "alt`" or \
  tagname BETWEEN "contact" AND "contacu" or \
  tagname BETWEEN "full_" AND "full`" or\
  tagname BETWEEN "int_" AND "int`" or\
  tagname BETWEEN "is_in" AND "is_io" or\
  tagname BETWEEN "loc_" AND "loc`" or\
  tagname BETWEEN "local_" AND "local`" or\
  tagname BETWEEN "long_" AND "long`" or\
  tagname BETWEEN "name" AND "namf" or\
  tagname BETWEEN "official_name" AND "official_namf" or\
  tagname BETWEEN "old_" AND "old`" or\
  tagname BETWEEN "operator" AND "operatos" or\
  tagname BETWEEN "place_name" AND "place_namf" or\
  tagname BETWEEN "ref" AND "reg" or\
  tagname BETWEEN "short_name" AND "short_namf" or\
  tagname IN ("brand","description","destination","email","level","network","phone","route_ref","website")');
	var qUpdTg=stg.sqlPrepare('UPDATE OR FAIL tags SET tagvalue=:tagvalue WHERE id=:id');
	var qDelTg=stg.sqlPrepare('DELETE FROM tags WHERE id=:id');
	var qUpdObjs=stg.sqlPrepare('UPDATE OR FAIL objtags SET tagid=(SELECT id FROM tags WHERE tagname=:tagname AND tagvalue=:newtagvalue) WHERE tagid=:id');
	var hasChanges,cnt=0,chcnt=0;
	do{
		hasChanges=false;
		var stgs=stg.sqlExec(qtgs,0,0);
		while(!stgs.eos){
			var tgs=stgs.read(1000).toArray();
			for(var i=tgs.length-3;i>=0;i-=3){
				var otv=tgs[i+2],ttv=ttf(otv);
				var exists=false;
				cnt++;
				if(ttv!=otv){
					hasChanges=true;
					chcnt++;
					try{
						stg.sqlExec(qUpdTg,[':id',':tagvalue'],[tgs[i],ttv]);
					}catch(e){exists=true};
				};
				if(exists){
					stg.sqlExec(qUpdObjs,[':id',':tagname',':newtagvalue'],[tgs[i],tgs[i+1],ttv]);
					stg.sqlExec(qDelTg,':id',tgs[i]);
				};
			};
			echo(chcnt+'/'+cnt+'   ',true);
		};
	}while(hasChanges);
	echo(chcnt+'/'+cnt+'   ');
};

function deleteAddrInfo(hMap){
	var addrTagNames='place,description,int_name,int_ref,loc_name,local_ref,official_name,old_name,oldname,operator';
	var addrTagRanges='addr:,address:,alt_name,cladr:,name';
	addrTagNames='\''+(addrTagNames.replace(/\'/g,'\'\'').split(',')).join('\',\'')+'\'';
	addrTagRanges=addrTagRanges.split(',');
	for(var i=0;i<addrTagRanges.length;i++){
		var s=addrTagRanges[i],s1;
		s1=s.slice(0,-1)+String.fromCharCode(s.charCodeAt(s.length-1)+1);
		addrTagRanges[i]='(\''+s.replace(/\'/g,'\'\'')+'\'<=tagname AND tagname<\''+s1.replace(/\'/g,'\'\'')+'\')';
	};
	var where='WHERE tagname IN ('+addrTagNames+') OR '+addrTagRanges.join(' OR ');
	hMap.exec('DELETE FROM objtags WHERE tagid IN (SELECT id FROM tags '+where+')');
	hMap.exec('DELETE FROM tags '+where);
};

function bitRound(hMap,bl){
	var qNIds=hMap.exec('SELECT id FROM nodes_attr'),stg=hMap.map.storage;
	var qGetCoord=stg.sqlPrepare('SELECT minlat*'+intToDeg+',minlon*'+intToDeg+' FROM nodes_latlon WHERE id=:id');
	var qSetCoord=stg.sqlPrepare('UPDATE nodes_latlon SET minlat=round(:lat*'+degToInt+'), minlon=round(:lon*'+degToInt+'), maxlat=round(:lat*'+degToInt+'), maxlon=round(:lon*'+degToInt+') WHERE id=:id');
	var cnt=0,tot=0;
	while(!qNIds.eos){
		var aNIds=qNIds.read(1000);
		aNIds=aNIds.toArray();
		var aNewCoords=[],testNode={lat:0,lon:0};
		for(var i=aNIds.length-1;i>=0;i--){
			var aCoords=stg.sqlExec(qGetCoord,':id',aNIds[i]).read(1).toArray();
			testNode.lat=aCoords[0];testNode.lon=aCoords[1];
			h.gt.bitRound(testNode,bl);
			tot++;
			aCoords[0]=Math.abs(aCoords[0]-testNode.lat);
			aCoords[1]=Math.abs(aCoords[1]-testNode.lon);
			if((aCoords[0]>5e-8)||(aCoords[1]>5e-8)){
				aNewCoords.push(aNIds[i],testNode.lat,testNode.lon);
				cnt++;
			}
		};
		if(aNewCoords.length>0){
			stg.sqlExec(qSetCoord,[':id',':lat',':lon'],aNewCoords);
		}
		echo(''+cnt+'/'+tot,true);
	};
	echo('');
};

function removeWayNodeDup(hMap){
	var stg=hMap.map.storage,wayIdList=stg.createIdList();
	echo('searching ways...',true);
	hMap.exec('INSERT INTO '+wayIdList.tableName+' (id) SELECT wayid FROM (SELECT id AS wayid FROM ways) AS wn WHERE (SELECT COUNT(DISTINCT nodeid) FROM waynodes WHERE wayid=wn.wayid)<>(SELECT COUNT(1) FROM waynodes WHERE wayid=wn.wayid)');
	var sWayIds=hMap.exec('SELECT id FROM '+wayIdList.tableName);
	while(!sWayIds.eos){
		var wIds=sWayIds.read(1000).toArray();
		for(var i=wIds.length-1;i>=0;i--){
			var way=hMap.map.getWay(wIds[i]);
			var wn=way.nodes.toArray(),oldl=wn.length;
			for(var j=oldl-1;j>0;){
				if(wn[j]==wn[j-1]){
					wn.splice(j,1)
					j=(j>=wn.length)?(wn.length-1):(j);
				}else if((j>1)&&(wn[j]==wn[j-2])){
					wn.splice(j-1,2);
					j=(j>=wn.length)?(wn.length-1):(j);
				}else{
					j--;
				};
			};
			if(wn.length<2){
				hMap.replaceObject(way,[]);
				echo(way.id+'-  ',true);
			}else if(wn.length!=oldl){
				way.nodes=wn;
				hMap.map.putWay(way);
				echo(way.id+'   ',true);
			};
		};
	};
	echo('');
};

function removeNotUsedNodes(hMap){
	var unl=hMap.map.storage.createIdList();
	echot('	adding ways nodes');
	hMap.exec('INSERT OR IGNORE INTO '+unl.tableName+' (id) SELECT nodeid FROM waynodes');
	echot('	adding relation nodes');
	hMap.exec('INSERT OR IGNORE INTO '+unl.tableName+' (id) SELECT memberid FROM relationmembers WHERE memberidxtype&3=0');
	echot('	adding tagged nodes');
	hMap.exec('INSERT OR IGNORE INTO '+unl.tableName+' (id) SELECT objid>>2 FROM objtags WHERE objid&3=0');
	echot('	removing nodes');
	hMap.exec('DELETE FROM nodes WHERE id NOT IN (SELECT id FROM '+unl.tableName+')');
};

function removeNotUsedWays(hMap){
	var unl=hMap.map.storage.createIdList();
	echot('	adding relation ways');
	hMap.exec('INSERT OR IGNORE INTO '+unl.tableName+' (id) SELECT memberid FROM relationmembers WHERE memberidxtype&3=1');
	echot('	adding tagged ways');
	hMap.exec('INSERT OR IGNORE INTO '+unl.tableName+' (id) SELECT objid>>2 FROM objtags WHERE objid&3=1');
	echot('	removing ways');
	hMap.exec('DELETE FROM ways WHERE id NOT IN (SELECT id FROM '+unl.tableName+')');
};

function normalizeRelations(hMap){
	var sRid=hMap.exec('SELECT id FROM relations');
	while(!sRid.eos){
		var rid=sRid.read(1).toArray()[0],rel=hMap.map.getRelation(rid);
		if(!rel)continue;
		var rtags=rel.tags,members=rel.members.getAll().toArray();
		for(var i=members.length-3;i>=0;i-=3){
			if(members[i]!='way')continue;
			var wid=members[i+1],way=hMap.map.getWay(wid);
			if(!way)continue;
			var wtags=way.tags.getAll().toArray(),isModified=false;
			for(var j=wtags.length-2;j>=0;j-=2){
				if(rtags.hasKey(wtags[j]) && (rtags.getByKey(wtags[j])==wtags[j+1])){
					wtags.splice(j,2);
					isModified=true;
				};
			};
			if(isModified){
				way.tags.setAll(wtags);
				hMap.map.putWay(way);
			};
		};
	};
};

function processAssociatedStreet(hMap){
	var sRid=hMap.exec("SELECT objid>>2 FROM objtags WHERE tagid in (SELECT id FROM tags WHERE tagname='type' AND tagvalue in ('associatedStreet','street')) and objid&3=2"),tagtest=/^name(:..)?$/;
	while(!sRid.eos){
		var rid=sRid.read(1).toArray()[0],rel=hMap.map.getRelation(rid);
		if(!rel)continue;
		var rtags=rel.tags,members=rel.members.getAll().toArray(),ways=[],rta=rtags.getAll().toArray(),isModified=false;
		for(var i=rta.length-2;i>=0;i-=2){
			if(!tagtest.test(rta[i]))rta.splice(i,2);
		};
		//copy names from ways to relation
		for(var i=members.length-3;i>=0;i-=3){
			if((members[i]!='way')||(members[i+2]!='street'))continue;
			var wid=members[i+1],way=hMap.map.getWay(wid);
			if(!way)continue;
			ways.push(way);
			var wtags=way.tags.getAll().toArray();
			for(var j=wtags.length-2;j>=0;j-=2){
				if(!tagtest.test(wtags[j]))continue;
				if(!rtags.hasKey(wtags[j])){
					rtags.setByKey(wtags[j],wtags[j+1]);
					rta.push(wtags[j],wtags[j+1]);
					isModified=true;
				};
			};
		};
		if(isModified){
			hMap.map.putRelation(rel);
		};
		//copy names from relation to ways
		for(var i=ways.length-1;i>=0;i--){
			var w=ways[i];
			isModified=false;
			for(var j=rta.length-2;j>=0;j-=2){
				if(!w.tags.hasKey(rta[j])){
					w.tags.setByKey(rta[j],rta[j+1]);
					isModified=true;
				};
			};
			if(isModified){
				hMap.map.putWay(w);
			};
		};
	};
};

function processLanguage(hMap,lng){
	var stg=hMap.map.storage;
	hMap.exec('CREATE TEMPORARY TABLE IF NOT EXISTS lngtrans (src INTEGER PRIMARY KEY,dst INTEGER, CONSTRAINT lngstrs_pair UNIQUE(src,dst) ON CONFLICT FAIL)');
	echot('	Make translate table');
	var q=stg.sqlPrepare('INSERT OR IGNORE INTO lngtrans SELECT src.id AS src, dst.tagid AS dst\
  FROM tags AS src,\
    (SELECT objid,tagid FROM objtags WHERE tagid IN (SELECT id FROM tags WHERE tagname=:lng)) AS dst\
  WHERE src.id IN (SELECT tagid FROM objtags WHERE objid=dst.objid)\
    AND (src.tagname||"")="name"\
    AND src.tagvalue NOT IN (SELECT tagvalue FROM tags WHERE id=dst.tagid)');
	stg.sqlExec(q,':lng','name:'+lng);
	echot('	Translating');
	var sTagReplace=hMap.exec('SELECT tg.id AS id,tg.tagname AS tagname,dstt.tagvalue AS newval FROM\
 (select id,tagname,tagvalue \
  from tags\
  where (tagname="name" or tagname>"addr:" and tagname<"addr;") \
    and tagvalue in (select tagvalue from tags where id in (select src from lngtrans)))as tg,\
  tags,lngtrans,tags as dstt\
  where tags.tagname="name" and tags.tagvalue=tg.tagvalue and tags.id=lngtrans.src and dstt.id=lngtrans.dst');
	var qSaveTag=stg.sqlPrepare('INSERT OR IGNORE INTO tags (tagname, tagvalue) VALUES (:tagname, :tagvalue)');
	var qTagId=stg.sqlPrepare('SELECT id FROM tags WHERE tagname=:tagname AND tagvalue=:tagvalue');
	var qUpdateObjTags=stg.sqlPrepare('UPDATE objtags SET tagid=:newtagid WHERE tagid=:oldtagid');
	var cnt=0,chcnt=0;
	while(!sTagReplace.eos){
		var arReplace=sTagReplace.read(100).toArray();
		for(var i=0;i<arReplace.length;i+=3){
			//0 - id, 1 - name, 2 - newval
			stg.sqlExec(qSaveTag,[':tagname',':tagvalue'],[arReplace[i+1],arReplace[i+2]]).read(1).toArray()[0];
			var newId=stg.sqlExec(qTagId,[':tagname',':tagvalue'],[arReplace[i+1],arReplace[i+2]]).read(1).toArray()[0];
			cnt++;
			if(newId != arReplace[i]){
				stg.sqlExec(qUpdateObjTags,[':oldtagid',':newtagid'],[arReplace[i],newId]);
				chcnt++;
			};
		};
		echo(''+chcnt+'/'+cnt,true);
	};
	hMap.exec('DELETE FROM lngtrans');
	echo(''+chcnt+'/'+cnt);
};

function main(){
	if(!checkArgs())return;
	echot('Opening map');
	var dst=h.mapHelper();
	dst.open(dstMapName);
	if(bitLevel){
		echot('Rounding coords to bit level '+bitLevel);
		bitRound(dst,bitLevel);
		echot('Merging duplicated nodes');
		mergeDupNodes(dst);
	};
	if(noAddr){
		echot('Deleting address info');
		deleteAddrInfo(dst);
	};
	if(!noTTable){
		echot('Translating tag values from UTF to ANSI');
		ttable(dst);
	};
	echot('Remove duplicated nodes from ways');
	removeWayNodeDup(dst);
	echot('Remove not used ways');
	removeNotUsedWays(dst);
	echot('Remove not used nodes');
	removeNotUsedNodes(dst);
	echot('Normalize relations');
	normalizeRelations(dst);
	echot('Process associatedStreet names');
	processAssociatedStreet(dst);
	echot('Fix incomplete ways');
	dst.fixIncompleteWays();
	echot('Fix incomplete relations');
	dst.fixIncompleteRelations();
	if(dstLang){
		echot('Process "name" tag language');
		processLanguage(dst,dstLang);
	};
	echot('Closing map');
	dst.close();
	echot('All done.');
}

//try{
main();
/*}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};*/
