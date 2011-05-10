
# This object simply pings the specified address and sets
# its state according to status

package Network_Item;

=begin comment

This code is not well tuned or tested.  Here is an example:

use Network_Item;

$network_house = new Network_Item('192.168.0.2',  10);
$network_hp    = new Network_Item('192.168.0.66', 20);

print_log "house just changed to $state" if      $state = state_changed $network_house;
print_log "house is $state" if new_second 15 and $state = state $network_house;

=cut


@Network_Item::ISA = ('Generic_Item');

sub new {
    my ($class, $address, $interval) = @_;
	my $self={};
	bless $self,$class;

    my $ping_test_cmd   = ($::OS_win) ? 'ping -n 1 ' : 'ping -c 1 ';
    my $ping_test_file  = "$::config_parms{data_dir}/ping_results.$address.txt";

    $self->{address}  = $address;
    $self->{interval} = $interval;

    $self->{timer} = new Timer;
    $self->{timer}-> set($self->{interval}, sub {&Network_Item::ping_check($self)}, -1);

    $self->{process} = new Process_Item($ping_test_cmd . $address);
    $self->{process}-> set_output($ping_test_file);
    unlink $ping_test_file;

    return $self;
}

sub ping_check {
    my ($self) = @_;
    my $address = $self->{address};
    &::print_log("Network_Item ping on ip=$address") if $::Debug{network};

    $self->{process}->stop();

    my $ping_test_file  = "$::config_parms{data_dir}/ping_results.$address.txt";
    if (-e $ping_test_file) {
        my $ping_results = &::file_read($ping_test_file);
        print "db ping_results for $address f=$ping_test_file: $ping_results\n" if $::Debug{network};
        my $state = ($ping_results =~ /ttl=/i) ? 'up' : 'down';
	if ($self->state ne $state) { $self->set($state); };
	unlink $ping_test_file;
    }

    $self->{process}->start();

}

sub default_setstate
{
    my ($self, $state) = @_;
    if ($state !~ m/^up|down|start$/i){
    	&::print_log("Invalid state for Network_Item: $state") if $::Debug{network};
    	return -1;
    } else {
    	&::print_log("Setting " .$self->{address}." as " .$state) if $::Debug{network};
    }
}
