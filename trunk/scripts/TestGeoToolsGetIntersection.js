//settings start
var testFileDir='F:\\db\\osm\\testdata';
var testFileIn='polyclip.osm';
var testFileOut='polyclipped.osm';
var testRelationId=-604;
//settings end
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

var man=0,fso=0;

function echo(s){
	WScript.Echo(s);
};

function getNextNodeId(aMap){
	var stg=aMap.storage;
	var qry=stg.sqlPrepare('select min(id) from nodes;');
	var rslt=stg.sqlExec(qry,'','');
	if(rslt.eos)return 1;
	return Math.min(0,rslt.read(1).toArray()[0])-1;
};

function getNextWayId(aMap){
	var stg=aMap.storage;
	var qry=stg.sqlPrepare('select min(id) from ways;');
	var rslt=stg.sqlExec(qry,'','');
	if(rslt.eos)return 1;
	return Math.min(0,rslt.read(1).toArray()[0])-1;
};

function testGetIntersectionWay(map,mpoly){
	var qway=map.storage.sqlPrepare('select id from ways;');//where id=-598
	var qway=map.storage.sqlExec(qway,'','');
	while(!qway.eos){
		var wayId=qway.read(1).toArray()[0];
		var way=map.getWay(wayId);
		if(!way)continue;
		var wns=way.nodes.toArray();
		if(wns[0]==wns[wns.length-1])continue;//skip polygons
		for(var i=0;i<wns.length;i++)wns[i]=map.getNode(wns[i]);
		var ipt=mpoly.getIntersection(map,wns).toArray();
		var nextNodeId=getNextNodeId(map);
		var nextWayId=getNextWayId(map);
		var wayTags=way.tags;
		for(var i=0;i<ipt.length;i++){
			var seg=ipt[i].toArray();
			for(var j=0;j<seg.length;j++){
				if(seg[j].id==0){
					seg[j].id=nextNodeId;
					nextNodeId--;
				};
				map.putNode(seg[j]);
				seg[j]=seg[j].id;
			};
			way.nodes=seg;
			map.putWay(way);
			way=map.createWay();
			way.id=nextWayId;
			way.tags=wayTags;
			nextWayId--;
		};
	}
}

function importFile(fileName,destMap){
	WScript.Echo(''+(new Date())+' importing '+fileName);
	var ext=fso.getExtensionName(fileName);
	var ds=0;
	switch(ext){
		case 'bz2':
			ds=man.createObject('UnBZ2');
			break;
		case 'gz':
			ds=man.createObject('UnGZ');
			break;
	};
	var fs=man.createObject('FileReader');
	fs.open(fileName);
	if (ds) {
		ds.setInputStream(fs);
	}else{
		ds=fs;
	};
	var osmr=man.createObject('OSMReader');
	osmr.setInputStream(ds);
	osmr.setOutputMap(destMap);
	osmr.read(0);
	fs.open('');
	fs=ds=osmr=0;
	WScript.Echo(''+(new Date())+'import done');
};

function exportFile(srcMap,dstFileName){
	echo('Exporting '+dstFileName+' ...');
	var d=new Date();
	var fw=man.createObject('FileWriter');
	fw.open(dstFileName);
	var ow=man.createObject('OSMWriter');
	ow.setOutputStream(fw);
	ow.setInputMap(srcMap);
	ow.write('');
	d=(new Date())-d;
	echo('	done in '+d+'ms');
};

function testGeoTools(){
	var d=new Date();
	var map=man.createObject('Map');
	echo('Map='+map.toString());
	var stg=man.createObject('Storage');
	echo('Storage='+stg.toString());
	var dbName=fso.buildPath(testFileDir,testFileIn+'.db3');
	if(fso.fileExists(dbName)){
		fso.deleteFile(dbName);
	};
	stg.dbName=dbName;
	map.storage=stg;
	map.initStorage();
	importFile(fso.buildPath(testFileDir,testFileIn),map);
	var gtls=man.createObject('GeoTools');
	echo('GeoTools='+gtls.toString());
	var rel=map.getRelation(testRelationId);
	if(rel){
		echo('Relation='+rel.toString());
		var mpoly=gtls.createPoly();
		echo('Multipolygon='+mpoly.toString());
		mpoly.addObject(rel);
		if(mpoly.resolve(map)){
			echo('All refs are resolved, all polygons are closed');
			testGetIntersectionWay(map,mpoly);
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
	}else{
		echo('Relation '+testRelationId+' not found');
	};
	rel=0;
	gtls=0;
	exportFile(map,fso.buildPath(testFileDir,testFileOut));
	map.storage=0;
	stg.dbName='';
	d=(new Date())-d;
	echo('Test time: '+d+'ms');
}

//---===   main   ===---//

fso=WScript.CreateObject('Scripting.FileSystemObject');
try{
	man=WScript.CreateObject("OSMan.Application");
	echo("App="+man.toString());
	man.logger=
		{
			log:function(msg){
				WScript.Echo(msg);
			}
		};
	testGeoTools();echo('');
	}catch(e){
	echo('Unexpected exception '+e.description+' '+e.number);
}

echo('\r\npress `Enter`');
WScript.StdIn.ReadLine();