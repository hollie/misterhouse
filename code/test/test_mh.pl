# Category=Test

# At startup program a time to stop the test after one minute
my  $shutdown_timer = new Timer; #noloop
$shutdown_timer->set(60, \&shutdown); #noloop
my  $start_test_code_timer = new Timer; #noloop
$start_test_code_timer->set(5, \&start_tests); #noloop

# Test get_url with a post parameter
my $get_url_http_output = '/tmp/get_url_post_http.txt';
my $get_url_https_output = '/tmp/get_url_post_https.txt';

my $get_url_test_http = new Process_Item("get_url -post 'testparameter=1' http://httpbin.org/post $get_url_http_output");
my $get_url_test_https = new Process_Item("get_url -post 'testparameter=1' https://httpbin.org/post $get_url_https_output");

if ($Startup) {
	$shutdown_timer->start();
	print_log "Shutdown timer set";
}

sub shutdown {
	print_log "Stopping self-test, exit...";
	run_voice_cmd("Exit Mister House");
}

sub start_tests {
	print_log "Starting the test routines...";
	## get_url with post parameter via http
	unlink $get_url_http_output;
	$get_url_test_http->start();

	## get_url with post parameter via https
	unlink $get_url_https_output;
	$get_url_test_https->start();
}

## Validation of the result of the HTTP POST test
if ($get_url_test_http->done_now()) {
	print_log "Get URL test done, checking output";
	my $url_test = file_read($get_url_http_output);

	if ($url_test =~ /testparameter/g) {
		# Test passed fine
		print_log "get_url code with post for HTTP worked as expected";

	} else {
		# Test failed
		print_log "get_url code with post over HTTP failed, output was '$url_test'";
		exit -1;
	}
}

## Validation of the result of the HTTPS POST test
if ($get_url_test_https->done_now()) {
	print_log "Get URL test done, checking output";
	my $url_test = file_read($get_url_https_output);

	if ($url_test =~ /testparameter/g) {
		# Test passed fine
		print_log "get_url code with post for HTTPS worked as expected";

	} else {
		# Test failed
		print_log "get_url code with post over HTTPS failed, output was '$url_test'";
		exit -1;
	}
}
