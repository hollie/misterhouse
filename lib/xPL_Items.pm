
=begin comment

xPL_Items.pm - Misterhouse interface for the xPL protocol

Info:

 xPL websites:
    http://www.xplproject.org.uk
    http://www.xaphal.com

Authors:
 10/26/2002  Created by Bruce Winter bruce@misterhouse.net


xPL works by using the xPL Hub built in misterhouse and listening for
xPL connections. See:
http://misterhouse.wikispaces.com/xAP+and+xPL+-+Getting+Started

Relevant variables for mh.private.ini are:
#ipaddress_xpl_broadcast = 192.168.205.255
#ipaddress_xpl = 192.168.205.3
#xpl_disable = 1
#xpl_nohub = 1
#xpl_enable_items = 1

You can disable the mh internal xPL hub if you are running a more capable one.
To get data input, you can use something like

xpl-rfxcom-rx --verbose --rfxcom-rx-verbose --rfxcom-rx-tty /dev/rfxcom --interface eth1

from xPL-Perl. Then watch for sensor updates passing by and paste their info
in your device table, like so:
XPL_SENSOR, bnz-rfxcomrx.gargamel:bthr918n.e6, oregon_intemp, XPL_temp, temp

Another option to figure out the name to use in XPL_SENSOR is to use
xpl-logger -head -body -i ethx 2>&1 | grep "xpl-trig\/"
(or without the grep for more details on which field is called what).

A few samples:
XPL_SENSOR, iranger-rfx.*:WGR918, oregon_winddir, , direction
XPL_SENSOR, iranger-rfx.*:BHTR968, oregon_intemp, , temp
XPL_SENSOR, bnz-owfs.*:10.2223EF010800, owfs_temp, , temp
XPL_SENSOR, bnz-owfs.*:26.2E4DF5000000, owfs_humidity, , humidity
XPL_SENSOR, bnz-owfs.*:26.2E4DF5000000.1, owfs_humidity1, , humidity
XPL_X10SECURITY, iranger-rfx.*:F8, x10sec_garage1, , ds10

Note that XPL_SENSOR should just be used for XPL messages of the x10.basic
type. XPL_X10SECURITY is for x10.security schema, while there is no way to
currently read x10.basic messages (see this file for more supported schemas).

Once it is running, objects get variables including these:
'state' => '17.9',
'states_nosubstate' => 1,
'states_substate' ?
'address' => 'bnz-rfxcomrx.gargamel',
'states_nomultistate' => 1,
'states_multistate' ?
'target_address' => '*',
'_device_id' => 'bthr918n.e6'
'set_time' => 1285555578,
'm_timerHeartBeat' => bless( {}, 'Timer' ),
'm_timeoutHeartBeat' => 0,


So, you would write this to print temperature:
print_log $oregon_intemp->state
=cut

use strict;

package xPL;

#@xPL::ISA = ('Generic_Item');

my (
    @xpl_item_names, $started,            %hub_ports,
    $xpl_listen,     $xpl_hub_listen,     $xpl_send,
    %xpl_hub_ports,  $xpl_hbeat_interval, $xpl_hbeat_counter
);

# Create sockets and add hook to check incoming data
sub startup {
    return
      if $started++
      ;    # Allows us to call with $Reload or with xpl_module mh.ini parm

    # In case you don't want xpl for some reason
    return if $::config_parms{xpl_disable};

    # determine our local ipaddress(es)
    @xpl_item_names = ();
    my ($port);

    # init the hbeat intervals and counters
    $xpl_hbeat_interval = $::config_parms{xpl_hbeat_interval};
    $xpl_hbeat_interval = 5 unless $xpl_hbeat_interval;
    $xpl_hbeat_counter  = $xpl_hbeat_interval;

    if ( !( $::config_parms{xpl_disable} ) ) {
        undef $port;
        $port = $::config_parms{xpl_port};
        $port = 3865 unless $port;

        # open the sending port
        &open_port( $port, 'send', 'xpl_send', 0, 1 );
        $xpl_send = new Socket_Item( undef, undef, 'xpl_send' );

        # Find and use the first open port
        my $port_listen;
        for my $p ( 49352 .. 65535 ) {
            $port_listen = $p;
            last if &open_port( $port_listen, 'listen', 'xpl_listen', 1, 1 );
        }

        # The socket code will select a free local port if given 0
        # not working on ubuntu 12.04
        #&open_port( 0, 'listen', 'xpl_listen', 1, 1 );
        #$port_listen = $::Socket_Ports{'xpl_listen'}{port};
        $xpl_listen = new Socket_Item( undef, undef, 'xpl_listen' );

        # initialize the hub (listen) port
        if ( $::config_parms{xpl_nohub} ) {
            $xpl_hub_listen = undef;
        }
        else {
            if ( &open_port( $port, 'listen', 'xpl_hub_listen', 0, 1 ) ) {
                $xpl_hub_listen =
                  new Socket_Item( undef, undef, 'xpl_hub_listen' );
                print " - mh in xPL Hub mode\n";

                # now set up the hub port that will send to mh
                $xpl_hub_ports{$port_listen} = &xPL::get_xpl_mh_source_info();
                my $port_name = "xpl_send_$port_listen";
                &open_port( $port_listen, 'send', $port_name, 1, 1 );
            }
            else {
                print " - mh automatically switching out of xPL Hub mode.  "
                  . "Another application is binding to the hub port ($port)\n";
                $xpl_hub_listen = undef;
            }
        }

        # now that a listen port exists, advertise it w/ the first hbeat msg
        &xPL::send_xpl_heartbeat() if $xpl_send;

    }

    &::MainLoop_pre_add_hook( \&xPL::check_for_data, 1 );

    # add reload hook so that xpl_item_names list is reset
    &::Reload_pre_add_hook( \&xPL::reload_hook, 1 );
}

