
=head1 B<RedRat>

=head2 SYNOPSIS

  $ir_dvd=new RedRat;
  $ir_dvd->add("power","[PF62........]");
  $if_dvd->add("play","[PF62........]");

  $v_ir_dvd = new Voice_Cmd('push dvd [power,play] button');

  if ($state = said $v_ir_dvd) {
    $ir_dvd->set($state);
  }

=head2 DESCRIPTION

Used to control infrared devices with the RedRat2

http://www.dodgies.demon.co.uk/index.html

=head2 INHERITS

B<Serial_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package RedRat;

@RedRat::ISA = ('Serial_Item');

sub serial_startup {
    &main::serial_port_create( 'RedRat',
        $main::config_parms{RedRat_serial_port},
        19200, 'none' );
}

sub new {
    my ($class) = @_;
    my $self = {};
    $$self{state} = '';
    bless $self, $class;
    return $self;
}

sub add {
    my ( $self, $command, $code ) = @_;
    $$self{$command} = $code;
    push( @{ $$self{states} }, $command );
}

sub set {
    my ( $self, $command ) = @_;
    if ( !defined $$self{$command} ) {
        &::print_log("RedRat: Invalid State: $command");
    }
    else {
        if ( $main::Debug{redrat} ) {
            &::print_log("RedRat: Sending $command -> $$self{$command}");
        }
        select( undef, undef, undef, 0.40 );
        $main::Serial_Ports{RedRat}{object}->write( $$self{$command} );
        &Generic_Item::set_states_for_next_pass( $self, $command );
    }

}

1;

=back

=head2 INI PARAMETERS

  RedRat_serial_port   = COM9

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

