function IniFile(){
	this.data=[];
	this.fname=false;
};

IniFile.prototype.fso=WScript.createObject('Scripting.FileSystemObject');

IniFile.prototype.read=function(fname,useUnicode){
	if(!fname)fname=this.fname;else this.fname=fname;
	var ini=this.fso.openTextFile(fname,1,true,(typeof(useUnicode)=='undefined')?(-1):((useUnicode)?(-1):(0)));
	var r=[];
	try{
		while(!ini.atEndOfStream){
			var s=ini.readLine();
			var i=s.indexOf('=');
			if(i<1)continue;
			r[s.substr(0,i)]=s.substr(i+1);
		};
	}finally{
		ini.close();
	};
	this.data=r;
	return r;
};

IniFile.prototype.write=function(fname,iniArray){
	if(!fname)fname=this.fname;else this.fname=fname;
	if(!iniArray)iniArray=this.data;
	var ini=this.fso.openTextFile(fname,2,true,-1);
	try{
		for(var i in iniArray){
			ini.writeLine(''+i+'='+iniArray[i]);
		};
	}finally{
		ini.close();
	};
};

IniFile;