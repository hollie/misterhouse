
# Question: Looking how to do a "triggered sequence" of X10
# commands (at specified intervals after the "trigger").

# Time offsets in a time_now argument need to be as string with the + in it,
# rather than a number that results from +.  Here is an example:

$v_evening_lights_on = new Voice_Cmd 'Evening lights on';
my $ontime;

if ( $state = said $v_evening_lights_on) {
    $ontime = $Time_Now;
    print_log 'starting lights on';
}

print_log '1nd light on' if time_now "$ontime + 0:01";
print_log '2nd light on' if time_now "$ontime + 0:02";

# Note: You can test timed events like this by putting mh into
# an accelerated test mode with the the -time_* startup options.
# For example to run from now till 11 pm, with one pass per minute:

#   mh -time_stop "11 pm"
