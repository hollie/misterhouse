# Category = Audrey
#@
#@ This is an example of controling the led and screen on the audrey.
#@ This is the Master Extended Audrey functionality for all defined
#@ Audries in you mh.ini file the entries should be in the 'audrey_ips'
#@ with all the definitions in NAME-IP format this can be a comma delimited
#@ list eg adurey_ips=Bedroom-192.168.1.1,Kitchen-192.168.1.2
#@
#@ All the functions in this module are intended for use in the standard
#@ MrAudrey image for the Audrey, No further hacking is necessary.
#@ For the play music function to work, you will need to install the
#@ optional mpgnoph2 MrAudrey package
#@
#@ Further information on the MrAudrey Image may be seen at
#@ <a href="http://www.mraudrey.net">http://www.mraudrey.net</a> -or-
#@ <a href="http://vsa.cape.com/~pjf">http://vsa.cape.com/~pjf</a>.
#@
#  MRU 20050214-04,
#  v0.16 Pete Flaherty - initial relase

#  v0.17 Pete Flaherty - updates to use get_url over a get

#  V0.18 Pete Flaherty - updated parse, eliminates text part getting called
#	now it only sends out by IP

#  V0.19 H.Plato - added options to prevent Audrey reboots, voice command responding,
#       and to point the music to the mp3_stream_server_port if defined.

#  V0.20 Pete Flaherty - updated reboot option to be off by default, audrey_monitor module
#	will actually check the Audreys and insure they are operational and reboot/power cycle
#	as needed. Ini parameter audrey_reboot_on_startup

#  V0.21 Pete Flaherty - commented read tagline code out so module does not fail dependencies
# 	when loading for first time (mh errors out if tagline is not selected ... my bad)
#

=begin comment

The following comments are from the original code
This is based on the original code in the bruce code dir

For this to work, you need to update your Audrey to allow for
control from external browsers.   Instructions for this, can be found
here:

  http://homepage.mac.com/deandavis/audrey/AudreyOnOff.html

More info is in mh/docs/faq_ia.* 'What is an Audrey'

All needed functionality is also included in the MrAudrey image
 so there is no need to do any further hacks to the Audrey

-This should not be necessary
Also change the http://audrey urls to the appropriate ip address,
or update your DNS server / local hosts file.

On windows boxes the hosts file is windows\system32\drivers\etc\hosts
On unix, it is in /etc/hosts

V0.19 Added to more options
Audrey_no_reboot_on_startup to prevent Audrey's from rebooting when MH starts
Audrey_no_voice_respond to prevent confirmation speech when the Audrey's voice commands are executed

=cut

# We need to define the elements for the web page Before we do anything
# noloop=start
my $listNM = ("all");
my @Aname;
my @Aip;
my $Acount = 0;

#Get all the Audrey listings from the ini file, and make an array of them
for my $ip ( split ',', $config_parms{Audrey_IPs} ) {
    ( $Aname[$Acount], $Aip[$Acount] ) = split '-', $ip;
    $Aip[$Acount] =~ s/\s*$//;
    print "$Aname[$Acount], $Aip[$Acount]\n";
    $listNM = $listNM . ",$Aname[$Acount]";
    $Acount++;
}
print "My list of Audreys $listNM \n";

# noloop=stop

# debug check
# print "My list of Audreys $listNM \n";

# Voice commands for Audrey functions

$v_audrey_mail_led_on =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey mail light on" );
$v_audrey_mail_led_off =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey mail light off" );
$v_audrey_mail_led_blink =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey mail light blink" );

$v_audrey_top_led_on =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey top light on" );
$v_audrey_top_led_off =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey top light off" );
$v_audrey_top_led_blink =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey top light blink" );

$v_audrey_both_leds_on =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey both lights on" );
$v_audrey_both_leds_off =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey both lights off" );
$v_audrey_both_leds_blink =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey both lights blink" );

$v_audrey_screen_on = new Voice_Cmd( "Set [" . $listNM . "] Audrey screen on" );
$v_audrey_screen_off =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey screen off" );

$v_audrey_photos =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey to photo screen" );

$v_audrey_wav = new Voice_Cmd( "Set [" . $listNM . "] Audrey to a wav file" );

