use strict;

package Serial_Item;

my (%serial_item_by_id);
my (@reset_states, @states_from_previous_pass);

sub reset {
    undef %serial_item_by_id;   # Reset on code re-load
}

sub serial_item_by_id {
    my($id) = @_;
    return $serial_item_by_id{$id};
}

sub new {
    my ($class, $id, $state, $port_name) = @_;
    my $self = {};
    print "\n\nWarning: duplicate ID codes on different Serial_Item objects:\n " .
          "id=$id state=$state states=@{${$serial_item_by_id{$id}}{states}}\n\n" if $serial_item_by_id{$id};
    $$self{port_name} = $port_name;
    &add($self, $id, $state);
    bless $self, $class;
    $self->set_interface($port_name) if $id =~ /^X/;
    return $self;
}
sub add {
    my ($self, $id, $state) = @_;
    $$self{state_by_id}{$id} = $state if $id;
    $$self{id_by_state}{$state} = $id;           # Note: State is optional
    push(@{$$self{states}}, $state);
    $serial_item_by_id{$id} = $self if $id;
#    print "db sid=", %Serial_Item::serial_item_by_id, "\n";

}

sub is_started {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    return ($main::Serial_Ports{$port_name}{object}) ? 1 : 0;
}
sub is_stopped {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    return ($main::Serial_Ports{$port_name}{object}) ? 0 : 1;
}

                                # Try to do a 'new' ... object is not kept, even if new is sucessful
                                #   - not sure if there is a better way to test if a port is available
                                #     Hopefully this is not too wasteful
sub is_available {
    my ($self) = @_;

    my $port_name = $self->{port_name};
    my $port = $main::Serial_Ports{$port_name}{port};
    print "testing port $port ... ";

    my $sp_object;

                                # Use the 2nd parm of '1' to indicate this do a test open
                                #  - Modified Win32::SerialPort so it does not compilain if New/open fails
    if (( $main::OS_win and $sp_object = new Win32::SerialPort($port, 1))or 
        (!$main::OS_win and $sp_object = new Device::SerialPort($port))) {
        print " available\n";
        $sp_object->close;
        return 1;
    }
    else {
        print " not available\n";
        return 0;
    }
}

sub start {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    print "Starting port $port_name on port $main::Serial_Ports{$port_name}{port}\n";
    if ($main::Serial_Ports{$port_name}{object}) {
        print "Port $port_name is already started\n";
        return;
    }
    if ($port_name) {
        if (&main::serial_port_open($port_name)) {
            print "Port $port_name was re-opened\n";
        }
        else {
            print "Serial_Item start failed for port $port_name\n";
        }
    }
    else {
        print "Error in Serial_Item start:  no port name for object=$self\n";
    }
}

sub stop {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    my $sp_object = $main::Serial_Ports{$port_name}{object};
    if ($sp_object) {

        my $port = $main::Serial_Ports{$port_name}{port};
#       &Win32::SerialPort::debug(1);
        if ($sp_object->close) {
            print "Port $port_name on port $port was closed\n";
        }
        else {
            print "Serial_Item stop failed for port $port_name\n";
        }
                                # Delete the ports, even if it didn't close, so we can do 
                                # starts again without a 'port reuse' message.
        delete $main::Serial_Ports{$port_name}{object};
        delete $main::Serial_Ports{object_by_port}{$port};
#       &Win32::SerialPort::debug(0);
    }
    else {
        print "Error in Serial_Item stop for port $port_name: Port is not started\n";
    }
}

sub state {
    return @_[0]->{state};
} 

sub state_now {
    return @_[0]->{state_now};
}

sub state_log {
    my ($self) = @_;
    return @{$$self{state_log}} if $$self{state_log};
}


