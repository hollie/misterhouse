# Category = HomeKit Integration

#@ This module generates a config.json to be used by the homebridge system
#@ To use several groups need to be set up:
#@   HB__<TYPE> where type is LIGHT, LOCK, FAN, GARAGEDOOR, BLINDS, SWITCH, THERMOSTAT
#@ Thermostat control only tested with a few models.

my $hb_debug = 1;
my $http_address = $config_parms{http_address};
$http_address = $Info{IPAddress_local} unless ($http_address);
my $port     = $config_parms{homebridge_port};
$port = 51826 unless ($port);
my $name = $config_parms{homebridge_name};
$name = "Homebridge" unless ($name);
my $pin = $config_parms{homebridge_pin};
$pin = "031-45-154" unless ($pin);
my $username = $config_parms{homebridge_username};
$username = "CC:22:3D:E3:CE:30" unless ($username);
my $version  = "4";
my $filepath = $config_parms{data_dir} . "/homebridge_config.json";
$filepath = $config_parms{homebridge_config_dir} . "/config.json"
  if ( defined $config_parms{homebridge_config_dir} );
my $acc_count;
$v_generate_hb_config = new Voice_Cmd("Generate new Homebridge config.json file");
$v_restart_hb_server  = new Voice_Cmd("[start,stop,restart] Homebridge Server");
my $units = "C";
$units = $config_parms{homebridge_temp_units}
  if ( defined $config_parms{homebridge_temp_units} );

if ( my $action = said $v_restart_hb_server) {
    if ( defined $config_parms{homebridge_service_path} ) {
        print_log "[Homebridge]: " . $action . "ing the Homebridge Server...";
        my $cmd = $config_parms{homebridge_service_path} . " " . $action;
        my $r   = system($cmd);
        if ( $r != 0 ) {
            print_log "[Homebridge]: Warning, couldn't control homebridge service: $r";
        }
    }
    else {
        print_log "[Homebridge]: Error, homebridge service path not defined";
    }
}

if ( said $v_generate_hb_config) {
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
    print_log "[Homebridge]: Writing configuration for server " . $http_address . " to $filepath...";

    #print_log $config_json;
    file_write( $filepath, $config_json );
}

