#Category=Audrey
#@Audrey monitor:
#@ This module allows monitoring and resetting of your defined
#@  Audreys.  It checks basic connectivity and web server functionality
#@<br><hr>
#@ For power cycling to operate you will need to define entries in your
#@  <b>items.mht</b> file for your audreys<br>
#@  The entries should be audrey_power_<b><i>xxxx</i></b> where <b><i>xxxx</i></b> is consistant with the Audrey-ips ini parameter name.<br>
#@ For example Audrey_ips=<b><i>Kitchen</b></i>-10.0.0.2 the entry should be set to
#@  audrey_power_<b><i>Kitchen</b></i>. <br>Yes Case matters !
#@

# Periodically Check the Audreys defined, ping them and check http responses
#  to see if they are alive.  If not power cycle them 1 min off then on
#
#  Our check interval needs to be offtime + 2 minutes minimum, so 5 mins is probably safe
#
#
#  v0.01 - pjf  initial revision, should allow change of auto reboot in audrey_control2 to default
#		to the off/disabled state, as we actually check them here and take action
#

$v_audrey_check = new Voice_Cmd('check audrey status');

# if we start, restart or its a certain time check em
if ( said $v_audrey_check or ( new_minute 5 ) or ($Startup) or ($Reload) ) {

    # then get the list from the ini entries
    my @Aname;
    my @Aip;
    my $Acount = 0;

    #Get all the Audrey listings from the ini file, and make an array of them
    # Now we loop through all the defined units to see whats up

    for my $ip ( split ',', $config_parms{Audrey_IPs} ) {
        ( $Aname[$Acount], $Aip[$Acount] ) = split '-', $ip;
        $Aip[$Acount] =~ s/\s//;
        my $AResetting = "";

        # For fun lets see if we have a MrAudrey Image running
        my $audreyInfo = get "http://$Aip[$Acount]/SystemProfile.shtml",
          "/dev/null";
        my ( $audreyHead, $audreyString ) = split '\:<br>\W', $audreyInfo;
        my ( $audreyVer,  $audreyRest )   = split '<br>',     $audreyString;
        ( $audreyHead,   $audreyRest ) = split '</b></br>\W', $audreyHead;
        ( $audreyString, $audreyRest ) = split '[Vv]',        $audreyVer;

        print " --- $audreyString = $audreyVer";

        # First we ping Audrey to see if she is responding
        if ( !&net_ping( $Aip[$Acount] ) ) {
            speak $Aname[$Acount]
              . " Audrey not responding, resetting her power.";
            eval "set_with_timer \$audrey_power_$Aname[$Acount] OFF, 1";
            $AResetting = "$Aname[$Acount]";
        }

        # if we can we need to see if she is serving webpages (net may be ok, but server died)
        #  this is not uncommon so we need to be thorough.  The situation is usually when
        #  you get a power glitch, or reboot too quickly
        # We also need to make sure we're not already resetting her

        if ( !$AResetting ) {
            if ( !$audreyInfo ) {
                speak
                  "$Aname[$Acount] Audrey Server not responding, resetting her power.";
                eval "set_with_timer \$audrey_power_$Aname[$Acount] OFF, 1";
                $AResetting = "$Aname[$Acount]";
            }
            else {
                print_log
                  "The $Aname[$Acount] Audrey at $Aip[$Acount] is UP and Serving - OK";
            }

        }
        $Acount++;
    }
}

#$audrey_power_Kitchen = new X10_Appliance 'B2';
# $audrey_power_Piano   = new X10_Appliance 'C2';
# $audrey_power_Bedroom = new X10_Appliance 'C3';
#if (new_minute 10) {
#if (time_now '4 pm') {
#    for my $audrey (split ',', 'Kitchen,Piano') {
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

#                               #We like to listen to a specific webcast on sat and sun
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

