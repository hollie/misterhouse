# Category=Pool

#
# Once a day (and at startup) set the Compool's time to the machine time.  We only noticed a 4 minute drift over 4 months, so
# this is more than overkill to keep us perfectly in sync.
#
&Compool::set_time( $Serial_Ports{Compool}{object} )
  if ( $Startup or $New_Day );

# Pool run cycle.  Turns on at 9am every day.  Turns off at 1pm and 5pm.  The 1pm turn off time (wintermodeoff)
# will be filtered out if the outside temperature is above 70.
$PoolTimer->tie_time( '00,01,02 09 * * *',
    'on', 'log=pool.log Pool pump on requested' );
$PoolTimer->tie_time(
    '00,01,02 13,14,15,16 * * *',
    'wintermodeoff',
    'log=pool.log Pool pump wintermodeoff requested ($time)'
);
$PoolTimer->tie_time( '00,01,02 17 * * *',
    'off', 'log=pool.log Pool pump turned off requested (5 pm)' );
$PoolTimer->tie_filter(
    '($Outdoor_temperature->state() > 70) && ($PoolTemp->state() < $PoolDesiredTemp->state())',
    'wintermodeoff',
    'log=pool.log Pool off requested (early afternoon) overridden due to outside temperature'
);
$PoolTimer->tie_filter( '$Pool->state() eq "on"',
    'on', 'log=pool.log Pool on overridden due to already on' );
$PoolTimer->tie_filter(
    '$SpaOverflow->state() eq "on"',
    'wintermodeoff',
    'log=pool.log Pool off overridden due to overflow on'
);
$PoolTimer->tie_filter(
    '$Waterfall->state() eq "on"',
    'wintermodeoff',
    'log=pool.log Pool off overridden due to waterfall on'
);

$PoolTimer->tie_items( $Pool, 'on', 'on', 'log=pool.log Pool on command sent' );
$PoolTimer->tie_items( $Pool, 'off', 'off',
    'log=pool.log Pool off command sent' );
$PoolTimer->tie_items( $Pool, 'wintermodeoff', 'off',
    'log=pool.log Winteroff request detected translating into true off command'
);

#
# When the Pool_ShockMode is set in Stargate then turn the pool on for
# extra time here (8 am on and 7 pm on till Midnight)
#
if ( $Startup or $New_Minute ) {
    print "Pool ShockMode is set to: "
      . $Mode_PoolShock->state() . "="
      . $SG_Pool_ShockMode->state() . "\n";
    print "Outside temperature is "
      . $Outdoor_temperature->state()
      . " and Pool temperature is "
      . $PoolTemp->state()
      . " desired is "
      . $PoolDesiredTemp->state() . "\n";
}

if ( $Mode_PoolShock->state() > 0 and $Mode_PoolShock->state() < 7 ) {
    if ( time_cron('00 08,18,19,20,21,22,23 * * *') ) {
        $Pool->set('on');
    }
    elsif ( time_cron('00 00 * * *') ) {
        $Pool->set('off');
    }
}

#noloop=start

