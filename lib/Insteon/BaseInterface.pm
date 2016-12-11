
=head1 B<Insteon::BaseInterface>

=head2 SYNOPSIS

Provides support for the Insteon Interface.

=head2 INHERITS

L<Class::Singleton|Class::Singleton>

=head2 METHODS

=over

=cut

package Insteon::BaseInterface;

use strict;
use Insteon::Message;
@Insteon::BaseInterface::ISA = ('Class::Singleton');

=item C<check_for_data>

Locates the active_interface from the main Insteon class and calls 
C<check_for_data> on it.  Called once per loop to get data from the PLM.

=cut

sub check_for_data {
    my $interface = &Insteon::active_interface();
    $interface->check_for_data();
}

=item C<poll_all>

Called at startup.  Will always request and print the plm_info, which 
contains the PLM revision number, to the log on startup.

If Insteon_PLM_scan_at_startup is set to 1 in the ini file, this routine will poll
all insteon devices and request their current state.  Useful for making sure that
no devices changed their state while MisterHouse was off.  Will also call 
L<Insteon::BaseObject::get_engine_version|Insteon::BaseInsteon/Insteon::BaseObject> on each device to ensure that
the proper ALDB object is created for them.

=cut

sub poll_all {
    my $scan_at_startup = $main::config_parms{Insteon_PLM_scan_at_startup};
    $scan_at_startup = 1 unless defined $scan_at_startup;
    if ( $scan_at_startup && $main::Save{mh_exit} ne 'normal' ) {
        ::print_log(
                "[Insteon] Skipping startup scan because MisterHouse did not "
              . "exit cleanly." );
        $scan_at_startup = 0;
    }
    my $plm = &Insteon::active_interface();
    if ( defined $plm ) {
        if ( !( $plm->device_id ) and !( $$plm{_id_check} ) ) {
            $$plm{_id_check} = 1;
            $plm->queue_message(
                new Insteon::InsteonMessage( 'plm_info', $plm ) );
        }
        if ($scan_at_startup) {

            for my $insteon_device (
                &Insteon::find_members('Insteon::BaseDevice') )
            {
                if (    $insteon_device
                    and $insteon_device->is_root
                    and $insteon_device->is_responder )
                {
                    # don't request status for objects associated w/ other than the primary group
                    #    as they are psuedo links
                    $insteon_device->get_engine_version();
                    $insteon_device->request_status();
                }
            }
        }
    }
}

=item C<new()>

Instantiate a new object.

=cut

sub new {
    my ($class) = @_;

    my $self = {};
    @{ $$self{command_stack2} }  = ();
    @{ $$self{command_history} } = ();
    $$self{received_commands} = {};
    bless $self, $class;
    $self->transmit_in_progress(0);

    #   	$self->debug(0) unless $self->debug;
    return $self;
}

=item C<equals([object])>

Returns 1 if object is the same as $self, otherwise returns 0.

=cut

sub equals {
    my ( $self, $compare_object ) = @_;

    # make sure that the compare_object is legitimate
    return 0
      unless $compare_object
      && ref $compare_object
      && $compare_object->isa('Insteon::BaseInterface');
    return 1 if $compare_object eq $self;

    # if they don't both have device_ids then treat them as identical
    return 1 unless $compare_object->device_id && $self->device_id;
    if ( $compare_object->device_id eq $self->device_id ) {
        return 1;
    }
    else {
        return 0;
    }
}

=item C<debuglevel([level])>

Returns 1 if Insteon or this device is at least debug level 'level', otherwise returns 0.

=cut

sub debuglevel {
    my ( $self, $debug_level, $debug_group ) = @_;
    return Generic_Item::debuglevel( $self, $debug_level, $debug_group );
}

=item C<_is_duplicate(cmd)>

Returns true if cmd already exists in the command stack.

=cut

sub _is_duplicate {
    my ( $self, $cmd ) = @_;
    return 1
      if ( $self->active_message
        && $self->active_message->interface_data eq $cmd );
    my $duplicate_detected = 0;

    # check for duplicates of $cmd already in command_stack and ignore if they exist
    foreach my $message ( @{ $$self{command_stack2} } ) {
        if ( $message->interface_data eq $cmd ) {
            $duplicate_detected = 1;
            last;
        }
    }
    return $duplicate_detected;
}

=item C<has_link(link_details)>

If a device has an ALDB, passes link_details onto one of the has_link() routines
within L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>.  Generally called as part of C<delete_orphan_links()>.

=cut

