
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
  CODE, $sb_living  = new SqueezeboxCLI_Player('living', $squeezecenter, [coupled_device], [auto_off_time]); #noloop
  CODE, $sb_kitchen = new SqueezeboxCLI_Player('kitchen', $squeezecenter, [coupled_device], [auto_off_time]); #noloop
  
Optional parameters:

=over

=item you can add a 'coupled device' to the Squeezebox. You would typically use this
when you want to switch the amplifier together with the Squeezebox. Couple a device with:
  CODE, $sb_living->couple_device($amplifier_living);

=item you can set an 'auto-off' time in minutes. When the player gets paused, you can define after how many minutes is should be turned off completely.
This is useful when you have defined a coupled device to avoid the amplifier to be on for too long after a playlist is paused.

=back

To play a file or URL from your user code you can use this function call:

$sb_kitchen->play_notification('/Volumes/Media/speech/test1.wave');


=head2 OVERVIEW

This module allows to control and to monitor the state over a Squeezebox player through the telnet 
command line interface of the server. It also allows you to play notifications. Notifications
can either be local files or URLs.

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
            # but only do this for players we're supposed to manage
            my $player = $1;
            if (defined $$self{players_mac}{$player}) {
            	$$self{players_mac}{$player}->process_cli_response($2);
            }
        }
        else {
            $self->debug("Received unknown text: $data");
        }

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
    $$self{'notification_active'}        = 0;
    $$self{'notification_command_fired'} = 0;

    # Ensure we can turn the SB on and off
    $self->addStates( 'on', 'off', 'play', 'pause' );
    return $self;
}

sub process_cli_response {
    my ( $self, $response ) = @_;

    # Remove URI escape sequences
    $response = uri_unescape($response);

    # Ignore the following messages, we're currently not using them
    return if ( $response =~ /^prefset/ );
    return if ( $response =~ /^menustatus/ );
    return if ( $response =~ /^displaynotify/ );

    $self->debug(
        $self->get_object_name()
            . ": processing '$response', current state "
            . $self->state(),
        2
    );

    if ( $response =~ /power[:| ](\d)/ ) {
        my $command = ( $1 == 1 ) ? 'on' : 'off';
        $self->debug( $$self{object_name}
                . " power is "
                . $1
                . " command is $command" );
        $self->set_now( $command, 'cli' );

        # Turn off the coupled device immediately if the SB is turned off
        if ( $$self{coupled_device} ne "" && $command eq 'off' ) {
            $$self{coupled_device}->set($command);
            $$self{auto_off_timer}->set(0);
        }

    }
    if ( $response =~ /mixer volume[:| ](\d+)/ ) {
        $$self{mixer_volume} = $1;
        $self->debug( $$self{object_name} . " mixer volume is " . $1 );
    }
    if ( ( $response =~ /^pause 1/ || $response =~ /mode[:| ][pause|stop]/ )
        && $self->state() ne 'off' )
    {
        $self->debug( $$self{object_name}
                . " we got mode pause and state is "
                . $self->state() );

        $self->set_now( 'pause', 'cli' );

        # Don't auto-off if the setting is '0';
        if ( $$self{auto_off_time} ) {

            # Program the auto-off timer
            my $action = sub { $self->set( 'off', 'timer' ); };
            $$self{auto_off_timer}
                ->set( $$self{auto_off_time} * 60, $action );
            $self->debug( $$self{object_name}
                    . " auto-off timer set because current state is "
                    . $self->state() );
        }
    }
    if ( ( $response =~ /^pause 0/ ) ) {

        # Request the current mode if pause is 0
        $self->send_cmd("mode ?");
    }
    if ( $response =~ /mode[:| ]play/ ) {
        $self->debug( $$self{object_name}
                . " received mode play, now in "
                . $self->state() );

        $self->set_now( 'play', 'cli' );

# In case an auto-off timer is active we need to disable it when we start playing
        $self->debug( $$self{object_name}
                . " mode is "
                . $self->state()
                . ", auto-timeoff cleared " );
        $$self{auto_off_timer}->set(0);

        # Control the coupled device too if it is defined
        if ( $$self{coupled_device} ne "" ) {
            $$self{coupled_device}->set('on');
        }

    }
    if ( $response =~ /playlist repeat[:| ](\d)/ ) {
        $$self{repeat} = $1;
        $self->debug( $$self{object_name} . " repeat mode is $1" );
    }
    if ( $response =~ /time (\d+.\d+)/ ) {
        $$self{'time'} = $1;
        $self->debug( $$self{object_name} . " time is $1" );
    }

    # Restore the SB status when the notification is finisched playing
    if ( $response =~ /playlist stop/ && $$self{notification_active} ) {
        $$self{notification_active} = 0;
        $self->restore_sb_state();
    }

# We need this to know when the notification is loaded, then the next 'done' means
# the notification is done. This way we don't need to poll and hence stall MisterHouse
    if (   $response =~ /playlist load_done/
        && $$self{notification_command_fired} )
    {
        $$self{notification_active}        = 1;
        $$self{notification_command_fired} = 0;
    }

}

