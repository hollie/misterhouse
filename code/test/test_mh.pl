# Category=Test

# At startup program a time to stop the test after one minute
my $shutdown_timer = new Timer;    #noloop
$shutdown_timer->set( 60, \&shutdown );    #noloop
my $start_test_code_timer = new Timer;     #noloop
$start_test_code_timer->set( 5, \&start_tests );    #noloop

# Test get_url with a post parameter
my $get_url_output = '/tmp/get_url_post.txt';
my $get_url_test   = new Process_Item("get_url -post 'testparameter=1' https://httpbin.org/post $get_url_output");

if ($Startup) {
    $shutdown_timer->start();
    print_log "Shutdown timer set";
}

sub shutdown {
    print_log "Stopping self-test code in code/test/test_mh.pl, going to exit Misterhouse now...";
    run_voice_cmd("Exit Mister House");
}

sub start_tests {
    print_log "Starting the test routines...";
    ## get_url with post parameter
    unlink $get_url_output;
    $get_url_test->start();
}

if ( $get_url_test->done_now() ) {
    print_log "Get URL test done, checking output";
    my $url_test = file_read($get_url_output);

    if ( $url_test =~ /testparameter/g ) {

        # Test passed fine
        print_log "get_url code with post worked as expected";

    }
    else {
        # Test failed
        print_log "get_url code with post failed, output was '$url_test'";
        exit -1;
    }
}