sub reload_hook {
    @xpl_item_names = ();
}

sub main::display_xpl {
    my (%args) = @_;
    my $schema = lc ${args}{schema};
    $schema = 'osd.basic' unless $schema;
    if ( $schema eq 'osd.basic' ) {
        &main::display_xpl_osd_basic(%args);
    }
    else {
        &main::print_log(
            "Display support for the schema, $schema, does not yet exist");
    }
}

sub main::display_xpl_osd_basic {
    my (%args) = @_;
    my ( $text, $duration, $address );
    $text = $args{raw_text};
    $text = $args{text} unless $text;
    $text =~ s/[\n\r ]+/ /gm;    # strip out new lines and extra space
    $text =~ s/\n/\\n/gm;        # escape new lines
    $duration = $args{duration};
    $duration = $args{display}
      unless $duration;          # this apparently is the original param?
    $duration = 10 unless $duration;              # default to 10 sec display
    $address  = $args{to};
    $address  = $args{address} unless $address;
    $address  = '*' unless $address;

    # auto pre-pend text w/ a newline if the target is a squeezebox and
    # doesn't already have one
    if ( $address =~ /^slimdev-slimserv/i ) {
        $text = "\\n$text" unless $text =~ /\\n\S+/i;
    }
    &xPL::send( 'xPL', $address,
        'osd.basic' =>
          { command => 'write', delay => $duration, text => $text } );
}

sub open_port {
    my ( $port, $send_listen, $port_name, $local, $verbose ) = @_;

    # Need to re-open the port, if client app has been re-started??
    close $::Socket_Ports{$port_name}{sock}
      if $::Socket_Ports{$port_name}{sock};

    my $sock;
    if ( $send_listen eq 'send' ) {
        my $dest_address;
        if ($local) {
            if ( $main::OS_win || $::Info{'OS_name'} eq 'cygwin' ) {
                $dest_address = $::Info{IPAddress_local} unless $dest_address;
            }
            else {
                $dest_address = '0.0.0.0';
            }
        }
        else {
            $dest_address = $::config_parms{'ipaddress_xpl_broadcast'};
            $dest_address = '255.255.255.255' unless $dest_address;
        }
        $sock = new IO::Socket::INET->new(
            PeerPort  => $port,
            Proto     => 'udp',
            PeerAddr  => $dest_address,
            Broadcast => 1
        );

        print "db xPL_Items open_port: pn=$port_name l=$local PeerPort=$port "
          . "PeerAddr=$dest_address"
          if $main::Debug{xpl};
    }
    else {
        my $listen_address;
        if ( !($local) ) {
            $listen_address = $::config_parms{'ipaddress_xpl'};
            $listen_address = $::config_parms{'xpl_address'}
              unless $listen_address;
        }
        if ( $main::OS_win || $::Info{'OS_name'} eq 'cygwin' ) {
            $listen_address = $::Info{IPAddress_local} unless $listen_address;
        }
        else {
            # can't get *nix to bind to a specific address; defaults to
            # kernel assigned default IP
            $listen_address = '0.0.0.0';
        }
        $sock = new IO::Socket::INET->new(
            LocalPort => $port,
            Proto     => 'udp',
            LocalAddr => $listen_address,
            Broadcast => 1
        );
        $port = $sock->sockport() if ( $port == 0 );

        print "db xPL_Items open_port: pn=$port_name l=$local LocalPort=$port "
          . "LocalAddr=$listen_address"
          if $main::Debug{xpl};
    }
    unless ($sock) {
        print " -- FAILED\n" if $main::Debug{xpl};
        print "\nError:  Could not start a udp xPL send server on $port: $@\n\n"
          if $send_listen eq 'send';
        return 0;
    }
    print "\n" if $main::Debug{xpl};

    printf " - creating %-15s on %3s %5s %s\n", $port_name, 'udp', $port,
      $send_listen
      if $verbose;

    $::Socket_Ports{$port_name}{protocol} = 'udp';
    $::Socket_Ports{$port_name}{datatype} = 'raw';
    $::Socket_Ports{$port_name}{port}     = $port;
    $::Socket_Ports{$port_name}{sock}     = $sock;
    $::Socket_Ports{$port_name}{socka} = $sock;  # UDP ports are always "active"

    return $sock;
}

sub check_for_data {

    if ( $xpl_hub_listen && ( my $xpl_hub_data = said $xpl_hub_listen) ) {
        &_process_incoming_xpl_hub_data($xpl_hub_data);
    }
    if ( $xpl_listen && ( my $xpl_data = said $xpl_listen) ) {
        &_process_incoming_xpl_data($xpl_data);
    }

    # check to see if hbeats need to be sent
    if ( &::new_minute($xpl_hbeat_interval) ) {
        if ($xpl_send) {
            if ( $xpl_hbeat_counter == 5 ) {
                &xPL::send_xpl_heartbeat();
                $xpl_hbeat_counter = $xpl_hbeat_interval;
            }
            else {
                $xpl_hbeat_counter = $xpl_hbeat_counter - 1;
            }
        }
    }
}

