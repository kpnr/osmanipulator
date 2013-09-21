var cfg={
	countryDBName:'s:\\db\\osm\\sql\\rf.db3',
	areaFile:'atlas_cfg.js',
	boundBackupDir:'f:\\db\\osm\\sql\\bounds'
};
//settings end

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new (include('helpers.js'));
var man=h.man;
var gt=h.gt;
var echo=h.echo;
var passCnt=0,failCnt=0;
var src=h.mapHelper();
src.open(cfg.countryDBName,false,true);

function checkBounds(ar){
	var bbhm=h.mapHelper();
	var bpoly=0,s='',bwl=[],awl=[];
	if((!ar)||(!ar.name)){
		s='			empty region';
	}else{
		if(ar.areas && (ar.areas.length>0)){
			for(var i=0;i<ar.areas.length;i++)awl=awl.concat(checkBounds(ar.areas[i]));
		};
		bbhm.open(h.fso.buildPath(cfg.boundBackupDir,ar.name+'.db3'));
		echo(ar.name+'	',true,true);
		try{
			ar.bound=ar.bound.split(',');
			bpoly=h.getMultiPoly(ar.bound,src.map,bbhm.map);
			if(bpoly.poly){
				if(bpoly.usedMap.storage.dbName!=src.map.storage.dbName){
					s+='	ok in '+bpoly.usedMap.storage.dbName;
				}
			};
			var cutter=h.polyIntersector(bbhm);
			for(var i=0;i<ar.bound.length;i++){
				var ref=ar.bound[i].split(':');
				if(ref[0]=='way'){
					bwl.push(parseFloat(ref[1]));
				}else if(ref[0]=='relation'){
					bwl=bwl.concat(cutter.buildWayList(bbhm.getObject(ar.bound[i]),true));
				};
			};
		}catch(e){
			s='		fail. Exception['+e.name+']='+e.description+'\n';
		};
		bbhm.close();
	};
	if(!bpoly){
		failCnt++;
	}else if(!bpoly.poly){
		failCnt++;
		if(bpoly.notFoundRefs.length>0){
			s+='\n	not found objects:\n';
			for(var i=0;i<bpoly.notFoundRefs.length;i++){s+='		'+bpoly.notFoundRefs[i]+'\n'};
		};
		if(bpoly.notClosedRefs.length>0){
			s+='\n	not closed objects:\n';
			for(var i=0;i<bpoly.notClosedRefs.length;i++){s+='		'+bpoly.notClosedRefs[i]+'\n'};
		};
		if((bpoly.notFoundRefs.length==0)&&(bpoly.notClosedRefs.length==0)){
			s+='\n	object is empty\n';
		};
	}else{
		if(ar.areas && ar.areas.length){
			//do coverage test
			awl=awl.concat(bwl);
			awl.sort(function(a,b){return (a-b)});
			for(var i=awl.length-1;i>0;i--){
				if(awl[i]==awl[i-1]){
					i--;
					awl.splice(i,2);
				};
			};
		}else{
			awl=[];
		};
		if(awl.length){
			s+='		fail subarea cover test. Not covered ways:\n';
			for(var i=0;i<awl.length;i++){
				s+=awl[i]+'\n';
			};
			failCnt++;
		}else{
			passCnt++;
		}
	};
	echo(s,!s);
	return bwl;
};

var arcfg=include(cfg.areaFile);
checkBounds(arcfg);
src.close();
WScript.echo('all done. '+passCnt+' of '+(passCnt+failCnt)+' passed.');
