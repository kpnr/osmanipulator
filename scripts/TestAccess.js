var re=/wscript/i;
if (WScript.FullName.search(re)>=0){
	var sh=WScript.CreateObject('WScript.Shell');
	WScript.Quit(sh.Run('CScript '+WScript.ScriptFullName,1,true));
};

function echo(s){
	WScript.Echo(s);
};

function testFileReader(){
	var fr1=man.createObject('FileReader');
	echo('FileReader short='+fr1.toString());

	var fr2=man.createObject('OSMan.FileReader');
	echo('FileReader  full='+fr2.toString());
	
	fr1.open(testFileName);
	var sz=0;
	while(!fr1.eos){
		var buf=fr1.read(80);
		sz+=80;
	}
	fr1=false;
	echo('File Reader done. Size about '+sz);
	
	var d=new Date();
	var n=100000;
	for(var i=0;i<n;i++){
		fr1=man.createObject('OSMan.FileReader');
	}
	d=(new Date())-d;
	echo(''+n+' readers are created in '+d+'ms. Rate='+Math.round(1000*n/d)+' obj/sec');

	d=new Date();
	for(var i=0;i<n;i++){
		var k=fr1.eos?'y':'n';
	}
	d=(new Date())-d;
	echo(''+n+' prop reads done in '+d+'ms. Rate='+Math.round(1000*n/d)+' reads/sec');
};

function createUnBZ2(){
	var fr=man.createObject('FileReader');
	echo('FileReader='+fr.toString());
	fr.open(testFileName);
	var ubz=man.createObject('UnBZ2');
	echo('UnBZ2='+ubz.toString());
	ubz.setInputStream(fr);
	return ubz;
};

function testUnBZ2(){
	echo('test UnBZ');
	var ubz=createUnBZ2();
	var sz=0;
	var bufSz=512;
	var d=new Date();
	while(!ubz.eos){
		ubz.read(bufSz);
		sz+=bufSz;
	};
	d=(new Date())-d;
	echo('Decompressed size about '+sz+' bytes in '+d+' ms. Rate='+Math.round(sz/d)+'kb/s');
};

function testUnGZ(){
	var d=new Date();
	echo('test UnGZ');
	var fr=man.createObject('FileReader');
	fr.open(fso.buildPath(testFileDir,'test.gz'));
	echo('FileReader='+fr.toString());
	var gz=man.createObject('UnGZ');
	echo('UnGZ='+gz.toString());
	gz.setInputStream(fr);
	var rd=man.createObject('OSMReader');
	echo('OSMReader='+rd.toString());
	rd.setInputStream(gz);
	var map=man.createObject('Map');
	echo('Map='+map.toString());
	rd.setOutputMap(map);
	var stg=man.createObject('Storage');
	echo('Storage='+stg.toString());
	stg.dbName=fso.buildPath(testFileDir,'test.db3');
	map.storage=stg;
	rd.read(0);
	d=(new Date())-d;
	echo('File parsed in '+d+'ms');
}

function testFileWriter(){
	var d=new Date();
	echo('Test FileWriter');
	var fw=man.createObject('FileWriter');
	echo('FileWriter='+fw.toString());
	fw.open(fso.buildPath(testFileDir,'test.osm'));
	var ow=man.createObject('OSMWriter');
	echo('OSMWriter='+ow.toString());
	ow.setOutputStream(fw);
	var map=man.createObject('Map');
	echo('Map='+map.toString());
	ow.setInputMap(map);
	var stg=man.createObject('Storage');
	echo('Storage='+stg.toString());
	stg.dbName=fso.buildPath(testFileDir,'test.db3');
	map.storage=stg;
	ow.write(0);
	map.storage=0;
	stg.dbName='';
	fw=ow=map=stg=0;
	d=(new Date())-d;
	echo('File exported in '+d+'ms');
}

function testOSMReader(){
	echo('test OSMReader');
	var d=new Date();
	var ubz=createUnBZ2();
	var reader=man.createObject('OSMReader');
	echo('OSMReader='+reader.toString());
	var map=man.createObject('Map');
	var stg=man.createObject('Storage');
	stg.dbName=fso.buildPath(testFileDir,'test.db3');
	map.storage=stg;
	map.initStorage();
	echo('Map='+map.toString());
	reader.setInputStream(ubz);
	reader.setOutputMap(map);
	reader.read(0);
	d=(new Date)-d;
	echo('File parsed in '+d+'ms');
	map.storage=0;
	stg.dbName='';
	ubz=reader=map=stg=0;
};

