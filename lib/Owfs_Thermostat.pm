
=head1 B<Owfs_Thermostat>

=head2 SYNOPSIS

In your code module, instantation the Owfs_Thermostat class.  Next,
inform the Thermostat of the one-wire devices which control the various
HVAC equipment, all of which are optional.

  add_thermometer ( "<device_id>", "<location>", zone );
  set_heat_relay  ( "<device_id>", "<location>");
  set_heat_sensor ( "<device_id>", "<location>", "<channel>");
  set_cool_relay  ( "<device_id>", "<location>");
  set_cool_sensor ( "<device_id>", "<location>", "<channel>");
  set_fan_relay   ( "<device_id>", "<location>");
  set_fan_sensor  ( "<device_id>", "<location>", "<channel>");

Usage:

  $thermostat = new Owfs_Thermostat ( );

  if ($Startup or $Reload) {
    $thermostat->add_thermometer ( "10.A930E4000800", "Sewing Room", 3 );
    $thermostat->add_thermometer ( "10.6D9EB1000800", "Kitchen", 1 );
    $thermostat->add_thermometer ( "10.4936E4000800", "Living Room", 1);
    $thermostat->add_thermometer ( "10.6474E4000800", "Master Bedroom", 2);
    $thermostat->add_thermometer ( "10.842CE4000800", "Guest Room", 3);
    $thermostat->set_heat_relay  ( "05.14312A000000", "Furnace" );
    $thermostat->set_heat_sensor ( "20.DB2506000000", "Furnace", "B");
    $thermostat->set_cool_relay  ( "05.F2302A000000", "Air Conditioner" );
    $thermostat->set_cool_sensor ( "20.DB2506000000", "Air Conditioner", "A");
    $thermostat->set_fan_relay   ( "05.14312A000000", "Air Fan" );
    $thermostat->set_cool_sensor ( "20.DB2506000000", "Air Fan", "C");
  }


=head2 DESCRIPTION

Use this module to create a software based thermostat control which is
manipulated by the MH web browser.  This library module interacts with
the perl cgi scripts found in code/public/Owfs_hvac.pl.  This cgi script
needs to be copied to web/ia5/outside/Owfs_hvac.pl.  You will
need to update web/ia5/outside/hvac.stml to call Owfs_hvac.pl.

Requirements:

 Download and install OWFS
 http://www.owfs.org

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Owfs_Thermostat;

@Owfs_Thermostat::ISA = ('Generic_Item');

use OW;
use Owfs_Item;

