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
#@ http://www.mraudrey.net -or- http://vsa.cape.com/~pjf
#@
#   MRU 20041125-04, v0.14 Pete Flaherty
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

=cut

# We need to define the elements for the web page Before we do anything
# noloop=start
my $listNM = ("all");
    my @Aname ;
    my @Aip ;
    my $Acount = 0 ;
    #Get all the Audrey listings from the ini file, and make an array of them
    for my $ip (split ',', $config_parms{Audrey_IPs}) {
	( $Aname[$Acount], $Aip[$Acount] ) = split '-', $ip ;
        print "$Aname[$Acount], $Aip[$Acount]\n";
	$listNM = $listNM . ",$Aname[$Acount]";
	$Acount++;
    }
print "My list of Audreys $listNM \n";
# noloop=stop


# debug check
# print "My list of Audreys $listNM \n";


#Definee the Voice commands for all the functions

$v_audrey_mail_led_on     = new Voice_Cmd("Set [". $listNM . "] Audrey mail light on");
$v_audrey_mail_led_off    = new Voice_Cmd("Set [". $listNM . "] Audrey mail light off");
$v_audrey_mail_led_blink  = new Voice_Cmd("Set [". $listNM . "] Audrey mail light blink");

$v_audrey_top_led_on     = new Voice_Cmd("Set [". $listNM . "] Audrey top light on");
$v_audrey_top_led_off    = new Voice_Cmd("Set [". $listNM . "] Audrey top light off");
$v_audrey_top_led_blink  = new Voice_Cmd("Set [". $listNM . "] Audrey top light blink");

$v_audrey_both_leds_on     = new Voice_Cmd("Set [". $listNM . "] Audrey both lights on");
$v_audrey_both_leds_off    = new Voice_Cmd("Set [". $listNM . "] Audrey both lights off");
$v_audrey_both_leds_blink  = new Voice_Cmd("Set [". $listNM . "] Audrey both lights blink");


$v_audrey_screen_on  = new Voice_Cmd("Set [". $listNM . "] Audrey screen on");
$v_audrey_screen_off = new Voice_Cmd("Set [". $listNM . "] Audrey screen off");

$v_audrey_photos     = new Voice_Cmd("Set [". $listNM . "] Audrey to photo screen");

$v_audrey_wav        = new Voice_Cmd("Set [". $listNM . "] Audrey to a wav file");

$v_audrey_tagline    = new Voice_Cmd("Read tag line to [". $listNM . "] Audrey");

$v_audrey_music_on  = new Voice_Cmd("Set [". $listNM . "] Audrey music on");
$v_audrey_music_off = new Voice_Cmd("Set [". $listNM . "] Audrey music off");

$v_audrey_volume_0    = new Voice_Cmd("Set [". $listNM . "] Audrey Volume to 0");
$v_audrey_volume_20   = new Voice_Cmd("Set [". $listNM . "] Audrey Volume to 20");
$v_audrey_volume_50   = new Voice_Cmd("Set [". $listNM . "] Audrey Volume to 50");
$v_audrey_volume_75   = new Voice_Cmd("Set [". $listNM . "] Audrey Volume to 75");
$v_audrey_volume_100  = new Voice_Cmd("Set [". $listNM . "] Audrey Volume to 100");

$v_audrey_reboot  = new Voice_Cmd("Reboot [". $listNM . "] Audrey");


# Run the function variables for the voice commands above

&audrey('top_led', 'on',     $state) if $state = said $v_audrey_top_led_on;
&audrey('top_led', 'off',    $state) if $state = said $v_audrey_top_led_off;
&audrey('top_led', 'blink',  $state) if $state = said $v_audrey_top_led_blink;
&audrey('mail_led', 'on',     $state) if $state = said $v_audrey_mail_led_on;
&audrey('mail_led', 'off',    $state) if $state = said $v_audrey_mail_led_off;
&audrey('mail_led', 'blink',  $state) if $state = said $v_audrey_mail_led_blink;
&audrey('both_leds', 'on',     $state) if $state = said $v_audrey_both_leds_on;
&audrey('both_leds', 'off',    $state) if $state = said $v_audrey_both_leds_off;
&audrey('both_leds', 'blink',  $state) if $state = said $v_audrey_both_leds_blink;

