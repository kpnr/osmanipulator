//settings start
var scriptIniFile='F:\\db\\osm\\snapdl.ini';
var scriptCfgFile='F:\\db\\osm\\snapdl.cfg';
//settings end

//reget download states:
//0 - waiting
//3 - paused
//4 - complete
//5 - downloading

//reget download property IDs:
//1 - url

//Tristate constants:
//TristateFalse = 0
//TristateMixed = -2
//TristateTrue = -1
//TristateUseDefault = -2

function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var osmSeqRoot,regetDlDir,snapshotDir,dl=new (include('reget.js')),Ini=include('inifile.js');

function echo(s){
	WScript.Echo(''+s);
};

function leadZero(value,len){
	var r=''+value;
	while(r.length<len)r='0'+r;
	return r;
}

function addSnapshot(seqNo){
	var p=leadZero(Math.floor(seqNo/1000000),3);
	var url=osmSeqRoot+p+'/';
	p=leadZero(Math.floor(seqNo/1000) % 1000,3);
	url+=p+'/';
	p=leadZero(seqNo % 1000,3)+'.osc.gz';
	url+=p;
	dl.addDlFile(url);
};

function deleteFile(fname){
	var fso=WScript.createObject('Scripting.FileSystemObject');
	if(fso.fileExists(fname)){
		fso.deleteFile(fname);
	};
};

function main(){
	var ini=new Ini();
	ini.read(scriptIniFile);
	var cfg=new Ini();
	cfg.read(scriptCfgFile);
	osmSeqRoot=cfg.data['osmSeqRoot'];
	regetDlDir=cfg.data['regetDlDir'];
	snapshotDir=cfg.data['snapshotDir'];
	deleteFile(regetDlDir+'state.txt');
	var stateDl=dl.addDlFile(osmSeqRoot+'state.txt');
	var startT=new Date();
	while((stateDl.state!=4) && (((new Date())-startT)<1000*60*10)){
		WScript.sleep(1000*1);
	};
	if(stateDl.state==4){
		echo('State.txt loaded');
		//add new snapshots into DlList
		var r=new Ini();
		r.read(regetDlDir+'state.txt',false);
		var maxSeqNo=parseInt(r.data['sequenceNumber']);
		echo('MaxSeqNo='+maxSeqNo);
		if(!isNaN(maxSeqNo)){
			var curSeqNo=parseInt(ini.data['lastSequenceNumber']);
			if(isNaN(curSeqNo))curSeqNo=0;
			echo('curSeqNo='+curSeqNo);
			for(var i=curSeqNo+1;i<=maxSeqNo;i++){
				addSnapshot(i);
			};
			ini.read();
			ini.data['lastSequenceNumber']=maxSeqNo;
			ini.write();
		};
	}else{
		echo('State download timeout');
	};
	dl.deleteDl(stateDl);
	//proceed ready snapshots
	var dls=dl.getDlList();
	echo('processing DlList.'+(dls.length)+' files total');
	for(var i=0;i<dls.length;i++){
		var dlf=dls[i];
		var url=dlf.value(1);
		echo(url);
		if((url.indexOf(osmSeqRoot)==0)){
			if(url.indexOf('state.txt')<0){
				echo('check...');
				var path=url.substr(osmSeqRoot.length);// [rootPath/]000/111/111.tar.gz
				var seqNo=path.substr(0,3)+path.substr(4,3)+path.substr(8,3);
				var ext=path.substr(12);
				switch(dlf.state){
				case 4:
					//download comlete. Move to snapshot dir
					echo(path+' loaded');
					var fso=WScript.createObject('Scripting.FileSystemObject');
					fso.copyFile(dlf.fileName,snapshotDir+seqNo+'.'+ext);
					deleteFile(dlf.fileName);
					//delete from DlList
					dl.deleteDl(dlf);
					break;
				case 6:
				case 3:
					dlf.startDownload();
					echo(path+' restarted');
					break;
				case 0:
				case 5:
					echo('load in progress');
					break;
				
				default:
					echo('unknown state '+dlf.state+ ' info='+dlf.additionalInfo );
					break;
				}
			}else{
				dl.deleteDl(dlf);
			}
		};
	};
};

main();