sub new {
    my ( $class, $interval ) = @_;
    my $self = {};
    bless $self, $class;

    $interval = 10 unless $interval;
    $interval = 10 if ( $interval < 10 );
    $self->{interval} = $interval;

    $self->{t_run_timer} = new Timer;
    $self->{t_run_timer}
      ->set( $self->{interval}, sub { &Owfs_Thermostat::run_loop($self) } );
    $self->{t_hold_timer} = new Timer;

    # create a timer to identify how long the compressor is on (maintain minimum on time)
    $self->{t_on_timer}     = new Timer;
    $self->{on_timer_value} = 3;
    if ( defined $::config_parms{owfs_on_timer_value} ) {
        $self->{on_timer_value} = $::config_parms{owfs_on_timer_value};
    }

    # create a timer to identify how long the compressor is off (maintain minimum off time)
    $self->{t_off_timer}     = new Timer;
    $self->{off_timer_value} = 3;
    if ( defined $::config_parms{owfs_off_timer_value} ) {
        $self->{off_timer_value} = $::config_parms{owfs_off_timer_value};
    }

    $self->{system_mode}  = "off";
    $self->{fan_mode}     = "auto";
    $self->{hold}         = 0;
    $self->{hold_timer}   = "00:00";
    $self->{temp_sp}      = 70;
    $self->{temp_zone}    = 1;
    $self->{thermometers} = {};
    $self->{index}        = 0;
    $self->{zone}         = ();
    $self->restore_defaults();

    $self->restore_data( "system_mode", "fan_mode", "hold", "hold_timer",
        "temp_sp" );
    $self->restore_data(
        "sun_0_time", "sun_0_temp", "sun_0_zone", "sun_1_time",
        "sun_1_temp", "sun_1_zone"
    );
    $self->restore_data(
        "sun_2_time", "sun_2_temp", "sun_2_zone", "sun_3_time",
        "sun_3_temp", "sun_3_zone"
    );
    $self->restore_data(
        "mon_0_time", "mon_0_temp", "mon_0_zone", "mon_1_time",
        "mon_1_temp", "mon_1_zone"
    );
    $self->restore_data(
        "mon_2_time", "mon_2_temp", "mon_2_zone", "mon_3_time",
        "mon_3_temp", "mon_3_zone"
    );
    $self->restore_data(
        "tue_0_time", "tue_0_temp", "tue_0_zone", "tue_1_time",
        "tue_1_temp", "tue_1_zone"
    );
    $self->restore_data(
        "tue_2_time", "tue_2_temp", "tue_2_zone", "tue_3_time",
        "tue_3_temp", "tue_3_zone"
    );
    $self->restore_data(
        "wed_0_time", "wed_0_temp", "wed_0_zone", "wed_1_time",
        "wed_1_temp", "wed_1_zone"
    );
    $self->restore_data(
        "wed_2_time", "wed_2_temp", "wed_2_zone", "wed_3_time",
        "wed_3_temp", "wed_3_zone"
    );
    $self->restore_data(
        "thu_0_time", "thu_0_temp", "thu_0_zone", "thu_1_time",
        "thu_1_temp", "thu_1_zone"
    );
    $self->restore_data(
        "thu_2_time", "thu_2_temp", "thu_2_zone", "thu_3_time",
        "thu_3_temp", "thu_3_zone"
    );
    $self->restore_data(
        "fri_0_time", "fri_0_temp", "fri_0_zone", "fri_1_time",
        "fri_1_temp", "fri_1_zone"
    );
    $self->restore_data(
        "fri_2_time", "fri_2_temp", "fri_2_zone", "fri_3_time",
        "fri_3_temp", "fri_3_zone"
    );
    $self->restore_data(
        "sat_0_time", "sat_0_temp", "sat_0_zone", "sat_1_time",
        "sat_1_temp", "sat_1_zone"
    );
    $self->restore_data(
        "sat_2_time", "sat_2_temp", "sat_2_zone", "sat_3_time",
        "sat_3_temp", "sat_3_zone"
    );

    return $self;
}

#--------------------------------------------------------------------------------------------------------
#
# ACCESS METHODS
#
#--------------------------------------------------------------------------------------------------------

sub add_thermometer {
    my ( $self, $thermometer, $location, $zone ) = @_;
    return if $self->{thermometers}{$thermometer};
    $zone = "1" unless defined $zone;
    &main::print_log(
        "Owfs_Thermostat::adding_thermometer: $thermometer zone: $zone")
      if $::Debug{owfs};
    $self->{thermometers}{$thermometer} =
      new Owfs_Item( $thermometer, $location );
    $self->{thermometers}{$thermometer}->set_key( "zone", $zone );
    $self->{zone}->[$zone]->{name} = $zone;
}

sub set_heat_relay {
    my ( $self, $relay, $location ) = @_;
    if ( exists $self->{heat_relay} ) {
        return if ( $self->{heat_relay}->get_device eq $relay );
        delete $self->{heat_relay};
    }
    $self->{heat_relay} = new Owfs_Item( $relay, $location );
}

sub set_heat_sensor {
    my ( $self, $sensor, $location, $channel ) = @_;
    if ( exists $self->{heat_sensor} ) {
        return if ( $self->{heat_sensor}->get_device eq $sensor );
        delete $self->{heat_sensor};
    }
    $self->{heat_sensor} = new Owfs_DS2450( $sensor, $location, $channel );
}

sub set_cool_relay {
    my ( $self, $relay, $location ) = @_;
    if ( exists $self->{cool_relay} ) {
        return if ( $self->{cool_relay}->get_device eq $relay );
        delete $self->{cool_relay};
    }
    $self->{cool_relay} = new Owfs_Item( $relay, $location );
}

sub set_cool_sensor {
    my ( $self, $sensor, $location, $channel ) = @_;
    if ( exists $self->{cool_sensor} ) {
        return if ( $self->{cool_sensor}->get_device eq $sensor );
        delete $self->{cool_sensor};
    }
    $self->{cool_sensor} = new Owfs_DS2450( $sensor, $location, $channel );
}

sub set_fan_relay {
    my ( $self, $relay, $location ) = @_;
    if ( exists $self->{fan_relay} ) {
        return if ( $self->{fan_relay}->get_device eq $relay );
        delete $self->{fan_relay};
    }
    $self->{fan_relay} = new Owfs_Item( $relay, $location );
}

