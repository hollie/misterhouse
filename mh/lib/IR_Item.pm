use strict;

package IR_Item;

@IR_Item::ISA = ('Generic_Item');

my %default_map = qw(
    ON  POWER
    OFF POWER
);

sub new {
    my ($class, $device, $code, $interface, $mapref) = @_;
    my $self = {};
    $$self{state} = '';
    $device = 'TV' unless $device;
    $$self{device} = uc $device;
    $$self{code} = $code if $code;
    $interface = 'CM17' unless $interface;
    $$self{interface} = $interface;
    $mapref = \%default_map unless $mapref;
    $$self{mapref} = $mapref;
    bless $self, $class;
    return $self;
}

my $device_prev;
sub set {
    my ($self, $state) = @_;

    print "db set=$state pass=$main::Loop_Count\n";

    return if &main::check_for_tied_filters($self, $state);
    &Generic_Item::set_states_for_next_pass($self, $state);

                                # Since the X10 IR Commander is a bit slow (.5 sec per xmit),
                                #  lets only send the device code if it is different than last time.
    my $device = $$self{device};
    $device = '' if $device and  $device eq $device_prev;
    $device_prev = $$self{device};

    $state = uc $state;

                                # Always lead single digit with a 0.  Cover all 4 cases:
                                #  1,record    stop,2   stop,3,record     4
    $state =~ s/^(\d),/0$1,/g;
    $state =~ s/,(\d),/,0$1,/g;
    $state =~ s/,(\d)$/,0$1/g;
    $state =~ s/^(\d)$/0$1/g;

                                # Lead with another 0 for devices that require 3 digits.
    if ($$self{code} and $$self{code} eq '3digit') {
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
    $state =~ s/POWER,/POWER,DELAY,/g;

    print "Sending IR_Item command $device $state\n";
    my $mapped_ir;
    for my $command (split(',', $state)) {

                                # Lets build our own delay
        if ($command eq 'DELAY') {
            select undef, undef, undef, 0.3; # Give it a chance to get going before doing other commands
            next;
        }
                                # IR mapping is mainly for controlers like 
                                # Homevision and CPU-XA that use learned IR
                                # slots instead of symbolic commands.
        if ($mapped_ir = $$self{mapref}->{$command}) {
            $command = $mapped_ir;
        }
        if ($$self{interface} eq 'CM17') {
            return if &main::proxy_send('CM17', 'send_ir', "$device $command");
            &ControlX10::CM17::send_ir($main::Serial_Ports{cm17}{object}, "$device $command");
        } elsif ($$self{interface} eq 'Homevision') {
            &Homevision::send($main::Serial_Ports{Homevision}{object}, $command);
        } elsif ($$self{interface} eq 'ncpuxa') {
            &ncpuxa_mh::send($main::config_parms{ncpuxa_port}, $command);
        } else {
            print "IR_Item::set Interface $$self{interface} not supported.\n";
        }
        $device = '';           # Use device only on the first command
    }
}

#
# $Log$
# Revision 1.9  2001/06/27 03:45:14  winter
# - 2.54 release
#
# Revision 1.8  2001/05/06 21:07:26  winter
# - 2.51 release
#
# Revision 1.7  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.6  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.5  2000/10/09 02:31:13  winter
# - 2.30 update
#
# Revision 1.4  2000/10/01 23:29:40  winter
# - 2.29 release
#
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