$v_audrey_tagline =
  new Voice_Cmd( "Read tag line to [" . $listNM . "] Audrey" );

$v_audrey_music_on  = new Voice_Cmd( "Set [" . $listNM . "] Audrey music on" );
$v_audrey_music_off = new Voice_Cmd( "Set [" . $listNM . "] Audrey music off" );

$v_audrey_volume_0 =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey Volume to 0" );
$v_audrey_volume_20 =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey Volume to 20" );
$v_audrey_volume_50 =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey Volume to 50" );
$v_audrey_volume_75 =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey Volume to 75" );
$v_audrey_volume_100 =
  new Voice_Cmd( "Set [" . $listNM . "] Audrey Volume to 100" );

$v_audrey_reboot = new Voice_Cmd( "Reboot [" . $listNM . "] Audrey" );

if ( said $v_audrey_top_led_on) {
    my $state = $v_audrey_top_led_on->{state};
    $v_audrey_top_led_on->respond("Turning $state Audrey top light on.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'top_led', 'on', $state );
}

if ( said $v_audrey_top_led_off) {
    my $state = $v_audrey_top_led_off->{state};
    $v_audrey_top_led_off->respond("Turning $state Audrey top light off.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'top_led', 'off', $state );
}

if ( said $v_audrey_top_led_blink) {
    my $state = $v_audrey_top_led_blink->{state};
    $v_audrey_top_led_blink->respond("Blinking $state Audrey top light.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'top_led', 'blink', $state );
}

if ( said $v_audrey_mail_led_on) {
    my $state = $v_audrey_mail_led_on->{state};
    $v_audrey_top_led_on->respond("Turning $state Audrey mail light on.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'mail_led', 'on', $state );
}

if ( said $v_audrey_mail_led_off) {
    my $state = $v_audrey_mail_led_off->{state};
    $v_audrey_mail_led_off->respond("Turning $state Audrey mail light off.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'mail_led', 'off', $state );
}

if ( said $v_audrey_mail_led_blink) {
    my $state = $v_audrey_mail_led_blink->{state};
    $v_audrey_mail_led_blink->respond("Blinking $state Audrey mail light.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'mail_led', 'blink', $state );
}

if ( said $v_audrey_both_leds_on) {
    my $state = $v_audrey_both_leds_on->{state};
    $v_audrey_both_leds_on->respond("Turning $state Audrey lights on.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'both_leds', 'on', $state );
}

if ( said $v_audrey_both_leds_off) {
    my $state = $v_audrey_both_leds_off->{state};
    $v_audrey_both_leds_off->respond("Turning $state Audrey lights off.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'both_leds', 'off', $state );
}

if ( said $v_audrey_both_leds_blink) {
    my $state = $v_audrey_both_leds_blink->{state};
    $v_audrey_both_leds_blink->respond("Blinking $state Audrey lights.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'both_leds', 'blink', $state );
}

if ( said $v_audrey_music_on) {
    my $state = $v_audrey_music_on->{state};
    $v_audrey_music_on->respond("Turning $state Audrey music on.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'music', 'Play', $state );
}

if ( said $v_audrey_music_off) {
    my $state = $v_audrey_music_off->{state};
    $v_audrey_music_off->respond("Turning $state Audrey music off.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'music', 'Stop', $state );
}

if ( said $v_audrey_volume_0) {
    my $state = $v_audrey_volume_0->{state};
    $v_audrey_volume_0->respond("Setting $state Audrey volume to 0.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'volume', '0', $state );
}

if ( said $v_audrey_volume_20) {
    my $state = $v_audrey_volume_20->{state};
    $v_audrey_volume_20->respond("Setting $state Audrey volume to 20.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'volume', '20', $state );
}

if ( said $v_audrey_volume_50) {
    my $state = $v_audrey_volume_50->{state};
    $v_audrey_volume_50->respond("Setting $state Audrey volume to 50.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'volume', '50', $state );
}

if ( said $v_audrey_volume_75) {
    my $state = $v_audrey_volume_75->{state};
    $v_audrey_volume_75->respond("Setting $state Audrey volume to 75.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'volume', '75', $state );
}

if ( said $v_audrey_volume_100) {
    my $state = $v_audrey_volume_100->{state};
    $v_audrey_volume_100->respond("Setting $state Audrey volume to 100.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'volume', '100', $state );
}

if ( said $v_audrey_reboot) {
    my $state = $v_audrey_reboot->{state};
    $v_audrey_reboot->respond("Rebooting $state Audrey.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'reboot', undef, $state );
}

if ( said $v_audrey_screen_on) {
    my $state = $v_audrey_screen_on->{state};
    $v_audrey_screen_on->respond("Turning $state Audrey screen on.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'screen', 'on', $state );
}

if ( said $v_audrey_screen_off) {
    my $state = $v_audrey_screen_off->{state};
    $v_audrey_screen_off->respond("Turning $state Audrey screen off.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'screen', 'off', $state );
}

if ( said $v_audrey_photos) {
    my $state = $v_audrey_photos->{state};
    $v_audrey_photos->respond("Showing photos on $state Audrey.")
      unless $config_parms{Audrey_no_voice_respond};
    &audrey( 'photos', undef, $state );
}

if ( said $v_audrey_wav) {
    my $state = $v_audrey_wav->{state};
    $v_audrey_wav->respond("Playing sound on $state Audrey.")
      unless $config_parms{Audrey_no_voice_respond};
    play
      address => &audrey_ip($state),
      file    => '../sounds/hello_from_bruce.wav';

    #   get "http://$state/cgi-bin/SendMessage?M=GOTO_URL\\&S=http://$Info{Machine}:$config_parms{http_port}/sounds/hello_from_bruce.wav";
}

# ready to go if tagline code is enabled
#if (said $v_audrey_tagline) {
#	my $state = $v_audrey_tagline->{state};
#	speak address => &audrey_ip($state), text => (read_next $house_tagline);
#	$v_audrey_tagline->respond("Reading house tag line on $state Audrey.") unless $config_parms{Audrey_no_voice_respond};
#}

# if ($state = said $v_audrey_music_on) {
#     get "http://$state/cgi-bin/mpctrl?action=Play&file=http://205.188.245.133:8068" ;
# }
# if ($state = said $v_audrey_volume_0) {
#     get "http://$state/cgi-bin/volume?0";
# }
#
# if ($state = said $v_audrey_volume_20) {
#     get "http://$state/cgi-bin/volume?20";
# }
# if ($state = said $v_audrey_volume_50) {
#     get "http://$state/cgi-bin/volume?50";
# }
# if ($state = said $v_audrey_volume_75) {
#     get "http://$state/cgi-bin/volume?75";
# }
# if ($state = said $v_audrey_volume_100) {
#     get "http://$state/cgi-bin/volume?100";
# }

# change the definitions  defined in the mh.private.ini / mh.ini file(s)
# under 'audrey-ips'
sub audrey_ip {

    my ($list)  = @_;
    my ($list2) = "";
    $list = 'Kitchen' if !$list or $list eq '1';

    my @Aname;
    my @Aip;

    my $Acount = 0;

    #Get all the Audrey listings from the ini file, and make an array of them
    for my $ip ( split ',', $config_parms{Audrey_IPs} ) {
        ( $Aname[$Acount], $Aip[$Acount] ) = split '-', $ip;

        #	$Aip[$Acount] =~ tr/\s//;
        $Aip[$Acount] =~ s/\s//;
        print "$Aname[$Acount], $Aip[$Acount]\n";

        #$listNM +=",$Aname[$Acount]";
        $Acount++;
    }

    my $AC = 0;

    #    # make up a list of all the entries Name only
    #    # $list = 'Kitchen,Piano,Desk,Bedroom' if $list eq 'all';
    $list2 = "";
    if ( $list eq 'all' ) {
        for ( $AC = 0; $AC < $Acount + 1; $AC++ ) {
            $list2 = "$list2 $Aname[$AC],$Aip[$AC]";

            #$list2 = "$list2 $Aname[$AC]";
            #$list2 = "$list2 $Aip[$AC]";
            $list2 = "$list2," if ( $Aname[ $AC + 1 ] ne '' );
        }
        print "$Acount - List  name - $list2 \n";
    }

    # we make up a list with the specific entry
    for ( $AC = 0; $AC < $Acount + 1; $AC++ ) {
        $list =~ s/$Aname[$AC]/$Aip[$AC]/;
        $list = "$list," if ( $Aname[ $AC + 1 ] ne '' );

        #print "list spec - $list\n";
    }
    $list = $list2 if $list2;
    print "list output $list\n";
    $list =~ s/\s*$//;
    return $list;
}

# Here we take the translated voice commands from above and do something
# we lill soop through all the entries if there is more than one (like 'all')
sub audrey {
    my ( $mode, $astate, $list ) = @_;
    for my $address ( split ',', &audrey_ip($list) ) {
        if ( substr( $address, 0, 1 ) ne ' ' ) {

            # some verbosity to the console about what were doing
            print "Setting Audrey $mode to $astate for $address!\n"
              if $Debug{audrey};
            $address =~ s/\s*$//;    #remove trailing whitespace if there
            my $audrey_cmd = "";

            if ( $mode eq 'top_led' ) {
                $state = 0 if $astate eq 'off';
                $state = 2 if $astate eq 'blink';
                $state = 1 if $astate eq 'on';

                #get "http://$address/led.shtml?t$state";
                $audrey_cmd = "http://$address/led.shtml?t$state";
            }

            if ( $mode eq 'mail_led' ) {
                $state = 0 if $astate eq 'off';
                $state = 2 if $astate eq 'blink';
                $state = 1 if $astate eq 'on';

                #get "http://$address/led.shtml?m$state";
                $audrey_cmd = "http://$address/led.shtml?m$state";
            }

            if ( $mode eq 'both_leds' ) {
                $state = 0 if $astate eq 'off';
                $state = 2 if $astate eq 'blink';
                $state = 1 if $astate eq 'on';

                #get "http://$address/led.shtml?t$state m$state";
                $audrey_cmd = "'http://$address/led.shtml?t$state m$state'";
            }
            elsif ( $mode eq 'screen' ) {
                $state = 0 if $astate eq 'off';
                $state = 1 if $astate eq 'on';

                #$get "http://$address/screen.shtml?$state";
                $audrey_cmd = "http://$address/screen.shtml?$state";
            }
            elsif ( $mode eq 'photos' ) {

                #get "http://$address/cgi-bin/SendMessage?M=GOTO_URL&S=http://$Info{IPAddress_local}:$config_parms{http_port}/misc/photos.html";
                $audrey_cmd =
                  "http://$address/cgi-bin/SendMessage?M=GOTO_URL\\&S=http://$Info{IPAddress_local}:$config_parms{http_port}/misc/photos.html";
            }
            elsif ( $mode eq 'music' ) {
                $state = 0 if $astate eq 'Stop';
                $state = 1 if $astate eq 'Play';

                #get "http://$address/cgi-bin/mpctrl?action=$astate&file=http://192.168.0.150:8010";
                if ( $config_parms{mp3_stream_server_port} ) {
                    $audrey_cmd =
                      "http://$address/cgi-bin/mpctrl?action=$astate\\&file=$config_parms{mp3_stream_server_port}";
                }
                else {
                    $audrey_cmd =
                      "http://$address/cgi-bin/mpctrl?action=$astate\\&file=http://192.168.0.150:8010";
                }
            }
            elsif ( $mode eq 'volume' ) {
                $state = $astate;

                #get "http://$address/cgi-bin/volume?$astate";
                $audrey_cmd = "http://$address/cgi-bin/volume?$astate";
            }
            elsif ( $mode eq 'reboot' ) {
                $state = $astate;

                #get "http://$address/reboot.shtml";
                $audrey_cmd = "http://$address/reboot.shtml";
            }
            run "get_url -quiet $audrey_cmd /dev/null";
        }

    }
}

# We restart the audries once MH is up, and we want to so everything is in sync
#  keeping no reboot ini for compatability
if ($Startup) {

    my $RebootMe = "YES";
    $RebootMe = "NO"  unless $config_parms{Audrey_reboot_on_startup};
    $RebootMe = "YES" unless !$config_parms{Audrey_reboot_on_startup};

    if (   ( $config_parms{Audrey_reboot_on_startup} eq "no" )
        or ( $config_parms{Audrey_reboot_on_startup} eq "0" ) )
    {
        $RebootMe = "NO";
    }

    if (   ( !$config_parms{Audrey_no_reboot_on_startup} )
        or ( $RebootMe eq "YES" ) )
    {
        run_voice_cmd 'reboot all audrey';
    }
}
