=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Photocell_Item.pm

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
use Base_Item;

package Photocell_Item;

@Photocell_Item::ISA = ('Base_Item');
my $m_writable = 0;
my $m_timerCheck;
my $m_blnCheck=1;

sub initialize
{
	my ($self) = @_;
	$$self{m_timerCheck} = new Timer() if ! defined $$self{m_timerCheck};
	$$self{m_timerCheck}->set(24*60*60,$self);
	$$self{state}='dark';
}

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;
	my $l_state;

	if ($p_state eq 'on') {
		$l_state = 'dark';
	} elsif ($p_state eq 'off' and $p_setby eq $$self{m_timerCheck} ) {
		$l_state = 'check';
		&::print_log($$self{object_name} . "->No state change in 24hrs.");
	} elsif ($p_state eq 'off') {
		$l_state = 'light';
	} else {
		$l_state = $p_state;
	}
	if ($$self{m_blnCheck}) {
		$$self{m_timerCheck}->set(24*60*60,$self);
	}
	$self->SUPER::set($l_state,$p_setby,$p_response);

}

sub check()
{
	my ($self,$p_blnCheck) = @_;
	$$self{m_blnCheck} = $p_blnCheck if defined $p_blnCheck;
	if (! $$self{m_blnCheck}) {
		$$self{m_timerCheck}->stop();		
	}
	return $$self{m_blnCheck};

}
1;