sub add_group {
    my ($type) = @_;
    my %url_types;
    $url_types{lock}{on}        = "lock";
    $url_types{lock}{off}       = "unlock";
    $url_types{blinds}{on}      = "up";
    $url_types{blinds}{off}     = "down";
    $url_types{garagedoor}{on}  = "up";
    $url_types{garagedoor}{off} = "down";
    my $groupname = "HB__" . ( uc $type );
    my $group = &get_object_by_name($groupname);
    print_log "gn=$groupname";
    return unless ($group);
    my $text = "";

    for my $member ( list $group) {
        $text .= "\t\t},\n" if ( $acc_count > 0 );
        $acc_count++;
        $text .= "\t\t{\n";
        $text .= "\t\t\"accessory\": \"HttpMulti\",\n";
        my $name = $member->{object_name};
        $name =~ s/_/ /g;
        $name =~ s/\$//g;
        $name = $member->{label} if ( defined $member->{label} );
        my $obj_name = $member->{object_name};
        $obj_name =~ s/^\$//;    #remove $ since the web sub system doesn't seem to like it.

        $text .= "\t\t\"name\": \"" . $name . "\",\n";
        if ( $type eq "thermostat" ) {
            $text .=
                "\t\t\"mode_url\": \"http://"
              . $http_address . ":"
              . $config_parms{http_port}
              . "/SUB?hb_thermo_set_state%28"
              . $obj_name
              . ",%VALUE%%29\",\n";
            $text .=
                "\t\t\"status_url\": \"http://"
              . $http_address . ":"
              . $config_parms{http_port}
              . "/SUB?hb_thermo_get_state%28"
              . $obj_name . ","
              . $type
              . "%29\",\n";
            $text .=
                "\t\t\"setpoint_url\": \"http://"
              . $http_address . ":"
              . $config_parms{http_port}
              . "/SUB?hb_thermo_set_setpoint%28"
              . $obj_name
              . ",%VALUE%%29\",\n";
            $text .=
                "\t\t\"gettemp_url\": \"http://"
              . $http_address . ":"
              . $config_parms{http_port}
              . "/SUB?hb_thermo_get_setpoint%28"
              . $obj_name
              . "%29\",\n";
            $text .= "\t\t\"unit_type\": \"" . $units . "\",\n";
        }
        else {
            my $on = "on";
            $on = $url_types{$type}{on} if ( defined $url_types{$type}{on} );
            my $off = "off";
            $off = $url_types{$type}{off} if ( defined $url_types{$type}{off} );
            $text .=
                "\t\t\""
              . $on
              . "_url\": \"http://"
              . $http_address . ":"
              . $config_parms{http_port}
              . "/SET;none?select_item="
              . $member->{object_name}
              . "&select_state="
              . $on . "\",\n";
            $text .=
                "\t\t\""
              . $off
              . "_url\": \"http://"
              . $http_address . ":"
              . $config_parms{http_port}
              . "/SET;none?select_item="
              . $member->{object_name}
              . "&select_state="
              . $off . "\",\n";
            $text .=
                "\t\t\"brightness_url\": \"http://"
              . $http_address . ":"
              . $config_parms{http_port}
              . "/SET;none?select_item="
              . $member->{object_name}
              . "&select_state=%VALUE%\",\n"
              if ( $type eq "light" );
            $text .=
                "\t\t\"speed_url\": \"http://"
              . $http_address . ":"
              . $config_parms{http_port}
              . "/SET;none?select_item="
              . $member->{object_name}
              . "&select_state=%VALUE%\",\n"
              if ( $type eq "fan" );
            $text .=
                "\t\t\"status_url\": \"http://"
              . $http_address . ":"
              . $config_parms{http_port}
              . "/SUB?hb_status%28"
              . $obj_name . ","
              . $type
              . "%29\",\n";
        }
        $text .= "\t\t\"deviceType\": \"" . $type . "\"\n";
    }
    return $text;
}

#curl "http://127.0.0.1:8080/sub?hb_status%28test_light%29"	 #()
sub hb_status {
    my ( $item, $type ) = @_;
    my $object = &get_object_by_name($item);
    my $data   = "";
    $type = "" unless ( defined $type );
    unless ( defined $object ) {
        print_log "[Homebridge: hb_status]: Error, unknown object $item";
    }
    else {
        my $state = lc $object->state;
        if ( ( $state =~ /^lock/i ) or ( $state =~ /^close/ ) ) {
            $data = "1";
        }
        elsif (( lc $state eq "off" )
            or ( $state =~ /^unlock/i )
            or ( $state =~ /^open/i )
            or ( $state =~ /^down/i ) )
        {
            $data = "0";
        }
        elsif ( $state =~ /^low/i ) {
            $data = "20";
        }
        elsif ( $state =~ /^med/i ) {
            $data = "50";
        }
        elsif ( $state =~ /^high/i ) {
            $data = "70";
        }
        elsif ( $state =~ /^up/i ) {
            $data = "100";
        }
        elsif ( lc $state eq "on" ) {
            $data = "100";
            if ( lc $type eq "light" ) {
                if ( $object->can('level') ) {
                    $data = $object->level;
                }
                print_log "[Homebridge]: Light Level $data" if ($hb_debug);
            }
        }
        else {
            ($data) = $state =~ /(\d+)/;
        }
        print_log "[Homebridge]: Warning, no state data to return!"
          if ( $data eq "" );
        print_log "[Homebridge]: Status request: item=$item state=$state status=[$data] type=$type"
          if ($hb_debug);
    }
    my $output = "HTTP/1.1 200 OK\r\n";
    $output .= "Server: MisterHouse\r\n";
    $output .= "Content-type: text/html\r\n";
    $output .= "Connection: close\r\n" if &http_close_socket;
    $output .= "Content-Length: " . ( length $data ) . "\r\n";
    $output .= "Cache-Control: no-cache\r\n";
    $output .= "Date: " . time2str(time) . "\r\n";
    $output .= "\r\n";
    $output .= $data;
    return $output;
}

