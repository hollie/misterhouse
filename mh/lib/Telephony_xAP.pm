=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Telephony_xAP.pm

Description:
	xAP Listener for Telephony Events (Based on CID.Meteor Schema)
	
Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	Example initialization:

		use Telephony_xAP;

		$tel = new Telephony_xAP();


	Input states:

	Output states:
		"CID"		- CallerID is available
		<input states>  - All input states are echoed exactly to the output state as 
				  well.


Bugs:
	- Does not handle all telephony events right now. 
	- Call logging will be implemented next

Special Thanks to: 
	Bruce Winter - MH
		

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use xAP_Items;
package Telephony_xAP;
@Telephony_xAP::ISA = ('Telephony_Item');

my $m_xap;

#Initialize class
sub new 
{
	my ($class,$p_xap) = @_;
	my $self={};
	bless $self, $class;

	#&xAP::startup if $Reload;
	$$self{m_xap} = new xAP_Item('Telephony.Info');# if ! defined $p_xap;
	&main::store_object_data($$self{m_xap},'xAP_Item','Telephony','Telephony'); #if ! defined $p_xap;
#	$$self{m_xap} = $p_xap if defined $p_xap;
	$$self{m_xap}->tie_items($self);
	return $self;
}

sub outgoing_hook
{
	my ($self,$p_xap)= @_;
	
        $self->cid_number($$p_xap{'outgoing.callcomplete'}{phone});
	$self->address($$p_xap{'outgoing.callcomplete'}{line});
	$self->cid_name('Outgoing');
	$self->cid_type('N');
	return 'dialed';

}

sub callerid_hook
{
	my ($self,$p_xap)= @_;
#	foreach (keys %{$$p_xap{'incoming.callwithcid'}}) {
#		&::print_log("Keys: $_");
#	}
	#CLEAR
	$self->cid_name('');
	$self->cid_number('');
	$self->cid_type('');
	$self->cid_name($$p_xap{'incoming.callwithcid'}{name});
        $self->cid_number($$p_xap{'incoming.callwithcid'}{phone});
        $self->cid_type('N'); # N-Normal, P-Private/Blocked, U-Unknown;
#	&::print_log("CID=====". $$p_xap{'incoming.callwithcid'}{rnname} );
	if (uc $$p_xap{'incoming.callwithcid'}{rnnumber} eq 'UNAVAILABLE' or 
		uc $$p_xap{'incoming.callwithcid'}{rnnumber} eq 'WITHHELD' ) {
	        $self->cid_type('U'); # N-Normal, P-Private/Blocked, U-Unknown;
	}	
	$self->address($$p_xap{'incoming.callwithcid'}{line});
#	&::print_log("CID====" . $self->cid_number());
	return "cid";
}



sub set 
{
	my ($self, $p_state, $p_setby, $p_response) = @_;
	return if &main::check_for_tied_filters($self, $state);

	if ($p_setby eq $$self{m_xap} ) {
		if (defined $$self{m_xap}{'incoming.callwithcid'} ) {
			$state=$self->callerid_hook($p_setby);
		} elsif (defined $$self{m_xap}{'outgoing.callcomplete'} ) {
			$state=$self->outgoing_hook($p_setby);
		}
#		&::print_log("TXAP:$p_state:$p_setby:" . ${$$self{m_xap}}{'incoming.callwithcid'}{phone} . ":");		
	}	


	# Always pass along the state to base class
	$self->SUPER::set($state,$p_setby, $p_response); 

	return;
}

sub patch
{
	my ($self,$p_state)= @_;

	return $self->SUPER::patch($p_state);
}

sub play
{
	my ($self,$p_file) = @_;

	$self->patch("on");
	&::play ($p_file);
	return $self->SUPER::play($p_file);
}

sub record
{
	my ($self,$p_file,$p_timeout) = @_;

#	&::rec ($p_file);  ????
	return $self->SUPER::rec($p_file,$p_timeout);
}

sub speak
{
	my ($self,%p_phrase) = @_;
	$self->patch('on');
	&::speak(%p_phrase);
#	Is there a way to know when speaking is finished?
#	$self->patch('off');
	return $self->SUPER::speak(%p_phrase);	

}
sub dtmf
{
	my ($self,$p_dtmf) = @_;
	
	return $self->SUPER::dtmf($p_dtmf);	
}

sub dtmf_sequence
{
	my ($self,$p_dtmf_seq) = @_;
	
	return $self->SUPER::dtmf_sequence($p_dtmf_seq);	
}

sub hook
{
	my ($self,$p_state) = @_;
	
	if ($p_state eq 'on')
	{
	}
	elsif (defined $p_state)
	{
	}
	return $self->SUPER::hook($p_state);
}

1;
