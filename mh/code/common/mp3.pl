# Category=Music

#@ This is the core mp3 script.  It is used by the <a href='/misc/mp3.html'>MP3 Jukebox web interface</a>
#@ to manage songs and playlists.  Also enable either mp3_winamp.pl or mp3_xmms.pl to control your mp3 player.
#@ Set mp3_dir to a comma separated list of directories where you keep mp3 or playlist (m3u, pls) files.
                                # Build the mp3 database
$v_mp3_build_list = new Voice_Cmd '[Build,Load] the {mp3,m p 3} database', '';
$v_mp3_build_list-> set_info("Builds/loads an mp3 database for these directories: $config_parms{mp3_dir}");

$p_mp3_build_list = new Process_Item;

                                # Allow for loading playlists

# noloop=start      This directive allows this code to be run on startup/reload
my $mp3_file = "$config_parms{data_dir}/mp3.dbm";
my ($mp3names, %mp3files) = &mp3_playlists;
# noloop=stop

($mp3names, %mp3files) = &mp3_playlists if 'Load' eq said $v_mp3_build_list;


my %mp3_dbm;
if ('Build' eq said $v_mp3_build_list) {
    speak "Ok, rebuilding";
    my @dirs = split ',', $config_parms{mp3_dir};
    print_log "Updating mp3 database for @dirs";
    set   $p_mp3_build_list "get_mp3_data -dbm $mp3_file @dirs";
    eval 'untie %mp3_dbm';       # eval in cause db_file is not installed
    start $p_mp3_build_list;
}

if (done_now $p_mp3_build_list) {
    speak "mp3 database build is done";
    print_log "Finished updating mp3 database";
    ($mp3names, %mp3files) = &mp3_playlists;
}

                                # Search the mp3 database
#&tk_entry('MP3 Search', \$Save{mp3_search}, 'MP3 Genre', \$Save{mp3_Genre});
if ($Tk_results{'MP3 Search'} or $Tk_results{'MP3 Genre'}){
    undef $Tk_results{'MP3 Search'};
    undef $Tk_results{'MP3 Genre'};
    my ($results1, $results2, $count1, $count2) = &mp3_search(quotemeta $Save{mp3_search}, quotemeta $Save{mp3_Genre});
    print_log "$count2 out of $count1 songs for search=$Save{mp3_search}, genre=$Save{mp3_Genre}";
    if ($results1) {
        speak "Found $count2 songs";
        display "Found $count2 (out of $count1) songs\n" . $results1, 30, 'MP3 Search Results', 'fixed';
        my $file = "$config_parms{data_dir}/search.m3u";
        file_write $file, $results2;
        &mp3_queue($file);
    }
    else {
        speak "Sorry, no songs found";
    }
}

sub mp3_search {
    my ($mp3_search, $mp3_genre, $mp3_artist, $mp3_album, $mp3_year) = @_;

    $mp3_search = quotemeta $mp3_search;

    my @titles   = split $;, $mp3_dbm{title};
    my @artists  = split $;, $mp3_dbm{artist};
    my @albums   = split $;, $mp3_dbm{album};
    my @years    = split $;, $mp3_dbm{year};
    my @comments = split $;, $mp3_dbm{comment};
    my @genres   = split $;, $mp3_dbm{genre};
    my @files    = split $;, $mp3_dbm{file};

    my (@results, $results1, $results2, $count1, $count2);
    $count1 = $count2 = 0;
    for my $i (0 .. @files) {
        $count1++;
        next unless $files[$i] =~ /\.mp3$/i;
        if (!$mp3_search or
            $titles[$i]  =~ /$mp3_search/i or
            $artists[$i] =~ /$mp3_search/i or
            $albums[$i]  =~ /$mp3_search/i or
            $files[$i]   =~ /$mp3_search/i) {
            next if $mp3_genre  and $genres[$i]  !~ /$mp3_genre/i;
            next if $mp3_artist and $artists[$i] !~ /$mp3_artist/i;
            next if $mp3_album  and $albums[$i]  !~ /$mp3_album/i;
            next if $mp3_year   and $years[$i]   !~ /$mp3_year/i;
            $count2++;
            push @results, $i;
        }
    }
    @results = sort {uc($artists[$a]) cmp uc($artists[$b])} @results;
    foreach my $i (@results) {
            my $file = $files[$i];
            $results2 .= "$file\n";
            $results1 .= "Title: $titles[$i]   Album: $albums[$i]  Year: $years[$i]  Genre: $genres[$i]\n";
            $results1 .= "  - Artist: $artists[$i]  Comments:$comments[$i]\n";
            $results1 .= "  - File: $file\n\n";
    }
    file_write "$config_parms{data_dir}/mp3_search_results.m3u", $results2;
    return ($results1, $results2, $count1, $count2);
}


