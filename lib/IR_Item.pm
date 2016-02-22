
=head1 B<IR_Item>

=head2 SYNOPSIS

  $TV = new IR_Item 'TV';
  $v_tv_control = new  Voice_Cmd("tv [power,on,off,mute,vol+,vol-,ch+,ch-]");
  set $TV $state if $state = said $v_tv_control;

  $VCR = new IR_Item 'vcr', '3digit';
  set $VCR "12,RECORD" if time_cron('59 19 * * 3');
  set $VCR "STOP"      if time_cron('00 20 * * 3');

=head2 DESCRIPTION

This object controls IR transmiters. The devices currently supported are the X10 IR Commander, HomeVision, CPU-XA/Ocelot/Leopard, and UIRT2 (http://www.fukushima.us/UIRT2/).

The X10 IR Commander (http://www.x10.com/products/ux17a_bj2.htm) receives commands from the wireless CM17 (firecracker) interface. Currently, you must use the X10 supplied software (http://www.x10.com/commander.htm and/or ftp://ftp.x10.com/pub/applications/commander/) to program the IR Commander to use the codes for your various remotes.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;

package IR_Item;

@IR_Item::ISA = ('Generic_Item');

my %default_map = qw(
  ON  POWER
  OFF POWER
);

my ( $hooks_added, @objects_xap );

=item C<new($type, $code, $interface, $mapref)>

Creates a new Item.

$type is the type of device being controlled.  Default is TV.  Here are the only valid types for the X10 IR Commander; TV, VCR, CAB, CD, SAT, DVD

$code specifies how numbers will be treated.  Default is 2digit.

  - noPad   : numbers are not modified
  - 2digit  : single digits will be padded with a leading zero
  - 3digit  : numbers will be padded to 3 digits with leading zeros
  - addEnter: adds an ENTER command after any numbers, to make changing channels faster on devices that wait for a timeout (e.g. Sony TVs).

$interface is the transmitter to be used.  Default is cm17.

  - cm17    : X10 IR Commander
  - homevision: HomeVision
  - ncpuxa  : CPU-XA/Ocelot/Leopard
  - uirt2   : UIRT2 (http://www.fukushima.us/UIRT2/)
  - xAP     : Sends / receives data via the xAP protocol.

$mapref is a reference to a hash that specifies commands to be mapped to other commands.  This is useful for transmitters like the Ocelot which use slot numbers instead of device and function name pairs.  Default is a reference to a hash containing ( ON  => POWER, OFF => POWER ) Which you would not want if you had descrete ON and OFF codes.

=cut

sub new {
    my ( $class, $device, $code, $interface, $mapref ) = @_;
    my $self = {};
    $$self{state}     = '';
    $$self{code}      = $code if $code;
    $$self{interface} = ($interface) ? lc $interface : 'cm17';

    # Enable receiving of IR data
    if ( $$self{interface} eq 'xap' ) {
        $$self{states_casesensitive} = 1;
        &::MainLoop_pre_add_hook( \&IR_Item::check_xap, 1 )
          unless $hooks_added++;
        push @objects_xap, $self;
    }

    $device = uc $device unless $$self{states_casesensitive};
    $device = 'TV'       unless $device;
    $$self{device} = $device;

    $mapref = \%default_map unless $mapref;
    $$self{mapref} = $mapref;

    bless $self, $class;
    return $self;
}

sub check_xap {
    if ( my $xap_data = &xAP::received_data() ) {
        return
          unless $$xap_data{'xap-header'}{class}
          and $$xap_data{'xap-header'}{class} eq 'ir.receive';
        for my $o (@objects_xap) {
            print
              "IR_Item xap: $$xap_data{'ir.signal'}{device} = $$xap_data{'ir.signal'}{signal}\n";
            next unless uc $$xap_data{'ir.signal'}{device} eq $$o{device};
            $o->SUPER::set( $$xap_data{'ir.signal'}{signal}, 'xap' );
        }
    }
}

my $device_prev;

sub default_setstate {
    my ( $self, $state, $substate, $setby ) = @_;

    return if $setby eq 'xap';    # Do not echo incoming data back out

    #   print "db set=$state pass=$main::Loop_Count\n";

    my $device = $$self{device};
    $state = uc $state unless $$self{states_casesensitive};

    # Option to make changing channels faster on devices with a timeout
    if ( $$self{code} and $$self{code} eq 'addEnter' ) {
        $state =~ s/^(\d+),/$1,ENTER,/g;
        $state =~ s/,(\d+),/,$1,ENTER,/g;
        $state =~ s/,(\d+)$/,$1,ENTER/g;
        $state =~ s/^(\d+)$/$1,ENTER/g;
    }

    # Option to do nothing to numbers
    elsif ( $$self{code} eq 'noPad' ) {
    }

    # Default is to lead single digit with a 0.  Cover all 4 cases:
    #  1,record    stop,2   stop,3,record     4
    else {
        $state =~ s/^(\d),/0$1,/g;
        $state =~ s/,(\d),/,0$1,/g;
        $state =~ s/,(\d)$/,0$1/g;
        $state =~ s/^(\d)$/0$1/g;

        # Lead with another 0 for devices that require 3 digits.
        if ( $$self{code} and $$self{code} eq '3digit' ) {
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
    for my $command ( split( ',', $state ) ) {

        # Lets build our own delay
        if ( $command eq 'DELAY' ) {
            select undef, undef, undef,
              0.3;   # Give it a chance to get going before doing other commands
            next;
        }

        # IR mapping is mainly for controlers like
        # Homevision and CPU-XA that use learned IR
        # slots instead of symbolic commands.
        if ( $mapped_ir = $$self{mapref}->{$command} ) {
            $command = $mapped_ir;
        }
        if ( $$self{interface} eq 'cm17' ) {

            # Since the X10 IR Commander is a bit slow (.5 sec per xmit),
            #  lets only send the device code if it is different than last time.
            $device = '' if $device and $device eq $device_prev;
            $device_prev = $$self{device};
            return
              if &main::proxy_send( 'cm17', 'send_ir', "$device $command" );
            &ControlX10::CM17::send_ir( $main::Serial_Ports{cm17}{object},
                "$device $command" );
            $device = '';    # Use device only on the first command
        }
        elsif ( $$self{interface} eq 'homevision' ) {
            &Homevision::send( $main::Serial_Ports{Homevision}{object},
                $command );
        }
        elsif ( $$self{interface} eq 'ncpuxa' ) {
            &ncpuxa_mh::send( $main::config_parms{ncpuxa_port}, $command );
        }
        elsif ( $$self{interface} eq 'uirt2' ) {
            &UIRT2::set( $device, $command );
        }
        elsif ( $$self{interface} eq 'usb_uirt' ) {
            &USB_UIRT::set( $device, $command );
        }
        elsif ( $$self{interface} eq 'lirc' ) {
            &lirc_mh::send( $device, $command );
        }
        elsif ( $$self{interface} eq 'ninja' ) {
            &ninja_mh::send( $device, $command );
        }
        elsif ( $$self{interface} eq 'xap' ) {
            &xAP::send( 'xAP', 'IR.Transmit',
                'IR.Signal' => { Device => $device, Signal => $command } );
        }
        else {
            print "IR_Item::set Interface $$self{interface} not supported.\n";
        }
    }
}

=back

=head2 INHERITED METHODS

=over

=item C<state>

Returns the last state that was sent

=item C<state_now>

Returns the state that was sent in the current pass.

=item C<state_log>

Returns a list array of the last max_state_log_entries (mh.ini parm) time_date stamped states.

=item C<set($command)>

Sends out commands to the IR device.  Here is a list of valid commands for the X10 IR Commander::
Note:  Commands are not case insensitive

        POWER      MUTE
        CH+        CH-
        VOL+       VOL-
        1          2
        3          4
        5          6
        7          8
        9          0
        MENU       ENTER
        FF         REW
        RECORD     PAUSE
        PLAY       STOP
        AVSWITCH   DISPLAY
        UP         DOWN
        LEFT       RIGHT
        SKIPDOWN   SKIPUP
        TITLE      SUBTITLE
        EXIT       OK
        RETURN

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
