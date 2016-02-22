# Category=Entertainment

#@ This code will search for tv shows in the database created
#@ by tv_grid code.

$f_tv_file = new File_Item("$config_parms{data_dir}/tv_info1.txt");

$p_tv_info = new Process_Item(
    qq[get_tv_info -times all -keys "$config_parms{favorite_tv_shows}" -keyfile $config_parms{favorite_tv_shows_file} -title_only -early_am 0+6 -outfile2 $config_parms{data_dir}/web/tv_info3.txt]
);

$v_tv_results = new Voice_Cmd( 'What are the tv search results', 0 );
$v_tv_movies1 = new Voice_Cmd(
    "What TV movies are on channel [$config_parms{favorite_tv_channels}] tonight",
    0
);
$v_tv_movies2 =
  new Voice_Cmd( 'What TV movies are on at [6pm,7pm,8pm,9pm] tonight', 0 );
$v_tv_movies1->set_info(
    'Looks for TV shows that are 2-3 hours in length from 6 to 10 pm, on channels:',
    0
);
$v_tv_movies2->set_info(
    'Looks for TV shows that are 2-3 hours in length on all channels, at time:',
    0
);

$v_tv_shows1 = new Voice_Cmd(
    "What TV shows are on channel [$config_parms{favorite_tv_channels}] tonight"
);
$v_tv_shows2 = new Voice_Cmd('What TV shows of interest are on today');
$v_tv_shows1->set_info(
    "Lists all shows on from 6 to 10 pm tonight on channels:$config_parms{favorite_tv_channels}"
);
$v_tv_shows2->set_info(
    "Checks to see if any of the following shows in $config_parms{favorite_tv_shows} are on today"
);

if ( my $state = said $v_tv_movies1) {
    $v_tv_movies1->respond("app=tv Searching for TV movies...");
    run qq[get_tv_info -lengths 1.5-3 -times 6pm+4 -channels $state];
    set_watch $f_tv_file;
}
if ( my $state = said $v_tv_movies2) {
    $v_tv_movies2->respond("app=tv Searching for TV movies...");
    run qq[get_tv_info -lengths 1.5-3 -times $state+.5];
    set_watch $f_tv_file;
}

if ( my $state = said $v_tv_shows1) {
    $v_tv_shows1->respond("app=tv Searching for shows of interest...");
    run qq[get_tv_info -channels $state];
    set_watch $f_tv_file;
}
if ( my $state = said $v_tv_shows2) {
    respond "app=tv Searching for shows of interest...";

    my ( $min, $hour, $mday, $mon ) = ( localtime(time) )[ 1, 2, 3, 4 ];

    run
      qq[get_tv_info -keys "$config_parms{favorite_tv_shows}" -keyfile $config_parms{favorite_tv_shows_file} -title_only -early_am 0+6 -times all];

    set_watch $f_tv_file "$state favorites today";
}    # *** trigger
elsif ( time_cron('47 * * * *') or $Reload )
{ #Refresh favorite shows today at one after each hour (so as to prune ended shows from the Web page)
    print_log "Searching for TV shows of interest on today";

    #run qq[get_tv_info -times all -keys "$config_parms{favorite_tv_shows}" -keyfile $config_parms{favorite_tv_shows_file} -title_only -early_am 0+6 -outfile2 $config_parms{data_dir}/web/tv_info3.txt];

    start $p_tv_info;
}

if ( done_now $p_tv_info) {
    my $summary = file_read "$config_parms{data_dir}/web/tv_info3.txt";
    my ($show_count) = $summary =~ /Found (\d+)/;

    if ( defined $show_count ) {
        if ($show_count) {
            my $msg = "There";
            $msg .= ( $show_count > 1 ) ? " are " : " is ";
            $msg .=
              (     $show_count
                  . ( ( $show_count == 1 ) ? ' show' : ' shows' )
                  . ' of interest' );
            $Save{tv_favorites} = "$msg on today.";
            print_log $Save{tv_favorites};
        }
        else {
            $Save{tv_favorites} = undef;    # nothing of interest on today
        }
    }
    else {
        warn "Problem retrieving tv info: $summary";
    }
}

# Check for favorite shows ever 1/2 hour
if ( time_cron('58,28 * * * *') ) {
    my ( $min, $hour, $mday, $mon ) = ( localtime( time + 120 ) )[ 1, 2, 3, 4 ];
    $mon++;
    run
      qq[get_tv_info -quiet -times $hour:$min -dates $mon/$mday -keys "$config_parms{favorite_tv_shows}"  -keyfile $config_parms{favorite_tv_shows_file} -title_only];
    set_watch $f_tv_file 'favorites now';
}

# Search for requested keywords
&tk_entry( 'TV Search', \$Save{tv_search} );
&tk_entry( 'TV Dates',  \$Save{tv_days} );

if ( $Tk_results{'TV Search'} or $Tk_results{'TV Dates'} ) {
    print_log "Searching TV programs...";
    run
      qq[get_tv_info -times all -dates "$Save{tv_days}" -keys "$Save{tv_search}"];
    set_watch $f_tv_file;
    undef $Tk_results{'TV search'};
    undef $Tk_results{'TV dates'};
}

# Speak/show the results for all of the above requests

# *** need to untangle this mess

if ( ( $state = changed $f_tv_file) or ( my $state2 = said $v_tv_results) ) {
    my $summary = read_all $f_tv_file;
    my ($show_count) = $summary =~ /Found (\d+)/;

    if ( defined $show_count ) {

        $summary =
            "Found $show_count TV show"
          . ( ( $show_count == 1 ) ? ''  : 's' )
          . ( ($show_count)        ? ':' : '.' );
        my @data = read_all $f_tv_file;
        shift @data;    # Drop summary;

        my $i    = 0;
        my $list = '';
        foreach my $line (@data) {

            if ( my ( $title, $channel, $channel_number, $start, $end ) =
                $line =~
                /^\d+\.\s+(.+)\.\s+(\S+)\s+Channel (\d+).+From ([0-9: APM]+) till ([0-9: APM]+)\./
              )
            {
                if ($channel) {
                    $channel = "$channel ($channel_number)";
                }
                else {
                    $channel = "channel $channel_number";
                }

                $channel = $channel . ' (in progress)'
                  if $line =~ /(in progress.)/i;

                if ( $state eq 'favorites now' ) {
                    $list .= "$title $channel.\n";
                }
                else {
                    $list .= "$start $channel $title.\n";
                }
            }
            $i++;
        }

        my $msg = "There";
        $msg .= ( $show_count > 1 ) ? " are " : " is ";
        $msg .=
          (     $show_count
              . ( ( $show_count == 1 ) ? ' show' : ' shows' )
              . ' of interest' );
        if ( $state =~ 'favorites today' ) {
            if ( $show_count > 0 ) {
                respond "app=tv $msg on today.\n$list";
            }
            else {
                respond "app=tv There are no shows of interest on today";
            }
        }
        elsif ( $state eq 'favorites now' ) {
            speak "app=tv force_chime=1 Notice, "
              . lcfirst($msg)
              . " starting now.\n$list"
              if $show_count > 0;
        }
        else {
            chomp $summary;    # Drop CR
            respond "app=tv no_chime=1 $summary $list ";

        }
    }
    else {
        warn 'Error retrieving TV search results.';
    }

}
