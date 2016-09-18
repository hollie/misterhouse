package Insteon::AllLinkDatabase;

=head1 B<Insteon::AllLinkDatabase>

=head2 SYNOPSIS

Generic class implementation of an insteon device's all link database.

=head2 DESCRIPTION

Generally this object should be interacted with through the insteon objects and 
not by directly calling any of the following methods.

=head2 INHERITS

None

=head2 METHODS

=over

=cut

use strict;

=item C<new()>

Instantiate a new object.

=cut

sub new {
    my ( $class, $device ) = @_;
    my $self = {};
    bless $self, $class;
    $$self{device} = $device;
    $self->health("unknown");    # unknown
    $self->aldb_version("I1");
    return $self;
}

sub _send_cmd {
    my ( $self, $msg ) = @_;
    $$self{device}->_send_cmd($msg);
}

=item C<aldb_version([i1|i2])>

Used to track the ALDB version type.

If provided, saves version to memory.

Returns the saved version type.

=cut

sub aldb_version {
    my ( $self, $aldb_version ) = @_;
    $$self{aldb_version} = $aldb_version if defined $aldb_version;
    return $$self{aldb_version};
}

=item C<health([changed|unknown|empty|unchanged])>

Used to track the health of MisterHouse's copy of a device's ALDB.

If provided, saves status to memory.

Returns the saved health status.

=cut

sub health {
    my ( $self, $health ) = @_;
    $$self{health} = $health if defined $health;
    return $$self{health};
}

=item C<get_linkkey($deviceid, $group, $is_controller, $data3)>

Returns the key in the ALDB hash that identifies this link.

=cut

sub get_linkkey {
    my ( $self, $deviceid, $group, $is_controller, $data3 ) = @_;
    my $linkkey = $deviceid . $group . $is_controller;

    # Data3 is irrelevant for the PLM itself, b/c for controller records
    # data3 will always be equal to group.  And for responder records it
    # can be equal to anything without causing an issue.  MH generally sets
    # data3 on the PLM to 00, but manual linking will set it to the linked
    # devices firmware version.  Here we set it to 00 so it is ignored.
    if ( $$self{device}->isa('Insteon_PLM') ) {
        $data3 = '00';
    }

    # '00' and '01' are generally interchangable for $data3 values and are
    # the most common values.  So to make searching easier we only
    # add data3 if it is unique
    $linkkey .= $data3 if ( $data3 ne '00' and $data3 ne '01' );
    return lc $linkkey;
}

=item C<scandatetime([seconds])>

Used to track the time, in unix time seconds, of the last ALDB scan.

If provided, saves the time to memory.

Returns the time of the last ALDB scan.

=cut

sub scandatetime {
    my ( $self, $scandatetime ) = @_;
    $$self{scandatetime} = $scandatetime if defined $scandatetime;
    return $$self{scandatetime};
}

=item C<aldb_delta([hex])>

Used to track the ALDB Delta.  The ALDB Delta starts at 00 and iterates
+1 for each change to a device's ALDB.  The ALDB Delta will be reset to 00 
whenever power is lost to the device or if the device is factory reset.

If provided, saves the hex value to memory. (This should likely only be done by
C<query_aldb_delta()>)

Returns the current ALDB Delta.

=cut

sub aldb_delta {
    my ( $self, $p_aldb_delta ) = @_;
    $$self{aldb_delta} = $p_aldb_delta if defined($p_aldb_delta);
    return $$self{aldb_delta};
}

=item C<query_aldb_delta([check|set])>

Interacts with the device's ALDB Delta.

If called with "check", MisterHouse will query the device to obtain the current
ALDB Delta.  If the ALDB Delta matches the version stored in C<aldb_delta> 
MisterHouse will eval the code stored in C<$self->{_aldb_unchanged_callback}>.
If the ALDB Delta does not match, MisterHouse will eval the code stored in
C<$self->{_aldb_changed_callback}>.

If called with "set" will cause MisterHouse to query the device for its ALDB
Delta and will store it with C<aldb_delta>.

=cut

sub query_aldb_delta {
    my ( $self, $action ) = @_;
    $$self{aldb_delta_action} = $action;
    if (   $action eq "check"
        && $self->health ne "unchanged"
        && $self->health ne "empty" )
    {
        &::print_log( "[Insteon::AllLinkDatabase] WARN The link table for "
              . $self->{device}->get_object_name
              . " has changed." );
        if ( defined $self->{_aldb_changed_callback} ) {

            package main;
            my $callback = $self->{_aldb_changed_callback};
            $self->{_aldb_changed_callback} = undef;
            eval($callback);
            &::print_log( "[Insteon::AllLinkDatabase] "
                  . $self->{device}->get_object_name
                  . ": error during scan callback $@" )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::AllLinkDatabase;
        }
    }
    elsif ( $action eq "check"
        && ( ( &main::get_tickcount - $self->scandatetime() ) <= 2000 ) )
    {
        #if we just did a aldb_query less than 2 seconds ago, don't repeat
        &::print_log( "[Insteon::AllLinkDatabase] The link table for "
              . $self->{device}->get_object_name
              . " is unchanged." );

        #Further extend Scan Time in case of serial aldb requests
        $self->scandatetime(&main::get_tickcount);
        if ( defined $self->{_aldb_unchanged_callback} ) {

            package main;
            my $callback = $self->{_aldb_unchanged_callback};
            $self->{_aldb_unchanged_callback} = undef;
            eval($callback);
            &::print_log( "[Insteon::AllLinkDatabase] "
                  . $self->{device}->get_object_name
                  . ": error during scan callback $@" )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::AllLinkDatabase;
        }
    }
    else {
        my $message =
          new Insteon::InsteonMessage( 'insteon_send', $$self{device},
            'status_request' );
        if ( defined( $$self{_failure_callback} ) ) {
            $message->failure_callback( $$self{_failure_callback} );
        }
        $self->_send_cmd($message);
    }
}

=item C<restore_string()>

This is called by mh on exit to save the cached ALDB of a device to persistant data.

=cut

sub restore_string {
    my ($self) = @_;
    my $restore_string = '';
    if ( $$self{aldb} ) {
        my $aldb = '';
        foreach my $aldb_key ( keys %{ $$self{aldb} } ) {
            next
              unless $aldb_key eq 'empty'
              || $aldb_key eq 'duplicates'
              || $$self{aldb}{$aldb_key}{inuse};
            $aldb .= '|' if $aldb;    # separate sections
            my $record = '';
            if ( $aldb_key eq 'empty' ) {
                foreach my $address ( @{ $$self{aldb}{empty} } ) {
                    $record .= ';' if $record;
                    $record .= $address;
                }
                $record = 'empty=' . $record;
            }
            elsif ( $aldb_key eq 'duplicates' ) {
                my $duplicate_record = '';
                foreach my $address ( @{ $$self{aldb}{duplicates} } ) {
                    $duplicate_record .= ';' if $duplicate_record;
                    $duplicate_record .= $address;
                }
                $record = 'duplicates=' . $duplicate_record;
            }
            else {
                my %aldb_record = %{ $$self{aldb}{$aldb_key} };
                foreach my $record_key ( keys %aldb_record ) {
                    next unless $aldb_record{$record_key};
                    $record .= ',' if $record;
                    $record .= $record_key . '=' . $aldb_record{$record_key};
                }
            }
            $aldb .= $record;
        }
        if ( defined $self->scandatetime ) {
            $restore_string .=
                $$self{device}->get_object_name
              . "->_aldb->scandatetime(q~"
              . $self->scandatetime
              . "~) if "
              . $$self{device}->get_object_name
              . "->_aldb;\n";
        }
        if ( defined $self->aldb_delta ) {
            $restore_string .=
                $$self{device}->get_object_name
              . "->_aldb->aldb_delta(q~"
              . $self->aldb_delta
              . "~) if "
              . $$self{device}->get_object_name
              . "->_aldb;\n";
        }
        $restore_string .=
            $$self{device}->get_object_name
          . "->_aldb->health(q~"
          . $self->health
          . "~) if "
          . $$self{device}->get_object_name
          . "->_aldb;\n";
        $restore_string .=
            $$self{device}->get_object_name
          . "->_aldb->restore_aldb(q~$aldb~) if "
          . $$self{device}->get_object_name
          . "->_aldb;\n";
    }
    return $restore_string;
}

=item C<restore_aldb()>

Used to reload MisterHouse's cached version of a device's ALDB on restart.

=cut

sub restore_aldb {
    my ( $self, $aldb ) = @_;
    if ($aldb) {
        foreach my $aldb_section ( split( /\|/, $aldb ) ) {
            my %aldb_record     = ();
            my @aldb_empty      = ();
            my @aldb_duplicates = ();
            my $deviceid        = '';
            my $groupid         = '01';
            my $is_controller   = 0;
            my $subaddress      = '00';
            foreach my $aldb_entry ( split( /,/, $aldb_section ) ) {
                my ( $key, $value ) = split( /=/, $aldb_entry );
                next unless $key and defined($value) and $value ne '';
                if ( $key eq 'empty' ) {
                    @aldb_empty = split( /;/, $value );
                }
                elsif ( $key eq 'duplicates' ) {
                    @aldb_duplicates = split( /;/, $value );
                }
                else {
                    $deviceid      = lc $value if ( $key eq 'deviceid' );
                    $groupid       = lc $value if ( $key eq 'group' );
                    $is_controller = $value    if ( $key eq 'is_controller' );
                    $subaddress    = $value    if ( $key eq 'data3' );
                    $aldb_record{$key} = $value if $key and defined($value);
                }
            }
            if (@aldb_empty) {
                @{ $$self{aldb}{empty} } = @aldb_empty;
            }
            elsif (@aldb_duplicates) {
                @{ $$self{aldb}{duplicates} } = @aldb_duplicates;
            }
            elsif ( scalar %aldb_record ) {
                next unless $deviceid;
                my $aldbkey =
                  $self->get_linkkey( $deviceid, $groupid,
                    $is_controller, $subaddress );
                %{ $$self{aldb}{$aldbkey} } = %aldb_record;
            }
        }

        #		$self->log_alllink_table();
    }
}

=item C<scan_link_table()>

Scans a device's link table and caches a copy.

=cut

sub scan_link_table {
    my ( $self, $success_callback, $failure_callback ) = @_;
    $$self{_mem_activity}     = 'scan';
    $$self{_success_callback} = ($success_callback) ? $success_callback : undef;
    $$self{_failure_callback} = ($failure_callback) ? $failure_callback : undef;
    $self->health('changed');    # allow acknowledge to set otherwise
    if ( $self->isa('Insteon::ALDB_i1') ) {
        $self->_peek( '0FF8', 0 );
    }
    else {
        $self->send_read_aldb('0000');
    }
}

=item C<delete_link([link details])>

Deletes a specific link from a device.  Generally called by C<delete_orphan_links()>.

=cut

