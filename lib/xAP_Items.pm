
=begin comment

xAP_Items.pm - Misterhouse interface for the xAP and xPL protocols

Info:

 xAP website:
    http://www.xapautomation.org

 xPL websites:
    http://www.xplproject.org.uk
    http://www.xaphal.com

Examples:
 See mh/code/common/test_xap.pl


Authors:
 10/26/2002  Created by Bruce Winter bruce@misterhouse.net

=cut

use strict;

package xAP;

@xAP::ISA = ('Generic_Item');

#se IO::Socket::INET;           # Gives us the INADDR constants, but not in perl 5.0 :(

my (
    @xap_item_names,    $started,             $xap_listen,
    $xap_hub_listen,    $xap_send,            %hub_ports,
    %xap_uids,          %xap_virtual_devices, $xap_hbeat_interval,
    $xap_hbeat_counter, @send_queue,          %timeouts,
    $send_queue_timeout
);
use vars '$xap_data';

# XAP_REAL_DEVICE_NAME is the default device name that appears in the last field of the primary source address
use constant XAP_REAL_DEVICE_NAME => 'core';

# Create sockets and add hook to check incoming data
sub startup {

    return
      if $started++
      ;    # Allows us to call with $Reload or with xap_module mh.ini parm

    @xap_item_names = ();
    @send_queue     = ();
    %timeouts       = {};

    # In case you don't want xap for some reason
    return if $::config_parms{xap_disable};

    my ($port);

    # init the hbeat intervals and counters
    $xap_hbeat_interval = $::config_parms{xap_hbeat_interval};
    $xap_hbeat_interval = 1 unless $xap_hbeat_interval;
    $xap_hbeat_counter  = $xap_hbeat_interval;

    if ( !( $::config_parms{xap_disable} ) ) {

        $send_queue_timeout = $::config_parms{xap_send_interval};
        $send_queue_timeout = 50 unless $send_queue_timeout;
        &_set_timeout( 'send_queue', $send_queue_timeout );

        #$last_xap_subaddress_uid = 0;
        $port = $::config_parms{xap_port};
        $port = 3639 unless $port;

        # open the sending port
        &open_port( $port, 'send', 'xap_send', 0, 1 );
        $xap_send = new Socket_Item( undef, undef, 'xap_send' );

        # and send the heartbeat

        # initialize the hub (listen) port
        if ( $::config_parms{xap_nohub} ) {
            $xap_hub_listen = undef;
        }
        else {
            if ( &open_port( $port, 'listen', 'xap_hub_listen', 0, 1 ) ) {
                $xap_hub_listen =
                  new Socket_Item( undef, undef, 'xap_hub_listen' );
                print " - mh in xAP Hub mode\n";
            }
            else {
                print
                  " - mh automatically switching out of xAP Hub mode.  Another application is binding to the hub port ($port)\n";
            }
        }

        # now that a listen port exists, advertise it w/ the first hbeat msg
        #	&xAP::send_heartbeat('xAP') if $xap_send;
        &init_xap_virtual_device(XAP_REAL_DEVICE_NAME);
    }

    &::MainLoop_pre_add_hook( \&xAP::check_for_data, 1 );

    # add exit hook so that xap-hbeat.stopped is sent
    &::Exit_add_hook( \&xAP::exit_hook, 1 );

    # add reload hook so that xap_item_names list is reset
    &::Reload_pre_add_hook( \&xAP::reload_hook, 1 );
}

sub reload_hook {
    @xap_item_names = ();
}

sub exit_hook {
    return if $main::Save{mh_exit} eq 'restart';
    for my $virtual_device_name ( keys %{xap_virtual_devices} ) {
        &send_xap_heartbeat( $xap_virtual_devices{$virtual_device_name}{port},
            $virtual_device_name, 'stopped' );
    }
}

sub init_xap_virtual_device {
    my ($virtual_device_name) = @_;

    if ( !( exists( $xap_virtual_devices{$virtual_device_name} ) ) ) {

        # grab a base UID so that it is reserved
        my $virtual_base_uid = &get_xap_base_uid($virtual_device_name);

        # Find and use the first open port
        my $port;
        for my $p ( 49152 .. 65535 ) {
            $port = $p;
            last
              if &open_port( $port, 'listen', "xap_listen_$virtual_device_name",
                1, 1 );
        }
        my $xap_socket =
          new Socket_Item( undef, undef, "xap_listen_$virtual_device_name" );
        $xap_virtual_devices{$virtual_device_name}{socket} = $xap_socket;
        $xap_virtual_devices{$virtual_device_name}{port}   = $port;

        # initialize the hub responder port if mh implements a hub
        if ( !( $::config_parms{xap_nohub} ) ) {

            # now set up the hub port that will send to mh
            $hub_ports{$port} =
              &xAP::get_xap_mh_source_info($virtual_device_name);
            my $port_name = "xap_send_$port";
            &open_port( $port, 'send', $port_name, 1, 1 );
        }

        # now that a listen port exists, advertise it w/ the first hbeat msg
        if ($xap_send) {
            &send_xap_heartbeat( $port, $virtual_device_name, 'alive' );
        }
    }

}

sub main::display_xap {
    my (%args) = @_;
    my $schema = lc ${args}{schema};
    $schema = 'message.display' unless $schema;
    if ( $schema eq 'message.display' ) {
        &main::display_xap_message_display(%args);
    }
    else {
        &main::print_log(
            "Display support for the schema, $schema, does not yet exist");
    }

}

