
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Tivo_Control.pm

Description:

Author:
	Kirk Bauer
	kirk@kaybee.org

License:
	This free software is licensed under the terms of the GNU public license.

Usage:
   This module is included from Misterhouse.  Just place it in your user code
   directory (code_dir in your config file).  You must then add the following
   configuration items to your mh.ini:
      tivocontrol_module=Tivo_Control
      tivocontrol_host=10.1.1.100
      tivocontrol_port=8762

   This requires that you have a hacked Tivo with a network card and the Tivo
   Control Station installed and operating (http://www.zirakzigil.net/tivo/TCS.html).
   You also must have my TCS module installed for the clearing of the screen.
   It is called ClearScreen.tcl and needs to be placed in your TCS modules directory
   on your Tivo (usually /var/hack/tcs/modules).  You can download this file
   from: ftp://ftp.kaybee.org/pub/linux/ClearScreen.tcl.

   Currently all this module does is display text to the screen through TCS.
   There could be other uses in the future.

   display('text'): Displays the text to the Tivo, breaking it up into chunks
   of less than 40 characters, and with a delay between each line of text.

   delay([delay]): Gets or sets the current delay between lines.  The default
   delay is defined below ($default_delay).

   clear_screen(): Clears any displayed text off of the Tivo screen.

   Here is how I use this to show spoken text:

      my $tivo = new Tivo_Control;
      sub pre_speak_hook {
         my ($parms) = @_;
         $tivo->display($parms->{'text'});
      }
      if ($Reload) {
         &Speak_parms_add_hook(\&pre_speak_hook);
      }

Special Thanks to:
	Bruce Winter - Misterhouse

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Tivo_Control;

@Tivo_Control::ISA = ('Generic_Item');

my $tivo_socket   = undef;
my $default_delay = 4;

sub new {
    my ( $class, $port_name ) = @_;
    my $self = {};
    bless $self, $class;
    $$self{'m_clrTimer'} = new Timer;
    $$self{'delay'}      = $default_delay;
    @{ $$self{'queue'} } = ();
    return $self;
}

sub _send_cmd {
    my ( $self, $cmd ) = @_;
    if ( not active $tivo_socket) {
        &::print_log("Attempting to reconnect to the Tivo...");
        start $tivo_socket;
    }
    if ( active $tivo_socket) {
        set $tivo_socket $cmd;
    }
    else {
        &::print_log("Not connected to Tivo, command '$cmd' lost.");
    }
}

sub startup {
    if (    not $tivo_socket
        and $main::config_parms{tivocontrol_host}
        and $main::config_parms{tivocontrol_port} )
    {
        my $port =
          "$main::config_parms{tivocontrol_host}:$main::config_parms{tivocontrol_port}";
        $tivo_socket =
          new Socket_Item( undef, undef, $port, 'tivocontrol', 'tcp',
            'record' );
        start $tivo_socket;
    }
}

sub delay {
    my ( $self, $delay ) = @_;
    $$self{'delay'} = $delay if defined $delay;
    return $$self{'delay'};
}

sub clear_screen {
    my ($self) = @_;
    $self->_send_cmd("CLRS");
}

sub _display_next_msg {
    my ( $self, $drop ) = @_;
    if ( @{ $$self{'queue'} } ) {

        # Drop the last message from the queue
        if ($drop) {
            shift @{ $$self{'queue'} };
        }
        if ( @{ $$self{'queue'} } ) {
            &::print_log("Tivo: displaying text '$$self{'queue'}->[0]'");
            $self->_send_cmd("DISP $$self{'queue'}->[0]");
            $$self{'m_clrTimer'}->set( $$self{'delay'}, $self );

            #&::print_log("Tivo: Setting timer for $$self{'delay'} seconds");
            return 1;
        }
    }
    return 0;
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;
    if (    defined $p_setby
        and ( $p_setby eq $$self{m_clrTimer} )
        and ( $p_state eq 'off' ) )
    {
        #&::print_log("Tivo: timer has expired");
        unless ( $self->_display_next_msg(1) ) {
            $self->clear_screen();
        }
    }
}

sub display {
    my ( $self, $text ) = @_;
    my @lines;
    my $displaynow = 1;
    if ( @{ $$self{'queue'} } ) {
        $displaynow = 0;
    }

    # Make sure there are no dollar-signs in the next (messes up TCS)
    $text =~ s/\$//g;
    while ($text) {

        #&::print_log("Tivo: breaking down text '$text'");
        if ( length($text) <= 40 ) {
            push @lines, $text;
            $text = '';
        }
        elsif ( $text =~ s/^(.{1,40})\s// ) {
            push @lines, $1;
        }
        else {
            $text =~ s/^(.{40})//;
            push @lines, $1;
        }
    }
    if (@lines) {
        push @{ $$self{'queue'} }, @lines;
    }
    if ($displaynow) {
        $self->_display_next_msg();
    }
}

1;
