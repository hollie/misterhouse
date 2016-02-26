
=head1 B<Stargate>

=head2 SYNOPSIS

  unless ($unithi = $table_iounit{lc($bytes[2])})
  {
    print "$::Time_Now Error, not a valid Stargate IO base: $code\n";
    next;
  }

  unless ($unitlo = $table_iounit{lc($bytes[3])})
  {
    print "$::Time_Now Error, not a valid Stargate IO base: $code\n";
    next;
  }

  $unitstates = (($unithi * 16) + $unitlo);

  #print "$::Time_Now Digital IO State change base:hi:lo=$base:$unithi:$unitlo:$unitstates\n";

=head2 DESCRIPTION

From Misterhouse HomeBase.pm

         I/ODevice         Offset

  TimeCommander-Plus         0x00    1-16
  reserved                   0x01
  IO Xpander -1              0x02    17-32
  IO Xpander -2              0x03    33-48
  IO Xpander -3              0x04    49-64
  IO Xpander -4              0x05    65-80

  DI Xpander-1               0x06
  DI Xpander-2               0x07
  DI Xpander-3               0x08
  DI Xpander-4               0x09

  RO Xpander-1               0x0a
  RO Xpander-2               0x0b
  RO Xpander-3               0x0c
  RO Xpander-4               0x0d

For reference on dealing with bits/bytes/strings:

  print pack('B8', '01101011');   # -> k   To go from bit to string
  print unpack('C', 'k');         # -> 107 To go from string to decimal
  print   pack('C', 107);         # -> k   To go from decimal to srting
  printf("%0.2lx", 107);          # -> 6b  To go to decimal -> hex
  print hex('6b');                # -> 107 to go from hex -> decimal

Examples:

  0x5a -> 90  -> Z
  0xa5 -> 165 -> ~N (tilde over N)
  0xc3 -> 195 -> |-
  0x3c -> 60 -> <


=head2 INHERITS

B<>

=head2 METHODS

=over

=cut

use Telephony_Item;
use strict;

my (
    @stargatedigitalinput_object_list, @stargatevariable_object_list,
    @stargateflag_object_list,         @stargaterelay_object_list
);
my (
    @stargatethermostat_object_list, @stargatetelephone_object_list,
    @stargateascii_object_list,      @stargateir_object_list
);

package Stargate;

my $temp;

=item C<serial_startup>

This code create the serial port and registers the callbacks we need

=cut

sub serial_startup {
    if ( $::config_parms{Stargate_serial_port} ) {
        my ($speed) = $::config_parms{Stargate_baudrate} || 9600;
        if (
            &::serial_port_create(
                'Stargate', $::config_parms{Stargate_serial_port},
                $speed,     'none'
            )
          )
        {
            init( $::Serial_Ports{Stargate}{object} );
            &::MainLoop_pre_add_hook( \&Stargate::UserCodePreHook, 1 );
            &::MainLoop_post_add_hook( \&Stargate::UserCodePostHook, 1 );
        }
    }
}

my $serial_data;           # Holds left over serial data
my $last_variable_load;    # Holds first part of two message variable load data
my $last_thermostat_address
  ;                        # Holds first part of two message thermostat command
my $last_caller_id;

my $Last_Upload_Timer;
my $Last_Upload_Variable;

my $Thermostat_Upload_Count
  ;    # We use this to track if all thermostats 'reported in'
my @Thermostat_Upload_List
  ;    # We use this to match thermostat uploads to the correct zone
my @Thermostat_Upload_Data
  ;    # We use this to match thermostat uploads to the correct zone

my ( @stargate_command_list, $transmitok );

sub init {
    my ($serial_port) = @_;

    # Echo off
    #$serial_port->write("##%1c\r");

    # Set to echo mode, so we can monitor events
    print "Sending Stargate echo init string\n" if $main::Debug{stargate};
    print "Bad Stargate init echo command transmition\n"
      unless 6 == $serial_port->write("##%1d\r");

    #$serial_port->write("##%07\r");
    # Set default values
    $last_variable_load = undef;

    ResetTimerUpload();
    ResetVariableUpload();
    ResetThermostatUpload();

    $transmitok = 1;
}

sub UserCodePreHook {
    if ( ($::Startup) or ( $::DelayOccured > 60 ) ) {
        RequestVariableUpload();
        RequestThermostatUpload();
        return;
    }

    #    if ($::New_Second and !($::Second % 20))
    if ( ::new_minute 3 ) {
        RequestThermostatUpload();
        return;
    }

    if ($::New_Msecond_100) {
        my ($serial_port) = $::Serial_Ports{Stargate}{object};
        my $parse_packet = 0;

        #my %table_iounit = qw(0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 a 10 b 11 c 12 d 13 e 14 f 15);

        #    my %table_echocommands = qw (0 0x00 2 0x02 3 0x03 4 0x04 5 0x05 8 0x08 a 0x0a c 0x0c);

        my ($data);
        unless ( $data = $serial_port->input ) {

            # If we do not do this, we may get endless error messages.
            $serial_port->reset_error;
        }

        # SerialPort returns the empty string, which is defined.
        # We need to allow for data=0, so need to use the defined test.
        undef $data if $data eq '';

        if ( defined $data ) {

            #print "SG:>$data<\n";
            #           $data =~ s/[\r\n]/\t/g;
            #           print "db Stargate serial data1=$data...\n" if $main::Debug{stargate};

            $serial_data .= $data;
            print "db Stargate serial data2=$serial_data...\n"
              if $main::Debug{stargate};
            while ( my ( $record, $remainder ) =
                $serial_data =~ /(.+?)[\r\n]+(.*)/s )
            {
                #print "** $record\n";
                $parse_packet = 1;
                $serial_data =
                  $remainder;    # Might have part of the next record left over

                print "db Stargate serial data3=$record remainder=$remainder.\n"
                  if $main::Debug{stargate};
                print "db Stargate serial data3=$record\n"
                  if $main::Debug{stargate};

                #print "Stargate serial1=$record\n" unless $record =~ /(\!\!\d\d\/.*)/;

                ParseTimerUpload($1) if $record =~ /(^[\d|A|B|C|D|E|F]{4})\z/i;
                next if $record =~ /(^[\d|A|B|C|D|E|F]{4})\z/i;
                ResetTimerUpload();

                ParseVariableUpload($1)
                  if $record =~ /(^[\d|A|B|C|D|E|F]{2})\z/i;
                next if $record =~ /(^[\d|A|B|C|D|E|F]{2})\z/i;
                ResetVariableUpload();

                ParseEchoCommand($1) if $record =~ /(\!\!\d\d\/.*)/;
                next if $record =~ /(\!\!\d\d\/.*)/;

                ParseCallerId($1)
                  if $last_caller_id and $record =~ /(^\d{7,10}.*)/;

                # When we get here it's time to clear the caller id flag
                $last_caller_id = 0;
                next if $record =~ /(^\d{7,10}.*)/;

                #print "TD=$1\n" if $record =~ /\#\#5f([\d|A|B|C|D|E|F]{8})\z/i;
                ParseThermostatUpload($1)
                  if $record =~ /\#\#5f([\d|A|B|C|D|E|F]{8})\z/i;
                next if $record =~ /\#\#5f([\d|A|B|C|D|E|F]{8})\z/i;

                # Ignore any responses to our commands
                next if $record eq "##0";
                next if $record eq "##1";

                ParseASCII($record);

                # It looks like the user has the Stargate modem configured on our port as it's sending us ocassioanl init strings?
                print
                  "Stargate sent modem command to MH: $record.\nPlease move modem to different Stargate port\n"
                  if $record =~ /^AT.*/ and $main::Debug{stargate};
                next if $record =~ /^AT.*/;

                print "Stargate unknown response:$record\n";
            }
            if ( $parse_packet == 0 ) {
                print "SG Didnt fit the regexp:>$serial_data<\n"
                  if $main::Debug{stargate};
            }
            $parse_packet = 0;
        }
    }

    if ( $::New_Msecond_250 && @stargate_command_list > 0 && $transmitok ) {
        if ( $::Serial_Ports{Stargate}{object} ) {
            my ($port)   = shift @stargate_command_list;
            my ($output) = shift @stargate_command_list;
            print "Stargate send: " . $output . "\n" if $main::Debug{stargate};
            $::Serial_Ports{Stargate}{object}
              ->write( "##%a5" . $port . $output . "\r" );
        }
    }

    return;
}

