
=head1 B<BSC>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

xAP support for Basic Status and Control schema

=head2 INHERITS

NONE

=head2 METHODS

=over

=cut

use strict;

use xAP_Items;

package BSC;

use constant INPUT  => 'input';
use constant OUTPUT => 'output';

my ( %handlers_by_obj_type, %mh_bsc_objects );

my ($bsc_X10_Device);

sub startup {
}

package BSC_Item;
@BSC_Item::ISA = ('Generic_Item');

=item C<new> 

Initialize class

=cut

sub new {
    my ( $class, $p_source_name, $p_writable ) = @_;
    my $self = {};
    bless $self, $class;

    $$self{m_xap} = new xAP_Item( 'xAPBSC.*', $p_source_name );
    $self->_initialize();
    $self->writable($p_writable) if defined $p_writable;
    $self->set_casesensitive();
    my $friendly_name = "bsc_$p_source_name";
    &main::store_object_data( $$self{m_xap}, 'xAP_Item', $friendly_name,
        $friendly_name );
    $$self{m_xap}->tie_items($self);
    $$self{source_name} = $p_source_name;
    $self->restore_data( 'm_xapuid', 'bsc_state', 'level', 'text',
        'display_text' );

    return $self;
}

sub _initialize {
    my ($self) = @_;
    $$self{m_always_set_state}        = 0;
    $$self{m_allow_local_set_state}   = 1;
    $$self{m_write}                   = 1;
    $$self{m_registered_objects}      = ();
    $$self{pending_device_state_mode} = ();
    $$self{pending_device_state}      = ();
    $$self{device_state}              = ();
}

=item C<bsc_state> 

bsc_state is a very bad name and only exists to prevent overriding mh's state member.  bsc_state maps to a BSC state

=cut

sub bsc_state {
    my ( $self, $p_state ) = @_;
    $$self{bsc_state} = $p_state if $p_state;
    if ( $$self{bsc_state} ) {
        return $$self{bsc_state};
    }
    else {
        return '?';
    }
}

sub source {
    my ($self) = @_;
    return $$self{m_xap}->source;
}

sub level {
    my ( $self, $p_level ) = @_;
    $$self{level} = $p_level if defined $p_level;
    return $$self{level};
}

sub text {
    my ( $self, $p_text ) = @_;
    $$self{text} = $p_text if defined $p_text;
    return $$self{text};
}

sub display_text {
    my ( $self, $p_display_text ) = @_;
    $$self{display_text} = $p_display_text if defined $p_display_text;
    return $$self{display_text};
}

sub always_set_state {
    my ( $self, $p_always_set_state ) = @_;
    $$self{m_always_set_state} = $p_always_set_state
      if defined $p_always_set_state;
    return $$self{m_always_set_state};
}

sub writable {
    my ( $self, $p_write ) = @_;
    if ( defined $p_write ) {
        if ( $p_write =~ /^read/i or $p_write =~ /0/ ) {
            $$self{m_write} = 0;
        }
        else {
            $$self{m_write} = 1;
        }
    }
    return $$self{m_write};
}

=item C<allow_local_set_state> 

allow_local_set_state(flag) - sets the local flag to either 1 (true) or 0 (false); the default is true.  If flag is true, then the item's state is changed on a "programatic" set (i.e., local control).  If flag is false, then the item's state is changed only when the device acknowledges it's state change via a BSC event or info message

=cut

sub allow_local_set_state {
    my ( $self, $p_allow_local_set_state ) = @_;
    $$self{m_allow_local_set_state} = $p_allow_local_set_state
      if defined $p_allow_local_set_state;
    return $$self{m_allow_local_set_state};
}

sub set {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;
    return if &main::check_for_tied_filters( $self, $p_state );
    my $state = $p_state;
    my ($xap_subaddress) = $$self{m_xap}->source =~ /.+\:(.+)/;
    if ( $p_setby eq $$self{m_xap} ) {
        my $sender_class = $$p_setby{'xap-header'}{class};
        if ( lc $sender_class eq 'xapbsc.cmd' ) {

            # handle command
            $state = $self->cmd_callback($p_setby);
        }
        elsif ( lc $sender_class eq 'xapbsc.query' ) {

            # handle query
            $state = $self->query_callback(
                $$p_setby{'xap-header'}{target},
                $$p_setby{'xap-header'}{source}
            );
        }
        elsif ( lc $sender_class eq 'xapbsc.event' ) {

            # handle event
            $self->uid( $$self{m_xap}{'xap-header'}{uid} );
            $state = $self->event_callback($p_setby);
        }
        elsif ( lc $sender_class eq 'xapbsc.info' ) {

            # handle info
            $self->uid( $$self{m_xap}{'xap-header'}{uid} );
            $state = $self->info_callback($p_setby);
        }
    }
    else {
        my $bsc_block;
        my $id = undef;
        if ($xap_subaddress) {
            my $subuid = undef;
            if ( $self->uid ) {
                ($subuid) = $self->uid =~ /^\S\S\.\S\S\S\S\:(\S\S)$/;
                $subuid = substr( $self->uid, 6 )
                  if !( defined $subuid )
                  and length( $self->uid ) == 8;
                print "[BSC] "
                  . $self->{object_name}
                  . " extracting subaddress uid = $subuid\n"
                  if $main::Debug{bsc};
            }
            else {
                print "[BSC] ERROR: "
                  . $self->{object_name}
                  . " does not have a registered xAP uid! Ignoring attempt to set object.\n";
                return;
            }
            $id = $subuid if defined($subuid);
        }
        $bsc_block->{'id'} = $id if defined $id;
        if ( $p_state eq 'off' ) {
            $bsc_block->{'state'} = 'off';
        }
        elsif ( $p_state eq 'on' ) {
            $bsc_block->{'state'} = 'on';
        }
        else {
            $bsc_block->{'state'} = 'on';
            if ( $p_state =~ /\d+\/\d+/ ) {
                $bsc_block->{'level'} = $p_state;
            }
            elsif ( $p_state =~ /^\d?\d?\d%$/ ) {
                my ($percent) = $p_state =~ /^(\d?\d?\d)%$/;
                if ( defined $percent ) {
                    $bsc_block->{'level'} = "$percent/100";
                }
            }
            else {
                $bsc_block->{'text'} = $p_state;
            }
        }
        my $target_address = $$self{m_xap}{source};
        $target_address =~ s/(\:.*)/\:\>/;
        &xAP::sendXap( $target_address, 'xapbsc.cmd',
            'output.state.1' => $bsc_block );

        # if allow_local_set_state is set false, then don't propogate the state
        # and instead only allow the device to acknowledge it's state change via info or event
        $state = '_masked' if !( $$self{m_allow_local_set_state} );
    }

    #   } else {
    #        print "Unable to process " . $self->{object_name} . "; state: $state\n" if $main::Debug{bsc};
    #        $state = '_unknown';
    #   }

    # Always pass along the state to base class
    $self->SUPER::set_now( $state, $p_setby, $p_respond )
      unless ( $state eq '_unknown'
        or $state eq '_unchanged'
        or $state eq '_masked' );
    return;
}

