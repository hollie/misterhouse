mh/code/public:

This directory has working, ready to use, applications.  Unlike the 
code snippets in the code/examples directory, these files are typically
more complex, functioning code.

-----------

alarmclock_evan.pl
 - Evan Grahaet's alarm clock with snooze.

alarmclock_david.pl
 - David McLellan's alarm clock

alarm_concept.*
 - Nick Maddock's code for the Concept alarm system from http://www.innerrange.com

audible_menu.pl
audible_menu.txt
 - David Norwood's code for walking through mh menus with just one or two
   switches (e.g. air sip switches for the disabled), using
   audible feedback to help pick menu items/states.

AudioControl.pl
 - Bill Sobel's example of using Mp3Player.pm object

audrey_cid.pl
 - Chris Witte's code that request callerid data from the Audrey acid UDP server.

calllog.pl          
 - Caller ID for modem.  Modified from mh/code/public/Brian/calllog.pl
   by Ernie O. to use the CallerID.pm state and names arrays.
   Another example of logging phone data can be found in mh/code/bruce/phone*

callerid_doug*
 - Caller ID for modem, from Doug Parrish.  Ties into a DB file and has an
   optional PHP page.

caddx*.*
 - Chris Witte's code for monitoring the outputs from a CADDX nx8e alarm panel.

callerisdn.pl
 - Ron Klinkien's code for monitoring callerid on  AVM Fritz!Card
   (ISDN4BSD or ISDN4Linux required)


cbus_v2.0.zip
 - Richard Morgan's code for talking to CBUS devices via Clipsal CGATE 
