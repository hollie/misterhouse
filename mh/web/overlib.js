////////////////////////////////////////////////////////////////////////////////////
//  overLIB 3.00  --  Please leave leave the following notice.
//
//  By Erik Bosrup (erik@bosrup.com)  Last modified 2000-02-25.
//  Portions by Dan Steinman (dansteinman.com).
//
//  Get the latest version at http://www.bosrup.com/web/overlib/
//
//  This script library was created for my personal usage from the start
//  but then it became popular and I made an easy to use version. It's that
//  version you're using now. Since this is free please don't try to sell
//  this solution to a company claiming it is yours. Give me credit where
//  credit is due and I'll be happy. And I'd love to see any changes you've
//  done to the code. Free to use - don't abuse.
//
//  To find out what you may do and not, see the Artistic License at:
//  http://www.opensource.org/licenses/artistic-license.html
//  If you are uncertain about something, please contact erik@bosrup.com.
//  Note that the Artistic License is not the final license for this script,
//  consider it as a guide as to what you may do.
////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////
// CONSTANTS
// Don't touch these. :)
////////////////////////////////////////////////////////////////////////////////////
var INARRAY		=	1;
var CAPARRAY		=	2;
var STICKY		=	3;
var BACKGROUND		=	4;
var NOCLOSE		=	5;
var CAPTION		=	6;
var LEFT		=	7;
var RIGHT		=	8;
var CENTER		=	9;
var OFFSETX		=	10;
var OFFSETY		=	11;
var FGCOLOR		=	12;
var BGCOLOR		=	13;
var TEXTCOLOR		=	14;
var CAPCOLOR		=	15;
var CLOSECOLOR		=	16;
var WIDTH		=	17;
var BORDER		=	18;
var STATUS		=	19;
var AUTOSTATUS		=	20;
var AUTOSTATUSCAP	=	21;
var HEIGHT		=	22;
var CLOSETEXT		=	23;
var SNAPX		=	24;
var SNAPY		=	25;
var FIXX		=	26;
var FIXY		=	27;
var FGBACKGROUND	=	28;
var BGBACKGROUND	=	29;
var PADX		=	30;
var PADY		=	31;
var PADX2		=	32;
var PADY2		=	33;
var FULLHTML		=	34;
var ABOVE		=	35;
var BELOW		=	36;
var CAPICON		=	37;
var TEXTFONT		=	38;
var CAPTIONFONT		=	39;
var CLOSEFONT		=	40;
var TEXTSIZE		=	41;
var CAPTIONSIZE		=	42;
var CLOSESIZE		=	43;


////////////////////////////////////////////////////////////////////////////////////
// DEFAULT CONFIGURATION
// You don't have to change anything here if you don't want to. All of this can be
// changed on your html page or through an overLIB call.
////////////////////////////////////////////////////////////////////////////////////

// Main background color (the large area)
// Usually a bright color (white, yellow etc)
//if (typeof ol_fgcolor == 'undefined') { var ol_fgcolor = "#CCCCFF";}
if (typeof ol_fgcolor == 'undefined') { var ol_fgcolor = "#F0F0F0";}
	
// Border color and color of caption
// Usually a dark color (black, brown etc)
if (typeof ol_bgcolor == 'undefined') { var ol_bgcolor = "#333399";}
	
// Text color
// Usually a dark color
if (typeof ol_textcolor == 'undefined') { var ol_textcolor = "#000000";}
	
// Color of the caption text
// Usually a bright color
if (typeof ol_capcolor == 'undefined') { var ol_capcolor = "#FFFFFF";}
	
// Color of "Close" when using Sticky
// Usually a semi-bright color
if (typeof ol_closecolor == 'undefined') { var ol_closecolor = "#9999FF";}

// Font face for the main text
if (typeof ol_textfont == 'undefined') { var ol_textfont = "Verdana,Arial,Helvetica";}

// Font face for the caption
if (typeof ol_captionfont == 'undefined') { var ol_captionfont = "Verdana,Arial,Helvetica";}

// Font face for the close text
if (typeof ol_closefont == 'undefined') { var ol_closefont = "Verdana,Arial,Helvetica";}

// Font size for the main text
if (typeof ol_textsize == 'undefined') { var ol_textsize = "1";}

// Font size for the caption
if (typeof ol_captionsize == 'undefined') { var ol_captionsize = "1";}

// Font size for the close text
if (typeof ol_closesize == 'undefined') { var ol_closesize = "1";}

// Width of the popups in pixels
// 100-300 pixels is typical
if (typeof ol_width == 'undefined') { var ol_width = "200";}
	