sub delete_link {
    my ( $self, $parms_text ) = @_;
    my %link_parms;
    if ( $parms_text eq 'ok' or $parms_text eq 'fail' ) {
        %link_parms             = %{ $self->{callback_parms} };
        $$self{callback_parms}  = undef;
        $link_parms{aldb_check} = $parms_text;
    }
    elsif ( @_ > 2 ) {
        shift @_;
        %link_parms = @_;
    }
    else {
        %link_parms = &main::parse_func_parms($parms_text);
    }
    $$self{_success_callback} =
      ( $link_parms{callback} ) ? $link_parms{callback} : undef;
    $$self{_failure_callback} =
      ( $link_parms{failure_callback} ) ? $link_parms{failure_callback} : undef;
    if ( !defined( $link_parms{aldb_check} )
        && ( !$$self{device}->isa('Insteon_PLM') ) )
    {
        ## Check whether ALDB has changed
        $self->{callback_parms} = \%link_parms;
        $$self{_aldb_unchanged_callback} =
            '&Insteon::AllLinkDatabase::delete_link('
          . $$self{device}->{object_name}
          . "->_aldb, 'ok')";
        $$self{_aldb_changed_callback} =
            '&Insteon::AllLinkDatabase::delete_link('
          . $$self{device}->{object_name}
          . "->_aldb, 'fail')";
        $self->query_aldb_delta("check");
    }
    elsif ( $link_parms{aldb_check} eq "fail" ) {
        &::print_log(
            "[Insteon::AllLinkDatabase] WARN: Link NOT deleted, please rescan this device and sync again."
        );
        if ( $link_parms{callback} ) {

            package main;
            eval( $link_parms{callback} );
            &::print_log(
                "[Insteon::AllLinkDatabase] failure occurred in callback eval for "
                  . $$self{device}->get_object_name . ":"
                  . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::AllLinkDatabase;
        }
    }
    elsif ( $link_parms{address} && $link_parms{aldb_check} eq "ok" ) {
        &main::print_log(
            "[Insteon::AllLinkDatabase] Now deleting link [0x$link_parms{address}]"
        );
        $$self{_mem_activity} = 'delete';
        $$self{pending_aldb}{address} = $link_parms{address};
        if ( $self->isa('Insteon::ALDB_i1') ) {
            $self->_peek( $link_parms{address}, 0 );
        }
        else {
            $self->_write_delete( $link_parms{address} );
        }

    }
    elsif ( $link_parms{aldb_check} eq "ok" ) {
        my $insteon_object = $link_parms{object};
        my $deviceid =
          ($insteon_object)
          ? $insteon_object->device_id
          : $link_parms{deviceid};
        my $groupid = $link_parms{group};
        $groupid = '01' unless $groupid;
        my $is_controller = ( $link_parms{is_controller} ) ? 1 : 0;
        my $subaddress = ( $link_parms{data3} ) ? $link_parms{data3} : '00';

        # get the address via lookup into the hash
        my $key =
          $self->get_linkkey( $deviceid, $groupid, $is_controller,
            $subaddress );
        my $address = $$self{aldb}{$key}{address};
        if ($address) {
            &main::print_log(
                "[Insteon::AllLinkDatabase] Now deleting link [0x$address] with the following data"
                  . " deviceid=$deviceid, groupid=$groupid, is_controller=$is_controller, subaddress=$subaddress"
            );

            # now, alter the flags byte such that the in_use flag is set to 0
            $$self{_mem_activity}               = 'delete';
            $$self{pending_aldb}{deviceid}      = lc $deviceid;
            $$self{pending_aldb}{group}         = $groupid;
            $$self{pending_aldb}{is_controller} = $is_controller;
            $$self{pending_aldb}{address}       = $address;
            $$self{pending_aldb}{data3}         = $subaddress;
            if ( $self->isa('Insteon::ALDB_i1') ) {
                $self->_peek( $address, 0 );
            }
            else {
                $self->_write_delete($address);
            }
        }
        else {
            &main::print_log( '[Insteon::AllLinkDatabase] WARN: ('
                  . $$self{device}->get_object_name
                  . ') attempt to delete link that does not exist!'
                  . " deviceid=$deviceid, groupid=$groupid, is_controller=$is_controller, subaddress=$subaddress"
            );
            if ( $link_parms{callback} ) {

                package main;
                eval( $link_parms{callback} );
                &::print_log(
                    "[Insteon::AllLinkDatabase] error encountered during delete_link callback: "
                      . $@ )
                  if $@ and $self->{device}->debuglevel( 1, 'insteon' );

                package Insteon::AllLinkDataBase;
            }
        }
    }
}

=item C<delete_orphan_links()>

Reviews the cached version of the link database for the device and removes
links from THIS device which are not present in the mht file, link to non-existant
devices, or which are only half-links.

Since this routine only processes this device, it is best to run the voice 
command 'delete all orphan links' from the interface so that all devices are 
scanned and processed.

=cut

sub delete_orphan_links {
    my ( $self, $audit_mode, $failure_callback, $is_batch_mode ) = @_;
    @{ $$self{delete_queue} } = ();    # reset the work queue
    $$self{delete_queue_processed} = 0;
    my $selfname = $$self{device}->get_object_name;

    # first, make sure that the health of ALDB is ok
    if ( $self->health ne 'unchanged'
        || ( $$self{device}->is_deaf && $is_batch_mode ) )
    {
        my $sent_to_failure = 0;
        if ( $$self{device}->is_deaf ) {
            ::print_log( "[Insteon::AllLinkDatabase] Will not delete "
                  . "links on deaf device: $selfname. Run 'Delete "
                  . "Orphan Links' directly on the device to do this." );
        }
        elsif ( $self->health eq 'empty' ) {
            ::print_log(
                "[Insteon::AllLinkDatabase] Skipping $selfname, because it has no links"
            );
        }
        else {
            ::print_log(
                "[Insteon::AllLinkDatabase] Delete orphan links: skipping $selfname because the link table is: "
                  . $self->health
                  . ". Please rescan the link table of this device and rerun delete "
                  . "orphans if necessary" );

            #log the failure
            $sent_to_failure = 1;
            if ($failure_callback) {

                package main;
                eval($failure_callback);
                &::print_log(
                    "[Insteon::AllLinkDatabase] error in delete orphans failure callback: "
                      . $@ )
                  if $@ and $self->{device}->debuglevel( 1, 'insteon' );

                package Insteon::AllLinkDatabase;
            }
        }
        if ( !$$self{device}->isa('Insteon_PLM') && !$sent_to_failure ) {
            $self->_process_delete_queue($is_batch_mode);
        }
        return;
    }

    # Loop through the device's ALDB table
    LINKKEY: for my $linkkey ( keys %{ $$self{aldb} } ) {

        # Skip empty addresses
        next LINKKEY if ( $linkkey eq 'empty' );

        # Define delete request
        my %delete_req = (
            callback =>
              "$selfname->_aldb->_process_delete_queue($is_batch_mode)",
            failure_callback => $failure_callback
        );

        # Delete duplicate entries
        if ( $linkkey eq 'duplicates' ) {
            push my @duplicate_addresses, @{ $$self{aldb}{duplicates} };
            foreach (@duplicate_addresses) {
                %delete_req = (
                    %delete_req,
                    address => $_,
                    cause   => "it is a duplicate record"
                );
                push @{ $$self{delete_queue} }, \%delete_req;
            }
            next LINKKEY;
        }

        # Initialize Variables
        my (
            $linked_device, $plm_scene,     $controller_object,
            $link_defined,  $controller_id, $responder_id,
            $recip_data3,   $group_object,  $data3_object
        );
        my $group         = lc $$self{aldb}{$linkkey}{group};
        my $is_controller = $$self{aldb}{$linkkey}{is_controller};
        my $data3         = lc $$self{aldb}{$linkkey}{data3};
        my $deviceid      = lc $$self{aldb}{$linkkey}{deviceid};
        my $self_id       = lc $$self{device}->device_id;
        my $interface_id  = $self_id;
        $interface_id = lc $$self{device}->interface->device_id
          if ( !$$self{device}->isa('Insteon_PLM') );
        $linked_device = Insteon::get_object( $deviceid, '01' );
        $linked_device = Insteon::active_interface()
          if ( $deviceid eq $interface_id );
        $group_object =
          ($is_controller)
          ? Insteon::get_object( $self_id,  $group )
          : Insteon::get_object( $deviceid, $group );
        $data3_object = Insteon::get_object( $self_id, $data3 );
        %delete_req = (
            %delete_req,
            deviceid      => $deviceid,
            group         => $group,
            is_controller => $is_controller,
            data3         => $data3
        );

        # IntraDevice links - Currently, a KPL can do this with a seperate
        # routine, but intralinks are not tolerated by any other known devices
        if ( $self_id eq $deviceid ) {
            $delete_req{cause} = "IntraDevice links are not allowed in ALDB.";
            push @{ $$self{delete_queue} }, \%delete_req;
            next LINKKEY;
        }

        # Is the linked device defined in MH?
        if ( !ref $linked_device ) {
            $delete_req{cause} =
              "no device with deviceid: $deviceid could be found";
            push @{ $$self{delete_queue} }, \%delete_req;
            next LINKKEY;
        }

        # If link is a PLM Scene, is the PLM Scene defined in MH?
        if (   ( $linked_device->isa("Insteon_PLM") and !$is_controller )
            || ( $$self{device}->isa("Insteon_PLM") and $is_controller ) )
        {
            $plm_scene = Insteon::get_object( '000000', $group );
            if ( !ref $plm_scene && $group ne '01' && $group ne '00' ) {
                $delete_req{cause} =
                  "no plm scene for group $group could be found";
                push @{ $$self{delete_queue} }, \%delete_req;
                next LINKKEY;
            }
        }

        # Is this link defined in MH? 3-Step Process
        # Define variables based on type of link
        $controller_id =
          ($is_controller) ? $self_id : lc $linked_device->device_id;
        $responder_id =
          ($is_controller) ? lc $linked_device->device_id : $self_id;
        $controller_object = Insteon::get_object( $controller_id, $group );
        $controller_object = $plm_scene if ( ref $plm_scene );

        # First, iterate over the controller object members to find the link definition
        MEMBERS:
        foreach my $member_ref ( keys %{ $$controller_object{members} } ) {
            my $member = $$controller_object{members}{$member_ref}{object};
            if ( $member->isa('Light_Item') ) {
                my @lights = $member->find_members('Insteon::BaseLight');
                $member = $lights[0] if (@lights);    # pick the first
            }

            #TODO - In the ALDB, the primary key is the combination of device ID "and" group
            #It is possible to link two buttons on a keypad link to the same controller
            #e.g. one button turns on and the other turns off when the controller activates
            #So then we should be checking the group here too.  Otherwise when removing links
            #this could inadvertently leave extra links in the ALDB.
            if ( lc( $member->device_id ) eq $responder_id ) {

                #Ask self what we should have in data3
                #For rspndr, D3 = rspndr group; For ctrlr, D3 = ctrlr group
                my $link_data3 =
                  $$self{device}
                  ->link_data3( ( $is_controller ? $group : $member->group ),
                    $is_controller );
                if ( $data3 eq $link_data3 ) {
                    $link_defined = 1;
                    $recip_data3 = ($is_controller) ? $member->group : $group;
                    last MEMBERS;
                }
            }
        }

        # Second, is this a PLM->Device, Device->PLM link, these are not members
        if ( $$self{device}->isa("Insteon_PLM") ) {
            if ( $is_controller && ( $group eq '00' || $group eq '01' ) ) {

                #Valid Controller for PLM->Device link
                $delete_req{skip} =
                  "$selfname -- Skipping reciprocal link check for controller group 00 or 01 link to "
                  . $linked_device->get_object_name;
                next LINKKEY;
            }
            elsif ( !$is_controller && ref $group_object ) {

                #Valid Responder for Device->PLM link
                $link_defined = 1;
                $recip_data3  = $group;
            }
        }
        elsif ( $deviceid eq $interface_id
            && ( ref $data3_object || ( $data3 eq '00' || $data3 eq '01' ) ) )
        {
            if ( $is_controller && ref $group_object ) {

                #Valid Controller for Device->PLM link
                $link_defined = 1;
                $recip_data3  = '00';
            }
            elsif ( !$is_controller && ( $group eq '00' || $group eq '01' ) ) {

                #Valid Responder for PLM->Device link
                $link_defined = 1;
                $recip_data3  = '00';
            }

        }

        # Third, delete link if not defined
        if ( !$link_defined ) {
            $delete_req{cause} = "link is not defined in MisterHouse";
            push @{ $$self{delete_queue} }, \%delete_req;
            next LINKKEY;
        }

        # Do not delete links to deaf devices
        if ( $linked_device->is_deaf ) {
            $delete_req{skip} =
              "$selfname -- Skipping check for reciprocal links on deaf device "
              . $linked_device->get_object_name;
            next LINKKEY;
        }

        # Do not delete links to unhealthy devices
        if (   $linked_device->_aldb->health ne 'unchanged'
            && $linked_device->_aldb->health ne 'empty' )
        {
            $delete_req{skip} =
                "$selfname -- Skipping check for reciprocal links on "
              . $linked_device->get_object_name
              . " because link table of that device has "
              . $linked_device->_aldb->health
              . ". Please rescan the link table on this device.";
            next LINKKEY;
        }

        # Do not delete responder links from the PLM (prevents locking i2CS devices)
        if ( $linked_device->isa("Insteon_PLM")
            and !$is_controller && ( $group eq '00' || $group eq '01' ) )
        {
            $delete_req{skip} =
              "$selfname -- Skipping check for reciprocal controller link on PLM for group 00 or 01.";
            next LINKKEY;
        }

        # Does a reciprocal link exist?
        if (
            !$linked_device->has_link(
                $$self{device}, $group,
                ($is_controller) ? 0 : 1, lc $recip_data3
            )
          )
        {
            $delete_req{cause} = "no reciprocal link was found on "
              . $linked_device->get_object_name;
            push @{ $$self{delete_queue} }, \%delete_req;
        }

    }    # /LINKKEY Loop
    my $index = 0;
    foreach ( @{ $$self{delete_queue} } ) {
        my %delete_req = %{$_};
        my $audit_text = "(AUDIT)" if ($audit_mode);
        my $log_text;
        if ( $delete_req{skip} ) {
            $log_text =
              "[Insteon::AllLinkDatabase] $audit_text " . $delete_req{skip};
            splice @{ $$self{delete_queue} }, $index, 1;
        }
        else {
            $log_text =
              "[Insteon::AllLinkDatabase] $audit_text Deleting the following link on $selfname because ";
            $log_text .= $delete_req{cause} . "\n";
            PRINT: for ( keys %delete_req ) {
                next PRINT
                  if ( ( $_ eq 'cause' )
                    || ( $_ eq 'callback' )
                    || ( $_ eq 'failure_callback' ) );
                $log_text .= "$_ = $delete_req{$_}; ";
            }
            if ( $delete_req{deviceid} ) {
                my $reciprocal_object =
                  Insteon::get_object( $delete_req{deviceid}, '01' );
                if ( !$delete_req{is_controller} ) {
                    $reciprocal_object =
                      Insteon::get_object( $delete_req{deviceid},
                        $delete_req{group} );
                }
                if ( ref $reciprocal_object ) {
                    $log_text .= "linked device name= "
                      . $reciprocal_object->get_object_name;
                }
            }
            $index++;
        }
        ::print_log($log_text);
    }
    if ($audit_mode) {
        @{ $$self{delete_queue} } = ();
    }
    else {
        ::print_log(
            "[Insteon::AllLinkDatabase] ## Begin processing delete queue for: $selfname"
        );
    }
    if ( !$$self{device}->isa('Insteon_PLM') ) {
        $self->_process_delete_queue($is_batch_mode);
    }
}

sub _process_delete_queue {
    my ( $self, $is_batch_mode ) = @_;
    my $num_in_queue = @{ $$self{delete_queue} };
    if ($num_in_queue) {
        my $delete_req_ptr = shift( @{ $$self{delete_queue} } );
        my %delete_req     = %$delete_req_ptr;
        if ( $delete_req{address} ) {
            &::print_log( "[Insteon::AllLinkDatabase] (#$num_in_queue) "
                  . $$self{device}->get_object_name
                  . " now deleting duplicate record at address "
                  . $delete_req{address} );
        }
        else {
            &::print_log(
                    "[Insteon::AllLinkDatabase] (#$num_in_queue) "
                  . $$self{device}->get_object_name
                  . " now deleting orphaned link w/ details: "
                  . (
                    ( $delete_req{is_controller} ) ? "controller" : "responder"
                  )
                  . ", "
                  . (
                    ( $delete_req{object} )
                    ? "device=" . $delete_req{object}->get_object_name
                    : "deviceid=$delete_req{deviceid}"
                  )
                  . ", group=$delete_req{group}, cause=$delete_req{cause}"
            );
        }
        $self->delete_link(%delete_req);
        $$self{delete_queue_processed}++;
    }
    else {
        &::print_log( "[Insteon::AllLinkDatabase] Nothing else to do for "
              . $$self{device}->get_object_name
              . " after deleting "
              . $$self{delete_queue_processed}
              . " links" )
          if $self->{device}->debuglevel( 1, 'insteon' );
        if ($is_batch_mode) {
            $$self{device}->interface->_aldb->_process_delete_queue(
                $$self{delete_queue_processed} );
        }
    }
}

=item C<add_duplicate_link_address([address])>

Adds address to the duplicate link hash. Called as part of C<scan_link_table()>.

=cut

sub add_duplicate_link_address {
    my ( $self, $address ) = @_;

    unshift @{ $$self{aldb}{duplicates} }, $address;

    # now, keep the list sorted!
    @{ $$self{aldb}{duplicates} } = sort( @{ $$self{aldb}{duplicates} } );

}

=item C<delete_duplicate_link_address([address])>

Removes address from the duplicate link hash. Called as part of C<delete_orphan_links()>.

=cut

sub delete_duplicate_link_address {
    my ( $self, $address ) = @_;
    my $num_duplicate_link_addresses = 0;

    $num_duplicate_link_addresses = @{ $$self{aldb}{duplicates} }
      if ( defined $$self{aldb}{duplicates} );
    if ($num_duplicate_link_addresses) {
        my @temp_duplicates = ();
        foreach my $temp_address ( @{ $$self{aldb}{duplicates} } ) {
            if ( $temp_address ne $address ) {
                push @temp_duplicates, $temp_address;
            }
        }

        # keep it sorted
        @{ $$self{aldb}{duplicates} } = sort(@temp_duplicates);
    }
}

=item C<add_empty_address([address])>

Adds address to the empty link hash. Called as part of C<delete_orphan_links()> 
or C<scan_link_table()>.

=cut

sub add_empty_address {
    my ( $self, $address ) = @_;

    # before adding it, make sure that it isn't already in the list!!
    my $num_addresses = 0;
    $num_addresses = @{ $$self{aldb}{empty} }
      if ( defined $$self{aldb}{empty} );
    my $exists = 0;
    if ( $num_addresses and $address ) {
        foreach my $temp_address ( @{ $$self{aldb}{empty} } ) {
            if ( $temp_address eq $address ) {
                $exists = 1;
                last;
            }
        }
    }

    # add it to the list if it doesn't exist
    if ( !($exists) and $address ) {
        unshift @{ $$self{aldb}{empty} }, $address;
    }

    # now, keep the list sorted!
    @{ $$self{aldb}{empty} } = sort( @{ $$self{aldb}{empty} } );

}

=item C<get_first_empty_address()>

Returns the highest empty link address, or if no empty addresses exist, returns
the highest unused address.  Called as part of C<delete_orphan_links()> or 
C<scan_link_table()>..

=cut

sub get_first_empty_address {
    my ($self) = @_;

    # NOTE: The issue here is that we give up an address from the list
    #   with the assumption that it will be made non-empty;
    #   So, if there is a problem during update/add, then will have
    #   a non-empty, but non-functional entry
    my $first_address = pop @{ $$self{aldb}{empty} };

    if ( !($first_address) ) {

        # then, cycle through all of the existing non-empty addresses
        # to find the lowest one and then decrement by 8
        #
        # TO-DO: factor in appropriate use of the "highwater" flag
        #
        my $high_address = 0xffff;
        for my $key ( keys %{ $$self{aldb} } ) {
            next if $key eq 'empty' or $key eq 'duplicates';
            my $new_address = hex( $$self{aldb}{$key}{address} );
            if ( $new_address and $new_address < $high_address ) {
                $high_address = $new_address;
            }
        }
        $first_address =
          ( $high_address > 0 ) ? sprintf( '%04x', $high_address - 8 ) : 0;
        main::print_log(
            "[Insteon::AllLinkDatabase] DEBUG4: No empty link entries; using next lowest link address ["
              . $first_address
              . "]" )
          if $self->{device}->debuglevel( 4, 'insteon' );
    }
    else {
        main::print_log(
                "[Insteon::AllLinkDatabase] DEBUG4: Found empty address ["
              . $first_address
              . "] in empty array" )
          if $self->{device}->debuglevel( 4, 'insteon' );
    }

    return $first_address;
}

=item C<add_link(link_params)>

Adds the link to the device's ALDB.  Generally called from the "sync links" or 
"link to interface" voice commands.

=cut

sub add_link {
    my ( $self, $parms_text ) = @_;
    my %link_parms;
    if ( $parms_text eq 'ok' or $parms_text eq 'fail' ) {
        %link_parms             = %{ $self->{callback_parms} };
        $$self{callback_parms}  = undef;
        $link_parms{aldb_check} = $parms_text;
    }
    elsif ( @_ > 2 ) {
        shift @_;
        %link_parms = @_;
    }
    else {
        %link_parms = &main::parse_func_parms($parms_text);
    }
    my $device_id;
    my $insteon_object = $link_parms{object};
    my $group          = $link_parms{group};
    if ( !( defined($insteon_object) ) ) {
        $device_id = lc $link_parms{deviceid};
        $insteon_object = &Insteon::get_object( $device_id, $group );
    }
    else {
        $device_id = lc $insteon_object->device_id;
    }
    my $is_controller = ( $link_parms{is_controller} ) ? 1 : 0;

    my $data3 =
      $$self{device}->link_data3( $link_parms{data3}, $is_controller );

    # check whether the link already exists
    my $key = $self->get_linkkey( $device_id, $group, $is_controller, $data3 );
    $$self{_success_callback} =
      ( $link_parms{callback} ) ? $link_parms{callback} : undef;
    $$self{_failure_callback} =
      ( $link_parms{failure_callback} ) ? $link_parms{failure_callback} : undef;
    if ( !defined( $link_parms{aldb_check} )
        && ( !$$self{device}->isa('Insteon_PLM') ) )
    {
        ## Check whether ALDB has changed
        $self->{callback_parms} = \%link_parms;
        $$self{_aldb_unchanged_callback} =
            '&Insteon::AllLinkDatabase::add_link('
          . $$self{device}->{object_name}
          . "->_aldb, 'ok')";
        $$self{_aldb_changed_callback} =
            '&Insteon::AllLinkDatabase::add_link('
          . $$self{device}->{object_name}
          . "->_aldb, 'fail')";
        $self->query_aldb_delta("check");
    }
    elsif ( $link_parms{aldb_check} eq "fail" ) {
        &::print_log(
            "[Insteon::AllLinkDatabase] WARN: Link NOT added, please rescan this device and sync again."
        );
        if ( $link_parms{callback} ) {

            package main;
            eval( $link_parms{callback} );
            &::print_log(
                "[Insteon::AllLinkDatabase] failure occurred in callback eval for "
                  . $$self{device}->get_object_name . ":"
                  . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::AllLinkDatabase;
        }
    }
    elsif ( defined $$self{aldb}{$key} && defined $$self{aldb}{$key}{inuse} ) {
        &::print_log( "[Insteon::AllLinkDatabase] WARN: attempt to add link to "
              . $$self{device}->get_object_name
              . " that already exists! object="
              . $insteon_object->get_object_name
              . ", group=$group, is_controller=$is_controller, data3=$data3" );
        if ( $link_parms{callback} ) {

            package main;
            eval( $link_parms{callback} );
            &::print_log(
                "[Insteon::AllLinkDatabase] failure occurred in callback eval for "
                  . $$self{device}->get_object_name . ":"
                  . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::AllLinkDatabase;
        }
    }
    elsif ( $link_parms{aldb_check} eq "ok" ) {

        # strip optional % sign to append on_level
        my $on_level = $link_parms{on_level};
        $on_level =~ s/(\d)%?/$1/;
        $on_level = '100' unless defined($on_level); # 100% == on is the default
              # strip optional s (seconds) to append ramp_rate
        my $ramp_rate = $link_parms{ramp_rate};
        $ramp_rate =~ s/(\d)s?/$1/;
        $ramp_rate = '0.1' unless $ramp_rate;    # 0.1s is the default
              # get the first available memory location
        my $address = $self->get_first_empty_address();

        if ($address) {
            &::print_log(
                    "[Insteon::AllLinkDatabase] DEBUG2: adding link record to "
                  . $$self{device}->get_object_name
                  . " light level controlled by "
                  . $insteon_object->get_object_name
                  . " and group: $group with on level: $on_level,"
                  . " ramp rate: $ramp_rate, local load(data3): $data3" )
              if $self->{device}->debuglevel( 2, 'insteon' );
            my ( $data1, $data2 );
            if ( $link_parms{is_controller} ) {
                $data1 = '03';    #application retries == 3
                $data2 = '00';    #ignored for controller entries
            }
            else {
                $data1 = &Insteon::DimmableLight::convert_level($on_level);
                $data2 =
                  ( $$self{device}->isa('Insteon::DimmableLight') )
                  ? &Insteon::DimmableLight::convert_ramp($ramp_rate)
                  : '00';
            }

            #data3 is defined above
            $$self{_mem_activity} = 'add';
            $self->_write_link( $address, $device_id, $group, $is_controller,
                $data1, $data2, $data3 );

            # TO-DO: ensure that pop'd address is restored back to queue if the transaction fails
        }
        else {
            &::print_log(
                "[Insteon::AllLinkDatabase] ERROR: adding link record failed because "
                  . $$self{device}->get_object_name
                  . " does not have a record of the first empty ALDB record."
                  . " Please rescan this device's link table" )
              if $self->{device}->debuglevel( 1, 'insteon' );

            if ( $$self{_success_callback} ) {

                package main;
                eval( $$self{_success_callback} );
                &::print_log(
                    "[Insteon::AllLinkDatabase] WARN1: Error encountered during callback: "
                      . $@ )
                  if $@ and $self->{device}->debuglevel( 1, 'insteon' );

                package Insteon::AllLinkDatabase;
            }
        }
    }
}

=item C<update_link(link_params)>

Updates the on_level and/or ramp_rate associated with a link to match the defined
value in MisterHouse. Generally called from the "sync links" voice command.

=cut

sub update_link {
    my ( $self, %link_parms ) = @_;
    if ( $_[1] eq 'ok' or $_[1] eq 'fail' ) {
        %link_parms             = %{ $self->{callback_parms} };
        $$self{callback_parms}  = undef;
        $link_parms{aldb_check} = $_[1];
    }
    my $insteon_object = $link_parms{object};
    my $group          = $link_parms{group};
    my $is_controller  = ( $link_parms{is_controller} ) ? 1 : 0;

    # strip optional % sign to append on_level
    my $on_level = $link_parms{on_level};
    $on_level =~ s/(\d+)%?/$1/;

    # strip optional s (seconds) to append ramp_rate
    my $ramp_rate = $link_parms{ramp_rate};
    $ramp_rate =~ s/(\d)s?/$1/;
    my $data1 = &Insteon::DimmableLight::convert_level($on_level);
    my $data2 =
      ( $$self{device}->isa('Insteon::DimmableLight') )
      ? &Insteon::DimmableLight::convert_ramp($ramp_rate)
      : '00';

    my $data3 =
      $$self{device}->link_data3( $link_parms{data3}, $is_controller );

    &::print_log( "[Insteon::AllLinkDatabase] DEBUG2: updating "
          . $$self{device}->get_object_name
          . " light level controlled by "
          . $insteon_object->get_object_name
          . " and group: $group with on level: $on_level,"
          . " ramp rate: $ramp_rate, local load(data3): $data3" )
      if $self->{device}->debuglevel( 2, 'insteon' );

    $$self{_success_callback} =
      ( $link_parms{callback} ) ? $link_parms{callback} : undef;
    $$self{_failure_callback} =
      ( $link_parms{failure_callback} ) ? $link_parms{failure_callback} : undef;

    my $deviceid = $insteon_object->device_id;
    my $key = $self->get_linkkey( $deviceid, $group, $is_controller, $data3 );
    if ( !defined( $link_parms{aldb_check} )
        && ( !$$self{device}->isa('Insteon_PLM') ) )
    {
        ## Check whether ALDB has changed
        $self->{callback_parms} = \%link_parms;
        $$self{_aldb_unchanged_callback} =
            '&Insteon::AllLinkDatabase::update_link('
          . $$self{device}->{object_name}
          . "->_aldb, 'ok')";
        $$self{_aldb_changed_callback} =
            '&Insteon::AllLinkDatabase::update_link('
          . $$self{device}->{object_name}
          . "->_aldb, 'fail')";
        $self->query_aldb_delta("check");
    }
    elsif ( $link_parms{aldb_check} eq "fail" ) {
        &::print_log(
            "[Insteon::AllLinkDatabase] WARN: Cannot update link, please rescan this device and sync again."
        );
        if ( $link_parms{callback} ) {

            package main;
            eval( $link_parms{callback} );
            &::print_log(
                "[Insteon::AllLinkDatabase] failure occurred in callback eval for "
                  . $$self{device}->get_object_name . ":"
                  . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::AllLinkDatabase;
        }
    }
    elsif ( defined $$self{aldb}{$key} && $link_parms{aldb_check} eq "ok" ) {
        my $address = $$self{aldb}{$key}{address};
        $$self{_mem_activity} = 'update';
        $self->_write_link( $address, $deviceid, $group, $is_controller,
            $data1, $data2, $data3 );
    }
    else {
        &::print_log(
            "[Insteon::AllLinkDatabase] ERROR: updating link record failed because "
              . $$self{device}->get_object_name
              . " does not have an existing ALDB entry key=$key" )
          if $self->{device}->debuglevel( 1, 'insteon' );

        if ( $$self{_success_callback} ) {

            package main;
            eval( $$self{_success_callback} );
            &::print_log(
                "[Insteon::AllLinkDatabase] WARN1: Error encountered during ack callback: "
                  . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::AllLinkDatabase;
        }
    }
}

=item C<log_alllink_table()>

Prints a human readable form of MisterHouse's cached version of a device's ALDB
to the print log.  Called as part of the "scan links" voice command
or in response to the "log links" voice command.

=cut

sub log_alllink_table {
    my ($self) = @_;
    my %aldb;

    &::print_log( "[Insteon::AllLinkDatabase] Link table for "
          . $$self{device}->get_object_name . " is: "
          . $self->health );

    # We want to log links sorted by ALDB address. Since the ALDB
    # addresses are scattered throughout the %{$$self{aldb}} hash,
    # and it is not easy to obtain them in a linear manner,
    # we build a new data structure that will allow us to easily
    # traverse the ALDB by address in a sorted manner. The new
    # data structure is a bidimensional hash (%aldb) where rows
    # are the ALDB addresses and the columns can be "empty"
    # (indicates that the ALDB at the corresponding address is
    # empty), "duplicate" (indicates that the ALDB at the
    # corresponding address is a duplicate), or a hash key (which
    # indicates that the ALDB at corresponding address contains
    # a link).
    foreach my $aldbkey ( keys %{ $$self{aldb} } ) {
        if ( $aldbkey eq "empty" ) {
            foreach my $address ( @{ $$self{aldb}{empty} } ) {
                $aldb{$address}{empty} = undef;    # Any value will do
            }
        }
        elsif ( $aldbkey eq "duplicates" ) {
            foreach my $address ( @{ $$self{aldb}{duplicates} } ) {
                $aldb{$address}{duplicate} = undef;    # Any value will do
            }
        }
        else {
            $aldb{ $$self{aldb}{$aldbkey}{address} }{$aldbkey} =
              $$self{aldb}{$aldbkey};
        }
    }

    # Finally traverse the ALDB, but this time sorted by ALDB address
    if ( $self->health eq 'unchanged' ) {
        foreach my $address ( sort keys %aldb ) {
            my $log_msg = "[Insteon::AllLinkDatabase] [0x$address] ";

            if ( exists $aldb{$address}{empty} ) {
                $log_msg .= "is empty";
            }
            elsif ( exists $aldb{$address}{duplicate} ) {
                $log_msg .= "holds a duplicate entry";
            }
            else {
                my ($key) = keys %{ $aldb{$address} };    # There's only 1 key
                my $aldb_entry = $aldb{$address}{$key};
                my $is_controller = $aldb_entry->{is_controller};
                my $device;

                if (
                    $$self{device}->interface()->device_id()
                    && ( $$self{device}->interface()->device_id() eq
                        $aldb_entry->{deviceid} )
                  )
                {
                    $device = $$self{device}->interface;
                }
                else {
                    $device =
                      &Insteon::get_object( $aldb_entry->{deviceid}, '01' );
                }
                my $object_name =
                  ($device)
                  ? $device->get_object_name
                  : $aldb_entry->{deviceid};

                my $on_level = 'unknown';
                if ( defined $aldb_entry->{data1} ) {
                    if ( $aldb_entry->{data1} ) {
                        $on_level = int(
                            ( hex( $aldb_entry->{data1} ) * 100 / 255 ) + .5 )
                          . "%";
                    }
                    else {
                        $on_level = '0%';
                    }
                }

                my $rspndr_group = $aldb_entry->{data3};
                $rspndr_group = '01' if $rspndr_group eq '00';

                my $ramp_rate = 'unknown';
                if ( $aldb_entry->{data2} ) {
                    if (  !( $$self{device}->isa('Insteon::DimmableLight') )
                        or ( !$is_controller and ( $rspndr_group != '01' ) ) )
                    {
                        $ramp_rate = 'none';
                        $on_level = $on_level eq '0%' ? 'off' : 'on';
                    }
                    else {
                        $ramp_rate =
                          &Insteon::DimmableLight::get_ramp_from_code(
                            $aldb_entry->{data2} )
                          . "s";
                    }
                }

                $log_msg .=
                  $is_controller
                  ? "contlr($aldb_entry->{group}) "
                  . "record to $object_name, "
                  . "(d1:$aldb_entry->{data1}, "
                  . "d2:$aldb_entry->{data2}, "
                  . "d3:$aldb_entry->{data3})"
                  : "rspndr($rspndr_group) record to $object_name "
                  . "($aldb_entry->{group}): onlevel=$on_level "
                  . "and ramp=$ramp_rate "
                  . "(d3:$aldb_entry->{data3})";
            }

            &::print_log($log_msg);
        }
    }
    else {
        main::print_log( "[Insteon::AllLinkDatabase] The link table is "
              . $self->health
              . " and will not be listed" );
    }
}

=item C<has_link(link_details)>

Checks and returns true if a link with the passed details exists on the device
or false if it does not.  Generally called as part of C<delete_orphan_links()>.

=cut

sub has_link {
    my ( $self, $insteon_object, $group, $is_controller, $data3 ) = @_;
    my $deviceid;
    if ( $insteon_object->isa('Insteon::AllLinkDatabase') ) {
        $deviceid = $$insteon_object{device}->device_id;
    }
    else {
        $deviceid = lc $insteon_object->device_id;
    }
    my $key = $self->get_linkkey( $deviceid, $group, $is_controller, $data3 );

    my $found = 0;
    $found++ if ( defined $$self{aldb}{$key} );

    return ($found);
}

=back

=head2 INI PARAMETERS

None

=head2 AUTHOR

Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

package Insteon::ALDB_i1;

=head1 B<Insteon::ALDB_i1>

=head2 SYNOPSIS

Unique class for storing a cahced copy of a verion i1 device's ALDB.

=head2 DESCRIPTION

Generally this object should be interacted with through the insteon objects and 
not by directly calling any of the following methods.

=head2 INHERITS

L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>

=head2 METHODS

=over

=cut

use strict;

@Insteon::ALDB_i1::ISA = ('Insteon::AllLinkDatabase');

=item C<new()>

Instantiate a new object.

=cut

sub new {
    my ( $class, $device ) = @_;

    my $self = new Insteon::AllLinkDatabase($device);
    bless $self, $class;
    $self->aldb_version("I1");
    return $self;
}

sub _on_poke {
    my ( $self, %msg ) = @_;
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $$self{device}, 'peek' );
    if (   ( $$self{_mem_activity} eq 'update' )
        or ( $$self{_mem_activity} eq 'add' ) )
    {
        if ( $$self{_mem_action} eq 'aldb_flag' ) {
            $$self{_mem_action} = 'aldb_group';
            $$self{_mem_lsb} = sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_group' ) {
            $$self{_mem_action} = 'aldb_devhi';
            $$self{_mem_lsb} = sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_devhi' ) {
            $$self{_mem_action} = 'aldb_devmid';
            $$self{_mem_lsb} = sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_devmid' ) {
            $$self{_mem_action} = 'aldb_devlo';
            $$self{_mem_lsb} = sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_devlo' ) {
            $$self{_mem_action} = 'aldb_data1';
            $$self{_mem_lsb} = sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_data1' ) {
            $$self{_mem_action} = 'aldb_data2';
            $$self{_mem_lsb} = sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_data2' ) {
            $$self{_mem_action} = 'aldb_data3';
            $$self{_mem_lsb} = sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_data3' ) {
            ## update the aldb records w/ the changes that were made
            my $aldbkey = $self->get_linkkey(
                $$self{pending_aldb}{deviceid},
                $$self{pending_aldb}{group},
                $$self{pending_aldb}{is_controller},
                $$self{pending_aldb}{data3}
            );
            $$self{aldb}{$aldbkey}{data1} = $$self{pending_aldb}{data1};
            $$self{aldb}{$aldbkey}{data2} = $$self{pending_aldb}{data2};
            $$self{aldb}{$aldbkey}{data3} = $$self{pending_aldb}{data3};
            $$self{aldb}{$aldbkey}{inuse} =
              1;    # needed so that restore string will preserve record
            if ( $$self{_mem_activity} eq 'add' ) {
                $$self{aldb}{$aldbkey}{is_controller} =
                  $$self{pending_aldb}{is_controller};
                $$self{aldb}{$aldbkey}{deviceid} =
                  lc $$self{pending_aldb}{deviceid};
                $$self{aldb}{$aldbkey}{group} = lc $$self{pending_aldb}{group};
                $$self{aldb}{$aldbkey}{address} = $$self{pending_aldb}{address};
                $self->health("unchanged");
            }

            # clear out mem_activity flag
            $$self{_mem_activity} = undef;
            $self->health("unchanged");

            # Put the new ALDB Delta into memory
            $self->query_aldb_delta('set');
        }
    }
    elsif ( $$self{_mem_activity} eq 'update_local' ) {
        if ( $$self{_mem_action} eq 'local_onlevel' ) {
            $$self{_mem_lsb}    = '21';
            $$self{_mem_action} = 'local_ramprate';
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'local_ramprate' ) {
            if (   $$self{device}->isa('Insteon::KeyPadLincRelay')
                or $$self{device}->isa('Insteon::KeyPadLinc') )
            {
                # update from eeprom--only a kpl issue
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'do_read_ee' );
                $self->_send_cmd($message);
            }

            # Put the new ALDB Delta into memory
            $self->query_aldb_delta('set');
        }
    }
    elsif ( $$self{_mem_activity} eq 'update_flags' ) {

        # update from eeprom--only a kpl issue
        $message = new Insteon::InsteonMessage( 'insteon_send', $$self{device},
            'do_read_ee' );
        $message->failure_callback( $$self{_failure_callback} );
        $self->_send_cmd($message);
    }
    elsif ( $$self{_mem_activity} eq 'delete' ) {

        # clear out mem_activity flag
        $$self{_mem_activity} = undef;

        # add the address of the deleted link to the empty list
        $self->add_empty_address( $$self{pending_aldb}{address} );

        # and, remove from the duplicates list (if it is a member)
        $self->delete_duplicate_link_address( $$self{pending_aldb}{address} );
        if ( exists $$self{pending_aldb}{deviceid} ) {
            my $key = $self->get_linkkey(
                $$self{pending_aldb}{deviceid},
                $$self{pending_aldb}{group},
                $$self{pending_aldb}{is_controller},
                $$self{pending_aldb}{data3}
            );
            delete $$self{aldb}{$key};
        }
        $self->health("unchanged");

        # Put the new ALDB Delta into memory
        $self->query_aldb_delta('set');
    }
    elsif ( $$self{_mem_activity} eq 'update_intradevice' ) {
        if ( $$self{_mem_lsb} eq '51' ) {
            ::print_log( "[Insteon::KeyPadLinc] Successfully wrote IntraDevice "
                  . "links for "
                  . $$self{device}->get_object_name
                  . " now asking device to reread settings from memory." );
            $message = new Insteon::InsteonMessage( 'insteon_send',
                $$self{device}, 'do_read_ee' );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        else {
            #Skip the toggle memory location
            $$self{_mem_lsb} = '49' if ( $$self{_mem_lsb} eq '48' );
            $$self{_mem_lsb} = sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} )
              ;    #KRK again not sure this exists
            $self->_send_cmd($message);
        }
    }
}

sub _on_peek {
    my ( $self, %msg ) = @_;
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $$self{device}, 'peek' );
    if ( $msg{is_extended} ) {
        &::print_log( "[Insteon::ALDB_i1]: extended peek for "
              . $$self{device}->{object_name} . " is "
              . $msg{extra} )
          if $self->{device}->debuglevel( 1, 'insteon' );
    }
    else {
        if ( $$self{_mem_action} eq 'aldb_peek' ) {
            if ( $$self{_mem_activity} eq 'scan' ) {
                $$self{_mem_action} = 'aldb_flag';

                # if the device is responding to the peek, then init the link table
                #   if at the very start of a scan
                if (    lc $$self{_mem_msb} eq '0f'
                    and lc $$self{_mem_lsb} eq 'f8'
                    && !$$self{_stress_test_act} )
                {
                    # reinit the aldb hash as there will be a new one
                    $$self{aldb} = undef;

                    # reinit the empty address list
                    @{ $$self{aldb}{empty} } = ();

                    # and, also the duplicates list
                    @{ $$self{aldb}{duplicates} } = ();
                }
            }
            elsif ( $$self{_mem_activity} eq 'update' ) {
                $$self{_mem_action} = 'aldb_data1';
            }
            elsif ( $$self{_mem_activity} eq 'update_local' ) {
                $$self{_mem_action} = 'local_onlevel';
            }
            elsif ( $$self{_mem_activity} eq 'update_flags' ) {
                $$self{_mem_action} = 'update_flags';
            }
            elsif ( $$self{_mem_activity} eq 'delete' ) {
                $$self{_mem_action} = 'aldb_flag';
            }
            elsif ( $$self{_mem_activity} eq 'add' ) {
                $$self{_mem_action} = 'aldb_flag';
            }
            elsif ( $$self{_mem_activity} eq 'update_intradevice' ) {
                $$self{_mem_action} = 'update_intradevice';
            }
            $message->extra( $$self{_mem_lsb} );
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_flag' ) {
            if ( $$self{_mem_activity} eq 'scan' ) {
                &::print_log( "[Insteon::ALDB_i1] DEBUG3: "
                      . $$self{device}->get_object_name . " [0x"
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] received: "
                      . lc $msg{extra} . " for "
                      . $$self{_mem_action} )
                  if $self->{device}->debuglevel( 3, 'insteon' );
                my $flag = hex( $msg{extra} );
                $$self{pending_aldb}{inuse}         = ( $flag & 0x80 ) ? 1 : 0;
                $$self{pending_aldb}{is_controller} = ( $flag & 0x40 ) ? 1 : 0;
                $$self{pending_aldb}{highwater}     = ( $flag & 0x02 ) ? 1 : 0;
                if ( $$self{_stress_test_act}
                    && !( $$self{pending_aldb}{highwater} ) )
                {
                    ::print_log(
                        "[Insteon::ALDB_i1] You need to create a link on this device before running stress_test"
                    );
                    $$self{_mem_activity}    = undef;
                    $$self{_mem_action}      = undef;
                    $$self{_stress_test_act} = 0;
                    $$self{device}->stress_test();
                }
                elsif ( !( $$self{pending_aldb}{highwater} ) ) {

                    # since this is the last unused memory location, then add it to the empty list
                    $self->add_empty_address(
                        $$self{_mem_msb} . $$self{_mem_lsb} );
                    $$self{_mem_action} = undef;

                    # clear out mem_activity flag
                    $$self{_mem_activity} = undef;
                    if (    lc $$self{_mem_msb} eq '0f'
                        and lc $$self{_mem_lsb} eq 'f8' )
                    {
                        # set health as empty for now
                        $self->health("empty");
                    }
                    else {
                        $self->health("unchanged");
                    }

                    &::print_log( "[Insteon::ALDB_i1] "
                          . $$self{device}->get_object_name
                          . " completed link memory scan" )
                      if $self->{device}->debuglevel( 1, 'insteon' );
                    $self->health("unchanged");

                    # Put the new ALDB Delta into memory
                    $self->query_aldb_delta('set');
                }
                elsif ( $$self{pending_aldb}{inuse} ) {
                    $$self{pending_aldb}{flag} = $msg{extra};
                    ## confirm that we have a high-water mark; otherwise stop
                    $$self{pending_aldb}{address} =
                      $$self{_mem_msb} . $$self{_mem_lsb};
                    $$self{_mem_lsb} =
                      sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
                    $$self{_mem_action} = 'aldb_group';
                    $message->extra( $$self{_mem_lsb} );
                    $message->failure_callback( $$self{_failure_callback} );
                    $self->_send_cmd($message);
                }
                else {
                    $self->add_empty_address(
                        $$self{_mem_msb} . $$self{_mem_lsb} );
                    if ( $$self{_mem_activity} eq 'scan' ) {
                        my $newaddress = sprintf( "%04X",
                            hex( $$self{_mem_msb} . $$self{_mem_lsb} ) - 8 );
                        $$self{pending_aldb} = undef;
                        $self->_peek($newaddress);
                    }
                }
            }
            elsif ( $$self{_mem_activity} eq 'add' ) {

                # TO-DO!!! Eventually add the ability to set the highwater mark
                #  the below flags never reset the highwater mark so that
                #  the scanner will continue scanning extra empty records
                my $flag =
                  ( $$self{pending_aldb}{is_controller} ) ? 'E2' : 'A2';
                $$self{pending_aldb}{flag} = $flag;
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra($flag);
                $message->failure_callback( $$self{_failure_callback} );
                $self->_send_cmd($message);
            }
            elsif ( $$self{_mem_activity} eq 'delete' ) {
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra('02');
                $message->failure_callback( $$self{_failure_callback} );
                $self->_send_cmd($message);
            }
        }
        elsif ( $$self{_mem_action} eq 'aldb_group' ) {
            if ( $$self{_mem_activity} eq 'scan' ) {
                &::print_log( "[Insteon::ALDB_i1] DEBUG3: "
                      . $$self{device}->get_object_name . " [0x"
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] received: "
                      . lc $msg{extra} . " for "
                      . $$self{_mem_action} )
                  if $self->{device}->debuglevel( 3, 'insteon' );
                $$self{pending_aldb}{group} = lc $msg{extra};
                $$self{_mem_lsb} =
                  sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
                $$self{_mem_action} = 'aldb_devhi';
                $message->extra( $$self{_mem_lsb} );
            }
            else {
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra( $$self{pending_aldb}{group} );
            }
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_devhi' ) {
            if ( $$self{_mem_activity} eq 'scan' ) {
                &::print_log( "[Insteon::ALDB_i1] DEBUG3: "
                      . $$self{device}->get_object_name . " [0x"
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] received: "
                      . lc $msg{extra} . " for "
                      . $$self{_mem_action} )
                  if $self->{device}->debuglevel( 3, 'insteon' );
                $$self{pending_aldb}{deviceid} = lc $msg{extra};
                $$self{_mem_lsb} =
                  sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
                $$self{_mem_action} = 'aldb_devmid';
                $message->extra( $$self{_mem_lsb} );
            }
            elsif ( $$self{_mem_activity} eq 'add' ) {
                my $devid = substr( $$self{pending_aldb}{deviceid}, 0, 2 );
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra($devid);
            }
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_devmid' ) {
            if ( $$self{_mem_activity} eq 'scan' ) {
                &::print_log( "[Insteon::ALDB_i1] DEBUG3: "
                      . $$self{device}->get_object_name . " [0x"
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] received: "
                      . lc $msg{extra} . " for "
                      . $$self{_mem_action} )
                  if $self->{device}->debuglevel( 3, 'insteon' );
                $$self{pending_aldb}{deviceid} .= lc $msg{extra};
                $$self{_mem_lsb} =
                  sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
                $$self{_mem_action} = 'aldb_devlo';
                $message->extra( $$self{_mem_lsb} );
            }
            elsif ( $$self{_mem_activity} eq 'add' ) {
                my $devid = substr( $$self{pending_aldb}{deviceid}, 2, 2 );
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra($devid);
            }
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'aldb_devlo' ) {
            if ( $$self{_mem_activity} eq 'scan' ) {
                &::print_log( "[Insteon::ALDB_i1] DEBUG3: "
                      . $$self{device}->get_object_name . " [0x"
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] received: "
                      . lc $msg{extra} . " for "
                      . $$self{_mem_action} )
                  if $self->{device}->debuglevel( 3, 'insteon' );
                $$self{pending_aldb}{deviceid} .= lc $msg{extra};
                $$self{_mem_lsb} =
                  sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
                $$self{_mem_action} = 'aldb_data1';
                $message->extra( $$self{_mem_lsb} );
                $message->failure_callback( $$self{_failure_callback} );
                $self->_send_cmd($message);
            }
            elsif ( $$self{_mem_activity} eq 'add' ) {
                my $devid = substr( $$self{pending_aldb}{deviceid}, 4, 2 );
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra($devid);
                $message->failure_callback( $$self{_failure_callback} );
                $self->_send_cmd($message);
            }
        }
        elsif ( $$self{_mem_action} eq 'aldb_data1' ) {
            if ( $$self{_mem_activity} eq 'scan' ) {
                &::print_log( "[Insteon::ALDB_i1] DEBUG3: "
                      . $$self{device}->get_object_name . " [0x"
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] received: "
                      . lc $msg{extra} . " for "
                      . $$self{_mem_action} )
                  if $self->{device}->debuglevel( 3, 'insteon' );
                $$self{_mem_action} = 'aldb_data2';
                $$self{_mem_lsb} =
                  sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
                $$self{pending_aldb}{data1} = $msg{extra};
                $message->extra( $$self{_mem_lsb} );
                $message->failure_callback( $$self{_failure_callback} );
                $self->_send_cmd($message);
            }
            elsif ($$self{_mem_activity} eq 'update'
                or $$self{_mem_activity} eq 'add' )
            {
                # poke the new value
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra( $$self{pending_aldb}{data1} );
                $message->failure_callback( $$self{_failure_callback} );
                $self->_send_cmd($message);
            }
        }
        elsif ( $$self{_mem_action} eq 'aldb_data2' ) {
            if ( $$self{_mem_activity} eq 'scan' ) {
                &::print_log( "[Insteon::ALDB_i1] DEBUG3: "
                      . $$self{device}->get_object_name . " [0x"
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] received: "
                      . lc $msg{extra} . " for "
                      . $$self{_mem_action} )
                  if $self->{device}->debuglevel( 3, 'insteon' );
                $$self{pending_aldb}{data2} = $msg{extra};
                $$self{_mem_lsb} =
                  sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
                $$self{_mem_action} = 'aldb_data3';
                $message->extra( $$self{_mem_lsb} );
                $message->failure_callback( $$self{_failure_callback} );
                $self->_send_cmd($message);
            }
            elsif ($$self{_mem_activity} eq 'update'
                or $$self{_mem_activity} eq 'add' )
            {
                # poke the new value
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra( $$self{pending_aldb}{data2} );
                $message->failure_callback( $$self{_failure_callback} );
                $self->_send_cmd($message);
            }
        }
        elsif ( $$self{_mem_action} eq 'aldb_data3' ) {
            if ( $$self{_mem_activity} eq 'scan' ) {
                &::print_log( "[Insteon::ALDB_i1] DEBUG3: "
                      . $$self{device}->get_object_name . " [0x"
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] received: "
                      . lc $msg{extra} . " for "
                      . $$self{_mem_action} )
                  if $self->{device}->debuglevel( 3, 'insteon' );
                $$self{pending_aldb}{data3} = $msg{extra};

                if ( $$self{_stress_test_act} ) {
                    $$self{_stress_test_act} = 0;
                    $$self{_mem_activity}    = undef;
                    $$self{_mem_action}      = undef;
                    $$self{device}->stress_test();
                }
                elsif ( $$self{pending_aldb}{highwater} ) {
                    if ( $$self{pending_aldb}{inuse} ) {

                        # save pending_aldb and then clear it out
                        my $aldbkey = $self->get_linkkey(
                            $$self{pending_aldb}{deviceid},
                            $$self{pending_aldb}{group},
                            $$self{pending_aldb}{is_controller},
                            $$self{pending_aldb}{data3}
                        );

                        # check for duplicates
                        if ( exists $$self{aldb}{$aldbkey}
                            && $$self{aldb}{$aldbkey}{inuse} )
                        {
                            $self->add_duplicate_link_address(
                                $$self{pending_aldb}{address} );
                        }
                        else {
                            %{ $$self{aldb}{$aldbkey} } =
                              %{ $$self{pending_aldb} };
                        }
                    }
                    else {
                        $self->add_empty_address(
                            $$self{pending_aldb}{address} );
                    }
                    my $newaddress = sprintf( "%04X",
                        hex( $$self{pending_aldb}{address} ) - 8 );
                    $$self{pending_aldb} = undef;
                    $self->_peek($newaddress);
                }
            }
            elsif ($$self{_mem_activity} eq 'update'
                or $$self{_mem_activity} eq 'add' )
            {
                # poke the new value
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra( $$self{pending_aldb}{data3} );
                $message->failure_callback( $$self{_failure_callback} );
                $self->_send_cmd($message);
            }
        }
        elsif ( $$self{_mem_action} eq 'local_onlevel' ) {
            my $device   = $$self{device};
            my $on_level = $$device{_onlevel};
            $on_level = &Insteon::DimmableLight::convert_level($on_level);
            $message =
              new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                'poke' );
            $message->extra($on_level);
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'local_ramprate' ) {
            my $device    = $$self{device};
            my $ramp_rate = $$device{_ramprate};
            $ramp_rate = '1f' unless $ramp_rate;
            $message =
              new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                'poke' );
            $message->extra($ramp_rate);
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'update_flags' ) {
            my $flags = $$self{_operating_flags};
            $message =
              new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                'poke' );
            $message->extra($flags);
            $message->failure_callback( $$self{_failure_callback} );
            $self->_send_cmd($message);
        }
        elsif ( $$self{_mem_action} eq 'update_intradevice' ) {
            my %byte_hash = %{ $$self{_intradevice_hash_ref} };
            my $byte      = $byte_hash{ $$self{_mem_lsb} };
            $byte = '00' if $byte eq '';
            $byte = sprintf( "%02X", $byte );
            if ( uc( $msg{extra} ) ne uc($byte) ) {
                $message =
                  new Insteon::InsteonMessage( 'insteon_send', $$self{device},
                    'poke' );
                $message->extra($byte);
                $message->failure_callback( $$self{_failure_callback} )
                  ;    #KRK, I don't think this is set
                $self->_send_cmd($message);
            }
            else {
                if ( $$self{_mem_lsb} eq '51' ) {
                    ::print_log(
                        "[Insteon::KeyPadLinc] Successfully wrote IntraDevice "
                          . "links for "
                          . $$self{device}->get_object_name
                          . " now asking device to reread settings from memory."
                    );
                    $message = new Insteon::InsteonMessage( 'insteon_send',
                        $$self{device}, 'do_read_ee' );
                    $message->failure_callback( $$self{_failure_callback} );
                    $self->_send_cmd($message);
                }
                else {
                    #Skip the toggle memory location
                    $$self{_mem_lsb} = '49' if ( $$self{_mem_lsb} eq '48' );
                    $$self{_mem_lsb} =
                      sprintf( "%02X", hex( $$self{_mem_lsb} ) + 1 );
                    $message->extra( $$self{_mem_lsb} );
                    $message->failure_callback( $$self{_failure_callback} )
                      ;    #KRK again not sure this exists
                    $self->_send_cmd($message);
                }
            }
        }
        else {
            ::print_log( "[Insteon::ALDB_i1] "
                  . $$self{device}->get_object_name
                  . ": unhandled _mem_action="
                  . $$self{_mem_action} )
              if $self->{device}->debuglevel( 1, 'insteon' );
        }
    }
}

