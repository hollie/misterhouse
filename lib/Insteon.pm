package Insteon;

use strict;

# Category=Insteon

#@ This module creates voice commands for all insteon related items.

my (@_insteon_plm,@_insteon_device,@_insteon_link,@_scannable_link,$_scan_cnt,$_sync_cnt,$_sync_failure_cnt);
my $init_complete;
my (@_scan_devices,@_scan_device_failures,$current_scan_device);
my (@_sync_devices,@_sync_device_failures,$current_sync_device);

sub scan_all_linktables
{
	if ($current_scan_device)
        {
        	&main::print_log("[Scan all linktables] WARN: link already underway. Ignoring request for new scan ...");
                return;
        }
        my @candidate_devices = ();
        # clear @_scan_devices
        @_scan_devices = ();
        @_scan_device_failures = ();
        $current_scan_device = undef;
        # alwayws include the active interface (e.g., plm)
       	push @_scan_devices, &Insteon::active_interface;

       	push @candidate_devices, &Insteon::find_members("Insteon::BaseDevice");

        # don't try to scan devices that are not responders
        if (@candidate_devices)
        {
        	foreach (@candidate_devices)
        	{
        		my $candidate_object = $_;
        		if ($candidate_object->is_root and
                		!($candidate_object->isa('Insteon::RemoteLinc')
                		or $candidate_object->isa('Insteon::InterfaceController')
                       		or $candidate_object->isa('Insteon::MotionSensor')))
                	{
		       		push @_scan_devices, $candidate_object;
                		&main::print_log("[Scan all linktables] INFO1: "
                        		. $candidate_object->get_object_name
                        		. " will be scanned.") if $main::Debug{insteon} >= 1;
        		}
                	else
                	{
                		&main::print_log("[Scan all linktables] INFO: !!! "
                        		. $candidate_object->get_object_name
                        		. " is NOT a candidate for scanning.");
                	}
		}
        }
        else
        {
        	&main::print_log("[Scan all linktables] WARN: No insteon devices could be found");
        }
        $_scan_cnt = scalar @_scan_devices;

        &_get_next_linkscan();
}

sub _get_next_linkscan_failure
{
        push @_scan_device_failures, $current_scan_device;
        &main::print_log("[Scan all link tables] WARN: failure occurred when scanning "
                	. $current_scan_device->get_object_name . ".  Moving on...");
        &_get_next_linkscan();

}

sub _get_next_linkscan
{
   	$current_scan_device = shift @_scan_devices;

	if ($current_scan_device)
        {
          	&main::print_log("[Scan all link tables] Now scanning: "
                	. $current_scan_device->get_object_name . " ("
                        . ($_scan_cnt - scalar @_scan_devices)
                        . " of $_scan_cnt)");
                # pass first the success callback followed by the failure callback
          	$current_scan_device->scan_link_table('&Insteon::_get_next_linkscan()','&Insteon::_get_next_linkscan_failure()');
    	} else {
          	&main::print_log("[Scan all link tables] All tables have completed scanning");
                my $_scan_failure_cnt = scalar @_scan_device_failures;
                if ($_scan_failure_cnt)
                {
          	  &main::print_log("[Scan all link tables] However, some failures were noted:");
                  for my $failed_obj (@_scan_device_failures)
                  {
        		&main::print_log("[Scan all link tables] WARN: failure occurred when scanning "
                	. $failed_obj->get_object_name);
                  }
                }

    	}
}