sub has_link {
    my ( $self, $insteon_object, $group, $is_controller, $subaddress ) = @_;
    if ( $self->_aldb ) {
        return $self->_aldb->has_link( $insteon_object, $group, $is_controller,
            $subaddress );
    }
    return 0;
}

=item C<add_link(link_params)>

If a device has an ALDB, passes link_details onto one of the add_link() routines
within L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>.  Generally called from the "sync links" or 
"link to interface" voice commands.

=cut

sub add_link {
    my ( $self, $parms_text ) = @_;
    if ( $self->_aldb ) {
        my %link_parms;
        if ( @_ > 2 ) {
            shift @_;
            %link_parms = @_;
        }
        else {
            %link_parms = &main::parse_func_parms($parms_text);
        }
        $self->_aldb->add_link(%link_parms);
    }
}

=item C<delete_link([link details])>

If a device has an ALDB, passes link_details onto one of the delete_link() routines
within L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>.  Generally called by C<delete_orphan_links()>.

=cut

sub delete_link {
    my ( $self, $parms_text ) = @_;
    if ( $self->_aldb ) {
        my %link_parms;
        if ( @_ > 2 ) {
            shift @_;
            %link_parms = @_;
        }
        else {
            %link_parms = &main::parse_func_parms($parms_text);
        }
        $self->_aldb->delete_link(%link_parms);
    }
}

=item C<active_message([msg])>

Optionally stores, and returns the message currently being processed by the interface.

=cut

sub active_message {
    my ( $self, $message ) = @_;
    if ( defined $message ) {
        $$self{active_message} = $message;
    }
    return $$self{active_message};
}

=item C<clear_active_message()>

Clears the message currently being processed by the interface, and sets the
transmit in progress flag to false.

=cut

sub clear_active_message {
    my ($self) = @_;
    $$self{active_message} = undef;
    $self->transmit_in_progress(0);
}

=item C<retry_active_message()>

Sets the transmit in progress flag to false.

=cut

sub retry_active_message {
    my ($self) = @_;
    $self->transmit_in_progress(0);
}

=item C<transmit_in_progress([xmit_flag])>

Sets the transmit in progress flag to xmit_flag, returns true if xmit_flag
true or xmit timout has not elapsed.

=cut

sub transmit_in_progress {
    my ( $self, $xmit_flag ) = @_;
    if ( defined $xmit_flag ) {
        $$self{xmit_in_progress} = $xmit_flag;
    }

    # also factor in xmit timer since this must be honored to allow
    #   adequate time to elapse
    return $$self{xmit_in_progress} || ( $self->_check_timeout('xmit') == 0 );
}

=item C<queue_message([msg])>

If no msg is passed, returns the queue length.

Msg is optionally a message, if sent is added to the message queue.  
C<process_queue()> is then called.

=cut

sub queue_message {
    my ( $self, $message ) = @_;

    my $command_queue_size = @{ $$self{command_stack2} };
    return $command_queue_size unless $message;

    #queue any new command
    if ( defined $message ) {
        my $setby = $message->setby;
        if ( $self->_is_duplicate( $message->interface_data )
            && !( $message->isa('Insteon::X10Message') ) )
        {
            ::print_log( "[Insteon::BaseInterface] WARN queuing a "
                  . "duplicate command already in queue." )
              if $self->debuglevel( 1, 'insteon' );
        }
        if (    $setby
            and ref($setby)
            and $setby->can('set_retry_timeout')
            and $setby->get_object_name )
        {
            $message->callback(
                $setby->get_object_name . "->set_retry_timeout()" );
        }
        unshift( @{ $$self{command_stack2} }, $message );
    }

    # and, begin processing either this entry or the oldest one in the queue
    $self->process_queue();
}

=item C<process_queue()>

If C<transmit_in_progress()> is true returns queue size.

If there is a pending message, will leave it as active_message.  If retries are 
exceeded, will log an error, clear the message, and call the message failure_callback.

Else, will pull a message from the queue and place it as the active_message.

=cut