sub main::display_xap_message_display {
    my (%args) = @_;
    my ( $mapped_priority, $priority, $duration, $address );
    my ( $text, $text_block, @xap_data );
    if ( exists( $args{line1} ) ) {
        $text = $args{line1};
    }
    else {
        $text = ( $args{raw_text} ) ? $args{raw_text} : $args{text};
    }
    $text =~ s/[\n\r ]+/ /gm;    # strip out new lines and extra space
    $text =~ s/^\\n//m;          # strip out leading new line
    $text_block->{line1} = $text;
    $text_block->{line2} = $args{line2} if $args{line2};
    $duration            = $args{duration};
    $duration            = $args{display}
      unless $duration;          # this apparently is the original param?
    $duration = 10 unless $duration;    # default to 10 sec display
    $text_block->{duration} = $duration;
    $priority = $args{priority};
    $priority = 9 unless $priority;

    if ( lc $priority eq 'high' ) {
        $mapped_priority = 1;
    }
    elsif ( lc $priority eq 'medium' ) {
        $mapped_priority = 5;
    }
    else {
        $mapped_priority = 9;
    }
    $text_block->{priority} = $mapped_priority;
    push @xap_data, 'Display.Text', $text_block;

    if ( $args{pic_url} or $args{pic_refresh} or $args{link_url} ) {
        my $web_block;
        $web_block->{pic}     = $args{pic_url}     if $args{pic_url};
        $web_block->{refresh} = $args{pic_refresh} if $args{pic_refresh};
        $web_block->{url}     = $args{link_url}    if $args{link_url};
        push @xap_data, 'display.web', $web_block;
    }

    $address = $args{to};
    $address = $args{address} unless $address;
    $address = '*' unless $address;
    &xAP::sendXap( $address, 'message.display', @xap_data );
}

sub main::display_xap_osd_display_tivo {
    my (%args) = @_;
    my ( $priority, $mapped_priority, $duration, $address );
    my ( $text_block, @xap_data );
    my $text = ( $args{raw_text} ) ? $args{raw_text} : $args{text};
    $text =~ s/[\n\r ]+/ /gm;    # strip out new lines and extra space
    $text_block->{text} = $duration = $args{duration};
    $duration = $args{display}
      unless $duration;          # this apparently is the original param?
    $duration = 10 unless $duration;    # default to 10 sec display
    $text_block->{duration} = $duration;
    $priority = $args{priority};
    $priority = 'low' unless $priority;
    $text_block->{priority}   = $priority;
    $text_block->{row}        = $args{row} if exists( $args{row} );
    $text_block->{column}     = $args{column} if exists( $args{column} );
    $text_block->{foreground} = $args{foreground}
      if exists( $args{foreground} );
    $text_block->{background} = $args{background}
      if exists( $args{background} );

    push @xap_data, 'display.tivo', $text_block;

    $address = $args{to};
    $address = $args{address} unless $address;
    $address = '*' unless $address;
    &xAP::sendXap( $address, 'xap-osd.display', @xap_data );
}

sub main::display_xap_osd_display_slimp3 {
    my (%args) = @_;
    my ( $priority, $duration,   $address );
    my ( $text,     $text_block, @xap_data );
    if ( exists( $args{line1} ) ) {
        $text = $args{line1};
    }
    else {
        $text = ( $args{raw_text} ) ? $args{raw_text} : $args{text};
    }
    $text =~ s/[\n\r ]+/ /gm;    # strip out new lines and extra space
    $text =~ s/^\\n//m;          # strip out leading new line
    $text_block->{line1} = $text;
    $text_block->{line2} = $args{line2} if $args{line2};
    $duration            = $args{duration};
    $duration            = $args{display}
      unless $duration;          # this apparently is the original param?
    $duration = 10 unless $duration;    # default to 10 sec display
    $text_block->{duration} = $duration;
    $text_block->{align1}   = $args{align1} if exists( $args{align1} );
    $text_block->{align2}   = $args{align2} if exists( $args{align2} );
    push @xap_data, 'display.slimp3', $text_block;

    $address = $args{to};
    $address = $args{address} unless $address;
    $address = '*' unless $address;
    &xAP::sendXap( $address, 'xap-osd.display', @xap_data );
}

