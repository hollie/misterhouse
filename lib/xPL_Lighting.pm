
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

xPL_Lighting.pm - xPL support for the xPL lighting schema

Info:

 xPL websites:
   http://wiki.xplproject.org.uk/index.php/Schema_-_LIGHTING

License:
	This free software is licensed under the terms of the GNU public license.
Authors:
 Gregg Liming   gregg@limings.net

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package xPL_LightGateway;

@xPL_LightGateway::ISA = ('xPL_Item');

sub new {
    my ( $class, $source ) = @_;
    my $self = $class->SUPER::new($source);
    $self->SUPER::class_name('lighting.*');
    @{ $$self{'valve_id_list'} } = ();
    @{ $$self{'queue_id_list'} } = ();
    $self->restore_data('preferred_network_id');    # keep track

    return $self;
}

sub preferred_network_id {
    my ($self) = @_;
    return $$self{preferred_network_id};
}

sub device_id_list {
    my ($self) = @_;
    return @{ $$self{device_id_list} };
}

sub request_stat {
    my ( $self, $request_all ) = @_;
    $self->SUPER::send_cmnd(
        'lighting.request' => { 'request' => 'gateinfo' } );
    if ($request_all) {
        for my $light ( $self->find_members('xPL_Light') ) {
            if ($light) {
                $light->request_stat();
            }
        }
    }
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    if ( $set_by =~ /^xpl/i ) {
        if ( $$self{changed} =~ /lighting\.gateinfo/ ) {
            &::print_log(
                    "[xPL_LightGateway] Received lighting.gateinfo message."
                  . " Preferred network id= "
                  . $$self{'lighting.gateinfo'}{'preferred-net'} )
              if $main::Debug{xpl_light};
            $$self{'preferred-net'} =
              $$self{'lighting.gateinfo'}{'preferred-net'};

            # send out a request to get info about the supported device list
            $self->SUPER::send_cmnd(
                'lighting.request' => { 'request' => 'devlist' } );
        }
        elsif ( $$self{changed} =~ /lighting\.devlist/ ) {
            &::print_log(
                "[xPL_LightGateway] Received lighting.devlist message: status "
                  . $$self{'lighting.devlist'}{status} )
              if $main::Debug{xpl_light};
            if ( $$self{'lighting.devlist'}{'device'} ) {
                my @list = split( /,/, $$self{'lighting.devlist'}{'device'} );
                @{ $$self{'device_id_list'} } =
                  ( @{ $$self{'device_id_list'} }, @list );
            }
        }
        elsif ( $$self{changed} =~ /lighting\.netlist/ ) {
            &::print_log("[xPL_LightGateway] Received lighting.netlist message")
              if $main::Debug{xpl_light};
        }
        elsif ( $$self{changed} =~ /lighting\.netinfo/ ) {
            &::print_log("[xPL_LightGateway] Received lighting.netinfo message")
              if $main::Debug{xpl_light};
        }
        elsif ( $$self{changed} =~ /lighting\.gateway/ ) {
            &::print_log("[xPL_LightGateway] Received lighting.gateway message")
              if $main::Debug{xpl_light};
        }
    }
    else {
        &::print_log(
            "[xPL_LightGateway] WARN: Gateway state may not be explicitely set.  Ignoring."
        ) if $main::Debug{xpl_light};

        # return a -1 if not changed by xpl so that state is not revised until receipt of gateinfo
        return -1;
    }
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_message = 0;
    if (
        !(
               defined( $$p_data{'lighting.gateinfo'} )
            or defined( $$p_data{'lighting.gateway'} )
            or defined( $$p_data{'lighting.devlist'} )
            or defined( $$p_data{'lighting.netinfo'} )
            or defined( $$p_data{'lighting.netlist'} )
        )
      )
    {
        $ignore_message = 1;
    }
    return $ignore_message;
}

sub add {
    my ( $self, @p_objects ) = @_;

    my @l_objects;

    for my $l_object (@p_objects) {
        if ( $l_object->isa('Group_Item') ) {
            @l_objects = $$l_object{members};
            for my $obj (@l_objects) {
                $self->add($obj);
            }
        }
        else {
            $self->add_item($l_object);
        }
    }
}

sub add_item {
    my ( $self, $p_object ) = @_;
    push @{ $$self{objects} }, $p_object;
    return $p_object;
}

