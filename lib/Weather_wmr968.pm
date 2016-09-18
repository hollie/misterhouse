# $Date$
# $Revision$

use strict;

package Weather_wmr968;

use Weather_Common;

=begin comment
# =============================================================================
# 11/18/01
Tom Vanderpool modified Bruce Winter's wx200 code to enable use of it
for the OS wmr968/918 and Radio Shack Accuweather Wireless weather stations.
The wx200 ~ wmr918 ~ wmr968 from what I could tell. It seems the main difference
in the wx200 and the 918/968 is the format of the data returned. The difference
between the 918 and the 968 that I found reference to was that the 918 is wired
and the 968 is wireless. Radio Shack has an Accuweather Wireless Weather Station
(63-1016) which is what I have.

 This mh code reads data from the Radio Shack Weather station but should work on the
918 & 968.

One of the big differences that will be seen when comparing this code to
Bruce's original is that the offsets have changed and the data is grouped
differently. With his, all the temperatures seemed to be returned at once
while with mine, all the inside readings are returned in one chunk.
(temp, humid, dew etc)

I also used the FULL data stream (including the first 2 FF hex bytes)
which means that you will need to add 2 to the offsets given in the
definition (they ignored the first 2 bytes).

And it appears that when in a called subroutine, there is one byte added
to the array so I had to compensate for that where it occurred.

# To use it, add these mh.ini parms
#  serial_wmr968_port      = COM7
#  serial_wmr968_baudrate  = 9600
#  serial_wmr968_handshake = dtr
#  serial_wmr968_datatype  = raw
#  serial_wmr968_module    = Weather_wmr968
#  serial_wmr968_skip      =  # Use to ignore bad sensor data.  e.g. TempOutdoor,
#                              HumidOutdoor,WindChill
# altitude = 1000 # In feet, used to find sea level barometric pressure
# in the RS weather station, it adjusts for sea level and gives a direct
# reading so altitude is not needed
#
# A complete usage example is at:
#    http://misterhouse.net/mh/code/bruce/weather_monitor.pl
# Lots of other good Wmr968 software links at:
#    http://www.qsl.net/zl1vfo/wx200/wx200.htm
# -----------------------------------------------------------------------------
# 24/11/03   1.6   Dominique Benoliel	Correct bugs and improvements
# - test for WMR928 Weather station (France)
# - Correct bug if not enough data and only 255 data (1 byte) for the first
#   pass : test data length lower than 3 (headers+device type)
# - Replace Batt. value 100% by 1=power and 0=low (better for test)
# - add $$wptr{WindGustOver} : 1=over, 0=normal
# - add $$wptr{WindAvgOver} : 1=over, 0=normal
# - add $$wptr{WindChillNoData} : 1=nodata, 0=normal
# - add $$wptr{WindChillOver} : 1=over, 0=normal
# - add $$wptr{DateMain} : format YYMMDDHHMM
# - add $$wptr{MinuteMain} : format MM
# - add $$wptr{RainRateOver} : 1=over, 0=normal
# - add $$wptr{RainTotalOver} : 1=over, 0=normal
# - add $$wptr{RainYestOver} : 1=over, 0=normal
# - add $$wptr{RainTotalStartDate} : format YYMMDDHHMM
# - add $$wptr{"ChannelSpare"} : channel 1, 2 ou 3 for extra sensor
# - add $$wptr{"DewSpareUnder1"} : 1=under, 0=normal
# - add $$wptr{"DewSpareUnder2"} : 1=under, 0=normal
# - add $$wptr{"DewSpareUnder3"} : 1=under, 0=normal
# - add $$wptr{DewOutdoorUnder} : 1=under, 0=normal
# - add	$$wptr{"TempSpareOverUnder1"} : -1=under, 1=over
# - add	$$wptr{"TempSpareOverUnder2"} : -1=under, 1=over
# - add	$$wptr{"TempSpareOverUnder3"} : -1=under, 1=over
# - add $$wptr{TempIndoorOverUnder} : -1=under, 1=over
# - add $$wptr{DewIndoorUnder} : 1=under, 0=normal
# - add $$wptr{uom_wind}
# - add $$wptr{uom_temp}
# - add $$wptr{uom_baro}
# - add $$wptr{uom_rain}
# - add $$wptr{uom_rainrate}
# - add mh.ini or mh.private.ini parameters :
#	default_uom_temp : 0=C, 1=F
#	default_uom_baro : 0=mb, 1=inHg
#	default_uom_wind : 0=mph, 1=kph
#	default_uom_rain : 0=mm, 1=in
#	default_uom_rainrate : 0=mm/hr, 1=in/hr
# - Suppress data $$wptr{WindAvgDir} : no average wind direction for wmr928,
#   wmr928 and wmr968
# - produce more lisible debug mode
# - Add device type TH (thermo only=4)
# 01/10/05   1.7   Dominique Benoliel
# - Calculate pressure sea level
# 01/23/05   1.8   Dominique Benoliel
# - make necessary conversions. Store data in global weather variable and use
#   the mh parameters weather_uom_...
# 01/24/05   1.9   Dominique Benoliel
# - fix a problem with wind data
# =============================================================================
=cut

