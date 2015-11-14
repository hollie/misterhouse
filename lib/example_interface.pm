
=head1 B<example_interface>

=head2 SYNOPSIS

Here is an example of reading/writing using this object:

 $test_example1 = new example_interface('string_on',   ON);
 $test_example1 ->add                  ('string_off', OFF);

 print "Example 1 data received: $state\n" if $state = state_now $test_example1;
 set $test_example1 OFF if new_second 5;


Here is another example

 $interface = new example_interface;
 $interface ->add('out123', 'request_status');
 $interface ->add('in123',  'door_open');

 set $interface 'request_staus' if $New_Second;
 speak 'Door just opened' if 'door_open' eq state_now $interface;


You could also query the incoming serial data directly:

 if (my $data = said $interface) {
        print_log "Data from interface: $data";
 }

=head2 DESCRIPTION

Methods (sub) 'startup' or 'serial_startup' are automatically
called by mh on startup.

=head2 INHERITS

B<Serial_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package example_interface;

@example_interface::ISA = ('Serial_Item');

sub startup {
    &main::serial_port_create( 'example_interface',
        $main::config_parms{example_interface_port},
        4800, 'none' );
    &::MainLoop_pre_add_hook( \&example_interface::check_for_data, 1 );
}

sub check_for_data {
    &main::check_for_generic_serial_data('example_interface');
}

sub set {
    my ( $self, $state, $set_by ) = @_;

    my $serial_data;

    # Allow for upper/mixed case (e.g. treat ON the same as on ... so X10_Items is simpler)
    if ( defined $self->{id_by_state}{$state} ) {
        $serial_data = $self->{id_by_state}{$state};
    }
    elsif ( defined $self->{id_by_state}{ lc $state } ) {
        $serial_data = $self->{id_by_state}{ lc $state };
    }
    else {
        $serial_data = $state;
    }

    print "Setting example_interface to $state -> $serial_data\n";
    $main::Serial_Ports{example_interface}{object}->write($serial_data);

    &Generic_Item::set_states_for_next_pass( $self, $state, $set_by );

}

1;

=back

=head2 INI PARAMETERS

 example_interface_module = example_interface
 example_interface_port   = COM9

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