sub open_port {
    my ( $port, $send_listen, $port_name, $local, $verbose ) = @_;

    # Need to re-open the port, if client app has been re-started??
    close $::Socket_Ports{$port_name}{sock}
      if $::Socket_Ports{$port_name}{sock};

    #   return 0 if $::Socket_Ports{$port_name}{sock};  # Already open

    my $sock;
    if ( $send_listen eq 'send' ) {
        my $dest_address;

        #       $dest_address = inet_ntoa(INADDR_BROADCAST);
        $dest_address = $::config_parms{'ipaddress_xap_broadcast'}
          if $port_name =~ /^xap/i;
        $dest_address = '255.255.255.255' unless $dest_address;
        if ($local) {
            $dest_address = 'localhost';
        }
        $sock = new IO::Socket::INET->new(
            PeerPort  => $port,
            Proto     => 'udp',
            PeerAddr  => $dest_address,
            Broadcast => 1
        );
    }
    else {
        my $listen_address = $::config_parms{'ipaddress_xap'};
        if ($main::OS_win) {
            $listen_address = $::Info{IPAddress_local} unless $listen_address;
        }
        else {
            # can't get *nix to bind to a specific address; defaults to kernel assigned default IP
            $listen_address = '0.0.0.0';
        }
        $listen_address = 'localhost' if $local;
        $sock = new IO::Socket::INET->new(
            LocalPort => $port,
            Proto     => 'udp',
            LocalAddr => $listen_address,
            Broadcast => 1
        );

        #                                          LocalAddr => '0.0.0.0', Broadcast => 1);
        #                                         LocalAddr => inet_ntoa(INADDR_ANY), Broadcast => 1);
    }
    unless ($sock) {
        print "\nError:  Could not start a udp xAP send server on $port: $@\n\n"
          if $send_listen eq 'send';
        return 0;
    }

    printf " - creating %-15s on %3s %5s %s\n", $port_name, 'udp', $port,
      $send_listen
      if $verbose;

    print "db xAP_Items open_port: p=$port pn=$port_name l=$local s=$sock\n"
      if $main::Debug{xap};

    $::Socket_Ports{$port_name}{protocol} = 'udp';
    $::Socket_Ports{$port_name}{datatype} = 'raw';
    $::Socket_Ports{$port_name}{port}     = $port;
    $::Socket_Ports{$port_name}{sock}     = $sock;
    $::Socket_Ports{$port_name}{socka} = $sock;  # UDP ports are always "active"

    return $sock;
}

sub check_for_data {

    if ( $xap_hub_listen && ( my $xap_hub_data = said $xap_hub_listen) ) {
        &_process_incoming_xap_hub_data($xap_hub_data);
    }

    for my $virtual_device_name ( keys %{xap_virtual_devices} ) {
        my $is_real_device = ( $virtual_device_name eq XAP_REAL_DEVICE_NAME );
        my $xap_socket     = $xap_virtual_devices{$virtual_device_name}{socket};
        if ( $xap_socket && ( my $xap_data = said $xap_socket) ) {
            &_process_incoming_xap_data( $xap_data, $virtual_device_name );
        }
    }

    # check to see if hbeats need to be sent
    if ($::New_Minute) {
        if ($xap_send) {
            if ( $xap_hbeat_counter == 1 ) {
                for my $virtual_device_name ( keys %{xap_virtual_devices} ) {
                    &send_xap_heartbeat(
                        $xap_virtual_devices{$virtual_device_name}{port},
                        $virtual_device_name, 'alive' );
                }
                $xap_hbeat_counter = $xap_hbeat_interval;
            }
            else {
                $xap_hbeat_counter = $xap_hbeat_counter - 1;
            }
        }
    }

    # check to see if any xAP message need to be sent
    if ( &_check_timeout('send_queue') == 1 ) {
        my $message_count = @send_queue;
        if ( $xap_send && $message_count ) {

            # check to see if the socket is still valid
            my $msg = shift @send_queue;
            if ( !( $::Socket_Ports{'xap_send'}{socka} ) ) {
                &xAP::_handleStaleXapSockets();
            }
            $xap_send->set($msg) if $::Socket_Ports{'xap_send'}{socka};
        }
        &_set_timeout( 'send_queue', $send_queue_timeout );
    }
}

# Parse incoming xAP records
sub parse_data {
    my ($data) = @_;
    my ( $data_type, %d );
    print "db4 xap data:\n$data\n"
      if $main::Debug{xap} and $main::Debug{xap} == 4;
    for my $r ( split /[\r\n]/, $data ) {
        next if $r =~ /^[\{\} ]*$/;

        # Store xap-header, xap-heartbeat, and other data
        if ( my ( $key, $value ) = $r =~ /(.+?)=(.*)/ ) {
            $key   = lc $key;
            $value = lc $value
              if ( $data_type =~ /^xap/ );    # Do not lc real data;
            $d{$data_type}{$key} = $value;
            print "db4 xap/xpl parsed c=$data_type k=$key v=$value\n"
              if ( $main::Debug{xap} and $main::Debug{xap} == 4 );
        }

        # data_type (e.g. xap-header, xap-heartbeat, source.instance
        else {
            $data_type = lc $r;
        }
    }

    # the following is a "hack" to allow unorthodox structures like xAP BSC's query
    if ( !( exists( $d{$data_type} ) ) ) {
        $d{$data_type}{'_dummy'} = 1;
    }
    return \%d;
}

