# Category = HomeKit Integration

#@ This module generates a config.json to be used by the homebridge system
#@ To use several groups need to be set up:
#@   HB__<TYPE> where type is LIGHT, LOCK, FAN, GARAGEDOOR, BLINDS, SWITCH, THERMOSTAT
#@ Thermostat control only tested with a few models. 

# TODO:
# Status Calls: determine if an object is on or off

# read_url = "http://mh/sub?hb_status('$item')";

my $port = $config_parms{homebridge_port};
$port = 51826 unless ($port);
my $name = $config_parms{homebridge_name};
$name = "Homebridge" unless ($name);
my $pin = $config_parms{homebridge_pin};
$pin = "031-45-154" unless ($pin);
my $username = $config_parms{homebridge_username};
$username = "CC:22:3D:E3:CE:30" unless ($username);
my $version = "2";
my $filepath = $config_parms{data_dir} . "/homebridge_config.json";
$filepath = $config_parms{homebridge_config_dir} . "/config.json" if (defined $config_parms{homebridge_config_dir});
my $acc_count;
$v_generate_hb_config = new Voice_Cmd("Generate new Homebridge config.json file");

if (said $v_generate_hb_config) {
	my $config_json = "{\n\t\"bridge\": {\n";
	$config_json .= "\t\t\"name\": \"" . $name . "\",\n";
	$config_json .= "\t\t\"username\": \"" . $username . "\",\n";
	$config_json .= "\t\t\"port\": " . $port . ",\n";
	$config_json .= "\t\t\"pin\": \"" . $pin . "\"\n\t},\n";
	$config_json .= "\t\"description\": \"MH Generated HomeKit Configuration v" . $version . " " . &time_date_stamp(17) . "\",\n";
	
	$config_json .= "\n\t\"accessories\": [\n";
	$acc_count = 0;
  	$config_json .= add_group("fan");
  	$config_json .= add_group("switch");
  	$config_json .= add_group("light");
  	$config_json .= add_group("lock");
  	$config_json .= add_group("garagedoor");
  	$config_json .= add_group("blinds");
  	$config_json .= add_group("thermostat");

	$config_json .= "\t\t}\n\t]\n}\n";
	print_log "Writing configuration to $filepath...";
	#print_log $config_json;
	file_write($filepath, $config_json);
}


sub add_group {
	my ($type) = @_;
	my %url_types;
	$url_types{lock}{on} = "lock";
	$url_types{lock}{off} = "unlock";
	$url_types{blind}{on} = "up";
	$url_types{blind}{off} = "down";
	$url_types{garagedoor}{on} = "open";
	$url_types{garagedoor}{off} = "close";
	my $groupname = "HB__" . (uc $type);
	my $group = &get_object_by_name($groupname);
	print_log "gn=$groupname";
	return unless ($group);
	my $text = "";
	for my $member (list $group) {
		$text .= "\t\t},\n" if ($acc_count > 0 );
		$acc_count++;		
		$text .= "\t\t{\n";
		$text .= "\t\t\"accessory\": \"HttpMulti\",\n";
		my $name = $member->{object_name};
		$name =~ s/_/ /g;
		$name =~ s/\$//g;
		$name = $member->{label} if (defined $member->{label});
		$text .= "\t\t\"name\": \"" . $name . "\",\n";
		if ($type eq "thermostat") {
			my $name2 = $member->{object_name};
			$name2 =~ s/\$//g;
			$text .= "\t\t\"setpoint_url\": \"http://" . $Info{IPAddress_local} . ":" . $config_parms{http_port} . "/sub?hb_thermo_setpoint(%27" . $name2 . "%27,%VALUE%)\",\n";
		} else {
			my $on = "on";
			$on = $url_types{$type}{on} if (defined $url_types{$type}{on});
			my $off = "off";
			$off = $url_types{$type}{off} if (defined $url_types{$type}{off});	
			$text .= "\t\t\"" . $on . "_url\": \"http://" . $Info{IPAddress_local} . ":" . $config_parms{http_port} . "/SET;none?select_item=" . $member->{object_name} . "&select_state=" .$on . "\",\n";
			$text .= "\t\t\"" . $off . "_url\": \"http://" . $Info{IPAddress_local} . ":" . $config_parms{http_port} . "/SET;none?select_item=" . $member->{object_name} . "&select_state=" .$off . "\",\n";
			$text .= "\t\t\"brightness_url\": \"http://" . $Info{IPAddress_local} . ":" . $config_parms{http_port} . "/SET;none?select_item=" . $member->{object_name} . "&select_state=%VALUE%\",\n" if ($type eq "light");
			$text .= "\t\t\"speed_url\": \"http://" . $Info{IPAddress_local} . ":" . $config_parms{http_port} . "/SET;none?select_item=" . $member->{object_name} . "&select_state=%VALUE%\",\n" if ($type eq "fan");
		}
		$text .= "\t\t\"deviceType\": \"" . $type . "\"\n";
	}
	return $text;
}
		