sub process_queue {
    my ($self) = @_;

    my $command_queue_size = @{ $$self{command_stack2} };

    if ( $self->transmit_in_progress ) {
        return $command_queue_size;
    }
    else

      #we dont transmit on top of another xmit
    { # no transmission is progress that has not already been acked or nacked by the PLM
            # get pending command record
        my $pending_message = $self->active_message;

        if ( !($pending_message) )
        {    # no prior message remains; so, get one from the queue
            $pending_message = pop( @{ $$self{command_stack2} } );
            $self->active_message($pending_message) if $pending_message;
        }

        if ($pending_message)
        {    # a message exists to be sent (whether previously sent or queued)

            if ( $self->active_message->send($self) == 0 )
            {    # this only occurs if the retry count has been exceeded
                    # which also means that there wasn't a message actually sent
                &::print_log(
                        "[Insteon::BaseInterface] WARN: number of retries ("
                      . $self->active_message->send_attempts
                      . ") for "
                      . $self->active_message->to_string()
                      . " exceeds limit.  Now moving on..." )
                  if $self->debuglevel( 1, 'insteon' );

                # !!!!!!!!! TO-DO - handle failure timeout ???
                my $failed_message = $self->active_message;

                # make sure to let the sending object know!!!
                if ( defined( $failed_message->setby )
                    and $failed_message->setby->can('is_acknowledged') )
                {
                    $failed_message->setby->is_acknowledged(0);
                    $failed_message->setby->fail_count_log(1)
                      if $failed_message->setby->can('fail_count_log');
                }
                elsif ( !$failed_message->isa('Insteon::X10Message') ) {
                    &main::print_log(
                        "[Insteon::BaseInterface] WARN! Unable to clear acknowledge for "
                          . (
                            ( defined( $failed_message->setby ) )
                            ? $failed_message->setby->get_object_name
                            : "undefined"
                          )
                    );
                }

                # Get failed message details before clearing
                my $callback = $failed_message->failure_callback;
                my $setby    = $failed_message->setby;

                # clear active message
                $self->clear_active_message();

                if ($callback) {
                    &::print_log(
                        "[Insteon::BaseInterface] WARN: Message Timeout:  Now calling callback: "
                          . $callback )
                      if $self->debuglevel( 1, 'insteon' );
                    $setby->failure_reason('timeout')
                      if ( defined($setby) and $setby->can('failure_reason') );

                    package main;
                    eval $callback;
                    &::print_log(
                        "[Insteon::BaseInterface] problem w/ retry callback: $@"
                    ) if $@;

                    package Insteon::BaseInterface;
                }

                #Any other outgoing messages pending in the queue?
                $self->process_queue();
            }
        }
        else    # no pending message
        {
            # clear the timer
            $self->_clear_timeout('command');
            return 0;
        }
    }
    my $command_queue_size = @{ $$self{command_stack2} };
    return $command_queue_size;
}

=item C<device_id([id])>

Used to store and return the associated device_id of a device.

If provided, stores id as the device's id.

Returns device id without any delimiters.

=cut

sub device_id {
    my ( $self, $p_deviceid ) = @_;
    $$self{deviceid} = $p_deviceid if defined $p_deviceid;
    return $$self{deviceid};
}

=item C<restore_string()>

This is called by mh on exit to save the cached ALDB of a device to persistant data.

=cut

sub restore_string {
    my ($self) = @_;
    my $restore_string = $self->SUPER::restore_string();
    $restore_string .= $self->_aldb->restore_string();
    return $restore_string;
}

=item C<restore_linktable()>

Used to reload the link table of a device on restart.

=cut

sub restore_linktable {
    my ( $self, $aldb ) = @_;
    if ( $self->_aldb and $aldb ) {
        $self->_aldb->restore_linktable($aldb);
    }
}

=item C<log_alllink_table()>

Prints a human readable form of MisterHouse's cached version of a device's ALDB
to the print log.  Called as part of the "scan links" voice command
or in response to the "log links" voice command.

=cut

sub log_alllink_table {
    my ($self) = @_;
    $self->_aldb->log_alllink_table if $self->_aldb;
}

=item C<delete_orphan_links(audit_mode)>

Reviews the cached version of all of the ALDBs and based on this review removes
links from this device which are not present in the mht file, not defined in the 
code, or links which are only half-links.

If audit_mode is true, prints the actions that would be taken to the log, but 
does nothing.

=cut

sub delete_orphan_links {
    my ( $self, $audit_mode ) = @_;
    return $self->_aldb->delete_orphan_links($audit_mode) if $self->_aldb;
}

=item C<plm_get_config>

Used to obtain the configuration flags from the PLM.  May be used in conjunction
with C<enable_monitor_mode>.

=cut

sub plm_get_config {
    my ($self) = @_;
    $self->queue_message(
        new Insteon::InsteonMessage( 'plm_get_config', $self ) );
}

sub plm_config {
    my ( $self, $p_config ) = @_;
    $$self{config} = $p_config if defined $p_config;
    return $$self{config};
}

=item C<enable_monitor_mode(boolean)>

If boolean is true, enables monitor mode on the PLM, else disables monitor mode.
If you have manually set any other PLM flags (unlikely), you should first call 
C<plm_get_config> to prevent these settings from being altered.

=cut

