# $Date$
# $Revision$
use strict;

package IR_Item;

@IR_Item::ISA = ('Generic_Item');

my %default_map = qw(
    ON  POWER
    OFF POWER
);

my ($hooks_added, @objects_xap);

sub new {
    my ($class, $device, $code, $interface, $mapref) = @_;
    my $self = {};
    $$self{state} = '';
    $$self{code}  = $code if $code;
    $$self{interface} = ($interface) ? lc $interface : 'cm17';
 
                # Enable receiving of IR data
    if ($$self{interface} eq 'xap') {
        $$self{states_casesensitive} = 1;
        &::MainLoop_pre_add_hook( \&IR_Item::check_xap, 1) unless $hooks_added++;
        push @objects_xap, $self;
    }
    
    $device = uc $device unless $$self{states_casesensitive};
    $device = 'TV' unless $device;
    $$self{device} =    $device;
    
    $mapref = \%default_map unless $mapref;
    $$self{mapref} = $mapref;
    
    bless $self, $class;
    return $self;
}

sub check_xap {
    if (my $xap_data = &xAP::received_data()) {
        return unless $$xap_data{'xap-header'}{class} and $$xap_data{'xap-header'}{class} eq 'ir.receive';
        for my $o (@objects_xap) {
            print "IR_Item xap: $$xap_data{'ir.signal'}{device} = $$xap_data{'ir.signal'}{signal}\n";
            next unless uc $$xap_data{'ir.signal'}{device} eq $$o{device};
            $o -> SUPER::set($$xap_data{'ir.signal'}{signal}, 'xap');
        }
    }
}

my $device_prev;
sub default_setstate {
    my ($self, $state, $substate, $setby) = @_;

    return if $setby eq 'xap';  # Do not echo incoming data back out

#   print "db set=$state pass=$main::Loop_Count\n";

    my $device = $$self{device};
    $state = uc $state unless $$self{states_casesensitive};

                                # Option to make changing channels faster on devices with a timeout
    if ($$self{code} and $$self{code} eq 'addEnter') {
        $state =~ s/^(\d+),/$1,ENTER,/g;
        $state =~ s/,(\d+),/,$1,ENTER,/g;
        $state =~ s/,(\d+)$/,$1,ENTER/g;
        $state =~ s/^(\d+)$/$1,ENTER/g;
    }
                                # Option to do nothing to numbers
    elsif ($$self{code} eq 'noPad') {
    }
                                # Default is to lead single digit with a 0.  Cover all 4 cases:
                                #  1,record    stop,2   stop,3,record     4
    else {
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
    }
                                # Put commas between all digits, so they are seperate commands
    $state =~ s/(\d)(?=\d)/$1,/g;
                                # Record must be pressed twice??
    $state =~ s/RECORD/RECORD,RECORD/g;
                                # Add delay after powering up
    $state =~ s/POWER,/POWER,DELAY,/g;

    print "Sending IR_Item command $device $state\n" if $main::Debug{ir};
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
        if ($$self{interface} eq 'cm17') {
                                # Since the X10 IR Commander is a bit slow (.5 sec per xmit),
                                #  lets only send the device code if it is different than last time.
            $device = '' if $device and  $device eq $device_prev;
            $device_prev = $$self{device};
            return if &main::proxy_send('cm17', 'send_ir', "$device $command");
            &ControlX10::CM17::send_ir($main::Serial_Ports{cm17}{object}, "$device $command");
            $device = '';       # Use device only on the first command
        } elsif ($$self{interface} eq 'homevision') {
            &Homevision::send($main::Serial_Ports{Homevision}{object}, $command);
        } elsif ($$self{interface} eq 'ncpuxa') {
            &ncpuxa_mh::send($main::config_parms{ncpuxa_port}, $command);
        } elsif ($$self{interface} eq 'uirt2') {
            &UIRT2::set($device, $command);
        } elsif ($$self{interface} eq 'usb_uirt') {
            &USB_UIRT::set($device, $command);
        } elsif ($$self{interface} eq 'lirc') {
	    &lirc_mh::send($device, $command);
        } elsif ($$self{interface} eq 'ninja') {
	    &ninja_mh::send($device, $command);
        } elsif ($$self{interface} eq 'xap') {
            &xAP::send('xAP', 'IR.Transmit', 'IR.Signal' => {Device => $device, Signal => $command});
        } else {
            print "IR_Item::set Interface $$self{interface} not supported.\n";
        }
    }
}

#
# $Log: IR_Item.pm,v $
# Revision 1.17  2004/07/18 22:16:37  winter
# *** empty log message ***
#
# Revision 1.16  2004/07/05 23:36:37  winter
# *** empty log message ***
#
# Revision 1.15  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.14  2004/02/01 19:24:35  winter
#  - 2.87 release
#
# Revision 1.13  2003/02/08 05:29:23  winter
#  - 2.78 release
#
# Revision 1.12  2002/12/02 04:55:19  winter
# - 2.74 release
#
# Revision 1.11  2002/09/22 01:33:23  winter
# - 2.71 release
#
# Revision 1.10  2001/08/12 04:02:58  winter
# - 2.57 update
#
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
