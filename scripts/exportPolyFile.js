//settings begin
var polyRefs='';
var srcMapName='';
var dstPolyName='';
var oneRing=false;
var mpHeader='\
[IMG ID]\n\
CodePage=1251\n\
LblCoding=9\n\
ID=\n\
Name=\n\
TypeSet=Navitel\n\
Elevation=M\n\
Preprocess=F\n\
TreSize=511\n\
TreMargin=0.00000\n\
RgnLimit=127\n\
POIIndex=Y\n\
POINumberFirst=Y\n\
POIZipFirst=Y\n\
Levels=2\n\
Level0=24\n\
Level1=15\n\
Zoom0=0\n\
Zoom1=5\n\
[END-IMG ID]\n\n\
[POLYGON]\n\
Type=0x4b\n\
EndLevel=4\n\
Background=Y\n\
DontFind=Y\
';
//settings end
function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}

var h=new(include('helpers.js'))();
var echo=h.echo;

function checkArgs(){
	function help(){
	echo('Multipolygon export to polish mp file\n\
  Command line options:\n\
    /src:"src_file_name.db3"\n\
    /dst:"dest_file_name.mp"\n\
    /refs:"relation:18,way:12"\n'
    /*/onering:merge polygons into one'*/);
	};
	var ar=WScript.arguments;
	ar=ar.named;
	if(ar.exists('help')||ar.exists('?')||ar.exists('h')){
		help();
		return false;
	};
	if(ar.exists('dst'))dstPolyName=ar.item('dst')||dstPolyName;
	if(ar.exists('src'))srcMapName=ar.item('src')||srcMapName;
	if(ar.exists('refs'))polyRefs=ar.item('refs')||polyRefs;
	oneRing=ar.exists('onering');
	if(dstPolyName && srcMapName && polyRefs){
		echo('Use config:\nsrc='+srcMapName);
		echo('dst='+dstPolyName);
		echo('refs='+polyRefs);
		//echo('onering='+oneRing);
		return true;
	}
	help();
	return false;
};

function centroid(nodes,centroid_node){
	var clat=0,clon=0,a=0;
	var lat1=nodes[0].lat,lon1=nodes[0].lon,lat,lon;
	for(var i=0;i<nodes.length-1;i++){
		lat=lat1;lon=lon1;
		lat1=nodes[i+1].lat;lon1=nodes[i+1].lon;
		var m=lon*lat1-lon1*lat;
		clat+=(lat+lat1)*m;
		clon+=(lon+lon1)*m;
		a+=m;
	};
	clon/=3*a;
	clat/=3*a;
	centroid_node.lat=clat;
	centroid_node.lon=clon;
	return centroid_node;
};

function mergeRings(rings){
	var rs=rings[0].concat(rings[1]);
	var r0=rs[0];
	for(var i=1;i<rs.length;i++){
		var r1=rs[i],cr0=centroid(r0,{}),cr1=centroid(r1,{});
		
	};
};

function main(){
	if(!checkArgs())return;
	var src=h.mapHelper();
	echo('opening source map');
	src.open(srcMapName,false,true);
	try{
		echo('creating destination file');
		var dst=h.fso.createTextFile(dstPolyName,true);
		
		function writePoly(nodes){
			dst.write('Data0=');
			for(var i=1/*skip first node to avoid "duplicated nodes warning"*/;i<nodes.length;i++){
				dst.write(((i-1)?(',('):('('))+nodes[i].lat.toFixed(7)+','+nodes[i].lon.toFixed(7)+')');
			};
			dst.writeLine('');
		};
		
		polyRefs=polyRefs.split(',');
		echo('creating multipoly object');
		var mpoly=h.gt.createPoly();
		for(var i=0;i<polyRefs.length;i++){
			var mo=src.getObject(polyRefs[i]);
			if(!mo){
				echo('Object '+polyRefs[i]+' not found. Exiting.');
				return false;
			};
			mpoly.addObject(mo);
		};
		if(!mpoly.resolve(src.map)){
			echo('Multipolygon not resolved. Exiting.');
			return false;
		};
		var pa=mpoly.getPolygons().toArray(),c=1;
		pa[0]=pa[0].toArray();pa[1]=pa[1].toArray();
		for(var i=0;i<pa[0].length;i++,c++)pa[0][i]=pa[0][i].toArray();
		for(var i=0;i<pa[1].length;i++,c++)pa[1][i]=pa[1][i].toArray();
		dst.writeLine(mpHeader);
		for(var i=0;i<pa.length;i++){
			for(var j=0;j<pa[i].length;j++){
				writePoly(pa[i][j]);
			};
		};
		dst.writeLine('[END]');
		/*if(oneRing){
			pa=[[mergeRings(pa)],[]];
		};
		dst.writeLine(h.fso.getBaseName(dstPolyName));
		for(var i=0;i<pa[0].length;i++,c++){
			var na=pa[0][i];
			dst.writeLine(c);
			for(var n=0;n<na.length;n++){
				dst.writeLine(' '+na[n].lon.toFixed(7)+' '+na[n].lat.toFixed(7));
			};
			dst.writeLine('END');
		};
		for(var i=0;i<pa[1].length;i++,c++){
			var na=pa[1][i];
			dst.writeLine('!'+c);
			for(var n=0;n<na.length;n++){
				dst.writeLine(' '+na[n].lon.toFixed(7)+' '+na[n].lat.toFixed(7));
			};
			dst.writeLine('END');
		};
		dst.writeLine('END');*/
		dst.close();
	}finally{
		src.close();
	}
	echo('all done.');
};

try{
	main();
}catch(e){
	echo('Exception name='+e.name+' message='+e.message+' description='+e.description+' number='+e.number);
	echo('press Enter');
	WScript.stdIn.readLine();
	WScript.quit(1);
};