sub enable_monitor_mode {
    my ( $self, $enable ) = @_;
    my $config = hex( $self->plm_config );
    if ($enable) {
        $config = $config | 64;
    }
    else {
        $config = $config & 191;
    }
    my $message = new Insteon::InsteonMessage( 'plm_set_config', $self );
    $message->interface_data( sprintf( "%02X", $config ) );
    $self->queue_message($message);
}

######################
### EVENT HANDLERS ###
######################

=item C<on_interface_config_received>

Called to process the plm_get_config request sent by the C<plm_get_config()> command.
Prints output to log.

=cut

sub on_interface_config_received {
    my ( $self, $data ) = @_;
    $data = $self->plm_config( substr( $data, 0, 2 ) );
    &::print_log("[Insteon_PLM] PLM config flags: $data")
      if $self->debuglevel( 1, 'insteon' );
    $self->clear_active_message();
}

=item C<on_interface_info_received>

Called to process the plm_info request sent by the C<poll_all()> command.
Prints output to log.

=cut

sub on_interface_info_received {
    my ($self) = @_;
    &::print_log( "[Insteon_PLM] PLM id: "
          . $self->device_id
          . " firmware: "
          . $self->firmware )
      if $self->debuglevel( 1, 'insteon' );
    $self->clear_active_message();
}

=item C<on_standard_insteon_received>

Called to process standard length insteon messages.  The routine is rather complex
some messsages are processed right here.  The majority are passed off to the
C<_is_info_request()> and C<_process_message()> routines for each device.

=cut