sub mp3_playlists {
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
#       my $name = ucfirst lc $1;
        my $name = $1;
        unless ($mp3files{$name}) {
            $mp3names .= $name . ',';
            $mp3files{$name} = $file;
        }
    }
    return 'none_found' unless $mp3names;
    chop $mp3names;         # Drop last ,
#   print "mp3 playlists: $mp3names \n";
    return $mp3names, %mp3files;
}

$v_mp3_playlist1 = new Voice_Cmd("Set house mp3 player to playlist [$mp3names]");
#set_icon $v_mp3_playlist1 'playlist';

if ($state = said $v_mp3_playlist1) {
    my $host = 'localhost';
    my $file = $mp3files{$state};
    print_log "MP3 playlist changed to: $state file=$file";
    &mp3_play($file);
}

$v_play_clear_music = new Voice_Cmd("Clear mp3 playlist");
if ($state = said $v_play_clear_music) {
    &mp3_clear();
}

# The following returns the current song being played
$v_what_playing = new Voice_Cmd('What is now playing');
if ($state = said $v_what_playing) {
#   my $mp3playing = ${&mp3_get_playlist()}[&mp3_get_playlist_pos()];
    my $mp3playing = '';
    my $pos = &mp3_get_playlist_pos();
    if ($pos >= 0) {
	$mp3playing = ${&mp3_get_playlist()}[$pos];
    } else {
	$mp3playing = &mp3_get_curr_song();
    }
    speak $mp3playing;
}


	# This can be slow if player is down, so don't do it too often
#if (new_second 15) {
#   my $ref = &mp3_get_playlist();
##  $Save{NowPlaying} = ${$ref}[&mp3_get_playlist_pos()] if $ref;
#   my $pos = &mp3_get_playlist_pos();
#   if ($pos >= 0) {
#      $Save{NowPlaying} = ${$ref}[$pos] if $ref;
#   } else {
#      $Save{NowPlaying} = &mp3_get_curr_song();
#   }
#}

sub mp3_find_all {
    my ($mp3_tag) = @_;

    my @artists;
    @artists   = split $;, $mp3_dbm{artist} if $mp3_tag eq 'album';
    my @files  = split $;, $mp3_dbm{file};

    my $count = -1;
    my %all;
    foreach my $tag (split $;, $mp3_dbm{$mp3_tag}) {
        $count++;
        next unless $files[$count] =~ /\.mp3$/i;
        if ($mp3_tag eq 'album') {
            $tag = "$artists[$count]$;$tag";
        }
        $all{$tag}++;
    }
    return %all;
}

sub mp3_play_search_results {
    my $enqueue = shift;
    my $file = "$config_parms{data_dir}/mp3_search_results.m3u";

    if ($enqueue) {
        mp3_queue $file;
    }
    else {
        mp3_play $file;
    }
}


# Internet radio code

my $f_radio_stations = "$config_parms{data_dir}/web/radio_stations.html";
$v_get_radio_stations = new Voice_Cmd 'Get internet radio station list';

$p_get_radio_stations = new Process_Item
    "get_url http://mindx.dyndns.org/kde/radio/live/entries.php $f_radio_stations";

if (my $state = said $v_get_radio_stations) {
    unlink $f_radio_stations;
    $p_get_radio_stations -> start;
    &respond_wait;  # Tell web browser to wait for respond
}

if (done_now $p_get_radio_stations) {
    print_log "Internet radio stations retreived";
    respond "Internet radio stations retreived\n";
}

sub mp3_radio_stations {
    my ($station, $url, $bandwidth, $style, @data);
    for my $html (file_read $f_radio_stations, '') {
        if ($html =~ /^<tr.*<td>(.*)<\/td><td><a href="(.*)">.*<\/a><\/td>$/) {
            $station = $1;
            $url = $2;
        }
        elsif (($bandwidth, $style) = $html =~ /^<td>(.*)<\/td><td>(.*)<\/td><\/tr>$/) {
            push @data, "$station$;$url$;$bandwidth$;$style";
        }
    }
    return @data;
}

my $f_radio_playlist = "$config_parms{data_dir}/web/radio_playlist.pls";
$p_get_radio_playlist = new Process_Item;

if (done_now $p_get_radio_playlist) {
    mp3_play($f_radio_playlist);
}

sub mp3_radio_play {
    my $url = shift;
    $p_get_radio_playlist -> set("get_url $url $f_radio_playlist");
    $p_get_radio_playlist -> start;
}

#run_voice_cmd 'Get internet radio station list' if $Reload;
