#
# From Misterhouse HomeBase.pm
#

#            I/ODevice         Offset
#
#    TimeCommander-Plus         0x00    1-16
#    reserved                   0x01
#    IO Xpander -1              0x02    17-32
#    IO Xpander -2              0x03    33-48
#    IO Xpander -3              0x04    49-64
#    IO Xpander -4              0x05    65-80
#
#    DI Xpander-1               0x06
#    DI Xpander-2               0x07
#    DI Xpander-3               0x08
#    DI Xpander-4               0x09
#
#    RO Xpander-1               0x0a
#    RO Xpander-2               0x0b
#    RO Xpander-3               0x0c
#    RO Xpander-4               0x0d 


use strict;

my (@stargatedigitalinput_object_list, @stargatevariable_object_list, @stargateflag_object_list, @stargaterelay_object_list);
my (@stargatethermostat_object_list, @stargatetelephone_object_list, @stargateascii_object_list);

package Stargate;

my $temp;

#
# This code create the serial port and registers the callbacks we need
#
sub serial_startup
{
    if ($::config_parms{Stargate_serial_port}) 
    {
        my($speed) = $::config_parms{Stargate_baudrate} || 9600;
        if (&::serial_port_create('Stargate', $::config_parms{Stargate_serial_port}, $speed, 'none')) 
        {
            init($::Serial_Ports{Stargate}{object}); 
            &::MainLoop_pre_add_hook( \&Stargate::UserCodePreHook,   1);
            &::MainLoop_post_add_hook( \&Stargate::UserCodePostHook, 1 );
        }
    }
}

my $serial_data;                # Holds left over serial data
my $last_variable_load;         # Holds first part of two message variable load data
my $last_thermostat_address;    # Holds first part of two message thermostat command
my $last_caller_id;
my $Last_Upload_Timer;
my $Last_Upload_Variable;
my @Thermostat_Upload_List;     # We use this to match thermostat uploads to the correct zone

my (@stargate_command_list, $transmitok);

sub init 
{
    my ($serial_port) = @_;
    # Echo off
    #$serial_port->write("##%1c\r");

    # Set to echo mode, so we can monitor events
    print "Sending Stargate echo init string\n";
    print "Bad Stargate init echo command transmition\n" unless 6 == $serial_port->write("##%1d\r");

    # Set default values
    $last_variable_load = undef;
    $Last_Upload_Timer = $Last_Upload_Variable = 0;

    $transmitok = 1;
}

sub UserCodePreHook
{
    if(($::Startup) or ($::DelayOccured > 60))
    {
        RequestVariableUpload();
        RequestThermostatUpload();
        return;
    }

    if ($::New_Minute and !($::Minute % 5)) 
    {
        RequestThermostatUpload();
        return;
    }

    if($::New_Msecond_100)
    {
        my ($serial_port) = $::Serial_Ports{Stargate}{object};
	my $parse_packet=0;
        #my %table_iounit = qw(0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 a 10 b 11 c 12 d 13 e 14 f 15);

        #    my %table_echocommands = qw (0 0x00 2 0x02 3 0x03 4 0x04 5 0x05 8 0x08 a 0x0a c 0x0c);

        my ($data);
        if ($data = $serial_port->input) 
        {
#		print "SG:>$data<\n";
            $data =~ s/[\r\n]/\t/g;
            print "db Stargate serial data1=$data...\n" if lc($main::config_parms{debug}) eq 'stargate';

            $serial_data .= $data;
            print "db Stargate serial data2=$serial_data...\n" if lc($main::config_parms{debug}) eq 'stargate';
            my ($record, $remainder);
            while (($record, $remainder) = $serial_data =~ /(\S.+?)\t+(.*)/s) 
            {
		$parse_packet=1;
                $serial_data = $remainder; # Might have part of the next record left over

                print "db Stargate serial data3=$record remainder=$remainder.\n" if lc($main::config_parms{debug}) eq 'stargate';
                print "db Stargate serial data3=$record\n" if lc($main::config_parms{debug}) eq 'stargate';

                #print "Stargate serial1=$record\n" unless $record =~ /(\!\!\d\d\/.*)/;

                ParseTimerUpload($1) if $record =~ /(^[\d|A|B|C|D|E|F]{4})\z/i;
                next if $record =~ /(^[\d|A|B|C|D|E|F]{4})\z/i;
                $Last_Upload_Timer = 0;

                ParseVariableUpload($1) if $record =~ /(^[\d|A|B|C|D|E|F]{2})\z/i;
                next if $record =~ /(^[\d|A|B|C|D|E|F]{2})\z/i;
                $Last_Upload_Variable = 0;

                ParseEchoCommand($1) if $record =~ /(\!\!\d\d\/.*)/;
                next if $record =~ /(\!\!\d\d\/.*)/;

                ParseCallerId($1) if $last_caller_id and $record =~ /(^\d{7,10}.*)/;
                # When we get here it's time to clear the caller id flag
                $last_caller_id = 0;
                next if $record =~ /(^\d{7,10}.*)/;
                
                ParseThermostatUpload($1) if $record =~ /\#\#5f([\d|A|B|C|D|E|F]{8})\z/i;
                next if $record =~ /\#\#5f([\d|A|B|C|D|E|F]{8})\z/i;

                # Ignore any responses to our commands
                next if $record eq "##0";
                next if $record eq "##1";

		ParseASCII($record);
                print "Unknown Stargate response:$record\n";
            }
		if ($parse_packet==0)
		{
			print "SG Didnt fit the regexp\n";
        	}
		$parse_packet=0;
            }
        # If we do not do this, we may get endless error messages.
        else 
        {
            $serial_port->reset_error;
        }
    }

    if($::New_Msecond_250 && @stargate_command_list > 0 && $transmitok)
    {
        if($::Serial_Ports{Stargate}{object})
        {
            #while(@stargate_command_list > 0)
            #{
            my ($port) = shift @stargate_command_list;
            my ($output) = shift @stargate_command_list;
            print "Stargate send: " .$output . "\n" if lc($main::config_parms{debug}) eq 'stargate';
            $::Serial_Ports{Stargate}{object}->write("##%a5" . $port . $output . "\r");
            #}
        }
    }

    return;
}

