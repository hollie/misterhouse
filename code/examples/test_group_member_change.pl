
# Example of detecting which member changed in a group

$m1 = new Generic_Item;
$m2 = new Generic_Item;
$m3 = new Generic_Item;

$mg = new Group( $m1, $m2, $m3 );

if ( new_second 15 ) {
    set $m1 TOGGLE;
    set $m3 TOGGLE;
    print "toggleing items\n";
}

if ( $state = state_now $mg) {
    my $member = member_changed $mg;
    print "pass=$Loop_Count: mg changed to $state by $member\n";
}