sub on_standard_insteon_received {
    my ( $self, $message_data ) = @_;
    my %msg = &Insteon::InsteonMessage::command_to_hash($message_data);
    return if $self->_is_duplicate_received( $message_data, %msg );
    if (%msg) {
        my $wait_time;
        my $wait_message = "[Insteon::BaseInterface] DEBUG3: Message received "
          . "with $msg{hopsleft} hops left, ";
        if (   !$msg{is_ack}
            && !$msg{is_nack}
            && $msg{type} ne 'alllink'
            && $msg{type} ne 'broadcast' )
        {
            #Wait for ACK to be delivered
            $wait_time = $msg{maxhops};
            $wait_message .= "plus ACK will take $msg{maxhops} to deliver, ";
        }
        $wait_time += $msg{hopsleft};

        #Standard msgs should only take 50 millis, but in practice additional
        #time has been required. Extra 50 millis helps prevent dupes
        $wait_time = ( $wait_time * 100 ) + 50;
        $wait_message .=
          "delaying next transmit by $wait_time milliseconds to avoid collisions.";
        ::print_log($wait_message)
          if ( $self->debuglevel( 3, 'insteon' ) && $wait_time > 50 );
        $self->_set_timeout( 'xmit', $wait_time );

        # get the matching object
        my $object = &Insteon::get_object( $msg{source}, $msg{group} );
        if ( defined $object ) {
            $object->max_hops_count( $msg{maxhops} )
              if $object->can('max_hops_count');
            $object->hops_left_count( $msg{hopsleft} )
              if $object->can('hops_left_count');
            $object->incoming_count_log(1)
              if $object->can('incoming_count_log');
            $object->last_contact(time);
            if ( $msg{type} ne 'broadcast' ) {
                $msg{command} = $object->message_type( $msg{cmd_code} );
                &::print_log( "[Insteon::BaseInterface] Received message from: "
                      . $object->get_object_name
                      . "; command: $msg{command}; type: $msg{type}; group: $msg{group}"
                  )
                  if ( !( $msg{is_ack} or $msg{is_nack} ) )
                  and $self->debuglevel( 1, 'insteon' );
            }
            if ( $msg{is_ack} or $msg{is_nack} ) {
                main::print_log(
                    "[Insteon::BaseInterface] DEBUG3: PLM command:insteon_received; "
                      . "Device command:$msg{command}; type:$msg{type}; group: $msg{group}"
                ) if $self->debuglevel( 3, 'insteon' );

                # need to confirm that this message corresponds to the current active one before clearing it
                # TO-DO!!! This is a brute force and poor compare technique; needs to be replaced by full compare
                if ( $self->active_message && ref $self->active_message->setby )
                {
                    if ( $self->active_message->send_attempts == 0 ) {
                        &main::print_log(
                            "[Insteon::BaseInterface] WARN: received ACK/NACK message for "
                              . $object->get_object_name
                              . " but cannot correlate to sent message "
                              . "(active but send attempts = 0).  IGNORING received message!!"
                        );
                    }
                    elsif ( $msg{type} eq 'direct' ) {
                        if (
                            lc $self->active_message->setby->device_id eq
                            lc $msg{source} )
                        {
                            # prevent re-processing transmit queue until after clearing occurs
                            $self->transmit_in_progress(1);

                            # ask the object to process the received message and update its state
                            # Object will return true if this is the end of the send transaction
                            if ( $object->_process_message( $self, %msg ) ) {
                                if ( $self->active_message->success_callback ) {
                                    main::print_log(
                                        "[Insteon::BaseInterface] DEBUG4: Now calling message success callback: "
                                          . $self->active_message
                                          ->success_callback )
                                      if $object->debuglevel( 4, 'insteon' );

                                    package main;
                                    eval
                                      $self->active_message->success_callback;
                                    ::print_log(
                                        "[Insteon::BaseInterface] problem w/ success callback: $@"
                                    ) if $@;

                                    package Insteon::BaseInterface;
                                }
                                $self->clear_active_message();
                            }
                        }
                        else {
                            &main::print_log(
                                "[Insteon::BaseInterface] WARN: deviceid of "
                                  . "active message != received message source ("
                                  . $object->get_object_name()
                                  . "). IGNORING received message!!" );

                            #These generally seem to be duplicate messages
                            $object->dupe_count_log(1)
                              if $object->can('dupe_count_log');
                        }
                    }
                    elsif ( $msg{type} eq 'cleanup' ) {
                        my $group_object =
                          &Insteon::get_object( '000000', $msg{extra} );
                        if ($group_object) {

                            # prevent re-processing transmit queue until after clearing occurs
                            $self->transmit_in_progress(1);

                            # Don't clear active message as ACK is only one of many
                            if (
                                (
                                    $msg{extra} ==
                                    $self->active_message->setby->group
                                )
                              )
                            {
                                &main::print_log(
                                    "[Insteon::BaseInterface] DEBUG3: Cleanup message received for scene "
                                      . $group_object->get_object_name
                                      . " from "
                                      . $object->get_object_name )
                                  if $group_object->debuglevel( 3, 'insteon' );
                            }
                            elsif ( $self->active_message->command_type eq
                                'all_link_direct_cleanup'
                                && lc( $self->active_message->setby->device_id )
                                eq $msg{source} )
                            {
                                &::print_log(
                                    "[Insteon::BaseInterface] DEBUG2: ALL-Linking Direct Completed with "
                                      . $self->active_message->setby
                                      ->get_object_name )
                                  if $group_object->debuglevel( 2, 'insteon' );
                                $self->clear_active_message();
                            }
                            else {
                                &main::print_log(
                                    "[Insteon::BaseInterface] DEBUG3: Cleanup message received from "
                                      . $object->get_object_name
                                      . " for scene "
                                      . $group_object->get_object_name
                                      . ", but group in recent message "
                                      . $msg{extra}
                                      . " did not match group in "
                                      . "prior sent message group "
                                      . $self->active_message->setby->group )
                                  if $group_object->debuglevel( 3, 'insteon' );
                            }

                            # If ACK or NACK received then PLM is still working on the ALL Link Command
                            # Increase the command timeout to wait for next one
                            $self->_set_timeout( 'command', 3000 );
                        }
                        elsif ( $msg{is_nack} && lc( $msg{extra} ) eq 'ff' ) {
                            ::print_log( "[Insteon::BaseInterface] ERROR: "
                                  . $object->get_object_name
                                  . " does not have a responder record for the most recent command"
                                  . " sent by the PLM.  Try scanning "
                                  . $object->get_object_name
                                  . " and then running 'sync links' on the most recently used "
                                  . " PLM Scene." );
                        }
                        else {
                            &main::print_log(
                                "[Insteon::BaseInterface] ERROR: received cleanup message from "
                                  . $object->get_object_name
                                  . " that does not correspond to a valid PLM group. Corrupted message is assumed "
                                  . "and will be skipped! Was group "
                                  . $msg{extra} );
                            $object->corrupt_count_log(1)
                              if $object->can('corrupt_count_log');
                        }
                    }
                    else    #not direct or cleanup
                    {
                        &main::print_log(
                            "[Insteon::BaseInterface] ERROR: received ACK/NACK message from "
                              . $object->get_object_name
                              . " but unable to process $msg{type} message type."
                              . " IGNORING received message!!" );
                        $self->active_message->no_hop_increase(1);
                        $object->corrupt_count_log(1)
                          if $object->can('corrupt_count_log');
                    }
                }
                else        #does not correspond to current active message
                {
                    if ( $msg{type} eq 'direct' ) {
                        &main::print_log(
                            "[Insteon::BaseInterface] WARN: received insteon ACK/NACK message from "
                              . $object->get_object_name
                              . " but cannot correlate to sent message! IGNORING received message!!"
                        );
                    }
                    elsif ( $msg{type} eq 'cleanup' ) {

                        # this is just going to be ignored since there is a virtual processing done
                        #   in the Insteon_PLM handler for cleanup messages.
                        #   however, if the virtual handler was not invoked due to receipt of the broadcast message
                        #   then, the above cleanup handler would be run
                        my $plm_group_obj =
                          Insteon::get_object( '000000', $msg{extra} );
                        my $group_name = $msg{extra};
                        $group_name = $plm_group_obj->get_object_name
                          if ( ref $plm_group_obj );
                        $plm_group_obj = $self if ( !ref $plm_group_obj );
                        &main::print_log(
                            "[Insteon::BaseInterface] DEBUG3: received cleanup message responding to "
                              . "PLM controller group: $group_name. Ignoring as this has already been processed"
                        ) if $plm_group_obj->debuglevel( 3, 'insteon' );
                    }
                    else {
                        # ask the object to process the received message and update its state
                        $object->_process_message( $self, %msg );
                    }
                }
            }
            else    # not ACK or NAK
            {
                # ask the object to process the received message and update its state
                $object->_process_message( $self, %msg );
            }
            if ( $object->is_deaf ) {

                #See if deaf device has commands waiting to be
                #sent
                $object->_process_command_stack();
            }
        }
        else {
            &::print_log(
                "[Insteon::BaseInterface] Warn! Unable to locate object for source: $msg{source} and group: $msg{group}"
            );
            $self->corrupt_count_log(1);
        }

        # treat the message as legitimate even if an object match did not occur
    }
}

