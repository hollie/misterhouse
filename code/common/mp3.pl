# Category=Music

# $Date$
# $Revision$

#@ This is the core mp3 script.  It is used by the <a href='/misc/mp3.html'>MP3 Jukebox web interface</a>
#@ to manage songs and playlists.  Also enable either mp3_winamp.pl, mp3_slimserver, mp3_alsaplayer or mp3_xmms.pl to control your mp3 player.
#@ Set mp3_dir to a comma separated list of directories where you keep mp3 or playlist (m3u, pls) files.

# Build the mp3 database

# *** A good argument to rename this section to music (MP3 is hardly appropriate at this time.)
$v_mp3_build_list = new Voice_Cmd '[Build,Load] the {mp3,m p 3} database', '';
$v_mp3_build_list->set_info(
    "Builds/loads an mp3 database for these directories: $config_parms{mp3_dir}"
);

$p_mp3_build_list = new Process_Item;

# Allow for loading playlists

# noloop=start      This directive allows this code to be run on startup/reload
my $mp3_file = "$config_parms{data_dir}/mp3.dbm";
my ( $mp3names, %mp3files ) = &mp3_playlists;

# noloop=stop

if ( $MW and $Reload ) {
    &tk_label_new( 4, \$Save{NowPlaying} );

    if ( $Tk_objects{fb4} ) {
        $Tk_objects{mp3_progress} = $Tk_objects{fb4}->ProgressBar(
            -from   => 0,
            -to     => 100,
            -value  => 0,
            -width  => 20,
            -blocks => 100
        )->pack(qw/-side left -padx 2/);
        &configure_element( 'progress', \$Tk_objects{mp3_progress} );
    }

}

( $mp3names, %mp3files ) = &mp3_playlists if 'Load' eq said $v_mp3_build_list;

my %mp3_dbm;
if ( 'Build' eq said $v_mp3_build_list) {
    my @dirs = split ',', $config_parms{mp3_dir};
    print_log "Updating mp3 database for @dirs";
    set $p_mp3_build_list "get_mp3_data -dbm $mp3_file @dirs";
    untie %mp3_dbm;
    start $p_mp3_build_list;
}

if ( done_now $p_mp3_build_list) {
    print_log "mp3 database build is done";
    ( $mp3names, %mp3files ) = &mp3_playlists;
}

# Search the mp3 database
&tk_entry( 'MP3 Search', \$Save{mp3_search} );
&tk_entry( 'MP3 Genre',  \$Save{mp3_Genre} );

if ( $Tk_results{'MP3 Search'} or $Tk_results{'MP3 Genre'} ) {
    undef $Tk_results{'MP3 Search'};
    undef $Tk_results{'MP3 Genre'};
    my ( $results1, $results2, $count1, $count2 ) =
      &mp3_search( quotemeta $Save{mp3_search}, quotemeta $Save{mp3_Genre} );
    print_log
      "$count2 out of $count1 songs for search=$Save{mp3_search}, genre=$Save{mp3_Genre}";
    if ($results1) {
        speak "Found $count2 songs";
        display "Found $count2 (out of $count1) songs\n" . $results1, 30,
          'MP3 Search Results', 'fixed';
        my $file = "$config_parms{data_dir}/search.m3u";
        file_write $file, $results2;
        &mp3_queue($file);
    }
    else {
        speak "Sorry, no songs found";
    }
}

