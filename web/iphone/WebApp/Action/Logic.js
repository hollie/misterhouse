var WebApp=(function(){var A_=setTimeout;var B_=setInterval;var L2R=+1;var R2L=-1;var HEAD=0;var HOME=1;var BACK=2;var LEFT=3;var RIGHT=4;var TITLE=5;var _def,_headView,_head;var _webapp,_group,_bdo,_bdy;var _GG=-1;var _HH=-1;var _II=[];var _JJ=[];var _KK=[];var _LL=[];var _MM=[];var _NN=[];var _OO=[];var _PP=history.length;var _QQ=0;var _RR=false;var _SS="";var _TT="";var _UU=0;var _VV=0;var _WW=1;var _XX=null;var _YY=!(!document.getElementsByClassName)&&_G("WebKit",navigator.userAgent);var _ZZ=false;var _aa="";var _bb={}
_bb.load=[];_bb.beginslide=[];_bb.endslide=[];_bb.error=[];_bb.success=[];_bb.orientationchange=[];_bb.tabchange=[];__p={SetDefault:function(layer){_def=layer},Proxy:function(url){_aa=url},HideBar:function(){window.scrollTo(0,1);return false},Header:function(show,what){_D(show);_U(_headView,0);_headView=$(what);_U(_headView,!show);return false},Tab:function(id,active){var o=$(id);_k(o,$$("li",o)[active])},AddEventListener:function(evt,handler){if(typeof _bb[evt]!="undefined")if(_bb[evt].indexOf(handler)==-1)_bb[evt].push(handler)},Toggle:function(){if(_JJ.length>1){if(_HH==_JJ.length-1){_w();history.back()}else{_w();history.forward()}}return false},Back:function(){if(_RR)return(_RR=false);if(history.length-_PP==_HH){_w();history.back()}else{_w();location=_II[_HH-1]||"#"}return false},Home:function(){if(history.length-_PP==_HH){_w();history.go(-_HH)}else{_w();location="#"}return(_RR=false)},Form:function(frm){var s,a,b,c,o,f;a=$(frm);b=$(_JJ[_HH]);s=(a.style.display!="block");f=_K(a)=="form"?a:_Q(a,"form");o=f.onsubmit;if(!s){f.onsubmit=f.onsubmit(null,true)}else{a.style.top=_group.offsetTop-2+"px";f.onsubmit=function(e,b){if(b)return o;if(o)o(e);e.preventDefault();__p.Submit(this)}}
_w();_X(s,_group.offsetTop);_U(a,s);o=$$("legend",a)[0];_s(s&&o?o.innerHTML:null);_XX=(s)?a:null;if(s){c=a;a=b;b=c}
_F(a);_E(b,s);if(s)__p.Header(s);else _D(!s);return false},Submit:function(frm){var a=arguments[1];var e=arguments[2];var f=$(frm);if(f&&_K(f)!="form")f=_Q(f,"form");if(f){var _=function(i,f){var q="";for(var n=0;n<i.length;n++)if(i[n].name&&!i[n].disabled&&(f?f(i[n]):1))q+="&"+i[n].name+"="+encodeURIComponent(i[n].value);return q}
var q=_($$("input",f),function(i){with(i)return((_G(type,["text","password","hidden","search"])||(_G(type,["radio","checkbox"])&&checked)))}
);q+=_($$("select",f));q+=_($$("textarea",f));e=e||event;a=!a?_J(e.target):a;if(!a)_C();q+="&"+(a&&a.id?a.id:"__submit")+"=1";q=q.substr(1);_4(f.action||self.location.href,null,q);if(_XX)__p.Form(_XX)}return false},Postable:function(keys,values){var q="";for(var i=1;i<values.length&&i<=keys.length;i++)q+="&"+keys[i-1]+"="+encodeURIComponent(values[i]);return q.replace(/&=/g,"&").substr(1)},Request:function(url,prms,cb,async,loader){cb=cb==-1?_5():cb;var o=new XMLHttpRequest();var c=function(){_8(o,cb,loader)}
var m=prms?"post":"get";async=!!async;if(loader)__p.Loader(loader,true);_OO[_OO.length]=[o,url,prms,arguments[5]];url=_3(url,"__async","true");url=_3(url,"__source",_JJ[_HH]);url=_1(url);o.open(m,url,async);if(prms)o.setRequestHeader("Content-Type","application/x-www-form-urlencoded");o.onreadystatechange=(async)?c:null;o.send(prms);if(!async)c()},Loader:function(obj,show){var o=obj;var h=_M(o,"__lod");if(h==show)return h;if(show){_O(o,"__lod");_LL.push(o)}else _P(o,"__lod");_B(o);return h},Player:function(src){src=src||_J(event.target).href;if(!_f()){window.open(src)}else{var o=$("__wa_media");if(o)_webapp.removeChild(o);o=_I("iframe");o.id="__wa_media";o.src=src;_webapp.appendChild(o)}return false}}
function _A(s,w,dir,step,mn){s+=Math.max((w-s)/step,mn||4);return[s,(w+w*dir)/2-Math.min(s,w)*dir]}
function _B(o){if(_M(o,"iMore")){var a=$$("a",o)[0];if(a&&a.title){o=a.innerHTML;a.innerHTML=a.title;a.title=o}}
}
function _C(){var i=_I("input");_group.appendChild(i);i.type="text";i.focus();_U(i,0);A_(_group.removeChild,5,i)}
function _D(s){if(_head){for(var i=1;i<_NN.length;i++)_U(_NN[i],s);_U(_NN[BACK],s&&!_NN[LEFT]&&_HH);_U(_NN[HOME],s&&!_NN[RIGHT]&&_HH>1)}}
function _E(lay,ignore){if(_head){var a=$$("a",lay);var p=RIGHT;for(var i=0;i<a.length&&p>=LEFT;i++){if(_NN[p]&&!ignore){i--;p--;continue}if(_L(a[i].rel,"action")||_L(a[i].rel,"back")){_O(a[i],p==RIGHT?"iRightButton":"iLeftButton");_U(a[i],1);_NN[p--]=a[i];_head.appendChild(a[i--])}}
}}
function _F(lay){if(_head){for(var i=LEFT;i<=RIGHT;i++){var a=_NN[i];if(a&&(_L(a.rel,"action")||_L(a.rel,"back"))){_U(a,0);_P(a,i==RIGHT?"iRightButton":"iLeftButton");lay.insertBefore(a,lay.firstChild)}}
_NN[RIGHT]=$("waRightButton");_NN[LEFT]=$("waLeftButton")}}
function _G(o,a){return a.indexOf(o)!=-1}
function _H(o){return _L(o.rev,"async")||_L(o.rev,"async:np")}
function $(i){return typeof i=="string"?document.getElementById(i):i}
function $$(t,o){return(o||document).getElementsByTagName(t)}
function _I(t){return document.createElement(t)}
function _J(o){return _K(o)=="a"?o:_Q(o,"a")}
function _K(o){return o.localName.toLowerCase()}
function _L(o,t){return o&&_G(t,o.toLowerCase().split(" "))}
function _M(o,c){return _G(c,_N(o))}
function _N(o){return o.className.split(" ")}
function _O(o,c){var h=_M(o,c);if(!h)o.className+=" "+c;return h}
function _P(o){var c=_N(o);var a=arguments;for(var i=1;i<a.length;i++){var p=c.indexOf(a[i]);if(p!=-1)c.splice(p,1)}
o.className=c.join(" ")}
function _Q(o,t){while((o=o.parentNode)&&(o.nodeType!=1||_K(o)!=t));return o}
function _R(o,c){while((o=o.parentNode)&&(o.nodeType!=1||!_M(o,c)));return o}
function _S(o){var o=o.childNodes;for(var i=0;i<o.length;i++)if(o[i].nodeType==3)return o[i].nodeValue.replace(/^\s+|\s+$/g,"");return null}
function _T(){_webapp=$("WebApp");_group=$("iGroup");_NN[HEAD]=$("iHeader");_NN[BACK]=$("waBackButton");_NN[HOME]=$("waHomeButton");_NN[RIGHT]=$("waRightButton");_NN[LEFT]=$("waLeftButton");_NN[TITLE]=$("waHeadTitle");_bdy=document.body;_bdo=(_bdy.dir=="rtl")?-1:+1}
function _U(o,s){if(o)o.style.display=s?"block":"none"}
function _V(o){_U(o,1);o.style.width="100%"}
function _W(o){o=o||$(_0());if(o){var z=$$("div",o);if(z[0]&&_M(z[0],"iList")){_O(o,"__lay");o.style.minHeight=parseInt(_webapp.style.minHeight)-_group.offsetTop+"px"}else _P(o,"__lay")}}
function _X(s,p){var o=$("__wa_shadow");o.style.top=p+"px";_U(o,s)}
function _Y(){if(!_UU++)_U($("__wa_noclick"),1)}
function _Z(){if(!--_UU)_U($("__wa_noclick"),0)}
function _a(o,l){if(o){_JJ.splice(++_HH,_JJ.length);_JJ.push(o);_II.splice(_HH,_II.length);_II.push(l?location.hash:null);_KK.splice(_HH,_KK.length);_KK.push(_WW)}}
function _b(){var s,i,c;while(s=_LL.pop())__p.Loader(s,0);s=$$("li");for(i=0;i<s.length;i++)if(_M(s[i],"__sel"))_P(s[i],"__sel")}
function _c(s,np){var ed=s.indexOf("#_");if(ed==-1)return null;var rs="";var bs=_2(s);if(!np)for(var i=0;i<bs[1].length;i++)rs+="/"+bs[1][i].split("=").pop();return bs[2]+rs}
function _d(o,cb){A_(function(){if(_MM.indexOf(o)!=-1)_d(o,cb);else cb()},5)}
function _e(o,show,cb,sp,nx){if(!nx){if(!o||_MM.indexOf(o)!=-1)return;_MM.push(o)}if(!sp)sp=0.5;with(o.style){if((!show&&opacity>0)||(show&&opacity<1)){if(show)display="block";opacity=parseFloat(opacity)+(show?+sp:-sp);A_(_e,0,o,show,cb,sp,1)}else{display=(opacity==0)?"none":"block";_MM.splice(_MM.indexOf(o),1);if(cb)cb()}}
}
function _f(){with(navigator.userAgent)return(indexOf("iPhone")+indexOf("iPod")>-2)}
function _g(){_webapp=$("WebApp");if(_QQ||!_webapp)return;var w=(window.innerWidth>=480)?480:320;if(w!=_VV){_VV=w;_webapp.style.minHeight=((w==320)?417:269)+"px";_webapp.className=(w==320)?"portrait":"landscape";_W();_i("orientationchange")}}
function _h(){if(_QQ||_RR==location.href)return;_RR=false;var act=_0();if(act==null)if(location.hash.length>0)return;else act=_JJ[0];var pos=_JJ.indexOf(act);var cur=_JJ[_HH];if(act==cur)return;if(pos!=-1&&pos<_HH){_HH=pos+1;_n(cur,act,L2R)}else{_m(act)}}
function _i(evt,ctx,obj){var l=_bb[evt].length;if(l==0)return true;var e={}
e.type=evt;e.target=obj||null;e.context=ctx||_x(_II[_HH]);e.windowWidth=_VV;e.windowHeight=_webapp.offsetHeight;var k=true;for(var i=0;i<l;i++)k=k&&(_bb[evt][i](e)==false?false:true);return k}
function _j(){_T();_FF();_BB();_AA();_9();_EE("div","__wa_noclick");_EE("div","__wa_shadow");var l=$("iLoader");if(l)_U(l,0);if(!_def)_def=_y()[0].id;_a(_def);var a=_0();if(a!=_def)_a(a,true);if(!a)a=_def;_V($(a));_E($(a));_U(_NN[BACK],(!_NN[LEFT]&&_HH));_U(_NN[HOME],(!_NN[RIGHT]&&_HH>1&&a!=_def));if(_NN[BACK])_TT=_NN[BACK].innerHTML;if(_NN[TITLE]){_SS=_NN[TITLE].innerHTML;_NN[TITLE].innerHTML=_z($(a))}
B_(_h,100);A_(_i,100,"load");A_(_w,500)}
function _k(ul,li,h,ev){var c,s,al=$$("li",ul);for(var i=0;i<al.length;i++){c=(al[i]==li);if(c)s=i;_U($(ul.id+i),(!h&&c));_P(al[i],"__act")}
_O(li,"__act");if(ev)_i("tabchange",[s],ul)}
function _l(e,b){if(_QQ){e.preventDefault();return}
var o=e.target;var n=_K(o);if(n=="label"){var f=$(o.getAttribute("for"));if(_M(f,"iToggle"))A_(_v,1,f.previousSibling.childNodes[1],true);return}
var li=_Q(o,"li");if(li&&_M(li,"iRadio")){_O(li,"__sel");_DD(li);return}
var ul=_Q(o,"ul");var pr=!ul?null:ul.parentNode;var a=_J(o);var ax=a&&_H(a);if(ul&&_M(pr,"iTab")){var h=$(ul.id+"-loader");_U(h,0);if(ax){_U(h,1);_4(a,function(o){_U(h,0);_U(_6(o)[0],1);_k(ul,li,null,1)}
)}else{h=null}
_k(ul,li,h,!ax);e.preventDefault();return}if(a&&!a.onclick&&_G(a.id,["waBackButton","waHomeButton"])){if(a.id=="waBackButton")__p.Back();else __p.Home();e.preventDefault();return}if(ul&&_M(ul,"iCheck")){var al=$$("li",ul);for(var i=0;i<al.length;i++)_P(al[i],"__act","__sel");_O(li,"__act __sel");A_(_P,1000,li,"__sel");e.preventDefault();return}if(ul&&!_M(li,"iMore")&&((_M(ul,"iMenu")||_M(pr,"iMenu"))||(_M(ul,"iList")||_M(pr,"iList")))){if(a&&!_M(a,"iButton")){var c=_O(li,"__sel");if(ax){if(!c)_4(a);e.preventDefault();return}if(_L(a.rev,"media")){__p.Player(a.href);A_(_P,500,li,"__sel");e.preventDefault();return}}
}
var dv=_R(o,"iMore");if(dv){if(!__p.Loader(dv,1)&&_H(a))_4(a);e.preventDefault();return}if(a&&_XX&&!a.onclick){if(_L(a.rel,"back"))__p.Form(_XX,a);if(_L(a.rel,"action"))__p.Submit(_XX,a);e.preventDefault();return}if(a&&_L(a.rev,"media")){__p.Player(a.href);e.preventDefault();return}if(a&&ax){_4(a);e.preventDefault();return}if(a&&_G("#_",a.href)){_w()}}
function _m(to){if(_JJ[_HH]!=to)_n(_JJ[_HH],to);return false}
function _n(src,dst,dir){if(_QQ)return;_Y();if(dst==_JJ[0])_PP=history.length;dir=dir||R2L;src=$(src);dst=$(dst);_W(dst);_U($("iFooter"),0);_QQ=1;_t(0,function(){_p(src,dst,dir)}
)}
function _o(d){return[_x(_II[_GG]),_x(location.hash),d]}
function _p(src,dst,dir){_i("beginslide",_o(dir));_GG=_HH;_F(src);_E(dst);_FF(dst);_BB(dst);var w=src.offsetWidth;var c,b=_bdy;_V(src);_O(b,"__wa_slideV1");if(dir*_bdo==L2R){A_(window.scrollTo,5,w,window.pageYOffset);c=src.cloneNode(true);_group.appendChild(c)}else if(_bdo==R2L){_V(dst)}
A_(function(){_V(dst);if(c){_group.removeChild(c)}if(dir==R2L){_group.insertBefore(src,dst);_a(dst.id,true)}else{_group.insertBefore(dst,src);while(_HH&&_JJ[--_HH]!=dst.id){}}
A_(function(){var s=0;var i=B_(function(){if(s<=w){var z=_A(s,w,dir*_bdo,6,2);s=z[0];window.scrollTo(z[1],1);return}
clearInterval(i);c=dst.cloneNode(true);_group.insertBefore(c,dst.nextSibling);_U(src,0);A_(function(){_group.removeChild(c);_q(src,dst,dir)},5)},5)},5)},5)}
function _q(src,dst,dir){_b();if(_NN[BACK]){var txt;if(dir==R2L)txt=src.title||_TT;else if(_HH)txt=$(_JJ[_HH-1]).title||_TT;if(txt)_NN[BACK].innerHTML=txt}
_U($("iFooter"),1);_s();_P(_bdy,"__wa_slideV1");_V(dst);_u(null,function(){_r(dir);_i("endslide",_o(dir));_GG=-1}
)}
function _r(dir){_Z();A_(_w,0,(dir==L2R)?_KK[_HH+1]:null);_QQ=0}
function _s(title){var o;if(o=_NN[TITLE]){o.innerHTML=title||_z($(_0()))||_SS}}
function _t(s,cb){_e(_head,0,function(){if(cb)cb();if(_XX)__p.Form(_XX);_U(_headView,0)},s?1:null)}
function _u(s,cb){_d(_head,function(){_U(_NN[BACK],!_NN[LEFT]&&_HH);_U(_NN[HOME],!_NN[RIGHT]&&_HH>1);_U(_NN[LEFT],1);_U(_NN[RIGHT],1);_D(1);_e(_head,1,cb,s?1:null)}
)}
function _v(o,dontChange){var i=$(o.parentNode.title);var txt=i.title.split("|");if(!dontChange)i.click();with(o.nextSibling){innerHTML=txt[i.checked?0:1];if(i.checked){o.style.left="";o.style.right="-1px";o.parentNode.className="iToggleOn";style.left="0";style.right=""}else{o.style.left="-1px";o.style.right="";o.parentNode.className="iToggle";style.left="";style.right="0"}}
}
function _w(to){_WW=window.pageYOffset;var h=to?to:Math.min(50,_WW);var s=to?Math.max(1,to-50):1;var d=to?-1:+1;while(s<=h){var z=_A(s,h,d,6,2);s=z[0];window.scrollTo(0,z[1])}if(!to)__p.HideBar()}
function _x(loc){if(loc){var pos=loc.indexOf("#_");var vis=[];if(pos!=-1){loc=loc.substring(pos+2).split("/");vis=_y().filter(function(l){return l.id=="wa"+loc[0]}
)}if(vis.length){loc[0]=vis[0].id;return loc}}return[]}
function _y(){var lay=[];var src=_group.childNodes;for(var i=0;i<src.length;i++)if(src[i].nodeType==1&&_M(src[i],"iLayer"))lay.push(src[i]);return lay}
function _z(o){return(!_HH&&_SS)?_SS:o.title}
function _0(){return _x(location.hash)[0]}
function _1(url){var d=url.match(/[a-z]+:\/\/(.+:.*@)?([a-z0-9-\.]+)((:\d+)?\/.*)?/i);return(!_aa||!d||d[2]==location.hostname)?url:_3(_aa,"__url=",url)}
function _2(u){var s,q,d;s=u.replace(/&amp;/g,"&");d=s.indexOf("#");d=s.substr(d!=-1?d:s.length);s=s.substr(0,s.length-d.length);q=s.indexOf("?");q=s.substr(q!=-1?q:s.length);s=s.substr(0,s.length-q.length);q=!q?[]:q.substr(1).split("&");return[s,q,d]}
function _3(u,k,v){u=_2(u);var q=u[1].filter(function(o){return o&&o.indexOf(k+"=")!=0}
);q.push(k+"="+encodeURIComponent(v));return u[0]+"?"+q.join("&")+u[2]}
function _4(item,cb,q){var h,o,u,i;i=(typeof item=="object");u=(i?item.href:item);o=_Q(item,"li");if(!cb)cb=_5(u,_L(item.rev,"async:np"));__p.Request(u,q,cb,true,o,(i?item:null))}
function _5(i,np){return function(o){var u=i?_c(i,np):null;var g=_6(o);if(g&&(g[1]||u)){_w();location=g[1]||u}else A_(_b,250);return null}}
function _6(o){if(o.responseXML){o=o.responseXML.documentElement;var k,a=_0();var g=$$("go",o);g=(g.length!=1)?null:g[0].getAttribute("to");var f,p=o.getElementsByTagName("part");if(p.length==0)p=[o];for(var z=0;z<p.length;z++){var dst=$$("destination",p[z])[0];var mod=dst.getAttribute("mode");var nds=$$("data",p[z])[0].childNodes;var txt="";for(var y=0;y<nds.length;y++)txt+=nds[y].nodeValue;var i=dst.getAttribute("zone");if(dst.getAttribute("create")=="true"&&i.substr(0,2)=="wa"&&!$(i)){var n=_I("div");n.className="iLayer";n.id=i;_group.appendChild(n)}
f=f||i;g=g||dst.getAttribute("go");i=$(i||dst.firstChild.nodeValue);if(!k&&a==i.id){_t(1);_F(i);k=i}
_7(i,txt,mod)}
var t=$$("title",o);if(t.length==1){var s=t[0].getAttribute("set");$(s).title=t[0].firstChild.nodeValue;if(a==s)_s(null,1)}if(k){_E(k);_u(1)}return[f,g?"#_"+g.substr(2):null]}
throw "Invalid asynchronous response received."}
function _7(o,c,m){if(m=="append"){o.innerHTML+=c}else if(m=="replace"){o.innerHTML=c}else{var p=o.parentNode;var a=(m=="self")?o:_I("div");a.innerHTML=c;if(m!="self")p.insertBefore(a,m=="after"?o.nextSibling:o);while(a.hasChildNodes())p.insertBefore(a.firstChild,a);p.removeChild(a)}}
function _8(o,cb,lr){if(o.readyState!=4)return;var er,ld,ob;er=(o.status!=200&&o.status!=0);if(!er){try{if(cb)ld=cb(o,lr)}
catch(ex){er=ex;console.error(er)}}if(lr){__p.Loader(lr,0);if(er)_P(lr,"__sel")}if(ob=_OO.filter(function(a){return o==a[0]}
)[0]){_i(er?"error":"success",ob,ob.pop());_OO.splice(_OO.indexOf(ob),1)}}
function _9(){var hd=_NN[HEAD];if(hd){var dv=_I("div");dv.style.opacity=1;while(hd.hasChildNodes())dv.appendChild(hd.firstChild);hd.appendChild(dv);_head=dv}}
function _AA(){var o=$$("ul");for(var i=0;i<o.length;i++){var p=o[i].parentNode;if(p&&_M(p,"iTab")){_O($$("li",o[i])[0],"__act");if(p=$(o[i].id+"0"))_U(p,1)}}
}
function _BB(p){var s="wa__radio";var o=$$("li",p);for(var i=0;i<o.length;i++){if(_M(o[i],"iRadio")&&!_M(o[i],"__done")){var lnk=_I("a");var sel=_I("span");var cpy=o[i].childNodes;var inp=$$("input",o[i]);for(var j=0;j<inp.length;j++){with(inp[j])if(type=="radio"&&checked){sel.innerHTML=_S(parentNode);break}}
lnk.appendChild(sel);while(o[i].hasChildNodes())lnk.appendChild(o[i].firstChild);o[i].appendChild(lnk);lnk.href="#";lnk.onclick=function(){_RR=location.href;return _m(s)}
_O(o[i],"__done")}}if(!$(s)){var d=_I("div");d.className="iLayer";d.id=s;_group.appendChild(d)}}
function _CC(a,p,u){var x=$$("input",p);var y=$$("a",u);for(var i=0;i<y.length;i++)if(y[i]==a){x[i].checked=true;$$("span",p)[0].innerHTML=_S(x[i].parentNode);break}}
function _DD(p){var o=$$("input",p);var dv=_I("div");var ul=_I("ul");ul.className="iCheck";for(var i=0;i<o.length;i++){if(o[i].type=="radio"){var li=_I("li");var a=_I("a");a.innerHTML=o[i].nextSibling.nodeValue;a.href="#";a.onclick=function(){_CC(this,p,ul)}
li.appendChild(a);ul.appendChild(li);if(o[i].checked)li.className="__act"}}
dv.className="iMenu";dv.appendChild(ul);o=$("wa__radio");if(o.firstChild)o.removeChild(o.firstChild);o.title=_S(p.firstChild);o.appendChild(dv)}
function _EE(t,i){var o=_I(t);o.id=i;_webapp.appendChild(o);return o}
function _FF(p){var o=$$("input",p);for(var i=0;i<o.length;i++){if(o[i].type=="checkbox"&&_M(o[i],"iToggle")&&!_M(o[i],"__done")){if(!o[i].id)o[i].id="__"+Math.random();if(!o[i].title)o[i].title="ON|OFF";var txt=o[i].title.split("|");var b1=_I("b");var b2=_I("b");var i1=_I("i");b1.className="iToggle";b1.title=o[i].id;b1.innerHTML="&nbsp;";i1.innerHTML=txt[1];b1.appendChild(b2);b1.appendChild(i1);o[i].parentNode.insertBefore(b1,o[i]);b2.onclick=function(){_v(this)}
_v(b2,true);_O(o[i],"__done")}}
}
B_(_g,100);addEventListener("load",_j,true);addEventListener("click",_l,true);return __p}
)();var WA=WebApp;