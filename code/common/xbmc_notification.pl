# Category=Home_Network
#
#@ Sends Notification message to XBMC

$v_xbmc_osd = new  Voice_Cmd("Test XBMC Notify");


if ($Startup) {
	&display_xbmcosd("System Restarted", "Misterhouse has been restarted");
}

if ($state = said $v_xbmc_osd) {
	#speak "Testing X B M C";
	&display_xbmcosd("Test Notification", "This is a test notification!!");
}



$xbmc_osd = new  Socket_Item(undef, undef, $config_parms{xbmc_notify_address}, 'xbmc', 'tcp');

sub display_xbmcosd {
	my ($heading, $text) = @_;

	$heading =~ s/ /%20/g;
	$text =~ s/ /%20/g;

	start $xbmc_osd unless (active $xbmc_osd);
	set $xbmc_osd <<EOT;
GET /jsonrpc?request={%22jsonrpc%22:%222.0%22,%22method%22:%22GUI.ShowNotification%22,%22params%22:{%22title%22:%22${heading}%22,%22message%22:%22${text}%22},%22id%22:1} HTTP/1.1
Connection: close
User-Agent: Misterhouse/1.0
Cache-Control: no-cache

EOT
	stop $xbmc_osd;
}
