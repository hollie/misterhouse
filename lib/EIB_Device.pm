=begin comment

EIB_Device.pm - Misterhouse EIB interface for the EIB Linux kernel driver
                from TU Wien.

Info:

EIB/KNX website:
    http://konnex.org

TU Wien, System Automation, Automation Systems Group:
    http://www.auto.tuwien.ac.at/~mkoegler/index.php/eibd

Notes:
    Tested with BCU1 (Bus Coupling Unit 1) on the following platforms:
        Red Hat 9 (linux kernel version 2.4.20-8), EIB driver version 0.2.4
        Fedora Core 3 (linux kernel version 2.6.13), EIB driver version 0.2.6.2
    eibd tested with BCU2 backend on
        Gentoo Linux (kernel 2.6.14), bcusdk-0.0.1

Authors:
 09/09/2005  Created by Peter Sjödin peter@sjodin.net
 20060205    Added EIB access via eibd by Mike Pieper eibdmh@pieper-family.de

=cut


use strict;
use Fcntl;
use bytes;

package EIB_Device;

# Configuration variables
my $started;	    # True if running already
my $EibdProto;	    # Protocol to connect to eibd
my $EibdProtoInfo;  # Protocol specific info

sub startup {
    return if $started++;
    return unless my $dev = $::config_parms{eib_device}; # Is EIB enabled?
    if ($dev =~ /(.+):(.+)/) {
                                # Using eibd communication
        die "EIB: Only ip supported on eibd communication" unless $1 eq "ip";
        $EibdProto = $1;
        $EibdProtoInfo = $2;
        die "Can't communicate with EIB" unless openMonitor ();
        &::MainLoop_pre_add_hook(\&EIB_Device::check_for_eibddata, 1);
    } else {
                                # Using direct BCU1 communication
        sysopen EIB, $dev, Fcntl::O_RDWR|Fcntl::O_BINARY or die "EIB: Can't open " . $dev;
        initdevice($dev);
        &::Exit_add_hook(\&EIB_Device::resetdevice, 1);
        &::MainLoop_pre_add_hook(\&EIB_Device::check_for_data, 1);
    }
   &main::print_log( "EIB device \"$dev\" initialized");
}

# Initialize BCU device
sub initdevice {
    writedev("\x46\x01\x00\x60\x12"); # access data link layer
    writedev("\x46\x01\x01\x16\x00"); # set zero length address mapping table, to snoop all datagrams
}

# Reset BCU device
sub resetdevice {
    writedev("\x46\x01\x00\x60\xc0"); # BCU reset
}

# Write a string to BCU
sub writedev {
    my ($str) = @_;
    die "EIB BCU write failure" unless syswrite(EIB, $str, bytes::length($str));
 }

my @outqueue = (); # Queue of messages to be sent
my $count = 0; # Number of passes since last message sent

