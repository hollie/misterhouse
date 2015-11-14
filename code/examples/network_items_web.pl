# Category = Network

#@ Network Items web subroutine

sub web_networkitems {

    my $html_hdr  = ();
    my $html_data = ();
    my $nd_down   = 0;
    my $nd_up     = 0;

    for my $net_item ( list $network_items) {
        $html_data .=
          "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>\n";
        my $tmp_name = $net_item->{object_name};
        $tmp_name =~ s/\$//g;
        $html_data .= "<td nowrap>$net_item->{object_name}</td>";
        my $tmp_state = &get_object_by_name( $net_item->{object_name} );
        $html_data .= "<td ";
        if ( state $tmp_state eq 'on' or state $tmp_state eq 'up' ) {
            $html_data .= "bgcolor='#33FF00' ";
            $nd_up = $nd_up + 1;
        }
        else {
            $nd_down = $nd_down + 1;
        }
        $html_data .= "nowrap>$tmp_state->{state}</td>";

        # doesn't work until proper set is figured out.
        #	if ($tmp_state->control('on')) {
        #		$html_data .= "<td nowrap><a href=\"/SET?$net_item->{object_name}=on\">turn on</a></td>";
        #		}
        #	else {
        $html_data .= "<td nowrap></td>";

        #		}
        #	if ($tmp_state->control('off')) {
        #		$html_data .= "<td nowrap><a href=\"/SET?$net_item->{object_name}=off\">turn off</a></td>";
        #		}
        #	else {
        $html_data .= "<td nowrap></td>";

        #		}
        $html_data .= "</tr>\n";
    }

    $html_hdr = &html_header("Network Devices: $nd_up on and $nd_down off ");
    $html_hdr .=
      "<table width=100% cellspacing=2><tbody><font face=COURIER size=2><tr id='resultrow' bgcolor='#9999CC' class='wvtheader'><th align='left'>Network Device</th><th align='left'>Status</th><th align='left'>Control ON</th><th align='left'>Control OFF</th>\n";

    my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>";

    $html .= $html_hdr . $html_data;

    $html .= "</body>";

    my $html_page = &html_page( '', $html );
    return &html_page( '', $html );

}

# End of Network_Items_Web.pl code
