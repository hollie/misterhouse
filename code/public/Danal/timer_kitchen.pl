# Category=Timers

# Define Them

$timer_UpOven = new Timer;
$timer_LwOven = new Timer;
$timer_RFBurn = new Timer;
$timer_LFBurn = new Timer;
$timer_RRBurn = new Timer;
$timer_LRBurn = new Timer;
$timer_EXTim1 = new Timer;
$timer_EXTim2 = new Timer;

# list all timers
$v_list_timer = new Voice_Cmd('List all timers');
set_order $v_list_timer '01';

if ( $state = said $v_list_timer) {
    my $result;
    $temp = minutes_remaining $timer_UpOven;
    $result .= &plural( $temp, "minute" ) . " left on Upper Oven timer\n"
      if ( $temp != 0 );
    $temp = minutes_remaining $timer_LwOven;
    $result .= &plural( $temp, "minute" ) . " left on Lower Oven timer\n"
      if ( $temp != 0 );
    $temp = minutes_remaining $timer_RFBurn;
    $result .=
      &plural( $temp, "minute" ) . " left on Right Front Burner timer\n"
      if ( $temp != 0 );
    $temp = minutes_remaining $timer_LFBurn;
    $result .= &plural( $temp, "minute" ) . " left on Left Front Burner timer\n"
      if ( $temp != 0 );
    $temp = minutes_remaining $timer_RRBurn;
    $result .= &plural( $temp, "minute" ) . " left on Right Rear Burner timer\n"
      if ( $temp != 0 );
    $temp = minutes_remaining $timer_LRBurn;
    $result .= &plural( $temp, "minute" ) . " left on Left Rear Burner timer\n"
      if ( $temp != 0 );
    $temp = minutes_remaining $timer_EXTim1;
    $result .= &plural( $temp, "minute" ) . " left on Extra timer number 1\n"
      if ( $temp != 0 );
    $temp = minutes_remaining $timer_EXTim2;
    $result .= &plural( $temp, "minute" ) . " left on Extra timer number 2\n"
      if ( $temp != 0 );
    display $result, 20, 'Kitchen Timer Status', 'fixed';

}

# Cancel all timers
$v_can_timer = new Voice_Cmd('Cancel all timers');
set_order $v_can_timer '02';
$v_can_timer->set_info('All timers will be unset');
if ( $state = said $v_can_timer) {
    unset $timer_UpOven;
    unset $timer_LwOven;
    unset $timer_RFBurn;
    unset $timer_LFBurn;
    unset $timer_RRBurn;
    unset $timer_LRBurn;
    unset $timer_EXTim1;
    unset $timer_EXTim2;
    speak "ALL timers have been canceled";
}

# Commands to set timers

my %timer_reminder_intervals = map { $_, 1 } ( 1, 5, 10, 20, 30, 60 );

$v_UpOven_timer = new Voice_Cmd(
    'Set Upper Oven Timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,45,60,90,120] minutes'
);
$v_LwOven_timer = new Voice_Cmd(
    'Set Lower Oven Timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,45,60,90,120] minutes'
);
$v_RFBurn_timer = new Voice_Cmd(
    'Set Right Front Burner Timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,45,60,90,120] minutes'
);
$v_LFBurn_timer = new Voice_Cmd(
    'Set Left Front Burner Timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,45,60,90,120] minutes'
);
$v_RRBurn_timer = new Voice_Cmd(
    'Set Right Rear Burner Timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,45,60,90,120] minutes'
);
$v_LRBurn_timer = new Voice_Cmd(
    'Set Left Rear Burner Timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,45,60,90,120] minutes'
);
$v_EXTim1_timer = new Voice_Cmd(
    'Set Extra Timer 1 for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,45,60,90,120] minutes'
);
$v_EXTim2_timer = new Voice_Cmd(
    'Set Extra Timer 2 for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,45,60,90,120] minutes'
);

set_order $v_UpOven_timer '03';
set_order $v_LwOven_timer '04';
set_order $v_RFBurn_timer '08';
set_order $v_LFBurn_timer '07';
set_order $v_RRBurn_timer '06';
set_order $v_LRBurn_timer '05';
set_order $v_EXTim1_timer '09';
set_order $v_EXTim2_timer '10';

