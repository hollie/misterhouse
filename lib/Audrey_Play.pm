use strict;

package Audrey_Play;

=head1 NAME

B<Audrey_Play> - This object can be used to play sound files on the Audrey.

=head1 SYNOPSIS

Created for use with PAobj.pm, but can be used separately.

=head1 DESCRIPTION

Tells an Audrey to download and play a file, already in the data/web folder,
by passing the name of the file. The Audrey must be modified to respond to
this request.

$audrey1 = new Audrey_Play('192.168.0.11');
#Create file data/web/tempfile.wav - perhaps by speaking to a file?
my $speakFile = 'tempfile.wav';
$audrey1->play($speakFile);

=head1 INHERITS

B<Generic_Item>

=over

=cut

@Audrey_Play::ISA = ('Generic_Item');

my $address;

=item C<new($ip)>

$ip is the IP address of the Audrey.

=cut

sub new {
    my ( $class, $ip ) = @_;
    my $self = {};
    $self->{address} = $ip;

    if ($ip) {
        &::print_log("Creating Audrey_Play object...");
    }
    else {
        warn 'Empty expression is not allowed.';
    }

    bless $self, $class;
    return $self;
}

sub play {
    my ( $self, $web_file ) = @_;
    &::print_log("Called 'play' in Audrey_Play object...");
    my $MHWeb = $::Info{IPAddress_local} . ":" . $::config_parms{http_port};
    &::print_log($MHWeb);
    &::run( "get_url -quiet http://"
          . $self->{address}
          . "/mhspeak.shtml?http://"
          . $MHWeb . "/"
          . $web_file
          . " /dev/null" );
}

1;

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

=begin Audrey Config

Exerpt from audreyspeak.pl

You must make certain modifications to your Audrey, as follows:

- Update the software and obtain root shell access capabilities (this
  should be available by using Bruce's CF card image or by following
  instructions available on the internet.)

- Open the Audrey's web server to outside http requests
  1) Start the "Root Shell"
  2) type: cd /config
  3) type: cp rm-apps rm-apps.copy
  4) type: vi rm-apps
     You'll be in the editor, editing the "rm-apps" file
     About the 14th line down is "rb,/kojak/kojak-slinger, -c -e -s -i 127.1"
     You need to delete the "-i 127.1" from the line.
     To do this, place the cursor under the space right after the "-s"
     Type the "x" key to start deleting from the line.
     The line should end up looking like this:
     "rb,/kojak/kojak-slinger, -c -e -s"
     If you need to start over type a colon to get to the vi command line
     At the colon prompt type "q!" and hit "enter" (this quits without saving)
     If it looks good then at the colon prompt type "wq" to save changes
     Now restart the Audrey by unplugging it, waiting 30 seconds and
     plugging it back in.

- Install playsound_noph and it's DLL
  1) Grab the zip file from http://www.planetwebb.com/audrey/
  2) Place playsound_noph    on the Audrey in /nto/photon/bin/
  3) Place soundfile_noph.so on the Audrey in /nto/photon/dll/

- Install mhspeak.shtml on the Audrey
  1) Start the "Root Shell"
  2) type: cd /data/XML
  3) type: ftp blah.com mhspeak.shtml

     The MHSPEAK.SHTML file placed on the Audrey should contain the following:

     <html>
     <head>
     <title>Shell</title>
     </head>
     <body>
     <!--#config cmdecho="OFF" -->
     <!--#exec cmd="playsound_noph $QUERY_STRING &" -->
     </body>
     </html>

=cut
