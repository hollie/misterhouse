
$test1 = new Voice_Cmd 'Test sendkey';
if ( state_now $test1) {
    print_log "Testing Setupsup sendkeys to outlook";
    my $window;
    if ( &WaitForAnyWindow( 'Outlook', \$window, 1000, 100 ) ) {
        &SendKeys( $window, "\\alt\\te\\ret\\", 1, 500 )
          ;    # Send alt Tools sEnd Return (for all accounts)
    }
    else {
        print_log "Outlook is not running";
    }
}
