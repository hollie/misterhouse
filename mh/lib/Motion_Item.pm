=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Motion_Item.pm

Description:
	

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	Example initialization:

	
	Constructor Parameters:

	Input states:

	Output states:

Bugs:

Special Thanks to: 
	Bruce Winter - MH
		

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;
use Timer;

package Motion_Item;

@Motion_Item::ISA = ('Base_Item');

sub initialize
{
	my ($self) = @_;

	$$self{m_timeout} = new Timer() if $$self{m_timeout} eq '';
	$$self{m_timeout}->set(2*60,$self);
	$$self{m_timerCheck} = new Timer() if $$self{m_timerCheck} eq '';
	$$self{m_timerCheck}->set(24*60*60,$self);
}

sub set
{
	my ($self,$p_state,$p_setby) = @_;

   # Hawkeye (MS13) motion detector
   if ($p_state eq 'motion') {
      $p_state = 'on';
   } elsif ($p_state eq 'still') {
      $p_state = 'off';
   }

	if ($p_state eq 'on' and $p_setby ne $$self{m_timeout}) { # Received ON
#		$main::DBI->prepare("insert into Events (Object,ObjectType,State) values ('$$self{object_name}','motion','$p_state');")->execute();
		$$self{m_timeout}->set(2*60,$self);
		$$self{m_timerCheck}->set(24*60*60,$self);
	} elsif ( $p_state eq 'on' and $p_setby eq $$self{m_timeout}) { # Timer expired
		$p_state='off';
	} elsif ( $p_state eq 'off' and $p_setby eq $$self{m_timerCheck} ) {
		$p_state='check';
		&::print_log($$self{object_name} . "->Has not received motion in 24hrs");
	} elsif ( $p_state eq 'off' and $p_setby ne $$self{m_timeout}) { # Motion OFF
		$$self{m_timeout}->stop() if defined $$self{m_timeout}
	}
	$self->SUPER::set($p_state,$p_setby);
}

sub delay_off()
{
	my ($self,$p_time) = @_;
	$$self{m_delay_off} = $p_time if defined $p_time;
	return $$self{m_delay_off};	
}

1;

