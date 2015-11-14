
# Category = xPL

#@ This code is used to test and monitor
#@ xPL data (see <a href=http://www.xplproject.org.uk/>xplproject.org.uk</a>
#@ Rio and TTS xPL clients are available from
#@ <a href=http://www.xplhal.com>Tony's page</a>.

# noloop = start

#
# Examples of how to Monitor generic xPL data
#
$xpl_monitor1 = new xPL_Item;
$xpl_monitor1->tie_event( '
	my $packet = $xpl_monitor1->received();
	$packet =~ s/\n\{\n/ \{ /mg;
	$packet =~ s/\n\}\n?/ \} /mg;
	$packet =~ s/\n/ \| /mg;
	print_log "xpl data: $packet";
' );

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
$outside_light_xpl =
  new xPL_Item( 'ACME-LAMP.outside', 'lamp.basic' => { action => '$state' } );
$outside_light_xpl->tie_event(
    'print_log "xpl says outside light was set to $state"');

#
# Test the Tony's nifty RIO xPL client
#
$rio_kitchen =
  new xPL_Item( 'tonyt-rio.unit100', 'rio.basic' => { sel => '$state' } );
$rio_kitchen = new xPL_Rio('tonyt-rio.unit100');

my $rio_states = join ',', @{ $$rio_kitchen{states} };
$rio_cmds = new Voice_Cmd "Set kitchen rio to [$rio_states]";
$rio_cmds->tie_items($rio_kitchen);

#
# Other xPL test
#
$xpl_test = new Voice_Cmd 'Test xpl send [0,1,2,3,4,5,6]';

# noloop = stop

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
