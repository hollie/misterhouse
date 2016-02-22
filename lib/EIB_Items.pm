
=head1 B<EIB_Item>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

EIB (European Installation Bus) items.

EIB/KNX website:  http://konnex.org

The following EIB types are supported: (MH Klassname, DPT Type, EIS Type, Description)

    EIB1:    DPT  1.001, EIS 1,      Switches
    EIB2:    NA,         EIS 2,      Dimmers
    EIB3:    DPT 10.000, EIS 3,      Time
    EIB4:    DPT 11.000, EIS 4,      Date
    EIB5:    DPT  9.000, EIS 5,      Values (weather stations etc)
    EIB6:    DPT  5.001, EIS 6,      Scaling (0 - 100%)
    EIB7:    NA,         EIS 7,      Motor drives
    EIB8:    DPT  2.001, EIS 8,      forced control 2 bit
    EIB9:    DPT 14.00x, EIS 9,      32-bit float
    EIB10:   DPT  7.001, EIS 10,     16-bit unsigned integer
    EIB10_1: DPT  8.001, EIS 10.001, 16-bit   signed integer
    EIB11:   DPT 12.001, EIS 11,     32-bit unsigned integer
    EIB11_1: DPT 13.001, EIS 11.001, 32-bit   signed integer
    EIB14:   DPT  6.001, EIS 14,      8-bit   signed integer
    EIB14_1: DPT  5.010, EIS 14.1;    8-bit unsigned integer
    EIB15:   DPT 16.000, EIS 15,     14 byte text messages

    EIBW:    NA,         NA,         summary object for 2 EIS1 Objects
                                     to define the state of a window
                                     (closed, tilt, open)

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;

package EIB_Item;
@EIB_Item::ISA = ('Generic_Item');

my %eib_items_by_id;

sub reset {
    undef %eib_items_by_id;    # Reset on code re-load
}

=item C<eib_items_by_id>

Lookup EIB_Item with the given address

=cut

sub eib_items_by_id {
    my ($id) = @_;
    &main::print_log("eib_items_by_id: asking for \'$id\'")
      if $main::config_parms{eib_errata} >= 8;
    return unless defined $eib_items_by_id{$id};
    return @{ $eib_items_by_id{$id} };
}

=item C<new>

Generic EIB_Item class. This class is not instantiated directly. It is used to inherit common EIB properties

=cut

sub new {
    my ( $class, $idstr, $mode ) = @_;
    my $self = $class->SUPER::new();

    bless $self, $class;

    if ( $idstr =~ /\|/ ) {
        &main::print_log(
            "EIB_Item: '$idstr' is a combined address vector. Ignore it")
          if $main::config_parms{eib_errata} >= 3;
    }
    else {
        my @ids = split /\+/, $idstr;
        &main::print_log("EIB_Item: '$idstr' is splitted into '@ids'")
          if $main::config_parms{eib_errata} >= 3;
        $self->{groupaddr} = $ids[0];
        map { $self->addEIBAddress($_) } @ids;
    }

    $self->{readable}    = 0;
    $self->{displayonly} = 0;
    map {
        if ( $_ eq "R" || $_ eq "r" ) {
            $self->{readable} = 1;
        }
        elsif ( $_ eq "DO" || $_ eq "do" ) {
            $self->{displayonly} = 1;
        }
        elsif ( $_ =~ /^label=(.*)$/ ) {
            $self->set_label($1);
        }
        elsif ( $_ =~ /^icon=(.*)$/ ) {
            $self->set_icon($1);
        }
    } split( /\|/, $mode ) if ( defined $mode );
    if ( $self->{readable} && defined $self->{groupaddr} ) {

        # trigger future EIB read command
        $self->read_request();
    }
    return $self;
}

sub addStates {
    my $self = shift;
    push( @{ $$self{states} }, @_ ) unless $self->{displayonly};
}

sub addEIBAddress {
    my ( $self, $addr ) = @_;
    &main::print_log("addEIBAddress: registering $addr for $self")
      if $main::config_parms{eib_errata} >= 3;
    push( @{ $eib_items_by_id{$addr} }, $self );
}

=item C<printname>

Item name to appear in logs etc

=cut

sub printname {
    my ($name) = @_;

    if ( $name =~ /\d+\/\d+\/\d+/ ) {
        my @eib_items = EIB_Item::eib_items_by_id($name);
        if (@eib_items) {
            $name = "";
            map {
                my $eib_item = $_;
                $name = $name . $eib_item->{object_name} . " "
                  if ( defined $eib_item && defined $eib_item->{object_name} );
            } @eib_items;
        }
    }
    return $name;
}

=item C<set_receive>

detected an EIB event on the bus.  Update item state to reflect the value in the event

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target ) = @_;

    &main::print_log("EIB_Item::set_receive: state '$state' for $self")
      if $main::config_parms{eib_errata} >= 3;
    return if &main::check_for_tied_filters( $self, $state, $set_by );

    # Set target to symbolic item name, if possible
    $target = $self->{groupaddr} unless ( defined $target );
    $target = &printname($target);
    &Generic_Item::set_states_for_next_pass( $self, $state, $set_by, $target );
}

sub set {
    my ( $self, $state, $set_by, $target ) = @_;

    &main::print_log("EIB_Item::set: state '$state' for '$self->{object_name}'")
      if $main::config_parms{eib_errata} >= 3;

    return 0 if &main::check_for_tied_filters( $self, $state, $set_by );

    if ( $state eq 'toggle' ) {
        if ( $$self{state} eq 'on' ) {
            $state = 'off';
        }
        elsif ( $$self{state} eq 'off' ) {
            $state = 'on';
        }
        else {
            &main::print_log(
                "Can't toggle EIB_Item object $self->{object_name} in state $$self{state}"
            );
            return 0;
        }
        &main::print_log(
            "Toggling EIB_Item object $self->{object_name} from $$self{state} to $state"
        );
    }

    $target = $self->{groupaddr} unless ( defined $target );
    $target = &printname($target);

    # Find all items which receives the groupaddr and notify them (including myself)
    my @eib_items = EIB_Item::eib_items_by_id( $self->{groupaddr} );
    if (@eib_items) {
        map { $_->set_receive( $state, $set_by, $target ); } @eib_items;
    }

    return 1 if $main::Save{mode} eq 'offline';

    # If encode method exists, generate and send EIB message
    my $data = $self->encode($state) if $self->can("encode");
    $self->send_write_msg($data) if ( defined $data );

    return 1;
}