sub said {
    my $port_name = @_[0]->{port_name};
    my $datatype  = $main::Serial_Ports{$port_name}{datatype};
    
    if ($datatype eq 'raw') {
        if (my $data = $main::Serial_Ports{$port_name}{data}) {
            $main::Serial_Ports{$port_name}{data} = '';
            return $data;
        }
        else {
            return;
        }
    }
    else {
        if (my $data = $main::Serial_Ports{$port_name}{data_record}) {
            $main::Serial_Ports{$port_name}{data_record} = ''; # Maybe this should be reset in main loop??
            return $data;
        }
        else {
            return;
        }
    }
}

sub set_data {
    my ($self, $data) = @_;
    my $port_name = $self->{port_name};
    my $datatype  = $main::Serial_Ports{$port_name}{datatype};
    if ($datatype eq 'raw') {
        $main::Serial_Ports{$port_name}{data} = $data;
    }
    else {
        $main::Serial_Ports{$port_name}{data_record} = $data;
    }
}

sub set_receive {
    my ($self, $state) = @_;
                                # Only add to the list once per pass
    push(@states_from_previous_pass, $self) unless defined $self->{state_next_pass};
    $self->{state_next_pass} = $state;

    unshift(@{$$self{state_log}}, "$main::Time_Date $state");
    pop @{$$self{state_log}} if @{$$self{state_log}} > $main::config_parms{max_state_log_entries};

}

sub set_dtr {
    my ($self, $state) = @_;
    my $port_name = $self->{port_name};
    if (my $serial_port = $main::Serial_Ports{$port_name}{object}) {
        $main::Serial_Ports{$port_name}{object}->dtr_active($state);
        print "Serial_port $port_name dtr set to $state\n" if $main::config_parms{debug} eq 'serial';
    }
    else {
        print "Error, serial port set_dtr for $port_name failed, port has not been set\n";
    }
}
sub set_rts {
    my ($self, $state) = @_;
    my $port_name = $self->{port_name};
    if (my $serial_port = $main::Serial_Ports{$port_name}{object}) {
        $main::Serial_Ports{$port_name}{object}->rts_active($state);
        print "Serial_port $port_name rts set to $state\n" if $main::config_parms{debug} eq 'serial';
    }
    else {
        print "Error, serial port set_rts for $port_name failed, port has not been set\n";
    }
}


