########################################################################
#
# Module: Lynx10PLC.pm
#
# Copyright (c) 2001 Joe Blecher. All rights reserved.
# This program is free software.  You may modify and/or
# distribute it under the same terms as Perl itself.
# This copyright notice must remain attached to the file.
#
# Author: Joe Blecher  misterhouse@blecherfamily.net
#
# This module implements code to support the Marrick Lynx10-PLC 
# controller. See http://www.marrickltd.com/LynX105.htm
#
# Note: This module adds additional capability to the MisterHouse 
#       application written by Bruce Winter (winter@misterhouse.net). 
#
# To use this interface, add the following lines (localized, of course)
# to your mh.ini file:
#
# Lynx10PLC_port=/dev/ttyS0
# Lynx10PLC_baudrate=19200
# Lynx10PLC_module = Lynx10PLC
#
########################################################################

use strict;
package Lynx10PLC;

########################################################################
# Lynx10-PLC Definitions

# Network ID Definitions     	
use constant NETID_NACK    => 0x00;
use constant NETID_ACK     => 0x01;
use constant NETID_UNDEF   => 0x02;
use constant NETID_X10     => 0x10;
use constant NETID_LYNXNET => 0xE0;

# Packet Offset Definitions
use constant NETID_OFFSET   => 0;
use constant NODEID_OFFSET  => 1;
use constant SEQNUM_OFFSET  => 2;
use constant PKTSIZE_OFFSET => 3;
use constant PAYLOAD_OFFSET => 4;
use constant PKTSIZE_MIN    => 5;

# LynxNet Commands
use constant LNCMD_FAILURE            => 0x00;
use constant LNCMD_SUCESS             => 0x01;
use constant LNCMD_ENUMDEVICE         => 0x06;
use constant LNCMD_ENUMINTERFACE      => 0x07;
use constant LNCMD_ENUMPROTOCOL       => 0x08;
use constant LNCMD_MFGANDMODEL        => 0x09;
use constant LNCMD_SERIALNUM          => 0x0A;
use constant LNCMD_FIRMWAREREV        => 0x0B;
use constant LNCMD_READNVRAM          => 0x10;
use constant LNCMD_WRITENVRAM         => 0x11;
use constant LNCMD_FACTORYDEFAULTS    => 0xF0;
use constant LNCMD_FACTORYTESTEN      => 0xF6;
use constant LNCMD_RESETPROTOCOLSTACK => 0xFE;
use constant LNCMD_RESETDEVICE        => 0xFF;
# Lynx-X10 Commands
use constant X10_CMDFAILURE           => 0x00;
use constant X10_CMDSUCCESS           => 0x01;
use constant X10_STATUS               => 0x02;
use constant X10_MONITORDATA          => 0x04;
use constant X10_ANALYZERDATA         => 0x05;
use constant X10_UNITADDRESS          => 0x08;
use constant X10_ALLUNITSOFF          => 0x10;
use constant X10_ALLLIGHTSON          => 0x11;
use constant X10_ON                   => 0x12;
use constant X10_OFF                  => 0x13;
use constant X10_DIM                  => 0x14;
use constant X10_BRIGHT               => 0x15;
use constant X10_ALLLIGHTSOFF         => 0x16;
use constant X10_EXTENDEDCODETRANSFER => 0x17;
use constant X10_HAILREQUEST          => 0x18;
use constant X10_HAILACKNOWLEDGE      => 0x19;
use constant X10_PRESETDIM_0          => 0x1A;
use constant X10_PRESETDIM_1          => 0x1B;
use constant X10_EXTENDEDDATATRANSFER => 0x1C;
use constant X10_STATUS_ON            => 0x1D;
use constant X10_STATUS_OFF           => 0x1E;
use constant X10_STATUS_REQUEST       => 0x1F;
use constant X10_EVERYUNITOFF         => 0x20;
use constant X10_EVERYLIGHTOFF        => 0x21;
use constant X10_EVERYLIGHTON         => 0x22;
use constant X10_DIM_PRESET           => 0x29;
use constant X10_OPTIONS              => 0xF0;
use constant X10_CARRIERPRESENT       => 0xF1;
use constant X10_RD_STATCOUNTER       => 0xF2;
use constant X10_CLR_STATCOUNTER      => 0xF3;
use constant X10_RECEIVERSENSITIVITY  => 0xFC;
use constant X10_TRANSMITPOWER        => 0xFD;
use constant X10_SELECTCHANNEL        => 0xFE;
use constant X10_RAWPOWERLINEDATA     => 0xFF;
use constant X10_EOL                  => 0xFF;

