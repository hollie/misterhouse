
use strict;
package Timer;

my ($class, $self, $id, $state, $action, $repeat, @timers_with_actions, $resort_timers_with_actions, $timer_loop_count);

sub expired_timers_with_actions {
    my @expired_timers = ();
                                # Keep the timers in order for effecient checking
    if ($resort_timers_with_actions) {
        @timers_with_actions = sort { $a->{expire_time} <=> $b->{expire_time} } @timers_with_actions;
        $resort_timers_with_actions = 0;
    }

#   print "db twa=@timers_with_actions\n";
    while (@timers_with_actions) {
        $self = $timers_with_actions[0];
#       print "db3 s=$self ex=$self->{expire_time}\n";
        if (!$self->{expire_time}) {
            shift @timers_with_actions; # These timers were 'unset' ... delete them
        }       
                                # Use this method avoids problems with Timer is called from X10_Items
#       elsif (expired $self) {
        elsif (&Timer::expired($self)) {
#       print "db4 s=$self\n";
            push(@expired_timers, $self);
            shift @timers_with_actions;
            if (--$self->{repeat} > 0) {
                set $self $self->{period}, $self->{action}, $self->{repeat};
            }
        }
        else {
            last;               # The first timer has not expired yet, so don't check the others
        }
    }
    return @expired_timers;
}

sub delete_timer_with_action {
    my ($timer) = @_;
    my $i = 0;
    while ($i <= $#timers_with_actions) {
        print "testing i=$i timer=$timer\n" if $main::config_parms{debug} eq 'misc';
        if ($timers_with_actions[$i] eq $timer) {
#           print "db deleting timer $timer\n";
            splice(@timers_with_actions, $i, 1);
            last;
        }
        $i++;
    }
}


sub new {
    my ($class, $id, $state) = @_;
    my $self = {};
                                # Not sure why this gives an error without || Timer
    bless $self, $class || 'Timer';
    return $self;
}

sub restore_string {
    my ($self) = @_;

    my $expire_time = $self->{expire_time};
    return if !$expire_time or $expire_time < &main::get_tickcount;

    my $restore_string  = "set $self->{object_name} $self->{period} " if $self->{period};
    $restore_string .= ", q|$self->{action}|" if $self->{action};
    $restore_string .= ", $self->{repeat}"     if $self->{repeat};
    $restore_string .= ";  ";
    $restore_string .= $self->{object_name} . "->{expire_time} = $expire_time;" if $expire_time;

    return $restore_string;
}

                                # Use this to re-start dynamic timers after reload
sub restore_self_set {
    my ($self) = @_;
    my $expire_time = $self->{expire_time};
    return if !$expire_time or $expire_time < &main::get_tickcount;
    set $self $self->{period}, $self->{action}, $self->{repeat};
    $self->{expire_time} = $expire_time;
}

sub state {
    ($self) = @_;
    return $self->{state};
}

sub state_log {
    my ($self) = @_;
    return @{$$self{state_log}} if $$self{state_log};
}

sub set {
    ($self, $state, $action, $repeat) = @_;

                                # Turn a timer off
    if ($state == 0) {
        $self->{expire_time} = undef;
        &delete_timer_with_action($self);
        $resort_timers_with_actions = 1;
    }
                                # Turn a timer on
    else {
        $self->{expire_time} = ($state * 1000) + main::get_tickcount;
        $self->{period}      = $state; 
        $self->{repeat}      = $repeat;
        if ($action) {
            $self->{action} = $action;
            print "action timer s=$self a=$action s=$state\n" if $main::config_parms{debug} eq 'misc';
            &delete_timer_with_action($self); # delete possible previous 
            push(@timers_with_actions, $self);
            $resort_timers_with_actions = 1;
        }
    }
    $self->{pass_triggered} = 0;

    unshift(@{$$self{state_log}}, "$main::Time_Date $state");
    pop @{$$self{state_log}} if @{$$self{state_log}} > $main::config_parms{max_state_log_entries};

}    

sub resort_timers_with_actions {
    $resort_timers_with_actions = 1;
}

sub unset {
    ($self) = @_;
    undef $self->{expire_time};
    undef $self->{action};
    &delete_timer_with_action($self);
}    

sub delete_old_timers {
    undef @timers_with_actions;
}


sub run_action {
    ($self) = @_;
    if (my $action = $self->{action}) {
        # Passing a subroutine ref to a timer is not tested ... probably not useful
        my $action_type = ref $action;
        print "Executing timer subroutine ref=$action_type   action=$action\n"  if $main::config_parms{debug} eq 'misc';
        if ($action_type eq 'REF') {
            &{$action};
        }
        else {
            package main;   # Had to do this to get the 'speak' function recognized without having to &main::speak() it
            eval $action;
            package Timer;
            print "\nError in running timer action: action=$action\n error: $@\n" if $@;
        }
    }
}

