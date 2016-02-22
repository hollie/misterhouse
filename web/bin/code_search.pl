
=begin comment

This file is called directly from the browser with: 

  http://localhost:8080/bin/code_search.pl?search_string

Used in the ia5/house/search menu

=cut

$^W = 0;    # Avoid redefined sub msgs

my ($string) = @ARGV;
$string =~ s/search=//;    # Allow for ?string or ?search=string

my $results = &search_code($string);

my $font_size = ( &http_agent_size < 800 ) ? 1 : 3;

$results =
  qq[<font size=$font_size><pre>Searching for "$string" in code scripts:<BR> <BR>$results</pre></font>];

return &html_page( '', $results, ' ' );

sub search_code {
    my $string = shift;
    print "Searching for code $string";
    my ( $results, $count, %files );
    $count = 0;
    for my $file ( sort keys %User_Code ) {
        my $n = 0;
        for ( @{ $User_Code{$file} } ) {
            $n++;
            if (/$string/i) {
                $count++;
                $results .= "\nFile: $file:\n------------------------------\n"
                  unless $files{$file}++;
                $results .= sprintf( "%4d: %s", $n, $_ );
            }
        }
    }
    return "Found $count matches\n" . $results;
}
