
=head1 B<xPL_Squeezebox>

=head2 DESCRIPTION

xPL_Squeezebox.pm - xPL support for the former SlimDevices (now Logitech) Squeezebox devices

This module allows to easily integrate Squeezebox devices in your MH setup by using the xPL
interface to the devices.

It supports device monitoring (check the heartbeat), keeps the state of the 
squeezebox (playing/stopped/power_off), and allows to play a file/URL.

Usage:

 In your items.mht, add the squeezebox devices like this:
 
   XPL_SQUEEZEBOX, xpl_device_id, object_name, SBs
 
 e.g. assuming the xpl name of your SB is 'slimdev-slimserv.kitchen'
 
   XPL_SQUEEZEBOX, kitchen, sb_kitchen, Squeezeboxes
   
 Then in your code do something like:
   
   $sb_status_req_timer = new Timer; # noloop
   set $sb_status_req_timer 10;      # noloop

   $sb_kitchen->manage_heartbeat_timeout(360, "speak 'Squeezebox kitchen is offline'", 1); #noloop

   if ($state = state_now $sb_kitchen){
	 print_log "+++ State event on sb_kitchen, state is " . $state;
   }
   
   if (expired $sb_status_req_timer) {
	set $sb_status_req_timer 60;
	xPL_Squeezebox::request_all_stat();
   }

Turn on debug=xpl_squeezebox for diagnostic messages

Currently supports:
  * Turning the SB on/off (play/stop command)
  * Keeping track of the status of the SB when it is controlled by the remote/web interface
  * Playing a file or an URL on a Squeezebox

=head2 METHODS

=over

=cut

use strict;

package xPL_Squeezebox;
use base qw(xPL_Item);

our @device_list;

=item C<new()>

Creates a new object

=cut

sub new {
    my ( $class, $p_source ) = @_;
    my $source = 'slimdev-slimserv.' . $p_source;
    my $self   = $class->SUPER::new($source);
    $self->SUPER::class_name('audio.basic');
    $$self{state_monitor} = "audio.basic : status";

    # Ensure we can turn the SB on and off
    $self->addStates( 'on', 'off' );

    # Save this object in the list of devices so that we can use the list in the request_all_stat function
    push @device_list, $self;

    &::print_log("[xPL_Squeezebox] Created device $source")
      if $main::Debug{xpl_squeezebox};

    return $self;
}

=item C<request_all_stat()>

Requests the state of all squeezebox devices

We need to do this through this rather elaborate code that keeps a list of all objects 
that have been created and that goes over this list one by one.
This is because SqueezeCenter currently does not respond to an audio.request that is directed to
slimdev-slimserv.*
If it would we could here simply use 
&xPL::sendXpl('slimdev-slimserv.*', 'cmnd', 'audio.request' => { 'cmd' => 'status' });

=cut

sub request_all_stat {
    foreach (@device_list) {
        $_->request_stat();
    }
}

=item C<request_stat()>

Request the status of a single Squeezebox

=cut

sub request_stat {
    my ($self) = @_;
    $self->SUPER::send_cmnd( 'audio.request' => { 'cmd' => 'status' } );
}

=item C<id()>

Returns the ID of the Squeezebox

=cut

sub id {
    my ($self) = @_;
    return $$self{id};
}

=item C<addStates()>

Add states to the device

=cut

sub addStates {
    my $self = shift;
    push( @{ $$self{states} }, @_ ) unless $self->{displayonly};
}

=item C<ignore_message()>

Determine what xPL messages will be interpreted

=cut

sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_msg = 0;
    if ( !( defined( $$p_data{'audio.basic'} ) ) ) {
        $ignore_msg = 1;
    }
    return $ignore_msg;
}

=item C<default_setstate()>

Handle state changes of the Squeezeboxes

=cut

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    if ( $set_by =~ /^xpl/i ) {
        if ( $$self{changed} =~ /audio\.basic/ ) {
            &::print_log( "[xPL_Squeezebox] "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{xpl_squeezebox};

            # TO-DO: process all of the other pertinent attributes available
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
    }
    else {
        my $cmnd = ( $state =~ /^off/i ) ? 'stop' : 'play';

        return -1
          if ( $self->state eq $state )
          ;              # Don't propagate state unless it has changed.
        &::print_log( "[xPL_Squeezebox] Request "
              . $self->get_object_name
              . " turn "
              . $cmnd )
          if $main::Debug{xpl_squeezebox};

        if ( $cmnd eq 'stop' ) {
            $self->SUPER::send_cmnd(
                'audio.slimserv' => { 'extended' => 'power 0' } );
        }
        else {
            $self->SUPER::send_cmnd(
                'audio.slimserv' => { 'command' => $cmnd } );
        }

        return;
    }

}

=item C<play(file/URL)>

Accepts a file (a full paths on the machine that is running the Squeezebox server 
application) or an URL that should be played on the device.

=cut

sub play {
    my ( $self, $file, $source ) = @_;

    $self->SUPER::send_cmnd( 'audio.slimserv' => { 'command' => $file } );

    return;
}

=back 

=head2 LICENSE

This free software is licensed under the terms of the GNU public license.

=head2 AUTHOR

Lieven Hollevoet  lieven@lika.be

=head2 CREDITS
  Gregg Liming for the idea that we should not rely on the heartbeat messages to get the 
     status of the Squeezebox.

=cut

1;
