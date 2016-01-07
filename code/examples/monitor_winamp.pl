#
# Category=Other
#
# Monitor the a winamp shoutcast server.
# I have had problems with winamp shoutcast crashing the computer if left running
# for more than a day, so this will give it a fresh start in the middle of the night.
#

if ( time_cron '0 3 * * * ' ) {
    my $window;
    if ( &WaitForAnyWindow( 'Winamp', \$window, 100, 100 ) ) {
        print_log "Winamp was shutdown and restarted.";

        # Send Alt-f  x
        &SendKeys( $window, "\\alt\\fx\\", 1, 500 );
    }
    else {
        print_log "Winamp was not running.  I just started it.";
    }

    # This command is created in mp3 controls
    #   run 'd:\utils\Winamp\Winamp.exe';
    run_voice_cmd "set mp3 player to top 100";
}
