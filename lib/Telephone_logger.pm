
=head1 B<Telephone_logger>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Control CK-602 Telephone Logger

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Telephone_logger;

@Telephone_logger::ISA = ('Generic_Item');

my @Telephone_logger_Ports;

sub serial_startup {
    my ($instance) = @_;
    my $count = 0;
    push( @Telephone_logger_Ports, $instance );

    my $port  = $::config_parms{ $instance . "_serial_port" };
    my $speed = $::config_parms{ $instance . "_baudrate" };

    foreach my $ports (@Telephone_logger_Ports) {
        $count++ if ( $ports eq $instance );
    }

    if ( $count == 1 ) {
        &::serial_port_create( $instance, $port, $speed, 'dtr', 'record' );
        $count = 0;
    }

    if ( 1 == scalar @Telephone_logger_Ports ) {  # Add hooks on first call only
        &::MainLoop_pre_add_hook( \&Telephone_logger::check_for_data, 1 );
    }
}

sub check_for_data {
    for my $port_name (@Telephone_logger_Ports) {
        &::check_for_generic_serial_data($port_name)
          if $::Serial_Ports{$port_name}{object};
        my $data = $::Serial_Ports{$port_name}{data_record};
        next if !$data;
    }
}

sub said {
    my $port_name = $_[0]->{port_name};
    my $retval    = $main::Serial_Ports{$port_name}{data_record};
    $main::Serial_Ports{$port_name}{data_record} = undef;
    return $retval;

}

sub new {
    my ( $class, $port_name ) = @_;
    print "Telephone logger new called\n";
    $port_name = 'Telephone_logger' if !$port_name;

    my $self = $class->SUPER::new();
    my $self = {};
    $$self{state}     = '';
    $$self{said}      = '';
    $$self{state_now} = '';
    $$self{port_name} = $port_name;
    bless $self, $class;
    return $self;
}

1;

=back

=head2 INI PARAMETERS

Telephone_logger_serial_port=/dev/ttyR4
Telephone_logger_baudrate=9600

=head2 AUTHOR

David Satterfield <david_misterhouse@yahoo.com>

This module was adapted from Kent Noonans Omnistat.pm
Thanks for the starting point Kent.

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

