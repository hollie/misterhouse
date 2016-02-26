
# Category = xAP

#@ This code is used to test and monitor xAP data (see <a href=http://www.xapautomation.org>xapautomation.org</a>)
#@ and/or xPL data (see <a href=http://www.xplproject.org.uk/>xplproject.org.uk</a>
#@ Rio and TTS xPL clients are available from <a href=http://www.xplhal.com>Tony's page</a>.

#
# Examples of how to Monitor generic xAP/xPL data
#
$xap_monitor1 = new xAP_Item;
$xap_monitor1->tie_event('print_log "xap data: $state"');
if ( $state = state_now $xap_monitor1) {
    display
      text        => "$Time_Date: $state\n",
      time        => 0,
      title       => 'xAP data',
      width       => 130,
      height      => 50,
      window_name => 'xAP',
      append      => 'top',
      font        => 'fixed'
      unless $state =~ /^xap-hbeat/;
}

$xap_monitor2 = new xAP_Item('xap-x10.*');
$xap_monitor2->tie_event('print_log "xap X10 class data: $state"');

$xap_monitor3 = new xAP_Item( '*', 'Rocket.*' );
$xap_monitor3->tie_event('print_log "xap Rocket sourced data: $state"');

$xpl_monitor1 = new xPL_Item;
$xpl_monitor1->tie_event('print_log "xpl data: $state"');

$xpl_monitor2 = new xPL_Item('TONYT-CLOCK.ATOMIC');
$xpl_monitor2->tie_event('print_log "xpl CLOCK sourced data: $state"');

#
# Test sending speech data to a xPL TTS client
# Note how $state is used to flag the field that state will correlate to.
#
$xpl_speak1_v = new Voice_Cmd 'Test speech to an xpl client [1,2]';
$xpl_speak1 =
  new xPL_Item( 'tonyt-tts.voice1', 'tts.basic' => { speech => '$state' } );
$xpl_speak2 = new xPL_Item( 'tonyt-ttsagent.agent1',
    'tts.basic' => { speech => '$state' } );
set $xpl_speak1 "xpl client says the time is $Time_Now"
  if state_now $xpl_speak1_v == 1;
set $xpl_speak2 "Hi, I'm an agent.   Today is $Date_Now"
  if state_now $xpl_speak1_v == 2;

#
# Test X10 data. Note:  Not yet tested with any X10 clients yet
#
$outside_light_xap = new xAP_Item( 'xap-x10.request', '*',
    'xap-x10.request' => { command => '$state', device => 'A1' } );
$outside_light_xpl =
  new xPL_Item( 'ACME-LAMP.outside', 'lamp.basic' => { action => '$state' } );
$outside_light_xap->tie_event(
    'print_log "xap says outside light was set to $state"');
$outside_light_xpl->tie_event(
    'print_log "xpl says outside light was set to $state"');

#
# Test a clock app.  Also print other fields, not just the state field.
#
$clock_xap = new xAP_Item( 'clock.report', '*', time => { local => '$state' } );
print_log "xap clock time=$state time/date=$$clock_xap{prettylocal}{long}"
  if $state = state_now $clock_xap;

#
# Various other tests for sending out xap data, both with
# xAP_Item and using the xAP::send function directly.
#
$xap_test = new Voice_Cmd 'Test xap send [0,1,2,3,4]';
if ( defined( $state = said $xap_test) ) {
    print_log "Running xap send test $state";

    #   &xAP::send_heartbeat if $state == 0;
    &xAP::send_xap_heartbeat if $state == 0;

    set $outside_light_xap TOGGLE if $state == 1;

    &xAP::send( 'xAP', 'xap-x10.request',
        'xap-x10.request' => { device => 'A1', command => 'on' } )
      if $state == 2;

    set $clock_xap $Time_Now if $state == 3;

    &xAP::send(
        'xAP',
        'clock.report',
        time        => { local => $Time_Now },
        date        => { local => $Date_Now },
        prettylocal => {
            long  => scalar time_date_stamp(1),
            short => scalar time_date_stamp(7)
        }
    ) if $state == 4;
}

#
# Test the Tony's nifty RIO xPL client
#
#rio_kitchen = new xPL_Item('tonyt-rio.unit100', 'rio.basic' => {sel => '$state'});
$rio_kitchen = new xPL_Rio('tonyt-rio.unit100');

my $rio_states = join ',', @{ $$rio_kitchen{states} };    # noloop
$rio_cmds = new Voice_Cmd "Set kitchen rio to [$rio_states]";
$rio_cmds->tie_items($rio_kitchen);

#
# Other xPL test
#
$xpl_test = new Voice_Cmd 'Test xpl send [0,1,2,3,4,5,6]';
if ( defined( $state = said $xpl_test) ) {
    print_log "Running xpl send tset $state";

    #   &xAP::send_heartbeat('xPL') if $state == 0;
    &xAP::send_xpl_heartbeat() if $state == 0;

    set $outside_light_xpl TOGGLE if $state == 1;

    &xAP::send( 'xPL', 'ACME-LAMP.LIVINGROOM',
        'lamp.basic' => { action => 'on' } )
      if $state == 2;

    &xAP::send( 'xPL', 'tonyt-rio.unit100', 'rio.basic' => { sel => 'skip' } )
      if $state == 3;

}

#
# Send normal speak data to to xpl clients, based on room option
#  (e.g. speak "room=bedroom Time to wake up!")
#
&Speak_pre_add_hook( \&xpl_speak, 0 ) if $Reload;

sub xpl_speak {
    my (%parms) = @_;
    return unless $parms{text};
    print "xpl speak parms: @_\n" if $Debug{xpl};
    $parms{rooms} = 'voice1' unless $parms{rooms};
    my @rooms = split ',', lc $parms{rooms};

    # Set xml flags for MS V5 engines
    $parms{text} = &Voice_Text::set_rate( $parms{rate}, $parms{text} )
      if $parms{rate};
    $parms{text} = &Voice_Text::set_voice( $parms{voice}, $parms{text} )
      if $parms{voice};
    $parms{text} = &Voice_Text::set_volume( $parms{volume}, $parms{text} )
      if $parms{volume};

    for my $room (@rooms) {
        &xAP::send( 'xPL', "tonyt-tts.$room",
            'tts.basic' => { speech => $parms{text} } );
    }
}
