
=begin comment

Use this code to create and/or process form data to send data to set a variable

Example:

 see web/bin/triggers.pl

=cut

use strict;

my ( $var, $resp, $value ) = @ARGV;

#print "db a=@ARGV\n";

# Process form
if ( defined $value ) {

    # Allow un-authorized users to browse only (if listed in password_allow)
    return &html_page( '', 'Not authorized to make set_var updates' )
      unless $Authorized;

    $var =~ s/^var=//;
    $value =~ s/^value=//;
    $resp =~ s/^resp=//;

    # Allow for increment/decrement
    if ( $value =~ /delta:(.+)/ ) {
        eval qq|$var += $1|;
    }
    else {
        #       eval qq|$var = "$value"|;  # If we use ", we mess up stuff like: set $camera_light TOGGLE
        $value =~ s/'/\\'/g;
        eval qq|$var = '$value'|;
    }
    print "\nError in set_var.pl: $@\n" if $@;
    return &http_redirect($resp);
}

# Create form
else {
    my $data = eval $var;
    print "\nError in set_var.pl: $@\n" if $@;
    my $html = &html_header('Set a Variable');
    $html .= "<p><form action='/bin/set_var.pl' method=post>\n";
    $html .= "<b>Variable:</b>$var\n<br>";
    $html .= "<b>Value:</b>\n";

    $data =~ s/\"/\'/g;    # Use hex 27 = '
    $var =~ s/\"/\'/g;
    $resp =~ s/\"/\'/g;

    $html .= qq|<input name='var'   type=hidden value="$var">\n|;
    $html .= qq|<input name='resp'  type=hidden value="$resp">\n|;
    $html .= qq|<input name='value' type=input  value="$data" size=100>\n|;

    return &html_page( '', $html );
}
