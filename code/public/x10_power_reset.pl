
# Example from Steve Flick of how to reset items in a group after a power reset

if ( New_Minute and $ControlX10::CM11::POWER_RESET ) {
    display time => 0, text => "Detected a CM11 power reset";
    $ControlX10::CM11::POWER_RESET = 0;
}

if ( state_now $Power_Supply eq 'Restored' ) {
    print_log "log=test.log Power restored" if $istest;
    &power_reset($PFL);
}

sub power_reset {
    my ($group) = @_;
    my ( $object_name, $object, $state, $level );
    for $object ( list $group) {
        next unless $object->isa('X10_Item');
        if ( $state = state $object) {
            if ( defined( $level = $object->{level} ) ) {
                $state = $level;
                undef $object->{level};    # Module was reset
            }
            print_log "Setting $object_name to $state (level=$level)";
            set $object $state;
        }
    }
}

# Use this to reset all X10 items ... probably a bad thing to do.

sub power_reset_all {
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
