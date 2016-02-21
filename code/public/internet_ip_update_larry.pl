# Category=Informational
#This will get you your actual IP address and display it in a TK interface.
#This is very useful if MH is sitting behind a router and you need to know your external IP address.
#It monitors any changes in your IP address and can take action upon a change.
#Larry Roudebush
my $f_get_external_ip = "$config_parms{data_dir}/web/externalip.html";
$v_get_external_ip = new Voice_Cmd 'Check external IP address';
$p_get_external_ip =
  new Process_Item "get_url http://www.whatismyip.com $f_get_external_ip";

if ( said $v_get_external_ip or $New_Hour ) {
    unlink $f_get_external_ip;
    start $p_get_external_ip;
    print_log 'Checking external IP address';
}

if ( done_now $p_get_external_ip) {
    my $html = file_read $f_get_external_ip;
    my ($externalip) = $html =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/;

    #print_log "External IP Address is:  $externalip";
    if ( $Save{ip_address_server} eq $externalip ) {

        #print_log "IP server address current";
        &TkIpAddressLabel;
    }
    else {
        $Save{ip_address_server} = $externalip;
        speak "Warning, external IP address changed\n";

        #if IP address changes add action here
        &net_mail_send(
            to      => '$person3email',
            subject => "IP Address",
            text    => "external IP address changed $externalip"
        );
        &TkIpAddressLabel;
    }
}

# Create/update a tk label that reflects the current address
&tk_label( \$Tk_objects{ip_address} );

# Shared funtion to update the label
sub TkIpAddressLabel {
    if (&net_connect_check) {
        $Tk_objects{ip_address} =
          "External IP address: $Save{ip_address_server}";
    }
    else {
        $Tk_objects{ip_address} = "Not Connected";
    }
}

# Set and update the label's value
if ( ($Startup) or ( $New_Minute and %Tk_objects ) ) {
    TkIpAddressLabel;
}
