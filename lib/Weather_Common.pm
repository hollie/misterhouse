# $Date$
# $Revision$

# Weather_Common package
#
# This packages should be included by all weather modules and libraries.
# It provides a standard method to update common %Weather elements and
# to add hooks whenever weather changes are detected
#
# Clients should call weather_updated whenever they have finished updating %Weather

package Weather_Common;

use strict;
use warnings;

BEGIN {
	use Exporter ();

	our @EXPORT = qw(
		weather_updated
		weather_add_hook
		convert_local_barom_to_sea_mb
		convert_local_barom_to_sea_in
		convert_sea_barom_to_local_mb
		convert_sea_barom_to_local_in
		populate_internet_weather
		);
}

our @weather_hooks;

# this should be called whenever a client has FINISHED updating %main::Weather

sub weather_updated {
	# get a pointer to the main $w hash to make things easier to read (and type!)
	my $w=\%main::Weather;

	my $windSpeed=$$w{WindAvgSpeed};

	# need wind speed in km/h for formulas to work
	if (defined $windSpeed) {	
		if ($main::config_parms{weather_uom_wind} eq 'mph') {
			$windSpeed=convert_mile2km($windSpeed);
		}
		if ($main::config_parms{weather_uom_wind} eq 'mps') {
			$windSpeed=convert_mps2kph($windSpeed);
		}
	} else {
		$windSpeed='unknown';
	}

	# assume for now that windchill and humidex are negligible
	my $apparentTemp='unknown';
	my $temperatureText='unknown';
	if (defined $$w{TempOutdoor}) {
		$apparentTemp=$$w{TempOutdoor};
		$temperatureText=sprintf('%.1f&deg;%s',$$w{TempOutdoor}, $main::config_parms{weather_uom_temp});

	}
	$$w{WindChill}=$apparentTemp;
	$$w{Humidex}=$apparentTemp;
	$$w{ApparentTemp}=$apparentTemp;

	my $temp=$apparentTemp;
	my $dewpoint=$$w{DewOutdoor};
	if (!defined $dewpoint) {
		$dewpoint = $$w{DewIndoor};
		if (!defined $dewpoint) {
			$dewpoint='unknown';
		}
	}

	# need temp and dewpoint in Celsius for formulas to work
	if ($main::config_parms{weather_uom_temp} eq 'F') {
		grep {$_=convert_f2c($_) if defined $_} ($temp,$dewpoint);
	}

	my $pressureText='unknown';
	if (defined $$w{BaromSea}) {
		$pressureText=sprintf("%s %s",$$w{BaromSea},$main::config_parms{weather_uom_baro});
	}

	if ($windSpeed ne 'unknown' and $temp ne 'unknown') {
	# windchill formula is only valid for the following conditions
		if ($windSpeed >= 5 and $windSpeed <= 100 and $temp >= -50 and $temp <= 5) {
			my $windchill=13.12+0.6215*$temp-11.37*($windSpeed**0.16)+0.3965*$temp*($windSpeed**0.16);
			if ($main::config_parms{config_uom_temp} eq 'F') {
				$windchill=convert_c2f($windchill);
			}
			$windchill=sprintf('%.1f',$windchill);
			$$w{WindChill}=$windchill;
			$apparentTemp=$windchill;
		}
	}

	if ($temp ne 'unknown' and $dewpoint ne 'unknown') {
		my $vapourPressureSaturation=6.112*10.0**(7.5*$temp/(237.7+$temp));
		my $vapourPressure=6.112*10.0**(7.5*$dewpoint/(237.7+$dewpoint));
		# only calculate humidity if is isn't directly measured by something
		if (!$$w{HumidOutdoorMeasured}) {
			$$w{HumidOutdoor}=sprintf('%.0f',100*$vapourPressure/$vapourPressureSaturation);
		}
		my $humidex=$temp+(0.5555*($vapourPressure-10));

		# only report humidex if temperature is at least 20 degrees and
		# humidex is at least 25 degrees (standard rules)
		if (($temp >= 20) && ($humidex >= 25)) {
			if ($main::config_parms{weather_uom_temp} eq 'F') {
				$humidex=convert_c2f($humidex);
			}
			$humidex=sprintf('%.1f',$humidex);
			$$w{Humidex}=$humidex;
			$apparentTemp=$humidex;
		}
	}

	my $humidityText='unknown';
	if (defined $$w{HumidOutdoor}) {
		$humidityText=sprintf('%.0f%%',$$w{HumidOutdoor});
	}

	if ($apparentTemp ne 'unknown') {
		$$w{OutdoorApparent}=sprintf('%.1f',$apparentTemp);
	}

	my $apparentTempText='';

	if ($apparentTemp ne 'unknown') {
		$$w{TempOutdoorApparent}=$apparentTemp;
		if ($apparentTemp != $$w{TempOutdoor}) {
			$apparentTempText=" ($apparentTemp)";
		}
	} 

	my $windDirName='unknown';

	if (defined $$w{WindGustDir} and !defined $$w{WindAvgDir}) {
		$$w{WindAvgDir} = $$w{WindGustDir};
	}
	if (defined $$w{WindAvgDir}) {
		$windDirName=qw{ N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW }[(($$w{WindAvgDir}+11.25)/22.5)%16];
	}

	my $shortWindText='unknown';
	my $longWindText='unknown';
	if (defined $$w{WindAvgSpeed}) {
		if (!defined($$w{WindGustSpeed}) and $$w{WindAvgSpeed} == 0) {
			$shortWindText='no wind';
			$longWindText='no wind';
		} else {
			$shortWindText=sprintf('%s %.0f %s',$windDirName,$$w{WindAvgSpeed},$main::config_parms{weather_uom_wind});

			$longWindText=sprintf('%s at %.0f %s',$windDirName,$$w{WindAvgSpeed},$main::config_parms{weather_uom_wind});
		}

		if (defined $$w{WindGustSpeed} and $$w{WindGustSpeed} > $$w{WindAvgSpeed}) {
			if ($$w{WindGustSpeed} == 0) {
				$shortWindText='no wind';
				$longWindText='no wind';
			} else {
				$shortWindText=sprintf('%s %.0f (%.0f) %s',$windDirName,$$w{WindAvgSpeed}, $$w{WindGustSpeed},$main::config_parms{weather_uom_wind});
				$longWindText.=sprintf(' gusting to %.0f %s',$$w{WindGustSpeed},$main::config_parms{weather_uom_wind});
			}
		}
	}

	my $clouds='unknown';
	$clouds=$$w{Clouds} if defined $$w{Clouds};
	my $conditions='unknown';
	$conditions=$$w{Conditions} if defined $$w{Conditions};

	$$w{Wind}=$shortWindText;

	$$w{Summary_Short}=sprintf('%s%s %s', $temperatureText, $apparentTempText, $humidityText);
	$$w{Summary}=$$w{Summary_Short}." $pressureText $clouds $conditions";
	$$w{SummaryLong}="Temperature: $temperatureText";
	if ($apparentTempText ne '') {
		$$w{SummaryLong}.='  Apparent Temperature: '.$$w{TempOutdoorApparent}.'&deg'.$main::config_parms{weather_uom_temp};
	}
	$$w{SummaryLong}.="  Humidity: $humidityText";
	$$w{SummaryLong}.="  Wind: $longWindText";
	$$w{SummaryLong}.="  Sky: $clouds";
	$$w{SummaryLong}.="  Conditions: $conditions";

	foreach my $subref (@weather_hooks) {
		&$subref();
	}
}