sub uid {
    my ( $self, $p_uid ) = @_;
    $$self{m_xapuid} = $p_uid if $p_uid;
    return $$self{m_xapuid};
}

sub cmd_callback {
    my ( $self, $p_xap ) = @_;
    for my $section_name ( keys %{$p_xap} ) {
        next unless ( $section_name =~ /^(output)\.state\.\d+/ );
        print "Process section:$section_name\n";
        my ( $id, $state, $level, $text );
        for my $field_name ( keys %{ $$p_xap{$section_name} } ) {
            my $value = $$p_xap{$section_name}{$field_name};
            if ( lc $field_name eq 'id' ) {
                $id = $value;
            }
            elsif ( lc $field_name eq 'state' ) {
                $state = $value;
            }
            elsif ( lc $field_name eq 'level' ) {
                $level = $value;
            }
            elsif ( lc $field_name eq 'text' ) {
                $text = $value;
            }
        }
        print
          "db BSC_Item->cmd_callback: id=$id,state=$state,level=$level,text=$text\n"
          if $main::Debug{bsc};
        if ( ($id) and ($state) ) {
            my $mode = 'output';    # cmds can only affect an 'output'
            $self->set_device( $id, '', $mode, $state, $level, $text );
        }
    }
    return 'cmd';
}

sub query_callback {
    my ( $self, $p_target, $p_source ) = @_;
    return 'query';
}

sub event_callback {
    my ( $self, $p_xap ) = @_;
    my $state = '_unknown';

    # clear out any old data
    $$self{bsc_state}    = undef;
    $$self{level}        = undef;
    $$self{text}         = undef;
    $$self{display_text} = undef;
    for my $section_name ( keys %{$p_xap} ) {
        next unless ( $section_name =~ /^(input|output)\.state/ );
        print "db BSC_Item->event_callback: Process section:$section_name"
          . " from "
          . $$p_xap{'xap-header'}{source} . "\n"
          if $main::Debug{bsc};
        my $bsc_level = $$p_xap{$section_name}{level};
        my $bsc_state = $$p_xap{$section_name}{state};
        my $bsc_text  = $$p_xap{$section_name}{text};
        $self->bsc_state($bsc_state);
        $self->level($bsc_level);
        $self->text($bsc_text);
        $self->display_text( $$p_xap{$section_name}{display_text} );

        # determine state
        if ($bsc_level) {
            $bsc_state = $bsc_level;
        }
        elsif ($bsc_text) {
            $bsc_state = $bsc_text;
        }
        $state = $bsc_state;
        last;
    }
    return $state;
}

sub info_callback {
    my ( $self, $p_xap ) = @_;
    my $state = '_unknown';

    # clear out any old data
    $$self{bsc_state}    = undef;
    $$self{level}        = undef;
    $$self{text}         = undef;
    $$self{display_text} = undef;
    for my $section_name ( keys %{$p_xap} ) {
        next unless ( $section_name =~ /^(input|output)\.state/ );
        print "db BSC_Item->info_callback: Process section:$section_name"
          . " from "
          . $$p_xap{'xap-header'}{source} . "\n"
          if $main::Debug{bsc};
        my $bsc_level = $$p_xap{$section_name}{level};
        my $bsc_state = $$p_xap{$section_name}{state};
        my $bsc_text  = $$p_xap{$section_name}{text};
        $self->bsc_state($bsc_state);
        $self->level($bsc_level);
        $self->text($bsc_text);
        $self->display_text( $$p_xap{$section_name}{display_text} );

        # determine state
        if ($bsc_level) {
            $bsc_state = $bsc_level;
        }
        elsif ($bsc_text) {
            $bsc_state = $bsc_text;
        }
        $state = $bsc_state;
        last;
    }
    if ( $self->always_set_state ) {
        return $state;
    }
    elsif ( lc $state eq 'toggle' ) {

        # a state of 'toggle' is special within BSC and shouldn't force a change
        return '_unchanged';
    }
    else {
        return ( ( $self->state eq $state ) ? '_unchanged' : $state );
    }
}

