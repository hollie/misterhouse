package Weather_daviswm2;

# $Date$
# $Revision$

use Tie::IxHash;
use strict;
use Weather_Common;
eval 'use Digest::mhCRC qw(crc16);';
if ($@) {
    die(
        "Weather_daviswm2:  Can't find the Digest::mhCRC package (mhCRC.pm).  Please ensure that it is installed.\n$@"
    );
}

=begin comment
=============================================================================
Davis Weather Monitor II
6/17/2006
Scott Huskey modified Tom Vanderpool's wmr968 code to enable use of it
for the Davis Weather Monitor II weather stations.

Matt Williams reworked it to interface correctly with mh and to make it a module
Jack Edin was heavily involved in testing and was the impedus behind the creation of this module.

1/27/2014 
Sean Mathews <coder at f34r dot com>
  
sponsored by a close friend and fellow maker Jack Edin 1961-2012 RIP
Movie nights and project days will be missed.

added barometric tendency calculation. The wm2 has a visual indicator of the barometric trend but
it can not be accessed via the serial port protocol. 

the barometric tendency indications based upon a given change over a one hour period.
   http://www.erh.noaa.gov/box/glossary.htm
   "Rising Rapidly" is indicated if the pressure increases > 2 mb (0.06")
   "Rising Slowly" is indicated if the pressure increases >1 mb but < 2 mb (> 0.02" but < 0.06")
   "Steady" is indicated if the pressure changes < 1 mb (< 0.02")
   "Falling Slowly" is indicated if the pressure falls > 1 mb but < 2 mb (> 0.02" but < 0.06")
   "Falling Rapidly" is indicated when the pressure decreases > 2 mb (>0.06")
   "Unsteady" unknown lack of samples or last sample fluctuated by 0.03 or more

in order to still get some trends before I have a long enough sample time I have opted to use this
psudo code. 
    collect a sample and add to fifo array
    expire any samples older than 1 hours from the sample we just took
    if last > 0 and deviation from last > .03" ( last is 0 on startup )
        report "Unsteady"
    else 
      if the sample array has a minimum of 10 samples
        find average oldest(head) 5 samples for oldest barom
        find average newest(tail) 5 samples for current barom
        report indicator based upon this calculation above
      else
        report ""






Note: You must enable this module by setting the following parameters in mh{.private}.ini.
    Obviously you must point the port to the actual port to which the station is connected.
	serial_daviswm2_port=COM10
	serial_daviswm2_baudrate=2400
	serial_daviswm2_datatype=raw
	serial_daviswm2_module=Weather_daviswm2

=============================================================================
=cut

our $loopCommand = join "", "LOOP", chr(255), chr(255), chr(13);
our $DavisWMII_port;
our $lastRainReading     = undef;
our $lastRainReadingTime = undef;
my $barom_tendency = "";
my %barom_samples  = undef;
my $barom_samples  = undef;

$barom_samples = tie %barom_samples, 'Tie::IxHash';

sub startup {
    my ($instance) = @_;
    $DavisWMII_port = new Serial_Item( undef, undef, 'serial_daviswm2' );
    &requestData;
    &::MainLoop_pre_add_hook( \&Weather_daviswm2::update, 1 );
    &::trigger_set(
        'new_minute(1)', '&Weather_daviswm2::requestData',
        'NoExpire',      'daviswm2 data request'
    ) unless &::trigger_get('daviswm2 data request');
}

# called by trigger every minute
sub requestData {
    &::print_log("daviswm2: requesting new data from station")
      if $::Debug{weather};
    $DavisWMII_port->set($loopCommand);
}

# called once per loop
sub update {
    return unless my $data = said $DavisWMII_port;

    my $remainder = &process( $data, \%main::Weather );
    $DavisWMII_port->set_data($remainder) if $remainder ne '';
    &weather_updated;
}

#my $sample = "\x01\xD3\x02\x70\x02\x05\x30\x01\x75\x73\x21\x22\x00\x00\x00\x00\x15\xE8";
#my $sample = "\x01\xD3\x02\x70\x02\x06\x30\x01\x75\x73\x21\x22\x00\x00\x00\x00\x6D\x12";

# Parse DavisWMII datastream into array pointed at with $wptr so Mr House
# can use the information
#
# Sample data from the DavisWMII: 01 D3 02 70 02 05 30 01 75 73 21 22 00 00 00 00 15 E8
#
#                                            offset sample  Dec
#start of block (Header)            1 byte    0       01       1
#indoor temperature (F)             2 bytes   1      02D3    723  <- - Intel format
#outdoor temperature (F)            2 bytes   3      0270    624  <- - Intel format
#wind speed (mph)                   1 byte    5       05       5
#wind direction                     2 bytes   6      0130    304  <- - Intel format
#barometer (inHg)                   2 bytes   8      7375  29557  <- - Intel format
#indoor humidity                    1 byte    10      21      33
#outdoor humidity                   1 byte    11      22      34
#total rain (in)                    2 bytes   12     0000      0
#not used                           2 bytes   14     0000      0
#CRC checksum                       2 bytes   16     15E8   5608   <- - NOT BYTE SWAPED
#                                  --------
#                                  18 bytes
#
#  Wind speed and wind direction are read and stored in the sensor image each time around the loop.
#  Temperature data is updated once for every ten wind speed readings.
#  Humidity, Barometer, and Rain are updated every time the sensor image is updated.
#
#  All binary data is transferred in "Intel" format: least significant byte first, except CRC Checksum.
#

sub process {
    my ( $data, $wptr ) = @_;
    my @data = unpack( 'C*', $data );
    my $gotheader = 0;

    if ( $::Debug{weather} ) {
        my $debugInfo = 'daviswm2: Read from Davis WM II ';
        for (@data) {
            $debugInfo .= sprintf( "0x%x ", $_ );
        }
        &::print_log($debugInfo);
    }

    my @bytes;

    my $foundHeader = 0;

    my (
        $indoor_temp,      $outdoor_temp, $wind_speed,
        $wind_direction,   $barometer,    $indoor_humidity,
        $outdoor_humidity, $total_rain,   $not_used,
        $crc16,            $rain_rate
    );

    # go through data until we have found a header
    &::print_log("daviswm2: looking for header") if $::Debug{weather};
    my $headerByte;
    while ( defined( $headerByte = shift(@data) ) ) {
        next if $headerByte != 1;    # need a 1 at start of data
        &::print_log(
            "daviswm2: found header, checking length and crc16 of remaining data"
        ) if $::Debug{weather};
        $data = pack( 'C*', @data );
        if ( length($data) < 17 ) {    # we need 17 bytes left to proceed
            &::print_log("daviswm2: not enough bytes left to process")
              if $::Debug{weather};
            return
              chr($headerByte) . $data; # need to return the header byte as well
        }
        (
            $indoor_temp,      $outdoor_temp, $wind_speed,
            $wind_direction,   $barometer,    $indoor_humidity,
            $outdoor_humidity, $total_rain,   $not_used,
            $crc16
        ) = unpack( 'vvCvvCCvvn', $data );
        if ( Digest::mhCRC::crc16( substr( $data, 0, 15 ) ) != $crc16 ) {
            &::print_log("daviswm2: wrong crc16, looking again for header")
              if $::Debug{weather};
            next;
        }

        # remove the 17 bytes that we just processed, we'll use the remainder as our return value
        $data = substr( $data, 17 );
        last;
    }

    # return because we didn't find a header :-(
    if ( $headerByte != 1 ) {
        &::print_log("daviswm2: ran out of bytes and didn't find a header")
          if $::Debug{weather};

        # don't use $data as return value as it only has a valid
        # value if a good header/packet is found
        return '';
    }

    &::print_log("daviswm2: found a header with the right checksum")
      if $::Debug{weather};

    # correct reading from reported to actual (just moving the decimal point)
    $indoor_temp  /= 10.0;
    $outdoor_temp /= 10.0;
    $barometer    /= 1000.0;
    $total_rain   /= 10.0;

    # barometric trend analysis
    my $btr_current_sample_time = time;

    ## save our barometric reading
    $barom_samples{$btr_current_sample_time} = $barometer;

    &::print_log("daviswm2: barometric samples") if $::Debug{weather};

    ## do the analysis on our dataset
    my $btr_tmp_counter = 0;
    my $btr_sum_head    = 0.0;
    my $btr_sum_tail    = 0.0;
    my ( $btr_datetime, $btr_barom, $btr_exflag, @btr_expire_list );
    while ( ( $btr_datetime, $btr_barom ) = each %barom_samples ) {

        # If the sample is older then 1 hour add to our remove list
        my $datediff = $btr_current_sample_time - $btr_datetime;
        if ( $datediff > 3600 ) {    # 3600s = 1 hour
            push( @btr_expire_list, $btr_datetime );
            $btr_exflag = "*" if $::Debug{weather};
        }
        else {
            $btr_exflag = " " if $::Debug{weather};
        }
        if ( $barom_samples->Length >= 10 ) {
            if ( $btr_tmp_counter < 5 ) {
                $btr_sum_head += $btr_barom;
                $btr_exflag .= "T" if $::Debug{weather};
            }
            else {
                if ( $btr_tmp_counter >= $barom_samples->Length - 5 ) {
                    $btr_sum_tail += $btr_barom;
                    $btr_exflag .= "H" if $::Debug{weather};
                }
            }
        }
        if ( $::Debug{weather} ) {
            &::print_log( "daviswm2:   "
                  . localtime($btr_datetime)
                  . " -> $btr_barom $btr_exflag $datediff" );
        }
        $btr_tmp_counter++;
    }

    ## calculate our average over 5 samples
    $btr_sum_head /= 5.0;
    $btr_sum_tail /= 5.0;

    ## calculate our difference
    my $btr_diff = $btr_sum_tail - $btr_sum_head;

    ## fetch last sample
    my $btr_last_diff =
      abs( $barometer - $barom_samples->Values( $barom_samples->Length - 2 ) );
    my $btr_last_value = $barom_samples->Values( $barom_samples->Length - 2 );

    &::print_log("daviswm2: last value($btr_last_value) diff($btr_last_diff)")
      if $::Debug{weather};

    ## calculate tendency
    if ( $btr_last_diff >= .03 or $barom_samples->Length < 15 ) {
        &::print_log(
            "daviswm2: unsteading reading $btr_last_diff $btr_last_value")
          if $::Debug{weather};
        $barom_tendency = "unsteady";
    }
    else {
        $barom_tendency = "rising rapidly" if $btr_diff > 0.06;
        $barom_tendency = "rising slowly"
          if $btr_diff > 0.02 and $btr_diff < 0.06;
        $barom_tendency = "steady"          if abs($btr_diff) < 0.02;
        $barom_tendency = "falling rapidly" if $btr_diff < -0.06;
        $barom_tendency = "falling slowly"
          if $btr_diff < -0.02 and $btr_diff > -0.06;
    }

    &::print_log("daviswm2: head($btr_sum_head) tail($btr_sum_tail)")
      if $::Debug{weather};

    ## remove expired values
    foreach (@btr_expire_list) {
        $barom_samples->DELETE($_);
    }

    # calculate sea level pressure
    my $barometer_sea = convert_local_barom_to_sea_in($barometer);

    # these dewpoints will be in Celsius
    my $indoor_dewpoint =
      &::convert_humidity_to_dewpoint( $indoor_humidity,
        &::convert_f2c($indoor_temp) );
    my $outdoor_dewpoint =
      &::convert_humidity_to_dewpoint( $outdoor_humidity,
        &::convert_f2c($outdoor_temp) );

    $rain_rate = undef;
    if ( defined($lastRainReadingTime) ) {
        $rain_rate = ( $total_rain - $lastRainReading );    # delta in inches
        my $time_delta = ( time - $lastRainReadingTime );
        if ( $time_delta != 0 ) {
            $rain_rate /= $time_delta;    # rate in inches per second
            $rain_rate *= 3600;           # rate in inches per hour
            if ( $rain_rate < 0 )
            {    # if total rain was reset to zero, this could happen
                $rain_rate = 0;
            }
        }
    }
    $lastRainReadingTime = time;
    $lastRainReading     = $total_rain;

    if ( $main::config_parms{weather_uom_temp} eq 'C' ) {
        grep { $_ = &::convert_f2c($_); } ( $indoor_temp, $outdoor_temp );

        # remember, dewpoints are in Celsius by default
    }
    elsif ( $main::config_parms{weather_uom_temp} eq 'F' ) {
        grep { $_ = &::convert_c2f($_); }
          ( $indoor_dewpoint, $outdoor_dewpoint );
    }
    if ( $main::config_parms{weather_uom_baro} eq 'mb' ) {
        grep { $_ = &::convert_in2mb($_); } ( $barometer, $barometer_sea );
    }
    if ( $main::config_parms{weather_uom_rain} eq 'mm' ) {
        grep { $_ = &::convert_in2mm($_); } ($total_rain);
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

    $$wptr{TempIndoor}    = $indoor_temp;
    $$wptr{TempOutdoor}   = $outdoor_temp;
    $$wptr{DewIndoor}     = $indoor_dewpoint;
    $$wptr{DewOutdoor}    = $outdoor_dewpoint;
    $$wptr{WindAvgSpeed}  = $wind_speed;
    $$wptr{WindGustSpeed} = $wind_speed;
    $$wptr{WindAvgDir}    = $wind_direction;
    $$wptr{WindGustDir}   = $wind_direction;
    $$wptr{Barom}         = $barometer;
    $$wptr{BaromSea}      = $barometer_sea;
    $$wptr{HumidIndoor}   = $indoor_humidity;
    $$wptr{HumidOutdoor}  = $outdoor_humidity;
    $$wptr{RainTotal}     = $total_rain;
    $$wptr{RainRate}      = $rain_rate;
    $$wptr{BaromDelta}    = $barom_tendency;

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
          BaromDelta
          HumidIndoor
          HumidOutdoor
          RainTotal
          RainRate
          ) {
            &::print_log( "daviswm2: $key " . $$wptr{$key} );
          };
    }

    &::weather_updated;
    return $data;
}

# all modules must return 1.  don't remove the following line
1;
