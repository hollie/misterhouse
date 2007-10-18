# Category=Insteon

#@ This module creates voice commands for all Insteon_Device, Insteon_Link and Insteon_PLM items.

if ($Reload) {
    my $insteon_menu_states = $config_parms{insteon_menu_states} if $config_parms{insteon_menu_states};
    &::print_log("Generating Voice commands for all Insteon objects");
    my $object_string;
    for my $object_name (keys %objects_by_object_name) {
        my $object = $objects_by_object_name{$object_name};
        next unless $object->isa('Insteon_Device') or $object->isa('Insteon_Link') or $object->isa('Insteon_PLM');
        my $command = $object_name;
        $command =~ s/^\$//;
        $command =~ tr/_/ /;
        my $object_name_v = $object_name . '_v';
        $object_string .= "use vars '${object_name}_v';\n";
        my $states = 'on,off';
        if ($object->isa('Insteon_Link')) {
           $states = 'on,off'; #,resume,enroll,unenroll,manual'; 
           my $cmd_states = $states;
           my $group = $object->group;
           if ($object->device_id eq '000000') {
              $cmd_states .= ',initiate linking as controller,cancel linking';
           }
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->initiate_linking_as_controller(\"$group\")', 'initiate linking as controller');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->interface()->cancel_linking','cancel linking');\n\n";
           $object_string .= "$object_name_v -> tie_items($object_name, 'on');\n\n";
           $object_string .= "$object_name_v -> tie_items($object_name, 'off');\n\n";
           $object_string .= &store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_link_commands');
        } elsif ($object->isa('Insteon_Device')) {
           $states = $insteon_menu_states if $insteon_menu_states;
           my $cmd_states = "$states,status,scan link table"; #,on level,ramp rate";
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           foreach my $state (split(/,/,$states)) {
              $object_string .= "$object_name_v -> tie_items($object_name, '$state');\n\n";
           }
           $object_string .= "$object_name_v -> tie_event('$object_name->request_status','status');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->scan_adlb','scan link table');\n\n";
# the remote_set_button_taps provide incorrect/inconsistent results
#           $object_string .= "$object_name_v -> tie_event('$object_name->remote_set_button_tap(1)','on level');\n\n";
#           $object_string .= "$object_name_v -> tie_event('$object_name->remote_set_button_tap(2)','ramp rate');\n\n";
           $object_string .= &store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_item_commands');
        } elsif ($object->isa('Insteon_PLM')) {
           my $cmd_states = "initiate linking as responder,cancel linking";
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->initiate_linking_as_responder','initiate linking as responder');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->cancel_linking','cancel linking');\n\n";
           $object_string .= &store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_PLM_commands');
        }
    }
    eval $object_string;
    print "Error in insteon_item_commands: $@\n" if $@;
}