# Stat Counter IDs. Used with
# X10_RD_STATCOUNTER and X10_CLR_STATCOUNTER commands
use constant STATCNTR_TRANSMIT_PKTS   => 0x00;
use constant STATCNTR_RECEIVED_PKTS   => 0x01;
use constant STATCNTR_RECEPTION_ERRS  => 0x02;
use constant STATCNTR_TRANSMIT_ERRS   => 0x03;
use constant STATCNTR_COLLISIONS      => 0x04;
use constant STATCNTR_POWERFAILURES   => 0x05;

# Lynx10-PLC Hardware Register Definitions
use constant L10PLCREG_BAUDRATE             => 0x00;
use constant L10PLCREG_INTERFACEOPTIONS     => 0x01;
use constant L10PLCREG_X10OPTIONS           => 0x02;
use constant L10PLCREG_HOSTBUFTHRESH        => 0x08;
use constant L10PLCREG_X10BUFTHRESH         => 0x0D;
use constant L10PLCREG_X10RECVRSENS         => 0x0E;
use constant L10PLCREG_X10TRANSLEVEL        => 0x0F;
use constant L10PLCREG_X10XMITPREAMBLE      => 0x10;
use constant L10PLCREG_X10XMITPOSTAMBLE     => 0x11;
use constant L10PLCREG_X10RECVPREAMBLE      => 0x12;
use constant L10PLCREG_X10RECVPREAMBLEMASK  => 0x13;
use constant L10PLCREG_X10RECVPOSTAMBLE     => 0x14;
use constant L10PLCREG_X10RECVPOSTAMBLEMASK => 0x15;

# X10_STATUS Codes
use constant X10STATUS_OK             => 0x00;
use constant X10STATUS_BUFFERFULL     => 0x01;
use constant X10STATUS_RCVRDECODEERR  => 0x10;
use constant X10STATUS_COLLISION      => 0x11;
use constant X10STATUS_COMONLINE      => 0x1E;
use constant X10STATUS_POWERFAILURE   => 0x1F;
########################################################################

my %table_hcodes = qw(0 A 1 B  2 C  3 D  4 E  5 F  6 G  7 H 
		      8 I 9 J 10 K 11 L 12 M 13 N 14 O 15 P);
my %table_ucodes = qw(0 1 1 2  2 3  3 4  4 5  5 6  6 7  7 8 
		      8 9 9 A 10 B 11 C 12 D 13 E 14 F 15 G
		      OFF K ON J);

my %table_hcodes2 = qw(A 0 B 1 C  2 D  3 E  4 F  5 G  6 H  7 
		       I 8 J 9 K 10 L 11 M 12 N 13 O 14 P 15);
my %table_ucodes2 = qw(1 0 2 1 3  2 4  3 5  4 6  5 7  6 8  7  
		       9 8 A 9 B 10 C 11 D 12 E 13 F 14 G 15);

my ($_netid, $_nodeid, $_seqnum, $_payld, $_paysz, $_chksum, $_paycmd);
my ($_cmds, %Lynx10PLC);

########################################################################
#
# This code create the serial port and registers the callbacks we need
#
########################################################################
sub startup 
{
    &serial_startup;

    # Add hook only if serial port was created ok
    if (my $serial_port = $main::Serial_Ports{Lynx10PLC}{object})
    {
	$Lynx10PLC{SEQNUM} = 0;
	$Lynx10PLC{NODEID} = 0;
	
	# Force LynxNet protocol and Legacy Dim Mode 1
	&send($serial_port, NETID_LYNXNET,
	      pack('C3', LNCMD_WRITENVRAM, 1,3));
	
	&readDeviceInfo($serial_port);
	&readAllStats($serial_port);
	
	&::MainLoop_pre_add_hook( \&Lynx10PLC::check_for_data,   1);
    }
}

