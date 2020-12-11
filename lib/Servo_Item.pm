
=head1 B<Servo_Item>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This object supports servo motors via the Mini SSC II serial servo
control board, available from http://seetron.com .

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package Servo_Item;

@Servo_Item::ISA = ('Generic_Item');

sub startup {
    ( $port_name, $port ) = @_;
    &::serial_port_create( $port_name, $port, 9600 );

    # Initialize servos?
    #   for my $object (&::list_objects_by_type2('Servo_Item')) {
    #       set $object 50;
    #   }
}

sub new {
    my ( $class, $port_name, $servo ) = @_;

    # Need to avoid this, or the Generic_Item ExtraHash tie will disable TK scale -variable slider :(
    #   my $self = $class->SUPER::new();
    my %myhash;
    my $self = \%myhash;
    bless $self, $class;
    $self->{servo}     = $servo;
    $self->{port_name} = $port_name;
    return $self;
}

sub set {
    my ( $self, $state ) = @_;
    $self->SUPER::set($state);
    &set_servo( $self, $state );
}

sub set_inc {
    my ( $self, $inc, $dir, $limit_min, $limit_max ) = @_;

    my $servo = $$self{servo};
    my $state = $$self{state};
    $dir = $$self{dir} unless $dir;
    $dir = 1           unless $dir;
    $inc = 2           unless $inc;
    $state += $dir * $inc;

    # Reverse dir if past limit
    $limit_min = 10 unless defined $limit_min;
    $limit_max = 90 unless defined $limit_max;
    if (   ( $dir < 0 and $state < $limit_min )
        or ( $dir > 0 and $state > $limit_max ) )
    {
        $state      = ( $dir > 0 ) ? $limit_max : $limit_min;
        $dir        = -$dir;
        $$self{dir} = $dir;
    }
    print "Servo_Item increment: s=$servo inc=$inc dir=$dir s=$state\n"
      if $::Debug{servo};
    &set( $self, $state );
}

sub set_servo {
    my ( $self, $pos ) = @_;
    my $servo     = $$self{servo};
    my $port_name = $$self{port_name};
    my $pos2      = $pos;
    $pos2 = 100 if $pos2 > 100;
    $pos2 = 0   if $pos2 < 0;
    $pos2 = int $pos2 * 2.54;    # Valid values are 0 -> 254
    print "Sending servo data: servo=$servo pos=$pos pos2=$pos2\n"
      if $::Debug{servo};

    if ( defined $servo ) {
        my $data = chr(255) . chr($servo) . chr($pos2);
        $::Serial_Ports{$port_name}{object}->write($data);
    }
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

Example usage can be found in mh/code/common/robot_esra.pl

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