sub UserCodePostHook {
}

sub ParseEchoCommand {
    my ($data) = @_;

    my %table_hcodes = qw(6  A 7  B 4  C 5  D 8  E 9  F a  G b H
      e  I f  J c  K d  L 0  M 1  N 2  O 3 P);
    my %table_dcodes = qw(06  1 07  2 04  3 05  4 08  5 09  6 0a  7 0b 8
      0e  9 0f  A 0c  B 0d  C 00  D 01  E 02  F 03 B
      14  J 1c  K 12  L 1a M 18 O 10 P);

    #                          10 ALL_OFF 18 ALL_ON
    #                         16 ALL_OFF_LIGHTS);

    $data = substr( $data, 13 );

    #           print "Stargate record=$record data=$data Hex=" . unpack('H*', $record) . "\n" if lc($main::config_parms{debug}) eq 'wes';
    print "db data4=$data\n" if $main::Debug{stargate};

    my @bytes       = split //, $data;
    my $command     = hex $bytes[0];
    my $subcommand  = hex $bytes[1];
    my $commanddata = hex $bytes[2] . $bytes[3];

    #	print "SG Command: $command: $subcommand : $commanddata \n"
    # First check for X10 data
    if ( $command == 0x00 ) {

        #return undef unless $bytes[0] eq '0'; # Only look at x10 data for now
        next
          unless $bytes[1] eq '0'
          or $bytes[1] eq '1'
          or $bytes[1] eq '8'
          or $bytes[1] eq '9';    # Only look at receive data for now
         # Disable using the Stargate for X10 receive if so configured.  I am using the CM11a and just use
         # the stargate for I/O and phone control (bsobel@vipmail.com)
        next if $main::config_parms{Stargate_DisableX10Receive};

        my ( $house, $device );
        if ( ( $house = $table_hcodes{ lc( $bytes[3] ) } ) eq undef ) {
            print "Error, not a valid Stargate house code: $bytes[3]\n";
            next;
        }
        $bytes[1] = $bytes[1] & 1;
        my $code = $bytes[1] . $bytes[2];
        if ( ( $device = $table_dcodes{ lc($code) } ) eq undef ) {
            print "Error, not a valid Stargate device code: $code\n";
            next;
        }
        else {
            my $data = $house . $device;
            print "Stargate X10 receive:$data\n" if $main::Debug{stargate};
            &main::process_serial_data( "X" . $data );
            next;
        }
    }

    # Next check for digital IO input
    elsif ( ( $command == 0x0a ) or ( $command eq 0x0c ) ) {
        my $code       = $bytes[0] . $bytes[1];
        my $unitstates = hex $bytes[2] . $bytes[3];
        ParseDigitalInputData( $code, $unitstates );

    }

    # Next check for phone state changes
    elsif ( $command == 0x01 ) {

        #	print "TELE>$rawdata<\n";
        my $data = hex $bytes[2] . $bytes[3];
        ParseTelephoneData( $subcommand, $commanddata );
    }

    # Next check for timer state changes
    elsif ( $command == 0x02 ) {

        #ParseTimerData($subcommand, $commanddata);
    }

    # Next check for flag state changes
    elsif ( $command == 0x03 ) {

        #	print "SG Flag $subcommand: $commanddata";
        ParseFlagData( $subcommand, $commanddata );
    }

    # Next check for variable state changes
    elsif ( $command == 0x04 ) {
        ParseVariableData( $subcommand, $commanddata );
    }

    # Next check for relay state changes
    elsif ( $command == 0x05 ) {
        my $code       = $bytes[0] . $bytes[1];
        my $unitstates = hex $bytes[2] . $bytes[3];
        ParseRelayData( $code, $unitstates );
    }

    # Next check for transmitted ir
    elsif ( $command == 0x09 ) {

        #print "SG IR $subcommand: $commanddata";
        ParseIRData( $subcommand, $commanddata );
    }

    # Check for thermostat state changes (part 1)
    elsif ( $command == 0x0d ) {
        if ( $subcommand == 0x00 ) {
            $last_thermostat_address = $commanddata;
        }
        else {
            print "Stargate Echo unknown thermostat command $data\n";
        }
    }

    # Check for thermostat state changes (part 2)
    elsif ( $command == 0x0b ) {
        ParseThermostatData( $last_thermostat_address, $subcommand,
            $commanddata );
    }
    else {
        print "$::Time_Now Unknown echo command:$data\n";
    }
}

sub RequestVariableUpload {
    $::Serial_Ports{Stargate}{object}->write("##%12\r");
}

sub ParseVariableUpload {
    my ($data) = @_;
    print "Variable #" . $Last_Upload_Variable . " upload command data=$data\n";
    SetVariableState( $Last_Upload_Variable++, hex($data) );
}

sub ResetVariableUpload {
    $Last_Upload_Variable = 0;
}

sub RequestThermostatUpload {
    ResetThermostatUpload();

    for my $current_object (@stargatethermostat_object_list) {
        my $data =
          "##%5f" . sprintf( "%02x", $current_object->{address} - 1 ) . "00\r";
        if ( $::Serial_Ports{Stargate}{object}->write($data) == length($data) )
        {
            push( @Thermostat_Upload_List,
                join( ',', $current_object->{address} - 1, time ) );
        }
    }

    $Thermostat_Upload_Count = scalar @stargatethermostat_object_list;
}

