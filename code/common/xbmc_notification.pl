# Category=Home_Network
#
#@ Sends Notification message to XBMC

use LWP::UserAgent;

$v_xbmc_osd = new  Voice_Cmd("Test XBMC Notify");


if ($Startup) {
	&display_xbmcosd("System Restarted", "Misterhouse has been restarted");
}

if ($state = said $v_xbmc_osd) {
	#speak "Testing X B M C";
	&display_xbmcosd("Test Notification", "This is a test notification!!");
}

sub display_xbmcosd {
	my ($title, $text) = @_;

	$title =~ s/ /%20/g;
	$text =~ s/ /%20/g;

	my $url = 'http://' .$config_parms{xbmc_notify_address}.'/jsonrpc?request={"jsonrpc":"2.0","method":"GUI.ShowNotification","params":{"title":"'.$title.'","message":"'.$text.'"},"id":1}';

	my $ua = new LWP::UserAgent;
	my $req = new HTTP::Request GET => $url;
	my $res = $ua->request($req);

}
