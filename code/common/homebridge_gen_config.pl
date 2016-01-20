# cycle through 

my $port = $config_parms{homebridge_port};
$port = 51826 unless ($port);
my $name = $config_parms{homebridge_name};
$name = "Homebridge" unless ($name);
my $pin = $config_parms{homebridge_pin};
$pin = "031-45-154" unless ($pin);
my $username = $config_parms{homebridge_username};
$username = "CC:22:3D:E3:CE:30" unless ($username);
my $version = "1.0";
my $filepath = $config_parms{data_dir} . "/homebridge_config.json";
my $acc_count;
$v_generate_hb_config = new Voice_Cmd("Generate new Homebridge config.json file");

if (said $v_generate_hb_config) {
	my $config_json = "{\n\t\"bridge\": {\n";
	$config_json .= "\t\t\"name\": " . $name . "\",\n";
	$config_json .= "\t\t\"username\": " . $username . "\",\n";
	$config_json .= "\t\t\"port\": " . $port . "\",\n";
	$config_json .= "\t\t\"pin\": " . $pin . "\"\n\t},\n";
	$config_json .= "\t\"description\": \"MH Generated HomeKit Configuration v" . $version . " " . &time_date_stamp(17) . "\",\n";
	
	$config_json .= "\n\t\"accessories\": [\n";
	$acc_count = 0;
  	$config_json .= add_group("fan");
  	$config_json .= add_group("switch");
  	$config_json .= add_group("light");
  	$config_json .= add_group("lock");
  	$config_json .= add_group("garagedoor");
  	$config_json .= add_group("blinds");

	$config_json .= "\t\t}\n\t]\n}\n";
	print_log "Writing configuration to $filepath...";
	print_log $config_json;
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
		my $on = "on";
		$on = $url_types{$type}{on} if (defined $url_types{$type}{on});
		my $off = "off";
		$off = $url_types{$type}{off} if (defined $url_types{$type}{off});	
		$text .= "\t\t\"" . $on . "_url\": \"http://" . $Info{IPAddress_local} . "/SET;none?select_item=" . $member->{object_name} . "&select_state=" .$on . "\",\n";
		$text .= "\t\t\"" . $off . "_url\": \"http://" . $Info{IPAddress_local} . "/SET;none?select_item=" . $member->{object_name} . "&select_state=" .$off . "\",\n";
		$text .= "\t\t\"brightness_url\": \"http://" . $Info{IPAddress_local} . "/SET;none?select_item=" . $member->{object_name} . "&select_state=%VALUE%\",\n" if ($type eq "light");
		$text .= "\t\t\"deviceType\": \"" . $type . "\"\n";
	}
	return $text;
}
		

	