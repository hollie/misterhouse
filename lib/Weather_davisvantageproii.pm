package Weather_davisvantageproii;

# $Date$
# $Revision$

use strict;
use Weather_Common;

#!#!#!# eval 'use Digest::mhCRC qw(crc16);';
#!#!#!# if ($@) {
#!#!#!#	die("Weather_davisvantageproii:  Can't find the Digest::mhCRC package (mhCRC.pm).  Please ensure that it is installed.\n$@");
#!#!#!#}

=begin comment
=============================================================================
Davis VantagePro 2 Weather Station Interface for MH
Version 0.1 - Alpha Test
12/4/2010

By: Brian Klier

Modified from Scott Huskey's Davis Weather Monitor II Code.

Note: You must enable this module by setting the following parameters in mh{.private}.ini.
    Obviously you must point the port to the actual port to which the station is connected.
	serial_davisvantageproii_port=COM3
	serial_davisvantageproii_baudrate=19200
	serial_davisvantageproii_datatype=raw
	serial_davisvantageproii_module=Weather_davisvantageproii

=============================================================================
=cut

our $wakeupCommand = chr(10);
our $loopCommand = join "", "LOOP", chr(255), chr(255), chr(49), chr(10);
our $DavisVP_port;

#our $lastRainReading = undef;
#our $lastRainReadingTime = undef;

our (
    $barometric_trend,  $next_rec,             $barometric_press,
    $air_temp_inside,   $humidity_inside,      $air_temp,
    $wind_speed,        $wind_speed_10min_ave, $wind_direction,
    $relative_humidity, $rain_rate,            $uv,
    $solar,             $rain_storm,           $storm_date,
    $rain_day,          $rain_month,           $rain_year,
    $day_ET,            $month_ET,             $year_ET,
    $alarms_inside,     $alarms_rain,          $alarms_outside,
    $batt_xmit,         $batt_cons,            $forecast_icon,
    $forecast_rule,     $sunrise,              $sunset,
    $dew_point_inside,  $dew_point_outside,    $crc,
    $crc_calc,          $wptr,                 $data
);

sub startup {
    my ($instance) = @_;
    $DavisVP_port = new Serial_Item( undef, undef, 'serial_davisvantageproii' );
    &requestData;
    &::MainLoop_pre_add_hook( \&Weather_davisvantageproii::update, 1 );
    &::trigger_set(
        '$New_Minute', '&Weather_davisvantageproii::requestData',
        'NoExpire',    'davisvantageproii data request'
    ) unless &::trigger_get('davisvantageproii data request');
}

sub wake_up {
    my $self = shift @_;

    foreach ( 1 .. 3 ) {
        $DavisVP_port->set($wakeupCommand);
        my $str = said $DavisVP_port;
        ###my ($cnt_in, $str) = $self->read(2);

        if ( $str eq "\n\r" ) {
            &::print_log("davisvantageproii: success on wakeup")
              if $::Debug{weather};
            return 1;
        }

        &::print_log("davisvantageproii: no wakeup response")
          if $::Debug{weather};

        sleep 1;    # As per page 5 of VantagePro Doc
    }

    &::print_log("davisvantageproii: could not wake up unit")
      if $::Debug{weather};
    return 1;       # fail
}

# called by trigger every minute
sub requestData {
    &::print_log("davisvantageproii: requesting new data from station")
      if $::Debug{weather};

    #!#!#!#! &wake_up;
    $DavisVP_port->set($wakeupCommand);
    $DavisVP_port->set($loopCommand);
}

# called once per loop
sub update {
    return unless my $data = said $DavisVP_port;
    my $remainder = &process( $data, \%main::Weather );
    $DavisVP_port->set_data($remainder) if $remainder ne '';
    &weather_updated;
}

# Parse DavisVP datastream into array pointed at with $wptr so Mr House
# can use the information
#

