
// parse the querystring
//

function qsParse() {
	var s = document.location.search;
	s = (s.indexOf('?') == 0) ? s.substr(1, s.length) : s;
	var a = s.split('&');
	for(var i = 0; i < a.length; i++) {
		var nv = a[i].split('=');
		if (nv[0] && nv[1]) {
			  this[nv[0]] = unescape(nv[1]);
		}
	}
}
qsParse();

function returnTrue() { return true; };
function returnFalse() { return false; };


function newImage(arg) {
	if (document.images) {
		rslt = new Image();
		rslt.src = arg;
		return rslt;
	}
}

function changeImages() {
	if (document.images && (preloadFlag == true)) {
		for (var i=0; i<changeImages.arguments.length; i+=2) {
			document[changeImages.arguments[i]].src = changeImages.arguments[i+1];
		}
	}
}

var preloadFlag = false;
function preloadImages() {
	if (document.images) {
	//	b_news_over = newImage("/images/b_news-over.gif");
	//	b_forums_over = newImage("/images/b_forums-over.gif");
	//	b_minions_over = newImage("/images/b_minions-over.gif");
	//	b_skins_over = newImage("/images/b_skins-over.gif");
	//	b_join_over = newImage("/images/b_join-over.gif");
	//	b_contact_over = newImage("/images/b_contact-over.gif");
	//	b_store_over = newImage("/images/b_store-over.gif");
	//	b_private_over = newImage("/images/b_private-over.gif");

		preloadFlag = true;

	//	fb_usercp_over = newImage("/images/fb_usercp-over.gif");
	//	fb_register_over = newImage("/images/fb_register-over.gif");
	//	fb_members_over = newImage("/images/fb_members-over.gif");
	//	fb_faq_over = newImage("/images/fb_faq-over.gif");
	//	fb_search_over = newImage("/images/fb_search-over.gif");
	//	fb_logout_over = newImage("/images/fb_logout-over.gif");
	}
}

function Init() {
	if (typeof InitPre == "function") { InitPre(); }
	
	preloadImages();
	
	if (typeof InitPost == "function") { InitPost(); }
}

window.onload = Init;

