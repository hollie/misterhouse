
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
    &main::serial_port_create( 'W800', $main::config_parms{W800_port},
        4800, 'none', 'raw' );

    # Add hook only if serial port was created ok
    &::MainLoop_pre_add_hook( \&X10_W800::check_for_data, 1 )
      if $main::Serial_Ports{W800}{object};
}

my ($prev_bad_checksums);
$prev_bad_checksums = 0;

my ($new_data_time);    # Leave undefined initially
my ( $prev_residual, @msg_buffer, $reset_prev_residual_pending );
$prev_residual               = '';
$reset_prev_residual_pending = 0;    # don't reset it
@msg_buffer                  = ();

sub check_for_data {
    my ($self) = @_;
    &main::check_for_generic_serial_data('W800');

    # Nothing to do if there is nothing in the buffer.
    unless ( $main::Serial_Ports{W800}{data} ) {
        if ( $prev_bad_checksums != 0 and !($prev_residual) ) {
            &::print_log(
                    "W800: failed to recover from bad checksums due to no data"
                  . "(count=$prev_bad_checksums)" );
            $prev_bad_checksums = 0;
        }

        $new_data_time = undef;

        return;
    }

    my $buffer = $main::Serial_Ports{W800}{data};
    if ( $buffer and $prev_residual ) {

        # mark prev_residual as being ready for reset if conditions below warrant it
        $reset_prev_residual_pending = 1;
    }
    $buffer = $prev_residual . $buffer if defined $prev_residual;

    # clear out the serial port's data
    $main::Serial_Ports{W800}{data} = undef;

    # Get a current time reading to be used with a couple of timers.
    my $time = &main::get_tickcount;
    $time += 2**32
      if $time < 0;    # force a wrap if mh's tickcount wrapped negative

    # A valid command is 4 bytes long.  If we didn't get 4 bytes from the
    # serial stream, then we are not ready to process a command.
    unless ( defined $buffer and length($buffer) >= 4 ) {

        # If it's been a while since the time the we started processing the
        # data stream and we still don't have enough bytes to finish the
        # command, flush the data buffer since it probably contains left over
        # data from a corrupt data stream.
        # NOTE: get_tickcount wraps, so $time < $new_data_time test is to
        #       make sure that doesn't become a problem.
        if ( not &X10_W800::is_within_timeout( $time, $new_data_time, 2000 ) ) {
            my $hex = unpack "H*", $main::Serial_Ports{W800}{data};
            &::print_log("W800: flushing incomplete data: $hex")
              if $main::Debug{w800};

            if ( $prev_bad_checksums != 0 ) {
                &::print_log( "W800: failed to recover from bad checksums "
                      . "(count=$prev_bad_checksums)" );
                $prev_bad_checksums = 0;
            }

            $new_data_time = undef;
        }
        return;
    }

    # See if we have at least 4 bytes in the buffer.  (allow for 0x0A with /s)
    my ( $data, $residual ) = $buffer =~ /(....)(.*)/s;

    # Even if there is some data left in the buffer we'll reset the time the
    # data stream started so that the next series of bytes will have a
    # reasonable time complete.
    $new_data_time = undef;

    while ($data) {

        # Got 4 bytes.  We'll keep them and put the residual back in the buffer.

        # Data gets sent multiple times
        #  - Check time
        #  - Process data only on the 2nd occurance, to avoid noise (seems essential)
        my $duplicate_threshold =
          1;    # 2nd occurance; set to 0 to omit duplicate check
        if ( &X10_W800::duplicate_count($data) == $duplicate_threshold ) {

            # If this is the first signs of new data in a while, make a note of the
            # time.
            $new_data_time = $time unless defined $new_data_time;

            # Log the raw data.
            my $hex = unpack "H*", $data;
            &::print_log("W800: raw data: $hex") if $main::Debug{w800};

            # For powerline type data bytes 1 and 3 contain the real data.  Bytes 2 and
            # 4 are just complements of bytes 1 and 2 (for doing checksums).  XOR'ing
            # byte 1 with byte 2 should result in 0xff.  The same goes for bytes 3 and
            # 4.  For security data, byte 4 is not a checksum and does contain part of
            # the device ID.  Other devices, such as the Digimax 210, don't seem to
            # have checksums at all.  See X10_RF.pm for more details.
            my @bytes = $data =~ /^(.)(.)(.)(.)$/s;

            my $state = X10_RF::decode_rf_bytes( 'W800', @bytes );

            # If the decode_rf_bytes routine didn't like the data that it got,
            # strip the first byte off and let the rest be resubmitted in case a
            # rogue byte got inserted into the data stream.
            if ( $state eq 'BADCHECKSUM' ) {

                if ( $prev_bad_checksums == 0 ) {
                    &::print_log("W800: bad checksum (attempting to recover)");
                }
                $prev_bad_checksums++;
                $data = substr( $data, 1 ) if length($data) > 1;
                $buffer = $data . $residual;
            }
            else {
                # we have "good" (not BADCHECKSUM) data

                # Report if we recovered from previous bad checksums.
                if ( $prev_bad_checksums != 0 ) {
                    &::print_log( "W800: recovered from bad checksum "
                          . "(count=$prev_bad_checksums)" );
                }

                # reset bad checksum counter since this one is ok
                $prev_bad_checksums = 0;

                # set buffer to any remaining bytes in case they can be processed
                $buffer = $residual;
            }
        }
        else {
            $buffer = $residual;    # in case there's any residual

            #          $prev_bad_checksums = 0;
        }
        ( $data, $residual ) = $buffer =~ /(....)(.*)/s;

        # set residual to buffer if no data present
        $residual = $buffer unless defined $data;
    }

    if ( $prev_residual eq $residual and $reset_prev_residual_pending ) {

        # don't keep it around as we have seen it before and need to get rid of it
        $prev_residual = '';
    }
    else {
        # keep a copy for the next time that we get data
        $prev_residual = $residual;
    }
    $reset_prev_residual_pending = 0;    # always clear the reset flag since
         # it should only be reset on new data and prev_residual

}

