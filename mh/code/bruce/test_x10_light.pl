# Category=Test


$v_test_light_timed = new Voice_Cmd("Outside lights off in [1,5,10,30,60] minutes");
$v_test_light_timed-> set_info('A test of the set_with_timer X10_Item method');
set_with_timer $camera_light ON, $state*60 if $state = said $v_test_light_timed;


$v_test_light = new Voice_Cmd("Set test camera light to [on,bright,dim,-50,+20,+50,+70,50,10%,30%,60%,&P1,&P2,&P3,&P13,&P10,&P30,&P40,&P50,&P60,fred]");
$v_test_light-> set_info('Test sending some extended X10 states to a fancy LM14 X10 module');

if ($state = said $v_test_light) {
   print_log "camera light set to $state";
   set_with_timer $camera_light $state, 2;
#  set $camera_light $state;
}

$v_test_lights = new Voice_Cmd("{please,}{turn the,} test lights [on,off,&P13,&P10,&P15,&P20,10%,20%,&P60]");
$v_test_lights-> set_info('Test sending some extended X10 states to a fancy LM14 X10 module');
#$test_lights   = new X10_Item("O7", "CM11",  'LM14');

#et $test_lights $state if $state = said $v_test_lights;
set $camera_light $state if $state = said $v_test_lights;
speak "Test light set to $state" if $state = state_now $camera_light;


$v_xmas_clue1 = new Voice_Cmd("Where is Nicks christmas present");
$v_xmas_clue2 = new Voice_Cmd("Where is Zacks christmas present");
$v_xmas_clue3 = new Voice_Cmd("Where are the christmas presents");
$v_xmas_clue1-> set_info('For use in a holiday treasure hunt');
$v_xmas_clue2-> set_info('For use in a holiday treasure hunt');
$v_xmas_clue3-> set_info('For use in a holiday treasure hunt');

speak "Nicks present is in a very, very clean place" if said $v_xmas_clue1 or said $v_xmas_clue3;
speak "Zacks present is in a very, very dirty place" if said $v_xmas_clue2 or said $v_xmas_clue3;


$button1 = new  Serial_Item('XNBNB');
print_log "Button pushed twice" if state_now $button1;