sub remove_all_items {
    my ($self) = @_;

    if ( ref $$self{objects} ) {
        foreach ( @{ $$self{objects} } ) {

            #        $_->untie_items($self);
        }
    }
    delete $self->{objects};
}

sub add_item_if_not_present {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{objects} ) {
        foreach ( @{ $$self{objects} } ) {
            if ( $_ eq $p_object ) {
                return 0;
            }
        }
    }
    $self->add_item($p_object);
    return 1;
}

sub remove_item {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{objects} ) {
        for ( my $i = 0; $i < scalar( @{ $$self{objects} } ); $i++ ) {
            if ( $$self{objects}->[$i] eq $p_object ) {
                splice @{ $$self{objects} }, $i, 1;

                #           $p_object->untie_items($self);
                return 1;
            }
        }
    }
    return 0;
}

sub is_member {
    my ( $self, $p_object ) = @_;

    my @l_objects = @{ $$self{objects} };
    for my $l_object (@l_objects) {
        if ( $l_object eq $p_object ) {
            return 1;
        }
    }
    return 0;
}

sub find_members {
    my ( $self, $p_type ) = @_;

    my @l_found;
    my @l_objects = @{ $$self{objects} };
    for my $l_object (@l_objects) {
        if ( $l_object->isa($p_type) ) {
            push @l_found, $l_object;
        }
    }
    return @l_found;
}

package xPL_Light;

@xPL_Light::ISA = ('xPL_Item');

sub new {
    my ( $class, $id, $gateway ) = @_;
    my $self = $class->SUPER::new( $gateway->source );
    $$self{gateway} = $gateway;
    $gateway->add_item_if_not_present($self);
    $self->SUPER::class_name('lighting.dev*');
    $$self{id}            = $id;
    $$self{state_monitor} = "lighting.devinfo : level|lighting.device : level";
    $self->SUPER::device_monitor("device=$id") if $id;

    # remap the state values to on and off
    $self->tie_value_convertor( 'level',
        '($section =~ /^lighting\.dev/ and $value eq "0") ? "off" : "$value"' );

    $self->state_overload('on');
    $self->restore_data('ramp_rate');    # keep track

    return $self;
}

sub request_stat {
    my ($self) = @_;
    $self->SUPER::send_cmnd( 'lighting.request' => { 'request' => 'devinfo' } );
}

sub id {
    my ($self) = @_;
    return $$self{id};
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_message = 0;
    if (
        !(
            (
                defined( $$p_data{'lighting.devinfo'} )
                and $$p_data{'lighting.devinfo'}{'device'} eq $self->id
            )
            or ( defined( $$p_data{'lighting.device'} )
                and $$p_data{'lighting.device'}{'device'} eq $self->id )
        )
      )
    {
        $ignore_message = 1;
    }
    return $ignore_message;
}

sub ramp_rate {
    my ( $self, $ramp_rate ) = @_;
    $$self{ramp_rate} = $ramp_rate if $ramp_rate;
    return $$self{ramp_rate};
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    if ( $set_by =~ /^xpl/i ) {
        if ( $$self{changed} =~ /lighting\.devinfo/ ) {
            &::print_log( "[xPL_Light] light: "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{xpl_light};

            # TO-DO: process all of the other pertinent attributes available
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
        elsif ( $$self{changed} =~ /lighting\.device/ ) {
            &::print_log( "[xPL_Light] light: "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{xpl_light};

            # TO-DO: process all of the other pertinent attributes available
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
    }
    else {
        my $level = '0';
        if ( $state =~ /^\d+/ ) {
            ($level) = $state =~ /^(\d+)%/;    # strip of any percentage sign
        }
        elsif ( $state =~ /^on/i ) {
            $level = '100';
        }
        elsif ( $state =~ /^off/i ) {
            $level = '0';
        }
        elsif ( $state eq 'default' or $state eq 'last' ) {
            $level = $state;
        }
        &::print_log( "[xPL_Light] Request light: "
              . $self->get_object_name
              . " turn "
              . ( ( $level eq '0' ) ? 'off' : "on at a level of $level" ) )
          if $main::Debug{xpl_light};
        my $cmd_block;
        $$cmd_block{'command'} = 'goto';
        $$cmd_block{'device'}  = $self->id;
        $$cmd_block{'level'}   = $level;
        $$cmd_block{'fade-rate'} =
          ( $self->ramp_rate ) ? $self->ramp_rate : 'default';
        $self->SUPER::send_cmnd( 'lighting.basic', $cmd_block );
        return;
    }

}

1;