# Parse incoming xPL records
sub parse_data {
    my ($data) = @_;
    my ( $source, $class, $target, $msg_type, $section, %d );
    print "db4 xPL data:\n$data\n"
      if $main::Debug{xpl} and $main::Debug{xpl} == 4;
    for my $r ( split /[\r\n]/, $data ) {
        next if $r =~ /^[\{\} ]*$/;

        # Store xpl-header, xpl-heartbeat, and other data
        if ( my ( $key, $value ) = $r =~ /(.+?)=(.*)/ ) {
            $key   = lc $key;
            $value = lc $value
              if ( $section =~ /^xpl/ );    # Do not lc real data;
            $source = $value if $section =~ /^xpl/ and $key =~ /^source$/i;
            $target = $value if $section =~ /^xpl/ and $key =~ /^target$/i;
            if ( exists( $d{$section}{$key} ) ) {
                $d{$section}{$key} .=
                  "," . $value;             # xpl allows "continuation lines"
            }
            else {
                $d{$section}{$key} = $value;
            }
            print "db4 xpl parsed c=$section k=$key v=$value\n"
              if ( $main::Debug{xpl} and $main::Debug{xpl} == 4 );
        }

        # section (e.g. xpl-header, xpl-heartbeat, source.instance
        else {
            $section = lc $r;
            $msg_type ? $class = $section : $msg_type = $section;
        }
    }

    # define target as '*' if undefined
    $target = '*' if !($target);

    return ( \%d, $source, $class, $target, $msg_type );
}

sub _process_incoming_xpl_hub_data {
    my ($data) = @_;
    my $ip_address = $::config_parms{'ipaddress_xpl'};
    $ip_address = $::Info{IPAddress_local} unless $ip_address;

    my ( $xpl_data, $source, $class, $target, $msg_type ) = &parse_data($data);

    return unless $source;

    my ($port);

    # Log hearbeats of other apps; ignore hbeat.basic messages as these
    # should not be handled by the hub
    if ( $$xpl_data{'hbeat.app'} ) {

        # rely on the xPL-message's remote-ip attribute in the hbeat.app
        # as the basis for performing IP comparisons
        my $sender_ip_address = $$xpl_data{'hbeat.app'}{'remote-ip'};

        # Open/re-open the port on every hbeat if it posts a listening port.
        # Skip if it is our own hbeat (port = listen port)
        if ( ( $sender_ip_address eq $ip_address ) ) {
            $port = $$xpl_data{'hbeat.app'}{port};
            if ($port) {
                $xpl_hub_ports{$port} = $source;
                my $port_name = "xpl_send_$port";
                my $msg =
                  ( $::Socket_Ports{$port_name}{sock} )
                  ? 'renewing'
                  : 'registering';
                print "db xpl $msg port=$port to xPL client $source\n"
                  if $main::Debug{xpl};

                # xPL apps want local
                &open_port( $port, 'send', $port_name, 1,
                    $msg eq 'registering' );
            }
        }
    }

    # As a hub, echo data to other xpl listeners unless it's our transmission
    for $port ( keys %xpl_hub_ports ) {
        my $sock = $::Socket_Ports{"xpl_send_$port"}{sock};
        print "db2 xpl hub: sending xpl data to p=$port destination="
          . "$xpl_hub_ports{$port} s=$sock d=\n$data.\n"
          if $main::Debug{xpl} and $main::Debug{xpl} == 2;
        print $sock $data if defined($sock);
    }
}

sub _process_incoming_xpl_data {
    my ($data) = @_;

    my ( $xpl_data, $source, $class, $target, $msg_type ) = &parse_data($data);

    print "db1 xpl check: s=$source c=$class t=$target d=\n$data\n"
      if $main::Debug{xpl} and $main::Debug{xpl} == 1;

    # the first time that this sub is called, the xpl_item_names array
    # needs to be filled
    if ( !(@xpl_item_names) ) {
        foreach my $object_type (&::list_object_types) {
            foreach my $object_name ( &::list_objects_by_type($object_type) ) {
                my $object = &::get_object_by_name("$object_name");
                if ( $object and $object->isa('xPL_Item') ) {
                    push @xpl_item_names, $object_name;
                }
            }
        }
    }

    return unless $source;

    # continue processing unless we are the source (e.g., heart-beat)
    if ( !( $source eq &xPL::get_xpl_mh_source_info() ) ) {

        # Set states in matching xPL objects
        for my $name (@xpl_item_names)
        {    #(&::list_objects_by_type('xPL_Item')) {
            my $o = &main::get_object_by_name($name);
            $o = $name unless $o;    # In case we stored object directly
            print "db3 xpl test  o=$name s=$source oa=$$o{source}\n"
              if $main::Debug{xpl} and $main::Debug{xpl} == 3;

            # skip this object unless the source matches if a stat or trig
            # otherwise, we check the target for a cmnd
            # NOTE: the object's hash reference for "source" is "address"
            my $regex_address = &wildcard_2_regex( $$o{address} );
            if ( $$o{set_state_on_cmnd} and $msg_type eq 'xpl-cmnd' ) {
                my $regex_target = &wildcard_2_regex($target);
                next
                  unless ( $target =~ /^$regex_address$/i )
                  or ( $$o{address} =~ /^$regex_target$/i );
            }
            else {
                if ( $source =~ /^$regex_address$/i ) {

                    # handle hbeat data
                    for my $section ( keys %{$xpl_data} ) {
                        if ( $section =~ /^hbeat./i ) {
                            if ( lc $section eq 'hbeat.app' ) {
                                $o->_handle_alive_app();
                            }
                            else {
                                $o->_handle_dead_app();
                            }
                        }
                    }
                }
                else {
                    next;
                }
            }

            # skip this object unless the class matches
            if ( $class && $$o{class} ) {
                my $regex_class = &wildcard_2_regex( $$o{class} );
                next unless $class =~ /^$regex_class$/i;
            }

            # check if device monitoring is enabled
            if ( !( $class =~ /hbeat./i ) ) {
                next if $o->ignore_message($xpl_data);
            }

            # Find and set the state variable
            my $state_value;
            $$o{changed} = '';
            for my $section ( keys %{$xpl_data} ) {
                $$o{sections}{$section} = 'received'
                  unless $$o{sections}{$section};
                for my $key ( keys %{ $$xpl_data{$section} } ) {
                    my $value = $$xpl_data{$section}{$key};

                    # does a tied value convertor exist for this key and object?
                    my $value_convertor = $$o{_value_convertors}{$key}
                      if defined( $$o{_value_convertors} );
                    if ($value_convertor) {
                        print
                          "db xpl: located value convertor: $value_convertor\n"
                          if $main::Debug{xpl};
                        my $converted_value = eval $value_convertor;
                        if ($@) {
                            print $@;
                        }
                        else {
                            print
                              "db xpl: converted value is: $converted_value\n"
                              if $main::Debug{xpl};
                        }
                        $value = $converted_value if $converted_value;
                    }
                    $$o{$section}{$key} = $value;

                    # Monitor what changed (real data, and include hbeat as
                    # it may include useful info, e.g., slimserver).
                    $$o{changed} .= "$section : $key = $value | "
                      unless $section eq 'xpl-stat'
                      or $section eq 'xpl-trig'
                      or $section eq 'xpl-cmnd'
                      or ( $section eq 'hbeat.app' and $key ne 'status' );
                    print "db3 xpl state check m=$$o{state_monitor} key="
                      . "$section : $key  value=$value\n"
                      if $main::Debug{xpl};    # and $main::Debug{xpl} == 3;
                    if ( $$o{state_monitor} ) {
                        foreach my $state_monitor (
                            split( /\|/, $$o{state_monitor} ) )
                        {
                            if ( $state_monitor =~ /$section\s*[:=]\s*$key/i
                                and defined $value )
                            {
                                print "db3 xpl setting state to $value\n"
                                  if $main::Debug{xpl}
                                  and $main::Debug{xpl} == 3;
                                $state_value = $value;
                            }
                        }
                    }
                }
            }

            # assign the "summary" of the message to state_value unless
            # state_monitor is being used
            $state_value = $$o{changed} unless $$o{state_monitor};
            print "db3 xpl set: n=$name to state=$state_value\n\n"
              if $main::Debug{xpl};    # and $main::Debug{xpl} == 3;

            # Can not use Generic_Item set method, as state_next_pass
            # only carries state, not all other $section data, to the next pass
            #           $o -> SUPER::set($state_value, 'xPL') if defined $state_value;

            $o->received($data);
            if ( defined $state_value and $state_value ne '' ) {
                my $set_by_name = 'xPL';
                $set_by_name .= " [$source]";
                $o->set_now( $state_value, $set_by_name );

                #$o->SUPER::set_now( $state_value, $set_by_name );
                $o->state_now_msg_type("$msg_type");
            }
        }
    }
}