sub query {
    my ($self) = @_;
    my ( $headerVars, @data2 );
    $headerVars->{'class'}  = 'xAPBSC.query';
    $headerVars->{'target'} = $$self{source_name};
    $headerVars->{'source'} =
      &xAP::get_xap_mh_source_info(xAP::XAP_REAL_DEVICE_NAME);
    $headerVars->{'uid'} =
      &xAP::get_xap_base_uid(xAP::XAP_REAL_DEVICE_NAME) . '00';
    push @data2, $headerVars;
    push @data2, 'request', ''
      ; # hmmm, this could blow-up maybe? really only want a blank request block

    &xAP::sendXapWithHeaderVars(@data2);
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Gregg Liming
gregg@limings.net

Special Thanks to: Bruce Winter - MH

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.












=head1 B<BSCMH_Item>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

NONE

=head2 METHODS

=over

=cut

package BSCMH_Item;

use constant DEVICE_TYPE_X10      => 'x10_device';
use constant DEVICE_TYPE_PRESENCE => 'presence';
use constant DEVICE_TYPE_ABSTRACT => 'abstract_device';

use constant X10_ITEM                  => 'X10_Item';
use constant X10_APPLIANCE             => 'X10_Appliance';
use constant X10_TRANSMITTER           => 'X10_Transmitter';
use constant X10_RF_RECEIVER           => 'X10_RF_Receiver';
use constant X10_GARAGE_DOOR           => 'X10_GARAGE_DOOR';
use constant X10_IRRIGATION_CONTROLLER => 'X10_IrrigationController';
use constant X10_SWITCHLINC            => 'X10_Switchlinc';
use constant X10_TEMPLINC              => 'X10_Templinc';
use constant X10_OTE                   => 'X10_Ote';
use constant X10_SENSOR                => 'X10_Sensor';

use constant LIGHT_ITEM  => 'Light_Item';
use constant MOTION_ITEM => 'Motion_Item';

use constant PRESENCE_MONITOR  => 'Presence_Monitor';
use constant OCCUPANCY_MONITOR => 'Occupancy_Monitor';

@BSCMH_Item::ISA = ('Generic_Item');

=item C<new> 

Initialize class

=cut

sub new {
    my ( $class, $p_device_family ) = @_;
    my $self = {};
    bless $self, $class;

    $$self{m_device_family} = $p_device_family;
    $$self{m_source_name}   = &xAP::get_xap_mh_source_info($p_device_family);

    my $source_name = &xAP::get_xap_mh_source_info($p_device_family);  # . ':>';
    $$self{m_xap} = new xAP_Item( 'xAPBSC.*', '*' );
    $$self{m_xap}->target_address($source_name)
      ;    # want to listen to messages directed to us
    $$self{m_xap}->device_name($p_device_family);
    $$self{m_xap}->allow_empty_state(1)
      ;    # because query commands result in an empty xap body
           # init a virtual xap device
     #   this will force a new xap listener to exist as well as separate hearbeats.
     #   it is only required because of the current max 254 endpoint limitation

    &xAP::init_xap_virtual_device($p_device_family);

    &main::store_object_data( $$self{m_xap}, 'xAP_Item', 'xAP_Item', 'BSC.pm' );
    $$self{m_xap}->tie_items($self);
    return $self;
}

sub register_obj {
    my ( $self, $mh_obj_name, $handler_name, $requested_uid ) = @_;

    my $o = &main::get_object_by_name($mh_obj_name);
    $o = $mh_obj_name unless $o;    # In case we stored object directly
    if ( !($requested_uid) ) {

        # extract the x10 id
        my ($x10_id) = $o->{x10_id} =~ /^X*(.*)/;

        # if a x10_id exists, then convert it to the hex uid format
        if ($x10_id) {

            # we can only permit the subaddress space to map to 254 devices;
            # so, don't allow the last 2 possible x10 devices
            if ( $x10_id eq 'PF' or $x10_id eq 'PG' ) {
                print
                  "WARNING: x10 devices w/ housecode/usercodes of $x10_id are not supported\n"
                  if $main::Debug{bsc};
                return;
            }
            print "x10id: $x10_id\n" if $main::Debug{bsc};
            $requested_uid = &_convert_x10_id($x10_id);
        }
    }

    # reserve the UID
    my $sub_uid =
      &xAP::get_xap_subaddress_uid( $handler_name, $mh_obj_name,
        $requested_uid );
    $$self{m_registered_objects}{ $$o{object_name} } = $handler_name;
    $o->tie_items($self) if $o;
    print
      "Registered $$o{object_name} as $sub_uid to $$self{object_name} using handler: $handler_name\n"
      if $main::Debug{bsc};
}

sub register_device_type {
    my ( $self, $p_device_type ) = @_;
    if (   $p_device_type eq X10_ITEM
        or $p_device_type eq X10_APPLIANCE
        or $p_device_type eq X10_TRANSMITTER
        or $p_device_type eq X10_RF_RECEIVER
        or $p_device_type eq X10_GARAGE_DOOR
        or $p_device_type eq X10_IRRIGATION_CONTROLLER
        or $p_device_type eq X10_SWITCHLINC
        or $p_device_type eq X10_TEMPLINC
        or $p_device_type eq X10_OTE
        or $p_device_type eq X10_SENSOR )
    {
        $self->_init_object( $p_device_type, DEVICE_TYPE_X10 );
    }
    elsif ($p_device_type eq LIGHT_ITEM
        or $p_device_type eq MOTION_ITEM )
    {
        $self->_init_object( $p_device_type, DEVICE_TYPE_ABSTRACT );
    }
    elsif ($p_device_type eq PRESENCE_MONITOR
        or $p_device_type eq OCCUPANCY_MONITOR )
    {
        $self->_init_object( $p_device_type, DEVICE_TYPE_PRESENCE );
    }
    else {
        print "WARNING: $p_device_type is not supported by BSCMH_Item!!\n"
          if $main::Debug{bsc};
    }
}

sub set {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;
    return if &main::check_for_tied_filters( $self, $p_state );
    my $state = $p_state;
    if ( $p_setby eq $$self{m_xap} ) {
        $$self{device_target} = $$self{m_xap}{target_address};
        my ($xap_subaddress) = $$self{m_xap}{target_address} =~ /.+\:(.+)/;
        $$self{device_subaddress_target} = $xap_subaddress;
        my $msg_class_name = lc( $$self{m_xap}{'xap-header'}{class} );
        if ( $msg_class_name eq 'xapbsc.cmd' ) {

            # handle command
            $state = $self->cmd_callback($p_setby);
        }
        elsif ( $msg_class_name eq 'xapbsc.query' ) {

            # handle query
            $state = $self->query_callback(
                $$p_setby{'xap-header'}{target},
                $$p_setby{'xap-header'}{target}
            );
        }
        elsif ( $msg_class_name eq 'xapbsc.event' ) {

            # ignore since only mh is responsible for sending out event messages
            $state = 'event';
        }
        elsif ( $msg_class_name eq 'xapbsc.info' ) {

            # ignore since only mh is responsible for sending out info messages
            $state = 'info';
        }
        $p_setby = $self;    # override so that SUPER doesn't attempt;
    }
    elsif ( defined( $$p_setby{object_name} )
        && ( exists( $$self{m_registered_objects}{ $$p_setby{object_name} } ) )
      )
    {
        print
          "In $$self{object_name} set callback for $$p_setby{object_name} using $$self{m_registered_objects}{$$p_setby{object_name}}\n"
          if $main::Debug{bsc};

        # only handle changes in state
        if ( $self->state_changed($p_setby) ) {
            my ( $mh_obj_name, $bsc_obj_name, $handler_name ) = @_;
            my $code =
              "\&BSCMH_Item::_handle_$$self{m_registered_objects}{$$p_setby{object_name}}";
            $code .=
              "('send-event', \'$$p_setby{object_name}\',\'$$self{object_name}\')";
            eval($code);
            $p_setby = $self;    # override so that SUPER doesn't attempt
        }
        else {
            print "No state change for $$p_setby{object_name}\n"
              if $main::Debug{bsc};
        }
        $p_setby = $self;
    }
    else {
        print
          "Unable to process $$self{object_name}->set for $$p_setby{object_name}\n"
          if $main::Debug{bsc};
    }

    # Always pass along the state to base class
    $self->SUPER::set( $p_state, $p_setby, $p_respond );

    return;
}

sub state_changed {
    my ( $self, $p_setby ) = @_;
    my $id =
      &xAP::get_xap_subaddress_uid(
        $$self{m_registered_objects}{ $$p_setby{object_name} },
        $$p_setby{object_name} );
    my $current_bsc_state = $self->{device_state}{$id}{'RefState'};
    return 1 if !( defined($current_bsc_state) );
    return ( $p_setby->state() ne $current_bsc_state );
}

sub pending_device_state {
    my ( $self, $id ) = @_;
    if ($id) {
        return $$self{pending_device_state}{$id};
    }
    else {
        return $$self{pending_device_state};
    }
}

=item C<set_device>

set's a device's state given the device's ID, mode (input or output), state and optionally level and text

=cut

sub set_device {
    my ( $self, $id, $ref_state, $mode, $bsc_state, $bsc_level, $bsc_text ) =
      @_;

    # set the device data in a "pending state" hash until it is committed
    $$self{pending_device_state_mode}{$id} = $mode;
    $$self{pending_device_state}{$id}{'State'} = $bsc_state;    #mandatory
    $$self{pending_device_state}{$id}{'Level'}    = $bsc_level if $bsc_level;
    $$self{pending_device_state}{$id}{'Text'}     = $bsc_text  if $bsc_text;
    $$self{pending_device_state}{$id}{'RefState'} = $ref_state if $ref_state;
    #
}

sub send_cmd {
    my ( $self, $family_name, $target );
    $target = '*'
      unless $target
      ; # possibly a bad idea as wildcarding across all devices doesn't make sense
    my ( $headerVars, @data2 );
    $headerVars->{'class'}  = 'xAPBSC.cmd';
    $headerVars->{'target'} = $target;
    $headerVars->{'source'} = &xAP::get_xap_mh_source_info($family_name);
    $headerVars->{'uid'}    = &xAP::get_xap_uid( $family_name, '00' );
    push @data2, $headerVars;

    # iterate over the pending/"state now" device state hash and create the blocks
    if ( $$self{pending_device_state} ) {
        my $bsc_block_index = 1;
        for my $key ( keys %{ $$self{pending_device_state} } ) {
            my $pending_state      = $$self{pending_device_state}{$key};
            my $pending_state_mode = $$self{pending_device_state_mode}{$key};
            my $bsc_block;
            $bsc_block->{'ID'} = $key;
            if ( $pending_state->{'State'} ) {
                $bsc_block->{'State'} = $pending_state->{'State'};
            }
            else {
                $bsc_block->{'State'} = '?'
                  ; # this doesn't make much sense as we can't command an uncertainty
            }
            $bsc_block->{'Level'} = $pending_state->{'Level'}
              if $pending_state->{'Level'};
            $bsc_block->{'Text'} = $pending_state->{'Text'}
              if $pending_state->{'Text'};
            my $block_name = "$pending_state_mode.state.$bsc_block_index";
            push @data2, $block_name, $bsc_block;
            $bsc_block_index++;

            # "commit" the pending state data to the state data
            # Note: this may be a bad idea as we probably ought to only commit state on receipt of
            # and info or event
            # Perhaps should make this optional instead of immediate commit, or not commit by default
            $self->commit_pending_state($key);
        }

        &xAP::sendXapWithHeaderVars(@data2);

        # clear pending data
        $$self{pending_device_state}      = undef;
        $$self{pending_device_state_mode} = undef;
    }
}

sub send_info {
    my ( $self, $family_name, $subaddress_name ) = @_;
    print "In send_info using $family_name and $subaddress_name\n"
      if $main::Debug{bsc};
    if ( !($family_name) ) {
        print "You MUST supply a family_name to BSC_Item->send_info\n"
          if $main::Debug{bsc};
        return;
    }
    my ($subaddress) = $subaddress_name =~ /^\$*(.*)/;
    my ( $headerVars, @data2 );
    $headerVars->{'class'}  = 'xAPBSC.info';
    $headerVars->{'target'} = '*';
    $headerVars->{'source'} =
      &xAP::get_xap_mh_source_info($family_name) . ":" . $subaddress_name;

    # iterate over the pending/"state now" device state hash and create the blocks
    if ( $$self{pending_device_state} ) {

        # the for loop is only needed since we don't know the key
        # since info messages can only have one pending device
        for my $key ( keys %{ $$self{pending_device_state} } ) {

            # now that we have the key, we can construct the UID
            $headerVars->{'uid'} = &xAP::get_xap_base_uid($family_name) . $key;

            # and push the headvars as we're only in this loop once
            push @data2, $headerVars;

            # now, construct the blocks that will be send
            my $pending_state      = $$self{pending_device_state}{$key};
            my $pending_state_mode = $$self{pending_device_state_mode}{$key};
            my $bsc_block;
            if ( $pending_state->{'State'} ) {
                $bsc_block->{'State'} = $pending_state->{'State'};
            }
            else {
                $bsc_block->{'State'} = '?';
            }
            $bsc_block->{'Level'} = $pending_state->{'Level'}
              if $pending_state->{'Level'};
            $bsc_block->{'Text'} = $pending_state->{'Text'}
              if $pending_state->{'Text'};
            my $block_name = "$pending_state_mode.state";
            push @data2, $block_name, $bsc_block;

            # "commit" the pending state data to the state data
            $self->commit_pending_state($key);

            # punch out of the loop -- perhaps a bit of a "kludge"
            last;
        }

        &xAP::sendXapWithHeaderVars(@data2);

        # clear pending data
        $$self{pending_device_state}      = undef;
        $$self{pending_device_state_mode} = undef;
    }
}

sub send_event {
    my ( $self, $family_name, $subaddress_name ) = @_;
    print "In send_event using $family_name and $subaddress_name\n"
      if $main::Debug{bsc};
    if ( !($family_name) ) {
        print "You MUST supply a family_name to BSC_Item->send_event\n"
          if $main::Debug{bsc};
        return;
    }
    elsif ( !($subaddress_name) ) {
        print "You MUST supply a subaddress_name to BSC_Item->send_event\n";
        return;
    }
    my ($subaddress) = $subaddress_name =~ /^\$*(.*)/;
    my ( $headerVars, @data2 );
    $headerVars->{'class'}  = 'xAPBSC.event';
    $headerVars->{'target'} = '*';
    $headerVars->{'source'} =
      &xAP::get_xap_mh_source_info($family_name) . ":" . $subaddress_name;

    # iterate over the pending/"state now" device state hash and create the blocks
    if ( $$self{pending_device_state} ) {

        # the for loop is only needed since we don't know the key
        # since events can only have one pending device
        for my $key ( keys %{ $$self{pending_device_state} } ) {

            # now that we have the key, we can construct the UID
            $headerVars->{'uid'} = &xAP::get_xap_base_uid($family_name) . $key;

            # and push the headvars as we're only in this loop once
            push @data2, $headerVars;

            # now, construct the blocks that will be send
            my $pending_state      = $$self{pending_device_state}{$key};
            my $pending_state_mode = $$self{pending_device_state_mode}{$key};
            my $bsc_block;
            if ( $pending_state->{'State'} ) {
                $bsc_block->{'State'} = $pending_state->{'State'};
            }
            else {
                $bsc_block->{'State'} = '?';
            }
            $bsc_block->{'Level'} = $pending_state->{'Level'}
              if $pending_state->{'Level'};
            $bsc_block->{'Text'} = $pending_state->{'Text'}
              if $pending_state->{'Text'};
            my $block_name = "$pending_state_mode.state";
            push @data2, $block_name, $bsc_block;

            # "commit" the pending state data to the state data
            $self->commit_pending_state($key);

            # punch out of the loop -- perhaps a bit of a "kludge"
            last;
        }

        &xAP::sendXapWithHeaderVars(@data2);

        # clear pending data
        $$self{pending_device_state}      = undef;
        $$self{pending_device_state_mode} = undef;
    }
}

sub commit_pending_state {
    my ( $self, $id ) = @_;
    $self->{device_state}{$id}{State} =
      $self->{pending_device_state}{$id}{State};
    $self->{device_state}{$id}{Level} =
      $self->{pending_device_state}{$id}{Level};
    $self->{device_state}{$id}{Text} = $self->{pending_device_state}{$id}{Text};
    $self->{device_state}{$id}{RefState} =
      $self->{pending_device_state}{$id}{RefState}
      if $self->{pending_device_state}{$id}{RefState};
    print "Committed refstate: $$self{device_state}{$id}{RefState}\n"
      if $main::Debug{bsc};
}

sub cmd_callback {
    my ( $self, $p_xap ) = @_;

    # use the base BSC class to deposit the request into the pending_device_state hash
    my $bscstate = $self->SUPER::cmd_callback($p_xap);

    for my $key ( keys %{ $$self{pending_device_state} } ) {

        # get the mh_obj that is indexed by $key
        my $mh_obj_name =
          &xAP::get_xap_subaddress_devname( $$self{m_device_family}, $key );
        print "Device to be controlled by cmd_callback: $mh_obj_name\n"
          if $main::Debug{bsc};

        my $code = "\&BSCMH_Item::_handle_$$self{m_device_family}";
        $code .= "('receive', \'$mh_obj_name\',\'$$self{object_name}\')";
        eval($code);
    }

    # clear pending data
    $$self{pending_device_state}      = undef;
    $$self{pending_device_state_mode} = undef;

    return $bscstate;
}

sub query_callback {
    my ( $self, $p_target, $p_source ) = @_;
    my $bscstate = 'query';

    my ($xap_subaddress) = $$self{m_xap}{target_address} =~ /.+\:(.+)/;
    print "db BSCMD->query_callback: xap_subaddress target=$xap_subaddress\n"
      if $main::Debug{bsc};
    $self->do_info($xap_subaddress);

    return $bscstate;
}

sub do_info {
    my ( $self, $p_subaddress ) = @_;

    # determine what event messages need to be sent base on $p_target
    # extract the endpoint portion; the right-side of the colon delimitter

    # does it have/begin w/ the endpointer wildcard (>)?
    if ( !($p_subaddress) || ( $p_subaddress =~ /^>.*/ ) ) {

        # if so, then iterate over all of the devices assigned
        for my $obj_name ( keys %{ $$self{m_registered_objects} } ) {
            my $code = "\&BSCMH_Item::_handle_$$self{m_device_family}";
            $code .= "('set-info', \'$obj_name\',\'$$self{object_name}\')";
            eval($code);
        }
    }
    else {
        # otherwise, just send an info on the requested endpoint
        my $code = "\&BSCMH_Item::_handle_$$self{m_device_family}";
        $code .= "('set-info', \'$p_subaddress\',\'$$self{object_name}\')";
        eval($code);
    }

}

sub _handle_x10_device {

    my ( $msg_type, $mh_obj_name, $bsc_obj_name ) = @_;
    my $mh_obj  = &main::get_object_by_name($mh_obj_name);
    my $bsc_obj = &main::get_object_by_name($bsc_obj_name);
    if ( defined($mh_obj) ) {

        # get a valid BSC ID--hopefully, corresponding to the x10 id
        # that should have been reserved at the point that the object was registered
        my $bsc_id =
          &xAP::get_xap_subaddress_uid( DEVICE_TYPE_X10, $mh_obj_name );
        if ( ( $msg_type eq 'send-event' ) or ( $msg_type eq 'set-info' ) ) {
            my $mh_state = $mh_obj->state_now()
              if ( $msg_type eq 'send-event' );
            $mh_state = $mh_obj->state()
              if ( $msg_type eq 'set-info' )
              ;    # probably need to parse out stacked state vals if they exist

            # TO-DO: handle "bright" and "dim"; this requires translating the relative vals to absolute levels
            if ( $mh_state eq 'on' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'on',
                    '100%', '' );
            }
            elsif ( $mh_state eq 'off' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'off',
                    '0%', '' );
            }
            elsif ( $mh_state =~ /.*\%$/ ) {

                # handle levels expressed as percent
                my ($state_in_percent) = $mh_state =~ /^[+|-]*(\d+)%$/;
                $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'on',
                    $state_in_percent . '%', '' );
            }
            elsif ( $mh_state =~ /&P\d+/ ) {

                # handle levels expressed as their presets
                # the following needs to change so that the preset amount is converted to
                # an actual level rather than passed as a text string
                $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'on', '',
                    $mh_state );

            }
            elsif ( $mh_state eq 'motion' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'input', 'on', '',
                    $mh_state );
            }
            elsif ( $mh_state eq 'still' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'input', 'off', '',
                    $mh_state );

                # now, handle X10_Sensor objects w/ photocells but ONLY if defined as type: brightness (not ms13)
            }
            elsif ( ( $mh_state eq 'light' )
                and ( lc $mh_obj->{type} eq 'brightness' ) )
            {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'input', 'on', '',
                    $mh_state );
            }
            elsif ( ( $mh_state eq 'dark' )
                and ( lc $mh_obj->{type} eq 'brightness' ) )
            {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'input', 'off', '',
                    $mh_state );
            }
            else {
                print "Warning: unable to process state: $mh_state\n"
                  if $main::Debug{bsc};
                return;
            }
            if ( $msg_type eq 'send-event' ) {

                # now, send the data after removing any starting $ symbol
                $mh_obj_name =~ s/^\$//;
                $bsc_obj->send_event( DEVICE_TYPE_X10, $mh_obj_name );
            }
            elsif ( $msg_type eq 'set-info' ) {

                # now, send the data after removing any starting $ symbol
                $mh_obj_name =~ s/^\$//;
                $bsc_obj->send_info( DEVICE_TYPE_X10, $mh_obj_name );
            }
        }
        elsif ( $msg_type eq 'receive' ) {

            # now, construct the blocks that will be send
            my $pending_state = $$bsc_obj{pending_device_state}{$bsc_id};
            my $pending_state_mode =
              $$bsc_obj{pending_device_state_mode}{$bsc_id};
            my $bsc_state = $$pending_state{'State'};
            my $mh_state  = '';
            if ($bsc_state) {

                # TO-DO: the following logic attempts to set the mh obj state
                #        regardless if it has changed.  Need to revisit this and
                #        optionally only set state on changed state
                my $bsc_level = $$pending_state{'Level'};
                my $bsc_text  = $$pending_state{'Text'};
                if ( $mh_obj->isa(X10_ITEM) or $mh_obj->isa(X10_SWITCHLINC) ) {
                    if ($bsc_level) {

                        # TO-DO: need to validate this is a valid state
                        # TO-DO: translate to relate level for non preset types
                        $mh_obj->set( $bsc_level, $bsc_obj );
                        $mh_state = $bsc_level;
                    }
                    elsif ($bsc_text) {

                        # TO-DO: need to validate this is a valid state
                        # this probably shouldn't be used; except, we're currently passing
                        # preset codes in this fashion.  If used, then validation is really
                        # needed
                        $mh_obj->set( $bsc_text, $bsc_obj );
                        $mh_state = $bsc_text;
                    }
                    else {
                        $mh_state = lc $bsc_state;
                        $mh_obj->set( $mh_state, $bsc_obj );
                    }
                }
                elsif ($mh_obj->isa(X10_APPLIANCE)
                    or $mh_obj->isa(X10_IRRIGATION_CONTROLLER)
                    or $mh_obj->isa(X10_GARAGE_DOOR) )
                {
                    $mh_state = lc $bsc_state;
                    $mh_obj->set( $mh_state, $bsc_obj );
                }
                if ($mh_state) {
                    $$pending_state{'RefState'} = $mh_state;

                    # "commit" the pending state data to the state data
                    $bsc_obj->commit_pending_state($bsc_id);
                }
            }
            else {
                print
                  "State for $mh_obj_name:$bsc_id is unset for incoming xAP BSC message!\n";
            }

            # be sure to set the 'RefState' hash member to whatever mh state gets mapped
        }
    }

}

