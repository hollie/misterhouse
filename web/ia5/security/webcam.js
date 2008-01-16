// WebCam Auto-Updater v1.9
//
// MODIFIED FROM THE ORIGINAL FOR MiseterHouse!
//  by Pete Flaherty
//
//
// Original:
// by Cowboy - 1/16/04 - cowboy@cowboyscripts.org
//
// (You can use this script, but credit me .. because I'm the man and you know it)
//
// http://cowboyscripts.org/
// http://rj3.net/ckb/
// http://rj3.net/cowboy/
//


// ============================================
// MODIFIED FROM THE ORIGINAL FOR THE CkB SITE!
//
// added "camID" / "webCamID" bits
// ============================================
// 
function webCamRegisterCam(camName, camURL, camID) {
	
    if (typeof webCamURL != "object") {
	webCamURL = new Array();
	webCamName = new Array();
	webCamID = new Array();
    }

    var idx = webCamName.length;
	
    webCamName[idx] = camName;
    webCamURL[idx] = camURL;
    webCamID[idx] = camID;
}


// -----   USER SETTINGS   -----
//
// added "camID" / "webCamID" bits
// ============================================
//
//function IncludeJavaScript(jsFile)
//{
//  document.write('<script type="text/javascript" src="' + jsFile + '"></script>'); 
//}

// IncludeJavaScript('webcam_cams.js');

// Check UPdate interval and Number of cameras. 
// we assume about .5 secs per image (maybe more)
//if ( webCamUpdateInterval < ( webCamName.length * .5) ){
//     webCamUpdateInterval = ( webCamName.length * .5 )
//}

webCamRegisterCam("MrHouse", "images/webcam_mrhouse.jpg", 0);

// Here are the WebCam images:

// Moved to webcam_cams.js for maintainence (and alternate generation )

//webCamRegisterCam("Driveway", "http://192.168.0.223/usr/yoics0.jpg", 1);
//webCamRegisterCam("UnAssigned", "http://192.168.0.223/usr/yoics1.jpg", 2);
//webCamRegisterCam("Front Door", "http://192.168.0.223/usr/yoics2.jpg", 3);
//webCamRegisterCam("Walkway", "http://192.168.0.223/usr/yoics3.jpg", 4);
//webCamRegisterCam("Driveway2", "http://192.168.0.223/usr/yoics0.jpg",5 );
//webCamRegisterCam("Driveway3", "http://192.168.0.223/usr/yoics0.jpg", 6);
//webCamRegisterCam("Triston", "http://www.rj3.net/~ckb/webcam/triston/triston.jpg", 2);
//webCamRegisterCam("Ireckon", "http://www.ireckon.org/webcam/ireckon.jpg", 46);
//webCamRegisterCam("Tankd", "http://www.spyderinternet.com/~wrang/cowcam.jpg", 5);
//webCamRegisterCam("Cheeseman", "http://rj3.net/~ckb/webcam/cheeseman/cheeseman.jpg", 97);
//webCamRegisterCam("jedi196", "http://rj3.net/~ckb/webcam/jedi196/jedi196.jpg", 13);
//webCamRegisterCam("Ferret of Death", "http://www.rj3.net/~ckb/webcam/fod/fod.jpg", 22);
//webCamRegisterCam("^BuGs^", "http://www.rj3.net/~ckb/webcam/bugs/bugs.jpg", 44);
//webCamRegisterCam("Tinkar", "http://www.rj3.net/~ckb/webcam/tinkar/tinkar.jpg", 0);
//webCamRegisterCam("T-Bone", "http://www.rj3.net/~ckb/webcam/tbone/tbone.jpg", 341);
//webCamRegisterCam("interface", "http://www.salsatech.com/face/drunktime.jpg", 292);

//webCamRegisterCam("", "", );


// ----- END USER SETTINGS -----



// Set your page's onload= to this function, otherwise it won't do anything!
//
function webCamInit() {
	webCamPreloadImages(); // MODIFIED FROM THE ORIGINAL FOR THE CkB SITE!
	
	webCamUpdateFunction();
	
	webCamUpdateTimeLeft = webCamUpdateInterval;
	webCamInterval = setInterval("webCamUpdate();", 1000);
}

