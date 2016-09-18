
# Category = Misterhouse

=begin comment

Use this to run a proxy mh.

The reasons you might want to run this are:

 - Allows the real real mh to not pause while reading or
   writing to slow interfaces (e.g. X10 CM11 or CM17).

 - Monitor remote serial ports (e.g 'mh in a barn')

 - Sharing of interfaces between different mh boxes

 - Speaking or playing sounds on a remote box

Run with mh/bin/mh_proxy

See 'Using distributed MisterHouse proxies' in mh/docs/mh.*  for more info.

=cut

$proxy_server =
  new Socket_Item( undef, undef, 'server_proxy', undef, undef, undef, "\035" );

#print '.';                      # A heartbeat

# Allow for proxy regstration to the main mh (optional)
# If you want this, add these mh.ini parms: mh_proxyreg_port, mh_server, and proxy_name
# And run code like in bruce/speak_proxy.pl
$v_proxy_init = new Voice_Cmd("Reconnect proxy");
if ( $config_parms{mh_proxyreg_port}
    and ( $Startup or said $v_proxy_init) )
{
    print "Connecting to server\n";
    my $s_proxy_init = new Socket_Item( undef, undef,
        $config_parms{mh_server} . ":" . $config_parms{mh_proxyreg_port} );
    start $s_proxy_init;
    set $s_proxy_init
      "$config_parms{password},$config_parms{proxy_name},$config_parms{server_proxy_port}";
}

# Process incoming requests from the real mh
if ( $state = said $proxy_server) {
    my ( $interface, $function, @data ) = split $;, $state;
    my $client = $Socket_Ports{'server_proxy'}{client_ip_address};
    print
      "Proxy data received from mh: client=$client, interface=$interface function=$function data=@data.\n"
      if $Debug{'proxy'};

    if ( $function eq 'send_serial_data' ) {
        &Serial_Item::send_serial_data( $interface, $data[0] );
    }
    elsif ( $function eq 'send_x10_data' ) {
        &Serial_Item::send_x10_data( $interface, $data[0] );

        # $proxy_x10_send is a Generic_Item on the host MH used to let
        # the host know when we are done sending data to an X10 interface.
        # It is first set on the host MH by x10_priority.pl to the $interface
        # string and then we set it here to 'idle' when done sending.
        if ( $config_parms{mh_proxy_status} and $proxy_server->active() ) {
            set $proxy_server join( $;, 'set', '$proxy_x10_send', 'idle' ),
              'all';
        }
    }
    elsif ( $function eq 'send_ir' ) {
        &ControlX10::CM17::send_ir( $main::Serial_Ports{cm17}{object},
            $data[0] );
    }
    elsif ( $function eq 'uirt2_send' ) {
        $main::Serial_Ports{UIRT2}{object}->write( pack 'C*', @data );
    }
    elsif ( $function eq 'BX24_Query_Barometer' ) {
        $main::Serial_Ports{BX24}{object}->write("B");
    }
    elsif ( $function eq 'ibutton' ) {
        my $function2 = shift @data;
        if ( $function2 eq 'scan_report' ) {
            my $result = &iButton::scan_report();
            $result =~ s/\n/$;/g;
            print "dbx sr=$result.\n";
            set $proxy_server $result, 'all';
        }
        elsif ( $function2 eq 'read_temp' ) {
            eval "$data[0] -> read_temp";
            print "proxy ibutton eval error: $@" if $@;
        }
    }
    elsif ( $function eq 'speak' ) {
        speak @data;
    }
    elsif ( $function eq 'play' ) {
        play @data;
    }
    elsif ( $function eq 'lynx10plc' ) {
        my $function2 = shift @data;
        if ( $function2 eq 'send_plc' ) {
            &Lynx10PLC::send_plc( $main::Serial_Ports{Lynx10PLC}{object},
                $data[0], $data[1] );
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
    my ( $data, $interface ) = @_;
    return unless $data;
    print "Proxy serial data sent to mh: interface=$interface data=$data.\n"
      if $Debug{proxy};
    if ( $proxy_server->active() ) {
        set $proxy_server join( $;, 'serial', $data, $interface ),
          'all';    # all writes out to all clients
    }
}

# Echo incoming iButton data back to the real mh
&iButton_receive_add_hook( \&proxy_ibutton_data ) if $Reload;

sub proxy_ibutton_data {
    if ( $proxy_server->active() ) {
        my ( $ref, $data ) = @_;
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

# Make sure main mh program is still alive ... don't announce when sleeping!
if ( new_minute 5 and !active $proxy_server) {
    my $msg = "Proxy can not talk to Mister House";
    ( $Hour > 9 and $Hour < 23 ) ? speak $msg : print_log $msg;
}
