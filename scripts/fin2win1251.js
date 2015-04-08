fin2win1251=function(s){
	var stt=[],sCur=0,vAOU='aouAOU',vEIY='eiyEIYY\u00E4\u00F6\u00C4\u00D6';
	function stm(pat){
		if(stt.length<pat.length)return 0;
		for(var i=0;i<pat.length;i++){
			var cs=stt[i];
			switch(pat.charAt(i)){
			case 'L':if(cs.isLetter)return 0; break;
			case 'l':if(!cs.isLetter)return 0; break;
			case 'V':if(cs.isVocal || !cs.isLetter)return 0; break;
			case 'v':if(!cs.isVocal)return 0; break;
			default:
				return 0;
			};
		};
		return 1;
	};
	function psm(pat){
		if(stt.length<pat.length)return 0;
		for(var i=0;i<pat.length;i++){
			var cs=stt[i];
			switch(pat.charAt(i)){
			case '0':if(cs.ps)return 0; break;
			case '1':if(!cs.ps)return 0; break;
			case ' ':break;
			default:
				return 0;
			};
		};
		return 1;
	};
	function out(){
		var s=stt.shift();
		r+=s.nch || '';
	};
	function cha(i){return stt[i || 0].ch};
	function nch(c,i){i=stt[i || 0];i.nch=c || '';i.ps=1};
	function parse(){
		if(psm('0000')){
			if(stm('l'))switch(cha()+cha(1)+cha(2)+cha(3)){
				case 'tier':nch('òüå');nch('',1);nch('',2);nch('',3);break;
			}else switch(cha(1)+cha(2)+cha(3)){
				case 'cha':nch('øà',1);nch('',2);nch('',3);break;
				case 'Cha':nch('Øà',1);nch('',2);nch('',3);break;
				case 'dju':nch('þ',1);nch('',2);nch('',3);break;
				case 'Dju':nch('Þ',1);nch('',2);nch('',3);break;
				case 'ski':
				case 'skj':nch('ø',1);nch('',2);nch('',3);break;
				case 'Ski':
				case 'Skj':nch('Ø',1);nch('',2);nch('',3);break;
			};
		};
		if(psm(' 00')){
			if(stm('vVVv') || stm('vVVL'))switch(cha(1)+cha(2)){
				case 'ck':nch('êê',1);nch('',2);break;
			}if(stm('Vll'))switch(cha(1)+cha(2)){
				case 'ii':switch(cha()){
					case 'j':nch('éèé');nch('',1);nch('',2);break;
					case 'J':nch('Éèé');nch('',1);nch('',2);break;
					};
					break;
				case 'ja':
				case 'j\u00E4':nch('üÿ',1);nch('',2);break;
				case 'je':nch('üå',1);nch('',2);break;
				case 'ji':nch('üè',1);nch('',2);break;
				case 'jo':nch('üî',1);nch('',2);break;
				case 'ju':
				case 'jy':nch('üþ',1);nch('',2);break;
				case 'j\u00F6':nch('ü¸',1);nch('',2);break;
			}else if(stm('Lll'))switch(cha(1)+cha(2)){
				case 'g\u00E4':
				case 'ge':if(cha(3)=='r'){nch('ÿð',1);nch('',3)}else nch('å',1);nch('',2);break;
				case 'G\u00E4':
				case 'Ge':if(cha(3)=='r'){nch('ßð',1);nch('',3)}else nch('Å',1);nch('',2);break;
				case 'gi':nch('éè',1);nch('',2);break;
				case 'Gi':nch('Éè',1);nch('',2);break;
				case 'gy':nch('þ',1);nch('',2);break;
				case 'Gy':nch('Þ',1);nch('',2);break;
				case 'g\u00F6':nch('é¸',1);if(cha(3)=='\u00F6')nch('î',3);nch('',2);break;
				case 'G\u00F6':nch('É¸',1);if(cha(3)=='\u00F6')nch('î',3);nch('',2);break;
				case 'hj':switch(cha(3)){
					case 'a':nch('ÿ',1);nch('',2);nch('',3);break;
					case '\u00F6':nch('é¸',1);nch('',2);nch('',3);break;
					};
					break;
				case 'Hj':switch(cha(3)){
					case 'a':nch('ß',1);nch('',2);nch('',3);break;
					case '\u00F6':nch('É¸',1);nch('',2);nch('',3);break;
					};
					break;
				case 'kj':nch('÷',1);nch('',2);break;
				case 'Kj':nch('×',1);nch('',2);break;
				case 'sk':if(vEIY.indexOf(cha(3))<0)break;
				case 'sj':nch('ø',1);nch('',2);break;
				case 'Sk':if(vEIY.indexOf(cha(3))<0)break;
				case 'Sj':nch('Ø',1);nch('',2);break;
				case '\u00E4i':
				case 'ei':nch('ýé',1);nch('',2);break;
				case '\u00C4i':
				case 'Ei':nch('Ýé',1);nch('',2);break;
				case '\u00E4y':nch('ýó',1);nch('',2);break;
				case '\u00C4y':nch('Ýó',1);nch('',2);break;
				case '\u00E4\u00E4':nch('ýý',1);nch('',2);break;
				case '\u00C4\u00E4':nch('Ýý',1);nch('',2);break;
				
			};
		};
		if(psm('000')){
			if(stm('vvL'))switch(cha()+cha(1)){
				case'ia':
					nch('èÿ');nch('',1);break;
			}else switch(cha()+cha(1)+cha(2)){
				case 'stj':nch('ø');nch('',1);nch('',2);break;
				case 'Stj':nch('Ø');nch('',1);nch('',2);break;
			};
		};
		if(psm(' 0')){
			if(stm('Lv'))switch(cha(1)){
				case 'e':nch('ý',1);break;
			}else if(stm('vVV')){
				if((cha(1)=='l') && (vEIY.indexOf(cha())>=0) && ('lj'.indexOf(cha(2))<0)){
					nch('ëü',1);
				};
			}else if(stm('vv')){
				if((cha(1)=='e') && (cha()!='i') && (cha()!='I'))nch('ý',1);
			};
		};
		if(psm('00')){
			switch(cha()+cha(1)){
				case 'ai':nch('à');nch('é',1);break;
				case 'Ai':nch('À');nch('é',1);break;
				case 'ei':nch('åé');nch('',1);break;
				case 'Ei':nch('åé');nch('',1);break;
				case 'j\u00E4':
				case 'ja':nch('ÿ');nch('',1);break;
				case 'J\u00E4':
				case 'Ja':nch('ß');nch('',1);break;
				case 'je':nch('å');nch('',1);break;
				case 'Je':nch('Å');nch('',1);break;
				case 'jo':nch('éî');nch('',1);break;
				case 'Jo':nch('Éî');nch('',1);break;
				case 'ju':
				case 'jy':nch('þ');nch('',1);break;
				case 'Ju':
				case 'Jy':nch('Þ');nch('',1);break;
				case 'j\u00F6':nch('é¸');nch('',1);break;
				case 'J\u00F6':nch('É¸');nch('',1);break;
				case 'ii':nch('èé');nch('',1);break;
				case 'Ii':nch('Èé');nch('',1);break;
				case 'oi':nch('î');nch('é',1);break;
				case 'Oi':nch('Î');nch('é',1);break;
				case 'ch':nch((vEIY.indexOf(cha(2))<0)?('ê'):('÷'));nch('',1);break;
				case 'ck':nch('ê');nch('',1);break;
				case 'Ch':nch((vEIY.indexOf(cha(2))<0)?('Ê'):('×'));nch('',1);break;
				case 'Ck':nch('Ê');nch('',1);break;
				case 'qu':nch('êâ');nch('',1);break;
				case 'Qu':nch('Êâ');nch('',1);break;
				case 'tj':nch('÷');nch('',1);break;
				case 'Tj':nch('×');nch('',1);break;
				case 'ui':nch('óé');nch('',1);break;
				case 'Ui':nch('Óé');nch('',1);break;
				case 'yi':nch('þé');nch('',1);break;
				case 'Yi':nch('Þé');nch('',1);break;
				case '\u00E4i':nch('ÿé');nch('',1);break;
				case '\u00C4i':nch('ßé');nch('',1);break;
				case '\u00E4y':nch('ÿó');nch('',1);break;
				case '\u00C4y':nch('ßó');nch('',1);break;
				case '\u00F6i':nch('¸é');nch('',1);break;
				case '\u00D6i':nch('¨é');nch('',1);break;
				case '\u00F6y':nch('¸ó');nch('',1);break;
				case '\u00D6y':nch('¨ó');nch('',1);break;
			}
		};
		if(psm('0')){
			switch(cha()){
			case 'a':nch('à');break;
			case 'A':nch('À');break;
			case 'b':nch('á');break;
			case 'B':nch('Á');break;
			case 'c':if(vEIY.indexOf(cha(1))<0)nch('ê');else nch('ñ');break;
			case 'C':if(vEIY.indexOf(cha(1))<0)nch('Ê');else nch('Ñ');break;
			case 'd':nch('ä');break;
			case 'D':nch('Ä');break;
			case 'e':nch('å');break;
			case 'E':nch('Ý');break;
			case 'f':nch('ô');break;
			case 'F':nch('Ô');break;
			case 'g':nch('ã');break;
			case 'G':nch('Ã');break;
			case 'h':nch('õ');break;
			case 'H':nch('Õ');break;
			case 'i':nch('è');break;
			case 'I':nch('È');break;
			case 'j':nch('é');break;
			case 'J':nch('É');break;
			case 'k':nch('ê');break;
			case 'K':nch('Ê');break;
			case 'l':nch(stm('VL')?'ëü':'ë');break;
			case 'L':nch('Ë');break;
			case 'm':nch('ì');break;
			case 'M':nch('Ì');break;
			case 'n':nch('í');break;
			case 'N':nch('Í');break;
			case 'o':nch('î');break;
			case 'O':nch('Î');break;
			case 'p':nch('ï');break;
			case 'P':nch('Ï');break;
			case 'q':nch('ê');break;
			case 'Q':nch('Ê');break;
			case 'r':nch('ð');break;
			case 'R':nch('Ð');break;
			case 's':
			case 'z':nch('ñ');break;
			case 'S':
			case 'Z':nch('Ñ');break;
			case 't':nch('ò');break;
			case 'T':nch('Ò');break;
			case 'u':nch('ó');break;
			case 'U':nch('Ó');break;
			case 'v':
			case 'w':nch('â');break;
			case 'V':
			case 'W':nch('Â');break;
			case 'x':nch('êñ');break;
			case 'X':nch('Êñ');break;
			case 'y':nch('þ');break;
			case 'Y':nch('Þ');break;
			case '\u00E5':nch('î');break;
			case '\u00C5':nch('Î');break;
			case '\u00E4':nch('ÿ');break;
			case '\u00C4':nch('Ý');break;
			case '\u00F6':nch('¸');break;
			case '\u00D6':nch('¨');break;
			default:nch(cha());break;
			};
		};
	}
	var isVocal=/[aeiouyAEIOUY\u00E4\u00E5\u00F6\u00C4\u00C5\u00D6]/,r='',isLetter=/[A-Za-z\u00C0-\u00F6]/;
	stt.push({},{},{},{});
	for(var i=0;i<s.length;i++){
		var c={};
		c.ch=s.charAt(i);
		c.isLetter=isLetter.test(c.ch);
		c.isVocal=isVocal.test(c.ch);
		stt.push(c);
		out();
		parse();
	};
	for(var i=0;i<4;i++){
		stt.push({});out();parse();
	};
	return arguments.callee.utf2win1251(r);
};
if(!include){
	fin2win1251.include=function(n){var w=WScript,h=w.createObject('WScript.Shell'),o=h.currentDirectory,s=w.createObject('Scripting.FileSystemObject'),f,t;h.currentDirectory=s.getParentFolderName(w.ScriptFullName);try{f=s.openTextFile(n,1,!1);try{t=f.ReadAll()}finally{f.close()}return eval(t)}catch(e){if(e instanceof Error)e.description+=' '+n;throw e}finally{h.currentDirectory=o}}
}else{
	fin2win1251.include=include;
};
if(!fin2win1251.utf2win1251)fin2win1251.utf2win1251=fin2win1251.include('utf2win1251.js');
fin2win1251;