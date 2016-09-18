# Category=Other

#@ Lists various items.  Standard items are listed in items.mht

# my ($temp, $state, $ref);

# Various X10 items

$all_lights_on_shop   = new Serial_Item('XHI');
$all_lights_on_zack   = new Serial_Item('XJI');
$all_lights_on_study  = new Serial_Item('XKI');
$all_lights_on_family = new Serial_Item('XMI');
$all_lights_on_nick   = new Serial_Item('XNI');
$all_lights_on_living = new Serial_Item('XOI');
$all_lights_on_bed    = new Serial_Item('XPI');

#$garage_movement_light= new Serial_Item('XI1');
#$garage_movement      = new Serial_Item('XI2');   # Do not respond to XIJ (on), so do not use X10_Item
$garage_movement_light = new Serial_Item('XJ1');
$garage_movement =
  new Serial_Item('XJ2');   # Do not respond to XIJ (on), so do not use X10_Item
$garage_movement->set_icon('motion');

# These are the dark/light signals that the motions sensors send ... ignore them
#$motion_sensor_ignore =  new Serial_Item('XA3AJ');
#$motion_sensor_ignore -> add            ('XA3AK');
#$motion_sensor_ignore -> add            ('XA5AJ');
#$motion_sensor_ignore -> add            ('XA3');
#$motion_sensor_ignore -> add            ('XA5');
#$motion_sensor_ignore -> add            ('XAJ');
#$motion_sensor_ignore -> add            ('XAK');
#$motion_sensor_ignore ->{no_log} = 1; # Avoid logging by mh/code/common/mh_control.pl

$sensor_hall->{no_log}     = 1;  # Avoid logging by mh/code/common/mh_control.pl
$sensor_bathroom->{no_log} = 1;  # Avoid logging by mh/code/common/mh_control.pl
$garage_lights->{no_speak} = 1;  # Avoid speaking by pa_control.pl

$bathroom_light->set_icon('motion');
$bathroom_light->{no_log} = 1;   # Avoid logging by mh/code/common/mh_control.pl
$toggle_bathroom_light = new Serial_Item( 'XPE', 'toggle' );
$toggle_bathroom_light->tie_items($bathroom_light);

#print_log "db bathroom sensor: $state" if $state = state_now $sensor_bathroom;
#print_log "db hall     sensor: $state" if $state = state_now $sensor_hall;

$hall_light->set_icon('motion');
$hall_light->{no_log} = 1;    # Avoid logging by mh/code/common/mh_control.pl

# Living room x10 items
$toggle_attic_fan = new Serial_Item( 'XOA', 'toggle' );
$toggle_attic_fan->add( 'XPA', 'toggle' );
$display_calls = new Serial_Item('XOF');

$test_3  = new Serial_Item('XO3');
$test_16 = new Serial_Item('XOG');

# Analog items
#$analog_request_a    = new  Serial_Item('AES', 'reset');
$analog_request_a = new Serial_Item( 'AES', 'request' );
$analog_results   = new Serial_Item('A');
$temp_zack        = new Serial_Item('AE1');
$temp_living      = new Serial_Item('AE2');
$temp_outside     = new Serial_Item('AE3');
$temp_nick        = new Serial_Item('AE4');
$humidity_inside  = new Serial_Item('AE5');
$humidity_outside = new Serial_Item('AE6');
$sun_sensor       = new Serial_Item('AE7');
$light_sensor     = new Serial_Item('AE8');

# Digital ports
$digital_read_port_a  = new Serial_Item('DARP');
$digital_read_port_b  = new Serial_Item('DBRP');
$digital_read_port_c  = new Serial_Item('DCRP');
$digital_read_results = new Serial_Item('D');

$digital_write_port_a = new Serial_Item('DAW');
$digital_write_port_b = new Serial_Item('DBWh00');
$digital_write_port_c = new Serial_Item('DCW');