sub hb_status {
     my ($item) = @_;
     my $object   = &get_object_by_name($item);
     my $state = $object->state;
     my $status = "1     ";
     $status = "0     " if (lc $state eq "off");
     print_log "Homebridge: Status request: item=$item status=$status\n";
     return "$status";
}

sub hb_thermo_setpoint {
	my ($item,$value) = @_;
	print_log "Homebridge: Temperature change request for $item to $value";
	my $object = &get_object_by_name($item);
	
	if (UNIVERSAL::isa($object,'Venstar_Colortouch')) {
		print_log "Homebridge: Thermostat Venstar Colortouch found";
		my $sp_delay = 0;
		if ($object->get_sched() eq "on") {
			print_log "Thermostat on a schedule, turning off schedule for override";			
			$object -> set_schedule("off");
			$sp_delay = 5;
		}
		my $auto_mode = ""
		$auto_mode = &calc_auto_mode($value,$object->get_temp()) if ($object->get_mode() eq "auto");
		print_log "Homebridge: Thermostat calc mode is $auto_mode" if ($auto_mode);
		if (($object->get_mode() eq "cooling") or ($auto_mode eq "cool")) {
			if ($sp_delay) {
				eval_with_timer '$' . $item . '->set_cool_sp(' .  $value . ');', $sp_delay;
			} else {
				$object -> set_cool_sp($value);
			}
		} else {
			if ($sp_delay) {
				eval_with_timer '$' . $item . '->set_heat_sp(' .  $value . ');', $sp_delay;
			} else {
				$object -> set_heat_sp($value);
			}
		}

	} elsif (UNIVERSAL::isa($object,'Nest_Thermostat')) {
		print_log "Homebridge: Nest Thermostat found";
		$object -> set_target_temp($value);

	} elsif (UNIVERSAL::isa($object,'Insteon::Thermostat')) {
		print_log "Homebridge: Insteon Thermostat found";
		my $auto_mode = ""
		$auto_mode = &calc_auto_mode($value) if ($object->get_mode() eq "auto");
		print_log "Homebridge: Thermostat calc mode is $auto_mode" if ($auto_mode);
		if (($object->get_mode() eq "cool") or ($auto_mode eq "cool")) {
			$object -> cool_setpoint($value);
		} else {
			$object -> heat_setpoint($value);
		}
	} else {
		print_log "Unsupported Thermostat type";
	} 
}

sub calc_auto_mode {
	my ($value,$intemp,$outtemp) = @_;
	
	my $mode = "heat";
	my $cool_threshold = 8; #set to cool if outside less
	my $outside = "";
	$outside = $Weather{Outdoor} if (defined $Weather{TempOutdoor});
	$outside = $outtemp if (defined $outtemp);
	my $inside = "";
	$inside = $Weather{Inside} if (defined $Weather{TempInside});
	$inside = $intemp if (defined $intemp);
	$mode = "cool" if ($value < $inside);
	$mode = "heat" if (($value - $cool_threshold) > $outside);
	
	return $mode;
}

	
	