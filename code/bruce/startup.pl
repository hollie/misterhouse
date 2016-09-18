# Category=MisterHouse

#@ Runs various startup initialization events.

# Set default speaking volume
# Note:  This sets max volume with mstts.
# volume=100 would use 100% of the default, not 100%
#speak volume => 75 if $Startup;

$v_initialize_serial_port = new Voice_Cmd("Initialize the serial port");
$v_initialize_serial_port->set_info(
    'This will initialize the weeder digital ports.  Automatically done on startup'
);

# In case a power fail reset the weeder boards (... they default to output only)
set $v_initialize_serial_port 1 if $Startup;

if ( said $v_initialize_serial_port) {

    # Make sure these sensors are in switch mode and read their status
    for my $ref ( $back_door, $garage_entry_door, $front_door,
        $entry_door, $garage_door, $wireless1, $mailbox )
    {
        set $ref 'init';
    }

    # Ignore incoming sensors after init
}

if ( said $v_initialize_serial_port or $Startup ) {

    # Get initial status of sensors
    #   set $digital_read_port_a;
    #   set $digital_read_port_b;
    set $digital_read_port_c;

    #   speak("Serial port initialized");
}

# At startup, read the state of the digital inputs
&digital_read($temp) if $temp = state_now $digital_read_results;

sub digital_read {
    my ($digital_data) = @_;
    my ( $digital_port, $digital_byte, $bit, $state, $ref, $id );
    unless ( length($digital_data) == 3 ) {

        #   print "Digital data is bad in digital_read: $digital_data.\n";
        return;
    }
    $digital_port = substr( $digital_data, 0, 2 );
    $digital_byte = unpack( 'C', substr( $digital_data, 2, 1 ) );

    for $bit ( 'A' .. 'H' ) {

        #        print "db byte=$digital_byte ";
        $state        = $digital_byte % 2;
        $digital_byte = int( $digital_byte / 2 );
        $state        = ($state) ? 'H' : 'L';
        $id           = "$digital_port$bit$state";

        #       print " bit=$bit state=$state byte=$digital_byte id=$id\n";
        next unless $ref = &Serial_Item::serial_item_by_id($id);
        $state = $$ref{state_by_id}{$id};
        $ref->{state} = $state;
    }
}