sub process {

    my ( $data, $wptr ) = @_;
    my @data = unpack( 'C*', $data );

    if ( $::Debug{weather} ) {
        my $debugInfo = 'davisvantageproii: Read from Davis VantagePro II ';
        for (@data) {
            $debugInfo .= sprintf( "0x%x ", $_ );
        }
        &::print_log($debugInfo);
    }

    my $data = shift @_;
    my $loo  = substr $data, 0, 3;
    my $ack  = ord substr( $data, 0, 1 );

    if ( $loo eq 'LOO' ) {
        &::print_log("davisvantageproii: found proper LOO header")
          if $::Debug{weather};
    }
    else {
        &::print_log("davisvantageproii: proper LOO header not found")
          if $::Debug{weather};
        return '';
    }

    $barometric_trend = unpack( "C", substr $data, 3, 1 );
    $next_rec         = unpack( "s", substr $data, 5, 2 );
    $barometric_press = unpack( "s", substr $data, 7, 2 ) / 1000;
    $air_temp_inside  = unpack( "s", substr $data, 9, 2 ) / 10;
    if ( $air_temp_inside eq '3276.7' ) { $air_temp_inside = undef }
    $humidity_inside = unpack( "C", substr $data, 11, 1 );
    if ( $humidity_inside eq '255' ) { $humidity_inside = undef }
    $air_temp = unpack( "s", substr $data, 12, 2 ) / 10;
    if ( $air_temp eq '3276.7' ) { $air_temp = undef }
    $wind_speed = unpack( "C", substr $data, 14, 1 );
    if ( $wind_speed eq '255' ) { $wind_speed = undef }
    $wind_speed_10min_ave = unpack( "C", substr $data, 15, 1 );
    if ( $wind_speed_10min_ave eq '255' ) { $wind_speed_10min_ave = undef }
    $wind_direction = unpack( "s", substr $data, 16, 2 );
    if ( $wind_direction eq '32767' ) { $wind_direction = undef }

    # Skip other temps for now...

    $relative_humidity = unpack( "C", substr $data, 33, 1 );
    if ( $relative_humidity eq '255' ) { $relative_humidity = undef }

    # Skip other humidities for now...

    $rain_rate = unpack( "s", substr $data, 41, 2 ) / 100;    # Inches per hr
    if ( $rain_rate < 0 ) { $rain_rate = undef }
    $uv = unpack( "C", substr $data, 43, 1 );
    if ( $uv eq '255' ) { $uv = undef }
    $solar = unpack( "s", substr $data, 44, 2 );              # watt/m**2
    if ( $solar eq '32767' ) { $solar = undef }
    $rain_storm = unpack( "s", substr $data, 46, 2 ) / 100;   # Inches per storm

    $storm_date = unpack( "s", substr $data, 48, 2 )
      ;    # Need to parse data (not sure what this is)
    $rain_day   = unpack( "s", substr $data, 50, 2 ) / 100;
    $rain_month = unpack( "s", substr $data, 52, 2 ) / 100;
    $rain_year  = unpack( "s", substr $data, 54, 2 ) / 100;

    $day_ET   = unpack( "s", substr $data, 56, 2 ) / 1000;
    $month_ET = unpack( "s", substr $data, 58, 2 ) / 100;
    $year_ET  = unpack( "s", substr $data, 60, 2 ) / 100;

    # Skip Soil/Leaf Wetness

    $alarms_inside  = unpack( "b8", substr $data, 70, 1 );
    $alarms_rain    = unpack( "b8", substr $data, 70, 1 );
    $alarms_outside = unpack( "b8", substr $data, 70, 1 );

    # Skip extra alarms

    #  $batt_xmit			= unpack("C", substr $data,86,1) * 0.005859375;
    $batt_xmit = unpack( "C", substr $data, 86, 1 );
    $batt_cons = unpack( "s", substr $data, 87, 2 ) * 0.005859375;

    $forecast_icon = unpack( "C", substr $data, 89, 1 );
    $forecast_rule = unpack( "C", substr $data, 90, 1 );

    $sunrise = sprintf( "%04d", unpack( "S", substr $data, 91, 2 ) );
    $sunrise =~ s/(\d{2})(\d{2})/$1:$2/;

    $sunset = sprintf( "%04d", unpack( "S", substr $data, 93, 2 ) );
    $sunset =~ s/(\d{2})(\d{2})/$1:$2/;

    my $nl = ord substr $data, 95, 1;
    my $cr = ord substr $data, 96, 1;

    $crc = unpack "%n", substr( $data, 97, 2 );
    $crc_calc = CRC_CCITT( substr( $data, 0, 98 ) );

    #  $crc_calc                = CRC_CCITT(substr($data,0,96));

    # $crc_calc			= Digest::mhCRC::crc16(substr($data,0,96));   # MH version
    # $crc_calc			= CRC_CCITT($data);     # 3rd party version

    ### MISTERHOUSE STUFF VVVVV

    #!#!#!#		if (Digest::mhCRC::crc16(substr($data,0,96)) != $crc) {
    #!#!#!#			&::print_log ("davisvantageproii: wrong crc16, looking again for header") if $::Debug{weather};
    #!#!#!#			next;
    #!#!#!#		}

    # I added this next part to throw out packets that don't have a CRC value at all
    if ( $crc eq '0' ) {
        &::print_log("davisvantageproii: wrong crc16, looking again for header")
          if $::Debug{weather};
        next;
    }

    # remove the 99 bytes that we just processed, we'll use the remainder as our return value
    $data = substr( $data, 99 );

    #!#!#!#		last;
## ?	}

    &::print_log("davisvantageproii: found a header with the right checksum")
      if $::Debug{weather};

    # calculate sea level pressure
    my $barometer_sea = convert_local_barom_to_sea_in($barometric_press);

    # 3rd party simple dew point calculation
    #     $dew_point_inside		= $air_temp - ( (100 - $relative_humidity)/5 );
    #     $dew_point_outside		= $air_temp_inside - ( (100 - $humidity_inside)/5 );

    # these dewpoints will be in Celsius
    if ( $humidity_inside ne undef ) {
        $dew_point_inside =
          &::convert_humidity_to_dewpoint( $humidity_inside,
            &::convert_f2c($air_temp_inside) );
    }
    if ( $relative_humidity ne undef ) {
        $dew_point_outside =
          &::convert_humidity_to_dewpoint( $relative_humidity,
            &::convert_f2c($air_temp) );
    }

    #	$rain_rate=undef;
    #	if (defined ($lastRainReadingTime)) {
    #		$rain_rate=($total_rain-$lastRainReading); # delta in inches
    #		my $time_delta=(time - $lastRainReadingTime);
    #		if ($time_delta != 0) {
    #			$rain_rate/=$time_delta; # rate in inches per second
    #			$rain_rate *= 3600; # rate in inches per hour
    #			if ($rain_rate < 0) { # if total rain was reset to zero, this could happen
    #				$rain_rate=0;
    #			}
    #		}
    #	}
    #	$lastRainReadingTime=time;
    #	$lastRainReading=$total_rain;

    if ( $main::config_parms{weather_uom_temp} eq 'C' ) {
        grep { $_ = &::convert_f2c($_); } ( $air_temp_inside, $air_temp );

        # remember, dewpoints are in Celsius by default
    }
    elsif ( $main::config_parms{weather_uom_temp} eq 'F' ) {
        $dew_point_inside = &::convert_c2f($dew_point_inside);
        if ( $relative_humidity ne undef ) {
            $dew_point_outside = &::convert_c2f($dew_point_outside);
        }

        #		grep {$_=&::convert_c2f($_);} (
        #			$dew_point_inside,
        #			$dew_point_outside
        #		);
    }
    if ( $main::config_parms{weather_uom_baro} eq 'mb' ) {
        grep { $_ = &::convert_in2mb($_); }
          ( $barometric_press, $barometer_sea );
    }
    if ( $main::config_parms{weather_uom_rain} eq 'mm' ) {
        grep { $_ = &::convert_in2mm($_); } ($rain_storm);
    }
    if ( $main::config_parms{weather_uom_rain} eq 'mm/hr' ) {
        grep { $_ = &::convert_in2mm($_); } ($rain_rate);
        $rain_rate = sprintf( '%.0f', $rain_rate );    # round to nearest mm/hr
    }
    else {
        $rain_rate =
          sprintf( '%.2f', $rain_rate );    # round to nearest 0.01 in/hr
    }
    if ( $main::config_parms{weather_uom_wind} eq 'kph' ) {
        grep { $_ = &::convert_mile2km($_); } ($wind_speed);
    }
    if ( $main::config_parms{weather_uom_wind} eq 'm/s' ) {
        grep { $_ = &::convert_mph2mps($_); } ($wind_speed);
    }

    $$wptr{TempIndoor}    = $air_temp_inside;
    $$wptr{TempOutdoor}   = $air_temp;
    $$wptr{DewIndoor}     = $dew_point_inside;
    $$wptr{DewOutdoor}    = $dew_point_outside;
    $$wptr{WindAvgSpeed}  = $wind_speed;
    $$wptr{WindGustSpeed} = $wind_speed;
    $$wptr{WindAvgDir}    = $wind_direction;
    $$wptr{WindGustDir}   = $wind_direction;
    $$wptr{Barom}         = $barometric_press;
    $$wptr{BaromSea}      = $barometer_sea;
    $$wptr{HumidIndoor}   = $humidity_inside;
    $$wptr{HumidOutdoor}  = $relative_humidity;
    $$wptr{RainTotal}     = $rain_storm;
    $$wptr{RainRate}      = $rain_rate;

    if ( $::Debug{weather} ) {
        foreach my $key qw(
          TempIndoor
          TempOutdoor
          DewIndoor
          DewOutdoor
          WindAvgSpeed
          WindAvgDir
          Barom
          BaromSea
          HumidIndoor
          HumidOutdoor
          RainTotal
          RainRate
          ) {
            &::print_log( "davisvantageproii: $key " . $$wptr{$key} );
          };
    }

    if ( $::Debug{weather} ) {
        &::print_log("uv: $uv");
        &::print_log("solar: $solar");
        &::print_log("batt_xmit: $batt_xmit");
        &::print_log("batt_cons: $batt_cons");
        &::print_log("sunrise: $sunrise");
        &::print_log("sunset: $sunset");
        &::print_log("crc: $crc");
        &::print_log("crc_calc: $crc_calc");
        &::print_log("barometric_trend: $barometric_trend");
        &::print_log("alarms_inside: $alarms_inside");
        &::print_log("alarms_rain: $alarms_rain");
        &::print_log("alarms_outside: $alarms_outside");
        &::print_log("forecast_icon: $forecast_icon");
        &::print_log("forecast_rule: $forecast_rule");
    }

    &::weather_updated;
    return $data;
}