sub set_fan_sensor {
    my ( $self, $sensor, $location, $channel ) = @_;
    if ( exists $self->{fan_sensor} ) {
        return if ( $self->{fan_sensor}->get_device eq $sensor );
        delete $self->{fan_sensor};
    }
    $self->{fan_sensor} = new Owfs_DS2450( $sensor, $location, $channel );
}

sub set_system_mode {
    my ( $self, $value ) = @_;
    if ( $value =~ /off|heat|cool/ ) {
        &main::logit(
            "$::config_parms{data_dir}/logs/hvac/$::Year_Month_Now.log",
            "System Mode change to $value",
            , 1
        );
        $self->{system_mode} = $value;
    }
}

sub get_system_mode {
    my ($self) = @_;
    return $self->{system_mode};
}

sub set_fan_mode {
    my ( $self, $value ) = @_;
    if ( $value =~ /on|auto/ ) {
        &main::logit(
            "$::config_parms{data_dir}/logs/hvac/$::Year_Month_Now.log",
            "Fan Mode change to $value",
            , 1
        );
        $self->{fan_mode} = $value;
    }
}

sub get_fan_mode {
    my ($self) = @_;
    return $self->{fan_mode};
}

sub get_state {
    my ($self) = @_;
    my $state = "Idle";
    if ( $self->{system_mode} eq 'off' ) {
        $state = "System Off";
    }
    elsif ( $self->{system_mode} eq 'heat' ) {
        if ( exists $self->{heat_relay} ) {
            my $location = $self->{heat_relay}->get_location();
            if ( $self->{heat_relay}->get("PIO") ) {
                if ( exists $self->{heat_sensor} ) {
                    if ( $self->{heat_sensor}->get_voltage() < 1 ) {
                        $state = "$location On";
                    }
                    else {
                        $state = "$location Off (???)";
                    }
                }
            }
            else {
                if ( exists $self->{heat_sensor} ) {
                    if ( $self->{heat_sensor}->get_voltage() < 1 ) {
                        $state = "$location On (Other)";
                    }
                    else {
                        $state = "$location Off";
                    }
                }
            }
        }
        else {
            $state = "No HEATER Available";
        }
    }
    elsif ( $self->{system_mode} eq 'cool' ) {
        if ( exists $self->{cool_relay} ) {
            my $location = $self->{cool_relay}->get_location();
            if ( $self->{cool_relay}->get("PIO") ) {
                if ( exists $self->{cool_sensor} ) {
                    if ( $self->{cool_sensor}->get_voltage() < 1 ) {
                        $state = "$location On";
                    }
                    else {
                        $state = "$location Off (???)";
                    }
                }
                else {
                    $state = "$location On";
                }
            }
            else {
                if ( exists $self->{cool_sensor} ) {
                    if ( $self->{cool_sensor}->get_voltage() < 1 ) {
                        $state = "$location On (Other)";
                    }
                    else {
                        $state = "$location Off";
                    }
                }
                else {
                    $state = "$location Off";
                }
            }
        }
        else {
            $state = "No COOL Available";
        }
    }
}

sub set_temp_sp {
    my ( $self, $temp_sp ) = @_;
    if ( ( $temp_sp >= 60 ) && ( $temp_sp <= 80 ) ) {
        &main::logit(
            "$::config_parms{data_dir}/logs/hvac/$::Year_Month_Now.log",
            "Set Point change to $temp_sp",
            , 1
        );
        $self->{temp_sp} = $temp_sp;
    }
}

sub get_temp_sp {
    my ($self) = @_;
    return $self->{temp_sp};
}

sub set_hold {
    my ( $self, $hold ) = @_;
    $self->{hold} = $hold;
    if ( $self->{hold} ) {
        if ( $self->{hold_timer} =~ /^(\d+):(\d+)$/ ) {
            my $hour    = $1;
            my $min     = $2;
            my $seconds = ( $hour * 3600 ) + ( $min * 60 );
            if ($seconds) {
                &main::logit(
                    "$::config_parms{data_dir}/logs/hvac/$::Year_Month_Now.log",
                    "Hold Timer change to $hold",, 1
                );
                $self->{t_hold_timer}->set($seconds);
            }
        }
    }
    else {
        $self->{t_hold_timer}->set(0);
    }
}

sub get_hold {
    my ($self) = @_;
    return $self->{hold};
}

sub set_hold_timer {
    my ( $self, $hold_timer ) = @_;
    if ( $hold_timer =~ /^\d+:\d+$/ ) {
        $self->{hold_timer} = $hold_timer;
    }
}

