var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

function echo(s){
	WScript.StdOut.write(s);
};

myLogger={
	log:function(msg){
		echo(msg);
	}
}
var man=WScript.createObject('OSMan.Application');
man.logger=myLogger;
man.log('test it!');
echo('\r\npress `Enter`');
WScript.StdIn.Read(1);