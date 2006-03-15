#
#Asterisk Telephony Implementation class
#

use Telephony_Item;

package Asterisk;

@Asterisk::ISA = ('Telephony_Item');

#Initialize class
sub new 
{
	my ($class) = @_;
	my $self;
	bless $self, $class;

	return $self;
}

#Add Asterisk implementation code here to get CID
sub callerid_hook
{
	my ($self)= @_;
	$self->cid_name('Jim Jones');
        $self->cid_number('4145551212);
        $self->cid_type('N'); # N-Normal, P-Private/Blocked, U-Unknown;
	$self->set('cid');
}

sub set 
{
	my ($self, $p_state, $p_setby, $p_response) = @_;
	return if &main::check_for_tied_filters($self, $state);


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