sub get_hold_timer {
    my ($self) = @_;
    return $self->{hold_timer};
}

sub get_hold_timer_remain {
    my ($self) = @_;
    my $hour   = 0;
    my $min    = 0;
    if ( $self->{t_hold_timer}->active() ) {
        $min = $self->{t_hold_timer}->minutes_remaining();
        $min =~ s/^(\d+)\.(.*)/$1/;
        if ( $min > 60 ) {
            $hour = $min / 60;
            $min  = $min % 60;
        }
    }
    return ("$hour:$min");
}

sub get_temperatures {
    my ($self) = @_;
    my %temps;
    foreach my $thermometer ( keys %{ $self->{thermometers} } ) {
        my $location = $self->{thermometers}{$thermometer}->get_location();
        my $zone     = $self->{thermometers}{$thermometer}->get_key("zone");
        my $temp     = $self->{last_reading}{$location};
        $location .= " [$zone]";
        $temps{$location} = $temp;
    }
    foreach my $zone ( @{ $self->{zone} } ) {
        if ( exists $zone->{name} ) {
            my $num      = $zone->{name};
            my $location = "ZONE $num";
            $temps{$location} = $zone->{average};
        }
    }
    return %temps;
}

sub restore_defaults {
    my ($self) = @_;
    my @schedule;
    for ( my $i = 0; $i < 7; $i++ ) {
        $schedule[$i][0][0] = "06:00 AM";
        $schedule[$i][1][0] = "09:00 AM";
        $schedule[$i][2][0] = "05:00 PM";
        $schedule[$i][3][0] = "11:00 PM";
        for ( my $j = 0; $j < 4; $j++ ) {
            $schedule[$i][$j][1] = 70;
            $schedule[$i][$j][2] = 1;
        }
    }
    $self->set_schedule(@schedule);
}

