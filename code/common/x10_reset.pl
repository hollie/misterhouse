
# Category = X10

#@ This module resets all X10 items after a power fail or when selected manually.

$v_reset_x10_states = new Voice_Cmd 'Restore all X10 items';
$v_reset_x10_states->set_info(
    'Used to restore the state of X10 devices after a power fail.  Warning, this can take a while if you have a lot of X10 devices.'
);

# Create trigger to reset all X10 items on power restore

if ($Reload) {
    my $command = 'state_now $Power_Supply =~ /restored/i';
    &trigger_set( $command, "run_voice_cmd('Restore all X10 items')",
        'NoExpire', 'restore x10 items' )
      unless &trigger_get('restore x10 items');
}

# Events

if ( said $v_reset_x10_states) {
    $v_reset_x10_states->respond(
        "Restoring all X10 items to previous states...");
    my ( $object_name, $object, $state, $level );

    # Use this if you have a Group called PFL with the list of items you wanted restored
    #   for $object (list $PFL) {

    # Use this to reset all X10 items ... probably a bad thing to do.
    for $object_name ( keys %objects_by_object_name ) {
        $object = $objects_by_object_name{$object_name};
        next unless $object->isa('X10_Item');
        if ( $state = state $object) {

            # Deal with non-ON/OFF states
            if ( defined( $level = $object->{level} ) ) {
                $state = $level;
                $state = ON if $level == 100;
                $state = OFF if $level == 0;
                undef $object->{level};    # Module was reset
            }
            print_log "Setting $object_name to $state (level=$level)";
            set $object $state;
        }
    }
}
