use strict;

package StargateJTelephone;

@StargateJTelephone::ISA = ('StargateTelephone');

sub patch()
{
	my ($self,$p_state) = @_;
	if (lc($p_state) eq 'on') {
		&::set_audio('ic','off');
		&::set_audio('sg','on');
	} else {
		&::set_audio('ic','on');
		&::set_audio('sg','off');
	}
	$self->SUPER::patch($p_state);
}

1;
