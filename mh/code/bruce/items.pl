# Category=Other

my ($temp, $state, $ref);
   
# Various X10 items

$all_lights_on_shop  = new Serial_Item('XHI');
$all_lights_on_zack  = new Serial_Item('XJI');
$all_lights_on_study = new Serial_Item('XKI');
$all_lights_on_family= new Serial_Item('XMI');
$all_lights_on_nick  = new Serial_Item('XNI');
$all_lights_on_living= new Serial_Item('XOI');
$all_lights_on_bed   = new Serial_Item('XPI');
      
$garage_movement_light= new Serial_Item('XI1'); 
$garage_movement      = new Serial_Item('XI2');   # Do not responde to XIJ (on), so do not use X10_Item
set_icon $garage_movement 'motion';

   
$movement_sensor      = new  Serial_Item('XAJ', ON);
$movement_sensor ->     add             ('XAK', OFF);
set_icon $movement_sensor 'motion';

#movement_sensor_unit = new  Serial_Item('XA1', 'stair');
$movement_sensor_unit = new  Serial_Item('XA2', 'hall');
$movement_sensor_unit-> add             ('XA3', 'stair');
$movement_sensor_unit-> add             ('XA4', 'bathroom');
#$movement_sensor_unit-> add             ('XA5', 'bathroom2');

# Living room x10 items
$toggle_attic_fan    = new Serial_Item('XOA', 'toggle');
$toggle_attic_fan->    add            ('XPA', 'toggle');
$display_calls       = new Serial_Item('XOF');


# Bedroom x10 items
$bedroom_curtain     = new  Serial_Item('XP8', OPEN);
$bedroom_curtain    -> add             ('XPC', CLOSE);
$bedroom_curtain    -> add             ('XP8PJ', OPEN);
$bedroom_curtain    -> add             ('XP8PK', CLOSE);

# Family room x10 items
$family_curtain      = new  Serial_Item('XM8', OPEN);
$family_curtain     -> add             ('XMC', CLOSE);
$family_curtain     -> add             ('XAFAJ', OPEN);
$family_curtain     -> add             ('XAFAK', CLOSE);

$basement_curtain      = new  Serial_Item('XM6', OPEN);
$basement_curtain     -> add             ('XMA', CLOSE);

#$tramp_timer         = new  Serial_Item('XM6', ON);
#$tramp_timer        -> add             ('XMA', OFF);

$toggle_backyard_light= new Serial_Item('XM5');
$toggle_fountain     = new Serial_Item('XM9'); # Family room
#toggle_fountain    -> add            ('XO9'); # Living room

# Nick's room 
$nick_curtain        = new  Serial_Item('XNCNK', OPEN);
$nick_curtain       -> add             ('XNCNJ', CLOSE);
$nick_curtain       -> add             ('XAGAJ', OPEN);
$nick_curtain       -> add             ('XAGAK', CLOSE);

# Zack's room 
#zack_curtain        = new  Serial_Item('XJ8', OPEN);
#zack_curtain       -> add             ('XJC', CLOSE);
$zack_curtain        = new  Serial_Item('XM7', OPEN);
$zack_curtain       -> add             ('XMB', CLOSE);
#$zack_curtain       -> add             ('XAEAJ', OPEN);
#$zack_curtain       -> add             ('XAEAK', CLOSE);

$laundry_timer       = new  Serial_Item('XH2', ON);
$laundry_timer      -> add             ('XH3', OFF);

# Comment x10 buttons

$request_temp        = new  Serial_Item('XH1');
$request_temp       -> add             ('XJ1');
$request_temp       -> add             ('XK1');
$request_temp       -> add             ('XM1');
$request_temp       -> add             ('XN1');
$request_temp       -> add             ('XO1');
$request_temp       -> add             ('XP1');

$test_3              = new  Serial_Item('XO3');
$test_16             = new  Serial_Item('XOG');
  
# Analog items
#$analog_request_a    = new  Serial_Item('AES', 'reset');
$analog_request_a    = new  Serial_Item('AES');
$analog_results      = new  Serial_Item('A');
$temp_zack           = new  Serial_Item('AE1');
$temp_living         = new  Serial_Item('AE2');
$temp_outside        = new  Serial_Item('AE3');
$temp_nick           = new  Serial_Item('AE4');
$humidity_inside     = new  Serial_Item('AE5');
$humidity_outside    = new  Serial_Item('AE6');
$sun_sensor          = new  Serial_Item('AE7');
$light_sensor        = new  Serial_Item('AE8');

