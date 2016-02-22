
=begin comment

This file is called directly from the browser with:

  http://localhost:8080/bin/photo_search.pl?search_string

More info on creating the photo list can be found
in mh/code/test/photo_index.pl

=cut

my ( $string, $limit ) = @ARGV;
$limit = 20 unless $limit;

if ( $string =~ /jump=(\S+)/ ) {

    #   $Save{photo_index} = $1;
    return http_redirect("/bin/photos.pl?$1");
}

$string =~ s/search=//;    # Allow for ?string or ?search=string

use vars '@photos';    # This will be persistent across passes and code reloads
@photos = file_read $config_parms{photo_index} unless @photos;

my @match = sort grep /$string/i, @photos;
@match = @photos unless $string;

my $count1  = @match;
my $count2  = @photos;
my $results = "Search for $string found $count1 matches from $count2 photos";
print_log $results;
my $html .= "<b>$results</b>";
$html .= "<b> (only first $limit are shown)</b>" if $count1 > $limit;
$html .=
  ".  <a href='/misc/photo_search.html'>Search Again</a>.  Back to <a href=photos.pl>photo slideshow</a>\n<br>\n";

my $i;
my ( $index, $photos );
my $href = '00001';
$index = "<table align=\"center\"><tr><td>";
for my $photo (@match) {
    $i++;
    my $name = $photo;
    $name =~ s/%20/ /g;
    $photo =~ s/ /%20/g;
    $photo =~ s/\#/%23/g;
    if ( $i < $limit ) {
        $index .= "<br><a href='#$href'>$name</a>\n";
        $href++;
        $photos .=
          "<hr><br><a name='$href' href='#top'>Back to top</a>.  <b>$name</b><br><img src='$photo'>\n";
    }
    else {
        $index .= "<br><a href='$photo'>$name</a>\n";
    }

    $index .= "</td><td>" if ( $i == int $count1 / 2 );

}
$index .= "</tr></table>";

$photos = "<div align=\"center\">" . $photos . "</div>";

return &html_page( '', $html . $index . $photos, ' ' );
