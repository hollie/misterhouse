
# x10_item_test.pl
# Bob Hackenberg (rhackenb@cyberenet.net)
# January 24, 1999
#
# This code demonstrates the use of X10_Item to read the state of X10
# devices and set them conditionally. For testing, two lights, A1 and
# A2, are set up. Every three seconds the code checks the on/off
# states of the two devices.  If there is a difference between A1 and
# A2, then A2 is toggled to A1's state.  The state of A1 is changed
# manually with a Radio Shack Remote Power Center as the code is
# running.
#
# One problem is that when the code is first started up, $state1 and
# $state2 are both blank and don't get a value until A1 is toggled on
# or off manually.  If the 'my' is removed, then the state is saved by
# mh.  However, if the program stopped and then A1 is toggled manually
# to the opposite state, the code will start up with the old, now
# false value.

my $state1;
my $state2;
my $dev1 = "A1";
my $dev2 = "A2";

my $test_light1 = new X10_Item($dev1);
my $test_light2 = new X10_Item($dev2);

&check_lights;

sub check_lights {
    if ( $New_Second and !( $Second % 3 ) ) {
        $state1 = state $test_light1;
        print "$dev1 is $state1\n";
        $state2 = state $test_light2;
        print "$dev2 is $state2\n";
        if ( $state1 ne $state2 ) {
            set $test_light2 $state1;
        }
    }
}