// How thick the ol_border should be in pixels
// 1-3 pixels is typical
if (typeof ol_border == 'undefined') { var ol_border = "1";}
	
// How many pixels to the right/left of the cursor to show the popup
// Values between 3 and 12 are best
if (typeof ol_offsetx == 'undefined') { var ol_offsetx = 10;}
	
// How many pixels to the below the cursor to show the popup
// Values between 3 and 12 are best
if (typeof ol_offsety == 'undefined') { var ol_offsety = 10;}

// Default text for popups
// Should you forget to pass something to overLIB this will be displayed.
if (typeof ol_text == 'undefined') { var ol_text = "Default Text"; }

// Default caption
// You should leave this blank or you will have problems making non caps popups.
if (typeof ol_cap == 'undefined') { var ol_cap = ""; }

// Decides if sticky popups are default.
// 0 for non, 1 for stickies.
if (typeof ol_sticky == 'undefined') { var ol_sticky = 0; }

// Default background image. Better left empty unless you always want one.
if (typeof ol_background == 'undefined') { var ol_background = ""; }

// Text for the closing sticky popups.
// Normal is "Close".
if (typeof ol_close == 'undefined') { var ol_close = "Close"; }

// Default vertical alignment for popups.
// It's best to leave RIGHT here. Other options are LEFT and CENTER.
if (typeof ol_hpos == 'undefined') { var ol_hpos = RIGHT; }

// Default status bar text when a popup is invoked.
if (typeof ol_status == 'undefined') { var ol_status = ""; }

// If the status bar automatically should load either text or caption.
// 0=nothing, 1=text, 2=caption
if (typeof ol_autostatus == 'undefined') { var ol_autostatus = 0; }

// Default height for popup. Often best left alone.
if (typeof ol_heigh == 'undefined') { var ol_height = -1; }

// Horizontal grid spacing that popups will snap to.
// 0 makes no grid, anything else will cause a snap to that grid spacing.
if (typeof ol_snapx == 'undefined') { var ol_snapx = 0; }

// Vertical grid spacing that popups will snap to.
// 0 makes no grid, andthing else will cause a snap to that grid spacing.
if (typeof ol_snapy == 'undefined') { var ol_snapy = 0; }

// Sets the popups horizontal position to a fixed column.
// Anything above -1 will cause fixed position.
if (typeof ol_fixx == 'undefined') { var ol_fixx = -1; }

// Sets the popups vertical position to a fixed row.
// Anything above -1 will cause fixed position.
if (typeof ol_fixy == 'undefined') { var ol_fixy = -1; }

// Background image for the popups inside.
if (typeof ol_fgbackground == 'undefined') { var ol_fgbackground = ""; }

// Background image for the popups frame.
if (typeof ol_bgbackground == 'undefined') { var ol_bgbackground = ""; }

// How much horizontal left padding text should get by default when BACKGROUND is used.
if (typeof ol_padxl == 'undefined') { var ol_padxl = 1; }

// How much horizontal right padding text should get by default when BACKGROUND is used.
if (typeof ol_padxr == 'undefined') { var ol_padxr = 1; }

// How much vertical top padding text should get by default when BACKGROUND is used.
if (typeof ol_padyt == 'undefined') { var ol_padyt = 1; }

// How much vertical bottom padding text should get by default when BACKGROUND is used.
if (typeof ol_padyb == 'undefined') { var ol_padyb = 1; }

// If the user by default must supply all html for complete popup control.
// Set to 1 to activate, 0 otherwise.
if (typeof ol_fullhtml == 'undefined') { var ol_fullhtml = 0; }

// Allow overLIB to load usage images. Set to zero to stop.
if (typeof o3_tracker == 'undefined') { var o3_tracker = 1; }
o3_tracker = 0;  // bbw This is a pain for dialup users ... disable it

// Default vertical position of the popup. Default should normally be BELOW.
// ABOVE only works when HEIGHT is defined.
if (typeof ol_vpos == 'undefined') { var ol_vpos = BELOW; }

// Default height of popup to use when placing the popup above the cursor.
if (typeof ol_aboveheight == 'undefined') { var ol_aboveheight = 0; }

// Default icon to place next to the popups caption.
if (typeof ol_caption == 'undefined') { var ol_capicon = ""; }



////////////////////////////////////////////////////////////////////////////////////
// ARRAY CONFIGURATION
// You don't have to change anything here if you don't want to. The following
// arrays can be filled with text and html if you don't wish to pass it from
// your html page.
////////////////////////////////////////////////////////////////////////////////////

// Array with texts.
var ol_texts = new Array("Array Text 0", "Array Text 1");

// Array with captions.
var ol_caps = new Array("Array Caption 0", "Array Caption 1");