sub sync_all_links
{
	my ($audit_mode) = @_;
        &main::print_log("[Sync all links] Starting now!");
        @_sync_devices = ();
	# iterate over all registered objects and compare whether the link tables match defined scene linkages in known Insteon_Links
	for my $obj (&Insteon::find_members('Insteon::BaseController'))
	{
        	if ($obj->isa('Insteon::RemoteLinc') or $obj->isa('Insteon::MotionSensor'))
                {
                	&main::print_log("[Sync all links] Ignoring links from 'deaf' device: " . $obj->get_object_name);
                }
                elsif(!($obj->isa('Insteon::InterfaceController')) && ($obj->_aldb->health eq 'unknown'))
                {
                	&main::print_log("[Sync all links] Skipping links from 'unreachable' device: "
                        	. $obj->get_object_name . ". Consider rescanning the link table of this device");
                }
                else
                {
			my %sync_req = ('sync_object' => $obj, 'audit_mode' => ($audit_mode) ? 1 : 0);
                	&main::print_log("[Sync all links] Adding " . $obj->get_object_name
                        	. " to sync queue");
	       		push @_sync_devices, \%sync_req
                };
	}

        $_sync_cnt = scalar @_sync_devices;

        &_get_next_linksync();
}

sub _get_next_linksync
{
   	$current_scan_device = shift @_scan_devices;
	my $sync_req_ptr = shift(@_sync_devices);
        my %sync_req = ($sync_req_ptr) ? %$sync_req_ptr : undef;
        if (%sync_req)
        {

        	$current_sync_device = $sync_req{'sync_object'};
        }
        else
        {
        	$current_sync_device = undef;
        }

	if ($current_sync_device)
        {
          	&main::print_log("[Sync all links] Now syncing: "
                	. $current_sync_device->get_object_name . " ("
                        . ($_sync_cnt - scalar @_sync_devices)
                        . " of $_sync_cnt)");
                # pass first the success callback followed by the failure callback
          	$current_sync_device->sync_links($sync_req{'audit_mode'}, '&Insteon::_get_next_linksync()','&Insteon::_get_next_linksync_failure()');
    	}
        else
        {
          	&main::print_log("[Sync all links] All links have completed syncing");
                my $_sync_failure_cnt = scalar @_sync_device_failures;
                if ($_sync_failure_cnt)
                {
          	  	&main::print_log("[Sync all links] However, some failures were noted:");
                  	for my $failed_obj (@_sync_device_failures)
                  	{
        			&main::print_log("[Sync all links] WARN: failure occurred when syncing "
                		. $failed_obj->get_object_name);
                  	}
                }

    	}

}

sub _get_next_linksync_failure
{
        push @_sync_device_failures, $current_sync_device;
        &main::print_log("[Sync all links] WARN: failure occurred when scanning "
                	. $current_sync_device->get_object_name . ".  Moving on...");
        &_get_next_linksync();

}


sub init {

    # only run once
    return if $init_complete;
    $init_complete = 1;

    # initialize scan and sync counters
    $_scan_cnt = 0;
    $_sync_cnt = 0;
    @_scan_devices = ();

    #################################################################
    ## Trigger creation
    #################################################################
    my ($trigger_event, $trigger_code, $trigger_type);

    my @trigger_info = &main::trigger_get('scan insteon link tables');
    if (@trigger_info) {
	# Trigger exists; modify just the minimum so the trigger continues
	# to work if we change the trigger code, but respect everything
	# else (trigger type and time to run). This prevents unconditionally
	# re-enabling the trigger if the user has disabled it.
	$trigger_event = $trigger_info[0];
	$trigger_type = $trigger_info[2];
    } else {
	# Trigger does not exist; create one with our default values.
	$trigger_event = "time_cron '00 02 * * *'";
	$trigger_type = 'NoExpire';
    }

    $trigger_code = '&Insteon::scan_all_linktables()';

    # Create/update trigger for a nightly link table scan
    &main::trigger_set($trigger_event, $trigger_code, $trigger_type,
		       'scan insteon link tables', 1);
    #################################################################

    @_insteon_plm = ();
    @_insteon_device = ();
    @_insteon_link = ();

}

