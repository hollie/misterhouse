use strict;

package Weather_wmr968;

=begin comment

11/18/01
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



 To use it, add these mh.ini parms
  serial_wmr968_port      = COM7
  serial_wmr968_baudrate  = 9600
  serial_wmr968_handshake = dtr
  serial_wmr968_datatype  = raw
  serial_wmr968_module    = Weather_wmr968
  serial_wmr968_skip      =  # Use to ignore bad sensor data.  e.g. TempOutdoor,HumidOutdoor,WindChill
#  altitude = 1000 # In feet, used to find sea level barometric pressure 
#  in the RS weather station, it adjusts for sea level and gives a direct
#  reading so altitude is not needed


 A complete usage example is at:
   http://misterhouse.net/mh/code/bruce/weather_monitor.pl

 Lots of other good Wmr968 software links at:
   http://www.qsl.net/zl1vfo/wx200/wx200.htm

=cut

my ($wmr968_port, %skip);
sub startup {
    $wmr968_port = new  Serial_Item(undef, undef, 'serial_wmr968');
    &::MainLoop_pre_add_hook(\&Weather_wmr968::update_wmr968_weather, 1 );
    %skip = map {$_, 1} split(',', $main::config_parms{serial_wmr968_skip}) if $main::config_parms{serial_wmr968_skip};
}

sub update_wmr968_weather {
    return unless my $data = said $wmr968_port;
                                # Process data, and reset incomplete data not processed this pass
    my $debug = 1 if $main::Debug{weather};
    my $remainder = &read_wmr968($data, \%main::Weather, $debug);
    set_data $wmr968_port $remainder if $remainder;
}                             

# Category=Weather

                                # Parse wx200 datastream into array pointed at with $wptr
                                # Lots of good info on the Wmr968 from: http://www.peak.org/~stanley/wmr918/dataspec

                                # Set up array of data types, including group index,
                                # group name, length of data, and relevant subroutine 

# tv changed table to reflect wmr968 values
my %wx_datatype = (0x0 => ['wind',    11, \&wx_wind],
                   0x1 => ['rain',    16, \&wx_rain],
                   0x2 => ['temp',     9, \&wx_spare],
                   0x3 => ['temp',     9, \&wx_outside],
                   0x5 => ['inside',  13, \&wx_inside],
                   0x6 => ['inside',  14,  \&wx_inside],
                   0xe => ['seq',      5,  \&wx_seq],
                   0xf => ['date',     9,  \&wx_time]);

        
sub read_wmr968 {
    my ($data, $wptr, $debug) = @_;

    my @data = unpack('C*', $data);
    print "at data is @data\n" if $debug;

    while (@data) {
        my $group = $data[2];  # tv changed from 0 
        my $dtp = $wx_datatype{$group};

                                # Check for valid datatype
        unless ($dtp) {
            my $length = @data;
            printf("Bad weather data.  group=%x length=$length\n", $group);
            return; 
        }
                                # If we don't have enough data, return what is left for next pass
        if ($$dtp[1] > @data) {
            return pack('C*', @data);
        }

                                # Pull out the number of bytes needed for this data type
        my @data2 = splice(@data, 0, $$dtp[1]);

                                # Check the checksum
         my $checksum1 = pop @data2;

        
        my $checksum2 = 0;
        for (@data2) {
            $checksum2 += $_;
        }

        $checksum2 &= 0xff;     # Checksum is lower 8 bits of the sum
        if ($checksum1 != $checksum2) {
            print "Warning, bad wx200 type=$$dtp[0] checksum: cs1=$checksum1 cs2=$checksum2\n";
        print "data2 is @data2\ndata is @data\ngroup is $group\n\n";
            next;
        }
                                # Process the data
#       print "process data $$dtp[0], $$dtp[1]\n";
        &{$$dtp[2]}($wptr, $debug, @data2);
    }
}


sub wx_temp2 {
    my ($n1, $n2) = @_;
    my $temp   =  sprintf('%x%02x', 0x07 & $n2, $n1);
    substr($temp, 2, 0) = '.';
    $temp *= -1 if 0x80 & $n2;
    $temp = &main::convert_c2f($temp);
    return $temp;
}