////////////////////////////////////////////////////////////////////////////////////
// END CONFIGURATION
////////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////////
// INIT
////////////////////////////////////////////////////////////////////////////////////


// Runtime variables init. Used for runtime only, don't change, not for config!
var o3_text = "";
var o3_cap = "";
var o3_sticky = 0;
var o3_background = "";
var o3_close = "Close";
var o3_hpos = RIGHT;
var o3_offsetx = 2;
var o3_offsety = 2;
var o3_fgcolor = "";
var o3_bgcolor = "";
var o3_textcolor = "";
var o3_capcolor = "";
var o3_closecolor = "";
var o3_width = 100;
var o3_border = 1;
var o3_status = "";
var o3_autostatus = 0;
var o3_height = -1;
var o3_snapx = 0;
var o3_snapy = 0;
var o3_fixx = -1;
var o3_fixy = -1;
var o3_fgbackground = "";
var o3_bgbackground = "";
var o3_padxl = 0;
var o3_padxr = 0;
var o3_padyt = 0;
var o3_padyb = 0;
var o3_fullhtml = 0;
var o3_vpos = BELOW;
var o3_aboveheight = 0;
var o3_capicon = "";
var o3_textfont = "Verdana,Arial,Helvetica";
var o3_captionfont = "Verdana,Arial,Helvetica";
var o3_closefont = "Verdana,Arial,Helvetica";
var o3_textsize = "1";
var o3_captionsize = "1";
var o3_closesize = "1";



// Display state variables
var o3_x = 0;
var o3_y = 0;
var o3_allowmove = 0;
var o3_showingsticky = 0;
var o3_removecounter = 0;

// Our layer
var over = null;


// Decide browser version
var ns4 = (document.layers)? true:false
var ie4 = (document.all)? true:false

// Microsoft Stupidity Check(tm).
if (ie4) {
	if (navigator.userAgent.indexOf('MSIE 5')>0) {
		var ie5 = true;
	} else {
		var ie5 = false;
	}
} else {
	var ie5 = false;
}


// Capture events and set over to correct DOM position.
if ( (ns4) || (ie4) ) {
	if (ns4) over = document.overDiv
	if (ie4) over = overDiv.style
	document.onmousemove = mouseMove
	if (ns4) document.captureEvents(Event.MOUSEMOVE)
}



////////////////////////////////////////////////////////////////////////////////////
// PUBLIC FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////