sub serial_startup
{
    my $debug = lc($main::config_parms{debug}) =~ /lynx10plc/;
    print "Lynx10PLC::serial_startup\n" if $debug;

    if ($::config_parms{Lynx10PLC_port})
    {
        my($speed) = $::config_parms{Lynx10PLC_baudrate} || 9600;
        if (&::serial_port_create('Lynx10PLC', 
				  $::config_parms{Lynx10PLC_port}, 
				  $speed, 'none'))
        {
            my $serial_port = $::Serial_Ports{Lynx10PLC}{object};
	    $serial_port->error_msg(0);
	    #$serial_port->user_msg(1);
	    $serial_port->debug(1);
	    
	    $serial_port->parity_enable(0);
	    $serial_port->databits(8);
	    $serial_port->parity("none");
	    $serial_port->stopbits(1);
	    $serial_port->dtr_active(1);
	    $serial_port->rts_active(0);       
	    select (undef, undef, undef, .100);         # Sleep a bit
	    
        }
    }
}

sub check_for_data
{
    my $serial_port = $::Serial_Ports{Lynx10PLC}{object};

    # Update the stats on the hour
    &readAllStats($serial_port) if $::New_Hour;

    my $pkt = &read($serial_port,1);
    processPkt($pkt) if ($pkt);

    # Process any pending commands recieved
    &main::process_serial_data($_cmds) if $_cmds;
    $_cmds = ();
}

#################################################################
# Function: send_plc
#
# Description:
#  This function is used convert an X10 ASCII string into a 
#  Lynx-Net packet, and then sends it to the PLC.
#
# Parameters:
#  $serial_port : Interface to write the command to
#  $cmd         : ASCII string to parse
#
# Returns: X10 Command in ASCII format
#
#################################################################
sub send_plc
{
    # Make sure we are passed a pkt
    return unless ( 2 == @_ ) ;
    my ($serial_port, $cmd) = @_;

    return unless my $payld = &cmd2payld($cmd);

    &send($serial_port, NETID_X10, $payld);
}

#################################################################
# Function: cmd2payld
#
# Description:
#  This function is used to convert an ASCII command into the 
#  LynxNet command payload. 
#
# Parameters:
#  $cmd : ASCII command to convert
#
# Returns: LynxNet payload in "packed" format
#
#################################################################
sub cmd2payld
{
    return undef unless ( 1 == @_ );

    my ($cmd) = @_;
    my $debug = lc($main::config_parms{debug}) =~ /lynx10plc/;

    # Incoming string looks like this:  XA1K
    my ($house, $device, $code) = $cmd =~ /X(\S)(\S)(\S+)/;

    my $hc = $table_hcodes2{$house};
    my $uc = $table_ucodes2{$device};

    my $payld = undef;

    # Command "K" is X10_OFF
    if ($code =~ /^k/i)
    {
	$payld = pack('C4', X10_OFF, $hc, $uc, X10_EOL);
    }

    # Command "J" is X10_ON
    elsif ($code =~ /^j/i)
    {
	$payld = pack('C4', X10_ON,  $hc, $uc, X10_EOL);
    }

    # Command "&P#" is X10_DIM_PRESET
    elsif (my($extended_data) = $code =~ /&P(\d+)/)
    {
        if (($extended_data >= 0) && ($extended_data < 32)) 
	{
	    $payld = pack('C5', X10_DIM_PRESET, $hc, $uc, X10_EOL, $extended_data);
        }
    }

    # Command "-#" is X10_DIM
    elsif ($code =~ /^-\d\d$/) 
    {
	my $dim_level = abs($code);
	my $dim = int(($dim_level / 100) * 20);
	$payld = pack('C5', X10_DIM, $hc, $uc, X10_EOL, $dim);
    }

    # Command "+#" is X10_BRIGHT
    elsif ($code =~ /^\+\d\d$/) 
    {
	my $dim_level = abs($code);
	my $dim = int(($dim_level / 100) * 20);
	$payld = pack('C5', X10_BRIGHT, $hc, $uc, X10_EOL, $dim);
    }

    print "cmd2payld: cmd: $cmd, payld=" . unpack('H*', $payld) . 
	"\n" if $debug;

    return $payld;
}