sub readable {
    my ($self) = @_;

    return ( defined $self->{readable} );
}

=item C<send_write_msg>

generate EIB message to set a value

=cut

sub send_write_msg {
    my ( $self, $data ) = @_;
    my $msg;

    $msg->{'type'} = 'write';
    $msg->{'dst'}  = $self->{groupaddr};
    $msg->{'data'} = $data;
    EIB_Device::send_msg($msg);
}

=item C<send_read_msg>

generate EIB message to read a value

=cut

sub send_read_msg {
    my ( $self, $data ) = @_;
    my $msg;

    &main::print_log(
        "EIB_Item::send_read_msg: Send read message to $self->{groupaddr}")
      if $main::config_parms{eib_errata} >= 3;

    $msg->{'type'} = 'read';
    $msg->{'dst'}  = $self->{groupaddr};
    $msg->{'data'} = [0];
    EIB_Device::send_msg($msg);
}

=item C<receive_write_msg>

process a message to set a value

=cut

sub receive_write_msg {
    my ( $self, $state, $set_by, $target ) = @_;

    &main::print_log(
        "EIB_Item::receive_write_msg: new state $state set on $self")
      if $main::config_parms{eib_errata} >= 3;
    $self->set_receive( $state, $set_by, $target );
}

=item C<receive_reply_msg>

process a message with a reply value (read response)

=cut

sub receive_reply_msg {
    my ( $self, $state, $set_by, $target ) = @_;
    my $t;

    $self->stop_read_timer();
    $self->{read_attempts} = undef;
    $self->set_receive( $state, $set_by, $target, 1 );
}

=item C<receive_msg>

entry point from device interface. Analyse message and call appropriate receive_*_msg handler

=cut

sub receive_msg {
    my ($msg) = @_;

    my $addr      = $msg->{'dst'};
    my $op        = $msg->{'type'};
    my @data      = @{ $msg->{'data'} };
    my @eib_items = EIB_Item::eib_items_by_id($addr);
    if (@eib_items) {
        map {
            my $eib_item = $_;
            if ( defined $eib_item->can("decode") ) {
                my $state = decode $eib_item @data if ( $op ne 'read' );

                &main::print_log(
                    "EIB $op from $msg->{'src'} to $msg->{'dst'}",
                    $op eq 'read'    ? ""
                    : defined $state ? ": \"$state\""
                    :                  ": \"[@data]\""
                ) if $main::config_parms{eib_errata} >= 3;
                if ( $op eq 'write' ) {
                    $eib_item->receive_write_msg( $state, $msg->{'src'},
                        $msg->{'dst'} );
                }
                elsif ( $op eq 'reply' ) {
                    $eib_item->receive_reply_msg( $state, $msg->{'src'},
                        $msg->{'dst'} );
                }
            }
        } @eib_items;
    }
    else {
        &main::print_log( "EIB $op from $msg->{'src'} to $msg->{'dst'}",
            ". Item not found." )
          if $main::config_parms{eib_errata} >= 2;
    }
}

=item C<start_read_timer>

set a timeout for waiting for read response

=cut

sub start_read_timer {
    my ( $self, $interval ) = @_;

    $interval = 0 + $::config_parms{eib_read_retry_interval}
      unless defined $interval;
    $self->{get_timer} = new Timer;
    $self->{get_timer}
      ->set( $interval, sub { EIB_Item::read_timeout($self); }, 1 );
    $self->{get_timer}->start();
}

=item C<stop_read_timer>

disable timer

=cut

sub stop_read_timer {
    my ($self) = @_;

    return unless defined $self->{get_timer};
    $self->{get_timer}->unset();
    $self->{get_timer} = undef;
}

=item C<read_timeout>

No reply to read request. Retry or give up.

=cut

sub read_timeout {
    my ($self) = @_;

    stop_read_timer($self);
    $self->{read_timeouts}++;
    if ( $self->{read_timeouts} > $::config_parms{eib_max_read_attempts} ) {
        &main::print_log( "EIB read failure for group ", $self->{groupaddr} );
    }
    else {
        $self->send_read_msg();
        start_read_timer($self);
    }
}

=item C<read_request>

send a read request, and start timer

=cut

sub read_request {
    my ($self) = @_;

    $self->send_read_msg();
    $self->{read_timeouts} = 0;
    $self->start_read_timer();
}

=item C<delayed_read_request> 

wait a while and then send a read request. If a read request is sent too soon, the EIB actuator may not have obtained a stable value, so we want to delay before sending the request.

=cut

