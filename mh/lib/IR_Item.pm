use strict;

package IR_Item;

@IR_Item::ISA = ('Generic_Item');

sub new {
    my ($class, $device, $code) = @_;
    my $self = {};
    $$self{state} = '';
    $device = 'TV' unless $device;
    $$self{device} = uc $device;
    $$self{code} = $code if $code;
    bless $self, $class;
    return $self;
}

my $device_prev;
sub set {
    my ($self, $state) = @_;

    &Generic_Item::set_states_for_next_pass($self, $state);

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

                                # Lead with another 0 for devices that require 3 digits.
    if ($$self{code} eq '3digit') {
        $state =~ s/^(\d\d),/0$1,/g;
        $state =~ s/,(\d\d),/,0$1,/g;
        $state =~ s/,(\d\d)$/,0$1/g;
        $state =~ s/^(\d\d)$/0$1/g;
    }
                                # Put commas between all digits, so they are seperate commands
    $state =~ s/(\d)(?=\d)/$1,/g;
                                # Record must be pressed twice??
    $state =~ s/RECORD/RECORD,RECORD/g;
                                # Add delay after powering up
    $state =~ s/POWER,/POWER,PAUSE,/g;

    print "Sending IR_Item command $device $state\n";
    for my $command (split(',', $state)) {
        $command  = 'POWER'     if $command eq 'ON';
        $command  = 'POWER'     if $command eq 'OFF';
                                # This seems to be built into the ir commander
                                #  - hmmm, PAUSE causes my VCR to play :(   Lets build our own pause
        if ($command eq 'PAUSE') {
            select undef, undef, undef, 0.3; # Give it a chance to get going before doing other commands
            next;
        }
        &ControlX10::CM17::send_ir($main::Serial_Ports{cm17}{object}, "$device $command");
        $device = '';           # Use device only on the first command
    }
}

#
# $Log$
# Revision 1.3  2000/06/24 22:10:54  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.2  2000/05/06 16:34:32  winter
# - 2.15 release
#
# Revision 1.1  2000/04/09 18:03:19  winter
# - 2.13 release
#
#

1;