#################################################################
# Function: processPkt
#
# Description:
#  This function is used to process a valid LynxNet packet 
#  received from the PLC
#
# Parameters:
#  $pkt : Lynx-Net packet to process
#
# Returns: 1
#
#################################################################
sub processPkt
{
    # Get pkt and pktlen
    my ($pkt) = @_;
    my $pktlen = length($pkt);
    my $debug = lc($main::config_parms{debug}) =~ /lynx10plc/;

    &splitPkt($pkt);

    print "processPkt: netid=" . sprintf("%02X", $_netid) . 
	", payld: len=$_paysz, data=" . 
	    unpack('H*',$_payld) . "\n" if $debug;

    &processPkt_X10 if ($_netid == NETID_X10);
    &processPkt_LYNXNET if ($_netid == NETID_LYNXNET);

    return 1;
}

sub processPkt_LYNXNET
{
    return unless $_netid == NETID_LYNXNET;

    if ($_paycmd == LNCMD_MFGANDMODEL)
    {
	print "LynxNet Mfg=" . unpack('H*', substr($_payld,1,2)) .
	    ", Model=" . unpack('H*', substr($_payld,3,2)) . "\n"
		if $_paysz == 5;
    }
    elsif ($_paycmd == LNCMD_SERIALNUM)
    {
	print "LynxNet Serial Number=" .
	    unpack('H*', substr($_payld,1,8)) . "\n"
		if $_paysz == 9;
    }
    elsif ($_paycmd == LNCMD_FIRMWAREREV)
    {
	print "LynxNet Firmware Rev=" .
	    unpack('H*', substr($_payld,1,2)) . "\n"
		if $_paysz == 3;
    }
}

my $noun = ();

sub processPkt_X10
{
    return unless $_netid == NETID_X10;

    my $debug = lc($main::config_parms{debug}) =~ /lynx10plc/;

    # Start by spliting the payld into individual fields
    my @data = unpack('C*', $_payld);

    if ($_paycmd == X10_UNITADDRESS)
    {
	$noun = $table_hcodes{$data[1]} . 
	    $table_ucodes{$data[2]} if ($_paysz >= 3);
    }
    elsif ($_paycmd == X10_OFF)
    {
	$_cmds .= "X" . $noun . $table_hcodes{$data[1]} .
	    $table_ucodes{OFF} if ($_paysz >= 2);
	print "_cmds= " . $_cmds . "\n" if $debug;
    }
    elsif ($_paycmd == X10_ON)
    {
	$_cmds .= "X" . $noun . $table_hcodes{$data[1]} .
	    $table_ucodes{ON} if ($_paysz >= 2);
	print "_cmds= " . $_cmds . "\n" if $debug;
    }
    elsif ($_paycmd == X10_DIM)
    {
	my $val = unpack('C', substr($_payld,-1,1));
	if ($val > 0)
	{
	    $_cmds .= "X" . $noun . "-" . $val if ($_paysz >= 2);
	    print "_cmds= " . $_cmds . "\n" if $debug;
	}
    }
    elsif ($_paycmd == X10_BRIGHT)
    {
	my $val = unpack('C', substr($_payld,-1,1));
	if ($val > 0)
	{
	    $_cmds .= "X" . $noun . "+" . $val if ($_paysz >= 2);
	    print "_cmds= " . $_cmds . "\n" if $debug;
	}
    }
    elsif ($_paycmd == X10_RD_STATCOUNTER)
    {
	if ($_paysz == 5)
	{
	    my $cntr = unpack('C', substr($_payld,2,1));
	    my $stat = unpack('C', substr($_payld,3,1)) * 256 +
		unpack('C', substr($_payld,4,1));
	    my $cntrname = &StatCntrName($cntr);
	    print "LynxNet X10 $cntrname counter: $stat\n";
	    $Lynx10PLC{$cntrname} = $stat;
	}
    }
    elsif ($_paycmd == X10_CARRIERPRESENT)
    {
	if ($_paysz == 7)
	{
	    my $days = unpack('C', substr($_payld,2,1)) * 256 +
		unpack('C', substr($_payld,3,1));
	    my $hours = unpack('C', substr($_payld,4,1));
	    my $mins  = unpack('C', substr($_payld,5,1));
	    my $secs  = unpack('C', substr($_payld,6,1));
	    
	    my $totsecs = ($days*24 + $hours) * 3600 +
		$mins*60 + $secs;
	    $Lynx10PLC{CARRIERPRESENT} = $totsecs;
	    
	    print "LynxNet X10 Uptime: $days days, $hours:" .
		sprintf ("%02d:%02d", $mins, $secs) . "\n";
	}
    }
    elsif ($_paycmd == X10_RECEIVERSENSITIVITY)
    {
	if ($_paysz == 3)
	{
	    my $val = unpack('C', substr($_payld,2,1));
	    $Lynx10PLC{RECEIVERSENSITIVITY} = $val;
	    my $percent = int (100 * ($val / 255));
	    print "LynxNet X10 Receiver Sensitivity = $percent%\n";
	}
    }
    elsif ($_paycmd == X10_TRANSMITPOWER)
    {
	if ($_paysz == 3)
	{
	    my $val = unpack('C', substr($_payld,2,1));
	    $Lynx10PLC{TRANSMITPOWER} = $val;
	    my $percent = int (100 * ($val / 255));
	    print "LynxNet X10 Transmit Power = $percent%\n";
	}
    }
    elsif ($_paycmd == X10_STATUS)
    {
	if ($_paysz == 2)
	{
	    my $status = unpack('C', substr($_payld,1,1));
	    my $msg = "Unknown status";

	    $msg = "Ready for commands"         if $status == X10STATUS_OK;
	    $msg = "Transmit buffer full"       if $status == X10STATUS_BUFFERFULL;
	    $msg = "Receiver Decoder Error"     if $status == X10STATUS_RCVRDECODEERR;
	    $msg = "Collision Detected"         if $status == X10STATUS_COLLISION;
	    $msg = "X-10 Communications Online" if $status == X10STATUS_COMONLINE;
	    $msg = "Power Failure"              if $status == X10STATUS_POWERFAILURE;
	    print "X10Status: $msg\n";
	}
    }
}