function testDBFReader(){
/*
Code-Page Identifiers
Identifier Name 
037 IBM EBCDIC - U.S./Canada 
437 OEM - United States 
500 IBM EBCDIC - International  
708 Arabic - ASMO 708 
709 Arabic - ASMO 449+, BCON V4 
710 Arabic - Transparent Arabic 
720 Arabic - Transparent ASMO 
737 OEM - Greek (formerly 437G) 
775 OEM - Baltic 
850 OEM - Multilingual Latin I 
852 OEM - Latin II 
855 OEM - Cyrillic (primarily Russian) 
857 OEM - Turkish 
858 OEM - Multlingual Latin I + Euro symbol 
860 OEM - Portuguese 
861 OEM - Icelandic 
862 OEM - Hebrew 
863 OEM - Canadian-French 
864 OEM - Arabic 
865 OEM - Nordic 
866 OEM - Russian 
869 OEM - Modern Greek 
870 IBM EBCDIC - Multilingual/ROECE (Latin-2) 
874 ANSI/OEM - Thai (same as 28605, ISO 8859-15) 
875 IBM EBCDIC - Modern Greek 
932 ANSI/OEM - Japanese, Shift-JIS 
936 ANSI/OEM - Simplified Chinese (PRC, Singapore) 
949 ANSI/OEM - Korean (Unified Hangeul Code) 
950 ANSI/OEM - Traditional Chinese (Taiwan; Hong Kong SAR, PRC)  
1026 IBM EBCDIC - Turkish (Latin-5) 
1047 IBM EBCDIC - Latin 1/Open System 
1140 IBM EBCDIC - U.S./Canada (037 + Euro symbol) 
1141 IBM EBCDIC - Germany (20273 + Euro symbol) 
1142 IBM EBCDIC - Denmark/Norway (20277 + Euro symbol) 
1143 IBM EBCDIC - Finland/Sweden (20278 + Euro symbol) 
1144 IBM EBCDIC - Italy (20280 + Euro symbol) 
1145 IBM EBCDIC - Latin America/Spain (20284 + Euro symbol) 
1146 IBM EBCDIC - United Kingdom (20285 + Euro symbol) 
1147 IBM EBCDIC - France (20297 + Euro symbol) 
1148 IBM EBCDIC - International (500 + Euro symbol) 
1149 IBM EBCDIC - Icelandic (20871 + Euro symbol) 
1200 Unicode UCS-2 Little-Endian (BMP of ISO 10646) 
1201 Unicode UCS-2 Big-Endian  
1250 ANSI - Central European  
1251 ANSI - Cyrillic 
1252 ANSI - Latin I  
1253 ANSI - Greek 
1254 ANSI - Turkish 
1255 ANSI - Hebrew 
1256 ANSI - Arabic 
1257 ANSI - Baltic 
1258 ANSI/OEM - Vietnamese 
1361 Korean (Johab) 
10000 MAC - Roman 
10001 MAC - Japanese 
10002 MAC - Traditional Chinese (Big5) 
10003 MAC - Korean 
10004 MAC - Arabic 
10005 MAC - Hebrew 
10006 MAC - Greek I 
10007 MAC - Cyrillic 
10008 MAC - Simplified Chinese (GB 2312) 
10010 MAC - Romania 
10017 MAC - Ukraine 
10021 MAC - Thai 
10029 MAC - Latin II 
10079 MAC - Icelandic 
10081 MAC - Turkish 
10082 MAC - Croatia 
12000 Unicode UCS-4 Little-Endian 
12001 Unicode UCS-4 Big-Endian 
20000 CNS - Taiwan  
20001 TCA - Taiwan  
20002 Eten - Taiwan  
20003 IBM5550 - Taiwan  
20004 TeleText - Taiwan  
20005 Wang - Taiwan  
20105 IA5 IRV International Alphabet No. 5 (7-bit) 
20106 IA5 German (7-bit) 
20107 IA5 Swedish (7-bit) 
20108 IA5 Norwegian (7-bit) 
20127 US-ASCII (7-bit) 
20261 T.61 
20269 ISO 6937 Non-Spacing Accent 
20273 IBM EBCDIC - Germany 
20277 IBM EBCDIC - Denmark/Norway 
20278 IBM EBCDIC - Finland/Sweden 
20280 IBM EBCDIC - Italy 
20284 IBM EBCDIC - Latin America/Spain 
20285 IBM EBCDIC - United Kingdom 
20290 IBM EBCDIC - Japanese Katakana Extended 
20297 IBM EBCDIC - France 
20420 IBM EBCDIC - Arabic 
20423 IBM EBCDIC - Greek 
20424 IBM EBCDIC - Hebrew 
20833 IBM EBCDIC - Korean Extended 
20838 IBM EBCDIC - Thai 
20866 Russian - KOI8-R 
20871 IBM EBCDIC - Icelandic 
20880 IBM EBCDIC - Cyrillic (Russian) 
20905 IBM EBCDIC - Turkish 
20924 IBM EBCDIC - Latin-1/Open System (1047 + Euro symbol) 
20932 JIS X 0208-1990 & 0121-1990 
20936 Simplified Chinese (GB2312) 
21025 IBM EBCDIC - Cyrillic (Serbian, Bulgarian) 
21027 Extended Alpha Lowercase 
21866 Ukrainian (KOI8-U) 
28591 ISO 8859-1 Latin I 
28592 ISO 8859-2 Central Europe 
28593 ISO 8859-3 Latin 3  
28594 ISO 8859-4 Baltic 
28595 ISO 8859-5 Cyrillic 
28596 ISO 8859-6 Arabic 
28597 ISO 8859-7 Greek 
28598 ISO 8859-8 Hebrew 
28599 ISO 8859-9 Latin 5 
28605 ISO 8859-15 Latin 9 
29001 Europa 3 
38598 ISO 8859-8 Hebrew 
50220 ISO 2022 Japanese with no halfwidth Katakana 
50221 ISO 2022 Japanese with halfwidth Katakana 
50222 ISO 2022 Japanese JIS X 0201-1989 
50225 ISO 2022 Korean  
50227 ISO 2022 Simplified Chinese 
50229 ISO 2022 Traditional Chinese 
50930 Japanese (Katakana) Extended 
50931 US/Canada and Japanese 
50933 Korean Extended and Korean 
50935 Simplified Chinese Extended and Simplified Chinese 
50936 Simplified Chinese 
50937 US/Canada and Traditional Chinese 
50939 Japanese (Latin) Extended and Japanese 
51932 EUC - Japanese 
51936 EUC - Simplified Chinese 
51949 EUC - Korean 
51950 EUC - Traditional Chinese 
52936 HZ-GB2312 Simplified Chinese  
54936 Windows XP: GB18030 Simplified Chinese (4 Byte)  
57002 ISCII Devanagari 
57003 ISCII Bengali 
57004 ISCII Tamil 
57005 ISCII Telugu 
57006 ISCII Assamese 
57007 ISCII Oriya 
57008 ISCII Kannada 
57009 ISCII Malayalam 
57010 ISCII Gujarati 
57011 ISCII Punjabi 
65000 Unicode UTF-7 
65001 Unicode UTF-8 
*/
	echo('test DBFReader');
	var d=new Date();
	var reader=man.createObject('DBFReader');
	echo('DBFReader='+reader.toString());
	var stg=man.createObject('Storage');
	stg.dbName=fso.buildPath(testFileDir,'test.db3');
	reader.storage=stg;
	reader.open(fso.buildPath(testFileDir,'ALTNAMES.DBF'));
	reader.read(866);
	reader.open(fso.buildPath(testFileDir,'DOMA.DBF'));
	reader.read(866);
	reader.open(fso.buildPath(testFileDir,'KLADR.DBF'));
	reader.read(866);
	reader.open(fso.buildPath(testFileDir,'SOCRBASE.DBF'));
	reader.read(866);
	reader.open(fso.buildPath(testFileDir,'STREET.DBF'));
	reader.read(866);
	d=(new Date)-d;
	echo('File imported in '+d+'ms');
	stg.dbName='';
	reader=stg=0;
}

//---===   main   ===---//

var fso=WScript.CreateObject('Scripting.FileSystemObject');
var testFileDir=fso.getParentFolderName(WScript.ScriptFullName);
var testFileName=(fso.buildPath(testFileDir,'test.bz2'));
try{
	var man=WScript.CreateObject("OSMan.Application");
	echo(" App="+man.toString());
	man.logger=
		{
			log:function(msg){
				echo(msg);
			}
		};
	
	var mods=man.getModules().toArray();
	echo('Module list:');
	for(var i=0;i<mods.length;i++){
		echo('	'+mods[i]);
		var cls=man.getModuleClasses(mods[i]).toArray();
		for(var j=0;j<cls.length;j++){
			echo('		'+cls[j]);
		};
	};
	echo('');

	//testFileReader();echo('');

	//testUnBZ2();echo('');

	testOSMReader();echo('');

	//testUnGZ();echo('');

	testFileWriter();echo('');

	//testDBFReader();echo('');

	}catch(e){
	echo('Unexpected exception '+e.description+' '+e.number);
}

echo('\r\npress `Enter`');
WScript.StdIn.Read(1);