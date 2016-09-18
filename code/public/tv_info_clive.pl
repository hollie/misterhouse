# Category=TV

my ( $start, $tv_flag, $tv_window );
$start = ( $Hour < 18 ) ? 18 : $Hour;
$start = ( $Hour < 7 ) ? 7 : $Hour if ($Weekend);

$f_tv_file = new File_Item("$config_parms{data_dir}/tv_info1.txt");

$v_tv_movies1 = new Voice_Cmd(
    'What TV movies are on channel [23,26,30,33,37] today (=Carlton, BBC1, Ch4, BBC2, Ch5)'
);

#$v_tv_movies2 = new  Voice_Cmd('What TV movies are on at [6pm,7pm,8pm,9pm] tonight');
$v_tv_movies1->set_info('Looks for TV movies, on channels:');

#$v_tv_movies2-> set_info('Looks for TV shows that are 2-3 hours in length on all channels, at time:');

$v_tv_shows1 = new Voice_Cmd(
    'What TV shows are on channel [23,26,30,33,37] today (=Carlton, BBC1, Ch4, BBC2, Ch5)'
);
$v_tv_shows1->set_info('Lists all shows on from 6 to 10 pm today on channel:');

$v_tv_shows2 = new Voice_Cmd(
    'What favorite TV programs are on [tonight,late tonight,this afternoon,this morning,tomorrow,today and tomorrow,next 2 days,yesterday]'
);
$v_tv_shows2->set_info("Checks to see what's on TV");

#$v_tv_shows2-> set_info("Checks to see if any of the following programs are on tonight:
#$config_parms{favorite_tv_shows}");

$v_tv_shows3 = new Voice_Cmd('TV for [Clive,Edward,James,Best] today');
$v_tv_shows3->set_info(
    "Checks to see what's on TV today for Clive,Edward,James,Best");
##$v_tv_shows3-> set_info("Checks to see if any of the following programs are on today:
#$config_parms{favorite_tv_shows}");

$v_tv_shows4 = new Voice_Cmd('TV films today');
$v_tv_shows4->set_info("Checks to see what films are on TV today");

$v_tv_print = new Voice_Cmd('Print TV program selection');
$v_tv_print->set_info("Prints out your TV program selections");

$v_play_tv = new Voice_Cmd('Turn on TV channel [23,26,30,33,37]');

if ( $state = said $v_play_tv) {
    &turn_on_tv;
}

if ($New_Minute) {
    if ( &WaitForAnyWindow( 'WinTV', \$tv_window, 100, 100 ) ) {
        $Save{TV_on} = 1;
    }
    else { $Save{TV_on} = 0; }
}

$Save{TV_on} = 0 if ($Reload);

sub turn_on_tv {
    $tv_window =
      &sendkeys_find_window( 'WinTV', 'C:\Progra~1\WinTV\hcw.exe /WINTV2K' );
    my $tv_command = "Turn on TV channel $state";
    my $timer_tv   = new Timer;
    if ( $Save{TV_on} ) { &SendKeys( $tv_window, $state, 1, 500 ); }
    else {
        set $timer_tv 2, "run_voice_cmd '$tv_command'";
        $Save{TV_on} = 1;
    }
}

sub turn_on_tv_spare2 {
    my $temp_window;
    $Save{TV_on} = 0
      if ( &WaitForAnyWindow( 'WinTV', \$temp_window, 100, 100 ) );
    print "$Save{TV_on}\n";
    my $window =
      &sendkeys_find_window( 'WinTV', 'C:\Progra~1\WinTV\hcw.exe /WINTV2K' );
    my $tv_command = "Turn on TV channel $state";
    print_log $tv_command;
    print "$tv_command\n";
    my $timer_tv = new Timer;

    #  set $timer_tv 15, "run_voice_cmd 'Turn on TV channel $state'" if (!$Save{TV_on});
    set $timer_tv 15, "run_voice_cmd '$tv_command'" if ( !$Save{TV_on} );
    $Save{TV_on} = 1;
    &SendKeys( $window, $state, 1, 500 );
}

sub turn_on_tv_spare {
    if ( my $window =
        &sendkeys_find_window( 'WinTV', 'C:\Progra~1\WinTV\hcw.exe /WINTV2K' ) )
    {
        &SendKeys( $window, '23', 1, 500 ) if $state == '23';
        &SendKeys( $window, '26', 1, 500 ) if $state == '26';
    }
}

# Films today
if ( $state = said $v_tv_movies1) {
    run qq[get_tv_info_uk -keys "Film" -times  "$start-23.5" -channels $state];
    set_watch $f_tv_file;
}