&audrey('music', 'Play',    $state) if $state = said $v_audrey_music_on;
&audrey('music', 'Stop',    $state) if $state = said $v_audrey_music_off;

&audrey('volume', '0',	$state) if $state = said $v_audrey_volume_0;
&audrey('volume', '20',	$state) if $state = said $v_audrey_volume_20;
&audrey('volume', '50',	$state) if $state = said $v_audrey_volume_50;
&audrey('volume', '75',	$state) if $state = said $v_audrey_volume_75;
&audrey('volume', '100',$state) if $state = said $v_audrey_volume_100;

&audrey('reboot', undef ,$state) if $state = said $v_audrey_reboot;

&audrey('screen', 'on',  $state) if $state = said $v_audrey_screen_on;
&audrey('screen', 'off', $state) if $state = said $v_audrey_screen_off;

&audrey('photos', undef, $state) if $state = said $v_audrey_photos;


if ($state = said $v_audrey_wav) {
    play address => &audrey_ip($state), file => '../sounds/hello_from_bruce.wav';
#   get "http://$state/cgi-bin/SendMessage?M=GOTO_URL&S=http://$Info{Machine}:$config_parms{http_port}/sounds/hello_from_bruce.wav";
}

if ($state = said $v_audrey_tagline) {
    speak address => &audrey_ip($state), text => (read_next $house_tagline);
}

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

    my ($list) = @_;
    my ($list2) = "" ;
    $list = 'Kitchen' if !$list or $list eq '1';

    my @Aname ;
    my @Aip ;


    my $Acount = 0 ;
    #Get all the Audrey listings from the ini file, and make an array of them
    for my $ip (split ',', $config_parms{Audrey_IPs}) {
	( $Aname[$Acount], $Aip[$Acount] ) = split '-', $ip ;
        print "$Aname[$Acount], $Aip[$Acount]\n";
	#$listNM +=",$Aname[$Acount]";
	$Acount++;
    }


    my $AC = 0;
#    # make up a list of all the entries Name only
#    # $list = 'Kitchen,Piano,Desk,Bedroom' if $list eq 'all';
    $list2 ="";
    if ( $list eq 'all' ) {
	for ( $AC= 0;$AC < $Acount + 1 ;$AC++){
	    $list2 = "$list2 $Aname[$AC],$Aip[$AC]";
	    #$list2 = "$list2 $Aname[$AC]";
	    #$list2 = "$list2 $Aip[$AC]";
	    $list2 = "$list2," if ($Aname[$AC + 1] ne '') ;
	}
	print "$Acount - List  name - $list2 \n";
    }

    # we make up a list with the specific entry
    for ( $AC=0 ;$AC < $Acount + 1;$AC++){
	$list =~ s/$Aname[$AC]/$Aip[$AC]/;
	$list = "$list," if ( $Aname[$AC + 1] ne '') ;
	#print "list spec - $list\n";
    }
    $list = $list2 if $list2;
    print "list output $list\n";
    return $list;
}