sub ParseThermostatUpload {
    my ($data) = @_;

    # Ignore the data unless we requested it (it would mean we are out of sync)
    return unless $Thermostat_Upload_Count > 0;

    my ( $address, $requesttime ) =
      split( ',', shift(@Thermostat_Upload_List) );
    my ($timediff) = time - $requesttime;

    # If the thermostat uploads got out of sync (somehow), reset and try again
    if ( $timediff > 30 ) {
        print
          "Stargate Thermostat out of sync data=$data timediff=$timediff Trying again\n"
          if $main::Debug{stargate};

        ResetThermostatUpload();

        # Clear any remaining thermostat states out of the queue by waiting 10 seconds and then try again
        ::run_after_delay 10, sub {
            &Stargate::RequestThermostatUpload();
        };
        return;
    }
    else {
        push( @Thermostat_Upload_Data, join( ',', $address, $data ) );
        $Thermostat_Upload_Count -= 1;
        print "Stargate Thermostat uploaded data for $address $data\n"
          if $main::Debug{stargate};
    }

    # Ok, this appears to be the last item from an expected group, now go set them all.
    if ( $Thermostat_Upload_Count == 0 ) {
        while ( scalar @Thermostat_Upload_Data > 0 ) {
            my ( $address, $data ) =
              split( ',', shift @Thermostat_Upload_Data );

            print "Stargate Thermostat upload command for address:"
              . $address
              . " data=$data\n"
              if $main::Debug{stargate};

            ParseThermostatData( $address, 0x00, hex substr( $data, 0, 2 ) );
            ParseThermostatData( $address, 0x01, hex substr( $data, 2, 2 ) );
            ParseThermostatData( $address, 0x03, hex substr( $data, 4, 2 ) );
            ParseThermostatData( $address, 0x04, hex substr( $data, 6, 2 ) );
        }
        ResetThermostatUpload();
    }
}

sub ResetThermostatUpload {
    $Thermostat_Upload_Count = 0;
    undef @Thermostat_Upload_List;
    undef @Thermostat_Upload_Data;
}

sub ParseThermostatData {
    my ( $address, $subcommand, $data ) = @_;

    # Temperature change
    if ( $subcommand eq 0x00 ) {
        SetThermostatState( $address, "temp", $data );
    }

    # Setpoint change
    elsif ( $subcommand eq 0x01 ) {
        SetThermostatState( $address, "setpoint", $data );
    }
    elsif ( $subcommand eq 0x03 ) {
        if ( $data eq 0x00 ) {
            SetThermostatState( $address, "systemmode", "off" );
        }
        elsif ( $data eq 0x01 ) {
            SetThermostatState( $address, "systemmode", "heat" );
        }
        elsif ( $data eq 0x02 ) {
            SetThermostatState( $address, "systemmode", "cool" );
        }
        elsif ( $data eq 0x03 ) {
            SetThermostatState( $address, "systemmode", "auto" );
        }
        else {
            print "Stargate Thermostat unknown state command: $data\n";
        }
    }
    elsif ( $subcommand eq 0x04 ) {
        if ( $data eq 0x00 ) {
            SetThermostatState( $address, "fanmode", "off" );
        }
        elsif ( $data eq 0x01 ) {
            SetThermostatState( $address, "fanmode", "on" );
        }
        else {
            print "Stargate Thermostat unknown fan command: $data\n";
        }
    }
    elsif ( $subcommand eq 0x06 ) {

        # This error message isn't prefaced with another message indicating the unit #, it's included
        # as the data to this message.
        #        print "Stargate Thermostat #$data polling error\n";
    }
    else {
        print
          "Stargate Thermostat #$address subcommand:$subcommand data=$data\n";
    }
}

sub SetThermostatState {
    my ( $address, $state, $statedata ) = @_;

    for my $current_object (@stargatethermostat_object_list) {
        next unless $current_object->{address} - 1 == $address;

        # Since we handle substates in this item, check if the substate has changed or not
        my $newstate;
        $newstate = $state if $current_object->{$state} ne $statedata;

        print "Stargate Thermostat #"
          . $current_object->{address}
          . " state change to $newstate:$statedata (internal=$state)\n"
          if $newstate;
        $current_object->set_states_for_next_pass($newstate) if $newstate;
        $current_object->set_states_for_next_pass(
            $newstate . ":" . $statedata )
          if $newstate;

        # Set the subitem state so we can check for changes later (and respond to state() requests)
        $current_object->{$state} = $statedata if $newstate;
    }
}

sub ParseDigitalInputData {
    my ( $code, $unitstates ) = @_;

    my %table_iobase = qw(a0 1 c0 2 a2 3 c2 4 a3 5 c3 6 a4 7 c4 8);

    my $base;
    unless ( $base = $table_iobase{ lc($code) } ) {
        print "$::Time_Now Error, not a valid Stargate IO base: $code\n";
        return;
    }

    SetDigitalInputState( $base, $unitstates );
}

sub SetDigitalInputState {
    my ( $base, $unitstates ) = @_;

    for my $current_object (@stargatedigitalinput_object_list) {
        print $current_object->{address}
          . " base=$base t1="
          . ( $base - 1 ) * 8 . " t2="
          . ( $base * 8 ) . "\n"
          if $main::Debug{stargate};

        # Make sure the item is within the range of 8 status bits returned, skip if not
        next
          unless ( $current_object->{address} > ( ( $base - 1 ) * 8 ) )
          and ( $current_object->{address} <= ( $base * 8 ) );

        my $unitbit =
          1 << ( $current_object->{address} - 1 ) - ( $base - 1 ) * 8;

        my $newstate;
        if ( $current_object->invert() == 1 ) {
            $newstate = "on"
              if $current_object->state ne 'on' and !( $unitstates & $unitbit );
            $newstate = "off"
              if $current_object->state ne 'off' and ( $unitstates & $unitbit );
        }
        else {
            $newstate = "on"
              if $current_object->state ne 'on' and ( $unitstates & $unitbit );
            $newstate = "off"
              if $current_object->state ne 'off'
              and !( $unitstates & $unitbit );
        }
        print "Stargate Digitial Input #"
          . $current_object->{address}
          . " state change to $newstate\n"
          if $newstate and $::config_parms{debug} =~ /StargateDigitalInput/i;
        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }
}

sub ParseTelephoneData {
    my ( $subcommand, $data ) = @_;

    #print "Parse HERE!$subcommand:$data\n";

    if ( $subcommand eq 0x05 )    #ICM DTMF
    {
        if ( $data <= 0x09 ) {
            SetTelephoneState( 'ICM', "dtmf::$data" );
        }
        elsif ( $data eq 0x0a ) {
            SetTelephoneState( 'ICM', "dtmf::0" );
        }
        elsif ( $data eq 0x0b ) {
            SetTelephoneState( 'ICM', "dtmf::*" );
        }
        elsif ( $data eq 0x0c ) {
            SetTelephoneState( 'ICM', "dtmf::#" );
        }
    }
    elsif ( $subcommand eq 0x06 )    #CO DTMF
    {
        if ( $data <= 0x09 ) {
            SetTelephoneState( 'CO', "dtmf::$data" );
        }
        elsif ( $data eq 0x0b ) {
            SetTelephoneState( 'CO', "dtmf::*" );
        }
        elsif ( $data eq 0x0c ) {
            SetTelephoneState( 'CO', "dtmf::#" );
        }
    }
    elsif ( $subcommand eq 0x01 )    #ICM Hookstate
    {
        if ( $data eq 0x12 ) {
            SetTelephoneState( "ICM", "offhook" );
        }
        elsif ( $data eq 0x13 ) {
            SetTelephoneState( "ICM", "onhook" );
        }
    }
    elsif ( $subcommand eq 0x02 )    #CO Hookstate
    {
        if ( $data eq 0x10 ) {
            SetTelephoneState( 'CO', "offhook" );
        }
        elsif ( $data eq 0x11 ) {
            SetTelephoneState( 'CO', "onhook" );
        }
        elsif ( $data >= 0x40 ) {
            SetTelephoneState( 'CO', "ring::" . ( $data - 0x40 ) );
        }
        else {
            &::print_log(
                "Stargate Telephone unknown subcommand:$subcommand data:$data\n"
            );
        }
    }
    elsif ( $subcommand eq 0x0f ) {
        if ( $data eq 0x33 ) {
            $last_caller_id = 1;
        }
        else {
            &::print_log(
                "Stargate Telephone unknown subcommand:$subcommand data:$data\n"
            );
        }
    }
    else {
        &::print_log(
            "Stargate Telephone unknown subcommand:$subcommand data:$data\n");
    }

}