#if ($state = said  $v_tv_movies2) {
#    run qq[get_tv_info_uk -length 2-3 -times $state+.5];
#    run qq[get_tv_info_uk -keys "film" -times 6pm+6];
#    set_watch $f_tv_file;
#}

if ( $state = said $v_tv_shows1) {
    run qq[get_tv_info_uk -channels $state -times "$start-23.5"];
    set_watch $f_tv_file;
}

# Evening
if ( said $v_tv_shows2 eq 'tonight' ) {
    print_log "Searching for TV programs";

    #    run qq[get_tv_info_uk -keys "$config_parms{favorite_tv_shows}"];
    #    run qq[get_tv_info_uk -keyfile "TV_clive.list" -dates "10/7" -time "18-23.5"];
    run
      qq[get_tv_info_uk -keyfile "TV_clive.list" -dates "${Month}/$Mday" -time "$start-23.55"];

    #   run qq[get_tv_info_uk -time "20:00" -keyfile "TV_clive.list" -dates $Month/$Mday  -quiet];
####    set_watch $f_tv_file 'favorites tonight';
    set_watch $f_tv_file;
}

# Clive, Edward, James, Best
if ( said $v_tv_shows3) {
    my ( $key_file, $tv_times );
    print_log "Searching for TV programs";
    if ( said $v_tv_shows3 eq 'Clive' ) {
        $key_file = "TV_clive.list";
        $tv_times = "$start-23:59";
    }
    if ( said $v_tv_shows3 eq 'Best' ) {
        $key_file = "TV_best.list";
        $tv_times = "$start-23:59";
    }
    if ( said $v_tv_shows3 eq 'Edward' ) {
        $key_file = "TV_edward.list";
        $tv_times = "$start-22";
    }
    if ( said $v_tv_shows3 eq 'James' ) {
        $key_file = "TV_james.list";
        $tv_times = "$start-22.5";
    }
    run
      qq[get_tv_info_uk -keyfile $key_file -dates "${Month}/$Mday" -time $tv_times];
    set_watch $f_tv_file;
}

if ( said $v_tv_shows4) {
    print_log "Searching for TV programs";
    run
      qq[get_tv_info_uk -keys "film" -dates "${Month}/$Mday" -time "$start-23.5"];
    set_watch $f_tv_file;
}

# Morning
if ( said $v_tv_shows2 eq 'this morning' ) {
    $start = ( $Hour < 4 ) ? 4 : $Hour;
    print_log "Searching for TV programs";
    run
      qq[get_tv_info_uk -keyfile "TV_clive.list"  -dates "${Month}/$Mday" -time "$start-13"];
    set_watch $f_tv_file;
}

# Afternoon
if ( said $v_tv_shows2 eq 'this afternoon' ) {
    $start = ( $Hour < 13 ) ? 13 : $Hour;
    print_log "Searching for TV programs";
    run
      qq[get_tv_info_uk -keyfile "TV_clive.list"  -dates "${Month}/$Mday" -time "$start-18"];
    set_watch $f_tv_file;
}

# Late tonight
if ( said $v_tv_shows2 eq 'late tonight' ) {

    #    $start = ($Hour > 18 and $Hour < 23) ? 23 : $Hour;
    $start = 0;
    my $this_day = ( $Hour > 5 ) ? $Mday : $Mday - 1;
    print_log "Searching for TV programs";
    run
      qq[get_tv_info_uk -keyfile "TV_clive.list"  -dates "${Month}/$this_day" -time "$start-6"];
    set_watch $f_tv_file;
}

# Yesterday
if ( said $v_tv_shows2 eq 'yesterday' ) {
    print_log "Searching for TV programs";
    my $this_day = $Mday - 1;
    run
      qq[get_tv_info_uk -keyfile "TV_clive.list"  -dates "${Month}/$this_day" -times "all" ];
    set_watch $f_tv_file;
}

# Tomorrow
if ( said $v_tv_shows2 eq 'tomorrow' ) {
    print_log "Searching for TV programs";
    my $tomorrow_day = $Mday + 1;

    #    run qq[get_tv_info_uk -keyfile "TV_clive.list" -dates "${Month}/$tomorrow_day" -time "$start-23.5"];
    run
      qq[get_tv_info_uk -keyfile "TV_clive.list" -dates "${Month}/$tomorrow_day" -times "all" ];
    set_watch $f_tv_file;
    my $summary = read_head $f_tv_file 6;
    my ($show_count) = $summary =~ /Found (\d+)/;
    speak "Probably no data for tomorrow in database." unless ($show_count);
}