// Use this function in-line with your HTML to generate the WebCam images
//
// Usage:
//
//   webCamDraw(n);
//
//   n is the array index. You can override the default webCamWidth and webCamHeight
//   by overloading the function: webCamDraw(n, width, height, altText);
//
function webCamDraw(camNum, w, h, altText) {
	var wStr = " width='" + ((typeof w == "undefined") ? webCamWidth : w) + "'";
	var hStr = " height='" + ((typeof h == "undefined") ? webCamHeight : h) + "'";

	if (w == "") wStr = "";
	if (h == "") hStr = "";

	var altText = (typeof altText == "string") ? altText : ((camNum == 0 && typeof wc_spareImgAltText == "string" && wc_spareImgAltText != "") ? wc_spareImgAltText : webCamName[camNum]);

	var theDate = new Date();
	
	if (wc_debugMode) {
		document.write("<p>" + webCamName[camNum] + "<br>" + camNum + "</p>");
	} else {
		document.write("<img name='webCam_" + camNum + "' src='" + webCamURL[0] + "'" + wStr + hStr + " border='0' alt=\"" + altText + "\">");
	}
}

// Display #sec remaining until next update in the status bar
//
function webCamUpdate() {
	webCamUpdateTimeLeft--;

	window.status = "WebCams: Reload in " + webCamUpdateTimeLeft + " seconds";
	
	if (webCamUpdateTimeLeft <= 0) {
		webCamUpdateFunction();
		webCamUpdateTimeLeft = webCamUpdateInterval;
	}
}

// Intelligent image preloader. Reloads each image into a separate image object,
// when that object is loaded it refreshes the visible WebCam pic so there isn't
// any flickering
//
function webCamImagePreloaded() {
	document["webCam_" + this.camNum].src = document["webCamPreload_" + this.camNum].src;

	window.status = "WebCams: Reloaded " + webCamName[this.camNum];
}

function webCamImageError() {
	document["webCam_" + this.camNum].src = webCamURL[0];

	window.status = "WebCams: Error reloading " + webCamName[this.camNum];
}

function webCamPreloadImage(camNum, imgURL) {
	theImage = new Image();
	theImage.src = imgURL;
	theImage.onerror = webCamImageError;
	theImage.onload = webCamImagePreloaded;
	theImage.camNum = camNum;
	
	return theImage;
}

function webCamUpdateWithPreload() {
	if (document.images) {
		var theDate = new Date();

		for (var i = 1; i < webCamURL.length; i++) {
			if (typeof document["webCam_" + i] == "object" && typeof document["webCam_" + i].src == "string") {
				document["webCamPreload_" + i] = webCamPreloadImage(i, webCamURL[i] + "?" + parseInt(theDate.getTime() / 1000));
			}
		}
	}
}


// Brute-force updating the images. No preloading or error-handling, but
// it works.
//
function webCamUpdateNoPreload() {
	if (document.images) {
		var theDate = new Date();
		
		for (var i = 1; i < webCamURL.length; i++) {
			if (typeof document["webCam_" + i] == "object" && typeof document["webCam_" + i].src == "string") {
				document["webCam_" + i].src = webCamURL[i] + "?" + parseInt(theDate.getTime() / 1000);
			}
		}
	}
}


webCamUpdateFunction = webCamUpdateWithPreload;
//webCamUpdateFunction = webCamUpdateNoPreload;


// Test to see if preloading images is supported (there are probably much
// better ways to do this, but I'm limited on time!) If preloading doesn't
// work, use the non-preloading webCamUpdateNoPreload function.
//
function testImagePreload() {
	if (typeof this.src != "string") {
		webCamUpdateFunction = webCamUpdateNoPreload;
	}
}
testImage = new Image();
testImage.onload = testImagePreload;
testImage.src = webCamURL[0];




// ************************************************************************************************
// ************************************************************************************************


// Here's some bonus stuff for the CkB site, you might not want this.. but it's really cool!
// You can see it in action here: http://www.rj3.net/ckb/webcam.shtml
//
// Note: needs at least 3 defined WebCams to work properly.. but of course, you wouldn't
//       use this unless you had at least half a dozen webcams anyways, right?

