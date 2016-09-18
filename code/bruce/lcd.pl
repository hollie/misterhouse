# Category=Other

#@ This code is used to display data to a LCD display (e.g. 4x20).
#@ An optional keypad can be used to walk through menus and select
#@ commands to run or data to display.

=begin comment

 The LCD object uses menus created by menu.pl (which also creates
 wml menus for WAP cell phones and vxml menus for voice portals).

 This example uses the LCD object lcdproc option.  lcdproc is
 a daemon that talks to LCD keypads via the serial port:
      Unix: http://lcdproc.omnipotent.net
   Windows: http://www.2morrow.com/

 Both version of the LCDproc server support displays from:
      http://www.matrix-orbital.com/
      http://www.crystalfontz.com/

 The Matrix displays also supports a keypad interface (unix only for now)
 
 Since Sockets are used, the computer with the serial-attatched
 display can be different than the MisterHouse computer.

 Any of the many LCDproc clients can be used at the same time
 as this MisterHouse client, and the LCDproc server will swap
 between the displays.

=cut

# The numeric entries are for using computer keyboard arrows
my %lcd_keymap1 = (
    N => 'up',
    I => 'down',
    M => 'left',
    H => 'right',
    F => 'exit',
    K => 'enter',
    L => 'left',
    G => 'right'
);

#                  type           port            size   menu_group    keymap
$lcd1 = new LCD 'lcdproc', '192.168.0.5:13666', '4x20', 'test', \%lcd_keymap1;

print "LCD key1: $state.\n" if defined( $state = said_key $lcd1);

#print "LCD key2: $Keyboard\n" if defined $Keyboard;

# Allow for manual start/stop of lcd menu
$v_lcdproc_control = new Voice_Cmd '[Start,Stop] the lcdproc client';
$v_lcdproc_control->set_info(
    'Connects to the lcdproc server, used to display LCD data.');
run_voice_cmd 'Start the lcdproc client' if time_now '11 pm';    # Daily restart

if ( $state = said $v_lcdproc_control) {
    ( $state eq 'Start' ) ? start $lcd1 : stop $lcd1;
}

if ( $Save{phone_callerid_data} ne $Save{phone_callerid_data_prev} ) {
    $Save{phone_callerid_data} =~ s/phone_call.wav,//g;
    set $lcd1 &time_date_stamp( 6, $Time ) . ' ' . &time_date_stamp( 8, $Time ),
      split "\n", $Save{phone_callerid_data};
    $Save{phone_callerid_data_prev} = $Save{phone_callerid_data};
}

# Display default display screen if the lcd keypad is not in use
if ( new_second 10 and inactive $lcd1) {
    set $lcd1

      #       substr(&time_date_stamp(14, $Time), 0, 18),
      &time_date_stamp( 6, $Time ) . ' ' . &time_date_stamp( 8, $Time ),
      $Weather{Summary_Short},
      $Save{phone_callerid_data},
      $Save{email_flag};
}