sub delayed_read_request {
    my ( $self, $interval ) = @_;

    $interval = 2 unless defined $interval;
    $self->{read_timeouts} = -1;    # ugly...
    $self->start_read_timer($interval);
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

09/09/2005  Created by Peter Sjödin peter@sjodin.net
06/01/2009  Enhanced by Ralf Klueber r(at)lf-klueber.de
08/01/2009  Listening addresses by Mike Pieper mptei@sourceforge.net

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.



=head1 B<EIB Sub-Items>

=head2 INHERITS

B<EIB_Item>

=head2 EIB1_Item

=over

=cut

package EIB1_Item;

@EIB1_Item::ISA = ('EIB_Item');

sub new {
    my ( $class, $idstr, $mode ) = @_;
    my $self = $class->SUPER::new( $idstr, $mode );

    $self->addStates( 'on', 'off' );

    return $self;
}

sub eis_type {
    return '1';
}

=item C<decode>

translate EIS 1 data to state (on/off)

=cut

sub decode {
    my ( $self, @data ) = @_;
    unless ( $#data == 0 ) {
        &main::print_log(
            "Not EIS type 1 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    if ( $data[0] == 0 ) {
        return 'off';
    }
    else {
        return 'on';
    }
}

=item C<encode>

translate state to EIS 1 data

=cut

sub encode {
    my ( $self, $state ) = @_;
    &main::print_log("EIS1::encode: state '$state' for '$self->{object_name}'")
      if $main::config_parms{eib_errata} >= 3;

    if ( $state eq 'on' ) {
        return ( [1] );
    }
    elsif ( $state eq 'off' ) {
        return ( [0] );
    }
    else {
        print "Invalid state for EIS type 1: \'$state\'\n";
        return;
    }
}

=back

=head2 EIG1G_Item

A group of EIB1 items. Setting the value of an  EIB1 group will affect all members in the group.  The class is used to keep track of EIB1 group memberships. If a write message is detected, all members will be updated.

=cut

package EIB1G_Item;

@EIB1G_Item::ISA = ('EIB1_Item');

sub new {
    my ( $class, $id, $groupstr ) = @_;
    my @groups = split /\|/, $groupstr;

    my $self = $class->SUPER::new($id);
    $self->{'linked_groups'} = \@groups;
    return $self;
}

sub eis_type {
    return '1';
}

sub set_receive {
    my ( $self, $state, $set_by, $target ) = @_;

    $self->SUPER::set_receive( $state, $set_by, $target );
    map {
        my @eib_items = EIB_Item::eib_items_by_id($_);
        if (@eib_items) {
            map { $_->set_receive( $state, $set_by, $target ); } @eib_items;
        }
    } @{ $self->{'linked_groups'} };
}

=head2 DIB2_Item

 EIS 2: Dimming
  EIB dimmers can be controlled in three different ways:
  1. "control": brighten, dim, stop. Handled by class EIB21_Item
  2. "value": numerical value: Handled by class EIB6_Item
  3. "position": on, off. Handled by class EIB1_Item

  Class EIB2_Item is a meta-item to represent dimmers, consist of the three underlying item.
  The main purpose is to make a dimmer appear as a single item, while the real work is done
  by the three underlying items.

  The identifier for the EIB2_Item is composed of the concatenation of the addresses of
  the three underlying items, with '|' between them. For example, '1/0/90|1/0/91|1/4/1' is a dimmer
  with control address 1/0/90, value address 1/0/91, and position address 1/4/1.

=over

=cut

package EIB2_Item;

@EIB2_Item::ISA = ('EIB_Item');

=item C<new>

create an EIB2_Item. Instantiate the three underlying items.

=cut

sub new {
    my ( $class, $id, $mode ) = @_;
    my @groups;
    my ( $subid, $item );

    my $self = $class->SUPER::new( $id, $mode );

    @groups = split( /\|/, $id );
    print "Three group addresses required for dimmer. Found $#groups in $id\n"
      if ( $#groups != 2 );

    $subid            = $groups[0];
    $item             = new EIB23_Item( $subid, "R", $self );
    $self->{Position} = $item;

    $subid           = $groups[1];
    $item            = new EIB21_Item( $subid, "", $self );
    $self->{Control} = $item;

    $subid         = $groups[2];
    $item          = new EIB22_Item( $subid, "R", $self );
    $self->{Value} = $item;

    if ( $main::config_parms{eib2_menu_states} ) {
        $self->addStates( split ',', $main::config_parms{eib2_menu_states} );
    }
    else {
        $self->addStates(
            'on',  'off', 'brighten', 'dim', 'stop', '5%',
            '30%', '60%', '100%'
        );
    }
    return $self;
}

sub eis_type {
    return '2';
}

=item C<position>

return "position" sub-item

=cut

sub position {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Position};
    return $self->{Position};
}

=item C<control>

return "control" sub-item

=cut

sub control {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Control};
    return $self->{Control};
}

=item C<value>

return "value" sub-item

=cut

sub value {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Value};
    return $self->{Value};
}

=item C<set>

Set EIB2 item.  Parse state to determine the corresponding sub-item to call.

=cut

sub set {
    my ( $self, $state, $set_by, $target ) = @_;
    my $subitem;

    if (   $state eq 'toggle'
        || $state eq 'on'
        || $state eq 'off' )
    {
        $subitem = $self->position();
    }
    elsif ( $state =~ /^(stop|brighten|dim)$/ ) {
        $subitem = $self->control();
    }
    elsif ($state =~ /^\d+$/
        || $state =~ /^(\+|\-)\d+$/
        || $state =~ /^\d+\%$/ )
    {
        $subitem = $self->value();
    }
    else {
        &main::print_log(
            " $self->{object_name}: Bad EIB dimmer state \'$state\'\n");
    }

    $subitem->set( $state, $set_by, $target ) if ( defined $subitem );
    return 1;
}

=item C<set_receive>

received an event from one of the sub_items. If it was a numerical value ("Value"), update the "Position" subitem to 'on' or 'off'.  If the value was zero, also set self to 'off'. Update level (0-100) to represent dimmer position

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target ) = @_;
    my $onoff;

    &main::print_log("EIB2_Item::set_receive: new state $state")
      if $main::config_parms{eib_errata} >= 3;

    my $newstate = $state;    # set SUPER state after all sub settings

    if ( $state =~ /(\d+)/ ) {
        $self->{level} = $1;
        $newstate = $1 . "%";
        if ( $1 eq '0' ) {
            $onoff    = 'off';
            $newstate = 'off';
        }
        else {
            $onoff = 'on';
            if ( $1 eq '100' ) {
                $newstate = 'on';
            }
        }
        my $pos = $self->position();
        if ( defined $pos && $pos->state_final() ne $onoff ) {
            $pos->set_receive( $onoff, $set_by, $target );
        }
    }
    elsif ( $state eq 'on' || $state eq 'off' ) {
        if ( $state eq 'off' ) {
            $self->{level} = 0;
            my $val = $self->value();
            if ( defined $val && $val->state_final() != 0 ) {
                $val->set_receive( 0, $set_by, $target );
            }
        }
        if ( $state eq 'on' ) {
            my $val = $self->value();
            delayed_read_request $val if ( defined $val && $val->{readable} );
        }
    }
    $self->SUPER::set_receive( $newstate, $set_by, $target );
}

=item C<state_level>

return 'on', 'off' or 'dim', depending on current setting (as obtained from "value" sub-item)

=cut

