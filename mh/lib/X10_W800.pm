
=begin comment

This is code will read X10 data received by the
RF W800RF32 receiver from http://www.wgldesigns.com .
The W800RF32 is similar to the MR26, but also supports extended codes
and has a better range.  Comparison is here: http://www.wgldesigns.com/comments.htm

Note:  Extended codes are not supported here yet.

Use these mh.ini parameters to enable this code:

 W800_module = X10_W800
 W800_port   = COM1

This will set any X10_Item that matches X10 codes received.

To monitor keys from an X10 TV/VCR RF remote (UR47A, UR51A, J20A, etc.),
(e.g. Play,Pause, etc), you can use something like this:

 $Remote  = new X10_W800;
 $Remote -> tie_event('print_log "W800 key: $state"');
 set $TV $state if $state = state_now $Remote;

For a more general way to handle TV/VCR RF remotes and X10 security
devices, see RF_Item.pm.

If you want to relay all the of the incoming powerline style RF data
back out to the powerline, use mh/code/common/x10_rf_relay.pl.

Also see X10_MR26.pm for a similar interface.

=cut

use strict;

package X10_W800;
use X10_RF;

@X10_W800::ISA = ('Generic_Item');

sub startup {
#  $main::config_parms{"W800_break"} = pack('C', 0xad);
   &main::serial_port_create('W800', $main::config_parms{W800_port}, 4800, 'none', 'raw');
                                # Add hook only if serial port was created ok
   &::MainLoop_pre_add_hook(  \&X10_W800::check_for_data, 1 ) if $main::Serial_Ports{W800}{object};
}

my ($prev_data, $prev_time, $prev_loop, $prev_done);
$prev_data = $prev_time = $prev_done = 0;

sub check_for_data {
    my ($self) = @_;
    &main::check_for_generic_serial_data('W800');
    return unless $main::Serial_Ports{W800}{data};
                                # Data comes 2 bytes at a time (no break character)
    my ($data, $remainder) = $main::Serial_Ports{W800}{data} =~ /(....)(.*)/;
    return unless $data;
    $main::Serial_Ports{W800}{data} = $remainder;

                                # Data gets sent multiple times
                                #  - Check time and loop count.  If mh paused (e.g. sending ir data)
                                #    then we better also check loop count.
                                #  - Process data only on the 2nd occurance, to avoid noise
    my $time = &main::get_tickcount;
    my $repeat_data = ($data eq $prev_data) && ($time < $prev_time + 1500 or $main::Loop_Count < $prev_loop + 7);
    return if $repeat_data and $prev_done;
    $prev_data = $data;
    $prev_time = $time;
    $prev_loop = $main::Loop_Count;
    unless ($repeat_data) {     # UnSet flag and wait for 2nd occurance
	$prev_done = 0;
	return;
    }
    $prev_done = 1;             # Set flag and process data


    my $hex = unpack "H*", $data;
    &main::main::print_log("W800: raw data: $hex") if $main::Debug{w800};

    # Bytes 1 and 3 contain the real data.  Bytes 2 and 4 are just complements
    # of bytes 1 and 2 (for doing checksums).  XOR'ing byte 1 with byte 2
    # should result in 0xff.  The same goes for bytes 3 and 4.  Note that for
    # security data, byte 4 is not a checksum and does contain part of the
    # device ID.
    my(@bytes);
    if ((@bytes) = $data =~ /^(.)(.)(.)(.)$/) {

	my $state = X10_RF::decode_rf_bytes('w800', @bytes);

	# If we got a bad checksum, throw out the rest of the data in the
	# buffer since we probably have a corrupt data stream.
	$main::Serial_Ports{W800}{data} = undef if $state eq 'BADCHECKSUM';

    } else {

	# We weren't able to parse our four bytes of data for some reason,
	# throw out the rest of the data in the buffer since we probably have a
	# corrupt data stream.
	print "W800: Unparsed data: $hex\n";
	$main::Serial_Ports{W800}{data} = undef
    }
}

# Data format info on here:  http://www.wgldesigns.com/dataformat.txt

#
# $Log$
# Revision 1.3  2004/02/01 19:24:35  winter
#  - 2.87 release
#
#

# vim: sw=4

1;
