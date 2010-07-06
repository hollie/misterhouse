=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

xPL_Squeezebox.pm - xPL support for the former SlimDevices (now Logitech) Squeezebox devices

  $Date$
  $Revision$

Info:

  This module allows to easily integrate Squeezebox devices in your MH setup.

  It supports device monitoring (check the heartbeat), keeps the state of the 
  squeezebox (playing/stopped/power_off), allows to play sounds while 
  maintaining the current playlist.
     
Usage:

 In your items.mht, add the squeezebox devices like this:
 
   XPL_SQUEEZEBOX, xpl_device_id, object_name, SBs
 
 e.g. assuming the xpl name of your SB is 'slimdev-slimserv.kitchen'
 
   XPL_SQUEEZEBOX, kitchen, sb_kitchen, Squeezeboxes
   
 Then in your code do something like:
   
   $sb_kitchen->manage_heartbeat_timeout(360, "speak 'Squeezebox kitchen is offline'", 1); #noloop

   if ($state = state_now $sb_kitchen){
	 print_log "+++ State event on sb_kitchen, state is " . $state;
   }
   
 Turn on debug=xpl_squeezebox for diagnostic messages
 
Currently supports:
  * Turning the SB on/off (play/stop command)
  * Keeping track of the status of the SB when it is controlled by the remote/web interface

Todo:
  * Add code to control the amplifier based on the state of the SB
  * Add code to pause the current playlist, play a certain file, and resume so that we can use the 
     SB to notify incoming calls/doorbell/...
  * Support displaying messages on the SB screen
  * Request current player state at startup of MH so that we don't have to wait for the heartbeat

License:
  This free software is licensed under the terms of the GNU public license.

Authors:
  Lieven Hollevoet  lieven@lika.be

Credits:

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package xPL_Squeezebox;
use base qw(xPL_Item);

sub new {
    my ($class, $p_source) = @_;
    my $source = 'slimdev-slimserv.' . $p_source;
    my $self = $class->SUPER::new($source);
    $self->SUPER::class_name('audio.bas*');
    $$self{state_monitor} = "audio.basic : status";

	# Ensure we can turn the SB on and off
	$self->addStates ('on', 'off');
	
    return $self;
}


sub request_stat {
    my ($self) = @_;
    $self->SUPER::send_cmnd('audio.basic' => { 'command' => 'status' });
}

sub id {
    my ($self) = @_;
    return $$self{id};
}

sub addStates {
    my $self = shift;
    push(@{$$self{states}}, @_) unless $self->{displayonly};
}

sub ignore_message {
    my ($self, $p_data) = @_;
    my $ignore_msg = 0;
    if (!(defined($$p_data{'audio.basic'}))){
	$ignore_msg = 1;
    }
    return $ignore_msg;
}

sub default_setstate
{
    my ($self, $state, $substate, $set_by) = @_;
    if ($set_by =~ /^xpl/i) {
    	if ($$self{changed} =~ /audio\.basic/) {
           &::print_log("[xPL_Squeezebox] " . $self->get_object_name
                . " state is $state") if $main::Debug{xpl_squeezebox};
           # TO-DO: process all of the other pertinent attributes available
    	   return -1 if $self->state eq $state; # don't propagate state unless it has changed
	}
    } else {
    	my $cmnd = ($state =~ /^off/i) ? 'stop' : 'play';
    	
    	return -1 if ($self->state eq $state); # Don't propagate state unless it has changed.
        &::print_log("[xPL_Squeezebox] Request " . $self->get_object_name
		     . " turn " . $cmnd 
	    ) if $main::Debug{xpl_squeezebox};
        my $cmd_block;
        
    	$self->SUPER::send_cmnd('audio.slimserv' => {'command' => $cmnd});

    	return;
    }
	
}
    
1;
