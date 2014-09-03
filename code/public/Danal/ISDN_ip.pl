# Category=Internet

##################################################################
#  For 3Com ISDN Lan Modem                                       #
#  Get the IP address of the current Internet call               #
#                                                                #
#  By: Danal Estes , N5SVV                                       #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

# The ISDN Lan Modem at Software level 5.3.1 and above broadcast an Ethernet packet
# periodically and at certain event triggers.
#
# Unfortunately, these packets (as of 5.3.1) do not contain the IP address of the
# other end of the call.
#
# So, we will pull the web page that contains call stats, parse it, and extract
# the IP address via which we're currently attached to the internet.

my $f_ISDN_addr = "$config_parms{data_dir}/web/ISDN_addr.txt";
my $f_ISDN_html = "$config_parms{data_dir}/web/ISDN_addr.html";

$p_ISDN_addr =
  new Process_Item("get_url http://lanmodem/stat3.htm $f_ISDN_html");

$v_ISDN_addr =
  new Voice_Cmd('[Get,Read,Show] the 3Com ISDN Lan Modem Internet IP address');
$v_ISDN_addr->set_info(
    "The IP address of the other end of the call; our public IP");

speak($f_ISDN_addr)   if said $v_ISDN_addr eq 'Read';
display($f_ISDN_addr) if said $v_ISDN_addr eq 'Show';

if ( said $v_ISDN_addr eq 'Get' ) {
    print_log "Retrieving 3Com Lan Modem Internet Call IP address...";
    start $p_ISDN_addr;
}

if ( done_now $p_ISDN_addr) {
    my $text = file_read $f_ISDN_html;

    # Delete text preceeding the Service Provider names of the calls
    $text =~ s/^.+?Dial-In User<\/td>//s;

    # Delete label for "IP address in use"
    $text =~ s/<td>IP address in use.*?<\/td>//s;

    # Pick next four table data elements as name/address pairs
    my ( $n1, $n2, $a1, $a2 ) = $text =~
      /(?:<td>)(.*?)(?:<\/td>)(?:.*?)(?:<td>)(.*?)(?:<\/td>)(?:.*?)(?:<td>)(.*?)(?:<\/td>)(?:.*?)(?:<td>)(.*?)(?:<\/td>)(?:.*?)/s;

    $n1 = 'No Call' if !$n1;
    $n2 = 'No Call' if !$n2;
    file_write( $f_ISDN_addr, "$n1=$a1, $n2=$a2" );

    display($f_ISDN_addr);
}

