
=head1 B<SqueezeboxCLI>

=head2 SYNOPSIS

The module enables control of a Squeezebox device through the CLI (command line 
interface) of the Squeezebox server (a.k.a. Logitech Media server).

=head2 CONFIGURATION

This module connects to the Squeezebox server through the telnet interface. The following 
preparations need to be done to get the code up and running:

Create the Squeezebox devices in the mht file or in user code:

Note: [parameters] are optional.

.mht file:

  CODE, require SqueezeboxCLI; #noloop 
  CODE, $squeezecenter = new SqueezeboxCLI_Interface('hostname'); #noloop 
  CODE, $sb_living  = new SqueezeboxCLI('living', $squeezecenter, [coupled_device], [auto_off_time]); #noloop
  CODE, $sb_kitchen = new SqueezeboxCLI('kitchen', $squeezecenter, [coupled_device], [auto_off_time]); #noloop
  
Optional parameters:

=over

=item you can add a 'coupled device' to the Squeezebox. You would typically use this
when you want to switch the amplifier together with the Squeezebox. Couple a device with:
  CODE, $sb_living->couple_device($amplifier_living);

=item you can set an 'auto-off' time in minutes. When the player gets paused, you can define after how many minutes is should be turned off completely.
This is useful when you have defined a coupled device to avoid the amplifier to be on for too long after a playlist is paused.

=back

=head2 OVERVIEW

This module allows to control and to monitor the state over a player through the telnet 
command line interface of the server.

=cut

package SqueezeboxCLI;

# Used solely to provide a consistent logging feature, copied from Nest.pm

use strict;

#log levels
my $warn  = 1;
my $info  = 2;
my $trace = 3;

sub debug {
    my ( $self, $message, $level ) = @_;
    $level = 0 if $level eq '';
    my $line   = '';
    my @caller = caller(0);
    if ( $::Debug{'squeezeboxcli'} >= $level || $level == 0 ) {
        $line = " at line " . $caller[2]
            if $::Debug{'squeezeboxcli'} >= $trace;
        ::print_log( "[" . $caller[0] . "] " . $message . $line );
    }
}

package SqueezeboxCLI_Interface;

use strict;

@SqueezeboxCLI_Interface::ISA = ( 'Generic_Item', 'SqueezeboxCLI' );

