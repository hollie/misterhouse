
=begin comment

This file is called directly from the browser with: 

  http://localhost:8080/bin/command_search.pl?search_string

Used in the ia5/house/search menu

=cut

$^W = 0;    # Avoid redefined sub msgs

my ($string) = @ARGV;
$string =~ s/search=//;    # Allow for ?string or ?search=string

my $html = &html_header(
    "<b>Search results for: <i>$string</i></b>&nbsp;&nbsp;&nbsp;&nbsp;"
      . &html_authorized );

$html .= qq|<form action='/bin/command_search.pl'>Search String:|
  . qq|<input align='left' size='25' name='search'></form>|;

$html .= &search_commands($string);

return &html_page( '', $html, ' ' );

sub search_commands {
    my $string = shift;
    print "Searching for code $string";

    my %seen;
    my ( %seen, @object_list, $html );
    for my $cmd ( &list_voice_cmds_match($string) ) {

        # Now find object name
        my ( $file, $cmd2 ) = $cmd =~ /(.+)\:(.+)/;
        my ( $object, $said, $vocab_cmd ) =
          &Voice_Cmd::voice_item_by_text( lc $cmd2 );
        my $object_name = $object->{object_name};
        next if $seen{$object_name}++;
        push @object_list, $object_name;
    }
    $html .= &widgets( 'search', $string );
    $html .= &html_command_table(@object_list);
    return $html;
}