# Next 2 days
if ( said $v_tv_shows2 eq 'next 2 days' ) {
    print_log "Searching for TV programs";
    my $tomorrow_day = $Mday + 1;
    my $second_day   = $Mday + 2;

    #    run qq[get_tv_info_uk -keyfile "TV_clive.list" -dates "${Month}/$tomorrow_day" -time "$start-23.5"];
    run
      qq[get_tv_info_uk -keyfile "TV_clive.list" -dates "${Month}/$tomorrow_day-${Month}/$second_day" -times "all" ];

    #    run qq[get_tv_info_uk -keyfile "TV_clive.list" -dates +2 -times "all" ];
    set_watch $f_tv_file;
    my $summary = read_head $f_tv_file 6;
    my ($show_count) = $summary =~ /Found (\d+)/;
    speak "Probably no data for that day in database." unless ($show_count);
}

# Today and tomorrow
if ( said $v_tv_shows2 eq 'today and tomorrow' ) {
    print_log "Searching for TV programs";
    run qq[get_tv_info_uk -keyfile "TV_clive.list" -dates +1 -times "all" ];
    set_watch $f_tv_file;
    my $summary = read_head $f_tv_file 6;
    my ($show_count) = $summary =~ /Found (\d+)/;
    speak "Probably no data for that day in database." unless ($show_count);
}

# Check for favorite shows ever 1/2 hour
#if ($New_Minute) {
# if ($Reload) {
if ( time_cron('59,4,9,14,19,24,29,34,39,44,49,54, * * * *') ) {

    # if (time_cron('59,14,29,44 18-23.5 * * *')) {
    #    run qq[get_tv_info_uk -time $Hour:$Minute -keys "$config_parms{favorite_tv_shows}" -quiet];
    my $Next_Minute = ( $Minute == 59 ) ? "00" : $Minute + 1;
    run
      qq[get_tv_info_uk -time $Hour:$Next_Minute -keyfile "TV_best.list" -dates $Month/$Mday  -quiet];
    set_watch $f_tv_file 'favorites now';

    # scf new:
    sleep 2;
    my $f_tv_info2   = "$config_parms{data_dir}/tv_info2.txt";
    my $summary      = file_head( $f_tv_info2, 6 );
    my ($show_count) = $summary =~ /Found (\d+)/;
    my ($channel)    = $summary =~ /\(Channel.(..)/s;
    if ($show_count) {
        print "channel = $channel\n";
        $state = $channel;
        &turn_on_tv;
    }

    # scf end
}

# Search for requested keywords
#&tk_entry('TV search', \$Save{tv_search}, 'TV dates', \$Save{tv_days});
if ( $Tk_results{'TV search'} or $Tk_results{'TV dates'} ) {
    speak "Searching";
    run
      qq[get_tv_info_uk -times all -dates "$Save{tv_days}" -keys "$Save{tv_search}"];
    set_watch $f_tv_file;
    undef $Tk_results{'TV search'};
    undef $Tk_results{'TV dates'};
}

# Speak/show the results for all of the above requests
if ( $state = changed $f_tv_file) {
    my $f_tv_info2 = "$config_parms{data_dir}/tv_info2.txt";

    my $summary      = read_head $f_tv_file 6;
    my ($show_count) = $summary =~ /Found (\d+)/;
    my @data         = read_all $f_tv_file;
    shift @data;    # Drop summary;
    foreach $_ (@data) { s/CH/Channel /; }

    my $msg = "There ";
    $msg .= ( $show_count > 1 ) ? " are " : " is ";
    $msg .= plural( $show_count, 'favorite show' );
    if ( $state eq 'favorites tonight' ) {
        if ( $show_count > 0 ) {
            speak "$msg on tonight. @data";
        }
        else {
            # scf
            #            speak "There are no favorite shows are on tonight";
            speak "There are no favorite shows on tonight";
        }
    }
    elsif ( $state eq 'favorites now' ) {
        speak "rooms=all Notice, $msg starting $start.  @data"
          if $show_count > 0;
    }
    else {
        chomp $summary;    # Drop the cr
        speak $summary;
    }
    display $f_tv_info2 if $show_count;
}

if ( said $v_tv_print) {
    browser "$config_parms{data_dir}/tv_info2.html";
    &WaitForAnyWindow( 'Explorer', \$window, 100, 100 );
    &SendKeys(
        $window,
        '\\CTRL+\\p\\CTRL-\\TAB\\TAB\\TAB\\TAB\\TAB\\TAB\\TAB\\TAB\\TAB\\TAB\\TAB\\RET\\',
        1,
        500
    );
}

