Tattler Applet v1.0
-------------------

Copyright (C) 2000, John W. Klar, Jr.

This applet and code are licensed under the GNU LGPL.  
See the Tattler/COPYING file for details.

What is it?
-----------
Tattler is a Java applet intended to be embedded in an HTML page to enable
realtime notification from the page's server to the browser.  This is useful
in cases where polling is impractical or an ugly page reload needs to be
avoided.

The Tattler applet opens a tcp socket (def. 9999) back to the host running the
web server that orginated the page.  Whenever the service sends a message, the
applet calls the named Javascript function (def. tattler) with the message as
an argument.

Usage
-----
<applet code="tattler.class" archive="tattler.jar" width=1 height=1 mayscript>
 <param name="dstPort" value=7000></param>
 <param name="tgtFunction" value="Mess"></param>
</applet>

The "dstPort" and "tgtFunction" parameters are optional.  Their defaults are
9999 and "tattler" respectively.  The value of the "tgtFunction" parameter is
case sensitive and must match that of a Javascript function with at least one
argument.

Compatibility
-------------
I have personally tested this on both IE5 and Netscape 4.7 on Win98 and 
Netscape 4.7.2 on Linux.  I have heard rumors that this will not work in Mac
IE5.5 but it will work in Mac Netscape 4.7.  Use of the Java Plugin may help.

Compiling
---------
You need to add the netscape.javascript.JSObject & .JSException classes to
your classpath.  I symlinked /usr/lib/netscape/java/classes/java40.jar
to $JDK_HOME/jre/lib/ext/java40.jar.  NOTE: in some instances netscape
installs under /usr/local/lib/netscape...

Using JDK1.2.2 for Linux I just typed:

$ javac tattler.java
$ jar cvf tattler.jar *.class

As always, YMMV.

Manifest
--------
README		 		this file
COPYING				The GNU LGPL
TODO
tattler.html			Example web-page
tattler.jar			Class Archive
tattler.java			Applet shell for tattleClientThread
tattleClientThread.java		The real work is here
tattle_serv.tcl			A test server written in Tcl/Tk

Testing
-------
This is easiest if your local workstation has an httpd.

Install the tattler.html and tattler.jar files in the same directory in your
html heirarchy.  The tattle_serv.tcl script must be run on the machine as the
web server.  This is a Java applet restriction[1].  The tattle_serv script
will pop up a window with a push button.

Fire up your web-browser and point it at the tattler.html page thru the
web-server.  The tattle_serv script will print a connect message to stdout.

Click the push button.  An alert dialog will pop up with the message encoded
in the script.

FYI, tattle_serv will only talk to the last host that connected.

[1] The restriction is for unsigned applets.  Web servers are light enough
that one should be able to run on the same machine as the notification server.
If you must contact another host you will need to modify the applet (and sign
it!).  I strongly advise you to add another parameter with the default set to
that returned by app.getCodeBase().getHost().

Conclusion
----------
Feel free to play with all the code.  There is certainly room for improvement
as this was mostly a proof-of-concept exercise.  Even so, it has enough
functionality to signal simple (one-line) messages.

