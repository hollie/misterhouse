# $Date$
# $Revision$

use strict;

package Weather_wx200;

use Weather_Common;

=begin comment

 This mh code reads data from the wx200 Weather station

 To use it, add these mh.ini parms
  serial_wx200_port      = COM7
  serial_wx200_baudrate  = 9600
  serial_wx200_handshake = dtr
  serial_wx200_datatype  = raw
  serial_wx200_module    = Weather_wx200
  serial_wx200_skip      =  # Use to ignore bad sensor data.  e.g. TempOutdoor,HumidOutdoor,WindChill
  altitude = 1000 # In feet, used to find sea level barometric pressure

 Default temperature scale used is Fahrenheit. To change to Celsius, add the following mh.ini parm
  default_temp=Celsius

 A complete usage example is at:
   http://misterhouse.net/mh/code/bruce/weather_monitor.pl

 Lots of other good WX200 software links at:
   http://weatherwatchers.org/wxstation/WX-200/

=cut

my ( $wx200_port, %skip );

sub startup {
    $wx200_port = new Serial_Item( undef, undef, 'serial_wx200' );
    &::MainLoop_pre_add_hook( \&Weather_wx200::update_wx200_weather, 1 );
    %skip = map { $_, 1 } split( ',', $main::config_parms{serial_wx200_skip} )
      if $main::config_parms{serial_wx200_skip};
}

sub update_wx200_weather {
    return unless my $data = said $wx200_port;

    # Process data, and reset incomplete data not processed this pass
    my $debug = 1 if $main::Debug{weather};
    my $remainder = &read_wx200( $data, \%main::Weather, $debug );
    set_data $wx200_port $remainder if $remainder;
    &weather_updated;
}

# Category=Weather

# Parse wx200 datastream into array pointed at with $wptr
# Lots of good info on the WX200 from:  http://wx200.planetfall.com/

# Set up array of data types, including group index,
# group name, length of data, and relevant subroutine
my %wx_datatype = (
    0x8f => [ 'humid', 35, \&wx_humid ],
    0x9f => [ 'temp',  34, \&wx_temp ],
    0xaf => [ 'barom', 31, \&wx_baro ],
    0xbf => [ 'rain',  14, \&wx_rain ],
    0xcf => [ 'wind',  27, \&wx_wind ],
    0xff => [ 'time',  5,  \&wx_time ]
);    # wx200d only?

sub read_wx200 {
    my ( $data, $wptr, $debug ) = @_;

    my @data = unpack( 'C*', $data );

    while (@data) {
        my $group = $data[0];
        my $dtp   = $wx_datatype{$group};

        # Check for valid datatype
        unless ($dtp) {
            my $length = @data;
            printf( "Bad weather data.  group=%x length=$length\n", $group );
            return;
        }

        # If we don't have enough data, return what is left for next pass
        if ( $$dtp[1] > @data ) {
            return pack( 'C*', @data );
        }

        # Pull out the number of bytes needed for this data type
        my @data2 = splice( @data, 0, $$dtp[1] );

        # Check the checksum
        my $checksum1 = pop @data2;
        my $checksum2 = 0;
        for (@data2) {
            $checksum2 += $_;
        }
        $checksum2 &= 0xff;    # Checksum is lower 8 bits of the sum
        if ( $checksum1 != $checksum2 ) {
            print
              "Warning, bad wx200 type=$$dtp[0] checksum: cs1=$checksum1 cs2=$checksum2\n";
            next;
        }

        # Process the data
        #       print "process data $$dtp[0], $$dtp[1]\n";
        &{ $$dtp[2] }( $wptr, $debug, @data2 );
    }
}

sub wx_humid {
    my ( $wptr, $debug, @data ) = @_;
    $data[8] = 0x99
      if $data[8] > 0x99;    # Can return 0xee (238) in sub zero weather
    $data[20] = 0x99
      if $data[20] > 0x99;    # Can return 0xee (238) in sub zero weather
    $$wptr{HumidIndoor} = sprintf( '%x', $data[8] ) unless $skip{HumidIndoor};
    $$wptr{HumidOutdoor} = sprintf( '%x', $data[20] )
      unless $skip{HumidOutdoor};
    print "humidity = $$wptr{HumidIndoor}, $$wptr{HumidOutdoor}\n" if $debug;

    #   $wx_counts{time}++;
}

#8F. 8	DD	all	Humid	Indoor:    10<ab<97 % @ 1
#8F.20	DD	all	Humid	Outdoor:    10<ab<97 % @ 1