sub _process_incoming_xap_hub_data {
    my ($data) = @_;
    my $ip_address = $::config_parms{'ipaddress_xap'};
    $ip_address = $::Info{IPAddress_local} unless $ip_address;

    undef $xap_data;
    $xap_data = &parse_data($data);

    my ( $protocol, $source, $class, $target );
    if ( $$xap_data{'xap-header'} or $$xap_data{'xap-hbeat'} ) {
        $protocol = 'xAP';
        $source   = $$xap_data{'xap-header'}{source};
        $class    = $$xap_data{'xap-header'}{class};
        $target   = $$xap_data{'xap-header'}{target};
        $source   = $$xap_data{'xap-hbeat'}{source} unless $source;
        $class    = $$xap_data{'xap-hbeat'}{class} unless $class;
        $target   = $$xap_data{'xap-hbeat'}{target} unless $target;
    }

    return unless $source;

    my ($port);

    # As a hub, echo data to other listeners
    for $port ( keys %hub_ports ) {

        # don't echo back the sender's own data
        #       if ($hub_ports{$port} ne $source) {
        if (   !( $source =~ /^$hub_ports{$port}/ )
            or $::config_parms{'xap_hub_echo'}
            or $main::Debug{xap} )
        {
            my $sock = $::Socket_Ports{"xap_send_$port"}{sock};
            print
              "db2 xap hub: sending $protocol data to p=$port s=$sock d=\n$data.\n"
              if $main::Debug{xap} and $main::Debug{xap} == 2;
            print $sock $data if defined($sock);
        }
    }

    # Log hearbeats of other apps
    if ( $$xap_data{'xap-hbeat'} ) {
        my $sender_iaddr      = $::Socket_Ports{'xap_hub_listen'}{from_ip};
        my $sender_ip_address = Socket::inet_ntoa($sender_iaddr)
          if $sender_iaddr;

        # Open/re-open the port on every hbeat if it posts a listening port.
        # Skip if it is our own transmitted msg (port = listen port)
        if ( $sender_ip_address eq $ip_address ) {
            $port = $$xap_data{'xap-hbeat'}{port};
            if ($port) {
                $hub_ports{$port} = $source;
                my $port_name = "xap_send_$port";
                my $msg =
                  ( $::Socket_Ports{$port_name}{sock} )
                  ? 'renewing'
                  : 'registering';
                print "$protocol $msg port=$port to xAP client $source"
                  if $main::Debug{xap};

                # xAP apps want local
                &open_port( $port, 'send', $port_name, 1,
                    $msg eq 'registering' );
            }
        }
    }
}

sub _process_incoming_xap_data {
    my ( $data, $device_name ) = @_;
    undef $xap_data;
    $xap_data = &parse_data($data);

    my ( $protocol, $source, $class, $target );
    if ( $$xap_data{'xap-header'} or $$xap_data{'xap-hbeat'} ) {
        $protocol = 'xAP';
        $source   = $$xap_data{'xap-header'}{source};
        $class    = $$xap_data{'xap-header'}{class};
        $target   = $$xap_data{'xap-header'}{target};
        $source   = $$xap_data{'xap-hbeat'}{source} unless $source;
        $class    = $$xap_data{'xap-hbeat'}{class} unless $class;
        $target   = $$xap_data{'xap-hbeat'}{target} unless $target;
    }
    print "db1 xap check: p=$protocol s=$source c=$class t=$target d=$data\n"
      if $main::Debug{xap} and $main::Debug{xap} == 1;

    # the first time that this sub is called, the xap_item_names array needs to be filled
    if ( !(@xap_item_names) ) {
        foreach my $object_type (&::list_object_types) {
            foreach my $object_name ( &::list_objects_by_type($object_type) ) {
                my $object = &::get_object_by_name("$object_name");
                $object = $object_name unless $object;
                if ( $object and $object->isa('xAP_Item') ) {
                    push @xap_item_names, $object_name;
                }
            }
        }
    }

    return unless $source;

    # set target as a wildcard if unspecified
    $target = '*' if !($target);

    # continue processing if mh is not the source (e.g., heat-beats)
    if ( !( $source eq &xAP::get_xap_mh_source_info() ) ) {

        # Set states in matching xAP objects
        for my $name (@xap_item_names) { #&::list_objects_by_type('xAP_Item')) {
            my $o = &main::get_object_by_name($name);
            $o = $name
              unless $o
              ;  # In case we stored object directly (e.g. lib/Telephony_xAP.pm)

            # don't continue processing object if it's not bound to the device
            next unless $o->device_name() eq $device_name;

            print
              "db3 xap test  o=$name s=$source os=$$o{source} c=$class oc=$$o{class} \n"
              if $main::Debug{xap} and $main::Debug{xap} == 3;
            my $regex_source = &wildcard_2_regex( $$o{source} );
            next unless $source =~ /^$regex_source$/i;

            # is current xap object a virtual device?
            my $objectIsVirtual = 0;

            # if so, is the source also from a virtual device?
            my $senderIsVirtual = 0;
            for my $virtual_device_name ( keys %{xap_virtual_devices} ) {
                if ( $virtual_device_name eq $o->device_name() ) {
                    $objectIsVirtual = 1;
                }
                if (    ( $source =~ /$virtual_device_name/ )
                    and ( $virtual_device_name ne XAP_REAL_DEVICE_NAME ) )
                {
                    $senderIsVirtual = 1;
                }
            }

            # don't continue if the sender and object are both virtual xap devices
            next if ($objectIsVirtual) and ($senderIsVirtual);

            # handle target wildcarding if it applies
            if ( $$o{target_address} ) {
                my $regex_ref_target = &wildcard_2_regex( $$o{target_address} );
                my $regex_target     = &wildcard_2_regex($target);

                next
                  unless ( $target =~ /^$regex_ref_target$/ )
                  or ( $$o{target_address} =~ /^$regex_target$/ );
            }

            # check/handle hbeats
            for my $section ( keys %{$xap_data} ) {
                if ( lc $class eq 'xap-hbeat' ) {
                    if ( lc $class eq 'xap-hbeat.alive' ) {
                        my $uid = $$xap_data{'xap-hbeat'}{uid};
                        $o->uid($uid) if $uid;
                        $o->_handle_alive_app();
                    }
                    else {
                        $o->_handle_dead_app();
                    }
                }
            }
            my $regex_class = &wildcard_2_regex( $$o{class} );
            next unless $class =~ /^$regex_class$/i;

            # Find and set the state variable
            my $state_value;
            $$o{changed} = '';
            for my $section ( keys %{$xap_data} ) {
                $$o{sections}{$section} = 'received'
                  unless $$o{sections}{$section};
                for my $key ( keys %{ $$xap_data{$section} } ) {
                    my $value = $$xap_data{$section}{$key};

                    # does a tied value convertor exist for this key and object?
                    my $value_convertor = $$o{_value_convertors}{$key}
                      if defined( $$o{_value_convertors} );
                    if ($value_convertor) {
                        print
                          "db xap: located value convertor: $value_convertor\n"
                          if $main::Debug{xap};
                        my $converted_value = eval $value_convertor;
                        if ($@) {
                            print $@;
                        }
                        else {
                            print
                              "db xap: converted value is: $converted_value\n"
                              if $main::Debug{xap};
                        }
                        $value = $converted_value if $converted_value;
                    }
                    $$o{$section}{$key} = $value;

                    # Monitor what changed (real data, not hbeat).
                    $$o{changed} .= "$section : $key = $value | "
                      unless $section eq 'xap-header'
                      ; # or ($section eq 'xap-hbeat' and !($$o{class} =~ /^xap-hbeat/i));
                    print
                      "db3 xap state check m=$$o{state_monitor} key=$section : $key  value=$value\n"
                      if $main::Debug{xap} and $main::Debug{xap} == 3;
                    if (    $$o{state_monitor}
                        and $$o{state_monitor} =~ /$section\s*[:=]\s*$key/i
                        and defined $value )
                    {
                        print "db3 xap setting state to $value\n"
                          if $main::Debug{xap} and $main::Debug{xap} == 3;
                        $state_value = $value;
                    }
                }
                if ( $$o{changed} eq '' && $section ne 'xap-header' ) {
                    $$o{changed} .= "$section";
                }
            }

            $state_value = $$o{changed} unless $$o{state_monitor};
            print "db3 xap set: n=$name to state=$state_value\n\n"
              if $main::Debug{xap} and $main::Debug{xap} == 3;

            #	       $$o{state} = $$o{state_now} = $$o{said} == $state_value if defined $state_value;
            # Can not use Generic_Item set method, as state_next_path only carries state, not all other $section data, to the next pass
            #              $o -> SUPER::set($state_value, 'xAP') if defined $state_value;
            my $set_by_name = 'xAP';
            $set_by_name .= " [$source]"
              ;   # no longer needed: if ($::config_parms{'xap_use_to_target'});
            $o->SUPER::set_now( $state_value, $set_by_name )
              if $o->allow_empty_state()
              or ( defined $state_value and $state_value ne '' );
        }
    }
}

