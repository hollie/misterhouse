=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Presence_Monitor.pm

Description:
	This is an object that is attached to the Occupancy Monitor (usually $om)
   as well as one Door_Item or Motion_Item.  It maintains whether or not there
   is presence (or predicted presence) within a given room.  You should have one
   per room in your house, even if the room has multiple motion detectors.  Not
   only will this object show up on floorplan.pl, but it can also be attached
   to a Light_Object to make sure the light remains on when somebody is present.
   If the light has prediction enabled it will also cause the light to turn on
   when somebody may be entering the room.

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:
	Example initialization:
      These are to be placed in a *.mht file in your user code directory.

      First, make sure you have an occupancy monitor:
         OCCUPANCY, om

      Then, create your presence objects:
         PRESENCE, sensor_X, om, presence_X

      This creates a new Presence_Monitor object of name 'presence_X'
      and attaches it to both the occupancy monitor and 'sensor_X'.  The
      'sensor_X' object must already have been defined and needs to be
      either a Door_Item or a Motion_Item.
	
	Output states:
      vacant: Nobody is in the room
      predict: Somebody may be entering the room
      occupied: Somebody is in the room

Special Thanks to: 
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Presence_Monitor;

@Presence_Monitor::ISA = ('Generic_Item');

sub new
{
	my ($class,$p_object,$p_OM) = @_;
	my $self={};
	bless $self,$class;
	$$self{m_obj}= $p_object;
	$$self{m_OM} = $p_OM;
	$p_OM->tie_items($self);
	$$self{m_timerVacant} = new Timer();
	$$self{state}=0;
	return $self;
}

sub set
{
	my ($self, $p_state, $p_setby, $p_response) = @_;

	my $l_count = $$self{m_OM}->sensor_count($$self{m_obj});
	#we dont care about $p_state as we derive it from the sensor count.  one way only.
		
	#Timer expired.  Reset predict state
	if ($p_setby eq $$self{m_timerVacant} and $self->state() eq 'predict') { #timer up reset
		if ($$self{m_OM}->sensor_count($$self{m_obj}) eq -1) {
			$$self{m_OM}->sensor_count($$self{m_obj}, 0);
			$p_state = 'vacant';
		} else {
			$p_state = undef;
		}
	} 
	elsif ($p_setby eq $$self{m_timerVacant} and $self->state() eq 'occupied') { #timer up
		$p_state = 'vacant';
	}
	#start the timer for prediction
	elsif ($l_count < 0 and ( $self->state() eq 'occupied' or $self->state() eq 'vacant' ) ) { 
		$$self{m_timerVacant}->set(60, $self);
		$p_state = 'predict';
	}		
	elsif ( $l_count eq '1' ) {
		$p_state = 'occupied';
		if (defined $$self{m_delay_off}) {
			$$self{m_timerVacant}->set($$self{m_delay_off}, $self);
		} else {
			$$self{m_timerVacant}->stop();
		}		
 	}
	elsif ( $l_count eq '0' or $l_count eq '') {
		$p_state = 'vacant';
	}
	elsif ( $l_count eq '-1' ) {
		$p_state = 'predict';
	}
	if ( defined $p_state and $p_state ne $self->state()) {
		$self->SUPER::set($p_state, $p_setby, $p_response);
	}
	#ignore all other state settings
}

sub writable
{
	return 0;
}

#sub default_getstate
#{
#	my ($self,$p_state) = @_;
#		
#	return $$self{m_OM}->sensor_count($$self{m_obj});
#}

1;

