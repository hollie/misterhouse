=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Door_Item.pm

Description:
   An abstract object that represents a door that you can add to a Light_Item.
   You typically associate a real door item (i.e. an RF door sensor or a digital
   input or the like) to this object.  It will also indicate the state of the
   door on the web-based floorplan.pl.

Author:
	Jason Sharpee/Kirk Bauer
	jason@sharpee.com/kirk@kaybee.org

License:
	This free software is licensed under the terms of the GNU public license.

Usage:
	Example initialization:
      These are to be placed in a *.mht file in your user code directory.

      First, define your actual door object (these are just examples):
         RF,          E1,     rf_front_door
         STARGATEDIN, 7,      sg_patio_door

      Then, define the Door_Item and attach the real object:
         # Object 'front_door' attached to existing object 'rf_front_door'
         DOOR, rf_front_door, front_door
	
	Input states:
      on: door opened
      off: door closed

	Output states:
      on: door opened
      off: door closed

   Optional Alarm:
      If you want to be alerted when the door is left open too long:
      om_front_door->set_alarm(300, "speak('front door left open');");

Bugs:
   Should state of 'open' be turned into 'on' and 'closed' turned into 'off'?

Special Thanks to: 
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Door_Item;

@Door_Item::ISA = ('Base_Item');

sub initialize
{
   my ($self) = @_;
   $$self{m_timerCheck} = new Timer() if $$self{m_timerCheck} eq '';
   $$self{'alarm_action'} = '';
}


# If an alarm is set, the specified action is executed if the 
# door was left open for the specified amount of time
sub set_alarm($$$) {
   my ($self, $time, $action) = @_;
   $$self{'alarm_action'} = $action;
   $$self{'alarm_time'} = $time;
}

sub set
{
   my ($self,$p_state,$p_setby) = @_;

   # X10.com door/window security sensor
   if (($p_state eq 'alertmin') or ($p_state eq 'alertmax')) {
      $p_state = 'on';
   } elsif (($p_state eq 'normalmin') or ($p_state eq 'normalmax')) {
      $p_state = 'off';
   }

   # Other door sensors?
   if ($p_state eq 'open') {
      $p_state = 'on';
   } elsif ($p_state eq 'closed') {
      $p_state = 'off';
   }

   if ($p_state eq 'on') {
      if ($$self{'alarm_action'}) {
         $$self{m_timerCheck}->set($$self{'alarm_time'}, $$self{'alarm_action'});
      }
   } elsif ($p_state eq 'off') {
      $$self{m_timerCheck}->unset();
   }

   $self->SUPER::set($p_state,$p_setby);
}

1;