#############################################################
# Function: splitPkt
#
# Description:
#  This function is to extract all of the fields from a packet 
#  and store them in global variables. Because of this, the 
#  function is NOT re-entrant.
#
# Parameters:
#  $pkt : Packet in "packed" format to anaylze
#
# Returns: nothing
#
#############################################################
sub splitPkt
{
    # Get pkt and pktlen
    my ($pkt) = @_;

    my $pktlen = length($pkt);

    $_netid  = unpack('C', substr($pkt,NETID_OFFSET,1));
    $_nodeid = unpack('C', substr($pkt,NODEID_OFFSET,1));
    $_seqnum = unpack('C', substr($pkt,SEQNUM_OFFSET,1));
    $_payld  = substr($pkt, PAYLOAD_OFFSET, length($pkt) - PKTSIZE_MIN);
    $_paysz  = length($_payld);
    $_chksum = unpack('C',substr($pkt,$pktlen-1));
    $_paycmd = unpack('C',$_payld) if $_paysz;
}

#############################################################
# Function: checksum
#
# Description:
#  This function is used to calculate a 8-bit checksum for
#  a given buffer.
#
# Parameters:
#  $buf  : Buffer in "packed" format to calculate checksum on
#  $len  : number of bytes to calculate checksum on
#
# Returns: checksum
#
#############################################################
sub checksum
{
    my ($buf, $len) = @_;

    my $sum   = 0;
    my @data = unpack('C*', $buf);

    for (my $idx = 0; $idx < $len; ++$idx)
    {
	$sum += $data[$idx];
    }

    return $sum & 0xff;
}

#############################################################
# Function: buildPkt
#
# Description:
#  This function is used to generate a LynxNet packet based
#  upon the packet_type and payload.
#
# Parameters:
#  $pkt_type    : Type of packet to send
#  $payld       : Lynx-Net payload
#
# Returns: packet in "pack" format
#
#############################################################
sub buildPkt
{
    my ($netid, $payld) = @_;

    # Get the packet sequnce number
    my $seqnum = $Lynx10PLC{SEQNUM}++ & 0x7F;

    my $pkt = pack('C4', $netid, $Lynx10PLC{NODEID},
		   $seqnum, length($payld));
    $pkt .= $payld;
    $pkt .= pack('C', checksum($pkt, length($pkt)));
    return $pkt;
}

