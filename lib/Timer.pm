use strict;

package Timer;

=head1 NAME

B<Timer>

=head1 SYNOPSIS

  $timer_laundary = new  Timer;
  $v_laundary_timer = new  Voice_Cmd('Laundary timer [on,off]');
  if ($state =  said $v_laundary_timer) {
    if ($state eq ON) {
       play('rooms' => 'shop', 'file' => 'cloths_started.wav');
       set $timer_laundary 35*60, 'speak "rooms=all The laundary clothes done"', 4;
    }
    else {
      speak 'rooms=shop The laundry timer has been turned off.';
      unset $timer_laundary;
    }
  }

This example uses an anonymous subroutine

  $v_test_delay = new  Voice_Cmd 'Test timer with [1,5,10] seconds';
  if ($state = said $v_test_delay) {
    print_log "Starting $state second timer test";
    my  $timer = new Timer;
    set $timer $state, sub {
      print_log "Ending $state second timer test";
    }
    #      set $timer $state, "print_log 'Ending $state second timer test'";
  }

=head1 DESCRIPTION

The Timer object can be used to run an action one or more times, at a specified interval.

=head1 INHERITS

B<>

=head1 METHODS

=over

=cut

my ( $class, $self, $id, $state, $action, $repeat, @timers_with_actions,
    $resort_timers_with_actions, @sets_from_previous_pass );

# This is called from mh each pass
sub check_for_timer_actions {
    my $ref;
    while ( $ref = shift @sets_from_previous_pass ) {
        &set_from_last_pass($ref);
    }
    for $ref (&expired_timers_with_actions) {
        &run_action($ref);
    }
}

sub expired_timers_with_actions {
    my @expired_timers = ();

    # Keep the timers in order for effecient checking
    if ($resort_timers_with_actions) {
        @timers_with_actions =
          sort { $a->{expire_time} <=> $b->{expire_time} } @timers_with_actions;
        $resort_timers_with_actions = 0;
    }

    #   print "db twa=@timers_with_actions\n";
    while (@timers_with_actions) {
        $self = $timers_with_actions[0];

        #       print "db3 s=$self ex=$self->{expire_time}\n";
        if ( !$self->{expire_time} ) {
            shift
              @timers_with_actions;  # These timers were 'unset' ... delete them
        }

        # Use this method avoids problems with Timer is called from X10_Items
        #       elsif (expired $self) {
        elsif ( &Timer::expired($self) ) {
            push( @expired_timers, $self );
            shift @timers_with_actions;
            if ( ( $self->{repeat} == -1 ) or ( --$self->{repeat} > 0 ) ) {
                set $self $self->{period}, $self->{action}, $self->{repeat};
            }
        }
        else {
            last
              ; # The first timer has not expired yet, so don't check the others
        }
    }
    return @expired_timers;
}

sub delete_timer_with_action {
    my ($timer) = @_;
    my $i = 0;
    while ( $i <= $#timers_with_actions ) {
        print "testing i=$i timer=$timer\n" if $main::Debug{timer};
        if ( $timers_with_actions[$i] eq $timer ) {

            #           print "db deleting timer $timer\n";
            splice( @timers_with_actions, $i, 1 );
            last;
        }
        $i++;
    }
}

=item C<new>

Used to create the object.

=cut

sub new {
    my ( $class, $id, $state ) = @_;
    my $self = {};

    # Not sure why this gives an error without || Timer
    bless $self, $class || 'Timer';
    return $self;
}

sub restore_string {
    my ($self) = @_;

    my $expire_time = $self->{expire_time};
    return
      unless $self->{time}
      or ( $expire_time and $expire_time > main::get_tickcount );

    my $restore_string = "set $self->{object_name} $self->{period}"
      if $self->{period};
    $restore_string .= ", q|$self->{action}|" if $self->{action};
    $restore_string .= ", $self->{repeat}"    if $self->{repeat};
    $restore_string .= ";\n";
    $restore_string .= $self->{object_name} . "->set_from_last_pass();\n";
    $restore_string .=
      $self->{object_name} . "->{expire_time} = $expire_time;\n"
      if $expire_time;
    $restore_string .= $self->{object_name} . "->{time} = q~$self->{time}~;\n"
      if $self->{time};
    $restore_string .=
      $self->{object_name} . "->{time_pause} = q~$self->{time_pause}~;\n"
      if $self->{time_pause};
    $restore_string .=
      $self->{object_name} . "->{time_adjust} = q~$self->{time_adjust}~;\n"
      if $self->{time_adjust};

    return $restore_string;
}

# Use this to re-start dynamic timers after reload
sub restore_self_set {
    my ($self) = @_;
    my $expire_time = $self->{expire_time};

    # Announced expired timers on restart/reload
    #   return if !$expire_time or $expire_time < main::get_tickcount;
    return if !$expire_time;

    # Need to set NOW, not on next pass, so expire_time can be set
    #   set $self $self->{period}, $self->{action}, $self->{repeat};
    @{ $self->{set_next_pass} } =
      ( $self->{period}, $self->{action}, $self->{repeat} );
    &set_from_last_pass($self);
    $self->{expire_time} = $expire_time;
}