// overlib(arg0, ..., argN)
// Loads parameters into global runtime variables.
function overlib() {
	
	// Load defaults to runtime.
	o3_text = ol_text;
	o3_cap = ol_cap;
	o3_sticky = ol_sticky;
	o3_background = ol_background;
	o3_close = ol_close;
	o3_hpos = ol_hpos;
	o3_offsetx = ol_offsetx;
	o3_offsety = ol_offsety;
	o3_fgcolor = ol_fgcolor;
	o3_bgcolor = ol_bgcolor;
	o3_textcolor = ol_textcolor;
	o3_capcolor = ol_capcolor;
	o3_closecolor = ol_closecolor;
	o3_width = ol_width;
	o3_border = ol_border;
	o3_status = ol_status;
	o3_autostatus = ol_autostatus;
	o3_height = ol_height;
	o3_snapx = ol_snapx;
	o3_snapy = ol_snapy;
	o3_fixx = ol_fixx;
	o3_fixy = ol_fixy;
	o3_fgbackground = ol_fgbackground;
	o3_bgbackground = ol_bgbackground;
	o3_padxl = ol_padxl;
	o3_padxr = ol_padxr;
	o3_padyt = ol_padyt;
	o3_padyb = ol_padyb;
	o3_fullhtml = ol_fullhtml;
	o3_vpos = ol_vpos;
	o3_aboveheight = ol_aboveheight;
	o3_capicon = ol_capicon;
	o3_textfont = ol_textfont;
	o3_captionfont = ol_captionfont;
	o3_closefont = ol_closefont;
	o3_textsize = ol_textsize;
	o3_captionsize = ol_captionsize;
	o3_closesize = ol_closesize;

	
	// What the next argument is expected to be.
	var parsemode = -1;

	for (i = 0; i < arguments.length; i++) {
		
		if (parsemode == 0) {
			// Arg is command
			if (arguments[i] == INARRAY) { parsemode = INARRAY; }
			if (arguments[i] == CAPARRAY) { parsemode = CAPARRAY; }
			if (arguments[i] == STICKY) { parsemode = opt_STICKY(arguments[i]); }
			if (arguments[i] == BACKGROUND) { parsemode = BACKGROUND; }
			if (arguments[i] == NOCLOSE) { parsemode = opt_NOCLOSE(arguments[i]); }
			if (arguments[i] == CAPTION) { parsemode = CAPTION; }
			if (arguments[i] == LEFT) { parsemode = opt_HPOS(arguments[i]); }
			if (arguments[i] == RIGHT) { parsemode = opt_HPOS(arguments[i]); }
			if (arguments[i] == CENTER) { parsemode = opt_HPOS(arguments[i]); }
			if (arguments[i] == OFFSETX) { parsemode = OFFSETX; }
			if (arguments[i] == OFFSETY) { parsemode = OFFSETY; }
			if (arguments[i] == FGCOLOR) { parsemode = FGCOLOR; }
			if (arguments[i] == BGCOLOR) { parsemode = BGCOLOR; }
			if (arguments[i] == TEXTCOLOR) { parsemode = TEXTCOLOR; }
			if (arguments[i] == CAPCOLOR) { parsemode = CAPCOLOR; }
			if (arguments[i] == CLOSECOLOR) { parsemode = CLOSECOLOR; }
			if (arguments[i] == WIDTH) { parsemode = WIDTH; }
			if (arguments[i] == BORDER) { parsemode = BORDER; }
			if (arguments[i] == STATUS) { parsemode = STATUS; }
			if (arguments[i] == AUTOSTATUS) { parsemode = opt_AUTOSTATUS(arguments[i]); }
			if (arguments[i] == AUTOSTATUSCAP) { parsemode = opt_AUTOSTATUSCAP(arguments[i]); }
			if (arguments[i] == HEIGHT) { parsemode = HEIGHT; }
			if (arguments[i] == CLOSETEXT) { parsemode = CLOSETEXT; }
			if (arguments[i] == SNAPX) { parsemode = SNAPX; }
			if (arguments[i] == SNAPY) { parsemode = SNAPY; }
			if (arguments[i] == FIXX) { parsemode = FIXX; }
			if (arguments[i] == FIXY) { parsemode = FIXY; }
			if (arguments[i] == FGBACKGROUND) { parsemode = FGBACKGROUND; }
			if (arguments[i] == BGBACKGROUND) { parsemode = BGBACKGROUND; }
			if (arguments[i] == PADX) { parsemode = PADX; }
			if (arguments[i] == PADY) { parsemode = PADY; }
			if (arguments[i] == FULLHTML) { parsemode = opt_FULLHTML(arguments[i]); }
			if (arguments[i] == ABOVE) { parsemode = opt_VPOS(arguments[i]); }
			if (arguments[i] == BELOW) { parsemode = opt_VPOS(arguments[i]); }
			if (arguments[i] == CAPICON) { parsemode = CAPICON; }
			if (arguments[i] == TEXTFONT) { parsemode = TEXTFONT; }
			if (arguments[i] == CAPTIONFONT) { parsemode = CAPTIONFONT; }
			if (arguments[i] == CLOSEFONT) { parsemode = CLOSEFONT; }
			if (arguments[i] == TEXTSIZE) { parsemode = TEXTSIZE; }
			if (arguments[i] == CAPTIONSIZE) { parsemode = CAPTIONSIZE; }
			if (arguments[i] == CLOSESIZE) { parsemode = CLOSESIZE; }


		} else {
			if (parsemode < 0) {
				// Arg is maintext, unless INARRAY
				if (arguments[i] == INARRAY) {
					parsemode = INARRAY;
				} else {
					o3_text = arguments[i];
					parsemode = 0;
				}
			} else {
				// Arg is option for command
				if (parsemode == INARRAY) { parsemode = opt_INARRAY(arguments[i]); }
				if (parsemode == CAPARRAY) { parsemode = opt_CAPARRAY(arguments[i]); }
				if (parsemode == BACKGROUND) { parsemode = opt_BACKGROUND(arguments[i]); }
				if (parsemode == CAPTION) { parsemode = opt_CAPTION(arguments[i]); }
				if (parsemode == OFFSETX) { parsemode = opt_OFFSETX(arguments[i]); }
				if (parsemode == OFFSETY) { parsemode = opt_OFFSETY(arguments[i]); }
				if (parsemode == FGCOLOR) { parsemode = opt_FGCOLOR(arguments[i]); }
				if (parsemode == BGCOLOR) { parsemode = opt_BGCOLOR(arguments[i]); }
				if (parsemode == TEXTCOLOR) { parsemode = opt_TEXTCOLOR(arguments[i]); }
				if (parsemode == CAPCOLOR) { parsemode = opt_CAPCOLOR(arguments[i]); }
				if (parsemode == CLOSECOLOR) { parsemode = opt_CLOSECOLOR(arguments[i]); }
				if (parsemode == WIDTH) { parsemode = opt_WIDTH(arguments[i]); }
				if (parsemode == BORDER) { parsemode = opt_BORDER(arguments[i]); }
				if (parsemode == STATUS) { parsemode = opt_STATUS(arguments[i]); }
				if (parsemode == HEIGHT) { parsemode = opt_HEIGHT(arguments[i]); }
				if (parsemode == CLOSETEXT) { parsemode = opt_CLOSETEXT(arguments[i]); }
				if (parsemode == SNAPX) { parsemode = opt_SNAPX(arguments[i]); }
				if (parsemode == SNAPY) { parsemode = opt_SNAPY(arguments[i]); }
				if (parsemode == FIXX) { parsemode = opt_FIXX(arguments[i]); }
				if (parsemode == FIXY) { parsemode = opt_FIXY(arguments[i]); }
				if (parsemode == FGBACKGROUND) { parsemode = opt_FGBACKGROUND(arguments[i]); }
				if (parsemode == BGBACKGROUND) { parsemode = opt_BGBACKGROUND(arguments[i]); }
				if (parsemode == PADX2) { parsemode = opt_PADX2(arguments[i]); } // must be before PADX
				if (parsemode == PADY2) { parsemode = opt_PADY2(arguments[i]); } // must be before PADY
				if (parsemode == PADX) { parsemode = opt_PADX(arguments[i]); }
				if (parsemode == PADY) { parsemode = opt_PADY(arguments[i]); }
				if (parsemode == CAPICON) { parsemode = opt_CAPICON(arguments[i]); }
				if (parsemode == TEXTFONT) { parsemode = opt_TEXTFONT(arguments[i]); }
				if (parsemode == CAPTIONFONT) { parsemode = opt_CAPTIONFONT(arguments[i]); }
				if (parsemode == CLOSEFONT) { parsemode = opt_CLOSEFONT(arguments[i]); }
				if (parsemode == TEXTSIZE) { parsemode = opt_TEXTSIZE(arguments[i]); }
				if (parsemode == CAPTIONSIZE) { parsemode = opt_CAPTIONSIZE(arguments[i]); }
				if (parsemode == CLOSESIZE) { parsemode = opt_CLOSESIZE(arguments[i]); }

			}
		}
	}
	
	return overlib300();
}



