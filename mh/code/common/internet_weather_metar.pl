# Category = Weather

#@ Retrieves current weather conditions and forecasts using 
# "http://weather.noaa.gov/cgi-bin/mgetmetar.pl?cccc=[METARCODE]", where
# [METARCODE] stands for the international local METAR (Meteorological Aviation Routine Weather Report) station ID.
# see "http://weather.noaa.gov" to look up your local METAR Code.

# As of now, this script works with an absolute path pointing to "c:/wetter.txt" and one METAR code: "EDDH". 
# You should substitute them with your path/data or put it into variables (which is better, of course).
# There is also much more data in a METAR report than the piece of information i found most interesting to extract.
# Now start looking for the sunshine ^-^:


# Get the current weather data from the internet via METAR Code
$v_get_internet_weather_data = new  Voice_Cmd('Get internet weather data');
$v_get_internet_weather_data-> set_info("Retrieve weather conditions and forecasts for METAR");

# This file will contain the weather report:
# $f_wetter   = new File_Item("c:/wetter.html");

if (said  $v_get_internet_weather_data or time_cron '10 8,12,16,20 * * *') {
    if (&net_connect_check) {

        #Here comes the 4 letter code of your local weather station
        my $p_weather = new Process_Item("get_url http://weather.noaa.gov/cgi-bin/mgetmetar.pl?cccc=EDDH c:/wetter.txt");

        print_log "Weather data requested for METAR=EDDH";
        start $p_weather;
    }
    else {
	   speak "Sorry, you must be logged onto the net";
    }
}

$v_show_internet_weather_data = new  Voice_Cmd('Show internet weather');
$v_show_internet_weather_data-> set_info('Display previously downloaded weather data');
$v_show_internet_weather_data-> set_authority('anyone');

if (said $v_show_internet_weather_data or time_cron '12 8,12,16,20 * * *') {
    
    my ($metar, $i);

    #METAR report in file
    for (file_read "c:/wetter.txt") {
        if (/EDDH(.+)/) {
		$i++;
		if($i == 4){
            $metar  = "$1\n";
            }
	  }
    }
	    
    my ($wind_dir, $wind_vel, $gusts, $visible, $clouds, $cloud_data, $temp, $pressure, $TEMPO, $NOSIG, $BECMG, $CAVOK);
    my $general;
    my $weather_remark_rain = new File_Item("$config_parms{data_dir}/remarks/bath_day.txt");
    my $weather_remark_belowzero = new File_Item("$config_parms{data_dir}/remarks/list_temp_below_0.txt");
    my $weather_thought_rain = read_random $weather_remark_rain;
    my $weather_thought_belowzero = read_random $weather_remark_belowzero;

    $wind_dir = "$1" if $metar =~ /Z\s(\d\d\d)\d\d\KT/;
    $wind_vel = "$1" if $metar =~ /Z\s\d\d\d(\d\d)KT/; 
    $wind_vel = "$1" if $metar =~ /Z\s\d\d\d(\d\d)G/;
    $gusts    = "and gusts with $1" if $metar =~ /G(\d\d)KT/;
    $visible  = "$1" if $metar =~ /KT\s(\d\d\d\d)/;
    $clouds   = "$1" if $metar =~ /(\S\S\S\d\d\d)\s\d\d\//;
    $temp     = "$1" if $metar =~ /(\d\d)\//;
    $pressure = "$1" if $metar =~ /Q(\d\d\d\d)/;
    $general .= "It drizzles." if $metar =~ /DZ/;
    $general .= "It rains." if $metar =~ /RA/;
    $general .= "Snow falls." if $metar =~ /SN/;
    $general .= "There have been snow grains reported." if $metar =~ /SG/;
    $general .= "There is mist." if $metar =~ /BR/;
    $TEMPO    = "is a temporary sign of change" if $metar =~ /TEMPO/;
    $NOSIG    = "seems to be no significant change ahead" if $metar =~ /NOSIG/;
    $BECMG	  = "is a weather change ahead" if $metar =~ /BECMG/;
    $CAVOK    = "is no better weather than this" if $metar =~ /CAVOK/;

    speak($weather_thought_rain) if $metar =~ /RA/ or $metar =~ /DZ/; 
    speak($weather_thought_belowzero) if $temp <= 0; 


    #change wind true degree to compass direction:    
    if(($wind_dir > 337.5) || ($wind_dir <= 22.5)){
       $wind_dir = "North" ;
    }
    elsif(($wind_dir > 22.5) && ($wind_dir <= 67.5)){
       $wind_dir = "North East" ;
    }
    elsif(($wind_dir > 67.5) && ($wind_dir <= 112.5)){
       $wind_dir = "East" ;
    }
    elsif(($wind_dir > 112.5) && ($wind_dir <= 157.5)){
       $wind_dir = "South East" ;
    }
    elsif(($wind_dir > 157.5) && ($wind_dir <= 202.5)){
       $wind_dir = "South" ;
    }
    elsif(($wind_dir > 202.5) && ($wind_dir <= 247.5)){
       $wind_dir = "South West" ;
    }
    elsif(($wind_dir > 247.5) && ($wind_dir <= 292.5)){
       $wind_dir = "West" ;
    }
    elsif(($wind_dir > 292.5) && ($wind_dir <= 337.5)){
       $wind_dir = "North West" ;
    }

    #change wind velocity into km/h:    
    $wind_vel *= 1.85;  
     
    #4types of cloudy sky:
    $cloud_data = "$1" if $clouds =~ /SKC(\d\d\d)/ or $clouds =~ /CLR/ or $clouds =~ /NSC/;
    $cloud_data = "$1" if $clouds =~ /FEW(\d\d\d)/;
    $cloud_data = "$1" if $clouds =~ /SCT(\d\d\d)/;
    $cloud_data = "$1" if $clouds =~ /BKN(\d\d\d)/;
    $cloud_data = "$1" if $clouds =~ /OVC(\d\d\d)/;

    #001 = 100ft and change feet to meters:    
    $cloud_data *= 30.48;

    #4types of cloudy sky:
    $clouds = "and there are no clouds in $cloud_data meters" if $clouds =~ /SKC/ or $clouds =~ /CLR/ or $clouds =~ /NSC/;
    $clouds = "and there are few clouds in $cloud_data meters" if $clouds =~ /FEW/;
    $clouds = "and there are some clouds in $cloud_data meters" if $clouds =~ /SCT/;
    $clouds = "and there are many clouds in $cloud_data meters" if $clouds =~ /BKN/;
    $clouds = "and there are only clouds in $cloud_data meters" if $clouds =~ /OVC/;

    #visibility:
    if($visible == 9999){
       $visible = "Visibility is above 10 kilometers";
    }
    else{
       $visible = "Visibility is below $visible meters";
    }

    #Additional: high/low pressure area
    my $area;
    if($pressure >= 1016){
       $area = "high";
    }
    else{
       $area = "low";
    }
    
    #4 different types of major forcasts:
    my $forc;
    if($TEMPO ne ""){$forc = $TEMPO};
    if($NOSIG ne ""){$forc = $NOSIG};
    if($BECMG ne ""){$forc = $BECMG};
    if($CAVOK ne ""){$forc = $CAVOK};   

    my $cast;
    $cast = "Wind comes from $wind_dir with $wind_vel kilometers per hour $gusts. 
    $visible $clouds. Temperature is $temp degree, while pressure is $area with $pressure hecto pascal. 
    $general. Forecast tells that there $forc."; 

    $v_mp3_control -> set('pause~20~play');
    speak "$cast";
}



