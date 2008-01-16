// WebCam Auto-Updater v1.9
//
// MODIFIED FROM THE ORIGINAL FOR MisterHouse!
//  by Pete Flaherty pjf@cape.com
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


// Global settings for webcam interface
//  seperated for maintainence
//  and possible MH ini intgration

// ----- USER SETTINGS HERE -----
//

// Width and height of each cam pic
var webCamWidth = 200;
var webCamHeight = 90;

// Time in sec to update images
//  This may get overridden if there are many cameras
//  then a best guess estimate of the time will be calculated
var webCamUpdateInterval = 5;


// Here's some bonus stuff for the CkB site, you might not want this.. but it's really cool!
// You can see it in action here: http://www.rj3.net/ckb/webcam.shtml
//
// Note: needs at least 3 defined WebCams to work properly.. but of course, you wouldn't
//       use this unless you had at least half a dozen webcams anyways, right?

var wc_debugMode = false;                    // Toggle Debug Mode on/off

// bg color may get overridden thru passed parm from mh
var wc_bgColor = 	" bgcolor='#0099cc'";  //'#1A3B3C';       // HTML bgcolor around each WebCam image
var wc_URL = 	"webcam.shtml";          // URL to the page this script is used in
var wc_pageName = 	"the MH WebCams page";   // page name, used in some image ALT tags
var wc_spacerImg = 	"images/spacer.gif";     // location of a 1x1 pixel transparent .gif
var wc_iconBase = 	"images/webcam/";        // base location of icon button images
var wc_iconSpace = 3;                        // icon button pixel spacing

var wc_clickable = true;                     // are the WebCam images clickable? (zoom)

var wc_useSpareImg = true;                   // enable if you want an image for spaces in the "grid"
var wc_spareImgAltText = "Bloops!";          // ALT text for this 0th (spare) image

var wc_width = 600; //640;                          // total width of the entire WebCam "grid"
var wc_padding = 3;                          // cellpadding / image padding for the WebCam "grid"

var wc_defaultCols = 2;                      // # columns to default to (only 2 or 3 is valid)

var wc_inOrder = true;                      // true: defaults to the order WebCams are defined
                                         // false: defaults to a random order every time
                                         
var wc_forceOrder = "1,3,2";                 // optional, you can force the image loading order
                                         // by specifying a comma-delimited list like "1,2,3"
                                          
var wc_showInfo = false;                      // enable a link to the info page for each WebCam
var wc_showPopup = true;                     // enable a link to a popup window for each WebCam
                                                                                  
                                         // if you enable wc_showInfo or wc_showPopup, define their action URLs here
                                         //
var wc_infoURL = "";
var wc_popupURL = "webcam_mini.shtml?cam=";
var wc_popupContentURL = "webcam_mini_content.shtml";
                                                                                  
