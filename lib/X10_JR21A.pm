
=begin comment

Original authors: Kevin Olande, Wally Kissel, Fenghua Zong
Adapted by: Denis Cheong

This code is a modified version of the original MR26A module
which supports the JR21A X-10 MouseRemote receiver with the
corresponding MouseRemote control (JR20A)

The JR20A has an "X10" mode, however the JR21A does not receive
or decode signals sent while the JR20A is in X10 mode, so you
need to use the PC mode instead.  The same buttons should
do the same things anyway.

Use these mh.ini parameters to enable this code:

 JR21A_module = X10_JR21A
 JR21A_port   = COM1

This will set any X10_Item that matches X10 codes received.

To monitor other keys (e.g. Play,Pause, etc), you can use
something like this:

 $Remote  = new X10_MR26;
 $Remote -> tie_event('print_log "MR26 key: $state"');
 set $TV $state if $state = state_now $Remote;


=cut

use strict;

package X10_JR21A;

@X10_JR21A::ISA = ('Generic_Item');

# Initialise the house/unit codes ...
my $house = "A";
my $unit  = "1";

sub startup {

    # The JR21A runs at 1200 N-8-1 DTR & RTS on
    &main::serial_port_create( 'JR21A', $main::config_parms{JR21A_port},
        1200, 'none', 'record' );

    # Add hook only if serial port was created ok
    &::MainLoop_pre_add_hook( \&X10_JR21A::check_for_data, 1 )
      if $main::Serial_Ports{JR21A}{object};

    $house = $main::config_parms{JR21A_house};

    print "House: $house\n";

    $house = "A" if ( !$house );

    &main::main::print_log("JR21A Default house set to $house\n")
      if $main::config_parms{debug} eq 'JR21A';
}

# House codes A-P
my %hcodes =
  qw(6 A 7 B 4 C 5 D   8 E 9 F a G b H   e I f J c K d L   0 M 1 N 2 O 3 P );

# Unit codes: 1-9,A-G.  J/K => ON/OFF, O/P => All-ON/OFF L/M => bright/dim
# Note on old keycahin remotes (HC40TX):
#   Normal (e.g. palmpad) sends 'd5aaf050ad' for J6 ON
#   Old keychain remote   sends 'd5aaf810ad' for J6 ON
my %ucodes = qw(000 1J 010 2J 008 3J 018 4J 040 5J 050 6J 048 7J 058 8J
  400 9J 410 AJ 408 BJ 418 CJ 440 DJ 450 EJ 448 FJ 458 GJ
  020 1K 030 2K 028 3K 038 4K 060 5K 070 6K 068 7K 078 8K
  420 9K 430 AK 428 BK 438 CK 460 DK 470 EK 468 FK 478 GK

  090 O  080 P  088 L  098 M  800 5J 810 6J 820 5K 830 6K);

# UR51A Function codes:
#  - OK and Ent are same, PC and Subtitle are same,
#  - Chan buttons and Skip buttons are same

my %vcodes = qw(f0 Power  d4 PC    d6 Title  3a Display 52 Enter d8 Return
  d5 Up     d3 Down  d2 Left   d1 Right   b6 Menu  c9 Exit
  38 Rew    b0 Play  b8 FF     ff Record  70 Stop  72 Pause
  f2 Recall 82 1     42 2      c2 3       22 4     a2 5
  62 6      e2 7     12 8      92 9       ba AB    02 0
  40 Ch+    c0 Ch-   e0 Vol-   60 Vol+    a0 Mute);

my ( $prev_data, $prev_time, $prev_loop );
$prev_data = $prev_time = 0;

