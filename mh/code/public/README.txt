
mh/code/public:

This directory has working, ready to use, applications.  Unlike the 
code snippets in the code/examples directory, these files are typically
more complex, functioning code.

-----------

alarmclock_evan.pl
 - Evan Grahaet's alarm clock with snooze.

alarmclock_david.pl
 - David McLellan's alarm clock

alarmclock_doug.pl
 - Doug Nakakihara's alarm clock for for  file based timed reminders.

audible_menu.pl
audible_menu.txt
 - David Norwood's code for walking through mh menus with just one or two
   switches (e.g. air sip switches for the disabled), using
   audible feedback to help pick menu items/states.

aqualink.pl
 - Tim Doyle's code for the Jandy AquaLink RS pool/spa controller.
   Like Compool.pl, you can get/set various temps and states.                    

AudioControl.pl
 - Bill Sobel's example of using Mp3Player.pm object

calllog.pl          
 - Caller ID for modem.  Modified from mh/code/public/Brian/calllog.pl
   by Ernie O. to use the CallerID.pm state and names arrays.
   Another example of logging phone data can be found in mh/code/bruce/phone*

callerid_doug*
 - Caller ID for modem, from Doug Parrish.  Ties into a DB file and has an
   optional PHP page.

callerisdn.pl
 - Ron Klinkien's code for monitoring callerid on  AVM Fritz!Card
   (ISDN4BSD or ISDN4Linux required)

chimes_cuckoo*.pl
chimes_westminster.pl
 - David Norwood's code for chimeing like cuckoo and grandfather clocks.
   Douglas Nakakihara's version that uses only one wav file

Compool*.pl
 - Bill Sobel's code for monitoring and controling ComPool pool/spa equipment.
   You can get/set time, get/set temperature, and get/set equipment states.    

copycode.pl
 - Jeff Crum's code for copying voice commands from one mh computer to another.

date_functions.pl
 - Jeff Crum's functions for dealing with dates (e.g. finding labor day).

door_monitor_jay.pl
 - Jay Archer's code for using an X10 powerflash and hawkeye motion sensors
   to monitor and control a garage door

iButton_ws.pl
 - Craig Schaeffer's code for monitoring the iButton weather station

iButton_ws_client.pl
 - Doug Mackie's code for for getting iButton weather station data from Henriksen's tcp server

ical.pl
 - David Lounsberry's code to run the mh/bin/ical_load program to create
   mh events based on the unix ical calander program.
   Similar to mh/code/bruce/outlook.pl and mh/bin/outlook_read (for windows).
   Set this mh.ini parm: calendar_file=/home/dbl/.calendar

ImageWebSub.pl
 - Samuel Bagfors example of a web icon selecting function

internet_earthquake.pl
internet_earthquake_cal.pl
 - Tim Doyle's script for monitoring earthquakes.
 - David Norwood created a California specific _cal version.

internet_ip_update.pl
internet_ip_update_craig.pl
 - Updates IP servers/web pages with IP addresses

internet_starshine.pl
 - Tim Doyle's code to announce when one of the visible passes of
   a StarShine satellite is about to occur.

irvs*
 - Walter Leemput's example of a DTFM driven phone menu, using the 
   Irvs phone module from CPAN (linux only).

mp3_control_GQmpeg.pl
 - Dave Lounsberry's code for controling the GQmpge.pl player on linux

mp3_control_mrMP3.pl
 - Douglas Nakakihara's code to control a Windows Media Player based mp3 player
   he wrote called mrMP3

monitor_sump_pump.pl
 - Craig's code to monitor his sump pump

monitor_server.pl
 - Use to monitor web hits to the mh server

monitor_ipchainlog.pl
 - Use to a linux ipchain log for web traffic

NetCallerID.pl
 - Timothy Spaulding's code to interface with the $30 NetCallerID box.  
   In addition to normal CallerID, it supports Call Waiting CallerID
   (callerid while you are on the phone).
   Aso see mh/code/bruce/phone_netcallid.pl for another example.

news*.pl
 - Tom Kotowski's code for getting news and info from various web pages
 - Brian Rigsby did news_yahoo.pl

pa_control_evan.pl
pa_control_evan_test.pl
 - Evan Graham's code for controling which rooms hear the sound 
   spoken or played by mh, using weeder DIO controled relays.

phone_logs_kieran.pl
 - Kieran Ames' code for summarizing recent callers.  Also see mh/code/bruce/phone_logs.pl

printer_control.pl
 - Paul Wilkinson's example of how to turn a printer on/off based on a unix print spool file.

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

rcstx15_old.pl          
 - Old rcs code for running a RCS TX15 Thermostat.  Use rcs.pl instead.

send_numeric_page.pl
 - Jeff's code for paging via modem

send_alpha_page.pl
 - David's code for sending alphanumberic pages using the linux bip program

sensors_lm.pl
 - Denis Cheong's code to get motherboard temperature data from the (linux only) lm sensors program.

slinke_*
 - Brian Paulsen's examples of calling the Slinke.pm module he wrote.
   We don't have this integrated into mh yet.

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

voicemodem.pl
 - Brian Klier's code for interfacing to a voice modem.  

voice_client/server.pl
 - Tim Doyle's code that allows mh to speak to other windows boxes, like his Windows box at work.

weather.pl
 - Ernie Oporto's weather script that queries wunderground web sites

weather_com.pl
 - Uses Geo::Weather.pm to get weather data from weather.com.  Good for international sites.

weather_sbweather.pl
 - Code for reading log files from the SBweather program.  I used to use this before I 
   wrote a direct interface for the Wx200 weather station (code/Bruce/weather_wx200.pl).

weather_vw.pl
 - An example of using Virtual Weatherstation log data

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

aws_weather.pl
weather_aws.pl
weather_monitor_aws.pl
 - Brian Rudy's weather scripts for AWS live web weather sites

weather_monitor_ultimeter2000.pl
 - Kent Noonan's code for the Peet Bros Ultimeter 2000 weather station

webcam_lite.html
webcam_lite.pl
 - Mike's code for allowing visitors to his webcam site to flash lights and
   type in TTS messages.

webcam_ron.html
webcam_ron.pl
 - Ron Klinkien's code for using a command line frame grabber to create
   a simple webcam.

winamp_control.pl
 - Evan Graham's code for controling and querying winamp using messaging via Win32::GUI. 

wintvpvr_grid.pl
 - Jeff Ferris's code for controlling a Hauppage WinTV PVR USB to record TV
   shows using the tv_grid web pages.

x10_video_security.pl
 - Mark Holm's code for a video surveillance system using X10 XCAM cameras and motion sensors.


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
