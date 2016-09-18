
=head1 B<Parallel port item>

=head2 SYNOPSIS

Item which follows digital logic state on standard PC parallel port inputs.

Each item should be defined with a pin number and description.

Example:

 use Parport_Item;
 $input1 = new Parport_Item('10', 'Test device on DB25 pin 10');

 print "Parallel port pin 10 now $state\n" if $state = state_now $input1;

=head2 DESCRIPTION

All inputs are pulled high in a typical parallel port (+5 V) when disconnected/open.  The item is considered on if the voltage is +5 V (logic high) and off if voltage is 0 V (logic low).  Also note that even for those bits that would normally be inverted in the register (ex: pin 11, nBUSY) are are automatically uninverted such that all inputs work the same.

Currently a parallel port item only supports the 5 input pins (DB25 pins 10, 11, 12, 13, and 15).

For a description of the various pins see http://en.wikipedia.org/wiki/Parallel_port

Currently the item tries to automatically determine the correct driver, and will default to the first port.  This means it should work cross platform but has not been tested on any platform other than Linux

=head2 INHERITS

B<Generic_Item>

=cut

#!/usr/bin/perl

use Device::ParallelPort;
use strict;

package Parport_Item;

my $parport;
my $parport_uninitialized = 1;
my @Parport_Items;
my %input_pin_to_bit = (
    '10' => '14',
    '11' => '15',
    '12' => '13',
    '13' => '12',
    '15' => '11'
);

@Parport_Item::ISA = ('Generic_Item');

# Add a hook so this gets initialized at startup/reload (note: for serial items the startup sub gets called automatically)
&main::Reload_post_add_hook( \&Parport_Item::startup, 'persistent' );

=head2 METHODS

=over

=item C<new()>

=cut

sub startup {
    if ($parport_uninitialized) {
        $parport               = Device::ParallelPort->new('auto:0');
        $parport_uninitialized = 0;
        &::MainLoop_pre_add_hook( \&Parport_Item::get_pin_state, 'persistent' );
    }
}

=item C<new()>

=cut

sub new {
    my ( $class, $pin, $logic_level_for_on, $description ) = @_;
    if ( exists( $input_pin_to_bit{$pin} ) ) {
        my $self = {};
        bless $self, $class;
        $$self{'pin'}         = $pin;
        $$self{'description'} = $description;
        $$self{state}         = undef;
        $$self{said}          = undef;
        $$self{state_now}     = undef;
        $$self{state_changed} = undef;
        push @Parport_Items, $self;
        push( @{ $$self{states} }, 'on', 'off' );

        return $self;
    }
    else {
        &main::print_log(
            "Parport_Item: ERROR: Unsupported pin ($pin) for $description");
        die "Parport_Item: ERROR: Unsupported pin ($pin) for $description";
    }
}

=item C<get_pin_state()>

=cut

sub get_pin_state {

    # Check the state of input pins 10 times per second.  This should be adequate for general use but the holdoff can be eliminated if fastest response is required.
    if ($::New_Msecond_100) {
        foreach my $item (@Parport_Items) {
            my $pin = $item->{'pin'};

            my $pin_state = $parport->get_bit( $input_pin_to_bit{$pin} );

            # Only make an update if the state changed
            # The register value for pin 11 (BUSY) is inverted so un-invert the logic here
            if (
                ( $item->{'state'} eq 'on' )
                && (   ( ( $pin eq '11' ) && ( $pin_state == '1' ) )
                    || ( $pin_state == '0' ) )
              )
            {
                &Generic_Item::set_states_for_next_pass( $item, 'off',
                    'Parallel Port' );
            }
            elsif (
                ( $item->{'state'} eq 'off' )
                && (   ( ( $pin eq '11' ) && ( $pin_state == '0' ) )
                    || ( $pin_state == '1' ) )
              )
            {
                &Generic_Item::set_states_for_next_pass( $item, 'on',
                    'Parallel Port' );
            }
        }
    }
}

=back

=head2 DEPENDENCIES:

This code depends on the Perl modules C<Device::ParallelPort> and may require C<Device::ParallelPort::drv::parport> or C<Device::ParallelPort::drv::win32> depending on your platform.  These modules are available from CPAN.

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jeff Siddall (news@siddall.name)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

