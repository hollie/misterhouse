#!/usr/bin/perl

=begin comment

This program provides a simple xAP listener for the Festival text-to-speech synthesizer.

Written by Chris Barrett, based on code provided by Bruce Winter.

version 0.1 - 27 March 2005
version 0.2 - 28 April 2005

Modified by Tim Sailer to support festival, flite and swift TTS systems.
11/07

=cut

my $debug = 0;

use strict;
use IO::Socket::INET;
use Getopt::Long;

# Setup constants
my $FORCE_LOCAL_HUB = 0;            # set to 0 if no hub or default operation
my $XAP_PORT        = 3639;
my $XAP_GUID        = 'FFBA8300';
my $XAP_ME          = 'MHOUSE';

# Use festival, flite, or swift for source
my $XAP_SOURCE = 'swift';
my $XAP_INSTANCE;
my $MAXLEN         = 1500;          # Max size of a UDP packet
my $HBEAT_INTERVAL = 120;           # Send every 2 minutes
my $fqfn;
my $room;
my $target;
my $xap_listen;

my $help;
GetOptions( 'room=s', \$room, 'debug', \$debug, 'help|h|?', \$help );
if ($help) {
    print "usage: $0 [--room=room] [--debug] [--help|h|?]\n";
    exit;
}

if ( $^O =~ /MSWin/i ) {
    print "Sorry, but this only works on *nix systems\n";
    exit;
}

if ( $room eq "" ) {
    my $hostname = `hostname`;
    chomp $hostname;
    $hostname =~ s/^(.*?)\.(.*)$/$1/;
    print
      "A room was not specified using --room= so I'm using the hostname [$hostname]\n"
      if $debug;
    $room = $hostname;
}
$XAP_INSTANCE = $room;

if ( $XAP_SOURCE eq "festival" ) {
    $fqfn = `which festival`;
    chomp $fqfn;
    if ( $fqfn =~ /no festival in/ ) {
        print "Could not find festival in the PATH\n";
        exit;
    }
}
elsif ( $XAP_SOURCE eq "flite" ) {
    $fqfn = `which flite`;
    chomp $fqfn;
    if ( ( $fqfn =~ /no flite in/ ) || ( $fqfn eq "" ) ) {
        print "Could not find flite in the PATH\n";
        exit;
    }
}
elsif ( $XAP_SOURCE eq "swift" ) {
    $fqfn = `which swift`;
    chomp $fqfn;
    if ( ( $fqfn =~ /no swift in/ ) || ( $fqfn eq "" ) ) {
        if ( -e "/opt/swift/bin/swift" ) {
            $fqfn = "/opt/swift/bin/swift";
        }
        else {
            print "Could not find swift binary";
            exit;
        }
    }
}

print "Using $fqfn for speech\n" if $debug;

my $my_address = lc("$XAP_ME.$XAP_SOURCE.$XAP_INSTANCE");
print "My address is $my_address\n" if $debug;

# Create a broadcast socket for sending data
my $xap_send = new IO::Socket::INET->new(
    PeerPort  => $XAP_PORT,
    Proto     => 'udp',
    PeerAddr  => inet_ntoa(INADDR_BROADCAST),
    Broadcast => 1
) or die "Could not create xap sender\n";

if ($FORCE_LOCAL_HUB) {
    for my $p ( 49152 .. 65535 ) {
        $XAP_PORT = $p;
        last
          if $xap_listen = new IO::Socket::INET->new(
            LocalAddr => 'localhost',
            LocalPort => $p,
            Proto     => 'udp'
          );
    }
}
else {

    $xap_listen = new IO::Socket::INET->new(
        LocalAddr => inet_ntoa(INADDR_ANY),
        LocalPort => $XAP_PORT,
        Proto     => 'udp',
        Broadcast => 1
    );

    # If a hub is not active, bind directly for listening
    if ($xap_listen) {
        print "No hub active.  Listening on broadcast socket ",
          $xap_listen->sockport(), "\n"
          if $debug;
    }
    else {
        # Hub is active.  Loop until we find an available port
        print "Hub is active, search for free relay port\n" if $debug;
        for my $p ( 49152 .. 65535 ) {
            $XAP_PORT = $p;
            last
              if $xap_listen = new IO::Socket::INET->new(
                LocalAddr => 'localhost',
                LocalPort => $p,
                Proto     => 'udp'
              );
        }
        die "Could not create xap listener\n" unless $xap_listen;
        print "Listening on relay socket ", $xap_listen->sockport(), "\n"
          if $debug;
    }
}

