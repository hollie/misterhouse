use strict;

package IR_Item;

my (@reset_states, @states_from_previous_pass);

sub new {
    my ($class, $device) = @_;
    my $self = {};
    $$self{state} = '';
    $device = 'TV' unless $device;
    $$self{device} = uc $device;
    bless $self, $class;
    return $self;
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

my $device_prev;
sub set {
    my ($self, $state) = @_;
    $self->{state_next_pass} = $state;
    push(@states_from_previous_pass, $self);
    unshift(@{$$self{state_log}}, "$main::Time_Date $state");
    pop @{$$self{state_log}} if @{$$self{state_log}} > $main::config_parms{max_state_log_entries};

                                # Since the X10 IR Commander is a bit slow (.5 sec per xmit),
                                #  lets only send the device code if it is different than last time.
    my $device = $$self{device};
    $device = '' if $device eq $device_prev;
    $device_prev = $$self{device};

    $state = uc $state;

                                # Always lead single digit with a 0.  Cover all 4 cases:
                                #  1,record    stop,2   stop,3,record     4
    $state =~ s/^(\d),/0$1,/g;
    $state =~ s/,(\d),/,0$1,/g;
    $state =~ s/,(\d)$/,0$1/g;
    $state =~ s/^(\d)$/0$1/g;
                                # Put commas between all digits, so they are seperate commands
    $state =~ s/(\d)(?=\d)/$1,/g;
                                # Record must be pressed twice??
    $state =~ s/RECORD/RECORD,RECORD/g;


    print "Sending IR_Item command $device $state\n";
    for my $command (split(',', $state)) {
        $command  = 'POWER'     if $command eq 'ON';
        $command  = 'POWER'     if $command eq 'OFF';
        &ControlX10::CM17::send_ir($main::Serial_Ports{cm17}{object}, "$device $command");
        $device = '';           # Use device only on the first command
    }
}

sub reset_states {
    my $ref;
    while ($ref = shift @reset_states) {
        undef $ref->{state_now};
    }

    while ($ref = shift @states_from_previous_pass) {
        $ref->{state}     = $ref->{state_next_pass};
        $ref->{state_now} = $ref->{state_next_pass};
        undef $ref->{state_next_pass};
        push(@reset_states, $ref);
    }
}


#
# $Log$
# Revision 1.1  2000/04/09 18:03:19  winter
# - 2.13 release
#
#

1;
