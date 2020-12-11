
# Here is an example of setting up an X10 button to mimic a voice command.

$v_wake_up    = new Voice_Cmd 'Wake everyone up';
$v_good_night = new Voice_Cmd 'Good night';
$x_wake_sleep = new X10_Item 'A8';

$state = state_now $x_wake_sleep;
run_voice_cmd 'Wake everyone up' if $state eq ON;
run_voice_cmd 'Good night'       if $state eq OFF;

# Or you can set the wakeup/sleep objects directly like this:

set $v_wake_up 1    if $state eq ON;
set $v_good_night 1 if $state eq OFF;

