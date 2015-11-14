
# On windows, use sendkeys to point a browser to a url
#  - does not work too well, due to timing issues for
#    the open window

$browser_test = new Voice_Cmd 'Test browser [1,2,3]';

if ( $state = said $browser_test) {
    print_log "Running browser test $state";
    if ( $state == 1 ) {
        if (
            my $window = &sendkeys_find_window(
                'Explorer', 'C:\Progra~1\Intern~1\IEXPLORE.EXE'
            )
          )
        {
            my $keys = '\\ctrl\\o\\ctrl-\\';
            &SendKeys( $window, $keys, 1 );
        }
        sleep .4;
        if ( my $window = &sendkeys_find_window('Open') ) {
            my $keys = 'http://misterhouse.net\\ret\\';
            &SendKeys( $window, $keys, 1 );
        }
    }
}
