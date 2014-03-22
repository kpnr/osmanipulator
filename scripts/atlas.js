/*Available processing flags:
bitlevel:nn
	nn in [8...32]. Do bitRound preprocess with preprocessMP.js /bitlevel:nn
convert:0|1
	Convert into mp-file without routing
keepFile:0|1
	Do not delete database file after processing
route:0|1
	Convert into invisible routing-only mp-file.
ttable:0|1
	Translate UTF-8 tag values into ANSI charmap with preprocessMP.js
*/
//settings begin
var cfg={
	countryDBName:'',
	areaFile:'',
	boundBackupDir:'e:\\db\\osm\\sql\\bounds',
	workDir:'e:\\db\\osm\\regions',
	outDir:'e:\\db\\osm\\out',
	maxTasks:3,
	cmd_mp_no_rt:'e:\\db\\cvt\\mp_no_rt.bat',//OSM2MP.PL require package LWP::Protocol::https
	cmd_mp_rt:'e:\\db\\cvt\\mp_rt.bat'
};
//settings end

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new (include('helpers.js'))();
var man=h.man;
var gt=h.gt;
var echo=h.echo;
var echot=h.bindFunc(h,h.echot);
var timeStats={};

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

function jsonSave(o,fn){
	var fs=WScript.createObject('Scripting.FileSystemObject');
	var f=fs.openTextFile(fn,2,true);
	function echo(s){f.write(s)};
	function writeVar(o){
		switch(typeof o){
		case 'object':
			if(o instanceof Array){
				echo('[');
				for(var i=0;i<o.length;i++){
					writeVar(o[i]);
					echo((i==o.length-1)?(''):',');
				};
				echo(']');
			}else{
				echo('{');
				var first=true;
				for(var i in o){
					echo(((first)?(''):(','))+i+':');
					first=false;
					writeVar(o[i]);
				};
				echo('}');
			};
			break;
		case 'string':
			o='\''+o.replace(/\\/g,'\\\\').replace(/\'/g,'\\\'')+'\'';
		case 'number':;
		case 'boolean':;
			echo(o);
			break;
		default:
			echo('type='+typeof(o));
			break;
	};
};
writeVar(o);
f.close();
};

