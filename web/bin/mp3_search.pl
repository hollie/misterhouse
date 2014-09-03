
=begin comment

This file is called directly from the browser with: 

  http://localhost:8080/bin/mp3_search.pl?search_string

Set search_string to playlist to get a list of all playlists.

This code requires you run code code/common/mp3.pl, to get
the &mp3_playlists and &mp3_search functions.

=cut

#$^W = 0;                        # Avoid redefined sub msgs

my ($string) = @ARGV;

$string =~ s/search=//;    # Allow for ?string or ?search=string

my ( $html, $i );
my $show_details = 1;

if ( ( $string eq 'playlists' ) or ( $string eq '' ) ) {
    my ( $playlists, %playfiles ) = &mp3_playlists;
    $html = "<h3>No playlists found in mh/web/bin/mp3_search.pl</h3>"
      unless $playlists;
    for my $playlist (
        sort {
            my $c = $a;
            my $d = $b;
            $c =~ s/^the //i;
            $d =~ s/^the //i;
            uc($c) cmp uc($d)
        } keys %playfiles
      )
    {
        my $href = encode_url( '"' . $playfiles{$playlist} . '"' );
        $href = "<a href='/sub?mp3_play($href)' target=invisible>";
        my $icon = $href;
        $icon .=
          "<img src='/graphics/playlist.gif' alt='playlist' border=0></a>";
        $html .= "<td align='right'  width='1%'>$icon</td>";
        $html .=
          "<td align='middle' width='15%' bgColor='#cccccc'>$href<b>$playlist</b></a><br></td>";
        $html .= "</tr><tr>\n" unless ++$i % 3;
    }
}
elsif ( $string eq 'stations' ) {
    my @stations = &mp3_radio_stations;
    $html .=
      "<td align='center' colspan=2 bgColor='#cccccc'><b>Station</b><br></td>";
    $html .= "<td align='center' bgColor='#cccccc'><b>URL</b><br></td>";
    $html .= "<td align='center' bgColor='#cccccc'><b>Bandwidth</b><br></td>";
    $html .= "<td align='center' bgColor='#cccccc'><b>Style</b><br></td>";
    $html .= "</tr><tr>\n";
    $html = "<h3>No stations found in mh/web/bin/mp3_search.pl</h3>"
      unless @stations;
    for my $station (@stations) {
        my ( $station, $url, $bandwidth, $style ) = split $;, $station;
        my $href = "<a href='sub;mp3_radio_play($url)' target=invisible>";
        my $icon = $href;
        $icon .=
          "<img src='/graphics/playlist.gif' alt='playlist' border=0></a>";
        $html .= "<td align='right'  width='1%'>$icon</td>";
        $html .= "<td align='left'   width='10%'>$station</td>";
        $html .= "<td align='middle' width='50%'>$href$url</a></td>";
        $html .= "<td align='middle' width='10%'>$bandwidth</td>";
        $html .= "<td align='middle' width='10%'>$style</td>";
        $html .= "</tr><tr>\n";
    }
    $html .= "<td align=rignt colspan=100>";
    $html .=
      "<a href='RUN;referer?Get_internet_radio_station_list'>Get internet radio station list</a></td></tr>\n";
}
elsif ( $string eq 'artists' ) {
    my %artists = &mp3_find_all('artist');
    $html = "<h3>No artists found in mh/web/bin/mp3_search.pl</h3>"
      unless keys %artists;
    for my $artist (
        sort {
            my $c = $a;
            my $d = $b;
            $c =~ s/^the //i;
            $d =~ s/^the //i;
            uc($c) cmp uc($d)
        } keys %artists
      )
    {
        my $href = encode_url( quotemeta($artist) );
        my $n    = $artists{$artist};
        $artist = 'none' if $artist eq '';
        $href =
          "<a href='/bin/mp3_search.pl?artist=\^$href\$' target=mp3_output>";
        my $icon = $href;
        $icon .=
          "<img src='/graphics/playlist.gif' alt='playlist' border=0></a>";
        $html .= "<td align='right'  width='1%'>$icon</td>";
        $html .=
          "<td align='middle' width='15%' bgColor='#cccccc'>$href<b>$artist ($n)</b></a><br></td>";
        $html .= "</tr><tr>\n" unless ++$i % 3;
    }
}
elsif ( $string eq 'albums' ) {
    my %albums = &mp3_find_all('album');
    $html = "<h3>No albums found in mh/web/bin/mp3_search.pl</h3>"
      unless keys %albums;
    for my $artistalbum (
        sort {
            my $c = $a;
            my $d = $b;
            $c =~ s/^the //i;
            $d =~ s/^the //i;
            uc($c) cmp uc($d)
        } keys %albums
      )
    {
        my ( $artist, $album ) = split $;, $artistalbum;
        next if $album eq '' or $albums{$artistalbum} < 3;
        my $href = encode_url( quotemeta($album) );
        my $n    = $albums{$artistalbum};
        $href =
          "<a href='/bin/mp3_search.pl?album=\^$href\$' target=mp3_output>";
        my $icon = $href;
        $icon .=
          "<img src='/graphics/playlist.gif' alt='playlist' border=0></a>";
        $html .= "<td align='right'  width='1%'>$icon</td>";
        $html .=
          "<td align='middle' width='15%' bgColor='#cccccc'>$href<b>$artist - $album ($n)</b></a><br></td>";
        $html .= "</tr><tr>\n" unless ++$i % 3;
    }
}
elsif ( $string eq 'years' ) {
    my %years = &mp3_find_all('year');
    $html = "<h3>No years found in mh/web/bin/mp3_search.pl</h3>"
      unless keys %years;
    for my $year ( sort { uc $a cmp uc $b } keys %years ) {
        my $href = encode_url( quotemeta($year) );
        my $n    = $years{$year};
        $year = 'none' if $year eq '';
        $href =
          "<a href='/bin/mp3_search.pl?year=\^$href\$' target=mp3_output>";
        my $icon = $href;
        $icon .=
          "<img src='/graphics/playlist.gif' alt='playlist' border=0></a>";
        $html .= "<td align='right'  width='1%'>$icon</td>";
        $html .=
          "<td align='middle' width='15%' bgColor='#cccccc'>$href<b>$year ($n)</b></a><br></td>";
        $html .= "</tr><tr>\n" unless ++$i % 3;
    }
}
elsif ( $string eq 'genres' ) {
    my %genres = &mp3_find_all('genre');
    $html = "<h3>No genres found in mh/web/bin/mp3_search.pl</h3>"
      unless keys %genres;
    for my $genre ( sort { uc $a cmp uc $b } keys %genres ) {
        my $href = encode_url( quotemeta($genre) );
        my $n    = $genres{$genre};
        $genre = 'none' if $genre eq '';
        $href =
          "<a href='/bin/mp3_search.pl?genre=\^$href\$' target=mp3_output>";
        my $icon = $href;
        $icon .=
          "<img src='/graphics/playlist.gif' alt='playlist' border=0></a>";
        $html .= "<td align='right'  width='1%'>$icon</td>";
        $html .=
          "<td align='middle' width='15%' bgColor='#cccccc'>$href<b>$genre ($n)</b></a><br></td>";
        $html .= "</tr><tr>\n" unless ++$i % 3;
    }
}
else {
    my $genre = $1 if $string =~ /genre=(.+)/;
    $string =~ s/genre=.+//;
    my $artist = $1 if $string =~ /artist=(.+)/;
    $string =~ s/artist=.+//;
    my $album = $1 if $string =~ /album=(.+)/;
    $string =~ s/album=.+//;
    my $year = $1 if $string =~ /year=(.+)/;
    $string =~ s/year=.+//;
    my ( $results1, $results2, $count1, $count2 ) =
      &mp3_search( $string, $genre, $artist, $album, $year );

    #   print "db r=$results1\n";
    if ($count2) {

        #        $html .= "<td colspan=5><a href='/sub?mp3_play($config_parms{data_dir}/mp3_search_results.m3u)' target=invisible><b>Play All</b></a></td></tr><tr>\n";
        $html .=
          "<a href='/sub?mp3_play($config_parms{data_dir}/mp3_search_results.m3u)' target=invisible><b>Play All</b></a>\n";
        $html .=
          " <a href='/sub?mp3_queue($config_parms{data_dir}/mp3_search_results.m3u)' target=invisible><b>Add All</b></a><p>\n";
        if ($show_details) {
            $html .=
              "<td align='center' width='15%' bgColor='#cccccc'><b>Title</b><br></td>";
            $html .=
              "<td align='center' width='15%' bgColor='#cccccc'><b>Artist</b><br></td>";
            $html .=
              "<td align='center' width='15%' bgColor='#cccccc'><b>Album</b><br></td>";
            $html .=
              "<td align='center' width='5%' bgColor='#cccccc'><b>Year</b><br></td>";
            $html .=
              "<td align='center' width='10%' bgColor='#cccccc'><b>Genre</b><br></td>";
            $html .= "</tr><tr>\n";
        }
    }
    else {
        $html .= "No matches.<p>";
    }

    while ( $results1 =~
        /Title: (.+?) *Album: (.+?) *Year: (.+?) *Genre: *(.+?) *- Artist: (.+?) *Comments: *(.+?) *- File: (.+?)$/smg
      )
    {
        my ( $title, $album, $year, $genre, $artist, $comments, $file ) =
          ( $1, $2, $3, $4, $5, $6, $7 );

        #       print "db t=$title a=$album y=$year g=$genre art=$artist c=$comments f=$file \n";
        last unless $title;
        chomp $genre;
        $title = $1 if $title =~ /^ *$/ and $file =~ /([^\\\/]+)$/;
        my ( $href, $arg );
        if ($show_details) {
            $href = encode_url( '"' . $file . '"' );
            $href =~
              s/\\/\//g;    # Forward slashes work ok in windows, and are easier
            $html .=
              "<td align='left' width='15%' bgColor='#cccccc'>[<a href='/SUB?mp3_queue($href)' target=invisible>add</a>]";
            $html .=
              " <a href='/SUB?mp3_play($href)' target=invisible><b>$title</b></a><br></td>";
            $href = encode_url( quotemeta($artist) );
            $html .=
              "<td align='left' width='15%' bgColor='#cccccc'><a href='/bin/mp3_search.pl?artist=\^$href\$' target=mp3_output><b>$artist</b></a><br></td>";
            $href = encode_url( quotemeta($album) );
            $html .=
              "<td align='left' width='15%' bgColor='#cccccc'><a href='/bin/mp3_search.pl?album=\^$href\$' target=mp3_output><b>$album</b></a><br></td>";
            $href = encode_url( quotemeta($year) );
            $html .=
              "<td align='left' width='5%' bgColor='#cccccc'><a href='/bin/mp3_search.pl?year=\^$href\$' target=mp3_output><b>$year</b></a><br></td>";
            $href = encode_url( quotemeta($genre) );
            $html .=
              "<td align='left' width='5%' bgColor='#cccccc'><a href='/bin/mp3_search.pl?genre=\^$href\$' target=mp3_output><b>$genre</b></a><br></td>";
            $html .= "</tr><tr>\n";
        }
        else {
            $html .=
              "<td align='left' width='15%' bgColor='#cccccc'>$href<b>$title</b></a><br></td>";
            $html .= "</tr><tr>\n" unless ++$i % 3;
        }
    }
}

$html = "
<html><body>
<base target ='mp3_output'>
<table width='100%' border='0'>
<center>
 <table cellSpacing=0 cellPadding=0 width='100%' border=1>  
$html
</table>
</center>
</table>
</body>
</html>";

return &html_page( '', $html );

sub encode_url {
    my $string = shift;

    $string =~ s/\%/%25/g;    # Encode percent
    $string =~ s/\&/%26/g;    # Encode percent
    $string =~ s/ /%20/g;     # Encode blanks
    $string =~ s/\'/%27/g;    # Encode quote
    $string =~ s/\+/%2B/g;    # Encode plus

    return $string;
}
