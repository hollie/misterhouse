
$backyard_light        = new X10_Item('C4');
$toggle_backyard_light = new Serial_Item('XM5');

if ( state_now $toggle_backyard_light) {

    #   $state = (ON eq state $backyard_light) ? OFF : ON;
    #   set $backyard_light $state;
    set $backyard_light TOGGLE;
    speak("The backyard light was toggled to $state");
}

my $light_states = 'on,brighten,dim,off,-30,-50,-80,+30,+50,+80';

$v_backyard_light = new Voice_Cmd("Backyard Light [$light_states]");
set $backyard_light $state if $state = said $v_backyard_light;
