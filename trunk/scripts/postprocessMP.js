//settings begin
var srcMpName='f:\\db\\osm\\sql\\route.mp';
var dstMpName='f:\\db\\osm\\sql\\routep.mp';
var noAddr=false;
var noPOI=false;
var noRouting=false;
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

//global variables
var h=new (include('helpers.js'))();
var echo=h.echo;
function echot(s,l,r){
	var d=new Date();
	function f(t){return (t>9)?(t):('0'+t)};
	echo(''+f(d.getYear()%100)+'.'+f(d.getMonth() + 1)+'.'+f(d.getDate())+' '+f(d.getHours())+':'+f(d.getMinutes())+':'+f(d.getSeconds())+' '+s,l,r);
}
//end global variables
function checkArgs(){
	function help(){
	echo('Postprocessing MP file before conversion to destination device format\n\
  Command line options:\n\
    /src:"src_mp_file_name.mp"\n\
    /dst:"dest_mp_file_name.mp"\n\
    /noaddr remove address info\n\
    /nopoi remove all POIs\n\
    /noroute remove routing data');
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('dst'))dstMpName=ar.item('dst')||dstMpName;
	if(ar.exists('src'))srcMpName=ar.item('src')||srcMpName;
	if(ar.exists('noaddr'))noAddr=true;
	if(ar.exists('nopoi'))noPOI=true;
	if(ar.exists('noroute'))noRouting=true;
	echo('Use config:\nsrc='+srcMpName);
	echo('dst='+dstMpName);
	echo('noaddr='+noAddr);
	echo('nopoi='+noPOI);
	echo('noroute='+noRouting);
	return true;
};

function processMP(src,dst){
	var curSection=[''], cnt=0;
	var reAddrInfo=/(StreetDesc|HouseNumber|CityName|RegionName|CountryName|Zip|City)=.*/i;
	var reRouteInfo=/(RoadID|RouteParams|Nod[0-9]+)=.*/i;
	while(!src.atEndOfStream){
		if(endOfSection)curSection.shift();
		var endOfSection=false;
		var l=src.readLine();
		cnt++;
		if(!l.length){
			dst.writeLine('');
			continue;
		};
		if(!(cnt&8191))echo(cnt,true);
		switch(l.charAt(0)){
			case ';':dst.writeLine(l);
				continue;
			case '[':
				if(l.substring(0,4)=='[END'){
					endOfSection=true;
				}else{
					curSection.unshift(l);
				};
				break;
		};
		switch(curSection[0]){
			case '[IMG ID]':
				if(noRouting &&(l=='Routing=Y'))dst.writeLine('Routing=N');else dst.writeLine(l);
				continue;
			case '[Restrict]':
				if(!noRouting)dst.writeLine(l);
				continue;
			case '[COUNTRIES]':;
			case '[REGIONS]':;
			case '[CITIES]':
				if(!noAddr)dst.writeLine(l);
				continue;
			case '[POI]':
				if(noPOI)continue;
			case '[POLYLINE]':;
				if(noRouting && reRouteInfo.test(l))continue;
			case '[POLYGON]':
				if(noAddr){
					if(reAddrInfo.test(l))continue;
					if(/Label=.*/i.test(l))dst.writeLine('DontFind=Y');
				}
				dst.writeLine(l);
				continue;
			default:
				dst.writeLine(l);
		};
		
	};
};

function main(){
	if(!checkArgs())return;
	echot('Opening mp');
	var src=h.fso.openTextFile(srcMpName,1,false,0);
	var dst=h.fso.openTextFile(dstMpName,2,true,0);
	processMP(src,dst);
	echot('Closing mp');
	src.close();
	dst.close();
	echot('All done.');
}

main();
//echo('press Enter');
//WScript.stdIn.readLine();
