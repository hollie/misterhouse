# sends messages to a Dreambox DVB reveicer (www.dream-multimedia-tv.de)
# These are nice DVB-S Receivers running Linux and they are very polular here in Europe
# only tested on a DM-7000S with amber display

# Timo Sariwating 12/oktober/2004 (timo@ab-telecom.nl)

=begin comment

Enable Dreambox support by using these parms in mh.ini or your mh.private.ini

dreambox_ip= 192.168.1.1 # IP Adress op Dreambox
dreambox_user= root	 # Username
dreambox_password= password	# Password
dreambox_label= Message from Misterhouse	# Standard subject on messagebox
dreambox_timeout= 5	 # Standard timeout for messagebox

Now you can use these parms in your perl code like this next example: 

my $Dreambox_IP = $config_parms{dreambox_ip};
my $Dreambox_label = $config_parms{dreambox_label};
my $Dreambox_timeout = $config_parms{dreambox_timeout};

				# Displays a message on the Dreambox OSD on 12:00
if (time_cron "00 12 * * 1-5") {
     speak(mode => 'unmuted', volume => 80, text => "Test Dreambox!");
     get "http://$Dreambox_IP/cgi-bin/xmessage?timeout=$Dreambox_timeout&caption=$Dreambox_label&body=This is a Dreambox Test.";
}

or 

				# Puts the Dreambox in standby if the A2 button is pushed
$dreambox_button = new Serial_Item('XA2');
if (state_now $dreambox_button) {
     &speak(mode => 'unmuted', volume => 80, text => "Dreambox switched to standby.");
     get "http://$Dreambox_IP/cgi-bin/admin?command=standby";
}

here is a list of command you can use:

http://dbox/?path=1:0:1:6dca:44d:1:0:0:0:0: ; zap to this Service
Parameter 1: ?
Parameter 2: ?
Parameter 3: tv/radio/data/... ?
Parameter 4: sid
Parameter 5: tsid
Parameter 6: onid
Parameter 7: ?
Parameter 8: ?
Parameter 9: ?
Parameter10: ?

http://dbox/setVolume?volume=5 ; Set Volume  (Range 0...10)
http://dbox/setVolume?mute=1 ; Mute ON (1) - Mute OFF (0)
http://dbox/cgi-bin/status ; Current Enigma-Date and -Time
http://dbox/cgi-bin/switchService ; ?????
http://dbox/cgi-bin/admin?command=shutdown ; dbox/dreambox shutdown
http://dbox/cgi-bin/admin?command=reboot ; dbox/dreambox reboot
http://dbox/cgi-bin/admin?command=restart ; Enigma restart
http://dbox/cgi-bin/admin?command=standby ; Enigma standby
http://dbox/cgi-bin/admin?command=wakeup ; Enigma wakeup from standby
http://dbox/cgi-bin/audio?volume=30 ; Set Volume (Range 64...1) 
http://dbox/cgi-bin/audio?mute=0 ; Mute ON (1) - Mute OFF (0)
http://dbox/cgi-bin/getPMT ; give the PMT as XML-File
http://dbox/cgi-bin/message?Hallo ; Puts message on de TV Screen
http://dbox/cgi-bin/xmessage?timeout=3&caption=Nachricht&body=Hallo ; Puts Message on TV Screen (More options) 
http://dbox/audio.m3u ; starts a Audio-HTTP-Stream of current Services
http://dbox/version ; shows Version of Enigma
http://dbox/cgi-bin/getcurrentepg ; shows the EPG of active Service
http://dbox/cgi-bin/streaminfo ; give the Stream-Data of active Service
http://dbox/channels/getcurrent ; gives the names of active Service

not all of these are tested

=cut

my $Dreambox_IP = $config_parms{dreambox_ip};

if ( time_cron "34 17 * * 1-5" ) {
    my $epg = get "http://$Dreambox_IP/channels/getcurrent";
    speak(
        mode   => 'unmuted',
        volume => 80,
        text   => "The Dreambox is set to channel, $epg"
    );
    display $epg;
}
