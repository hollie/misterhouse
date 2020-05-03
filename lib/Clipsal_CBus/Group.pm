
=head1 B<Clipsal CBus Group>
 
=head2 SYNOPSIS
 
Group.pm - support for Clipsal CBus output groups.
 
=head2 DESCRIPTION
 
This module is a child of Clispal_CBus. It provides a MisterHouse object
that corresponds to a CBus output group, with a set() method that overides
that inherited from it's GenericItem parent.
 
Note that there is no provision for an output group to have a "relay" type
behaviour (i.e. states "on" and "off" only) as output groups can be mapped
to multiple CBus output unit channels, which may include dimmer and/or relay
channels.
 
=cut

package Clipsal_CBus::Group;

use strict;
use Clipsal_CBus;

#log levels
my $warn   = 1;
my $notice = 2;
my $info   = 3;
my $debug  = 4;
my $trace  = 5;

@Clipsal_CBus::Group::ISA = ( 'Generic_Item', 'Clipsal_CBus' );

=item C<new()>
 
 Instantiates a new CBus group object.
 
=cut

sub new {
    my ( $class, $address, $name, $label ) = @_;
    my $self = new Generic_Item();

    bless $self, $class;

    my $object_name   = "\$" . $name;
    my $object_name_v = $object_name . '_v';

    &::print_log("[Clipsal CBus] New group object $object_name at $address");

    $self->set_states( split ',', 'on,off,5%,10%,20%,30%,40%,50%,60%,70%,80%,90%' );
    $self->set_label($label);
    $$self{ramp_speed} = $::config_parms{cbus_ramp_speed};
    $$self{address}    = $address;

    #Add this object to the CBus object hash.
    $Clipsal_CBus::Groups{$address}{object_name} = $object_name;
    $Clipsal_CBus::Groups{$address}{name}        = $name;
    $Clipsal_CBus::Groups{$address}{label}       = $label;
    $Clipsal_CBus::Groups{$address}{note}        = "Added at object creation";

    return $self;
}

=item C<set(state, set_by, respond)>
 
 Places the value into the state field (e.g. set $light on) at the start of the next mh pass, and reflects that state
 to the CBus group via the CBus talker. 
 
 Depending on the source of the set() call, one or both of these actions may not be required. Scenarios are as follows:
 
 1) A CBus group is set to a new value by a CBus unit (e.g. a switch). This is seen by the CBus monitor, and the source
    of set_by is passed as "cbus". The CBus monitor calls set(), which reflects the new $state in the MH object.
 
 2) A MH object is set by the web interface or user code (or other MH function), by calling the objects set() method. 
    The set() method sets the MH object $state, and sends the corresponding CBus command to the CBus Talker socket.
 
 (optional) set_by overrides the default set_by value.
 
 (optional) respond overrides the default respond value.
 
=cut

sub set {
    my ( $self, $state, $set_by, $respond ) = &Generic_Item::_set_process(@_);
    &Generic_Item::set_states_for_next_pass( $self, $state, $set_by, $respond )
      if $self;

    my $orig_state = $state;
    my $cbus_label = $self->{label};
    my $address    = $$self{address};
    my $speed      = $$self{ramp_speed};

    $self->debug( "$cbus_label set to state $state by $set_by", $info );

    if ( $set_by =~ /cbus/ ) {

        # This was a Recursive set, we are ignoring
        $self->debug( "set() by CBus - no CBus update required", $debug );
        return;
    }

    if ( $set_by =~ /MisterHouseSync/ ) {

        # This was a Recursive set, we are ignoring
        $self->debug( "set() by MisterHouse sync - no CBus update required", $debug );
        return;
    }

    # Get rid of any % signs in the $Level value
    $state =~ s/%//g;

    if ( ( $state =~ /on/ ) || ( $state =~ /ON/ ) ) {
        $state = 255;

    }
    elsif ( ( $state eq /off/ ) || ( $state eq /OFF/ ) ) {
        $state = 0;

    }
    elsif ( ( $state <= 100 ) && ( $state >= 0 ) ) {
        $state = int( $state / 100.0 * 255.0 );

    }
    else {
        $self->debug( "invalid level \'$state\' passed to set()", $warn );
        return;
    }

    my $cmd_log_string = "RAMP $cbus_label set $state, speed=$speed";
    $self->debug( "$cmd_log_string", $debug );

    my $ramp_command = "[MisterHouse-$Clipsal_CBus::Command_Counter] RAMP $address $state $speed\n";
    $Clipsal_CBus::Talker->set($ramp_command);
    $Clipsal_CBus::Talker_last_sent = $ramp_command;
    $Clipsal_CBus::Command_Counter  = 0
      if ( ++$Clipsal_CBus::Command_Counter > $Clipsal_CBus::Command_Counter_Max );
}

=item C<get_voice_cmds>
 
 Returns a hash of voice commands where the key is the voice command name and the
 value is the perl code to run when the voice command name is called.
 
 Higher classes which inherit this object may add to this list of voice commands by
 redefining this routine while inheriting this routine using the SUPER function.
 
 This routine is called by L<Clipsal_CBus::generate_voice_commands> to generate the
 necessary voice commands.
 
=cut

sub get_voice_cmds {
    my ($self) = @_;
    my %voice_cmds = (

        'set on'  => $self->get_object_name . '->set( 100 , "Voice Command")',
        'set off' => $self->get_object_name . '->set( 0 , "Voice Command")'
    );

    return \%voice_cmds;
}

=head1 AUTHOR
 
 This code is based on the original cbus.pl implementation by:
 
 Richard Morgan, omegaATbigpondDOTnetDOTau
 Andrew McCallum, Mandoon Technologies, andyATmandoonDOTcomDOTau
 
 It was refactored to make it more MisterHouse "native" by:
 
 Jon Whitear, jonATwhitearDOTorg

=head1 LICENSE
 
 This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
 of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License along with this program; if not, write to the
 Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 
=cut

1;
