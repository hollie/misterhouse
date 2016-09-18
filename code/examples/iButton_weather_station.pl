# Category=Weather
#
# Interface to DS2450 based 1-Wire weather stations.
# Max Lock 12/08.

use iButton;
use Weather_Common;

$ib_wind_dir     = new iButton '2000000000F521';
$ib_wind_speed   = new iButton '1D0000000151A3';
$ib_temp_outside = new iButton '100008000948F7';

use vars '%weather';
my $delta_i;
my %delta;
my %iButton_data_avg_data;
my $wind_time2;
my $last_wind_count;
my @wind_speed;
my @wind_cos;
my @wind_sin;

&read_iButton_temp($ib_temp_outside)
  if $New_Second and ( $Second == 45 or $Second == 15 );
&iButton_wind_read if ( $New_Second and !( $Second % 15 ) );

&setup_ds2450($ib_wind_dir) if $Startup;

#if (time_cron('* * * * *') || $Startup) {
if ( time_cron('* * * * *') ) {
    #
    # Define the source variables
    $Weather{DewOutdoor};    # used in status line
    $Weather{TempOutdoor} = state $ib_temp_outside;    # used in status line
    $Weather{WindDir}     = state $ib_wind_dir;
    $Weather{WindSpeed}   = state $ib_wind_speed;
    #
    # Define the derived variables
    $Weather{WindGustDir} =
      $Weather{WindDir};    # Whats the relation between Dir and GustDir?
    $Weather{WindAvgDir}    = &average_wind_dir( $Weather{WindDir} );
    $Weather{WindGustSpeed} = $Weather{WindSpeed}
      if $Weather{WindSpeed} > $Weather{WindGustSpeed};
    $Weather{WindAvgSpeed} = &average_wind_speed( $Weather{WindSpeed} );
    $Weather{WindChill} =
      &windchill( $Weather{TempOutdoor}, $Weather{WindAvgSpeed} );
    #
    # Log variables
    $Weather{SummaryWind} = sprintf(
        "cur/avg %s(%3.1f)/%s(%3.1f) %3.1f%s/%3.1f%s",
        ( &convert_wind_dir_to_abbr( $Weather{WindDir} ) ),
        $Weather{WindDir},
        ( &convert_wind_dir_to_abbr( $Weather{WindAvgDir} ) ),
        $Weather{WindAvgDir},
        $Weather{WindSpeed},
        $main::config_parms{weather_uom_wind},
        $Weather{WindAvgSpeed},
        $main::config_parms{weather_uom_wind}
    );
    $Weather{SummaryTemp} = sprintf( "%3.1f%s",
        $Weather{TempOutdoor}, $main::config_parms{weather_uom_temp} );
    #
    print_log "Wind $Weather{SummaryWind}, Temperature $Weather{SummaryTemp}";
    &Weather_Common::weather_updated;
}

### Only subroutines below this point ###

sub deg_to_rad {
    ( $_[0] / 180 ) * ( 4 * atan2( 1, 1 ) );
}    # convert degrees to radians

sub rad_to_deg {
    ( $_[0] / ( 4 * atan2( 1, 1 ) ) ) * 180;
}    # convert radians to degrees

sub average_wind_dir {
    my $readings = 10;
    my $sum_wind_sin;
    my $sum_wind_cos;
    push( @wind_sin, sin( &deg_to_rad( $_[0] ) ) );
    push( @wind_cos, cos( &deg_to_rad( $_[0] ) ) );
    if ( ( scalar(@wind_cos) ) == ( $readings + 1 ) ) { shift @wind_cos }
    if ( ( scalar(@wind_sin) ) == ( $readings + 1 ) ) { shift @wind_sin }
    foreach (@wind_sin) { $sum_wind_sin += $_ }
    foreach (@wind_cos) { $sum_wind_cos += $_ }
    my $avg_wind_dir = &rad_to_deg( atan2( $sum_wind_sin, $sum_wind_cos ) );
    if ( $avg_wind_dir < 0 ) { $avg_wind_dir += 359; }
    $avg_wind_dir = sprintf( "%.0f", $avg_wind_dir );
    return $avg_wind_dir;
}

sub average_wind_speed {
    my $readings = 10;
    my $avg_wind_speed;
    push( @wind_speed, $_[0] );
    if ( ( scalar(@wind_speed) ) == ( $readings + 1 ) ) { shift @wind_speed }
    foreach (@wind_speed) { $avg_wind_speed += $_ }
    $avg_wind_speed = $avg_wind_speed / scalar(@wind_speed);
    return $avg_wind_speed;
}

sub convert_wind_dir_to_abbr {
    my ($dir) = @_;
    return 'unknown' if $dir !~ /^[\d \.]+$/;
    if ( $dir >= 0 and $dir <= 360 ) {
        return
          qw{North NNE NE ENE East ESE SE SSE South SSW SW WSW West WNW NW NNW North}
          [ ( ( $dir + 11.25 ) / 22.5 ) % 16 ];
    }
    return 'unknown';
}