sub mp3_search {
    my ( $mp3_search, $mp3_genre, $mp3_artist, $mp3_album, $mp3_year ) = @_;

    $mp3_search = quotemeta $mp3_search;

    my @titles   = split $;, $mp3_dbm{title};
    my @artists  = split $;, $mp3_dbm{artist};
    my @albums   = split $;, $mp3_dbm{album};
    my @years    = split $;, $mp3_dbm{year};
    my @comments = split $;, $mp3_dbm{comment};
    my @genres   = split $;, $mp3_dbm{genre};
    my @files    = split $;, $mp3_dbm{file};

    my ( @results, $results1, $results2, $count1, $count2 );
    $count1 = $count2 = 0;
    for my $i ( 0 .. @files ) {
        $count1++;
        next unless $files[$i] =~ /\.(mp3|ogg|wma)$/i;
        if (  !$mp3_search
            or $titles[$i] =~ /$mp3_search/i
            or $artists[$i] =~ /$mp3_search/i
            or $albums[$i] =~ /$mp3_search/i
            or $files[$i] =~ /$mp3_search/i )
        {
            next if $mp3_genre  and $genres[$i] !~ /$mp3_genre/i;
            next if $mp3_artist and $artists[$i] !~ /$mp3_artist/i;
            next if $mp3_album  and $albums[$i] !~ /$mp3_album/i;
            next if $mp3_year   and $years[$i] !~ /$mp3_year/i;
            $count2++;
            push @results, $i;
        }
    }
    @results = sort {
        my $c = $artists[$a];
        my $d = $artists[$b];
        $c =~ s/^the //i;
        $d =~ s/^the //i;
        uc($c) cmp uc($d)
    } @results;
    foreach my $i (@results) {
        my $file = $files[$i];
        $results2 .= "$file\n";
        $results1 .=
          "Title: $titles[$i]   Album: $albums[$i]  Year: $years[$i]  Genre: $genres[$i]\n";
        $results1 .= "  - Artist: $artists[$i]  Comments:$comments[$i]\n";
        $results1 .= "  - File: $file\n\n";
    }
    file_write "$config_parms{data_dir}/mp3_search_results.m3u", $results2;
    return ( $results1, $results2, $count1, $count2 );
}

sub mp3_playlists {

    # Re-tie to the database, in case it has changed.
    eval 'untie %mp3_dbm';    # eval in cause db_file is not installed
    print_log "Tieing to music database: $mp3_file" if $Startup;
    my $tie_code =
      qq[tie %mp3_dbm, 'DB_File', "$mp3_file", O_RDWR|O_CREAT, 0666 or print_log "Error in tieing to $mp3_file"];
    eval $tie_code;
    if ($@) {
        warn "Error in tieing to $mp3_file:\n  $@";
        $mp3_dbm{empty} = 'empty';
    }

    # Find the playlist files
    my ( $mp3names, %mp3files );
    return '', '', '' unless $mp3_dbm{file};
    for my $file ( split $;, $mp3_dbm{file} ) {
        next unless $file =~ /([^\\\/]+)((\.m3u)|(\.pls))$/i;

        #       my $name = ucfirst lc $1;
        my $name = $1;
        unless ( $mp3files{$name} ) {

            # mp3names is only used for voice cmd, so exclude illegal characters
            $mp3names .= $name . ',' unless $name =~ /[\[\]\,\|]/;
            $mp3files{$name} = $file;
        }
    }
    return 'none_found' unless $mp3names;    # ???
    chop $mp3names;                          # Drop last ,
    print_log "Music playlists: "
      . (
        ( length $mp3names < 500 )
        ? $mp3names
        : ( substr $mp3names, 0, 500 ) . '...'
      ) if $Startup;
    return $mp3names, %mp3files;
}

$v_mp3_playlist1 =
  new Voice_Cmd("Set house mp3 player to playlist [$mp3names]");

#set_icon $v_mp3_playlist1 'playlist'; # ???

if ( $state = said $v_mp3_playlist1) {
    my $host = 'localhost';
    my $file = $mp3files{$state};
    print_log "Music playlist changed to: $state file=$file";
    $Save{NowPlayingPlaylist} = $state;
    &mp3_play($file);
}

$v_play_clear_music = new Voice_Cmd("Clear mp3 playlist");
if ( said $v_play_clear_music) {
    &mp3_clear();
}

# The following returns the current song being played
$v_what_playing = new Voice_Cmd( '[What track is,Show track] playing now', 0 );
if ( said $v_what_playing) {

    #   my $mp3playing = ${&mp3_get_playlist()}[&mp3_get_playlist_pos()];
    my $mp3playing = '';
    my $pos        = &mp3_get_playlist_pos();
    if ( $pos >= 0 ) {
        $mp3playing = ${ &mp3_get_playlist() }[$pos];
    }
    else {
        $mp3playing = &mp3_get_curr_song()
          ;    # Where is this function?  Does not appear to exist anywhere (!)
    }
    respond $mp3playing;
}

# *** Add config for monitoring freq (move to mp3_winamp?)

my $old_percent;
my $elapsed_seconds;
my $total_seconds;

# *** Once per second check saved mode and if playing, bump cached elapsed time and update pb if needed

sub set_tk_progress {
    my $percent = shift;
    $Tk_objects{mp3_progress}->configure( -value => $percent );
}