# Here we take the translated voice commands from above and do something
# we lill soop through all the entries if there is more than one (like 'all')
sub audrey {
    my ($mode, $astate, $list) = @_;
    for my $address (split ',', &audrey_ip($list)) {

	# some verbosity to the console about what were doing
	print "Setting Audrey $mode to $astate for $address\n";

        if ($mode eq 'top_led') {
            print_log "$address Audrey top led set to $astate";
            $state = 0 if $astate eq 'off';
            $state = 2 if $astate eq 'blink';
            $state = 1
 if $astate eq 'on';
            get "http://$address/led.shtml?t$state";
        }

        if ($mode eq 'mail_led') {
            print_log "$address Audrey mail led set to $astate";
            $state = 0 if $astate eq 'off';
            $state = 2 if $astate eq 'blink';
            $state = 1 if $astate eq 'on';
            get "http://$address/led.shtml?m$state";
        }

        if ($mode eq 'both_leds') {
            print_log "$address Audrey both leds set to $astate";
            $state = 0 if $astate eq 'off';
            $state = 2 if $astate eq 'blink';
            $state = 1 if $astate eq 'on';
            get "http://$address/led.shtml?t$state m$state";
        }
        elsif ($mode eq 'screen') {
            print_log "$address Audrey screen set to $astate";
            $state = 0 if $astate eq 'off';
            $state = 1 if $astate eq 'on';
            get "http://$address/screen.shtml?$state";
        }
        elsif ($mode eq 'photos') {
            print_log "$address Audrey to photo screen";
            get "http://$address/cgi-bin/SendMessage?M=GOTO_URL&S=http://$Info{IPAddress_local}:$config_parms{http_port}/misc/photos.html";
        }
	elsif ($mode eq 'music') {
            print_log "$address Audrey Music set to $astate";
            $state = 0 if $astate eq 'Stop';
            $state = 1 if $astate eq 'Play';
            get "http://$address/cgi-bin/mpctrl?action=$astate&file=http://192.168.0.150:8010";
        }
	elsif ($mode eq 'volume') {
            print_log "$address Audrey volume set to $astate";
            $state = $astate;
            get "http://$address/cgi-bin/volume?$astate";
        }
	elsif ($mode eq 'reboot') {
            print_log "$address Audrey $astate";
            $state = $astate;
            get "http://$address/reboot.shtml";
        }


    }
}

                        # Periodically ping Audrey to see if she is responding
$audrey_power_Kitchen = new X10_Appliance 'B2';
# $audrey_power_Piano   = new X10_Appliance 'C2';
# $audrey_power_Bedroom = new X10_Appliance 'C3';
#if (new_minute 10) {
#if (time_now '4 pm') {
#    for my $audrey (split ',', 'Kitchen,Piano') {
#        if (!&net_ping(&audrey_ip($audrey))) {
#            speak "$audrey Audrey not responding, resetting her power.";
#           eval "set_with_timer \$audrey_power_$audrey OFF, 5";
#        }
#    }
#}


#$audrey_power_kitchen_v = new Voice_Cmd 'Turn Kitchen Audrey [on,off]';
#$audrey_power_kitchen_v-> tie_items($audrey_power_Kitchen);

# Reset periodically
#set_with_timer $audrey_power_Kitchen OFF, 5 if time_now '10:50 pm';

#get "http://kitchen/screen.shtml?1" if time_now  '6:50 am';
#get "http://kitchen/screen.shtml?0" if time_now '11:20 pm';

#get "http://piano/screen.shtml?1" if time_now  '6:40 am';
#get "http://piano/screen.shtml?0" if time_now '11:00 pm';



## Some sample Crom jobs for useful functionality

				# Alarm clock for dad
#if (time_cron '0 7 * * 1-5') {
#    run_voice_cmd 'set Bedroom Audrey music on';
#    run_voice_cmd 'set piano Audrey music on';
#}
				# Just in case I oversleep
#if (time_cron '45 7 * * 1-5') {
#    run_voice_cmd 'set Bedroom Audrey music off';
#    run_voice_cmd 'set piano Audrey music off';
#}
                                # Restart slideshows
#if (time_cron '1 10,17 * * *') {
#     run_voice_cmd 'set piano audrey to photo screen';
#    run_voice_cmd 'set kitchen audrey to photo screen';
#}


#				#We like to listen to a specific webcast on sat and sun
#if (time_cron '0 17 * * 6,7') {
#    run_voice_cmd 'set house mp3 player to wers';
#    run_voice_cmd 'set the house mp3 player to Play';
#    run_voice_cmd 'set all audrey volume to 20';
#    run_voice_cmd 'set all audrey music on';
#    get "http://192.168.0.142/cgi-bin/urgentMsg?message=The Playground is on";
#
#}
				# and it comes to an end at 8
#if (time_cron '0 20 * * 6,7') {
#    run_voice_cmd 'set all audrey music off';
#}


# We restart the audries once MH is up, so everything is in sync

if ( $Startup ) {
    run_voice_cmd 'reboot all audrey';
}
