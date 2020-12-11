
=begin comment 

From Dave Lounsberry on 02/2002:

I also included my weederA.pl code that supports the new weeder Solid
State Relay board. Nothing fancy really thanks to Serial_Item. The board
supports status queries and other fancy functions that I have not coded
for as of yet, mainly because I have no real need for them. The
garage_door_button does use the builtin timer function that simulates a
push of the garage door button. 

=cut

# Category=Other

$v_test_hvac_heat = new Voice_Cmd('Set test HVAC heat to [ON,OFF]');
if ( $state = said $v_test_hvac_heat) {
    set $hvac_heat_relay $state;
    speak "HVAC heat set to $state";
}

$v_test_hvac_ac = new Voice_Cmd('Set test HVAC AC to [ON,OFF]');
if ( $state = said $v_test_hvac_ac) {
    set $hvac_ac_relay $state;
    speak "HVAC AC set to $state";
}

$v_test_hvac_fan = new Voice_Cmd('Set test HVAC fan to [ON,OFF]');
if ( $state = said $v_test_hvac_fan) {
    set $hvac_fan_relay $state;
    speak "HVAC fan set to $state";
}

$v_test_gdoor_button = new Voice_Cmd('Push garage door button');
if ( $state = said $v_test_gdoor_button) {
    set $garage_door_button 'push';
    speak "Garage door button pushed.";
}

$v_weeder_status = new Voice_Cmd('Get status of weeder board A');
if ( $state = said $v_weeder_status) {
    set $weeder_a 'status';
    speak "Getting status of HVAC test";
}

if ( my $stat = said $weeder_a) {
    if ( $stat eq '(.?)!' ) {
        speak "weeder relay board $1 just reset.";
    }
    elsif ( $stat eq '(.?)?' ) {
        speak "weeder relay board $1 received error.";
    }
}

#set $test_garage_door_button 'push' if $New_Minute;

$weeder_a = new Serial_Item( 'AR', 'status', 'weeder' );

$hvac_heat_relay = new Serial_Item( 'ACA', ON, 'weeder' );
$hvac_heat_relay->add( 'AOA', OFF,      'weeder' );
$hvac_heat_relay->add( 'ARA', 'status', 'weeder' );

$hvac_ac_relay = new Serial_Item( 'ACB', ON, 'weeder' );
$hvac_ac_relay->add( 'AOB', OFF,      'weeder' );
$hvac_ac_relay->add( 'ARB', 'status', 'weeder' );

$hvac_fan_relay = new Serial_Item( 'ACC', ON, 'weeder' );
$hvac_fan_relay->add( 'AOC', OFF,      'weeder' );
$hvac_fan_relay->add( 'ARC', 'status', 'weeder' );

$garage_door_button = new Serial_Item( 'ACD500', 'push', 'weeder' );
$garage_door_button->add( 'ARC', 'status', 'weeder' );

