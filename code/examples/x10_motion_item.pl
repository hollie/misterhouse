
# Uses Motion_Item and Light_Item

$office_motion = new X10_Sensor('B1');
$office_light  = new X10_Item('A5');

$m_office = new Motion_Item($office_motion);
$l_office = new Light_Item( $office_light, $m_office );
$l_office->delay_off( 30 * 60 )