my ( $wmr968_port, %skip );

sub startup {
    $wmr968_port = new Serial_Item( undef, undef, 'serial_wmr968' );
    &::MainLoop_pre_add_hook( \&Weather_wmr968::update_wmr968_weather, 1 );
    %skip = map { $_, 1 } split( ',', $main::config_parms{serial_wmr968_skip} )
      if $main::config_parms{serial_wmr968_skip};
}

sub update_wmr968_weather {
    return unless my $data = said $wmr968_port;

    # Process data, and reset incomplete data not processed this pass
    my $debug = 1 if $main::Debug{weather};
    my $remainder = &read_wmr968( $data, \%main::Weather, $debug );
    set_data $wmr968_port $remainder if $remainder;
    &main::weather_updated;
}

# Category=Weather
# Parse wx200 datastream into array pointed at with $wptr
# Lots of good info on the Wmr968 from: http://www.peak.org/~stanley/wmr918/dataspec
# Set up array of data types, including group index,
# group name, length of data, and relevant subroutine

# tv changed table to reflect wmr968 values
# wx_datatype : data type, nb byte, function
my %wx_datatype = (
    0x0 => [ 'wind',   11, \&wx_wind ],
    0x1 => [ 'rain',   16, \&wx_rain ],
    0x2 => [ 'temp',   9,  \&wx_spare ],
    0x3 => [ 'temp',   9,  \&wx_outside ],
    0x4 => [ 'temp',   7,  \&wx_spare ],
    0x5 => [ 'inside', 13, \&wx_inside ],
    0x6 => [ 'inside', 14, \&wx_inside ],
    0xe => [ 'seq',    5,  \&wx_seq ],
    0xf => [ 'date',   9,  \&wx_time ]
);

sub read_wmr968 {
    my ( $data, $wptr, $debug ) = @_;

    my @data = unpack( 'C*', $data );
    print "Data read : #@data#\n" if $debug;

    # Test if we have headers and device type, if not return what is left for next pass
    if ( @data < 3 ) {
        printf("     Not enough data, length<3, return data for next pass\n")
          if $debug;
        return pack( 'C*', @data );
    }

    while (@data) {
        my $group = $data[2];               # tv changed from 0
        my $dtp   = $wx_datatype{$group};

        # Check for valid datatype
        unless ($dtp) {
            my $length = @data;
            printf( "     Bad weather data = group(%x) length($length)\n",
                $group );
            return;
        }

        # If we don't have enough data, return what is left for next pass
        if ( $$dtp[1] > @data ) {
            printf("     Not enough data, return data for next pass\n")
              if $debug;
            return pack( 'C*', @data );
        }

        # Pull out the number of bytes needed for this data type
        my @data2 = splice( @data, 0, $$dtp[1] );

        # Get the checksum (last byte)
        my $checksum1 = pop @data2;

        # Control the checksum
        my $checksum2 = 0;

        # Sum of the data send (include header)
        for (@data2) {
            $checksum2 += $_;
        }

        # Control only the lower byte (lower 8 bits of the sum)
        $checksum2 &= 0xff;
        if ( $checksum1 != $checksum2 ) {
            print
              "     Warning, bad wmr968 type=$$dtp[0] checksum: cs1=$checksum1 cs2=$checksum2\n";
            print "     data2 is @data2\ndata is @data\ngroup is $group\n\n";
            next;
        }

        # Process the data
        &{ $$dtp[2] }( $wptr, $debug, @data2 );
    }
}

sub wx_temp2 {
    my ( $n1, $n2 ) = @_;
    my $temp = sprintf( '%x%02x', 0x07 & $n2, $n1 );
    substr( $temp, 2, 0 ) = '.';
    $temp *= -1 if 0x80 & $n2;
    $temp = &main::convert_c2f($temp);
    return $temp;
}

