package Weather_daviswm2;

# $Date$
# $Revision$

use strict;
use Weather_Common;
eval 'use Digest::mhCRC qw(crc16);';
if ($@) {
	die("Weather_daviswm2:  Can't find the Digest::mhCRC package (mhCRC.pm).  Please ensure that it is installed.\n$@");
}

=begin comment
=============================================================================
Davis Weather Monitor II
6/17/2006
Scott Huskey modified Tom Vanderpool's wmr968 code to enable use of it
for the Davis Weather Monitor II weather stations.

Matt Williams reworked it to interface correctly with mh and to make it a module
Jack Edin was heavily involved in testing and was the impedus behind the creation of this module.

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
our $lastRainReading = undef;
our $lastRainReadingTime = undef;

sub startup{ 
	my ($instance)=@_;
	$DavisWMII_port = new Serial_Item(undef, undef, 'serial_daviswm2');
	&requestData;
	&::MainLoop_pre_add_hook(\&Weather_daviswm2::update,1);
	&::trigger_set('&new_minute','&Weather_daviswm2::requestData','NoExpire','daviswm2 data request')
		unless &::trigger_get('daviswm2 data request');
}

# called by trigger every minute
sub requestData {
	 &::print_log ("daviswm2: requesting new data from station") if $::Debug{weather};
	 $DavisWMII_port->set($loopCommand);
}

# called once per loop
sub update{
	return unless my $data = said $DavisWMII_port;
	
	my $remainder=&process($data, \%main::Weather);
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

sub process{
	my ($data, $wptr) = @_;
	my @data = unpack('C*',$data);
	my $gotheader = 0;

	if ($::Debug{Weather}) {
		my $debugInfo='daviswm2: Read from Davis WM II ';
		for (@data) {
		$debugInfo .= sprintf ("0x%x ",$_);
		}
	&::print_log($debugInfo);
	}

	my @bytes;
	
	my $foundHeader=0;
	
	my ($indoor_temp,     
		$outdoor_temp,    
		$wind_speed,      
		$wind_direction,  
		$barometer,       
		$indoor_humidity, 
		$outdoor_humidity,
		$total_rain,      
		$not_used,        
		$crc16,
		$rain_rate);
		
	# go through data until we have found a header  
	&::print_log ("daviswm2: looking for header") if $::Debug{Weather};
	my $headerByte;
	while (defined($headerByte=shift(@data))) {
		next if $headerByte != 1; # need a 1 at start of data
		&::print_log ("daviswm2: found header, checking length and crc16 of remaining data") if $::Debug{Weather};
		$data=pack('C*',@data);
		if (length($data) < 17) { # we need 17 bytes left to proceed
			&::print_log("daviswm2: not enough bytes left to process") if $::Debug{Weather};
			return $headerByte.$data; # need to return the header byte as well
		}
		($indoor_temp,     
		$outdoor_temp,    
		$wind_speed,      
		$wind_direction,  
		$barometer,       
		$indoor_humidity, 
		$outdoor_humidity,
		$total_rain,      
		$not_used,        
		$crc16)=unpack('vvCvvCCvvn', $data);
		if (Digest::mhCRC::crc16(substr($data,0,15)) != $crc16) {
			&::print_log ("daviswm2: wrong crc16, looking again for header") if $::Debug{Weather};
			next;
		}
		# remove the 17 bytes that we just processed, we'll use the remainder as our return value
		$data=substr($data,17); 
		last;
	}
	
	# return because we didn't find a header :-(
	if ($headerByte != 1) { 
		&::print_log ("daviswm2: ran out of bytes and didn't find a header") if $::Debug{Weather};
		# don't use $data as return value as it only has a valid
		# value if a good header/packet is found
		return '';
	}
	
	&::print_log ("daviswm2: found a header with the right checksum") if $::Debug{Weather};
	
	# correct reading from reported to actual (just moving the decimal point)
	$indoor_temp/=10.0;
	$outdoor_temp/=10.0;
	$barometer/=1000.0;
	$total_rain/=10.0;
	
	# calculate sea level pressure
	my $barometer_sea=convert_local_barom_to_sea_in($barometer);
	
	# these dewpoints will be in Celsius
	my $indoor_dewpoint=&::convert_humidity_to_dewpoint($indoor_humidity,&::convert_f2c($indoor_temp));
	my $outdoor_dewpoint=&::convert_humidity_to_dewpoint($outdoor_humidity,&::convert_f2c($outdoor_temp));
	
	$rain_rate=undef;
	if (defined ($lastRainReadingTime)) {
		$rain_rate=($total_rain-$lastRainReading); # delta in inches
		my $time_delta=(time - $lastRainReadingTime);
		if ($time_delta != 0) {
			$rain_rate/=$time_delta; # rate in inches per second
			$rain_rate *= 3600; # rate in inches per hour
			if ($rain_rate < 0) { # if total rain was reset to zero, this could happen
				$rain_rate=0; 
			}
		}
	}
	$lastRainReadingTime=time;
	$lastRainReading=$total_rain;
	
	if ($main::config_parms{weather_uom_temp} eq 'C') {
		grep {$_=&::convert_f2c($_);} (
			$indoor_temp,
			$outdoor_temp
		);
	# remember, dewpoints are in Celsius by default
	} elsif ($main::config_parms{weather_uom_temp} eq 'F') {
		grep {$_=&::convert_c2f($_);} (
			$indoor_dewpoint,
			$outdoor_dewpoint
		);
	}
	if ($main::config_parms{weather_uom_baro} eq 'mb') {
		grep {$_=&::convert_in2mb($_);} (
			$barometer,
			$barometer_sea
		);
	}
	if ($main::config_parms{weather_uom_rain} eq 'mm') {
		grep {$_=&::convert_in2mm($_);} (
			$total_rain
		);
	}
	if ($main::config_parms{weather_uom_rain} eq 'mm/hr') {
		grep {$_=&::convert_in2mm($_);} (
			$rain_rate
		);
		$rain_rate=sprintf('%.0f',$rain_rate); # round to nearest mm/hr
	} else {
		$rain_rate=sprintf('%.2f',$rain_rate); # round to nearest 0.01 in/hr
	}
	if ($main::config_parms{weather_uom_wind} eq 'kph') {
		grep {$_=&::convert_mile2km($_);} (
			$wind_speed
		);
	}
	if ($main::config_parms{weather_uom_wind} eq 'm/s') {
		grep {$_=&::convert_mph2mps($_);} (
			$wind_speed
		);
	}
	
	$$wptr{TempIndoor}=$indoor_temp;
	$$wptr{TempOutdoor}=$outdoor_temp;
	$$wptr{DewIndoor}=$indoor_dewpoint;
	$$wptr{DewOutdoor}=$outdoor_dewpoint; 
	$$wptr{WindAvgSpeed}=$wind_speed;
	$$wptr{WindGustSpeed}=$wind_speed;
	$$wptr{WindAvgDir}=$wind_direction;
	$$wptr{WindGustDir}=$wind_direction;
	$$wptr{Barom}=$barometer;
	$$wptr{BaromSea}=$barometer_sea;
	$$wptr{HumidIndoor}=$indoor_humidity;
	$$wptr{HumidOutdoor}=$outdoor_humidity;
	$$wptr{RainTotal}=$total_rain;
	$$wptr{RainRate}=$rain_rate;
	
	if ($::Debug{Weather}) {
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
			&::print_log ("daviswm2: $key ".$$wptr{$key});
		}
	}

	&::weather_updated;
	return $data;
} 

# all modules must return 1.  don't remove the following line
1;