sub get_mh_vendor_info {
    return 'mhouse';
}

sub get_mh_device_info {
    return 'mh';
}

sub get_xpl_mh_source_info {
    my $instance = $::config_parms{xpl_title};
    $instance = $::config_parms{title} unless $instance;
    $instance =
      ( $instance =~ /misterhouse(.*)pid/i ) ? 'misterhouse' : $instance;
    $instance = &xPL::get_ok_name_part($instance);
    return
        &get_mh_vendor_info() . '-'
      . &get_mh_device_info() . '.'
      . $instance;
}

sub get_ok_name_part {
    my ($in_name) = @_;
    my $out_name = lc $in_name;
    $out_name =~ tr/ /_/;
    $out_name =~ s/[^a-z0-9\-_]//g;
    return $out_name;
}

sub wildcard_2_regex {
    my ($expr) = @_;
    return unless $expr;

    # convert all periods
    $expr =~ s/\./(\\\.)/g;

    # convert all asterisks
    $expr =~ s/\*/(\.\*)/g;

    # treat all :> as asterisks
    $expr =~ s/:>/(\.\*)/g;

    # convert all greater than symbols
    $expr =~ s/>/(\.\*)/g;

    return $expr;
}

sub send {
    my ( $protocol, $class_address, @data ) = @_;

    print "db5 xPL send: ca=$class_address d=@data xpl_send=$xpl_send\n"
      if ( $main::Debug{xpl} and $main::Debug{xpl} == 5 );

    my $target = $class_address;
    &sendXpl( $target, 'cmnd', @data );
}

sub sendXpl {
    if ( defined($xpl_send) ) {
        my ( $target, $msg_type, @data ) = @_;
        my ( $parms, $msg );
        $msg = "xpl-$msg_type\n{\nhop=1\nsource="
          . &xPL::get_xpl_mh_source_info() . "\n";
        if ( defined($target) ) {
            $msg .= "target=$target\n";
        }
        $msg .= "}\n";
        while (@data) {
            my $section = shift @data;
            $msg .= "$section\n{\n";
            my $ptr = shift @data;
            if ($ptr) {
                my %parms = %$ptr;
                for my $key ( sort keys %parms ) {

                    # order is important for many xPL clients
                    # allow a sort key delimitted by ## to drive the order
                    my ( $subkey1, $subkey2 ) = $key =~ /^(\S+)##(.*)/;
                    if ( defined $subkey1 and defined $subkey2 ) {
                        $msg .= "$subkey2=$parms{$key}\n";
                    }
                    else {
                        $msg .= "$key=$parms{$key}\n";
                    }
                }
            }
            $msg .= "}\n";
        }
        print "db5 xpl msg: $msg"
          if $main::Debug{xpl};    # and $main::Debug{xpl} == 5;
        if ($xpl_send) {

            # check to see if the socket is still valid
            if ( !( $::Socket_Ports{'xpl_send'}{socka} ) ) {
                &xPL::_handleStaleXplSockets();
            }
            $xpl_send->set($msg) if $::Socket_Ports{'xpl_send'}{socka};
        }
    }
    else {
        print "WARNING! xPL is disabled and you are trying to send xPL "
          . "data!! (xPL::sendXpl())\n";
    }
}