sub wx_rain {
    my ($wptr, $debug, @data) = @_;
    $$wptr{BatRain} = &wx_p968 unless $skip {BatRain};
    $$wptr{RainRate} = sprintf('%x%02x', 0x0f & $data[5], $data[4]) unless $skip{RainRate};
    $$wptr{RainYest} = sprintf('%x%02x',        $data[9], $data[8]) unless $skip{RainYest};
    $$wptr{RainTotal}= sprintf('%x%02x',        $data[7], $data[6]) unless $skip{RainTotal};
    $$wptr{RainRate} = sprintf('%3.1f', $$wptr{RainRate} / 25.4)    unless $skip{RainRate};
    $$wptr{RainYest} = sprintf('%3.1f', $$wptr{RainYest} / 25.4)    unless $skip{RainYest};
    $$wptr{RainTotal}= sprintf('%3.1f', $$wptr{RainTotal}/ 25.4)    unless $skip{RainTotal};
    print "rain = $$wptr{RainRate}, $$wptr{RainYest}, $$wptr{RainTotal}\n"  if $debug;

    $$wptr{SummaryRain} = sprintf("Rain Recent/Total: %3.1f / %4.1f  Barom: %4d",
                                  $$wptr{RainYest}, $$wptr{RainTotal}, $$wptr{Barom});

# print "rain=@data\n";
#   $wx_counts{rain}++;
}

#Byte	Nibble	Bit	Meaning
#01. 0	01		Rain guage packet
#01. 1	Bx		Battery status. Higher value == lower battery volt
#01. 1   xB		Unknown
#01. 2	DD		Rain rate, bc of 0<abc<999 mm/hr
#01. 3	xD		Rain rate, a  of 0<abc<999 mm/hr
#01. 3	Dx		Bucket tips since ??
#01. 4	DD		Rain Total, cd of 0<abcd<9999 mm (?)
#01. 5	DD		Rain Total, ab of 0<abcd<9999 mm (?)
#01. 6	DD		Rain Yesterday, cd of 0<abdc<9999 mm (?)
#01. 7	DD		Rain Yesterday, ab of 0<abcd<9999 mm (?)


sub wx_wind {
    
    my ($wptr, $debug, @data) = @_;
    $$wptr{BatWind} = &wx_p968 unless $skip{BatWind};
                                # Convert from meters/sec to miles/hour  = 1609.3 / 3600
    unless ($skip{WindGustSpeed}) {
        $$wptr{WindGustSpeed} = sprintf('%x%x', $data[6], 0xf0 & $data[5]);
        substr($$wptr{WindGustSpeed}, -2, 0) = '.'; # comp for being in hi nibble
        $$wptr{WindGustSpeed} = sprintf('%.1f', $$wptr{WindGustSpeed} * 2.237);
        $$wptr{WindGustDir}   = sprintf('%1x%02x', 0x07 & $data[5], $data[4] );
    }
    unless ($skip{WindAvgSpeed}) {
        $$wptr{WindAvgSpeed}  = sprintf('%x%02x', 0x0f & $data[8], $data[7]);
        substr($$wptr{WindAvgSpeed}, -1, 0)  = '.';
        $$wptr{WindAvgSpeed}  = sprintf('%3d', $$wptr{WindAvgSpeed}  * 2.237);
        $$wptr{WindAvgDir}    = sprintf('%1x%02x', 0x07 & $data[5], $data[4] );
    }

    unless ($skip{WindChill}) {
        $$wptr{WindChill} = sprintf('%x', $data[9]);
        $$wptr{WindChill} *= -1 if 0x80 & $data[8];
        $$wptr{WindChill} = &main::convert_c2f($$wptr{WindChill});
    }

    $$wptr{SummaryWind} = sprintf("Wind avg/gust:%3d /%3d  from the %s",
                                  $$wptr{WindAvgSpeed}, $$wptr{WindGustSpeed}, &main::convert_direction($$wptr{WindAvgDir}));

    print "wind = $$wptr{WindGustSpeed}, $$wptr{WindAvgSpeed}, $$wptr{WindGustDir}, $$wptr{WindAvgDir} chill=$$wptr{WindChill}\n" 
        if $debug;
# print "wind=@data\n";
# $wx_counts{wind}++;
}
#Byte	Nibble	Bit	Meaning
#00. 0	00		Anemometer data packet
#00. 1	Bx		Battery status. Higher value == lower battery volt
#00. 1   xB		Unknown
#00. 2	DD		Gust direction, bc of 0<abc<359 degrees
#00. 3	xD		Gust direction, a  of 0<abc<359 degrees
#00. 3	Dx		Gust speed, c  of 0<ab.c<56 m/s
#00. 4	DD		Gust speed, ab of 0<ab.c<56 m/s
#00. 5	DD		Average speed, bc  of 0<ab.c<56 m/s
#00. 6	xD		Average speed, a of 0<ab.c<56 m/s
#00. 6	Bx	3	Sign of wind chill, 1 = negative
#00. 7	DD		Wind chill

