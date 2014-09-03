# Category=Lights

$reading_light   = new X10_Item('NG');
$v_reading_light = new Voice_Cmd('Turn reading light [on,off]');

set $reading_light $state if $state = said $v_reading_light;