=item C<on_standard_insteon_received>

Called to process extended length insteon messages.  The majority of messages are 
passed off to the C<_process_message()> routines for each device.

=cut

sub on_extended_insteon_received {
    my ( $self, $message_data ) = @_;
    my %msg = &Insteon::InsteonMessage::command_to_hash($message_data);
    return if $self->_is_duplicate_received( $message_data, %msg );
    if (%msg) {
        my $wait_time;
        my $wait_message = "[Insteon::BaseInterface] DEBUG3: Message received "
          . "with $msg{hopsleft} hops left, ";
        if (   !$msg{is_ack}
            && !$msg{is_nack}
            && $msg{type} ne 'alllink'
            && $msg{type} ne 'broadcast' )
        {
            #Wait for ACK to be delivered
            $wait_time = $msg{maxhops};
            $wait_message .= "plus ACK will take $msg{maxhops} to deliver, ";
        }
        $wait_time += $msg{hopsleft};

        #Standard msgs should only take 108 millis, but in practice additional
        #time has been required. Extra 50 millis helps prevent dupes
        $wait_time = ( $wait_time * 200 ) + 50;
        $wait_message .=
          "delaying next transmit by $wait_time milliseconds to avoid collisions.";
        ::print_log($wait_message)
          if ( $self->debuglevel( 3, 'insteon' ) && $wait_time > 50 );
        $self->_set_timeout( 'xmit', $wait_time );

        # get the matching object
        my $object = &Insteon::get_object( $msg{source}, $msg{group} );
        if ( defined $object ) {
            $object->max_hops_count( $msg{maxhops} )
              if $object->can('max_hops_count');
            $object->hops_left_count( $msg{hopsleft} )
              if $object->can('hops_left_count');
            $object->incoming_count_log(1)
              if $object->can('incoming_count_log');
            $object->last_contact(time);
            if ( $msg{type} ne 'broadcast' ) {
                $msg{command} = $object->message_type( $msg{cmd_code} );
                main::print_log(
                    "[Insteon::BaseInterface] DEBUG: PLM command:insteon_ext_received; "
                      . "Device command:$msg{command}; type:$msg{type}; group: $msg{group}"
                  )
                  if (
                    (
                        !( $msg{is_ack} or $msg{is_nack} )
                        and $self->debuglevel( 1, 'insteon' )
                    )
                    or $self->debuglevel( 3, 'insteon' )
                  );
            }
            &::print_log( "[Insteon::BaseInterface] Processing message for "
                  . $object->get_object_name )
              if $object->debuglevel( 3, 'insteon' );
            if ( $object->_process_message( $self, %msg ) ) {
                if ( ref $self->active_message
                    && $self->active_message->success_callback )
                {
                    main::print_log(
                        "[Insteon::BaseInterface] DEBUG4: Now calling message success callback: "
                          . $self->active_message->success_callback )
                      if $object->debuglevel( 4, 'insteon' );

                    package main;
                    eval $self->active_message->success_callback;
                    ::print_log(
                        "[Insteon::BaseInterface] problem w/ success callback: $@"
                    ) if $@;

                    package Insteon::BaseInterface;
                }
                $self->clear_active_message();
            }
            if ( $object->is_deaf ) {

                #See if deaf device has commands waiting to be
                #sent
                $object->_process_command_stack();
            }
        }
        else {
            &::print_log(
                "[Insteon::BaseInterface] Warn! Unable to locate object for source: $msg{source} and group: $msg{group}"
            );
        }

        # treat the message as legitimate even if an object match did not occur
    }

}