sub ParseCallerId {
    my ($data) = @_;

    &::print_log("Stargate CallerId=$data\n");
    SetTelephoneState( 'CO', "callerid::N::" . $data );
}

sub SetTelephoneState {
    my ( $address, $state ) = @_;

    #    print "SetTelephoneState called with state=$line,$state\n";

    for my $current_object (@stargatetelephone_object_list) {
        next unless lc $current_object->{address} eq lc $address;

        #        next unless $current_object->{address} == $address;

        $current_object->set($state);
        my $newstate;
        $newstate = $state if $current_object->state ne $state;

        #        print "Stargate Telephone #" . $current_object->{address} . " state change to $newstate\n"
        #        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }

}

sub ParseASCII {
    my ($data) = @_;
    SetASCIIState( 'COM1', $data );
}

sub SetASCIIState {
    my ( $address, $state ) = @_;

    #    print "SetTelephoneState called with state=$line,$state\n";

    for my $current_object (@stargateascii_object_list) {

        #	next unless lc $current_object->{line} eq lc $line;
        next unless $current_object->{address} == $address;

        $current_object->set($state);
        my $newstate;
        $newstate = $state if $current_object->state ne $state;

        #        print "Stargate Telephone #" . $current_object->{line} . " state change to $newstate\n"
        #        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }
}

sub ParseFlagData {
    my ( $subcommand, $data ) = @_;

    if ( $subcommand eq 0x00 ) {
        SetFlagState( $data, 'clear' );
    }

    # Is this a load command?
    elsif ( $subcommand eq 0x01 ) {
        SetFlagState( $data, 'set' );
    }
}

sub SetFlagState {
    my ( $address, $state ) = @_;

    for my $current_object (@stargateflag_object_list) {
        next unless $current_object->{address} == $address;

        my $newstate;
        $newstate = $state if $current_object->state ne $state;

        print "Stargate Flag #"
          . $current_object->{address}
          . " state change to $newstate\n"
          if $newstate;
        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }
}

sub ParseVariableData {
    my ( $subcommand, $data ) = @_;

    if ( $subcommand eq 0x00 ) {

        # Store off read value;
        $last_variable_load = $data;
    }

    # Is this a load command?
    elsif ( $subcommand eq 0x01 ) {

        # Use stored value here
        SetVariableState( $data, $last_variable_load );
    }

    # Is this a clear command?
    elsif ( $subcommand eq 0x02 ) {
        SetVariableState( $data, 0 );
    }

    # Is this an increment command?
    elsif ( $subcommand eq 0x03 ) {
        SetVariableState( $data, $last_variable_load );
    }

    # Is this a decrement command?
    elsif ( $subcommand eq 0x04 ) {
        SetVariableState( $data, $last_variable_load );
    }
}

sub SetVariableState {
    my ( $address, $state ) = @_;

    for my $current_object (@stargatevariable_object_list) {
        next unless $current_object->{address} == $address;

        my $newstate;
        $newstate = $state if $current_object->state() ne $state;

        print "Stargate Variable #"
          . $current_object->{address}
          . " state change to $newstate\n"
          if $newstate ne undef;
        $current_object->set_states_for_next_pass($newstate)
          if $newstate ne undef;
    }
}

sub ParseRelayData {
    my ( $code, $unitstates ) = @_;

    my %table_iobase = qw(50 1 52 2 53 3 54 4);

    my $base;
    unless ( $base = $table_iobase{ lc($code) } ) {
        print "$::Time_Now Error, not a valid Stargate IO base: $code\n";
        return;
    }

    SetRelayState( $base, $unitstates );
}

sub SetRelayState {
    my ( $base, $unitstates ) = @_;

    for my $current_object (@stargaterelay_object_list) {
        print $current_object->{address}
          . " base=$base t1="
          . ( $base - 1 ) * 8 . " t2="
          . ( $base * 8 ) . "\n"
          if $main::Debug{stargate};

        # Make sure the item is within the range of 8 status bits returned, skip if not
        next
          unless ( $current_object->{address} > ( ( $base - 1 ) * 8 ) )
          and ( $current_object->{address} <= ( $base * 8 ) );

        my $unitbit = 1 << ( $current_object->{address} - 1 );

        my $newstate;
        $newstate = "on"
          if $current_object->state ne 'on' and ( $unitstates & $unitbit );
        $newstate = "off"
          if $current_object->state ne 'off' and !( $unitstates & $unitbit );

        print "Stargate Relay #"
          . $current_object->{address}
          . " state change to $newstate\n"
          if $newstate;
        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }
}

sub ParseIRData {
    my ( $subcommand, $data ) = @_;

    # Command is bank (0 = 0-255, 1 = 256-511)
    SetIRState( hex( ( $subcommand * 256 ) + $data ), "played" );
}

sub SetIRState {
    my ( $address, $state ) = @_;

    for my $current_object (@stargateir_object_list) {
        next unless $current_object->{address} == $address;

        my $newstate;
        $newstate = $state if $current_object->state ne $state;

        print "Stargate IR #"
          . $current_object->{address}
          . " state change to $newstate\n"
          if $newstate;
        $current_object->set_states_for_next_pass($newstate) if $newstate;

        # Removed, why did we reset to idle? state vs state_now should have indicated the mode to us?
        #$current_object->set_states_for_next_pass("idle") if $newstate;
    }
}

sub ParseTimerUpload {
    my ($data) = @_;
    print "Timer upload command data=$data\n";
}

sub ResetTimerUpload {
    $Last_Upload_Timer = 0;
}

#
# Below are externally callable functions
#

sub send_command {
    my ( $serial_port, $port, $command ) = @_;
    if ( $port =~ /com1/i ) {
        $port = "01";
    }
    elsif ( $port =~ /com2/i ) {
        $port = "01";
    }
    elsif ( $port =~ /com3/i ) {
        $port = "01";
    }
    elsif ( $port =~ /rs485/i ) {
        $port = "07";
    }
    else {
        print "Stargage send_command invalid port $port\n";
        return;
    }

    push( @stargate_command_list, $port );
    push( @stargate_command_list, $command );

    return;
}

sub read_time {
    my ($serial_port) = @_;
    print "Reading Stargate time\n";
    if ( 6 == ( $temp = $serial_port->write("##%06\r") ) ) {
        select undef, undef, undef, 100 / 1000;    # Give it a chance to respond
        if ( my $data = $serial_port->input ) {

            #print "Stargate time string: $data\n";
            # Not sure about $second.  $wday looks like year, not 0-7??
            my ( $year, $month, $mday, $wday, $hour, $minute, $second ) =
              unpack( "A2A2A2A2A2A2A2", $data );
            print "Stargate time:  $hour:$minute:$second $month/$mday/$year\n";
            return
              wantarray
              ? ( $second, $minute, $hour, $mday, $month, $year, $wday )
              : " $hour:$minute:$second $month/$mday/$year";
        }
        else {
            print "Stargate did not respond to read_time request\n";
            return 0;
        }
    }
    else {
        print "Stargate bad write on read_time request: $temp\n";
        return 0;
    }
}

sub read_log {
    my ($serial_port) = @_;
    print "Reading Stargate log\n";
    if ( 6 == ( $temp = $serial_port->write("##%15\r") ) ) {
        select undef, undef, undef, 100 / 1000;    # Give it a chance to respond
               # May need to paste data together to find real line breaks
        my @log;
        my $buffer;

        # Read data in a buffer string
        while ( my $data = $serial_port->input ) {
            $buffer .= $data;
            select undef, undef, undef,
              100 / 1000;    # Need more/less/any delay here???
        }

        # Filter out extraneous stuff before splitting into list
        $buffer =~ s/##0\r\n//g;
        $buffer =~ s/!!.*\r\n//g;

        @log = split /\r\n/, $buffer;

        #my $elem;
        #foreach $elem (@log) {
        #        # Check for real log record
        #        if ( $elem =~ /^\d+\// ) {
        #                print "-->$elem<--\n";
        #        }
        #}

        my $count = @log;
        print "$count Stargate log records were read\n";
        return @log;
    }
    else {
        print "Stargate bad write on read_log request: $temp\n";
        return 0;
    }
}

#       Stargate log sample format
#Stargate log record: r call
#09/29 10:03:54 Downstairs Unoccupied
#09/29 11:58:14 Call from Mom
#09/29 15:21:34 Crawl
#Stargate log record:  space door opened
#09/29 15:22:13 Downstairs is Occupied
#09/29 15:24:00 Call from Mom
#09/29 15:43:06

sub clear_log {
    my ($serial_port) = @_;

    #print "Clearing Stargate log\n";
    if ( 6 == $serial_port->write("##%16\r") ) {
        print "Stargate log cleared\n";
        return 1;
    }
    else {
        print "Bad Stargate log reset\n";
        return 0;
    }
}

sub read_flags {
    my ($serial_port) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object};
    print "Reading Stargate Flags\n";
    if ( 6 == ( $temp = $serial_port->write("##%10\r") ) ) {
        select undef, undef, undef, 100 / 1000;    # Give it a chance to respond
               # How may flags?? Best look for end of data character ... \n\n??
        my @flags;
        while ( my $data = $serial_port->input ) {
            my ( $header, $flags ) = $data =~ /(\S+?)[\n\r]+(\S+)/;
            my $l = length $flags;
            $l /= 2;

            #print "Flag string has $l bits: $flags\n";
            # There are 2 characters per flag
            #           push(@flags, split('', $flags));
            while ($flags) {
                push( @flags, substr( $flags, 0, 2 ) );
                $flags = substr( $flags, 2 );
            }
        }
        print "Stargate did not respond to read_flags request\n" unless @flags;
        return @flags;
    }
    else {
        print "Stargate bad write on read_flags request: $temp\n";
    }
}

sub read_voicemail_count {
    my ($l_box) = @_;
    my $serial_port = $::Serial_Ports{Stargate}{object};
    my %count;

    $l_box = sprintf( "%02d", $l_box );
    &::print_log("VM count :$l_box:");
    if ( 7 == ( $temp = $serial_port->write("##%5c$l_box\r") ) or 1 ) {
        select undef, undef, undef, 100 / 1000;    # Give it a chance to respond
               #5c0301\r\n  3 old messages 1 new
        my $data = $serial_port->input;
        $data =~ /###5c(\d\d)(\d\d)/i;
        $count{new} = sprintf( "%d", $2 );
        $count{old} = sprintf( "%d", $1 );
        return \%count;
    }
}

sub voicemail {
    my ( $l_box, $l_command, $l_output ) = @_;

    $l_box = sprintf( "%02d", $l_box );
    if ( !defined $l_output or !defined $l_box ) {
        &::print_log("Please specify box and output device (lo,co,ic)");
        return;
    }

    my $serial_port  = $::Serial_Ports{Stargate}{object};
    my %table_output = qw(lo 02 co 04 ic 08);
    my %table_commands =
      qw(first 01 next 02 repeat 04 stop 06 all 07 allnew 08 cid 05 delete 03 back 09 forward 0a);
    my $l_string;

    &::print_log("Play :$l_command:");
    $l_string = "##%94"
      . $table_commands{$l_command}
      . $l_box . "00"
      . $table_output{$l_output} . "\r";
    if ( 7 == ( $temp = $serial_port->write($l_string) ) or 1 ) {

        #	        select undef, undef, undef, 100 / 1000; # Give it a chance to respond
        #		#5c0301\r\n  3 old messages 1 new
        #		my $data = $serial_port->input;
        #		$data =~/###5c(\d\d)(\d\d)/i;
        #		$count{new}=sprintf("%d",$2);
        #		$count{old}=sprintf("%d",$1);
        #		return \%count;
    }

}

sub read_variables {
    my ($serial_port) = @_;
    print "Reading Stargate Variables\n";
    if ( 6 == ( $temp = $serial_port->write("##%12\r") ) ) {
        select undef, undef, undef, 100 / 1000;    # Give it a chance to respond
               # May need to paste data together to find real line breaks
        my @vars;
        my $buffer;
        while ( my $data = $serial_port->input ) {
            $buffer .= $data
              unless ( $data =~ /#/ );    # ##0 is end of list marker
            select undef, undef, undef,
              100 / 1000;                 # Need more/less/any delay here???
        }
        @vars = split /\r\n/, $buffer;
        my $count = @vars;
        print "$count Stargate var records were read\n";
        print "Stargate did not respond to read_variables request\n"
          unless @vars;
        return @vars;
    }
    else {
        print "Stargate bad write on read_variables request: $temp\n";
    }
}

=item C<set_time>

This command was decoded empirically from Starate/WinEVM interaction
Homebase (Stargate) command is ##%05AAAALLLLTTSSYYMMDDRRHHMMCC
AAAA = Latitude, LLLL = Longitude, TT=Timezone (05=EST)
SS="Is daylight savings time used in your area?" (01=Yes)
YY=Year, MM=Month, DD=Day, RR=DOW (Seems to be ignored, but set as
      Th=01, Wen=02, Tu=04, Mo=08, Sun=10, Sat=20)
CC=00 (Checksum? doesn't appear to be used)

=cut

sub set_time {
    my ($serial_port) = @_;
    my ( $Second, $Minute, $Hour, $Mday, $Month, $Year, $Wday, $Yday, $isdst )
      = localtime time;
    $Month++;
    $Wday++;
    my $localtime = localtime time;

    # Week day setting seems to be ignored by stargate, so set it to 00
    $Wday = 0;

    # Bruce's weekday calculation, Mon=1, Sun=7)
    # $Wday = 2 ** (7 - $Wday);
    # if ($Yday > 255) {
    #    $Yday -= 256;
    #    $Wday *= 2;
    # }

    # Fix Year 2000 = 100 thing??
    if ( $Year ge 100 ) {
        $Year -= 100;
    }

    # Set daylight savings flag, this should be in mh.private.ini if your area uses DST
    $isdst = "00";    # was 01
                      #
      #print ("DST=$isdst Y=$Year M=$Month D=$Mday DOW=$Wday H=$Hour M=$Minute\n");
    my $set_time = sprintf(
        "%04x%04x%02x%02x%02d%02d%02d%02d%02d%02d",
        abs( $main::config_parms{latitude} ),
        abs( $main::config_parms{longitude} ),
        $main::config_parms{time_zone},
        $isdst,
        $Year,
        $Month,
        $Mday,
        $Wday,
        $Hour,
        $Minute
    );

    #Checksum not required, so set it to 00
    #my $checksum = sprintf("%02x", unpack("%8C*", $set_time));
    my $checksum = "00";
    print "Stargate set_time=$set_time checksum=$checksum\n"
      if $main::Debug{stargate};

    if (
        32 == (
            $temp =
              $serial_port->write( "##%05" . $set_time . $checksum . "\r" )
        )
      )
    {
        print "Stargate time has been updated to $localtime\n";
        return 1;
    }
    else {
        print "Stargate bad write on set_time: $temp\n";
        return -1;
    }

}

sub send_X10 {
    my ( $serial_port, $house_code ) = @_;
    print "\ndb sending Stargate x10 code: $house_code\n"
      if $main::Debug{stargate};

    my ( $house, $code ) = $house_code =~ /(\S)(\S+)/;
    $house = uc($house);
    $code  = uc($code);

    my %table_hcodes = qw(A 6  B 7  C 4  D 5  E 8  F 9  G a  H b
      I e  J f  K c  L d  M 0  N 1  O 2  P 3);
    my %table_dcodes = qw(1 06  2 07  3 04  4 05  5 08  6 09  7 0a  8 0b
      9 0e  A 0f  B 0c  C 0d  D 00  E 01  F 02  G 03
      J 14  K 1c  L 12  M 1a O 18 P 10
      ON 14  OFF 1c  BRIGHT 12  DIM 1a);

    #                          ALL_OFF 10  ALL_ON 18
    #                          ALL_OFF_LIGHTS 16);

    my ( $house_bits, $code_bits, $function, $header );

    if ( ( $house_bits = $table_hcodes{ uc($house) } ) eq undef ) {
        print "Error, invalid Stargate X10 house code: $house\n";
        return;
    }

    if ( ( $code_bits = $table_dcodes{ uc($code) } ) eq undef ) {
        print "Error, invalid Stargate x10 code: $code\n";
        return;
    }

    $header = "##%040" . $code_bits . $house_bits;
    print "db Stargate x10 command sent: $header\n" if $main::Debug{stargate};

    my $sent = $serial_port->write( $header . "\r" );
    print "Bad Stargate X10 transmition sent=$sent\n" unless 10 == $sent;
}

=item C<send_telephone>

  Valid digitis 0-9, * #
  OnHook = +
  OffHook = ^
  Pause = ,
  CallerID C
  HookFlash !

=cut

sub send_telephone {
    my ( $serial_port, $phonedata ) = @_;
    print "\ndb sending Stargate telephone command: $phonedata\n"
      if $main::Debug{stargate};

    $phonedata = "##%57<" . $phonedata . ">";
    print "db Stargate telephone command sent: $phonedata\n"
      if $main::Debug{stargate};

    my $sent = $serial_port->write( $phonedata . "\r" );
    print "Bad Stargate telephone transmition sent=$sent\n" unless $sent > 0;
}

sub send_ascii {
    my ($data) = @_;
    my $serial_port;

    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );
}

sub set_audio {
    my ( $p_input, $p_output, $p_state ) = @_;
    my $serial_port;

    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my %table_input  = qw(li 02 ic 03 co 04 icm 03);
    my %table_output = qw(lo 02 co 04 ic 08 icm 08);
    my %table_state  = qw(off 00 on 01);

##%5d010402 CoLoConnect
##%5d000402 CoLoDisconnect
##%5d010302 ImLoConnect
##%5d000302 ImLoDisConnect
##%5d010204 LiCoConnect
##%5d000204 LiCoDisConnect
##%5d010208 LiImConnect
##%5d000208 LiImDisConnect

    my ($command) = "##%5d"
      . $table_state{ lc($p_state) }
      . $table_input{ lc($p_input) }
      . $table_output{ lc($p_output) } . "\r";

    #        print "Stargate Audio Input: $command\n";
    if ( 8 == $serial_port->write($command) ) {

        #      print "Stargate Audio Input: $p_input Output: $p_output State: $p_state\n";
        return 1;
    }
    else {
        #       print "BAD Stargate Audio Input: $p_input Output: $p_output State: $p_state\n";
        return 0;
    }
}

1;    # for require

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateDigitalInput>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#
# Item object version (this lets us use object links and events)
#

package StargateDigitalInput;
@StargateDigitalInput::ISA = ('Generic_Item');
my $m_inverted;

sub new {
    my ( $class, $address, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my $self = { address => $address, serial_port => $serial_port };
    bless $self, $class;

    push( @stargatedigitalinput_object_list, $self );

    return $self;
}

sub setstate_invert {
    my ( $self, $substate ) = @_;
    return $self->invert(1)
      if $substate eq '1'
      or $substate eq 'set'
      or $substate eq 'on'
      or $substate eq 'yes'
      or $substate eq 'true';
    return $self->invert(0)
      if $substate eq '0'
      or $substate eq 'clear'
      or $substate eq 'off'
      or $substate eq 'no'
      or $substate eq 'false';
    print "Stargate Digital Inputs invalid invert request:$substate\n";
    return -1;
}

sub default_setstate {
    print "Stargate Digital Inputs can not be set\n";
    return -1;
}

sub invert {
    my ( $class, $p_invert ) = @_;
    if ( defined $p_invert ) {
        $class->{m_inverted} = $p_invert;
    }
    return $class->{m_inverted};
}
1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateVariable>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#
# Item object version (this lets us use object links and events)
#
package StargateVariable;
@StargateVariable::ISA = ('Generic_Item');

sub new {
    my ( $class, $address, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my $self = { address => $address, serial_port => $serial_port };
    bless $self, $class;

    push( @stargatevariable_object_list, $self );

    return $self;
}

sub default_setstate {
    my ( $self, $state, $set_by, $respond ) = @_;

    $state = int($state);

    if ( $state < 0 or $state > 255 ) {
        print "StargateVariable invalid state:$state set (must be 0-255)\n";
        return -1;
    }

    if ( $state eq $self->state() ) {
        print "StargateVariable ignoring reset of $state\n";
        return -1;
    }

    # The Stargate scripts supports:
    # Load
    # Clear
    # Increment
    # Decrement
    #
    # Our set will only handle a specific value for now (e.g. do a load)

    my ($command) =
      "##%26" . sprintf( "%02x%02x01", $self->{address}, $state ) . "\r";

    #print "Stargate variable command:$command\n";

    if ( length($command) != $self->{serial_port}->write($command) ) {
        print "StargateVariable serial write command failed:$command\n";
    }
    else {
        # Do this ourselves since we may change state to it's integer version
        $self->set_states_for_next_pass( $state, $set_by, $respond );
    }
    return -1;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateFlag>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#
# Item object version (this lets us use object links and events)
#
package StargateFlag;
@StargateFlag::ISA = ('Generic_Item');

sub new {
    my ( $class, $address, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my $self = { address => $address, serial_port => $serial_port };
    bless $self, $class;

    push( @stargateflag_object_list, $self );

    return $self;
}

sub default_setstate {
    my ( $self, $state ) = @_;

    $state = "set"
      if $state eq '1'
      or $state eq 'set'
      or $state eq 'on'
      or $state eq 'yes'
      or $state eq 'true';
    $state = "clear"
      if $state eq '0'
      or $state eq 'clear'
      or $state eq 'off'
      or $state eq 'no'
      or $state eq 'false';
    if ( $state ne "set" and $state ne "clear" ) {
        print
          "StargateFlag invalid state:$state set (set|on|1|yes|true or clear|off|0|no|false)\n";
        return -1;
    }

    my ($command) = "##%25"
      . sprintf( "%02x%02x", $self->{address}, $state eq "set" ? 1 : 0 ) . "\r";

    #print "Stargate flag command:$command\n";

    if ( length($command) != $self->{serial_port}->write($command) ) {
        print "StargateFlag serial write command failed:$command\n";
        return -1;
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateRelay>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#
# Item object version (this lets us use object links and events)
#
package StargateRelay;
@StargateRelay::ISA = ('Generic_Item');

sub new {
    my ( $class, $address, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my $self = { address => $address, serial_port => $serial_port };
    bless $self, $class;

    push( @stargaterelay_object_list, $self );

    return $self;
}

sub default_setstate {
    my ( $self, $state ) = @_;

    my %l_address = qw ( 1 1  2 2  3 4  4 8  5 16  6 32  7 64  8 128 );

    $state = "set"
      if $state eq '1'
      or $state eq 'set'
      or $state eq 'on'
      or $state eq 'yes'
      or $state eq 'true';
    $state = "clear"
      if $state eq '0'
      or $state eq 'clear'
      or $state eq 'off'
      or $state eq 'no'
      or $state eq 'false';
    if ( $state ne "set" and $state ne "clear" ) {
        print
          "StargateRelay invalid state:$state set (set|on|1|yes|true or clear|off|0|no|false)\n";
        return -1;
    }

    # Set
    my ($command) = "##%330019"
      . sprintf( "%02x%02x",
        $l_address{ $self->{address} },
        $state eq "set" ? $l_address{ $self->{address} } : 0 )
      . "\r";

    #&main::print_log("Stargate relay:$command:");
    if ( length($command) != $self->{serial_port}->write($command) ) {
        print "StargateRelay serial write command failed:$command\n";
        return -1;
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateThermostat>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#
# Item object version (this lets us use object links and events)
#
package StargateThermostat;
@StargateThermostat::ISA = ('Generic_Item');

sub new {
    my ( $class, $address, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my $self = { address => $address, serial_port => $serial_port };
    bless $self, $class;
    $self->restore_data( 'temp', 'setpoint', 'systemmode', 'fanmode' );

    push( @stargatethermostat_object_list, $self );

    return $self;
}

sub setstate_setpoint {
    my ( $self, $substate ) = @_;

    # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
    $self->SendTheromostatCommand( 0x20, $substate );
}

sub setstate_heatpoint {
    my ( $self, $substate ) = @_;

    # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
    $self->SendTheromostatCommand( 0x30, $substate )
      if $self->{systemmode} eq 'heat';
}

sub setstate_coolpoint {
    my ( $self, $substate ) = @_;

    # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
    $self->SendTheromostatCommand( 0x30, $substate )
      if $self->{systemmode} eq 'cool';
}

sub setstate_autopoint {
    my ( $self, $substate ) = @_;

    # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
    return $self->SendTheromostatCommand( 0x30, $substate )
      if $self->{systemmode} eq 'auto';
}

sub setstate_systemmode {
    my ( $self, $substate ) = @_;

    # Valid mode $state is 0/O for off 1/H for heat, 2/C for cool, and 3/A for auto (we add one to get to right command for the Stargate)
    $self->SendTheromostatCommand( 0x30, hex( 1 + ReturnCommand($substate) ) );
}

sub setstate_systemfanmode {
    my ( $self, $substate ) = @_;

    # Valid mode $state is 0 or 1 (we subtract from 6 to get to the 05 on and 06 auto commands)
    $self->SendTheromostatCommand( 0x30, hex( 6 - ReturnCommand($substate) ) );
}

sub default_getstate {
    my ( $self, $device ) = @_;

    return undef if ( $self->{address} == 0 );
    return $self->{state} if $device eq undef;

    SWITCH: for ($device) {
        /^address/i && do { return $self->{address} };

        #       /^zone/i            && do { return $self->{zone}};

        /^temp/i        && do { return $self->{temp} };
        /^temperature/i && do { return $self->{temp} };
        /^setpoint/i    && do { return $self->{setpoint} };
        /^zonemode/i    && do { return ReturnString( $self->{systemmode} ) };
        /^zonefanmode/i && do { return ReturnString( $self->{fanmode} ) };

        #       /^heatingstage1/i   && do { return ReturnString($self->{heatingstage1})};
        #       /^heatingstage2/i   && do { return ReturnString($self->{heatingstage2})};
        #       /^coolingstage1/i   && do { return ReturnString($self->{coolingstage2})};
        #       /^coolingstage2/i   && do { return ReturnString($self->{coolingstage2})};

        #       /^fanstatus/i       && do { return ReturnString($self->{fanstatus})};
        #       /^shortcycle/i      && do { return ReturnString($self->{shortcycle})};
        #       /^scp/i             && do { return ReturnString($self->{shortcycle})};

        /^systemmode/i && do { return ReturnString( $self->{systemmode} ) };
        /^mode/i       && do { return ReturnString( $self->{systemmode} ) };
        /^fanmode/     && do { return ReturnString( $self->{fanmode} ) };
    }

    return undef;
}

sub ReturnCommand {
    my ($data) = @_;

    SWITCH: for ($data) {
        /on/i  && do { return "1" };
        /1/    && do { return "1" };
        /0/    && do { return "0" };
        /off/i && do { return "0" };
        /h/i   && do { return "1" };
        /c/i   && do { return "2" };
        /a/i   && do { return "3" };
    }
    return undef;
}

sub ReturnString {
    my ($data) = @_;

    SWITCH: for ($data) {
        /0/ && do { return "off" };
        /1/ && do { return "on" };
        /H/ && do { return "heat" };
        /C/ && do { return "cool" };
        /A/ && do { return "auto" };
        /I/ && do { return "invalid" };
    }
    return "unknown";
}

sub SendTheromostatCommand {
    my ( $self, $command, $data ) = @_;
    return undef unless defined $command;

    my $output =
      "##%5e" . sprintf( "%02x%02x%02x\r", $self->{address}, $command, $data );
    $self->{serial_port}->write($output);
    return 1;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateTelephone>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Telephony_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#
# Item object version (this lets us use object links and events)
#
package StargateTelephone;
@StargateTelephone::ISA = ('Telephony_Item');

sub new {
    my ( $class, $address, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my $self = { address => $address, serial_port => $serial_port };
    bless $self, $class;

    push( @stargatetelephone_object_list, $self );
    $self->address( lc $address );
    return $self;
}

sub set {
    my ( $self, $state ) = @_;
    return if &main::check_for_tied_filters( $self, $state );

    # Set
    # Clear
    &::print_log("SGTelephoneclass call $$self{line} ,$state,");
    if ( $state =~ /^callerid/i ) {
        $state =~
          /callerid::([a-z,A-Z]*)::([0-9]*)\s*([a-z,A-Z,\s]*)\s*([0-9]*)/;
        $self->cid_name($3);
        $self->cid_number($2);
        $self->cid_type($1);
        $state = 'cid';
    }
    elsif ( $state =~ /^dialed/i ) {
        $state =~ /dialed::([0-9,\*,\#,\+,\^]*)/i;
        $self->cid_name('');
        $self->cid_number($1);
        $self->cid_type('');
        $state = 'dialed';
    }
    elsif ( $state =~ /^ring/i ) {
        $state =~ /ring::([0-9]*)/;
        $self->ring_count($1);
        $state = 'ring';
    }
    elsif ( $state =~ /^dtmf/i ) {
        my ($temp_digit) = $state =~ /dtmf::([0-9,\*,\#,\+,\^])/i;
        $self->SUPER::dtmf($temp_digit);
        $state = 'dtmf';
    }
    elsif ( $state =~ /.*hook/i ) {
        if ( $state eq 'onhook' ) {
            $self->SUPER::hook('on');
        }
        else {
            $self->SUPER::hook('off');
        }
        $state = 'hook';
    }
    $self->SUPER::set($state);

    #        $self->set_states_for_next_pass($state);
    return;
}

sub patch {
    my ( $self, $p_state ) = @_;

    &::print_log( "***PATCH ***:" . $self->address() . ":" . $p_state );
    if ( $p_state eq 'on' ) {
        &Stargate::set_audio( 'li',             $self->address(), 'on' );
        &Stargate::set_audio( $self->address(), 'lo',             'on' );
    }
    elsif ( defined $p_state ) {
        &Stargate::set_audio( 'li',             $self->address(), 'off' );
        &Stargate::set_audio( $self->address(), 'lo',             'off' );
    }
    return $self->SUPER::patch($p_state);
}

sub play {
    my ( $self, $p_file ) = @_;

    &Stargate::set_audio( 'li', $self->address(), 'on' );
    &::play($p_file);
    return $self->SUPER::play($p_file);
}

sub record {
    my ( $self, $p_file, $p_timeout ) = @_;

    &Stargate::set_audio( $self->address(), 'lo', 'on' );

    #	&::rec ($p_file);  ????
    return $self->SUPER::rec( $p_file, $p_timeout );
}

sub speak {
    my ( $self, %p_phrase ) = @_;
    $self->patch('on');
    &::speak(%p_phrase);

    #	Is there a way to know when speaking is finished?
    #	$self->patch('off');
    return $self->SUPER::speak(%p_phrase);

}

sub dtmf {
    my ( $self, $p_dtmf ) = @_;

    &Stargate::send_telephone($p_dtmf) if defined $p_dtmf;
    return $self->SUPER::dtmf($p_dtmf);
}

sub dtmf_sequence {
    my ( $self, $p_dtmf_seq ) = @_;

    &Stargate::send_telephone($p_dtmf_seq) if defined $p_dtmf_seq;
    return $self->SUPER::dtmf_sequence($p_dtmf_seq);
}

sub hook {
    my ( $self, $p_state ) = @_;

    if ( $p_state eq 'on' ) {
        &Stargate::send_telephone( $$self{serial_port}, '+' );
    }
    elsif ( defined $p_state ) {
        &Stargate::send_telephone( $$self{serial_port}, '^' );
    }
    return $self->SUPER::hook($p_state);
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateASCII>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#
# Item object version (this lets us use object links and events)
#
package StargateASCII;
@StargateASCII::ISA = ('Generic_Item');

sub new {
    my ( $class, $address, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my $self = { address => $address, serial_port => $serial_port };
    bless $self, $class;

    $self->set_casesensitive();

    push( @stargateascii_object_list, $self );

    return $self;
}

sub default_setrawstate {
    my ( $self, $state ) = @_;

    #&::print_log("SGascii class call $$self{line} $state");
    if ( length($state) + 1 != $self->{serial_port}->write( $state . "\r" ) ) {
        print "StargateAscii serial write command failed:$state\n";
        return -1;
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateVoicemail>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package StargateVoicemail;
@StargateVoicemail::ISA = ('Generic_Item');

sub new {
    my ( $class, $address, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my $self = { address => $address, serial_port => $serial_port };
    bless $self, $class;

    #    push(@stargatevariable_object_list, $self);

    return $self;
}

sub default_setstate {
    my ( $self, $state ) = @_;

    if ( $state < 0 or $state > 255 ) {
        print "StargateVoicemail invalid state:$state set (must be 0-255)\n";
        return -1;
    }

    my ($command) =
      "##%26" . sprintf( "%02x%02x01", $self->{address}, $state ) . "\r";
    if ( length($command) != $self->{serial_port}->write($command) ) {
        print "StargateVariable serial write command failed:$command\n";
        return -1;
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateIR>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#
# Item object version (this lets us use object links and events)
#

package StargateIR;
@StargateIR::ISA = ('Generic_Item');

sub new {
    my ( $class, $address, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object}
      if ( $serial_port == undef );

    my ($alternateplay);
    $alternateplay = 0;

    my ( $realaddress, $portmap ) = $address =~ /([0-9]{1,3}):([0-9]{1,2})/;
    $realaddress = $address if $realaddress == undef;
    $portmap = 0x0f if $portmap == 0 or $portmap == undef;

    my $self = {
        address       => $realaddress,
        serial_port   => $serial_port,
        alternateplay => $alternateplay,
        portmap       => $portmap
    };
    bless $self, $class;

    push( @stargateir_object_list, $self );
    return $self;
}

sub setstate_play {
    my ( $self, $substate ) = @_;

    # Handle play:repeatcount (e.g. play:10)
    my ($repeatcount) = $substate =~ /^([0-9]{1,3})/;
    $repeatcount = 1 if $repeatcount == undef;

    # ##%28 6c 0685 f5 ea 01 0 f 00. (bank 0 ea)
    # ##%28 6c 0685 f7 f5 01 0 f 00. (bank 1 f5-f8)
    # ##%28 6c 0685 f7 f6 01 0 f 00.
    # ##%28 6c 0685 f7 f7 01 0 f 00.
    # ##%28 6c 0685 f7 f8 01 0 f 00.
    # +++++ ad ???? mb ad ## A P CC
    # ad=address
    # ???=static
    # mb=memory bank (low f5 or high f7)
    # ad=address
    # ##=repeate count
    # A=alternate play
    # P=port (F=all)
    # CC=checksum (unused)
    my ( $memorybank, $address );
    if ( $self->{address} <= 256 ) {
        $memorybank = "f5";
        $address    = $self->{address} - 1;
    }
    else {
        $memorybank = "f7";
        $address    = $self->{address} - 256 - 1;
    }

    my ($command) =
        "##%286c0685"
      . $memorybank
      . sprintf(
        "%02x%02x%01x%01x",
        $address, $repeatcount, $self->{alternateplay},
        $self->{portmap}
      ) . "00\r";

    print "Stargate IR command:$command\n";

    if ( length($command) != $self->{serial_port}->write($command) ) {
        print "StargateIR serial write command failed:$command\n";
        return -1;
    }
}

sub default_setstate {
    my ( $self, $state ) = @_;
    print
      "StargateIR invalid state:$state set (must be play or play:repeatcount\n";
    return;
}
1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

