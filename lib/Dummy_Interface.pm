# $Date$
# $Revision$

# This is the Dummy_Interface class and is used as a placeholder interface.
# It's entire job is to warn users that a real, working interface couldn't
# be found.

package Dummy_Interface;

use Device_Item;
@Dummy_Interface::ISA=('Device_Item');

our $nextInstanceId=0;
our @supported_interfaces=('dummy');

sub new {
	my ($class, $id, $state, $interface)=@_;
	my $self={};
	bless $self,$class;
	$self->{instanceId}=$nextInstanceId;
	$nextInstanceId++;

	# let users know why we exist
	$self->firstWarning; 

	$self->warning("being created for id $id, state $state and interface $interface");
	return $self;
}

sub firstWarning {
	my ($self)=@_;

	$self->warning("This Dummy_Interface is being used because MrHouse can't find a real hardware device to support some requested functionality")
}

sub warning {
	my ($self,$message)=@_;

	$message='Dummy_Item #'.$self->instanceId.": $message";
	warn $message;
}

sub instanceId {
	my ($self) =@_;

	return $self->{instanceId};
}

sub set {
	my ($self,$state)=@_;

	$self->warning("trying to set state $state");
}

sub add {
	my ($self, $id, $state)=@_;

	$self->warning("trying to add id $id state $state");
	$self->SUPER::add($id, $state);
}

sub said {
	my ($self)=@_;

	return '';
}

sub set_data {
	my ($self, $data) = @_;

	$self->warning("trying to set_data $data");
}

sub set_receive {
	my ($self, $state) = @_;

	$self->warning("trying to set_receive $state");
}

sub write_data {
	my ($self, $data) = @_;

	$self->warning("trying to write_data $data");
}

sub is_started {
	my ($self) = @_;

	return 0;
}

sub start {
	my ($self) = @_;

	$self->warning("trying to start");
}

sub set_interface {
	my ($self, $interface)=@_;

	$self->warning("trying to set interface $interface");
}

sub lookup_interface {
	my ($self, $interface)=@_;

	$self->warning("trying to lookup_interface $interface");

	if ($interface and $interface ne '') {
		return lc $interface;
	}

	return 'dummy';
}

sub get_supported_interfaces {
	my ($self) = @_;

	$self->warning("trying to get_supported_interfaces");
	return \@supported_interfaces;
}

sub supports {
	my ($self, $interface);

	$self->warning("trying to find out if we support $interface");

	return 1;
}

# do not remove the following line, packages must return a true value
1;
