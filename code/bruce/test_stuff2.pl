
#@ Test stuff :)

$test_x10_all_o = new X10_Item 'O';
print_log "house code O set to $state" if $state = state_now $test_x10_all_o;

speak 'fan light' if state_now $living_fan_light;

#if (new_minute) {
#    print "sp=$Save{sleeping_parents} sz=$Save{sleeping_zack}\n";
#}

#if (new_second 15) {
#    print "Setting pedistal light\n";
#    set $pedestal_light 'off';
#    set $pedestal_light 'on';
#    set $pedestal_light '-50';
#   set $pedestal_light '-60';
#}

#    $state = dark $sensor_bathroom;
#    print_log "Bathroom dark is $state";
#    $state = light $sensor_bathroom;
#    print_log "Bathroom light is $state";
#}

$incoming_x10_data = new Serial_Item 'XO7';

if ( $state = said $incoming_x10_data) {
    print "X10 data: $state\n";

    #    set $proxy_server $state if active $proxy_server;
}

#speak "Driveway light set to $state" if $state = state_now $driveway_light;

# Category=Other_Scheduled_Events
run_voice_cmd "Itemize the Call Log" if ( time_now '7:25 PM' );

#run_voice_cmd "What time is it" if new_second 10;

# Category = Test

#$front_door2        = new    Serial_Item('0101', ON, 'serial_relays');
#$front_door2       -> add               ('0100', OFF);

#set $front_door2 ON if $New_Second and ! ($Second % 5);
#print "db1 $front_door2\n"  if $New_Second and ! ($Second % 5);

$Light1  = new X10_Item 'O6';
$Light1X = new Serial_Item 'X';

$test_stuff2 = new Voice_Cmd 'Test stuff 2';
if ( said $test_stuff2) {
    set $Light1 '+5';
    set $Light1X 'XO7O+5';

    #    set $furnace_heat ON;
    #   select undef, undef, undef, 0.1; # New cards need this?
    #    set $furnace_fan  ON;
}

#print "key=$Keyboard" if $Keyboard;

print_log "Test state set on pass $Loop_Count" if state_now $test_stuff2;

print_log "File has been updated" if $New_Second and file_change "/temp/junk1";

#$test_light_a = new X10_Item 'K4';
#print_log "Light changed to $state" if $state = state_now $test_light_a;

#print "db sensor=$sensor_bathroom->{state}\n" if $New_Second;

# Test mirroring objects via xAP
$test_item1 = new Generic_Item;
$test_item1->xAP_enable(1);

#$test_item1 -> set(TOGGLE) if new_second 30;