sub wx_temp {
    my ( $wptr, $debug, @data ) = @_;
    $$wptr{TempIndoor} = &wx_temp2( @data[ 1 .. 2 ] ) unless $skip{TempIndoor};
    $$wptr{TempOutdoor} = &wx_temp2( @data[ 16 .. 17 ] )
      unless $skip{TempOutdoor};
    if ( $main::config_parms{weather_uom_temp} eq 'F' ) {
        grep { $$wptr{$_} = &::convert_c2f( $$wptr{$_} ) unless $skip{$_}; } qw(
          TempIndoor
          TempOutdoor
        );
    }
    print "temp = $$wptr{TempIndoor}, $$wptr{TempOutdoor}\n" if $debug;

    #   $wx_counts{temp}++;
}

#9F. 1	DD	all	Temp	Indoor: 'bc' of 0<ab.c<50 degrees C @ 0.1
#9F. 2	-B	0-2	Temp	Indoor: 'a' of <ab.c> C
#9F. 2	-B	3	Temp	Indoor: Sign 0=+, 1=-
#9F.16	DD	all	Temp	Outdoor: 'bc' of -40<ab.c<60 degrees C @ 0.1
#9F.17	-B	0-2	Temp	Outdoor: 'a' of <ab.c> C
#9F.17	-B	3	Temp	Outdoor: Sign 0=+, 1=-

sub wx_temp2 {
    my ( $n1, $n2 ) = @_;
    my $temp = sprintf( '%x%02x', 0x07 & $n2, $n1 );
    substr( $temp, 2, 0 ) = '.';
    $temp *= -1 if 0x08 & $n2;
    return $temp;
}

sub wx_baro {
    my ( $wptr, $debug, @data ) = @_;
    $$wptr{Barom} = sprintf( '%x%02x', $data[2], $data[1] ) unless $skip{Barom};

    unless ( $skip{BaromSea} ) {
        $$wptr{BaromSea} =
          sprintf( '%x%02x%02x', 0x0f & $data[5], $data[4], $data[3] );
        substr( $$wptr{BaromSea}, -1, 0 ) = '.';
        if ( $$wptr{BaromSea} == $$wptr{Barom} ) {
            $$wptr{BaromSea} =
              &::convert_local_barom_to_sea_mb( $$wptr{Barom} );
        }
    }

    if ( $main::config_parms{weather_uom_baro} eq 'in' ) {
        $$wptr{Barom}    = &::convert_mb2in( $$wptr{Barom} );
        $$wptr{BaromSea} = &::convert_mb2in( $$wptr{BaromSea} );
    }

    $data[18] = 0x00
      if $data[18] == 0xee;    # Returns 0xee (238) in sub zero weather

    $$wptr{DewIndoor}  = sprintf( '%x', $data[7] )  unless $skip{DewIndoor};
    $$wptr{DewOutdoor} = sprintf( '%x', $data[18] ) unless $skip{DewOutdoor};
    if ( $main::config_parms{weather_uom_temp} eq 'F' ) {
        grep { $$wptr{$_} = &::convert_c2f( $$wptr{$_} ) unless $skip{$_}; } qw(
          DewIndoor
          DewOutdoor
        );
    }
    print
      "baro = $$wptr{Barom}, $$wptr{BaromSea} dew=$$wptr{DewIndoor}, $$wptr{DewOutdoor}\n"
      if $debug;

    #   $wx_counts{baro}++;
}

#AF. 1	DD	all	Barom	Local: 'cd' of 795<abcd<1050 mb @ 1
#AF. 2	DD	all	Barom	Local: 'ab' of <abcd> mb
#AF. 3	DD	all	Barom	SeaLevel: 'de' of 795<abcd.e<1050 mb @ .1
#AF. 4	DD	all	Barom	SeaLevel: 'bc' of <abcd.e> mb
#AF. 5	-D	all	Barom	SeaLevel: 'a' of <abcd.e> mb
#AF. 5	Bx	0,1	Barom	Format: 0=inches, 1=mm, 2=mb, 3=hpa
#AF. 7	DD	all	Dewpt	Indoor:    0<ab<47 degrees C @ 1
#AF.18	DD	all	Dewpt	Outdoor:    0<ab<56 degrees C @ 1

sub wx_rain {
    my ( $wptr, $debug, @data ) = @_;
    $$wptr{RainRate} = sprintf( '%x%02x', 0x0f & $data[2], $data[1] )
      unless $skip{RainRate};
    $$wptr{RainYest} = sprintf( '%x%02x', $data[4], $data[3] )
      unless $skip{RainYest};
    $$wptr{RainTotal} = sprintf( '%x%02x', $data[6], $data[5] )
      unless $skip{RainTotal};

    if ( $main::config_parms{weather_uom_rain} eq 'in' ) {
        grep { $$wptr{$_} = &::convert_mm2in( $$wptr{$_} ) unless $skip{$_}; }
          qw(
          RainRate
          RainYest
          RainTotal
        );
    }
    print "rain = $$wptr{RainRate}, $$wptr{RainYest}, $$wptr{RainTotal}\n"
      if $debug;

    $$wptr{SummaryRain} =
      sprintf( "Rain Recent/Total: %3.1f / %4.1f  Barom: %4d",
        $$wptr{RainYest}, $$wptr{RainTotal}, $$wptr{Barom} );

    #   print "rain=@data\n";
    #   $wx_counts{rain}++;
}