=item C<update_local_properties()>

Used to update the local on level and ramp rate of a device.  Called by 
L<Insteon::BaseDevice::update_local_properties()|Insteon::BaseInsteon/Insteon::BaseDevice>.

=cut

sub update_local_properties {
    my ( $self, $aldb_check ) = @_;
    if ( defined($aldb_check) ) {
        $$self{_mem_activity} = 'update_local';
        $self->_peek('0032');    # 0032 is the address for the onlevel
    }
    else {
        $$self{_aldb_unchanged_callback} =
            '&Insteon::ALDB_i1::update_local_properties('
          . $$self{device}->{object_name}
          . "->_aldb, 1)";
        $$self{_aldb_changed_callback} =
            '&Insteon::ALDB_i1::update_local_properties('
          . $$self{device}->{object_name}
          . "->_aldb, 1)";
        $self->query_aldb_delta("check");
    }
}

=item C<update_flags()>

Used to update the flags of a device.  Called by L<Insteon::KeyPadLinc::update_flags()|Insteon::Lighting/Insteon::KeyPadLinc>.

=cut

sub update_flags {
    my ( $self, $flags, $aldb_check ) = @_;
    return unless defined $flags;
    if ( defined($aldb_check) ) {
        $$self{_mem_activity}    = 'update_flags';
        $$self{_operating_flags} = $flags;
        $self->_peek('0023');
    }
    else {
        $$self{_aldb_unchanged_callback} =
            '&Insteon::ALDB_i1::update_flags('
          . $$self{device}->{object_name}
          . "->_aldb, '$flags', 1)";
        $$self{_aldb_changed_callback} =
            '&Insteon::ALDB_i1::update_flags('
          . $$self{device}->{object_name}
          . "->_aldb, '$flags', 1)";
        $self->query_aldb_delta("check");
    }
}

