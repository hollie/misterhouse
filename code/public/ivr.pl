# Category = MisterHouse

use Numbered_Menu;
use Telephony_DTMF;
$co_dtmf  = new Telephony_DTMF($tel);
$icm_dtmf = new Telephony_DTMF($icm);

#Instance a Number_Menu object using the ivr.menu file.  4 second item delay
$km = new Numbered_Menu( 'ivr', undef, '4' );

#If phone goes offhook and pound received in 4 seconds, then start IVR
$co_dtmf->tie_sequence( '^#', '&::ivr_start();', '4' );

#If phone goes onhook, stop IVR
$icm_dtmf->tie_sequence( '+', '&::ivr_stop();', '2' );

my $ivr_menu;

if ($Startup) {

    #	$km->init();
    $icm_dtmf->tie_items( $km, '1', '1' );
    $icm_dtmf->tie_items( $km, '2', '2' );
    $icm_dtmf->tie_items( $km, '3', '3' );
    $icm_dtmf->tie_items( $km, '4', '4' );
    $icm_dtmf->tie_items( $km, '5', '5' );
    $icm_dtmf->tie_items( $km, '6', '6' );
    $icm_dtmf->tie_items( $km, '7', '7' );
    $icm_dtmf->tie_items( $km, '8', '8' );
    $icm_dtmf->tie_items( $km, '9', '9' );
    $icm_dtmf->tie_items( $km, '0', 'repeat' );
    $icm_dtmf->tie_items( $km, '#', 'repeat' );
    $icm_dtmf->tie_items( $km, '*', 'exit' );
    $km->tie_event('ivr_process_menu $state');
}

sub ivr_start {
    print_log("VM Start");

    # SG Flag that connects the phone to icm port when on
    $phonetoicm->set('on');

    # Start Voicemail
    $km->set('start');
}

sub ivr_stop {
    print_log("VM Stop");

    # Stop voicemail
    $km->set('stop');

    # SG Flag that connects the phone to co port when on
    $phonetoco->set('on');
}

sub ivr_process_menu {
    my ($p_state) = @_;
    $p_state = lc($p_state);
    $p_state =~ s/_/ /g;
    if ( $p_state =~ /^menu/ ) {
        $p_state =~ /(.*):(.*)/;
        $ivr_menu = $2;
        $icm->speak( text => "$2 menu", right => 90, left => 0 );
    }
    elsif ( $p_state =~ /^item/ ) {
        print_log "Item";
        $p_state =~ /(.*):(.*):(.*)/;
        if ( $2 eq '-' ) {
            $icm->speak( text => "End of menu.", right => 90, left => 0 );
        }
        else {
            $icm->speak( text => "Press $2, for $3.", right => 90, left => 0 );
        }
    }
    elsif ( $p_state =~ /^start/ ) {

        #connect sound card to telephony device
        $icm->patch('on');

    }
    elsif ( $p_state =~ /^stop/ ) {

        # disconnect sound card to telephony device
        $icm->patch('off');
    }
    elsif ( $p_state =~ /^response/ ) {
        $p_state =~ /^response:(.*)/;
        $icm->speak( text => "$1", right => 90, left => 0 );
    }

    print_log "IVR menu: $p_state : $ivr_menu";
}

