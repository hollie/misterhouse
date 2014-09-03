
# Category = X10

#@ This module creates voice commands for all X10 and derivative items.

if ($Reload) {
    print_log "Generating Voice commands for all X10 objects";
    my $object_string;
    for my $object_name ( keys %objects_by_object_name ) {
        my $object = $objects_by_object_name{$object_name};
        next unless $object->isa('X10_Item') or $object->isa('X10SL_Scene');
        my $command = $object_name;
        $command =~ s/^\$//;
        $command =~ tr/_/ /;
        my $object_name_v = $object_name . '_v';
        $object_string .= "use vars '${object_name}_v';\n";
        my $states = 'on,off,status';

        if ( $object->isa('X10_Item') ) {
            my $states = 'on,off,status';
            $states = $config_parms{x10_menu_states}
              unless $object->isa('X10_Appliance')
              or $object->isa('X10_Appliancelinc');
            $states .=
              ',add to scene,remove from scene,set ramp rate,set on level'
              if $object->isa('X10_Switchlinc')
              or $object->isa('X10_Appliancelinc')
              or $object->isa('X10_Lamplinc')
              or $object->isa('X10_Keypadlinc');
            $object_string .=
              "$object_name_v  = new Voice_Cmd '$command [$states]';\n";
            $object_string .= "$object_name_v -> tie_items($object_name);\n\n";
            $object_string .=
              &store_object_data( $object_name_v, 'Voice_Cmd', 'X10',
                'x10_item_commands' );
        }
        else {
            $states = 'on,off,resume,enroll,unenroll,manual';
            $object_string .=
              "$object_name_v  = new Voice_Cmd '$command [$states]';\n";
            $object_string .=
              "$object_name_v -> tie_event('$object_name->enroll', 'enroll');\n\n";
            $object_string .=
              "$object_name_v -> tie_event('$object_name->remove_all_members', 'unenroll');\n\n";
            $object_string .=
              "$object_name_v -> tie_items($object_name, 'on');\n\n";
            $object_string .=
              "$object_name_v -> tie_items($object_name, 'off');\n\n";
            $object_string .=
              "$object_name_v -> tie_items($object_name, 'resume');\n\n";
            $object_string .=
              "$object_name_v -> tie_items($object_name, 'manual');\n\n";
            $object_string .=
              &store_object_data( $object_name_v, 'Voice_Cmd', 'X10',
                'x10_scene_commands' );
        }
    }
    eval $object_string;
    print "Error in x10_item_commands: $@\n" if $@;
}