//IncludeJavaScript('webcam_settings.js');

//wc_debugMode = true;                    // Toggle Debug Mode on/off

//wc_bgColor = " bgcolor='#1A3B3C'";       // HTML bgcolor around each WebCam image
//wc_URL = "webcam.shtml";                 // URL to the page this script is used in
//wc_pageName = "the CkB WebCams page";    // page name, used in some image ALT tags
//wc_spacerImg = "images/spacer.gif";      // location of a 1x1 pixel transparent .gif
//wc_iconBase = "images/webcam/";          // base location of icon button images
//wc_iconSpace = 3;                        // icon button pixel spacing

//wc_clickable = true;                     // are the WebCam images clickable? (zoom)

//wc_useSpareImg = true;                   // enable if you want an image for spaces in the "grid"
//wc_spareImgAltText = "Bloops!";          // ALT text for this 0th (spare) image

//wc_width = 577;                          // total width of the entire WebCam "grid"
//wc_padding = 6;                          // cellpadding / image padding for the WebCam "grid"

//wc_defaultCols = 3;                      // # columns to default to (only 2 or 3 is valid)

//wc_inOrder = true;                      // true: defaults to the order WebCams are defined
                                         // false: defaults to a random order every time
                                                                         
//wc_forceOrder = "";                      // optional, you can force the image loading order
                                         // by specifying a comma-delimited list like "1,2,3"

//wc_showInfo = true;                      // enable a link to the info page for each WebCam
//wc_showPopup = true;                     // enable a link to a popup window for each WebCam

// if you enable wc_showInfo or wc_showPopup, define their action URLs here
//
//wc_infoURL = "/ckb/forums/member.php?action=getinfo&userid=";
//wc_popupURL = "webcam_mini.html?cam=";
//wc_popupContentURL = "webcam_mini_content.html";



// the rest of this stuff shouldn't need to be edited!
//
wc_margin = (2 * wc_padding) + 1;

wc_width2col = parseInt((wc_width - wc_margin) / 2) - (2 * wc_padding);
wc_width2colSpan = (2 * wc_width2col) + ( wc_margin ) + (2 * wc_padding);

wc_width3col = parseInt((wc_width - (2 * wc_margin)) / 3) - (2 * wc_padding);
wc_width3colSpan = (2 * wc_width3col) + wc_margin + (2 * wc_padding);

function webCamGetPopupSize(size) { 
//    return ((size == 0) ? wc_width3colSpan : wc_width);
//    return ((size == 0) ? '602' : '640');
    return ((size == 1) ? wc_width2colSpan : wc_width2col);
    return ((size == 0) ? wc_width3colSpan : wc_width3col); 
};

wc_PopupSize = (typeof wc_PopupSize != "undefined" && wc_PopupSize == "0") ? 0 : 1;


wc_widthPopup = webCamGetPopupSize(wc_PopupSize);


// preload icon images
//
function webCamNewImg(arg) {
	if (document.images) {
		rslt = new Image();
		rslt.src = arg;
		return rslt;
	}
}

function webCamChangeImg() {
	if (document.images && (webCamPreloadFlag == true)) {
		for (var i=0; i<webCamChangeImg.arguments.length; i+=2) {
			document[webCamChangeImg.arguments[i]].src = webCamChangeImg.arguments[i+1];
		}
	}
}

var webCamPreloadFlag = false;
function webCamPreloadImages() {
	if (document.images) {
		wc_close_over =   webCamNewImg(wc_iconBase + "wc_close-over.gif");
		wc_home_over =    webCamNewImg(wc_iconBase + "wc_home-over.gif");
		wc_info_over =    webCamNewImg(wc_iconBase + "wc_info-over.gif");
		wc_popup_over =   webCamNewImg(wc_iconBase + "wc_popup-over.gif");
		wc_zoomin_over =  webCamNewImg(wc_iconBase + "wc_zoomin-over.gif");
		wc_zoomout_over = webCamNewImg(wc_iconBase + "wc_zoomout-over.gif");
		webCamPreloadFlag = true;
	}
}

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

