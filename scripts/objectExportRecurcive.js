//settings begin
var exportObject=['relation',60189];
var srcMapName='f:\\db\\osm\\sql\\rf.db3';
var dstMapName='f:\\db\\osm\\sql\\rf_boundary.db3';
//settings end

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
		map.initStorage();
	};
	echo(map.toString());
	return map;
};

function closeMap(aMap){
	var stg=aMap.storage;
	aMap.storage=0;
	stg.dbName='';
};

function exportRecurcive(srcMap,dstMap,objRefArray){
	function ex(objRef){
		var rslt=[];
		var obj=false;
		var i;
		switch(objRef[0]){
			case 'node':
				obj=srcMap.getNode(objRef[1]);
				break;
			case 'way':
				obj=srcMap.getWay(objRef[1]);
				if(!obj)break;
				var ndl=obj.nodes.toArray();
				for(i=0;i<ndl.length;i++){
					rslt[rslt.length]=['node',ndl[i]];
				};
				break;
			case 'relation':
				obj=srcMap.getRelation(objRef[1]);
				if(!obj)break;
				var mbrl=obj.members.getAll.toArray();
				for(i=0;i<mbrl.length;i+=3){
					rslt[rslt.length]=[mbrl[i],mbrl[i+1]];
				};
				break;
		}
		(obj)?(dstMap.putObject(obj)):(echo(objRef[0]+'	'+objRef[1]+'	not found'));
		return rslt;
	};
	while(objRefArray.length>0){
		var objRef=objRefArray.pop();
		objRefArray=objRefArray.concat(ex(objRef));
	}
};

var src=openMap(srcMapName);
var dst=openMap(dstMapName);
exportRecurcive(src,dst,[exportObject]);
closeMap(dst);
closeMap(src);
man=0;
echo('press Enter');
WScript.stdIn.readLine();
