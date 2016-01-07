
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

xPL_Irrigation.pm - xPL support for the xPL sprinkler schema

Info:

 xPL websites:
    http://www.rgbled.org/sprinkler/sprinkler/docs/sprinkler.schema

License:
	This free software is licensed under the terms of the GNU public license.
Authors:
 Gregg Liming   gregg@limings.net

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package xPL_IrrigationGateway;

@xPL_IrrigationGateway::ISA = ('xPL_Item');

sub new {
    my ( $class, $source ) = @_;
    my $self = $class->SUPER::new($source);
    $self->SUPER::class_name('sprinklr.*');
    $$self{'pump_is_running'} = 0;    # assume it is not running
    @{ $$self{'valve_id_list'} } = ();
    @{ $$self{'queue_id_list'} } = ();
    $self->restore_data( 'pump_is_running', 'default_queue_id' );   # keep track

    return $self;
}

sub default_queue_id {
    my ($self) = @_;
    return $$self{default_queue_id};
}

sub valve_id_list {
    my ($self) = @_;
    return @{ $$self{valve_id_list} };
}

sub queue_id_list {
    my ($self) = @_;
    my @list = ();
    if ( $$self{'sprinklr.gateinfo'}{'queue-id-list'} ) {
        @list = split( /,/, $$self{'sprinklr.gateinfo'}{'queue-id-list'} );
    }
    return @list;
}

sub get_queue {
    my ( $self, $queue_id ) = @_;
    for my $queue ( $self->find_members('xPL_IrrigationQueue') ) {
        if ( $queue and $queue->id eq $queue_id ) {
            return $queue;
        }
    }

    # if we got this far, then no queue exists
    my $new_queue = xPL_IrrigationQueue->new( $queue_id, $self );

    # persist the newly created item
    &main::store_object_data(
        $new_queue, 'xPL_IrrigationQueue',
        'IrrigationQueue' . $queue_id,
        'IrrigationQueue' . $queue_id
    );
    $self->add_item_if_not_present($new_queue);
    return $new_queue;
}

sub get_default_queue {
    my ($self) = @_;
    if ( !( defined $self->default_queue_id ) ) {
        $$self{default_queue_id} = '0'; # invent one; this should never happen!!
        &::print_log(
            "[xPL_IrrigationGateway] WARN: automatically creating a new default queue id of "
              . $self->default_queue_id );
    }
    return $self->get_queue( $self->default_queue_id );
}