#=============================================================================
# DECODE DATA TYPE RAIN GAUGE
# Byte	Nibble	Bit	Meaning
#  0	01		Rain guage packet
#  1    xB			Unknown
#  1	Bx	 4	Rate over
#  1	Bx	 5	Total over
#  1	Bx	 6	Low batt.
#  1	Bx	 7	Yesterday over
#  2	DD		Rain rate, bc of 0<abc<999 mm/hr
#  3	xD		Rain rate, a of 0<abc<999 mm/hr
#  3	Dx		Rain Total, e of 0<abcd.e<9999.9 mm
#  4	DD		Rain Total, cd of 0<abcd.e<9999.9 mm
#  5	DD		Rain Total, ab of 0<abcd.e<9999.9 mm
#  6	DD		Rain Yesterday, cd of 0<abcd<9999 mm
#  7	DD		Rain Yesterday, ab of 0<abcd<9999 mm
#  8	DD		Total start date minute
#  9	DD		Total start date hour
#  10   DD		Total start date day
#  11   DD		Total start date month
#  12   DD		Total start date year
#=============================================================================
sub wx_rain {
    my ( $wptr, $debug, @data ) = @_;

    unless ( $skip{RainRateOver} ) {
        $$wptr{RainRateOver} = ( ( $data[3] & 0x10 ) >> 4 ) ? 1 : 0;
    }
    unless ( $skip{RainTotalOver} ) {
        $$wptr{RainTotalOver} = ( ( $data[3] & 0x20 ) >> 5 ) ? 1 : 0;
    }
    unless ( $skip{BatRain} ) {
        $$wptr{BatRain} = ( ( $data[3] & 0x40 ) >> 6 ) ? 0 : 1;
    }
    unless ( $skip{RainYestOver} ) {
        $$wptr{RainYestOver} = ( ( $data[3] & 0x80 ) >> 7 ) ? 1 : 0;
    }
    unless ( $skip{RainRate} ) {
        $$wptr{RainRate} =
          sprintf( '%u', 0x0f & $data[5] ) * 100 +
          sprintf( '%u', ( 0xf0 & $data[4] ) >> 4 ) * 10 +
          sprintf( '%u', 0x0f & $data[4] );
        $$wptr{RainRate} = &main::convert_mm2in( $$wptr{RainRate} )
          if $main::config_parms{weather_uom_rainrate} eq 'in/hr';
    }
    unless ( $skip{RainTotal} ) {
        $$wptr{RainTotal} =
          sprintf( '%u', ( 0xf0 & $data[7] ) >> 4 ) * 1000 +
          sprintf( '%u', 0x0f & $data[7] ) * 100 +
          sprintf( '%u', ( 0xf0 & $data[6] ) >> 4 ) * 10 +
          sprintf( '%u', 0x0f & $data[6] ) +
          sprintf( '%u', ( 0xf0 & $data[5] ) >> 4 ) * 0.1;

        $$wptr{RainTotal} = &main::convert_mm2in( $$wptr{RainTotal} )
          if $main::config_parms{weather_uom_rain} eq 'in';
    }
    unless ( $skip{RainYest} ) {
        $$wptr{RainYest} =
          sprintf( '%u', ( 0xf0 & $data[9] ) >> 4 ) * 1000 +
          sprintf( '%u', 0x0f & $data[9] ) * 100 +
          sprintf( '%u', ( 0xf0 & $data[8] ) >> 4 ) * 10 +
          sprintf( '%u', 0x0f & $data[8] );
        $$wptr{RainYest} = &main::convert_mm2in( $$wptr{RainYest} )
          if $main::config_parms{weather_uom_rain} eq 'in';
    }
    unless ( $skip{RainTotalStartDate} ) {
        $$wptr{RainTotalStartDate} = sprintf( "%02x%02x%02x%02x%02x",
            $data[14], $data[13], $data[12], $data[11], $data[10] );
    }

    print "** RAIN GAUGE : $main::Time_Date\n"               if $debug;
    print "       BatRain         ($$wptr{BatRain})\n"       if $debug;
    print "       RainRateOver    ($$wptr{RainRateOver})\n"  if $debug;
    print "       RainTotalOver   ($$wptr{RainTotalOver})\n" if $debug;
    print "       YesterdayOver   ($$wptr{RainYestOver})\n"  if $debug;
    print
      "       RainRate        ($$wptr{RainRate} $main::config_parms{weather_uom_rainrate})\n"
      if $debug;
    print
      "       RainTotal       ($$wptr{RainTotal} $main::config_parms{weather_uom_rain})\n"
      if $debug;
    print
      "       RainYesterday   ($$wptr{RainYest} $main::config_parms{weather_uom_rain})\n"
      if $debug;
    print "       RainTotalStartDate ($$wptr{RainTotalStartDate})\n" if $debug;
}

