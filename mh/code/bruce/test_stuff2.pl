
# Category = Test

#$front_door2        = new    Serial_Item('0101', ON, 'serial_relays');
#$front_door2       -> add               ('0100', OFF);

#set $front_door2 ON if $New_Second and ! ($Second % 5);
#print "db1 $front_door2\n"  if $New_Second and ! ($Second % 5);

 
if ($New_Second or time_cron('00 * * * *'))
{
#    print list_object_types();
#    print lib_objects_by_type("Compool_Item");
}

#&test_sub1;
