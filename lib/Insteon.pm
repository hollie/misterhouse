package Insteon;

use strict;

# Category=Insteon

#@ This module creates voice commands for all insteon related items.

my (@_insteon_plm,@_insteon_device,@_insteon_link,@_scannable_link,$_scan_cnt,$_scan_failure_cnt,$_sync_cnt,$_sync_failure_cnt);
my $init_complete;
my (@_scan_devices);

#my $_scan_link_tables_v = new Voice_Cmd 'Scan all link tables';

#if ($_scan_link_tables_v->state_now()) {
#   &_get_next_linkscan(); # unless $_scan_cnt; # prevent multiple concurrent scans
#}

sub _get_next_linkscan
{
    my ($current_name, $prior_failure) = @_;
    if ($prior_failure) {
       $_scan_failure_cnt++;
    } else {
       $_scan_failure_cnt = 0;
    }
    if (!(scalar(@_scan_devices))) {
       push @_scan_devices, &Insteon::active_interface;
       push @_scan_devices, &Insteon::find_members("Insteon::BaseDevice");
       $_scan_cnt = 0;
    }

    return unless scalar(@_scan_devices);

    my $current_obj = $_scan_devices[0];
    my $next_obj = $current_obj;
#    my @devices = ();
#    push @devices,@_insteon_plm;
#    push @devices,@_insteon_device;
#    push @devices,@_scannable_link;
#    my $dev_cnt = @devices;
#    my $return_next = ($current_name) ? 0 : 1;
#    my $next_name = undef;

#    if ($current_name) {
#       for (my $i=0; $i<$dev_cnt; $i++) {
#          if ($devices[$i] eq $current_name) {
             if ($_scan_failure_cnt == 0) {
                # get the next
#                $next_name = $devices[$i+1] if $i+1 < $dev_cnt;
		 $next_obj = shift @_scan_devices;
#                $_scan_cnt = $i + 2;
		$_scan_cnt += 1;
                # remove the queue_timer_callback
#                my $current_obj = &main::get_object_by_name($current_name);
                if (!($current_obj->isa('Insteon_PLM'))) {
#                   $current_obj->queue_timer_callback('');
                }
                # don't try to scan devices that are not responders
#                my $next_obj = &main::get_object_by_name($next_name);
                while (ref $next_obj and $next_obj->isa('Insteon::BaseDevice')
                     and !($next_obj->is_responder) and !($next_obj->isa('Insteon::InterfaceController'))) {
                   &main::print_log("[Scan all link tables] " . $next_obj->get_object_name . " is not a candidate for scanning.  Moving to next");
                   $next_obj = shift @_scan_devices;
                }
             } elsif ($_scan_failure_cnt == 1) {
                # try again
#                $next_name = $current_name;
		$next_obj = $current_obj;
                &main::print_log("[Scan all link tables] WARN: failure occurred when scanning " . $current_obj->get_object_name . ".  Trying again...");
#                $_scan_cnt = $i + 1;
             } else {
                # skip because this is a repeat failure
#                $next_name = $devices[$i+1] if $i+1 < $dev_cnt;
		$next_obj = shift @_scan_devices;
                &main::print_log("[Scan all link tables] WARN: failure occurred when scanning " . $current_obj->get_object_name . ".  Moving on...");
                $_scan_failure_cnt = 0; # reset failure counter
#                $_scan_cnt += $i + 2;
                 # remove the queue_timer_callback
#                my $current_obj = &main::get_object_by_name($current_name);
                if (!($current_obj->isa('Insteon_PLM'))) {
#                   $current_obj->queue_timer_callback('');
                }
             }
#            last;
#          }
#       }
#    } else {
#       if ($dev_cnt) {
#          $next_name = $devices[0];
#          $_scan_cnt = 1;
#       }
#    }

    if ($next_obj) {
#       my $obj = &main::get_object_by_name($next_name);
       if ($next_obj) {
          &main::print_log("[Scan all link tables] Now scanning: " . $next_obj->get_object_name . " ($_scan_cnt of ?)");
#          $next_obj->queue_timer_callback('&Insteon::_get_next_linkscan(\'' . $next_obj->get_object_name . '\',1)') unless $next_obj->isa('Insteon_PLM');
          $next_obj->scan_link_table('&Insteon::_get_next_linkscan(\'' . $next_obj->get_object_name . '\')');
       }
    } else {
       $_scan_cnt = 0;
       return undef;
    }
}

