
# This shows a way to list all objects of a specific type

$test_group = new Voice_Cmd 'Turn all [X10_Item,X10_Appliance] items off';

if ( my $type = said $test_group) {
    for my $name ( &list_objects_by_type($type) ) {
        print "Turning $name off";
        my $object = &get_object_by_name($name);
        set $object OFF;
    }
}
