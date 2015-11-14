
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

xPL_Security.pm - xPL support for the xPL security schema

Info:

 xPL websites:
   http://xplproject.org.uk/wiki/index.php/Schema_-_SECURITY

License:
	This free software is licensed under the terms of the GNU public license.
Authors:
 Greg Satz   satz@iranger.com
 Gregg Liming   gregg@limings.net

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package xPL_SecurityGateway;

@xPL_SecurityGateway::ISA = ('xPL_Item');

sub new {
    my ( $class, $source ) = @_;
    my $self = $class->SUPER::new($source);
    $self->SUPER::class_name('security.*');
    @{ $$self{'zone_id_list'} } = ();
    @{ $$self{'area_id_list'} } = ();
    $$self{'zone_count'}       = 0;
    $$self{'area_count'}       = 0;
    $$self{'gateway_commands'} = "";
    $$self{'zone_commands'}    = "";
    $$self{'area_commands'}    = "";
    $self->restore_data('ac_status');         # keep track
    $self->restore_data('battery_status');    # keep track
    $self->restore_data('alarm_status');      # keep track

    return $self;
}

sub ac_status {
    my ($self) = @_;
    return $$self{ac_status};
}

sub battery_status {
    my ($self) = @_;
    return $$self{battery_status};
}

sub alarm_status {
    my ($self) = @_;
    return $$self{alarm_status};
}

sub zone_id_list {
    my ($self) = @_;
    return @{ $$self{zone_id_list} };
}

sub area_id_list {
    my ($self) = @_;
    return @{ $$self{area_id_list} };
}