if ( $::config_parms{Stargate485_serial_port} ) {

    # Tie events to link compool states to update Stargate LCD keypad entries
    # (invert for on, uninvert for off)
    $Pool->tie_event('&::CompoolSetStargateLCDDetails($object,90,2)');
    $Spa->tie_event('&::CompoolSetStargateLCDDetails($object,90,4)');
    $Waterfall->tie_event('&::CompoolSetStargateLCDDetails($object,90,6)');
    $SpaOverflow->tie_event('&::CompoolSetStargateLCDDetails($object,90,7)');
    $PoolLights->tie_event('&::CompoolSetStargateLCDDetails($object,91,2)');
    $MalibuLights->tie_event('&::CompoolSetStargateLCDDetails($object,91,3)');
    $SpotLights->tie_event('&::CompoolSetStargateLCDDetails($object,91,4)');
    $FanLamps->tie_event('&::CompoolSetStargateLCDDetails($object,91,5)');

    # Tie events to link states to update the LCD main screen pool row (screen 1, row 6)
    $Pool->tie_event("&::CompoolSetStargateLCD()");
    $PoolTemp->tie_event("&::CompoolSetStargateLCD()");
    $Spa->tie_event('&::CompoolSetStargateLCD();');
    $SpaTemp->tie_event('&::CompoolSetStargateLCD();');
    $Waterfall->tie_event('&::CompoolSetStargateLCD();');
    $SpaOverflow->tie_event('&::CompoolSetStargateLCD();');
    $PoolLights->tie_event('&::CompoolSetStargateLCD();');
    $MalibuLights->tie_event('&::CompoolSetStargateLCD();');
    $SpotLights->tie_event('&::CompoolSetStargateLCD();');
    $FanLamps->tie_event('&::CompoolSetStargateLCD();');

    $All_LCD->tie_items( $Pool,         'macro210', 'toggle' );
    $All_LCD->tie_items( $Spa,          'macro211', 'toggle' );
    $All_LCD->tie_items( $Waterfall,    'macro212', 'toggle' );
    $All_LCD->tie_items( $SpaOverflow,  'macro213', 'toggle' );
    $All_LCD->tie_items( $PoolLights,   'macro214', 'toggle' );
    $All_LCD->tie_items( $MalibuLights, 'macro215', 'toggle' );
    $All_LCD->tie_items( $SpotLights,   'macro216', 'toggle' );
    $All_LCD->tie_items( $FanLamps,     'macro217', 'toggle' );

    #
    # Use a tied event so the LCD updates quickly and doesn't wait for the Compool equipment
    # to receive and process the request
    #
    $All_LCD->tie_event( '&::CompoolSetStargateLCDDetailsReverse($Pool,90,2)',
        'macro210' );
    $All_LCD->tie_event( '&::CompoolSetStargateLCDDetailsReverse($Spa,90,4)',
        'macro211' );
    $All_LCD->tie_event(
        '&::CompoolSetStargateLCDDetailsReverse($Waterfall,90,6)', 'macro212' );
    $All_LCD->tie_event(
        '&::CompoolSetStargateLCDDetailsReverse($SpaOverflow,90,7)',
        'macro213' );
    $All_LCD->tie_event(
        '&::CompoolSetStargateLCDDetailsReverse($PoolLights,91,2)',
        'macro214' );
    $All_LCD->tie_event(
        '&::CompoolSetStargateLCDDetailsReverse($MalibuLights,91,3)',
        'macro215' );
    $All_LCD->tie_event(
        '&::CompoolSetStargateLCDDetailsReverse($SpotLights,91,4)',
        'macro216' );
    $All_LCD->tie_event(
        '&::CompoolSetStargateLCDDetailsReverse($FanLamps,91,5)', 'macro217' );
}

my $CompoolSetStargateLCD_Last_Loop_Count = 0;

sub CompoolSetStargateLCD {
    return if $CompoolSetStargateLCD_Last_Loop_Count == $Loop_Count;

    my $text;
    $text .= $Pool->state eq 'on'         ? "P" : " ";
    $text .= $Spa->state eq 'on'          ? "S" : " ";
    $text .= $Waterfall->state eq 'on'    ? "1" : " ";
    $text .= $SpaOverflow->state eq 'on'  ? "2" : " ";
    $text .= $PoolLights->state eq 'on'   ? "3" : " ";
    $text .= $MalibuLights->state eq 'on' ? "4" : " ";
    $text .= $SpotLights->state eq 'on'   ? "5" : " ";
    $text .= $FanLamps->state eq 'on'     ? "6" : " ";

    $text = "Pool Off " if $text eq "        ";
    $text = sprintf( " Pool %2.2d ",  $PoolTemp->state ) if $text eq "P       ";
    $text = sprintf( " Pool %2.2d *", $PoolTemp->state ) if $text eq "P 1     ";
    $text = sprintf( " Pool %2.2d *", $PoolTemp->state ) if $text eq "P 12    ";
    $text = sprintf( " Pool %2.2d *", $PoolTemp->state ) if $text eq "P  2    ";
    $text = sprintf( " Spa %3.3d ",   $SpaTemp->state )  if $text eq " S      ";
    $text = "Waterfall"  if $text eq "  1     ";
    $text = "Overflow "  if $text eq "   2    ";
    $text = "Waterfalls" if $text eq "  12    ";
    $text = " Lights  "  if $text eq "    3   ";
    $text = " Lights  "  if $text eq "     4  ";
    $text = " Lights  "  if $text eq "    34  ";
    $text = " Floods  "  if $text eq "      5 ";
    $text = "  Fans   "  if $text eq "       6";
    $text = " Service "  if $PoolService eq 'on';

    $All_LCD->ChangeText( 1, 6, $text );

    $CompoolSetStargateLCD_Last_Loop_Count = $Loop_Count;
}

sub CompoolSetStargateLCDDetails {
    my ( $object, $menu, $row ) = @_;

    if ( $object->state() eq 'on' ) {
        $All_LCD->InvertText( $menu, $row );
    }
    elsif ( $object->state() eq 'off' ) {
        $All_LCD->UnInvertText( $menu, $row );
    }
}

