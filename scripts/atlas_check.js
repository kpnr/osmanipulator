var cfg={
	countryDBName:'',
	areaFile:'',
	boundBackupDir:'e:\\db\\osm\\sql\\bounds'
};
//settings end

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new (include('helpers.js'));
var man=h.man;
var gt=h.gt;
var echo=h.echo, echot=h.echot;
var passCnt=0,failCnt=0;

function checkArgs(){
	function help(){
	echo('Command line options:\n\
\t/src:"source_database_name"\n\
\t/atlas:"atlas_file_name"');
	};
	var ar=WScript.arguments;
	if(!ar.length){
		help();
		return false;
	};
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('atlas'))cfg.areaFile=ar.item('atlas');
	if(ar.exists('src'))cfg.countryDBName=ar.item('src');
	echo('Use config:\natlas='+cfg.areaFile+'\nsrc='+cfg.countryDBName);
	if(!(cfg.areaFile && cfg.countryDBName)){
		help();
		echo('\nInvalid arguments. Exiting');
		return false;
	};
	return true;
};

if(!checkArgs())WScript.quit(1);
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
			bpoly=h.getMultiPoly(ar.bound,src.map/*,bbhm.map*/);
			if(bpoly.poly){
				if(bpoly.usedMap.storage.dbName!=src.map.storage.dbName){
					s+='	ok in '+bpoly.usedMap.storage.dbName;
				}
			};
			var cutter=h.polyIntersector(src);
			for(var i=0;i<ar.bound.length;i++){
				var ref=ar.bound[i].split(':');
				if(ref[0]=='way'){
					bwl.push(parseFloat(ref[1]));
				}else if(ref[0]=='relation'){
					bwl=bwl.concat(cutter.buildWayList(src.getObject(ar.bound[i]),true));
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

function checkNames(ar){
	checkNames.arNames=checkNames.arNames || [];
	if(h.indexOf(checkNames.arNames,ar.name)<0){
		checkNames.arNames.push(ar.name);
		if(ar.areas && (ar.areas.length>0)){
			for(var i=0;i<ar.areas.length;i++){
				var ari=ar.areas[i];
				if(!ari || !ari.name || !ari.bound){
					echo('Empty or invalid subarea in '+ar.name+'/'+i);
				}else{
					checkNames(ari);
				}
			};
		};
	}else{
		echo('Duplicated name <'+ar.name+'>');
	};
}
var arcfg=include(cfg.areaFile);
echot('Checking names');
checkNames(arcfg);
echot('Checking bounds integrity');
checkBounds(arcfg);
src.close();
echot('all done. '+passCnt+' of '+(passCnt+failCnt)+' passed.');