sub get_xap_uid {
    my ( $device_type, $subaddress_name ) = @_;
    my $uid = &get_xap_base_uid($device_type)
      . &get_xap_subaddress_uid( $device_type, $subaddress_name );
    return $uid;
}

sub get_xap_subaddress_uid {
    my ( $p_type_name, $subaddress_name, $requested_uid ) = @_;
    my $subaddress_uid = "00";
    if ($subaddress_name) {
        if ( exists( $xap_uids{$p_type_name} )
            && exists(
                $xap_uids{$p_type_name}{'sub-fwd-map'}{$subaddress_name} ) )
        {
            $subaddress_uid =
              $xap_uids{$p_type_name}{'sub-fwd-map'}{$subaddress_name};
        }
        else {
            # did we get a $requested_uid?
            if ( $requested_uid && ( length($requested_uid) == 2 ) )
            {    # not a very robust validation
                    # try to honor the request
                if (
                    !(
                        exists(
                            $xap_uids{$p_type_name}{'sub-rvs-map'}
                              {$requested_uid}
                        )
                    )
                  )
                {
                    $subaddress_uid = $requested_uid;
                }
            }
            if ( !($requested_uid) || $subaddress_uid eq '00' ) {
                my $last_xap_subaddress_uid =
                  $xap_uids{$p_type_name}{'last_sub_uid'};
                $last_xap_subaddress_uid = 0 unless $last_xap_subaddress_uid;
                $last_xap_subaddress_uid++;

                # store it
                $xap_uids{$p_type_name}{'last_sub_uid'} =
                  $last_xap_subaddress_uid;

                #convert to hex
                $subaddress_uid = sprintf( "%X", $last_xap_subaddress_uid );
                if ( length($subaddress_uid) % 2 ) {
                    $subaddress_uid =
                      "0$subaddress_uid"; # pad w/ a 0 if number of chars is odd
                }
            }

            #and, store it in the hash
            $xap_uids{$p_type_name}{'sub-fwd-map'}{$subaddress_name} =
              $subaddress_uid;

            # as well as the reverse map
            $xap_uids{$p_type_name}{'sub-rvs-map'}{$subaddress_uid} =
              $subaddress_name;
        }
    }
    return $subaddress_uid;
}

