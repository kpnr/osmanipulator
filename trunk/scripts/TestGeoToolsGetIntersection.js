//settings start
var testFileDir='F:\\db\\osm\\testdata';
var testFileIn='polyclip.osm';
var testFileOut='polyclipped.osm';
//boundary objects has 'name=osmanbound'
//settings end
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}


var h=new (include('helpers.js'))();

echo=h.echo;

function testGetIntersectionComplexPoly(map,mpoly){
	function intersectRelation(r){
		function buildWayList(){
			var rs=[];
			var rm=r.members.getAll().toArray();
			for(var i=0;i<rm.lenth;i+=3){
				//skip nodes - they not processed at all
				//skip relations - they processed by other iteration
				if(rm[i]!='way')continue;
				rs.push(map.getWay(rm[i+1]));
			};
			return rs;
		};
		function buildNodeListArray(wl){
			var rs=[];
			for(var i=0;i<wl.length;i++){
				var na=h.gt.wayToNodeArray(map,wl[i]).toArray();
				rs.push(na);
				for(var ni=0;ni<na.length;ni++){
					na[ni].tags.setByKey('osman:parent',wl[i].id);
				};
			};
			return rs;
		};
		function merge2(l1,l2){
			//l1=l1 merged with l2
			//return false if l1 and l2 not merged
			var l10=l1[0].id,l20=l2[0].id,l11=l1[l1.length-1].id,l21=l2[l2.length-1];
			var s;
			if(l10==l20){
				//new=reverse(old)+segment
				s=l1[0].getByKey('osman:parent');
				s+=';'+l2[0].getByKey('osman:parent');
				l1[0].tags.setByKey('osman:parent',s);
				l2.shift();
				l1.reverse();
				l1=l1.concat(l2);
				return true;
			}else if(l11==l20){
				//new=old+segment
				s=l1[l1.length-1].getByKey('osman:parent');
				s+=';'+l2[0].getByKey('osman:parent');
				l1[l1.length-1].tags.setByKey('osman:parent',s);
				l2.shift();
				l1=l1.concat(l2);
				return true;
			}else if(l10==l21){
				//new=segment+old
				s=l1[0].getByKey('osman:parent');
				s+=';'+l2[l2.length-1].getByKey('osman:parent');
				l1[0].tags.setByKey('osman:parent',s);
				l2.pop();
				l1=l2.concat(l1);
				return true;
			}else if(l11==l21){
				//new=segment+reverse(old)
				s=l1[l1.length-1].getByKey('osman:parent');
				s+=';'+l2[l2.length-1].getByKey('osman:parent');
				l1[length-1].tags.setByKey('osman:parent',s);
				l2.pop();
				l1.reverse();
				l1=l2.concat(l1);
				return true;
			}else{
				return false;
			};
		};
		function mergeNodeLists(nl){
			var doRepeat=false;
			do{
				for(var i=0;i<nl.length;i++){
					if(nl[i][0]==nl[i][nl[i].length-1])continue;//nl[i] is polygon already 
					for(var j=i+1;j<nl.length;j++){
						if(merge2(nl[i],nl[j])){
							doRepeat=true;
							nl.splice(j,1);
							j--;
						}
					}
				};
			}while(doRepeat)
		};
		var wayList=buildWayList();//osman objects
		var nodeListArray=buildNodeListArray(wayList);//convert Way array to array of NodeArray
		if(!mergeNodeLists(nodeListArray)){//convert Way array to simple polygon array
			echo('Relation has not closed polygons. Delete it');
			map.deleteRelation(r.id);
			updateRelDeps(r.id,[]);
		};
		for(var i=0;i<nodeListArray.length;i++){
			var intersection=mpoly.getIntersection
		};
	};
	
	var qMPRel=map.storage.sqlPrepare('select id from relations where id in ( select (objid>>2) as relid from objtags where tagid in (select id as tagid from tags where tagname="type" and tagvalue in ("multipolygon","boundary")) and objid&3=2)');
	qMPRel=map.storage.sqlExec(qMPRel,0,0);
	while(!qMPRel.eos){
		var relation=qMPRel.read(1).toArray()[0];//id
		relation=map.getRelation(relation);//osman object
		intersectRelation(relation);
	};
};

