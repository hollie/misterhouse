
=begin comment

This Module is for the Peet Bros. Ultimeter 2000 Weather Monitor

#################
 TODO:
  Puts the dates into the weather array as day-of-year instead
  of something that makes sense like October 15
#################A

 This module sets the serial port mode to complete record mode
 This module creates a lot of weather items

 The only setting necessary is this on in the mh.ini
 Ultimeter_serial_port=/dev/ttyR33

 If you want some information about what is going on (way too much)
 set debug=ultimeter

 You can set the time on your weather monitor with a code file like:

#################
 $weather_monitor = new Ultimeter;

 if ($New_Hour) {
        $weather_monitor->set_time;
 }

 $v_set_weather_time= new Voice_Cmd("Set the time on the weather monitor");

 if (said $v_set_weather_time) {
        $weather_monitor->set_time;
 }
#################


=cut

# DECODE
# Store in %main::Weather

# Conversions:
# 1 kph   = 0.06213 mph
# 1000 millibars = 29.53 inches Mercury

use strict;

package Ultimeter;

@Ultimeter::ISA = ('Serial_Item');

sub serial_startup {
    &main::serial_port_create( 'Ultimeter',
        $main::config_parms{Ultimeter_serial_port},
        2400, 'none' );

    #Start complete record mode
    $main::Serial_Ports{Ultimeter}{object}->write(">K\n");
    &main::MainLoop_pre_add_hook( \&Ultimeter::update_weather, 1 );
}

sub adjust_temp {
    my ($vvv) = @_;
    my ($vvvv);

    if ( $vvv > 655 ) {
        $vvvv = $vvv - 6553.5;
        $vvv  = $vvvv;
    }

    if ( $main::config_parms{Ultimeter_celsius} != 0 ) {
        $vvv = int( ( ( $vvv - 32 ) * 50 ) / 9 ) / 10;
    }

    return $vvv;
}

