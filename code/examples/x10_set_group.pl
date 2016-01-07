
=begin comment

From Scott Reston on 3/2002

here's a piece of code i put together for a specific need i had and thought
someone else might be able to use it... when i hit a bedside button at night,
i needed to turn off every light in the house except the light next to my bed
so that i could read for a bit. thus, the "set_all_but". you can set a group
to a certain level and have it skip specified items.

=cut

$v_set_all_but = new Voice_Cmd('Test Set All But');
if ( said $v_set_all_but) {

    #&set_all_but($Indoor_Lights, 'OFF', $Master_Scott_Light); # turn off all indoor lights except scott's reading light
    &set_all_but( $Indoor_Lights, 'OFF', list $Kitchen, list $Living_room)
      ; #turn off all indoor lights except the kitchen and living room lights (groups)
}

sub set_all_but {

    # look for the arguments... the group to set, the state to set them to and the items that should be skipped
    my ( $group, $state, @items_to_skip ) = @_;

    # step through each item in the group ($item gets valued for each pass)
    foreach my $item ( list $group) {

        my $found = 0
          ; # zero out the variable that we'll set to 1 if this $item is in the list of objects to be ignored
        foreach my $item_to_skip (@items_to_skip)
        {    # step through the items to skip...
            $found = 1
              if $item == $item_to_skip
              ; # and make see if the item to skip is the current $item we are about to set (from the outer foreach loop)
        } # is there a better way to do that? does perl have a 'list contains ...' type function?

        set $item $state
          unless $found
          ; # if it wasn't in the skip list, go ahead and set it to the specified state
        print_log "setting " . $item->{object_name} . " to " . $state
          unless $found;    # log what we're doing...

    }

}
