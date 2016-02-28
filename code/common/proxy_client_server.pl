# Category = MisterHouse

#@ Sends speak text and play wav files to proxy clients

=begin comment

Use this code to provide a meshed networking interface between
a set of misterhouse computers.  All computers share a baseline
mh.private.ini while each individual computer has an additional
mh.local.private.ini.  Use two ini files in your mh_parms
environment variable.

All computers can share all resources in the collective.

mh.private.ini used by all machines

define networking ports

  server_proxy_port = 8085
  mh_proxyreg_port = 5557
  server_proxy_register_port=5557

define the location of all resources, this example has one
resource in each computer.  The actual port name must be
overridden in the mh.local.private.ini file for the computer
which has the resource locally attached.

  cm11_port     = proxy livingroom:8085
  ti103_port    = proxy livingroom:8085
  W800_port     = proxy bedroom:8085
  callerid_port = proxy kitchen:8085

mh.local.private.ini for livingroom

  speak_mh_room      = livingroom
  speak_bedroom_port = proxy bedroom:8085
  speak_kitchen_port = proxy kitchen:8085

  cm11_port = /dev/tty1
  ti103_port = /dev/tty1

  proxy_name = livingroom
  speak_voice=us2_mbrola
  speak_rooms=livingroom
  play_rooms=livingroom

mh.local.private.ini for bedroom

  speak_mh_room         = bedroom
  speak_kitchen_port    = proxy kitchen:8085
  speak_livingroom_port = proxy livingroom:8085

  W800_port = /dev/tty1

  proxy_name = bedroom
  speak_voice=us2_mbrola
  speak_rooms=bedroom
  play_rooms=bedroom

mh.local.private.ini for kitchen

  speak_mh_room         = kitchen
  speak_bedroom_port    = proxy bedroom:8085
  speak_livingroom_port = proxy livingroom:8085

  callerid_port = /dev/ttyE1

  proxy_name = kitchen
  speak_voice=us2_mbrola
  speak_rooms=kitchen
  play_rooms=kitchen

See 'Use distributed MisterHouse proxies' in mh/docs/mh.*  for more info.

=cut

# Proxy Client Section

# Log hook is not muted like speak hook is
&Speak_pre_add_hook( \&proxy_speak_play, 0, 'speak' ) if $Reload;

#Log_Hooks_add_hook(\&proxy_speak_play, 0, 'speak') if $Reload;

&Play_pre_add_hook( \&proxy_speak_play, 0, 'play' ) if $Reload;

# proxy_by_room defines the assignment between "room" name and
# dns network names.  Use the room name for speak and play commands.

my %proxy_by_room = (
    livingroom => 'linux',
    jim        => 'jim',
    sharon     => 'sharon',
    kitchen    => 'kitchen',
    gym        => 'gym',
    bedroom    => 'bedroom'
);

$test_voice_proxy = new Voice_Cmd
  'Test proxy speak to [all,livingroom,jim,sharon,kitchen,bedroom]';
$test_voice_proxy->tie_event(
    'speak "rooms=$state we are the borg,, you will be assimilated,, resistance is few tile"'
);

$test_play_proxy = new Voice_Cmd
  'Test proxy play to [all,livingroom,jim,sharon,kitchen,bedroom]';
$test_play_proxy->tie_event(
    'play (rooms=> "$state", time => 60, volume => 80, file => "chimes/west30.wav")'
);

#speak "room=office The time is $Time_Now" if new_second 15;

sub proxy_speak_play {
    my ($mode)  = pop @_;
    my (%parms) = @_;

    return unless $Run_Members{proxy_client_server};
    return unless $parms{text} or $parms{file};

    print "3 proxy_play mode=$mode parms: @_\n" if $Debug{'proxy'};

    # Drop extra blanks and newlines
    $parms{text} =~ s/[\n\r ]+/ /gm;

    my @rooms = split ',', lc $parms{rooms};
    push @rooms;    # Announce all stuff to the shoutcast dj

    @rooms = sort keys %proxy_by_room if lc $parms{rooms} =~ /all/;
    for my $room (@rooms) {
        next
          unless my $address =
          $proxy_by_room{$room} . ":" . $config_parms{server_proxy_port};
        next if ( $room eq $config_parms{speak_mh_room} );
        print "Sending speech to proxy room=$room address=$address\n"
          if $Debug{'proxy'};

        # Filter out the blank parms
        %parms = map { $_, $parms{$_} } grep $parms{$_} =~ /\S+/, keys %parms;
        undef $parms{room};

        #        undef $parms{voice};  # MY ADD HERE
        &main::proxy_send( $address, $mode, %parms );
    }
}

# The following loads up a remote proxy system to allow it to receive speech.
$proxy_register = new Socket_Item( undef, undef, 'server_proxy_register' );
if ( my $datapart = said $proxy_register) {
    my ( $pass, $ws, $port, $room ) = split /,/, $datapart;
    if ( my $user = password_check $pass, 'server_proxy_register' ) {
        print_log "Proxy accepted for:  $room at $ws";
        $proxy_by_room{$room} = $ws;
        &add_proxy( $ws . ":$port" );
    }
    else {
        print_log "Proxy denied for:  $room at $ws";
    }
    stop $proxy_register;
}

if ( $New_Minute and $Debug{'proxy'} ) {
    for my $address ( keys %proxy_servers ) {
        if ( $proxy_servers{$address}->active ) {
            print_log "proxy_server: $address alive";
        }
        else {
            print_log "proxy_server: $address dead";
        }
    }
}

# Proxy Server Section

$proxy_server =
  new Socket_Item( undef, undef, 'server_proxy', undef, undef, undef, "\035" );

