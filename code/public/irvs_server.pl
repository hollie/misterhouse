##############################################################################
# Ident  Date      Name          Description
# -----  ----      ----          -----------
# V1.0   21-03-01  W. Leemput    Initial creation
#
# Functional Description:
# -----------------------
#
# Socket servers for IVR system
# add following line in mh.ini:
# server_telnet_ivr_port=1235 # IVR socket server
#
##############################################################################
#
# IVR socket server
$telnet_server_ivr = new Socket_Item( undef, undef, 'server_telnet_ivr' );

####################
# IVR socket server
####################
my $handle_telnet_server_ivr = handle $telnet_server_ivr;
if ( my $msg = said $telnet_server_ivr) {
    chomp $msg;
    if ( process_external_command($msg) ) {
        print $handle_telnet_server_ivr "ok $msg\n";
    }
    else {
        print $handle_telnet_server_ivr "er $msg\n";
    }
}