=item C<update_intradevice_links()>

Used to update the IntraDevice Links on a device.  Currently these only exist on
KeypadLinc devices.  This routine is called by 
L<Insteon::Lighting::sync_intradevice_links()|Insteon::Lighting/Insteon::KeyPadLincRelay>.

=cut

sub update_intradevice_links {
    my ( $self, $intradevice_hash_ref, $aldb_check ) = @_;
    $$self{_intradevice_hash_ref} = $intradevice_hash_ref
      if $intradevice_hash_ref ne '';
    if ( defined($aldb_check) ) {
        $$self{_mem_activity} = 'update_intradevice';
        $self->_peek('0241');    # 0241 is the first address
    }
    else {
        $$self{_aldb_unchanged_callback} =
            '&Insteon::ALDB_i1::update_intradevice_links('
          . $$self{device}->{object_name}
          . "->_aldb, '', 1)";
        $$self{_aldb_changed_callback} =
            '&Insteon::ALDB_i1::update_intradevice_links('
          . $$self{device}->{object_name}
          . "->_aldb, '', 1)";
        $self->query_aldb_delta("check");
    }
}

=item C<get_link_record()>

Gets and returns the details of a link.  Called by L<Insteon::BaseController::update_members()|Insteon::BaseInsteon/Insteon::BaseController>.

