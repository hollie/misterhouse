=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Light_Item.pm

Description:
   An abstract object that represents a light that can be automatically
   controlled by Door_Items, Motion_Items, Presence_Monitors, Photocell_Items,
   Light_Restriction_Items, and Light_Switch_Items.  

   Often times, Door_Items and Motion_Items are also used by the Occupancy
   Monitor which in turn manages the state of the Presence_Monitor objects.

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:
	Example initialization:
      These are to be placed in a *.mht file in your user code directory.

      First, define your actual light object:
         X10I,      H2,     x10_hallway_lights

      Then, define the Light_Item and attach the real object:
         LIGHT, x10_hallway_lights, hallway_light

      Finally, in your user code, you need to add one or more objects
      that will determine how the light is controlled.  You can attach
      objects of type: Door_Item, Motion_Item, Photocell_Item, Presence_Item,
      and Light_Restriction_Item.  You used the add() function:

         $om_auto_hall_bath_light->add($om_motion_hall_bath, 
            $om_presence_hall_bath, $only_when_home);

   Other configuration:
      delay_off(): How long the light should remain on after the last event
         (i.e. door, motion, occupancy) occurs.  The light will not turn off
         as long as occupancy remains true.  If this is set to 0, the light
         will never turn off based on a timer (but could still turn off
         because of a Photocell_Item/Light_Restriction_Item or if 
         door_auto_off() is enabled.
      x10_sync(): Pass in a 1 to enable x10 sync, 0 to disable.  Currently
         this will make sure lights that are supposed to be off really are
         off around once per hour.  The default is enabled.
      set_on_state(): Pass in another state besides the default of ON to 
         use when turning "on" the light.  Set to empty ('') to prevent
         this light from turning on automatically (but it will still 
         turn off automatically).
      set_predict_off_time(): You can override the default 60-second off time
         when a light is predictively turned on but nobody actually enters
         the room.
      door_auto_off(X): Turn off this light X seconds after all attached doors
         are closed UNLESS an attached occupancy monitor has a state of
         'occupied'.  In that case, when the room is no longer occupied
         and if all doors are closed the light will immediately turn off.
         Set this to 0 to disable (default) or a number of seconds to wait
         to establish occupancy before the light is turned off.
      door_always_on(): This light should always be on whenever an attached
         door is open, assuming any attached photocell items say it is dark
         in the room and unless a light restriction item says otherwise.
      delay_on(): The room must be continuously occupied for the specified
         number of seconds before the light will come on.  Note that you
         do NOT want to attach door objects and motion objects to the object
         if using this feature -- just attach the presence object(s) and
         any light restriction objects (and possibly a Light_Switch_Object).
      manual(X): Set X to 1 to set the light into a full manual mode where
         it will never be turned on or off automatically.
	
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

Special Thanks to: 
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;
use Base_Item;

package Light_Item;

@Light_Item::ISA = ('Base_Item');

sub initialize
{
	my ($self) = @_;
   $$self{m_write} = 1;
	$$self{m_timerSync} = new Timer();
	$$self{m_timerSync}->set(1800 + (rand() * 1800), $self); #random off command
	$$self{m_timerOff} = new Timer();
	$$self{m_timerUnlock} = new Timer();
	$$self{m_timerOn} = new Timer();
   $$self{m_predict_off_time} = 60;  # Default predict off time of 60 seconds
	$$self{m_on_state} = 'on'; # Turn on to "on" by default
	$$self{m_predict} = 0; # Turn off prediction by default
	$$self{m_sync} = 1; # Turn on X10 sync
	$$self{m_door_auto_off} = 0;
	$$self{m_door_always_on} = 0;
   $$self{m_pending_lock} = 0;
   $$self{m_delay_on} = 0;
   $$self{m_manual} = undef;
}

sub set
{
	my ($self,$p_state,$p_setby,$p_respond) = @_;
   if (ref $p_setby) {
      if ($p_setby->can('get_set_by')) {
         &::print_log("Light_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name} was set by " . $p_setby->get_set_by) if $main::Debug{occupancy};
      } else {
         &::print_log("Light_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name}") if $main::Debug{occupancy};
      }
      &::print_log("Timers: sync: $$self{m_timerSync}, off: $$self{m_timerOff}, unlock: $$self{m_timerUnlock}") if $main::Debug{occupancy};
   }

	my $l_state=$p_state;

   return if defined($$self{m_manual});

	################ Light Restriction Item ###############
   if (defined $p_setby and $p_setby->isa('Light_Restriction_Item')) {
      # No immediate action by default, unless this change allowed or disallowed lighting
	   $l_state = undef;
      if (($p_state eq 'light_ok') and ($self->is_change_allowed())) {
         # Now lights are okay where they might not have been okay before
         # So, if the room is occupied, turn on the light...
         # NOTE: Shouldn't this also happen when a Photocell_Item changes to 'dark'?
         if ($self->is_somebody_present()) {
			   if ($self->get_photo() eq 'dark' and $self->state() eq 'off') {
				   unless ($$self{m_timerOn}->active()) {
         		   $l_state = $$self{m_on_state};
               }
            }
         }
      } elsif (($p_state eq 'no_light') and ($self->state() eq 'on') and (not $$self{m_pending_lock})) {
         # Lights are no longer okay, and the light is on, so turn it off.
         &::print_log("$$self{object_name}: Turning off light because $$p_setby{object_name} no longer allows lights");
         $l_state = 'off';
      }
   }

	################ Light Switch Item ###############
   if (defined $p_setby and $p_setby->isa('Light_Switch_Item')) {
      # Right now, these objects never cause the light to turn on or off...
      # they just possibly enable a "lock" on the light (a lock means that
      # the light will not be turned on or off by this module)
	   $l_state = undef;
      if ($p_setby->lockable) {
         my $tmp = $p_setby->lock_timeout_on;
         if ($p_state eq 'off') {
            $tmp = $p_setby->lock_timeout_off;
         }
         if ($tmp > $$self{m_pending_lock}) {
            &::print_log("Light_Item($$self{object_name}): setting pending lock: $tmp") if $main::Debug{occupancy};
            $$self{m_pending_lock} = $tmp;
         }
      }
   }

	################ Presence Monitor ###############
	elsif (defined $p_setby and 
		$p_setby->isa('Presence_Monitor') ) {
#		&::print_log("Presence in light:" . $$self{object_name} . ":" . $$p_setby{object_name} . ":" . $p_state . ":" . $self->state() . ":");
		if ($p_state eq 'occupied') { #Someone is in the room. Kill all timers
         &::print_log("$$self{object_name}: Stopping delay off because of presence...") if $main::Debug{occupancy};
			$$self{m_timerOff}->stop();
			$$self{m_timerUnlock}->stop();
	      if ($$self{m_delay_on}) {
            if ($$self{m_timerOn}->inactive()) {
   				$$self{m_timerOn}->set($$self{m_delay_on}, $self); 
            }
			   $l_state = undef; # only turn on after a delay
         } else {
   			if ($self->get_photo() eq 'dark' and
   				$self->state() eq 'off') { #only turn on if room is dark
               if ($self->is_change_allowed()) {
      				$l_state = $$self{m_on_state};
               } else {
   				   $l_state = undef; # do not set on state if already on
               }
   			} else {
   				$l_state = undef; # do not set on state if already on
            }
			}
		} elsif ($p_state eq 'vacant') {
			$l_state = undef;
         unless ($self->is_somebody_present()) {
   			$$self{m_timerOn}->stop();
   	      if ($$self{m_door_auto_off} and $self->are_all_doors_closed()) {
               &::print_log("$$self{object_name}: All doors closed and room vacant, turning off light");
               # All doors closed... turn off light immediately
               if ($self->is_change_allowed()) {
 			         $l_state = 'off';
               }
            } else {
               &::print_log("$$self{object_name}: Starting delay off after vacancy...") if $main::Debug{occupancy};
      			$self->start_delay_off($p_setby);
            }
            if ($$self{m_pending_lock}) {
			      $l_state = undef;
               $$self{m_timerUnlock}->set($$self{m_pending_lock}, $self);
            }
         }
		} elsif ( $p_state eq 'predict' ) {
			if ($self->state() eq 'off' and $$self{m_predict} ) {
#				&::print_log("Predict: " . $$self{object_name});
            &::print_log("$$self{object_name}: Starting delay off because of prediction...") if $main::Debug{occupancy};
				if ($self->get_photo() eq 'dark' and
					$self->state() eq 'off') { #only turn on if room is dark
               if ($self->is_change_allowed()) {
   				   $l_state = $$self{m_on_state};
                  unless ($$self{m_timerOff}->active) {
                     $$self{m_timerOff}->set($$self{m_predict_off_time}, $self); 
                  }
               } else {
   				   $l_state = undef; # do not set on state if already on
               }
				} else {
					$l_state = undef; # do not set on state if already on
				}
			} else {
				$l_state=undef;
			}
		} else {
			$l_state=undef;
		}
	}

	############## Motion and Door ################
	elsif (defined $p_setby and 
		( $p_setby->isa('Motion_Item') or $p_setby->isa('Door_Item') ) ) { #Motion or Door
		if (($p_state eq 'open') or ($p_state eq 'motion')) {
			if ($self->get_photo() eq 'dark' and
				$self->state() eq 'off') { #only turn on if room is dark
            if ($self->is_change_allowed()) {
               &::print_log("$$self{object_name}: Stopping delay off because of motion or door...") if $main::Debug{occupancy};
			      $$self{m_timerOff}->stop();
   			   $l_state = $$self{m_on_state};
            } else {
				   $l_state = undef; # do not set on state if already on
            }
			} else {
				$l_state = undef; # do not set on state if already on
			}
			#If presence monitor attached and someone is present then dont set timer
         unless ($self->is_somebody_present()) {
				#set off timer
            &::print_log("$$self{object_name}: Starting delay off after door or motion...") if $main::Debug{occupancy};
				$self->start_delay_off($p_setby);
			}
			# Someone is in this room reset the x10 sync if active
			if ($$self{m_timerSync}->active() ) {
#				&::print_log($$self{object_name} . ":x10 sync restart");
				$$self{m_timerSync}->restart();
			}
		} elsif (($p_state eq 'closed') and $p_setby->isa('Door_Item') and
         (not $self->is_somebody_present()) and $self->are_all_doors_closed()) {
 			$l_state = undef;
         if ($$self{m_door_auto_off}) {
            # Door auto-off enabled and a door was just closed and nobody is 
            # present.  Also all connected doors are closed
            &::print_log("$$self{object_name}: Starting delay off for door closure: $$self{m_door_auto_off} seconds") if $main::Debug{occupancy};
            if ($self->is_change_allowed()) {
               unless ($$self{m_timerOff}->active) {
                  $$self{m_timerOff}->set($$self{m_door_auto_off}, $self);
               }
            }
         } elsif ($$self{m_door_always_on}) {
            # Light was forced on because a door was open... so now start off timer
            &::print_log("$$self{object_name}: Starting delay off after door was closed...") if $main::Debug{occupancy};
				$self->start_delay_off($p_setby);
         }
      } else { #ignore anything else from sensor
			$l_state = undef;
		}
	}
	############## Photocell ################
	elsif (defined $p_setby and
		$p_setby->isa('Photocell_Item') ) {
		#if no motion, door, or presence, then turn on / off light with photocell
		if ( ! (defined $self->find_members('Motion_Item') or
			defined $self->find_members('Door_Item') or
			defined $self->find_members('Presence_Monitor') ) ) { 
			if ($p_state eq 'dark') {
            if ($self->is_change_allowed()) {
			      $l_state = $$self{m_on_state};
            } else {
				   $l_state = undef; # do not set on state if already on
            }
			} else {
            if ($self->is_change_allowed()) {
				   $l_state = 'off';
            }
			}			
		} else {
			$l_state=undef;
		}
	}
	############## X10 SYNC ####################
	elsif (defined $p_setby and 
		$p_setby eq $$self{m_timerSync}) {
		$l_state = undef;
		if ($self->state() eq 'off') { ## For now only sync off state
#			&::print_log($$self{object_name} . ": X10 off sync");
         if ($self->is_change_allowed()) {
            # Don't sync lights to off unless turning it on would otherwise be okay
   			$l_state = $self->state();	
         }
		}
		if ($$self{m_sync}) {
         if ($self->is_change_allowed()) {
   			$$self{m_timerSync}->set(1800 + (rand() * 1800), $self);
         }
		}
	} 
	############## Unlock object ####################
	elsif (defined $p_setby and ($p_setby eq $$self{m_timerUnlock}) and ($p_state eq 'off')) {
		$l_state = undef;
      # Clear the pending lock and start the off timer
      &::print_log("Light_Item($$self{object_name}): clearing pending lock") if $main::Debug{occupancy};
      $$self{m_pending_lock} = 0;
      &::print_log("$$self{object_name}: Starting delay off after object was unlocked...") if $main::Debug{occupancy};
		$self->start_delay_off($p_setby);
	} 
	############## Delayed on timer ####################
   elsif (defined $p_setby and ($p_setby eq $$self{m_timerOn}) and ($p_state eq 'off')) {
      $l_state = undef;
      &::print_log("Light_Item($$self{object_name}): got delayed on timer...") if $main::Debug{occupancy};
      if ($self->get_photo() eq 'dark' and
            $self->state() eq 'off') { #only turn on if room is dark
         &::print_log("Light_Item($$self{object_name}): delayed on: room is dark and light is off...") if $main::Debug{occupancy};
         if ($self->is_change_allowed()) {
            &::print_log("Light_Item($$self{object_name}): delayed on: turning light on...") if $main::Debug{occupancy};
            $l_state = $$self{m_on_state};
         }
      }
   }
	############# SET LIGHT STATE ##############
	if (defined $l_state and $l_state) {
		$self->SUPER::set($l_state,$p_setby,$p_respond);
	}
}

sub is_change_allowed {
	my ($self) = @_;

	my @l_objects;
	@l_objects = $self->find_members('Light_Restriction_Item');
	for my $obj (@l_objects) {
      &::print_log("Light_Item($$self{object_name}): Light_Restriction_Item $$obj{object_name}: " . $obj->state()) if $main::Debug{occupancy};
		if ($obj->state() eq 'no_light') {
         return 0;
		}
	}
   # Only return 1 if no restrictions are active *and* no lock is pending
   if ($$self{m_pending_lock}) {
      &::print_log("Light_Item($$self{object_name}): not allowing on because of pending lock") if $main::Debug{occupancy};
      return 0;
   } else {
      return 1;
   }
}

sub is_somebody_present {
	my ($self) = @_;
   my @l_objects = $self->find_members('Presence_Monitor');
   foreach (@l_objects) {
      if ($_->state() eq 'occupied') {
         return 1;
      }
   }
   return 0;
}

sub are_all_doors_closed {
   my ($self) = @_;
   my @l_objects = $self->find_members('Door_Item');
   foreach (@l_objects) {
      if ($_->state() eq 'open') {
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
	my $l_light=0;
	my $l_count=0;
	# Avg light sensors
	for my $obj (@l_objects) {
		$l_count++;
		if ($obj->state() eq 'light') {
			$l_light++;
		}

	}
	if ($l_light == 0 or ($l_light / $l_count) < .5) {
		return 'dark';
	}
}

sub predict
{
	my ($self,$p_blnPredict) = @_;
	$$self{m_predict} = $p_blnPredict if defined $p_blnPredict;
#	&::print_log("InPredict:" . $$self{object_name} . ":" . $p_blnPredict . ":" . $$self{m_predict});
	return $$self{m_predict};
}

sub set_on_state
{
	my ($self,$p_strOnState) = @_;
#  &::print_log("set_on_state($self, $p_strOnState)");
	$$self{m_on_state} = $p_strOnState if defined $p_strOnState;
	return $$self{m_on_state};
}

sub predict_off_time
{
	my ($self,$p_intPredictOffTime) = @_;
	$$self{m_predict_off_time} = $p_intPredictOffTime if defined $p_intPredictOffTime;
	return $$self{m_predict_off_time};
}

sub door_always_on {
	my ($self, $p_blnDoorAlwaysOn) = @_;
	$$self{m_door_always_on} = $p_blnDoorAlwaysOn if defined $p_blnDoorAlwaysOn;
	return $$self{m_door_always_on};
}

sub door_auto_off {
	my ($self, $p_blnDoorAutoOff) = @_;
	$$self{m_door_auto_off} = $p_blnDoorAutoOff if defined $p_blnDoorAutoOff;
	return $$self{m_door_auto_off};
}

sub delay_on {
	my ($self, $p_intDelayOn) = @_;
	$$self{m_delay_on} = $p_intDelayOn if defined $p_intDelayOn;
	return $$self{m_delay_on};
}

sub manual {
	my ($self, $p_manual) = @_;
   if (defined($p_manual)) {
   	$$self{m_manual} = $p_manual;
   }
	return $$self{m_manual};
}

sub x10_sync
{
	my ($self,$p_blnSync) = @_;
	$$self{m_sync} = $p_blnSync if defined $p_blnSync;
	if (! $$self{m_sync}) {
		$$self{m_timerSync}->stop();
	}
	return $$self{m_sync};
}

sub start_delay_off {
   my ($self, $p_setby) = @_;
   my $delay = 0;
   if ($self->{m_on_state}) {
      # Don't set timer to turn off if we think it is already off...
      # Unless no on state is specified, in which case this light is
      # one that only turns off and not on, in which case we might not
      # know the light is on
      return if ($self->state eq 'off');
   }
   # Return if it wouldn't be okay to turn on the light 
   return unless ($self->is_change_allowed());
   # Don't set timer if it is already active
   return if ($$self{m_timerOff}->active);
   # Don't start off delay timer if delay_off is set to 0
   return if ($self->delay_off() == 0);
   if ($$self{m_door_always_on} and not $self->are_all_doors_closed()) {
      # Don't start delay off if a door is opened... and door always on is enabled
      return;
   }
   if ($p_setby->can('delay_off') and defined $p_setby->delay_off()) {
      # Use controlling objects delay, if set
      $delay = $p_setby->delay_off();
   } elsif ($self->can('delay_off') and defined $self->delay_off()) { 
      # Otherwise, use this light object's delay
      $delay = $self->delay_off();
   }
   if ($$self{m_pending_lock} and ($$self{m_pending_lock} > $delay)) {
      # Use pending lock delay if greater...
      $delay = $$self{m_pending_lock};
      &::print_log("Light_Item($$self{object_name}): timed off, using pending lock: $delay") if $main::Debug{occupancy};
   }
   &::print_log("$$self{object_name}: delay off started: $delay") if $main::Debug{occupancy};
   $$self{m_timerOff}->set($delay, $self);
}

1;