sub UserCodePostHook
{
}

sub RequestVariableUpload
{
    $::Serial_Ports{Stargate}{object}->write("##%12\r");
}

sub RequestThermostatUpload
{
    for my $current_object (@stargatethermostat_object_list) 
    {
        my $data = "##%5f" . sprintf("%02x", $current_object->{address}-1) . "00\r";
        if($::Serial_Ports{Stargate}{object}->write($data) == length($data))
        {
            push(@Thermostat_Upload_List,$current_object->{address}-1);
            push(@Thermostat_Upload_List,time);
        }
    }
    return;
}

sub ParseEchoCommand
{
    my ($data) = @_;

    my %table_hcodes = qw(6  A 7  B 4  C 5  D 8  E 9  F a  G b H
                          e  I f  J c  K d  L 0  M 1  N 2  O 3 P);
    my %table_dcodes = qw(06  1 07  2 04  3 05  4 08  5 09  6 0a  7 0b 8
                          0e  9 0f  A 0c  B 0d  C 00  D 01  E 02  F 03 B
                          14  J 1c  K 12  L 1a M
                          10 ALL_OFF 18 ALL_ON
                          16 ALL_OFF_LIGHTS);

    $data = substr($data, 13);

    #           print "Stargate record=$record data=$data Hex=" . unpack('H*', $record) . "\n" if lc($main::config_parms{debug}) eq 'wes';
    print "db data4=$data\n" if lc($main::config_parms{debug}) eq 'stargate';

    my @bytes = split //, $data;
    my $command = hex $bytes[0];
    my $subcommand = hex $bytes[1];
    my $commanddata = hex $bytes[2].$bytes[3];

#	print "SG Command: $command: $subcommand : $commanddata \n"
    # First check for X10 data
    if($command == 0x00)
    {
        #return undef unless $bytes[0] eq '0'; # Only look at x10 data for now
        next unless $bytes[1] eq '0' or $bytes[1] eq '1'; # Only look at receive data for now
        # Disable using the Stargate for X10 receive if so configured.  I am using the CM11a and just use
        # the stargate for I/O and phone control (bsobel@vipmail.com)
        next if $main::config_parms{Stargate_DisableX10Receive};
	
        my ($house, $device);
        unless ($house = $table_hcodes{lc($bytes[3])}) 
        {
            print "Error, not a valid Stargate house code: $bytes[3]\n";
            next;
        }
        my $code = $bytes[1] . $bytes[2];
        unless ($device = $table_dcodes{lc($code)}) 
        {
            print "Error, not a valid Stargate device code: $code\n";
            next;
        }
        else 
        {
            my $data = $house . $device;
            print "Stargate X10 receive:$data\n" if lc($main::config_parms{debug}) eq 'stargate';
            &main::process_serial_data("X" . $data);
            next;
        }
    }
    # Next check for digital IO input
    elsif(($command == 0x0a) or ($command eq 0x0c))
    {
        my $code = $bytes[0] . $bytes[1];
        my $unitstates = hex $bytes[2].$bytes[3];
        ParseDigitalInputData($code, $unitstates);

    }
    # Next check for phone state changes
    elsif($command == 0x01)
    {
#	print "TELE>$rawdata<\n";
        my $data = hex $bytes[2].$bytes[3];
        ParseTelephoneData($subcommand, $commanddata);
    }
    # Next check for timer state changes
    elsif($command == 0x02)
    {
        #ParseTimerData($subcommand, $commanddata);
    }
    # Next check for flag state changes
    elsif($command == 0x03)
    {
#	print "SG Flag $subcommand: $commanddata";
        ParseFlagData($subcommand, $commanddata);
    }
    # Next check for variable state changes
    elsif($command == 0x04)
    {
        ParseVariableData($subcommand, $commanddata);
    }
    # Next check for relay state changes
    elsif($command == 0x05)
    {
        my $code = $bytes[0] . $bytes[1];
        my $unitstates = hex $bytes[2].$bytes[3];
        ParseRelayData($code, $unitstates);
    }
    # Check for thermostat state changes (part 1)
    elsif($command == 0x0d)
    {
        if($subcommand == 0x00)
        {
            $last_thermostat_address = $commanddata;
        }
        else
        {
            print "Stargate Echo unknown thermostat command $data\n";
        }
    }
    # Check for thermostat state changes (part 2)
    elsif($command == 0x0b)
    {
        ParseThermostatData($last_thermostat_address, $subcommand, $commanddata);
    }
    else
    {
        print "$::Time_Now Unknown echo command:$data\n";
    }
}