// Clears popups if appropriate
function nd() {
	if ( o3_removecounter >= 1 ) { o3_showingsticky = 0 };
	if ( (ns4) || (ie4) ) {
		if ( o3_showingsticky == 0 ) {
			o3_allowmove = 0;
			hideObject(over);
		} else {
			o3_removecounter++;
		}
	}
	
	return true;
}







////////////////////////////////////////////////////////////////////////////////////
// OVERLIB 3.00 FUNCTION
////////////////////////////////////////////////////////////////////////////////////


// This function decides what it is we want to display and how we want it done.
function overlib300() {

	// Make layer content
	var layerhtml;
	
	
	if (o3_background != "" || o3_fullhtml) {
		// Use background instead of box.
		layerhtml = ol_content_background(o3_text, o3_background, o3_fullhtml);
	} else {
		// They want a popup box.

		// Prepare popup background
		if (o3_fgbackground != "") {
			o3_fgbackground = "BACKGROUND=\""+o3_fgbackground+"\"";
		}
		if (o3_bgbackground != "") {
			o3_bgbackground = "BACKGROUND=\""+o3_bgbackground+"\"";
		}

		// Prepare popup colors
		if (o3_fgcolor != "") {
			o3_fgcolor = "BGCOLOR=\""+o3_fgcolor+"\"";
		}
		if (o3_bgcolor != "") {
			o3_bgcolor = "BGCOLOR=\""+o3_bgcolor+"\"";
		}

		// Prepare popup height
		if (o3_height > 0) {
			o3_height = "HEIGHT=" + o3_height;
		} else {
			o3_height = "";
		}

		// Decide which kinda box.
		if (o3_cap == "") {
			// Plain
			layerhtml = ol_content_simple(o3_text);
		} else {
			// With caption
			if (o3_sticky) {
				// Show close text
				layerhtml = ol_content_caption(o3_text, o3_cap, o3_close);
			} else {
				// No close text
				layerhtml = ol_content_caption(o3_text, o3_cap, "");
			}
		}
	}
	
	// We want it to stick!
	if (o3_sticky) {
		o3_showingsticky = 1;
		o3_removecounter = 0;
	}
	
	// Write layer
	layerWrite(layerhtml);
	
	// Prepare status bar
	if (o3_autostatus > 0) {
		o3_status = o3_text;
		if (o3_autostatus > 1) {
			o3_status = o3_cap;
		}
	}

	// When placing the layer the first time, even stickies may be moved.
	o3_allowmove = 0;

	// Show layer
	disp(o3_status);

	// Stickies should stay where they are.	
	if (o3_sticky) {
		o3_allowmove = 0;
		return false;
	} else {
		return false;
	}
}



