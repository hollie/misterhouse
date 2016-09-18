# Category=Pushover

# Sample code for sending Pushover notifications
# Brian Rudy (brudyNO@SPAMpraecogito.com)

# Pushover_token and Pushover_user must be defined in mh.private.ini

use Pushover;

$v_send_pushover_to_all =
  new Voice_Cmd 'Send pushover notification to [all,tusdroidrazrhd]';
my $push = new Pushover();

if ( $state = said $v_send_pushover_to_all) {
    if ( $state eq "all" ) {
        print_log "Sending Pushover notification to all devices";
        $push->notify( "A low priority test message",
            { title => 'Test title', priority => -1 } );
    }
    else {
        print_log "Sending Pushover notification to $state";
        $push->notify( "A low priority test message to $state",
            { title => 'Test title', priority => -1, device => $state } );
    }
}