# Handle device I/O: Read and write messages on the bus
sub check_for_data {
    my ($rin, $rout, $ein, $eout, $win, $wout);
    my ($nfound, $nread);
    my ($buf);

    # Check for input
    $rin = $win = $ein = '';
    vec($rin, fileno(EIB), 1) = 1;
    $ein = $rin;
    ($nfound) = select($rout=$rin, undef,  undef, 0);
    if ($nfound > 0) {
	if ((sysread(EIB, $buf, 32)) > 0) {
	    my $msg = decode($buf);
	    EIB_Item::receive_msg($msg);
	}
    }

    # Check for output
    $count++ unless $count > $::config_parms{eib_send_interval};
    if (($#outqueue >= 0) && $count >= $::config_parms{eib_send_interval}) {
	$count = 0;
	my $mref = shift @outqueue;
	writedev(encode ($mref));
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
    my $b = $_[1];  # 1 if local (group) address, else physical address
    my $str ;
    if ($b == 1) { # logical address used
        $str = sprintf "%d/%d/%d", ($a >> 11) & 0xf, ($a >> 8) & 0x7, $a & 0xff;
    }
    else { # physical address used
        $str = sprintf "%d.%d.%d", $a >> 12, ($a >> 8) & 0xf, $a & 0xff;
    }
    return $str;
}

# str2addr: Convert an EIB address string in the form "1/2/3" or "1.2.3" to an integer
sub str2addr {
    my $str = $_[0];
    if ($str =~ /(\d+)\/(\d+)\/(\d+)/) { # logical address
        return ($1 << 11) | ($2 << 8) | $3;
    }
    elsif ($str =~ /(\d+)\.(\d+)\.(\d+)/) { # physical address
        return ($1 << 12) | ($2 << 8) | $3;
    }
    else
    {
	print "Bad EIB address string: \'$str\'\n";
	return;
    }
}

# addrIsLogical: Is an EIB address logical, i.e. in the form "1/2/3"
sub addrIsLogical {
    my $str = $_[0];
    return ($str =~ /(\d+)\/(\d+)\/(\d+)/)
}


# For mapping between APCI symbols and values
my @apcicodes = ('read', 'reply', 'write');
my %apcivalues = ('read' => 0, 'reply' => 1, 'write' => 2,);

# decode: unmarshall a string with an EIB message into a hash
# The hash has the follwing fields:
#	- type: APCI (symbolic value)
#	- src: source address
#	- dst: destiniation address
#	- data: array of integers; one for each byte of data
sub decode{
    my ($buf) = @_;
    my %msg;
    my @data;
    my ($type, $src, $dst, $drl, $bytes) = unpack("CxnnCxa*", $buf);
    my $apci;

    $apci = vec($bytes, 3, 2);
# mask out apci bits, so we can use the whole byte as data:
    vec($bytes, 3, 2) = 0;
    if ($apci >= 0 && $apci <= $#apcicodes) {
	$msg{'type'} = $apcicodes[$apci];
    }
    else {
	$msg{'type'} = 'apci ' . $apci;
    }

    $msg{'src'} = addr2str($src);
    $msg{'dst'} = addr2str($dst, $drl>>7);

    @data = unpack ("C" . bytes::length($bytes), $bytes);
    $msg{'data'} = \@data;
    $msg{'buf'} = unpack ("H*", $buf) if $main::config_parms{eib_errata} >= 4;
    return \%msg;
}

# encode: marshall a hash into a EIB message string
sub encode {
    my ($mref) = @_;
    my @msg;
    my $APCI;
    my $data;

    $APCI = $apcivalues{$mref->{'type'}};
    if (!(defined $APCI)) {
	printf "Bad EIB message type '%s'\n", $mref->{'type'};
	return;
    }
    $data = $mref->{'data'};
    @msg = (0x11, 			# L_Data.req
	    0x04, 			# Control field -- priority class high
	    0x0000, 			# Source address, leave blank
	    str2addr( $mref->{'dst'}), 	# Destination address
	    0x60 | ($#$data + 1) | 	# Routing, length and
	    (addrIsLogical( $mref->{'dst'} ) << 7),   # address type
	    0x0 | ($APCI >> 2), 	# TPDU type, Sequence no, APCI (msb)
	    (($APCI & 0x3) << 6) | $$data[0],
	    );
    if ($#$data > 0) {
	push @msg, @$data[1..$#$data];
    }
    return (pack "CCnnC" . ($#msg - 3), @msg);
}

#
# eibd communication part
#
my $MonSock;
my $EibdConnectionError = 0;

sub openMonitor {
    # Connect to eibd to listen on the bus
    if ($MonSock = connectEIB ()) {
	openVBusmonitor ($MonSock);
    }
}

# Write a string to eibd
sub writeeibd {
    my ($data) = @_;

    my ($src, $dst, $daf, $bytes) = unpack ("xxnnCa*", $data);

    return unless my $Sock = connectEIB();

    if ($daf & 0x80) {
	# Group communication

	my $srctxt = addr2str ($src);
	my $dsttxt = addr2str ($dst, 1);

	openT_Group ($Sock, $dst);
	sendAPDU ($Sock, $bytes);
    } else {
	printf "Physical destination address not tested\n";
	openT_TPDU ($Sock, 0);
	sendTPDU ($Sock, $dst, $bytes);
    }
}

# Connect to eibd
# Returns open socket
sub connectEIB {
    my $Sock;
    if ($Sock = new IO::Socket::INET->new(PeerAddr => $EibdProtoInfo,
					  PeerPort => 6720,
					  Proto    => 'tcp')) {
	if ($EibdConnectionError) {
	    print "Eibd communictaion re-established\n";
	    $EibdConnectionError = 0;
	}
	return $Sock
    } else {
	if (!$EibdConnectionError) {
	    print "Connect to eibd via $EibdProto:$EibdProtoInfo failed\n";
	    $EibdConnectionError = 1;
	}
	return undef;
    }
}

# Open group
sub openT_Group {
    my $Sock = shift;
    my $destAddr = shift;

    # print "openT_Group\n";

    my @msg = (0x0022,			# EIB_OPEN_T_GROUP
	       $destAddr,
	       0x00);
    sendRequest ($Sock, pack ("nnC", @msg));
    goto error unless my $answer = getRequest ($Sock);
    my $head = unpack ("n", $answer);
    goto error unless $head == 0x0022;
    return 1;

  error:
    printf "openT_Group failed\n";
    return undef;
}

# Open layer 4 connection
# Expects source address
sub openT_TPDU {
    my $Sock = shift;
    my $srcAddr = shift;

    # print "OpenT_TPDU\n";

    my @msg = (0x0024,			# EIB_OPEN_T_TPDU
	       $srcAddr,
	       0x00);
    sendRequest ($Sock, pack ("nnC" ,@msg));
    goto error unless my $answer = getRequest ($Sock);
    my $head = unpack ("n", $answer);
    goto error unless $head == 0x0024;
    return 1;

  error:
    print "openT_TPDU failed\n";
    return undef;
}

# Activate virtual bus monitor
# openVBusmonitor SOCK
sub openVBusmonitor {
    my $Sock = shift;

    # print "OpenVBusmonitor\n";

    my @msg = (0x0012);			# EIB_OPEN_T_TPDU
    sendRequest ($Sock, pack "n" ,@msg);
    goto error unless my $answer = getRequest ($Sock);
    my $head = unpack ("n", $answer);
    goto error unless $head == 0x0012;
    return 1;

  error:
    print "openVBusmonitor failed\n";
    return undef;
}

# Send an APDU packet
# sendAPDU DATA
sub sendAPDU {
    my $Sock = shift;
    my ($str) = @_;

    my @msg = (0x0025);			# EIB_APDU_PACKET
    push @msg, $str;

    sendRequest ($Sock, pack "na*", @msg);
}

# Send a TPDU packet
# Expects destAddr, data
sub sendTPDU {
    my $Sock = shift;
    my $destAddr = shift;
    my ($str) = @_;

    # my $strDestAddr = addr2str ($destAddr, 1);
    # print "sendTPDU to $strDestAddr\n";

    my @msg = (0x0025,			# EIB_APDU_PACKET
	       $destAddr);
    push @msg, $str;

    sendRequest ($Sock, pack "nnC*", @msg);
}

# Gets a packet from bus monitor
# DATA = getBusmonitorPacket SOCK
sub getBusmonitorPacket {
    my $Sock = shift;

    goto error unless my $buf = getRequest ($Sock);
    my ($head, $data) = unpack ("na*", $buf);
    goto error unless $head == 0x0014;

    # Modify data to make it compatible to data from BCU1
    my @tmpdat = unpack ("C" . (bytes::length($data)-1), $data);
    $data = pack "CCC" . $#tmpdat, $tmpdat[0], 0, @tmpdat[1..$#tmpdat];

    return $data;

  error:
    print "getBusmonitorPacket failed\n";
    return undef;
}

# Sends a request to eibd
# sendRequest SOCK,DATA
sub sendRequest {
    my $Sock = shift;
    my ($str) = @_;
    my $size = bytes::length($str);
    my @head = (($size >> 8) & 0xff, $size & 0xff);
    return undef unless syswrite $Sock, (pack "CC", @head);
    return undef unless syswrite $Sock, $str;
}

# Gets a request from eibd
# DATA = getRequest SOCK
sub getRequest {
    my $Sock = shift;
    my ($data);
    goto error unless sysread $Sock, $data, 2;
    my $size = unpack ("n", $data);
    goto error unless sysread $Sock, $data, $size;
    return $data;

  error:
    printf "eibd communication failed\n";
    return undef;
}


# Handle device I/O: Read and write messages on the bus
sub check_for_eibddata {
    my ($rin, $rout, $ein, $eout, $win, $wout);
    my ($nfound, $nread);
    my ($buf);


    openMonitor () unless $MonSock;
    if ($MonSock) {
	# Check for input
	$rin = $win = $ein = '';
	vec($rin, fileno($MonSock), 1) = 1;
	$ein = $rin;
	($nfound) = select($rout=$rin, undef,  undef, 0);
	if ($nfound > 0) {
	    if (my $buf = getBusmonitorPacket ($MonSock)) {
		my $msg = decode($buf);
		EIB_Item::receive_msg($msg);
	    } else {
		# Close socket in case of errors
		close $MonSock;
		$MonSock = undef;
	    }
	}
    }

    # Check for output
    $count++ unless $count > $::config_parms{eib_send_interval};
    if (($#outqueue >= 0) && $count >= $::config_parms{eib_send_interval}) {
	$count = 0;
	my $mref = shift @outqueue;
	writeeibd(encode ($mref));
    }
}



return 1;