////////////////////////////////////////////////////////////////////////////////////
// LAYER GENERATION FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////

// Makes simple table without caption
function ol_content_simple(text) {
	txt = "<TABLE WIDTH="+o3_width+" BORDER=0 CELLPADDING="+o3_border+" CELLSPACING=0 "+o3_bgcolor+" "+o3_height+"><TR><TD><TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=0 "+o3_fgcolor+" "+o3_fgbackground+" "+o3_height+"><TR><TD VALIGN=TOP><FONT FACE=\""+o3_textfont+"\" COLOR=\""+o3_textcolor+"\" SIZE=\""+o3_textsize+"\">"+text+"</FONT></TD></TR></TABLE></TD></TR></TABLE>"
	set_background("");
	return txt;
}

// Makes table with caption and optional close link
function ol_content_caption(text, title, close) {
	closing = "";
	if (close != "") {
		closing = "<TD ALIGN=RIGHT><A HREF=\"/\" onMouseOver=\"cClick();\"><FONT COLOR=\""+o3_closecolor+"\" FACE=\""+o3_closefont+"\" SIZE=\""+o3_closesize+"\">"+close+"</FONT></A></TD>";
	}
	if (o3_capicon != "") {
		o3_capicon = "<IMG SRC=\""+o3_capicon+"\"> ";
	}
	txt = "<TABLE WIDTH="+o3_width+" BORDER=0 CELLPADDING="+o3_border+" CELLSPACING=0 "+o3_bgcolor+" "+o3_bgbackground+" "+o3_height+"><TR><TD><TABLE WIDTH=100% BORDER=0 CELLPADDING=0 CELLSPACING=0><TR><TD><B><FONT COLOR=\""+o3_capcolor+"\" FACE=\""+o3_captionfont+"\" SIZE=\""+o3_captionsize+"\">"+o3_capicon+title+"</FONT></B></TD>"+closing+"</TR></TABLE><TABLE WIDTH=100% BORDER=0 CELLPADDING=2 CELLSPACING=0 "+o3_fgcolor+" "+o3_fgbackground+" "+o3_height+"><TR><TD VALIGN=TOP><FONT COLOR=\""+o3_textcolor+"\" FACE=\""+o3_textfont+"\" SIZE=\""+o3_textsize+"\">"+text+"</FONT></TD></TR></TABLE></TD></TR></TABLE>";
	set_background("");
	return txt;
}

// Sets the background picture, padding and lost more. :)
function ol_content_background(text, picture, hasfullhtml) {
	if (hasfullhtml) {
		txt = text;
	} else {
		txt = "<TABLE WIDTH="+o3_width+" BORDER=0 CELLPADDING=0 CELLSPACING=0 HEIGHT="+o3_height+"><TR><TD COLSPAN=3 HEIGHT="+o3_padyt+"></TD></TR><TR><TD WIDTH="+o3_padxl+"></TD><TD VALIGN=TOP WIDTH="+(o3_width-o3_padxl-o3_padxr)+"><FONT FACE=\""+o3_textfont+"\" COLOR=\""+o3_textcolor+"\" SIZE=\""+o3_textsize+"\">"+text+"</FONT></TD><TD WIDTH="+o3_padxr+"></TD></TR><TR><TD COLSPAN=3 HEIGHT="+o3_padyb+"></TD></TR></TABLE>";
	}
	set_background(picture);
	return txt;
}

function set_background(pic) {
	if (ns4) {
		over.background.src = pic;
	} else if(ie4) {
		over.backgroundImage = "url("+pic+")";
	}
}



////////////////////////////////////////////////////////////////////////////////////
// HANDLING FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////


// Displays the popup
function disp(statustext) {
	if ( (ns4) || (ie4) ) {
		if (o3_allowmove == 0) 	{
			placeLayer();
			showObject(over);
			o3_allowmove = 1;
		}
	}

	if (statustext != "") {
		self.status = statustext;
	}
}