#my $_sync_links_v = new Voice_Cmd 'Sync all links';

#if ($_sync_links_v->state_now()) {
#   &_process_sync_links(); # unless $_sync_cnt;
#}

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
                my $current_obj = &main::get_object_by_name($current_name);
                if (!($current_obj->isa('Insteon_PLM'))) {
#                   $current_obj->queue_timer_callback('');
                }
                 # don't try to scan devices that are not responders
                my $next_obj = &main::get_object_by_name($next_name);
                if (ref $next_obj and $next_obj->isa('Insteon::BaseDevice')
                     and !($next_obj->is_responder) and !($next_obj->isa('Insteon::InterfaceController'))) {
                   &main::print_log("[Sync all links] $next_name is not a candidate for syncing.  Moving to next");
                   $current_name = $next_name;
                   # move on
                   next;
                }
            } elsif ($_sync_cnt == 1) {
                #try again
                $next_name = $current_name;
                &main::print_log("[Sync all links] WARN: failure occurred when syncing $current_name.  Trying again...");
                $_sync_cnt = $i + 1;
             } else {
                # skip because this is a repeat failure
                $next_name = $devices[$i+1] if $i+1 < $dev_cnt;
                &main::print_log("[Sync all links] WARN: failure occurred when syncing $current_name.  Moving on...");
                $_sync_failure_cnt = 0; # reset failure counter
                $_sync_cnt = $i + 2;
                # remove the queue_timer_callback
                my $current_obj = &main::get_object_by_name($current_name);
                if (!($current_obj->isa('Insteon_PLM'))) {
#                   $current_obj->queue_timer_callback('');
                }
             }
          }
       }
    } elsif ($dev_cnt) {
       $next_name = $devices[0];
       $_sync_cnt = 1;
    }

    if ($next_name) {
       my $obj = &main::get_object_by_name($next_name);
       if ($obj) {
          &main::print_log("[Sync all links] Now syncing links: " . $obj->get_object_name . " ($_sync_cnt of $dev_cnt)");
#          $obj->queue_timer_callback('&main::_process_sync_links(\'' . $next_name . '\',1)') unless $obj->isa('Insteon_PLM');
          $obj->sync_links('&Insteon::_process_sync_links(\'' . $next_name . '\')');
       }
    } else {
       $_sync_cnt = 0;
       return undef;
    }
}


sub uninstall_insteon_item_commands {
    &main::trigger_delete('scan insteon link tables');
}