sub send_xpl_heartbeat {
    my ($protocol) = @_;
    my $port       = $::Socket_Ports{xpl_listen}{port};
    my $ip_address = $::config_parms{'xpl_address'};
    $ip_address = $::config_parms{'ipaddress_xpl'} unless $ip_address;
    $ip_address = $::Info{IPAddress_local}
      unless $ip_address and $ip_address ne '0.0.0.0';

    my $msg;
    if ($xpl_send) {
        $msg =
            "xpl-stat\n{\nhop=1\nsource="
          . &xPL::get_xpl_mh_source_info()
          . "\ntarget=*\n}\nhbeat.app\n{\ninterval=$xpl_hbeat_interval\nport="
          . "$port\nremote-ip=$ip_address\n}\n";

        # check to see if all of the sockets are still valid
        &xPL::_handleStaleXplSockets();
        if ( $::Socket_Ports{'xpl_send'}{socka} ) {
            $xpl_send->set($msg);
            print "db6 xPL heartbeat: $msg.\n"
              if $main::Debug{xpl} and $main::Debug{xpl} == 6;
        }
        else {
            print
              "Error in xPL_Item::send_heartbeat.  send socket not active\n";
        }
    }
    else {
        print "Error in xPL_Item::send_heartbeat.  "
          . "xPL send socket not available.\n"
          . "Either disable xPL (xpl_disable = 1) or resolve "
          . "system network problem (UDP port 3865).\n";
    }
}

sub _handleStaleXplSockets {

    # check main sending socket
    my $port_name = 'xpl_send';
    if ( !( $::Socket_Ports{$port_name}{socka} ) ) {
        if (
            &xPL::open_port(
                $::Socket_Ports{$port_name}{port},
                'send', $port_name, 0, 1
            )
          )
        {
            print "Notice. xPL socket ($port_name) had been closed and "
              . "has been reopened\n";
        }
        else {
            print "WARNING! xPL socket ($port_name) had been closed and "
              . "can not be reopened\n";
        }
    }

    # check main listening socket
    $port_name = 'xpl_listen';
    if ( !( $::Socket_Ports{$port_name}{socka} ) ) {
        if (
            &xPL::open_port(
                $::Socket_Ports{$port_name}{port},
                'listen', $port_name, 0, 1
            )
          )
        {
            print "Notice. xPL socket ($port_name) had been closed and "
              . "has been reopened\n";
        }
        else {
            print "WARNING! xPL socket ($port_name) had been closed and "
              . "can not be reopened\n";
        }
    }

    # check the hub listening socket if hub mode is enabled
    if ( !( $::config_parms{xpl_nohub} ) and defined($xpl_hub_listen) ) {
        $port_name = 'xpl_hub_listen';
        if ( !( $::Socket_Ports{$port_name}{socka} ) ) {
            if (
                &xPL::open_port(
                    $::Socket_Ports{$port_name}{port},
                    'listen', $port_name, 0, 1
                )
              )
            {
                print "Notice. xPL socket ($port_name) had been closed and "
                  . "has been reopened\n";
            }
            else {
                print "WARNING! xPL socket ($port_name) had been closed and "
                  . "can not be reopened\n";
            }
        }

        # no need to check each hub "responder" socket as it is automatically
        # reopened on receipt of client's heartbeat
    }
}

package xPL_Item;

=head1 NAME

xPL_Item - Misterhouse base xPL Item

=head1 SYNOPSIS

   IMPORTANT: Mark uses of following methods if for init purposes w/ # noloop.  Sample use follows:

   $mySqueezebox = new xPL_Item('slimdev-slimserv.squeezebox');
   $mySqueezebox->manage_heartbeat_timeout(360, "speak 'Squeezebox is not reporting'",1); # noloop

