# Category=Internet

				# An example on how to get and process html from the net ... Lettermans top 10 list

my $f_top10_list = "$config_parms{data_dir}/web/top10_list.txt";
my $f_top10_html = "$config_parms{data_dir}/web/top10_list.html";

#$f_top10_html2 = new File_Item($f_top10_html); # Needed if we use run instead of process_item

#p_top10_list = new Process_Item("get_url http://marketing.cbs.com/lateshow/topten/ $f_top10_html");
#p_top10_list = new Process_Item("get_url http://marketing.cbs.com/network/tvshows/mini/lateshow/index.shtml $f_top10_html");
#p_top10_list = new Process_Item("get_url http://marketing.cbs.com/latenight/lateshow/# $f_top10_html");
#p_top10_list = new Process_Item("get_url http://www.cbs.com/latenight/lateshow/# $f_top10_html");
$p_top10_list = new Process_Item("get_url http://www.cbs.com/latenight/lateshow/top_ten/ $f_top10_html");

$v_top10_list  = new  Voice_Cmd('[Get,Read,Show] the top 10 list');
$v_top10_list -> set_info("This is David Lettermans famoust Top 10 List"); 

                                # Allow for an open access action
$v_top10_list2 = new  Voice_Cmd('{Display,What is} the top 10 list');
$v_top10_list2-> set_info("This is David Lettermans famoust Top 10 List"); 
$v_top10_list2-> set_authority('anyone');
$v_top10_list2-> tie_items($v_top10_list, 1, 'Show');

$state = said $v_top10_list;
speak  voice => 'male', text => $f_top10_list, display => 0 if $state eq 'Read';
display text => $f_top10_list, time => 300, font => 'Times 25 bold', geometry => '+0+0', width => 72, height => 24
#display text => $f_top10_list, time => 300, font => 'biggest' if $state eq 'Show' or $state eq 'Read';
  if $state eq 'Show' or $state eq 'Read';

if (said $v_top10_list eq 'Get') {

                                # Do this only if we the file has not already been updated today and it is not empty
    if (-s $f_top10_html > 10 and
        time_date_stamp(6, $f_top10_html) eq time_date_stamp(6)) {
        print_log "Top 10 list is current";
#       set $v_top10_list 'Show';
        start $p_top10_list 'do_nothing';  # Fire the process with no-op, so we can still run the parsing code for debug
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving top10 list from the net ...";

                                # Use start instead of run so we can detect when it is done
            start $p_top10_list;
#           run "get_url http://marketing.cbs.com/lateshow/topten/ $f_top10_html";
#           set_watch $f_top10_html2;

#           $html = get 'http://marketing.cbs.com/lateshow/topten';
#           file_write("$config_parms{data_dir}/web/top10_list.html", $html);
        }
        else {
            speak "Sorry, you must be logged onto the net";
        }
    }            
}

if (done_now $p_top10_list) {
    my $html = file_read $f_top10_html;

    my $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($html));

                                # Delete &nbsb
    $text =~ s/\240/ /g;

                                # Delete text preceeding the list
#<tr valign="top"><td width="290" valign="top" align="center"><font class="toptentitle">Top Ten Signs You've Hired A Bad NFL Referee</font></td></tr>
#   $text =~ s/^.+?the Top Ten List for/The Top Ten list for/is;
#   $text =~ s/^.+?Top Ten/Top Ten/is;
    $text =~ s/^.+(Top Ten.+?.+10\.)/$1/is;

                                # Delete data past the last line: 1. xxxxx\n
    $text =~ s/(.+?\n\s *1\..+?)\n.+/$1\n/s;
                                # Add a period at the end of line, if needed
    $text =~ s/([^\.\?\!])\n/$1\.\n/g;
                                # Drop the (name) at the end of each line (name of presentor)
    $text =~ s/\(.+?\)[ \.]+\n/\n/g;
                                # Only one blank line per item.
    $text =~ s/\n\s+\n/\n\n/g;
                                # Make sure the number at the beginning as a space.
    $text =~ s/(\n[\d]+)\.?/$1\. /g;

    file_write($f_top10_list, $text);

    set $v_top10_list 'Show';
}


                                # Get the forcast and current weather data from the internet
$v_get_internet_weather_data = new  Voice_Cmd('Get internet weather data');
$v_get_internet_weather_data-> set_info("Retreive weather conditions and forecasts for $config_parms{city}, $config_parms{state}");

                                # These files get set by the get_weather program
$f_weather_forecast   = new File_Item("$config_parms{data_dir}/web/weather_forecast.txt");
$f_weather_conditions = new File_Item("$config_parms{data_dir}/web/weather_conditions.txt");

if (said  $v_get_internet_weather_data) {
    if (&net_connect_check) {
                                # Detatch this, as it may take 10-20 seconds to retreive
                                # Another, probably better way, to do this is with the
                                # Process_Item, as is with p_top10_list above
        run "get_weather -city $config_parms{city} -zone $config_parms{zone} -state $config_parms{state}";

        set_watch $f_weather_forecast;
        speak "Weather data requested";
    }
    else {
	    speak "Sorry, you must be logged onto the net";
    }
}

$v_show_internet_weather_data = new  Voice_Cmd('Show internet weather [forecast,conditions]');
$v_show_internet_weather_data-> set_info('Display previously downloaded weather data');
$v_show_internet_weather_data-> set_authority('anyone');
if ($state = said  $v_show_internet_weather_data or changed $f_weather_forecast) {
    print_log "Weather $state displayed";
    if ($state eq 'forecast') {
        my $name = name $f_weather_forecast;
        print "displaying $f_weather_forecast $name\n";
        display name $f_weather_forecast;
        display $name;
    }
    else {
        print "displaying $f_weather_conditions\n";
        display name $f_weather_conditions;
# Parse data.  Here is an example:
# At 6:00 AM, Rochester, MN conditions were  at  55 degrees , wind was south at
#    5 mph.  The relative humidity was 100%, and barometric pressure was
#    rising from 30.06 in.
        my $conditions = read_all $f_weather_conditions;
        $conditions =~ s/\n/ /g;
        $Weather{TempInternet}  = $1 if $conditions =~ /(\d+) degrees/i;
        $Weather{HumidInternet} = $1 if $conditions =~ /(\d+)\%/;
        $Weather{BaromInternet} = $1 if $conditions =~ /([\d\.]+) in\./;
        $Weather{WindInternet}  = $1 if $conditions =~ /wind (.+?)\./;
        print_log "Internet weather Temp=$Weather{TempInternet} Humid=$Weather{HumidInternet} " . 
                  "Wind=$Weather{WindInternet} Pres=$Weather{BaromInternet}";
    }
}



                                # Check clock against an internet atomic clock
$v_set_clock = new  Voice_Cmd('Set the clock via the internet');
$v_set_clock-> set_info('Use an Internet connected atomic clock to set your pc clock time');
set_icon $v_set_clock 'time';
if (said $v_set_clock or
    time_cron '7 6 * * * ') {
    print "Running set_clock to set clock via the internet ...";
#   run "$Pgm_Path/set_clock"; 
    @ARGV = (-log => "$config_parms{data_dir}/logs/set_clock.log");
    my $status = do "$Pgm_Path/set_clock"; 
    print " set_clock was run\n";
    print_log "Clock has been set";
    speak $status unless $Save{sleeping_parents};
}

my $f_set_clock_log = "$config_parms{data_dir}/logs/set_clock.log";
$v_view_clock_log = new  Voice_Cmd('Display the clock adjustment log');
display $f_set_clock_log if said $v_view_clock_log;

