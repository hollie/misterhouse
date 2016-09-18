
=begin comment

Original authors: Kevin Olande, Wally Kissel, Fenghua Zong

This is code will read the information coming from most of 
the X10 remote controls with RF (e.g. UR19, UR47, JR20) 
using the MR26A receiver ($30):

 http://www.x10.com/products/x10_mr26a.htm 

Use these mh.ini parameters to enable this code:

 MR26_module = X10_MR26
 MR26_port   = COM1

This will set any X10_Item that matches X10 codes received.

To monitor keys from an X10 TV/VCR RF remote (UR47A, UR51A, J20A, etc.),
(e.g. Play,Pause, etc), you can use something like this:

 $Remote  = new X10_MR26;
 $Remote -> tie_event('print_log "MR26 key: $state"');
 set $TV $state if $state = state_now $Remote;

If you want to relay all the of the incoming RF data back out to 
the powerline, use mh/code/common/x10_rf_relay.pl.

Note on range.  Depending on who knows what, people have reported 
a maximum range for 10 -> 50 feet from receiver to remote. 
See comment at the end of this file for hints on increasing the range.

Also see X10_W800.pm for a similar interface, which is reported to have better range.


=cut

use strict;

package X10_MR26;
use X10_RF;

@X10_MR26::ISA = ('Generic_Item');

sub startup {
    $main::config_parms{"MR26_break"} = pack( 'C', 0xad );

    #   &main::serial_port_create('MR26', $main::config_parms{MR26_port}, 9600, 'none', 'raw');
    &main::serial_port_create( 'MR26', $main::config_parms{MR26_port},
        9600, 'none' );

    # Add hook only if serial port was created ok
    &::MainLoop_pre_add_hook( \&X10_MR26::check_for_data, 1 )
      if $main::Serial_Ports{MR26}{object};
}

my ( $prev_data, $prev_time, $prev_loop, $prev_done );
$prev_data = $prev_time = $prev_done = 0;

sub check_for_data {
    my ($self) = @_;

    # Sending commands to another device on the same serial port may have dropped
    # the DTR signal, so let the MR-26 know we're ready to recieve data again
    $main::Serial_Ports{MR26}{object}->dtr_active(1)
      or warn "Could not set dtr_active(1)";

    &main::check_for_generic_serial_data('MR26');
    my $data = $main::Serial_Ports{MR26}{data_record};
    $main::Serial_Ports{MR26}{data_record} = undef;

    #&main::main::print_log("MR26 entered read loop data\n") if (&main::main::new_second(10));
    return unless $data;
    &main::main::print_log("MR26 got data") if $main::Debug{mr26};

    # Data gets sent multiple times
    #  - Check time and loop count.  If mh paused (e.g. sending ir data)
    #    then we better also check loop count.
    #  - Process data only on the 2nd occurance, to avoid noise
    my $time        = &main::get_tickcount;
    my $repeat_time = $main::config_parms{MR26_multireceive_delay} or 400;
    my $repeat_data = ( $data eq $prev_data )
      && ( $time < $prev_time + $repeat_time
        or $main::Loop_Count < $prev_loop + 7 );
    return if $repeat_data and $prev_done;
    &main::main::print_log("MR26 data is not dupe") if $main::Debug{mr26};
    $prev_data = $data;
    $prev_time = $time;
    $prev_loop = $main::Loop_Count;

    unless ($repeat_data) {    # UnSet flag and wait for 2nd occurance
        $prev_done = 0;
        return;
    }
    $prev_done = 1;            # Set flag and process data

    my $hex = unpack "H*", $data;
    print "MR26 raw data: $hex\n" if $main::Debug{mr26};
    &main::main::print_log("MR26: raw data: $hex") if $main::Debug{mr26};

    # The decode_rf_bytes routine expects to get powerline and TV remote
    # data as a four byte stream with the second byte being the complement
    # of the first byte and the forth byte being the complement of third.
    # The decode_rf_bytes routine will cope with checksums not being present.
    # We can't just eliminate sending the extra two bytes because the
    # decode_rf_bytes routine is capable of handling security data which
    # does need unique data in byte four.
    my (@bytes);
    if ( ( $bytes[0], $bytes[2] ) = $data =~ /^\xd5\xaa(.)(.)$/ ) {

        my $state = X10_RF::decode_rf_bytes( 'MR26', @bytes );

        # If we got a bad checksum, throw out the rest of the data in the
        # buffer since we probably have a corrupt data stream.
        $main::Serial_Ports{MR26}{data_record} = undef
          if $state eq 'BADCHECKSUM';

    }
    else {

        # We weren't able to parse our four bytes of data for some reason,
        # throw out the rest of the data in the buffer since we probably have a
        # corrupt data stream.
        print "MR26: Unparsed data: $hex\n";
        $main::Serial_Ports{MR26}{data_record} = undef;
    }

}

