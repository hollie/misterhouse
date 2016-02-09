
# Process requests from the clicks on button_light images

# Use 'server side' image map xy to notice dim/bright requrests
# ISMAP data looks like this:  state?39,24
# Example: http://house:8080/bin/button_action.pl?X10_Item&$all_lights_living&on?39,24

my ( $list_name, $item, $state_xy ) = @ARGV;

my ( $state, $x, $y ) = $state_xy =~ /(\S+)\?(\d+),(\d+)/;

#print "db ln=$list_name, i=$item, s=$state_xy xy=$x,$y\n";

my $object = &get_object_by_name($item);

if ( $object->isa('X10_Item') && !$object->isa('X10_Appliance') ) {

    # Do not dim the dishwasher :)

    # Dim if clicked on left side of image, brighten if clicked on right
    # side of image, or use state passed through the button URL if clicked
    # in the center of the image.
    if ( $x < 40 ) {
        $state = 'dim';
    }
    elsif ( $x > 110 ) {
        $state = 'brighten';
    }
}
elsif ( $object->isa('EIB7_Item') ) {    # Motor/drive states are stop/up/down
    $state = 'stop';
    $state = 'down' if $x < 40;          # Left  side of image
    $state = 'up' if $x > 110;           # Right side of image
}
elsif ( $object->isa('Insteon::DimmableLight') ) {
    my @states     = $object->get_states();
    my $curr_state = $object->state();

    # Find the index into @states for the element that corresponds to the
    # current state.
    my ($index) = grep { $states[$_] eq $curr_state } 0 .. $#states;

    # Dim if clicked on left side of image, brighten if clicked on right
    # side of image, or use state passed through the button URL if clicked
    # in the center of the image.
    if ( $x < 40 ) {
        $index-- if ($index);    # Can't dim if light is off
        $state = $states[$index];
    }
    elsif ( $x > 110 ) {
        $index++
          if ( $index != $#states );    # Can't brighten if light is fully on
        $state = $states[$index];
    }
}

$object->set( "$state", 'web' );

#   print "dbx4a i=$item s=$state\n";
#   my $object = &get_object_by_name($item);
#   $state =   $$object{state};
#   print "dbx4b i=$item s=$state\n";

# Internal state of INSTEON devices does not change immediately after
# clicking on the button. That is because, unlike X10 devices (for example),
# an acknowledgement from the INSTEON device needs to be received so MH
# can change the internal state. If we finish the HTTP transaction before
# the acknowledge comes back then the resulting HTML page will display the
# object that was just clicked on in the old state. This delay here prevents
# this problem at the expense of, well, an extra delay. As this is
# experimental, and this delay causes MH to pause for the duration of the
# delay, this is currently disabled by default. But feel free to enable
# to see if things improve.
#sleep(1);

my $h = &referer("/bin/list_buttons.pl?$list_name");

return &http_redirect($h);
