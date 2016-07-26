
=begin comment

Use this code to create and/or process form data to send data to a function

Example:

 see web/bin/triggers.pl

=cut

use strict;

#print "db a=@ARGV\n";

# Process form
if ( @ARGV > 2 ) {

    # Allow un-authorized users to browse only (if listed in password_allow)
    return 'Not authorized to make set_func updates' unless $Authorized;

    # Drop var= prefix.  Required order:  func, resp, @vars
    my ( $func, $args, $resp );
    for (@ARGV) {
        $_ =~ s/^\S+?=//;
        if ($resp) {
            $_ =~ s/'/\\'/g;    # added to escape single quotes
            $args .= "'$_',";
        }
        elsif ($func) {
            $resp = $_;
        }
        else {
            $func = "&$_";
        }
    }
    $func = "$func($args)";
    my $html = eval $func;
    print "\nError in set_func.pl: $@\n" if $@;
    return $html if $html;    # Allow function to override response
    return &http_redirect($resp);
}

# Create form ... not tested ...
else {
    my $func = shift;
    my $resp = shift;
    my $html = &html_header('Set a Function');
    $html .= "<p><form action='/bin/set_var.pl' method=post>\n";
    $html .= "<b>Function:</b>$func\n<br>";
    $html .= "<b>Value:</b>\n";

    $html .= qq|<input name='func'  type=hidden value="$func">\n|;
    $html .= qq|<input name='resp'  type=hidden value="$resp">\n|;
    $html .= qq|<input name='value' type=input  size=100>\n|;
    $html .= "</form>\n";

    return &html_page( '', $html );
}

