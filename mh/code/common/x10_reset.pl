
# Category = MisterHouse

#@ This module resets all X10 items after a power fail or when selected manually.

run_voice_cmd 'Reset all X10 Items' if state_now $Power_Supply eq 'Restored';

$reset_x10_states = new Voice_Cmd 'Reset all X10 Items';
$reset_x10_states ->set_info('Used to reset the state of X10 devices after a power fail.  Warning, this can take a while if you have a lot of X10 devices.');

if (said $reset_x10_states) {
    speak "Resetting all X10 devices";
    my ($object_name, $object, $state, $level);

# Use this if you have a Group called PFL with the list of items you wanted restored
#   for $object (list $PFL) {

# Use this to reset all X10 items ... probably a bad thing to do.
    for $object_name (keys %objects_by_object_name) {
        $object = $objects_by_object_name{$object_name};
        next unless $object->isa('X10_Item');
        if ($state = state $object) {
                                # Deal with non-ON/OFF states
            if (defined($level = $object->{level})) {
                $state = $level;
                $state =  ON if $level == 100;
                $state = OFF if $level ==   0;
                undef $object->{level}; # Module was reset
            }
            print_log "Setting $object_name to $state (level=$level)";
            set $object $state;
        }
    }
}