sub request_stat {
    my ( $self, $request_all ) = @_;
    $self->SUPER::send_cmnd(
        'sprinklr.request' => { 'request' => 'gateinfo' } );
    if ($request_all) {
        for my $valve ( $self->find_members('xPL_IrrigationValve') ) {
            if ($valve) {
                $valve->request_stat();
            }
        }
    }
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    if ( $set_by =~ /^xpl/i ) {
        if ( $$self{changed} =~ /sprinklr\.gateinfo/ ) {
            &::print_log(
                "[xPL_IrrigationGateway] Received sprinklr.gateinfo message."
                  . " Default queue id= "
                  . $$self{'sprinklr.gateinfo'}{'default-queue-id'} )
              if $main::Debug{irrigation};
            $$self{'default_queue_id'} =
              $$self{'sprinklr.gateinfo'}{'default-queue-id'};
            if ( $$self{'sprinklr.gateinfo'}{'valve-id-list'} ) {
                my @list =
                  split( /,/, $$self{'sprinklr.gateinfo'}{'valve-id-list'} );
                @{ $$self{'valve_id_list'} } = @list;
            }
            if ( $$self{'sprinklr.gateinfo'}{'queue-id-list'} ) {
                my @list =
                  split( /,/, $$self{'sprinklr.gateinfo'}{'queue-id-list'} );
                @{ $$self{'queue_id_list'} } = @list;
            }
            $self->SUPER::send_cmnd(
                'sprinklr.request' => { 'request' => 'pumpinfo' } );
        }
        elsif ( $$self{changed} =~ /sprinklr\.pumpinfo/ ) {
            &::print_log(
                "[xPL_IrrigationGateway] Received sprinkler.pumpinfo message: pump is "
                  . $$self{'sprinklr.pumpinfo'}{state} )
              if $main::Debug{irrigation};
            $$self{pump_is_running} =
              ( $$self{'sprinklr.pumpinfo'}{state} =~ /^running/i ) ? 1 : 0;
        }
        elsif ( $$self{changed} =~ /sprinkler\.gateway/ ) {
            &::print_log(
                "[xPL_IrrigationGateway] Received sprinkler.gateway message")
              if $main::Debug{irrigation};
        }
        elsif ( $$self{changed} =~ /sprinklr\.pump/ ) {
            &::print_log(
                "[xPL_IrrigationGateway] Received sprinkler.pump message: pump is "
                  . $$self{'sprinklr.pump'}{state} )
              if $main::Debug{irrigation};
            $$self{pump_is_running} =
              ( $$self{'sprinklr.pump'}{state} =~ /^running/i ) ? 1 : 0;
        }
        elsif ( $$self{changed} =~ /sprinklr\.vrequest/ ) {
            my $queue_id      = $$self{'sprinklr.vrequest'}{'queue-id'};
            my $request_index = $$self{'sprinklr.vrequest'}{'request-index'};
            my $action        = $$self{'sprinklr.vrequest'}{'action'};
            my $valve_id      = $$self{'sprinklr.vrequest'}{'valve-id'};
            my $run_minutes   = $$self{'sprinklr.vrequest'}{'run-minutes'};
            my $remaining_minutes =
              $$self{'sprinklr.vrequest'}{'remaining-minutes'};

            &::print_log(
                "[xPL_IrrigationGateway] Received sprinklr.vrequest message."
                  . " queue_id=$queue_id, request_index=$request_index, action=$action,"
                  . " valve_id=$valve_id, run_minutes=$run_minutes, remaining_minutes=$remaining_minutes"
            ) if $main::Debug{irrigation};

        }
        elsif ( $$self{changed} =~ /sprinklr\.rqstinfo/ ) {
            &::print_log(
                "[xPL_IrrigationGateway] Received sprinkler.rqstinfo message")
              if $main::Debug{irrigation};
        }
    }
    else {
        &::print_log(
            "[xPL_IrrigationGateway] WARN: Gateway state may not be explicitely set.  Ignoring."
        ) if $main::Debug{irrigation};

        # return a -1 if not changed by xpl so that state is not revised until receipt of gateinfo
        return -1;
    }
}