function genTasks(){
	function genTaskSequence(taskArray){
		var rs=taskArray[0],r=rs;
		for(var i=1;i<taskArray.length;i++){
			r.tasks=r.tasks||[];
			r.tasks=((taskArray[i] instanceof Array)?(taskArray[i]):([taskArray[i]])).concat(r.tasks);
			r=r.tasks[0];
		};
		return rs;
	};
	function genAreas(a,srcFile){
		var rs=[];
		if(a.areas && a.areas.length){
			var tl=[],arlist=[];
			for(var i=0;i<a.areas.length;i++){
				var ai=a.areas[i];
				ai.country = ai.country || a.country;
				ai.region = ai.region || a.region;
				echot('genAreas for '+ai.name);
				var ali={ref:ai.bound.split(','),name:ai.name};
				//generate names for files
				var dstDBName=cfg.workDir+'\\'+ai.name,
					dstOSMName=cfg.outDir+'\\'+ai.name,
					mpFileName=dstOSMName+'.mp',
					nmFileName=dstOSMName+'.nm2',
					rtDBName=cfg.workDir+'\\rt_'+ai.name,
					rtOSMName=cfg.outDir+'\\rt_'+ai.name,
					rtMPName=rtOSMName+'.mp',
					rtNMName=rtOSMName+'.nm2',
					boundPolyName=dstDBName+'_b.mp',
					sOSM2MPpars=((ai.country)?('--defaultcountry='+ai.country):(' '))+((ai.region)?(' --defaultregion='+ai.region):(''));
				dstDBName+='.db3';
				dstOSMName+='.osm';
				rtDBName+='.db3';
				rtOSMName+='.osm';
				if(!ai.flags)ai.flags={};
				var ti=[
					{task:'areaCut.js',cmdline:'/src:"'+srcFile+'" /dst:"'+dstDBName+'" /bound:'+ai.bound+' /xml /alreadyimported'},
					{task:'preprocessMP.js',cmdline:'/dst:"'+dstDBName+'"'+((ai.flags.bitlevel)?(' /bitlevel:'+ai.flags.bitlevel):(''))+((ai.flags.ttable)?(''):(' /nottable'))}
				];
				if(ai.flags.route){
					var ers=[
						{task:'exportRouting.js',cmdline:'/src:"'+dstDBName+'" /dst:"'+rtDBName+'"',afterEnd:'v.'+ai.name+'--'},
						{task:'exportOSM.js',cmdline:'/src:"'+rtDBName+'" /dst:"'+rtOSMName+'"'},
						{task:cfg.cmd_mp_rt,cmdline:'"'+rtOSMName+'" "'+rtMPName+'" "'+sOSM2MPpars+'"'},
						{task:'mp2nm.js',cmdline:'/src:"'+rtMPName+'" /dst:"'+rtNMName+'"'}
						];
					if(!ai.flags.keepFile){
						ers.push({task:'%ComSpec%',cmdline:'/C del "'+rtDBName+'"'});
					};
					ti.push(genTaskSequence(ers));
				};
				if(ai.flags.convert){
					ti.push({task:'exportOSM.js',cmdline:'/src:"'+dstDBName+'" /dst:"'+dstOSMName+'"'});
					ti.push({task:'exportPolyFile.js',cmdline:'/src:"'+dstDBName+'" /dst:"'+boundPolyName+'" /refs:"'+ai.bound+'"'});
					ti.push({task:cfg.cmd_mp_no_rt,cmdline:'"'+dstOSMName+'" "'+mpFileName+'" "'+sOSM2MPpars+'"'});
					ti.push({task:'mp2nm.js',cmdline:'/src:"'+mpFileName+'" /dst:"'+nmFileName
					/*
					do not use map cover poly
					+'" /bound:"'+boundPolyName+'"'*/
					});
					ti.push({task:'%ComSpec%',cmdline:'/C del "'+boundPolyName+'"'});
				};
				ti[ti.length-1].afterEnd='v.'+a.name+'--';
				if(ai.areas && ai.areas.length){
					ti.push(genAreas(ai,dstDBName))
				}else if(!ai.flags.keepFile){
					ti.push({task:'%ComSpec%',cmdline:'/C del "'+dstDBName+'"',beforeStart:'!((\''+ai.name+'\' in v)?(v.'+ai.name+'):(v.'+ai.name+'=0))'});
				}
				arlist.push(ali);
				if(ti.length)tl.push(genTaskSequence(ti));
			};
			var listFileName=cfg.workDir+'\\list_'+Math.random()+'.lst';
			jsonSave(arlist,listFileName);
			tl.unshift({task:'%ComSpec%',cmdline:'/C del "'+listFileName+'"'});
			if(!a.flags.keepFile){
				tl.push({task:'%ComSpec%',cmdline:'/C del "'+srcFile+'"',beforeStart:'!v.'+a.name});
			};
			rs.push(genTaskSequence([
				{task:'exportListDb.js',cmdline:'/dst:"'+cfg.workDir+'" /src:"'+srcFile+'" /lst:"'+listFileName+'" /bbakdir:"'+cfg.boundBackupDir+'"',beforeStart:'v.'+a.name+'='+(a.areas.length||0)},
				tl
			]));
		};
		return rs
	};
	var arcfg=include(cfg.areaFile),l=(arcfg.areas)?(arcfg.areas.length):(0),i,r;
	if((l>1)&&(cfg.maxTasks>1)){
		var ar=arcfg.areas,st=0,r=[];
		for(i=1;st<l;i+=i){
			arcfg.areas=ar.slice(st,st+i);
			st+=i;
			r=r.concat(genAreas(arcfg,cfg.countryDBName));
		};
	}else{
		r=genAreas(arcfg,cfg.countryDBName);
	};
	return r;
};