# Door sensor items
$wireless1 = new Serial_Item( 'DCAH', OPENED );
$wireless1->add( 'DCAL', CLOSED );
$wireless1->add( 'DCSA', 'init' );
$wireless1->add( 'DCRA', 'read' );
$mailbox = new Serial_Item( 'DCBH', OPENED );
$mailbox->add( 'DCBL', CLOSED );
$mailbox->add( 'DCSB', 'init' );
$mailbox->add( 'DCRB', 'read' );
$garage_door = new Serial_Item( 'DCCH', OPENED );
$garage_door->add( 'DCCL', CLOSED );
$garage_door->add( 'DCSC', 'init' );
$garage_door->add( 'DCRC', 'read' );
$input_does_not_work = new Serial_Item( 'DCEH', OPENED );
$garage_entry_door   = new Serial_Item( 'DCDH', OPENED );
$garage_entry_door->add( 'DCDL', CLOSED );
$garage_entry_door->add( 'DCSD', 'init' );
$garage_entry_door->add( 'DCRD', 'read' );
$front_door = new Serial_Item( 'DCFH', OPENED );
$front_door->add( 'DCFL', CLOSED );
$front_door->add( 'DCSF', 'init' );
$front_door->add( 'DCRF', 'read' );
$entry_door = new Serial_Item( 'DCGH', OPENED );
$entry_door->add( 'DCGL', CLOSED );
$entry_door->add( 'DCSG', 'init' );
$entry_door->add( 'DCRG', 'read' );
$back_door = new Serial_Item( 'DCHH', OPENED );
$back_door->add( 'DCHL', CLOSED );
$back_door->add( 'DCSH', 'init' );
$back_door->add( 'DCRH', 'read' );

# PA curtain items
$curtain_updown = new Serial_Item( 'DAHA', 'down' );
$curtain_updown->add( 'DAHA', CLOSE );
$curtain_updown->add( 'DALA', OPEN );
$curtain_updown->add( 'DALA', 'up' );
$curtain_updown->add( 'DALA', OFF );
$curtain_bedroom = new Serial_Item( 'DAHB', ON );
$curtain_bedroom->add( 'DALB', OFF );
$curtain_nick = new Serial_Item( 'DAHC', ON );
$curtain_nick->add( 'DALC', OFF );
$curtain_family = new Serial_Item( 'DAHD', ON );
$curtain_family->add( 'DALD', OFF );
$curtain_zack = new Serial_Item( 'DAHG', ON );
$curtain_zack->add( 'DALG', OFF );

# Other relay items
$furnace_heat = new Serial_Item( 'DAHE', ON );
$furnace_heat->add( 'DALE', OFF );
$furnace_fan = new Serial_Item( 'DAHF', ON );
$furnace_fan->add( 'DALF', OFF );
$garage_door_button = new Serial_Item( 'DAHH', ON );
$garage_door_button->add( 'DALH', OFF );

# PA relay items

#$pa_study            = new  Serial_Item('DBHA', ON);
#$pa_study           -> add             ('DBLA', OFF);
#$pa_family           = new  Serial_Item('DBHB', ON);
#$pa_family          -> add             ('DBLB', OFF);
#$pa_shop             = new  Serial_Item('DBHC', ON);
#$pa_shop            -> add             ('DBLC', OFF);
#$pa_radio            = new  Serial_Item('DBHD', ON);
#$pa_radio           -> add             ('DBLD', OFF);
#$pa_bedroom          = new  Serial_Item('DBHE', ON);
#$pa_bedroom         -> add             ('DBLE', OFF);
#$pa_nick             = new  Serial_Item('DBHF', ON);
#$pa_nick            -> add             ('DBLF', OFF);
#$pa_zack             = new  Serial_Item('DBHG', ON);
#$pa_zack            -> add             ('DBLG', OFF);
#$pa_living           = new  Serial_Item('DBHH', ON);
#$pa_living          -> add             ('DBLH', OFF);

$mh_toggle_mode = new Serial_Item( 'XPG', 'toggle' );
tie_event $mh_toggle_mode "run_voice_cmd 'Toggle the house mode'";

# This is an example of how to create a Voice_Cmd
# control for all X10 items.

my $list_x10_items = join ',', &list_objects_by_type('X10_Item');
$list_x10_on  = new Voice_Cmd "X10 Turn on  [$list_x10_items]";
$list_x10_off = new Voice_Cmd "X10 Turn off [$list_x10_items]";

eval "$state->set(ON)"  if $state = state_now $list_x10_on;
eval "$state->set(OFF)" if $state = state_now $list_x10_off;
