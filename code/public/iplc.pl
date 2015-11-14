# Category=Insteon

#@ various tests (A - H) for Insteon Objects and email. I really need to separate this into 2 files.

=begin comment

=cut

# noloop=start      This directive allows this code to be run on startup/reload
# noloop=stop

$my_test = new Voice_Cmd 'Run test [A,B,C]';

if ( $state = said $my_test) {
    if ( $state eq 'A' ) {
        speak "You ran test A at $Time_Now";
    }
    elsif ( $state eq 'B' ) {
        display "You ran test B (iAppliance On) on $Date_Now";
        set $iAppliance ON;
    }
    elsif ( $state eq 'C' ) {
        print_log "Test C: iAppliance Off";
        set $iAppliance OFF;
    }
}