// Decides where we want the popup.
function placeLayer() {
	var placeX, placeY;
	
	// HORIZONTAL PLACEMENT
	if (o3_fixx > -1) {
		// Fixed position
		placeX = o3_fixx;
	} else {
		// From mouse
		if (o3_hpos == CENTER) { // Center
			placeX = o3_x+o3_offsetx-(o3_width/2);
		}
		if (o3_hpos == RIGHT) { // Right
			placeX = o3_x+o3_offsetx;
		}
		if (o3_hpos == LEFT) { // Left
			placeX = o3_x-o3_offsetx-o3_width;
		}
	
		// Snapping!
		if (o3_snapx > 1) {
			var snapping = placeX % o3_snapx;
			if (o3_hpos == LEFT) {
				placeX = placeX - (o3_snapx + snapping);
			} else {
				// CENTER and RIGHT
				placeX = placeX + (o3_snapx - snapping);
			}
		}
	}

	
	
	// VERTICAL PLACEMENT
	if (o3_fixy > -1) {
		// Fixed position
		placeY = o3_fixy;
	} else {
		// From mouse
		if (o3_aboveheight > 0 && o3_vpos == ABOVE) {
			placeY = o3_y - (o3_aboveheight + o3_offsety);
		} else {
			// BELOW
			placeY = o3_y + o3_offsety;
		}

		// Snapping!
		if (o3_snapy > 1) {
			var snapping = placeY % o3_snapy;
			
			if (o3_aboveheight > 0 && o3_vpos == ABOVE) {
				placeY = placeY - (o3_snapy + snapping);
			} else {
				placeY = placeY + (o3_snapy - snapping);
			}
		}
	}


	// Actually move the object.	
	moveTo(over, placeX, placeY);
}


// Moves the layer
function mouseMove(e) {
	if (ns4) {o3_x=e.pageX; o3_y=e.pageY;}
	if (ie4) {o3_x=event.x; o3_y=event.y;}
	if (ie5) {o3_x=event.x+document.body.scrollLeft; o3_y=event.y+document.body.scrollTop;}
	
	if (o3_allowmove) {
		placeLayer();
	}
}

// The Close onMouseOver function for stickies
function cClick() {
	hideObject(over);
	o3_showingsticky=0;
}


// Usage statistics
function trk() {
	if ( (ns4) || (ie4) ) {
			bt=new Image(1,1); bt.src="http://www.bosrup.com/web/overlib/o3/tr.gif";
			
	}
	o3_tracker = 0;
}




////////////////////////////////////////////////////////////////////////////////////
// LAYER FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////


// Writes to a layer
function layerWrite(txt) {
        if (ns4) {
                var lyr = document.overDiv.document
                lyr.write(txt)
                lyr.close()
        }
        else if (ie4) document.all["overDiv"].innerHTML = txt
		if (o3_tracker) { trk(); }
}

// Make an object visible
function showObject(obj) {
        if (ns4) obj.visibility = "show"
        else if (ie4) obj.visibility = "visible"
}

// Hides an object
function hideObject(obj) {
        if (ns4) obj.visibility = "hide"
        else if (ie4) obj.visibility = "hidden"
        
        self.status = "";
}

// Move a layer
function moveTo(obj,xL,yL) {
        obj.left = xL
        obj.top = yL
}





////////////////////////////////////////////////////////////////////////////////////
// PARSER FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////


// Sets text from array.
function opt_INARRAY(id) {
	o3_text = ol_texts[id];
	return 0;
}

// Sets caption from array.
function opt_CAPARRAY(id) {
	o3_cap = ol_caps[id];	
	return 0;
}

// Sets stickiness.
function opt_STICKY(unused) {
	o3_sticky = 1;
	return 0;
}

// Sets background picture.
function opt_BACKGROUND(file) {
	o3_background = file;
	return 0;
}

// Sets use of close text.
function opt_NOCLOSE(unused) {
	o3_close = "";
	return 0;
}

// Sets caption.
function opt_CAPTION(text) {
	o3_cap = text;
	return 0;
}

// Sets hpos, for LEFT, RIGHT and CENTER.
function opt_HPOS(pos) {
	o3_hpos = pos;
	return 0;
}

// Sets the x offset
function opt_OFFSETX(offset) {
	o3_offsetx = offset;
	return 0;
}

// Sets the y offset
function opt_OFFSETY(offset) {
	o3_offsety = offset;
	return 0;
}


// Sets the fg color
function opt_FGCOLOR(clr) {
	o3_fgcolor = clr;
	return 0;
}

// Sets the bg color
function opt_BGCOLOR(clr) {
	o3_bgcolor = clr;
	return 0;
}

// Sets the text color
function opt_TEXTCOLOR(clr) {
	o3_textcolor = clr;
	return 0;
}

// Sets the caption color
function opt_CAPCOLOR(clr) {
	o3_capcolor = clr;
	return 0;
}

// Sets the close color
function opt_CLOSECOLOR(clr) {
	o3_closecolor = clr;
	return 0;
}

// Sets the popup width
function opt_WIDTH(pixels) {
	o3_width = pixels;
	return 0;
}

