
=begin comment

This file is called directly from the browser with: 

  http://localhost:8080/bin/mp3_search.pl?search_string

Set search_string to playlist to get a list of all playlists.

This code requires you run code mp3_playlist.pl, to get
the &mp3_playlists and &mp3_search functions.

=cut

#$^W = 0;                        # Avoid redefined sub msgs

my ($string) = @ARGV;

$string =~ s/search=//;         # Allow for ?string or ?search=string

my ($html, $i);

if ($string eq 'playlists') {
    my $playlists = $Save{mp3_playlists};
    ($playlists) = &mp3_playlists         unless $playlists;
    $html = '<h3>No Playlists found</h3>' unless $playlists;
    for my $playlist (split ',', $playlists) {
        my $href = $playlist;
        $href =~ tr/_/~/;   # http_server translates _ to blank, and ~ to _
        $href =~ s/ /_/g;
        $href  = "<a href='/RUN?Set_house_mp3_player_to_playlist_$href' target=invisible>";
        my $icon  = $href;
        $icon .= "<img src='/graphics/playlist.gif' alt='playlist' border=0></a>"; 
        $html .= "<td align='right'  width='15%'>$icon</td>";
        $html .= "<td align='middle' width='15%' bgColor='#cccccc'>$href<b>$playlist</b></a><br></td>";
        $html .= "</tr><tr>\n" unless ++$i % 3;
    }
}
else {
    my $genre = $1 if $string =~ /genre=(.+)/;
    $string =~ s/genre=.+//;

    my ($results1, $results2, $count1, $count2) = &mp3_search($string, $genre);
    while ($results1 =~ /Title: (.+?) +Album:.+? +Genre: (.+?) +Artist: (.+?) Comments:.+? File: (.+?)$/smg) {
        last unless $1;
        my $title = $1;
        my $file  = $4;
#       print "db t=$title f=$file r=$results1\n";
        $title = $1 if $title =~ /^ *$/ and $file =~ /([^\\\/]+)$/;
        $file =~ s/ /%20/g;     # Encode blanks
        $file =~ s/\'/%27/g;     # Encode other
        $file =~ s/\\/\//g;     # Forward slashes work ok in windows, and are easier
        my $href  = qq[<a href='/SUB?mp3_play("$file")' target=invisible>];
        $html .= "<td align='left' width='15%' bgColor='#cccccc'>$href<b>$title</b></a><br></td>";
        $html .= "</tr><tr>\n" unless ++$i % 3;
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

return &html_page('', $html);