#################################
### INTERNAL METHODS/FUNCTION ###
#################################

=item C<_set_timeout(timeout_name, timeout_millis)>

Sets an internal variable, timeout_name, the current time plus the number of 
milliseconds specified by timeout_millis.

=cut

sub _set_timeout {
    my ( $self, $timeout_name, $timeout_in_millis ) = @_;
    my $tickcount = &main::get_tickcount + $timeout_in_millis;
    $tickcount += 2**32
      if $tickcount < 0;    # force a wrap; to be handleded by check timeout
    $$self{"_timeout_$timeout_name"} = $tickcount;
}

=item C<_check_timeout(timeout_name)>

Checks to see if the current number of milliseconds has exceeded the number of
milliseconds defined in timeout_name, which was set by C<_set_timeout()>.

return -1 if timeout_name does not match an existing timer
return 0 if timer has not expired
return 1 if timer has expired

=cut

sub _check_timeout {
    my ( $self, $timeout_name ) = @_;
    return 0  unless $timeout_name;
    return -1 unless defined $$self{"_timeout_$timeout_name"};
    my $current_tickcount = &main::get_tickcount;
    return 0
      if (  ( $current_tickcount >= 2**16 )
        and ( $$self{"_timeout_$timeout_name"} < 2**16 ) );
    return ( $current_tickcount > $$self{"_timeout_$timeout_name"} ) ? 1 : 0;
}

=item C<_check_timeout(timeout_name)>

Erases timeout_name, which was set by C<_set_timeout()>.

=cut

sub _clear_timeout {
    my ( $self, $timeout_name ) = @_;
    $$self{"_timeout_$timeout_name"} = undef;
}

=item C<_aldb()>

Returns the ALDB object associated with the device.

=cut

sub _aldb {
    my ($self) = @_;
    return $$self{aldb};
}

=item C<_is_duplicate_received()>

This function attempts to identify erroneous duplicative incoming messages 
while still permitting identical messages to arrive in close proximity.  For 
example, a valid identical message is the ACK of an extended aldb read which 
is always 2F00.

Messages are deemed to be identical if, excluding the max_hops and hops_left
bits, they are otherwise the same.  Identical messages are deemed to be 
erroneous if they are received within a calculated message window, $delay.  

The message window is calculated based on the amount of time that should have
elapsed before a subsequent identical message could have been received..

Returns 1 if the received message is an erroneous duplicate message

See discussion at: https://github.com/hollie/misterhouse/issues/169

=cut

