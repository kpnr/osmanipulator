function echo(s){
	WScript.Echo(''+s);
};
var reget=WScript.createObject('ReGetDx.ReGet2App');
var dls=reget.Downloads;
echo(typeof(dls));
var dls=dls.array.toArray();
echo(dls.toString());
var api=WScript.createObject('ReGetDx.ReGet2Api');
echo(typeof(api));
for(var i=0;i<dls.length;i++){
	var dl=api.downloadById(dls[i]);
	echo('download id='+dls[i]);
	echo('	Fn='+dl.fileName);
	echo('	state='+dl.State);
	echo('	size='+dl.size);
	echo('	loaded='+dl.downloaded);
	echo('	info='+dl.additionalInfo);
	echo('	shed='+dl.sheduled);
	echo('	support='+dl.reGetSupport);
	var prop=dl.properties.toArray();
	echo('props='+prop.toString());
	prop=dl.description.toArray();
	echo('url='+dl.value(1));

}
echo('press Enter');
WScript.stdIn.read(1);