sub _handle_abstract_device {

    my ( $msg_type, $mh_obj_name, $bsc_obj_name ) = @_;
    my $mh_obj  = &main::get_object_by_name($mh_obj_name);
    my $bsc_obj = &main::get_object_by_name($bsc_obj_name);
    if ( defined($mh_obj) ) {

        # get a valid BSC ID--hopefully, corresponding to the x10 id
        # that should have been reserved at the point that the object was registered
        my $bsc_id =
          &xAP::get_xap_subaddress_uid( DEVICE_TYPE_ABSTRACT, $mh_obj_name );
        if ( ( $msg_type eq 'send-event' ) or ( $msg_type eq 'set-info' ) ) {
            my $mh_state = $mh_obj->state_now()
              if ( $msg_type eq 'send-event' );
            $mh_state = $mh_obj->state()
              if ( $msg_type eq 'set-info' )
              ;    # probably need to parse out stacked state vals if they exist

            # TO-DO: handle "bright" and "dim"; this requires translating the relative vals to absolute levels
            if ( $mh_state eq 'on' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'on',
                    '100%', '' );
            }
            elsif ( $mh_state eq 'off' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'off',
                    '0%', '' );
            }
            elsif ( $mh_state =~ /.*\%$/ ) {

                # handle levels expressed as percent
                my ($state_in_percent) = $mh_state =~ /^[+|-]*(\d+)%$/;
                $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'on',
                    $state_in_percent . '%', '' );
            }
            elsif ( $mh_state eq 'motion' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'input', 'on', '',
                    $mh_state );
            }
            elsif ( $mh_state eq 'still' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'input', 'off', '',
                    $mh_state );
            }
            elsif ( $mh_state eq 'light' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'input', 'on', '',
                    $mh_state );
            }
            elsif ( $mh_state eq 'dark' ) {
                $bsc_obj->set_device( $bsc_id, $mh_state, 'input', 'off', '',
                    $mh_state );
            }
            else {
                print "Warning: unable to process state: $mh_state\n"
                  if $main::Debug{bsc};
                return;
            }
            if ( $msg_type eq 'send-event' ) {

                # now, send the data after removing any starting $ symbol
                $mh_obj_name =~ s/^\$//;
                $bsc_obj->send_event( DEVICE_TYPE_ABSTRACT, $mh_obj_name );
            }
            elsif ( $msg_type eq 'set-info' ) {

                # now, send the data after removing any starting $ symbol
                $mh_obj_name =~ s/^\$//;
                $bsc_obj->send_info( DEVICE_TYPE_ABSTRACT, $mh_obj_name );
            }
        }
        elsif ( $msg_type eq 'receive' ) {

            # now, construct the blocks that will be send
            my $pending_state = $$bsc_obj{pending_device_state}{$bsc_id};
            my $pending_state_mode =
              $$bsc_obj{pending_device_state_mode}{$bsc_id};
            my $bsc_state = $$pending_state{'State'};
            my $mh_state  = '';
            if ($bsc_state) {

                # TO-DO: the following logic attempts to set the mh obj state
                #        regardless if it has changed.  Need to revisit this and
                #        optionally only set state on changed state
                my $bsc_level = $$pending_state{'Level'};
                my $bsc_text  = $$pending_state{'Text'};
                if ( $mh_obj->isa(LIGHT_ITEM) ) {
                    if ($bsc_level) {

                        # TO-DO: need to validate this is a valid state
                        # TO-DO: translate to relate level for non preset types
                        $mh_obj->set( $bsc_level, $bsc_obj );
                        $mh_state = $bsc_level;
                    }
                    elsif ($bsc_text) {

                        # TO-DO: need to validate this is a valid state
                        # this probably shouldn't be used; except, we're currently passing
                        # preset codes in this fashion.  If used, then validation is really
                        # needed
                        $mh_obj->set( $bsc_text, $bsc_obj );
                        $mh_state = $bsc_text;
                    }
                    else {
                        $mh_state = lc $bsc_state;
                        $mh_obj->set( $mh_state, $bsc_obj );
                    }

                    # allows motion items to be externally controllable because they are abstract
                }
                elsif ( $mh_obj->isa(MOTION_ITEM) ) {
                    if ( lc $bsc_state eq 'on' ) {
                        $mh_state = 'motion';
                    }
                    else {
                        $mh_state = 'still';
                    }
                    $mh_obj->set( $mh_state, $bsc_obj );
                }
                if ($mh_state) {
                    $$pending_state{'RefState'} = $mh_state;

                    # "commit" the pending state data to the state data
                    $bsc_obj->commit_pending_state($bsc_id);
                }
            }
            else {
                print
                  "State for $mh_obj_name:$bsc_id is unset for incoming xAP BSC message!\n";
            }

            # be sure to set the 'RefState' hash member to whatever mh state gets mapped
        }
    }

}