sub set_schedule {
    my ( $self, @schedule ) = @_;
    $self->{sun_0_time} = $schedule[0][0][0];
    $self->{sun_0_temp} = $schedule[0][0][1];
    $self->{sun_0_zone} = $schedule[0][0][2];
    $self->{sun_1_time} = $schedule[0][1][0];
    $self->{sun_1_temp} = $schedule[0][1][1];
    $self->{sun_1_zone} = $schedule[0][1][2];
    $self->{sun_2_time} = $schedule[0][2][0];
    $self->{sun_2_temp} = $schedule[0][2][1];
    $self->{sun_2_zone} = $schedule[0][2][2];
    $self->{sun_3_time} = $schedule[0][3][0];
    $self->{sun_3_temp} = $schedule[0][3][1];
    $self->{sun_3_zone} = $schedule[0][3][2];
    $self->{mon_0_time} = $schedule[1][0][0];
    $self->{mon_0_temp} = $schedule[1][0][1];
    $self->{mon_0_zone} = $schedule[1][0][2];
    $self->{mon_1_time} = $schedule[1][1][0];
    $self->{mon_1_temp} = $schedule[1][1][1];
    $self->{mon_1_zone} = $schedule[1][1][2];
    $self->{mon_2_time} = $schedule[1][2][0];
    $self->{mon_2_temp} = $schedule[1][2][1];
    $self->{mon_2_zone} = $schedule[1][2][2];
    $self->{mon_3_time} = $schedule[1][3][0];
    $self->{mon_3_temp} = $schedule[1][3][1];
    $self->{mon_3_zone} = $schedule[1][3][2];
    $self->{tue_0_time} = $schedule[2][0][0];
    $self->{tue_0_temp} = $schedule[2][0][1];
    $self->{tue_0_zone} = $schedule[2][0][2];
    $self->{tue_1_time} = $schedule[2][1][0];
    $self->{tue_1_temp} = $schedule[2][1][1];
    $self->{tue_1_zone} = $schedule[2][1][2];
    $self->{tue_2_time} = $schedule[2][2][0];
    $self->{tue_2_temp} = $schedule[2][2][1];
    $self->{tue_2_zone} = $schedule[2][2][2];
    $self->{tue_3_time} = $schedule[2][3][0];
    $self->{tue_3_temp} = $schedule[2][3][1];
    $self->{tue_3_zone} = $schedule[2][3][2];
    $self->{wed_0_time} = $schedule[3][0][0];
    $self->{wed_0_temp} = $schedule[3][0][1];
    $self->{wed_0_zone} = $schedule[3][0][2];
    $self->{wed_1_time} = $schedule[3][1][0];
    $self->{wed_1_temp} = $schedule[3][1][1];
    $self->{wed_1_zone} = $schedule[3][1][2];
    $self->{wed_2_time} = $schedule[3][2][0];
    $self->{wed_2_temp} = $schedule[3][2][1];
    $self->{wed_2_zone} = $schedule[3][2][2];
    $self->{wed_3_time} = $schedule[3][3][0];
    $self->{wed_3_temp} = $schedule[3][3][1];
    $self->{wed_3_zone} = $schedule[3][3][2];
    $self->{thu_0_time} = $schedule[4][0][0];
    $self->{thu_0_temp} = $schedule[4][0][1];
    $self->{thu_0_zone} = $schedule[4][0][2];
    $self->{thu_1_time} = $schedule[4][1][0];
    $self->{thu_1_temp} = $schedule[4][1][1];
    $self->{thu_1_zone} = $schedule[4][1][2];
    $self->{thu_2_time} = $schedule[4][2][0];
    $self->{thu_2_temp} = $schedule[4][2][1];
    $self->{thu_2_zone} = $schedule[4][2][2];
    $self->{thu_3_time} = $schedule[4][3][0];
    $self->{thu_3_temp} = $schedule[4][3][1];
    $self->{thu_3_zone} = $schedule[4][3][2];
    $self->{fri_0_time} = $schedule[5][0][0];
    $self->{fri_0_temp} = $schedule[5][0][1];
    $self->{fri_0_zone} = $schedule[5][0][2];
    $self->{fri_1_time} = $schedule[5][1][0];
    $self->{fri_1_temp} = $schedule[5][1][1];
    $self->{fri_1_zone} = $schedule[5][1][2];
    $self->{fri_2_time} = $schedule[5][2][0];
    $self->{fri_2_temp} = $schedule[5][2][1];
    $self->{fri_2_zone} = $schedule[5][2][2];
    $self->{fri_3_time} = $schedule[5][3][0];
    $self->{fri_3_temp} = $schedule[5][3][1];
    $self->{fri_3_zone} = $schedule[5][3][2];
    $self->{sat_0_time} = $schedule[6][0][0];
    $self->{sat_0_temp} = $schedule[6][0][1];
    $self->{sat_0_zone} = $schedule[6][0][2];
    $self->{sat_1_time} = $schedule[6][1][0];
    $self->{sat_1_temp} = $schedule[6][1][1];
    $self->{sat_1_zone} = $schedule[6][1][2];
    $self->{sat_2_time} = $schedule[6][2][0];
    $self->{sat_2_temp} = $schedule[6][2][1];
    $self->{sat_2_zone} = $schedule[6][2][2];
    $self->{sat_3_time} = $schedule[6][3][0];
    $self->{sat_3_temp} = $schedule[6][3][1];
    $self->{sat_3_zone} = $schedule[6][3][2];
}

