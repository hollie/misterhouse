# Category=Insteon

#@ This module creates voice commands for all Insteon_Device, Insteon_Link and Insteon_PLM items.

my (@_insteon_plm,@_insteon_device,@_insteon_link);
$_scan_link_tables_v = new Voice_Cmd 'Scan all link tables';

if ($_scan_link_tables_v->state_now()) {
   &_get_next_linkscan();
}

sub _get_next_linkscan
{
    my ($current_name) = @_;
    my @devices = ();
    push @devices,@_insteon_plm;
    push @devices,@_insteon_device;
    my $return_next = ($current_name) ? 0 : 1;
    my $next_name = undef;
    foreach my $name (@devices) {
       if ($return_next) {
          $next_name = $name;
          last;
       }
       $return_next = 1 if $current_name eq $name;
    }
    $return_next = 0 if !($next_name) or $current_name eq $next_name;
    if ($return_next) {
       my $obj = $objects_by_object_name{$next_name};
       if ($obj) {
          $current_name = $next_name;
          &main::print_log("[Scan all link tables] Now scanning: " . $obj->get_object_name);
          $obj->scan_link_table('&main::_get_next_linkscan(\'' . $next_name . '\')');
       }
    } else {
       $current_name = undef;
       return undef;
    }
}

sub uninstall_insteon_item_commands {
    &trigger_delete('scan insteon link tables');
}

if ($Reload) {

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
           $states = 'on,off'; #,resume,enroll,unenroll,manual'; 
           my $cmd_states = $states;
           if ($object->device_id eq '000000') {
              $cmd_states .= ',initiate linking as controller,cancel linking,sync links';
           } else {
              $cmd_states .= ",link to interface,unlink with interface";
           }
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           if ($object->device_id eq '000000') {
              $object_string .= "$object_name_v -> tie_event('$object_name->initiate_linking_as_controller(\"$group\")', 'initiate linking as controller');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->interface()->cancel_linking','cancel linking');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->sync_links()','sync links');\n\n";
           } else {
              $object_string .= "$object_name_v -> tie_event('$object_name->link_to_interface','link to interface');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->unlink_to_interface','unlink with interface');\n\n";
           }
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

