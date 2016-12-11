# Category=Other

# Note: These examples assume you have enabled generic serial ports
#       by editing the serialx parms in mh.ini (or mh.private.ini)
#
# For example:  serial1_port     = COM1
#               serial1_baudrate = 9600
#               serial2_port     = COM2
#
# Examples on how to send data to a generic serial port
# You can rename serial1* to serial_xyz*
$init_strings = new Serial_Item( 'your init string 1', 'init1', 'serial1' );
set $init_strings 'init1' if $Startup;

$serial_msg = new Serial_Item( 'your message string 1', 'msg1', 'serial1' );
$serial_msg->add( 'your message string 2', 'msg2' );
$v_serial_msg = new Voice_Cmd("Send serial string [1,2]");
my $state;
set $serial_msg "msg$state" if $state = said $v_serial_msg;

# Here is another way to write changing data out to a serial port
$serial_out = new Serial_Item( undef, undef, 'serial2' );
set $serial_out "The time is $Time_Now" if $New_Minute;

# Example on how to read generic serial port data
if ( my $data = said $serial_out) {
    logit( "/mh/data/logs/serial1.$Year_Month_Now.log", $data );
    print_log "Serial data received";
}

# Example on how to start and stop a serial port
$v_port_control1 = new Voice_Cmd("[start,stop] the test serial port");
if ( $state = said $v_port_control1) {
    print_log "The test serial port was set to $state";
    ( $state eq 'start' ) ? start $serial_out : stop $serial_out;
}

# Re-start the port, if it is not in use
start $serial_out
  if $New_Minute
  and is_stopped $serial_out
  and is_available $serial_out;