( http://www.clipsal.com.au )

chart_xl.pl
 - Clive Freedman's code for generating html that calls Excel via activex to chart log data.

chimes_cuckoo_doug.pl
   Douglas Nakakihara's version that uses only one wav file

Compool*.pl
 - Bill Sobel's code for monitoring and controling ComPool pool/spa equipment.
   You can get/set time, get/set temperature, and get/set equipment states.    

copycode.pl
 - Jeff Crum's code for copying voice commands from one mh computer to another.

date_functions.pl
 - Jeff Crum's functions for dealing with dates (e.g. finding labor day).

dss_interface.pl
 - Andrew Drummond's code for providing serial port control of most dss receivers.

dialup_unix.pl
 - Gaetan linny Lord's code for starting/stopping a dialup ppp connection in linux.

door_monitor_jay.pl
 - Jay Archer's code for using an X10 powerflash and hawkeye motion sensors
   to monitor and control a garage door

froggyrita.pl
 - Gaetan Lord's code for the temp,pressure,humidity sensor from http://www.froggyhome.com

get_state.php
 - Douglas Parrish's example of how to get mh states from php

grafik.pl
 - Rob Williams's interfaces to the Lutron Grafik Eye system

hvac_craig.pl
 - Craig Schaeffer's example of a function he uses in 
   his HVAC setup to do a smart heat/cool setback cycle.

hvac_david.pl
 - David Lounsberry's code to monitor 14 different iButtons and control HVAC with a weeder board!
 
iButton_ws.pl
 - Craig Schaeffer's code for monitoring the iButton weather station

iButton_ws_brian.pl
 - Brian Paulson's example for monitoring the iButton weather station

iButton_ws_ernie.pl
 - Ernie Oporto's iButton code.  Includes an example for reading a
   DS2438-based humidity sensor using the Honeywell HIH-3605/3610. 

iButton_ws_client.pl
 - Doug Mackie's code for for getting iButton weather station data from Henriksen's tcp server


iButton temps ploted with gnuplot
 - Kieran Ames has a page showing how he plots ibutton temps with gnuplot here:
     http://ames.myip.org:81/pages/my_iButtonVenture.htm

ical.pl
 - David Lounsberry's code to run the mh/bin/ical_load program to create
   mh events based on the unix ical calander program.
   Similar to mh/code/bruce/outlook.pl and mh/bin/outlook_read (for windows).
   Set this mh.ini parm: calendar_file=/home/dbl/.calendar

ImageWebSub.pl
 - Samuel Bagfors example of a web icon selecting function

internet_hebcal.pl
 - Max Kelly's code for downloading a shabbat calendar

internet_ip_update*.pl
 - Updates IP servers/web pages with IP addresses

internet_speed_check.pl
 - Larry Roudebush's code to time ftp updload and download rates.

irman.pl
 - Code to receive IR signals from the $30 irman box, available at 
   http://evation.com/irman/interface.txt

irvs*
 - Walter Leemput's example of a DTFM driven phone menu, using the 
   Irvs phone module from CPAN (linux only).

ir_creative.pl
 - Richard Smith's example of reading IR data from Creative Credit Card Remotes.

HVweb.pl
 - Joseph Gaston's code to control Homevision controller via the Homevision web server 

mp3_control_GQmpeg.pl
 - Dave Lounsberry's code for controling the GQmpge.pl player on linux

mp3_control_mrMP3.pl
 - Douglas Nakakihara's code to control a Windows Media Player based mp3 player
   he wrote called mrMP3

mp3_control_xmms.pl, mp3_playlist_xmms.pl
 - Richard Phillips's code for controling the xmms MP3 player for Linux.
 - Also see xmms_*.pl members

mirror_directory*
 - Larry Roudebush's code mirror directories.
 
monitor_sump_pump.pl
 - Craig's code to monitor his sump pump

monitor_ipchainlog.pl
 - Use to a linux ipchain log for web traffic

monitor_occupancy_brian.pl
 - Brian Rudy's example of monitoring multiple motion sensors to determine
   activity in the house.

monitor_occupancy_jason.pl
 - An example of Jason Sharpe's algorithm for monitoring multiple motion
   sensors to determine activity away and sleep status.

omnistat.pl
 - Kent Noonan's preliminary code for controling HAI Omnistat Communicating 
   thermostats (e.g. RC80).  Kent switched houses before he had a chance
   to finish testing this code.

NetCallerID.pl
 - Timothy Spaulding's code to interface with the $30 NetCallerID box.  
   In addition to normal CallerID, it supports Call Waiting CallerID
   (callerid while you are on the phone).
   Also see mh/code/bruce/phone_netcallid.pl for another example.

news*.pl
 - Tom Kotowski's code for getting news and info from various web pages
 - Brian Rigsby did news_yahoo.pl

palm_calendar*
 - Axel Brown's code for copying palm calendar entries to the mh organizer calendar

pa_control_evan.pl
pa_control_evan_test.pl
 - Evan Graham's code for controling which rooms hear the sound 
   spoken or played by mh, using weeder DIO controled relays.

phone_logs_kieran.pl
 - Kieran Ames' code for summarizing recent callers.  Also see mh/code/bruce/phone_logs.pl

pictures_files1.pl
 - Robert Rozman's code that uses a dbm to index a photo database.

printer_control.pl
 - Paul Wilkinson's example of how to turn a printer on/off based on a unix print spool file.

random_time_offset.pl
 - Jeff Siddall's code for adding random offset times to time_now tests.

readrat_capture
readrat.pl
 - Kent Noonan's code for controling IR devices with the 
   RedRat interface: http://www.dodgies.demon.co.uk/index.html

rrd.pl
rrd_graph
rrd_create.sh
rrd_create.bat
 - David Lounsberry's example of how to create graphs using  rrdtool.
   Download from http://ee-staff.ethz.ch/~oetiker/webtools/rrdtool/
   You can see David's plots at: http://dittos.yi.org/automation/plots/temps.html 
   See &update_rrd in mh/code/bruce/iButton.pl for an example of logging data.
   To install RRDs.pm on windows, download the i386 distro, then from
   the perl-shared directory, run:  ppm install rrds.ppd
   After installing RRDs.pm, set the rrd_dir mh.ini parm to enable from mh.
   Edit and use rrd_create to initialize the RRD databases.

rcs.pl
 - Craig's code to run RCS X10 thermostats.

RCSs.pl
 - Chris Witte's code for talking to the RS232/485 versions of the RCS thermostats.

rcstx15_old.pl          
 - Old rcs code for running a RCS TX15 Thermostat.  Use rcs.pl instead.

send_numeric_page.pl
 - Jeff's code for paging via modem

send_alpha_page.pl
 - David's code for sending alphanumberic pages using the linux bip program

sensors_lm.pl
 - Denis Cheong's code to get motherboard temperature data from the (linux only) lm sensors program.

sensors_water.pl
 - Jeff Pagel's example for sensing water in the basement.
 
slinke_*
 - Brian Paulsen's examples of calling the Slinke.pm module he wrote.
   We don't have this integrated into mh yet.

speak_mbrola.pl
 - Example of using the mbrola TTS engine. 

speak_server.pl
 - Older code, now replaced with mhsend_server.pl and eliza_server.pl.
   If on windows, also see voice_client/server.pl

speak_voices.pl
 - A goofy example of speaking with a different voice for each word.
   This also demonstrates how to read and write wav files.

speak_proxy.pl
 - An example of how to allow for speech to distributed mh proxies 
   using the speak rooms= parm.

sprinklers_*.pl 
 - Brian Rudy and Bill Sobel's code for sprinklers

sms1.pl
 - Roger Bille's quick and dirty perl script to play with SMS 
using a GSM modem phone without keyboard and display but with RS232.

test_homebase.pl
 - example code on how to talk to the homebase (JDS star*) interfaces

test_homevision.pl
 - example code on how to talk to the homevision interface.

tv_info_clive.pl
 - Clive Freedman's code for tv queries (derived from mh/code/bruce/tv_info.pl

tv_info_ge.pl
 - Stoll Thomas's code for tv queries of german stations (uses mh/bin/get_tv_info_ge) 
   via http://www.tvspielfilm.de

video_inline.pl
 - Kent Noonan's code for controling the inline video scan doubler

vocp_func.pl
 - Dave Lounsberry's code for monitoring linux vocp logs for callerid and voice mail.

voicemodem.pl
 - Brian Klier's code for interfacing to a voice modem.  

voice_client/server.pl
 - Tim Doyle's code that allows mh to speak to other windows boxes, like his Windows box at work.

v4l_pvr.pl
 - David Norwood's Personal Video Recorder (PVR) script for Linux systems.
   It can record shows picked from the TV listings or shows that match a list of keywords.
   It has a basic web interface for controlling all its functionality.   

v4l_radio.pl
 - David Norwood's code for Linux that allows you to stream music from a video4linux
   compatible FM tuner card to shoutcast clients on your network.  

wakeup_on_lan.pl
 - Bill Sobel's code for waking up computers via lan.


weather.pl
 - Ernie Oporto's weather script that queries wunderground web sites

weather_com.pl
 - Uses Geo::Weather.pm to get weather data from weather.com.  Good for international sites.

weather_ec.pl
 - Harald Koch's code for parsing data from weatheroffice.ec.gc.ca into %Weather.

weather_sbweather.pl
 - Code for reading log files from the SBweather program.  I used to use this before I 
   wrote a direct interface for the Wx200 weather station (code/Bruce/weather_wx200.pl).

weather_vw.pl
 - An example of using Virtual Weatherstation ( http://www.ambientsw.com ) log data.
   Includes Clay Jackson's example of logging weather data to
   APRSWXNET: http://www.findu.com/aprswxnet.html
   For example:  http://www.findu.com/cgi-bin/wxpage.cgi?n7qnm 

weather_wrtv.pl
 - Tom K. example on geting weather from his local news web page

weather_upload.pl
 - David Norwood's code for uploading weather data to the
   wunderground personal weather project.

wxserver_client.pl
wxserver_server.pl
 - Tony Drumm's code that supports his wxserver weather protocol.
   wxserver_client.pl will get data from any wxserver.  wxserver_server.pl
   will serve the data in the mh %weather array.
   Tony also has code at his site that will serve data from a Peet Brother's weather station.

weather_monitor_ultimeter2000.pl
 - Kent Noonan's code for the Peet Bros Ultimeter 2000 weather station

weather_monitor_wmr968.pl
 - Tom Vanderpool's code for the wireless wmr968 (aka Radio Shack Accuweather) weather station.

webcam_lite.pl
 - Mike's code for allowing visitors to his webcam site to flash lights and
   type in TTS messages.  Also see mh/web/public/webcam_lite.html

webcam_ron.pl
 - Ron Klinkien's code for using a command line frame grabber to create
   a simple webcam. Also see mh/web/public/webcam_ron.shtml

weeder_david.pl
 - David Lounsberry's code for controling hist HVAC system with a Solid State Relay weeder board!

weeder_init.pl
 - Jeff Pagel's code for initializing weeder DIO cards.

winamp_control.pl
 - Evan Graham's code for controling and querying winamp using messaging via Win32::GUI. 

wintvpvr_grid.pl
 - Jeff Ferris's code for controlling a Hauppage WinTV PVR USB to record TV
   shows using the tv_grid web pages.

wintv_radio.pl
 - Mickey Argo's code for controling the radio on a wintv card. 
   Also see mh/web/public/wintv_radio.html


x10_video_security.pl
 - Mark Holm's code for a video surveillance system using X10 XCAM cameras and motion sensors.

x10_power_reset.pl
 - Example of how to reset X10 items after a power reset

Xmms_Control.pl
Xmms_jukebox.pl
Xmms_x10_control.pl
 - Gaetan Lord's files for controling the linux xmms mp3 player.  
   These files also interact with the web interface at /music/xmms (mh/web/music/xmms)
   More info in mh/web/music/xmms/README*
   Also see mp3_control_xmms.pl.

------------

mh/code/public/Brian:

calllog.pl          
 - Caller ID for modem.

klier.pl            
 - Misc code from Brian.  Includes examples of how to control winamp.

pageme.pl           
 - Brian's code for paging via modem

tracking.pl         
tracking.pos        
 - Brian's code for tracking car location/speed and weather station info with a ham radio TNC.
   Bruce has a modified/subseted version he uses in mh/code/bruce/tracking_aprs.pl

---------

mh/code/public/Danal

This is Danal's Estes's code.  Amongst other things,
he has ISDN callerid, Stanley garage door sensors, and DCS alarm pannel code. 

Garage_Door.pl
Garage_Door.txt
 - From Danal Estes.  Uses the X10_Items X10_Garage_Door object
   to receive Extended X10 data from Stanley modules.

---------

mh/code/public/Nick:

This is an example of a bare bones setup that we set up for Bruce's son Nick.
With tk turned off, and with few events, it consumes very little of Nick's 
valuable gaming computer resources ;)  Nick uses it in his room to control
a few lights and his mp3 player.  Bruce likes it cause he can then have 
his version of MisterHouse turn off Nick's music after hours :)

---------

mh/code/public/Roger

From Roger Bille on Jan 2002.  This code is targeting APRS but they include many different
technologies and therefore could be used as templates. For example:
 
 a)    Reading and sending data through TCP/IP sockets
 b)    Retrieve Web pages and decipher the content
 c)    Using SQL statement for select, insert and update an MS Access database.
       (used to send over APRS roadwork's within 30 km of a moving APRS station.)
 d)    Create web pages. This one is created live by my system ahub.pl. http://ahubswe.net/ahub.html
 e)    Calculating distances and bearing between locations
 
Some of them is better documented than others and they are constantly modified.

