=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Light_Item.pm

Description:
   An abstract object that represents a light that can be automatically
   controlled by Door_Items, Motion_Items, Presence_Items, Photocell_Items,
   and Light_Restriction_Items.  These are all controlled through the 
   Occupancy_Monitor object.

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
         as long as occupancy remains true.
      x10_sync(): Pass in a 1 to enable x10 sync, 0 to disable.  Currently
         this will make sure lights that are supposed to be off really are
         off around once per hour.  The default is enabled.
      set_on_state(): Pass in another state besides the default of ON to 
         use when turning "on" the light.
      set_predict_off_time(): You can override the default 60-second off time
         when a light is predictively turned on but nobody actually enters
         the room.
      door_auto_off(X): Turn off this light X seconds after all attached doors
         are closed UNLESS an attached occupancy monitor has a state of
         'occupied'.  In that case, when the room is no longer occupied
         and if all doors are closed the light will immediately turn off.
         Set this to 0 to disable (default) or a number of seconds to wait
         to establish occupancy before the light is turned off.
	
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

Bugs:

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
	$$self{m_timerSync} = new Timer();
	$$self{m_timerSync}->set(1800 + (rand() * 1800), $self); #random off command
	$$self{m_timerOff} = new Timer();
   $$self{m_predict_off_time} = 60;  # Default predict off time of 60 seconds
	$$self{m_on_state} = 'on'; # Turn on to "on" by default
	$$self{m_predict} = 0; # Turn off prediction by default
	$$self{m_sync} = 1; # Turn on X10 sync
	$$self{m_door_auto_off} = 0;
}

sub set
{
	my ($self,$p_state,$p_setby,$p_respond) = @_;

	my $l_state=$p_state;
   if (defined $p_setby and $p_setby->isa('Light_Restriction_Item')) {
      # No immediate action by default, unless this change now made
      # lighting okay.
	   $l_state = undef;
      if (($p_state eq 'light_ok') and ($self->is_on_okay())) {
         # Now lights are okay where they might not have been okay before
         # So, if the room is occupied, turn on the light...
         # NOTE: Shouldn't this also happen when a Photocell_Item changes to 'dark'?
         if ($self->is_somebody_present()) {
			   if ($self->get_photo() eq 'dark' and $self->state() eq 'off') {
   				$l_state = $$self{m_on_state};
            }
         }
      }
   }
	################ Presence Monitor ###############
	if (defined $p_setby and 
		$p_setby->isa('Presence_Monitor') ) {
#		&::print_log("Presence in light:" . $$self{object_name} . ":" . $$p_setby{object_name} . ":" . $p_state . ":" . $self->state() . ":");
		if ($p_state eq 'occupied') { #Someone is in the room. Kill all timers
#			$self->set_with_timer('',0,'off');
			$$self{m_timerOff}->stop();
#			&::print_log("TimerOff:" . $$self{m_timerOff} );
			if ($self->get_photo() eq 'dark' and
				$self->state() eq 'off') { #only turn on if room is dark
            if ($self->is_on_okay()) {
   				$l_state = $$self{m_on_state};
            } else {
				   $l_state = undef; # do not set on state if already on
            }
			} else {
				$l_state = undef; # do not set on state if already on
			}
		} elsif ($p_state eq 'vacant' and ! $$self{m_timerOff}->active()) {
			$l_state = undef;
         unless ($self->is_somebody_present()) {
   	      if ($$self{m_door_auto_off} and $self->are_all_doors_closed()) {
               # All doors closed... turn off light immediately
			      $l_state = 'off';
            } else { 
   			   #Self delay comes first then setby's delay
      			$self->start_delay_off($p_setby);
            }
         }
		} elsif ( $p_state eq 'predict' ) {
			if ($self->state() eq 'off' and $$self{m_predict} ) {
#				&::print_log("Predict: " . $$self{object_name});
				$$self{m_timerOff}->set($$self{m_predict_off_time}, $self); 
				if ($self->get_photo() eq 'dark' and
					$self->state() eq 'off') { #only turn on if room is dark
               if ($self->is_on_okay()) {
   				   $l_state = $$self{m_on_state};
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
		if ($p_state eq 'on') {
			if ($self->get_photo() eq 'dark' and
				uc $self->state() eq 'OFF') { #only turn on if room is dark
            if ($self->is_on_okay()) {
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
				$self->start_delay_off($p_setby);
			}
			# Someone is in this room reset the x10 sync if active
			if ($$self{m_timerSync}->active() ) {
#				&::print_log($$self{object_name} . ":x10 sync restart");
				$$self{m_timerSync}->restart();
			}
		} elsif (($p_state eq 'off') and $p_setby->isa('Door_Item') and 
               $$self{m_door_auto_off} and (not $self->is_somebody_present())
               and $self->are_all_doors_closed()) {
         # Door auto-off enabled and a door was just closed and nobody is present
         # Also all connected doors are closed
         $$self{m_timerOff}->set($$self{m_door_auto_off}, $self);
			$l_state = undef;
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
            if ($self->is_on_okay()) {
			      $l_state = $$self{m_on_state};
            } else {
				   $l_state = undef; # do not set on state if already on
            }
			} else {
				$l_state = 'off';
			}			
		} else {
			$l_state=undef;
		}
	}
	############## X10 SYNC ####################
	if (defined $p_setby and 
		$p_setby eq $$self{m_timerSync} ) {
		if ($self->state() eq 'off') { ## For now only sync off state
#			&::print_log($$self{object_name} . ": X10 off sync");
			$l_state = $self->state();	
		} else {
			$l_state = undef;
		}
		if ($$self{m_sync} ) {
			$$self{m_timerSync}->set(1800 + (rand() * 1800),$self);
		}
	} 
	############# SET LIGHT STATE ##############
	if (defined $l_state) {
		$self->SUPER::set($l_state,$p_setby,$p_respond);
	}
}

sub is_on_okay {
	my ($self) = @_;

	############################
	# Check Light_Restriction_Item objects
	############################
	my @l_objects;
	@l_objects = $self->find_members('Light_Restriction_Item');
	for my $obj (@l_objects) {
		if ($obj->state() eq 'no_light') {
         return 0;
		}
	}
   # Only return 1 if no restrictions are active
   return 1;
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
      if ($_->state() eq 'on') {
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

sub door_auto_off {
	my ($self, $p_blnDoorAutoOff) = @_;
	$$self{m_door_auto_off} = $p_blnDoorAutoOff if defined $p_blnDoorAutoOff;
	return $$self{m_door_auto_off};
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

sub start_delay_off
{
	my ($self,$p_setby) = @_;

	if ($p_setby->can('delay_off') and defined $p_setby->delay_off() ) {
      # Use controlling objects delay, if set
		$$self{m_timerOff}->set($p_setby->delay_off(), $self);
	} elsif ($self->can('delay_off') and defined $self->delay_off() ) { 
      # Otherwise, use this light object's delay
		$$self{m_timerOff}->set($self->delay_off(), $self);
	}
}

1;