sub get_schedule {
    my ($self) = @_;
    my @schedule = ();
    $schedule[0][0][0] = $self->{sun_0_time};
    $schedule[0][0][1] = $self->{sun_0_temp};
    $schedule[0][0][2] = $self->{sun_0_zone};
    $schedule[0][1][0] = $self->{sun_1_time};
    $schedule[0][1][1] = $self->{sun_1_temp};
    $schedule[0][1][2] = $self->{sun_1_zone};
    $schedule[0][2][0] = $self->{sun_2_time};
    $schedule[0][2][1] = $self->{sun_2_temp};
    $schedule[0][2][2] = $self->{sun_2_zone};
    $schedule[0][3][0] = $self->{sun_3_time};
    $schedule[0][3][1] = $self->{sun_3_temp};
    $schedule[0][3][2] = $self->{sun_3_zone};
    $schedule[1][0][0] = $self->{mon_0_time};
    $schedule[1][0][1] = $self->{mon_0_temp};
    $schedule[1][0][2] = $self->{mon_0_zone};
    $schedule[1][1][0] = $self->{mon_1_time};
    $schedule[1][1][1] = $self->{mon_1_temp};
    $schedule[1][1][2] = $self->{mon_1_zone};
    $schedule[1][2][0] = $self->{mon_2_time};
    $schedule[1][2][1] = $self->{mon_2_temp};
    $schedule[1][2][2] = $self->{mon_2_zone};
    $schedule[1][3][0] = $self->{mon_3_time};
    $schedule[1][3][1] = $self->{mon_3_temp};
    $schedule[1][3][2] = $self->{mon_3_zone};
    $schedule[2][0][0] = $self->{tue_0_time};
    $schedule[2][0][1] = $self->{tue_0_temp};
    $schedule[2][0][2] = $self->{tue_0_zone};
    $schedule[2][1][0] = $self->{tue_1_time};
    $schedule[2][1][1] = $self->{tue_1_temp};
    $schedule[2][1][2] = $self->{tue_1_zone};
    $schedule[2][2][0] = $self->{tue_2_time};
    $schedule[2][2][1] = $self->{tue_2_temp};
    $schedule[2][2][2] = $self->{tue_2_zone};
    $schedule[2][3][0] = $self->{tue_3_time};
    $schedule[2][3][1] = $self->{tue_3_temp};
    $schedule[2][3][2] = $self->{tue_3_zone};
    $schedule[3][0][0] = $self->{wed_0_time};
    $schedule[3][0][1] = $self->{wed_0_temp};
    $schedule[3][0][2] = $self->{wed_0_zone};
    $schedule[3][1][0] = $self->{wed_1_time};
    $schedule[3][1][1] = $self->{wed_1_temp};
    $schedule[3][1][2] = $self->{wed_1_zone};
    $schedule[3][2][0] = $self->{wed_2_time};
    $schedule[3][2][1] = $self->{wed_2_temp};
    $schedule[3][2][2] = $self->{wed_2_zone};
    $schedule[3][3][0] = $self->{wed_3_time};
    $schedule[3][3][1] = $self->{wed_3_temp};
    $schedule[3][3][2] = $self->{wed_3_zone};
    $schedule[4][0][0] = $self->{thu_0_time};
    $schedule[4][0][1] = $self->{thu_0_temp};
    $schedule[4][0][2] = $self->{thu_0_zone};
    $schedule[4][1][0] = $self->{thu_1_time};
    $schedule[4][1][1] = $self->{thu_1_temp};
    $schedule[4][1][2] = $self->{thu_1_zone};
    $schedule[4][2][0] = $self->{thu_2_time};
    $schedule[4][2][1] = $self->{thu_2_temp};
    $schedule[4][2][2] = $self->{thu_2_zone};
    $schedule[4][3][0] = $self->{thu_3_time};
    $schedule[4][3][1] = $self->{thu_3_temp};
    $schedule[4][3][2] = $self->{thu_3_zone};
    $schedule[5][0][0] = $self->{fri_0_time};
    $schedule[5][0][1] = $self->{fri_0_temp};
    $schedule[5][0][2] = $self->{fri_0_zone};
    $schedule[5][1][0] = $self->{fri_1_time};
    $schedule[5][1][1] = $self->{fri_1_temp};
    $schedule[5][1][2] = $self->{fri_1_zone};
    $schedule[5][2][0] = $self->{fri_2_time};
    $schedule[5][2][1] = $self->{fri_2_temp};
    $schedule[5][2][2] = $self->{fri_2_zone};
    $schedule[5][3][0] = $self->{fri_3_time};
    $schedule[5][3][1] = $self->{fri_3_temp};
    $schedule[5][3][2] = $self->{fri_3_zone};
    $schedule[6][0][0] = $self->{sat_0_time};
    $schedule[6][0][1] = $self->{sat_0_temp};
    $schedule[6][0][2] = $self->{sat_0_zone};
    $schedule[6][1][0] = $self->{sat_1_time};
    $schedule[6][1][1] = $self->{sat_1_temp};
    $schedule[6][1][2] = $self->{sat_1_zone};
    $schedule[6][2][0] = $self->{sat_2_time};
    $schedule[6][2][1] = $self->{sat_2_temp};
    $schedule[6][2][2] = $self->{sat_2_zone};
    $schedule[6][3][0] = $self->{sat_3_time};
    $schedule[6][3][1] = $self->{sat_3_temp};
    $schedule[6][3][2] = $self->{sat_3_zone};
    return (@schedule);
}

sub get_schedule_sp {
    my $self = shift;
    my ( $currTemp, $currZone, $index );
    my @schedule = $self->get_schedule();
    my $dayIndex = $main::Wday - 1;
    if ( $dayIndex < 0 ) {
        $dayIndex = 6;
    }
    $index    = 3;
    $currTemp = $schedule[$dayIndex][$index][1];
    $currZone = $schedule[$dayIndex][$index][2];
    $dayIndex = $main::Wday;
    for ( $index = 0; $index < 4; $index++ ) {
        if (
            &main::time_less_than(
                $self->time_from_ampm( $schedule[$dayIndex][$index][0] )
            )
          )
        {
            return ( $currTemp, $currZone );
        }
        $currTemp = $schedule[$dayIndex][$index][1];
        $currZone = $schedule[$dayIndex][$index][2];
    }
    return ( $currTemp, $currZone );
}