sub set {
    my ($self, $state) = @_;
                                # Only add to the list once per pass
    push(@states_from_previous_pass, $self) unless defined $self->{state_next_pass};
    $self->{state_next_pass} = $state;

    unshift(@{$$self{state_log}}, "$main::Time_Date $state");
    pop @{$$self{state_log}} if @{$$self{state_log}} > $main::config_parms{max_state_log_entries};

    return unless %main::Serial_Ports;

    my $serial_data;
    if (defined $self->{id_by_state}{$state}) {
        $serial_data = $self->{id_by_state}{$state};
    }
    else {
        $serial_data = $state;
    }


    my $port_name = $self->{port_name};

    print "Serial_Item: port=$port_name self=$self state=$state data=$serial_data interface=$$self{interface}\n" 
        if $main::config_parms{debug} eq 'serial';

    return if $main::Save{mode} eq 'offline';

    if ($$self{interface} eq 'cm11') {
                                # If code is &P##, prefix with item code.
        if (substr($serial_data, 0, 1) eq '&') {
            $serial_data = $self->{x10_id} . $serial_data;
        }
                                # Extended data will have & starting the function code
                                #  - e.g. XO7&P23 -> Device O7 to Preset Dim code 23
        if (substr($serial_data, 3, 1) eq '&') {
            &ControlX10::CM11::send($main::Serial_Ports{cm11}{object}, substr($serial_data, 1));
        }
                                # Normal data ... call once for the Unit code, once for the Function code
        else {
            &ControlX10::CM11::send($main::Serial_Ports{cm11}{object}, substr($serial_data, 1, 2));
            &ControlX10::CM11::send($main::Serial_Ports{cm11}{object}, substr($serial_data, 3)) if length($serial_data) > 3;
        }
    }
    elsif ($$self{interface} eq 'cm17') {
                                # cm17 wants XA1K, not XA1AK
        substr($serial_data, 3, 1) = '';
        &ControlX10::CM17::send($main::Serial_Ports{cm17}{object}, substr($serial_data, 1));
    }
    elsif ($$self{interface} eq 'homevision') {
        print "Using homevision to send: $serial_data\n";
        &Homevision::send($main::Serial_Ports{Homevision}{object}, $serial_data);
    }
    elsif ($$self{interface} eq 'homebase') {
        print "Using homebase to send: $serial_data\n";
        &HomeBase::send_X10($main::Serial_Ports{HomeBase}{object}, substr($serial_data, 1, 2));
        &HomeBase::send_X10($main::Serial_Ports{HomeBase}{object}, substr($serial_data, 3)) if length($serial_data) > 2;
    }
    else {
        $port_name = 'Homevision' if !$port_name and $main::Serial_Ports{Homevision}{object}; #Since it's multifunction, it should be default
        $port_name = 'weeder'  if !$port_name and $main::Serial_Ports{weeder}{object};
        $port_name = 'serial1' if !$port_name and $main::Serial_Ports{serial1}{object};
        $port_name = 'serial2' if !$port_name and $main::Serial_Ports{serial2}{object};
#       print "\$port_name is $port_name\n\$main::Serial_Ports{Homevision}{object} is $main::Serial_Ports{Homevision}{object}\n";
        unless ($port_name) {
            print "Error, serial set called, but no serial port found: data=$serial_data\n";
            return;
        }
        unless ($main::Serial_Ports{$port_name}{object}) {
            print "Error, serial port for $port_name has not been set: data=$serial_data\n";
            return;
        }
        
                                # Weeder table does not match what we defined in CM11,CM17,X10_Items.pm
                                #  - Dim -> L, Bright -> M,  AllOn -> I, AllOff -> H
        if ($port_name eq 'weeder' and
            my ($device, $house, $command) = $serial_data =~ /^X(\S\S)(\S)(\S+)/) {

                                # Allow for +-xx%
            my $dim_amount = 3;
            if ($command =~ /[\+\-]\d+/) {
                $dim_amount = int(10 * abs($command) / 100); # about 10 levels to 100%
                $command = ($command > 0) ? 'L' : 'M';
            }
                
            if ($command eq 'M') {
                $command =  'L' . (($house . 'L') x $dim_amount);
            }
            elsif ($command eq 'L') {
                $command =  'M' . (($house . 'M') x $dim_amount);
            }
            elsif ($command eq 'O') {
                $command =  'I';
            }
            elsif ($command eq 'P') {
                $command =  'H';
            }
            $serial_data = 'X' . $device . $house . $command;

				# Give weeder a chance to do the previous command
				# Surely there must be a better way!
	    select undef, undef, undef, 1.2;
        }

        if (lc($port_name) eq 'homevision') {
            &Homevision::send($main::Serial_Ports{Homevision}{object}, $serial_data);
        }
        else {
            my $datatype  = $main::Serial_Ports{$port_name}{datatype};
            $serial_data .= "\r" unless $datatype eq 'raw';
            my $results = $main::Serial_Ports{$port_name}{object}->write($serial_data);
            
            &main::print_log("serial port=$port_name out=$serial_data results=$results") if $main::config_parms{debug} eq 'serial';
        }
    }
}    

sub reset_states {
    my $ref;
    while ($ref = shift @reset_states) {
        undef $ref->{state_now};
    }

    while ($ref = shift @states_from_previous_pass) {
        $ref->{state}     = $ref->{state_next_pass};
                                # Ignore $Startup events
        $ref->{state_now} = $ref->{state_next_pass} unless $main::Loop_Count < 5;
#       $ref->{state_now} = $ref->{state_next_pass} unless $main::Time_Uptime_Seconds < 20;
        undef $ref->{state_next_pass};
        push(@reset_states, $ref);
    }
}

