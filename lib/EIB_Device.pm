
=head1 B<EIB_Device>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Misterhouse EIB interface for the EIB Linux kernel driver from TU Wien.

EIB/KNX website: http://konnex.org

TU Wien, System Automation, Automation Systems Group:  http://www.auto.tuwien.ac.at/~mkoegler/index.php/eibd

Notes:

    Tested with BCU1 (Bus Coupling Unit 1) on the following platforms:
        Red Hat 9 (linux kernel version 2.4.20-8), EIB driver version 0.2.4
        Fedora Core 3 (linux kernel version 2.6.13), EIB driver version 0.2.6.2
    eibd tested with BCU2 backend on
        Gentoo Linux (kernel 2.6.23), bcusdk-0.0.3

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;
use Fcntl;
eval "use bytes";    # Not on all installs, so eval to avoid errors

package EIB_Device;

# Configuration variables
my $started;          # True if running already
my $EibdProto;        # Protocol to connect to eibd
my $EibdProtoInfo;    # Protocol specific info

sub startup {
    return if $started++;
    die
      "Parameter eib_device has changed to eib_connection!\nPlease change ini file!\n\n"
      if $::config_parms{eib_device};
    return unless my $dev = $::config_parms{eib_connection};   # Is EIB enabled?
    printf " - initializing EIB connection to '$dev' ...";
    &main::print_log("Initializing EIB connection");
    if ( $dev =~ /(.+):(.+)/ ) {

        # Using eibd communication
        die "EIB: Only ip supported on eibd communication" unless $1 eq "ip";
        $EibdProto     = $1;
        $EibdProtoInfo = $2;
        die "Can't communicate with EIB" unless openEIBSocket();
        &::MainLoop_pre_add_hook( \&EIB_Device::check_for_eibddata, 1 );
    }
    else {
        # Using direct BCU1 communication
        sysopen EIB, $dev, Fcntl::O_RDWR | Fcntl::O_BINARY
          or die "EIB: Can't open " . $dev;
        initdevice($dev);
        &::Exit_add_hook( \&EIB_Device::resetdevice, 1 );
        &::MainLoop_pre_add_hook( \&EIB_Device::check_for_data, 1 );
    }
    printf(" ok\n");
}

# Initialize BCU device
sub initdevice {
    writedev("\x46\x01\x00\x60\x12");    # access data link layer
    writedev("\x46\x01\x01\x16\x00")
      ;    # set zero length address mapping table, to snoop all datagrams
}

# Reset BCU device
sub resetdevice {
    writedev("\x46\x01\x00\x60\xc0");    # BCU reset
}

# Write a string to BCU
sub writedev {
    my ($str) = @_;
    die "EIB BCU write failure"
      unless syswrite( EIB, $str, bytes::length($str) );
}

my @outqueue = ();    # Queue of messages to be sent
my $count    = 0;     # Number of passes since last message sent