sub state_level {
    my ($self) = @_;

    my $state = $self->{state};
    my $level = $self->value()->{state};
    if ( !defined $state or !( $state eq 'on' or $state eq 'off' ) ) {
        if ( defined $level and $level =~ /^[\+\-\d\%]+$/ ) {
            $state = 'dim';
            $state = 'off' if $level == 0;
            $state = 'on' if $level == 100;
        }
        elsif ($state =~ /^[\+\-\d\%]+$/
            or $state eq 'dim'
            or $state eq 'brighten' )
        {
            $state = 'dim';
        }
        else {
            $state = '';    # unknown
        }
    }
    elsif ( $state eq 'on' and defined $level and $level < 100 ) {
        $state = 'dim';
    }
    return $state;
}

=back

=head2 EIB2_Subitem

A generic class for the three dimming sub-functions

=over

=cut

package EIB2_Subitem;

@EIB2_Subitem::ISA = ('EIB_Item');

sub new {
    my ( $class, $id, $mode, $dimmer ) = @_;
    my @args;

    my $self = $class->SUPER::new( $id, $mode );
    $self->{'Dimmer'} = $dimmer;
    return $self;
}

=item C<dimmer>

return "dimmer" meta-item

=cut

sub dimmer {
    my ($self) = @_;

    return unless defined $self->{Dimmer};
    return $self->{Dimmer};
}

=item C<set_receive>

forward to meta-item

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target ) = @_;

    &main::print_log("EIB2_Subitem::set_receive: new state $state")
      if $main::config_parms{eib_errata} >= 3;

    $self->SUPER::set_receive( $state, $set_by, $target );
    my $dimmer = dimmer $self;
    if ( defined $dimmer ) {
        $dimmer->set_receive( $state, $set_by, $target );
    }
    else {
        &main::print_log(
            "No dimmer defined for dimmer subitem $self->{groupaddr}");
    }
}

=back

=head2 EIB21_Item

Dimming sub-function "control"

=over

=cut

package EIB21_Item;

@EIB21_Item::ISA = ('EIB2_Subitem');

sub eis_type {
    return '2.1';
}

=item C<dimmer_timeout>

dimmer should have reached stable state. Issue a read request to obtain current value

=cut

sub dimmer_timeout {
    my ($self) = @_;
    my $value;

    $value = $self->dimmer()->value();
    $value->send_read_msg();
}

=item C<set>

To allow adjusting dimmer value in real-time from for example web interface: If state is set to same dim/brighten value twice before dimmer timer has expired, it means "stop".  For example, first 'dim' means start dimming, second means stop dimming (This behaviour is configurable via configuration parameter "eib_dim_stop_on_repeat")

=cut

sub set {
    my ( $self, $state, $set_by, $target ) = @_;
    my $subitem;

    if ( $::config_parms{eib_dim_stop_on_repeat}
        && defined $self->{dimmer_timer} )
    {
        if (   ( $state eq 'brighten' && $self->{state} eq 'brighten' )
            || ( $state eq 'dim' && $self->{state} eq 'dim' ) )
        {
            $state = 'stop';
        }
    }
    return $self->SUPER::set( $state, $set_by, $target );
}

sub decode {
    my ( $self, @data ) = @_;
    unless ( $#data == 0 ) {
        &main::print_log(
            "Not EIS type 21 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    if ( ( $data[0] & 0x7 ) == 0 ) {
        return 'stop';
    }
    elsif ( ( $data[0] & 0x8 ) == 0 ) {
        return 'dim';
    }
    else {
        return 'brighten';
    }
}

sub encode {
    my ( $self, $state ) = @_;

    &main::print_log("EIS21::encode: state '$state' for '$self->{object_name}'")
      if $main::config_parms{eib_errata} >= 3;
    if ( $state eq 'stop' ) {
        return ( [0] );
    }
    elsif ( $state eq 'dim' ) {
        return ( [1] );
    }
    elsif ( $state eq 'brighten' ) {
        return ( [9] );
    }
    else {
        print "Invalid state for EIS type 2.1: \'$state\'\n";
        return;
    }
}

=item C<set_receive>

if it is a 'stop' event, generate a read request for the 'Value' sub-item, to learn the actual dimmer setting

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target ) = @_;
    my ( $dimmer, $value );

    $self->SUPER::set_receive( $state, $set_by, $target );
    if ( $state eq 'stop' ) {
        $dimmer = dimmer $self;
        $value = value $dimmer if ( defined $dimmer );
        if ( defined $value ) {
            delayed_read_request $value;
        }
        else {
            &main::print_log(
                "No dimmer value subitem for dimmer control $self->{groupaddr}"
            );
        }
        $self->{dimmer_timer}->unset() if defined $self->{dimmer_timer};
    }
    elsif ( $state eq 'dim' || $state eq 'brighten' ) {

        # let some time pass and then issue a read request, to find out the final dimmer level.
        # The time is configurable via configuration parameter "eib_dimmmer_time".

        $self->{dimmer_timer} = new Timer unless defined $self->{dimmer_timer};
        if ( $self->{dimmer_timer}->inactive() ) {
            my $interval = 0 + $::config_parms{eib_dimmer_timer};
            $self->{dimmer_timer}
              ->set( $interval, sub { EIB21_Item::dimmer_timeout($self); }, 1 );
        }
    }
}

=back

=head2 EIB22_Item

Dimming sub-function "value". Set dimmer to a given brightness level
(0-100) with 8 bit resolution
Values are coded according to EIS 6

=over

=cut

package EIB22_Item;

# Multiple inheritance -- use encode/decode methods from EIB6_Item,
# the rest from EIB2_Subitem
@EIB22_Item::ISA = ( 'EIB2_Subitem', 'EIB6_Item' );    # order is important!

sub eis_type {
    return '2.2';
}

=item C<set_receive>

detected a "read" or "write" message on the bus.  For readable actuators, don't trust the values in "write" messages, as they may not have been accepted by the actuator. So if it is a write, and the actuator is readable, generate a read request to obtain the actual value from the actuator

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target, $read ) = @_;

    if ( !$read && $self->{readable} ) {
        &main::print_log(
            "EIB22_Item::set_receive: read_request for $self->{groupaddr}")
          if $main::config_parms{eib_errata} >= 3;
        $self->delayed_read_request();
    }
    else {
        $self->SUPER::set_receive( $state, $set_by, $target );
    }
}

=back

=head2 EIB23_Item

