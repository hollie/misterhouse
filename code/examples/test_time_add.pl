
my $fishtank_light_on_time;
my $fishtank_light_off_time;
my $fishtank_light_duration;

if ($Startup) {
    $fishtank_light_on_time  = time_add "$Time_Sunrise_Twilight+3:00";
    $fishtank_light_off_time = time_add "$Time_Sunset_Twilight+4:00";
    $fishtank_light_duration =
      time_add "$fishtank_light_off_time-$fishtank_light_on_time";
}

if ($Reread) {
    print "db1 $Time_Sunrise_Twilight\n";
    print "db2 $fishtank_light_on_time\n";
    print "db3 $fishtank_light_off_time\n";
    print "db4 $fishtank_light_duration\n";
}
