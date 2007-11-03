package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$session->{__old_loglevel} = $session->loglevel();
$session->loglevel(10);
$connection->log_print(OSCAR_DBG_WARN, "Server initiated migration.  Migration support is experimental.  Please tell matthewg\@zevils.com that this happened and whether or not it worked!  Include the information below.");
$connection->log_print(OSCAR_DBG_WARN, "Migration families sent: ", join(" ", keys %{$connection->{families}}));
$connection->proto_send(protobit => "pause_ack", protodata => {
	families => [keys %{$connection->{families}}]
});
$connection->pause();

};
