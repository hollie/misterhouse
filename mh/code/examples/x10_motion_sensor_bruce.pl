
# Yet another way to do motion sensors

$movement_sensor      = new  Serial_Item('XAJ', ON);
$movement_sensor ->     add             ('XAK', OFF);

$movement_sensor_unit = new  Serial_Item('XA3', 'stair');
$movement_sensor_unit-> add             ('XA2', 'hall');

$timer_stair_movement = new  Timer();

if (state_now $movement_sensor eq ON and 
    inactive $timer_stair_movement and
    !$Save{sleeping_parents}) {
    set $timer_stair_movement 60;
    if ((state $movement_sensor_unit) eq 'stair') {
        play('file' => "stairs_creek*.wav");
    }
    elsif ((state $movement_sensor_unit) eq 'hall') {
        play(rooms => 'all', file => 'sound_hall*.wav');
    }
} 