#--------------------------------------------------------------------------------------------------------
#
# FUNCTIONS
#
#--------------------------------------------------------------------------------------------------------

sub time_from_ampm {
    my ( $self, $time ) = @_;
    $time =~ /(.*):(.*) (.*)/;
    my $hour = $1;
    my $min  = $2;
    my $ampm = $3;
    $ampm = lc($ampm);
    $hour += 12 if ( $ampm eq 'pm' );
    $hour = 12 if ( $hour >= 24 );
    return ("$hour:$min");
}

sub heat_relay {
    my ( $self, $value ) = @_;
    if ( exists $self->{heat_relay} ) {
        my $current = $self->{heat_relay}->get("PIO");
        if ( $current != $value ) {
            $self->{heat_relay}->set( "PIO", $value );
            my $display   = $value ? "On" : "Off";
            my $zone_temp = $self->{zone}->[ $self->{temp_zone} ]->{average};
            my $sp        = $self->{temp_sp};
            &main::logit(
                "$::config_parms{data_dir}/logs/hvac/$::Year_Month_Now.log",
                "Heat $display zone_temp: $zone_temp temp_sp: $sp",
                , 1
            );
        }
    }
}

sub cool_relay {
    my ( $self, $value ) = @_;
    if ( exists $self->{cool_relay} ) {
        my $current = $self->{cool_relay}->get("PIO");
        if ( $current != $value ) {
            if ( !$value && $self->{t_on_timer}->active() ) {
                &main::print_log("Waiting for on_timer to expire ...")
                  if $::Debug{owfs};
            }
            elsif ( $value && $self->{t_off_timer}->active() ) {
                &main::print_log("Waiting for off_timer to expire ...")
                  if $::Debug{owfs};
            }
            else {
                $self->{cool_relay}->set( "PIO", $value );
                if ( $self->{fan_mode} eq 'auto' ) {
                    $self->fan_relay($value);
                }
                if ($value) {
                    $self->{t_on_timer}->set( $self->{on_timer_value} * 60 );
                }
                else {
                    $self->{t_off_timer}->set( $self->{off_timer_value} * 60 );
                }
                my $display = $value ? "On" : "Off";
                my $zone_temp =
                  $self->{zone}->[ $self->{temp_zone} ]->{average};
                my $sp = $self->{temp_sp};
                &main::logit(
                    "$::config_parms{data_dir}/logs/hvac/$::Year_Month_Now.log",
                    "Cool $display zone_temp: $zone_temp temp_sp: $sp",, 1
                );
            }
        }
    }
}

sub fan_relay {
    my ( $self, $value ) = @_;
    if ( exists $self->{fan_relay} ) {
        my $current = $self->{fan_relay}->get("PIO");
        if ( $current != $value ) {
            $self->{fan_relay}->set( "PIO", $value );
            my $display   = $value ? "On" : "Off";
            my $zone_temp = $self->{zone}->[ $self->{temp_zone} ]->{average};
            my $sp        = $self->{temp_sp};
            &main::logit(
                "$::config_parms{data_dir}/logs/hvac/$::Year_Month_Now.log",
                "Fan $display $zone_temp temp_sp: $sp",
                , 1
            );
        }
    }
}

sub dump {
    my $self = shift;
    print "\n";
    for my $key ( sort keys %$self ) {
        print "$key:\t\t$$self{$key}\n";
    }
    print "\n";
}

#--------------------------------------------------------------------------------------------------------
#
# MAIN RUN LOOP
#
#--------------------------------------------------------------------------------------------------------