#BF. 1	DD	all	Rain	Rate: 'bc' of 0<abc<998 mm/hr @ 1
#BF. 2	-D	all	Rain	Rate: 'a' of <abc> mm/hr
#BF. 2	Bx	all
#BF. 3	DD	all	Rain	Yesterday: 'cd' of 0<abcd<9999 mm @ 1
#BF. 4	DD	all	Rain	Yesterday: 'ab' of <abcd> mm
#BF. 5	DD	all	Rain	Total: 'cd' of <abcd> mm
#BF. 6	DD	all	Rain	Total: 'ab' of <abcd> mm

sub wx_wind {
    my ( $wptr, $debug, @data ) = @_;
    unless ( $skip{WindGustSpeed} ) {
        $$wptr{WindGustSpeed} = sprintf( '%x%02x', 0x0f & $data[2], $data[1] );
        substr( $$wptr{WindGustSpeed}, -1, 0 ) = '.';
        $$wptr{WindGustDir} = sprintf( '%x%01x', $data[3], $data[2] >> 4 );
    }
    unless ( $skip{WindAvgSpeed} ) {
        $$wptr{WindAvgSpeed} = sprintf( '%x%02x', 0x0f & $data[5], $data[4] );
        substr( $$wptr{WindAvgSpeed}, -1, 0 ) = '.';
        $$wptr{WindAvgDir} = sprintf( '%x%01x', $data[6], $data[5] >> 4 );
    }

    # 	This is calculated by Weather_Common using a more modern formula
    #    unless ($skip{WindChill}) {
    #        $$wptr{WindChill} = sprintf('%x', $data[16]);
    #        $$wptr{WindChill} *= -1 if 0x20 & $data[21];
    #    }

    if ( $main::config_parms{weather_uom_wind} eq 'mph' ) {
        grep { $$wptr{$_} = &::convert_mps2mph( $$wptr{$_} ) unless $skip{$_}; }
          qw(
          WindAvgSpeed
          WindGustSpeed
        );
    }
    if ( $main::config_parms{weather_uom_wind} eq 'kph' ) {
        grep { $$wptr{$_} = &::convert_mps2kph( $$wptr{$_} ) unless $skip{$_}; }
          qw(
          WindAvgSpeed
          WindGustSpeed
        );
    }
    print
      "wind = $$wptr{WindGustSpeed}, $$wptr{WindAvgSpeed}, $$wptr{WindGustDir}, $$wptr{WindAvgDir}\n"
      if $debug;

    #   print "wind=@data\n";
    #   $wx_counts{wind}++;
}

#CF. 1	DD	all	Wind	Gust Speed: 'bc' of 0<ab.c<56 m/s @ 0.2
#CF. 2	-D	all	Wind	Gust Speed: 'a' of <ab.c> m/s
#CF. 2	Dx	all	Wind	Gust Dir:   'c' of 0<abc<359 degrees @ 1
#CF. 3	DD	all	Wind	Gust Dir:   'ab' of <abc>
#CF. 4	DD	all	Wind	Avg Speed:  'bc' of 0<ab.c<56 m/s @ 0.1
#CF. 5	-D	all	Wind	Avg Speed:  'a' of <ab.c> m/s
#CF. 5	Dx	all	Wind	Avg Dir:    'c' of <abc>
#CF. 6	DD	all	Wind	Avg Dir:    'ab' of <abc>
#CF.16	DD	all	Chill	Temp: -85<ab<60 degrees C @ 1
#CF.21	Bx	1	Chill	Temp: Sign 0=+, 1=-

sub wx_time {
}

#
# $Log: Weather_wx200.pm,v $
# Revision 1.11  2003/07/06 17:55:11  winter
#  - 2.82 release
#
#
# Revision 1.11 2003/04/27 17:53:00 Richard Phillips
# - added in support for celsius readings for us foreigners ;-)
#
# Revision 1.10  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.9  2002/10/13 02:07:59  winter
#  - 2.72 release
#
# Revision 1.8  2002/08/22 04:33:20  winter
# - 2.70 release
#
# Revision 1.7  2002/03/31 18:50:40  winter
# - 2.66 release
#
# Revision 1.6  2001/11/18 22:51:43  winter
# - 2.61 release
#
# Revision 1.5  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.4  2001/08/12 04:02:58  winter
# - 2.57 update
#
#
