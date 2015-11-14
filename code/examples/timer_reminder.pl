
# Here are 2 ways of setting a reminder timer

$timer_school_v = new Voice_Cmd 'Set the school timer';

$timer_school1 = new Timer;
$timer_school1->set( 15 * 60,
    "speak 'Timer expired.  Go get the kids from school'" )
  if said $timer_school_v;

$timer_school2 = new Timer;
if ( $state = said $timer_school_v) {
    speak 'School timer has been set';
    set $timer_school2 15 * 60;
}
speak 'Timer expired.  Go get the kids from school' if expired $timer_school2;