#############################################################
# Function: read
#
# Description:
#  This function is used to read data from the serial
#  interface, and will return with a complete Lynx-Net
#  packet. If the checksum of the packet is bad, an
#  error message is displayed, and the packet is tossed.
#
# Parameters:
#  $serial_port : serial interface to read from
#  $no_block    : 0, timeout is 100*50msec=5secs 
#                 1, timeout is 0secs
#
# Returns: packet in pack format, or undef if no packet
#          was read.  
#
#############################################################
my $readBuf = ();
sub read
{
    my ($serial_port, $no_block) = @_;

    my $tries = ($no_block) ? 1 : 100;

    my $debug = lc($main::config_parms{debug}) =~ /lynx10plc|serial/;

    while ($tries--)
    {
	my $data;
	
	# read data from serial port
	if ($data = $serial_port->input)
	{
	    # Data was read, so append it to the readBuf
	    $readBuf .= $data;

	    print "Data rcvd: len=" . length($data) . ", data=" . 
		unpack('H*',$data) . "\n" if $debug;
	}
	else
	{
	    # No data read, so reset errors if any
	    $serial_port->reset_error;
	}

	while (length($readBuf))
	{
	    my $id = unpack('C', $readBuf);

	    # Make sure NetID is valid
	    last if $id == NETID_NACK;
	    last if $id == NETID_ACK;
	    last if $id == NETID_UNDEF;
	    last if $id == NETID_X10;
	    last if $id == NETID_LYNXNET;
	    
	    # NetID is unknown, so toss it in the bitbucket
	    print "Unexpected NetID=" . sprintf("%02X", $id) . ". Skipping\n";
	    $readBuf = substr($readBuf,1);
	}

	print "readBuf=" . unpack('H*', $readBuf) . "\n" 
	    if length($readBuf) && $debug;

	# See if we have a complete packet
	if (length($readBuf) >= PKTSIZE_MIN)
	{
	    # split the buffer into individual characters
	    my @data = unpack('C*',$readBuf);
	    
	    # Calculate the pktlen based upon information in the packet
	    my $pktlen = $data[PKTSIZE_OFFSET] + PKTSIZE_MIN;

	    # Make sure we have enough data for this packet
	    if (length($readBuf) >= $pktlen)
	    {
		# Extract the packet from the readBuf
		my $pkt  = substr($readBuf,0,$pktlen);
		$readBuf = substr($readBuf,$pktlen);
		
		# Calculate the checksum of the packet. Keep in mind
		# that the last byte in the packet is the act checksum
		my $sum  = &checksum($pkt, $pktlen-1);

		# Extract fields from packet
		&splitPkt($pkt);

		my $status=();
		$status = sprintf("  Chksum Failed, act=%02X", $sum) 
		    if $sum != $_chksum;

		print "<-- pkt: len=" . length($pkt) . ", data=" . 
		    unpack('H*',$pkt) . $status . "\n" 
			if $debug || length($status);

		return $pkt if $sum == $_chksum;
	    }
	}
	select undef, undef, undef, 50 / 1000 if ($tries);
    }
    return undef;
}

