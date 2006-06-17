
# Category = X10

#@ This module creates voice commands for all X10 and derivative items.

if ($Reload) {
    print_log "Generating Voice commands for all X10 objects";
    my $object_string;
    for my $object_name (keys %objects_by_object_name) {
        my $object = $objects_by_object_name{$object_name};
        next unless $object->isa('X10_Item');
        my $command = $object_name;
        $command =~ s/^\$//;
        $command =~ tr/_/ /;
        my $object_name_v = $object_name . '_v';
        my $states = 'on,off';
        $states = 'on,off,brighten,dim,20%,40%,60%,80%,100%,-35,+35,-50%,+50%' unless $object->isa('X10_Appliance');
        $object_string .= "use vars '${object_name}_v';\n";
        $object_string .= "$object_name_v  = new Voice_Cmd '$command [$states]';\n";
        $object_string .= "$object_name_v -> tie_items($object_name);\n\n";
        $object_string .= &store_object_data($object_name_v, 'Voice_Cmd', 'X10', 'x10_item_commands');
    }
    eval $object_string;
    print "Error in x10_item_commands: $@\n" if $@;
}