sub wx_time {
#print "time sub here\n";
my ($wptr, $debug, @data) = @_;
$$wptr{BatMain} = "Please check" if 0x80 & @data[3];
printf("weather station thinks it's %x00 hours - %x/%x/200%x\n",@data[4],@data[6], @data[5], @data[7]) if $debug;  
}
# This hits once an hour. Made a routine for it if we need it for more wonderful things in
# future.
#Byte	Nibble	Bit	Meaning
#0e. 0	0e		Sequence number packet
#0e. 1	Bx		Status, high bit, battery for main unit
#0e. 1	DD		After removing high bit, minute chime



sub wx_inside {
my $xb = "";
my ($wptr, $debug, @data) = @_;
print "inside sub\n" if $debug;
$$wptr{BatIndoor} = &wx_p968 unless $skip{BatIndoor};
$$wptr{TempIndoor} = &wx_t968 unless $skip{TempIndoor};
$$wptr{HumidIndoor} = &wx_h968 unless $skip{HumidIndoor};
$$wptr{DewIndoor} = &wx_d968 unless $skip{DewIndoor};
$$wptr{WxTendency} = &wx_f968 unless $skip{WxTendency};
$xb = &wx_b968 unless $skip{WxBarom};
$$wptr{Barom} = sprintf('%.2f',($xb+600) * .0295301) unless $skip{Barom};
$xb = $xb + sprintf('%x%x',@data[12],@data[11]);
$$wptr{BaromSea} = sprintf('%.2f',($xb * .0295301)) unless $skip{BaromSea};
print "B=$$wptr{BatIndoor} T=$$wptr{TempIndoor} H=$$wptr{HumidIndoor} D=$$wptr{DewIndoor} F=$$wptr{WxTendency} Bar=$$wptr{Barom} BarSea=$$wptr{BaromSea}\n" if $debug;
}
# Above is the inside information being parsed.
# As you can tell, the format of this and the following routines are to just call 
# the subroutines for each item. Each data stream has the same items in the same
# relative locations for indoor, outdoor, spare etc so we economize on the actual
# code written (yep, I'm lazy).
# One of the nice things is that each unit reports the status of their batteries!
#Byte	Nibble	Bit	Meaning
#05. 0	05		Inside sensor data
#05. 1	Bx		Battery status. Higher value == lower battery volt
#05. 1   xB		Unknown
#05. 2	DD		Inside temp, bc of -?<ab.c<? Celsius
#05. 3	xD		Inside temp, a  of -?<ab.c<? Celsius
#05. 3	Bx	3	Sign of temp, 1 = negative
#05. 4	DD		Relative humidity, ab of ?<ab<? percent
#05. 5	DD		Dew point, ab of 0<ab<? Celsius
#05. 6	HH		Baro pressure, convert to decimal and add 795. mb.
#05. 7	Bx		Unknown
#05. 7	xB		Encoded 'tendency' 0x0c=clear 0x06=partly cloudy
#			0x02=cloudy 0x03=rain
#05. 8	DD		Sea level reference, cd of <abc.d>. 
#05. 9	DD		Sea level reference, ab of <abc.d>. Add this to raw
#			bp from byte 6 to get sea level pressure.


sub wx_outside {
my ($wptr, $debug, @data) = @_;
print "outside sub\n" if $debug;
$$wptr{BatOutdoor} = &wx_p968 unless $skip{BatOutdoor};
$$wptr{TempOutdoor} = &wx_t968 unless $skip{TempOutdoor};
$$wptr{HumidOutdoor} = &wx_h968 unless $skip{HumidOutdoor};
$$wptr{DewOutdoor} = &wx_d968 unless $skip{DewOutdoor};
print "B=$$wptr{BatOutdoor} T=$$wptr{TempOutdoor} H=$$wptr{HumidOutdoor} D=$$wptr{DewOutdoor}\n" if $debug;
}
# Outside items being processed above.
#Byte	Nibble	Bit	Meaning
#03. 0	03		Outside temp/humidity data
#03. 1	Bx		Battery status. Higher value == lower battery volt
#03. 1   xB		Unknown
#03. 2	DD		Outside temp, bc of -?<ab.c<? Celsius
#03. 3	xD		Outside temp, a  of -?<ab.c<? Celsius
#03. 3	Bx	3	Sign of outside temp, 1 = negative
#03. 4	DD		Relative humidity, ab of ?<ab<? percent
#03. 5	DD		Dew point, ab of 0<ab<? Celsius




