# Category=Music
 
# Build and search an mp3 playlist, reading tag data.
# mp3_control.pl can be used to control an mp3 player

                                # Build the mp3 database
$v_mp3_build_list = new Voice_Cmd '[Build,Load] the {mp3,m p 3} database', '';
$v_mp3_build_list-> set_info("Builds/loads an mp3 database for these directories: $config_parms{mp3_dir}");

$p_mp3_build_list = new Process_Item;

my %mp3_dbm;
if ('Build' eq said $v_mp3_build_list) {
    speak "Ok, rebuilding";
    my @dirs = split ',', $config_parms{mp3_dir};
    print_log "Updating mp3 database for @dirs";
    set   $p_mp3_build_list "get_mp3_data -dbm $mp3_file @dirs";
    eval 'untie %mp3_dbm';       # eval in cause db_file is not installed
    start $p_mp3_build_list;
}

speak "mp3 database build is done" if done_now $p_mp3_build_list;

                                # Search the mp3 database
#&tk_entry('MP3 Search', \$Save{mp3_search}, 'MP3 Genre', \$Save{mp3_Genre});
if ($Tk_results{'MP3 Search'} or $Tk_results{'MP3 Genre'}){
    undef $Tk_results{'MP3 Search'};
    undef $Tk_results{'MP3 Genre'};
    my $mp3_search = quotemeta $Save{mp3_search};
    my $mp3_genre  = quotemeta $Save{mp3_Genre};

    my @titles   = split $;, $mp3_dbm{title};
    my @artists  = split $;, $mp3_dbm{artist};
    my @albums   = split $;, $mp3_dbm{album};
    my @years    = split $;, $mp3_dbm{year};
    my @comments = split $;, $mp3_dbm{comment};
    my @genres   = split $;, $mp3_dbm{genre};
    my @files    = split $;, $mp3_dbm{file};

    my ($results1, $results2, $count1, $count2);
    $count1 = $count2 = 0;
    for my $i (0 .. @titles) {
        $count1++;
        if ($titles[$i]  =~ /$mp3_search/i or
            $artists[$i] =~ /$mp3_search/i or
            $albums[$i]  =~ /$mp3_search/i or
            $files[$i]   =~ /$mp3_search/i) {
            next if $mp3_genre and $genres[$i] !~ /$mp3_genre/i;
            $count2++;
            my $file = $files[$i];
            $results2 .= "$file\n";
            $results1 .= "Title: $titles[$i]   Album: $albums[$i]  $years[$i]  $genres[$i]\n";
            $results1 .= "  - Artist: $artists[$i]  Comments:$comments[$i]\n";
            $results1 .= "  - $file\n\n";
        }
    }
    if ($results1) {
        speak "Found $count2 songs";
        display "Found $count2 songs\n" . $results1, 10, 'MP3 Search Results', 'fixed';
        my $file = "$config_parms{data_dir}/search.m3u";
        file_write $file, $results2;
        run "$config_parms{mp3_program} $file";
    }
    else {
        speak "Sorry, no soungs found";
        print_log "$count2 out of $count1 soungs $mp3_search, genre=$mp3_genre";
    }
}

                                # Allow for loading playlists

# noloop=start      This directive allows this code to be run on startup/reload
my $mp3_file = "$config_parms{data_dir}/mp3.dbm";
my ($mp3names, %mp3files) = &load_playlist;

sub load_playlist {
    unless (%mp3_dbm) {
        print_log "Now Tieing to $mp3_file";
        my $tie_code = qq[tie %mp3_dbm, 'DB_File', "$mp3_file", O_RDWR|O_CREAT, 0666 or print_log "Error in tieing to $mp3_file"];
        eval $tie_code;
        if ($@) {
            print_log "\n\nError in tieing to $mp3_file:\n  $@";
            $mp3_dbm{empty} = 'empty';
        }

    }
                                # Find the playlist files
    my ($mp3names, %mp3files);
    return '', '', '' unless $mp3_dbm{file};
    for my $file (split $;, $mp3_dbm{file}) {
        next unless $file =~ /([^\\\/]+)((\.m3u)|(\.pls))$/i;
        my $name = ucfirst lc $1;
        unless ($mp3files{$name}) {
            $mp3names .= $name . ','; 
            $mp3files{$name} = $file;
        }
    }
    chop $mp3names;         # Drop last ,
    print "mp3 playlists: $mp3names \n";
    return $mp3names, %mp3files;
}

# noloop=stop

($mp3names, %mp3files) = &load_playlist if 'Load' eq said $v_mp3_build_list;

$v_mp3_playlist1 = new Voice_Cmd("Set house mp3 player to playlist [$mp3names]");
$v_mp3_playlist2 = new Voice_Cmd("Set Nicks mp3 player to playlist [$mp3names]");
$v_mp3_playlist3 = new Voice_Cmd("Set Zacks mp3 player to playlist [$mp3names]");
$v_mp3_playlist4 = new Voice_Cmd("Set the shoutcast mp3 player to playlist [$mp3names]");
$v_mp3_playlist5 = new Voice_Cmd("Set the phone mp3 player to playlist [$mp3names]");
#set_icon $v_mp3_playlist1 'playlist';

if ($state = said $v_mp3_playlist1 or
    $state = said $v_mp3_playlist2 or
    $state = said $v_mp3_playlist3 or
    $state = said $v_mp3_playlist4 or
    $state = said $v_mp3_playlist5) {

    my $host = 'localhost';
    $host = 'dm'  if said $v_mp3_playlist2;
    $host = 'z'   if said $v_mp3_playlist3;
    $host = 'c2'  if said $v_mp3_playlist4;
    $host = 'p90' if said $v_mp3_playlist5;

                                # Start winamp, if it is not already running (windows localhost only)
    &sendkeys_find_window('winamp', $config_parms{mp3_program}) if $OS_win and $host eq 'localhost';

    my $file = $mp3files{$state};
    if ($config_parms{mp3_program_control} eq 'httpq') {
        print_log "Winamp (httpq) playlist: $state file=$file";
        print_log filter_cr get "http://$host:4800/DELETE?p=$config_parms{mp3_program_password}";
        print_log filter_cr get "http://$host:4800/PLAYFILE?p=$config_parms{mp3_program_password}&a=$file";
        print_log filter_cr get "http://$host:4800/PLAY?p=$config_parms{mp3_program_password}";
    }
    else {
        print_log "Winamp {wcatl) playlist: $state file=$file";
        run "$config_parms{mp3_program} $file";
    }
}



#set_order $v_mp3_build_list  1;
#set_order $v_mp3_playlist1   1;
#set_order $v_mp3_playlist2   2;
#set_order $v_mp3_playlist3   2;
#set_order $v_mp3_playlist4   2;
#set_order $v_mp3_playlist5   2;