sub _is_duplicate_received {
    my ( $self, $message_data, %msg ) = @_;
    my $is_duplicate;

    my $curr_milli = sprintf( '%.0f', &main::get_tickcount );

    # $key will be set to $message_data with max hops and hops left set to 0
    my $key = $message_data;
    substr( $key, 13, 1 ) = 0;

    #Standard = 50 millis; Extended = 108 millis;
    #In practice requires 75% more
    my $message_time = ( length($message_data) > 18 ) ? 183 : 87;

    #Wait period before PLM can send ACK or next request
    my $max_hops = $msg{hopsleft};

    if (   !$msg{is_ack}
        && !$msg{is_nack}
        && $msg{type} ne 'alllink'
        && $msg{type} ne 'broadcast' )
    {
        #ACK sent with same max hops plus 1 for initial timeslot
        $max_hops += $msg{maxhops} + 1;

        #Subsequent Reply, arrives in same number of hops + 1 for intial timeslot
        $max_hops += ( $msg{maxhops} - $msg{hopsleft} ) + 1;
    }
    else {
        #Subsequent PLM request is sent with max hops + 1 for intial timeslot
        $max_hops += $msg{maxhops} + 1;
    }

    my $delay = ( $message_time * $max_hops );

    #Clean hash of outdated entries
    for ( keys %{ $$self{received_commands} } ) {
        if ( $$self{received_commands}{$_} < $curr_milli ) {
            delete( $$self{received_commands}{$_} );
        }
    }

    #Check if the message exists
    if ( exists( $$self{received_commands}{$key} ) ) {
        $is_duplicate = 1;

        #Reset the time in case there are multiple duplicates
        $$self{received_commands}{$key} = $curr_milli + $delay;

        #Make a nicer name
        my $source = $msg{source};
        my $object = &Insteon::get_object( $msg{source}, $msg{group} );
        if ( defined $object ) {
            $source = $object->get_object_name();
            $object->dupe_count_log(1) if $object->can('dupe_count_log');
            $object->max_hops_count( $msg{maxhops} )
              if $object->can('max_hops_count');
            $object->hops_left_count( $msg{hopsleft} )
              if $object->can('hops_left_count');
            $object->incoming_count_log(1)
              if $object->can('incoming_count_log');

            #This message still provides a data point on how many hops it is
            #taking for messages to arrive.
            $object->default_hop_count( $msg{maxhops} - $msg{hopsleft} )
              if $object->can('default_hop_count');
            ::print_log(
                "[Insteon::BaseInterface] WARN! Dropped duplicate incoming message "
                  . $message_data
                  . ", from "
                  . $object->get_object_name )
              if $object->debuglevel( 1, 'insteon' );
        }
        else {
            ::print_log(
                "[Insteon::BaseInterface] WARN! Dropped duplicate incoming message "
                  . " from an unknown device.  Id: $msg{source} Grp: $msg{group}"
            ) if $main::Debug{'insteon'};
        }
    }
    else {
        #Message was not in hash, so add it
        $$self{received_commands}{$key} = $curr_milli + $delay;
    }
    return $is_duplicate;
}

=item C<get_voice_cmds>

Returns a hash of voice commands where the key is the voice command name and the
value is the perl code to run when the voice command name is called.

Higher classes which inherit this object may add to this list of voice commands by
redefining this routine while inheriting this routine using the SUPER function.

This routine is called by L<Insteon::generate_voice_commands> to generate the
necessary voice commands.

=cut 

sub get_voice_cmds {
    my ($self)      = @_;
    my $object_name = $self->get_object_name;
    my %voice_cmds  = (
        'plm - complete linking as responder' =>
          "$object_name->complete_linking_as_responder",
        'plm - initiate linking as controller' =>
          "$object_name->initiate_linking_as_controller",
        'plm - initiate unlinking' =>
          "$object_name->initiate_unlinking_as_controller",
        'plm - cancel linking'      => "$object_name->cancel_linking",
        'plm - log links'           => "$object_name->log_alllink_table",
        'plm - scan PLM link table' => "$object_name->scan_link_table(\""
          . '\$self->log_alllink_table' . "\")",
        'global - scan changed device link tables' =>
          "Insteon::scan_all_linktables(1)",
        'global - delete orphan links' => "$object_name->delete_orphan_links",
        'global - audit delete orphan links' =>
          "$object_name->delete_orphan_links(1)",
        'global - force scan all device link tables' =>
          "Insteon::scan_all_linktables",
        'global - sync all links'       => "Insteon::sync_all_links(0)",
        'global - audit sync all links' => "Insteon::sync_all_links(1)",
        'global - print all message stats' =>
          "Insteon::print_all_message_stats",
        'global - reset all message stats' =>
          "Insteon::reset_all_message_stats",
        'global - stress test ALL devices' => "Insteon::stress_test_all(5,1)",
        'global - ping test ALL devices'   => "Insteon::ping_all(5)",
        'global - log all device ALDB status' => "Insteon::log_all_ADLB_status",
        'plm - enable monitor mode'  => "$object_name->enable_monitor_mode(1)",
        'plm - disable monitor mode' => "$object_name->enable_monitor_mode(0)",
    );
    return \%voice_cmds;
}

=item C<is_deaf()>

Returns false.

=cut

sub is_deaf {
    return 0;
}

=item C<is_controller()>

Returns true.

=cut

sub is_controller {
    return 1;
}

=item C<is_responder()>

Returns true.

=cut

sub is_responder {
    return 1;
}

=back

=head2 INI PARAMETERS

=over

=item Insteon_PLM_scan_at_startup

By default, MisterHouse will scan all devices at startup.  This scan involves
asking each device for its current state and asking each device for its engine
version.  In a larger network this can take a few seconds to complete and it does
send a lot of messages all at once, but polling at startup is a good way to make
sure that MisterHouse has an accurate understanding of the network.

If set to false, will disable the scan at startup.

=back

=head2 AUTHOR

Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1
