# Category=Informational

#@ Announces time and date info (e.g. sun/moon times and holidays)

$v_what_time = new  Voice_Cmd('{What time is it,Tell me the time}', 0);
$v_what_time-> set_info('Says the Time and Date');
$v_what_time-> set_authority('anyone');
#$v_what_time = new Voice_Cmd("{Please, } tell me the time");

if (said $v_what_time) {
    my $temp = "It is $Holiday" if $Holiday;
              # Avoid really speaking if command was from an Instant Messanger
    my $mode = (get_set_by $v_what_time eq 'im') ? 'mode=mute' : '';
    speak "$mode It is $Time_Now on $Date_Now_Speakable. $temp";
}

speak "Today is $Holiday" if $Holiday and time_cron '30 9,12,19 * * *';

$v_sun_set = new  Voice_Cmd('When will the sun set', 0);
$v_sun_set-> set_info("Calculates sunrise and sunset for latitude=$config_parms{latitude}, longitude=$config_parms{longitude}");
$v_sun_set-> set_authority('anyone');
speak "Sunrise today is at $Time_Sunrise, sunset is at $Time_Sunset." if said $v_sun_set;

speak "Notice, the sun is now rising at $Time_Sunrise" if time_now $Time_Sunrise and !$Save{sleeping_parents};
speak "app=notice Notice, the sun is now setting at $Time_Sunset"  if time_now $Time_Sunset;


$v_moon_info1 = new Voice_Cmd "When is next [new,full] moon";
$v_moon_info2 = new Voice_Cmd "When was the last [new,full] moon";
$v_moon_info3 = new Voice_Cmd "What is the phase of the moon";
$v_moon_info3-> set_info('Phase will be: New, One-Quarter Waxing, Half Waxing, Three-Quarter Waxing, Full, etc for Waning');
$v_moon_info1-> set_authority('anyone');
$v_moon_info2-> set_authority('anyone');
$v_moon_info3-> set_authority('anyone');

if ($state = said $v_moon_info1) {
    my $days = &time_diff($Moon{"time_$state"}, $Time);
    speak qq[The next $state moon is in $days, on $Moon{$state}];
}

if ($state = said $v_moon_info2) {
    my $days = &time_diff($Moon{"time_${state}_prev"}, $Time);
    speak qq[The last $state moon was $days ago, on $Moon{"${state}_prev"}];
}

if ($state = said $v_moon_info3) {
    speak qq[The moon is $Moon{phase}, $Moon{brightness}% bright, and $Moon{age} days old];
}

$full_moon = new File_Item("$config_parms{data_dir}/remarks/full_moon.txt");
if ($Moon{phase} eq 'Full' and time_random('* 8-22 * * *', 240)) {
    speak "app=notice Notice, tonight is a full moon.  " . (read_next $full_moon);
}