sub windchill {
    my $temp = shift;
    my $wind = shift;
    my $chill;

    if ( ( $wind < 5 ) || ( $wind > 100 ) || ( $temp < -50 ) || ( $temp > 5 ) )
    {
        $chill = '';
    }
    else {
        $chill =
          ( 13.12 + 0.6215 * $temp -
              11.37 * ( $wind**0.16 ) +
              0.3965 * $temp * ( $wind**0.16 ) );
        $chill = int( $chill + 0.5 );
        print "temp $temp wind $wind chill $chill\n";
    }
    return $chill;
}

sub iButton_wind_read {
    #
    #wind speed (mph)
    #
    my $wind_time1 = &get_tickcount;
    my $count =
      $ib_wind_speed->Hardware::iButton::Device::DS2423::read_counter();
    #
    if ($wind_time2) {
        my $revolution_sec =
          ( ( $count - $last_wind_count ) * 1000 ) /
          ( $wind_time1 - $wind_time2 ) / 2.0;
        set $ib_wind_speed sprintf( "%3.2f", $revolution_sec * 2.453 );
    }
    #
    $last_wind_count = $count;
    $wind_time2      = $wind_time1;
    $Save{WindGustMax} = 0 if $New_Day;
    #
    # wind direction (c)
    #
    my %position_lookup = ();
    $position_lookup{'HHLH'} = 1;
    $position_lookup{'HMMH'} = 2;
    $position_lookup{'HLHH'} = 3;
    $position_lookup{'MMHH'} = 4;
    $position_lookup{'LHHH'} = 5;
    $position_lookup{'LHHZ'} = 6;
    $position_lookup{'HHHZ'} = 7;
    $position_lookup{'HHZZ'} = 8;
    $position_lookup{'HHZH'} = 9;
    $position_lookup{'HZZH'} = 10;
    $position_lookup{'HZHH'} = 11;
    $position_lookup{'ZZHH'} = 12;
    $position_lookup{'ZHHH'} = 13;
    $position_lookup{'ZHHL'} = 14;
    $position_lookup{'HHHL'} = 15;
    $position_lookup{'HHMM'} = 16;
    #
    my $wind_adc_states = &read_ds2450($ib_wind_dir);
    my $wind_position   = $position_lookup{$wind_adc_states};
    $Weather{WindDir} = sprintf( "%3.1f", ( $wind_position * 22.5 ) );
    set $ib_wind_dir $Weather{WindDir};
}

sub read_iButton_temp {
    my @ib_list = @_;
    for my $ib (@ib_list) {
        my $temp = $ib->read_temperature_hires();
        next if $temp < -20 or $temp > 120;
        my $temp_c = sprintf( "%3.2f", $temp );
        my $temp_f = sprintf( "%3.2f", $temp * 9 / 5 + 32 );
        my $serial = $ib->serial();

        # Average the last 5 entries
        if ( defined @{ $iButton_data_avg_data{$serial} } ) {
            unshift( @{ $iButton_data_avg_data{$serial} }, $temp_c );
            pop( @{ $iButton_data_avg_data{$serial} } );
        }
        else {
            @{ $iButton_data_avg_data{$serial} } = ($temp_c) x 5;
        }

        my $iButton_data_avg = 0;
        grep( $iButton_data_avg += $_, @{ $iButton_data_avg_data{$serial} } );
        $iButton_data_avg /= 5;
        $ib->{state} = sprintf( "%3.1f", $iButton_data_avg );
    }
}

sub read_ds2450 {

    # Read ds2450 adc's and return a 4 character string representing their states
    # H=high,M=medium,L=low,Z=zero
    #
    $ib_wind_dir->Hardware::iButton::Device::DS2450::convert('all');
    my ( $A, $B, $C, $D ) =
      $ib_wind_dir->Hardware::iButton::Device::DS2450::readAD('all');
    my $channel_A_state = &volts_to_state($A);
    my $channel_B_state = &volts_to_state($B);
    my $channel_C_state = &volts_to_state($C);
    my $channel_D_state = &volts_to_state($D);
    return
        $channel_A_state
      . $channel_B_state
      . $channel_C_state
      . $channel_D_state;
}

sub volts_to_state {

    # Calculate state from voltage
    my $volts = $_[0];
    my $state = 'Z';
    if ( $volts >= 2 ) { $state = 'L' }
    if ( $volts >= 3 ) { $state = 'M' }
    if ( $volts >= 4 ) { $state = 'H' }
    return $state;
}

sub setup_ds2450 {
    my $ibutton = $_[0];
    my $VCC     = 0;
    my %A;
    my %B;
    my %C;
    my %D;
    my $setupds2450 = 0;
    until ( $setupds2450 == 1 ) {
        #
        $A{type}       = "AD";
        $A{resolution} = 4;
        $A{range}      = 5.12;
        $B{type}       = "AD";
        $B{resolution} = 4;
        $B{range}      = 5.12;
        $C{type}       = "AD";
        $C{resolution} = 4;
        $C{range}      = 5.12;
        $D{type}       = "AD";
        $D{resolution} = 4;
        $D{range}      = 5.12;
        #
        if (
            $ib_wind_dir->Hardware::iButton::Device::DS2450::setup(
                $VCC, \%A, \%B, \%C, \%D
            )
          )
        {
            $setupds2450 = 1;
        }
        if ( $setupds2450 = 1 ) {
            print_log "Initialised weather station DS2450";
        }
        else {
            print_log
              "Failed to initialise weather station DS2450, retrying...";
            sleep 1;
        }
    }
}