sub state {
    ($self) = @_;
    return $self->{state};
}

sub state_log {
    my ($self) = @_;
    return @{ $$self{state_log} } if $$self{state_log};
}

=item C<set($period, $action, $cycles)>

$period is the timer period in seconds
$action (optional) is the code (either a string or a code reference) to run when the timer expires
$cycles (optional) is how many times to repeat the timer.  Set to -1 to repeat forever.

=cut

sub set {
    ( $self, $state, $action, $repeat ) = @_;

    my @c = caller;
    $repeat = 0 unless defined $repeat;

    #   print "db1 $main::Time_Date running set s=$self s=$state a=$action t=$self->{text} c=@c\n";
    return if &main::check_for_tied_filters( $self, $state );

    # Set states for NEXT pass, so expired, active, etc,
    # checks are consistent for one pass.
    push @sets_from_previous_pass, $self;
    @{ $self->{set_next_pass} } = ( $state, $action, $repeat );
}

# This is called from mh
sub set_from_last_pass {
    my ($self) = @_;

    return unless $self->{set_next_pass};
    ( $state, $action, $repeat ) = @{ $self->{set_next_pass} };
    undef $self->{set_next_pass};

    # Turn a timer off
    if ( $state == 0 ) {
        $self->{expire_time} = undef;
        $self->{time}        = undef;
        &delete_timer_with_action($self);
        $resort_timers_with_actions = 1;
    }

    # Turn a timer on
    else {
        $self->{expire_time} = ( $state * 1000 ) + main::get_tickcount;
        $self->{period}      = $state;
        $self->{repeat}      = $repeat;
        if ($action) {
            $self->{action} = $action;
            print "action timer s=$self a=$action s=$state\n"
              if $main::Debug{timer};
            &delete_timer_with_action($self);    # delete possible previous
            push( @timers_with_actions, $self );
            $resort_timers_with_actions = 1;
        }
    }
    $self->{pass_triggered} = 0;

    unshift( @{ $$self{state_log} }, "$main::Time_Date $state" );
    pop @{ $$self{state_log} }
      if @{ $$self{state_log} } > $main::config_parms{max_state_log_entries};
}

sub resort_timers_with_actions {
    $resort_timers_with_actions = 1;
}

=item C<unset>

Unset the timer.  'set $my_timer 0' has the same effect.

=cut

sub unset {
    ($self) = @_;
    undef $self->{expire_time};
    undef $self->{time};
    undef $self->{action};
    &delete_timer_with_action($self);
}

sub delete_old_timers {
    undef @timers_with_actions;
}

=item C<run_action>

Runs the timers action, even if the timer has not expired.

=cut

sub run_action {
    ($self) = @_;
    if ( my $action = $self->{action} ) {
        my $action_type = ref $action;
        print "Executing timer subroutine ref=$action_type   action=$action\n"
          if $main::Debug{timer};

        # Note: passing in a sub ref will cause problems on code reloads.
        # So the 2nd of these 2 would be the better choice:
        #    set $kids_bedtime_timer 10, \&kids_bedtime2;
        #    set $kids_bedtime_timer 10, '&kids_bedtime2';

        if ( $action_type eq 'CODE' ) {
            &{$action};
        }
        elsif ( $action_type eq '' ) {

            #       &::print_log("Action");
            package main
              ; # Had to do this to get the 'speak' function recognized without having to &main::speak() it
            my $timer_name = $self->{object_name}
              ;    # So we can use this in the timer action eval
            $state = $self->{object_name}
              ;    # So we can use this in the timer action eval
            eval $action;

            package Timer;
            print
              "\nError in running timer action: action=$action\n error: $@\n"
              if $@;
        }
        else {
            $action->set( 'off', $self );
        }

    }
}

=item C<expired>

Returns true for the one pass after the timer has expired.

=cut

sub expired {
    ($self) = @_;

    #   print "db $self->{expire_time} $self->{pass_triggered}\n";
    if (    $self->{expire_time}
        and $self->{expire_time} < main::get_tickcount )
    {
        #       print "db expired1 loop=$self->{pass_triggered} lc= $main::Loop_Count\n";

        # Reset if we finished the trigger pass
        if (    $self->{pass_triggered}
            and $self->{pass_triggered} < $main::Loop_Count )
        {
            #           print "db expired2 loop=$self->{pass_triggered}\n";
            $self->{expire_time}    = 0;
            $self->{pass_triggered} = 0;
            return 0;
        }
        else {
            $self->{pass_triggered} = $main::Loop_Count;
            return 1;
        }
    }
    else {
        return 0;
    }
}

=item C<hours_remaining, hours_remaining_now, minutes_remaining, minutes_remaining_now, seconds_remaining, seconds_remaining_now>

These methods return the hours, minutes or seconds remaining on the timer.  The _now methods only return the remaining time on the hour, minute, or second boundary.

=cut