sub _handle_presence {

    my ( $msg_type, $mh_obj_name, $bsc_obj_name ) = @_;
    my $mh_obj  = &main::get_object_by_name($mh_obj_name);
    my $bsc_obj = &main::get_object_by_name($bsc_obj_name);
    if ( defined($mh_obj) ) {

        # get a valid BSC ID
        # that should have been reserved at the point that the object was registered
        my $bsc_id =
          &xAP::get_xap_subaddress_uid( DEVICE_TYPE_PRESENCE, $mh_obj_name );
        if ( ( $msg_type eq 'send-event' ) or ( $msg_type eq 'set-info' ) ) {
            my $mh_state = $mh_obj->state_now()
              if ( $msg_type eq 'send-event' );
            $mh_state = $mh_obj->state()
              if ( $msg_type eq 'set-info' )
              ;    # probably need to parse out stacked state vals if they exist
            if ( $mh_obj->isa(PRESENCE_MONITOR) ) {
                my $room_count = $mh_obj->get_count();
                if ( $mh_state eq 'occupied' ) {
                    $room_count = 1
                      if $room_count == 0
                      ; # doesn't make much sense otherwise; perhaps a mistake in Presence_Monitor
                    $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'on',
                        '', "room_count=$room_count" );
                }
                elsif ( $mh_state eq 'predict' ) {
                    $room_count =
                      0;    # allowing -1 doesn't make much sense except to mh
                    $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'on',
                        '', "room_count=$room_count" );
                }
                elsif ( $mh_state eq 'vacant' ) {
                    $room_count = 0
                      ; # apparently, no room count exists if vacant and we want to report it always
                    $bsc_obj->set_device( $bsc_id, $mh_state, 'output', 'off',
                        '', "room_count=$room_count" );
                }
            }
            else {
                print "Warning: unable to process state: $mh_state\n"
                  if $main::Debug{bsc};
                return;
            }
            if ( $msg_type eq 'send-event' ) {

                # now, send the data after removing any starting $ symbol
                $mh_obj_name =~ s/^\$//;
                $bsc_obj->send_event( DEVICE_TYPE_PRESENCE, $mh_obj_name );
            }
            elsif ( $msg_type eq 'set-info' ) {

                # now, send the data after removing any starting $ symbol
                $mh_obj_name =~ s/^\$//;
                $bsc_obj->send_info( DEVICE_TYPE_PRESENCE, $mh_obj_name );
            }
        }
        elsif ( $msg_type eq 'receive' ) {

            # now, construct the blocks that will be send
            my $pending_state = $$bsc_obj{pending_device_state}{$bsc_id};
            my $pending_state_mode =
              $$bsc_obj{pending_device_state_mode}{$bsc_id};
            my $bsc_state = $$pending_state{'State'};
            my $mh_state  = '';
            if ($bsc_state) {

                # TO-DO: the following logic attempts to set the mh obj state
                #        regardless if it has changed.  Need to revisit this and
                #        optionally only set state on changed state
                my $bsc_level = $$pending_state{'Level'};
                my $bsc_text  = $$pending_state{'Text'};
                if ( $mh_obj->isa(PRESENCE_MONITOR) ) {
                    $mh_state = lc $bsc_state;
                    if ( $mh_state eq 'off' ) {
                        $mh_obj->set( 'vacant', $bsc_obj );
                    }
                    else {
                        my ($room_count) = $bsc_text =~ /room_count=(\d+)/;
                        if ( $room_count > 0 ) {
                            $mh_obj->set( 'occupied', $bsc_obj );
                        }
                        else {
                            $mh_obj->set( 'predict', $bsc_obj );
                        }
                        $mh_obj->set_count($room_count);
                    }
                }
                if ($mh_state) {
                    $$pending_state{'RefState'} = $mh_state;

                    # "commit" the pending state data to the state data
                    $bsc_obj->commit_pending_state($bsc_id);
                }
            }
            else {
                print
                  "State for $mh_obj_name:$bsc_id is unset for incoming xAP BSC message!\n";
            }

            # be sure to set the 'RefState' hash member to whatever mh state gets mapped
        }
    }

}

