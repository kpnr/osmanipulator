var ws=WScript.createObject('WScript.Shell');
var ddnsurl='http://freedns.afraid.org/dynamic/update.php?dXZ4VTE4MzhhMlVpNmh2ZnhqRHVkc0dNOjExNjk4Mjcy';

function rebootRouter(){
	WScript.echo(''+(new Date())+' rebooting modem');
	var rq=WScript.createObject('WinHttp.WinHttpRequest.5.1');
	rq.open('GET','http://192.168.1.1/rebootinfo.cgi',false);
	var p=-1;
	try{
		rq.send();
		p=rq.status;
	}catch(e){
	};
	WScript.echo(''+(new Date())+' reboot status='+p);
	if(p==200) return;
	var rq=WScript.createObject('WinHttp.WinHttpRequest.5.1');
	WScript.echo(''+(new Date())+' rebooting router');
	rq.open('GET','http://192.168.1.3/index.cgi?res_cmd=6&res_buf=null&res_cmd_type=nbl&v2=y&rq=y',false);
	rq.setCredentials('admin','admin',0);//0 - server, 1 - proxy
	rq.setRequestHeader('Cookie','client_login=admin; client_password=admin; url_hash=');
	var p=-1;
	try{
		rq.send();
		p=rq.status;
	}catch(e){
	};
	WScript.echo(''+(new Date())+' reboot status='+p+' text='+((p>=0)?(rq.statusText):('unknown')));
	return;
/*	function activate(){
		var r=ws.appActivate('telnet.exe')||ws.appActivate('Telnet');
		return r;
	};

	function sendTelnetCh(s){
		for(var i=0;i<s.length;i++){
			WScript.sleep(300);
			if(!activate())return false;
			var p=s.charAt(i);
			ws.sendKeys(p);
		}
		return true;
	};
	function sendTelnet(s){
		WScript.sleep(1000);
		if(!activate())return false;
		ws.sendKeys(s);
		return true;
	};

	WScript.echo(''+(new Date())+'rebooting router');
	while(!activate()){
		WScript.echo(''+(new Date())+'starting telnet');
		ws.run('telnet',5,false);
		WScript.sleep(10000);
	}

	WScript.echo(''+(new Date())+'telnet activated');
	sendTelnet('open 192.168.1.1~');
	WScript.sleep(10000);
	sendTelnetCh('admin~');
	WScript.sleep(3000);	
	sendTelnetCh('admin~');
	while(sendTelnet('reboot~')){
		WScript.sleep(5000);
		sendTelnet('q~');
	};*/
};

var checkPeriod=60*1000;//ms units
var failCnt=0;
var pb=0;
var ddnsUpdate=0;
while(true){
	var rq=WScript.createObject('WinHttp.WinHttpRequest.5.1'),tStart=new Date();
	rq.open('HEAD','http://ya.ru',false);
	var p=-1;
	try{
		rq.send();
		p=rq.status;
	}catch(e){
	};
	if(p!=200)failCnt++;else failCnt=0;
	if(failCnt>0){
		ddnsUpdate=0;
		WScript.echo(((failCnt==1)?('\n'):(''))+(new Date())+'	fail count='+failCnt);
		if(failCnt>=5){
			rebootRouter();
			failCnt=0;
		};
	}else{
		WScript.stdOut.write(''+pb);
		pb++;if(pb>8)pb=0;
	}
	if(!ddnsUpdate){
		var rq=WScript.createObject('WinHttp.WinHttpRequest.5.1');
		rq.open('GET',ddnsurl,false);
		var p=-1;
		try{
			rq.send();
			p=rq.status;
		}catch(e){
		};
		if(p==200){
			WScript.stdOut.write('D');
			ddnsUpdate=60;//checkPeriod units
		}else{
			WScript.stdOut.write('d'+p+' ');
		}
	}else{
		ddnsUpdate--;
	}
	var st=(new Date())-tStart;
	st=checkPeriod-st;
	if(st>0)WScript.sleep(st);
};
