# Category=Informational
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	mos_forecast.pl

Description:
	Retrieves the MOS formated forecast (computer parsable)
	This is a conversion of some of my proprietary code into MH for HVAC and 
	other purposes within MH (display abbreviated weather to RCS TR40 thermostat)

	
Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	Example initialization:
	- For now, change the $f_mos_forecast_station parm to the station id you would like weather on.
	If anyone would like to make this a config option (I am too lazy) have at it ;)

	- Weather sits in the @mos_forecast var.

	To get weather:
	Voice Command: "get mos forecast"

	To display weather:
	mos_forecast_brief_text();


Bugs:
	- Some strings are not "trimmed" of whitespace well.
	- A lot of data is not being processed.  Only took what I am interested in.. Expand at your pleasure.

Special Thanks to: 
	Bruce Winter - MH
		

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

my $f_mos_forecast = "$config_parms{data_dir}/web/mos_forecast.html";
my $f_mos_forecast_station = "KCLT";

$v_mos_forecast = new Voice_Cmd 'get mos forecast';

$p_mos_forecast = new Process_Item("get_url http://www.nws.noaa.gov/cgi-bin/mos/getmav.pl?sta=$f_mos_forecast_station $f_mos_forecast");

my @mos_forecast;

if (said $v_mos_forecast) {
	start $p_mos_forecast;
	print_log "Retrieving MOS forecast";
}


