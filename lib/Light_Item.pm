
=head1 B<Light_Item>

=head2 SYNOPSIS

Example initialization:

These are to be placed in a *.mht file in your user code directory.

First, define your actual light object:

  X10I,      H2,     x10_hallway_lights

Then, define the Light_Item and attach the real object:

  LIGHT, x10_hallway_lights, hallway_light

Finally, in your user code, you need to add one or more objects that will determine how the light is controlled.  You can attach objects of type: Door_Item, Motion_Item, Photocell_Item, Presence_Item, and Light_Restriction_Item.  You used the add() function:

  $om_auto_hall_bath_light->add($om_motion_hall_bath,
  $om_presence_hall_bath, $only_when_home);

Input states:

      From a Light_Restriction_Item:
         light_ok: Light can be turned on (light will immediately turn on
            if room is occupied AND no other restrictions are active)
         no_light: Light can not be turned on (will not affect current state)
      From a Presence_Monitor:
         occupied: Turns on light if photocell object(s) say it is dark
            and there are no active restrictions.
         vacant: Light will turn off after the delay set by delay_off() unless
            the Presence_Monitor has a delay that was set by delay_off() in
            which case that delay is used.
         predict: If prediction is enabled (with predict(1)), then the light
            will turn on if photocell object(s) say it is dark and there are
            no active restrictions.  Light will turn off after delay set by
            predict_off_time() or the default of 60 seconds unless something
            else (presence, motion, etc) causes light to remain on.
      From a Motion_Item or a Door_Item:
         on: Turns on light if photocell object(s) say it is dark
            and there are no active restrictions.  Light will turn off after
            delay set by predict_off_time() or the default of 60 seconds
            unless something else (presence, motion, etc) causes light to
            remain on.  EXCEPTION: Light will not turn off if there is an
            attached Presence_Monitor that indicates somebody is present.
      From a Photocell_Item:
         dark: Indicates that it is dark in the room, which could allow the
            light to be turned on.  No immediate action will be taken unless
            there are no Motion_Items, Door_Items, AND Presence_Monitors
            attached to the light, in which case the light will imediately
            turn on if there are no active restrictions (Light_Restriction_Item)
      From internal timer object:
         When this internal timer object triggers, if the light is supposed to
         be off, then it will be re-set to off to make sure it really is off.

Output states:

      'off': Light is off
      'on': Light is on (note: if set_on_state() was called then this will
         instead be whatever state specified in that function call)

=head2 DESCRIPTION

An abstract object that represents a light that can be automatically controlled by Door_Items, Motion_Items, Presence_Monitors, Photocell_Items, Light_Restriction_Items, and Light_Switch_Items.

Often times, Door_Items and Motion_Items are also used by the Occupancy Monitor which in turn manages the state of the Presence_Monitor objects.

=head2 INHERITS

B<Base_Item>

=head2 METHODS

=over

=item C<delay_off()>

