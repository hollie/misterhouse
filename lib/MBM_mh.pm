
=head1 B<MBM_mh>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Interface mh user scripts to MBM (Mother Board Monitor)

MBM monitors Temperature, Voltage, Fans, etc. via sensors included in many motherboards.  MBM runs on Windows only.  MBM available at http://mbm.livewiredev.com

MBM must be installed and configured.  Win32::API must be installed via "ppm install Win32-API".  Do not confuse Win32::API with Win32API

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;
use Win32::API;
use MBM_sensors;   # Required.  Distributed with MisterHouse or obtain from CPAN

package MBM_mh;
@MBM_mh::ISA = ('Generic_Item');

my @MBM_Sensor_Objects;
my %MBM_sensors;
my $type;
my $num;

##
# Methods called from user scripts
##

sub new {
    my ( $class, $sensor_type, $sensor_num ) = @_;
    my $self = {};
    $$self{state}         = undef;
    $$self{said}          = undef;
    $$self{state_now}     = undef;
    $$self{state_changed} = undef;
    $$self{type}          = $sensor_type;
    $$self{num}           = $sensor_num;
    bless $self, $class;

    push @MBM_Sensor_Objects, $self;
    restore_data $self (
        'name',  'current', 'high',   'low',
        'count', 'total',   'alarm1', 'alarm2',
        'timestamp'
    );

    return $self;
}

sub name {
    return $_[0]->{name};
}

sub current {
    return $_[0]->{current};
}

sub low {
    return $_[0]->{low};
}

sub high {
    return $_[0]->{high};
}

sub count {
    return $_[0]->{count};
}

sub total {
    return $_[0]->{total};
}

sub alarm1 {
    return $_[0]->{alarm1};
}

sub alarm2 {
    return $_[0]->{alarm2};
}

sub time {
    return $_[0]->{timestamp};
}

##
# Methods internal to package
##

=item C<startup>

mh calls startup when mh.ini MBM_module=MBM_mh parm is processed 

=cut

sub startup {
    &::Reload_pre_add_hook( \&MBM_mh::reload_reset, 'persistent' );
    &::MainLoop_pre_add_hook( \&MBM_mh::check_for_data, 'persistent' );

    print " - creating MBM             object on shared memory\n";
}

sub reload_reset {
    undef @MBM_Sensor_Objects;
}

sub check_for_data {
    if ($main::New_Second) {
        %MBM_sensors = &MBM_sensors::get;
        for my $self (@MBM_Sensor_Objects) {
            $type = $self->{type};
            $num  = $self->{num};
            if ( $self->{count} != $MBM_sensors{$type}{count}[$num] ) {
                $self->{name}      = $MBM_sensors{$type}{name}[$num];
                $self->{current}   = $MBM_sensors{$type}{current}[$num];
                $self->{low}       = $MBM_sensors{$type}{low}[$num];
                $self->{high}      = $MBM_sensors{$type}{high}[$num];
                $self->{count}     = $MBM_sensors{$type}{count}[$num];
                $self->{total}     = $MBM_sensors{$type}{total}[$num];
                $self->{alarm1}    = $MBM_sensors{$type}{alarm1}[$num];
                $self->{alarm2}    = $MBM_sensors{$type}{alarm2}[$num];
                $self->{timestamp} = $MBM_sensors{timecurrent};
                set $self $MBM_sensors{$type}{current}[$num];
                ::print_log
                  "MBM updating $type $num $self->{name} with $self->{current}"
                  if $::config_parms{debug} eq 'MBM';
            }
        }
    }
}

1;

=back

=head2 INI PARAMETERS

"MBM_module=MBM_mh" required.

=head2 AUTHOR

Danal Estes danal@earthling.net

=head2 SEE ALSO

See /mh/code/common/MBM.pl for example user script.

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

