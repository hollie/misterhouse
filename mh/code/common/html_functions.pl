# Category = MisterHouse

#@ These functions are used by the web browser

sub html_header {
    my ($text) = @_;
    $text = 'Generic Header' unless $text;

    my $color = $config_parms{html_color_header};
    $color = '#9999cc' unless $color;

    return qq[

<table width=100% bgcolor='$color'>
<td><center>
<font size=3 color="black"><b>
$text
</b></font></center>
</td>
</table>

];
    
}


# This is used by mh/web/bin/menu.pl

sub button_action {

# Process requests from the clicks on smart active buttons
# Use 'server side' image map xy to notice dim/bright requrests
# ISMAP data looks like this:  state?39,24

    my ($args) = @_;
    my ($object_name, $state, $referer, $xy) = split ',', $args;

    my ($x, $y) = $xy =~ /(\d+)\|(\d+)/;
#   print "dbx4 on=$object_name s=$state r=$referer xy=$xy xy=$x,$y\n";

                                # Do not dim the dishwasher :)
    unless (eval qq|$object_name->isa('X10_Appliance')|) {
        $state = 'dim'      if $x < 30;   # Left  side of image
        $state = 'brighten' if $x > 70;  # Right side of image
    }

    eval qq|$object_name->set("$state")|;
    print "smart_button_action.pl eval error: $@\n" if $@;

    $referer =~ s/ /%20/g;
    $referer =~ s/&&/&/g;
    return &http_redirect($referer);
}
