function include(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}};

var h=new(include('helpers.js'));
var hMap=h.mapHelper();
hMap.open('c:\\tmp\\htc\\chkt_e1.db3');
var mp=h.getMultiPoly('relation:1949879',hMap.map);
if(mp.poly){
	var nodeArr=mp.poly.getPolygons().toArray()[0].toArray()[0].toArray();
	var sx = 0, sy=0, sq=0, p0=nodeArr[0];
	for(var i=1; i<nodeArr.length; i++){
		var p=nodeArr[i],p1=nodeArr[i+1];
		var tsq=((p.lon-p0.lon)*(p1.lat-p0.lat)-(p1.lon-p0.lon)*(p.lat-p0.lat));
		if(!tsq)continue;
		var tx=(p0.lon+p.lon+p1.lon)/3, ty=(p0.lat+p.lat+p1.lat)/3;
		sx+=tx*tsq;
		sy+=ty*tsq;
		sq+=tsq;
	};
  var result=[sx/sq, sy/sq];
	h.echo('center at '+result[1]+','+result[0]);
};