sub request_stat {
    my ( $self, $request_all ) = @_;
    $self->SUPER::send_cmnd(
        'security.request' => { 'request' => 'gateinfo' } );
    if ($request_all) {
        for my $zone ( $self->find_members('xPL_Zone') ) {
            if ($zone) {
                $zone->request_stat();
            }
        }
        for my $area ( $self->find_members('xPL_Area') ) {
            if ($area) {
                $area->request_stat();
            }
        }
    }
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    if ( $set_by =~ /^xpl/i ) {
        if ( $$self{changed} =~ /security\.gateinfo/ ) {
            $$self{'zone_count'} = $$self{'security.gateinfo'}{'zone-count'};
            $$self{'area_count'} = $$self{'security.gateinfo'}{'area-count'};
            $$self{'gateway_commands'} =
              $$self{'security.gateinfo'}{'gateway-commands'};
            $$self{'zone_commands'} =
              $$self{'security.gateinfo'}{'zone-commands'};
            $$self{'area_commands'} =
              $$self{'security.gateinfo'}{'area-commands'};
            &::print_log(
                    "[xPL_SecurityGateway] Received security.gateinfo message."
                  . " Zone Count= "
                  . $$self{'zone_count'}
                  . " Area Count= "
                  . $$self{'area_count'} )
              if $main::Debug{xpl_security};

            # send out a request to get info about the supported zone list
            if ( $$self{'zone_count'} > 0 ) {
                $self->SUPER::send_cmnd(
                    'security.request' => { 'request' => 'zonelist' } );
            }
            elsif ( $$self{'area_count'} > 0 ) {
                $self->SUPER::send_cmnd(
                    'security.request' => { 'request' => 'arealist' } );
            }
            else {
                $self->SUPER::send_cmnd(
                    'security.request' => { 'request' => 'gatestat' } );
            }
        }
        elsif ( $$self{changed} =~ /security\.zonelist/ ) {
            &::print_log(
                "[xPL_SecurityGateway] Received security.zonelist message")
              if $main::Debug{xpl_security};
            if ( $$self{'security.zonelist'}{'zone-list'} ) {
                my @list =
                  split( /,/, $$self{'security.zonelist'}{'zone-list'} );
                @{ $$self{'zone_id_list'} } =
                  ( @{ $$self{'zone_id_list'} }, @list );
                print "zone_id_list size is "
                  . @{ $$self{'zone_id_list'} } . "\n";
            }
            if ( $$self{'area_count'} > 0 ) {
                $self->SUPER::send_cmnd(
                    'security.request' => { 'request' => 'arealist' } );
            }
            else {
                $self->SUPER::send_cmnd(
                    'security.request' => { 'request' => 'gatestat' } );
            }
        }
        elsif ( $$self{changed} =~ /security\.arealist/ ) {
            &::print_log(
                "[xPL_SecurityGateway] Received security.arealist message")
              if $main::Debug{xpl_security};
            if ( $$self{'security.arealist'}{'area-list'} ) {
                my @list =
                  split( /,/, $$self{'security.arealist'}{'area-list'} );
                @{ $$self{'area_id_list'} } =
                  ( @{ $$self{'area_id_list'} }, @list );
            }
            $self->SUPER::send_cmnd(
                'security.request' => { 'request' => 'gatestat' } );
        }
        elsif ( $$self{changed} =~ /security\.gatestat/ ) {
            &::print_log(
                "[xPL_SecurityGateway] Received security.gatestat message")
              if $main::Debug{xpl_security};
            $$self{'ac_status'} = $$self{'security.gatestat'}{'ac-fail'};
            $$self{'battery_status'} =
              $$self{'security.gatestat'}{'low-battery'};
            $$self{'alarm_status'} = $$self{'security.gatestat'}{'status'};
        }
        elsif ( $$self{changed} =~ /security\.zoneinfo/ ) {
            &::print_log(
                "[xPL_SecurityGateway] Received security.zoneinfo message")
              if $main::Debug{xpl_security};
        }
        elsif ( $$self{changed} =~ /security\.areainfo/ ) {
            &::print_log(
                "[xPL_SecurityGateway] Received security.areainfo message")
              if $main::Debug{xpl_security};
        }
        elsif ( $$self{changed} =~ /security\.zonestat/ ) {
            &::print_log(
                "[xPL_SecurityGateway] Received security.zonestat message")
              if $main::Debug{xpl_security};
        }
        elsif ( $$self{changed} =~ /security\.areastat/ ) {
            &::print_log(
                "[xPL_SecurityGateway] Received security.areastat message")
              if $main::Debug{xpl_security};
        }
    }
    else {
        &::print_log(
            "[xPL_SecurityGateway] WARN: Gateway state may not be explicitely set.  Ignoring."
        ) if $main::Debug{xpl_security};

        # return a -1 if not changed by xpl so that state is not revised until receipt of gateinfo
        return -1;
    }
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_message = 0;
    if (
        !(
               defined( $$p_data{'security.gateinfo'} )
            or defined( $$p_data{'security.zonelist'} )
            or defined( $$p_data{'security.arealist'} )
            or defined( $$p_data{'security.zoneinfo'} )
            or defined( $$p_data{'security.areainfo'} )
            or defined( $$p_data{'security.gatestat'} )
            or defined( $$p_data{'security.zonestat'} )
            or defined( $$p_data{'security.areastat'} )
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

package xPL_Zone;

@xPL_Zone::ISA = ('xPL_Item');

sub new {
    my ( $class, $id, $gateway ) = @_;
    my $self = $class->SUPER::new( $gateway->source );
    $$self{gateway} = $gateway;
    $gateway->add_item_if_not_present($self);
    $self->SUPER::class_name('security.zone*');
    $$self{id} = $id;
    $$self{state_monitor} =
      "security.zonestat : armed|security.zonestat : alert|security.zonestat : alarm|security.zone : event";
    $self->SUPER::device_monitor("zone=$id") if $id;

    $self->state_overload('off');

    return $self;
}

sub request_stat {
    my ($self) = @_;
    $self->SUPER::send_cmnd(
        'security.request' => { 'request' => 'zonestat' } );
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
                defined( $$p_data{'security.zonestat'} )
                and $$p_data{'security.zonestat'}{'zone'} eq $self->id
            )
            or ( defined( $$p_data{'security.zone'} )
                and $$p_data{'security.zone'}{'zone'} eq $self->id )
        )
      )
    {
        $ignore_message = 1;
    }
    return $ignore_message;
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    if ( $set_by =~ /^xpl/i ) {
        if ( $$self{changed} =~ /security\.zonestat/ ) {
            &::print_log( "[xPL_Security] security zone status: "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{xpl_security};

            # TO-DO: process all of the other pertinent attributes available
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
        elsif ( $$self{changed} =~ /security\.zone/ ) {
            &::print_log( "[xPL_Security] security zone : "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{xpl_security};

            # TO-DO: process all of the other pertinent attributes available
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
    }
}

package xPL_Area;

@xPL_Area::ISA = ('xPL_Item');

sub new {
    my ( $class, $id, $gateway ) = @_;
    my $self = $class->SUPER::new( $gateway->source );
    $$self{gateway} = $gateway;
    $gateway->add_item_if_not_present($self);
    $self->SUPER::class_name('security.area*');
    $$self{id} = $id;
    $$self{state_monitor} =
      "security.areastat : armed|security.areastat : alert|security.areastat : alarm|security.area : event";
    $self->SUPER::device_monitor("area=$id") if $id;

    $self->state_overload('off');

    return $self;
}

sub request_stat {
    my ($self) = @_;
    $self->SUPER::send_cmnd(
        'security.request' => { 'request' => 'areastat' } );
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
                defined( $$p_data{'security.areastat'} )
                and $$p_data{'security.areastat'}{'area'} eq $self->id
            )
            or ( defined( $$p_data{'security.device'} )
                and $$p_data{'security.area'}{'area'} eq $self->id )
        )
      )
    {
        $ignore_message = 1;
    }
    return $ignore_message;
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    if ( $set_by =~ /^xpl/i ) {
        if ( $$self{changed} =~ /security\.areastat/ ) {
            &::print_log( "[xPL_Security] security area stat: "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{xpl_security};

            # TO-DO: process all of the other pertinent attributes available
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
        elsif ( $$self{changed} =~ /security\.area/ ) {
            &::print_log( "[xPL_Security] security area: "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{xpl_security};

            # TO-DO: process all of the other pertinent attributes available
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
    }
}

1;