Dimming sub-function "position". Set dimmer to on/off.  Values are coded according to EIS 1

=cut

package EIB23_Item;

# Multiple inheritance -- use encode/decode methods from EIB1_Item, and the rest from
# EIB2_Subitem
@EIB23_Item::ISA = ( 'EIB2_Subitem', 'EIB1_Item' );    # order is important!

sub eis_type {
    return '2.3';
}

=head2 EIB3_Item

Uhrzeit

=cut

package EIB3_Item;

@EIB3_Item::ISA = ('EIB_Item');

my @DoW = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

sub eis_type {
    return '3';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 3 ) {
        &main::print_log(
            "Not EIS type 3 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 3;
        return;
    }
    my $weekday = ( $data[1] & 0xE0 ) >> 5;
    my $hour    = $data[1] & 0x1F;
    my $minute  = $data[2] & 0xFF;
    my $second  = $data[3] & 0xFF;

    $res =
      sprintf( "%s, %02i:%02i:%02i", $DoW[$weekday], $hour, $minute, $second );
    &main::print_log("EIS3 for $self->{groupaddr}: >$res<")
      if $main::config_parms{eib_errata} >= 3;
    return $res;
}

sub encode {
    my ( $self, $state ) = @_;
    my $time = &main::my_str2time($state);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = localtime($time);
    my $res1 = sprintf( "%s, %02i:%02i:%02i", $DoW[$wday], $hour, $min, $sec );
    my @res = (0);

    if ( $wday == 0 ) { $wday = 7; }

    push( @res, $wday << 5 | $hour );
    push( @res, $min );
    push( @res, $sec );

    my $res = '[' . join( " ", @res ) . ']';

    &main::print_log("EIS3 for $self->{groupaddr}: >$res< >$res1<")
      if $main::config_parms{eib_errata} >= 3;
    return \@res;

}

=head2 EIB4_Item

Uhrzeit

=cut

package EIB4_Item;

@EIB4_Item::ISA = ('EIB_Item');

my @DoW = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

sub eis_type {
    return '3';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 3 ) {
        &main::print_log(
            "Not EIS type 4 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 3;
        return;
    }
    my $mday = $data[1] & 0x1F;
    my $mon  = $data[2] & 0x0F;
    my $year = $data[3] & 0x7F;

    $res = sprintf( "%02i/%02i/%02i", $mon, $mday, ( $year + 2000 ) % 100 );
    &main::print_log("EIS4 for $self->{groupaddr}: >$res<")
      if $main::config_parms{eib_errata} >= 2;
    return $res;
}

sub encode {
    my ( $self, $state ) = @_;
    my $time = &main::my_str2time($state);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = localtime($time);
    my $res1 = sprintf( "%02i/%02i/%02i", $mon + 1, $mday, $year % 100 );
    my @res = (0);

    push( @res, $mday );
    push( @res, $mon + 1 );
    push( @res, $year - 100 );

    my $res = '[' . join( " ", @res ) . ']';

    &main::print_log("EIS4 for $self->{groupaddr}: >$res< >$res1<")
      if $main::config_parms{eib_errata} >= 3;
    return \@res;

}

=head2 EIB5_Item

=cut

# EIS 5: Value
# Represents real values
package EIB5_Item;

@EIB5_Item::ISA = ('EIB_Item');

sub eis_type {
    return '5';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 2 ) {
        &main::print_log(
            "Not EIS type 5 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $sign = $data[1] & 0x80;
    my $exp  = ( $data[1] & 0x78 ) >> 3;
    my $mant = ( ( $data[1] & 0x7 ) << 8 ) | $data[2];

    $mant = -( ~( $mant - 1 ) & 0x7ff ) if $sign != 0;
    $res = ( 1 << $exp ) * 0.01 * $mant;
    return $res;
}

sub encode {
    my ( $self, $state ) = @_;
    my $data;

    &main::print_log("EIS5::encode: state '$state' for '$self->{object_name}'")
      if $main::config_parms{eib_errata} >= 3;
    my $sign = ( $state < 0 ? 0x8000 : 0 );
    my $exp  = 0;
    my $mant = 0;

    $mant = int( $state * 100.0 );
    while ( abs($mant) > 2047 ) {
        $mant = $mant >> 1;
        $exp++;
    }

    $data = $sign | ( $exp << 11 ) | ( $mant & 0x07ff );

    return ( [ 0, $data >> 8, $data & 0xff ] );
}

=head2 EIB6_Item

"scaling". Relative values 0-100% with 8 bit resolution

=over

=cut

package EIB6_Item;

@EIB6_Item::ISA = ('EIB_Item');

sub eis_type {
    return '6';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 1 ) {
        &main::print_log(
            "Not EIS type 6 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    $res = sprintf( "%.0f", $data[1] * 100 / 255 );
    return $res;
}

sub encode {
    my ( $self, $state ) = @_;
    &main::print_log("EIS6::encode: state '$state' for '$self->{object_name}'")
      if $main::config_parms{eib_errata} >= 3;
    my $newval;
    if ( $state =~ /^(\d+)$/ ) {
        $newval = $1;
    }
    elsif ( $state =~ /^\+(\d+)$/ ) {
        $newval = $self->{state} + $1;
        $newval = 100 if ( $newval > 100 );
    }
    elsif ( $state =~ /^\-(\d+)$/ ) {
        if ( $self->{state} < $1 ) {
            $newval = 0;
        }
        else {
            $newval = $self->{state} - $1;
        }
    }
    elsif ( $state =~ /^(\d+)\%$/ ) {
        $newval = $1;
    }
    else {
        print "Invalid state for EIS type 6: \'$state\'\n";
        return;
    }
    my $byte = sprintf( "%.0f", $newval * 255 / 100 );
    return ( [ 0, int $byte ] );
}

=item C<set_receive>

detected a "read" or "write" message on the bus.  For readable actuators, don't trust the values in "write" messages, as they may not have been accepted by the actuator. So if it is a write, and the actuator is readable, generate a read request to obtain the actual value from the actuator

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target, $read ) = @_;

    &main::print_log("EIB6_Item::set_receive: new state $state")
      if $main::config_parms{eib_errata} >= 3;

    if ( !$read && $self->{readable} ) {
        &main::print_log(
            "EIB6_Item::set_receive: read_request for $self->{groupaddr}")
          if $main::config_parms{eib_errata} >= 3;
        $self->delayed_read_request();
    }
    else {
        $self->SUPER::set_receive( $state, $set_by, $target );
    }
}

