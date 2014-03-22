ttable=function(s){
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
				case 'tier':nch('���');nch('',1);nch('',2);nch('',3);break;
			}else switch(cha(1)+cha(2)+cha(3)){
				case 'cha':nch('��',1);nch('',2);nch('',3);break;
				case 'Cha':nch('��',1);nch('',2);nch('',3);break;
				case 'dju':nch('�',1);nch('',2);nch('',3);break;
				case 'Dju':nch('�',1);nch('',2);nch('',3);break;
				case 'ski':
				case 'skj':nch('�',1);nch('',2);nch('',3);break;
				case 'Ski':
				case 'Skj':nch('�',1);nch('',2);nch('',3);break;
			};
		};
		if(psm(' 00')){
			if(stm('vVVv') || stm('vVVL'))switch(cha(1)+cha(2)){
				case 'ck':nch('��',1);nch('',2);break;
			}if(stm('Vll'))switch(cha(1)+cha(2)){
				case 'ii':switch(cha()){
					case 'j':nch('���');nch('',1);nch('',2);break;
					case 'J':nch('���');nch('',1);nch('',2);break;
					};
					break;
				case 'ja':
				case 'j\u00E4':nch('��',1);nch('',2);break;
				case 'je':nch('��',1);nch('',2);break;
				case 'ji':nch('��',1);nch('',2);break;
				case 'jo':nch('��',1);nch('',2);break;
				case 'ju':
				case 'jy':nch('��',1);nch('',2);break;
				case 'j\u00F6':nch('��',1);nch('',2);break;
			}else if(stm('Lll'))switch(cha(1)+cha(2)){
				case 'g\u00E4':
				case 'ge':if(cha(3)=='r'){nch('��',1);nch('',3)}else nch('�',1);nch('',2);break;
				case 'G\u00E4':
				case 'Ge':if(cha(3)=='r'){nch('��',1);nch('',3)}else nch('�',1);nch('',2);break;
				case 'gi':nch('��',1);nch('',2);break;
				case 'Gi':nch('��',1);nch('',2);break;
				case 'gy':nch('�',1);nch('',2);break;
				case 'Gy':nch('�',1);nch('',2);break;
				case 'g\u00F6':nch('�',1);if(cha(3)=='\u00F6')nch('�',3);nch('',2);break;
				case 'G\u00F6':nch('ɸ',1);if(cha(3)=='\u00F6')nch('�',3);nch('',2);break;
				case 'hj':switch(cha(3)){
					case 'a':nch('�',1);nch('',2);nch('',3);break;
					case '\u00F6':nch('�',1);nch('',2);nch('',3);break;
					};
					break;
				case 'Hj':switch(cha(3)){
					case 'a':nch('�',1);nch('',2);nch('',3);break;
					case '\u00F6':nch('ɸ',1);nch('',2);nch('',3);break;
					};
					break;
				case 'kj':nch('�',1);nch('',2);break;
				case 'Kj':nch('�',1);nch('',2);break;
				case 'sk':if(vEIY.indexOf(cha(3))<0)break;
				case 'sj':nch('�',1);nch('',2);break;
				case 'Sk':if(vEIY.indexOf(cha(3))<0)break;
				case 'Sj':nch('�',1);nch('',2);break;
				case '\u00E4i':
				case 'ei':nch('��',1);nch('',2);break;
				case '\u00C4i':
				case 'Ei':nch('��',1);nch('',2);break;
				case '\u00E4y':nch('��',1);nch('',2);break;
				case '\u00C4y':nch('��',1);nch('',2);break;
				case '\u00E4\u00E4':nch('��',1);nch('',2);break;
				case '\u00C4\u00E4':nch('��',1);nch('',2);break;
				
			};
		};
		if(psm('000')){
			if(stm('vvL'))switch(cha()+cha(1)){
				case'ia':
					nch('��');nch('',1);break;
			}else switch(cha()+cha(1)+cha(2)){
				case 'stj':nch('�');nch('',1);nch('',2);break;
				case 'Stj':nch('�');nch('',1);nch('',2);break;
			};
		};
		if(psm(' 0')){
			if(stm('Lv'))switch(cha(1)){
				case 'e':nch('�',1);break;
			}else if(stm('vVV')){
				if((cha(1)=='l') && (vEIY.indexOf(cha())>=0) && ('lj'.indexOf(cha(2))<0)){
					nch('��',1);
				};
			}else if(stm('vv')){
				if((cha(1)=='e') && (cha()!='i') && (cha()!='I'))nch('�',1);
			};
		};
		if(psm('00')){
			switch(cha()+cha(1)){
				case 'ai':nch('�');nch('�',1);break;
				case 'Ai':nch('�');nch('�',1);break;
				case 'ei':nch('��');nch('',1);break;
				case 'Ei':nch('��');nch('',1);break;
				case 'j\u00E4':
				case 'ja':nch('�');nch('',1);break;
				case 'J\u00E4':
				case 'Ja':nch('�');nch('',1);break;
				case 'je':nch('�');nch('',1);break;
				case 'Je':nch('�');nch('',1);break;
				case 'jo':nch('��');nch('',1);break;
				case 'Jo':nch('��');nch('',1);break;
				case 'ju':
				case 'jy':nch('�');nch('',1);break;
				case 'Ju':
				case 'Jy':nch('�');nch('',1);break;
				case 'j\u00F6':nch('�');nch('',1);break;
				case 'J\u00F6':nch('ɸ');nch('',1);break;
				case 'ii':nch('��');nch('',1);break;
				case 'Ii':nch('��');nch('',1);break;
				case 'oi':nch('�');nch('�',1);break;
				case 'Oi':nch('�');nch('�',1);break;
				case 'ch':nch((vEIY.indexOf(cha(2))<0)?('�'):('�'));nch('',1);break;
				case 'ck':nch('�');nch('',1);break;
				case 'Ch':nch((vEIY.indexOf(cha(2))<0)?('�'):('�'));nch('',1);break;
				case 'Ck':nch('�');nch('',1);break;
				case 'qu':nch('��');nch('',1);break;
				case 'Qu':nch('��');nch('',1);break;
				case 'tj':nch('�');nch('',1);break;
				case 'Tj':nch('�');nch('',1);break;
				case 'ui':nch('��');nch('',1);break;
				case 'Ui':nch('��');nch('',1);break;
				case 'yi':nch('��');nch('',1);break;
				case 'Yi':nch('��');nch('',1);break;
				case '\u00E4i':nch('��');nch('',1);break;
				case '\u00C4i':nch('��');nch('',1);break;
				case '\u00E4y':nch('��');nch('',1);break;
				case '\u00C4y':nch('��');nch('',1);break;
				case '\u00F6i':nch('��');nch('',1);break;
				case '\u00D6i':nch('��');nch('',1);break;
				case '\u00F6y':nch('��');nch('',1);break;
				case '\u00D6y':nch('��');nch('',1);break;
			}
		};
		if(psm('0')){
			switch(cha()){
			case 'a':nch('�');break;
			case 'A':nch('�');break;
			case 'b':nch('�');break;
			case 'B':nch('�');break;
			case 'c':if(vEIY.indexOf(cha(1))<0)nch('�');else nch('�');break;
			case 'C':if(vEIY.indexOf(cha(1))<0)nch('�');else nch('�');break;
			case 'd':nch('�');break;
			case 'D':nch('�');break;
			case 'e':nch('�');break;
			case 'E':nch('�');break;
			case 'f':nch('�');break;
			case 'F':nch('�');break;
			case 'g':nch('�');break;
			case 'G':nch('�');break;
			case 'h':nch('�');break;
			case 'H':nch('�');break;
			case 'i':nch('�');break;
			case 'I':nch('�');break;
			case 'j':nch('�');break;
			case 'J':nch('�');break;
			case 'k':nch('�');break;
			case 'K':nch('�');break;
			case 'l':nch(stm('VL')?'��':'�');break;
			case 'L':nch('�');break;
			case 'm':nch('�');break;
			case 'M':nch('�');break;
			case 'n':nch('�');break;
			case 'N':nch('�');break;
			case 'o':nch('�');break;
			case 'O':nch('�');break;
			case 'p':nch('�');break;
			case 'P':nch('�');break;
			case 'q':nch('�');break;
			case 'Q':nch('�');break;
			case 'r':nch('�');break;
			case 'R':nch('�');break;
			case 's':
			case 'z':nch('�');break;
			case 'S':
			case 'Z':nch('�');break;
			case 't':nch('�');break;
			case 'T':nch('�');break;
			case 'u':nch('�');break;
			case 'U':nch('�');break;
			case 'v':
			case 'w':nch('�');break;
			case 'V':
			case 'W':nch('�');break;
			case 'x':nch('��');break;
			case 'X':nch('��');break;
			case 'y':nch('�');break;
			case 'Y':nch('�');break;
			case '\u00E5':nch('�');break;
			case '\u00C5':nch('�');break;
			case '\u00E4':nch('�');break;
			case '\u00C4':nch('�');break;
			case '\u00F6':nch('�');break;
			case '\u00D6':nch('�');break;
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
	return r;
};
ttable;