# Handle device I/O: Read and write messages on the bus
sub check_for_data {
    my ( $rin, $rout, $ein, $eout, $win, $wout );
    my ( $nfound, $nread );
    my ($buf);

    # Check for input
    $rin = $win = $ein = '';
    vec( $rin, fileno(EIB), 1 ) = 1;
    $ein = $rin;
    ($nfound) = select( $rout = $rin, undef, undef, 0 );
    if ( $nfound > 0 ) {
        if ( ( sysread( EIB, $buf, 32 ) ) > 0 ) {
            my $msg = decode($buf);
            EIB_Item::receive_msg($msg);
        }
    }

    # Check for output
    $count++ unless $count > $::config_parms{eib_send_interval};
    if ( ( $#outqueue >= 0 ) && $count >= $::config_parms{eib_send_interval} ) {
        $count = 0;
        my $mref = shift @outqueue;
        writedev( encode($mref) );
    }
}

# send_msg: Send a message -- store it in output queue.
sub send_msg {
    my ($mref) = @_;
    push @outqueue, ($mref);
}

# addr2str: Convert an integer to an EIB address string, in the form "1/2/3" or "1.2.3"
sub addr2str {
    my $a = $_[0];
    my $b = $_[1];    # 1 if local (group) address, else physical address
    my $str;
    if ( $b == 1 ) {    # logical address used
        $str = sprintf "%d/%d/%d", ( $a >> 11 ) & 0xf, ( $a >> 8 ) & 0x7,
          $a & 0xff;
    }
    else {              # physical address used
        $str = sprintf "%d.%d.%d", $a >> 12, ( $a >> 8 ) & 0xf, $a & 0xff;
    }
    return $str;
}

# str2addr: Convert an EIB address string in the form "1/2/3" or "1.2.3" to an integer
sub str2addr {
    my $str = $_[0];
    if ( $str =~ /(\d+)\/(\d+)\/(\d+)/ ) {    # logical address
        return ( $1 << 11 ) | ( $2 << 8 ) | $3;
    }
    elsif ( $str =~ /(\d+)\.(\d+)\.(\d+)/ ) {    # physical address
        return ( $1 << 12 ) | ( $2 << 8 ) | $3;
    }
    else {
        print "Bad EIB address string: \'$str\'\n";
        return;
    }
}

# addrIsLogical: Is an EIB address logical, i.e. in the form "1/2/3"
sub addrIsLogical {
    my $str = $_[0];
    return ( $str =~ /(\d+)\/(\d+)\/(\d+)/ );
}

# For mapping between APCI symbols and values
my @apcicodes = ( 'read', 'reply', 'write' );
my %apcivalues = ( 'read' => 0, 'reply' => 1, 'write' => 2, );

# decode: unmarshall a string with an EIB message into a hash
# The hash has the follwing fields:
#	- type: APCI (symbolic value)
#	- src: source address
#	- dst: destiniation address
#	- data: array of integers; one for each byte of data
sub decode {
    my ($buf) = @_;
    my %msg;
    my @data;
    my ( $type, $src, $dst, $drl, $bytes ) = unpack( "CxnnCxa*", $buf );
    my $apci;

    $apci = vec( $bytes, 3, 2 );

    # mask out apci bits, so we can use the whole byte as data:
    vec( $bytes, 3, 2 ) = 0;
    if ( $apci >= 0 && $apci <= $#apcicodes ) {
        $msg{'type'} = $apcicodes[$apci];
    }
    else {
        $msg{'type'} = 'apci ' . $apci;
    }

    $msg{'src'} = addr2str($src);
    $msg{'dst'} = addr2str( $dst, $drl >> 7 );

    @data = unpack( "C" . bytes::length($bytes), $bytes );
    $msg{'data'} = \@data;
    $msg{'buf'} = unpack( "H*", $buf ) if $main::config_parms{eib_errata} >= 4;
    return \%msg;
}

# encode: marshall a hash into a EIB message string
sub encode {
    my ($mref) = @_;
    my @msg;
    my $APCI;
    my $data;

    $APCI = $apcivalues{ $mref->{'type'} };
    if ( !( defined $APCI ) ) {
        printf "Bad EIB message type '%s'\n", $mref->{'type'};
        return;
    }
    $data = $mref->{'data'};
    @msg  = (
        0x11,                          # L_Data.req
        0x04,                          # Control field -- priority class high
        0x0000,                        # Source address, leave blank
        str2addr( $mref->{'dst'} ),    # Destination address
        0x60 | ( $#$data + 1 ) |       # Routing, length and
          ( addrIsLogical( $mref->{'dst'} ) << 7 ),    # address type
        0x0 | ( $APCI >> 2 ),    # TPDU type, Sequence no, APCI (msb)
        ( ( $APCI & 0x3 ) << 6 ) | $$data[0],
    );
    if ( $#$data > 0 ) {
        push @msg, @$data[ 1 .. $#$data ];
    }
    return ( pack "CCnnC" . ( $#msg - 3 ), @msg );
}

#
# eibd communication part
#
my $EIBSock;
my $EibdConnectionError = 0;

sub openEIBSocket {

    # Connect to eibd to listen for group communication
    &main::print_log("Opening EIB connection")
      if $main::config_parms{eib_errata} >= 9;
    if ( $EIBSock = connectEIB() ) {
        &main::print_log("Opening group socket")
          if $main::config_parms{eib_errata} >= 9;
        openGroupSocket($EIBSock);
    }
}

# Write a string to eibd
sub writeeibd {
    my ($data) = @_;

    my ( $src, $dst, $daf, $bytes ) = unpack( "xxnnCa*", $data );

    if ( $daf & 0x80 ) {

        # Group communication

        my $srctxt = addr2str($src);
        my $dsttxt = addr2str( $dst, 1 );

        sendGroup( $EIBSock, $dst, $bytes );
    }
    else {
        print "Only group communication is supported!\n";
    }
}

# Connect to eibd
# Returns open socket
sub connectEIB {
    my $Sock;
    if (
        $Sock = new IO::Socket::INET->new(
            PeerAddr => $EibdProtoInfo,
            PeerPort => 6720,
            Proto    => 'tcp'
        )
      )
    {
        if ($EibdConnectionError) {
            print "Eibd communictaion re-established\n";
            $EibdConnectionError = 0;
        }
        return $Sock;
    }
    else {
        if ( !$EibdConnectionError ) {
            print "Connect to eibd via $EibdProto:$EibdProtoInfo failed\n";
            $EibdConnectionError = 1;
        }
        return undef;
    }
}

# Functions four group socket communication
# Open a group socket for group communication
# openGroupSocket SOCK
sub openGroupSocket {
    my $Sock = shift;

    my @msg = ( 0x0026, 0x0000, 0x00 );    # EIB_OPEN_GROUPCON
    sendRequest( $Sock, pack "nnC", @msg );
    goto error unless my $answer = getRequest($Sock);
    my $head = unpack( "n", $answer );
    goto error unless $head == 0x0026;
    return 1;

    error:
    print "openGroupSocket failed\n";
    return undef;
}

# Send group data
# sendGroup SOCK DEST DATA
sub sendGroup {
    my $Sock  = shift;
    my $Dest  = shift;
    my ($str) = @_;

    #print "SendGroupPacket: ", unpack("H*",$str), "\n";

    my @msg = ( 0x0027, $Dest );    # EIB_GROUP_PACKET
    push @msg, $str;
    sendRequest( $Sock, pack "nna*", @msg );
    return 1;

    error:
    print "sendGroup failed\n";
    return undef;
}

# Receive group data
# getGroup_Src SOCK
sub getGroup_Src {
    my $Sock = shift;

    goto error unless my $buf = getRequest($Sock);
    my ( $head, $data ) = unpack( "na*", $buf );
    goto error unless $head == 0x0027;

    return $data;

    error:
    print "getGroup_Src failed\n";
    return undef;
}

# Sends a request to eibd
# sendRequest SOCK,DATA
sub sendRequest {
    my $Sock = shift;
    my ($str) = @_;

    #print "Sending packet: ", unpack("H*",$str), "\n";
    my $size = bytes::length($str);
    my @head = ( ( $size >> 8 ) & 0xff, $size & 0xff );
    return undef unless syswrite $Sock, ( pack "CC", @head );
    return undef unless syswrite $Sock, $str;
}

# Gets a request from eibd
# DATA = getRequest SOCK
sub getRequest {
    my $Sock = shift;
    my ($data);
    goto error unless sysread $Sock, $data, 2;
    my $size = unpack( "n", $data );
    goto error unless sysread $Sock, $data, $size;

    #print "Received packet: ", unpack("H*",$data), "\n";
    return $data;

    error:
    printf "eibd communication failed\n";
    return undef;
}

# Handle device I/O: Read and write messages on the bus
sub check_for_eibddata {
    my ( $rin, $rout, $ein, $eout, $win, $wout );
    my ( $nfound, $nread );
    my ($buf);

    openEIBSocket() unless $EIBSock;
    if ($EIBSock) {

        # Check for input
        $rin = $win = $ein = '';
        vec( $rin, fileno($EIBSock), 1 ) = 1;
        $ein = $rin;
        ($nfound) = select( $rout = $rin, undef, undef, 0 );
        if ( $nfound > 0 ) {
            if ( my $buf = getGroup_Src($EIBSock) ) {

                # Modify data to make it compatible to data from BCU1
                my @tmpdat = unpack( "nna*", $buf );
                my $data = pack "CCnnCa*", 0xbc, 0x00, $tmpdat[0], $tmpdat[1],
                  0xe1, $tmpdat[2];

                #print "Modified packet: ", unpack("H*",$data), "\n";
                my $msg = decode($data);
                EIB_Item::receive_msg($msg) unless $msg->{'src'} eq "0.0.0";
            }
            else {
                # Close socket in case of errors
                close $EIBSock;
                $EIBSock = undef;
            }
        }
    }

    openEIBSocket() unless $EIBSock;
    if ($EIBSock) {

        # Check for output
        $count++ unless $count > $::config_parms{eib_send_interval};
        if ( ( $#outqueue >= 0 )
            && $count >= $::config_parms{eib_send_interval} )
        {
            $count = 0;
            my $mref = shift @outqueue;
            if ( !writeeibd( encode($mref) ) ) {

                # Close socket in case of errors
                close $EIBSock;
                $EIBSock = undef;
            }
        }
    }
}

return 1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

  09/09/2005  Created by Peter Sjödin peter@sjodin.net
  20060205    Added EIB access via eibd by Mike Pieper eibdmh@pieper-family.de
  20090721    Overworked eibd communication by Mike Pieper eibdmh@pieper-family.de
              eib_device --> eib_connection to avoid clash with generic device
              using only one group socket

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