sub CRC_CCITT {

    # Expects packed data...
    my $data_str = shift @_;

    my @crc_table = crc_table();

    my $tempcrc = 0;
    my @lst = split //, $data_str;
    foreach my $data (@lst) {
        my $data = unpack( "c", $data );

        my $crc_prev = $tempcrc;
        my $index    = $tempcrc >> 8 ^ $data;
        my $lhs      = $crc_table[$index];
        my $rhs      = ( $tempcrc << 8 ) & 0xFFFF;
        $tempcrc = $lhs ^ $rhs;

        #$data = unpack("H*",$data);
        #printf("%X\t %s\t %X\t %X\t %X\t : %x \n", $crc_prev, $data, $index, $lhs, $rhs, $crc);
    }

    return $tempcrc;
}

# - - - - - - - - - - - - - - - - - - -
sub crc_table {

    my @crc_table = (
        0x0,    0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
        0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
        0x1231, 0x210,  0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
        0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
        0x2462, 0x3443, 0x420,  0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
        0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
        0x3653, 0x2672, 0x1611, 0x630,  0x76d7, 0x66f6, 0x5695, 0x46b4,
        0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
        0x48c4, 0x58e5, 0x6886, 0x78a7, 0x840,  0x1861, 0x2802, 0x3823,
        0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
        0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0xa50,  0x3a33, 0x2a12,
        0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
        0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0xc60,  0x1c41,
        0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
        0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0xe70,
        0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
        0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
        0x1080, 0xa1,   0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
        0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
        0x2b1,  0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
        0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
        0x34e2, 0x24c3, 0x14a0, 0x481,  0x7466, 0x6447, 0x5424, 0x4405,
        0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
        0x26d3, 0x36f2, 0x691,  0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
        0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
        0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x8e1,  0x3882, 0x28a3,
        0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
        0x4a75, 0x5a54, 0x6a37, 0x7a16, 0xaf1,  0x1ad0, 0x2ab3, 0x3a92,
        0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
        0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0xcc1,
        0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
        0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0xed1,  0x1ef0
    );
}

