
=begin comment

From Jim Duda  on 09/2003

Thanks for your help everyone, my modem can now dial my phone
from a voice command.

I used two suggestions from the list, ATs7=5 during startup
and "+++" with the ATH0 command.  I haven't gone back to figure
out if one or the other work by themselves ... lazy bum.

=cut

if ( $Startup or $Reload ) {
    set $phone_modem 'ATs7=5';
}

my ( $DialNumber, $state );

# -------------------------- Dial Number
$v_voice_dial = new Voice_Cmd('call [number one,number two,cell,parents]');
if ( $state = said $v_voice_dial) {

    #    $VoiceModemStatus = "Dialing";
    if ( $state eq 'number one' ) {
        $DialNumber = "1xxx";
    }
    elsif ( $state eq 'number two' ) {
        $DialNumber = "1xxx";
    }
    elsif ( $state eq 'cell' ) {
        $DialNumber = "1xxx";
    }
    elsif ( $state eq 'parents' ) {
        $DialNumber = "1xxx";
    }

    speak "dialing $DialNumber";
    print_log "VOICE - Dialing $DialNumber...";
    $DialNumber = "ATDT" . $DialNumber . "+++ATH0";
    set $phone_modem $DialNumber;
}