NOTE - This routine may be obsolete, its parent routine is not called by any code.

=cut

sub get_link_record {
    my ( $self, $link_key ) = @_;
    my %link_record = ();
    %link_record = %{ $$self{aldb}{$link_key} } if $$self{aldb}{$link_key};
    return %link_record;
}

sub _write_link {
    my ( $self, $address, $deviceid, $group, $is_controller, $data1, $data2,
        $data3 )
      = @_;
    if ($address) {
        &::print_log( "[Insteon::ALDB_i1] "
              . $$self{device}->get_object_name
              . " address: $address found for device: $deviceid and group: $group"
        );

        # change address for start of change to be address + offset
        if ( $$self{_mem_activity} eq 'update' ) {
            $address = sprintf( '%04X', hex($address) + 5 );
        }
        $$self{pending_aldb}{address}       = $address;
        $$self{pending_aldb}{deviceid}      = lc $deviceid;
        $$self{pending_aldb}{group}         = lc $group;
        $$self{pending_aldb}{is_controller} = $is_controller;
        $$self{pending_aldb}{data1} = ( defined $data1 ) ? lc $data1 : '00';
        $$self{pending_aldb}{data2} = ( defined $data2 ) ? lc $data2 : '00';
        $$self{pending_aldb}{data3} = ( defined $data3 ) ? lc $data3 : '00';
        $self->_peek($address);
    }
    else {
        &::print_log( "[Insteon::ALDB_i1] WARN: "
              . $$self{device}->get_object_name
              . " write_link failure: no address available for record to device: $deviceid and group: $group"
              . " and is_controller: $is_controller" );
        if ( $$self{_success_callback} ) {

            package main;
            eval( $$self{_success_callback} );
            &::print_log(
                "[Insteon::ALDB_i1] WARN1: Error encountered during ack callback: "
                  . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::ALDB_i1;
        }
    }
}

sub _peek {
    my ( $self, $address, $extended ) = @_;
    my $msb = substr( $address, 0, 2 );
    my $lsb = substr( $address, 2, 2 );
    if ($extended) {
        my $message =
          $self->device->derive_message( 'peek', 'insteon_ext_send',
            $lsb . "0000000000000000000000000000" );
        $self->interface->queue_message($message);

    }
    else {
        $$self{_mem_lsb}    = $lsb;
        $$self{_mem_msb}    = $msb;
        $$self{_mem_action} = 'aldb_peek';
        &::print_log( "[Insteon::ALDB_i1] "
              . $$self{device}->get_object_name
              . " accessing memory at location: 0x"
              . $address );
        my $message =
          new Insteon::InsteonMessage( 'insteon_send', $$self{device},
            'set_address_msb' );
        $message->extra($msb);
        $message->failure_callback( $$self{_failure_callback} );
        $self->_send_cmd($message);

        #		$self->_send_cmd('command' => 'set_address_msb', 'extra' => $msb, 'is_synchronous' => 1);
    }
}

=back

=head2 INI PARAMETERS

None

=head2 AUTHOR

Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

package Insteon::ALDB_i2;

=head1 B<Insteon::ALDB_i2>

=head2 SYNOPSIS

Unique class for storing a cahced copy of a verion i2 device's ALDB.

=head2 DESCRIPTION

Generally this object should be interacted with through the insteon objects and 
not by directly calling any of the following methods.

=head2 INHERITS

L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>

=head2 METHODS

=over

=cut

use strict;

@Insteon::ALDB_i2::ISA = ('Insteon::AllLinkDatabase');

=item C<new()>

Instantiate a new object.

=cut

sub new {
    my ( $class, $device ) = @_;

    my $self = new Insteon::AllLinkDatabase($device);
    bless $self, $class;
    $self->aldb_version("I2");
    return $self;
}

=item C<on_read_write_aldb()>

Called as part of any process to read or write to a device's ALDB.

=cut

sub on_read_write_aldb {
    my ( $self, %msg ) = @_;
    my $clear_message = 1;    #Default Action is to Clear the Current Message
    &::print_log( "[Insteon::ALDB_i2] DEBUG3: "
          . $$self{device}->get_object_name . " [0x"
          . $$self{_mem_msb}
          . $$self{_mem_lsb}
          . "] received: "
          . lc $msg{extra}
          . " for _mem_activity="
          . $$self{_mem_activity}
          . " _mem_action="
          . $$self{_mem_action} )
      if $self->{device}->debuglevel( 3, 'insteon' );

    if ( $$self{_mem_action} eq 'aldb_i2read' ) {

        #This is an ACK. Will be followed by a Link Data message, so don't clear
        $clear_message = 0;

        #Only move to the next state if the received message is a device ack
        #if the ack is dropped the retransmission logic will resend the request
        if ( $msg{is_ack} ) {
            $$self{_mem_action} = 'aldb_i2readack';
            &::print_log( "[Insteon::ALDB_i2] DEBUG3: "
                  . $$self{device}->get_object_name . " [0x"
                  . $$self{_mem_msb}
                  . $$self{_mem_lsb}
                  . "] received ack" )
              if $self->{device}->debuglevel( 3, 'insteon' );
        }
        else {
            #otherwise just ignore the message because it is out of sequence
            &::print_log( "[Insteon::ALDB_i2] DEBUG3: "
                  . $$self{device}->get_object_name . " [0x"
                  . $$self{_mem_msb}
                  . $$self{_mem_lsb}
                  . "] ack not received. "
                  . "ignoring message" )
              if $self->{device}->debuglevel( 3, 'insteon' );
        }

    }
    elsif ( $$self{_mem_action} eq 'aldb_i2readack' ) {
        if ( $msg{is_ack} ) {
            &::print_log( "[Insteon::ALDB_i2] DEBUG3: "
                  . $$self{device}->get_object_name . " [0x"
                  . $$self{_mem_msb}
                  . $$self{_mem_lsb}
                  . "] received duplicate ack. Ignoring." )
              if $self->{device}->debuglevel( 3, 'insteon' );
            $clear_message = 0;
        }
        elsif ( length( $msg{extra} ) < 30 ) {
            &::print_log(
                "[Insteon::ALDB_i2] WARNING: Corrupted I2 response not processed: "
                  . $$self{device}->get_object_name . " [0x"
                  . $$self{_mem_msb}
                  . $$self{_mem_lsb}
                  . "] received: "
                  . lc $msg{extra} . " for "
                  . $$self{_mem_action} )
              if $self->{device}->debuglevel( 3, 'insteon' );
            $$self{device}->corrupt_count_log(1)
              if $$self{device}->can('corrupt_count_log');

            #can't clear message, if valid message doesn't arrive
            #resend logic will kick in
            $clear_message = 0;
        }
        elsif ( $$self{_mem_msb}
            . $$self{_mem_lsb} ne '0000'
            and $$self{_mem_msb}
            . $$self{_mem_lsb} ne substr( $msg{extra}, 6, 4 ) )
        {
            ::print_log(
                "[Insteon::ALDB_i2] WARNING: Corrupted I2 response not processed, "
                  . " address received did not match address requested: "
                  . $$self{device}->get_object_name . " [0x"
                  . $$self{_mem_msb}
                  . $$self{_mem_lsb}
                  . "] received: "
                  . lc $msg{extra} . " for "
                  . $$self{_mem_action} )
              if $self->{device}->debuglevel( 3, 'insteon' );
            $$self{device}->corrupt_count_log(1)
              if $$self{device}->can('corrupt_count_log');

            #can't clear message, if valid message doesn't arrive
            #resend logic will kick in
            $clear_message = 0;
        }
        elsif ( $$self{_stress_test_act} ) {
            $$self{_mem_activity}    = undef;
            $$self{_mem_action}      = undef;
            $$self{_stress_test_act} = 0;
            $$self{device}->stress_test();
        }
        else {
            # init the link table if at the very start of a scan
            if ( lc $$self{_mem_msb} eq '00' and lc $$self{_mem_lsb} eq '00' ) {
                main::print_log(
                    "[Insteon::ALDB_i2] DEBUG4: Start of scan; initializing aldb structure"
                ) if $self->{device}->debuglevel( 4, 'insteon' );

                # reinit the aldb hash as there will be a new one
                $$self{aldb} = undef;

                # reinit the empty address list
                @{ $$self{aldb}{empty} } = ();

                # and, also the duplicates list
                @{ $$self{aldb}{duplicates} } = ();
                $$self{_mem_msb} = substr( $msg{extra}, 6, 2 );
                $$self{_mem_lsb} = substr( $msg{extra}, 8, 2 );
            }

            #$msg{extra} includes cmd2 at the beginning so cmd2.d1.d2.d3...
            #e.g. 0001010fff00a2042042d3fe1c00cc
            # 0:cmd2:00       - unused
            # 2:  D1:01       - unused
            # 4:  D2:01       - command (read aldb response)
            # 6:  D3:0fff     - aldb address (first entry in this case)
            #10:  D5:00       - unused in responses
            #12:  D6:a2       - flags
            #14:  D7:04       - group number
            #16:  D8:11.31.a2 - device id
            #22: D11:fe       - link data 1
            #24: D12:1c       - link data 2
            #26: D13:00       - link data 3 (unused)
            #28: D14:cc       - unused in i2; checksum in i2CS

            $$self{pending_aldb}{address} = substr( $msg{extra}, 6, 4 );

            $$self{pending_aldb}{flag} = substr( $msg{extra}, 12, 2 );
            my $flag = hex( $$self{pending_aldb}{flag} );
            $$self{pending_aldb}{inuse}         = ( $flag & 0x80 ) ? 1 : 0;
            $$self{pending_aldb}{is_controller} = ( $flag & 0x40 ) ? 1 : 0;
            $$self{pending_aldb}{highwater}     = ( $flag & 0x02 ) ? 1 : 0;
            unless ( $$self{pending_aldb}{highwater} ) {

                #highwater is set for every entry that has been used before
                #highwater being 0 indicates entry has never been used (i.e. top of list)
                # since this is the last unused memory location, then add it to the empty list
                &::print_log(
                    "[Insteon::ALDB_i2] WARNING: highwater not set but marked inuse: "
                      . $$self{device}->get_object_name . " [0x"
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] received: "
                      . lc $msg{extra} . " for "
                      . $$self{_mem_action} )
                  if ( ( $$self{pending_aldb}{inuse} )
                    and $self->{device}->debuglevel( 3, 'insteon' ) );
                main::print_log(
                    "[Insteon::ALDB_i2] DEBUG4: scan done; adding last address ["
                      . $$self{_mem_msb}
                      . $$self{_mem_lsb}
                      . "] to empty array" )
                  if $self->{device}->debuglevel( 4, 'insteon' );
                $self->add_empty_address( $$self{_mem_msb} . $$self{_mem_lsb} );

                # scan done; clear out state flags
                $$self{_mem_action}   = undef;
                $$self{_mem_activity} = undef;
                if (    lc $$self{_mem_msb} eq '0f'
                    and lc $$self{_mem_lsb} eq 'ff' )
                {
                    # set health as empty for now
                    $self->health("empty");
                }
                else {
                    $self->health("unchanged");
                }

                &::print_log( "[Insteon::ALDB_i2] "
                      . $$self{device}->get_object_name
                      . " completed link memory scan.  Status: "
                      . $self->health() )
                  if $self->{device}->debuglevel( 1, 'insteon' );
                $self->health("unchanged");

                # Put the new ALDB Delta into memory
                $self->query_aldb_delta('set');
            }
            else    #($$self{pending_aldb}{highwater})
            {
                unless ( $$self{pending_aldb}{inuse} ) {
                    main::print_log(
                        "[Insteon::ALDB_i2] DEBUG4: inuse flag == false; adding address ["
                          . $$self{_mem_msb}
                          . $$self{_mem_lsb}
                          . "] to empty array" )
                      if $self->{device}->debuglevel( 4, 'insteon' );
                    $self->add_empty_address( $$self{pending_aldb}{address} );
                }
                else {
                    $$self{pending_aldb}{group} =
                      lc substr( $msg{extra}, 14, 2 );
                    $$self{pending_aldb}{deviceid} =
                      lc substr( $msg{extra}, 16, 6 );
                    $$self{pending_aldb}{data1} =
                      lc substr( $msg{extra}, 22, 2 );
                    $$self{pending_aldb}{data2} =
                      lc substr( $msg{extra}, 24, 2 );
                    $$self{pending_aldb}{data3} =
                      lc substr( $msg{extra}, 26, 2 );

                    # save pending_aldb and then clear it out
                    my $aldbkey = $self->get_linkkey(
                        $$self{pending_aldb}{deviceid},
                        $$self{pending_aldb}{group},
                        $$self{pending_aldb}{is_controller},
                        $$self{pending_aldb}{data3}
                    );

                    # check for duplicates
                    if ( exists $$self{aldb}{$aldbkey}
                        && $$self{aldb}{$aldbkey}{inuse} )
                    {
                        main::print_log(
                            "[Insteon::ALDB_i2] DEBUG4: duplicate link found; adding address ["
                              . $$self{_mem_msb}
                              . $$self{_mem_lsb}
                              . "] to duplicates array" )
                          if $self->{device}->debuglevel( 4, 'insteon' );
                        $self->add_duplicate_link_address(
                            $$self{pending_aldb}{address} );
                    }
                    else {
                        main::print_log(
                            "[Insteon::ALDB_i2] DEBUG4: active link found; adding address ["
                              . $$self{_mem_msb}
                              . $$self{_mem_lsb}
                              . "] to aldb" )
                          if $self->{device}->debuglevel( 4, 'insteon' );
                        %{ $$self{aldb}{$aldbkey} } = %{ $$self{pending_aldb} };
                    }
                }

                #keep going; request the next record
                $self->send_read_aldb(
                    sprintf( "%04x", hex( $$self{pending_aldb}{address} ) - 8 )
                );

            }    #($$self{pending_aldb}{highwater})
        }    #else $msg{extra} !< 30
    }
    elsif ( $$self{_mem_action} eq 'aldb_i2writeack' ) {
        unless ( $$self{_mem_activity} eq 'delete' ) {
            ## update the aldb records w/ the changes that were made
            my $aldbkey = $self->get_linkkey(
                $$self{pending_aldb}{deviceid},
                $$self{pending_aldb}{group},
                $$self{pending_aldb}{is_controller},
                $$self{pending_aldb}{data3}
            );
            $$self{aldb}{$aldbkey}{data1} = $$self{pending_aldb}{data1};
            $$self{aldb}{$aldbkey}{data2} = $$self{pending_aldb}{data2};
            $$self{aldb}{$aldbkey}{data3} = $$self{pending_aldb}{data3};
            $$self{aldb}{$aldbkey}{inuse} =
              1;    # needed so that restore string will preserve record
            if ( $$self{_mem_activity} eq 'add' ) {
                $$self{aldb}{$aldbkey}{is_controller} =
                  $$self{pending_aldb}{is_controller};
                $$self{aldb}{$aldbkey}{deviceid} =
                  lc $$self{pending_aldb}{deviceid};
                $$self{aldb}{$aldbkey}{group} = lc $$self{pending_aldb}{group};
                $$self{aldb}{$aldbkey}{address} = $$self{pending_aldb}{address};
            }
            $$self{_mem_activity} = undef;
            $$self{_mem_action}   = undef;
            $$self{pending_aldb}  = undef;
            main::print_log( "[Insteon::ALDB_i2] DEBUG3: "
                  . $$self{device}->get_object_name
                  . " link write completed for ["
                  . $$self{aldb}{$aldbkey}{address}
                  . "]" )
              if $self->{device}->debuglevel( 3, 'insteon' );
            $self->health("unchanged");

            # Put the new ALDB Delta into memory
            $self->query_aldb_delta('set');
        }
        else {
            # clear out mem_activity flag
            $$self{_mem_activity} = undef;

            # add the address of the deleted link to the empty list
            $self->add_empty_address( $$self{pending_aldb}{address} );

            # and, remove from the duplicates list (if it is a member)
            $self->delete_duplicate_link_address(
                $$self{pending_aldb}{address} );
            if ( exists $$self{pending_aldb}{deviceid} ) {
                my $key = $self->get_linkkey(
                    $$self{pending_aldb}{deviceid},
                    $$self{pending_aldb}{group},
                    $$self{pending_aldb}{is_controller},
                    $$self{pending_aldb}{data3}
                );
                delete $$self{aldb}{$key};
            }
            $self->health("unchanged");

            # Put the new ALDB Delta into memory
            $self->query_aldb_delta('set');
        }
    }
    else {
        main::print_log( "[Insteon::ALDB_i2] "
              . $$self{device}->get_object_name
              . ": unhandled _mem_action="
              . $$self{_mem_action} )
          if $self->{device}->debuglevel( 1, 'insteon' );
        $clear_message = 0;
    }
    return $clear_message;
}