if ( !$config_parms{mp3_no_tkupdates} and new_second and &mp3_player_running() )
{

    if ( new_second 5 ) {
        $Save{mp3_mode} = &mp3_playing();
        my $ref = &mp3_get_playlist();

        #  $Save{NowPlaying} = ${$ref}[&mp3_get_playlist_pos()] if $ref;
        if ($ref) {
            my $pos = &mp3_get_playlist_pos();
            if ( $pos >= 0 ) {
                $Save{NowPlaying} = ${$ref}[$pos] if $ref;
            }
            else {
                $Save{NowPlaying} = &mp3_get_curr_song();
            }
        }

        # *** Set progress to 0 if stopped

        # check ONLY if playing and tk window exists

        if ( $MW and $Save{mp3_mode} == 1 ) {
            my $mptimestr = &mp3_get_output_timestr();

            if ( $mptimestr =~ /\// and $mptimestr =~ /:/ ) {
                my ( $mpelapse, $mprest ) = split( /\//, $mptimestr );
                my ( $mpmin,    $mpsec )  = split( /:/,  $mpelapse );
                $mpelapse = ( $mpmin * 60 ) + $mpsec;
                ( $mpmin, $mpsec ) = split( /:/, $mprest );
                $mprest = ( $mpmin * 60 ) + $mpsec;
                my $percent = 0;
                $percent = int( ( $mpelapse * 100 ) / $mprest ) if $mprest;
                if ( defined $old_percent and $percent != $old_percent ) {
                    &set_tk_progress($percent) if ref $Tk_objects{mp3_progress};
                }
                $old_percent     = $percent;
                $elapsed_seconds = $mpelapse;
                $total_seconds   = $mprest;

            }
        }
    }    # new second 5
    else {
        if ( $MW and $Save{mp3_mode} == 1 ) {
            my $new_percent = 0;
            $elapsed_seconds++;

            # *** Save and tack on difference of timestamp and now (instead of adding a second each time.)

            $new_percent = int( ( $elapsed_seconds * 100 ) / $total_seconds )
              if $total_seconds;
            if ( defined $old_percent and $new_percent != $old_percent ) {
                &set_tk_progress($new_percent) if ref $Tk_objects{mp3_progress};
            }
            $old_percent = $new_percent;
        }
    }

}    # new second and mp3 player is running

sub mp3_find_all {
    my ($mp3_tag) = @_;

    my @artists;
    @artists = split $;, $mp3_dbm{artist} if $mp3_tag eq 'album';
    my @files = split $;, $mp3_dbm{file};

    my $count = -1;
    my %all;
    foreach my $tag ( split $;, $mp3_dbm{$mp3_tag} ) {
        $count++;
        next unless $files[$count] =~ /\.(mp3|ogg|wma)$/i;
        if ( $mp3_tag eq 'album' ) {
            $tag = "$artists[$count]$;$tag";
        }
        $all{$tag}++;
    }
    return %all;
}

sub mp3_play_search_results {
    my $enqueue = shift;
    my $file    = "$config_parms{data_dir}/mp3_search_results.m3u";

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

if ( my $state = said $v_get_radio_stations) {
    unlink $f_radio_stations;
    $p_get_radio_stations->start;
    &respond_wait;    # Tell web browser to wait for respond
}

if ( done_now $p_get_radio_stations) {
    print_log "Internet radio stations retreived";
    respond "Internet radio stations retreived\n";
}

sub mp3_radio_stations {
    my ( $station, $url, $bandwidth, $style, @data );
    for my $html ( file_read $f_radio_stations, '' ) {
        if ( $html =~ /^<tr.*<td>(.*)<\/td><td><a href="(.*)">.*<\/a><\/td>$/ )
        {
            $station = $1;
            $url     = $2;
        }
        elsif ( ( $bandwidth, $style ) =
            $html =~ /^<td>(.*)<\/td><td>(.*)<\/td><\/tr>$/ )
        {
            push @data, "$station$;$url$;$bandwidth$;$style";
        }
    }
    return @data;
}

my $f_radio_playlist = "$config_parms{data_dir}/web/radio_playlist.pls";
$p_get_radio_playlist = new Process_Item;

if ( done_now $p_get_radio_playlist) {
    mp3_play($f_radio_playlist);
}

sub mp3_radio_play {
    my $url = shift;
    $p_get_radio_playlist->set("get_url $url $f_radio_playlist");
    $p_get_radio_playlist->start;
}

#run_voice_cmd 'Get internet radio station list' if $Reload;
