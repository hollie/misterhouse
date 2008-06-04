# Category=Insteon

#@ This module creates voice commands for all Insteon_Device, Insteon_Link and Insteon_PLM items.

my (@_insteon_plm,@_insteon_device,@_insteon_link,@_scannable_link,$_scan_cnt,$_scan_failure_cnt,$_sync_cnt,$_sync_failure_cnt);

$_scan_link_tables_v = new Voice_Cmd 'Scan all link tables';

if ($_scan_link_tables_v->state_now()) {
   &_get_next_linkscan() unless $_scan_cnt; # prevent multiple concurrent scans
}

sub _get_next_linkscan
{
    my ($current_name, $prior_failure) = @_;
    if ($prior_failure) {
       $_scan_failure_cnt++;
    } else {
       $_scan_failure_cnt = 0;
    }
    my @devices = ();
    push @devices,@_insteon_plm;
    push @devices,@_insteon_device;
    push @devices,@_scannable_link;
    my $dev_cnt = @devices;
    my $return_next = ($current_name) ? 0 : 1;
    my $next_name = undef;

    if ($current_name) {
       for (my $i=0; $i<$dev_cnt; $i++) {
          if ($devices[$i] eq $current_name) {
             if ($_scan_failure_cnt == 0) {
                # get the next
                $next_name = $devices[$i+1] if $i+1 < $dev_cnt;
                $_scan_cnt = $i + 2;
                # remove the queue_timer_callback
                my $current_obj = $objects_by_object_name{$current_name};
                if (!($current_obj->isa('Insteon_PLM'))) {
                   $current_obj->queue_timer_callback('');
                }
             } elsif ($_scan_failure_cnt == 1) { 
                # try again
                $next_name = $current_name;
                &main::print_log("[Scan all link tables] WARN: failure occurred when scanning $current_name.  Trying again...");
                $_scan_cnt = $i + 1;
             } else {
                # skip because this is a repeat failure
                $next_name = $devices[$i+1] if $i+1 < $dev_cnt;
                &main::print_log("[Scan all link tables] WARN: failure occurred when scanning $current_name.  Moving on...");
                $_scan_failure_cnt = 0; # reset failure counter
                $_scan_cnt = $i + 2;
                 # remove the queue_timer_callback
                my $current_obj = $objects_by_object_name{$current_name};
                if (!($current_obj->isa('Insteon_PLM'))) {
                   $current_obj->queue_timer_callback('');
                }
             }
            last;
          }
       }
    } else {
       if ($dev_cnt) {
          $next_name = $devices[0];
          $_scan_cnt = 1;
       }
    }

    if ($next_name) {
       my $obj = $objects_by_object_name{$next_name};
       if ($obj) {
          &main::print_log("[Scan all link tables] Now scanning: " . $obj->get_object_name . " ($_scan_cnt of $dev_cnt)");
          $obj->queue_timer_callback('&main::_get_next_linkscan(\'' . $next_name . '\',1)') unless $obj->isa('Insteon_PLM');
          $obj->scan_link_table('&main::_get_next_linkscan(\'' . $next_name . '\')');
       }
    } else {
       $_scan_cnt = 0;
       return undef;
    }
}

$_sync_links_v = new Voice_Cmd 'Sync all links';

if ($_sync_links_v->state_now()) {
   &_process_sync_links() unless $_sync_cnt;
}

sub _process_sync_links
{
    my ($current_name, $prior_failure) = @_;
    if ($prior_failure) {
       $_sync_failure_cnt++;
    } else {
       $_sync_failure_cnt = 0;
    }
    my @devices = ();
    push @devices,@_insteon_link;
    my $dev_cnt = @devices;
    my $return_next = ($current_name) ? 0 : 1;
    my $next_name = undef;

    if ($current_name) {
       for (my $i=0; $i<$dev_cnt; $i++) {
          if ($devices[$i] eq $current_name) {
             if ($_sync_failure_cnt ==0) {
                # get the next
                $next_name = $devices[$i+1] if $i+1 < $dev_cnt;
                $_sync_cnt = $i + 2;
                # remove the queue_timer_callback
                my $current_obj = $objects_by_object_name{$current_name};
                if (!($current_obj->isa('Insteon_PLM'))) {
                   $current_obj->queue_timer_callback('');
                }
            } elsif ($_sync_cnt == 1) {
                #try again
                $next_name = $current_name;
                &main::print_log("[Scan all link tables] WARN: failure occurred when syncing $current_name.  Trying again...");
                $_sync_cnt = $i + 1;
             } else {
                # skip because this is a repeat failure
                $next_name = $devices[$i+1] if $i+1 < $dev_cnt;
                &main::print_log("[Scan all link tables] WARN: failure occurred when syncing $current_name.  Moving on...");
                $_sync_failure_cnt = 0; # reset failure counter
                $_sync_cnt = $i + 2;
                # remove the queue_timer_callback
                my $current_obj = $objects_by_object_name{$current_name};
                if (!($current_obj->isa('Insteon_PLM'))) {
                   $current_obj->queue_timer_callback('');
                }
             }
          }
       }
    } elsif ($dev_cnt) {
       $next_name = $devices[0];
       $_sync_cnt = 1;
    }

    if ($next_name) {
       my $obj = $objects_by_object_name{$next_name};
       if ($obj) {
          &main::print_log("[Sync all links] Now syncing links: " . $obj->get_object_name . " ($_sync_cnt of $dev_cnt)");
          $obj->queue_timer_callback('&main::_process_sync_links(\'' . $next_name . '\',1)') unless $obj->isa('Insteon_PLM');
          $obj->sync_links('&main::_process_sync_links(\'' . $next_name . '\')');
       }
    } else {
       $_sync_cnt = 0;
       return undef;
    }
}