sub hb_thermo_get_state {
    my ($item) = @_;
    print_log "[Homebridge]: Get Thermostat Current Operating Mode";
    my $data   = "0";
    my $mode   = "off";
    my $object = &get_object_by_name($item);
    unless ( defined $object ) {
        print_log "[Homebridge]: hb_thermo_state: Error, unknown object $item";
    }
    else {
        if ( UNIVERSAL::isa( $object, 'Venstar_Colortouch' ) ) {
            $mode = $object->get_mode();
            print_log "[Homebridge]: Thermostat Venstar Colortouch with mode " . $mode . " found";
            if ( $mode =~ /^auto/i ) {
                $data = "3";
            }
            elsif ( $mode =~ /^cool/i ) {
                $data = "2";
            }
            elsif ( $mode =~ /^heat/i ) {
                $data = "1";
            }
            else {
                $data = "0";
            }
        }
        print_log "[Homebridge]: Thermostat State request: item=$item mode=$mode status=[$data]\n"
          if ($hb_debug);
    }
    my $output = "HTTP/1.1 200 OK\r\n";
    $output .= "Server: MisterHouse\r\n";
    $output .= "Content-type: text/html\r\n";
    $output .= "Connection: close\r\n" if &http_close_socket;
    $output .= "Content-Length: " . ( length $data ) . "\r\n";
    $output .= "Cache-Control: no-cache\r\n";
    $output .= "Date: " . time2str(time) . "\r\n";
    $output .= "\r\n";
    $output .= $data;
    return $output;
}

sub hb_thermo_set_state {
    my ( $item, $value ) = @_;
    print_log "[Homebridge]: Mode change request for $item to $value";
    my $object = &get_object_by_name($item);

    if ( UNIVERSAL::isa( $object, 'Venstar_Colortouch' ) ) {
        print_log "[Homebridge]: Thermostat Venstar Colortouch found";
        my $sp_delay = 0;
        if ( $object->get_sched() eq "on" ) {
            print_log "[Homebridge]: Thermostat on a schedule, turning off schedule for override";
            $object->set_schedule("off");
            $sp_delay = 5;
        }
        my $mode = "off";
        if ( $value == 1 ) {
            $mode = "heat";
        }
        elsif ( $value == 2 ) {
            $mode = "cool";
        }
        elsif ( $value == 3 ) {
            $mode = "auto";
        }
        print_log "[Homebridge]: Setting thermostat to $mode";
        if ($sp_delay) {
            eval_with_timer '$' . $item . '->set_mode(' . $mode . ');', $sp_delay;
        }
        else {
            $object->set_mode($mode);
        }

    }
    elsif ( UNIVERSAL::isa( $object, 'Nest_Thermostat' ) ) {
        print_log "[Homebridge]: Nest Thermostat found";

    }
    elsif ( UNIVERSAL::isa( $object, 'Insteon::Thermostat' ) ) {
        print_log "[Homebridge]: Insteon Thermostat found";

    }
    else {
        print_log "Unsupported Thermostat type";
    }
    return "";
}