sub increment_timer_loop {
    # Hmmm, might be safer / more efficient to set an expired flag here
    $timer_loop_count++;
}

sub expired {
    ($self) = @_;
#   print "db $self-{expire_time} $self{pass_triggered} $loop_count\n";
    if ($self->{expire_time} and
        $self->{expire_time} < main::get_tickcount) {
        # Reset if we finished the trigger pass
        # Note: $timer_loop_count must be set by calling loop.
        if ($self->{pass_triggered} and 
            $self->{pass_triggered} < $timer_loop_count) {
#       print "db expired loop=$self->{pass_triggered}\n";
            $self->{expire_time} = 0;
            $self->{pass_triggered} = 0;
            return 0;
        }
        else {
            $self->{pass_triggered} = $timer_loop_count;
            return 1;
        }
    }
    else {
        return 0;
    }
}    

sub hours_remaining {
    ($self) = @_;
    return if inactive $self;
    my $diff = $self->{expire_time} - main::get_tickcount;
#   print "d=$diff s=$self st=", $self->{expire_time}, "\n";
    return sprintf("%3.1f", $diff/(60*60000));
}
sub hours_remaining_now {
    ($self) = @_;
    return if inactive $self;
    my $hours_left = int(.5 + ($self->{expire_time} - main::get_tickcount) / (60*60000));
    if ($hours_left and
        $self->{hours_remaining} != $hours_left) {
        $self->{hours_remaining}  = $hours_left;
        return $hours_left;
    }
    else {
        return undef;
    }
}

sub minutes_remaining {
    ($self) = @_;
    return if inactive $self;
    my $diff = $self->{expire_time} - main::get_tickcount;
#   print "d=$diff s=$self st=", $self->{expire_time}, "\n";
    return sprintf("%3.1f", $diff/60000);
}
sub minutes_remaining_now {
    ($self) = @_;
    return if inactive $self;
    my $minutes_left = int(.5 + ($self->{expire_time} - main::get_tickcount) / 60000);
    if ($minutes_left and
        $self->{minutes_remaining} != $minutes_left) {
        $self->{minutes_remaining}  = $minutes_left;
        return $minutes_left;
    }
    else {
        return undef;
    }
}

sub seconds_remaining {
    ($self) = @_;
    return if inactive $self;
    my $diff = $self->{expire_time} - main::get_tickcount;
    return sprintf("%3.1f", $diff/1000);
}
sub seconds_remaining_now {
    ($self) = @_;
    return if inactive $self;
    my $seconds_left = int(.5 + ($self->{expire_time} - main::get_tickcount) / 1000);
    if ($seconds_left and
        $self->{seconds_remaining} != $seconds_left) {
        $self->{seconds_remaining}  = $seconds_left;
        return $seconds_left;
    }
    else {
        return undef;
    }
}


sub active {
    ($self) = @_;
    if ($self->{expire_time} and
        $self->{expire_time} >= main::get_tickcount) {
        return 1;
    }
    else {
        return 0;
    }
}
sub inactive {
    ($self) = @_;
    if ($self->{expire_time}) {
        if ($self->{expire_time} < main::get_tickcount) {
#       $self->{expire_time} = 0;   ... this could disable a expire timer test??
            return 1;
        }
        else {
            return 0;
        }
    }
    else {
        return 1;
    }
}   

1;

#
# $Log$
# Revision 1.19  2000/12/21 18:54:15  winter
# - 2.38 release
#
# Revision 1.18  2000/11/12 21:02:38  winter
# - 2.34 release
#
# Revision 1.17  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.16  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.15  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.14  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.13  2000/01/27 13:43:19  winter
# - update version number
#
# Revision 1.12  1999/12/12 23:59:55  winter
# - change elseif (expired) check
#
# Revision 1.11  1999/11/08 02:20:41  winter
# - fix xxx_left roundoff bug.
#
# Revision 1.10  1999/09/27 03:17:41  winter
# - make debug conditional on debug parm
#
# Revision 1.9  1999/07/05 22:34:36  winter
# *** empty log message ***
#
# Revision 1.8  1999/06/27 20:12:36  winter
# - add delete_timer_with_action
#
# Revision 1.7  1999/02/16 02:05:59  winter
# - print 'timer eval' errata only if debug is on
#
# Revision 1.6  1999/02/08 00:31:36  winter
# - add delete_old_timers
#
# Revision 1.5  1999/01/23 16:31:47  winter
# *** empty log message ***
#
# Revision 1.4  1999/01/23 16:25:30  winter
# - Call get_tickcount, so we are platform independent
#
# Revision 1.3  1998/12/08 02:26:48  winter
# - add log
#
#