sub pump_is_running {
    my ($self) = @_;
    return $$self{pump_is_running};
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_message = 0;
    if (
        !(
               defined( $$p_data{'sprinklr.gateinfo'} )
            or defined( $$p_data{'sprinklr.pump'} )
            or defined( $$p_data{'sprinklr.gate'} )
            or defined( $$p_data{'sprinklr.pumpinfo'} )
            or defined( $$p_data{'sprinklr.vrequest'} )
            or defined( $$p_data{'sprinklr.rqstinfo'} )
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

sub queue_request {
    my ( $self, $valve, $run_time, $queue_id ) = @_;
    my $queue =
      ( defined $queue_id )
      ? $self->get_queue($queue_id)
      : $self->get_default_queue;
    $queue->queue_request( $valve, $run_time );
}

sub clear_queue {
    my ( $self, $queue_id ) = @_;
    my $queue =
      ( defined $queue_id )
      ? $self->get_queue($queue_id)
      : $self->get_default_queue;
    $queue->clear();
}

sub hold_queue {
    my ( $self, $queue_id ) = @_;
    my $queue =
      ( defined $queue_id )
      ? $self->get_queue($queue_id)
      : $self->get_default_queue;
    $queue->hold();
}

sub release_queue {
    my ( $self, $queue_id ) = @_;
    my $queue =
      ( defined $queue_id )
      ? $self->get_queue($queue_id)
      : $self->get_default_queue;
    $queue->release();
}

package xPL_IrrigationValve;

@xPL_IrrigationValve::ISA = ('xPL_Item');

sub new {
    my ( $class, $id, $gateway ) = @_;
    my $self = $class->SUPER::new( $gateway->source );
    $$self{gateway} = $gateway;
    $gateway->add_item_if_not_present($self);
    $self->SUPER::class_name('sprinklr.valv*');
    $$self{id}            = $id;
    $$self{state_monitor} = "sprinklr.valvinfo : state|sprinklr.valve : action";
    $self->SUPER::device_monitor("valve-id=$id") if defined $id;

    # remap the state values to on and off
    $self->tie_value_convertor( 'state',
        '($section eq "sprinklr.valvinfo" and $value eq "closed") ? "off" : "on"'
    );
    $self->tie_value_convertor( 'action',
        '($section eq "sprinklr.valve" and $value eq "closed") ? "off" : "on"'
    );

    $self->state_overload('on');

    return $self;
}

sub request_stat {
    my ($self) = @_;
    $self->SUPER::send_cmnd(
        'sprinklr.request' => { 'request' => 'valvinfo' } );
}

sub id {
    my ($self) = @_;
    return $$self{id};
}

sub default_run_time {
    my ( $self, $p_run_time ) = @_;
    $$self{default_run_time} = $p_run_time if $p_run_time;
    return $$self{default_run_time};
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_message = 0;
    if (
        !(
            (
                defined( $$p_data{'sprinklr.valvinfo'} )
                and $$p_data{'sprinklr.valvinfo'}{'valve-id'} eq $self->id
            )
            or ( defined( $$p_data{'sprinklr.valve'} )
                and $$p_data{'sprinklr.valve'}{'valve-id'} eq $self->id )
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
        if ( $$self{changed} =~ /sprinklr\.valvinfo/ ) {
            &::print_log( "[xPL_IrrigationValve] valve: "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{irrigation};
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
        elsif ( $$self{changed} =~ /sprinklr\.valve/ ) {
            &::print_log( "[xPL_IrrigationValve] valve: "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{irrigation};
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
    }
    else {
        if ( $state =~ /^\d+/ ) {
            if ($substate) {
                &::print_log( "[xPL_IrrigationValve] Request valve: "
                      . $self->get_object_name
                      . " queued for $state minutes on queue: $substate" )
                  if $main::Debug{irrigation};
                $$self{gateway}->queue_request( $self, $state, $substate );
            }
            else {
                &::print_log( "[xPL_IrrigationValve] Request valve: "
                      . $self->get_object_name
                      . " queued for $state minutes on default queue" )
                  if $main::Debug{irrigation};
                $$self{gateway}->queue_request( $self, $state );
            }
        }
        elsif ( $state =~ /^on/i ) {

            # TO-DO;  this is a bit more difficult since it involves locating the active
            #    request and deleting it from it's queue
            if ( $self->default_run_time ) {
                &::print_log( "[xPL_IrrigationValve] Request valve: "
                      . $self->get_object_name
                      . " queued for (default) "
                      . $self->default_run_time
                      . " minutes on default queue" )
                  if $main::Debug{irrigation};
                $$self{gateway}
                  ->queue_request( $self, $self->default_run_time );
            }
            else {
                &::print_log( "[xPL_IrrigationValve] Request valve: "
                      . $self->get_object_name
                      . " queued for gateway default run time on default queue"
                ) if $main::Debug{irrigation};
                $$self{gateway}->queue_request($self);
            }
        }
        elsif ( $state =~ /^off/i ) {

            # TO-DO;  this is a bit more difficult since it involves locating the active
            #    request and deleting it from it's queue
            &::print_log(
                "[xPL_IrrigationValve] WARN: Unable to support off state.  Request is ignored."
            ) if $main::Debug{irrigation};
        }

        # return a -1 if not changed by xpl so that state is not revised until receipt of gateinfo
        return -1;
    }

}

package xPL_IrrigationQueue;

@xPL_IrrigationQueue::ISA = ('xPL_Item');

sub new {
    my ( $class, $id, $gateway ) = @_;
    my $self = $class->SUPER::new( $gateway->source );
    $$self{gateway} = $gateway;
    $gateway->add_item_if_not_present($self);
    $self->SUPER::class_name('sprinklr.que*');
    $$self{id}                   = $id;
    $$self{queued_request_count} = 0;

    # default the default run time as 5 minutes; possibly this should be longer?
    $$self{default_run_time} = 5;
    $$self{state_monitor} = "sprinklr.queinfo : state|sprinklr.queue : action";
    $self->SUPER::device_monitor("queue-id=$id") if defined $id;

    $self->state_overload('on');

    return $self;
}

sub request_stat {
    my ($self) = @_;
    $self->SUPER::send_cmnd( 'sprinklr.request' => { 'request' => 'queinfo' } );
}

sub id {
    my ($self) = @_;
    return $$self{id};
}

sub queued_request_count {
    my ($self) = @_;
    return $$self{queue_request_count};
}

sub default_run_time {
    my ( $self, $p_run_time ) = @_;
    $$self{default_run_time} = $p_run_time if $p_run_time;
    return $$self{default_run_time};
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_message = 0;
    if (
        !(
            (
                defined( $$p_data{'sprinklr.queinfo'} )
                and $$p_data{'sprinklr.queinfo'}{'queue-id'} eq $self->id
            )
            or ( defined( $$p_data{'sprinklr.queue'} )
                and $$p_data{'sprinklr.queue'}{'queue-id'} eq $self->id )
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
        if ( $$self{changed} =~ /sprinklr\.queinfo/ ) {
            my $prior_request_count = $self->queued_request_count;
            $$self{queued_request_count} =
              $$self{'sprinklr.queinfo'}{'request-count'};
            return -1
              if ( $self->state eq $state )
              and ( $prior_request_count == $$self{queued_request_count} );
        }
        elsif ( $$self{changed} =~ /sprinklr\.queue/ ) {
            my $prior_request_count = $self->queued_request_count;
            $$self{queued_request_count} =
              $$self{'sprinklr.queue'}{'request-count'};
            return -1
              if ( $self->state eq $state )
              and ( $prior_request_count == $$self{queued_request_count} );
        }
    }
    else {
        # return a -1 if not changed by xpl so that state is not revised until receipt of gateinfo
        return -1;
    }

}

sub queue_request {
    my ( $self, $valve, $run_time ) = @_;
    my $cmd_block;
    $$cmd_block{'command'}  = 'QUEUE-REQUEST';
    $$cmd_block{'valve-id'} = $valve->id;
    $$cmd_block{'run-minutes'} =
      ($run_time) ? $run_time : $$self{default_run_time};
    $$cmd_block{'queue-id'} = $self->id;
    $self->SUPER::send_cmnd( 'sprinklr.basic', $cmd_block );
}

sub clear {
    my ($self) = @_;
    my $cmd_block = {};
    $$cmd_block{'command'}  = 'CLEAR-QUEUE';
    $$cmd_block{'queue-id'} = $self->id;
    &::print_log(
        "[xPL_IrrigationQueue] Received request to clear queue: " . $self->id )
      if $main::Debug{irrigation};
    $self->SUPER::send_cmnd( 'sprinklr.basic', $cmd_block );
}

sub hold {
    my ($self) = @_;
    my $cmd_block = {};
    $$cmd_block{'command'}  = 'HOLD-QUEUE';
    $$cmd_block{'queue-id'} = $self->id;
    &::print_log(
        "[xPL_IrrigationQueue] Received request to hold queue: " . $self->id )
      if $main::Debug{irrigation};
    $self->SUPER::send_cmnd( 'sprinklr.basic', $cmd_block );
}

sub release {
    my ($self) = @_;
    my $cmd_block = {};
    $$cmd_block{'command'}  = 'RELEASE-QUEUE';
    $$cmd_block{'queue-id'} = $self->id;
    &::print_log( "[xPL_IrrigationQueue] Received request to release queue: "
          . $self->id )
      if $main::Debug{irrigation};
    $self->SUPER::send_cmnd( 'sprinklr.basic', $cmd_block );
}

1;
