# Category=Test

# At startup program a time to stop the test after one minute
my  $shutdown_timer = new Timer; #noloop
$shutdown_timer->set(60, \&shutdown); #noloop

if ($Startup) {
	$shutdown_timer->start();
	print_log "Shutdown timer set";
}

sub shutdown {
	print_log "Stopping self-test, exit...";
	run_voice_cmd("Exit Mister House");
}