#
# $Log: X10_MR26.pm,v $
# Revision 1.13  2004/07/18 22:16:37  winter
# *** empty log message ***
#
# Revision 1.12  2004/07/05 23:36:37  winter
# *** empty log message ***
#
# Revision 1.11  2003/12/22 00:25:06  winter
#  - 2.86 release
#
# Revision 1.10  2003/07/06 17:55:11  winter
#  - 2.82 release
#
# Revision 1.9  2003/04/20 21:44:08  winter
#  - 2.80 release
#
# Revision 1.8  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.7  2002/12/02 04:55:20  winter
# - 2.74 release
#
# Revision 1.6  2002/10/13 02:07:59  winter
#  - 2.72 release
#
# Revision 1.5  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.4  2001/08/12 04:02:58  winter
# - 2.57 update
#
# Revision 1.3  2001/06/27 03:45:14  winter
# - 2.54 release
#
# Revision 1.2  2001/05/06 21:12:01  winter
# - 2.51 release
#
#

=begin comment

>From Ray Dzek on 05/2001:

I found this link that is specifically for the MR26a.
  http://www.shed.com/tutor/mr26ant.html


>From Clay Jackson on 04/2001:

OK - here's how I solved the RF range issue (lack of range) with my MR26A.
My MR26 is located in a room with 5 computers and two ham radios (VHF and
HF) on the ground floor of our tri-level.  Before any 'enhancements', the
range of a PalmPad controller to the MR26 was about 10' (through one
interior wall, although that didn't seem to make much difference).  These
tests were conducted over the course of a few days, in a pretty 'informal'
fashion (I didn't have a tape measure, or any sort of RF 'range' set up, I
was just running around the house pushing buttons on the PalmPad, making
note of where I was and which buttons I pushed, and then reading the debug
logs from the computer running MH).  Since my receiver is in such an 'RF
rich' environment, I suspect anyone else's mileage will vary quite a bit,
but perhaps this will help with a baseline.  I did perform all the test with
fresh alkaline batteries in both the PalmPad and the various sensors.


First, I built the antenna described at
http://www.laser.com/dhouston/turnstil.htm (thanks Dave!).

Tests with the antenna wired to the end of the 'tail' coming out of the MR26
increased my reliable range to about 15'.  I also discovered that the
antenna performed best when vertically oriented (by almost double the
range), so all subsequent tests were conducted at

Next, I got an 'F' type (cable TV) through-plate connector and mounted it on
top of the MR26 (I'll try to get some pictures if someone's really
interested).  I soldered the ground on the connector to the large   Using
25' RG58 (50 Ohm cable, NOT 75 Ohm RG56) between the antenna and MR26 the
increased the reliable range to about 30'.

Then, I had a Radio Shack 'InLine Cable Amplifier' (15-1170) in my junk box,
so I put that in the line.  This amp delivers 10Db gain from 50-1170 MHz
(the X10 signals are around 319 MHz).  I only got about 10' more range with
this setup.  Since I have one HawkEye that's almost 100' away, that still
wasn't good enough (be careful to get the one that's 50-1170 MHz, and NOT
the 20db one that's only good from 450-2000 MHz).

So, I went out and bought a separately powered amp (again from Radio Shack,
part number  15-1112B) that delivers VARIABLE gain (there's a
pot on the side), up to 20Db.  With that installed, and the gain control
cranked all the way up, I get about 150' reliable range, BUT, I also see a
bunch of 'garbage' (basically bad values, an occasional stray signal that
still gets decoded correctly, but doesn't match one of my remotes).  If I
back the gain down to about 3/4 (assuming it's linear, that would probably
be somewhere between 12 and 15Db gain), the garbage goes away, and I get
reliable reception of the PalmPad, a couple of the SlimeFire switches, and
several HawkEye and EagleEye motion detectors, some of which are as much as
100' away from the receiver.

One of the reasons I was so interested in getting this working was that I
was expecting to see a much more rapid response to the RF 'event' (since the
path is now Sensor->MR26->MH->CM11->X10 Device, as opposed to Sensor->RF
Receiver->CM11->MH->CM11->X10 Device).  In fact, I did get much faster
response (I haven't measured, but the delay between sensor activation and
X10 response is almost imperceptible now).

--------------

>From Wally Kissel 

I also built the antenna.  I used the 'F' type balun and hot glued the
antenna and balun to a 18" square piece of cardboard.  I also drilled
a hole in the top of the MR26 and installed an 'F' style connector.  For my
purposes I connect the antenna directly to the top of the MR26 and get
about 30' range.  I think I'll play with some RF amps also.
Thanks for the info, Clay!

=cut

# vim: sw=4

1;