sub ParseDigitalInputData
{
    my ($code, $unitstates) = @_;

    my %table_iobase = qw(a0 1 c0 2 a2 3 c2 4 a3 5 c3 6 a4 7 c4 8);

    my $base;
    unless ($base = $table_iobase{lc($code)}) 
    {
        print "$::Time_Now Error, not a valid Stargate IO base: $code\n";
        return;
    }

    SetDigitalInputState($base, $unitstates);
}

sub SetDigitalInputState
{
    my ($base, $unitstates) = @_;

    for my $current_object (@stargatedigitalinput_object_list) 
    {
        print $current_object->{address} . " base=$base t1=" . ($base - 1) * 8 . " t2=" . ($base * 8) . "\n" if lc($main::config_parms{debug}) eq 'stargate';
        # Make sure the item is within the range of 8 status bits returned, skip if not
        next unless ($current_object->{address} > (($base-1) * 8)) and ($current_object->{address} <= ($base * 8));

        my $unitbit = 1 << ($current_object->{address}-1);

        my $newstate;
	if ($current_object->invert() == 1)
	{
	        $newstate = "on" if $current_object->state ne 'on' and !($unitstates & $unitbit);
		$newstate = "off" if $current_object->state ne 'off' and ($unitstates & $unitbit);
	}
	else
	{
	        $newstate = "on" if $current_object->state ne 'on' and ($unitstates & $unitbit);
 		$newstate = "off" if $current_object->state ne 'off' and !($unitstates & $unitbit);
	}
        print "Stargate Digitial Input #" . $current_object->{address} . " state change to $newstate\n" if $newstate;
        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }
}

sub ParseTelephoneData
{
    my ($subcommand, $data) = @_;
	#print "Parse HERE!$subcommand:$data\n";	

    if ($subcommand eq 15) #VoiceMail Notification ????
    {
	if($data <= 38 )
	{
	   SetTelephoneState('CO','new message');
	   SetTelephoneState('ICM','new message');
	}
    }
    if($subcommand eq 0x05) #ICM DTMF
    {
        if($data <= 0x09)
        {
            SetTelephoneState('ICM',"$data");
        }
        elsif($data eq 0x0b)
        {
            SetTelephoneState('ICM',"*");
        }
        elsif($data eq 0x0c)
        {
            SetTelephoneState('ICM',"#");
        }
    }
    if($subcommand eq 0x06) #CO DTMF
    {
        if($data <= 0x09)
        {
            SetTelephoneState('CO',"$data");
        }
        elsif($data eq 0x0b)
        {
            SetTelephoneState('CO',"*");
        }
        elsif($data eq 0x0c)
        {
            SetTelephoneState('CO',"#");
        }
    }
    elsif($subcommand eq 0x01) #ICM Hookstate
    {
	if($data eq 0x12)
	{
		SetTelephoneState("ICM","offhook");
	}
	elsif($data eq 0x13)
	{
		SetTelephoneState("ICM","onhook");
	}
    }
    elsif($subcommand eq 0x02) #CO Hookstate
    {
        if($data eq 0x10)
        {
            SetTelephoneState('CO',"offhook");
        }
        elsif($data eq 0x11)
        {
            SetTelephoneState('CO',"onhook");
        }
        elsif($data >= 0x40)
        {
            SetTelephoneState('CO',"ring:".($data - 0x40));
        }
        else
        {
            print "Stargate Telephone unknown subcommand:$subcommand data:$data\n";
        }
    }
    elsif($subcommand eq 0x0f)
    {
        if($data eq 0x33)
        {
            $last_caller_id = 1;
        }
        else
        {
            print "Stargate Telephone unknown subcommand:$subcommand data:$data\n";
        }
    }
    else
    {
        ;
    }

}

sub ParseCallerId
{
    my ($data) = @_;

    print "Stargate CallerId=$data\n";
    SetTelephoneState('CO',"callerid::" . $data);
}

