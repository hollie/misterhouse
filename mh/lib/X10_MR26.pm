
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

To monitor other keys (e.g. Play,Pause, etc), you can use 
something like this:

 $Remote  = new X10_MR26;
 $Remote -> tie_event('print_log "MR26 key: $state"');
 set $TV $state if $state = state_now $Remote;


Note on range.  Depending on who knows what, people have reported 
a maximum range for 10 -> 50 feet from receiver to remote. 
See comment at the end of this file for hints on increasing the range.

=cut

use strict;

package X10_MR26;

@X10_MR26::ISA = ('Generic_Item');

sub startup {
    &main::serial_port_create('MR26', $main::config_parms{MR26_port}, 9600, 'none', 'raw');
                                # Add hook only if serial port was created ok
    &::MainLoop_pre_add_hook(  \&X10_MR26::check_for_data, 1 ) if $main::Serial_Ports{MR26}{object};
}

                                # House codes A-P
my %hcodes = qw(6 A 7 B 4 C 5 D   8 E 9 F a G b H   e I f J c K d L   0 M 1 N 2 O 3 P );

# Unit codes: 1-9,A-G.  J/K => ON/OFF, O/P => All-ON/OFF L/M => bright/dim
# Note on old keycahin remotes (HC40TX):
#   Normal (e.g. palmpad) sends 'd5aaf050ad' for J6 ON
#   Old keychain remote   sends 'd5aaf810ad' for J6 ON
my %ucodes = qw(000 1J 010 2J 008 3J 018 4J 040 5J 050 6J 048 7J 058 8J
                400 9J 410 AJ 408 BJ 418 CJ 440 DJ 450 EJ 448 FJ 458 GJ
                020 1K 030 2K 028 3K 038 4K 060 5K 070 6K 068 7K 078 8K
                420 9K 430 AK 428 BK 438 CK 460 DK 470 EK 468 FK 478 GK
                090 O  080 P  088 L 098 M 800 5J 810 6J 820 5K 830 6K);


                                # UR51A Function codes:  
                                #  - OK and Ent are same, PC and Subtitle are same, 
                                #  - Chan buttons and Skip buttons are same
my %vcodes = qw(f0 Power d4 PC d6 Title 3a Display 52 Enter d8 Return
                d5 Up d3 Down d2 Left d1 Right b6 Menu c9 Exit 38 Rew
                b0 Play b8 FF ff Record 70 Stop 72 Pause f2 Recall
                82 1 42 2 c2 3 22 4 a2 5 62 6 e2 7 12 8 92 9
                ba AB 02 0 40 Ch+ c0 Ch- e0 Vol- 60 Vol+ a0 Mute);

my ($prev_data, $prev_time, $prev_loop);
$prev_data = $prev_time = 0;

sub check_for_data {
    my ($self) = @_;
    &main::check_for_generic_serial_data('MR26');
    my $data = $main::Serial_Ports{MR26}{data};
    $main::Serial_Ports{MR26}{data} = '';
    return unless $data;

    my $hex = unpack "H10", $data;
    &main::main::print_log("MR26 Data: $hex") if $main::config_parms{debug} eq 'MR26';

    if (my ($n1, $n2, $b2) = $hex =~ /^d5aa(.)(.)(..)ad/)  {
        
                                # Data often gets sent multiple times
                                #  - check time and loop count.  If mh paused (e.g. sending ir data)
                                #    then we better also check loop count.
        my $time = &main::get_tickcount;
        return if $hex eq $prev_data and ($time < $prev_time + 600 or $main::Loop_Count < $prev_loop + 6);
        $prev_data = $hex;
        $prev_time = $time;
        $prev_loop = $main::Loop_Count;

                                # Handle TV/VCR type data
        my ($state);
        if ($n1 . $n2 eq 'ee') {
            print "MR26 Bad ee data: $b2.\n" unless defined($state = $vcodes{$b2});
        }
                                # Handle normal X10 data
        else {
            my $house = $hcodes{$n1};
            my $unit  = $ucodes{$n2 . $b2};
            if ($house and $unit) {
                substr($unit, 1, 0) = $house if length $unit == 2; # Need XA1AJ, not XA1J
                $state = "X$house$unit";
                &main::process_serial_data($state) if $state; # Set states on X10_Items
            }
            else {
                print "MR26 Bad X10 data: $n1,$n2$b2 house=$house unit=$unit\n";
            }
        }
        &main::main::print_log("MR26 Code: $state") if $main::config_parms{debug} eq 'MR26';

                                # Set state of all MR26 objects
        for my $name (&main::list_objects_by_type('X10_MR26')) {
            my $object = &main::get_object_by_name($name);
            $object -> set($state);
        }
    }
    else {
        print "MR26: Bad data: $hex\n";
    }


}

#
# $Log$
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

From Ray Dzek on 05/2001:

I found this link that is specifically for the MR26a.
  http://www.shed.com/tutor/mr26ant.html


From Clay Jackson on 04/2001:

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

From Wally Kissel 

I also built the antenna.  I used the 'F' type balun and hot glued the
antenna and balun to a 18" square piece of cardboard.  I also drilled
a hole in the top of the MR26 and installed an 'F' style connector.  For my
purposes I connect the antenna directly to the top of the MR26 and get
about 30' range.  I think I'll play with some RF amps also.
Thanks for the info, Clay!

=cut

1;
