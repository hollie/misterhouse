# Category=Music

# Build and search an mp3 playlist, reading tag data.
# mp3_control.pl can be used to control an mp3 player
# modified by Richard Phillips to use xmms rather than winamp

# Build the mp3 database
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

( $mp3names, %mp3files ) = &mp3_playlists if 'Load' eq said $v_mp3_build_list;

my %mp3_dbm;
if ( 'Build' eq said $v_mp3_build_list) {
    speak "Ok, rebuilding";
    my @dirs = split ',', $config_parms{mp3_dir};
    print_log "Updating mp3 database for @dirs";
    set $p_mp3_build_list "get_mp3_data -dbm $mp3_file @dirs";
    eval 'untie %mp3_dbm';    # eval in cause db_file is not installed
    start $p_mp3_build_list;
}

if ( done_now $p_mp3_build_list) {
    speak "mp3 database build is done";
    ( $mp3names, %mp3files ) = &mp3_playlists;
}

# Search the mp3 database
#&tk_entry('MP3 Search', \$Save{mp3_search}, 'MP3 Genre', \$Save{mp3_Genre});
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
        run "$config_parms{mp3_program} -e $file";
    }
    else {
        speak "Sorry, no songs found";
    }
}

sub mp3_play {
    my $file = shift;
    print_log "mp3 play: $file";
    run qq[$config_parms{mp3_program} -e "$file"];
}

sub mp3_search {
    my ( $mp3_search, $mp3_genre ) = @_;

    $mp3_search = quotemeta $mp3_search;
    $mp3_genre  = quotemeta $mp3_genre;

    my @titles   = split $;, $mp3_dbm{title};
    my @artists  = split $;, $mp3_dbm{artist};
    my @albums   = split $;, $mp3_dbm{album};
    my @years    = split $;, $mp3_dbm{year};
    my @comments = split $;, $mp3_dbm{comment};
    my @genres   = split $;, $mp3_dbm{genre};
    my @files    = split $;, $mp3_dbm{file};

    my ( $results1, $results2, $count1, $count2 );
    $count1 = $count2 = 0;
    for my $i ( 0 .. @files ) {
        $count1++;
        if (  !$mp3_search
            or $titles[$i] =~ /$mp3_search/i
            or $artists[$i] =~ /$mp3_search/i
            or $albums[$i] =~ /$mp3_search/i
            or $files[$i] =~ /$mp3_search/i )
        {
            next if $mp3_genre and $genres[$i] !~ /$mp3_genre/i;
            $count2++;
            my $file = $files[$i];
            $results2 .= "$file\n";
            $results1 .=
              "Title: $titles[$i]   Album: $albums[$i]  Year: $years[$i]  Genre: $genres[$i]\n";
            $results1 .= "  - Artist: $artists[$i]  Comments:$comments[$i]\n";
            $results1 .= "  - File: $file\n\n";
        }
    }
    return ( $results1, $results2, $count1, $count2 );
}

sub mp3_playlists {
    unless (%mp3_dbm) {
        print_log "Now Tieing to $mp3_file";
        my $tie_code =
          qq[tie %mp3_dbm, 'DB_File', "$mp3_file", O_RDWR|O_CREAT, 0666 or print_log "Error in tieing to $mp3_file"];
        eval $tie_code;
        if ($@) {
            print_log "\n\nError in tieing to $mp3_file:\n  $@";
            $mp3_dbm{empty} = 'empty';
        }

    }

    # Find the playlist files
    my ( $mp3names, %mp3files );
    return '', '', '' unless $mp3_dbm{file};
    for my $file ( split $;, $mp3_dbm{file} ) {
        next unless $file =~ /([^\\\/]+)((\.m3u)|(\.pls))$/i;
        my $name = ucfirst lc $1;
        unless ( $mp3files{$name} ) {
            $mp3names .= $name . ',';
            $mp3files{$name} = $file;
        }
    }
    return 'none_found' unless $mp3names;
    chop $mp3names;    # Drop last ,
    print "mp3 playlists: $mp3names \n";
    return $mp3names, %mp3files;
}

$v_mp3_playlist1 =
  new Voice_Cmd("Set house mp3 player to playlist [$mp3names]");

#set_icon $v_mp3_playlist1 'playlist';

if ( $state = said $v_mp3_playlist1) {

    my $host = 'localhost';
    my $file = $mp3files{$state};
    print_log "xmms playlist changed to: $state file=$file";
    run "$config_parms{mp3_program} $file";
}