sub uninstall_insteon_item_commands {
    &trigger_delete('scan insteon link tables');
}

if ($Reload) {

    # initialize scan and sync counters
    $_scan_cnt = 0;
    $_sync_cnt = 0;

    # create trigger
    my $trig_cmd = "time_cron '00 02 * * *'";
    &trigger_set($trig_cmd,'&_get_next_linkscan()','NoExpire','scan insteon link tables')
       unless &trigger_get('scan insteon link tables');

    @_insteon_plm = ();
    @_insteon_device = ();
    @_insteon_link = ();
    my $insteon_menu_states = $config_parms{insteon_menu_states} if $config_parms{insteon_menu_states};
    &::print_log("Generating Voice commands for all Insteon objects");
    my $object_string;
    for my $object_name (keys %objects_by_object_name) {
        my $object = $objects_by_object_name{$object_name};
        next unless $object->isa('Insteon_Device') or $object->isa('Insteon_Link') or $object->isa('Insteon_PLM');
        my $command = $object_name;
        $command =~ s/^\$//;
        $command =~ tr/_/ /;
        my $object_name_v = $object_name . '_v';
        $object_string .= "use vars '${object_name}_v';\n";
        my $states = 'on,off';
        my $group = ($object->isa('Insteon_PLM')) ? '' : $object->group;
        if ($object->isa('Insteon_Link')) {
           $states = 'on,off,sync links'; #,resume,enroll,unenroll,manual'; 
           my $cmd_states = $states;
           if ($object->is_plm_controlled) {
              $cmd_states .= ',initiate linking as controller,cancel linking';
           } else {
              $cmd_states .= ",link to interface,unlink with interface";
           }
           if ($object->is_root and !($object->is_plm_controlled)) {
              $cmd_states .= ",status,scan link table,log links";
              push @_scannable_link, $object_name;
           }
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           if ($object->is_plm_controlled) {
              $object_string .= "$object_name_v -> tie_event('$object_name->initiate_linking_as_controller(\"$group\")', 'initiate linking as controller');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->interface()->cancel_linking','cancel linking');\n\n";
           } else {
              $object_string .= "$object_name_v -> tie_event('$object_name->link_to_interface','link to interface');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->unlink_to_interface','unlink with interface');\n\n";
           }
           if ($object->is_root and !($object->is_plm_controlled)) {
              $object_string .= "$object_name_v -> tie_event('$object_name->request_status','status');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->scan_link_table(\"" . '\$self->log_alllink_table' . "\")','scan link table');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->log_alllink_table()','log links');\n\n";
           }
           $object_string .= "$object_name_v -> tie_event('$object_name->sync_links()','sync links');\n\n";
           $object_string .= "$object_name_v -> tie_items($object_name, 'on');\n\n";
           $object_string .= "$object_name_v -> tie_items($object_name, 'off');\n\n";
           $object_string .= &store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_link_commands');
           push @_insteon_link, $object_name;
        } elsif ($object->isa('Insteon_Device')) {
           $states = $insteon_menu_states if $insteon_menu_states;
           my $cmd_states = "$states,status,scan link table,log links,update onlevel/ramprate"; #,on level,ramp rate";
           $cmd_states .= ",link to interface,unlink with interface" if $object->is_controller;
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           foreach my $state (split(/,/,$states)) {
              $object_string .= "$object_name_v -> tie_items($object_name, '$state');\n\n";
           }
           $object_string .= "$object_name_v -> tie_event('$object_name->log_alllink_table()','log links');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->request_status','status');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->update_local_properties','update onlevel/ramprate');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->scan_link_table(\"" . '\$self->log_alllink_table' . "\")','scan link table');\n\n";
           if ($object->is_controller) {
              $object_string .= "$object_name_v -> tie_event('$object_name->link_to_interface','link to interface');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->unlink_to_interface','unlink with interface');\n\n";
           }
# the remote_set_button_taps provide incorrect/inconsistent results
#           $object_string .= "$object_name_v -> tie_event('$object_name->remote_set_button_tap(1)','on level');\n\n";
#           $object_string .= "$object_name_v -> tie_event('$object_name->remote_set_button_tap(2)','ramp rate');\n\n";
           $object_string .= &store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_item_commands');
           push @_insteon_device, $object_name if $group eq '01'; # don't allow non-base items to participate
        } elsif ($object->isa('Insteon_PLM')) {
           my $cmd_states = "complete linking as responder,cancel linking,delete link with PLM,scan link table,log links,delete orphan links";
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->complete_linking_as_responder','complete linking as responder');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->initiate_unlinking_to_plm','delete link with PLM');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->cancel_linking','cancel linking');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->log_alllink_table','log links');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->scan_link_table(\"" . '\$self->log_alllink_table' . "\")','scan link table');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->delete_orphan_links','delete orphan links');\n\n";
           $object_string .= &store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_PLM_commands');
           push @_insteon_plm, $object_name;
        }
    }
    eval $object_string;
    print "Error in insteon_item_commands: $@\n" if $@;
}

