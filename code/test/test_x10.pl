# Category=Test

#@ This has simple examples for controling and monitoring X10 data.

my $light_states = 'on,brighten,dim,off';
my $state;

#
#  Note: X10 items are now defined in test_x10.mht
#
#$test_light1 = new X10_Item('A1');
#$test_light2 = new X10_Item('B1');
#$test_appliance = new X10_Appliance('B2');

# If you have more than one X10 interface, and want to choose which
# one gets used to control a device, you can specify the
# interface name as a second parameter, like this:
#    $test_light_1 = new X10_Item('A1', 'CM11');
#    $test_light_1 = new X10_Item('B1', 'CM17');

$v_test_light2 = new Voice_Cmd("Turn test light 2 [$light_states]");

#set $test_light2 $state if $state = said $v_test_light_2;
tie_items $v_test_light2 $test_light2;

$v_test_lights = new Voice_Cmd("All lights [$light_states]");
set $All_Lights $state if $state = said $v_test_lights;

# Toggle the light on/off every 30 seconds
if ( $New_Second and !( $Second % 30 ) ) {
    my $state = ( 'on' eq state $test_light1) ? 'off' : 'on';
    set $test_light1 $state;
    my $remark = "Light set to $state";
    print_log "$remark";

    #   speak $remark;
}

# Respond if the A2 button is pushed
$test_button = new Serial_Item('XA2');
if ( state_now $test_button) {
    my $remark = "You just pushed the A2 button";
    print_log "$remark";
    speak $remark;
}