#=============================================================================
# DECODE DATA TYPE ANEMOMETER
# Byte	Nibble	Bit	Meaning
#  0	00		Anemometer data packet
#  1    xB		Unknown
#  1	Bx	 4	gust over
#  1    Bx	 5	average over
#  1    Bx	 6	low batt
#  1    Bx	 7	Unknown
#  2	DD		Gust direction, bc of 0<abc<359 degrees
#  3	xD		Gust direction, a  of 0<abc<359 degrees
#  3	Dx		Gust speed, c  of 0<ab.c<56 m/s
#  4	DD		Gust speed, ab of 0<ab.c<56 m/s
#  5	DD		Average speed, bc  of 0<ab.c<56 m/s
#  6	xD		Average speed, a of 0<ab.c<56 m/s
#  6	Bx	4	Unknown
#  6	Bx	5	Chill no data
#  6	Bx	6	Chill over
#  6	Bx	7	Sign of wind chill, 1 = negative
#  7	DD		Wind chill
#=============================================================================
sub wx_wind {
    my ( $wptr, $debug, @data ) = @_;

    unless ( $skip{WindGustOver} ) {
        $$wptr{WindGustOver} = ( ( $data[3] & 0x10 ) >> 4 ) ? 1 : 0;
    }
    unless ( $skip{WindAvgOver} ) {
        $$wptr{WindAvgOver} = ( ( $data[3] & 0x20 ) >> 5 ) ? 1 : 0;
    }
    unless ( $skip{BatWind} ) {
        $$wptr{BatWind} = ( ( $data[3] & 0x40 ) >> 6 ) ? 0 : 1;
    }
    unless ( $skip{WindGustSpeed} ) {
        $$wptr{WindGustSpeed} =
          sprintf( '%u', ( 0xf0 & $data[6] ) >> 4 ) * 10 +
          sprintf( '%u', 0x0f & $data[6] ) +
          sprintf( '%u', ( 0xf0 & $data[5] ) >> 4 ) * 0.1;
        $$wptr{WindGustSpeed} =
          sprintf( '%.0f', &main::convert_mps2kph( $$wptr{WindGustSpeed} ) )
          if $main::config_parms{weather_uom_wind} eq 'kph';
        $$wptr{WindGustSpeed} =
          sprintf( '%.0f', &main::convert_mps2mph( $$wptr{WindGustSpeed} ) )
          if $main::config_parms{weather_uom_wind} eq 'mph';
        $$wptr{WindGustDir} =
          sprintf( '%u', 0x0f & $data[5] ) * 100 +
          sprintf( '%u', ( 0xf0 & $data[4] ) >> 4 ) * 10 +
          sprintf( '%u', 0x0f & $data[4] );
        $$wptr{WindAvgDir} = $$wptr{WindGustDir};
    }
    unless ( $skip{WindAvgSpeed} ) {
        $$wptr{WindAvgSpeed} =
          sprintf( '%u', 0x0f & $data[8] ) * 10 +
          sprintf( '%u', ( 0xf0 & $data[7] ) >> 4 ) +
          sprintf( '%u', 0x0f & $data[7] ) * 0.1;
        $$wptr{WindAvgSpeed} =
          sprintf( '%.0f', &main::convert_mps2kph( $$wptr{WindAvgSpeed} ) )
          if $main::config_parms{weather_uom_wind} eq 'kph';
        $$wptr{WindAvgSpeed} =
          sprintf( '%.0f', &main::convert_mps2mph( $$wptr{WindAvgSpeed} ) )
          if $main::config_parms{weather_uom_wind} eq 'mph';
        $$wptr{WindAvgSpeed} = sprintf( '%.0f', $$wptr{WindAvgSpeed} );
    }
    unless ( $skip{WindChill} ) {

        # currently commented out as generally accepted windchill formula has changed since product was released
        # Weather_Common will calculate it for us anyway
        #        $$wptr{WindChill} = sprintf('%x', $data[9]);
        #        $$wptr{WindChill} *= -1 if 0x80 & $data[8];
        #        $$wptr{WindChill} = &main::convert_c2f($$wptr{WindChill}) if $main::config_parms{weather_uom_temp} eq 'F';
        #
        #        $$wptr{WindChillNoData} = (0x20 & $data[8])?1:0;
        #        $$wptr{WindChillOver} = (0x40 & $data[8])?1:0;
    }

    print "** ANEMOMETER : $main::Time_Date\n"              if $debug;
    print "       BatWind         ($$wptr{BatWind})\n"      if $debug;
    print "       WindGustOver    ($$wptr{WindGustOver})\n" if $debug;
    print "       WindAvgOver     ($$wptr{WindAvgOver})\n"  if $debug;
    print
      "       WindGustSpeed   ($$wptr{WindGustSpeed} $main::config_parms{weather_uom_wind})\n"
      if $debug;
    print "       WindGustDir     ($$wptr{WindGustDir})\n" if $debug;
    print
      "       WindAvgSpeed    ($$wptr{WindAvgSpeed} $main::config_parms{weather_uom_wind})\n"
      if $debug;

    #    print "       WindChill       ($$wptr{WindChill})\n" if $debug;
    #    print "       WindChillNoData ($$wptr{WindChillNoData})\n" if $debug;
    #    print "       WindChillOver   ($$wptr{WindChillOver})\n" if $debug;
}