sub weather_add_hook {
	my ($subref)=@_;
	push @weather_hooks, $subref;
}

# for the following conversion routines, this rule was used:
# pressure changes by 1 mb for each 8 meters of altitude gain
# and by 1 inHg for each 1000 ft
#
# for mb: altitude is in feet, so 1 mb for each 8 meters is
# 1 mb for each 8*3.28 feet = 24.24 feet

sub convert_local_barom_to_sea_mb {
	return sprintf('%.1f',$_[0] + $main::config_parms{altitude}/24.24);
}

sub convert_local_barom_to_sea_in {
	return sprintf('%.2f',$_[0] + $main::config_parms{altitude}/1000);
}

sub convert_sea_barom_to_local_mb {
	return sprintf('%.1f',$_[0] - $main::config_parms{altitude}/24.24);
}

sub convert_sea_barom_to_local_in {
	return sprintf('%.2f',$_[0] - $main::config_parms{altitude}/1000);
}

# This should be called by external sources of weather like those
# found on the internet.
#
# Only a subset of the passed keys will be copied to the %Weather hash

sub populate_internet_weather {
	my ($weatherHashRef, $weatherKeys)=@_;

	my @keys;

	if ($weatherKeys ne '') {
		@keys=split(/\s+/,$weatherKeys);	
	} else {
		if ($main::config_parms{weather_internet_elements} eq 'all' or $main::config_parms{weather_internet_elements} eq '') {
			@keys=qw (
				TempOutdoor
				DewOutdoor
				WindAvgDir
				WindAvgSpeed
				WindGustDir
				WindGustSpeed
				Clouds
				Conditions
				Barom
				BaromSea
			);
		} else {
			@keys=split(/\s+/,$main::config_parms{weather_internet_elements});
		}
	}
	foreach my $key (@keys) {
		if ($$weatherHashRef{$key} ne '') {
			$main::Weather{$key}=$$weatherHashRef{$key};
		}
	}
}


1;