=item C<default_setstate()>

Handle state changes of the Squeezeboxes

=cut

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;

    $self->debug(
        $$self{object_name} . " in setstate with $state setby $set_by" );

    # If we're set by the CLI then we don't need to send out the command again
    # as we actually received it from the server
    return if ( $set_by eq 'cli' );

    # Don't propagate state unless it has changed.
    return -1 if ( $self->state eq $state );

    # Print debug info
    $self->debug( "Request "
            . $self->get_object_name
            . " to change to state '$state' by '$set_by'" );

    if ( $state =~ /^off/i ) {
        $self->send_cmd('power 0');
    }
    if ( $state =~ /^on/i ) {
        $self->send_cmd('power 1');
    }
    if ( $state =~ /^play/i ) {
        $self->send_cmd('mode play');
    }
    if ( $state =~ /^pause/i ) {
        $self->send_cmd('mode pause');
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

=item C<play_notification(notification)>

Play a notification on this squeezebox. The notification can either be a file or an URL.
This function stops the current playback, plays the notification and then returns the
Squeezebox to the previous state. Credits to @rudybrian for writing the first version 
of this code and his permission to re-use it!

=cut

sub play_notification {
    my ( $self, $notification ) = @_;

    # Save the state
    $self->save_sb_state();

    # Pause playback if required
    if ( $self->state() eq "play" ) {
        $self->send_cmd("pause 1 1");
    }

    # Get the current playback position
    $self->send_cmd("time ?");

    # Save the current playlist
    $self->send_cmd("playlist save prenotification_playlist_" . $$self{object_name});

    # Set the repeat to none
    $self->send_cmd("playlist repeat 0");

    # Play notification
    # Ensure we know we're playing a notification.
    $$self{'notification_command_fired'} = 1;

    $self->send_cmd("playlist play $notification");

    #$self->send_cmd("mode play");

}

=item C<save_sb_state> 

Saves the current state of the Squeezebox so that it can be restored later

=cut

sub save_sb_state {
    my $self = shift;

    $$self{'prev_state'}->{'state'}  = $self->state();
    $$self{'prev_state'}->{'repeat'} = $$self{'repeat'};
    $self->debug( $$self{object_name}
            . " saved state to be: state:"
            . $$self{'prev_state'}->{'state'}
            . " repeat:"
            . $$self{'prev_state'}->{'repeat'} );

}

=item C<restore_sb_state> 

Resume the Squeezebox state from the previously saved state

=cut

sub restore_sb_state {
    my $self = shift;

    $self->debug( $$self{object_name} . " restoring the SB state" );

    # Restore playlist/mode
    if ( $$self{prev_state}->{'state'} eq 'play' ) {
        $self->send_cmd("playlist resume prenotification_playlist");
        $self->send_cmd( "time " . $$self{'time'} );
    }
    else {
        $self->send_cmd("playlist resume prenotification_playlist noplay:1");
    }

    # And restore repeat state
    $self->send_cmd( "playlist repeat " . $$self{'prev_state'}->{'repeat'} );

# Ensure we know the state of the device in this module, request the state explicitly
    $self->send_cmd("mode ?");

}

=item C<send_cmd(command)>

Helper function to send a command to the squeezebox over the CLI

=cut

sub send_cmd {
    my ( $self, $cmd ) = @_;
    $$self{interface}{squeezecenter}->set( $$self{sb_name} . ' ' . $cmd );
    $self->debug( $$self{object_name} . " sending command '$cmd'" );
}
1;