// Sets the popup border width
function opt_BORDER(pixels) {
	o3_border = pixels;
	return 0;
}

// Sets the status bar text
function opt_STATUS(text) {
	o3_status = text;
	return 0;
}

// Sets that status bar text to the text
function opt_AUTOSTATUS(val) {
	o3_autostatus = 1;
	return 0;
}

// Sets that status bar text to the caption
function opt_AUTOSTATUSCAP(val) {
	o3_autostatus = 2;
	return 0;
}

// Sets the popup height
function opt_HEIGHT(pixels) {
	o3_height = pixels;
	o3_aboveheight = pixels;
	return 0;
}

// Sets the close text.
function opt_CLOSETEXT(text) {
	o3_close = text;
	return 0;
}

// Sets horizontal snapping
function opt_SNAPX(pixels) {
	o3_snapx = pixels;
	return 0;
}

// Sets vertical snapping
function opt_SNAPY(pixels) {
	o3_snapy = pixels;
	return 0;
}

// Sets horizontal position
function opt_FIXX(pos) {
	o3_fixx = pos;
	return 0;
}

// Sets vertical position
function opt_FIXY(pos) {
	o3_fixy = pos;
	return 0;
}

// Sets the fg background
function opt_FGBACKGROUND(picture) {
	o3_fgbackground = picture;
	return 0;
}

// Sets the bg background
function opt_BGBACKGROUND(picture) {
	o3_bgbackground = picture;
	return 0;
}

// Sets the left x padding for background
function opt_PADX(pixels) {
	o3_padxl = pixels;
	return PADX2;
}

// Sets the top y padding for background
function opt_PADY(pixels) {
	o3_padyt = pixels;
	return PADY2;
}

// Sets the right x padding for background
function opt_PADX2(pixels) {
	o3_padxr = pixels;
	return 0;
}

// Sets the bottom y padding for background
function opt_PADY2(pixels) {
	o3_padyb = pixels;
	return 0;
}

// Sets that user provides full html.
function opt_FULLHTML(unused) {
	o3_fullhtml = 1;
	return 0;
}

// Sets vpos, for ABOVE and BELOW
function opt_VPOS(pos) {
	o3_vpos = pos;
	return 0;
}

// Sets the caption icon.
function opt_CAPICON(icon) {
	o3_capicon = icon;
	return 0;
}

// Sets the text font
function opt_TEXTFONT(fontname) {
	o3_textfont = fontname;
	return 0;
}

// Sets the caption font
function opt_CAPTIONFONT(fontname) {
	o3_captionfont = fontname;
	return 0;
}

// Sets the close font
function opt_CLOSEFONT(fontname) {
	o3_closefont = fontname;
	return 0;
}

// Sets the text font size
function opt_TEXTSIZE(fontsize) {
	o3_textsize = fontsize;
	return 0;
}

// Sets the caption font size
function opt_CAPTIONSIZE(fontsize) {
	o3_captionsize = fontsize;
	return 0;
}

// Sets the close font size
function opt_CLOSESIZE(fontsize) {
	o3_closesize = fontsize;
	return 0;
}





////////////////////////////////////////////////////////////////////////////////////
// OVERLIB 2 COMPATABILITY FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////

// Converts old 0=left, 1=right and 2=center into constants.
function vpos_convert(d) {
	if (d == 0) {
		d = LEFT;
	} else {
		if (d == 1) {
			d = RIGHT;
		} else {
			d = CENTER;
		}
	}
	
	return d
}

// Simple popup
function dts(d,text) {
	o3_hpos = vpos_convert(d);
	overlib(text, o3_hpos, CAPTION, "");
}

// Caption popup
function dtc(d,text, title) {
	o3_hpos = vpos_convert(d);
	overlib(text, CAPTION, title, o3_hpos);
}

// Sticky
function stc(d,text, title) {
	o3_hpos = vpos_convert(d);
	overlib(text, CAPTION, title, o3_hpos, STICKY);
}

// Simple popup right
function drs(text) {
	dts(1,text);
}

// Caption popup right
function drc(text, title) {
	dtc(1,text,title);
}

// Sticky caption right
function src(text,title) {
	stc(1,text,title);
}

// Simple popup left
function dls(text) {
	dts(0,text);
}

// Caption popup left
function dlc(text, title) {
	dtc(0,text,title);
}

// Sticky caption left
function slc(text,title) {
	stc(0,text,title);
}

// Simple popup center
function dcs(text) {
	dts(2,text);
}

// Caption popup center
function dcc(text, title) {
	dtc(2,text,title);
}

// Sticky caption center
function scc(text,title) {
	stc(2,text,title);
}