#############################################################
# Function: send
#
# Description:
#  This function is used to send a Lynx-Net packet to the 
#  serial interface. After the packet is sent, the function will
#  wait for both the "received", and "completed" packets to return.
#  If a packet other that these two are recieved, it will be
#  processed at this time.
#  If the packet is not completed within an defined timeout,
#  it will be resent, and the process will repeat, until the
#  retry limit has been exhausted.
#
# Parameters:
#  $serial_port : serial interface to write to
#  $pkt_type    : Type of packet to send
#  $payld       : Lynx-Net payload to write
#
# Returns:  1 for SUCCESS, 0 for FAILURE
#
#############################################################
sub send
{
    my ($serial_port, $pkt_type, $payld) = @_;

    my $tries = 0;
    my $debug = lc($main::config_parms{debug}) =~ /lynx10plc/;

  RETRY:
    print "Lynx10PLC::send: resending packet\n" if $tries;
    return 0 if $tries++ > 2;

    # Construct the packet to send
    my $pkt = &buildPkt($pkt_type, $payld);

    # Extract the expected sequence number from the packet
    &splitPkt($pkt);
    my ($exp_seqnum, $exp_netid) = ($_seqnum, $_netid);

    print "--> pkt: len=" . length($pkt) . ", data=" . 
	unpack('H*',$pkt) . ", payld=", unpack('H*',$payld) .
	    "\n" if $debug;

    # write packet to serial interface
    if ( length($pkt) != $serial_port->write($pkt) )
    {
	print "Bad Lynx10PLC data send transmition\n";
        goto RETRY;
    }

  ACK_PKT:
    # Read packet from interface
    goto RETRY unless $pkt = &read($serial_port);

    if ($exp_seqnum != $_seqnum)
    {
	processPkt($pkt);
	goto ACK_PKT;
    }

    # We are expecting an ACK packet at this time
    goto RETRY if (NETID_ACK != $_netid);

  DONE_PKT:
    # Read packet from interface
    goto RETRY unless $pkt = &read($serial_port);

    if (($exp_seqnum != $_seqnum) || ($_paysz != 1))
    {
	processPkt($pkt);
	goto DONE_PKT;
    }

    # We are expecting a DONE packet at this time.

    # Retry if the NETID is not ours. This is a bad thing at this time.
    goto RETRY if ($exp_netid != $_netid);
    goto RETRY if (unpack('C',$_payld) != LNCMD_SUCESS);

    return 1;
}

sub StatCntrName
{
    my ($cntr) = @_;

    return "TRANSMIT_PKTS"  if ($cntr == STATCNTR_TRANSMIT_PKTS);
    return "RECEIVED_PKTS"  if ($cntr == STATCNTR_RECEIVED_PKTS);
    return "RECEPTION_ERRS" if ($cntr == STATCNTR_RECEPTION_ERRS);
    return "TRANSMIT_ERRS"  if ($cntr == STATCNTR_TRANSMIT_ERRS);
    return "COLLISIONS"     if ($cntr == STATCNTR_COLLISIONS);
    return "POWERFAILURES"  if ($cntr == STATCNTR_POWERFAILURES);
    return "UNKNOWN";
}

sub ReadStatCntr
{
    my ($serial_port, $cntr) = @_;

    &send($serial_port, NETID_X10, 
	  pack('C3', X10_RD_STATCOUNTER, X10_EOL, $cntr));
    return $Lynx10PLC{&StatCntrName($cntr)};
}

sub ClrStatCntr
{
    my ($serial_port, $cntr) = @_;

    &send($serial_port, NETID_X10, 
	  pack('C3', X10_CLR_STATCOUNTER, X10_EOL, $cntr));
}

sub readAllStats
{
    my ($serial_port) = @_;

    my @cntrs = (STATCNTR_TRANSMIT_PKTS,
		 STATCNTR_RECEIVED_PKTS,
		 STATCNTR_RECEPTION_ERRS,
		 STATCNTR_TRANSMIT_ERRS,
		 STATCNTR_COLLISIONS,
		 STATCNTR_POWERFAILURES);
    while (scalar @cntrs)
    {
	my $val = &ReadStatCntr($serial_port, shift @cntrs);
    }

    my @other = (X10_CARRIERPRESENT,
		       X10_RECEIVERSENSITIVITY,
		       X10_TRANSMITPOWER);
    while (scalar @other)
    {
	&send($serial_port, NETID_X10, 
	      pack('C2', shift @other, X10_EOL));
    }
}

sub readDeviceInfo
{
    my ($serial_port) = @_;

    my @cmds = (LNCMD_MFGANDMODEL,
		LNCMD_SERIALNUM,
		LNCMD_FIRMWAREREV);
    while (scalar @cmds)
    {
	&send($serial_port, NETID_LYNXNET, 
	      pack('C1', shift @cmds));
    }
    &send($serial_port, NETID_LYNXNET,
	  pack('C2', LNCMD_READNVRAM, 01));

}

return 1;           # for require
