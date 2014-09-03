
# An example of listing groups that objects are members of

if ( new_second 5 ) {
    print "\nTesting find_group\n";
    for my $object_name ( &list_objects_by_type('X10_Item') ) {
        my $object = &get_object_by_name($object_name);
        for my $group ( &list_groups_by_object($object) ) {
            print
              "$object->{object_name} is a member of $group->{object_name}\n";
        }
    }
}

