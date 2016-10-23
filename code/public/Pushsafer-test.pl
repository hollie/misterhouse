# Category=Pushsafer

# Sample code for sending Pushsafer notifications

# Pushsafer_token and Pushsafer_user must be defined in mh.private.ini

use Pushsafer;

$v_send_pushsafer_to_all =
  new Voice_Cmd 'Send pushsafer notification to [all,tusdroidrazrhd]';
my $push = new Pushsafer();

print_log "Sending Pushsafer notification to $state";
$push->notify( "A test message to $state", { title => 'Test title', priority => -1, device => $state } );