How long the light should remain on after the last event (i.e. door, motion, occupancy) occurs.  The light will not turn off as long as occupancy remains true.  If this is set to 0, the light will never turn off based on a timer (but could still turn off because of a Photocell_Item/Light_Restriction_Item or if door_auto_off() is enabled.

=item C<x10_sync()>

Pass in a 1 to enable x10 sync, 0 to disable.  Currently this will make sure lights that are supposed to be off really are off around once per hour.  The default is enabled.

=item C<set_on_state()>

Pass in another state besides the default of ON to use when turning "on" the light.  Set to empty ('') to prevent this light from turning on automatically (but it will still turn off automatically).

=item C<set_predict_off_time()>

You can override the default 60-second off time when a light is predictively turned on but nobody actually enters the room.

=item C<door_auto_off(X)>

Turn off this light X seconds after all attached doors are closed UNLESS an attached occupancy monitor has a state of 'occupied'.  In that case, when the room is no longer occupied and if all doors are closed the light will immediately turn off.  Set this to 0 to disable (default) or a number of seconds to wait to establish occupancy before the light is turned off.

=item C<door_always_on()>

This light should always be on whenever an attached door is open, assuming any attached photocell items say it is dark in the room and unless a light restriction item says otherwise.

=item C<delay_on()>

The room must be continuously occupied for the specified number of seconds before the light will come on.  Note that you do NOT want to attach door objects and motion objects to the object if using this feature -- just attach the presence object(s) and any light restriction objects (and possibly a Light_Switch_Object).

=item C<manual(X,time_on,time_off)>

Set X to 1 to set the light into a full manual mode where it will never be turned on or off automatically unless optional time_on or time_off are set.  Set X to the physical light to ensure that the light_item tracks the state of the physical light while in manual mode.  Assign time_on and optionally time_off to time in secs for manual mode to be set until resuming to automatic mode.  time_off is assigned to time_on if uninitialized.

=item C<always_set_state(X)>

set X to 0 to only set state when the state changes value.  The default is 1 and allows any number of sets with the same value.

=item C<retrict_off(X)>

set X to 0 to prevent any attached light restriction items from preventing off states.  The default is "0".

=item C<save_state(X)>

set X to 1 to force Light_Item states to be saved and restored across a restart.  The default is "0".

=cut

use strict;
use Base_Item;

package Light_Item;

@Light_Item::ISA = ('Base_Item');

#sub initialize
#{
#	my ($self) = @_;
#	$$self(m_write} = 1; #This object should pass its state onto added objects
#	$$self{m_x10sync_timer} = new Timer();
#	$$self{m_x10sync_timer} = set(1800 + (rand() * 1800), $self); #sync non-status reporting light status
#	$$self{m_off_delay} = new Timer();
#	$$self{m_unlock_timer} = new Timer();
#

sub initialize {
    my ($self) = @_;
    $$self{m_write}         = 1;
    $$self{m_timerSync}     = new Timer();
    $$self{m_timerSyncTime} = 1800;
    $$self{m_timerSync}
      ->set( $$self{m_timerSyncTime} + ( rand() * $$self{m_timerSyncTime} ),
        $self );    #random off command
    $$self{m_timerOff}    = new Timer();
    $$self{m_timerUnlock} = new Timer();
    $$self{m_timerOn}     = new Timer();
    $$self{m_predict_off_time} = 60;    # Default predict off time of 60 seconds
    $$self{m_on_state}         = 'on';  # Turn on to "on" by default
    $$self{m_predict}          = 0;     # Turn off prediction by default
    $$self{m_sync}             = 1;     # Turn on X10 sync
    $$self{m_door_auto_off}    = 0;
    $$self{m_door_always_on}   = 0;
    $$self{m_pending_lock}     = 0;
    $$self{m_delay_on}         = 0;
    $$self{m_manual}           = undef;
    $$self{m_manualTimer}     = new Timer();
    $$self{m_idleTimer}       = new Timer();
    $$self{m_idleAmount}      = 0;
    $$self{m_idleState}       = undef;
    $$self{m_idleActiveState} = undef;
    $$self{state}             = 'off';
    $$self{m_always_set_state} =
      1;    # the default is to set state regardless of change
    $$self{m_restrict_off} =
      0;    # disable light restrictions items from preventing off states
    $$self{m_save_state} = 0;    # allow states to be restored across restarts
    $$self{debug} = $main::Debug{light_item};

    # defined possible states
    @{ $$self{states} } = ( 'on', 'off' );
}

sub set_debug {
    my ( $self, $debug ) = @_;
    $self->{debug} = $debug;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;

############################################################################
## NEW Redesign
############################################################################
    my $l_event_state   = undef;
    my $l_handler_state = undef;
    my $l_final_state   = undef;
    my $l_temp_state    = undef;

    $p_state = lc($p_state);

    ### prevent reciprocal sets ###
    return
      if (  ref $p_setby
        and $p_setby->can('get_set_by')
        and $p_setby->{set_by} eq $self );

    ### allow "automatic resume from manual" if a timer has been set
    if ( ( ref $p_setby ) && ( $p_setby eq $$self{m_manualTimer} ) ) {

        # reset the current state to what is in $$self{_automation_state} ???
        if (   ( ( $self->state eq 'off' ) and $$self{m_manual_auto_off} )
            or ( ( $self->state ne 'off' ) and $$self{m_manual_auto_on} ) )
        {
            if ( $self->allow_set_state( $$self{_automation_state}, $p_setby ) )
            {
                &::print_log(
                    "Light_Item($$self{object_name}):: manual state reverting to tracked state: "
                      . "$$self{_automation_state}" )
                  if $self->{debug};
                $self->SUPER::set( $$self{_automation_state},
                    $p_setby, $p_respond );
            }
            else {
                &::print_log(
                    "Light_Item($$self{object_name}):: resuming from manual to automatic mode"
                ) if $self->{debug};
            }
        }
        else {
            &::print_log(
                "Light_Item($$self{object_name}):: resuming from manual to automatic mode"
            ) if $self->{debug};
        }

        $self->manual(0);
        $$self{m_manualTimer}->unset();
        return;
    }

    ### Manual shutoff (unless set by the manually controlled light) ###
    #	return if ($self->manual() && !((ref $p_setby) && (ref $self->manual) && ($self->manual eq $p_setby)));

######### EVENTS
    #Determine what type of event this is ON/OFF
    if ( $self->is_on_event( $p_state, $p_setby ) ) {
        $l_event_state = 'on';
    }
    elsif ( $self->is_off_event( $p_state, $p_setby ) ) {
        $l_event_state = 'off';
    }

    if (
        $self->manual
        && (   ( ref $p_setby )
            && ( ref $self->manual )
            && ( $self->manual eq $p_setby ) )
      )
    {
        if ( $l_event_state eq 'on' ) {
            if ( $p_state =~ /^[+-]?\d?\d\%?/ or $p_state =~ /^[+]?100\%?/ ) {

                #Someone wants a pre-set dim or dimmed state
                $l_final_state = $p_state;
            }
            else {
                $l_final_state = 'on';
            }
        }
        elsif ( $l_event_state eq 'off' ) {
            $l_final_state = 'off';
        }
    }
    else {
######### HANDLERS
        #IDLE Handler
        $l_handler_state = $l_event_state;

        #IDLE handler
        $l_temp_state = $self->do_idle( $p_state, $p_setby, $l_event_state );
        $l_handler_state =
          $self->get_handler_state( $l_temp_state, $l_event_state,
            $l_handler_state );

        #Delay ON handler
        $l_temp_state =
          $self->do_on_delay( $p_state, $p_setby, $l_event_state );
        $l_handler_state =
          $self->get_handler_state( $l_temp_state, $l_event_state,
            $l_handler_state );

        #Delay OFF handler
        $l_temp_state =
          $self->do_off_delay( $p_state, $p_setby, $l_event_state );
        $l_handler_state =
          $self->get_handler_state( $l_temp_state, $l_event_state,
            $l_handler_state );

        #X10 Sync handler
        $l_temp_state =
          $self->do_X10_sync( $p_state, $p_setby, $l_event_state );
        $l_handler_state =
          $self->get_handler_state( $l_temp_state, $l_event_state,
            $l_handler_state );

        ######### RESTRICTIONS
        # Apply restrictions
        #  ON
        if ( defined($l_handler_state) and $l_handler_state ne 'off' )
        {    #If we are on
            if ( $self->is_on_restriction( $p_state, $p_setby )
                and !( $self->manual ) )
            {    #if there is a restriction in place, dont do it
                $l_final_state = undef;
            }
            else {
                if ( $l_event_state ne $l_handler_state )
                {    #If a handler modified the state, then use it instead
                    $l_final_state = $l_handler_state;
                }
                elsif ($p_state =~ /^[+-]?\d?\d\%?/
                    or $p_state =~ /^[+]?100\%?/ )
                {
                    #Someone wants a pre-set dim or dimmed state
                    $l_final_state = $p_state;
                }
                else {
                    $l_final_state = $self->set_on_state();
                }
            }
        }

        #  OFF
        if ( defined($l_handler_state) and $l_handler_state eq 'off' )
        {    #If we are off
            if ( $self->is_off_restriction( $p_state, $p_setby ) )
            {    #if there is a restriction in place, dont do it
                $l_final_state = undef;
            }
            else {
                $l_final_state = $l_handler_state;
            }
        }

######## MAINTAIN STATE ###
        if ( defined($l_final_state) ) {
            $$self{_automation_state} = $l_final_state;
            if ( $self->manual ) {
                $l_final_state = undef;    # don't set state if manual
            }
        }
    }
    if ( defined($l_final_state) ) {
        if ( $self->allow_set_state( $l_final_state, $p_setby ) ) {
######### LOG ##############
            &::print_log(
                "Light_Item($$self{object_name}):: State->$p_state Event->$l_event_state Handler->$l_handler_state Final->$l_final_state DelayOff->"
                  . $$self{m_timerOff}->active()
                  . " Setby->$p_setby ("
                  . ( ref($p_setby) ? $$p_setby{object_name} : '' )
                  . ")" )
              if $self->{debug};

######### SET LIGHT STATE ##############
            $self->SUPER::set( $l_final_state, $p_setby, $p_respond );
        }
    }
}

## used to prevent set state if no change
sub allow_set_state {
    my ( $self, $p_final_state, $p_setby ) = @_;
    my $allow_set = 1;

    # always allow set states if setby is the timerSync
    if (   !( $self->always_set_state() )
        and ( $p_setby ne $$self{m_timerSync} ) )
    {
        if (   ( $self->state() eq $p_final_state )
            or ( $self->state() eq '100%' and $p_final_state eq 'on' )
            or ( $self->state() eq 'on'   and $p_final_state eq '100%' ) )
        {
            $allow_set = 0;
        }
    }
    return $allow_set;
}

sub always_set_state {
    my ( $self, $p_always_set_state ) = @_;
    $$self{m_always_set_state} = $p_always_set_state
      if defined($p_always_set_state);
    return $$self{m_always_set_state};
}

sub restrict_off {
    my ( $self, $p_restrict_off ) = @_;
    $$self{m_restrict_off} = $p_restrict_off if defined($p_restrict_off);
    return $$self{m_restrict_off};
}

sub save_state {
    my ( $self, $p_save_state ) = @_;
    $$self{m_save_state} = $p_save_state if defined($p_save_state);
    return $$self{m_save_state};
}

sub get_handler_state {
    my ( $self, $p_handler_state, $p_event_state, $p_origHandler_state ) = @_;

    ## All we want to do here is determine if the handler changed something
    if ( $p_event_state ne $p_handler_state ) {
        return $p_handler_state;
    }
    else {
        return $p_origHandler_state;
    }
}

sub get_off_delay_effective {
    my ( $self, $p_state, $p_setby ) = @_;

    my $l_delay = undef;

    # use the parent delay off if specified
    if (    defined($p_setby)
        and $p_setby->can('delay_off')
        and defined( $p_setby->delay_off() ) )
    {
        $l_delay = $p_setby->delay_off();
    }
    if (    !defined($l_delay)
        and $self->can('delay_off')
        and defined( $self->delay_off() ) )
    {
        $l_delay = $self->delay_off();
    }
    if ( $self->predict_off_time() != 0 and $p_state eq 'predict' )
    {    #Predict delay instead of default
        $l_delay = $self->predict_off_time();
    }
    if ( defined( $$self{m_pending_lock} )
        and ( $$self{m_pending_lock} > $l_delay ) )
    {
        $l_delay = $$self{m_pending_lock};
    }
    return $l_delay;
}

sub do_X10_sync {
    my ( $self, $p_state, $p_setby, $p_event_state ) = @_;

    if ( $self->x10_sync() and $p_event_state eq 'off' )
    {    #if we have a qualified attempt to turn off
        if ( !$$self{m_timerOff}->active() )
        {    #if the off timer isnt already running
            $$self{m_timerSync}->set(
                $$self{m_timerSyncTime} + ( rand() * $$self{m_timerSyncTime} ),
                $self
            );    #sync non-status reporting light status
            &::print_log("$$self{object_name}:X10Sync Start") if $self->{debug};
        }
        elsif ( $p_setby eq $$self{m_timerSync} )
        {         #If delay_off timer is running and this is a Sync Event
            $p_event_state = undef;
        }
    }

    return $p_event_state;
}

sub do_on_delay {
    my ( $self, $p_state, $p_setby, $p_event_state ) = @_;
    my $l_delay;

    if ( $p_event_state eq 'on' ) {   #if we have a qualified attempt to turn on
        $l_delay = $self->delay_on();
        if ( $l_delay > 0 ) {         #If a delay is set, then set timer
            if ( !$$self{m_timerOn}->active() )
            {                         #only reset if we arent previously running
                $$self{m_timerOn}->set( $l_delay, $self );
            }

            #stop ON command for now.
            if ( $p_setby ne $$self{m_timerOn} )
            {                         #stop everything but out timer
                $p_event_state = undef;
            }
        }
    }

    return $p_event_state;
}

sub do_off_delay {
    my ( $self, $p_state, $p_setby, $p_event_state ) = @_;
    my $l_delay;

    $l_delay = $self->get_off_delay_effective( $p_state, $p_setby );
    &::print_log("do_off_delay:$$self{object_name}:$l_delay") if $self->{debug};
    if ( $l_delay > 0 ) {    #Delay off is enabled
                             #ON EVENT
        if ( $p_event_state eq 'on' ) {

            #These are considered "Temporary" ON state sets
            if (
                defined($p_setby)
                and (
                    $p_setby->isa('Motion_Item')
                    or (    $p_setby->isa('Presence_Monitor')
                        and $p_state eq 'predict' )
                )
              )
            { #These are subject to a delay off timer upon turning on (temporary state)
                if ( !$self->is_somebody_present( $p_setby, $p_state ) )
                {    #only start the timer if no one is here
                    &::print_log("$$self{object_name}:Delay Start:$l_delay")
                      if $self->{debug};
                    $$self{m_timerOff}->set( $l_delay, $self );
                }
                else {    #stop the timer if this is true
                    $$self{m_timerOff}->unset();
                    &::print_log("$$self{object_name}:Delay Stop:$l_delay")
                      if $self->{debug};
                }
            }
            elsif ( defined($p_setby) and $p_setby eq $$self{m_idleTimer} ) {

                #Ignore the Idle timer, it never causes a delay
            }
            else {
                # All other device states can turn on and stay on
                #stop a delay off timer on any other device set
                &::print_log("$$self{object_name}:Delay Stop:$l_delay")
                  if $self->{debug};
                $$self{m_timerOff}->unset();
            }
            ### OFF EVENT
        }
        elsif ( $p_event_state eq 'off' ) {
            if (
                defined($p_setby)
                and (  $p_setby->isa('Motion_Item')
                    or $p_setby->isa('Presence_Monitor')
                    or $p_setby->isa('Photocell_Item')
                    or $p_setby->isa('Door_Item') )
              )
            { # Do not immediately turn off for these devices. Qualify for delay override
                if ( !$self->is_somebody_present( $p_setby, $p_state ) ) {
                    if ( !$$self{m_timerOn}->active() )
                    {    #only reset if we arent previously running
                        &::print_log("$$self{object_name}:Delay Start:$l_delay")
                          if $self->{debug};
                        $$self{m_timerOff}->set( $l_delay, $self );
                    }
                }
                else {    #stop the timer if someone is here
                    &::print_log("$$self{object_name}:Delay Stop:$l_delay")
                      if $self->{debug};
                    $$self{m_timerOff}->unset();
                }
                $p_event_state = undef;
            }
        }

    }
    &::print_log("$$self{object_name}:Delayout:$p_event_state")
      if $self->{debug};
    return $p_event_state;
}

sub do_idle {
    my ( $self, $p_state, $p_setby, $p_event_state ) = @_;

    #Idle is enabled?
    if ( defined( $$self{m_idleAmount} ) && $$self{m_idleAmount} > 0 ) {

        #Activation qualifying event?
        if ( $p_event_state eq 'on' and $p_setby ne $$self{m_idleTimer} )
        {    #Dont trigger on ourselves!
            $$self{m_idleTimer}->set( $$self{m_idleAmount}, $self );
        }
    }

    #Idle timeout - Neither on or off event, so handle the state change here..
    if (    defined($p_setby)
        and $p_setby eq $$self{m_idleTimer}
        and defined( $$self{m_idleState} ) )
    {
        $p_event_state = $self->idle_state();
    }
    return $p_event_state;
}

sub is_on_event {
    my ( $self, $p_state, $p_setby ) = @_;
    my $l_qualified = 0;

    if ( defined $p_setby and ref $p_setby ) {

        #Criteria Qualifying to turn the light on

        if ( $p_setby->isa('Motion_Item') ) {
            if ( $p_state eq 'motion' ) { $l_qualified = 1; }
        }
        elsif ( $p_setby->isa('Door_Item') ) {
            if ( $p_state eq 'open' ) { $l_qualified = 1; }
        }
        elsif ( $p_setby->isa('Presence_Monitor') ) {
            if ( $p_state eq 'occupied' ) { $l_qualified = 1; }
            if ( $p_state eq 'predict' and $self->predict() ) {
                $l_qualified = 1;
            }
        }
        elsif ( $p_setby->isa('Light_Restriction_Item') ) {
            if (   ( $p_state eq 'light_ok' )
                && ( $self->is_somebody_present( $p_setby, $p_state ) ) )
            {
                $l_qualified = 1;
            }
        }
        elsif ( $p_setby->isa('Photocell_Item') )
        { #Photocell only triggers an ON event if there are no other devices attached
            if ( $p_state eq 'dark' ) {
                if (
                    !(
                           defined $self->find_members('Motion_Item')
                        or defined $self->find_members('Door_Item')
                        or defined $self->find_members('Presence_Monitor')
                    )
                  )
                {
                    $l_qualified = 1;
                }
            }
        }
        elsif ( $p_setby eq $$self{m_idleTimer} )
        { #We consider an idle time an 'on' event.  It will try and set the light at a visible level at least
            if ( $self->idle_state() ne 'off' )
            {    #Only if the idle state is considered on
                $l_qualified = 1;
            }
        }
        elsif ( $p_setby eq $$self{m_timerSync} )
        {        #Todo: Eventually this should probably sync ON states as well..
            $l_qualified = 0;
        }
        elsif ( $p_setby eq $$self{m_timerOn} ) {    #Timeout occurs then go
            if ( $p_state eq 'off' and $self->delay_on() > 0 ) {
                $l_qualified = 1;
            }
        }
        elsif ( $p_setby eq $$self{m_timerOff} ) {
            $l_qualified = 0;
        }
        elsif ( $p_setby eq $$self{m_timerUnlock} ) {
            $l_qualified = 0;
        }
        elsif ( $p_state ne 'off' and $p_state ne 'manual' )
        {                                            #defined but unknown object
            $l_qualified = 1;
        }
    }
    elsif ( $p_state ne 'off' and $p_state ne 'manual' )
    {                                                #undefined unknown object
        $l_qualified = 1;
    }
    return $l_qualified;
}

sub is_on_restriction {
    my ( $self, $p_state, $p_setby ) = @_;
    my $setby_conduit = &main::set_by_to_target($p_setby);
    if (   ( $setby_conduit =~ /^serial|xpl|xap|web|telnet/i )
        or ( $main::Reload and ( $p_setby eq 'init' ) ) )
    {
        &::print_log(
            "$$self{object_name}:No on restrictions permitted when set by non-automation device\n"
        ) if $self->{debug};
        return 0;
    }
    my $l_qualified = 0;

    #restrictions
    if (  !$self->is_change_allowed()
        or $self->manual() )
    {    #restrictions
        $l_qualified = 1;
    }
    if ( defined($p_setby) ) {

        #Automatic on events are no allowed to shutoff lights if someone is here
        if ( $p_setby->isa('Light_Restriction_Item') ) {
            if ( ( $self->is_somebody_present( $p_setby, $p_state ) ) )
            {    #If someone is in the room, allow the light on!
                $l_qualified = 1;
            }
        }
    }
    if ( lc( $self->get_photo() ) eq 'light' ) {

        # if we think it is light, then dont let these objects set to on
        if (
            defined($p_setby)
            and (  $p_setby->isa('Motion_Item')
                or $p_setby->isa('Door_Item')
                or $p_setby->isa('Presence_Monitor')
                or $p_setby eq $$self{m_idleTimer} )
          )
        {
            $l_qualified = 1;
        }

        #Any other object / user can toggle light state
    }

    #	if ($self->is_on_event($p_state,$p_setby) and $self->state() eq 'on') {
    if ( $p_state eq $self->state() )
    {    #Dont bother setting the state if it already is
        $l_qualified = 1;
    }
    if (
        $self->state() eq 'on'
        and (  $p_state eq 'motion'
            or $p_state eq 'open' )
      )
    {    #Dont want to spam these on states if not necessary
        $l_qualified = 1;
    }
    return $l_qualified;
}

sub is_off_event {
    my ( $self, $p_state, $p_setby ) = @_;
    my $l_qualified = 0;

    if ( defined $p_setby ) {

        #Criteria Qualifying to turn the light off

        if ( $p_setby->isa('Motion_Item') )
        {   #Motion Item off event (usually not used by itself, but with a delay
            my @l_objects = $self->find_members('Presence_Monitor');
            if ( @l_objects == 0 ) {
                $l_qualified = 1;
            }    # Generate this event _only_ if occupancy system is not used
        }
        elsif ( $p_setby->isa('Door_Item') ) {    #Closed door will turn us off
            if ( $p_state eq 'closed' ) { $l_qualified = 1; }
        }
        elsif ( $p_setby->isa('Presence_Monitor') ) {    #Vacancy will turn off
            if ( $p_state eq 'vacant' ) { $l_qualified = 1; }
        }
        elsif ( $p_setby->isa('Light_Restriction_Item') )
        {    #We cant be on anymore, so turn off
            if ( $p_state eq 'no_light' ) { $l_qualified = 1; }
        }
        elsif ( $p_setby->isa('Photocell_Item') )
        { #If a photocell is attached and shows us that it is light, then turn off the lights
            if ( $p_state eq 'light' ) { $l_qualified = 1; }
        }
        elsif ( $p_setby eq $$self{m_idleTimer} ) {    #Neither on or off
            if ( $self->idle_state() eq 'off' ) { #only if the idle state is off
                $l_qualified = 1;
            }
        }
        elsif ( $p_setby eq $$self{m_timerSync} )
        {    #Make sure devices that are thought of in MH as off stay off.
            if (    $self->x10_sync()
                and $self->state() eq $p_state
                and $p_state eq 'off'
                and !$$self{m_timerSync}->active() )
            {
                $l_qualified = 1;
                &::print_log("$$self{object_name}:X10syncEnd:Off")
                  if $self->{debug};
            }
        }
        elsif ( $p_setby eq $$self{m_timerOn} ) {    #Does not apply
            $l_qualified = 0;
        }
        elsif ( $p_setby eq $$self{m_timerOff} )
        {    #Delay off timer is tripped, turn off now
            $l_qualified = 1;
        }
        elsif ( $p_setby eq $$self{m_timerUnlock} )
        {    #TODO: Not really sure of the behaviour for this guy.  Kirk?
            $l_qualified = 0;
        }
        elsif ( $p_state eq 'off' ) {    #defined but unknown object
            $l_qualified = 1;
        }
    }
    elsif ( $p_state eq 'off' ) {        #undefined unknown object
        $l_qualified = 1;
    }
    return $l_qualified;

}

sub is_off_restriction {
    my ( $self, $p_state, $p_setby ) = @_;
    my $setby_conduit = &main::set_by_to_target($p_setby);
    if (   ( $setby_conduit =~ /^serial|xpl|xap|web|telnet/i )
        or ( $main::Reload and ( $p_setby eq 'init' ) ) )
    {
        &::print_log(
            "$$self{object_name}:No off restrictions permitted when set by non-automation device ($setby_conduit)"
        ) if $self->{debug};
        return 0;
    }
    my $l_qualified = 0;
    if ( $$self{m_restrict_off} and ( !$self->is_change_allowed() ) )
    {    # We cant change the status of the light
        $l_qualified = 1;
    }
    if ( defined($p_setby) ) {

        #Automatic Off events are no allowed to shutoff lights if someone is here
        if (   $p_setby->isa('Motion_Item')
            or $p_setby->isa('Door_Item')
            or $p_setby->isa('Presence_Monitor')
            or $p_setby eq $$self{m_timerOff}
            or $p_setby eq $$self{m_idleTimer}
            or $p_setby eq $$self{m_timerSync} )
        {
            if ( $self->is_somebody_present( $p_setby, $p_state ) )
            {    #If someone is in the room, dont turn the light off!
                $l_qualified = 1;
            }
        }
    }
    if ( $self->door_always_on() and !$self->are_all_doors_closed() )
    {            #If door always on is enabled
        $l_qualified = 1;
    }
    if ( $self->state() eq $p_state and $p_setby ne $$self{m_timerSync} )
    {            #If we are already off, dont bother sending another.
        $l_qualified = 1;
    }
    return $l_qualified;
}

sub is_change_allowed {
    my ($self) = @_;

    my @l_objects;
    @l_objects = $self->find_members('Light_Restriction_Item');
    for my $obj (@l_objects) {
        &::print_log(
            "Light_Item($$self{object_name}): Light_Restriction_Item $$obj{object_name}: "
              . $obj->state() )
          if $self->{debug};
        if ( $obj->state() eq 'no_light' ) {
            return 0;
        }
    }

    # Only return 1 if no restrictions are active *and* no lock is pending
    if ( $$self{m_pending_lock} ) {
        &::print_log(
            "Light_Item($$self{object_name}): not allowing on because of pending lock"
        ) if $self->{debug};
        return 0;
    }
    else {
        return 1;
    }
}

sub is_somebody_present {
    my ( $self, $p_setby, $p_state ) = @_;
    my @l_objects = $self->find_members('Presence_Monitor');
    foreach (@l_objects) {
        if ( $_->state() eq 'occupied' ) {

            # if the setby object is a Presence_Monitor, then it's state will not yet be set to vacant; so, use the following test
            return 1 unless ( $p_state eq 'vacant' ) and ( $p_setby eq $_ );
        }
    }
    return 0;
}

sub are_all_doors_closed {
    my ($self) = @_;
    my @l_objects = $self->find_members('Door_Item');
    foreach (@l_objects) {
        if ( $_->state() eq 'open' ) {
            return 0;
        }
    }
    return 1;
}

sub get_photo {
    my ($self) = @_;

    ############################
    # Check photocell objects
    ############################
    my @l_objects;
    @l_objects = $self->find_members('Photocell_Item');
    my $l_light = 0;
    my $l_count = 0;

    # Avg light sensors
    for my $obj (@l_objects) {
        $l_count++;
        if ( $obj->state() eq 'light' ) {
            $l_light++;
        }

    }
    if ( $l_light == 0 or ( $l_light / $l_count ) < .5 ) {
        return 'dark';
    }
    return 'light';
}

sub predict {
    my ( $self, $p_blnPredict ) = @_;
    $$self{m_predict} = $p_blnPredict if defined $p_blnPredict;
    &::print_log( "InPredict:"
          . $$self{object_name} . ":"
          . $p_blnPredict . ":"
          . $$self{m_predict} )
      if $self->{debug};
    return $$self{m_predict};
}

sub set_on_state {
    my ( $self, $p_strOnState ) = @_;
    &::print_log("$$self{object_name}:set_on_state($self, $p_strOnState)")
      if $self->{debug};
    $$self{m_on_state} = $p_strOnState if defined $p_strOnState;
    return $$self{m_on_state};
}

sub predict_off_time {
    my ( $self, $p_intPredictOffTime ) = @_;
    $$self{m_predict_off_time} = $p_intPredictOffTime
      if defined $p_intPredictOffTime;
    return $$self{m_predict_off_time};
}

sub door_always_on {
    my ( $self, $p_blnDoorAlwaysOn ) = @_;
    $$self{m_door_always_on} = $p_blnDoorAlwaysOn if defined $p_blnDoorAlwaysOn;
    return $$self{m_door_always_on};
}

sub door_auto_off {
    my ( $self, $p_blnDoorAutoOff ) = @_;
    $$self{m_door_auto_off} = $p_blnDoorAutoOff if defined $p_blnDoorAutoOff;
    return $$self{m_door_auto_off};
}

sub delay_on {
    my ( $self, $p_intDelayOn ) = @_;
    $$self{m_delay_on} = $p_intDelayOn if defined $p_intDelayOn;
    return $$self{m_delay_on};
}

sub manual {
    my ( $self, $p_manual, $p_manualOnTime, $p_manualOffTime ) = @_;
    if ( defined($p_manual) ) {
        $$self{m_manual_auto_off} = 0;
        $$self{m_manual_auto_on}  = 0;
        if ( $p_manual =~ /^auto/i ) {
            $$self{m_manual_auto_off} = 1;
            $$self{m_manual_auto_on}  = 1;
        }
        $$self{m_manual} = $p_manual;
        if ( ($p_manual) and ($p_manualOnTime) ) {
            my ( $onTime, $autoOnFlag ) = $p_manualOnTime =~ /(\d+):(\S+)?/;
            $onTime = $p_manualOnTime unless defined $onTime;
            $$self{m_manual_auto_on} = 1 if $autoOnFlag;
            my $_manualOffTime = $p_manualOffTime;
            $_manualOffTime = $p_manualOnTime unless $_manualOffTime;
            my ( $offTime, $autoOffFlag ) = $_manualOffTime =~ /(\d+):(\S+)?/;
            $offTime = $p_manualOffTime unless defined $offTime;
            $$self{m_manual_auto_off} = 1 if $autoOffFlag;
            $$self{m_manualTimer}->unset();

            if (   ( $self->state eq 'off' )
                or ( $self->state eq '' )
                or ( $self->state eq '0%' ) )
            {
                &::print_log(
                    "Light_Item($$self{object_name}):: setting mode to manual (off)"
                      . ( ( $$self{m_manual_auto_off} ) ? "[auto]" : "" )
                      . "; reverting in $offTime seconds" )
                  if $self->{debug};
                $$self{m_manualTimer}->set( $offTime, $self );
            }
            else {
                &::print_log(
                    "Light_Item($$self{object_name}):: setting mode to manual (on)"
                      . ( ( $$self{m_manual_auto_on} ) ? "[auto]" : "" )
                      . "; reverting in $onTime seconds" )
                  if $self->{debug};
                $$self{m_manualTimer}->set( $onTime, $self );
            }
        }
    }
    return $$self{m_manual};
}

sub idle_state {
    my ( $self, $p_idleState, $p_idleAmount ) = @_;
    if ( defined($p_idleState) ) {
        $$self{m_idleState} = $p_idleState;
        $self->idle_amount($p_idleAmount);
    }
    return $$self{m_idleState};
}

sub idle_amount {
    my ( $self, $p_idleAmount ) = @_;
    if ( defined($p_idleAmount) ) {
        $$self{m_idleAmount} = $p_idleAmount;
    }
}

sub x10_sync {
    my ( $self, $p_blnSync ) = @_;
    $$self{m_sync} = $p_blnSync if defined $p_blnSync;
    if ( !$$self{m_sync} ) {
        $$self{m_timerSync}->unset();
    }
    return $$self{m_sync};
}

sub start_delay_off {
    my ( $self, $p_setby ) = @_;
    my $delay = 0;
    if ( $self->{m_on_state} ) {

        # Don't set timer to turn off if we think it is already off...
        # Unless no on state is specified, in which case this light is
        # one that only turns off and not on, in which case we might not
        # know the light is on
        return if ( $self->state eq 'off' );
    }

    # Return if it wouldn't be okay to turn on the light
    return unless ( $self->is_change_allowed() );

    # Don't set timer if it is already active
    return if ( $$self{m_timerOff}->active );

    # Don't start off delay timer if delay_off is set to 0
    return if ( $self->delay_off() == 0 );
    if ( $$self{m_door_always_on} and not $self->are_all_doors_closed() ) {

        # Don't start delay off if a door is opened... and door always on is enabled
        return;
    }
}

sub restore_string {
    my ($self) = @_;
    my $l_restore_string = undef;

    #We dont want MH saving our state.. Start new everytime! :)

    if ( $$self{m_save_state} ) {
        $l_restore_string = $self->SUPER::restore_string;
        $l_restore_string =~ s/-\>{state}=(.*);/-\>{state}='off'/ig;

        #&::print_log("Restore:::$l_restore_string:") if $self->{debug};
    }

    return $l_restore_string;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee  - jason@sharpee.com

Kirk Bauer - kirk@kaybee.org

Special Thanks to: Bruce Winter - MH

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

