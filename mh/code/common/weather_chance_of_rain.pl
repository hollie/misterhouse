# Category = Weather

#@ David Norwood's script that parses rain info from the weather forecasts
#@ downloaded by get_weather (US only).  If rain is forecasted, it will be
#@ announced.  There is also some example code for skipping sprinkler cycles
#@ based on the forecast.

=begin comment

weather_chance_of_rain.pl
1.0	Created by David Norwood (dnorwood2@yahoo.com) 12/7/2001

This script reads the weather forecasts downloaded by mh/bin/get_weather and 
extracts the percent chance of rain for the various forecast periods in the 
next week.  If rain is forecast, it will be announced. 

The voice command for get_weather is defined in internet_data.pl and scheduled
to run in internet_weather.pl.  This script is triggered when a new forecast is
received, so modify internet_login.pl to adjust when the rain forecast is
spoken.

The get_weather script is for the US only.

=cut


$weather_forecast = new File_Item "$config_parms{data_dir}/web/weather_forecast.txt";
set_watch $weather_forecast if $Reload;

$v_chance_of_rain = new Voice_Cmd 'What is the forecasted chance of rain';
$v_chance_of_rain-> set_info('Reports on chance of rain and snow from the mh/bin/get_weather results');

if (said $v_chance_of_rain or ($New_Minute and changed $weather_forecast)) {
	set_watch $weather_forecast;

    my ($size, $text, $line, $day, $current_day, $forecast, $tomorrow, $chance, %forecasts);
    my @days = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",	"Friday", "Saturday");

	($size) = (stat($weather_forecast->name))[7];
	if ($size < 100) {
		speak "Incomplete weather forecast received" if said $v_chance_of_rain;
		return;
	}
	foreach $day (split $Weather{"Forecast Days"}, /\|/) {
		undef $Weather{"Chance of Rain $day"};
	}
	$Weather{"Forecast Days"} = '';
	foreach $line (read_all $weather_forecast) {
		next if $line =~ /^As of/;
		if (($forecast) = $line =~ /^\s*( \S.+)/) {
			$forecasts{$current_day} .= $forecast;
		}
		if (($day, $forecast) = $line =~ /^([\w ]+): (.+)/) {
			$forecasts{$day} = $forecast;
			$Weather{"Forecast Days"} .= $day . '|';
			$current_day = $day;
		}
		#print "$line\n";
		#print "$current_day : $forecasts{$current_day}\n";
	}
	$Weather{"Forecast Days"} =~ s/\|$//;
	$text = '';
	foreach $day (split /\|/, $Weather{"Forecast Days"}) {
		$chance = 0;
		$chance = 20 if $forecasts{$day} =~ /(slight|a) chance (of|for) *\S* *(rain|showers|snow)/i;
		$chance = 60 if $forecasts{$day} =~ /(rain|showers|snow) (becoming )?likely/i;
		$chance = $1 if $forecasts{$day} =~ /(\d+) percent chance (of|for) *\S* *(rain|showers|snow)/i;
		$chance = $3 if $forecasts{$day} =~ /chance (of|for) *\S* *(rain|showers|snow) (\d+) percent/i;
		$chance = $3 if $forecasts{$day} =~ /chance (of|for) *\S* *(rain|showers|snow) increasing to (\d+) percent/i;
		print "$day : $chance\n";
		$chance = 80 if $chance > 100;
        my $precip = ($forecasts{$day} =~ / snow/) ? 'snow' : 'rain';
		$Weather{"Chance of $precip $day"} = $chance;
		$text .= " a $chance percent chance of $precip $day," if $chance;
	}
	unless ($text) { 
		speak "There is no rain in the forecast." if said $v_chance_of_rain;
		return;
	}
	$tomorrow = $days[($Wday + 1) % 7];
	$text =~ s/$tomorrow/tomorrow/g;
	$text = 'There is' . $text;
	$text =~ s/,$/./;
	$text =~ s/a 8/an 8/g;
	$text =~ s/,([^,]+)$/ and$1/;
	speak $text if said $v_chance_of_rain or $Hour > 7;
}


=begin comment

The following code is an example of using the rain forecast to skip sprinkler cycles before and after 
the rain.

if (time_cron "40 4,16 * * *") {
	foreach $day (split /\|/, $Weather{"Forecast Days"}) {
		$chance = $Weather{"Chance of Rain $day"};
		if ($chance > 50) {
			$Save{sprinkler_skip} = 3;
			last;
		}
	}
	return unless $Save{sprinkler_skip};
	if ($Save{sprinkler_skip} == 3) {
		speak "Rain forecasted, skipping sprinklers.";
	}
	else {
		speak "Skipping sprinklers due to recent rain.";
	}
	system 'nxacmd -v 2 -n 1';
}

$Save{sprinkler_skip}-- if $Save{sprinkler_skip} and $New_Day;

=cut
