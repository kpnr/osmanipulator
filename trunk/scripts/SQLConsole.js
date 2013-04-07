//settings begin
var srcMapName='';
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

//global variables
var h=new (include('helpers.js'))();
var echo=h.echo,indexOf=h.indexOf;
function echot(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
}
//end global variables
function read(){
	return WScript.stdIn.readLine();
};

function checkArgs(){
	function help(){
	echo('SQL console for OSManipulator.\n\
  Command line options:\n\
    /src:"src_file_name.db3"');
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('src'))srcMapName=ar.item('src')||srcMapName;
	if(srcMapName){
		echo('Use config:');
		echo('src='+srcMapName);
		return true;
	}
	help();
	return false;
};

function help(){
	echo('\nConsole commands:\n\
  q to quit\n\
  j js_code to eval js_code.\n\
    You can use echo() function to display messages.\n\
  ? or h for this message\n\
Use back slash <\\> character at end of line for multiline commands.\n');
}
function main(){
	if(!checkArgs())return;
	echot('Opening map');
	var src=h.mapHelper(),cmd='';
	src.open(srcMapName);
	src.exec('PRAGMA cache_size=200000');
	help();
	while(1){
		echo('sql>',true,true);
		cmd+=read();
		try{
			if(cmd.slice(-1)=='\\'){
				cmd=cmd.slice(0,-1);
				continue;
			}else if(cmd=='q'){
				//end of session
				break;
			}else if(cmd.slice(0,2)=='j '){
				//js code
				echo('js result=<'+eval(cmd.slice(2))+'>');
			}else if(indexOf(['h','?','help'],cmd)>=0){
				help();
			}else if(cmd>''){
				//sql command
				var r=src.exec(cmd);
				if(!r.eos){
					var cn=r.getColNames().toArray(),i,rcnt=0;
					for(i=0;i<cn.length;i++)echo(cn[i]+'	',true,true);
					echo('');
					while(!r.eos){
						rcnt++;
						cn=r.read(1).toArray();
						for(i=0;i<cn.length;i++)echo(cn[i]+'	',true,true);
						echo('');
					};
					echo('ok. Total '+rcnt+' rows');
				}else{
					echo('ok');
				};
			};
		}catch(e){
			echo('Exception\n name='+e.name+'\n message='+e.message+'\n description='+e.description+'\n number='+e.number);
		};
		cmd='';
	};
	src.close();
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