sub _convert_x10_id {
    my ($x10_id) = @_;
    my $id = '';
    if ( length($x10_id) == 2 ) {
        my ( $hcode, $ucode ) = $x10_id =~ /(.)(.)/;
        my %table_hcodes = qw(A 0  B 1  C 2  D 3  E 4  F 5  G 6  H 7
          I 8  J 9  K A  L B  M C  N D  O E  P F);
        my %table_ucodes = qw(1 0  2 1  3 2  4 3  5 4  6 5  7 6  8 7
          9 8  A 9  B A  C B  D C  E D  F E  G F);
        $id = $table_hcodes{$hcode} . $table_ucodes{$ucode};

        # we need to support A1 (since it's too common), but we can't permit
        # a map to '00'; so, convert to numeric, add 1 and then convert back to hex
        $id = sprintf( "%X", hex($id) + 1 );
        print "Converting hcode: $hcode and ucode: $ucode to hex id: $id\n"
          if $main::Debug{bsc};
    }
    return $id;
}

sub _init_object {
    my ( $self, $object_type, $virtual_device_name ) = @_;

    for my $name ( &::list_objects_by_type($object_type) ) {
        $self->register_obj( $name, $virtual_device_name );
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Gregg Liming
gregg@limings.net

Special Thanks to: Bruce Winter - MH

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

