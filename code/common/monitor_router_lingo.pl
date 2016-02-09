# Category = Misc

#@ Connects to your Lingo router and checks that it is connected to
#@ VoIP. If not connected it reboots the router which should bring the
#@ VoIP connection back up.

=begin comment

 monitor_router_lingo.pl
 Created by Axel Brown

 This code connects to your Lingo VoIP router and checks its
 current "connected" status.  If it is not "Connected to VoIP"
 then the router is rebooted.

 Only thing you should need to change for your own setup is the
 $lingo_ip variable below.  NOTE: The $lingo_user and $lingo_pass
 variables are set to the standard settings that Lingo use when
 shipping routers out to customers.  They are NOT the user/pass
 you use on the lingo.com website!

 Revision History

 Version 0.1             January 26, 2005
 And so it begins...

=cut

# noloop=start
my $lingo_ip   = "lingo.localdomain";    # <-- Change this to the IP of
                                         # your Lingo router!!!
my $lingo_user = "user";
my $lingo_pass = "ph3taswe";

my $lingo_status_url =
  "http://${lingo_user}:${lingo_pass}\@${lingo_ip}/LP_status.html";
my $f_lingo_status_html =
  "$config_parms{data_dir}/web/lingo_router_status.html";

my $lingo_reboot_url =
  "http://${lingo_user}:${lingo_pass}\@${lingo_ip}/LP_reboot.html";
my $f_lingo_reboot_html =
  "$config_parms{data_dir}/web/lingo_router_reboot.html";

# noloop=stop

$v_check_lingo_router = new Voice_Cmd('Check Lingo router');
$p_check_lingo_router = new Process_Item(
    "get_url -quiet \"$lingo_status_url\" \"$f_lingo_status_html\"");
$p_reboot_lingo_router = new Process_Item(
    "get_url -quiet \"$lingo_reboot_url\" \"$f_lingo_reboot_html\"");

# Run on the 3rd minute of every 5 minute block (or when requested by
# the voice command)
if ( ( $New_Minute and ( ( $Minute % 5 ) == 3 ) ) or said $v_check_lingo_router)
{
    # Check for active internet connection
    # VoIP won't work without it regardless of the
    # state of the Lingo ATA
    if (&net_connect_check) {

        # Run the check
        start $p_check_lingo_router;
    }
}

if ( done_now $p_check_lingo_router) {

    # The html file has been retrieved from the router so looked for
    # the <INPUT> line relating to the current "connected" state
    my $html = file_read $f_lingo_status_html;
    my ($status) = $html =~ /name="l_voip" value="(.*)">/;
    if ( $status =~ /Not connected to VoIP/i ) {

        # We're not connected so attempt to reboot the lingo router
        start $p_reboot_lingo_router;
    }
}

if ( done_now $p_reboot_lingo_router) {
    print_log "Rebooting the Lingo router";
    respond "Lingo router has been rebooted";
}
