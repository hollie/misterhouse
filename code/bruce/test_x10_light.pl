# Category=Test

#@ Test x10 light commands

$v_test_light_timed =
  new Voice_Cmd("Turn the Outside lights off in [1,5,10,30,60] minutes");
$v_test_light_timed->set_info('A test of the set_with_timer X10_Item method');
set_with_timer $camera_light ON, $state * 60
  if $state = said $v_test_light_timed;

$v_test_light1 = new Voice_Cmd(
    "Set test camera light 1 to [on,brighten,dim,-50,+20,+50,+70,50,10%,12%,30%,50%,60%,70%,&P1,&P2,&P3,&P13,&P10,&P30,&P40,&P50,&P60,&P80,fred]"
);
$v_test_light2 = new Voice_Cmd(
    "Set test camera light 2 to [on,brighten,dim,-50,+20,+50,+70,50,10%,12%,30%,50%,60%,70%,&P1,&P2,&P3,&P13,&P10,&P30,&P40,&P50,&P60,&P80,fred]"
);

#v_test_light2 = new Voice_Cmd("Set bathroom light to [on,off,brighten,dim,-50,+20,+50,+70,50,10%,12%,30%,60%,70%,&P1,&P2,&P3,&P13,&P10,&P30,&P40,&P50,&P60,&P80,fred]");
$v_test_light1->set_info(
    'Test sending some extended X10 states to a fancy LM14 X10 module');

if ( $state = said $v_test_light1) {
    print_log "Camera light set to $state";

    #   set_with_timer $camera_light $state, 2;
    set $camera_light $state;
}

if ( $state = said $v_test_light2) {
    print_log "Bathroom light set to $state";

    #   set_with_timer $camera_light $state, 2;
    set $bathroom_light $state;
}

$v_test_lights = new Voice_Cmd(
    "{please, } {turn the, } test lights [on,off,&P13,&P10,&P15,&P20,10%,20%,70%,&P60]"
);

#$v_test_lights-> set_info('Test sending some extended X10 states to a fancy LM14 X10 module');
#$test_lights   = new X10_Item('C9');

#set $test_lights $state if $state = said $v_test_lights;
#set $camera_light $state if $state = said $v_test_lights;
#speak "Test light set to $state" if $state = state_now $camera_light;

$v_xmas_clue1 = new Voice_Cmd("Where is Nicks christmas present");
$v_xmas_clue2 = new Voice_Cmd("Where is Zacks christmas present");
$v_xmas_clue3 = new Voice_Cmd("Where are the christmas presents");
$v_xmas_clue1->set_info('For use in a holiday treasure hunt');
$v_xmas_clue2->set_info('For use in a holiday treasure hunt');
$v_xmas_clue3->set_info('For use in a holiday treasure hunt');

speak "Nicks present is in a very, very clean place"
  if said $v_xmas_clue1 or said $v_xmas_clue3;
speak "Zacks present is in a very, very dirty place"
  if said $v_xmas_clue2 or said $v_xmas_clue3;

$button1 = new Serial_Item( 'XI8IJ', ON );
$button1->add( 'XI8IK', OFF );
$button1->tie_items($garage_lights);

$test_house_o = new X10_Item 'O';
$test_house   = new Voice_Cmd 'Test house code o [on,off]';

set $test_house_o $state if $state = state_now $test_house;

#$test_house_o1 = new X10_Item 'O1';
print_log "X10 code O  set to $state by $test_house_o->{set_by} "
  if $state = state_now $test_house_o;

#print_log "X10 code O1 set to $state by $test_house_o1->{set_by}" if $state = state_now $test_house_o1;