&send_heartbeat;

# Do a loop
while (1) {
    select undef, undef, undef, 1.0;    # Sleep a bit
    my $time = time;
    &send_heartbeat if !( $time % $HBEAT_INTERVAL );

    # Check for incoming xap traffic
    my $rin = '';
    vec( $rin, $xap_listen->fileno(), 1 ) = 1;
    if ( select( $rin, undef, undef, 0 ) ) {
        my $xap_rx_msg;
        recv( $xap_listen, $xap_rx_msg, $MAXLEN, 0 ) or die "recv: $!";
        print "\n------------- Incoming message -------------\n$xap_rx_msg\n"
          if $debug;

        ( my $header ) = $xap_rx_msg =~ /xap-header\n\{(.*?)\}/is;
        if ( $header =~ /\nclass\=tts.speak\n/i ) {
            print "header = [$header]\n" if $debug;
            ($target) = $header =~ /target=(.*?)\n/is;
            $target = lc $target;
            print "target=[$target]\n" if $debug;
            if (   ( $target eq "" )
                || ( $target eq "*" )
                || ( $target eq "*." . $XAP_SOURCE . ".*" )
                || ( $target eq $my_address ) )
            {
                &handle_tts_speak($xap_rx_msg);
            }
            else {
                print "Not for me\n" if $debug;
            }
        }
    }
}

sub send_heartbeat {
    print "Sending heartbeat on port ", $xap_send->peerport, "\n" if ($debug);
    print $xap_send
      "xap-hbeat\n{\nv=12\nhop=1\nuid=$XAP_GUID\nclass=xap-hbeat.alive\n"
      . "source=$XAP_ME.$XAP_SOURCE.$XAP_INSTANCE\ninterval=$HBEAT_INTERVAL\nport=$XAP_PORT\npid=$$\n}\n";
}

sub handle_tts_speak {
    my $xap_rx_msg = shift;

    ( my $block ) = $xap_rx_msg =~ /tts.speak\n\{(.*?)\}/is;
    print "block = [$block]\n" if $debug;

    ( my $present, my $say ) = $block =~ /(say)=(.*?)\n/is;
    print "say=[$say]\n" if ( $present && $debug );

    my $volume = 50;    # The SABLE spec says that the default is "medium"
    ( my $present, $volume ) = $block =~ /(volume)=(.*?)\n/is;
    print "volume=[$volume]\n" if ( $present && $debug );

    # The SABLE spec says that the default is the "default gender for the engine";
    ( my $present, my $voice ) = $block =~ /(voice)=(.*?)\n/is;
    print "voice=[$voice]\n" if ( $present && $debug );

    ( my $present, my $priority ) = $block =~ /(priority)=(.*?)\n/is;
    print "priority=[$priority]\n" if ( $present && $debug );

    ( my $present, my $rooms ) = $block =~ /(rooms)=(.*?)\n/is;
    print "rooms=[$rooms]\n" if ( $present && $debug );
    $rooms = lc($rooms);

    if ( ( $rooms eq "" ) || ( $rooms eq "all" ) || ( $rooms eq $room ) ) {
        &speak( $say, $volume, $voice );
    }
}

sub speak {
    my $text   = shift;
    my $volume = shift;
    my $voice  = shift;
    my $cmd;
    $volume = $volume / 100
      ; # SABLE uses a floating point-number between zero and 1 to represent volume.

    #    The SABLE tags are currently not working properly - it's reading them out
    #    $text = "<VOLUME LEVEL=".$volume.">".$text."<VOLUME>" if ($volume != 0.5);
    #    $text = "<SPEAKER GENDER=".$voice.">".$text."</SPEAKER>" if ($voice ne "");

    if ( $XAP_SOURCE eq "festival" ) {
        $cmd = "echo \"$text\" | $fqfn --tts";
    }
    elsif ( $XAP_SOURCE eq "flite" ) {
        $cmd = "$fqfn -t \"$text\"";
    }
    elsif ( $XAP_SOURCE eq "swift" ) {
        $cmd = "$fqfn \"$text\"";
    }
    print "cmd=[$cmd]\n" if $debug;
    print "cmd=[$cmd]\n";
    system $cmd;
}