# Allow for proxy regstration to the main mh (optional)
# If you want this, add these mh.ini parms: mh_proxyreg_port, mh_server, and proxy_name
# And run code like in bruce/speak_proxy.pl
$v_proxy_init = new Voice_Cmd("Reconnect proxy");
if ( new_minute 20 or $Startup or $Reload or said $v_proxy_init) {
    my @rooms = sort keys %proxy_by_room;
    for my $room (@rooms) {
        print_log "$room $proxy_by_room{$room}";
        next unless my $address = $proxy_by_room{$room};
        next if ( $room eq $config_parms{speak_mh_room} );
        print "Connecting to server $address\n";
        my $s_proxy_init = new Socket_Item( undef, undef,
            $address . ":" . $config_parms{mh_proxyreg_port} );
        start $s_proxy_init;
        set $s_proxy_init
          "$config_parms{password},$config_parms{proxy_name},$config_parms{server_proxy_port},$config_parms{speak_mh_room}";
    }
}

# Process incoming requests from the real mh
if ( $state = said $proxy_server) {
    my ( $interface, $function, @data ) = split $;, $state;
    my $client = $Socket_Ports{'server_proxy'}{client_ip_address};
    print
      "client proxy data received from: client=$client function=$function data=@data.\n"
      if $Debug{'proxy'};

    if ( $function eq 'send_serial_data' ) {
        &Serial_Item::send_serial_data( $interface, $data[0] );
    }
    elsif ( $function eq 'send_x10_data' ) {
        &Serial_Item::send_x10_data( $interface, $data[0] );
    }
    elsif ( $function eq 'send_ir' ) {
        &ControlX10::CM17::send_ir( $main::Serial_Ports{cm17}{object},
            $data[0] );
    }
    elsif ( $function eq 'uirt2_send' ) {
        $main::Serial_Ports{UIRT2}{object}->write( pack 'C*', @data );
    }
    elsif ( $function eq 'ibutton' ) {
        my $function2 = shift @data;
        if ( $function2 eq 'scan_report' ) {
            my $result = &iButton::scan_report();
            $result =~ s/\n/$;/g;
            print "dbx sr=$result.\n";
            set $proxy_server join( $;, $result ), 'all';
        }
        elsif ( $function2 eq 'read_temp' ) {
            eval "$data[0] -> read_temp";
            print "proxy ibutton eval error: $@" if $@;
        }
    }
    elsif ( $function eq 'speak' ) {
        print_log "proxy speak: @data";
        my (%parms) = &parse_func_parms(@data);
        $parms{room}  = '';
        $parms{rooms} = $config_parms{speak_mh_room};
        $parms{voice} = $config_parms{speak_voice} if !defined( $parms{voice} );
        speak %parms;
    }
    elsif ( $function eq 'play' ) {
        print_log "proxy play: @data";
        my (%parms) = &parse_func_parms(@data);
        $parms{room}  = '';
        $parms{rooms} = $config_parms{speak_mh_room};
        play %parms;
    }
    elsif ( $function eq 'lynx10plc' ) {
        my $function2 = shift @data;
        if ( $function2 eq 'send_plc' ) {
            &Lynx10PLC::send_plc( $main::Serial_Ports{Lynx10PLC}{object},
                @data );
        }
        elsif ( $function2 eq 'readDeviceInfo' ) {
            &Lynx10PLC::readDeviceInfo( $main::Serial_Ports{Lynx10PLC}{object},
                $data[0] );
        }
    }

}

# Echo incoming serial data back to the real mh
&Serial_data_add_hook( \&proxy_serial_data ) if $Reload;

sub proxy_serial_data {
    my ( $data, $interface, $proxy ) = @_;
    return unless $data;
    return unless $interface;

    # if command came in from a proxy, don't send out as proxy
    print_log "proxy_serial_data: $proxy $interface" if $Debug{proxy};
    return if ($proxy);
    set $proxy_server join( $;, 'serial', $data, $interface ),
      'all';    # all writes out to all clients
    print
      "Proxy serial data sent to collective: interface=$interface data=$data.\n"
      if $Debug{proxy};
}

# Echo incoming iButton data back to the real mh
&iButton_receive_add_hook( \&proxy_ibutton_data ) if $Reload;

sub proxy_ibutton_data {
    if ( $proxy_server->active() ) {
        my ( $ref, $data, $proxy ) = @_;

        # if command came in from a proxy, don't send out as proxy
        return if ($proxy);
        my $name = $$ref{object_name};
        print "Proxy ibutton data sent:  $name $data.\n" if $Debug{proxy};
        set $proxy_server join( $;, 'set_receive', $name, $data ), 'all';
    }
}

# The rest of this code is similar to mh/code/mh_control.pl

# Those with ups devices can set this separately
# Those without a CM11 ... this will not hurt any
if ($ControlX10::CM11::POWER_RESET) {
    $ControlX10::CM11::POWER_RESET = 0;
    if ( $proxy_server->active() ) {
        print "Proxy CM11 power reset sent\n" if $Debug{proxy};
        set $proxy_server join( $;, 'set', '$Power_Supply', 'Restored' ), 'all';
    }
}

# Allow for keyboard control
if ($Keyboard) {
    if ( $Keyboard eq 'F1' ) {
        print "Key F1 pressed.  Reloading code\n";

        # Must be done before the user code eval
        push @Nextpass_Actions, \&read_code;
    }
    elsif ( $Keyboard eq 'F3' ) {
        print "Key F3 pressed.  Exiting\n";
        &exit_pgm;
    }
    elsif ($Keyboard) {
        print "key press: $Keyboard\n" if $Debug{misc};
    }
}

# Need this so the default tk_widgets.pl will not fail
$search_code_string = new Generic_Item;