sub generate_voice_commands
{

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
              $cmd_states .= ",status,get engine version,scan link table,log links";
              push @_scannable_link, $object_name;
           }
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->initiate_linking_as_controller(\"$group\")', 'initiate linking as controller');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->interface()->cancel_linking','cancel linking');\n\n";
           if ($object->is_root and !($object->isa('Insteon::InterfaceController'))) {
              $object_string .= "$object_name_v -> tie_event('$object_name->link_to_interface','link to interface');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->unlink_to_interface','unlink with interface');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->request_status','status');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->get_engine_version','get engine version');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->scan_link_table(\"" . '\$self->log_alllink_table' . "\")','scan link table');\n\n";
              $object_string .= "$object_name_v -> tie_event('$object_name->log_alllink_table()','log links');\n\n";
           }
           $object_string .= "$object_name_v -> tie_event('$object_name->sync_links(0)','sync links');\n\n";
           $object_string .= "$object_name_v -> tie_items($object_name, 'on');\n\n";
           $object_string .= "$object_name_v -> tie_items($object_name, 'off');\n\n";
           $object_string .= &main::store_object_data($object_name_v, 'Voice_Cmd', 'Insteon', 'Insteon_link_commands');
           push @_insteon_link, $object_name;
        } elsif ($object->isa('Insteon::BaseDevice')) {
           $states = $insteon_menu_states if $insteon_menu_states
           	&& ($object->can('is_dimmable') && $object->is_dimmable);
           my $cmd_states = "$states,status,get engine version,scan link table,log links,update onlevel/ramprate"; #,on level,ramp rate";
           $cmd_states .= ",link to interface,unlink with interface" if $object->isa("Insteon::BaseController") || $object->is_controller;
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           foreach my $state (split(/,/,$states)) {
              $object_string .= "$object_name_v -> tie_items($object_name, '$state');\n\n";
           }
           $object_string .= "$object_name_v -> tie_event('$object_name->log_alllink_table()','log links');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->request_status','status');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->get_engine_version','get engine version');\n\n";
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
           my $cmd_states = "complete linking as responder,cancel linking,delete link with PLM,scan link table,log links,delete orphan links,AUDIT - delete orphan links,scan all device link tables,sync all links,AUDIT - sync all links";
           $object_string .= "$object_name_v  = new Voice_Cmd '$command [$cmd_states]';\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->complete_linking_as_responder','complete linking as responder');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->initiate_unlinking_as_controller','initiate unlinking');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->cancel_linking','cancel linking');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->log_alllink_table','log links');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->scan_link_table(\"" . '\$self->log_alllink_table' . "\")','scan link table');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->delete_orphan_links','delete orphan links');\n\n";
           $object_string .= "$object_name_v -> tie_event('$object_name->delete_orphan_links(1)','AUDIT - delete orphan links');\n\n";
           $object_string .= "$object_name_v -> tie_event('&Insteon::scan_all_linktables','scan all device link tables');\n\n";
           $object_string .= "$object_name_v -> tie_event('&Insteon::sync_all_links(0)','sync all links');\n\n";
           $object_string .= "$object_name_v -> tie_event('&Insteon::sync_all_links(1)','AUDIT - sync all links');\n\n";
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

   $insteon_manager->_active_interface($interface)
   	if $interface && ref $interface && $interface->isa('Insteon::BaseInterface');
#print "############### active interface is: " . $insteon_manager->_active_interface->get_object_name . "\n";
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
      &main::Reload_post_add_hook(\&Insteon::generate_voice_commands, 1);
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
         if ($_->equals($p_object)) {
            return 0;
         }
      }
   }
   $self->add_item($p_object);
   return 1;
}

sub remove_item {
   my ($self, $p_object) = @_;
   return 0 unless $p_object and ref $p_object;
   if (ref $$self{objects}) {
      for (my $i = 0; $i < scalar(@{$$self{objects}}); $i++) {
         if ($p_object->equals($$self{objects}->[$i])) {
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
	if ($l_object->equals($p_object)) {
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