// launch the popup window
//
function launchWebCamPopup(camNum, camSize) {
	var w = webCamGetPopupSize(camSize);
	var foo = window.open(wc_popupURL + camNum + "&wc_PopupSize=" + camSize, "webCamPopup_" + camNum, "scrollbars=no,resizable=no,status=no,width=" + (w + (2 * wc_padding)) + ",height=" + ((w * 0.75) + (2 * wc_padding) + 22));
}

// resize the popup window
function resizePopup() {
	var test = (typeof window == "object" && typeof window.innerWidth == "number");
	var w = (test) ? window.innerWidth : document.body.clientWidth;
	var h = (test) ? window.innerHeight : document.body.clientHeight;
	
	w = wc_widthPopup + (2 * wc_padding) - w;
	h = (wc_widthPopup * 0.75) + (2 * wc_padding) + 22 - h;
	
	top.resizeBy(w, h);
}

// draw a "container" for each webcam name/pic/etc
//
function webCamSpacer(w, h) {
	return "<img src='" + wc_spacerImg + "' width='" + w + "' height='" + h + "'>";
}

function webCamDrawCkBpic(camNum, displayMode) {
	var launchTarget = (displayMode == "Popup") ? " target='webCamMainPage'" : "";
	
	document.write("<table width='100%' cellpadding='0' cellspacing='0' border='0'>");
	document.write("  <tr>");
	document.write("    <td nowrap><p class='small'><a name='" + webCamName[camNum] + "'></a>" + webCamName[camNum] + "</p></td>");
	document.write("    <td align='right' nowrap>");
	
	// draw icon button bar
	//
	if (camNum != 0) {
		if (displayMode == "Popup") {
			document.write("<a href='" + wc_URL + "?zoom=y&order=" + camNum + "'" + launchTarget);
			document.write(" onmouseover='webCamChangeImg(\"wc_h_" + camNum + "\",\"" + wc_iconBase + "wc_home-over.gif\");return true;'");
			document.write(" onmouseout='webCamChangeImg(\"wc_h_" + camNum + "\",\"" + wc_iconBase + "wc_home.gif\");return true;'");
			document.write("><img name='wc_h_" + camNum + "' src='" + wc_iconBase + "wc_home.gif' border='0' alt='Click to load " + wc_pageName + "'></a>");
			document.write(webCamSpacer(wc_iconSpace, 1));
		}
		var wc_zoom = "";
		if (wc_clickable) {
			if (displayMode == "Popup") {
				document.write("<a href='" + wc_popupURL + camNum + "&wc_PopupSize=" + (1 - wc_PopupSize) + "'");
				wc_zoom = (wc_PopupSize == 1) ? "out" : "in";
			} else if (camNum == 0) {
				document.write("");
			} else if (displayMode == "2col" || displayMode == "3col") {
				document.write("<a href='" + wc_URL + "?zoom=y&order=" + camNum + "'");
				wc_zoom = "in";
			} else if (displayMode == "3colSpan") {
				document.write("<a href='" + wc_URL + "?order=" + camNum + "'");
				wc_zoom = "out";
			}
		}
		if (wc_zoom != "") {
			document.write(" onmouseover='webCamChangeImg(\"wc_z_" + camNum + "\",\"" + wc_iconBase + "wc_zoom" + wc_zoom + "-over.gif\");return true;'");
			document.write(" onmouseout='webCamChangeImg(\"wc_z_" + camNum + "\",\"" + wc_iconBase + "wc_zoom" + wc_zoom + ".gif\");return true;'");
			document.write("><img name='wc_z_" + camNum + "' src='" + wc_iconBase + "wc_zoom" + wc_zoom + ".gif' border='0' alt='Click to " + (wc_zoom == "in" ? "zoom" : "unzoom") + " WebCam'></a>");
			document.write(webCamSpacer(wc_iconSpace, 1));
		}
		
		if (wc_showInfo && webCamID[camNum] > 0) {
			document.write("<a href='" + wc_infoURL + webCamID[camNum] + "'" + launchTarget);
			document.write(" onmouseover='webCamChangeImg(\"wc_i_" + camNum + "\",\"" + wc_iconBase + "wc_info-over.gif\");return true;'");
			document.write(" onmouseout='webCamChangeImg(\"wc_i_" + camNum + "\",\"" + wc_iconBase + "wc_info.gif\");return true;'");
			document.write("><img name='wc_i_" + camNum + "' src='" + wc_iconBase + "wc_info.gif' border='0' alt='Click to view info for " + webCamName[camNum] + "'></a>");
		}
		if (wc_showInfo && wc_showPopup && webCamID[camNum] > 0) {
			document.write(webCamSpacer(wc_iconSpace, 1));
		}
		if (wc_showPopup) {
			if (displayMode == "Popup") {
				document.write("<a href='#' onclick='top.close();'");
				document.write(" onmouseover='webCamChangeImg(\"wc_c_" + camNum + "\",\"" + wc_iconBase + "wc_close-over.gif\");return true;'");
				document.write(" onmouseout='webCamChangeImg(\"wc_c_" + camNum + "\",\"" + wc_iconBase + "wc_close.gif\");return true;'");
				document.write("><img name='wc_c_" + camNum + "' src='" + wc_iconBase + "wc_close.gif' border='0' alt='Close Window'></a>");
			} else {
				document.write("<a href='#' onclick='launchWebCamPopup(" + camNum + ", " + (wc_zoom == "out" ? 1 : 0) + "); return false;'");
				document.write(" onmouseover='webCamChangeImg(\"wc_o_" + camNum + "\",\"" + wc_iconBase + "wc_popup-over.gif\");return true;'");
				document.write(" onmouseout='webCamChangeImg(\"wc_o_" + camNum + "\",\"" + wc_iconBase + "wc_popup.gif\");return true;'");
				document.write("><img name='wc_o_" + camNum + "' src='" + wc_iconBase + "wc_popup.gif' border='0' alt='Click to launch Popup'></a>");
			}
		}
	} else {
			document.write(webCamSpacer(1, 13));
	}
	document.write("    </td>");
	document.write("  </tr>");
	document.write("  <tr>");
	document.write("    <td colspan='2'>" + webCamSpacer(1, 3) + "</td>");
	document.write("  </tr>");
	document.write("</table>");

	if (displayMode == "Popup") {
		webCamDraw(camNum, wc_widthPopup, parseInt(wc_widthPopup * 0.75));
	} else if (displayMode == "3colSpan") {
		webCamDraw(camNum, wc_width3colSpan, parseInt(wc_width3colSpan * 0.75));
	} else if (displayMode == "3col") {
		webCamDraw(camNum, wc_width3col, parseInt(wc_width3col * 0.75));
	} else {
		webCamDraw(camNum, wc_width2col, parseInt(wc_width2col * 0.75));
	}

	if (wc_clickable && displayMode && camNum != 0) {
		document.write("</a>");
	}
	
	if (displayMode == "3colSpan") {
		document.write("      <table width='" + wc_width3colSpan + "' height='24' cellpadding='0' cellspacing='0' border='0'><tr><td align='center' valign='bottom'>");
		document.write("      <p><a href='" + wc_URL + "?order=" + camNum + "'>Return to un-zoomed view</a></p>");
		document.write("      </td></tr></table>");
	}
}