sub update_weather {
    my ( $v, $vv, $vvv, $vvvv, $data, $record_type );
    &main::check_for_generic_serial_data('Ultimeter');
    $data = $::Serial_Ports{Ultimeter}{data_record};
    $::Serial_Ports{Ultimeter}{data_record} = '';
    return unless $data;

    if ( $main::Debug{ultimeter} ) {
        &::print_log( "Ultimeter: datalength " . length($data) );
        &::print_log("Ultimeter: data:$data");
    }

####Complete Record Mode
    if ( $data =~ /^&CR&(\S{452})$/i ) {
        if ( $main::Debug{ultimeter} ) {
            &::print_log("Ultimeter: Complete Record Found");
        }

        #1 Current windspeed
        $v   = substr( $data, 4, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0 * 0.6;
        $main::Weather{CurrentWindSpeed} = sprintf( "%.1f", $vvv );

        #2 Current Wind direction
        $v   = substr( $data, 8, 4 );
        $vv  = hex($v);
        $vvv = $vv / 255 * 360.0;
        $main::Weather{CurrentWindDirection} = sprintf( "%.1f", $vvv );

        #3 5 minute wind speed peak
        $v   = substr( $data, 12, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10 * 0.6;
        $main::Weather{FiveMinPeakWindSpeed} = sprintf( "%.1f", $vvv );

        #4 5 minute wind direction peak
        $v   = substr( $data, 16, 4 );
        $vv  = hex($v);
        $vvv = $vv / 255 * 360.0;
        $main::Weather{FiveMinPeakWindDirection} = sprintf( "%.1f", $vvv );

        #5 Wind Chill
        $v                               = substr( $data, 20, 4 );
        $vv                              = hex($v);
        $vvv                             = $vv / 10.0;
        $vvv                             = &adjust_temp($vvv);
        $main::Weather{CurrentWindChill} = $vvv;

        #6 Outdoor Temp
        $v                                 = substr( $data, 24, 4 );
        $vv                                = hex($v);
        $vvv                               = $vv / 10.0;
        $vvv                               = &adjust_temp($vvv);
        $main::Weather{CurrentOutdoorTemp} = $vvv;

        #7 Rain Today
        $v   = substr( $data, 28, 4 );
        $vv  = hex($v);
        $vvv = $vv / 100.0;
        $main::Weather{CurrentRain} = sprintf( "%.2f", $vvv );

        #8 Current Barometer (millibars)
        $v   = substr( $data, 32, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        $main::Weather{CurrentBarometer} = sprintf( "%.2f", $vvv * .02953 );

        #9 Barometer Delta (millibars)
        $v = substr( $data, 36, 4 );
        $vv = hex($v);
        if ( $vv > 32767 ) { $vv = $vv - hex("10000"); }
        $vvv = $vv / 10.0;
        $main::Weather{ThreeHourBarometerChange} = $vvv;

        #10 Barometric correction factor lsw
        $v   = substr( $data, 40, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;

        #11 Barometric correction factor msw
        $v   = substr( $data, 44, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;

        #12 Indoor Temp
        $v                                = substr( $data, 48, 4 );
        $vv                               = hex($v);
        $vvv                              = $vv / 10.0;
        $vvv                              = &adjust_temp($vvv);
        $main::Weather{CurrentIndoorTemp} = $vvv;

        #13 Outdoor Humidity
        $v = substr( $data, 52, 4 );
        if ( $v ne "----" ) {
            $vv                                    = hex($v);
            $vvv                                   = $vv / 10.0;
            $main::Weather{CurrentOutdoorHumidity} = $vvv;
        }
        else {
            $main::Weather{CurrentOutdoorHumidity} = "N/A";
        }

        #14 Indoor Humidity
        $v = substr( $data, 56, 4 );
        if ( $v ne "----" ) {
            $vv                                   = hex($v);
            $vvv                                  = $vv / 10.0;
            $main::Weather{CurrentIndoorHumidity} = $vvv;
        }
        else {
            $main::Weather{CurrentIndoorHumidity} = "N/A";
        }

        #15 Dew Point
        $v                              = substr( $data, 60, 4 );
        $vv                             = hex($v);
        $vvv                            = $vv / 10.0;
        $main::Weather{CurrentDewPoint} = $vvv;

        #16 Date (day of year) Jan 1 = 0
        $v = substr( $data, 64, 4 );
        $vv = hex($v);

        #       $main::Weather{DATE}=$vv;

        #17 Time (minute of day)
        $v = substr( $data, 68, 4 );
        $vv = hex($v);

        #       $main::Weather{TIME}=$vv;

        #18 Today's Low Chill Value
        $v                                = substr( $data, 72, 4 );
        $vv                               = hex($v);
        $vvv                              = $vv / 10.0;
        $vvv                              = &adjust_temp($vvv);
        $main::Weather{TodayLowWindChill} = $vvv;

        #19 Today's Low Chill Time
        $v                                    = substr( $data, 76, 4 );
        $vv                                   = hex($v);
        $main::Weather{TodayLowWindChillTime} = &ultimeter_time($vv);

        #20 Yesterdays's Low Chill Value
        $v                                    = substr( $data, 80, 4 );
        $vv                                   = hex($v);
        $vvv                                  = $vv / 10.0;
        $vvv                                  = &adjust_temp($vvv);
        $main::Weather{YesterdayLowWindChill} = $vvv;

        #21 Yesterdays's Low Chill Time
        $v                                        = substr( $data, 84, 4 );
        $vv                                       = hex($v);
        $main::Weather{YesterdayLowWindChillTime} = &ultimeter_time($vv);

        #22 Long Term Low Chill Date
        $v                                       = substr( $data, 88, 4 );
        $vv                                      = hex($v);
        $main::Weather{LongtermLowWindChillDate} = $vv;

        #23 Long Term Low Chill Value
        $v                                   = substr( $data, 92, 4 );
        $vv                                  = hex($v);
        $vvv                                 = $vv / 10.0;
        $vvv                                 = &adjust_temp($vvv);
        $main::Weather{LongtermLowWindChill} = $vvv;

        #24 Long Term Low Chill Time
        $v                                       = substr( $data, 96, 4 );
        $vv                                      = hex($v);
        $main::Weather{LongtermLowWindChillTime} = &ultimeter_time($vv);

        #25 Today's Low Outdoor Temp Value
        $v                              = substr( $data, 100, 4 );
        $vv                             = hex($v);
        $vvv                            = $vv / 10.0;
        $vvv                            = &adjust_temp($vvv);
        $main::Weather{TodayOutdoorLow} = $vvv;

        #26 Today's Low Outdoor Temp Time
        $v                                  = substr( $data, 104, 4 );
        $vv                                 = hex($v);
        $main::Weather{TodayOutdoorLowTime} = &ultimeter_time($vv);

        #27 Yesterday's Low Outdoor Temp Value
        $v                                  = substr( $data, 108, 4 );
        $vv                                 = hex($v);
        $vvv                                = $vv / 10.0;
        $vvv                                = &adjust_temp($vvv);
        $main::Weather{YesterdayOutdoorLow} = $vvv;

        #28 Yesterday's Low Outdoor Temp Time
        $v                                      = substr( $data, 112, 4 );
        $vv                                     = hex($v);
        $main::Weather{YesterdayOutdoorLowTime} = &ultimeter_time($vv);

        #29 Long Term Low Outdoor Temp Date
        $v                                     = substr( $data, 116, 4 );
        $vv                                    = hex($v);
        $main::Weather{LongtermOutdoorLowDate} = $vv;

        #30 Long Term Low Outdoor Temp Value
        $v                                 = substr( $data, 120, 4 );
        $vv                                = hex($v);
        $vvv                               = $vv / 10.0;
        $vvv                               = &adjust_temp($vvv);
        $main::Weather{LongtermOutdoorLow} = $vvv;

        #31 Long Term Low Outdoor Temp Time
        $v                                     = substr( $data, 124, 4 );
        $vv                                    = hex($v);
        $main::Weather{LongtermOutdoorLowTime} = &ultimeter_time($vv);

        #32 Today's Low Barometer Value
        $v   = substr( $data, 128, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        $main::Weather{TodayLowBarometer} = sprintf( "%.2f", $vvv * .02953 );

        #33 Today's Low Barometer Time
        $v                                    = substr( $data, 132, 4 );
        $vv                                   = hex($v);
        $main::Weather{TodayLowBarometerTime} = &ultimeter_time($vv);

        #34 Wind Speed (0.1kph)
        $v   = substr( $data, 136, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10 * 0.6;

        #35 Current Wind Direction (0-255)
        $v   = substr( $data, 140, 4 );
        $vv  = hex($v);
        $vvv = $vv / 255 * 360.0;

        #36 Yesterday's Low Barometer Value
        $v   = substr( $data, 144, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        $main::Weather{YesterdayBarometerLow} =
          sprintf( "%.2f", $vvv * .02953 );

        #37 Yesterday's Low Barometer Time
        $v                                        = substr( $data, 148, 4 );
        $vv                                       = hex($v);
        $main::Weather{YesterdayBarometerLowTime} = &ultimeter_time($vv);

        #38 Long Term Low Barometer Date
        $v                                       = substr( $data, 152, 4 );
        $vv                                      = hex($v);
        $main::Weather{LongtermBarometerLowDate} = $vv;

        #39 Long Term Low Barometer Value
        $v   = substr( $data, 156, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        $main::Weather{LongtermBarometerLow} = sprintf( "%.2f", $vvv * .02953 );

        #40 Long Term Low Barometer Time
        $v                                       = substr( $data, 160, 4 );
        $vv                                      = hex($v);
        $main::Weather{LongtermBarometerLowTime} = &ultimeter_time($vv);

        #41 Today's Low Indoor Temp Value
        $v                             = substr( $data, 164, 4 );
        $vv                            = hex($v);
        $vvv                           = $vv / 10.0;
        $vvv                           = &adjust_temp($vvv);
        $main::Weather{TodayIndoorLow} = $vvv;

        #42 Today's Low Indoor Temp Time
        $v                                 = substr( $data, 168, 4 );
        $vv                                = hex($v);
        $main::Weather{TodayIndoorLowTime} = &ultimeter_time($vv);

        #43 Yesterday's Low Indoor Temp Value
        $v                                 = substr( $data, 172, 4 );
        $vv                                = hex($v);
        $vvv                               = $vv / 10.0;
        $vvv                               = &adjust_temp($vvv);
        $main::Weather{YesterdayIndoorLow} = $vvv;

        #44 Yesterday's Low Indoor Temp Time
        $v                                     = substr( $data, 176, 4 );
        $vv                                    = hex($v);
        $main::Weather{YesterdayIndoorLowTime} = &ultimeter_time($vv);

        #45 Long Term Low Indoor Temp Date
        $v                                    = substr( $data, 180, 4 );
        $vv                                   = hex($v);
        $main::Weather{LongtermIndoorLowDate} = $vv;

        #46 Long Term Low Indoor Temp Value
        $v                                = substr( $data, 184, 4 );
        $vv                               = hex($v);
        $vvv                              = $vv / 10.0;
        $vvv                              = &adjust_temp($vvv);
        $main::Weather{LongtermIndoorLow} = $vvv;

        #47 Long Term Low Indoor Temp Time
        $v                                    = substr( $data, 188, 4 );
        $vv                                   = hex($v);
        $main::Weather{LongtermIndoorLowTime} = &ultimeter_time($vv);

        #48 Today's Low Outdoor Humidity Value
        $v   = substr( $data, 192, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{TodayOutdoorLowHumidity} = $vvv;
        }
        else {
            $main::Weather{TodayOutdoorLowHumidity} = "N/A";
        }

        #49 Today's Low Outdoor Humidity Time
        $v = substr( $data, 196, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{TodayOutdoorLowHumidityTime} = &ultimeter_time($vv);
        }
        else {
            $main::Weather{TodayOutdoorLowHumidityTime} = "N/A";
        }

        #50 Yesterday's Low Outdoor Humidity Value
        $v   = substr( $data, 200, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{YesterdayOutdoorLowHumidity} = $vvv;
        }
        else {
            $main::Weather{YesterdayOutdoorLowHumidity} = "N/A";
        }

        #51 Yesterday's Low Outdoor Humidity Time
        $v = substr( $data, 204, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{YesterdayOutdoorLowHumidityTime} =
              &ultimeter_time($vv);
        }
        else {
            $main::Weather{YesterdayOutdoorLowHumidityTime} = "N/A";
        }

        #52 Long Term Low Outdoor Humidity Date
        $v = substr( $data, 208, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermOutdoorLowHumidityDate} = $vv;
        }
        else {
            $main::Weather{LongtermOutdoorLowHumidityDate} = "N/A";
        }

        #53 Long Term Low Outdoor Humidity Value
        $v   = substr( $data, 212, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermOutdoorLowHumidity} = $vvv;
        }
        else {
            $main::Weather{LongtermOutdoorLowHumidity} = "N/A";
        }

        #54 Long Term Low Outdoor Humidity Time
        $v = substr( $data, 216, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermOutdoorLowHumidityTime} =
              &ultimeter_time($vv);
        }
        else {
            $main::Weather{LongtermOutdoorLowHumidityTime} = "N/A";
        }

        #55 Today's Low Indoor Humidity Value
        $v   = substr( $data, 220, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{TodayIndoorLowHumidity} = $vvv;
        }
        else {
            $main::Weather{TodayIndoorLowHumidity} = "N/A";
        }

        #56 Today's Low Indoor Humidity Time
        $v = substr( $data, 224, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{TodayIndoorLowHumidityTime} = &ultimeter_time($vv);
        }
        else {
            $main::Weather{TodayIndoorLowHumidityTime} = "N/A";
        }

        #57 Yesterday's Low Indoor Humidity Value
        $v   = substr( $data, 228, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{YesterdayIndoorLowHumidity} = $vvv;
        }
        else {
            $main::Weather{YesterdayIndoorLowHumidity} = "N/A";
        }

        #58 Yesterday's Low Indoor Humidity Time
        $v = substr( $data, 232, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{YesterdayIndoorLowHumidityTime} =
              &ultimeter_time($vv);
        }
        else {
            $main::Weather{YesterdayIndoorLowHumidityTime} = "N/A";
        }

        #59 Long Term Low Indoor Humidity Date
        $v = substr( $data, 236, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermIndoorLowHumidityDate} = $vv;
        }
        else {
            $main::Weather{LongtermIndoorLowHumidityDate} = "N/A";
        }

        #60 Long Term Low Indoor Humidity Value
        $v   = substr( $data, 240, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermIndoorLowHumidity} = $vvv;
        }
        else {
            $main::Weather{LongtermIndoorLowHumidity} = "N/A";
        }

        #61 Long Term Low Indoor Humidity Time
        $v = substr( $data, 244, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermIndoorLowHumidityTime} =
              &ultimeter_time($vv);
        }
        else {
            $main::Weather{LongtermIndoorLowHumidityTime} = "N/A";
        }

        #62 Today's Wind Speed Value
        $v                                 = substr( $data, 248, 4 );
        $vv                                = hex($v);
        $vvv                               = $vv / 10 * 0.6;
        $main::Weather{TodayWindSpeedPeak} = $vvv;

        #63 Today's Wind Speed Time
        $v                                     = substr( $data, 252, 4 );
        $vv                                    = hex($v);
        $main::Weather{TodayWindSpeedPeakTime} = &ultimeter_time($vv);

        #64 Yesterday's Wind Speed Value
        $v                                     = substr( $data, 256, 4 );
        $vv                                    = hex($v);
        $vvv                                   = $vv / 10 * 0.6;
        $main::Weather{YesterdayWindSpeedPeak} = $vvv;

        #65 Yesterday's Wind Speed PeakTime
        $v                                         = substr( $data, 260, 4 );
        $vv                                        = hex($v);
        $main::Weather{YesterdayWindSpeedPeakTime} = &ultimeter_time($vv);

        #66 Long Term Wind Speed Date
        $v                                        = substr( $data, 264, 4 );
        $vv                                       = hex($v);
        $main::Weather{LongtermWindSpeedPeakDate} = $vv;

        #67 Long Term Wind Speed Value
        $v                                    = substr( $data, 268, 4 );
        $vv                                   = hex($v);
        $vvv                                  = $vv / 10 * 0.6;
        $main::Weather{LongtermWindSpeedPeak} = $vvv;

        #68 Long Term Wind Speed Time
        $v                                        = substr( $data, 272, 4 );
        $vv                                       = hex($v);
        $main::Weather{LongtermWindSpeedPeakTime} = &ultimeter_time($vv);

        #69 Today's High Outdoor Temp Value
        $v                               = substr( $data, 276, 4 );
        $vv                              = hex($v);
        $vvv                             = $vv / 10.0;
        $vvv                             = &adjust_temp($vvv);
        $main::Weather{TodayOutdoorHigh} = $vvv;

        #70 Today's High Outdoor Temp Time
        $v                                   = substr( $data, 280, 4 );
        $vv                                  = hex($v);
        $main::Weather{TodayOutdoorHighTime} = &ultimeter_time($vv);

        #71 Wind Speed (0.1kph)
        $v   = substr( $data, 284, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10 * 0.6;

        #72 Current Wind Direction (0-255)
        $v   = substr( $data, 288, 4 );
        $vv  = hex($v);
        $vvv = $vv / 255 * 360.0;

        #73 Yesterday's High Outdoor Temp Value
        $v                                   = substr( $data, 292, 4 );
        $vv                                  = hex($v);
        $vvv                                 = $vv / 10.0;
        $vvv                                 = &adjust_temp($vvv);
        $main::Weather{YesterdayOutdoorHigh} = $vvv;

        #74 Yesterday's High Outdoor Temp Time
        $v                                       = substr( $data, 296, 4 );
        $vv                                      = hex($v);
        $main::Weather{YesterdayOutdoorHighTime} = &ultimeter_time($vv);

        #75 Long Term High Outdoor Temp Date
        $v                                      = substr( $data, 300, 4 );
        $vv                                     = hex($v);
        $main::Weather{LongtermOutdoorHighDate} = $vv;

        #76 Long Term High Outdoor Temp Value
        $v                                  = substr( $data, 304, 4 );
        $vv                                 = hex($v);
        $vvv                                = $vv / 10.0;
        $vvv                                = &adjust_temp($vvv);
        $main::Weather{LongtermOutdoorHigh} = $vvv;

        #77 Long Term High Outdoor Temp Time
        $v                                      = substr( $data, 308, 4 );
        $vv                                     = hex($v);
        $main::Weather{LongtermOutdoorHighTime} = &ultimeter_time($vv);

        #78 Today's High Barometer Value
        $v   = substr( $data, 312, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        $main::Weather{TodayBarometerHigh} = sprintf( "%.2f", $vvv * .02953 );

        #79 Today's High Barometer Time
        $v                                     = substr( $data, 316, 4 );
        $vv                                    = hex($v);
        $main::Weather{TodayBarometerHighTime} = &ultimeter_time($vv);

        #80 Yesterday's High Barometer Value
        $v   = substr( $data, 320, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        $main::Weather{YesterdayBarometerHigh} =
          sprintf( "%.2f", $vvv * .02953 );

        #81 Yesterday's High Barometer Time
        $v                                         = substr( $data, 324, 4 );
        $vv                                        = hex($v);
        $main::Weather{YesterdayBarometerHighTime} = &ultimeter_time($vv);

        #82 Long Term High Barometer Date
        $v                                        = substr( $data, 328, 4 );
        $vv                                       = hex($v);
        $main::Weather{LongtermBarometerHighDate} = $vv;

        #83 Long Term High Barometer Value
        $v   = substr( $data, 332, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        $main::Weather{LongtermBarometerHigh} =
          sprintf( "%.2f", $vvv * .02953 );

        #84 Long Term High Barometer Time
        $v                                        = substr( $data, 336, 4 );
        $vv                                       = hex($v);
        $main::Weather{LongtermBarometerHighTime} = &ultimeter_time($vv);

        #85 Today's High Indoor Temp Value
        $v                                  = substr( $data, 340, 4 );
        $vv                                 = hex($v);
        $vvv                                = $vv / 10.0;
        $vvv                                = &adjust_temp($vvv);
        $main::Weather{TodayIndoorHighTemp} = $vvv;

        #86 Today's High Indoor Temp Time
        $v                                      = substr( $data, 344, 4 );
        $vv                                     = hex($v);
        $main::Weather{TodayIndoorHighTempTime} = &ultimeter_time($vv);

        #87 Yesterday's High Indoor Temp Value
        $v                                      = substr( $data, 348, 4 );
        $vv                                     = hex($v);
        $vvv                                    = $vv / 10.0;
        $vvv                                    = &adjust_temp($vvv);
        $main::Weather{YesterdayIndoorHighTemp} = $vvv;

        #88 Yesterday's High Indoor Temp Time
        $v                                      = substr( $data, 352, 4 );
        $vv                                     = hex($v);
        $main::Weather{YesterdayIndoorHighTime} = &ultimeter_time($vv);

        #89 Long Term High Indoor Temp Date
        $v                                     = substr( $data, 356, 4 );
        $vv                                    = hex($v);
        $main::Weather{LongtermIndoorHighDate} = $vv;

        #90 Long Term High Indoor Temp Value
        $v                                 = substr( $data, 360, 4 );
        $vv                                = hex($v);
        $vvv                               = $vv / 10.0;
        $vvv                               = &adjust_temp($vvv);
        $main::Weather{LongtermIndoorHigh} = $vvv;

        #91 Long Term High Indoor Temp Time
        $v                                     = substr( $data, 364, 4 );
        $vv                                    = hex($v);
        $main::Weather{LongtermIndoorHighTime} = &ultimeter_time($vv);

        #92 Today's High Outdoor Humidity Value
        $v                                       = substr( $data, 368, 4 );
        $vv                                      = hex($v);
        $vvv                                     = $vv / 10.0;
        $main::Weather{TodayOutdoorHighHumidity} = $vvv;

        #93 Today's High Outdoor Humidity Time
        $v                                           = substr( $data, 372, 4 );
        $vv                                          = hex($v);
        $main::Weather{TodayOutdoorHighHumidityTime} = &ultimeter_time($vv);

        #94 Yesterday's High Outdoor Humidity Value
        $v   = substr( $data, 376, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{YesterdayOutdoorHighHumidity} = $vvv;
        }
        else {
            $main::Weather{YesterdayOutdoorHighHumidity} = "N/A";
        }

        #95 Yesterday's High Outdoor Humidity Time
        $v = substr( $data, 380, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{YesterdayOutdoorHighHumidityTime} =
              &ultimeter_time($vv);
        }
        else {
            $main::Weather{YesterdayOutdoorHighHumidityTime} = "N/A";
        }

        #96 Long Term High Outdoor Humidity Date
        $v = substr( $data, 384, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermOutdoorHighHumidityDate} = $vv;
        }
        else {
            $main::Weather{LongtermOutdoorHighHumidityDate} = "N/A";
        }

        #97 Long Term High Outdoor Humidity Value
        $v   = substr( $data, 388, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermOutdoorHighHumidity} = $vvv;
        }
        else {
            $main::Weather{LongtermOutdoorHighHumidity} = "N/A";
        }

        #98 Long Term High Outdoor Humidity Time
        $v = substr( $data, 392, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentOutdoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermOutdoorHighHumidityTime} =
              &ultimeter_time($vv);
        }
        else {
            $main::Weather{LongtermOutdoorHighHumidityTime} = "N/A";
        }

        #99 Today's High Indoor Humidity Value
        $v   = substr( $data, 396, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{TodayIndoorHighHumidity} = $vvv;
        }
        else {
            $main::Weather{TodayIndoorHighHumidity} = "N/A";
        }

        #100 Today's High Indoor Humidity Time
        $v = substr( $data, 400, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{TodayIndoorHighHumidityTime} = &ultimeter_time($vv);
        }
        else {
            $main::Weather{TodayIndoorHighHumidityTime} = "N/A";
        }

        #101 Yesterday's High Indoor Humidity Value
        $v   = substr( $data, 404, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{YesterdayIndoorHighHumidity} = $vvv;
        }
        else {
            $main::Weather{YesterdayIndoorHighHumidity} = "N/A";
        }

        #102 Yesterday's High Indoor Humidity Time
        $v = substr( $data, 408, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{YesterdayIndoorHighHumidityTime} =
              &ultimeter_time($vv);
        }
        else {
            $main::Weather{YesterdayIndoorHighHumidityTime} = "N/A";
        }

        #03 Long Term High Indoor Humidity Date
        $v = substr( $data, 412, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermIndoorHighHumidityDate} = $vv;
        }
        else {
            $main::Weather{LongtermIndoorHighHumidityDate} = "N/A";
        }

        #104 Long Term High Indoor Humidity Value
        $v   = substr( $data, 416, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermIndoorHighHumidity} = $vvv;
        }
        else {
            $main::Weather{LongtermIndoorHighHumidity} = "N/A";
        }

        #105 Long Term High Indoor Humidity Time
        $v = substr( $data, 420, 4 );
        $vv = hex($v);
        if ( $main::Weather{CurrentIndoorHumidity} ne "N/A" ) {
            $main::Weather{LongtermIndoorHighHumidityTime} =
              &ultimeter_time($vv);
        }
        else {
            $main::Weather{LongtermIndoorHighHumidityTime} = "N/A";
        }

        #106 Yesterday's Rain Total (0.01")
        $v   = substr( $data, 424, 4 );
        $vv  = hex($v);
        $vvv = $vv / 100.0;
        $main::Weather{YesterdayRain} = sprintf( "%.2f", $vvv );

        #107 Long Term Rain Date
        $v                               = substr( $data, 428, 4 );
        $vv                              = hex($v);
        $main::Weather{LongtermRainDate} = $vv;

        #108 Long Term Rain Total (0.01")
        $v   = substr( $data, 432, 4 );
        $vv  = hex($v);
        $vvv = $vv / 100.0;
        $main::Weather{LongtermRainTotal} = sprintf( "%.2f", $vvv );

        #109 Leap Year Value (0-3)
        $v   = substr( $data, 436, 4 );
        $vv  = hex($v);
        $vvv = $vv;

        #110 WDCF Value (0-255)
        $v   = substr( $data, 440, 4 );
        $vv  = hex($v);
        $vvv = $vv / 255 * 360.0;

        #111 Yesterday's High Wind Direction (2 bytes)
        $v   = substr( $data, 444, 2 );
        $vv  = hex($v);
        $vvv = $vv / 255 * 360.0;
        $main::Weather{YesterdayHighWindDirection} = sprintf( "%.1f", $vvv );

        #112 Today's High Wind Direction (2 bytes)
        $v   = substr( $data, 446, 2 );
        $vv  = hex($v);
        $vvv = $vv / 255 * 360.0;
        $main::Weather{TodayHighWindDirection} = sprintf( "%.1f", $vvv );

        #113 Spare (2 bytes, 448-449)

        #114 Long Term High Wind Direction (2 bytes)
        $v   = substr( $data, 450, 2 );
        $vv  = hex($v);
        $vvv = $vv / 255 * 360.0;
        $main::Weather{LongtermHighWindDirection} = sprintf( "%.1f", $vvv );

        #115 1 Minute Wind Speed Average (0.1kph)
        $v   = substr( $data, 452, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10 * 0.6;
        $main::Weather{OneMinWindSpeedAverage} = sprintf( "%.1f", $vvv );

####End Complete Record
####Start Data Log Record
    }
    elsif ( $data =~ /^!!(.+)/i ) {
        if ( $main::Debug{ultimeter} ) {
            &::print_log("Ultimeter: Data Log Record Found");
        }

        #1 Current windspeed
        $v   = substr( $data, 4, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0 * 0.6;
        $main::Weather{CurrentWindSpeed} = sprintf( "%.1f", $vvv );

        #2 Current Wind direction
        $v   = substr( $data, 8, 4 );
        $vv  = hex($v);
        $vvv = $vv / 255 * 360.0;
        $main::Weather{CurrentWindDirection} = sprintf( "%.1f", $vvv );

        #3 Outdoor Temp
        $v                                 = substr( $data, 12, 4 );
        $vv                                = hex($v);
        $vvv                               = $vv / 10.0;
        $vvv                               = &adjust_temp($vvv);
        $main::Weather{CurrentOutdoorTemp} = $vvv;

        #4 Long Term Rain Total (0.01")
        $v                                = substr( $data, 16, 4 );
        $vv                               = hex($v);
        $vvv                              = $vv / 100.0;
        $main::Weather{LongtermRainTotal} = $vvv;

        #5 Current Barometer (millibars)
        $v   = substr( $data, 20, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        $main::Weather{CurrentBarometer} = sprintf( "%.2f", $vvv * .02953 );

        #6 Indoor Temp
        $v                                = substr( $data, 24, 4 );
        $vv                               = hex($v);
        $vvv                              = $vv / 10.0;
        $vvv                              = &adjust_temp($vvv);
        $main::Weather{CurrentIndoorTemp} = $vvv;

        #7 Outdoor Humidity
        $v = substr( $data, 28, 4 );
        if ( $v ne "----" ) {
            $vv                                    = hex($v);
            $vvv                                   = $vv / 10.0;
            $main::Weather{CurrentOutdoorHumidity} = $vvv;
        }
        else {
            $main::Weather{CurrentOutdoorHumidity} = "N/A";
        }

        #8 Indoor Humidity
        $v = substr( $data, 32, 4 );
        if ( $v ne "----" ) {
            $vv                                   = hex($v);
            $vvv                                  = $vv / 10.0;
            $main::Weather{CurrentIndoorHumidity} = $vvv;
        }
        else {
            $main::Weather{CurrentIndoorHumidity} = "N/A";
        }

        #9 Date (day of year) Jan 1 = 0
        $v = substr( $data, 36, 4 );
        $vv = hex($v);

        #       $main::Weather{DATE}=$vv;

        #10 Time (minute of day)
        $v = substr( $data, 40, 4 );
        $vv = hex($v);

        #       $main::Weather{TIME}=$vv;

        #11 Rain Today
        $v                          = substr( $data, 44, 4 );
        $vv                         = hex($v);
        $vvv                        = $vv / 100.0;
        $main::Weather{CurrentRain} = $vvv;

        #12 1 Minute Wind Speed Average (0.1kph)
        $v   = substr( $data, 48, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10 * 0.6;
        $main::Weather{OneMinWindSpeedAverage} = sprintf( "%.1f", $vvv );

####End Data Log Record
####Start Packet Record
    }
    elsif ( $data =~ /^\$ultw(.+)/i ) {
        if ( $main::Debug{ultimeter} ) {
            &::print_log("Ultimeter: Packet Record Found");
        }

        #1 5 minute wind speed peak
        $v   = substr( $data, 5, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10 * 0.6;
        $main::Weather{FiveMinPeakWindSpeed} = sprintf( "%.1f", $vvv );

        #2 Long Term Wind Speed Date
        $v                                        = substr( $data, 9, 4 );
        $vv                                       = hex($v);
        $main::Weather{LongtermWindSpeedPeakDate} = $vv;

        #3 Outdoor Temp
        $v                                 = substr( $data, 13, 4 );
        $vv                                = hex($v);
        $vvv                               = $vv / 10.0;
        $vvv                               = &adjust_temp($vvv);
        $main::Weather{CurrentOutdoorTemp} = $vvv;

        #4 Long Term Rain Total (0.01")
        $v                                = substr( $data, 17, 4 );
        $vv                               = hex($v);
        $vvv                              = $vv / 100.0;
        $main::Weather{LongtermRainTotal} = $vvv;

        #5 Current Barometer (millibars)
        $v   = substr( $data, 21, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;
        $main::Weather{CurrentBarometer} = sprintf( "%.2f", $vvv * .02953 );

        #6 Barometer Delta (millibars)
        $v = substr( $data, 25, 4 );
        $vv = hex($v);
        if ( $vv > 32767 ) { $vv = $vv - hex("10000"); }
        $vvv = $vv / 10.0;
        $main::Weather{ThreeHourBarometerChange} = $vvv;

        #7 Barometric correction factor lsw
        $v   = substr( $data, 29, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;

        #8 Barometric correction factor msw
        $v   = substr( $data, 33, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10.0;

        #9 Outdoor Humidity
        $v = substr( $data, 37, 4 );
        if ( $v ne "----" ) {
            $vv                                    = hex($v);
            $vvv                                   = $vv / 10.0;
            $main::Weather{CurrentOutdoorHumidity} = $vvv;
        }
        else {
            $main::Weather{CurrentOutdoorHumidity} = "N/A";
        }

        #10 Date (day of year) Jan 1 = 0
        $v = substr( $data, 41, 4 );
        $vv = hex($v);

        #       $main::Weather{DATE}=$vv;

        #11 Time (minute of day)
        $v = substr( $data, 45, 4 );
        $vv = hex($v);

        #       $main::Weather{TIME}=$vv;

        #12 Rain Today
        $v                          = substr( $data, 49, 4 );
        $vv                         = hex($v);
        $vvv                        = $vv / 100.0;
        $main::Weather{CurrentRain} = $vvv;

        #13 1 Minute Wind Speed Average (0.1kph)
        $v   = substr( $data, 53, 4 );
        $vv  = hex($v);
        $vvv = $vv / 10 * 0.6;
        $main::Weather{OneMinWindSpeedAverage} = sprintf( "%.1f", $vvv );

####End Packet Record
    }
    else {
        $data = undef;
        if ( $main::Debug{utilimeter} ) {
            &::print_log("Ultimeter: Invalid Data Found");
        }

    }

}

sub ultimeter_time {
    my ($ult_minutes) = @_;
    my ( $hour, $minute );
    $hour   = int( $ult_minutes / 60 );
    $minute = $ult_minutes % 60;
    if ( $minute < 10 ) {
        $minute = "0" . $minute;
    }
    return ("$hour:$minute");

}

sub set_time {
    my ( @date, $time, $string, $leap );
    (@date) = localtime(time);

    ##Leap Year
    $leap = 4 - ( $date[5] % 4 );
    $main::Serial_Ports{Ultimeter}{object}->write(">F$leap\n");
    if ( $main::Debug{ultimeter} ) {
        &::print_log("Ultimeter Leap year set: $leap");
    }

    #Time/Date
    $time = $main::Hour * 60 + $main::Minute;
    if ( length($time) == 3 ) {
        $time = "0" . $time;
    }
    elsif ( length($time) == 2 ) {
        $time = "00" . $time;
    }
    elsif ( length($time) == 1 ) {
        $time = "000" . $time;
    }
    if ( length( $date[7] ) == 1 ) {
        $date[7] = "000" . $date[7];
    }
    elsif ( length( $date[7] ) == 2 ) {
        $date[7] = "00" . $date[7];
    }
    elsif ( length( $date[7] ) == 3 ) {
        $date[7] = "0" . $date[7];
    }

    $string = ">A" . $date[7] . $time . "\n";
    if ( $main::Debug{ultimeter} ) {
        &::print_log("Ultimeter time set: $string");
    }
    $main::Serial_Ports{Ultimeter}{object}->write($string);

    ##Return to complete record mode
    $main::Serial_Ports{Ultimeter}{object}->write(">K\n");
}

1;

