# Category= Timers

# This code processes tk/web entered timer data
# It also allows for limited voice command timers

                                # Create Tk/Web widgets
$timer_time = new Generic_Item;
$timer_text = new Generic_Item;
&tk_entry('Timer amount' => $timer_time, 'Timer Text' => $timer_text);

                                # Create timers
if (state_now $timer_time or state_now $timer_text) {
    my $timer_time = state $timer_time;
    my $timer_text = state $timer_text;
    my ($time, $unit) = $timer_time =~ /([\d\.]+) *(\S*)/;

                                # Allow for unit shortcuts
    $unit = 'minute' unless $unit;
    $unit = 'second' if $unit =~ /^s/i;
    $unit = 'minute' if $unit =~ /^m/i;
    $unit = 'hour'   if $unit =~ /^h/i;

    my $seconds = $time;
    $seconds *=   60 if $unit eq 'minute';
    $seconds *= 3600 if $unit eq 'hour';

    my $timer = new Timer;
    push @{$Persistent{timers}}, $timer;
    $timer->{text} = $timer_text;
    $timer->{time} = $time;
    $timer->{unit} = $unit;
    set $timer $seconds, "&expired_timer( '$time $unit', '$timer_text')";
    speak "A $time $unit $timer_text timer has been set." ;
    print_log "$time $unit ($seconds seconds) $timer_text timer started";
}

sub expired_timer {
    my ($time, $text) = @_;
    play 'timer';               # Set in event_sounds.pl
    play 'timer';
    my $text2;
    if ($text) {
        $text2 = "Time to $text";
    }
    else {
        $text2 = 'Timer expired';
    }
    speak "rooms=all volume=100 Notice: $text2.  The $time $text timer just expired";
}    
    

                                # Allow for limited voice command timers
$v_minute_timer = new  Voice_Cmd('Set a timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,25,30,45,60,90,120] minutes');
$v_minute_timer-> set_info('Set a minute timer.  Time remaining will be periodically announced');
if ($state =  said $v_minute_timer) {
    speak "A timer has been set for $state minutes";
    set $timer_time "$state minuts";
    set $timer_text 'minite';
}

                                # List all timers
$v_list_timers = new  Voice_Cmd('list all timers');
$v_list_timers-> set_info('Summarize all timers');
if ($state = said $v_list_timers) {
    if (@{$Persistent{timers}}) {
        for my $timer (@{$Persistent{timers}}) {
            my $time_left = int seconds_remaining $timer;
            next unless $time_left;
            $time_left /=   60 if $timer->{unit} eq 'minute';
            $time_left /= 3600 if $timer->{unit} eq 'hour';
            $time_left = round $time_left, 1;
            if ($timer->{text}) {
                speak "$timer->{text} in " . &plural($time_left, $timer->{unit}) ;
            } else {
                speak &plural($time_left, $timer->{unit}) . " left on the timer" ;
            }
        }
    }
    else {
        speak 'There are no active timers';
    }
}		

                                # Speak periodic timer count-downs
                                #  - also delete expired timers
my %timer_reminder_intervals = map {$_, 1} (1,2,3,4,5,10,20,30,60);
if ($New_Second) {
    my @timers = @{$Persistent{timers}};
    my $i = 0;
    for my $timer (@timers) {
        my $time_left = seconds_remaining $timer;
                                # Delete expired timers
        unless (defined $time_left) {
            splice @{$Persistent{timers}}, $i, 1;
            next;
        }
        $i++;
        next if $time_left < 10;
        $time_left = int $time_left;
        $time_left /=   60 if $timer->{unit} eq 'minute';
        $time_left /= 3600 if $timer->{unit} eq 'hour';
        if ($timer_reminder_intervals{$time_left}) {
            if ($timer->{text}) {
                speak "$timer->{text} in " . &plural($time_left, $timer->{unit}) ;
            } else {
                speak &plural($time_left, $timer->{unit}) . " left on the timer" ;
            }
        }
    }
}

                                # Cancel timers
$v_timer_cancel = new  Voice_Cmd 'Cancel all timers';
if ($state = said $v_timer_cancel) {
    undef @{$Persistent{timers}};
 	speak "All timers have been canceled";
}
