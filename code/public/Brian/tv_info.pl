# Category=TV

$f_tv_file = new File_Item("$Pgm_Root/data/tv_info1.txt");

$v_tv_movies1 = new  Voice_Cmd('What TV movies are on channel [all,2-11,2,4,5,9,11,23,29] tonight');
$v_tv_movies2 = new  Voice_Cmd('What TV movies are on at [6pm,7pm,8pm,9pm] tonight');
$v_tv_movies3 = new  Voice_Cmd('What TV shows are on channel [2,4,5,9,11,23,29] tonight');

if ($state = said  $v_tv_movies1) {
    run qq[get_tv_info -length 2-3 -times 6pm+4 -channels $state];
    set_watch $f_tv_file 'favorites speak';
}
if ($state = said  $v_tv_movies2) {
    run qq[get_tv_info -length 2-3 -times $state+.5];
    set_watch $f_tv_file 'favorites speak';
}
if ($state = said  $v_tv_movies3) {
    run qq[get_tv_info -channels $state];
    set_watch $f_tv_file 'favorites speak';
}

my $favorite_tv_shows = "star trek,family guy,Ally McBeal,southpark,bill nye";

$v_tv_movies4 = new  Voice_Cmd('What favorite TV shows are on tonight');
if (said $v_tv_movies4) {
    run qq[get_tv_info -keys "$favorite_tv_shows"];
    set_watch $f_tv_file 'favorites tonight';
}

                                # Check for favorite shows ever 1/2 hour
#if (time_cron('0,30 18-22 * * *')) {
#    run qq[get_tv_info -times $Hour:$Minute -keys "$favorite_tv_shows"];
#    set_watch $f_tv_file 'favorites now';
#}

                                # Search for requested keywords
&tk_entry('TV search', \$Save{tv_search}, 'TV dates', \$Save{tv_days});
if ($Tk_results{'TV search'} or $Tk_results{'TV dates'}) {
    speak "Searching";
    run qq[get_tv_info -times all -dates "$Save{tv_days}" -keys "$Save{tv_search}"];
    set_watch $f_tv_file;
    undef $Tk_results{'TV search'};
    undef $Tk_results{'TV dates'};
}

                                # Speak/show the results for all of the above requests
if ($state = changed $f_tv_file) {
    my $f_tv_info1 = "$Pgm_Root/data/tv_info1.txt";
    my $f_tv_info2 = "$Pgm_Root/data/tv_info2.txt";

    my $summary = file_head($f_tv_info1, 1);
    my ($show_count) = $summary =~ /Found (\d+)/;
    my @data = file_read $f_tv_info1;
    shift @data;            # Drop summary;

    my $msg = "There ";
    $msg .= ($show_count > 1) ? " are " : " is ";
    $msg .= plural($show_count, 'favorite show');
    if ($state eq 'favorites tonight') {
        if ($show_count > 0) {
            speak "$msg on tonight. @data";
        }
        else {
            speak "There are no favorite shows are on tonight";
        }
    }
    elsif ($state eq 'favorites now' and $show_count > 0) {
        speak "Notice, $msg starting now.  @data";
    }
    elsif ($state eq 'favorites speak' and $show_count > 0) {
        speak "@data";
    }
    else {
        chomp $summary;         # Drop the cr
        speak $summary;
    }
    display $f_tv_info2 if $show_count;
}

    