sub init {

    # only run once
    return if $init_complete;
    $init_complete = 1;

    # initialize scan and sync counters
    $_scan_cnt = 0;
    $_sync_cnt = 0;
    @_scan_devices = ();

    # create trigger
    my $trig_cmd = "time_cron '00 02 * * *'";
    &main::trigger_set($trig_cmd,'&_get_next_linkscan()','NoExpire','scan insteon link tables')
       unless &main::trigger_get('scan insteon link tables');

    @_insteon_plm = ();
    @_insteon_device = ();
    @_insteon_link = ();

    my $insteon_menu_states = $main::config_parms{insteon_menu_states} if $main::config_parms{insteon_menu_states};
    &main::print_log("Generating Voice commands for all Insteon objects");
    my $object_string;
    for my $object (&main::list_all_objects) {
        next unless ref $object;
        next unless $object->isa('Insteon::BaseInterface') or $object->isa('Insteon::BaseObject');
        my $object_name = $object->get_object_name;
        # ignore the thermostat
        next if $object->isa('Insteon_Thermostat');
        my $command = $object_name;
        $command =~ s/^\$//;
        $command =~ tr/_/ /;
        my $object_name_v = $object_name . '_v';
        $object_string .= "use vars '${object_name}_v';\n";
        my $states = 'on,off';
        my $group = ($object->isa('Insteon_PLM')) ? '' : $object->group;
        if ($object->isa('Insteon::BaseController')) {
           $states = 'on,off,sync links'; #,resume,enroll,unenroll,manual';
           my $cmd_states = $states;
           if ($object->isa('Insteon::InterfaceController')) {
              $cmd_states .= ',initiate linking as controller,cancel linking';
           } else {
              $cmd_states .= ",link to interface,unlink with interface";
           }
           if ($object->is_root and !($object->isa('Insteon::InterfaceController'))) {
              $cmd_states .= ",status,scan link table,log links";
              push @_scannable_link, $object_name;
           }
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           if ($object->isa('Insteon::BaseController')) {
              $object_string .= "$object_name_v -> tie_event('$object_name->initiate_linking_as_controller(\"$group\")', 'initiate linking as controller');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->interface()->cancel_linking','cancel linking');\n\n";
           } else {
              $object_string .= "$object_name_v -> tie_event('$object_name->link_to_interface','link to interface');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->unlink_to_interface','unlink with interface');\n\n";
           }
           if ($object->is_root and !($object->isa('Insteon::InterfaceController'))) {
              $object_string .= "$object_name_v -> tie_event('$object_name->request_status','status');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->scan_link_table(\"" . '\$self->log_alllink_table' . "\")','scan link table');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->log_alllink_table()','log links');\n\n";
           }
           $object_string .= "$object_name_v -> tie_event('$object_name->sync_links()','sync links');\n\n";
           $object_string .= "$object_name_v -> tie_items($object_name, 'on');\n\n";
           $object_string .= "$object_name_v -> tie_items($object_name, 'off');\n\n";
           $object_string .= &main::store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_link_commands');
           push @_insteon_link, $object_name;
        } elsif ($object->isa('Insteon::BaseDevice')) {
           $states = $insteon_menu_states if $insteon_menu_states
           	&& ($object->can('is_dimmable') && $object->is_dimmable);
           my $cmd_states = "$states,status,scan link table,log links,update onlevel/ramprate"; #,on level,ramp rate";
           $cmd_states .= ",link to interface,unlink with interface" if $object->isa("Insteon::BaseController") || $object->is_controller;
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           foreach my $state (split(/,/,$states)) {
              $object_string .= "$object_name_v -> tie_items($object_name, '$state');\n\n";
           }
           $object_string .= "$object_name_v -> tie_event('$object_name->log_alllink_table()','log links');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->request_status','status');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->update_local_properties','update onlevel/ramprate');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->scan_link_table(\"" . '\$self->log_alllink_table' . "\")','scan link table');\n\n";
           if ($object->isa("Insteon::BaseController") || $object->is_controller) {
              $object_string .= "$object_name_v -> tie_event('$object_name->link_to_interface','link to interface');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->unlink_to_interface','unlink with interface');\n\n";
           }
# the remote_set_button_taps provide incorrect/inconsistent results
#           $object_string .= "$object_name_v -> tie_event('$object_name->remote_set_button_tap(1)','on level');\n\n";
#           $object_string .= "$object_name_v -> tie_event('$object_name->remote_set_button_tap(2)','ramp rate');\n\n";
           $object_string .= &main::store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_item_commands');
           push @_insteon_device, $object_name if $group eq '01'; # don't allow non-base items to participate
        } elsif ($object->isa('Insteon_PLM')) {
           my $cmd_states = "complete linking as responder,cancel linking,delete link with PLM,scan link table,log links,delete orphan links,scan all link tables,debug on, debug off";
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->complete_linking_as_responder','complete linking as responder');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->initiate_unlinking_as_controller','initiate unlinking');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->cancel_linking','cancel linking');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->log_alllink_table','log links');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->scan_link_table(\"" . '\$self->log_alllink_table' . "\")','scan link table');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->delete_orphan_links','delete orphan links');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->debug(1)','debug on');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->debug(0)','debug off');\n\n";
           $object_string .= "$object_name_v -> tie_event('&Insteon::_get_next_linkscan','scan all link tables');\n\n";
           $object_string .= &main::store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_PLM_commands');
           push @_insteon_plm, $object_name;
        }
    }

    package main;
    eval $object_string;
    print "Error in insteon_item_commands: $@\n" if $@;
    package Insteon;
}