#
# This version of the function inverts the display line
# inversed.  It is used when the LCD macro is first received
# which is before the object processes the toggle request and
# as such must set the screen to the state it WILL BE once
# the toggle is processed
#
sub CompoolSetStargateLCDDetailsReverse {
    my ( $object, $menu, $row ) = @_;

    if ( $object->state() eq 'on' ) {
        $All_LCD->UnInvertText( $menu, $row );
    }
    elsif ( $object->state() eq 'off' ) {
        $All_LCD->InvertText( $menu, $row );
    }
}

$Pool_Keypad_1->tie_items( $Pool_Music,    "on",  "on" );
$Pool_Keypad_1->tie_items( $Pool_Music,    "off", "off" );
$Pool_Keypad_2->tie_items( $Pool_Music,    "on",  "volume:up" );
$Pool_Keypad_2->tie_items( $Pool_Music,    "on",  "volume:down" );
$Pool_Keypad_3->tie_items( $house_input_3, "on",  "next" );
$Pool_Keypad_3->tie_items( $house_input_3, "off", "prev" );

# #4 will choose inputs

# Tie X10 items to pool items
#$Pool_X10_Pool->tie_items($Pool, "on", "on");
#$Pool_X10_Pool->tie_items($Pool, "off", "off");
#$Pool_X10_Spa->tie_items($Spa, "on", "on");
#$Pool_X10_Spa->tie_items($Spa, "off", "off");
#$Pool_X10_Waterfall->tie_items($Waterfall, "on", "on");
#$Pool_X10_Waterfall->tie_items($Waterfall, "off", "off");
#$Pool_X10_PoolLights->tie_items($PoolLights, "on", "on");
#$Pool_X10_PoolLights->tie_items($PoolLights, "off", "off");
#$Pool_X10_SpaOverflow->tie_items($SpaOverflow, "on", "on");
#$Pool_X10_SpaOverflow->tie_items($SpaOverflow, "off", "off");
#$Pool_X10_MalibuLights->tie_items($MalibuLights, "on", "on");
#$Pool_X10_MalibuLights->tie_items($MalibuLights, "off", "off");
#$Pool_X10_SpotLights->tie_items($SpotLights, "on", "on");
#$Pool_X10_SpotLights->tie_items($SpotLights, "off", "off");
#$Pool_X10_FanLamps->tie_items($FanLamps, "on", "on");
#$Pool_X10_FanLamps->tie_items($FanLamps, "off", "off");

#$Pool->tie_items($Pool_X10_Pool);
#$Spa->tie_items($Pool_X10_Spa);
#$Waterfall->tie_items($Pool_X10_Waterfall);
#$PoolLights->tie_items($Pool_X10_PoolLights);
#$SpaOverflow->tie_items($Pool_X10_SpaOverflow);
#$MalibuLights->tie_items($Pool_X10_MalibuLights);
#$SpotLights->tie_items($Pool_X10_SpotLights);
#$FanLamps->tie_items($Pool_X10_FanLamps);

#noloop=stop

#
# Pool voice commands
#
#noloop=start
$v_compool_set_pool_temperature =
  new Voice_Cmd('Set Pool Temperature to [82,84,86,88,90,92]');
$v_compool_set_pool_temperature->set_info('Set the pool target temperature');
$v_compool_set_pool_temperature->set_icon('fountain');

$v_compool_set_spa_temperature =
  new Voice_Cmd('Set Spa Temperature to [96,98,100,102,104]');
$v_compool_set_spa_temperature->set_info('Set the spa target temperature');
$v_compool_set_spa_temperature->set_icon('fountain');

$v_compool_status = new Voice_Cmd('Pool Status report');
$v_compool_status->set_info('Display a pool status report');
$v_compool_status->set_authority('anyone');
$v_compool_status->set_icon('stats');

$v_compool_waterfall_timer =
  new Voice_Cmd('Turn on the waterfall for [10,20,30,60,90,120] minutes');
$v_compool_waterfall_timer->set_info(
    'Turn on the waterfall under timer control');
$v_compool_waterfall_timer->set_icon('timer');

$v_compool_spa_timer =
  new Voice_Cmd('Turn on spa scene for [1,10,20,30,60,90,120] minutes');
$v_compool_spa_timer->set_info('Turn on the spa scene under timer control');
$v_compool_spa_timer->set_icon('timer');

#noloop=stop