#=============================================================================
# DECODE DATA TYPE CLOCK
# This hits once an hour or when new RF clock time is being received.
# Byte	Nibble	Bit	Meaning
#  0	0f	 	Sequence number packet
#  1	xB	  	Date 1 digit minute
#  1	Bx	 4	Date 10 digit minute
#  1	Bx	 5	Date 10 digit minute
#  1	Bx	 6	Date 10 digit minute
#  1	Bx	 7	Batt. low
#  2	DD	  	Date hour
#  3	DD	  	Date Day
#  4	DD	  	Date Month
#  5	DD	  	Date Year
#=============================================================================
sub wx_time {
    my ( $wptr, $debug, @data ) = @_;

    #$$wptr{BatMain} = "Please check" if 0x80 & @data[3];
    $$wptr{BatMain} = ( ( $data[3] & 0x80 ) >> 7 ) ? 0 : 1;

    $$wptr{DateMain} = sprintf( "%x%x%x%x%u%u",
        $data[7], $data[6], $data[5], $data[4],
        ( $data[3] & 0x70 ) >> 4,
        $data[3] & 0x0F )
      if $debug;

    print "** MAIN UNIT - CLOCK : $main::Time_Date\n"   if $debug;
    print "       BatMain         ($$wptr{BatMain})\n"  if $debug;
    print "       DateMain        ($$wptr{DateMain})\n" if $debug;
}