sub run_loop {
    my $self = shift;
    &::print_log("Owfs_Thermostat::run_loop $self->{index}") if $::Debug{owfs};

    my @thermometers    = keys %{ $self->{thermometers} };
    my $numThermometers = @thermometers;

    # fetch information from the next thermometer
    my $thermometer = $thermometers[ $self->{index} ];
    if ( $self->{thermometers}{$thermometer}->get("present") ) {

        # fetch the temperatures
        &::print_log("Owfs_Thermostat::fetch $thermometer") if $::Debug{owfs};
        my $location = $self->{thermometers}{$thermometer}->get_location();
        my $temp     = $self->{thermometers}{$thermometer}->get("temperature");
        my $zone     = $self->{thermometers}{$thermometer}->get_key("zone");

        # convert to fahrenheit
        $temp = ( ( $temp * 9 ) / 5 ) + 32;

        # store result in temps array for averaging
        if ( ( $temp > 0 ) && ( $temp < 85 ) ) {
            push( @{ $self->{zone}->[$zone]->{temps} }, $temp );
        }

        # save last official reading
        my $location = $self->{thermometers}{$thermometer}->get_location();
        $self->{last_reading}{$location} = $temp;
    }

    # udpate the index
    $self->{index} += 1;

    if ( ( $self->{index} % $numThermometers ) == 0 ) {
        $self->{index} = 0;
        my $totalSum = 0;
        my $totalNum = 0;
        foreach my $zone ( @{ $self->{zone} } ) {
            if ( exists $zone->{name} ) {
                my $num = $zone->{name};

                # average the temperatures if we counted any
                my $zoneNum =
                  exists( $zone->{temps} ) ? @{ $zone->{temps} } : ();
                if ($zoneNum) {
                    my $zoneSum = 0;
                    foreach my $temp ( @{ $zone->{temps} } ) {
                        $zoneSum += $temp;
                    }
                    my $zoneAve = $zoneSum / $zoneNum;
                    $zone->{average} = $zoneAve;
                    $totalSum += $zoneAve;
                    $totalNum++;
                }

                # reset the temperature array and index indicator
                @{ $zone->{temps} } = ();
            }
        }
        if ($totalNum) {
            my $totalAve = $totalSum / $totalNum;
            $::Weather{TempIndoor} = $totalAve;
        }
    }

    # reschedule the timer for next pass
    $self->{t_run_timer}
      ->set( $self->{interval}, sub { &Owfs_Thermostat::run_loop($self) } );

    # has the hold timer expired?
    if ( $self->{t_hold_timer}->inactive() ) {
        $self->{hold} = 0;
    }

    # fetch current schedule if not in hold system_mode
    if ( !$self->{hold} ) {
        ( $self->{temp_sp}, $self->{temp_zone} ) = $self->get_schedule_sp();
    }

    # system off - turn off all relays
    if ( $self->{system_mode} eq 'off' ) {
        $self->heat_relay(0);
        if ( $self->{t_on_timer}->active() ) {
            $self->{t_on_timer}->stop();
        }
        $self->cool_relay(0);
        $self->fan_relay(0);
    }

    # turn on/off heat relay
    if ( $self->{system_mode} eq 'heat' ) {
        $self->cool_relay(0);
        $self->fan_relay(0);
        if ( exists $self->{zone}->[ $self->{temp_zone} ]->{average} ) {
            if (
                ( $self->{temp_sp} < 75 )
                && ( $self->{temp_sp} >
                    $self->{zone}->[ $self->{temp_zone} ]->{average} )
                && (   ( not exists $::Weather{TempOutdoor} )
                    || ( $::Weather{TempOutdoor} < $self->{temp_sp} )
                    || $self->{hold} )
              )
            {
                &::print_log("turning heat on") if $::Debug{owfs};
                $self->heat_relay(1);
            }
            else {
                &::print_log("turning heat off") if $::Debug{owfs};
                $self->heat_relay(0);
            }
        }
    }

    # turn on/off cool relay
    if ( $self->{system_mode} eq 'cool' ) {
        $self->heat_relay(0);
        if ( exists $self->{zone}->[ $self->{temp_zone} ]->{average} ) {
            if (
                ( $self->{temp_sp} >= 70 )
                && ( $self->{temp_sp} <
                    $self->{zone}->[ $self->{temp_zone} ]->{average} )
                && (   ( not exists $::Weather{TempOutdoor} )
                    || ( $::Weather{TempOutdoor} >= ( $self->{temp_sp} - 2 ) )
                    || 1
                    || $self->{hold} )
              )
            {
                &::print_log("turning cool on") if $::Debug{owfs};
                $self->cool_relay(1);
            }
            else {
                &::print_log("turning cool off") if $::Debug{owfs};
                $self->cool_relay(0);
            }
        }
    }

    # turn on fan relay
    if ( $self->{system_mode} eq 'cool' ) {
        if ( $self->{fan_mode} eq 'on' ) {
            $self->fan_relay(1);
        }
    }

}

1;

=back

=head2 INI PARAMETERS

owfs_on_timer_value = 3       # minimum A/C compressor ON time
owfs_off_timer_value = 3      # minimum A/C compressor OFF time

=head2 AUTHOR

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

