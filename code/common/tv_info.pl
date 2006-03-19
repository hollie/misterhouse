# Category=Entertainment

#@ This code will search for tv shows in the database created
#@ by tv_grid code.

$f_tv_file = new File_Item("$config_parms{data_dir}/tv_info1.txt");

$v_tv_results = new  Voice_Cmd '[What are,Show] the tv search results';
$v_tv_movies1 = new  Voice_Cmd('What TV movies are on channel [$config_parms{favorite_tv_channels}] tonight');
$v_tv_movies2 = new  Voice_Cmd('What TV movies are on at [6pm,7pm,8pm,9pm] tonight');
$v_tv_movies1-> set_info('Looks for TV shows that are 2-3 hours in length from 6 to 10 pm, on channels:');
$v_tv_movies2-> set_info('Looks for TV shows that are 2-3 hours in length on all channels, at time:');

$v_tv_shows1 = new  Voice_Cmd('What TV shows are on channel [$config_parms{favorite_tv_channels}] tonight');
$v_tv_shows2 = new  Voice_Cmd('[Show,What are the] favorite TV shows on today');
$v_tv_shows1-> set_info('Lists all shows on from 6 to 10 pm tonight on channel:');
$v_tv_shows2-> set_info("Checks to see if any of the following shows in $config_parms{favorite_tv_shows} are on today");

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
if ($state = said $v_tv_shows2) {
    print_log "Searching for favorite shows";
    run qq[get_tv_info -times all -keys "$config_parms{favorite_tv_shows}" -keyfile $config_parms{favorite_tv_shows_file} -title_only];
    set_watch $f_tv_file "$state favorites today";
}
elsif (time_cron('0 0 * * *') or $Reload) { #Refresh favorite shows today at midnight
    print_log "Searching for favorite shows on today";
    run qq[get_tv_info -times all -keys "$config_parms{favorite_tv_shows}" -keyfile $config_parms{favorite_tv_shows_file} -title_only -outfile2 $config_parms{data_dir}/web/tv_info3.txt];

}

                                # Check for favorite shows ever 1/2 hour
if (time_cron('58,28 * * * *')) {
    my ($min, $hour, $mday, $mon) = (localtime(time + 120))[1,2,3,4];
    $mon++;
    run qq[get_tv_info -quiet -times $hour:$min -dates $mon/$mday -keys "$config_parms{favorite_tv_shows}"  -keyfile $config_parms{favorite_tv_shows_file}  -title_only];
    set_watch $f_tv_file 'favorites now';
}


                                # Search for requested keywords
&tk_entry('TV search', \$Save{tv_search}, 'TV dates', \$Save{tv_days});
if ($Tk_results{'TV search'} or $Tk_results{'TV dates'}) {
    print_log "Searching TV programs...";
    run qq[get_tv_info -times all -dates "$Save{tv_days}" -keys "$Save{tv_search}"];
    set_watch $f_tv_file;
    undef $Tk_results{'TV search'};
    undef $Tk_results{'TV dates'};
}

                                # Speak/show the results for all of the above requests




if (($state = changed $f_tv_file) or (my $state2 = said $v_tv_results)) {
    my $f_tv_info2 = "$config_parms{data_dir}/tv_info2.txt";

    my $summary = read_head $f_tv_file 6;
    my ($show_count) = $summary =~ /Found (\d+)/;
    $summary = "Found $show_count TV shows:";
    my @data = read_all $f_tv_file;
    shift @data;            # Drop summary;

    my $i = 0;
    my $list = '';
    foreach my $line (@data) {

        if (my ($title, $channel, $start, $end) =
          $line =~ /^\d+\.\s+(.+)\.\s+\S+\s+Channel (\d+).+From ([0-9: APM]+) till ([0-9: APM]+)\./) {

            if ($state eq 'favorites now') {
                $list .= "$title Channel $channel.\n";
            }
            else {
                $list .= "$start Channel $channel $title.\n";
            }
        }
        $i++;
    }

    my $msg = "There ";
    $msg .= ($show_count > 1) ? " are " : " is ";
    $msg .= plural($show_count, 'favorite show');
    if ($state =~ 'favorites today') {
        if ($show_count > 0) {
	    if ($state =~ 'What') {
            	respond "target=speak app=tv $msg on today. $list";
	    }
	    else {
		respond "app=tv $msg on today. $list\n";
            }
        }
        else {
                respond "target=" . ((($state =~ 'What'))?'speak':'') . " app=tv There are no favorite shows on today";
        }
    }
    elsif ($state eq 'favorites now') {
        speak "app=tv Notice, $msg starting now.  $list" if $show_count > 0;
    }
    else {
        chomp $summary;         # Drop the cr
	if ($state2 eq 'Show') {
        	respond "app=tv $summary $list ";
	}
	else {
		respond "app=tv target=speak $summary $list ";
	}
    }

}