# Digital ports
$digital_read_port_a = new  Serial_Item('DARP');
$digital_read_port_b = new  Serial_Item('DBRP');
$digital_read_port_c = new  Serial_Item('DCRP');
$digital_read_results= new  Serial_Item('D');

$digital_write_port_a = new  Serial_Item('DAW');
$digital_write_port_b = new  Serial_Item('DBWh00');
$digital_write_port_c = new  Serial_Item('DCW');


# Door sensor items
$wireless1           = new  Serial_Item('DCAH', OPENED);
$wireless1          -> add             ('DCAL', CLOSED);
$wireless1          -> add             ('DCSA', 'init');
$wireless1          -> add             ('DCRA', 'read');
$mailbox             = new  Serial_Item('DCBH', OPENED);
$mailbox            -> add             ('DCBL', CLOSED);
$mailbox            -> add             ('DCSB', 'init');
$mailbox            -> add             ('DCRB', 'read');
$garage_door         = new  Serial_Item('DCCH', OPENED);
$garage_door        -> add             ('DCCL', CLOSED);
$garage_door        -> add             ('DCSC', 'init');
$garage_door        -> add             ('DCRC', 'read');
$input_does_not_work = new  Serial_Item('DCEH', OPENED);
$garage_entry_door   = new  Serial_Item('DCDH', OPENED);
$garage_entry_door  -> add             ('DCDL', CLOSED);
$garage_entry_door  -> add             ('DCSD', 'init');
$garage_entry_door  -> add             ('DCRD', 'read');
$front_door          = new  Serial_Item('DCFH', OPENED);
$front_door         -> add             ('DCFL', CLOSED);
$front_door         -> add             ('DCSF', 'init');
$front_door         -> add             ('DCRF', 'read');
$entry_door          = new  Serial_Item('DCGH', OPENED);
$entry_door         -> add             ('DCGL', CLOSED);
$entry_door         -> add             ('DCSG', 'init');
$entry_door         -> add             ('DCRG', 'read');
$back_door           = new  Serial_Item('DCHH', OPENED);
$back_door          -> add             ('DCHL', CLOSED);
$back_door          -> add             ('DCSH', 'init');
$back_door          -> add             ('DCRH', 'read');

# PA curtain items
$curtain_updown      = new  Serial_Item('DAHA', 'down');
$curtain_updown     -> add             ('DAHA', CLOSE);
$curtain_updown     -> add             ('DALA', OPEN);
$curtain_updown     -> add             ('DALA', 'up');
$curtain_updown     -> add             ('DALA', OFF);
$curtain_bedroom     = new  Serial_Item('DAHB', ON);
$curtain_bedroom    -> add             ('DALB', OFF);
$curtain_nick        = new  Serial_Item('DAHC', ON);
$curtain_nick       -> add             ('DALC', OFF);
$curtain_family      = new  Serial_Item('DAHD', ON);
$curtain_family     -> add             ('DALD', OFF);
$curtain_zack        = new  Serial_Item('DAHG', ON);
$curtain_zack       -> add             ('DALG', OFF);

# Other relay items
$furnace_heat        = new  Serial_Item('DAHE', ON);
$furnace_heat       -> add             ('DALE', OFF);
$furnace_fan         = new  Serial_Item('DAHF', ON);
$furnace_fan        -> add             ('DALF', OFF);
$garage_door_button  = new  Serial_Item('DAHH', ON);
$garage_door_button -> add             ('DALH', OFF);

# PA relay items
$pa_study            = new  Serial_Item('DBHA', ON);
$pa_study           -> add             ('DBLA', OFF);
$pa_family           = new  Serial_Item('DBHB', ON);
$pa_family          -> add             ('DBLB', OFF);
$pa_shop             = new  Serial_Item('DBHC', ON); 
$pa_shop            -> add             ('DBLC', OFF);
$pa_radio            = new  Serial_Item('DBHD', ON);
$pa_radio           -> add             ('DBLD', OFF);
$pa_bedroom          = new  Serial_Item('DBHE', ON);
$pa_bedroom         -> add             ('DBLE', OFF);
$pa_nick             = new  Serial_Item('DBHF', ON);
$pa_nick            -> add             ('DBLF', OFF);
$pa_zack             = new  Serial_Item('DBHG', ON);
$pa_zack            -> add             ('DBLG', OFF);
$pa_living           = new  Serial_Item('DBHH', ON);
$pa_living          -> add             ('DBLH', OFF);

$mh_toggle_mode = new  Serial_Item('XPG', 'toggle');
tie_event $mh_toggle_mode "run_voice_cmd 'Toggle the house mode'";