if (done_now $p_mos_forecast) {
	my $l_html = file_read $f_mos_forecast;
	my $l_file;
	my $l_lineno;

	my @l_time;
	my @l_utc_time;
	my @l_min_max_temp;
	my @l_temp;
	my @l_dew_point;
	my @l_cloud_cover;
	my @l_wind_dir;
	my @l_wind_speed;
	my @l_precip_6hr;
	my @l_precip_12hr;
	my @l_quan_6hr;
	my @l_quan_12hr;
	my @l_thunder_6hr;
	my @l_thunder_12hr;
	my @l_freeze;
	my @l_snow;
	my @l_precip_type;
	my @l_ceiling_height;
	my @l_visibility;
	my @l_visibility_type;

	$l_lineno=0;
	my $l_lineOffset=0;

	open(l_file,$f_mos_forecast);
	while(<l_file>)
	{
		$l_lineno++;
		if ($l_lineno<2+$l_lineOffset) {
			next;
		}
		if ($l_lineno == 8+$l_lineOffset) {
			@l_utc_time = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 9+$l_lineOffset) {
			@l_min_max_temp = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 10+$l_lineOffset) {
			@l_temp = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 11) {
			@l_dew_point = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 12) {
			@l_cloud_cover = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 15) {
			@l_precip_6hr = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 16) {
			@l_precip_12hr = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 17) {
			@l_quan_6hr = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 18) {
			@l_quan_12hr = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 19) {
			@l_thunder_6hr = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 20) {
			@l_thunder_12hr = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 23) {
			@l_precip_type = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		if ($l_lineno == 24) {
			@l_thunder_12hr = $_ =~ /......(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..).(..)/;
		}
		next;
	}
	close(l_file);

	#Calculate local time
	@l_time = mos_adjust_time(@l_utc_time);


	#calculate the day vars
	my $l_dayOffset=0;
	my $l_prevHour='';

	### Daily information
	my @l_daily_max;
	my @l_daily_min;
	for (my $i=0;$i<@l_time;$i++) {
		#calc the day we are on
		if ($l_prevHour == 00 and $l_prevHour ne '') {
			$l_dayOffset++;
		}
		$l_prevHour = $l_utc_time[$i];
		if ($l_utc_time[$i]== 12) {
			@l_daily_max[$l_dayOffset]=$l_min_max_temp[$i];
		}			
		if ($l_utc_time[$i]== 00) {
			@l_daily_min[$l_dayOffset]=$l_min_max_temp[$i];
		}			
	}	


	# for now just get the morning / midday / night forecast
	my $l_startMorning=5;
	my $l_endMorning=$l_startMorning+3;
	my $l_startAfternoon=$l_startMorning+6;
	my $l_endAfternoon=$l_startAfternoon+3;
	my $l_startEvening=$l_startAfternoon+6;
	my $l_endEvening=$l_startEvening+3;

	my $l_index=0;



#	print_log "STUFF:" . $l_startMorning . ":" . $l_endMorning;
#	print_log "PARSE: @l_precip_6hr";

	##### Get Morning / Afternoon / Even data
	$l_dayOffset=0;
	$l_prevHour=0;
	for (my $i=0;$i<@l_time;$i++) {
		if ($l_prevHour > $l_time[$i] ) {
			$l_dayOffset++;
		}
		$l_prevHour = $l_time[$i];
		#### Morning
		if ($l_time[$i]>$l_startMorning and $l_time[$i]<=$l_endMorning) { #morning forecast
			my $values={};
			$$values{hour}=$l_time[$i];
			$$values{day}=$l_dayOffset;
			$$values{period_name}='Morn';
			$$values{temperature}=$l_temp[$i];
			$$values{precip}=$l_precip_6hr[$i];
			$$values{precip_type}=$l_precip_type[$i];
			$$values{min}=$l_daily_min[$l_dayOffset];
			$$values{max}=$l_daily_max[$l_dayOffset];
			@mos_forecast[$l_index]=$values;
#			print "Morning";
			$l_index++;	
		}
		#### Afternoon
		if ($l_time[$i]>$l_startAfternoon and $l_time[$i]<=$l_endAfternoon) {
			my $values={};
			$$values{hour}=$l_time[$i];
			$$values{day}=$l_dayOffset;
			$$values{period_name}='Noon';
			$$values{temperature}=$l_temp[$i];
			$$values{precip}=$l_precip_6hr[$i];
			$$values{precip_type}=$l_precip_type[$i];
			$$values{min}=$l_daily_min[$l_dayOffset];
			$$values{max}=$l_daily_max[$l_dayOffset];
			@mos_forecast[$l_index]=$values;
#			print "After:" . @l_temp[$i] . ":";
			$l_index++;	
		}
		#### Evening
		if ($l_time[$i]>$l_startEvening and $l_time[$i]<=$l_endEvening) {
			my $values={};
			$$values{hour}=$l_time[$i];
			$$values{day}=$l_dayOffset;
			$$values{period_name}='Eve';
			$$values{temperature}=$l_temp[$i];
			$$values{precip}=$l_precip_6hr[$i];
			$$values{precip_type}=$l_precip_type[$i];
			$$values{min}=$l_daily_min[$l_dayOffset];
			$$values{max}=$l_daily_max[$l_dayOffset];
			@mos_forecast[$l_index]=$values;
#			print "Eve";
			$l_index++;	
		}
		#Precipitation percentage (might not be available on the same hour as used for morning.. get the next closest)
		if (defined $mos_forecast[$l_index] && $l_precip_6hr[$i]>0) {
			@mos_forecast[$l_index]->{precip}=$l_precip_6hr[$i];
		}		
	}
#	print_log("Pizza:" . @mos_forecast[0]->{temperature});

}

sub mos_brief_text_forecast
{
	my $l_message="";
	my $l_dayOffset=-1;

	for (my $i=0; $i < @mos_forecast; $i++) {
		print_log "Here" . $i;
		#Get day
		if (@mos_forecast[$i]->{day} != $l_dayOffset) {
			$l_dayOffset=@mos_forecast[$i]->{day};
			if ($l_dayOffset==0) {
				$l_message.="Tdy:(";
			} else {
				$l_message.=". Day+" . $l_dayOffset . ":(";
			}
			$l_message.=@mos_forecast[$i]->{max} . "/" . @mos_forecast[$i]->{min};
			$l_message.=")F";
		}
		$l_message.=", " . @mos_forecast[$i]->{period_name} . ":";
		$l_message.= @mos_forecast[$i]->{temperature} . "F";
		$l_message.=" " . (@mos_forecast[$i]->{precip} * 10) . "%" . @mos_forecast[$i]->{precip_type};
	}
	return $l_message;
}

sub mos_adjust_time
{
	# convert from UTC to Local Time
	my (@p_time) = @_;
	my @l_time;

	for (my $i=0;$i<@p_time;$i++)
	{
		$l_time[$i]=$p_time[$i]+$config_parms{time_zone};
		if ($l_time[$i] < 0) {
			$l_time[$i]=24+$l_time[$i];
		} elsif ($l_time[$i] > 24) {
			$l_time[$i]=$l_time[$i]-24;
		}		

	}
	return @l_time;
}