sub duplicate_count {
    my ($raw_msg) = @_;
    my $duplicate_count = 0;
    my $repeat_time = $main::config_parms{W800_multireceive_delay} || 1500;
    my $time = &main::get_tickcount;

    if ( my $msg_buffer_size = @msg_buffer ) {

        # most recent messages are always first in the queue
        for my $msg_ptr (@msg_buffer) {
            my %msg = %$msg_ptr;
            if ( &X10_W800::is_within_timeout( $time, $msg{time}, $repeat_time )
              )
            {
                # a match exists on the data; so, compare against the time stamp
                if ( $raw_msg eq $msg{data} ) {

                    # it's a duplicate since it's within the multireceive_delay
                    $duplicate_count++;
                }
            }
            else {
                # no point in continueing to look at the rest as it's out of the time window
                last;
            }
        }
    }

    # add to the msg buffer if it is not a duplicate
    &X10_W800::add_data($raw_msg) unless $duplicate_count > 2;
    return $duplicate_count;
}

sub add_data {
    my ($data) = @_;
    my %msg = ();
    $msg{data} = $data;
    $msg{time} = &main::get_tickcount;

    my $max_length      = 20;
    my $msg_buffer_size = @msg_buffer;
    while ( $msg_buffer_size >= $max_length ) {

        # most recent messages are always first in the queue
        pop @msg_buffer;
        $msg_buffer_size = @msg_buffer;
    }
    unshift @msg_buffer, \%msg;
}

sub is_within_timeout {
    my ( $time1, $time2, $timeout ) = @_;
    return 1 if ( ( $time1 >= 2**7 ) and ( $time2 < 2**7 ) );
    return ( $time1 < ( $time2 + $timeout ) ) ? 1 : 0;
}

# Data format info on here:  http://www.wgldesigns.com/dataformat.txt

#
# $Log: X10_W800.pm,v $
# Revision 1.6  2004/11/22 22:57:26  winter
# *** empty log message ***
#
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