sub wx_spare {
my ($wptr, $debug, @data, $copy) = @_;

print "spare sub\n" if $debug;
$copy = &wx_u968 unless $skip{copy};
$$wptr{"BatSpare$copy"} = &wx_p968 unless $skip{"BatSpare$copy"};
$$wptr{"TempSpare$copy"} = &wx_t968 unless $skip{"TempSpare$copy"};
$$wptr{"HumidSpare$copy"} = &wx_h968 unless $skip{"HumidSpare$copy"};
$$wptr{"DewSpare$copy"} = &wx_d968 unless $skip{"DewSpare$copy"};

print "B=".$$wptr{"BatSpare$copy"}." T=".$$wptr{"TempSpare$copy"}." H=".$$wptr{"HumidSpare$copy"}." D=".$$wptr{"DewSpare$copy"}."    copy=$copy\n" if $debug;

}

# This unit can handle up to 3 extra sensors. I have two now, so that is how
# many I installed support for. 3 should work as expected but I have not
# tested this.
#02. 0	02		Outside temp/humidity data
#02. 1	Bx		Battery status. Higher value == lower battery volt
#02. 1   xB		Unknown
#02. 1	xB		Sensor number bit encoded, 4=3 2=2 1=1
#02. 2	DD		Outside temp, bc of -?<ab.c<? Celsius
#02. 3	xD		Outside temp, a  of -?<ab.c<? Celsius
#02. 3	Bx	3	Sign of outside temp, 1 = negative
#02. 4	DD		Relative humidity, ab of ?<ab<? percent
#02. 5	DD		Dew point, ab of 0<ab<? Celsius




sub wx_seq {
my ($wptr, $debug, @data) = @_;
print "main sequence sub once a minute\n" if $debug;
$$wptr{BatMain} = "OK";
$$wptr{BatMain} = "Please Check" if 0x80 & @data[3];
print "B=$$wptr{BatMain}\n" if $debug;
}
# not really sure what a "sequence" is but here is where it is handled -
# once a minute. Important thing here is this reports on the main unit
# battery which is either shown as good or not.
#Byte	Nibble	Bit	Meaning
#0e. 0	0e		Sequence number packet
#0e. 1	Bx		Status, high bit, battery for main unit
#0e. 1	DD		After removing high bit, minute chime



# subroutines below are called by the above "main" routines

sub wx_b968{
my (@data) = @_;
my $b968 = $data[10];
my $b968h = 0x03 & $data[11];
$b968h = sprintf('%x%x',$b968h,$b968);
$b968h = hex($b968h);
$b968h = $b968h;
return $b968h;
}
# barometer processed above.


sub wx_d968 {
my (@data) = @_;
my $temp = 0x80 & $data[5];
my $d968 = sprintf('%x', $data[9]);
$d968 *= -1 if 0x80 & $temp; 
$d968 = &main::convert_c2f($d968);
#print "data8 is $data[9]\n";
return $d968;
}
# Dew point figured above

sub wx_f968 {
my (@data) = @_;
my $f968 = $data[11];
my %eval = (0xc0 => "Sunny",
            0x60 => "Partly Cloudy",
            0x30 => "Rain",
            0x20 => "Cloudy",
            );

$f968 &= 0xf0;
$f968 = $eval{( 0xf0 & $f968)};
return $f968;
}
# Forecast for within the next 12-24 hours - what the weather station thinks
# it will do
# Thanks to Alan Jackson for the above routine!


sub wx_h968 {
my (@data) = @_;
my $h968 = $data[8];
$h968 = 0x99 if $h968 > 0x99;
my $h968 = sprintf('%x', $h968);
return $h968;
}
# Humidity subroutine above

sub wx_p968 {
my (@data) = @_;
my $p968 = $data[5];
$p968 &= 0xf0;
$p968 = 100 - ($p968 * .416);  # a number out of the blue - assume 0xF0 as high
$p968 = sprintf('%d',$p968);
$p968 = join('',$p968,"%");
return $p968;
}
# Power (battery - b was already used for barometer) routine

sub wx_t968 {
my (@data) = @_;
my $t968 = &wx_temp2(@data[6..7]);
return $t968;
}
# Temperature subroutine above

sub wx_u968 {
my (@data) = @_;
my $u968 = $data[5];
$u968  &= 0x07;
my %eval = (0x1 => "Garage",
            0x2 => "2",
            0x4 => "3",
            );
$u968 = $eval{$u968};
return $u968;
}
#Above routine decodes which remote sensor you are using. In this case
#it will decode in the following fashion BatSpareGarage, BatSpare2, BatSpare3.
#You will need to edit the above table using the last of the variable
#that was changed in the weather_monitor.pl file.



# 2001/11/18 v1.0 of Weather_wmr968.pm based on Bruce's Weather_wx200.pm
#
# $Log$
# Revision 1.3  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.2  2002/08/22 04:33:20  winter
# - 2.70 release
#
# Revision 1.1  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.5  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.4  2001/08/12 04:02:58  winter
# - 2.57 update
#
#