// allow the user to pass a comma-delimited list of indices to force
// displaying of webcam images in a specific order
//
function webCamCkBrandomOrder(startIdx, endIdx, displayOrder) {
	var displayOrder = (typeof displayOrder == "string") ? displayOrder : "";

	if (displayOrder.split(",").length >= endIdx - startIdx + 1) {
		return displayOrder;
		
	} else {
		
		do {
			randNum = parseInt(Math.random() * (endIdx - startIdx + 1)) + startIdx;
		}
		while (("," + displayOrder + ",").indexOf("," + randNum + ",") != -1);

		return webCamCkBrandomOrder(startIdx, endIdx, displayOrder + ((displayOrder == "") ? "" : ",") + randNum);
	}
}

// this is the function that gets called in the HTML page to draw the
// entire WebCam grid, see http://www.rj3.net/ckb/webcam.shtml for usage!
//
// you can force displaying from a start to end point by using those args :)
//
function webCamDrawCkBpage(startIdx, endIdx) {
	var startIdx = (typeof startIdx == "number") ? startIdx : 1;
	var endIdx = (typeof endIdx == "number") ? endIdx : webCamURL.length - 1;
	
	var displayOrder = (typeof order == "string") ? order : wc_forceOrder;
	var displayTemplate = (typeof zoom == "string" && zoom == "y") ? 4 : wc_defaultCols;

	if (wc_inOrder){
		var displayOrderArray = displayOrder.split(",");
		
		var displayOrder = (typeof displayOrder == "string" && displayOrderArray[0] != "") ? (displayOrderArray[0] + ",") : "";
		for (var i = 1; i < webCamURL.length; i++) {
			if (i != parseInt(displayOrderArray[0])) {
				displayOrder += i + ",";
			}
		}
	}
	var displayOrder = webCamCkBrandomOrder(startIdx, endIdx, displayOrder);
	if (wc_debugMode) document.write("<p>" + displayOrder + "</p>");

	var displayOrderArray = displayOrder.split(",");
	
	document.write("<table width='" + wc_width + "' cellpadding='" + wc_padding + "' cellspacing='0' border='0'>");
	
	if (displayTemplate == 3 || displayTemplate == 4) {
		
		var i = startIdx - 2;
		
		if (displayTemplate == 4  && displayOrderArray[0] >= startIdx && displayOrderArray[0] <= endIdx) {
			document.write("<tr>");
			document.write("  <td rowspan='3' colspan='3' valign='top'" + wc_bgColor + ">");

			webCamDrawCkBpic(displayOrderArray[++i], "3colSpan");

			document.write("  </td>");
			document.write("  <td rowspan='3'>" + webCamSpacer(1, 1) + "</td>");
		
			i = webCamDrawCkBtest(++i, endIdx, displayOrderArray[i], "3col");
			
			document.write("</tr>");
	
			document.write("<tr>");
			document.write("  <td>" + webCamSpacer(1, 1) + "</td>");
			document.write("</tr>");
	
			document.write("<tr>");
		
			i = webCamDrawCkBtest(++i, endIdx, displayOrderArray[i], "3col");
			
			document.write("</tr>");

			document.write("<tr>");
			document.write("  <td colspan='5'>" + webCamSpacer(1, 1) + "</td>");
			document.write("</tr>");
		}

		for (i++; i < endIdx; i++) {
	
			document.write("<tr>");
	
			i = webCamDrawCkBtest(i, endIdx, displayOrderArray[i], "3col");
			
			document.write("  <td>" + webCamSpacer(1, 1) + "</td>");
			
			i = webCamDrawCkBtest(++i, endIdx, displayOrderArray[i], "3col");

			document.write("  <td>" + webCamSpacer(1, 1) + "</td>");
			
			i = webCamDrawCkBtest(++i, endIdx, displayOrderArray[i], "3col");

			document.write("</tr>");

			if (i < endIdx - 1) {
				document.write("<tr>");
				document.write("  <td colspan='5'>" + webCamSpacer(1, 1) + "</td>");
				document.write("</tr>");
			}
		}
		
	} else {

		for (var i = startIdx - 1; i < endIdx; i++) {
	
			document.write("<tr>");
	
			i = webCamDrawCkBtest(i, endIdx, displayOrderArray[i], "2col");
			
			document.write("  <td>" + webCamSpacer(1, 1) + "</td>");
			
			i = webCamDrawCkBtest(++i, endIdx, displayOrderArray[i], "2col");

			document.write("</tr>");
			
			if (i < endIdx - 1) {
				document.write("<tr>");
				document.write("  <td colspan='4'>" + webCamSpacer(1, 1) + "</td>");
				document.write("</tr>");
			}
		}
	}
	
	document.write("</table>");
}

function webCamDrawCkBtest(curIdx, endIdx, orderIdx, mode) {
	var isImage = ((typeof webCamURL[curIdx + 1] == "string") && (webCamURL[curIdx + 1] != ""));

	document.write("<td" + ((wc_useSpareImg || isImage) ? wc_bgColor : "") + ">");
	if (isImage) {
		webCamDrawCkBpic(orderIdx, mode);
	} else {
		if (wc_useSpareImg) {
			webCamDrawCkBpic(0, mode);
		} else {
			document.write("&nbsp;");
		}
	}
	return curIdx;
}




