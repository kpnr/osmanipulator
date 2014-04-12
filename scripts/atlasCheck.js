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
	var s='',bwl=[],awl=[],notFound=[],notClosed=[];
	if((!ar)||(!ar.name)){
		s='			empty region';
	}else{
		if(ar.areas && (ar.areas.length>0)){
			for(var i=0;i<ar.areas.length;i++)awl=awl.concat(checkBounds(ar.areas[i]));
		};
		echo(ar.name+'	',true,true);
		try{
			ar.bound=ar.bound.split(',');
			var cutter=h.polyIntersector(src);
			for(var i=0;i<ar.bound.length;i++){
				var ref=ar.bound[i],o=src.getObject(ref);
				ref=ref.split(':');
				if(ref[0]=='way'){
					if(!o){
						notFound.push(ar.bound[i]+' ref by ['+ar.name+']');
						continue;
					};
					o.tags.setByKey('osman:parent',ar.name);
					bwl.push(o);
				}else if(ref[0]=='relation'){
					o=src.getObject(ar.bound[i]);
					if(!o){
						notFound.push(ar.bound[i]+' ref by ['+ar.name+']');
						continue;
					};
					ref=cutter.buildWayList(o,true);//get ways ids
					for(var j=0;j<ref.length;j++){
						o=src.map.getWay(ref[j]);
						if(!o){
							notFound.push('way:'+ref[j]+' ref by ['+ar.name+' '+ar.bound[i]+']');
							continue;
						}
						o.tags.setByKey('osman:parent',ar.name+' '+ar.bound[i]);
						bwl.push(o);
					}
				};
			};
			//now check for closed polygons and nodes
			var clusters=cutter.mergeWayList(bwl),
				qNodeExist=src.map.storage.sqlPrepare('SELECT EXISTS(SELECT id FROM nodes_attr WHERE id=:id)');
			for(var i=clusters.length-1; i>=0; i--){
				var clust=clusters[i];
				if(clust.id1!=clust.idn){
					notClosed.push('node:'+clust.id1+',node:'+clust.idn);
				}else{
					//check is nodes exists
					for(var j=0;j<clust.ways.length;j++){
						var nds=clust.ways[j].nodes.toArray();
						for(var k=0; k<nds.length; k++){
							if(!src.map.storage.sqlExec(qNodeExist,':id',nds[k]).read(1).toArray()[0])notFound.push('node:'+nds[k]+' ref by way:'+clust.ways[j]);
						}
					}
				};
			};
		}catch(e){
			s='		fail. Exception['+e.name+']='+e.description+'\n';
		};
	};
	if(notFound.length || notClosed.length){
		failCnt++;
		if(notFound.length>0){
			s+='\n	not found objects:\n';
			for(var i=0;i<notFound.length;i++){s+='		'+notFound[i]+'\n'};
		};
		if(notClosed.length>0){
			s+='\n	not closed objects:\n';
			for(var i=0;i<notClosed.length;i++){s+='		'+notClosed[i]+'\n'};
		};
	}else{
		if(ar.areas && ar.areas.length){
			//do coverage test
			awl=awl.concat(bwl);
			awl.sort(function(a,b){return (a.id-b.id)});
			for(var i=awl.length-1;i>0;i--){
				if(awl[i].id==awl[i-1].id){
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
				s+=awl[i].id+' ref by ['+awl[i].tags.getByKey('osman:parent')+']\n';
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
