
# Sendkeys is a windows only (currently not in perl 5.6) way
# of controling other windows

$test_sendkey = new Voice_Cmd 'Test sendkey [1,2,3]';

if ( $state = said $test_sendkey) {

    # Send data to notepad
    if ( my $window = &sendkeys_find_window( 'Notepad', 'notepad' ) ) {
        my $keystr = '33';
        &SendKeys( $window, $keystr, 1, 500 ) if $state == 1;
        &SendKeys( $window, '33',    1, 500 ) if $state == 2;
        print_log "keys sent: $state";
    }
}
