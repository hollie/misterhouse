=head1 B<SqueezeboxCLI>

=head2 SYNOPSIS

The module enables control of a Squeezebox device through the CLI (command line 
interface) of the Squeezebox server (a.k.a. Logitech Media server).

=head2 CONFIGURATION

This module connects to the Squeezebox server through the telnet interface. The following 
preparations need to be done to get the code up and running:

Create the Squeezebox devices in the mht file or in user code:

.mht file:

  CODE, require SqueezeboxCLI; #noloop 
  CODE, $sb_living  = new SqueezeboxCLI('living', <server_name>); #noloop
  CODE, $sb_kitchen = new SqueezeboxCLI('kitchen', <servername>); #noloop

=head2 OVERVIEW

This module allows control over a player through the telnet command line interface of
the server.

=cut
package SqueezeboxCLI;

# Used solely to provide a consistent logging feature, copied from Nest.pm

use strict;

#log levels
my $warn  = 1;
my $info  = 2;
my $trace = 3;

sub debug {
    my ($self, $message, $level) = @_;
    $level = 0 if $level eq '';
    my $line = '';
    my @caller = caller(0);
    if ($::Debug{'squeezeboxcli'} >= $level || $level == 0){
        $line = " at line " . $caller[2] if $::Debug{'squeezeboxcli'} >= $trace;
        ::print_log("[" . $caller[0] . "] " . $message . $line);
    }
}

package SqueezeboxCLI_Interface;

use strict;

@SqueezeboxCLI_Interface::ISA = ('Generic_Item', 'SqueezeboxCLI');

sub new {
	my ($class, $server, $port, $user, $pass) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	$$self{server} = $server;
	$$self{port}   = $port || 9090;
	$$self{login}  = $user . " " . $pass || "";
	$$self{players} = {};
	$$self{reconnect_timer} = new Timer;
	$$self{squeezecenter} = new Socket_Item(undef, undef, $$self{server}. ":" . $$self{port}, "squeezecenter_cli", 'tcp', 'record');
	$self->login();
	::MainLoop_pre_add_hook(sub {$self->check_for_data();}, 'persistent');
	return $self;
}


sub login {
	my ($self) = @_;
	
	$self->debug( "Connecting to squeezecenter ..." ); 
    $self->{squeezecenter}->start();
    $self->{squeezecenter}->set_echo(0);
    
    if ($self->{login} ne " ") {
    	$self->{squeezecenter}->set('login ' . $self->{login});
    }
    	 
    $self->{squeezecenter}->set('listen 1');      
}

sub reconnect {     
	my ($self) = @_;
	
	$self->{squeezecenter}->stop();
    $self->login();

}

sub reconnect_delay {
    my ($self, $seconds) = @_;
    my $action = sub {$self->reconnect()};
    if (!$seconds) {
        $seconds = 60;
        $self->debug("Connection to squeezecenter lost, will try to connect again in 1 minute.");
    }
    $$self{reconnect_timer}->set($seconds,$action);
}

sub check_for_data {
	my ($self) = @_;

	unless ($$self{squeezecenter}->connected()) {
		$self->reconnect_delay();
		return;
	}
			
	if (my $data = $self->{squeezecenter}->said()) {
	
		# If we get a status response, check if we need to add the player to the lookup hash.
		# This code will be executed after the status is requested in the 'add_player' routine.
		# This is the only time we touch the actual server response, all other protocol specific 
		# code is implemented in SqueezeboxCLI_Player.
		if ($data =~ /([\w|%]{27})\s+status\s+player_name%3A(\w+)/) {
			my $player_mac  = $1;
			my $player_name = $2;
			if (!defined($$self{players_mac}{$player_mac})) {
				$self->debug("Adding $player_name to the MAC lookup", 2);
				$$self{players_mac}{$player_mac} = $$self{players}{$player_name};
				return;
			}
		
		}
		
		if ($data =~ /([\w|%]{27})\s+(.+)/) {
			$self->debug("Passing message to player '$1' for further processing", 4);
			# Pass the message to the correct object for processing
			$$self{players_mac}{$1}->process_cli_response($2);
		} else {
			$self->debug("Received unknown text: $data");
		}
		
    	# if ($data =~ m/.* power 0 .*$/) {
#         	main::print_log " power aus";        
#     	} elsif ($data =~ m/.* power 1 .*$/) {
#         	main::print_log " power an";        
#         #set $EG_WZ_Multimedia ON;
#     	} elsif ($data =~ /([\w|%]+)\s+status\s+player_name%3A(\w+)/) {
#     		$self->debug("Got status response for $1 (= $2), adding it to the lookup hash", 1);
#     		
#     		$$self{players_mac}{$1} = shift(@{$self->{players}});
#     	} else {
#         	main::print_log " unknown text: $data";
#     	}
	}
}

sub add_player {
	my ($self, $player) = @_;
	
	# Add the player to the list of players the gateway knows
	$$self{players}{$player->{sb_name}} =  $player;
	$self->debug( "Added player '" . $player->{sb_name} . "'");
	
	# Determine the MAC address of the player by requesting the status
	$$self{squeezecenter}->set($player->{sb_name} . " status");
}
	
	
package SqueezeboxCLI_Player;

use strict;

=head2 DEPENDENCIES

  URI::Escape       - The CLI interface uses an escaped format

=cut

use URI::Escape;

@SqueezeboxCLI_Player::ISA = ('Generic_Item', "SqueezeboxCLI");

sub new {
	my ($class, $name, $interface) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	$$self{sb_name} = $name;
	$$self{interface} = $interface;
	$$self{interface}->add_player($self);
	return $self;
}

sub process_cli_response {
	my ($self, $response) = @_;
	$self->debug($self->get_object_name() . ": processing $response", 2);
	
	if ($response =~ /^power (\d)/) {
		$self->debug($$self{object_name} . " power is " . $1);
	}
}


=item C<set_receive()>

Handles setting the state of the object inside MisterHouse

=cut

sub set_receive {
    my ($self, $p_state, $p_setby, $p_response) = @_;
    $self->SUPER::set($p_state, $p_setby, $p_response);
}

1;