=back

=head2 EIB8_Item

"forced control". 2 bit

  Enforcement  ON  + Turn Device ON  (11)
  Enforcement  ON  + Turn Device OFF (10)
  Enforcement  OFF + Turn Device OFF (00)
  Enforcement  OFF + Turn Device ON  (01)

=cut

package EIB8_Item;

@EIB8_Item::ISA = ('EIB_Item');

sub new {
    my ( $class, $id, $mode ) = @_;

    my $self = $class->SUPER::new( $id, $mode );
    $self->add( $id . '00', '00' );
    $self->add( $id . '01', '01' );
    $self->add( $id . '10', '10' );
    $self->add( $id . '11', '11' );
    return $self;
}

sub eis_type {
    return '8';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 0 ) {
        &main::print_log(
            "Not EIS type 8 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    if ( ( $data[0] & 0x03 ) == 0 ) {
        return '00';
    }
    elsif ( ( $data[0] & 0x03 ) == 1 ) {
        return '01';
    }
    elsif ( ( $data[0] & 0x03 ) == 2 ) {
        return '10';
    }
    else {
        return '11';
    }

}

sub encode {
    my ( $self, $state ) = @_;

    if ( $state eq '00' ) {
        return ( [0] );
    }
    elsif ( $state eq '01' ) {
        return ( [1] );
    }
    elsif ( $state eq '10' ) {
        return ( [2] );
    }
    elsif ( $state eq '11' ) {
        return ( [3] );
    }
    else {
        print "Invalid state for EIS type 8: \'$state\'\n";
        return;
    }
}

=head2 EIB9_Item

32-bit float

=cut

package EIB9_Item;

@EIB9_Item::ISA = ('EIB_Item');

