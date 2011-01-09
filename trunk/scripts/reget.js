//reget download states:
//0 - waiting
//3 - paused
//4 - complete
//5 - downloading

//reget download property IDs:
//1 - url
function Reget(){
	var t=this;
	t.api=false;
	t.app=false;
};

Reget.prototype.getApp=function(){
	var t=this;
	if(!t.app)t.app=WScript.createObject('ReGetDx.ReGet2App');
	return t.app;
};

Reget.prototype.getApi=function(){
	var t=this;
	if(!t.api)t.api=WScript.createObject('ReGetDx.ReGet2Api');
	return t.api;
};

Reget.prototype.addDlFile=function(url){
	return (this.getApp().createDownload(url,true));
};

Reget.prototype.getDlList=function(){//returns array of IReget2Download
	var api=this.getApi(),dls=this.getApp().downloads.array.toArray(),r=[];
	for(var i=0;i<dls.length;i++){
		r[i]=api.downloadById(dls[i]);
	};
	return r;
};

Reget.prototype.deleteDlById=function(dlId){
	this.getApp().deleteDownload(dlId);
};

Reget.prototype.deleteDl=function(iDownload){
	this.deleteDlById(iDownload.id);
};

Reget.prototype.clearDlList=function(){
	var dls=this.getDlList();
	for(var i=0;i<dls.length;i++){
		if(dls[i].State==4)this.deleteDl(dls[i]);
	};
};

Reget.prototype.close=function(){
	try{
		this.getApi().close();
	}catch(e){
	};
};

Reget;