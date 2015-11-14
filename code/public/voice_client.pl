
=begin comment

voice_client.pl
 1.2 Added ping functionality - TD - 11/14/2001
 1.1 Added auto-reconnect functionality - Tim Doyle - 11/13/2001
 1.0 Original version by Tim Doyle <tim@greenscourt.com> - 10/31/2001

This script is designed to run on a remote machine and connect to
a socket created by the voice_server.pl script running in MisterHouse.
The voice_server.pl script echos all text spoken and the names of all
sound files played to the socket, and this script grabs it and sends
it to the msv5 speech engine.

This script currently only supports MS TTS v4 and v5.

Usage is voice_client.pl host:port password
If host:port are omitted, you will be prompted for them.

Ctrl-C to exit.

Enhancement List:

- Better multiple machine solution - use select()?
- graceful disconnect
- Revisit argument functionality

=cut

use strict;
use WIN32::OLE;
use Win32::Sound;
use IO::Socket;
use IO::Select;

my (
    $host, $port,     $VTxt,       $VTxt_version, $VTxt_stream,
    $data, $password, $askforpass, $socket
);
my ( $sel, $attempts, $connected, $rh, $buf, @ready );

# Get host and port
( $host, $port ) = @ARGV[0] =~ /(.*):(.*)/;
$password = @ARGV[1];

if ( $host eq '' ) {
    print "Voice Server Host (i.e. machine.location.com): ";
    $host = <STDIN>;
    chop $host;
    $askforpass = 1;
}

if ( $port eq '' ) {
    print "Voice Server port (i.e. 23): ";
    $port = <STDIN>;
    chop $port;
}

if ( $askforpass == 1 ) {
    print "Voice Server password (can be blank): ";
    $password = <STDIN>;
    chop $password;
}

# Open Speech Engine
if ( $VTxt = Win32::OLE->new('Sapi.SpVoice') ) {
    $VTxt_version = 'msv5';
    $VTxt_stream  = Win32::OLE->new('Sapi.SpFileStream');
}
else {
    $VTxt = Win32::OLE->new('Speech.VoiceText');
    die "Couldn't open speech engine" unless $VTxt;
    $VTxt->Register( "Local PC", "perl voice_client.pl" );
}

$|++;

$socket =
  new IO::Socket::INET( PeerAddr => $host, PeerPort => $port, Proto => 'tcp' )
  or die "\nCould not create socket to $host port $port: $!\n";

$sel = new IO::Select($socket);

&SendPassword($password);

while (1) {
    @ready = $sel->can_read(120);    #120 second time-out

    if ( @ready == 0 ) {
        &ProcessData("Warning, socket stale.");
        &Reconnect;
    }

    foreach $rh (@ready) {
        $buf = <$rh>;
        if ($buf) {
            &ProcessData($buf);
        }
        else {
            close($rh);
            &Reconnect;
        }
    }
}

sub Reconnect {

    #    &speak("Connection closed. Attempting to reconnect");

    $attempts  = 0;
    $connected = 0;
    while ( $connected == 0 ) {
        $attempts = $attempts + 1;

        #        &speak("Attempt $attempts");
        $socket = new IO::Socket::INET(
            PeerAddr => $host,
            PeerPort => $port,
            Proto    => 'tcp'
        );
        if ( $attempts == 10 ) {
            &speak("Failed to reconnect, ending program");
            sleep 2;
            die "Failed to reconnect to MisterHouse Voice Server";
        }
        if ( $socket ne '' ) {
            $connected = 1;
        }
        else {
            sleep 10;
        }
    }
    $sel = new IO::Select($socket);
    &SendPassword($password);
}

sub SendPassword {

    #Need to add a can_write here - if we send too early, we can lock up

    my ($password) = @_;
    $password = pack( "u", "voiceclient:$password" );
    print $socket "Authorization: Basic $password\n\n";
}

sub ProcessData {
    my ($data) = @_;
    chop $data;
    chop $data;

    if ( $data eq 'PING' ) {
        $data = '';
    }

    if ( $data eq 'RELOAD' ) {
        &Reconnect;
        $data = '';
    }

    if ( $data =~ /PLAY: (.*)/ ) {
        my $file = "$1";
        if ( $file ne '' ) {
            my $time_now =
              sprintf( "%2d:%02d", (localtime)[2], (localtime)[1] );
            print "$time_now Playing file $file\n";
            Win32::Sound::Play( $file, 0 | SND_NOSTOP );
        }
        $data = '';
    }
    if ( $data ne '' ) {
        &speak($data);
    }
}

sub speak {
    my ($text) = @_;

    my $time_now = sprintf( "%2d:%02d", (localtime)[2], (localtime)[1] );
    print "$time_now $text\n";
    if ( $VTxt_version eq 'msv5' ) {

        #$text = "<pitch absmiddle='5'/> " . $text;
        #$text = "<rate absspeed='0'/> " . $text;
        #$text = "<volume level='100'/> " . $text;
        #$text = "<voice required='Name=Sample TTS voice'/> " . $text;
    }
    $VTxt->Speak( $text, 0 );
}

sub uuencode {
    my ($string) = @_;
    return pack( "u", $string );
}

