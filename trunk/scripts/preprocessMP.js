//settings begin
var dstMapName='';
var noAddr=false;
var noTTable=false;
var bitLevel=0;
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
	if(ar.exists('bitlevel')){
		bitLevel=parseInt(ar.item('bitlevel'));
		if((!bitLevel)||(isNaN(bitLevel))||!((8<=bitLevel)&&(bitLevel<=32)))bitLevel=0;
	};
	if(dstMapName){
		echo('Use config:\ndst='+dstMapName);
		echo('bitLevel='+(bitLevel||'none'));
		echo('noaddr='+noAddr);
		echo('nottable='+noTTable);
		return true;
	}
	help();
	return false;
};

function mergeDupNodes(hMap){
	var stg=hMap.map.storage;
	var dupIdList=stg.createIdList();
	hMap.exec('INSERT OR IGNORE INTO '+dupIdList.tableName+'(id) SELECT n1.id FROM nodes_latlon AS n1,nodes_latlon AS n2 WHERE n1.minlat=n2.minlat AND n1.minlon=n2.minlon AND n1.id<n2.id');
	var qcoord=stg.sqlPrepare('SELECT minlat,minlon FROM nodes_latlon WHERE id=:id');
	var qdup=stg.sqlPrepare('SELECT id FROM nodes_latlon WHERE minlat=:lat AND minlon=:lon');
	var dupListIsEmpty;
	do{
		dupListIsEmpty=true;
		var qdn=hMap.exec('SELECT id FROM '+dupIdList.tableName);
		while(!qdn.eos){
			var nid=qdn.read(1).toArray();
			if(typeof(nid[0])!='number'){
				echo('warning: unexpected type of node id: '+typeof(nid[0]));continue;
			};
			dupIdList.remove(nid[0]);
			var nc=stg.sqlExec(qcoord,':id',nid).read(1).toArray();
			if(!nc.length)continue;
			dupListIsEmpty=false;
			var qnids=stg.sqlExec(qdup,[':lat',':lon'],nc),nds=[];
			while(!qnids.eos)nds=nds.concat(qnids.read(1000).toArray());
			if(nds.length<2)continue;
			for(var i=nds.length-1;i>=0;i--){
				dupIdList.remove(nds[i]);
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
	}while (!dupListIsEmpty)
	echo('');
};

function ttable(hMap){
	var ttf=include('utf2win1251.inc');
	var stg=hMap.map.storage;
	var qtgs=stg.sqlPrepare('SELECT id,tagname,tagvalue FROM tags');
	var qUpdTg=stg.sqlPrepare('UPDATE OR FAIL tags SET tagvalue=:tagvalue WHERE id=:id');
	var qDelTg=stg.sqlPrepare('DELETE FROM tags WHERE id=:id');
	var qUpdObjs=stg.sqlPrepare('UPDATE OR FAIL objtags SET tagid=(SELECT id FROM tags WHERE tagname=:tagname AND tagvalue=:newtagvalue) WHERE tagid=:id');
	var hasChanges;
	do{
		hasChanges=false;
		var stgs=stg.sqlExec(qtgs,0,0);
		while(!stgs.eos){
			var tgs=stgs.read(1000).toArray();
			for(var i=tgs.length-3;i>=0;i-=3){
				var otv=tgs[i+2],ttv=ttf(otv);
				var exits=false;
				if(ttv!=otv){
					hasChanges=true;
					echo(otv+' => '+ttv+'   ',true);
					try{
						stg.sqlExec(qUpdTg,[':id',':tagvalue'],[tgs[i],ttv]);
					}catch(e){exits=true};
				};
				if(exits){
					stg.sqlExec(qUpdObjs,[':id',':tagname',':newtagvalue'],[tgs[i],tgs[i+1],ttv]);
					stg.sqlExec(qDelTg,':id',tgs[i]);
				};
			};
		};
		echo('');
	}while(hasChanges);
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

function main(){
	if(!checkArgs())return;
	echot('Opening map');
	var dst=h.mapHelper();
	dst.open(dstMapName);
	dst.exec('PRAGMA cache_size=200000');
	if(bitLevel){
		echot('Rounding coords to bit level '+bitLevel);
		bitRound(dst,bitLevel);
	};
	echot('Merging duplicated nodes');
	mergeDupNodes(dst);
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
	echot('Remove not used nodes');
	removeNotUsedNodes(dst);
	echot('Fix incomplete ways');
	dst.fixIncompleteWays();
	echot('Fix incomplete relations');
	dst.fixIncompleteRelations();
	echot('Closing map');
	dst.close();
	echot('All done.');
}

try{
main();
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