if ( $state = said $v_UpOven_timer) {
    speak "The Upper Oven has a timer set for $state minutes";
    set $timer_UpOven $state * 60,
      "speak 'rooms=all Notice, the Upper Oven timer just expired after $state minutes. Repeat <emph>Upper Oven</emph>'";
}
speak &plural( $temp, "minute" ) . " left on the Upper Oven timer"
  if ( $temp = minutes_remaining_now $timer_UpOven)
  and $timer_reminder_intervals{$temp};

if ( $state = said $v_LwOven_timer) {
    speak "The Lower Oven has a timer set for $state minutes";
    set $timer_LwOven $state * 60,
      "speak 'rooms=all Notice, the Lower Oven timer just expired after $state minutes. Repeat <emph>Lower Oven</emph>'";
}
speak &plural( $temp, "minute" ) . " left on the Lower Oven timer"
  if ( $temp = minutes_remaining_now $timer_LwOven)
  and $timer_reminder_intervals{$temp};

if ( $state = said $v_RFBurn_timer) {
    speak "The Right Front Burner has a timer set for $state minutes";
    set $timer_RFBurn $state * 60,
      "speak 'rooms=all Notice, the Right Front Burner timer just expired after $state minutes. Repeat <emph>Right Front burner</emph>'";
}
speak &plural( $temp, "minute" ) . " left on the Right Front burner timer"
  if ( $temp = minutes_remaining_now $timer_RFBurn)
  and $timer_reminder_intervals{$temp};

if ( $state = said $v_LFBurn_timer) {
    speak "The Left Front Burner has a timer set for $state minutes";
    set $timer_LFBurn $state * 60,
      "speak 'rooms=all Notice, the Left Front Burner timer just expired after $state minutes. Repeat <emph>Left Front burner</emph>'";
}
speak &plural( $temp, "minute" ) . " left on the Left Front burner timer"
  if ( $temp = minutes_remaining_now $timer_LFBurn)
  and $timer_reminder_intervals{$temp};

if ( $state = said $v_RRBurn_timer) {
    speak "The Right Rear Burner has a timer set for $state minutes";
    set $timer_RRBurn $state * 60,
      "speak 'rooms=all Notice, the Right Rear Burner timer just expired after $state minutes. Repeat <emph>Right Rear burner</emph>'";
}
speak &plural( $temp, "minute" ) . " left on the Right Rear burner timer"
  if ( $temp = minutes_remaining_now $timer_RRBurn)
  and $timer_reminder_intervals{$temp};

if ( $state = said $v_LRBurn_timer) {
    speak "The Left Rear Burner has a timer set for $state minutes";
    set $timer_LRBurn $state * 60,
      "speak 'rooms=all Notice, the Left Rear Burner timer just expired after $state minutes. Repeat <emph>Left Rear burner</emph>'";
}
speak &plural( $temp, "minute" ) . " left on the Left Rear burner timer"
  if ( $temp = minutes_remaining_now $timer_LRBurn)
  and $timer_reminder_intervals{$temp};

if ( $state = said $v_EXTim1_timer) {
    speak "The Extra timer 1 is set for $state minutes";
    set $timer_EXTim1 $state * 60,
      "speak 'rooms=all Notice, the Extra timer 1 just expired after $state minutes. Repeat <emph>Extra 1</emph>'";
}
speak &plural( $temp, "minute" ) . " left on the Extra 1 timer"
  if ( $temp = minutes_remaining_now $timer_EXTim1)
  and $timer_reminder_intervals{$temp};

if ( $state = said $v_EXTim2_timer) {
    speak "The Extra timer 2 is set for $state minutes";
    set $timer_EXTim2 $state * 60,
      "speak 'rooms=all Notice, the Extra timer 2 just expired after $state minutes. Repeat <emph>Extra 2</emph>'";
}
speak &plural( $temp, "minute" ) . " left on the Extra 2 timer"
  if ( $temp = minutes_remaining_now $timer_EXTim2)
  and $timer_reminder_intervals{$temp};