sub check_for_data {

    package main;

    my ($self) = @_;
    &main::check_for_generic_serial_data('JR21A');
    my $data = $main::Serial_Ports{JR21A}{data};
    $main::Serial_Ports{JR21A}{data} = '';
    return unless $data;

    my $hex = unpack "H10", $data;
    &main::main::print_log("JR21A Data: $hex")
      if $main::config_parms{debug} eq 'JR21A';

    my ($state);

    # The following block of code is no longer used with the JR21A,
    # it was all for the old MR26, it will stay here to serve as an example
    # until the corresponding commands are completed for the JR21A
    # The first line isn't held true for the JR21A so it never gets executed
    # anyway.

    if ( my ( $n1, $n2, $b2 ) = $hex =~ /^d5aa(.)(.)(..)ad/ ) {

        # Handle TV/VCR type data
        if ( $n1 . $n2 eq 'ee' ) {
            print "JR21A Bad ee data: $b2.\n"
              unless defined( $state = $vcodes{$b2} );
        }

    }
    else {
        # Data often gets sent multiple times
        #  - check time and loop count.  If mh paused (e.g. sending ir data)
        #    then we better also check loop count.

        my $time = &main::get_tickcount;
        return
          if $hex eq $prev_data
          and
          ( $time < $prev_time + 600 or $main::Loop_Count < $prev_loop + 6 );
        $prev_data = $hex;
        $prev_time = $time;
        $prev_loop = $main::Loop_Count;

        my $state;
        my $cmd = "";

        SWITCH: {
            # The JR21A seems to send cd while it's being initialised,
            # we'll regard it as a confirmation that it is present
            if ( $hex eq "cd" ) {
                print "JR21A: Recognised on $main::config_parms{JR21A_port}\n";
                last SWITCH;
            }

            # These are the defined commands

            # We need a key to use as shift to enter device 11-16
            # probably Up arrow

            # We probably also need something to switch house codes ...

            if ( $hex eq "c5a0ff" ) {
                speak("Device 1 active");
                $unit = "1";
                last SWITCH;
            }
            if ( $hex eq "c541ff" ) {
                speak("Device 2 active");
                $unit = "2";
                last SWITCH;
            }
            if ( $hex eq "c5d0ff" ) {
                speak("Device 3 active");
                $unit = "3";
                last SWITCH;
            }
            if ( $hex eq "c542ff" ) {
                speak("Device 4 active");
                $unit = "4";
                last SWITCH;
            }
            if ( $hex eq "c5a1ff" ) {
                speak("Device 5 active");
                $unit = "5";
                last SWITCH;
            }
            if ( $hex eq "c543ff" ) {
                speak("Device 6 active");
                $unit = "6";
                last SWITCH;
            }
            if ( $hex eq "c5e8ff" ) {
                speak("Device 7 active");
                $unit = "7";
                last SWITCH;
            }
            if ( $hex eq "c544ff" ) {
                speak("Device 8 active");
                $unit = "8";
                last SWITCH;
            }
            if ( $hex eq "c5a2ff" ) {
                speak("Device 9 active");
                $unit = "9";
                last SWITCH;
            }
            if ( $hex eq "c540ff" ) {
                speak("Device 10 active");
                $unit = "A";
                last SWITCH;
            }

            if ( $hex eq "c4f4ff" ) { $cmd = "O";        last SWITCH; }
            if ( $hex eq "c4a1ff" ) { $cmd = "P";        last SWITCH; }
            if ( $hex eq "c441ff" ) { $cmd = "${unit}J"; last SWITCH; }
            if ( $hex eq "c4d0ff" ) { $cmd = "${unit}K"; last SWITCH; }
            if ( $hex eq "c443ff" ) { $cmd = "${unit}L"; last SWITCH; }
            if ( $hex eq "c4e8ff" ) { $cmd = "${unit}M"; last SWITCH; }

            if ( $hex eq "c5d5ff" ) { print "JR21A: Up arrow\n"; last SWITCH; }
            if ( $hex eq "c545ff" ) { print "JR21A: ENT\n";      last SWITCH; }
            if ( $hex eq "cffdcffdcf" ) {
                print "JR21A: Up-Left\n";
                last SWITCH;
            }
            if ( $hex eq "cc40318031" ) { print "JR21A: Up\n"; last SWITCH; }
            if ( $hex eq "cca0318131" ) {
                print "JR21A: Up-Right\n";
                last SWITCH;
            }
            if ( $hex eq "c301c301c3" ) { print "JR21A: Left\n";  last SWITCH; }
            if ( $hex eq "c020102c04" ) { print "JR21A: Right\n"; last SWITCH; }
            if ( $hex eq "c305c305c3" ) {
                print "JR21A: Down-Left\n";
                last SWITCH;
            }
            if ( $hex eq "c040201828" ) { print "JR21A: Down\n"; last SWITCH; }
            if ( $hex eq "c0a0102c14" ) {
                print "JR21A: Down-Right\n";
                last SWITCH;
            }
            if ( $hex eq "e040201c08" ) {
                print "JR21A: Left button down\n";
                last SWITCH;
            }
            if ( $hex eq "d040201a08" ) {
                print "JR21A: Right button down\n";
                last SWITCH;
            }
            if ( $hex eq "c040201808" ) {
                print "JR21A: Button up\n";
                last SWITCH;
            }
            if ( $hex eq "c4d5ff" ) { print "JR21A: PC\n";    last SWITCH; }
            if ( $hex eq "c6d5ff" ) { print "JR21A: CD\n";    last SWITCH; }
            if ( $hex eq "c6d1ff" ) { print "JR21A: WEB\n";   last SWITCH; }
            if ( $hex eq "c7d1ff" ) { print "JR21A: DVD\n";   last SWITCH; }
            if ( $hex eq "c5d1ff" ) { print "JR21A: PHONE\n"; last SWITCH; }
            if ( $hex eq "c5a7ff" ) { print "JR21A: A-B\n";   last SWITCH; }
            if ( $hex eq "c54eff" ) { print "JR21A: DISP\n";  last SWITCH; }
            if ( $hex eq "c4a3ff" ) { print "JR21A: PLAY\n";  last SWITCH; }
            if ( $hex eq "c447ff" ) { print "JR21A: STOP\n";  last SWITCH; }
            if ( $hex eq "c4a7ff" ) { print "JR21A: FF\n";    last SWITCH; }
            if ( $hex eq "c44eff" ) { print "JR21A: REW\n";   last SWITCH; }
            if ( $hex eq "c5abff" ) { print "JR21A: GUIDE\n"; last SWITCH; }
            if ( $hex eq "c7fdff" ) { print "JR21A: REC\n";   last SWITCH; }
            if ( $hex eq "c547ff" ) { print "JR21A: PAUSE\n"; last SWITCH; }
            if ( $hex eq "c5f4ff" ) { print "JR21A: last\n";  last SWITCH; }

            # Select does not send anything on my remote
            if ( $hex eq "c6d2ff" ) { print "JR21A: SELECT\n"; last SWITCH; }

            #print "JR21A: Bad data: $hex\n";
        }
        if ($cmd) {
            substr( $cmd, 1, 0 ) = $house
              if length $cmd == 2;    # Need XA1AJ, not XA1J

            $state = "X" . $house . $cmd;

            &main::process_serial_data($state)
              if $state;              # Set states on X10_Items
        }

        # Set state of all JR21A objects
        for my $name ( &main::list_objects_by_type('X10_JR21A') ) {
            my $object = &main::get_object_by_name($name);
            $object->set($state);
        }
    }

}

1;
