# Category=TV

$f_tv_file = new File_Item("$config_parms{data_dir}/tv_info1.txt");

$v_tv_movies1 = new  Voice_Cmd('What TV movies are on channel [all,4-12,4,6,8,9,12] tonight');
$v_tv_movies2 = new  Voice_Cmd('What TV movies are on at [6pm,7pm,8pm,9pm] tonight');
$v_tv_movies1-> set_info('Looks for TV shows that are 2-3 hours in length from 6 to 10 pm, on channels:');
$v_tv_movies2-> set_info('Looks for TV shows that are 2-3 hours in length on all channels, at time:');

$v_tv_shows1 = new  Voice_Cmd('What TV shows are on channel [5,6,8,9,12,51] tonight');
$v_tv_shows2 = new  Voice_Cmd('What favorite TV shows are on tonight');
$v_tv_shows1-> set_info('Lists all shows on from 6 to 10 pm tonight on channel:');
$v_tv_shows2-> set_info("Checks to see if any of the following shows are on tonight: $config_parms{favorite_tv_shows}");

if ($state = said  $v_tv_movies1) {
    run qq[get_tv_info -length 2-3 -times 6pm+4 -channels $state];
    set_watch $f_tv_file;
}
if ($state = said  $v_tv_movies2) {
    run qq[get_tv_info -length 2-3 -times $state+.5];
    set_watch $f_tv_file;
}

if ($state = said  $v_tv_shows1) {
    run qq[get_tv_info -channels $state];
    set_watch $f_tv_file;
}
if (said $v_tv_shows2) {
    print_log "Searching for $config_parms{favorite_tv_shows}";
    run qq[get_tv_info -keys "$config_parms{favorite_tv_shows}"];
    set_watch $f_tv_file 'favorites tonight';
}

                                # Check for favorite shows ever 1/2 hour
if (time_cron('0,30 18-22 * * *')) {
    run qq[get_tv_info -times $Hour:$Minute -keys "$config_parms{favorite_tv_shows}" -quiet];
    set_watch $f_tv_file 'favorites now';
}

                                # Search for requested keywords
#&tk_entry('TV search', \$Save{tv_search}, 'TV dates', \$Save{tv_days});
if ($Tk_results{'TV search'} or $Tk_results{'TV dates'}) {
    speak "Searching";
    run qq[get_tv_info -times all -dates "$Save{tv_days}" -keys "$Save{tv_search}"];
    set_watch $f_tv_file;
    undef $Tk_results{'TV search'};
    undef $Tk_results{'TV dates'};
}

                                # Speak/show the results for all of the above requests
if ($state = changed $f_tv_file) {
    my $f_tv_info2 = "$config_parms{data_dir}/tv_info2.txt";

    my $summary = read_head $f_tv_file 6;
    my ($show_count) = $summary =~ /Found (\d+)/;
    my @data = read_all $f_tv_file;
    shift @data;            # Drop summary;

    my $msg = "There ";
    $msg .= ($show_count > 1) ? " are " : " is ";
    $msg .= plural($show_count, 'favorite show');
    if ($state eq 'favorites tonight') {
        if ($show_count > 0) {
            speak "$msg on tonight. @data";
        }
        else {
            speak "There are no favorite shows on tonight";
        }
    }
    elsif ($state eq 'favorites now') {
        speak "rooms=all Notice, $msg starting now.  @data" if $show_count > 0;
    }
    else {
        chomp $summary;         # Drop the cr
        speak $summary;
    }
    display $f_tv_info2 if $show_count;
}

    

