$Date$
$Revision$

mh/code/public:

This directory has code sent in by you, the public.
Unlike the code snippets in the code/examples directory, these files are typically
more complex, functioning code.

Much of this code is not actively maintained.   The more common, activly maintained
code is in the code/common directory.  You can select or deselect that code using
the web interface.

-----------

alarmclock_evan.pl
 - Evan Grahaet's alarm clock with snooze.

alarmclock_david.pl
 - David McLellan's alarm clock

concept_*
 - Nick Maddock's code for the Concept alarm system from http://www.innerrange.com

audible_menu.pl
audible_menu.txt
 - David Norwood's code for walking through mh menus with just one or two
   switches (e.g. air sip switches for the disabled), using
   audible feedback to help pick menu items/states.

asterisk_*.*
 - Jason Sharpe's mh interface to the Asterisk phone system:  http://www.asterisk.org which
allow you to send commands (voice, etc) to the MH via touch tone menus.

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

dreambox.pl
- Timo Sariwating's code for interfacing to the the European Dreambox satelite receiver.

dcs_pc5401.pl
- Jocelyn Brouillard's code for the DSC Alarm PC5401 Serial interface.

froggyrita.pl
 - Gaetan Lord's code for the temp,pressure,humidity sensor from http://www.froggyhome.com

games_chess.pl
 - Lennart Lopin's voice interface to chess

garage_door_code.pl
 - Jeff Pagel's code for monitoring and controlling garage doors.

gas_prices.pl
 - Dan Hoffard's code to find low gas prices in For Worth, TX.

get_state.php
 - Douglas Parrish's example of how to get mh states from php

grafik.pl
 - Rob Williams's interfaces to the Lutron Grafik Eye system

hvac_craig.pl
 - Craig Schaeffer's example of a function he uses in
   his HVAC setup to do a smart heat/cool setback cycle.

hvac_david.pl
 - David Lounsberry's code to monitor 14 different iButtons and control HVAC with a weeder board!

HVweb.pl
 - Joseph Gaston's code to control Homevision controller via the Homevision web server

iButton_temps.pl
 - Use digitemp to read ibuttons, when the built in mh perl code has problems reading ibutton temps.

iButton_DS2450.pl
 - Brian Rudy's sample code for communicating with the DS2450 Quad A/D converter

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

internet_usgs.pl
 - Rick Steeve's code for monitoring the water level of any river or lake in the continental US that
   is monitored by the USGS.  Whenever that level passes a certain point MH will send notification.


internet_speed_check.pl
 - Larry Roudebush's code to time ftp updload and download rates.

irman.pl
 - Code to receive IR signals from the $30 irman box, available at
   http://evation.com/irman/interface.txt

irvs*
 - Walter Leemput's example of a DTFM driven phone menu, using the
   Irvs phone module from CPAN (linux only).

ivr.pl and ivr.menu
 - Jason Sharpe's code for DTFM Interactive Voice Response using the Stargate phone interface.

ir_creative.pl
 - Richard Smith's example of reading IR data from Creative Credit Card Remotes.

mh_restart.pl
 - Richard Phillips's example and notes on restarting MisterHouse each night.

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

monitor_dj.pl
 - An example adjust volume on winamp whenever the mh TTS is speaking.

monitor_im_status.pl
 - Steve Switzer's example of monitoring an im buddy status.

monitor_mh.pl
 - An example of on mh box monitoring another and warning when it goes down.

monitor_mbm*.pl
 - Craig Schaeffer and Danal Estes's code for montioring motherboard temperature data, using mbm.

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