#=============================================================================
# BARO-THERMO-HYGROMETER
#Byte	Nibble	Bit	Meaning
# 0	06	        Device 5=BTH, 6=EXTBTH
# 1	xB		Unknown
# 1	Bx	5	Dew under : 1=under, 0=normal
# 1	Bx	6	Battery status. Higher value == lower battery volt
# 2	DD		Temp, bc of eab.c Celsius
# 3	xD		Temp, a of eab.c Celsius
# 3	Dx	4,5	Temp, e of eab.c Celcius
# 3	Bx	6	Over/under
# 3	Bx	7	Sign of outside temp, 1 = negative
# 4	DD		Relative humidity, ab of ab percent
# 5	DD		Dew point, ab of ab Celsius
# 6	HH		Baro pressure, convert to decimal and
# 			add 600mb for device 6
# device 6
# 7	xB		Encoded 'tendency' 0x0c=clear 0x06=partly cloudy
#			0x02=cloudy 0x03=rain
# 8	DD		Sea level reference, cd of <abc.d>.
# 9	DD		Sea level reference, ab of <abc.d>. Add this to raw
#			bp from byte 6 to get sea level pressure.
#=============================================================================
sub wx_inside {
    my $xb = "";
    my ( $wptr, $debug, @data ) = @_;
    my %eval = (
        0xc0 => "Sunny",
        0x60 => "Partly Cloudy",
        0x30 => "Rain",
        0x20 => "Cloudy",
    );

    $$wptr{BatIndoor} = ( ( $data[3] & 0x40 ) >> 6 ) ? 0 : 1;

    unless ( $skip{TempIndoor} ) {
        $$wptr{TempIndoor} =
          sprintf( '%u', ( 0x0f & $data[4] ) ) * 0.1 +
          sprintf( '%u', ( 0xf0 & $data[4] ) >> 4 ) * 1 +
          sprintf( '%u', ( 0x0f & $data[5] ) ) * 10 +
          sprintf( '%u', ( 0x30 & $data[5] ) >> 4 ) * 100;
        $$wptr{TempIndoor} *= -1 if 0x80 & $data[5];
        $$wptr{TempIndoor} = &main::convert_c2f( $$wptr{TempIndoor} )
          if $main::config_parms{weather_uom_temp} eq 'F';

        #Over/Under
        $$wptr{TempIndoorOverUnder} =
          ( ( ( $data[5] & 0x40 ) >> 6 ) ? 1  : 0 ) *
          ( ( 0x80 & $data[5] )          ? -1 : 1 );
    }
    $$wptr{DewIndoorUnder} = ( $data[3] & 0x10 ) >> 4;

    unless ( $skip{HumidIndoor} ) {
        $$wptr{HumidIndoor} =
          sprintf( '%u', ( 0x0f & $data[6] ) ) * 1 +
          sprintf( '%u', ( 0xf0 & $data[6] ) >> 4 ) * 10;
    }
    unless ( $skip{DewIndoor} ) {
        $$wptr{DewIndoor} =
          sprintf( '%u', ( 0x0f & $data[7] ) ) * 1 +
          sprintf( '%u', ( 0xf0 & $data[7] ) >> 4 ) * 10;
        $$wptr{DewIndoor} = &main::convert_c2f( $$wptr{DewIndoor} )
          if $main::config_parms{weather_uom_temp} eq 'F';
    }

    $$wptr{WxTendency} = &wx_f968;

    unless ( $skip{Barom} ) {
        $xb = &wx_b968;
        $$wptr{Barom} = sprintf( '%.2f', ( $xb + 600 ) );

        $$wptr{BaromSea} =
          &main::convert_local_barom_to_sea_mb( $$wptr{Barom} );
        if ( $main::config_parms{weather_uom_baro} eq 'in' ) {
            grep { $_ = &main::convert_mb2in($_); }
              ( $$wptr{Barom}, $$wptr{BaromSea} );
        }
    }

    print "** BARO-THERMO-HYGROMETER : $main::Time_Date\n" if $debug;
    print "       Device type     ($data[2])\n"            if $debug;
    print "       BatIndoor       ($$wptr{BatIndoor})\n"   if $debug;
    print
      "       TempIndoor      ($$wptr{TempIndoor} $main::config_parms{weather_uom_temp})\n"
      if $debug;
    print "       TempIndoorOverUnder ($$wptr{TempIndoorOverUnder})\n"
      if $debug;
    print "       HumidIndoor     ($$wptr{HumidIndoor})\n" if $debug;
    print
      "       DewIndoor       ($$wptr{DewIndoor} $main::config_parms{weather_uom_temp})\n"
      if $debug;
    print "       DewIndoorUnder  ($$wptr{DewIndoorUnder})\n" if $debug;
    print "       WxTendency      ($$wptr{WxTendency})\n"     if $debug;
    print "       Barom           ($$wptr{Barom})\n"          if $debug;
    print "       BaromSea        ($$wptr{BaromSea})\n"       if $debug;
}