sub SetTelephoneState
{
    my ($address, $state) = @_;
#    print "SetTelephoneState called with state=$line,$state\n";

    for my $current_object (@stargatetelephone_object_list) 
    {
	next unless lc $current_object->{address} eq lc $address;
#        next unless $current_object->{address} == $address;

	$current_object->set($state);
        my $newstate;
        $newstate = $state if $current_object->state ne $state;

#        print "Stargate Telephone #" . $current_object->{address} . " state change to $newstate\n"
#        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }

}
sub ParseASCII
{
	my ($data) = @_;

	SetASCIIState('COM1',$data);

}

sub SetASCIIState
{
	my ($address,$state) = @_;
#    print "SetTelephoneState called with state=$line,$state\n";

    for my $current_object (@stargateascii_object_list)
    {
#	next unless lc $current_object->{line} eq lc $line;
        next unless $current_object->{address} == $address;

	$current_object->set($state);
        my $newstate;
        $newstate = $state if $current_object->state ne $state;

#        print "Stargate Telephone #" . $current_object->{line} . " state change to $newstate\n"
#        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }
}

sub ParseFlagData
{
    my ($subcommand, $data) = @_;

    if($subcommand eq 0x00)
    {
        SetFlagState($data, 'clear');
    }
    # Is this a load command?
    elsif($subcommand eq 0x01)
    {
        SetFlagState($data, 'set');
    }
}

sub SetFlagState
{
    my ($address, $state) = @_;

    for my $current_object (@stargateflag_object_list) 
    {
        next unless $current_object->{address} == $address;

        my $newstate;
        $newstate = $state if $current_object->state ne $state;

        print "Stargate Flag #" . $current_object->{address} . " state change to $newstate\n" if $newstate;
        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }
}

sub ParseVariableData
{
    my ($subcommand, $data) = @_;

    if($subcommand eq 0x00)
    {
        # Store off read value;
        $last_variable_load = $data;
    }
    # Is this a load command?
    elsif($subcommand eq 0x01)
    {
        # Use stored value here
        SetVariableState($data,$last_variable_load);
    }
    # Is this a clear command?
    elsif($subcommand eq 0x02)
    {
        SetVariableState($data,0);
    }
    # Is this an increment command?
    elsif($subcommand eq 0x03)
    {
        SetVariableState($data,$last_variable_load);
    }
    # Is this a decrement command?
    elsif($subcommand eq 0x04)
    {
        SetVariableState($data,$last_variable_load);
    }
}

sub SetVariableState
{
    my ($address, $state) = @_;

    for my $current_object (@stargatevariable_object_list) 
    {
        next unless $current_object->{address} == $address;
        
        my $newstate;
        $newstate = $state if $current_object->state() ne $state;

        print "Stargate Variable #" . $current_object->{address} . " state change to $newstate\n" if $newstate ne undef;
        $current_object->set_states_for_next_pass($newstate) if $newstate ne undef;
    }
}

sub ParseRelayData
{
    my ($code, $unitstates) = @_;

    my %table_iobase = qw(50 1 52 2 53 3 54 4);

    my $base;
    unless ($base = $table_iobase{lc($code)}) 
    {
        print "$::Time_Now Error, not a valid Stargate IO base: $code\n";
        return;
    }

    SetRelayState($base, $unitstates);
}

sub SetRelayState
{
    my ($base, $unitstates) = @_;

    for my $current_object (@stargaterelay_object_list) 
    {
        print $current_object->{address} . " base=$base t1=" . ($base - 1) * 8 . " t2=" . ($base * 8) . "\n" if lc($main::config_parms{debug}) eq 'stargate';
        # Make sure the item is within the range of 8 status bits returned, skip if not
        next unless ($current_object->{address} > (($base-1) * 8)) and ($current_object->{address} <= ($base * 8));

        my $unitbit = 1 << ($current_object->{address}-1);

        my $newstate;
        $newstate = "on" if $current_object->state ne 'on' and ($unitstates & $unitbit);
        $newstate = "off" if $current_object->state ne 'off' and !($unitstates & $unitbit);

        print "Stargate Relay #" . $current_object->{address} . " state change to $newstate\n" if $newstate;
        $current_object->set_states_for_next_pass($newstate) if $newstate;
    }
}

sub ParseThermostatData
{
    my ($address, $subcommand, $data) = @_;

    # Temperature change
    if($subcommand eq 0x00)
    {
        SetThermostatState($address, "temp", $data);
    }
    # Setpoint change
    elsif($subcommand eq 0x01)
    {
        SetThermostatState($address, "setpoint", $data);
    }
    elsif($subcommand eq 0x03)
    {
        if($data eq 0x00)
        {
            SetThermostatState($address, "systemmode", "off");
        }
        elsif($data eq 0x01)
        {
            SetThermostatState($address, "systemmode", "heat");
        }
        elsif($data eq 0x02)
        {
            SetThermostatState($address, "systemmode", "cool");
        }
        elsif($data eq 0x03)
        {
            SetThermostatState($address, "systemmode", "auto");
        }
        else
        {
            print "Stargate Thermostat unknown state command: $data\n";
        }
    }
    elsif($subcommand eq 0x04)
    {
        if($data eq 0x00)
        {
            SetThermostatState($address, "fanmode", "off");
        }
        elsif($data eq 0x01)
        {
            SetThermostatState($address, "fanmode", "on");
        }
        else
        {
            print "Stargate Thermostat unknown fan command: $data\n";
        }
    }
    elsif($subcommand eq 0x06)
    {
        # This error message isn't prefaced with another message indicating the unit #, it's included
        # as the data to this message.
        print "Stargate Thermostat #$data polling error\n";
    }
    else
    {
        print "Stargate Thermostat #$address subcommand:$subcommand data=$data\n";
    }
}

sub SetThermostatState
{
    my ($address, $state, $statedata) = @_;

    for my $current_object (@stargatethermostat_object_list) 
    {
        next unless $current_object->{address}-1 == $address;

        # Since we handle substates in this item, check if the substate has changed or not
        my $newstate;
        $newstate = $state if $current_object->{$state} ne $statedata;

        print "Stargate Thermostat #" . $current_object->{address} . " state change to $newstate:$statedata\n" if $newstate;
        $current_object->set_states_for_next_pass($newstate) if $newstate;
        $current_object->set_states_for_next_pass($newstate.":".$statedata) if $newstate;
        # Set the subitem state so we can check for changes later (and respond to state() requests)
        $current_object->{$state} = $statedata if $newstate;
    }
}

sub ParseTimerUpload
{
    my ($data) = @_;
    print "Timer upload command data=$data\n";
}

sub ParseVariableUpload
{
    my ($data) = @_;
    print "Variable #" . $Last_Upload_Variable . " upload command data=$data\n";

    SetVariableState($Last_Upload_Variable++,hex($data));
}

sub ParseThermostatUpload
{
    my ($data) = @_;

    # Ignore the data unless we requested it (it would mean we are out of sync)
    return unless @Thermostat_Upload_List > 0;

    my ($address) = shift @Thermostat_Upload_List;
    my ($requesttime) = shift @Thermostat_Upload_List;

    my ($timediff) = time - $requesttime;

    # If the thermostat uploads got out of sync (somehow), reset and try again
    if($timediff > 30)
    {
        print "Stargate Thermostat out of sync data=$data timediff=$timediff Trying again\n" if lc($main::config_parms{debug}) eq 'stargate';
        undef @Thermostat_Upload_List;
        RequestThermostatUpload();
        return;
    }

    print "Thermostat upload command for address:$address data=$data\n";
    
    ParseThermostatData($address, 0x00, hex substr($data,0,2));
    ParseThermostatData($address, 0x01, hex substr($data,2,2));
    ParseThermostatData($address, 0x03, hex substr($data,4,2));
    ParseThermostatData($address, 0x04, hex substr($data,6,2));
}

#
# Below are externally callable functions
#

sub send_command
{
    my ($serial_port, $port, $command) = @_;
    if($port =~ /com1/i)
    {
        $port = "01";
    }
    elsif($port =~ /com2/i)
    {
        $port = "01";
    }
    elsif($port =~ /com3/i)
    {
        $port = "01";
    }
    elsif($port =~ /rs485/i)
    {
        $port = "07";
    }
    else
    {
        print "Stargage send_command invalid port $port\n";
        return;
    }

    push(@stargate_command_list,$port);
    push(@stargate_command_list,$command);
 
    return;
}


sub read_time 
{
    my ($serial_port) = @_;
    print "Reading Stargate time\n";
    if (6 == ($temp = $serial_port->write("##%06\r"))) 
    {
        select undef, undef, undef, 100 / 1000; # Give it a chance to respond
        if (my $data = $serial_port->input) 
        {
            #print "Stargate time string: $data\n";
                                # Not sure about $second.  $wday looks like year, not 0-7??
            my ($year, $month, $mday, $wday, $hour, $minute, $second) = unpack("A2A2A2A2A2A2A2", $data);
            print "Stargate time:  $hour:$minute:$second $month/$mday/$year\n";
            return wantarray ? ($second, $minute, $hour, $mday, $month, $year, $wday) : " $hour:$minute:$second $month/$mday/$year";
        }
        else 
        {
            print "Stargate did not respond to read_time request\n";
            return 0;
        }
    }
    else 
    {
        print "Stargate bad write on read_time request: $temp\n";
        return 0;
    }
}

sub read_log 
{
    my ($serial_port) = @_;
    print "Reading Stargate log\n";
    if (6 == ($temp = $serial_port->write("##%15\r"))) 
    {
        select undef, undef, undef, 100 / 1000; # Give it a chance to respond
                                # May need to paste data together to find real line breaks
        my @log;
        my $buffer;

        # Read data in a buffer string
        while (my $data = $serial_port->input) 
        {
            $buffer .= $data;
            select undef, undef, undef, 100 / 1000; # Need more/less/any delay here???
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
    else 
    {
        print "Stargate bad write on read_log request: $temp\n";
        return 0
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


sub clear_log 
{
    my ($serial_port) = @_;
    #print "Clearing Stargate log\n";
    if (6 == $serial_port->write("##%16\r")) 
    {
        print "Stargate log cleared\n";
        return 1;
    }
    else 
    {
        print "Bad Stargate log reset\n";
        return 0;
    }
}

sub read_flags 
{
    my ($serial_port) = @_;
	$serial_port=$::Serial_Ports{Stargate}{object};
    print "Reading Stargate Flags\n";
    if (6 == ($temp = $serial_port->write("##%10\r"))) 
    {
        select undef, undef, undef, 100 / 1000; # Give it a chance to respond
                                # How may flags?? Best look for end of data character ... \n\n??
        my @flags;
        while (my $data = $serial_port->input) 
        {
            my ($header, $flags) = $data =~ /(\S+?)[\n\r]+(\S+)/;
            my $l = length $flags;
            $l /= 2;
            #print "Flag string has $l bits: $flags\n";
                                # There are 2 characters per flag
#           push(@flags, split('', $flags));
            while ($flags) 
            {
                push(@flags, substr($flags, 0, 2));
                $flags = substr($flags, 2);
            }
        }
        print "Stargate did not respond to read_flags request\n" unless defined @flags;
        return @flags;
    }
    else 
    {
        print "Stargate bad write on read_flags request: $temp\n";
    }
}

sub read_variables 
{
    my ($serial_port) = @_;
    print "Reading Stargate Variables\n";
    if (6 == ($temp = $serial_port->write("##%12\r"))) 
    {
        select undef, undef, undef, 100 / 1000; # Give it a chance to respond
                                # May need to paste data together to find real line breaks
        my @vars;
        my $buffer;
        while (my $data = $serial_port->input) 
        {
            $buffer .= $data unless ( $data =~ /#/ ); # ##0 is end of list marker
            select undef, undef, undef, 100 / 1000; # Need more/less/any delay here???
        }
        @vars = split /\r\n/, $buffer;
        my $count = @vars;
        print "$count Stargate var records were read\n";
        print "Stargate did not respond to read_flags request\n" unless defined @vars;
        return @vars;
    }
    else 
    {
        print "Stargate bad write on read_variables request: $temp\n";
    }
}

# Set Time
# this command was decoded empirically from Starate/WinEVM interaction
# Homebase (Stargate) command is ##%05AAAALLLLTTSSYYMMDDRRHHMMCC
# AAAA = Latitude, LLLL = Longitude, TT=Timezone (05=EST)
# SS="Is daylight savings time used in your area?" (01=Yes)
# YY=Year, MM=Month, DD=Day, RR=DOW (Seems to be ignored, but set as
#       Th=01, Wen=02, Tu=04, Mo=08, Sun=10, Sat=20)
# CC=00 (Checksum? doesn't appear to be used)

sub set_time 
{
    my ($serial_port) = @_;
    my ($Second, $Minute, $Hour, $Mday, $Month, $Year, $Wday, $Yday, $isdst) = localtime time;
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
    if ($Year ge 100) 
    {
        $Year -= 100;
    }

    # Set daylight savings flag, this should be in mh.private.ini if your area uses DST
    $isdst = "00";                          # was 01
    #
    #print ("DST=$isdst Y=$Year M=$Month D=$Mday DOW=$Wday H=$Hour M=$Minute\n");
    my $set_time = sprintf("%04x%04x%02x%02x%02d%02d%02d%02d%02d%02d",
                           abs($main::config_parms{latitude}),
                           abs($main::config_parms{longitude}),
                           $main::config_parms{time_zone},
                           $isdst,
                           $Year,
                           $Month,
                           $Mday,
                           $Wday,
                           $Hour,
                           $Minute);
    #Checksum not required, so set it to 00
    #my $checksum = sprintf("%02x", unpack("%8C*", $set_time));
    my $checksum = "00";
    print "Stargate set_time=$set_time checksum=$checksum\n";

    if (32 == ($temp = $serial_port->write("##%05" . $set_time . $checksum . "\r"))) 
    {
        print "Stargate time has been updated to $localtime\n";
        return 1;
    }
    else 
    {
        print "Stargate bad write on set_time: $temp\n";
        return -1;
    }


}

sub send_X10 
{
    my ($serial_port, $house_code) = @_;
    print "\ndb sending Stargate x10 code: $house_code\n" if lc($main::config_parms{debug}) eq 'stargate';

    my ($house, $code) = $house_code =~ /(\S)(\S+)/;
    $house = uc($house);
    $code  = uc($code);

    my %table_hcodes = qw(A 6  B 7  C 4  D 5  E 8  F 9  G a  H b
                          I e  J f  K c  L d  M 0  N 1  O 2  P 3);
    my %table_dcodes = qw(1 06  2 07  3 04  4 05  5 08  6 09  7 0a  8 0b
                          9 0e  A 0f  B 0c  C 0d  D 00  E 01  F 02  G 03
                          J 14  K 1c  L 12  M 1a
                          ON 14  OFF 1c  BRIGHT 12  DIM 1a
                          ALL_OFF 10  ALL_ON 18
                          ALL_OFF_LIGHTS 16);


    my ($house_bits, $code_bits, $function, $header);

    unless ($house_bits = $table_hcodes{uc($house)}) 
    {
        print "Error, invalid Stargate X10 house code: $house\n";
        return;
    }

    unless ($code_bits = $table_dcodes{uc($code)}) 
    {
        print "Error, invalid Stargate x10 code: $code\n";
        return;
    }

    $header  = "##%040" . $code_bits . $house_bits;
    print "db Stargate x10 command sent: $header\n" if lc($main::config_parms{debug}) eq 'stargate';

    my $sent = $serial_port->write($header . "\r");
    print "Bad Stargate X10 transmition sent=$sent\n" unless 10 == $sent;
}

# Valid digitis 0-9, * # 
# OnHook = +
# OffHook = ^
# Pause = ,
# CallerID C
# HookFlash !
sub send_telephone 
{
    my ($serial_port, $phonedata) = @_;
    print "\ndb sending Stargate telephone command: $phonedata\n" if lc($main::config_parms{debug}) eq 'stargate';

    $phonedata = "##%57<" . $phonedata . ">";
    print "db Stargate telephone command sent: $phonedata\n" if lc($main::config_parms{debug}) eq 'stargate';

    my $sent = $serial_port->write($phonedata . "\r");
    print "Bad Stargate telephone transmition sent=$sent\n" unless $sent > 0;
}


1;           # for require



#
# Item object version (this lets us use object links and events)
#

package StargateDigitalInput;
@StargateDigitalInput::ISA = ('Generic_Item');
my $m_inverted;

sub new 
{
    my ($class, $address, $serial_port) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object} if ($serial_port == undef);

    my $self = {address => $address, serial_port => $serial_port};
    bless $self, $class;

    push(@stargatedigitalinput_object_list, $self);

    return $self;
}

sub set 
{
    print "Stargate Digital Inputs can not be set\n";
}
sub invert
{
	my ($class, $p_invert) = @_;
	if (defined $p_invert) 
	{
		$class->{m_inverted} = $p_invert; 
	}
	return $class->{m_inverted};
}
1;



#
# Item object version (this lets us use object links and events)
#
package StargateVariable;
@StargateVariable::ISA = ('Generic_Item');

sub new 
{
    my ($class, $address, $serial_port) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object} if ($serial_port == undef);

    my $self = {address => $address, serial_port => $serial_port};
    bless $self, $class;

    push(@stargatevariable_object_list, $self);

    return $self;
}

sub set 
{
    my ($self, $state) = @_;
    
    if($state < 0 or $state > 255)
    {
        print "StargateVariable invalid state:$state set (must be 0-255)\n";
        return;
    }

    # The Stargate scripts supports:
    # Load
    # Clear
    # Increment
    # Decrement
    #
    # Our set will only handle a specific value for now (e.g. do a load)

    my ($command) = "##%26" . sprintf("%02x%02x01", $self->{address}, $state) . "\r";
    
    #print "Stargate variable command:$command\n";

    if (length($command) == $self->{serial_port}->write($command))
    {
        $self->set_states_for_next_pass($state);
        return 1;
    }
    else 
    {
        print "StargateVariable serial write command failed:$command\n";
        return 0;
    }
}

1;



#
# Item object version (this lets us use object links and events)
#
package StargateFlag;
@StargateFlag::ISA = ('Generic_Item');

sub new 
{
    my ($class, $address, $serial_port) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object} if ($serial_port == undef);

    my $self = {address => $address, serial_port => $serial_port};
    bless $self, $class;

    push(@stargateflag_object_list, $self);

    return $self;
}

sub set 
{
    my ($self, $state) = @_;
    
    $state = lc($state);
    $state = "set" if $state eq "on" or $state eq "1";
    $state = "clear" if $state eq "off" or $state eq "0";

    if($state ne "set" and $state ne "clear")
    {
        print "StargateFlag invalid state:$state set (set|on|1 or clear|off|0)\n";
        return;
    }

    my ($command) = "##%25" . sprintf("%02x%02x", $self->{address}, $state eq "set" ? 1 : 0) . "\r";
    
    #print "Stargate flag command:$command\n";

    if (length($command) == $self->{serial_port}->write($command))
    {
        $self->set_states_for_next_pass($state);
        return 1;
    }
    else 
    {
        print "StargateFlag serial write command failed:$command\n";
        return 0;
    }
}

1;



#
# Item object version (this lets us use object links and events)
#
package StargateRelay;
@StargateRelay::ISA = ('Generic_Item');

sub new 
{
    my ($class, $address, $serial_port) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object} if ($serial_port == undef);

    my $self = {address => $address, serial_port => $serial_port};
    bless $self, $class;

    push(@stargaterelay_object_list, $self);

    return $self;
}

sub set 
{
    my ($self, $state) = @_;
	my %l_address = qw ( 1 1  2 2  3 4  4 8  5 16  6 32  7 64  8 128 );

    $state = lc($state);
    $state = "set" if $state eq "on" or $state eq "1";
    $state = "clear" if $state eq "off" or $state eq "0";

    if($state ne "set" and $state ne "clear")
    {
        print "StargateRelay invalid state:$state set (set|on|1 or clear|off|0)\n";
        return;
    }

    # Set
    my ($command) = "##%330019" . sprintf("%02x%02x", 
	$l_address{$self->{address}}, 
	$state eq "set" ? $l_address{$self->{address}} : 0) . "\r";
	&main::print_log("Stargate relay:$command:");
    if (length($command) == $self->{serial_port}->write($command))
    {
        $self->set_states_for_next_pass($state);
        return 1;
    }
    else 
    {
        print "StargateFlag serial write command failed:$command\n";
        return 0;
    }
    # Clear
    return;
}

1;



#
# Item object version (this lets us use object links and events)
#
package StargateThermostat;
@StargateThermostat::ISA = ('Generic_Item');

sub new 
{
    my ($class, $address, $serial_port) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object} if ($serial_port == undef);

    my $self = {address => $address, serial_port => $serial_port};
    bless $self, $class;

    push(@stargatethermostat_object_list, $self);

    return $self;
}

sub set
{
    my ($self, $setstate) = @_;
    return undef if($self->{address} == 0);

    my ($device,$state) = $setstate =~ /\s*(\w+)\s*:*\s*(\w*)/;
    
    $self->SUPER::set($device);
    $self->SUPER::set($device . ":" . $state);

    SWITCH: for( $device )
    {
        # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
        /^setpoint/i        && do { return $self->SendTheromostatCommand(0x20, $state) };
        
        # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
        /^heatpoint/i       && do { return $self->SendTheromostatCommand(0x30, $state) if $self->{systemmode} eq 'heat' };
        # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
        /^coolpoint/i       && do { return $self->SendTheromostatCommand(0x30, $state) if $self->{systemmode} eq 'cool' };
        # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
        /^autopoint/i       && do { return $self->SendTheromostatCommand(0x30, $state) if $self->{systemmode} eq 'auto' };

        # Valid mode $state is 0/O for off 1/H for heat, 2/C for cool, and 3/A for auto (we add one to get to right command for the Stargate)
        /^systemmode/i      && do { return $self->SendTheromostatCommand(0x30, hex(1 + ReturnCommand($state))) };
        # Valid mode $state is 0 or 1 (we subtract from 6 to get to the 05 on and 06 auto commands)
        /^systemfanmode/i   && do { return $self->SendTheromostatCommand(0x30, hex(6 - ReturnCommand($state))) };
    }

    return undef;
}

sub state
{
    my ($self, $device) = @_;

    return $self->SUPER::state() unless defined $device;
    return undef if($self->{zone} == 0);

    SWITCH: for( $device )
    {
        /^address/i         && do { return $self->{address}};
#       /^zone/i            && do { return $self->{zone}};

        /^temp/i            && do { return $self->{temp}};
        /^temperature/i     && do { return $self->{temp}};
        /^setpoint/i        && do { return $self->{setpoint}};
        /^zonemode/i        && do { return ReturnString($self->{systemmode})};
        /^zonefanmode/i     && do { return ReturnString($self->{fanmode})};

#       /^heatingstage1/i   && do { return ReturnString($self->{heatingstage1})};
#       /^heatingstage2/i   && do { return ReturnString($self->{heatingstage2})};
#       /^coolingstage1/i   && do { return ReturnString($self->{coolingstage2})};
#       /^coolingstage2/i   && do { return ReturnString($self->{coolingstage2})};

#       /^fanstatus/i       && do { return ReturnString($self->{fanstatus})};
#       /^shortcycle/i      && do { return ReturnString($self->{shortcycle})};
#       /^scp/i             && do { return ReturnString($self->{shortcycle})};

        /^systemmode/i      && do { return ReturnString($self->{systemmode})};
        /^mode/i            && do { return ReturnString($self->{systemmode})};
        /^fanmode/          && do { return ReturnString($self->{fanmode})};
    }

    return undef;
}

sub ReturnCommand
{
    my ($data) = @_;

    SWITCH: for ( $data )
    {
        /on/i               && do { return "1"};   
        /1/                 && do { return "1"};   
        /0/                 && do { return "0"};   
        /off/i              && do { return "0"};   
        /h/i                && do { return "1"};
        /c/i                && do { return "2"};
        /a/i                && do { return "3"};
    }
    return undef;
}

sub SendTheromostatCommand
{
    my ($self, $command, $data) = @_;
    return undef unless defined $command;

    my $output = "##%5e" . sprintf("%02x%02x%02x\r", $self->{address}, $command, $data);
    $self->{serial_port}->write($output);
    return 1;
}

1;



#
# Item object version (this lets us use object links and events)
#
package StargateTelephone;
@StargateTelephone::ISA = ('Generic_Item');


sub new 
{
    my ($class, $address, $serial_port) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object} if ($serial_port == undef);

    my $self = {address => $address, serial_port => $serial_port};
    bless $self, $class;

    push(@stargatetelephone_object_list, $self);

    return $self;
}

sub set 
{
    my ($self, $state) = @_;
    # Set
    # Clear
#	&::print_log("SGTelephoneclass call $$self{line} $state");
        $self->set_states_for_next_pass($state);
    return;
}

1;

#
# Item object version (this lets us use object links and events)
#
package StargateASCII;
@StargateASCII::ISA = ('Generic_Item');


sub new 
{
    my ($class, $address, $serial_port) = @_;
    $serial_port = $::Serial_Ports{Stargate}{object} if ($serial_port == undef);

    my $self = {address => $address, serial_port => $serial_port};
    bless $self, $class;

    push(@stargateascii_object_list, $self);

    return $self;
}

sub set 
{
    my ($self, $state) = @_;
    # Set
    # Clear
#	&::print_log("SGascii class call $$self{line} $state");
        $self->set_states_for_next_pass($state);
    return;
}

1;

# For reference on dealing with bits/bytes/strings:
#
#print pack('B8', '01101011');   # -> k   To go from bit to string
#print unpack('C', 'k');         # -> 107 To go from string to decimal
#print   pack('C', 107);         # -> k   To go from decimal to srting
#printf("%0.2lx", 107);          # -> 6b  To go to decimal -> hex
#print hex('6b');                # -> 107 to go from hex -> decimal

# Examples:
# 0x5a -> 90  -> Z
# 0xa5 -> 165 -> ~N (tilde over N)
# 0xc3 -> 195 -> |-
# 0x3c -> 60 -> <

# Modified by Bob Steinbeiser 2/12/00
#


=pod
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

=cut