function execTasks(tasks){
	var taskQueue=[],activeTasks=[],cntTask=0,cntDone=0,failedTasks=[];
	var v={};//global task variable
	function countTasks(ts){
		var r=ts.length||0;
		for(var i=0;i<ts.length;i++){
			if(ts[i].tasks)r+=countTasks(ts[i].tasks);
		};
		return r;
	};
	function checkFinished(){
		for(var i=activeTasks.length-1;i>=0;i--){
			var at=activeTasks[i]
			if(at.app.status==1){
				echot('done PID='+at.app.processId+((at.app.exitCode)?(' fail'):(' ok'))+'\n\ttasks '+(++cntDone)+' of '+cntTask);
				var upTime=(new Date())-at.startTime;
				if(at.app.exitCode){
					failedTasks.push(at.task+' '+at.cmdline+'\n\texit code='+at.app.exitCode+' upTime='+(upTime/1000).toFixed(1));
				};
				if(!timeStats[at.task])timeStats[at.task]=0;
				timeStats[at.task]+=upTime;
				try{
					if(at.afterEnd){
						eval(at.afterEnd);
						//WScript.echo('afterEnd handler. Task='+at.task+' '+at.cmdline+'. Script='+at.afterEnd);
					};
				}catch(e){
					echot('Exception in afterEnd handler. Task='+at.task+' '+at.cmdline+'. Message='+e.description);
				}
				activeTasks.splice(i,1);
				if((at.app.exitCode==0)&&at.tasks)taskQueue=at.tasks.concat(taskQueue);
			};
		};
	};
	function execTask(task){
		echot('exec '+task.task+' '+task.cmdline);
		try{
			task.app=gt.exec(task.task+' '+task.cmdline);
			echo('	ok. PID='+task.app.processId);
			task.startTime=new Date();
			activeTasks.push(task);
			WScript.sleep(1000);
		}catch(e){
			failedTasks.push(task.task+' '+task.cmdline+'\n\texit code=<not started> upTime=<none>');
			echo('	fail. Message='+e.description);
		};
	};
	for(var i=0;i<tasks.length;i++){
		taskQueue.push(tasks[i]);
	};
	cntTask=countTasks(tasks);
	while((taskQueue.length+activeTasks.length)>0){
		checkFinished();
		var i=taskQueue.length
		while((activeTasks.length<cfg.maxTasks)&&(i>0)){
			var tsk=taskQueue.shift();
			i--;
			if(tsk.beforeStart)try{
				//WScript.echo('beforeStart handler. Task='+tsk.task+' '+tsk.cmdline+'. Script='+tsk.beforeStart);
				if(!eval(tsk.beforeStart)){
					taskQueue.push(tsk);
					tsk=false;
				}
			}catch(e){
				echo('Exception in beforeStart handler. Task='+tsk.task+' '+tsk.cmdline+'. Message='+e.description);
				tsk=false;
			};
			if(tsk)execTask(tsk);
		};
		if((activeTasks.length==0)&&(taskQueue.length>0)){
			echot('Can`t activate next task. Task var:');
			varDump(v);
			echo('Task list:');
			for(i=0;i<taskQueue.length;i++){
				echo('  '+taskQueue[i].task+'\n    '+taskQueue[i].cmdline+'\n      '+taskQueue[i].beforeStart);
			};
			break;
		};
		WScript.sleep(1000);
	};
	if(failedTasks.length>0)echo('\nFailed tasks list:');
	for(var i=0;i<failedTasks.length;i++){
		echo(failedTasks[i]);
	};
};

function varDump(o,s){
	var n;
	s=s||'';
	n=typeof(o);
	echo(s+'<'+n+'>'+((n!='object')?(o):('')));
	for(n in o){
		echo(s+n);
		varDump(o[n],s+' ');
	};
}

if(!checkArgs()){
	WScript.quit(1);
};
var tasks=genTasks();
//jsonSave(tasks,'c:\\tmp\\cfg.js');
execTasks(tasks);
echo('Task timing stats:');
var totalT=0,i,sortedStats=[];
for(i in timeStats){
	totalT+=timeStats[i];
	sortedStats.push({k:i,v:timeStats[i]});
}
sortedStats.sort(function(a,b){return (a.v-b.v)});
for(i=0;i<sortedStats.length;i++){
	echo(sortedStats[i].k+'	_	_	'+(sortedStats[i].v/totalT*100).toFixed(3));
};

//WScript.echo('Tasks:');
