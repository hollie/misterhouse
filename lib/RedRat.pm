=begin comment

Used to control infrared devices with the RedRat2

http://www.dodgies.demon.co.uk/index.html

Use these mh.ini parameters to enable this code:

 RedRat_serial_port   = COM9

 in code use:

#####################################################
	$ir_dvd=new RedRat;
	$ir_dvd->add("power","[PF62........]");
	$if_dvd->add("play","[PF62........]");

	$v_ir_dvd = new Voice_Cmd('push dvd [power,play] button');

	if ($state = said $v_ir_dvd) {
	        $ir_dvd->set($state);
	}
#####################################################
=cut

use strict;

package RedRat;

@RedRat::ISA = ('Serial_Item');

sub serial_startup {
    &main::serial_port_create('RedRat', $main::config_parms{RedRat_serial_port}, 19200, 'none');
}

sub new {
    my ($class) = @_;
    my $self = {};
    $$self{state} = '';
    bless $self, $class;
    return $self;
}

sub add {
	my ($self, $command, $code) = @_;
        $$self{$command} = $code;
	push(@{$$self{states}},$command);
}

sub set {
    my ($self, $command) = @_;
	if (!defined $$self{$command}) {
		&::print_log("RedRat: Invalid State: $command");
	} else {
		if ($main::Debug{redrat} ) {
			&::print_log("RedRat: Sending $command -> $$self{$command}");
		}
		select(undef,undef,undef,0.40);
		$main::Serial_Ports{RedRat}{object}->write($$self{$command});
		&Generic_Item::set_states_for_next_pass($self,$command);
	}

}


1;
