#Category=Weather

#@ This module gets the pollen forecast from wunderground.com and puts the pollen
#@ type and pollen count into the %Weather hash.
#@
#@ Uses mh.ini parameter zip_code

# Get pollen count forecast from wunderground.com and put it and the pollen
# type into the %Weather hash.
# Technically there is a 4 day forecast, but I have seen it vary so widely
# from day 2 and what day 1 will say tomorrow that I don't count on it for
# more than the current day.
#
#uses mh.ini parameter zip_code=
#
#info from:
#http://www.wunderground.com/DisplayPollen.asp?Zipcode=64119
#

# weather_pollen.pl
# Original Author:  Kent Noonan
# Revision:  1.3
# Date:  07/12/2014

=begin comment

 1.0 Initial Release
     Kent Noonan - ca. 12/16/2001
 1.1 Revisions
     David J. Mark - 06/12/2006
 1.2 Updated to use new Trigger design.
     Bruce Winter - 06/25/2006
 1.3 Updated to use Wunderground instead of Pollen.com because
     Pollen.com has added annoying countermeasures to prevent
     screenscraping that would take much more code to parse.  Plus,
     their encryption scheme could change at anytime, breaking the
     script again.  Wunderground is perfect in this case because the data is
     much easier to scrape and they actually receive their pollen data from
     Pollen.com anyway.  I've also done some general cleanup & added
     a log message to warn if parsing fails.
     Jared J. Fernandez - 07/12/2014

=cut

$v_get_pollen_forecast = new Voice_Cmd('[Get,Check] pollen forecast');
$v_get_pollen_forecast->set_info("Downloads and parses the pollen forecast page from wunderground.com.  The 'check' option reads out the result after parsing is complete.");

$v_read_pollen_forecast = new Voice_Cmd('Read pollen forecast');
$v_read_pollen_forecast->set_info("Reads out the previously fetched pollen forecast");

$p_pollen_forecast = new Process_Item("get_url http://www.wunderground.com/DisplayPollen.asp?Zipcode=$config_parms{zip_code} $config_parms{data_dir}/web/pollen_forecast.html");

&parse_pollen_forecast if $Reload;

sub parse_pollen_forecast {

	my ($found1,$found2);
	open(FILE,"$config_parms{data_dir}/web/pollen_forecast.html");
	while (<FILE>) {
		if ((/Pollen Type:<\/strong>\s(\w+)\.<\/h3>/) && (!defined($found1))) {
			$found1 = 1;
			$main::Weather{TodayPollenType}=$1;
		} elsif ((/<p>(\d+\.\d+)<\/p>/) && (!defined($found2))) {
			$found2 = 1;
			$main::Weather{TodayPollenCount}=$1;
		}
		last if ($found1 && $found2);
	}
	close(FILE);
	unless ($found1 && $found2) {
		warn "Error parsing pollen info.";
	}

}

if ($state = said $v_get_pollen_forecast) {
	$v_get_pollen_forecast->respond("app=pollen Retrieving pollen forecast...");
	start $p_pollen_forecast;
}

if (done_now $p_pollen_forecast){
	&parse_pollen_forecast();
	if ($v_get_pollen_forecast->{state} eq 'Check') {
		$v_get_pollen_forecast->respond("app=pollen Today's pollen count is $main::Weather{TodayPollenCount}. The predominant pollens are from " . lc($main::Weather{TodayPollenType} . "."));
	}
	else {
		$v_get_pollen_forecast->respond("app=pollen Pollen forecast retrieved");
	}


}

if (said $v_read_pollen_forecast) {
	if ($Weather{TodayPollenCount}) {
		$v_read_pollen_forecast->respond("app=pollen Today's pollen count is $main::Weather{TodayPollenCount}. The predominant pollens are from " . lc($main::Weather{TodayPollenType}) . ".");
	}
	else {
		$v_read_pollen_forecast->respond("app=pollen I do not know the pollen count at the moment.");
	}
}

# create trigger to download pollen forecast

if ($Reload) {
    if ($Run_Members{'internet_dialup'}) {
        &trigger_set("state_now \$net_connect eq 'connected'", "run_voice_cmd 'Get pollen forecast'", 'NoExpire', 'get pollen forecast')
          unless &trigger_get('get pollen forecast');
    }
    else {
        &trigger_set("time_cron '0 5 * * *' and net_connect_check", "run_voice_cmd 'Get Pollen forecast'", 'NoExpire', 'get pollen forecast')
          unless &trigger_get('get pollen forecast');
    }
}