#=============================================================================
# THERMO HYGRO THERMO-HYGROMETER (OUTSIDE)
# Byte	Nibble	Bit	Meaning
#  0	02		temp/humidity data
#  1	xB		Unknown
#  1	Bx	5	Dew under : 1=under, 0=normal
#  1	Bx	6	Battery status. Higher value == lower battery volt
#  2	DD		Temp, bc of eab.c Celsius
#  3	xD		Temp, a of eab.c Celsius
#  3	Dx	4,5	Temp, e of eab.c Celcius
#  3	Bx	6	Over/under
#  3	Bx	7	Sign of outside temp, 1 = negative
#  4	DD		Relative humidity, ab of ab percent
#  5	DD		Dew point, ab of ab Celsius
#=============================================================================
sub wx_outside {
    my ( $wptr, $debug, @data ) = @_;

    $$wptr{BatOutdoor} = ( ( $data[3] & 0x40 ) >> 6 ) ? 0 : 1;

    unless ( $skip{TempOutdoor} ) {
        $$wptr{TempOutdoor} =
          sprintf( '%u', ( 0x0f & $data[4] ) ) * 0.1 +
          sprintf( '%u', ( 0xf0 & $data[4] ) >> 4 ) * 1 +
          sprintf( '%u', ( 0x0f & $data[5] ) ) * 10 +
          sprintf( '%u', ( 0x30 & $data[5] ) >> 4 ) * 100;
        $$wptr{TempOutdoor} *= -1 if 0x80 & $data[5];
        $$wptr{TempOutdoor} = &main::convert_c2f( $$wptr{TempOutdoor} )
          if $main::config_parms{weather_uom_temp} eq 'F';

        #Over/Under
        $$wptr{TempOutdoorOverUnder} =
          ( ( ( $data[5] & 0x40 ) >> 6 ) ? 1  : 0 ) *
          ( ( 0x80 & $data[5] )          ? -1 : 1 );
    }
    $$wptr{DewOutdoorUnder} = ( $data[3] & 0x10 ) >> 4;

    unless ( $skip{HumidOutdoor} ) {
        $$wptr{HumidOutdoor} =
          sprintf( '%u', ( 0x0f & $data[6] ) ) * 1 +
          sprintf( '%u', ( 0xf0 & $data[6] ) >> 4 ) * 10;

        # Let Weather_Common know that we 'directly' measured humidity
        $$wptr{HumidOutdoorMeasured} = 1;
    }
    unless ( $skip{DewOutdoor} ) {
        if ( !$$wptr{DewOutdoorUnder} ) {
            $$wptr{DewOutdoor} =
              sprintf( '%u', ( 0x0f & $data[7] ) ) * 1 +
              sprintf( '%u', ( 0xf0 & $data[7] ) >> 4 ) * 10;
            $$wptr{DewOutdoor} = &main::convert_c2f( $$wptr{DewOutdoor} )
              if $main::config_parms{weather_uom_temp} eq 'F';
        }
    }
    print "** THERMO-HYGROMETER : $main::Time_Date\n"      if $debug;
    print "       BatOutdoor       ($$wptr{BatOutdoor})\n" if $debug;
    print
      "       TempOutdoor      ($$wptr{TempOutdoor} $main::config_parms{weather_uom_temp})\n"
      if $debug;
    print "       TempOutdoorOverUnder ($$wptr{TempOutdoorOverUnder})\n"
      if $debug;
    print "       HumidOutdoor     ($$wptr{HumidOutdoor})\n" if $debug;
    print
      "       DewOutdoor       ($$wptr{DewOutdoor} $main::config_parms{weather_uom_temp})\n"
      if $debug;
    print "       DewOutdoorUnder  ($$wptr{DewOutdoorUnder})\n" if $debug;

}