sub eis_type {
    return '9';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 4 ) {
        &main::print_log(
            "Not EIS type 9 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $res = unpack "f", pack "L",
      ( ( $data[1] << 24 ) | ( $data[2] << 16 ) | ( $data[3] << 8 ) |
          $data[4] );

    #    &main::print_log("EIS9 for $self->{groupaddr}: >$res<");
    return $res;
}

sub encode {
    my ( $self, $state ) = @_;
    my $res;
    $res = unpack "L", pack "f", $state;

    #&main::print_log("Res: $res State: $state \n");
    return (
        [
            0,
            ( $res & 0xff000000 ) >> 24,
            ( $res & 0xff0000 ) >> 16,
            ( $res & 0xff00 ) >> 8,
            $res & 0xff
        ]
    );
}

=head2 EIB10_Item

16-bit unsigned integer

=cut

package EIB10_Item;

@EIB10_Item::ISA = ('EIB_Item');

sub eis_type {
    return '10';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 2 ) {
        &main::print_log(
            "Not EIS type 10 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $res = ( $data[1] << 8 ) | $data[2];

    #    &main::print_log("EIS10 for $self->{groupaddr}: >$res<");
    return $res;
}

sub encode {
    my ( $self, $state ) = @_;

    return ( [ 0, ( $state & 0xff00 ) >> 8, $state & 0xff ] );
}

=head2 EIB10.1_Item

16-bit signed integer

=cut

package EIB10_1_Item;

@EIB10_1_Item::ISA = ('EIB_Item');

sub eis_type {
    return '10.1';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 2 ) {
        &main::print_log(
            "Not EIS type 10.1 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $res = ( $data[1] << 8 ) | $data[2];

    if ( $data[1] < 128 ) {
        return $res;
    }
    else {
        return ( 0 - ( 0xFFFF - $res + 1 ) );
    }
}

sub encode {
    my ( $self, $state ) = @_;
    my $res;
    if ( int($state) < 0 ) {
        $res = ( $state + 0xFFFF + 1 );
    }
    else {
        $res = $state;
    }
    return ( [ 0, ( $res & 0xff00 ) >> 8, $res & 0xff ] );
}

=head2 EIB11_Item

32-bit unsigned integer

=cut

package EIB11_Item;

@EIB11_Item::ISA = ('EIB_Item');

sub eis_type {
    return '11';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 4 ) {
        &main::print_log(
            "Not EIS type 11 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $res =
      ( $data[1] << 24 ) | ( $data[2] << 16 ) | ( $data[3] << 8 ) | $data[4];

    #    &main::print_log("EIS11 for $self->{groupaddr}: >$res<");
    return $res;
}

sub encode {
    my ( $self, $state ) = @_;

    return (
        [
            0,
            ( $state & 0xff000000 ) >> 24,
            ( $state & 0xff0000 ) >> 16,
            ( $state & 0xff00 ) >> 8,
            $state & 0xff
        ]
    );
}

=head2 EIB11.1_Item

32-bit signed integer

=cut

package EIB11_1_Item;

@EIB11_1_Item::ISA = ('EIB_Item');

sub eis_type {
    return '11';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 4 ) {
        &main::print_log(
            "Not EIS type 11 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $res =
      ( $data[1] << 24 ) | ( $data[2] << 16 ) | ( $data[3] << 8 ) | $data[4];

    #    &main::print_log("EIS11 for $self->{groupaddr}: >$res<");
    if ( $data[1] < 128 ) {
        return $res;
    }
    else {
        return ( 0 - ( 0xFFFFFFFF - $res + 1 ) );
    }
}

sub encode {
    my ( $self, $state ) = @_;
    my $res;
    if ( int($state) < 0 ) {
        $res = ( $state + 0xFFFFFFFF + 1 );
    }
    else {
        $res = $state;
    }

    #&main::print_log("Res: $res State: $state \n");
    return (
        [
            0,
            ( $res & 0xff000000 ) >> 24,
            ( $res & 0xff0000 ) >> 16,
            ( $res & 0xff00 ) >> 8,
            $res & 0xff
        ]
    );
}

=head2 EIB14_Item

8-bit signed integer

=cut

package EIB14_Item;

@EIB14_Item::ISA = ('EIB_Item');

sub eis_type {
    return '14';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 1 ) {
        &main::print_log(
            "Not EIS type 14 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $res = $data[1];

    if ( $data[1] < 128 ) {
        return $res;
    }
    else {
        return ( 0 - ( 0xFF - $res + 1 ) );
    }
}

sub encode {
    my ( $self, $state ) = @_;
    my $res;
    if ( int($state) < 0 ) {
        $res = ( $state + 0xFF + 1 );
    }
    else {
        $res = $state;
    }

    #&main::print_log("Res: $res State: $state \n");
    return ( [ 0, $res & 0xff ] );
}

=head2 EIB14_1_Item

"scaling". Relative values 0-255 with 8 bit resolution

=over

=cut

package EIB14_1_Item;

@EIB14_1_Item::ISA = ('EIB_Item');

sub eis_type {
    return '14.1';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 1 ) {
        &main::print_log(
            "Not EIS type 14.1 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    $res = sprintf( "%.0f", $data[1] );
    return $res;
}

sub encode {
    my ( $self, $state ) = @_;
    my $newval;
    if ( $state =~ /^(\d+)$/ ) {
        $newval = $1;
    }
    elsif ( $state =~ /^\+(\d+)$/ ) {
        $newval = $self->{state} + $1;
        $newval = 255 if ( $newval > 255 );
    }
    elsif ( $state =~ /^\-(\d+)$/ ) {
        if ( $self->{state} < $1 ) {
            $newval = 0;
        }
        else {
            $newval = $self->{state} - $1;
        }
    }
    elsif ( $state =~ /^(\d+)\%$/ ) {
        $newval = $1;
    }
    else {
        print "Invalid state for EIS type 14.1: \'$state\'\n";
        return;
    }
    my $byte = sprintf( "%.0f", $newval );
    return ( [ 0, int $byte ] );
}

=item C<set_receive>

detected a "read" or "write" message on the bus.  For readable actuators, don't trust the values in "write" messages, as they may not have been accepted by the actuator. So if it is a write, and the actuator is readable, generate a read request to obtain the actual value from the actuator

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target, $read ) = @_;

    if ( !$read && $self->{readable} ) {
        &main::print_log(
            "EIB14_1_Item::set_receive: read_request for $self->{groupaddr}")
          if $main::config_parms{eib_errata} >= 3;
        $self->delayed_read_request();
    }
    else {
        $self->SUPER::set_receive( $state, $set_by, $target );
    }
}

=back

=head2 EIB7_Item

Drive control

  Blinds, windows, etc
  Drives can be controlled in two different ways:
  1. "move": up/down
  2. "stop": stop/step movement

  NB EIS7 objects may not be read, since this can cause drive movements

=over

=cut

package EIB7_Item;

@EIB7_Item::ISA = ('EIB_Item');

sub new {
    my ( $class, $id, $opmode ) = @_;
    my @groups;
    my ( $subid, $item );

    my $self = $class->SUPER::new($id);

    @groups = split( /\|/, $id );
    if ( $#groups != 1 ) {
        print "Bad EIS 7 drive group addresses \'$id\'";
        return;
    }

    $self->{OperatingMode} = 'shutter';
    map {
        if ( $_ eq "blind" ) {
            $self->{OperatingMode} = $_;
        }
    } split( /\|/, $opmode ) if ( defined $opmode );

    $self->addStates( 'up', 'down' );

    $subid        = $groups[0];
    $item         = new EIB71_Item( $subid, $opmode, $self );
    $self->{Move} = $item;

    if ( $self->{OperatingMode} eq 'shutter' ) {
        $subid        = $groups[1];
        $item         = new EIB72_Item( $subid, $opmode, $self );
        $self->{Stop} = $item;
        $self->addStates('stop');
    }
    elsif ( $self->{OperatingMode} eq 'blind' ) {
        $subid        = $groups[1];
        $item         = new EIB73_Item( $subid, $opmode, $self );
        $self->{Step} = $item;
        $self->addStates( 'step_up', 'step_down' );
    }
    else {
        print "Bad EIS 7 operating mode \'$self->{OperatingMode}\'";
        return;
    }

    return $self;
}

sub eis_type {
    return '7';
}

=item C<set>

set EIB drive item. Parse state to determine the corresponding sub-item to call.  Don't modify own state here -- that will be done later, when/if the sub-items call set_receive for this item.

=cut

sub set {
    my ( $self, $state, $set_by, $target ) = @_;
    my $subitem;

    return unless $self->SUPER::set( $state, $set_by, $target );

    if ( $state eq 'up' || $state eq 'down' ) {
        $subitem = $self->{Move};
    }
    elsif ( $state eq 'stop' ) {
        $subitem = $self->{Stop};
    }
    elsif ( $state eq 'step-up' || $state eq 'step-down' ) {
        $subitem = $self->{Step};
    }
    else {
        &main::print_log(
            " $self->{object_name}: Bad EIB drive state \'$state\'\n");
        return;
    }
    $subitem->set( $state, $set_by, $target );
    return 1;
}

=back

=head2 EIB7_Subitem

generic class for drive sub-functions

=over

=cut

package EIB7_Subitem;

@EIB7_Subitem::ISA = ('EIB_Item');

=item C<new>

Instantiated with last args "driveid": the id of EIS7 item to which this subitem belongs

=cut

sub new {
    my ( $class, $id, $mode, $driveid ) = @_;
    my @args;

    my $self = $class->SUPER::new( $id, $mode );
    $self->{Drive} = $driveid;
    return $self;
}

=item C<set_receive>

forward to main Drive item (EIS7 item)

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target ) = @_;

    $self->SUPER::set_receive( $state, $set_by, $target );
    if ( defined $self->{Drive} ) {
        if ( my $drive = $self->{Drive} ) {
            $drive->set_receive( $state, $set_by, $target );
        }
    }
}

=back

=head2 EIB71_Item

Dimming sub-function "move"

=cut

package EIB71_Item;

@EIB71_Item::ISA = ('EIB7_Subitem');

sub eis_type {
    return '7.1';
}

sub decode {
    my ( $self, @data ) = @_;
    unless ( $#data == 0 ) {
        &main::print_log(
            "Not EIS type 71 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    if ( $data[0] == 0 ) {
        return 'up';
    }
    else {
        return 'down';
    }
}

sub encode {
    my ( $self, $state ) = @_;

    if ( $state eq 'up' ) {
        return ( [0] );
    }
    elsif ( $state eq 'down' ) {
        return ( [1] );
    }
    else {
        print "Invalid state for EIS type 7.1: \'$state\'\n";
        return;
    }
}

=head2 EIB72_Item

Drive sub-function "stop"

=cut

package EIB72_Item;

@EIB72_Item::ISA = ('EIB7_Subitem');

sub eis_type {
    return '7.2';
}

sub decode {
    my ( $self, @data ) = @_;
    unless ( $#data == 0 ) {
        &main::print_log(
            "Not EIS type 72 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    return 'stop';
}

sub encode {
    my ( $self, $state ) = @_;

    return ( [0] );
}

=head2 EIB73_Item

Drive sub-function "step-up/step-down"

=cut

package EIB73_Item;

@EIB73_Item::ISA = ('EIB7_Subitem');

sub eis_type {
    return '7.3';
}

sub decode {
    my ( $self, @data ) = @_;
    unless ( $#data == 0 ) {
        &main::print_log(
            "Not EIS type 73 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    if ( $data[0] == 0 ) {
        return 'step-up';
    }
    else {
        return 'step-down';
    }
}

sub encode {
    my ( $self, $state ) = @_;

    if ( $state eq 'step-up' ) {
        return ( [0] );
    }
    elsif ( $state eq 'step-down' ) {
        return ( [1] );
    }
    else {
        print "Invalid state for EIS type 7.3: \'$state\'\n";
        return;
    }
}

=head2 EIB15_Item

14-Byte Text Message

=cut

package EIB15_Item;

@EIB15_Item::ISA = ('EIB_Item');

sub eis_type {
    return '15';
}

sub decode {
    my ( $self, @data ) = @_;
    my $res;

    unless ( $#data == 14 ) {
        &main::print_log(
            "Not EIS type 15 data received for $self->{groupaddr}: \[@data\]")
          if $main::config_parms{eib_errata} >= 2;
        return;
    }
    shift(@data);
    $res = pack( "C*", @data );
    my $hex = unpack( 'H*', "$res" );
    &main::print_log("EIS15 for $self->{groupaddr}: >$res< ($hex) (@data");
    return $res;
}

sub encode {
    my ( $self, $state ) = @_;
    my $newstate;
    $newstate = sprintf( "%-14.14s", $state );
    my @res = (0);
    push( @res, unpack( "C*", $newstate ) );
    return \@res;
}

=head2 EIBW_Item

EIBW: Windows type of object wich uses 2 underlaying EIB1 Items (Top and Bottom) Definition as follows EIBW , GA1|GA2, Name, nameforOffOf|nameOffOn|NameOnOff|NameOnOn

=over

=cut

package EIBW_Item;

@EIBW_Item::ISA = ('EIB_Item');

=item C<new>

create an EIBW_Item. Instantiate the three underlying items.

=cut

sub new {
    my ( $class, $id, $mode ) = @_;
    my @groups;
    my ( $subid, $item );

    my $self = $class->SUPER::new($id);

    @groups = split( /\|/, $id );
    print "Two group addresses required for window. Found $#groups in $id\n"
      if ( $#groups != 1 );

    $subid = $groups[0];
    $item = new EIBW1_Item( $subid, "R", $self );

    $self->{Top} = $item;

    if ( $groups[0] ne $groups[1] ) {
        $subid = $groups[1];
        $item = new EIBW1_Item( $subid, "R", $self );
    }

    $mode = "closed|tilt|tilt|open" if ( !( defined $mode ) );
    $self->{Modes} = $mode;
    my @modes = split( /\|/, $mode );
    print "Four states required for window. Found $#modes in $id\n"
      if ( $#modes != 3 );
    $self->addStates(@modes);

    $self->{Bottom} = $item;

    return $self;
}

sub eis_type {
    return 'w';
}

# position: return "position" sub-item
sub top {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Top};
    return $self->{Top};
}

# control: return "control" sub-item
sub bottom {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Bottom};
    return $self->{Bottom};
}

=item C<set_receive>

received an event from one of the sub_items.

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target ) = @_;

    my $top    = $self->top()->state_final();
    my $bottom = $self->bottom()->state_final();

    my @modes = split( /\|/, $self->{Modes} );
    $state = $modes[0];
    $state = $modes[1] if ( $top eq "on" && $bottom eq "off" );
    $state = $modes[2] if ( $top eq "off" && $bottom eq "on" );
    $state = $modes[3] if ( $top eq "on" && $bottom eq "on" );

    #&main::print_log("################### t:$top b:$bottom w:$state ");

    $self->SUPER::set_receive( $state, $set_by, $target );
}

=back

=head2 EIBW_Subitem

generic class for the three dimming sub-functions

=over

=cut

package EIBW_Subitem;

@EIBW_Subitem::ISA = ('EIB_Item');

sub new {
    my ( $class, $id, $mode, $window ) = @_;
    my @args;

    my $self = $class->SUPER::new( $id, $mode );
    $self->{'Window'} = $window;
    return $self;
}

sub window {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Window};
    return $self->{Window};
}

=item C<set_receive>

forward to meta-item

=cut

sub set_receive {
    my ( $self, $state, $set_by, $target ) = @_;

    $self->SUPER::set_receive( $state, $set_by, $target );
    my $window = window $self;
    if ( defined $window ) {
        $window->set_receive( $state, $set_by, $target );
    }
    else {
        &main::print_log(
            "No window defined for window subitem $self->{groupaddr}");
    }
}

=back

=head2 EIBW1_Item

=cut

package EIBW1_Item;

# Multiple inheritance -- use encode/decode methods from EIB1_Item, and the rest from
# EIBW_Subitem
@EIBW1_Item::ISA = ( 'EIBW_Subitem', 'EIB1_Item' );    # order is important!

sub eis_type {
    return 'w.3';
}

=head2 AUTHOR

  09/09/2005  Created by Peter Sjödin peter@sjodin.net
  06/01/2009  Enhanced by Ralf Klueber r(at)lf-klueber.de
  08/01/2009  Listening addresses by Mike Pieper mptei@sourceforge.net

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