sub hours_remaining {
    ($self) = @_;
    return if inactive $self;
    my $diff = $self->{expire_time} - main::get_tickcount;

    #   print "d=$diff s=$self st=", $self->{expire_time}, "\n";
    return sprintf( "%3.1f", $diff / ( 60 * 60000 ) );
}

sub hours_remaining_now {
    ($self) = @_;
    return if inactive $self;
    my $hours_left = int(
        .5 + ( $self->{expire_time} - main::get_tickcount ) / ( 60 * 60000 ) );
    if (    $hours_left
        and $self->{hours_remaining} != $hours_left )
    {
        $self->{hours_remaining} = $hours_left;
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
    return sprintf( "%3.1f", $diff / 60000 );
}

sub minutes_remaining_now {
    ($self) = @_;
    return if inactive $self;
    my $minutes_left =
      int( .5 + ( $self->{expire_time} - main::get_tickcount ) / 60000 );
    if (    $minutes_left
        and $self->{minutes_remaining} != $minutes_left )
    {
        $self->{minutes_remaining} = $minutes_left;
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
    return sprintf( "%3.1f", $diff / 1000 );
}

sub seconds_remaining_now {
    ($self) = @_;
    return if inactive $self;
    my $seconds_left =
      int( .5 + ( $self->{expire_time} - main::get_tickcount ) / 1000 );
    if (    $seconds_left
        and $self->{seconds_remaining} != $seconds_left )
    {
        $self->{seconds_remaining} = $seconds_left;
        return $seconds_left;
    }
    else {
        return undef;
    }
}

=item C<active>

Returns true if the timer is still running.

=cut

sub active {
    ($self) = @_;
    if (
        (
                $self->{expire_time}
            and $self->{expire_time} >= main::get_tickcount
        )
        or ( $self->{set_next_pass} )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

=item C<inactive>

Returns true if the timer is has expired or has not been set.

=cut

sub inactive {
    ($self) = @_;
    return !&active($self);
}

=item C<start>

Starts the timer

=cut

# The reset of these methods apply to a countup/stopwatch type timer
sub start {
    ($self) = @_;
    if ( $self->{time} ) {
        &main::print_log("Timer is already running");
        return;
    }
    $self->{time}        = time;
    $self->{time_adjust} = 0;
}

=item C<restart>

Restarts the timer (start on an active timer does nothing)

=cut

sub restart {
    ($self) = @_;
    $self->{time}        = time;
    $self->{time_adjust} = 0;
    $self->{time_pause}  = 0;
    if ( $$self{expire_time} )
    {    # If this timer is countdown type then restart it instead

        #           $self->{expire_time} = ($$self{period} * 1000) + main::get_tickcount;
        #       push @sets_from_previous_pass, $self;
        #       @{$self->{set_next_pass}} = ($$self{period}, $$self{action}, $$self{repeat});
        $self->set( $$self{period}, $$self{action}, $$self{repeat} );
    }

}

=item C<stop>

Stops a timer.

=cut

sub stop {
    ($self) = @_;
    $self->{time}        = undef;
    $self->{expire_time} = undef;
}

=item C<pause>

Pauses

=cut

sub pause {
    ($self) = @_;
    return if $self->{time_pause};    # Already paused
    $self->{time_pause} = time;
}

=item C<resume>

Bet you can guess :)

=cut

sub resume {
    ($self) = @_;
    return unless $self->{time_pause};    # Not paused
    $self->{time_adjust} += ( time - $self->{time_pause} );
    $self->{time_pause} = 0;
}

=item C<query>

Returns the seconds on the timer.

=cut

sub query {
    ($self) = @_;
    my $time = $self->{time};
    return undef unless $time;
    my $time_ref = ( $self->{time_pause} ) ? $self->{time_pause} : time;
    $time = $time_ref - $time;
    $time -= $self->{time_adjust} if $self->{time_adjust};
    return $time;
}

=item C<get_type()>

Returns the class (or type, in Misterhouse terminology) of this item.

=cut

sub get_type {
    return ref $_[0];
}

1;

=back

=head1 INI PARAMETERS

NONE

=head1 AUTHOR

UNK

=head1 SEE ALSO

See mh/code/bruce/timers.pl for more examples

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

#
# $Log: Timer.pm,v $
# Revision 1.32  2004/11/22 22:57:26  winter
# *** empty log message ***
#
# Revision 1.31  2004/07/18 22:16:37  winter
# *** empty log message ***
#
# Revision 1.30  2004/07/05 23:36:37  winter
# *** empty log message ***
#
# Revision 1.29  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.28  2003/12/22 00:25:06  winter
#  - 2.86 release
#
# Revision 1.27  2003/11/23 20:26:01  winter
#  - 2.84 release
#
# Revision 1.26  2003/02/08 05:29:23  winter
#  - 2.78 release
#
# Revision 1.25  2002/08/22 13:45:50  winter
# - 2.70 release
#
# Revision 1.24  2002/05/28 13:07:51  winter
# - 2.68 release
#
# Revision 1.23  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.22  2001/02/24 23:26:40  winter
# - 2.45 release
#
# Revision 1.21  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.20  2001/01/20 17:47:50  winter
# - 2.41 release
#
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
