# Category= Time

# $Date$
# $Revision$

#@ This modules provides basic timer functionality. After
#@ activation, you can set various timers.

# This code processes tk/web entered timer data
# It also allows for limited voice command timers

# Create Tk/Web widgets
$timer_time = new Generic_Item;
$timer_text = new Generic_Item;
&tk_entry( 'Timer Amount' => $timer_time );
&tk_entry( 'Timer Text'   => $timer_text );

# Create timers
#  - only set timer when time changes ... the web interface
#    will only set one field at a time :(
#f (state_now $timer_time or state_now $timer_text) {
if ( state_now $timer_time) {
    my $timer_time = state $timer_time;
    my $timer_text = state $timer_text;
    my ( $time, $unit ) = $timer_time =~ /([\d\.]+) *(\S*)/;

    # Allow for unit shortcuts
    $unit = 'minute' unless $unit;
    $unit = 'second' if $unit =~ /^s/i;
    $unit = 'minute' if $unit =~ /^m/i;
    $unit = 'hour'   if $unit =~ /^h/i;

    my $seconds = $time;
    $seconds *= 60   if $unit eq 'minute';
    $seconds *= 3600 if $unit eq 'hour';

    my $timer = new Timer;
    push @{ $Persistent{timers} }, $timer;
    $timer->{text} = $timer_text;
    $timer->{time} = $time;
    $timer->{unit} = $unit;
    set $timer $seconds, "&expired_timer( '$time $unit', qq|$timer_text|)";
    speak "app=timer A $time $unit $timer_text timer has been set.";
    print_log "$time $unit ($seconds seconds) $timer_text timer started";
}

sub expired_timer {
    my ( $time, $text ) = @_;
    play app => 'timer', file => 'timer';    # Set in event_sounds.pl
    my $text2;
    if ($text) {
        $text2 = "Time to $text";
    }
    else {
        $text2 = 'Timer expired';
    }
    speak "app=timer Notice: $text2. The $time $text timer just expired";
    play app => 'timer', file => 'timer';    # Set in event_sounds.pl
}

# Allow for limited voice command timers
$v_minute_timer = new Voice_Cmd(
    'Set a timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,25,30,45,60,90,120] minutes'
);
$v_minute_timer->set_info(
    'Set a minute timer.  Time remaining will be periodically announced');
if ( said $v_minute_timer) {
    my $state = $v_minute_timer->{state};
    $v_minute_timer->respond(
        "app=timer A timer has been set for $state minutes.");
    set $timer_time "$state minutes";

    #   set $timer_text 'minite';
}

# List all timers
$v_list_timers = new Voice_Cmd('list all timers');
$v_list_timers->set_info('Summarize all timers');
if ( $state = said $v_list_timers) {
    my @x10_timers = ();
    foreach my $object ( list_objects_by_type('X10_Appliance') ) {
        if ( get_object_by_name($object)->{timer} ) {
            push( @x10_timers, get_object_by_name($object)->{timer} );
        }
    }
    if ( @{ $Persistent{timers} } or @x10_timers ) {
        for my $timer ( @{ $Persistent{timers} }, @x10_timers ) {
            my $time_left = seconds_remaining $timer;
            next unless $time_left;
            $time_left /= 60   if $timer->{unit} eq 'minute';
            $time_left /= 3600 if $timer->{unit} eq 'hour';
            $time_left = round $time_left, 1;
            if ( $timer->{text} ) {
                speak "app=timer $timer->{text} in "
                  . &plural( $time_left, $timer->{unit} );
            }
            else {
                speak "app=timer "
                  . &plural( $time_left, $timer->{unit} )
                  . " left on the timer.";
            }
        }
    }
    else {
        speak 'app=timer There are no active timers.';
    }
}

# Speak periodic timer count-downs
#  - also delete expired timers
my %timer_reminder_intervals = map { $_, 1 } ( 1, 2, 3, 4, 5, 10, 20, 30, 60 );
if ($New_Second) {
    my $i = 0;
    for my $timer ( @{ $Persistent{timers} } ) {
        my $time_left = seconds_remaining $timer;

        # Delete expired timers
        unless ( defined $time_left ) {
            splice @{ $Persistent{timers} }, $i, 1;
            next;
        }
        $i++;
        $time_left = int $time_left;
        next if $time_left < 10;

        #       print "db1 u=$timer->{unit} tl=$time_left\n";
        $time_left /= 60   if $timer->{unit} eq 'minute';
        $time_left /= 3600 if $timer->{unit} eq 'hour';
        my $pitch = int 10 * ( 1 - $time_left / 5 );

        #       $time_left = int $time_left;
        if ( $timer_reminder_intervals{$time_left} ) {
            if ( $timer->{text} ) {
                speak "app=timer pitch=$pitch $timer->{text} in "
                  . &plural( $time_left, $timer->{unit} );
            }
            else {
                speak "app=timer pitch=$pitch "
                  . &plural( $time_left, $timer->{unit} )
                  . " left on the timer.";
            }
        }
    }
}

# Cancel timers
$v_timer_cancel = new Voice_Cmd 'Cancel all timers';
if ( $state = said $v_timer_cancel) {
    for my $timer ( @{ $Persistent{timers} } ) {
        unset $timer;
    }
    undef @{ $Persistent{timers} };
    $v_timer_cancel->respond("app=timer All timers have been canceled.");
}