sub new {
    my ( $class, $server, $port, $user, $pass ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{server}          = $server;
    $$self{port}            = $port || 9090;
    $$self{login}           = $user . " " . $pass || "";
    $$self{players}         = {};
    $$self{reconnect_timer} = new Timer;
    $$self{squeezecenter}
        = new Socket_Item( undef, undef, $$self{server} . ":" . $$self{port},
        "squeezecenter_cli", 'tcp', 'record' );
    $self->login();
    ::MainLoop_pre_add_hook( sub { $self->check_for_data(); }, 'persistent' );
    return $self;
}

sub login {
    my ($self) = @_;

    $self->debug("Connecting to squeezecenter ...");
    $self->{squeezecenter}->start();
    $self->{squeezecenter}->set_echo(0);

    if ( $self->{login} ne " " ) {
        $self->{squeezecenter}->set( 'login ' . $self->{login} );
    }

    $self->{squeezecenter}->set('listen 1');
}

sub reconnect {
    my ($self) = @_;

    $self->{squeezecenter}->stop();
    $self->login();

}

sub reconnect_delay {
    my ( $self, $seconds ) = @_;
    my $action = sub { $self->reconnect() };
    if ( !$seconds ) {
        $seconds = 60;
        $self->debug(
            "Connection to squeezecenter lost, will try to connect again in 1 minute."
        );
    }
    $$self{reconnect_timer}->set( $seconds, $action );
}

sub check_for_data {
    my ($self) = @_;

    unless ( $$self{squeezecenter}->connected() ) {
        $self->reconnect_delay();
        return;
    }

    if ( my $data = $self->{squeezecenter}->said() ) {

# If we get a status response, check if we need to add the player to the lookup hash.
# This code will be executed after the status is requested in the 'add_player' routine.
# This is the only time we touch the actual server response, all other protocol specific
# code is implemented in SqueezeboxCLI_Player.
        if ( $data =~ /([\w|%]{27})\s+status\s+player_name%3A(\w+)/ ) {
            my $player_mac  = $1;
            my $player_name = $2;
            if ( !defined( $$self{players_mac}{$player_mac} ) ) {
                $self->debug( "Adding $player_name to the MAC lookup", 2 );
                $$self{players_mac}{$player_mac}
                    = $$self{players}{$player_name};
            }

        }

        if ( $data =~ /([\w|%]{27})\s+(.+)/ ) {
            $self->debug(
                "Passing message to player '$1' for further processing", 4 );

            # Pass the message to the correct object for processing
            $$self{players_mac}{$1}->process_cli_response($2);
        }
        else {
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
    my ( $self, $player ) = @_;

    # Add the player to the list of players the gateway knows
    $$self{players}{ $player->{sb_name} } = $player;
    $self->debug( "Added player '" . $player->{sb_name} . "'" );

    # Determine the MAC address of the player by requesting the status
    $$self{squeezecenter}->set( $player->{sb_name} . " status" );

}

package SqueezeboxCLI_Player;

use strict;

=head2 DEPENDENCIES

  URI::Escape       - The CLI interface uses an escaped format

=cut

use URI::Escape;

@SqueezeboxCLI_Player::ISA = ( 'Generic_Item', "SqueezeboxCLI" );

sub new {
    my ( $class, $name, $interface, $coupled_device, $auto_off_time ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{sb_name}        = $name;
    $$self{interface}      = $interface;
    $$self{coupled_device} = $coupled_device || "";
    $$self{auto_off_time}  = $auto_off_time || 0;
    $$self{auto_off_timer} = new Timer;
    $$self{interface}->add_player($self);

    # Ensure we can turn the SB on and off
    $self->addStates( 'on', 'off' );
    return $self;
}

sub process_cli_response {
    my ( $self, $response ) = @_;

    # Remove URI escape sequences
    $response = uri_unescape($response);

    # Ignore the following messages, we're currently not using them
    return if ( $response =~ /^prefset/ );
    return if ( $response =~ /^menustatus/ );

    $self->debug( $self->get_object_name() . ": processing $response", 2 );

    if ( $response =~ /power[:| ](\d)/ ) {
        my $command = ( $1 == 1 ) ? 'ON' : 'OFF';
        $self->set( $command, 'cli' );
        $self->debug( $$self{object_name}
                . " power is "
                . $1
                . " command is $command" );

        # Turn off the coupled device immediately if the SB is turned off
        if ( $$self{coupled_device} ne "" && $command eq 'OFF' ) {
            $$self{coupled_device}->set($command);
            $$self{auto_off_timer}->unset();
        }

    }
    if ( $response =~ /mixer volume[:| ](\d+)/ ) {
        $$self{mixer_volume} = $1;
        $self->debug( $$self{object_name} . " mixer volume is " . $1 );
    }
    if ( $response =~ /^pause (\d)/ || /mode[:| ]pause/ ) {

        # If we are paused then maybe we need to fire the auto-off timer
        if ( $1 == '1' ) {

            # Don't auto-off if the setting is '0';
            return if ( $$self{auto_off_time} == 0 );

            # Otherwise program the auto-off timer
            my $action = sub { $self->default_setstate('off'); };
            $$self{auto_off_timer}
                ->set( $$self{auto_off_time} * 60, $action );
            $self->debug( $$self{object_name} . " auto-off timer set" );
        }
    }
    if ( $response =~ /mode[:| ]play/ ) {

# In case an auto-off timer is active we need to disable it when we start playing
        $self->debug(
            $$self{object_name} . " mode is playing, auto-timeoff cleared " );
        $$self{auto_off_timer}->unset();

        # Control the coupled device too if it is defined
        if ( $$self{coupled_device} ne "" ) {
            $$self{coupled_device}->set('on');
        }

    }

}

=item C<default_setstate()>

Handle state changes of the Squeezeboxes

=cut

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;

    # If we're set by the CLI then we don't need to send out the command again
    return -1 if ( $set_by eq 'cli' );

    my $cmnd = ( $state =~ /^off/i ) ? 'stop' : 'play';

    return -1
        if ( $self->state eq $state )
        ;    # Don't propagate state unless it has changed.
    $self->debug( "[SqueezeboxCLI] Request "
            . $self->get_object_name
            . " turn "
            . $cmnd
            . ' after '
            . $state );

    if ( $cmnd eq 'stop' ) {
        $$self{interface}{squeezecenter}->set( $$self{sb_name} . ' power 0' );
    }
    else {
        $$self{interface}{squeezecenter}->set( $$self{sb_name} . ' power 1' );
    }

}

=item C<addStates()>

Add states to the device

=cut

sub addStates {
    my $self = shift;
    push( @{ $$self{states} }, @_ ) unless $self->{displayonly};
}

=item C<couple_device(amplifier)>

Couple another MisterHouse object to the Squeezebox device so that this device follows the
state of the Squeezebox. This can e.g. be used to switch an amplifier on when the
Squeezebox starts playing.

=cut

sub couple_device {
    my ( $self, $device ) = @_;

    $$self{coupled_device} = $device;
}
1;
