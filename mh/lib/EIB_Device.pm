=begin comment

EIB_Device.pm - Misterhouse EIB interface for the EIB Linux kernel driver from TU Wien.

Info:

EIB/KNX website:
    http://konnex.org

TU Wien, System Automation, Automation Systems Group:
    http://www.auto.tuwien.ac.at/knx

Notes:
    Tested with BCU1 (Bus Coupling Unit 1) on the following platforms:
        Red Hat 9 (linux kernel version 2.4.20-8), EIB driver version 0.2.4
        Fedora Core 3 (linux kernel version 2.6.13), EIB driver version 0.2.6.2

Authors:
 09/09/2005  Created by Peter Sjödin peter@sjodin.net

=cut


use strict;
use Fcntl;
use bytes;

package EIB_Device;

# Configuration variables
my $started;	# True if running already

sub startup {
    return if $started++;
    return unless my $dev = $::config_parms{eib_device}; # Is EIB enabled?
    sysopen EIB, $dev, Fcntl::O_RDWR|Fcntl::O_BINARY or die "EIB: Can't open " . $dev;
    initdevice($dev);
    &::Exit_add_hook(\&EIB_Device::resetdevice, 1);
    &::MainLoop_pre_add_hook(\&EIB_Device::check_for_data, 1);
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

# addr2str: Convert an integer to an EIB address string, on the form "1/2/3"
sub addr2str {
    my $a = $_[0];
    my $str = sprintf "%d/%d/%d", $a >> 11, ($a >> 8) & 0x7, $a & 0xff;
    return $str;
}

# str2addr: Convert an EIB address string the form "1/2/3" to an integer
sub str2addr {
    my $str = $_[0];
    if (!($str =~ /(\d+)\/(\d+)\/(\d+)/)) {
	print "Bad EIB address string: \'$str\'\n";
	return;
    }
    return ($1 << 11) | ($2 << 8) | $3;
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
    my ($type, $src, $dst, undef, $bytes) = unpack("CxnnxCa*", $buf);
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
    $msg{'dst'} = addr2str($dst);

    @data = unpack ("C" . bytes::length($bytes), $bytes);
    $msg{'data'} = \@data;
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
	    0x00, 			# Control field -- priority class 0
	    0x0000, 			# Source address, leave blank
	    str2addr( $mref->{'dst'}), 	# Destination address
	    0xe0 | ($#$data + 1), 	# Address type, routing, length
	    0x0 | ($APCI >> 2), 	# TPDU type, Sequence no, APCI (msb)
	    (($APCI & 0x3) << 6) | $$data[0],
	    );
    if ($#$data > 0) {
	push @msg, @$data[1..$#$data];
    }
    return (pack "CCnnC" . ($#msg - 3), @msg);
}

return 1;
