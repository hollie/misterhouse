
=head1 B<RCSs>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Control RCS serial (rs232/rs485) thermostats.

=head2 INHERITS

B<Serial_Item>

=head2 METHODS

=over

=cut

use strict;

package RCSs;

@RCSs::ISA = ('Serial_Item');

my @RCSs_Thermistat_Ports;
my %RCSs_Thermistat_Address;

sub serial_startup {
    my ($instance) = @_;

    #    print "instance is $instance\n";
    my $count = 0;
    push( @RCSs_Thermistat_Ports, $instance );

    my $port      = $::config_parms{ $instance . "_serial_port" };
    my $speed     = $::config_parms{ $instance . "_baudrate" };
    my $thermaddr = $::config_parms{ $instance . "_address" };
    $thermaddr = "01" if !$thermaddr;
    $RCSs_Thermistat_Address{$instance} = $thermaddr;

    foreach my $ports (@RCSs_Thermistat_Ports) {
        $count++ if ( $ports eq $instance );
    }

    if ( $count == 1 ) {

        #	$main::config_parms{"RCSs_break"} = ' ';
        &::serial_port_create( $instance, $port, $speed );
        $count = 0;
    }

    if ( 1 == scalar @RCSs_Thermistat_Ports ) {   # Add hooks on first call only
        &::MainLoop_pre_add_hook( \&RCSs::check_for_data, 1 );
    }

    # &_poll();
}

sub check_for_data {
    for my $port_name (@RCSs_Thermistat_Ports) {
        &::check_for_generic_serial_data($port_name)
          if $::Serial_Ports{$port_name}{object};
        my $data = $::Serial_Ports{$port_name}{data_record};
        next if !$data;

        #     		print "$port_name got: [$::Serial_Ports{$port_name}{data_record}]\n";
        #      		$main::Serial_Ports{$port_name}{data_record}='';
    }
}

sub said {
    my $port_name = $_[0]->{port_name};
    my $retval    = $main::Serial_Ports{$port_name}{data_record};
    $main::Serial_Ports{$port_name}{data_record} = undef;
    return $retval;

}

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

sub new {
    my ( $class, $port_name ) = @_;
    $port_name = 'RCSs' if !$port_name;
    my $thermaddr = $RCSs_Thermistat_Address{$port_name};

    my $self = {};
    $$self{state}        = '';
    $$self{said}         = '';
    $$self{state_now}    = '';
    $$self{port_name}    = $port_name;
    $$self{thermaddress} = $thermaddr;
    bless $self, $class;
    return $self;
}

=item C<hold>

Hold isn't directly available on the RCS, but we'll implement a holdlike
feature via software.

=cut

sub hold {
    my ( $self, $state ) = @_;
    $state = lc($state);

    print "RCSs: Hold Not yet implemented\n";

    print "$::Time_Date: RCSs -> Hold $state\n"
      unless $main::config_parms{no_log} =~ /RCSs/;
    if ( $state eq "off" ) {
    }
    elsif ( $state eq "on" ) {
    }
    else {
        print "RCSs: Invalid Hold state: $state\n";
    }
}

sub mode {
    my ( $self, $state ) = @_;
    my $instance = $$self{port_name};
    $state = lc($state);
    print "$::Time_Date: RCSs -> Mode $state\n"
      unless $main::config_parms{no_log} =~ /RCSs/;
    my $mode;
    if ( $state eq "off" ) {
        $mode = "0";
    }
    elsif ( $state eq "heat" ) {
        $mode = "H";
    }
    elsif ( $state eq "cool" ) {
        $mode = "C";
    }
    elsif ( $state eq "auto" ) {
        $mode = "A";
    }
    else {
        print "RCSs: Invalid Mode state: $state\n";
        return ();
    }
    my $cmd = "A=$self->{thermaddress} M=$mode\r";
    $main::Serial_Ports{$instance}{object}->write($cmd);
    $self->_poll();
}

sub fan {
    my ( $self, $state ) = @_;
    my $instance = $$self{port_name};
    $state = lc($state);
    print "$::Time_Date: RCSs -> Fan $state\n"
      unless $main::config_parms{no_log} =~ /RCSs/;
    my $fan;
    if ( $state eq "on" ) {
        $fan = "1";
    }
    elsif ( $state eq "auto" || $state eq "off" ) {
        $fan = "0";
    }
    else {
        print "RCSs: Invalid Fan state: $state\n";
        return ();
    }
    my $cmd = "A=$self->{thermaddress} F=$fan\r";
    $main::Serial_Ports{$instance}{object}->write($cmd);
    $self->_poll();
}

sub cool_setpoint {
    my ( $self, $temp ) = @_;
    print "$::Time_Date: RCSs -> Cool setpoint $temp\n"
      unless $main::config_parms{no_log} =~ /RCSs/;
    &_setpoint( $self, $temp );
}

sub heat_setpoint {
    my ( $self, $temp ) = @_;
    print "$::Time_Date: RCSs -> Heat setpoint $temp\n"
      unless $main::config_parms{no_log} =~ /RCSs/;
    &_setpoint( $self, $temp );
}

sub _setpoint {
    my ( $self, $temp ) = @_;
    my $instance = $$self{port_name};
    if ( $temp !~ /^\d+$/ ) {
        print "$::Time_Date: RCSs -> _setpoint ERROR $temp not numeric\n";
        return;
    }
    my $cmd = "A=$self->{thermaddress} SP=$temp\r";
    $main::Serial_Ports{$instance}{object}->write($cmd);
    $self->_poll();
}

sub _poll {
    my ( $self, $temp ) = @_;
    my $instance = $self->{port_name};
    my $cmd      = "A=$self->{thermaddress} R=12\r";
    $main::Serial_Ports{$instance}{object}->write($cmd);

    #	print "$::Time_Date: RCSs::_poll (ing) [$self]\n";
}

sub heating_cycle_time {
    my ( $self, $time ) = @_;
    print
      "$::Time_Date: RCSs -> Heat cycle time $time IGNORED: controller enforces embedded cycle time\n"
      unless $main::config_parms{no_log} =~ /RCSs/;
}

sub cooling_cycle_time {
    my ( $self, $time ) = @_;
    print
      "$::Time_Date: RCSs -> Cool cycle time $time IGNORED: controller enforces embedded cycle time\n"
      unless $main::config_parms{no_log} =~ /RCSs/;
}

sub cooling_anticipator {
    my ( $self, $value ) = @_;
    print "$::Time_Date: RCSs -> Cooling Anticipator NOT available\n"
      unless $main::config_parms{no_log} =~ /RCSs/;
}

sub heating_anticipator {
    my ( $self, $value ) = @_;
    print "$::Time_Date: RCSs -> Heating Anticipator NOT available\n"
      unless $main::config_parms{no_log} =~ /RCSs/;
}

1;

=back

=head2 INI PARAMETERS

  RCSs_serial_port=/dev/ttyS4
  RCSs_baudrate=9600
  RCSs_address=1 to 255 (for mutiple thermistats on a 422 interface) May be omitted (or 1) if using RS232.

=head2 AUTHOR

Chris Witte <cwitte@xmlhq.com>

This module was shamelessly cloned from Kent Noonans Omnistat.pm
Thanks for the starting point Kent.

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