#=============================================================================
# THERMO HYGRO EXTRA SENSOR
# OR
# THERMO ONLY EXTRA SENSOR
# This unit can handle up to 3 extra sensors.
# Byte	Nibble	Bit	Meaning
#  0	02		temp/humidity data
#  1	xB		Sensor number bit encoded, 4=channel 3, 2=channel 2,
# 			1=channel 1
#  1	Bx	5	Dew under : 1=under, 0=normal
#  1	Bx	6	Battery status. Higher value == lower battery volt
#  2	DD		Temp, bc of eab.c Celsius
#  3	xD		Temp, a of eab.c Celsius
#  3	Dx	4,5	Temp, e of eab.c Celcius
#  3	Bx	6	Over/under
#  3	Bx	7	Sign of temp, 1 = negative
#  4	DD		Relative humidity, ab of ab percent
#  5	DD		Dew point, ab of ab Celsius
#=============================================================================
sub wx_spare {
    my ( $wptr, $debug, @data, $copy ) = @_;

    $$wptr{"ChannelSpare"} = ( $data[3] & 0x0F ) == 4 ? 3 : ( $data[3] & 0x0F );
    $copy = $$wptr{"ChannelSpare"};

    $$wptr{"BatSpare$copy"} = ( ( $data[3] & 0x40 ) >> 6 ) ? 0 : 1;

    unless ( $skip{"TempSpare$copy"} ) {
        $$wptr{"TempSpare$copy"} =
          sprintf( '%u', ( 0x0f & $data[4] ) ) * 0.1 +
          sprintf( '%u', ( 0xf0 & $data[4] ) >> 4 ) * 1 +
          sprintf( '%u', ( 0x0f & $data[5] ) ) * 10 +
          sprintf( '%u', ( 0x30 & $data[5] ) >> 4 ) * 100;
        $$wptr{"TempSpare$copy"} *= -1 if 0x80 & $data[5];
        $$wptr{"TempSpare$copy"} =
          &main::convert_c2f( $$wptr{"TempSpare$copy"} )
          if $main::config_parms{weather_uom_temp} eq 'F';

        #Over/Under
        $$wptr{"TempSpareOverUnder$copy"} =
          ( ( ( $data[5] & 0x40 ) >> 6 ) ? 1  : 0 ) *
          ( ( 0x80 & $data[5] )          ? -1 : 1 );
    }

    # Get Dew & Humid if thermo-hygro
    if ( $data[2] == 2 ) {
        $$wptr{"DewSpareUnder$copy"} = ( $data[3] & 0x10 ) >> 4;

        unless ( $skip{"HumidSpare$copy"} ) {
            $$wptr{"HumidSpare$copy"} =
              sprintf( '%u', ( 0x0f & $data[6] ) ) * 1 +
              sprintf( '%u', ( 0xf0 & $data[6] ) >> 4 ) * 10;
        }
        unless ( $skip{"DewSpare$copy"} ) {
            $$wptr{"DewSpare$copy"} =
              sprintf( '%u', ( 0x0f & $data[7] ) ) * 1 +
              sprintf( '%u', ( 0xf0 & $data[7] ) >> 4 ) * 10;
            $$wptr{"DewSpare$copy"} =
              &main::convert_c2f( $$wptr{"DewSpare$copy"} )
              if $main::config_parms{weather_uom_temp} eq 'F';
        }
    }
    print "** EXTRA THERMO(ONLY/HYGROMETER) #$copy : $main::Time_Date\n"
      if $debug;
    print "       Device type     ($data[2])\n"             if $debug;
    print "       ChannelSpare    ($$wptr{ChannelSpare})\n" if $debug;
    print "       BatSpare$copy       (" . $$wptr{"BatSpare$copy"} . ")\n"
      if $debug;
    print "       TempSpare$copy      ("
      . $$wptr{"TempSpare$copy"}
      . " $main::config_parms{weather_uom_temp})\n"
      if $debug;
    print "       TempSpareOverUnder$copy ("
      . $$wptr{"TempSpareOverUnder$copy"} . ")\n"
      if $debug;
    print "       HumidSpare$copy     (" . $$wptr{"HumidSpare$copy"} . ")\n"
      if $debug;
    print "       DewSpare$copy       ("
      . $$wptr{"DewSpare$copy"}
      . " $main::config_parms{weather_uom_temp})\n"
      if $debug;
    print "       DewSpareUnder$copy  (" . $$wptr{"DewSpareUnder$copy"} . ")\n"
      if $debug;
}

#=============================================================================
# DECODE DATA TYPE MINUTE
# not really sure what a "sequence" is but here is where it is handled -
# once a minute. Important thing here is this reports on the main unit
# battery which is either shown as good or not.
# Byte	Nibble	Bit	Meaning
#  0	0e		Sequence number packet
#  1	xB	  	Date 1 digit minute
#  1	Bx	 4	Date 10 digit minute
#  1	Bx	 5	Date 10 digit minute
#  1	Bx	 6	Date 10 digit minute
#  1	Bx	 7	Batt. low
#=============================================================================
sub wx_seq {
    my ( $wptr, $debug, @data ) = @_;

    $$wptr{BatMain} = ( ( $data[3] & 0x80 ) >> 7 ) ? 0 : 1;
    $$wptr{MinuteMain} =
      sprintf( "%u%u", ( $data[3] & 0x70 ) >> 4, $data[3] & 0x0F )
      if $debug;

    print "** MAIN UNIT - MINUTE : $main::Time_Date\n"    if $debug;
    print "       BatMain         ($$wptr{BatMain})\n"    if $debug;
    print "       MinuteMain      ($$wptr{MinuteMain})\n" if $debug;
}

# barometer processed
sub wx_b968 {
    my (@data) = @_;
    my $b968   = $data[10];
    my $b968h  = 0x03 & $data[11];
    $b968h = sprintf( '%x%x', $b968h, $b968 );
    $b968h = hex($b968h);
    $b968h = $b968h;
    return $b968h;
}

sub wx_f968 {
    my (@data) = @_;
    my $f968   = $data[11];
    my %eval   = (
        0xc0 => "Sunny",
        0x60 => "Partly Cloudy",
        0x30 => "Rain",
        0x20 => "Cloudy",
    );
    $f968 &= 0xf0;
    $f968 = $eval{ ( 0xf0 & $f968 ) };
    return $f968;
}