if ( $state = said $v_compool_set_pool_temperature) {
    &Compool::set_temp( $Serial_Ports{Compool}{object}, 'pool', $state );
}

if ( $state = said $v_compool_set_spa_temperature) {
    &Compool::set_temp( $Serial_Ports{Compool}{object}, 'spa', $state );
}

if ( $state = said $v_compool_status) {
    my $port = $Serial_Ports{Compool}{object};

    my $status;

    # Basic temperature settings
    $status .= "Pool status report:\n";
    $status .=
        "Pool Temperature is : "
      . &Compool::get_temp( $port, 'pool' )
      . " degrees\n";
    $status .=
        "Pool limit is       : "
      . &Compool::get_temp( $port, 'pooldesired' )
      . " degrees\n";
    $status .=
        "Spa Temperature is  : "
      . &Compool::get_temp( $port, 'spa' )
      . " degrees\n";
    $status .=
        "Spa limit is        : "
      . &Compool::get_temp( $port, 'spadesired' )
      . " degrees\n";
    $status .=
        "Air Temperature is  : "
      . &Compool::get_temp( $port, 'air' )
      . " degrees\n";
    $status .=
        "Solar Temperature is: "
      . &Compool::get_temp( $port, 'poolsolar' )
      . " degrees\n";

    # Primary equipment
    $status .=
      "The Pool is         : " . &Compool::get_device( $port, 'pool' ) . "\n";
    $status .=
      "The Spa is          : " . &Compool::get_device( $port, 'spa' ) . "\n";
    $status .=
      "The waterfall is    : " . &Compool::get_device( $port, 'aux1' ) . "\n";
    $status .=
      "The spa waterfall is: " . &Compool::get_device( $port, 'aux2' ) . "\n";
    $status .=
      "The pool lights are : " . &Compool::get_device( $port, 'aux3' ) . "\n";
    $status .=
      "The malibu's are    : " . &Compool::get_device( $port, 'aux4' ) . "\n";
    $status .=
      "The spotlights are  : " . &Compool::get_device( $port, 'aux5' ) . "\n";
    $status .=
      "The fans are        : " . &Compool::get_device( $port, 'aux6' ) . "\n";
    $status .=
      "The music is        : " . &Compool::get_device( $port, 'aux7' ) . "\n";

    # Secondary equipment
    $status .= "The Service mode is : "
      . &Compool::get_device( $port, 'service' ) . "\n";
    $status .=
      "The Gas heater is   : " . &Compool::get_device( $port, 'heater' ) . "\n";
    $status .=
      "The Solar heater is : " . &Compool::get_device( $port, 'solar' ) . "\n";
    $status .=
      "The Remote is       : " . &Compool::get_device( $port, 'remote' ) . "\n";

    #   $status .= "The Display is      : " . &Compool::get_device($port, 'display') . "\n";
    #   $status .= "Solar is available  : " . &Compool::get_device($port, 'allowsolar') . "\n";
    #   $status .= "The aux7 is         : " . &Compool::get_device($port, 'aux7') . "\n";
    $status .=
      "The Freeze alert is : " . &Compool::get_device( $port, 'freeze' ) . "\n";
    if ( $Mode_PoolShock->state() < 1 ) {
        $status .= "The ShockMode is    : off\n";
    }
    else {
        $status .=
          "The ShockMode set   : " . $Mode_PoolShock->state() . " days\n";
    }

    print_log $status;
    print "\n" . $status . "\n";
}

if ( $state = said $v_compool_waterfall_timer) {
    speak "A timer has been set for $state minutes";
    &Compool::set_device_with_timer( $Serial_Ports{Compool}{object},
        'aux1', 'on', $state * 60 );
}

if ( $state = said $v_compool_spa_timer) {
    speak "A timer has been set for $state minutes";

    # Turn on Malibu, Pool, Waterfall, and then Spa
    &Compool::set_device_with_timer( $Serial_Ports{Compool}{object},
        'aux4', 'on', $state * 60 );
    &Compool::set_device_with_timer( $Serial_Ports{Compool}{object},
        'aux3', 'on', $state * 60 );
    &Compool::set_device_with_timer( $Serial_Ports{Compool}{object},
        'aux1', 'on', $state * 60 );
    &Compool::set_device_with_timer( $Serial_Ports{Compool}{object},
        'spa', 'on', $state * 60 );
}

# speak "Pool temp below 78\n" if(&Compool::get_temp_now($Serial_Ports{Compool}{object}, 'pool', '<',78) and &Compool::get_device($Serial_Ports{Compool}{object}, 'pool') eq "on");