# all modules must return 1.  don't remove the following line
1;

=begin comment
=============================================================================
Contents of the LOOP packet.
Field Offset Size Explanation
"L" 0 1
"O" 1 1
"O" 2 1
Spells out "LOO" for Rev B packets and "LOOP" for Rev A
packets. Identifies a LOOP packet
"P" (Rev A)
Bar Trend (Rev B)
3 1 Signed byte that indicates the current 3-hour barometer trend. It
is one of these values:
-60 = Falling Rapidly = 196 (as an unsigned byte)
-20 = Falling Slowly = 236 (as an unsigned byte)
0 = Steady
20 = Rising Slowly
60 = Rising Rapidly
80 = ASCII "P" = Rev A firmware, no trend info is available
Any other value means that the Vantage does not have the 3
hours of bar data needed to determine the bar trend.
Packet Type 4 1 Has the value zero. In the future we may define new LOOP
packet formats and assign a different value to this field.
Page 21 of 52
Field Offset Size Explanation
Next Record 5 2 Location in the archive memory where the next data packet will
be written. This can be monitored to detect when a new record is
created.
Barometer 7 2 Current Barometer. Units are (in Hg / 1000). The barometric
value should be between 20 inches and 32.5 inches in Vantage
Pro and between 20 inches and 32.5 inches in both Vantatge Pro
Vantage Pro2. Values outside these ranges will not be logged.
Inside Temperature 9 2 The value is sent as 10th of a degree in F. For example, 795 is
returned for 79.5°F.
Inside Humidity 11 1 This is the relative humidity in %, such as 50 is returned for 50%.
Outside Temperature 12 2 The value is sent as 10th of a degree in F. For example, 795 is
returned for 79.5°F.
Wind Speed 14 1 It is a byte unsigned value in mph. If the wind speed is dashed
because it lost synchronization with the radio or due to some
other reason, the wind speed is forced to be 0.
10 Min Avg Wind Speed 15 1 It is a byte unsigned value in mph.
Wind Direction 16 2 It is a two byte unsigned value from 1 to 360 degrees. (0° is no
wind data, 90° is East, 180° is South, 270° is West and 360° is
north)
Extra Temperatures 18 7 This field supports seven extra temperature stations.
Each byte is one extra temperature value in whole degrees F with
an offset of 90 degrees. For example, a value of 0 = -90°F ; a
value of 100 = 10°F ; and a value of 169 = 79°F.
Soil Temperatures 25 4 This field supports four soil temperature sensors, in the same
format as the Extra Temperature field above
Leaf Temperatures 29 4 This field supports four leaf temperature sensors, in the same
format as the Extra Temperature field above
Outside Humidity 33 1 This is the relative humitiy in %.
Extra Humidties 34 7 Relative humidity in % for extra seven humidity stations.
Rain Rate 41 2 This value is sent as number of rain clicks (0.2mm or 0.01in).
For example, 256 can represent 2.56 inches/hour.
UV 43 1 The unit is in UV index.
Solar Radiation 44 2 The unit is in watt/meter2.
Storm Rain 46 2 The storm is stored as 100th of an inch.
Start Date of current Storm 48 2 Bit 15 to bit 12 is the month, bit 11 to bit 7 is the day and bit 6 to
bit 0 is the year offseted by 2000.
Day Rain 50 2 This value is sent as number of rain clicks. (0.2mm or 0.01in)
Month Rain 52 2 This value is sent as number of rain clicks. (0.2mm or 0.01in)
Year Rain 54 2 This value is sent as number of rain clicks. (0.2mm or 0.01in)
Day ET 56 2 This value is sent as the 1000th of an inch.
Month ET 58 2 This value is sent as the 100th of an inch.
Year ET 60 2 This value is setnt as the 100th of an inch.
Soil Moistures 62 4 The unit is in centibar. It supports four soil sensors.
Leaf Wetnesses 66 4 This is a scale number from 0 to 15 with 0 meaning very dry and
15 meaning very wet. It supports four leaf sensors.
Inside Alarms 70 1 Currently active inside alarms. See the table below
Rain Alarms 71 1 Currently active rain alarms. See the table below
Outside Alarms 72 2 Currently active outside alarms. See the table below
Extra Temp/Hum Alarms 74 8 Currently active extra temp/hum alarms. See the table below
Soil & Leaf Alarms 82 4 Currently active soil/leaf alarms. See the table below
Transmitter Battery Status 86 1
Console Battery Voltage 87 2 Voltage = ((Data * 300)/512)/100.0
Forecast Icons 89 1
Page 22 of 52
Field Offset Size Explanation
Forecast Rule number 90 1
Time of Sunrise 91 2 The time is stored as hour * 100 + min.
Time of Sunset 93 2 The time is stored as hour * 100 + min.
"\n" <LF> = 0x0A 95 1
"\r" <CR> = 0x0D 96 1
CRC 97 2
Total Length 99
Forecast Icons in LOOP packet
Field Byte Bit #
Forecast Icons 89 Bit maps for forecast icons on the console screen.
Rain 0
Cloud 1
Partly Cloudy 2
Sun 3
Snow 4
Forecast Icon Values
Value Decimal Value Hex Segments Shown Forecast
8 0x08 Sun Mostly Clear
6 0x06 Partial Sun + Cloud Partially Cloudy
2 0x02 Cloud Mostly Cloudy
3 0x03 Cloud + Rain Mostly Cloudy, Rain within 12 hours
18 0x12 Cloud + Snow Mostly Cloudy, Snow within 12 hours
19 0x13 Cloud + Rain + Snow Mostly Cloudy, Rain or Snow within 12 hours
7 0x07 Partial Sun + Cloud +
Rain
Partially Cloudy, Rain within 12 hours
22 0x16 Partial Sun + Cloud +
Snow
Partially Cloudy, Snow within 12 hours
23 0x17 Partial Sun + Cloud +
Rain + Snow
Partially Cloudy, Rain or Snow within 12 hours
Currently active alarms in the LOOP packet
This table shows which alarms correspond to each bit in the LOOP alarm fields. Not all bits in
each field are used. The Outside Alarms field has been split into 2 1-byte sections.
Field Byte Bit #
Inside Alarms 70 Currently active inside alarms.
Falling bar trend alarm 0
Rising bar trend alarm 1
Low inside temp alarm 2
High inside temp alarm 3
Page 23 of 52
Field Byte Bit #
Low inside hum alarm 4
High inside hum alarm 5
Time alarm 6
Rain Alarms 71 Currently active rain alarms.
High rain rate alarm 0
15 min rain alarm 1 Flash Flood alarm
24 hour rain alarm 2
Storm total rain alarm 3
Daily ET alarm 4
Outside Alarms 72 Currently active outside alarms.
Low outside temp alarm 0
High outside temp alarm 1
Wind speed alarm 2
10 min avg speed alarm 3
Low dewpoint alarm 4
High dewpoint alarm 5
High heat alarm 6
Low wind chill alarm 7
Outside Alarms, byte 2 73
High THSW alarm 0
High solar rad alarm 1
High UV alarm 2
UV Dose alarm 3
UV Dose alarm Enabled 4 It is set to 1 when a UV dose alarm threshold has been entered
AND the daily UV dose has been manually cleared.
Outside Humidity Alarms 74 1 Currently active outside humidity alarms.
Low Humidity alarm 2
High Humidity alarm 3
Extra Temp/Hum Alarms 75 - 81 7 Each byte contains four alarm bits (0 – 3) for a single extra
Temp/Hum station. Bits (4 – 7) are not used and reserved for
future use.
Use the temperature and humidity sensor numbers, as
described in Section XIII.4 to locate which byte contains the
appropriate alarm bits. In particular, the humidity and
temperature alarms for a single station will be found in
different bytes.
Low temp X alarm 0
High temp X alarm 1
Low hum X alarm 2
High hum X alarm 3
Soil & Leaf Alarms 82 - 85 4 Currently active soil/leaf alarms.
Low leaf wetness X alarm 0
High leaf wetness X alarm 1
Low soil moisture X alarm 2
High soil moisture X alarm 3
Low leaf temp X alarm 4
High leaf temp X alarm 5
Low soil temp X alarm 6
High soil temp X alarm 7
=============================================================================
=cut