mr26_vdr.pl
 - Norm Dressler's script to send remote control commands to VDR
  ( http://www.cadsoft.de/vdr/ ) from an X10 RF remote, via a MR26 interface.

omnistat.pl
 - Kent Noonan's preliminary code for controling HAI Omnistat Communicating
   thermostats (e.g. RC80).  Kent switched houses before he had a chance
   to finish testing this code.

news*.pl
 - Tom Kotowski's code for getting news and info from various web pages
 - Brian Rigsby did news_yahoo.pl
 - Dan Hoffard did news_star_telegram.pl and news_onion.pl

palm_calendar*
 - Axel Brown's code for copying palm calendar entries to the mh organizer calendar

pa_control_evan.pl
pa_control_evan_test.pl
 - Evan Graham's code for controling which rooms hear the sound
   spoken or played by mh, using weeder DIO controled relays.

pha_k256.pl
 - Lincoln Foreman's example of reading data from phanderson's K256 kit which can
   monitor 256 DS1820 temperature sensors, 8 bits digital IO, and 11 bits of analog IO.
   Available for $50 from http://www.phanderson.com/t64.html

phone_identifier.pl
 - Craig  Schaeffer's code for talking to the 2+ line incoming/outgoing/DTFM
   Identifier phone line monitor: http://www.yes-tele.com/mlm.html

phone_logs_kieran.pl
 - Kieran Ames' code for summarizing recent callers.  Also see mh/code/bruce/phone_logs.pl

phone_merlin.pl
 - Pete Flaherty's test code for talking to the Merlin phone system.

phonelogger.tgz
 - Walter Leemput's code to allow a linux box to monitor DTMF, callerid, and phone messages via a soundcard.


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

robot_er1.pl
 - Dave Hall's code for interacting with the Evolution Robotics ER1 robot: http://www.evolution.com/er1/

rrd.pl
rrd_graph
rrd_create.sh
rrd_create.bat
 - David Lounsberry's example of how to create graphs using  rrdtool.
   Download from http://ee-staff.ethz.ch/~oetiker/webtools/rrdtool/
   You can see David's plots at: http://dittos.yi.org/automation/plots/temps.html
   See &update_rrd in mh/code/bruce/iButton_bruce.pl for an example of logging data.
   To install RRDs.pm on windows, download the i386 distro, then from
   the perl-shared directory, run:  ppm install rrds.ppd
   After installing RRDs.pm, set the rrd_dir mh.ini parm to enable from mh.
   Edit and use rrd_create to initialize the RRD databases.

rrd_graph_web.*
 - Robin van Oosten's code for graphing iButtons with RRDsDavid Lounsberry's
   example of how to create graphs using  rrdtool.

rcs.pl
 - Craig's code to run RCS X10 thermostats.

RCSs.pl
 - Chris Witte's code for talking to the RS232/485 versions of the RCS thermostats.

rcstx15_old.pl
 - Old rcs code for running a RCS TX15 Thermostat.  Use rcs.pl instead.

school_clock.pl
 - A simple clock for announcing time till school bus

school_closing.pl
 - Screen scrapes tv/radio web pages for school closings (e.g. snow days).

send_numeric_page.pl
 - Jeff's code for paging via modem

send_alpha_page.pl
 - David's code for sending alphanumberic pages using the linux bip program

sensors_lm.pl
 - Denis Cheong's code to get motherboard temperature data from the (linux only) lm sensors program.

sensors_water.pl
 - Jeff Pagel's example for sensing water in the basement.

siteplayer.pl
 - Scott Johnson's example of sending digital signals to a $30 siteplayer ethernet interface: http://www.siteplayer.com/

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

sports_score_bball.pl
 - Robert Hughes code for getting basketball scores.

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

tivo_direct.*
 - Andrew Drummond's code for controling a Tivo dvr.

Tivo_Control.*
 - Krik Bauer's code for controling a Tivo dvr.

video_inline.pl
 - Kent Noonan's code for controling the inline video scan doubler

vocp_func.pl
 - Dave Lounsberry's code for monitoring linux vocp logs for callerid and voice mail.

vocp_sean.pl
 - Sean Walker's code for integrating with linux vocp voicemail.

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

weather_email_breaking.pl
 - Larry Roudebush's code for announcing important weather info from email alerts.

weather_metar.pl
- Matthew Williams's code for getting weather provided the international standard METAR format.

weather_mos_forecast.pl
 - Jason Sharpee's code to decode MOS forecast data.

weather_sbweather.pl
 - Code for reading log files from the SBweather program.  I used to use this before I
   wrote a direct interface for the Wx200 weather station (code/Bruce/weather_wx200.pl).

weather_vw.pl
 - An example of using Virtual Weatherstation ( http://www.ambientsw.com ) log data.
   Includes Clay Jackson's example of logging weather data to
   APRSWXNET: http://www.findu.com/aprswxnet.html
   For example:  http://www.findu.com/cgi-bin/wxpage.cgi?n7qnm

weather_warning.pl
 - Dan Hoffard's code that periodically checks the NOAA website for severe
   watches and warnings in any given area and speaks warning messages

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

webcam_bob.pl
 - Bob Hughes's code for snapping pictures using the linux program v4lctl.

webcam_joel.pl
 - Joel Davididson's code for snapping pictures using the linux program v4lctl.

weeder_david.pl
 - David Lounsberry's code for controling hist HVAC system with a Solid State Relay weeder board!

weeder_doorbell.pl
 - Bill Young's example of monitoring and controlling a doorbell with a weeder board.

weeder_init.pl
 - Jeff Pagel's code for initializing weeder DIO cards.

whole_house_audio_speech.pl
whole_house_audio_musica.pl
 - Kirk Bauer's code for distributing speech and music using multiple sources and multiple destinations.

winamp_control.pl
 - Evan Graham's code for controling and querying winamp using messaging via Win32::GUI.

winlirc_clietn.pl
 - Robert Rozman's example of reading winlirc IR data: http://winlirc.sourceforge.net/

wintvcapture.pl
 - Bazyle Butcher's example using sendkeys to the WinTV program.

wintvpvr_grid.pl
 - Jeff Ferris's code for controlling a Hauppage WinTV PVR USB to record TV
   shows using the tv_grid web pages.

wintv_radio.pl
 - Mickey Argo's code for controling the radio on a wintv card.
   Also see mh/web/public/wintv_radio.html

Xantech_test.pl
 - Lou Montulli's code for a web based control test of the Xantech whole house audio system.

x10_battery_charger.pl
 - An example of using X10 to control a battery charger.

x10_power_reset.pl
 - Example of how to reset X10 items after a power reset

x10_priority.pl
 - Richard Koch code for creating a x10_priority_set function for allowing high priority X10
   events to get prioritized to get sent first.

x10_video_security.pl
 - Mark Holm's code for a video surveillance system using X10 XCAM cameras and motion sensors.

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
