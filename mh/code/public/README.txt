
mh/code/public:

This directory has working, ready to use, applications.  Unlike the 
code snippets in the code/examples directory, these files are typically
more complex, functioning code.

-----------

calllog.pl          
 - Caller ID for modem.  Modified from mh/code/public/Brian/calllog.pl
   by Ernie O. to use the CallerID.pm state and names arrays.
   Another example of logging phone data can be found in mh/code/bruce/phone*

Compool*.pl
 - Bill Sobel's code for monitoring and controling ComPool pool/spa equipment.
   You can get/set time, get/set temperature, and get/set equipment states.    

door_monitor_jay.pl
 - Jay Archer's code for using an X10 powerflash and hawkeye motion sensors
   to monitor and control a garage door

iButton_ws.pl
 - Craig Schaeffer's code for monitoring the iButton weather station

internet_ip_update.p
 - Updates IP servers/web pages with IP addresses

Garage_Door.pl
Garage_Door.txt
 - From Danal Estes.  Uses the X10_Items X10_Garage_Door object
   to receive Extended X10 data from Stanley modules.

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

news*.pl
 - Tom Kotowski's code for getting news and info from various web pages

rcs.pl
 - Craig's code to run RCS X10 thermostats.

rcstx15_old.pl          
 - Old rcs code for running a RCS TX15 Thermostat.  Use rcs.pl instead.

send_numeric_page.pl
 - Jeff's code for paging via modem

send_alpha_page.pl
 - David's code for sending alphanumberic pages using the linux bip program

slinke_build_IR_database.pl
slinke_decode_IR.pl
 - Brian Paulsen's examples of calling the Slinke.pm module he wrote.
   We don't have this integrated into mh yet.

test_homebase.pl
 - example code on how to talk to the homebase (JDS star*) interfaces

test_homevision.pl
 - example code on how to talk to the homevision interface.

voicemodem.pl
 - Brian Klier's code for interfacing to a voice modem.  

weather_sbweather.pl
 - Code for reading log files from the SBweather program.  I used to use this before I 
   wrote a direct interface for the Wx200 weather station (code/Bruce/weather_wx200.pl).

weather_wrtv.pl
 - Tom K. example on geting weather from his local news web page

webcam_lite.html
webcam_lite.pl
 - Mike's code for allowing visitors to his webcam site to flash lights and
   type in TTS messages.

x10_ma26.txt
 - Kevin Olande's code for reading data from an X10 wireless mouse receiver.
   Also reads normal X10 traffic!

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

---------

mh/code/public/Nick:

This is an example of a bare bones setup that we set up for Bruce's son Nick.
With tk turned off, and with few events, it consumes very little of Nick's 
valuable gaming computer resources ;)  Nick uses it in his room to control
a few lights and his mp3 player.  Bruce likes it cause he can then have 
his version of MisterHouse turn off Nick's music after hours :)