sub hb_thermo_get_setpoint {
    my ($item) = @_;
    print_log "[Homebridge]: Get Thermostat Current setpoint";
    my $data   = 0;
    my $mode   = "off";
    my $object = &get_object_by_name($item);
    unless ( defined $object ) {
        print_log "[Homebridge]: hb_thermo_get_setpoint]: Error, unknown object $item";
    }
    else {
        if ( UNIVERSAL::isa( $object, 'Venstar_Colortouch' ) ) {
            $object->get_mode();
            print_log "[Homebridge]: Thermostat Venstar Colortouch with mode " . $mode . " found";
            if ( $mode =~ /^cool/ ) {
                $data = $object->get_sp_cool;
            }
            else {
                $data = $object->get_sp_heat;
            }
        }
    }
    print_log "[Homebridge]: Thermostat Get Setpoint request: item=$item mode=$mode status=[$data]\n"
      if ($hb_debug);
    my $output = "HTTP/1.1 200 OK\r\n";
    $output .= "Server: MisterHouse\r\n";
    $output .= "Content-type: text/html\r\n";
    $output .= "Connection: close\r\n" if &http_close_socket;
    $output .= "Content-Length: " . ( length $data ) . "\r\n";
    $output .= "Cache-Control: no-cache\r\n";
    $output .= "Date: " . time2str(time) . "\r\n";
    $output .= "\r\n";
    $output .= $data;
    return $output;
}

sub hb_thermo_set_setpoint {
    my ( $item, $value ) = @_;
    print_log "[Homebridge]: Temperature change request for $item to $value";
    my $object = &get_object_by_name($item);

    if ( UNIVERSAL::isa( $object, 'Venstar_Colortouch' ) ) {
        print_log "[Homebridge]: Thermostat Venstar Colortouch found";
        my $sp_delay = 0;
        if ( $object->get_sched() eq "on" ) {
            print_log "[Homebridge]: Thermostat on a schedule, turning off schedule for override";
            $object->set_schedule("off");
            $sp_delay = 5;
        }
        my $auto_mode = "";
        $auto_mode = &calc_auto_mode( $value, $object->get_temp() )
          if ( $object->get_mode() eq "auto" );
        print_log "[Homebridge]: Thermostat calc mode is $auto_mode"
          if ($auto_mode);
        if ( ( $object->get_mode() eq "cooling" ) or ( $auto_mode eq "cool" ) ) {
            if ($sp_delay) {
                eval_with_timer '$' . $item . '->set_cool_sp(' . $value . ');', $sp_delay;
            }
            else {
                $object->set_cool_sp($value);
            }
        }
        else {
            if ($sp_delay) {
                eval_with_timer '$' . $item . '->set_heat_sp(' . $value . ');', $sp_delay;
            }
            else {
                $object->set_heat_sp($value);
            }
        }

    }
    elsif ( UNIVERSAL::isa( $object, 'Nest_Thermostat' ) ) {
        print_log "[Homebridge]: Nest Thermostat found";
        $object->set_target_temp($value);

    }
    elsif ( UNIVERSAL::isa( $object, 'Insteon::Thermostat' ) ) {
        print_log "[Homebridge]: Insteon Thermostat found";
        my $auto_mode = "";
        $auto_mode = &calc_auto_mode($value)
          if ( $object->get_mode() eq "auto" );
        print_log "[Homebridge]: Thermostat calc mode is $auto_mode"
          if ($auto_mode);
        if ( ( $object->get_mode() eq "cool" ) or ( $auto_mode eq "cool" ) ) {
            $object->cool_setpoint($value);
        }
        else {
            $object->heat_setpoint($value);
        }
    }
    else {
        print_log "Unsupported Thermostat type";
    }
    return "";
}

sub calc_auto_mode {
    my ( $value, $intemp, $outtemp ) = @_;

    my $mode           = "heat";
    my $cool_threshold = 8;        #set to cool if outside less
    my $outside        = "";
    $outside = $Weather{Outdoor} if ( defined $Weather{TempOutdoor} );
    $outside = $outtemp          if ( defined $outtemp );
    my $inside = "";
    $inside = $Weather{Inside} if ( defined $Weather{TempInside} );
    $inside = $intemp          if ( defined $intemp );
    $mode   = "cool"           if ( $value < $inside );
    $mode = "heat" if ( ( $value - $cool_threshold ) > $outside );

    return $mode;
}