sub set_interface {
    my ($self, $interface) = @_;
                                # Set the default interface
    unless ($interface) {
        if ($main::Serial_Ports{cm11}{object}) {
            $interface = 'cm11';
        }
        elsif ($main::Serial_Ports{cm17}{object}) {
            $interface = 'cm17';
        }
        elsif ($main::Serial_Ports{Homevision}{object}) {
            $interface = 'homevision';
        }
        elsif ($main::Serial_Ports{HomeBase}{object}) {
            $interface = 'homebase';
        }
    }
    $$self{interface} = lc($interface) if $interface;
}

#
# $Log$
# Revision 1.33  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.32  2000/01/27 13:42:42  winter
# - update version number
#
# Revision 1.31  2000/01/19 13:23:29  winter
# - add yucky delay to Weeder X10 xmit
#
# Revision 1.30  2000/01/02 23:47:43  winter
# - add Device:: to as Serilport check.  Use 10, not 7, increments in weeder dim
#
# Revision 1.29  1999/12/09 03:00:21  winter
# - added Weeder bright/dim support
#
# Revision 1.28  1999/11/08 02:16:17  winter
# - Move X10 stuff to X10_Items.pm.  Fix close method
#
# Revision 1.27  1999/11/02 14:51:36  winter
# - delete port in any case in stop method
#
# Revision 1.26  1999/10/31 14:49:04  winter
# - added X10 &P## preset dim option and X10_Lamp item
#
# Revision 1.25  1999/10/27 12:42:27  winter
# - add delete to serial_ports_by_port in sub close
#
# Revision 1.24  1999/10/09 20:36:49  winter
# - add call to set_interface in first new method.  Change to ControlX10
#
# Revision 1.23  1999/10/02 22:41:10  winter
# - move interface stuff to set_interface, so we can use for x10_appliances also
#
# Revision 1.22  1999/09/27 03:16:32  winter
# - move cm11 to HomeAutomation dir
#
# Revision 1.21  1999/09/12 16:57:07  winter
# - point to new cm17 path
#
# Revision 1.20  1999/08/30 00:23:30  winter
# - add set_dtr set_rts.  Add check on loop_count
#
# Revision 1.19  1999/08/02 02:24:21  winter
# - Add STATUS state
#
# Revision 1.18  1999/06/27 20:12:09  winter
# - add CM17 support
#
# Revision 1.17  1999/06/20 22:32:43  winter
# - check for raw datatype on writes
#
# Revision 1.16  1999/04/29 12:25:20  winter
# - add House all on/off states
#
# Revision 1.15  1999/03/21 17:35:36  winter
# - add datatype raw
#
# Revision 1.14  1999/03/12 04:30:24  winter
# - add start, stop, and set_receive methods
#
# Revision 1.13  1999/02/16 02:06:57  winter
# - add homebase send errata
#
# Revision 1.12  1999/02/08 03:50:25  winter
# - re-enable serial writes!  Bug introduced in last install.
#
# Revision 1.11  1999/02/08 00:30:54  winter
# - make serial port prints depend on debug parm
#
# Revision 1.10  1999/01/30 19:55:45  winter
# - add more checks for blank objects, so we don't abend
#
# Revision 1.9  1999/01/23 16:23:43  winter
# - change the Serial_Port object to match Socket_Port format
#
# Revision 1.8  1999/01/13 14:11:03  winter
# - add some more debug records
#
# Revision 1.7  1999/01/07 01:55:40  winter
# - add 5% increments on X10_Item
#
# Revision 1.6  1998/12/10 14:34:19  winter
# - fix empty state case
#
# Revision 1.5  1998/12/07 14:33:27  winter
# - add dim level support.  Allow for arbitrary set commands.
#
# Revision 1.4  1998/11/15 22:04:26  winter
# - add support for generic serial ports
#
# Revision 1.3  1998/09/12 22:13:14  winter
# - added HomeBase call
#
# Revision 1.2  1998/08/29 20:46:36  winter
# - allow for cm11 interface
#
#

1;
