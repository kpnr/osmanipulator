//settings
var regionBoundaryCollectionRelationId=184217;
var srcMapName='S:\\db\\osm\\sql\\rf.db3';
var dstDir='F:\\db\\osm\\rf_regions';
//end settings

//boundary Russia relation = 60189
//boundary Московская область relation =51490
//субъекты РФ relation=184217
var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

var man=WScript.createObject('OSMan.Application');
var fso=WScript.createObject('Scripting.FileSystemObject');

function echo(s){
	WScript.StdOut.write(s+'\n');
};

function openMap(storageName){
	var stg=man.createObject('Storage');
	var map=man.createObject('Map');
	var initStg=!fso.fileExists(storageName);
	stg.dbName=storageName;
	map.storage=stg;
	if (initStg){
		stg.initSchema();
	};
	echo(map.toString());
	return map;
};

function createPoly(boundObject,aMap){
	var gt=man.createObject('GeoTools');
	var mp=gt.createPoly();
	mp.addObject(boundObject);
	if(mp.resolve(aMap)){
		return mp;
	}else {
		echo('Not resolved refs:');
		var url=mp.getNotResolved().getAll().toArray();
		for(var i=0;i<url.length;i+=3){
			echo('	'+url[i]+'	'+url[i+1]+'	'+url[i+2]);
		};
		return false;
	}
}

function exportOSM(srcMap,exportFilter,dstFileName){
	if(fso.fileExists(dstFileName)){
		echo('	File already exists. Skipped.');
		return;
	};
	echo('Exporting '+dstFileName+' ...');
	var d=new Date();
	var fw=man.createObject('FileWriter');
	fw.open(dstFileName);
	var ow=man.createObject('OSMWriter');
	ow.setOutputStream(fw);
	ow.setInputMap(srcMap);
	ow.write(exportFilter);
	d=(new Date())-d;
	echo('	done in '+d+'ms');
}

var srcMap=openMap(srcMapName);
var bounds=srcMap.getRelation(regionBoundaryCollectionRelationId);
var netmap=man.createObject('NetMap');
netmap.storage=man.createObject('HTTPStorage');
if(bounds){
	bounds=bounds.members.getAll().toArray();
	var exportList=[];
	var gt=man.createObject('GeoTools');
	for(var i=0,i1=0;i<bounds.length;i+=3){
		if((bounds[i]!='relation')&&(bounds[i]!='way'))continue;
		echo('Processing '+bounds[i]+' '+bounds[i+1]);
		var bound=false;
		if(bounds[i]=='relation'){
			bound=srcMap.getRelation(bounds[i+1])
		}else{
			bound=srcMap.getWay(bounds[i+1]);
		};
		if(!bound){
			echo('	not found');
			continue;
		};
		echo('	name='+bound.tags.getByKey('name'));
		var bp=gt.createPoly();
		bp.addObject(bound);
		var retryResolve=true;
		while(retryResolve && !bp.resolve(srcMap)){
			var ul=bp.getNotResolved().getAll().toArray();
			echo('	Resolving objects:');
			echo('l='+bp.getNotResolved().count);
			retryResolve=false;
			for(var j=0;j<ul.length;j+=3){
				WScript.stdOut.write('		('+(j/3+1)+'/'+(ul.length/3)+')'+ul[j]+'	id='+ul[j+1]);
				try{
					var obj=false;
					switch(ul[j]){
						case 'node':obj=netmap.getNode(ul[j+1]);break;
						case 'way':obj=netmap.getWay(ul[j+1]);break;
						case 'relation':obj=netmap.getRelation(ul[j+1]);break;
					};
					if(obj){
						srcMap.putObject(obj);
						retryResolve=true;
						WScript.stdOut.write(' resolved	\r');
					}else{
						echo(' not found');
					};
				}catch(e){
					echo(' failed with exception');
					continue;
				}
			};
			echo('');
		};
		if(bp.getNotResolved().count>0){
			echo('	Poly not resolved. Skipped.');
			continue;
		};
		if(bp.getNotClosed().count>0){
			echo('	Poly not closed. Skipped.');
			continue;
		}
		var bbox=bp.getBBox().toArray();
		if((bbox[1]-bbox[3])>300){
			echo('	Too large region. Skipped.');
			continue;
		};
		exportList[i1]=[bound,bp,bbox];
		i1++;
	};
	exportList.sort(function(a,b){if(a[2][3]<b[2][3])return -1;else if(a[2][3]>b[2][3]) return 1;else return 0});
	for(var i=0;i<exportList.length;i++){
		var flt=[':clipIncompleteWays',':bpoly',exportList[i][1],':bbox'].concat(exportList[i][2]);
		exportOSM(srcMap,flt,fso.buildPath(dstDir, exportList[i][0].tags.getByKey('name')+'.osm'));
	}
}else{
	echo('Region boundary collection relation not found');
}