function testGetIntersectionWay(hMap,mpoly){
	var map=hMap.map;
	var qway=map.storage.sqlPrepare('select id from ways');// where id=-118');
	qway=map.storage.sqlExec(qway,'','');
	while(!qway.eos){
		var wayId=qway.read(1).toArray()[0];
		var way=map.getWay(wayId);
		if(!way)continue;
		var wns=way.nodes.toArray();
		if((wns.length<2)||(wns[0]!=wns[wns.length-1]))continue;//skip non-polygons
		echo('processing '+way.toString()+' id='+way.id);//+' name='+way.tags.getByName('name'));
		wns=hMap.wayToNodeArray(way);
		var nextNodeId=hMap.getNextNodeId();
		var ipt=mpoly.getIntersection(map,wns,nextNodeId).toArray();
		var nextWayId=hMap.getNextWayId();
		var wayTags=way.tags;
		for(var i=0;i<ipt.length;i++){
			var seg=ipt[i].toArray();
			wns=[];
			for(var j=0;j<seg.length;j++){
				if((seg[j].id<=nextNodeId)||(seg[j].tags.getByKey('osman:note')=='boundary')){
					map.putNode(seg[j]);
				};
				wns.push(seg[j].id);
			};
			way.nodes=wns;
			map.putWay(way);
			way=map.createWay();
			way.id=nextWayId;
			way.tags=wayTags;
			nextWayId--;
		};
		if(ipt.length==0)map.deleteWay(wayId);
	}
}

function testGeoTools(){
	var d=new Date();
	var hMap=h.mapHelper();
	hMap.open(h.fso.buildPath(testFileDir,testFileIn+'.db3'),true);
	var map=hMap.map;
	var stg=map.storage;
	echo('Importing...');
	hMap.importXML(h.fso.buildPath(testFileDir,testFileIn));
	echo('GeoTools='+h.gt.toString());
	var cutByBound=function(mobj){
			echo('Testing '+mobj.getClassName()+'='+mobj.toString());
			var mpoly=h.gt.createPoly();
			echo('Multipolygon='+mpoly.toString());
			mpoly.addObject(mobj);
			if(mpoly.resolve(hMap.map)){
				echo('All refs are resolved, all polygons are closed');
				testGetIntersectionWay(hMap,mpoly);
			}else{
				echo('Not resolved refs:');
				var url=mpoly.getNotResolved().getAll().toArray();
				for(var i=0;i<url.length;i+=3){
					echo('	'+url[i]+'	'+url[i+1]+'	'+url[i+2]);
				}
				echo('Not closed nodes:');
				var url=mpoly.getNotClosed().getAll().toArray();
				for(var i=0;i<url.length;i+=3){
					echo('	'+url[i]+'	'+url[i+1]+'	'+url[i+2]);
				}
			}
			mpoly=0;
		};
	var q=stg.sqlPrepare("select (objid>>2) from strobjtags where tagname='name' and tagvalue='osmanbound' and (objid&3)=2");
	var q=stg.sqlExec(q,'','');
	var mobj=false;
	while(!q.eos){
		mobj=map.getRelation(q.read(1).toArray()[0]);
		cutByBound(mobj);
	};
	q=stg.sqlPrepare("select (objid>>2) from strobjtags where tagname='name' and tagvalue='osmanbound' and (objid&3)=1");
	var q=stg.sqlExec(q,'','');
	while(!q.eos){
		mobj=map.getWay(q.read(1).toArray()[0]);
		cutByBound(mobj);
	};
	echo('Exporting...');
	hMap.exportXML(h.fso.buildPath(testFileDir,testFileOut));
	hMap.close();
	d=(new Date())-d;
	echo('Test time: '+d+'ms');
}

//---===   main   ===---//

try{
	echo("App="+h.man.toString());
	h.man.logger=
		{
			log:echo
		};
	testGeoTools();echo('');
	}catch(e){
	echo('Unexpected exception '+e.description+' '+e.number);
}

echo('\r\npress `Enter`');
WScript.StdIn.ReadLine();