sub get_xap_subaddress_devname {
    my ( $p_type_name, $p_subaddress_uid ) = @_;
    my $devname = '';
    if ( exists( $xap_uids{$p_type_name}{'sub-rvs-map'}{$p_subaddress_uid} ) ) {
        $devname = $xap_uids{$p_type_name}{'sub-rvs-map'}{$p_subaddress_uid};
    }
    return $devname;
}

sub get_xap_base_uid {
    my ($p_type_name) = @_;
    if (  !( defined($p_type_name) )
        || ( $p_type_name eq XAP_REAL_DEVICE_NAME ) )
    {
        $p_type_name = XAP_REAL_DEVICE_NAME;
        if (   exists( $xap_uids{$p_type_name} )
            && exists( $xap_uids{$p_type_name}{'base'} ) )
        {
            return $xap_uids{$p_type_name}{'base'};
        }
        else {
            # allow an override via the xap_uid
            # note: this should always be overridden to deconflict when multiple
            #   mh instances are running
            my $uid = $::config_parms{xap_uid};

            # all uids must start with FF
            if ( defined($uid) and ( $uid =~ /^FF/ ) ) {
                if ( length($uid) > 6 ) {

                    # get the first 6 digits
                    $uid = substr( $uid, 0, 6 );
                }
                elsif ( length($uid) == 6 ) {

                    # do nothing
                }
                else {
                    # set to something likely not conflict; FF123400 is too common
                    $uid = 'FFE900';
                }
            }
            else {
                $uid = 'FFE900';
            }

            # store it
            $xap_uids{$p_type_name}{'base'} = $uid;

            # convert and save it
            $xap_uids{'last_base_uid'} = hex($uid);
            return $uid;
        }
    }
    else {
        if ( exists( $xap_uids{$p_type_name} ) ) {
            return $xap_uids{$p_type_name}{'base'};
        }
        else {
            # get the last base uid and convert hex string to number
            my $uid = &get_xap_base_uid(XAP_REAL_DEVICE_NAME)
              ;    # make sure it's initialized
            $uid = $xap_uids{'last_base_uid'};
            my $uid_num = $uid;

            # increment number and convert back to hex string
            $uid_num                   = $uid_num + 1;
            $uid                       = sprintf( "%X", $uid_num );
            $xap_uids{'last_base_uid'} = $uid_num;
            if ( length($uid) % 2 ) {
                $uid = "0$uid";    # pad w/ a 0 if an odd number of chars
            }
            $xap_uids{$p_type_name}{'base'} = $uid;
            return $uid;
        }
    }
}

sub get_mh_vendor_info {
    return 'mhouse';
}

sub get_mh_device_info {
    return 'mh';
}

sub get_xap_mh_source_info {
    my ($instance) = @_;
    $instance = XAP_REAL_DEVICE_NAME if !($instance);
    $instance = &get_ok_name_part($instance);
    my $device = $::config_parms{xap_title};
    $device = $::config_parms{title} unless $device;
    $device = ( $device =~ /misterhouse(.*)pid/i ) ? 'misterhouse' : $device;
    $device = &xAP::get_ok_name_part($device);
    return
        &get_mh_vendor_info() . '.'
      . &get_mh_device_info() . '.'
      . $device . '.'
      . $instance;
}

sub get_ok_name_part {
    my ($in_name) = @_;
    my $out_name = lc $in_name;
    $out_name =~ tr/ /_/;
    $out_name =~ s/[^a-z0-9\-_]//g;
    return $out_name;
}

