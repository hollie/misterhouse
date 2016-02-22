#!/usr/bin/perl
#
# Jason Sharpee <jason@sharpee.com>  GPL Licensed
# Based on code by: James Golovich <james@gnuinter.net>
# Based on code by: Patrick Lidstone <patrick@lidstone.net>

use IO::Socket::INET;

use lib './lib', '../lib';
use Asterisk::Manager;

$|++;

my $astman = new Asterisk::Manager;

$astman->user('test');
$astman->secret('test');
$astman->host('127.0.0.1');

$astman->connect || die $astman->error . "\n";

$astman->setcallback( 'Newstate', \&newstate_callback );
$astman->setcallback( 'Newexten', \&newexten_callback );
$astman->setcallback( 'DEFAULT',  \&default_callback );

#######################
## xAP setup
#######################
# Default xAP UDP port
$port = 3639;

# How this app is known in the xAP world
$XAP_GUID     = "FF000100";
$XAP_ME       = "Asterisk";
$XAP_SOURCE   = "xAP-info";
$XAP_INSTANCE = "Perl";
$XAP_CLASS    = "Telephony.Info";

# The hub will disconnect this application after 2 heartbeats
# have elapsed. Normally we would use a timer to send
# regular heartbeats at say 30s intervals -- in this example
# we just send the heartbeat once, so this app will "go deaf"
# after 1200*2 = 2400 seconds.
$HBEAT_INTERVAL = 1200;

# Max size of a UDP packet
$MAXLEN = 1500;

# Attempt to create a broadcast socket on which all
# outgoing xAP messages will be sent. If we can't create this, we
# can't continue

my $xap_send = new IO::Socket::INET->new(
    PeerPort  => $port,
    Proto     => 'udp',
    PeerAddr  => inet_ntoa(INADDR_BROADCAST),
    Broadcast => 1
);
my ($l_name) = $params{Callerid} =~ /\"(.*)\"/;
die "Could not create xap sender\n" unless $xap_send;

# Now send a heartbeat to the broadcast socket. This will be
# intercepted by all xAP enabled applications, including the
# local hub if active.

# If a local hub is active, then it will relay messages on
# the port we tell it we are listening on.

#print "Sending heartbeat on port ", $xap_send->peerport, "\n";

# Compose and send a heartbeat
print $xap_send "xap-hbeat\n{\nv=12\nhop=1\nuid=", $XAP_GUID,
  "\nclass=xap-hbeat.alive\nsource=",
  $XAP_ME, ".", $XAP_SOURCE, ".", $XAP_INSTANCE, "\ninterval=", $HBEAT_INTERVAL,
  "\nport=", $port, "\n}\n";

######################

#print STDERR $astman->command('zap show channels');

#print STDERR $astman->sendcommand( Action => 'IAXPeers');

#print STDERR $astman->sendcommand( Action => 'Originate',
#					Channel => 'Zap/7',
#					Exten => '500',
#					Context => 'default',
#					Priority => '1' );

#&newstate_callback(State=>'Ringing',Callerid=>'"Jason" <414-444-4444>');
#&newstate_callback(State=>'Ringing',Callerid=>'<unknown>');

$astman->eventloop;

$astman->disconnect;

sub newexten_callback {
    my (%params) = @_;

    xap_extension( $params{'Extension'}, $params{'Context'},
        $params{'Channel'} );
    default_callback(@_);

}

sub newstate_callback {
    my (%params) = @_;

    #	print "NEWSTATE!!!!!:" . $params{'State'} . ":" . uc $params{State} . ":";
    if ( uc $params{State} eq 'RINGING' ) {

        #ex. '"Joe Blow" <4441112222>'
        #		print "\nCID!!:" . $params{Callerid} . ":";
        my ($l_name)   = $params{Callerid} =~ /^\"(.*)\".*/;
        my ($l_number) = $params{Callerid} =~ /<(.*)>$/;
        my $l_type     = "Available";
        if ( uc $l_number eq 'UNKNOWN' ) { $l_type = "Unavailable"; }

        #		print "\nCID:" . $l_name . ":" . $l_number . ":";
        xap_cid( $l_number, $l_name, $l_type, $params{Channel} );

        #		print "CALLERID:" . $params{Callerid} . ":";
    }
    default_callback(@_);
}

sub default_callback {
    my (%stuff) = @_;
    foreach ( keys %stuff ) {
        print STDERR "$_: " . $stuff{$_} . "\n";
    }
    print STDERR "\n";
}

#Callerid: "dskfjakjfsadf"
#Event: Newstate
#State: Ringing
#Channel: Zap/2-1

#Event: Newexten
#Extension: 3431423432
#Channel: Zap/2-1

sub xap_extension {
    my ( $p_number, $p_context, $p_line ) = @_;
    my $response;

    my $l_reason = $p_type;

    $response =
        "xap-header\n{\nv=12\nhop=1\nuid="
      . $XAP_GUID
      . "\nclass="
      . $XAP_CLASS
      . "\nsource="
      . $XAP_ME . "."
      . $XAP_SOURCE . "."
      . $XAP_INSTANCE;

    $response = $response . "\n}\n";
    $response = $response . "Outgoing.CallComplete\n";
    $response = $response . "{\n";
    $response = $response . "Phone=" . $p_number . "\n";
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    $year += 1900;
    $mon  += 1;
    $mon  = sprintf( "%02d", $mon );
    $mday = sprintf( "%02d", $mday );
    $hour = sprintf( "%02d", $hour );
    $min  = sprintf( "%02d", $min );
    $sec  = sprintf( "%02d", $sec );
    $response =
        $response
      . "DateTime="
      . $year
      . $mon
      . $mday
      . $hour
      . $min
      . $sec . "\n";
    $response = $response . "Duration=00:00:00\n";
    $response = $response . "Context=" . $p_context . "\n";
    $response = $response . "Line=" . $p_line . "\n";
    $response = $response . "}\n";
    print $xap_send $response;
    return $response;

}

sub xap_cid {
    my ( $p_number, $p_name, $p_type, $p_line ) = @_;
    my $response;

    my $l_reason = $p_type;

    $response =
        "xap-header\n{\nv=12\nhop=1\nuid="
      . $XAP_GUID
      . "\nclass="
      . $XAP_CLASS
      . "\nsource="
      . $XAP_ME . "."
      . $XAP_SOURCE . "."
      . $XAP_INSTANCE;

    $response = $response . "\n}\n";
    $response = $response . "Incoming.CallWithCID\n";
    $response = $response . "{\n";
    $response = $response . "Type=" . "Voice" . "\n";
    $response = $response . "Phone=" . $p_number . "\n";
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    $year += 1900;
    $mon  += 1;
    $mon  = sprintf( "%02d", $mon );
    $mday = sprintf( "%02d", $mday );
    $hour = sprintf( "%02d", $hour );
    $min  = sprintf( "%02d", $min );
    $sec  = sprintf( "%02d", $sec );
    $response =
        $response
      . "DateTime="
      . $year
      . $mon
      . $mday
      . $hour
      . $min
      . $sec . "\n";
    $response = $response . "RNNumber=" . $l_reason . "\n";
    $response = $response . "Name=" . $p_name . "\n";
    $response = $response . "Line=" . $p_line . "\n";
    $response = $response . "}\n";
    print $xap_send $response;
    return $response;

}
