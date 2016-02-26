
# Category = Audrey

#@ This is an example of controling the led and screen on the audrey.

=begin comment

For this to work, you need to update your Audrey to allow for
control from external browsers.   Instructions for this, can be found
here:

  http://homepage.mac.com/deandavis/audrey/AudreyOnOff.html

More info is in mh/docs/faq_ia.* 'What is an Audrey'

Also change the http://audrey urls to the appropriate ip address,
or update your hosts file.  

On my windows box, this file is \windows\system32\drivers\etc\hosts
On unix, it is in /etc/hosts

=cut

$v_audrey_led_on =
  new Voice_Cmd("Set [,all,Kitchen,Piano,Bedroom] Audrey light on");
$v_audrey_led_off =
  new Voice_Cmd("Set [,all,Kitchen,Piano,Bedroom] Audrey light off");
$v_audrey_led_blink =
  new Voice_Cmd("Set [,all,Kitchen,Piano,Bedroom] Audrey light blink");

$v_audrey_screen_on =
  new Voice_Cmd("Set [,all,Kitchen,Piano,Bedroom] Audrey screen on");
$v_audrey_screen_off =
  new Voice_Cmd("Set [,all,Kitchen,Piano,Bedroom] Audrey screen off");

$v_audrey_photos =
  new Voice_Cmd("Set [,all,Kitchen,Piano,Bedroom] Audrey to photo screen");

$v_audrey_wav =
  new Voice_Cmd("Set [,all,Kitchen,Piano,Bedroom] Audrey to a wav file");

$v_audrey_tagline =
  new Voice_Cmd("Read tag line to [,all,Kitchen,Piano,Bedroom] Audrey");

&audrey( 'led', 'on',    $state ) if $state = said $v_audrey_led_on;
&audrey( 'led', 'off',   $state ) if $state = said $v_audrey_led_off;
&audrey( 'led', 'blink', $state ) if $state = said $v_audrey_led_blink;

&audrey( 'screen', 'on',  $state ) if $state = said $v_audrey_screen_on;
&audrey( 'screen', 'off', $state ) if $state = said $v_audrey_screen_off;

&audrey( 'photos', undef, $state ) if $state = said $v_audrey_photos;

if ( $state = said $v_audrey_wav) {
    play
      address => &audrey_ip($state),
      file    => '../sounds/hello_from_bruce.wav';

    #   get "http://$state/cgi-bin/SendMessage?M=GOTO_URL&S=http://$Info{Machine}:$config_parms{http_port}/sounds/hello_from_bruce.wav";
}

if ( $state = said $v_audrey_tagline) {
    speak address => &audrey_ip($state), text => ( read_next $house_tagline);
}

sub audrey_ip {
    my ($list) = @_;
    $list = 'Kitchen' if !$list or $list eq '1';
    $list = 'Kitchen,Piano,Bedroom' if $list eq 'all';
    $list =~ s/Kitchen/192.168.0.81/;
    $list =~ s/Piano/192.168.0.82/;
    $list =~ s/Bedroom/192.168.0.83/;
    return $list;
}

sub audrey {
    my ( $mode, $astate, $list ) = @_;
    for my $address ( split ',', &audrey_ip($list) ) {

        if ( $mode eq 'led' ) {
            print_log "$address Audrey led set to $astate";
            $state = 0 if $astate eq 'off';
            $state = 1 if $astate eq 'blink';
            $state = 2 if $astate eq 'on';
            get "http://$address/cgi-bin/SetLEDState?$state";
        }
        elsif ( $mode eq 'screen' ) {
            print_log "$address Audrey screen set to $astate";
            $state = 0 if $astate eq 'off';
            $state = 3 if $astate eq 'on';
            get "http://$address/gpio.shtml?$state";
        }
        elsif ( $mode eq 'photos' ) {
            print_log "$address Audrey to photo screen";
            get
              "http://$address/cgi-bin/SendMessage?M=GOTO_URL&S=http://$Info{IPAddress_local}:$config_parms{http_port}/misc/photos.html";
        }
    }
}

# Periodically ping Audrey to see if she is responding
$audrey_power_Kitchen = new X10_Appliance 'B2';
$audrey_power_Piano   = new X10_Appliance 'B3';

# $audrey_power_Piano   = new X10_Appliance 'C2';
# $audrey_power_Bedroom = new X10_Appliance 'C3';
#if (new_minute 10) {
if ( time_now '4 pm' or time_now '7 am' ) {
    for my $audrey ( split ',', 'Kitchen,Piano' ) {

        #       if (!&net_ping(&audrey_ip($audrey))) {
        #          speak "$audrey Audrey not responding, resetting her power.";
        #       }
        print_log "reseting $audrey power";
        eval "set_with_timer \$audrey_power_$audrey OFF, 5";
    }
}

$audrey_power_kitchen_v = new Voice_Cmd 'Turn Kitchen Audrey power [on,off]';
$audrey_power_kitchen_v->tie_items($audrey_power_Kitchen);

$audrey_power_piano_v = new Voice_Cmd 'Turn Piano Audrey power [on,off]';
$audrey_power_piano_v->tie_items($audrey_power_Piano);

# Reset periodically
set_with_timer $audrey_power_Kitchen OFF, 15
  if time_now '10:52 pm' or time_now '8:02 am';
set_with_timer $audrey_power_Piano OFF, 15
  if time_now '10:51 pm' or time_now '8:01 am';

get "http://kitchen/screen.shtml?1" if time_now '6:50 am';
get "http://kitchen/screen.shtml?0" if time_now '11:20 pm';

get "http://piano/screen.shtml?1" if time_now '6:40 am';
get "http://piano/screen.shtml?0" if time_now '11:00 pm';

# Restart slideshows
if ( time_cron '1 10,17 * * *' ) {

    #    run_voice_cmd 'set piano audrey to photo screen';
    #    run_voice_cmd 'set kitchen audrey to photo screen';
}