sub add
{
   my ($object) = @_;

   my $insteon_manager = InsteonManager->instance();
   if ($insteon_manager->remove_item($object)) {
      # print out debug info
   }
   $insteon_manager->add_item($object);
}

sub find_members
{
   my ($name) = @_;

   my $insteon_manager = InsteonManager->instance();
   return $insteon_manager->find_members($name);
}


sub get_object
{
	my ($p_deviceid, $p_group) = @_;

	my $retObj = undef;

        my $insteon_manager = InsteonManager->instance();
        my @search_objects = ();
        push @search_objects, $insteon_manager->find_members('Insteon::BaseObject');
	for my $obj (@search_objects)
	{
		#Match on Insteon objects only
	#	if ($obj->isa("Insteon::Insteon_Device"))
	#	{
			if (lc $obj->device_id() eq lc $p_deviceid)
			{
				if ($p_group)
				{
					if (lc $p_group eq lc $obj->group)
					{
						$retObj = $obj;
						last;
					}
				} else {
					$retObj = $obj;
					last;
				}
			}
	#	}
	}

	return $retObj;
}

sub active_interface
{
   my ($interface) = @_;
   my $insteon_manager = InsteonManager->instance();

   $insteon_manager->_active_interface($interface) if $interface;
print "############### active interface is: " . $insteon_manager->_active_interface->get_object_name . "\n";
   return $insteon_manager->_active_interface;

}

package InsteonManager;

use strict;
use base 'Class::Singleton';

sub _new_instance
{
	my $class = shift;
	my $self = bless {}, $class;

	return $self;
}

sub _active_interface
{
   my ($self, $interface) = @_;
   # setup hooks the first time that an interface is made active
   if (!($$self{active_interface}) and $interface) {
      &main::print_log("[Insteon] Setting up initialization hooks") if $main::Debug{insteon};
      &main::MainLoop_pre_add_hook(\&Insteon::BaseInterface::check_for_data, 1);
      &main::Reload_post_add_hook(\&Insteon::BaseInterface::poll_all, 1);
      $Insteon::init_complete = 0;
      &main::MainLoop_pre_add_hook(\&Insteon::init, 1);
   }
   $$self{active_interface} = $interface if $interface;
   return $$self{active_interface};
}

sub add
{
	my ($self,@p_objects) = @_;

	my @l_objects;

	for my $l_object (@p_objects) {
		if ($l_object->isa('Group_Item') ) {
			@l_objects = $$l_object{members};
			for my $obj (@l_objects) {
				$self->add($obj);
			}
		} else {
		    $self->add_item($l_object);
        	}
	}
}

sub add_item
{
   my ($self,$p_object) = @_;

   push @{$$self{objects}}, $p_object;
   if ($p_object->isa('Insteon::BaseInterface') and !($self->_active_interface)) {
      $self->_active_interface($p_object);
   }
   return $p_object;
}

sub remove_all_items {
   my ($self) = @_;

   if (ref $$self{objects}) {
      foreach (@{$$self{objects}}) {
 #        $_->untie_items($self);
      }
   }
   delete $self->{objects};
}

sub add_item_if_not_present {
   my ($self, $p_object) = @_;

   if (ref $$self{objects}) {
      foreach (@{$$self{objects}}) {
         if ($_ eq $p_object) {
            return 0;
         }
      }
   }
   $self->add_item($p_object);
   return 1;
}

sub remove_item {
   my ($self, $p_object) = @_;

   if (ref $$self{objects}) {
      for (my $i = 0; $i < scalar(@{$$self{objects}}); $i++) {
         if ($$self{objects}->[$i] eq $p_object) {
            splice @{$$self{objects}}, $i, 1;
            return 1;
         }
      }
   }
   return 0;
}


sub is_member {
    my ($self, $p_object) = @_;

    my @l_objects = @{$$self{objects}};
    for my $l_object (@l_objects) {
	if ($l_object eq $p_object) {
	    return 1;
	}
    }
    return 0;
}

sub find_members {
	my ($self,$p_type) = @_;

	my @l_found;
	my @l_objects = @{$$self{objects}};
	for my $l_object (@l_objects) {
		if ($l_object->isa($p_type)) {
			push @l_found, $l_object;
		}
	}
	return @l_found;
}

1