=head1 DESCRIPTION
=begin comment


   If # noloop is not used on manage_heartbeat_timeout, you will see many attempts to start the timer

   state_now(): returns all current section data using the following form (unless otherwise
	set via state monitor):
	<section_name1> : <key1> = <value1> | <section_name_n> : <key_n> = <value_n>

   state_now(section_name): returns undef if not defined; otherwise, returns current data for
	section name using the following form (unless otherwise set via state_monitor):
	<key1> = <value1> | <key_n> = <value_n>

   current_section_names: returns the list of current section names delimitted by the pipe character

   tie_value_convertor(keyname, expr): ties the code reference in expr to keyname.  The returned
      value from expr is substituted into the key value. The reference in expr may use the variables
      $section and $value for processing (where $section is the section name and $value is the
      original value.

      e.g., $xpl_obj->tie_value_convertor('temp','$main::convert_c_to_f_degrees($value');
      note: the reference to '$main::' allows access to the user code sub - convert_c_to_f_degrees

   class_name(class_name): Sets/Gets the classname.  Classname is actually the <classname>.<typename>
      for xPL.  It is also often referred to as the schema name.  Used to filter
      inbound messages.  Except for generic "monitors", this shoudl be set.

   source(source): Sets/Gets the source (name).  This is normally <vendor_id>.<device_id>.<instance_id>.
      It is used to filter inbound messages. Except for generic "monitors", this should be set.

   target_address(target_address): Sets/Gets the target (name).  Syntax is similar to source.  Used to direct (target)
      the message to a specific device.  Use "*" (default) for broadcast messages.

   manage_heartbeat_timeout(timeout, action, repeat).  Sets the timeout interval (in secs) and action to be performed
      on expiration of a timer w/ no corresponding heart-beat messages.  Used to enable warnings/notices
      of absent heart-beats. See comments on using # noloop above.  Timeout should be set to a value
      greater than the actual device heartbeat interval. Action/timer is not repeated unless
      repeat is -1 (probably the only thing that makes sense for a heartbeat check).

   dead_action(action).  Sets/gets the action to be applied on receipt of a "dead" heartbeat (the app
      indicates that it is stopping/dying). Not all devices supply a "dead" heartbeat message;
      therefore, use manage_heartbeat_timeout as the primary safeguard.

   app_status().  Gets the app status. Initially, set to "unknown" until receipt of first "alive"
      heartbeat (then, set to "alive"). Set to "dead" on first dead heart-beat.

   send_cmnd(data).  Sends xPL message to target device using data hash.

   device_monitor(deviceinfo): constrains state updates to only messages w/ a devicekey=devicevalue
       pair. A common example is where deviceinfo is set to 'someid'.  In this case, state updates
       are constrained to occur only when a message constains "device=someid".  deviceinfo can also
       take the literal 'somekey = someid' for messages that use a key other than the literal: 'device'.


=cut

@xPL_Item::ISA = ('Generic_Item');

=item $h = xPL_Item->new('tag', 'attrname' => 'value',...)

The object constructor.  Takes a tag name as argument. Optionally,
allows you to specify initial attributes at object creation time.

=cut

# Support both send and receive objects
sub new {
    my ( $object_class, $xpl_source, @data, $xpl_class ) = @_;
    my $self = {};
    bless $self, $object_class;

    $xpl_source = '*' if !$xpl_source or $xpl_source eq '*';

    $$self{state}          = '';
    $$self{address}        = $xpl_source;           # left in place for legacy
    $$self{address}        = '*' if !$xpl_source;
    $$self{target_address} = '*';
    $$self{class}                = $xpl_class unless !$xpl_class;
    $$self{m_timeoutHeartBeat}   = 0;
    $$self{m_appStatus}          = 'unknown';
    $$self{m_timerHeartBeat}     = new Timer();
    $$self{m_state_now_msg_type} = 'unknown';
    $$self{m_allow_empty_state}  = 0;

    &xPL_Item::store_data( $self, @data );

    $self->state_overload('off')
      ;    # By default, do not process ~;: strings as substate/multistate

    return $self;
}

sub source {
    my ( $self, $p_strSource ) = @_;
    $$self{address} = $p_strSource if defined $p_strSource;
    return $$self{address};
}

sub class_name {

    my ( $self, $p_strClassName ) = @_;
    $$self{class} = $p_strClassName if defined $p_strClassName;
    return $$self{class};
}

sub target_address {
    my ( $self, $p_strTarget ) = @_;
    $$self{target_address} = $p_strTarget if defined $p_strTarget;
    return $$self{target_address};
}

sub received {
    my ( $self, $received ) = @_;
    $$self{received} = $received if defined $received;
    return $$self{received};
}

sub device_name {
    my ( $self, $p_strDeviceName ) = @_;
    $$self{m_device_name} = $p_strDeviceName if $p_strDeviceName;
    return $$self{m_device_name};
}

sub on_set_message {
    my ( $self, @data ) = @_;
    while (@data) {
        my $section = shift @data;
        my $ptr     = shift @data;
        my %parms   = %$ptr;
        for my $key ( sort keys %parms ) {
            my $value = $parms{$key};
            $$self{_on_set_message}{$section}{$key} = $value;
        }
    }
    return $$self{_on_set_message};
}

sub allow_empty_state {
    my ( $self, $p_allowEmptyState ) = @_;
    $$self{m_allow_empty_state} = $p_allowEmptyState
      if defined($p_allowEmptyState);
    return $$self{m_allow_empty_state};
}

sub manage_heartbeat_timeout {
    my ( $self, $p_timeoutHeartBeat, $p_actionHeartBeat, $p_repeatAction ) = @_;
    if ( defined($p_timeoutHeartBeat) and defined($p_actionHeartBeat) ) {
        my $m_repeatAction = 0;
        $m_repeatAction = $p_repeatAction if $p_repeatAction;
        $$self{m_actionHeartBeat}  = $p_actionHeartBeat;
        $$self{m_timeoutHeartBeat} = $p_timeoutHeartBeat;
        $$self{m_timerHeartBeat}->set(
            $$self{m_timeoutHeartBeat},
            $$self{m_actionHeartBeat},
            $m_repeatAction
        );
        $$self{m_timerHeartBeat}->start();
    }
}

sub dead_action {
    my ( $self, $p_actionDeadApp ) = @_;
    if ( defined $p_actionDeadApp ) {
        $$self{m_actionDeadApp} = $p_actionDeadApp;
    }
    return $$self{m_actionDeadApp};
}

sub _handle_dead_app {
    my ($self) = @_;
    $$self{m_appStatus} = 'dead';
    return $$self{m_actionDeadApp}->() if defined( $$self{m_actionDeadApp} );
}

sub _handle_alive_app {
    my ($self) = @_;
    $$self{m_appStatus} = 'alive';
    if ( $$self{m_timeoutHeartBeat} != 0 ) {
        $$self{m_timerHeartBeat}->restart()
          unless $$self{m_timerHeartBeat}->inactive();
        return 1;
    }
    else {
        $$self{m_timerHeartBeat}->stop()
          unless $$self{m_timerHeartBeat}->inactive();
        return 0;
    }
}

sub app_status {
    my ($self) = @_;
    return $$self{m_appStatus};
}

sub store_data {
    my ( $self, @data ) = @_;
    while (@data) {
        my $section = shift @data;
        $$self{class} = $section;
        $$self{sections}{$section} = 'send';
        my $ptr   = shift @data;
        my %parms = %$ptr;
        for my $key ( sort keys %parms ) {
            my $value = $parms{$key};
            $$self{$section}{$key} = $value;
            $$self{state_monitor} = "$section : $key" if $value eq '$state';
        }
    }
}

sub state_now {
    my ( $self, $section_name ) = @_;
    my $state_now = $self->SUPER::state_now();
    if ($section_name) {

        # default section_state_now to undef unless it actually exists
        my $section_state_now = undef;
        for my $section ( split( /\s+\|\s+/, $state_now ) ) {
            my @section_data = split( /\s+:\s+/, $section );
            my $section_ref = $section_data[0];
            next if $section_ref eq '';
            if ( $section_ref eq $section_name ) {
                if ( defined($section_state_now) ) {
                    $section_state_now .= " | $section_data[1]";
                }
                else {
                    $section_state_now = $section_data[1];
                }
            }
        }
        print "db xPL_Item:state_now: section data for $section_name is: "
          . "$section_state_now\n"
          if $main::Debug{xpl} and $section_state_now;
        $state_now = $section_state_now;
    }
    return $state_now;
}

sub current_section_names {
    my ($self)                = @_;
    my $changed               = $$self{changed};
    my $current_section_names = undef;
    if ($changed) {
        for my $section ( split( /\s+\|\s+/, $changed ) ) {
            my @section_data = split( /\s+:\s+/, $section );
            if ( defined($current_section_names) ) {
                $current_section_names .= " | $section_data[0]";
            }
            else {
                $current_section_names = $section_data[0];
            }
        }

    }
    print "db xPL_Item:current_section_names : $current_section_names\n"
      if $main::Debug{xpl};
    return $current_section_names;
}

sub tie_value_convertor {
    my ( $self, $key_name, $convertor ) = @_;
    $$self{_value_convertors}{$key_name} = $convertor
      if ( defined($key_name) && defined($convertor) );

}

sub device_monitor {
    my ( $self, $monitor_info ) = @_;
    if ($monitor_info) {
        my ( $key, $value ) = $monitor_info =~ /(\S+)\s*[:=]\s*(.+)/;
        if ( !( $value or $value =~ /^0/ ) ) {
            $value = ($key) ? $key : $monitor_info;
            $key = 'device';
        }
        $$self{_device_id}     = lc $value;
        $$self{_device_id_key} = lc $key;
    }
    if ( defined $$self{_device_id} ) {
        return (
            ( $$self{_device_id_key} ) ? $$self{_device_id_key} : 'device' )
          . $$self{_device_id};
    }
    else {
        return;
    }
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;

    # Send data, unless we are processing incoming data
    return if !( ref $set_by ) and $set_by =~ /^xpl/i;
    my @parms;

    if ( $$self{_on_set_message} ) {
        for my $class_name ( sort keys %{ $$self{_on_set_message} } ) {
            my $block;
            for my $msg_key (
                sort keys %{ $$self{_on_set_message}{$class_name} } )
            {
                my $field_value =
                  eval( $$self{_on_set_message}{$class_name}{$msg_key} );
                $block->{$msg_key} = $field_value;
            }
            push @parms, $class_name, $block;
        }
    }
    else {
        if ( $$self{state_monitor} ) {
            foreach my $state_monitor ( split( /\|/, $$self{state_monitor} ) ) {
                my ( $section, $key ) =
                  $$self{state_monitor} =~ /(\S+)\s*[:=]\s*(\S+)/;
                $$self{$section}{$key} = $state;
            }
        }
        for my $section ( sort keys %{ $$self{sections} } ) {
            next
              unless $$self{sections}{$section} eq
              'send';    # Do not echo received data
            push @parms, $section, $$self{$section};
        }
    }

    if (@parms) {

        # sending stat info about ourselves?
        if ( lc $$self{source} eq &xPL::get_xpl_mh_source_info() ) {
            $self->send_trig(@parms);
        }
        else {

            # must be cmnd info to another device addressed by address
            $self->send_cmnd(@parms);
        }
    }
}

sub state_now_msg_type {
    my ( $self, $p_msgType ) = @_;
    $$self{m_state_now_msg_type} = $p_msgType if defined($p_msgType);
    return $$self{m_state_now_msg_type};
}

# DO NOT use the following sub
# Instead, DO use either send_cmnd, send_trig or send_stat
sub send_message {
    my ( $self, $p_strTarget, @p_data ) = @_;
    $self->send_cmnd(@p_data);
}

sub send_cmnd {
    my ( $self, @p_data ) = @_;
    if ( defined $$self{_device_id} ) {
        my $classname = shift @p_data;
        my $ptr       = shift @p_data;
        my @new_data  = ();
        $ptr->{ $$self{_device_id_key} } = $$self{_device_id};
        push @new_data, $classname, $ptr;
        &xPL::sendXpl( $self->source, 'cmnd', @new_data );
    }
    else {
        &xPL::sendXpl( $self->source, 'cmnd', @p_data );
    }
}

sub send_stat {
    my ( $self, @p_data ) = @_;
    if ( defined $$self{_device_id} ) {
        my $classname = shift @p_data;
        my $ptr       = shift @p_data;
        my @new_data  = ();
        $ptr->{ $$self{_device_id_key} } = $$self{_device_id};
        push @new_data, $classname, $ptr;
        &xPL::sendXpl( '*', 'stat', @new_data );
    }
    else {
        &xPL::sendXpl( '*', 'stat', @p_data );
    }
}

sub send_trig {
    my ( $self, @p_data ) = @_;
    if ( defined $$self{_device_id} ) {
        my $classname = shift @p_data;
        my $ptr       = shift @p_data;
        my @new_data  = ();
        $ptr->{ $$self{_device_id_key} } = $$self{_device_id};
        push @new_data, $classname, $ptr;
        &xPL::sendXpl( '*', 'trig', @new_data );
    }
    else {
        &xPL::sendXpl( '*', 'trig', @p_data );
    }
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_message = 0;
    if ( $$self{_device_id_key} and $self->class_name ) {
        print
          "Device monitoring enabled: key=$$self{_device_id_key}, id=$$self{_device_id}, tested value="
          . $$p_data{ $self->class_name }{ $$self{_device_id_key} } . "\n"
          if $main::Debug{xpl};
        $ignore_message =
          ( $$self{_device_id} ne
              lc $$p_data{ $self->class_name }{ $$self{_device_id_key} } )
          ? 1
          : 0;
    }
    return $ignore_message;
}

package xPL_Sensor;

@xPL_Sensor::ISA = ('xPL_Item');

sub new {
    my ( $class, $p_source, $p_type, $p_statekey ) = @_;
    my ( $source, $deviceid ) = $p_source =~ /(\S+)?:([\S ]+)/;
    $source = $p_source unless $source;
    my $self = $class->SUPER::new($source);
    if ($p_type) {
        $$self{sensor_type} = $p_type;
        if ( $p_type eq 'output'
          ) # define a default message to be sent out on a call to the "set" method
        {
            # the following can always be overwritten
            $self->on_set_message(
                'control.basic' => { 'z##current' => '$state' } );
        }
    }
    else {
        $$self{sensor_type} = 'input';    # set a default
    }
    my $statekey = 'current';
    $statekey = $p_statekey if $p_statekey;
    $self->SUPER::class_name('sensor.basic');
    $$self{state_monitor} = "sensor.basic : $statekey";
    $self->SUPER::device_monitor("device=$deviceid") if defined $deviceid;
    return $self;
}

sub type {
    my ( $self, $p_type ) = @_;
    $$self{sensor_type} = $p_type if $p_type;
    return $$self{sensor_type};
}

sub current {
    my ($self) = @_;
    return $$self{'sensor.basic'}{current};
}

sub units {
    my ($self) = @_;
    return $$self{'sensor.basic'}{units};
}

sub lowest {
    my ($self) = @_;
    return $$self{'sensor.basic'}{lowest};
}

sub highest {
    my ($self) = @_;
    return $$self{'sensor.basic'}{highest};
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    return 1
      if $self->SUPER::ignore_message($p_data)
      ;    # user xPL_Item's filter against deviceid
    return ( $$p_data{'sensor.basic'}{type} ne $$self{sensor_type} ) ? 1 : 0;
}

sub request_stat {
    my ($self) = @_;
    $self->SUPER::send_cmnd( 'sensor.request' =>
          { 'request' => 'current', 'type' => "'$$self{sensor_type}'" } );
}

package xPL_UPS;

@xPL_UPS::ISA = ('xPL_Item');

sub new {
    my ( $class, $p_source, $p_statekey ) = @_;
    my ( $source, $deviceid ) = $p_source =~ /(\S+):(\S+)/;
    $source = $p_source unless $source;
    my $self     = $class->SUPER::new($source);
    my $statekey = $p_statekey;
    $statekey = 'status';

    #    $self->SUPER::class_name('ups.basic');
    $$self{state_monitor} = "ups.basic : $statekey|hbeat.app : $statekey";
    $self->SUPER::device_monitor("device=$deviceid") if defined $deviceid;
    return $self;
}

sub status {
    my ( $self, $p_status ) = @_;
    return ( $$self{'ups.basic'}{status} )
      ? $$self{'ups.basic'}{status}
      : $$self{'hbeat.app'}{status};
}

sub event {
    my ($self) = @_;
    return $$self{'ups.basic'}{event};
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    return 1
      if $self->SUPER::ignore_message($p_data)
      ;    # user xPL_Item's filter against deviceid
    return ( $$p_data{'ups.basic'} or $$p_data{'hbeat.app'} ) ? 0 : 1;
}

package xPL_X10Security;

@xPL_X10Security::ISA = ('xPL_Item');

sub new {
    my ( $class, $p_source, $p_type, $p_statekey ) = @_;
    my ( $source, $deviceid ) = $p_source =~ /(\S+):(\S+)/;
    $source = $p_source unless $source;
    my $self = $class->SUPER::new($source);
    $$self{type} = $p_type if $p_type;
    my $statekey = $p_statekey;
    $statekey = 'command';
    $self->SUPER::class_name('x10.security');
    $$self{state_monitor} = "x10.security : $statekey";
    $self->SUPER::device_monitor("device=$deviceid") if defined $deviceid;
    return $self;
}

sub type {
    my ( $self, $p_type ) = @_;
    $$self{type} = $p_type if $p_type;
    return $$self{type};
}

sub command {
    my ($self) = @_;
    return $$self{'x10.security'}{command};
}

sub tamper {
    my ($self) = @_;
    return $$self{'x10.security'}{tamper};
}

sub low_battery {
    my ($self) = @_;
    return $$self{'x10.security'}{'low-battery'};
}

sub delay {
    my ($self) = @_;
    return $$self{'x10.security'}{delay};
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    return 1
      if $self->SUPER::ignore_message($p_data)
      ;    # user xPL_Item's filter against deviceid
    if ( $$self{type} ) {
        return ( $$p_data{'x10.security'}{type} ne $$self{type} ) ? 1 : 0;
    }
    else {
        return 0;
    }
}

package xPL_Rio;

@xPL_Rio::ISA = ('xPL_Item');

# Support both send and receive objects
sub new {
    my ( $object_class, $xpl_source, $xpl_target ) = @_;
    my $self = {};
    bless $self, $object_class;

    $$self{state}          = '';
    $$self{source}         = $xpl_source;
    $$self{target_address} = $xpl_target unless !$xpl_target;

    &xPL_Item::store_data( $self, 'rio.basic' => { sel => '$state' } );

    @{ $$self{states} } = (
        'play',
        'stop',
        'mute',
        'volume +20',
        'volume -20',
        'volume 100',
        'skip',
        'back',
        'random',
        'power on',
        'power off',
        'light on',
        'light off'
    );

    return $self;

}

1;
