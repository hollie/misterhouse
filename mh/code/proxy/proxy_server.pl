
# Category = Misterhouse

=begin comment

Use this to run a proxy mh, to process only serial events.

The reasons you might want to run this are:

 - Allows the real real mh to not pause while reading or
   writing to slow interfaces (e.g. X10 CM11 or CM17).

 - Monitor remote serial ports (e.g 'mh in a barn')

 - Sharing of interfaces between different mh boxes

Run with mh/bin/mh_proxy

See 'Using distributed MisterHouse proxies' in mh/docs/mh.*  for more info.

=cut

$proxy_server  = new  Socket_Item(undef, undef, 'server_proxy', undef, undef, undef, "\035");

#print '.';                      # A heartbeat

                                # Process incoming requests from the real mh
if ($state = said $proxy_server) {
    my ($interface, $function, @data) = split $;, $state;
    print_log "Proxy data received from mh: interface=$interface function=$function data=@data." if $config_parms{debug} eq 'proxy';

    if ($function eq 'send_serial_data') {
        &Serial_Item::send_serial_data($interface, $data[0]);
    }
    elsif ($function eq 'send_x10_data') {
        &Serial_Item::send_x10_data($interface, $data[0]);
    }
    elsif ($function eq 'send_ir') {
        &ControlX10::CM17::send_ir($main::Serial_Ports{cm17}{object}, $data[0]);
    }
    elsif ($function eq 'ibutton') {
        my $function2 = shift @data;
        if ($function2 eq 'scan_report') {
            my $result = &iButton::scan_report();
            $result =~ s/\n/$;/g;
            print "dbx sr=$result.\n";
            set $proxy_server $result, 'all';
        }
        elsif ($function2 eq 'read_temp') {
            eval "$data[0] -> read_temp";
            print "proxy ibutton eval error: $@" if $@;
        }
    }
    elsif ($function eq 'speak') {
        speak @data;
    }
    elsif ($function eq 'play') {
        play @data;
    }
}

                                # Echo incoming serial data back to the real mh
&Serial_data_add_hook(\&proxy_serial_data) if $Reload;
sub proxy_serial_data {
    my ($data, $interface) = @_;
    return unless $data;
    print_log "Proxy serial data sent to mh: interface=$interface data=$data." if $config_parms{debug} eq 'proxy';
    if ($proxy_server->active()) {
        set $proxy_server join($;, 'serial', $data, $interface), 'all'; # all writes out to all clients
    }
}


                                # Echo incoming iButton data back to the real mh
&iButton_receive_add_hook(\&proxy_ibutton_data) if $Reload;
sub proxy_ibutton_data {
    if ($proxy_server->active()) {
        my ($ref, $data) = @_;
        my $name = $$ref{object_name};
        print_log "Proxy ibutton data sent:  $name $data." if $config_parms{debug} eq 'proxy';
        set $proxy_server join($;, 'set_receive', $name, $data), 'all';
    }
}


# The rest of this code is similar to mh/code/mh_control.pl

                                # Those with ups devices can set this seperatly
                                # Those without a CM11 ... this will not hurt any
if ($ControlX10::CM11::POWER_RESET) {
    $ControlX10::CM11::POWER_RESET = 0;
    if ($proxy_server->active()) {
        print_log "Proxy CM11 power reset sent" if $config_parms{debug} eq 'proxy';
        set $proxy_server join($;, 'set', '$Power_Supply', 'Restored'), 'all';
    }
}


                                # Allow for keyboard control
if ($Keyboard) {    
    if ($Keyboard eq 'F1') {
        print "Key F1 pressed.  Reloading code\n";
                                # Must be done before the user code eval
        push @Nextpass_Actions, \&read_code;
    }
    elsif ($Keyboard eq 'F3') {
        print "Key F3 pressed.  Exiting\n";
        &exit_pgm;
    }
    elsif ($Keyboard) {
        print "key press: $Keyboard\n" if $config_parms{debug} eq 'misc';
    }
}

                                # Need this so the default tk_widgets.pl will not fail
$search_code_string = new Generic_Item;


                                # Make sure main mh program is still alive
if ($New_Minute and !active $proxy_server) {
    speak "Proxy can not talk to Mister House";
}

