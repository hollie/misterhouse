
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

my ($prev_data, $prev_time, $prev_loop, $prev_done, $prev_bad_checksums);
$prev_data = $prev_time = $prev_loop = $prev_done = $prev_bad_checksums = 0;

my ($new_data_time);	# Leave undefined initially

sub check_for_data {
    my ($self) = @_;
    &main::check_for_generic_serial_data('W800');

    # Nothing to do if there is nothing in the buffer.
    unless ($main::Serial_Ports{W800}{data}) {
	if ($prev_bad_checksums != 0) {
	    &::print_log(  "W800: failed to recovered from bad checksums "
		         . "(count=$prev_bad_checksums)");
	    $prev_bad_checksums = 0;
	}

	$new_data_time = undef;

	return;
    }

    # Get a current time reading to be used with a couple of timers.
    my $time = &main::get_tickcount;

    # If this is the first signs of new data in a while, make a note of the
    # time.
    $new_data_time = $time unless defined $new_data_time;

    # See if we have at least 4 bytes in the buffer.
    my ($data, $remainder) = $main::Serial_Ports{W800}{data} =~ /(....)(.*)/;

    # A valid command is 4 bytes long.  If we didn't get 4 bytes from the
    # serial stream, then we are not ready to process a command.
    unless (defined $data) {
	# If it's been a while since the time the we started processing the
	# data stream and we still don't have enough bytes to finish the
	# command, flush the data buffer since it probably contains left over
	# data from a corrupt data stream.
	# NOTE: get_tickcount wraps, so $time < $new_data_time test is to
	#       make sure that doesn't become a problem.
	if ($time > $new_data_time + 2000 or $time < $new_data_time) {
	    my $hex = unpack "H*", $main::Serial_Ports{W800}{data};
	    &::print_log("W800: flushing incomplete data: $hex");

	    if ($prev_bad_checksums != 0) {
		&::print_log(  "W800: failed to recovered from bad checksums "
			     . "(count=$prev_bad_checksums)");
		$prev_bad_checksums = 0;
	    }

	    $main::Serial_Ports{W800}{data} = undef;
	    $new_data_time = undef;
	}
	return;
    }

    # Got 4 bytes.  We'll keep them and put the remainder back in the buffer.
    $main::Serial_Ports{W800}{data} = $remainder;

    # Even if there is some data left in the buffer we'll reset the time the
    # data stream started so that the next series of bytes will have a
    # reasonable time complete.
    $new_data_time = undef;

    # Data gets sent multiple times
    #  - Check time and loop count.  If mh paused (e.g. sending ir data)
    #    then we better also check loop count.
    #  - Process data only on the 2nd occurance, to avoid noise
    my $repeat_time = $main::config_parms{W800_multireceive_delay} || 1500;
    my $repeat_data =    ($data eq $prev_data)
		      && (   $time < $prev_time + $repeat_time
			  || $main::Loop_Count < $prev_loop + 7);
    return if $repeat_data and $prev_done;
    $prev_data = $data;
    $prev_time = $time;
    $prev_loop = $main::Loop_Count;
    unless ($repeat_data) {     # UnSet flag and wait for 2nd occurance
	$prev_done = 0;
	return;
    }
    $prev_done = 1;             # Set flag and process data

    # Log the raw data.
    my $hex = unpack "H*", $data;
    &::print_log("W800: raw data: $hex") if $main::Debug{w800};

    # For powerline type data bytes 1 and 3 contain the real data.  Bytes 2 and
    # 4 are just complements of bytes 1 and 2 (for doing checksums).  XOR'ing
    # byte 1 with byte 2 should result in 0xff.  The same goes for bytes 3 and
    # 4.  For security data, byte 4 is not a checksum and does contain part of
    # the device ID.  Other devices, such as the Digimax 210, don't seem to
    # have checksums at all.  See X10_RF.pm for more details.
    my @bytes = $data =~ /^(.)(.)(.)(.)$/;

    my $state = X10_RF::decode_rf_bytes('w800', @bytes);

    # If the decode_rf_bytes routine didn't like the data that it got,
    # strip the first byte off and let the rest be resubmitted in case a
    # rogue byte got inserted into the data stream.
    if ($state eq 'BADCHECKSUM') {
	$data =~ s/^.//;
	$main::Serial_Ports{W800}{data} = $data.$main::Serial_Ports{W800}{data};

	if ($prev_bad_checksums == 0) {
	    &::print_log("W800: bad checksum (attempting to recover)");
	}
	$prev_bad_checksums++;
    } else {
	# Report if we recovered from previous bad checksums.
	if ($prev_bad_checksums != 0) {
	    &::print_log(  "W800: recovered from bad checksum "
		         . "(count=$prev_bad_checksums)");
	}
	$prev_bad_checksums = 0;
    }
}

# Data format info on here:  http://www.wgldesigns.com/dataformat.txt

#
# $Log$
# Revision 1.5  2004/07/18 22:16:37  winter
# *** empty log message ***
#
# Revision 1.4  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.3  2004/02/01 19:24:35  winter
#  - 2.87 release
#
#

# vim: sw=4

1;