sub is_target {
    my ( $target, $source ) = @_;
    return (
        ( !( $source eq &xAP::get_xap_mh_source_info() ) ) && ( ( !($target) )
            || $target eq '*'
            || $target eq ( &get_mh_vendor_info() . '.*' )
            || $target eq
            ( &get_mh_vendor_info() . '.' & get_mh_device_info() . '.*' )
            || $target eq &xAP::get_xap_mh_source_info() )
    );

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

sub received_data {
    my ($protocol) = @_;
    return $xap_data;
}

sub send {
    my ( $protocol, $class_address, @data ) = @_;

    #    print "db5 $protocol send: ca=$class_address d=@data xap_send=$xap_send\n" if ($main::Debug{xap} and $main::Debug{xap} == 5) or ($main::Debug{xpl} and $main::Debug{xpl} == 5);

    my $target = '*';
    my @data2
      ;    # this will hold the "stripped" data after looking for a target arg
    while (@data) {
        my $section = shift @data;
        if ( lc $section eq 'xap_target' ) {
            $target = shift @data;
        }
        else {
            push @data2, $section, shift @data;
        }
    }
    &sendXap( $target, $class_address, @data2 );
}

sub sendXap {
    if ( defined($xap_send) ) {
        my ( $target, $class_name, @data ) = @_;
        my ( $headerVars, @data2 );
        $headerVars->{'class'} = $class_name;
        undef $target if $::config_parms{xap_disable_target};
        $headerVars->{'target'} = $target if defined $target;
        push @data2, $headerVars;
        while (@data) {
            my $section = shift @data;
            push @data2, $section, shift @data;
        }
        &sendXapWithHeaderVars(@data2);
    }
    else {
        print
          "WARNING! xAP is disabled and you are trying to send xAP data!! (xAP::sendXap())\n";
    }
}

sub sendXapWithHeaderVars {
    if ( defined($xap_send) ) {
        my (@data) = @_;
        my ( $parms, $msg, $headerVarsPtr, %headerVars );

        $headerVarsPtr = shift @data;
        %headerVars    = %$headerVarsPtr;
        $msg           = "xap-header\n{\n";
        $msg .= "v=12\n";
        $msg .= "hop=1\n";
        if ( exists( $headerVars{'uid'} ) ) {
            $msg .= "uid=" . $headerVars{'uid'} . "\n";
        }
        else {
            $msg .= "uid=" . &get_xap_uid() . "\n";
        }
        if ( exists( $headerVars{'source'} ) ) {
            $msg .= "source=" . $headerVars{'source'} . "\n";
        }
        else {
            $msg .= "source=" . &xAP::get_xap_mh_source_info() . "\n";
        }
        $msg .= "class=" . $headerVars{'class'} . "\n";
        if ( exists( $headerVars{'target'} )
            && ( $headerVars{'target'} ne '*' ) )
        {
            $msg .= "target=" . $headerVars{'target'} . "\n";
        }
        $msg .= "}\n";
        while (@data) {
            my $section = shift @data;
            $msg .= "$section\n{\n";
            my $ptr = shift @data;
            if ($ptr) {
                my %parms = %$ptr;
                for my $key ( keys %parms ) {
                    $msg .= "$key=$parms{$key}\n";
                }
            }
            $msg .= "}\n";
        }
        print "db5 xap msg: $msg"
          if $main::Debug{xap} and $main::Debug{xap} == 5;

        #       if ($xap_send) {
        # check to see if the socket is still valid
        #           if (!($::Socket_Ports{'xap_send'}{socka})) {
        #               &xAP::_handleStaleXapSockets();
        #           }
        #           $xap_send->set($msg) if $::Socket_Ports{'xap_send'}{socka};
        #       }
        push @send_queue, $msg;

    }
    else {
        print
          "WARNING! xAP is disabled and you are trying to send xAP data!! (xAP::sendXapWIthHeaderVars())\n";
    }
}

sub send_xap_heartbeat {
    my ( $port, $base_ref, $hbeat_type ) = @_;
    if ($xap_send) {
        $base_ref   = "core"  if !($base_ref);
        $hbeat_type = "alive" if !($hbeat_type);

        my $xap_hbeat_interval_in_secs = $xap_hbeat_interval * 60;
        my $xap_version                = '12';
        my $msg = "xap-hbeat\n{\nv=$xap_version\nhop=1\n";
        $msg .= "uid=" . &get_xap_base_uid($base_ref) . "00" . "\n";
        $msg .= "class=xap-hbeat.$hbeat_type\n";
        $msg .= "source=" . &xAP::get_xap_mh_source_info($base_ref) . "\n";
        $msg .= "interval=$xap_hbeat_interval_in_secs\nport=$port\npid=$$\n}\n";

        # check to see if all of the sockets are still valid
        #      &xAP::_handleStaleXapSockets();
        #      $xap_send->set($msg) if $::Socket_Ports{'xap_send'}{socka};
        push @send_queue, $msg;
        print "db6 xap heartbeat: $msg.\n"
          if $main::Debug{xap} and $main::Debug{xap} == 6;
    }
}

#################################
### INTERNAL METHODS/FUNCTION ###
#################################

sub _set_timeout {
    my ( $timeout_name, $timeout_in_millis ) = @_;
    my $tickcount = &main::get_tickcount + $timeout_in_millis;
    $tickcount += 2**32
      if $tickcount < 0;    # force a wrap; to be handleded by check timeout
    $timeouts{$timeout_name} = $tickcount;
}

sub _check_timeout {
    my ($timeout_name) = @_;
    return 0  unless $timeout_name;
    return -1 unless defined $timeouts{$timeout_name};
    my $current_tickcount = &main::get_tickcount;
    return 0
      if (  ( $current_tickcount >= 2**16 )
        and ( $timeouts{$timeout_name} < 2**16 ) );
    return ( $current_tickcount > $timeouts{$timeout_name} ) ? 1 : 0;
}

sub _clear_timeout {
    my ($timeout_name) = @_;
    $timeouts{$timeout_name} = undef;
}

sub _handleStaleXapSockets {

    # check main sending socket
    my $port_name = 'xap_send';
    if ( !( $::Socket_Ports{$port_name}{socka} ) ) {
        if (
            &xAP::open_port(
                $::Socket_Ports{$port_name}{port},
                'send', $port_name, 0, 1
            )
          )
        {
            print
              "Notice. xAP socket ($port_name) had been closed and has been reopened\n";
        }
        else {
            print
              "WARNING! xAP socket ($port_name) had been closed and can not be reopened\n";
        }
    }

    # check each primary listening socket
    for my $virtual_device_name ( keys %{xap_virtual_devices} ) {
        $port_name = "xap_listen_$virtual_device_name";
        if ( !( $::Socket_Ports{$port_name}{socka} ) ) {
            if (
                &xAP::open_port(
                    $::Socket_Ports{$port_name}{port},
                    'listen', $port_name, 0, 1
                )
              )
            {
                print
                  "Notice. xAP socket ($port_name) had been closed and has been reopened\n";
            }
            else {
                print
                  "WARNING! xAP socket ($port_name) had been closed and can not be reopened\n";
            }
        }
    }

    # check the hub listening socket if hub mode is enabled
    if ( !( $::config_parms{xap_nohub} ) ) {
        $port_name = 'xap_hub_listen';
        if ( !( $::Socket_Ports{$port_name}{socka} ) ) {
            if (
                &xAP::open_port(
                    $::Socket_Ports{$port_name}{port},
                    'listen', $port_name, 0, 1
                )
              )
            {
                print
                  "Notice. xAP socket ($port_name) had been closed and has been reopened\n";
            }
            else {
                print
                  "WARNING! xAP socket ($port_name) had been closed and can not be reopened\n";
            }
        }

        # no need to check each hub "responder" socket as it is automatically reopened on receipt
        # of client's heartbeat
    }
}

package xAP_Item;

=begin comment

   IMPORTANT: Mark uses of following methods if for init purposes w/ # noloop.  Sample use follows:

   $mySqueezebox = new xPL_Item('slimdev-slimserv.squeezebox');
   $mySqueezebox->manage_heartbeat_timeout(360, "speak 'Squeezebox is not reporting'",1); # noloop

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

      e.g., $xap_obj->tie_value_convertor('temp','$main::convert_c_to_f_degrees($value');
      note: the reference to '$main::' allows access to the user code sub - convert_c_to_f_degrees

   class_name(class_name): Sets/Gets the classname.  Classname is actually the <classname>.<typename>
      for xAP and xPL.  It is also often referred to as the schema name.  Used to filter
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

   send_message(target, data).  Sends xAP message to target using data hash.

=cut

@xAP_Item::ISA = ('Generic_Item');

# Support both send and receive objects
sub new {
    my ( $object_class, $xap_class, $xap_source, @data ) = @_;
    my $self = {};
    bless $self, $object_class;

    $xap_class  = '*' if !$xap_class;
    $xap_source = '*' if !$xap_source;
    $$self{state}              = '';
    $$self{class}              = $xap_class;
    $$self{source}             = $xap_source;
    $$self{protocol}           = 'xAP';
    $$self{target_address}     = '*';
    $$self{m_timeoutHeartBeat} = 0;             # don't monitor heart beats
    $$self{m_appStatus}        = 'unknown';
    $$self{m_timerHeartBeat}   = new Timer();
    $$self{m_device_name}       = xAP::XAP_REAL_DEVICE_NAME;
    $$self{m_allow_empty_state} = 0;
    &store_data( $self, @data );

    $self->state_overload('off')
      ;    # By default, do not process ~;: strings as substate/multistate

    return $self;
}

sub class_name {

    my ( $self, $p_strClassName ) = @_;
    $$self{class} = $p_strClassName if defined $p_strClassName;
    return $$self{class};
}

sub source {

    my ( $self, $p_strSource ) = @_;
    $$self{source} = $p_strSource if defined $p_strSource;
    return $$self{source};
}

sub target_address {
    my ( $self, $p_strTarget ) = @_;
    $$self{target_address} = $p_strTarget if defined $p_strTarget;
    return $$self{target_address};
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

sub uid {
    my ( $self, $p_uid ) = @_;
    $$self{m_uid} = $p_uid if $p_uid;
    return $$self{m_uid};
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
    $$self{m_app_Status} = 'dead';
    if ( defined $p_actionDeadApp ) {
        $$self{m_actionDeadApp} = $p_actionDeadApp;
    }
    return $$self{m_actionDeadApp};
}

sub _handle_dead_app {
    my ($self) = @_;
    return eval $$self{m_actionDeadApp} if defined( $$self{m_actionDeadApp} );
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

sub send_message {
    my ( $self, $p_strTarget, @p_strData ) = @_;
    my ( $m_strClassName, $m_strTarget );
    $m_strTarget = $p_strTarget  if defined $p_strTarget;
    $m_strTarget = $$self{class} if !$p_strTarget;
    $m_strClassName = $$self{class};
    $m_strClassName = '*' if !$m_strClassName;
    &xAP::sendXap( $m_strTarget, $m_strClassName, @p_strData );
}

sub store_data {
    my ( $self, @data ) = @_;
    while (@data) {
        my $section = shift @data;
        if ( $$self{protocol} eq 'xPL' ) {
            $$self{class} = $section;
        }
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

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;

    # Send data, unless we are processing incoming data
    return if $set_by =~ /^xap/i;

    my ( $section, $key ) = $$self{state_monitor} =~ /(\S+)\s*[:=]\s*(\S+)/;
    $$self{$section}{$key} = $state;

    my @parms;
    for my $section ( sort keys %{ $$self{sections} } ) {
        next
          unless $$self{sections}{$section} eq
          'send';    # Do not echo received data
        push @parms, $section, $$self{$section};
    }

    # sending stat info about ourselves?
    if ( lc $$self{source} eq &xAP::get_xap_mh_source_info() ) {
        &xAP::sendXap( '*', $$self{class}, @parms );
    }
    else {
        # must be cmnd info to another device addressed by source
        &xAP::sendXap( $$self{source}, $$self{class}, @parms );
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
        print
          "db xAP_Item:state_now: section data for $section_name is: $section_state_now\n"
          if $main::Debug{xap} and $section_state_now;
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
    print "db xAP_Item:current_section_names : $current_section_names\n"
      if $main::Debug{xap};
    return $current_section_names;
}

sub tie_value_convertor {
    my ( $self, $key_name, $convertor ) = @_;
    $$self{_value_convertors}{$key_name} = $convertor
      if ( defined($key_name) && defined($convertor) );

}

1;