sub _write_link {
    my ( $self, $address, $deviceid, $group, $is_controller, $data1, $data2,
        $data3 )
      = @_;
    if ($address) {
        &::print_log( "[Insteon::ALDB_i2] "
              . $$self{device}->get_object_name
              . " writing address: $address for device: $deviceid and group: $group"
        );

        my $message =
          new Insteon::InsteonMessage( 'insteon_ext_send', $$self{device},
            'read_write_aldb' );

        #cmd2.00.write_aldb_record.addr_msb.addr_lsb.byte_count.d6-d14 bytes to write
        my $message_extra = '00' . '00' . '02';

        $$self{pending_aldb}{address} = $address;
        $message_extra .= $address;

        $message_extra .= '08';    #write 8 bytes

        #D6-D13 aldb entry:  flags.group.deviceid(3).data1.data2.data3
        #flags
        $$self{pending_aldb}{is_controller} = $is_controller;
        my $flag = ( $$self{pending_aldb}{is_controller} ) ? 'E2' : 'A2';
        $$self{pending_aldb}{flag} = $flag;
        $message_extra .= $flag;

        #group
        $$self{pending_aldb}{group} = lc $group;
        $message_extra .= $$self{pending_aldb}{group};

        #device ID
        $$self{pending_aldb}{deviceid} = lc $deviceid;
        $message_extra .= $$self{pending_aldb}{deviceid};

        #data1 - data3
        $$self{pending_aldb}{data1} = ( defined $data1 ) ? lc $data1 : '00';
        $message_extra .= $$self{pending_aldb}{data1};
        $$self{pending_aldb}{data2} = ( defined $data2 ) ? lc $data2 : '00';
        $message_extra .= $$self{pending_aldb}{data2};
        $$self{pending_aldb}{data3} = ( defined $data3 ) ? lc $data3 : '00';
        $message_extra .= $$self{pending_aldb}{data3};
        $message_extra .= '00';                          #byte 14
        $message->extra($message_extra);
        $$self{_mem_action} = 'aldb_i2writeack';
        $message->failure_callback( $$self{_failure_callback} );
        $self->_send_cmd($message);
    }
    else {
        &::print_log( "[Insteon::ALDB_i2] WARN: "
              . $$self{device}->get_object_name
              . " write_link failure: no address available for record to device: $deviceid and group: $group"
              . " and is_controller: $is_controller" );
        if ( $$self{_success_callback} ) {

            package main;
            eval( $$self{_success_callback} );
            &::print_log(
                "[Insteon::ALDB_i2] WARN1: Error encountered during ack callback: "
                  . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::ALDB_i2;
        }
    }
}

sub _write_delete {

    #pending_aldb must be populated before calling
    my ( $self, $address ) = @_;

    if ($address) {
        &::print_log( "[Insteon::ALDB_i2] "
              . $$self{device}->get_object_name
              . " writing address as deleted: $address" );

        my $message =
          new Insteon::InsteonMessage( 'insteon_ext_send', $$self{device},
            'read_write_aldb' );

        #cmd2.00.write_aldb_record.addr_msb.addr_mid.addr_lsb.byte_count.d6-d14 bytes to write
        my $message_extra = '00' . '00' . '02';
        $message_extra .= $address;
        $message_extra .= '08';       #write 8 bytes

        #D6-D13 aldb entry:  flags.group.deviceid(3).data1.data2.data3
        #flag = 02 deleted
        $message_extra .= '02';

        #group
        $message_extra .= '00';

        #device ID
        $message_extra .= '000000';

        #data1 - data3
        $message_extra .= '00';
        $message_extra .= '00';
        $message_extra .= '00';

        #byte 14
        $message_extra .= '00';

        $message->extra($message_extra);
        $$self{_mem_action} = 'aldb_i2writeack';
        $message->failure_callback( $$self{_failure_callback} );
        $self->_send_cmd($message);
    }
    else {
        &::print_log( "[Insteon::ALDB_i2] WARN: "
              . $$self{device}->get_object_name
              . " write_delete failure: no address available" );
        if ( $$self{_success_callback} ) {

            package main;
            eval( $$self{_success_callback} );
            &::print_log(
                "[Insteon::ALDB_i2] WARN1: Error encountered during ack callback: "
                  . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon::ALDB_i2;
        }
    }
}

=item C<send_read_aldb()>

Called as part of "scan link table" voice command.

=cut

sub send_read_aldb {
    my ( $self, $address ) = @_;

    $$self{_mem_msb} = substr( $address, 0, 2 );
    $$self{_mem_lsb} = substr( $address, 2, 2 );
    $$self{_mem_action} = 'aldb_i2read';
    main::print_log( "[Insteon::ALDB_i2] "
          . $$self{device}->get_object_name
          . " reading ALDB at location: 0x"
          . $address );
    my $message =
      new Insteon::InsteonMessage( 'insteon_ext_send', $$self{device},
        'read_write_aldb' );

    #cmd2.00.read_aldb_record.addr_msb.addr_lsb.record_count(0 for all).d6-d14 unused
    $message->extra( "00" . "00" . "00"
          . $$self{_mem_msb}
          . $$self{_mem_lsb} . "01"
          . "000000000000000000" );
    $message->failure_callback( $$self{_failure_callback} );
    $self->_send_cmd($message);
}

=back

=head2 INI PARAMETERS

None

=head2 AUTHOR

Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

package Insteon::ALDB_PLM;

=head1 B<Insteon::ALDB_PLM>

=head2 SYNOPSIS

Unique class for storing a cahced copy of a the PLM's link database.

=head2 DESCRIPTION

Generally this object should be interacted with through the insteon objects and 
not by directly calling any of the following methods.

=head2 INHERITS

L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>

=head2 METHODS

=over

=cut

use strict;

@Insteon::ALDB_PLM::ISA = ('Insteon::AllLinkDatabase');

=item C<new()>

Instantiate a new object.

=cut

sub new {
    my ( $class, $device ) = @_;

    my $self = new Insteon::AllLinkDatabase($device);
    bless $self, $class;
    return $self;
}

=item C<restore_string()>

This is called by mh on exit to save the cached ALDB of a device to persistant data.

=cut

sub restore_string {
    my ($self) = @_;
    my $restore_string = '';
    if ( $$self{aldb} ) {
        my $link = '';
        foreach my $link_key ( keys %{ $$self{aldb} } ) {
            $link .= '|' if $link;    # separate sections
            my %link_record = %{ $$self{aldb}{$link_key} };
            my $record      = '';
            foreach my $record_key ( keys %link_record ) {
                next unless $link_record{$record_key};
                $record .= ',' if $record;
                $record .= $record_key . '=' . $link_record{$record_key};
            }
            $link .= $record;
        }
        $restore_string .=
            $$self{device}->get_object_name
          . "->_aldb->restore_linktable(q~$link~) if "
          . $$self{device}->get_object_name
          . "->_aldb;\n";
    }
    if ( defined $self->scandatetime ) {
        $restore_string .=
            $$self{device}->get_object_name
          . "->_aldb->scandatetime(q~"
          . $self->scandatetime
          . "~) if "
          . $$self{device}->get_object_name
          . "->_aldb;\n";
    }
    $restore_string .=
        $$self{device}->get_object_name
      . "->_aldb->health(q~"
      . $self->health
      . "~) if "
      . $$self{device}->get_object_name
      . "->_aldb;\n";
    return $restore_string;
}

=item C<restore_linktable()>

Used to reload MisterHouse's cached version of a device's ALDB on restart.

=cut

sub restore_linktable {
    my ( $self, $links ) = @_;
    if ($links) {
        foreach my $link_section ( split( /\|/, $links ) ) {
            my %link_record   = ();
            my $deviceid      = '';
            my $groupid       = '01';
            my $is_controller = 0;
            my $subaddress    = '';
            foreach my $link_record ( split( /,/, $link_section ) ) {
                my ( $key, $value ) = split( /=/, $link_record );
                $deviceid      = $value if ( $key eq 'deviceid' );
                $groupid       = $value if ( $key eq 'group' );
                $is_controller = $value if ( $key eq 'is_controller' );
                $subaddress    = $value if ( $key eq 'data3' );
                $link_record{$key} = $value if $key and defined($value);
            }
            my $linkkey =
              $self->get_linkkey( $deviceid, $groupid, $is_controller,
                $subaddress );
            %{ $$self{aldb}{ lc $linkkey } } = %link_record;
        }
    }
}

=item C<log_alllink_table()>

Prints a human readable form of MisterHouse's cached version of a device's ALDB
to the print log.  Called as part of the "scan links" voice command
or in response to the "log links" voice command.

=cut

sub log_alllink_table {
    my ($self) = @_;
    &::print_log( "[Insteon::ALDB_PLM] Link table health: " . $self->health );
    foreach my $linkkey ( sort( keys( %{ $$self{aldb} } ) ) ) {
        my $is_controller = $$self{aldb}{$linkkey}{is_controller};
        my $group         = $$self{aldb}{$linkkey}{group};
        $group = '01' if $group eq '00';
        my $deviceid        = $$self{aldb}{$linkkey}{deviceid};
        my $linked_subgroup = '01';
        my $controller_device;
        my $controller_name;
        if ( !$is_controller ) {
            $linked_subgroup = $group;
        }
        elsif ( $group ne '00' && $group ne '01' ) {
            $controller_device = Insteon::get_object( '000000', $group );

            $controller_name =
              defined($controller_device)
              ? $controller_device->get_object_name
              : "unknown scene";
            $controller_name .= " ($group)";
        }
        else {
            $controller_name = $group;
        }
        my $linked_object = Insteon::get_object( $deviceid, $linked_subgroup );
        my $linked_name = '';
        if ($linked_object) {
            $linked_name = $linked_object->get_object_name;
        }
        else {
            $linked_name =
                uc substr( $deviceid, 0, 2 ) . '.'
              . uc substr( $deviceid, 2, 2 ) . '.'
              . uc substr( $deviceid, 4, 2 );
        }
        &::print_log(
            "[Insteon::ALDB_PLM] "
              . (
                ($is_controller)
                ? "cntlr($controller_name) record to " . $linked_name
                : "responder record to "
                  . $linked_name
                  . "($$self{aldb}{$linkkey}{group})"
              )
              . " (d1=$$self{aldb}{$linkkey}{data1}, d2=$$self{aldb}{$linkkey}{data2}, "
              . "d3=$$self{aldb}{$linkkey}{data3})"
        );
    }
}

=item C<parse_alllink()>

Parses the alllink message sent from the PLM.

=cut

sub parse_alllink {
    my ( $self, $data ) = @_;
    if ( substr( $data, 0, 6 ) ) {
        my %link = ();
        my $flag = substr( $data, 0, 1 );
        $link{is_controller} = ( hex($flag) & 0x04 ) ? 1 : 0;
        $link{flags} = substr( $data, 0, 2 );
        $link{group}    = lc substr( $data, 2, 2 );
        $link{deviceid} = lc substr( $data, 4, 6 );
        $link{data1} = substr( $data, 10, 2 );
        $link{data2} = substr( $data, 12, 2 );
        $link{data3} = substr( $data, 14, 2 );
        my $key = $self->get_linkkey(
            $link{deviceid},      $link{group},
            $link{is_controller}, $link{data3}
        );
        %{ $$self{aldb}{ lc $key } } = %link;
    }
}

=item C<get_first_alllink()>

Sends the request for the first alllink entry on the PLM.

=cut

sub get_first_alllink {
    my ($self) = @_;
    $self->health('changed')
      ;    # set as corrupt and allow acknowledge to set otherwise
    $$self{device}->queue_message(
        new Insteon::InsteonMessage( 'all_link_first_rec', $$self{device} ) );
}

=item C<get_next_alllink()>

Sends the request for the next alllink entry on the PLM.

=cut

sub get_next_alllink {
    my ($self) = @_;
    $$self{device}->queue_message(
        new Insteon::InsteonMessage( 'all_link_next_rec', $$self{device} ) );
}

=item C<delete_orphan_links()>

Reviews the cached version of all of the ALDBs and based on this review removes
links from this device which are not present in the mht file, not defined in the 
code, or links which are only half-links..

=cut

sub delete_orphan_links {
    my ( $self, $audit_mode ) = @_;

    &::print_log(
        "[Insteon::ALDB_PLM] #### NOW BEGINNING DELETE ORPHAN LINKS ####");
    @{ $$self{_delete_device_failures} } = ();

    $self->SUPER::delete_orphan_links($audit_mode);

    # iterate over all registered objects and compare whether the link tables match defined scene linkages in known Insteon_Links
    for my $obj ( &Insteon::find_members('Insteon::BaseDevice') ) {

        #Match on real objects only
        if ( ( $obj->is_root ) ) {
            my %delete_req =
              ( 'root_object' => $obj, 'audit_mode' => $audit_mode );
            push @{ $$self{delete_queue} }, \%delete_req;
        }
    }

    $self->_process_delete_queue();
}

sub _process_delete_queue {
    my ( $self, $p_num_deleted ) = @_;
    $$self{delete_queue_processed} += $p_num_deleted if $p_num_deleted;
    my $num_in_queue = @{ $$self{delete_queue} };
    if ($num_in_queue) {
        my $delete_req_ptr   = shift( @{ $$self{delete_queue} } );
        my %delete_req       = %$delete_req_ptr;
        my $failure_callback = $$self{device}->get_object_name
          . "->_aldb->_process_delete_queue_failure";

        # distinguish between deleting PLM links and processing delete orphans for a root item
        if ( $delete_req{'root_object'} ) {
            $$self{current_delete_device} =
              $delete_req{'root_object'}->get_object_name;
            my $is_batch_mode = 1;
            $delete_req{'root_object'}
              ->delete_orphan_links( ( $delete_req{'audit_mode'} ) ? 1 : 0,
                $failure_callback, $is_batch_mode );
        }
        else {
            $$self{current_delete_device} = $$self{device}->get_object_name;
            &::print_log(
                "[Insteon::ALDB_PLM] now deleting orphaned link w/ details: "
                  . (
                    ( $delete_req{is_controller} )
                    ? "controller($delete_req{data3})"
                    : "responder"
                  )
                  . ", "
                  . (
                    ( $delete_req{object} )
                    ? "object=" . $delete_req{object}->get_object_name
                    : "deviceid=$delete_req{deviceid}"
                  )
                  . ", group=$delete_req{group}"
            ) if $self->{device}->debuglevel( 1, 'insteon' );
            $delete_req{failure_callback} = $failure_callback;
            $self->delete_link(%delete_req);
            $$self{delete_queue_processed}++;
        }
    }
    else {
        ::print_log("[Insteon::ALDB_PLM] Delete All Links has Completed.");
        my $_delete_failure_cnt = scalar $$self{_delete_device_failures};
        if ($_delete_failure_cnt) {
            my $obj_list;
            for my $failed_obj ( @{ $$self{_delete_device_failures} } ) {
                $obj_list .= $failed_obj . ", ";
            }
            ::print_log( "[Insteon::ALDB_PLM] However, some failures were "
                  . "noted with the following devices: $obj_list" );
        }
        ::print_log(
            "[Insteon::ALDB_PLM] A total of $$self{delete_queue_processed} orphaned link records were deleted."
        );
        ::print_log("[Insteon::ALDB_PLM] #### END DELETE ORPHAN LINKS ####");
    }
}

sub _process_delete_queue_failure {
    my ($self) = @_;
    push @{ $$self{_delete_device_failures} }, $$self{current_delete_device};
    ::print_log(
        "[Insteon::ALDB_PLM] WARN: failure occurred when deleting orphan links from: "
          . $$self{current_delete_device}
          . ".  Moving on..." );
    $self->health('changed');
    $self->_process_delete_queue;

}

=item C<delete_link([link details])>

Deletes a specific link from a device.  Generally called by C<delete_orphan_links()>.

=cut

sub delete_link {

    # linkkey is concat of: deviceid, group, is_controller
    my ( $self, $parms_text ) = @_;
    my %link_parms;
    if ( @_ > 2 ) {
        shift @_;
        %link_parms = @_;
    }
    else {
        %link_parms = &main::parse_func_parms($parms_text);
    }
    my $num_deleted    = 0;
    my $insteon_object = $link_parms{object};
    my $deviceid =
      ($insteon_object) ? $insteon_object->device_id : $link_parms{deviceid};
    my $group = $link_parms{group};
    my $is_controller = ( $link_parms{is_controller} ) ? 1 : 0;
    my $subaddress = ( defined $link_parms{data3} ) ? $link_parms{data3} : '00';
    my $linkkey =
      $self->get_linkkey( $deviceid, $group, $is_controller, $subaddress );

    if ( defined $$self{aldb}{$linkkey} ) {
        my $cmd = '80'
          . $$self{aldb}{$linkkey}{flags}
          . $$self{aldb}{$linkkey}{group}
          . $$self{aldb}{$linkkey}{deviceid}
          . $$self{aldb}{$linkkey}{data1}
          . $$self{aldb}{$linkkey}{data2}
          . $$self{aldb}{$linkkey}{data3};
        delete $$self{aldb}{$linkkey};
        $num_deleted = 1;
        my $message =
          new Insteon::InsteonMessage( 'all_link_manage_rec', $$self{device} );
        $$self{_success_callback} =
          ( $link_parms{callback} ) ? $link_parms{callback} : undef;
        $$self{_failure_callback} =
          ( $link_parms{failure_callback} )
          ? $link_parms{failure_callback}
          : undef;
        $message->interface_data($cmd);
        $$self{device}->queue_message($message);
    }
    else {
        &::print_log(
                "[Insteon::ALDB_PLM] no entry in linktable could be found for: "
              . "deviceid=$deviceid, group=$group, is_controller=$is_controller, subaddress=$subaddress"
        );
        if ( $link_parms{callback} ) {

            package main;
            eval( $link_parms{callback} );
            &::print_log( "[Insteon_PLM] error in add link callback: " . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon_PLM;
        }
    }
    return $num_deleted;
}

=item C<add_link(link_params)>

Adds the link to the device's ALDB.  Generally called from the "sync links" or 
"link to interface" voice commands.

=cut

sub add_link {
    my ( $self, $parms_text ) = @_;
    my %link_parms;
    if ( @_ > 2 ) {
        shift @_;
        %link_parms = @_;
    }
    else {
        %link_parms = &main::parse_func_parms($parms_text);
    }
    my $device_id;
    my $group = ( $link_parms{group} ) ? $link_parms{group} : '01';
    my $insteon_object = $link_parms{object};
    if ( !( defined($insteon_object) ) ) {
        $device_id = lc $link_parms{deviceid};
        $insteon_object = &Insteon::get_object( $device_id, $group );
    }
    else {
        $device_id = lc $insteon_object->device_id;
    }
    my $is_controller = ( $link_parms{is_controller} ) ? 1 : 0;
    my $subaddress = ( defined $link_parms{data3} ) ? $link_parms{data3} : '00';
    my $linkkey =
      $self->get_linkkey( $device_id, $group, $is_controller, $subaddress );
    if ( defined $$self{aldb}{$linkkey} ) {
        &::print_log(
            "[Insteon::ALDB_PLM] WARN: attempt to add link to PLM that already exists! "
              . "deviceid=$device_id, group=$group, is_controller=$is_controller, subaddress=$subaddress"
        );
        if ( $link_parms{callback} ) {

            package main;
            eval( $link_parms{callback} );
            &::print_log(
                "[Insteon::ALDB_PLM] error in add link callback: " . $@ )
              if $@ and $self->{device}->debuglevel( 1, 'insteon' );

            package Insteon_PLM;
        }
    }
    else {
        # The modem developers guide appears to be wrong regarding control
        # codes.  40 and 41 will respond with a NACK if a record for that
        # group/device/is_controller combination already exist.  It appears
        # that code 20 can be used to edit existing but not create new records.
        # However, since data1-3 are consistent for all PLM links we never
        # really need to update a PLM link.  NB prior MH code did not set
        # data3 on control records to the group, however this does not
        # appear to have any adverse effects, and the current MH code will
        # not flag these entries as being incorrect or requiring an update
        my $control_code = ($is_controller) ? '40' : '41';

        # flags should be 'a2' for responder and 'e2' for controller
        my $flags = ($is_controller) ? 'E2' : 'A2';
        my $data1 =
          ( defined $link_parms{data1} )
          ? $link_parms{data1}
          : ( ($is_controller) ? '01' : '00' );
        my $data2 = ( defined $link_parms{data2} ) ? $link_parms{data2} : '00';
        my $data3 = ( defined $link_parms{data3} ) ? $link_parms{data3} : '00';

        # from looking at manually linked records, data1 and data2 are both 00 for responder records
        # and, data1 is 01 and usually data2 is 00 for controller records

        my $cmd =
            $control_code
          . $flags
          . $group
          . $device_id
          . $data1
          . $data2
          . $data3;
        $$self{aldb}{$linkkey}{flags}         = lc $flags;
        $$self{aldb}{$linkkey}{group}         = lc $group;
        $$self{aldb}{$linkkey}{is_controller} = $is_controller;
        $$self{aldb}{$linkkey}{deviceid}      = lc $device_id;
        $$self{aldb}{$linkkey}{data1}         = lc $data1;
        $$self{aldb}{$linkkey}{data2}         = lc $data2;
        $$self{aldb}{$linkkey}{data3}         = lc $data3;
        $$self{aldb}{$linkkey}{inuse}         = 1;
        $self->health('unchanged') if ( $self->health() eq 'empty' );
        my $message =
          new Insteon::InsteonMessage( 'all_link_manage_rec', $$self{device} );
        $message->interface_data($cmd);
        $$self{_success_callback} =
          ( $link_parms{callback} ) ? $link_parms{callback} : undef;
        $$self{_failure_callback} =
          ( $link_parms{failure_callback} )
          ? $link_parms{failure_callback}
          : undef;
        $message->interface_data($cmd);
        $$self{device}->queue_message($message);
    }
}

=item C<add_link_to_hash()>

This is used in response to an all_link_complete command received by the PLM.
This may be from the C<Insteon::BaseInterface::link_to_interface_i2cs> routine, 
or it may be as a result of a manual link creation. This routine manually adds 
a record to MH's cache of the PLM ALDB.  Normally you only want to add records 
during a scan of the ALDB, so use this routine with caution.

=cut

sub add_link_to_hash {
    my ( $self, $flags, $group, $is_controller,
        $device_id, $data1, $data2, $data3 )
      = @_;
    my $linkkey =
      $self->get_linkkey( $device_id, $group, $is_controller, $data3 );
    $$self{aldb}{$linkkey}{flags}         = lc $flags;
    $$self{aldb}{$linkkey}{group}         = lc $group;
    $$self{aldb}{$linkkey}{is_controller} = $is_controller;
    $$self{aldb}{$linkkey}{deviceid}      = lc $device_id;
    $$self{aldb}{$linkkey}{data1}         = lc $data1;
    $$self{aldb}{$linkkey}{data2}         = lc $data2;
    $$self{aldb}{$linkkey}{data3}         = lc $data3;
    $$self{aldb}{$linkkey}{inuse}         = 1;
    $self->health('unchanged') if ( $self->health() eq 'empty' );
    return;
}

=item C<has_link(link_details)>

Checks and returns true if a link with the passed details exists on the device
or false if it does not.  Generally called as part of C<delete_orphan_links()>.

=cut

sub has_link {
    my ( $self, $insteon_object, $group, $is_controller, $data3 ) = @_;
    my $key = $self->get_linkkey( $insteon_object->device_id,
        $group, $is_controller, $data3 );

    my $found = 0;
    $found++ if ( defined $$self{aldb}{$key} );

    return ($found);
}

=back

=head2 INI PARAMETERS

None

=head2 AUTHOR

Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
