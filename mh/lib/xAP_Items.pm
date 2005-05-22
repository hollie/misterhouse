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

my ($started, $xap_listen, $xap_send, $hub_flag, %hub_ports, $xpl_listen, $xpl_send, $xpl_hub_flag, %xpl_hub_ports);
use vars '$xap_data','$xpl_data';

                                # Create sockets and add hook to check incoming data
sub startup {
    return if $started++;       # Allows us to call with $Reload or with xap_module mh.ini parm

                                # In case you don't want xap for some reason
    return if $::config_parms{xap_disable} and $::config_parms{xpl_disable};

    my ($port);

    if (!($::config_parms{xap_disable})) {
    	$port = $::config_parms{xap_port};
    	$port = 3639 unless $port;

   	 &open_port($port, 'send', 'xap_send', 0, 1);

                                  # Find and use the first open port
    	my $port_listen;
    	for my $p ($port .. $port+100) {
            next if $::config_parms{xap_nohub} and $p == $port;
            $port_listen = $p;
            last if &open_port($port_listen, 'listen', 'xap_listen', 0, 1);
    	}
                                  # mh will be a hub if the ports are the same
    	$hub_flag = $port == $port_listen;
    	print " - mh in xAP Hub mode\n" if $hub_flag;

    	$xap_listen = new Socket_Item(undef, undef, 'xap_listen');
    	$xap_send   = new Socket_Item(undef, undef, 'xap_send');
    }

# now, do the same for xpl
    if (!($::config_parms{xpl_disable})) {
    	undef $port;
    	$port = $::config_parms{xpl_port};
    	$port = 3865 unless $port;

    	&open_port($port, 'send', 'xpl_send', 0, 1);

                                  # Find and use the first open port
    	my $port_listen;
    	for my $p ($port .. $port+100) {
        	next if $::config_parms{xpl_nohub} and $p == $port;
        	$port_listen = $p;
        	last if &open_port($port_listen, 'listen', 'xpl_listen', 0, 1);
    	}
                                  # mh will be a hub if the ports are the same
    	$xpl_hub_flag = $port == $port_listen;
    	print " - mh in xPL Hub mode\n" if $xpl_hub_flag;

    	$xpl_listen = new Socket_Item(undef, undef, 'xpl_listen');
    	$xpl_send   = new Socket_Item(undef, undef, 'xpl_send');
    }

    &::MainLoop_pre_add_hook(\&xAP::check_for_data, 1 );

    &xAP::send_heartbeat('xAP');
    &xAP::send_heartbeat('xPL');

}

sub open_port {
    my ($port, $send_listen, $port_name, $local, $verbose) = @_;

# Need to re-open the port, if client app has been re-started??
    close $::Socket_Ports{$port_name}{sock} if $::Socket_Ports{$port_name}{sock};
#   return 0 if $::Socket_Ports{$port_name}{sock};  # Already open

    my $sock;
    if ($send_listen eq 'send') {
        my $address;
#       $address = inet_ntoa(INADDR_BROADCAST);
        $address = '255.255.255.255';
        $address = 'localhost' if $local;
        $sock = new IO::Socket::INET->new(PeerPort => $port, Proto => 'udp',
                                          PeerAddr => $address, Broadcast => 1);
    }
    else {
        $sock = new IO::Socket::INET->new(LocalPort => $port, Proto => 'udp',
                                          LocalAddr => '0.0.0.0', Broadcast => 1);
#                                         LocalAddr => inet_ntoa(INADDR_ANY), Broadcast => 1);
    }
    unless ($sock) {
        print "\nError:  Could not start a udp xAP/xPL send server on $port: $@\n\n" if $send_listen eq 'send';
        return 0;
    }

    printf " - creating %-15s on %3s %5s %s\n", $port_name, 'udp', $port, $send_listen if $verbose;

    print "db xap open_port: p=$port pn=$port_name l=$local s=$sock\n" if $main::Debug{xap};

    $::Socket_Ports{$port_name}{protocol} = 'udp';
    $::Socket_Ports{$port_name}{datatype} = 'raw';
    $::Socket_Ports{$port_name}{port}     = $port;
    $::Socket_Ports{$port_name}{sock}     = $sock;
    $::Socket_Ports{$port_name}{socka}    = $sock;  # UDP ports are always "active"

    return $sock;
}


sub check_for_data {
    my $ip_address = $::Info{IPAddress_local};

    undef $xap_data;
    if (my $data = said $xap_listen) {
        $xap_data = &parse_data($data);

        my ($protocol, $source, $class, $target);
        if ($$xap_data{'xap-header'} or $$xap_data{'xap-hbeat'}) {
            $protocol = 'xAP';
            $source   = $$xap_data{'xap-header'}{source};
            $class    = $$xap_data{'xap-header'}{class};
	    $target   = $$xap_data{'xap-header'}{target};
            $source   = $$xap_data{'xap-hbeat'}{source} unless $source;
            $class    = $$xap_data{'xap-hbeat'}{class}  unless $class;
	    $target   = $$xap_data{'xap-hbeat'}{target} unless $target;
        }
        print "db1 xap check: p=$protocol s=$source c=$class t=$target d=$data\n" if $main::Debug{xap} and $main::Debug{xap} == 1;

        return unless $source;

        if ($hub_flag) {
            my ($port);
                                  # As a hub, echo data to other listeners (no need to distinguish xAP and xPL?)
            for $port (keys %hub_ports) {
                my $sock = $::Socket_Ports{"xap_send_$port"}{sock};
                print "db2 xap hub: sending $protocol data to p=$port s=$sock d=\n$data.\n" if $main::Debug{xap} and $main::Debug{xap} == 2;
                print $sock $data;
            }
                                  # Log hearbeats of other apps
            if ($$xap_data{'xap-hbeat'}) {
		my $sender_iaddr = $::Socket_Ports{'xap_listen'}{from_ip};
		my $sender_ip_address = Socket::inet_ntoa($sender_iaddr) if $sender_iaddr;
		if ($sender_ip_address eq $ip_address) {
		   print "Adding local xAP port ($source) for hub management\n" if $main::Debug{xap};
                   $port   = $$xap_data{'xap-hbeat'}{port};
		}
	    }

                                # Open/re-open the port on every hbeat if it posts a listening port.
                                # Skip if it is our own hbeat (port = listen port)
            if ($port and $port ne $::Socket_Ports{'xap_listen'}{port}) {
                $hub_ports{$port} = $source;
                my $port_name = "xap_send_$port";
                my $msg = ($::Socket_Ports{$port_name}{sock}) ? 'renewing' : 'registering';
                print "$protocol $msg port=$port to xAP client $source" if $main::Debug{xap};
                                  # xAP apps want local
                &open_port($port, 'send', $port_name, 1, $msg eq 'registering');
            }
        }

	# continue processing if mh is not the source (e.g., heat-beats)
	if (!($source eq &get_mh_source_info())) {
                                  # Set states in matching xAP objects
           for my $name (&::list_objects_by_type('xAP_Item')) {
               my $o = &main::get_object_by_name($name);
               $o = $name unless $o; # In case we stored object directly (e.g. lib/Telephony_xAP.pm)
               next unless $protocol eq $$o{protocol};
               print "db3 xap test  o=$name s=$source os=$$o{source} c=$class oc=$$o{class}\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
               next unless $source  =~ /$$o{source}/i;
               # check/handle hbeats
               for my $section (keys %{$xap_data}) {
		  if (lc $class eq 'xap-hbeat') {
		     if (lc $class eq 'xap-hbeat.alive') {
			$o->_handle_alive_app();
		     } else {
			$o->_handle_dead_app();
		     }
		  }
	       }

	       next unless $class   =~ /$$o{class}/i;

                                  # Find and set the state variable
               my $state_value;
               $$o{changed} = '';
               for my $section (keys %{$xap_data}) {
                   $$o{sections}{$section} = 'received' unless $$o{sections}{$section};
                   for my $key (keys %{$$xap_data{$section}}) {
                       my $value = $$xap_data{$section}{$key};
		       # does a tied value convertor exist for this key and object?
                       my $value_convertor = $$o{_value_convertors}{$key} if defined($$o{_value_convertors});
                       if ($value_convertor) {
                           print "db xap: located value convertor: $value_convertor\n" if $main::Debug{xap};
                           my $converted_value = eval $value_convertor;
                           if ($@) {
                               print $@;
                           } else {
                               print "db xap: converted value is: $converted_value\n" if $main::Debug{xap};
                           }
                           $value = $converted_value if $converted_value;
                       }
                       $$o{$section}{$key} = $value;
                                  # Monitor what changed (real data, not hbeat).
                       $$o{changed} .= "$section : $key = $value | "
                           unless $section eq 'xap-header' or ($section eq 'xap-hbeat' and !($$o{class} =~ /^xap-hbeat/i));
                       print "db3 xap state check m=$$o{state_monitor} key=$section : $key  value=$value\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
                       if ($$o{state_monitor} and "$section : $key" eq $$o{state_monitor} and defined $value) {
                           print "db3 xap setting state to $value\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
                           $state_value = $value;
                       }
                   }
               }
               $state_value = $$o{changed} unless defined $state_value;
      	       print "db3 xap set: n=$name to state=$state_value\n\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
#	       $$o{state} = $$o{state_now} = $$o{said} == $state_value if defined $state_value;
# Can not use Generic_Item set method, as state_next_path only carries state, not all other $section data, to the next pass
#              $o -> SUPER::set($state_value, 'xap') if defined $state_value;
               $o -> SUPER::set_now($state_value, 'xap') if (defined $state_value and $state_value ne '');
           }
	}
    }
# now try the same for the xpl listener
    undef $xpl_data;
    if (my $data = said $xpl_listen) {
        $xpl_data = &parse_data($data);

        my ($protocol, $source, $class, $target, $msg_type);
            $protocol = 'xPL';
            $source   = $$xpl_data{'xpl-stat'}{source};
            $source   = $$xpl_data{'xpl-cmnd'}{source} unless $source;
            $source   = $$xpl_data{'xpl-trig'}{source} unless $source;
	    $target   = $$xpl_data{'xpl-stat'}{target};
	    $target   = $$xpl_data{'xpl-cmnd'}{target} unless $target;
	    $target   = $$xpl_data{'xpl-trig'}{target} unless $target;
	    if ($$xpl_data{'xpl-stat'}) {
		$msg_type = 'stat';
	    } elsif ($$xpl_data{'xpl-cmnd'}) {
		$msg_type = 'cmnd';
	    } else {
		$msg_type = 'trig';
	    }

        print "db1 xpl check: p=$protocol s=$source c=$class t=$target d=$data\n" if $main::Debug{xap} and $main::Debug{xap} == 1;

        return unless $source;

        if ($xpl_hub_flag) {
            my ($port);
                                  # As a hub, echo data to other xpl listeners
            for $port (keys %xpl_hub_ports) {
                my $sock = $::Socket_Ports{"xpl_send_$port"}{sock};
                print "db2 xpl hub: sending $protocol data to p=$port source=$xpl_hub_ports{$port} s=$sock d=\n$data.\n" if $main::Debug{xap} and $main::Debug{xap} == 2;
                print $sock $data;
            }
                                  # Log hearbeats of other apps
            if ($protocol eq 'xPL' and $$xpl_data{'hbeat.app'}) {
		my $sender_iaddr = $::Socket_Ports{'xpl_listen'}{from_ip};
		my $sender_ip_address = Socket::inet_ntoa($sender_iaddr) if $sender_iaddr;
		if ($sender_ip_address eq $ip_address) {
		   print "Adding local xPL port ($source) for hub management\n" if $main::Debug{xap};
                   $port    = $$xpl_data{'hbeat.app'}{port};
		}
            }

                                # Open/re-open the port on every hbeat if it posts a listening port.
                                # Skip if it is our own hbeat (port = listen port)
            if ($port and $port ne $::Socket_Ports{'xpl_listen'}{port}) {
                $xpl_hub_ports{$port} = $source;
                my $port_name = "xpl_send_$port";
                my $msg = ($::Socket_Ports{$port_name}{sock}) ? 'renewing' : 'registering';
                print "db $protocol $msg port=$port to xPL client $source" if $main::Debug{xap};
		# xPL apps want local
                &open_port($port, 'send', $port_name, 1, $msg eq 'registering');
            }
        }

	# continue processing unless we are the source (e.g., heart-beat)
	if (!($source eq &get_mh_source_info())) {
                                  # Set states in matching xPL objects
           for my $name (&::list_objects_by_type('xPL_Item')) {
               my $o = &main::get_object_by_name($name);
               $o = $name unless $o; # In case we stored object directly (e.g. lib/Telephony_xAP.pm)
               next unless $protocol eq $$o{protocol};
                   print "db3 xpl test  o=$name s=$source oa=$$o{source}\n" if $main::Debug{xap} and $main::Debug{xap} == 3;

	       # skip this object unless the source matches
	       # NOTE: the object's hash reference for "source" is "address"
	       next unless $source =~ /$$o{address}/i;

	       # handle hbeat data
               for my $section (keys %{$xpl_data}) {
	          if ($section =~ /^hbeat./i) {
		     if (lc $section eq 'hbeat.app') {
		         $o->_handle_alive_app();
		     } else {
		         $o->_handle_dead_app();
		     }
	          }
	       }

	       my $className;
	       # look at each section name; any that don't match the header titles is the classname
               #   since is there is only one "block" in an xPL message and its label is the classname
	       for my $section (keys %{$xpl_data}) {
		  if ($section) {
		      $className = $section unless ($section eq 'xpl-stat' || $section eq 'xpl-cmnd' || $section eq 'xpl-trig');
		  }
	        }
		# skip this object unless the classname matches
		if ($className && $$o{class}) {
		   next unless $className =~ /$$o{class}/i;
		}

                                  # Find and set the state variable
               my $state_value;
               $$o{changed} = '';
               for my $section (keys %{$xpl_data}) {
                   $$o{sections}{$section} = 'received' unless $$o{sections}{$section};
                   for my $key (keys %{$$xpl_data{$section}}) {
                       my $value = $$xpl_data{$section}{$key};
                       # does a tied value convertor exist for this key and object?
                       my $value_convertor = $$o{_value_convertors}{$key} if defined($$o{_value_convertors});
                       if ($value_convertor) {
                           print "db xpl: located value convertor: $value_convertor\n" if $main::Debug{xap};
                           my $converted_value = eval $value_convertor;
                           if ($@) {
                               print$@;
                           } else {
                               print "db xpl: converted value is: $converted_value\n" if $main::Debug{xap};
                           }
                           $value = $converted_value if $converted_value;
                       }
                       $$o{$section}{$key} = $value;
                                  # Monitor what changed (real data, not hbeat).
                       $$o{changed} .= "$section : $key = $value | "
                           unless $section eq 'xpl-stat' or $section eq 'xpl-trig' or $section eq 'xpl-cmnd' or ($section =~ /^hbeat./i and !($$o{class} =~ /^hbeat.app/i));
                       print "db3 xpl state check m=$$o{state_monitor} key=$section : $key  value=$value\n" if $main::Debug{xap};# and $main::Debug{xap} == 3;
                       if ($$o{state_monitor} and "$section : $key" eq $$o{state_monitor} and defined $value) {
                           print "db3 xpl setting state to $value\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
                           $state_value = $value;
                       }
                   }
               }
               $state_value = $$o{changed} unless defined $state_value;
	       print "db3 xpl set: n=$name to state=$state_value\n\n" if $main::Debug{xap};# and $main::Debug{xap} == 3;
#	       $$o{state} = $$o{state_now} = $$o{said} == $state_value if defined $state_value;
# Can not use Generic_Item set method, as state_next_path only carries state, not all other $section data, to the next pass
#              $o -> SUPER::set($state_value, 'xap') if defined $state_value;
               $o -> SUPER::set_now($state_value, 'xap') if (defined $state_value and $state_value ne '');
           }
	}
    }

    &xAP::send_heartbeat('xAP') if $::New_Minute;
    &xAP::send_heartbeat('xPL') if $::New_Minute;
}

                                  # Parse incoming xAP records
sub parse_data {
    my ($data) = @_;
    my ($data_type, %d);
    print "db4 xap data:\n$data\n" if $main::Debug{xap} and $main::Debug{xap} == 4;
    for my $r (split /[\r\n]/, $data) {
        next if $r =~ /^[\{\} ]*$/;
                                  # Store xap-header, xap-heartbeat, and other data
        if (my ($key, $value) = $r =~ /(.+?)=(.*)/) {
            $key   = lc $key;
            $value = lc $value if ($data_type =~ /^xap/ || $data_type =~ /^xpl/); # Do not lc real data;
            $d{$data_type}{$key} = $value;
            print "db4 xap/xpl parsed c=$data_type k=$key v=$value\n" if $main::Debug{xap} and $main::Debug{xap} == 4;
        }
                                  # data_type (e.g. xap-header, xap-heartbeat, source.instance
        else {
            $data_type = lc $r;
        }
    }
    return \%d;
}

sub get_mh_vendor_info {
   return 'mhouse';
}

sub get_mh_device_info {
   return 'mh';
}

sub get_mh_source_info {
   my $instance = lc($::config_parms{title});
   $instance =~ tr/ /_/;
   return &get_mh_vendor_info() . '.' . &get_mh_device_info() . '.' . $instance;
}

sub is_target {
    my ($target, $source) = @_;
    return  ( (!($source eq &get_mh_source_info())) &&
		( (!($target))
		|| $target eq '*'
		|| $target eq (&get_mh_vendor_info() . '.*')
		|| $target eq (&get_mh_vendor_info() . '.' &get_mh_device_info() . '.*')
		|| $target eq &get_mh_source_info() )	);

}

sub received_data {
    my ($protocol) = @_;
    if ($protocol and $protocol eq 'xPL') {
	return $xpl_data;
    } else {
        return $xap_data;
    }
}

sub send {
    my ($protocol, $class_address, @data) = @_;
    print "db5 $protocol send: ca=$class_address d=@data xap_send=$xap_send\n" if $main::Debug{xap};# and $main::Debug{xap} == 5;

    if ($protocol eq 'xAP') {
	my $target = '*';
        my @data2; # this will hold the "stripped" data after looking for a target arg
	while (@data) {
	    my $section = shift @data;
            if (lc $section eq 'xap_target') {
	    	$target = shift @data;
	    } else {
		push @data2, $section, shift @data;
	    }
	}
	&sendXap($target, $class_address, @data2);
    } else {
	my $target = $class_address;
	&sendXpl($target, 'cmnd', @data);
    }
}

sub sendXap {
    my ($target, $class_name, @data) = @_;
    my ($parms, $msg);
    my $uid = $::config_parms{xap_uid};
    $uid = 'FF123400' unless $uid;
    $msg  = "xap-header\n{\nv=12\nhop=1\nuid=$uid\nsource=" . &get_mh_source_info() . "\n";
    $msg .= "class=$class_name\n";
    # include target only if its defined; we won't try to extract it out of class_name
    undef $target if $::config_parms{xap_disable_target};
    if (defined($target)) {
        $msg .= "target=$target\n";
    }
	$msg .= "}\n";
    while (@data) {
        my $section = shift @data;
        $msg .= "$section\n{\n";
        my $ptr = shift @data;
        my %parms = %$ptr;
        for my $key (sort keys %parms) {
            $msg .= "$key=$parms{$key}\n";
        }
        $msg .= "}\n";
    }
    print "db5 xap msg: $msg" if $main::Debug{xap} and $main::Debug{xap} == 5;
    if ($xap_send) {
       $xap_send->set($msg);
    }
    else {
        print "Error in xAP_Item::sendXap. Send socket not available.\n";
    }
}

sub sendXpl {
    my ($target, $msg_type, @data) = @_;
    my ($parms, $msg);
    $msg  = "xpl-$msg_type\n{\nhop=1\nsource=" . &get_mh_source_info() . "\n";
    if (defined($target)) {
	$msg .= "target=$target\n";
    }
    $msg .= "}\n";
    while (@data) {
	my $section = shift @data;
	$msg .= "$section\n{\n";
	my $ptr = shift @data;
	my %parms = %$ptr;
	for my $key (sort keys %parms) {
	    $msg .= "$key=$parms{$key}\n";
	}
	$msg .= "}\n";
    }
    print "db5 xpl msg: $msg" if $main::Debug{xap} and $main::Debug{xap} == 5;
    if ($xpl_send) {
	$xpl_send->set($msg);
    }
    else {
	print "Error in xAP_Item::sendXpl. Send socket not available.\n";
    }
}

sub send_heartbeat {
    my ($protocol) = @_;
    my $port = $::Socket_Ports{xap_listen}{port};
    my $uid      = $::config_parms{xap_uid};
    my $instance = $::config_parms{title};
    $instance =~ tr/ /_/;
#   $uid = 'FF200301' unless $uid;
    $uid = 'FF123400' unless $uid;
    my $ip_address = $::Info{IPAddress_local};
    my $msg;
    if ($protocol eq 'xAP') {
	if ($xap_send) {
            $msg = "xap-hbeat\n{\nv=12\nhop=1\nuid=$uid\nclass=xap-hbeat.alive\n";
            $msg .= "source=" . &get_mh_source_info() . "\ninterval=60\nport=$port\npid=$$\n}\n";
    	    $xap_send->set($msg);
    	    print "db6 $protocol heartbeat: $msg.\n" if $main::Debug{xap} and $main::Debug{xap} == 6;
	} else {
	    print "Error in xAP_Item::send_heartbeat.  xAP send socket not available.\n";
	    print "Either disable xAP (xap_disable = 1) or resolve system network problem (UDP port 3639).\n";
	}
    }
    elsif ($protocol eq 'xPL') {
	if ($xpl_send) {
	    $port = $::Socket_Ports{xpl_listen}{port};
            $msg  = "xpl-stat\n{\nhop=1\nsource=" . &get_mh_source_info() . "\ntarget=*\n}\n";
            $msg .= "hbeat.app\n{\ninterval=1\nport=$port\nremote-ip=$ip_address\npid=$$\n}\n";
    	    $xpl_send->set($msg);
    	    print "db6 $protocol heartbeat: $msg.\n" if $main::Debug{xap} and $main::Debug{xap} == 6;
	} else {
	    print "Error in xAP_Item::send_heartbeat.  xPL send socket not available.\n";
	    print "Either disable xPL (xpl_disable = 1) or resolve system network problem (UDP port 3865).\n";
	}
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

   target(target): Sets/Gets the target (name).  Syntax is similar to source.  Used to direct (target)
      the message to a specific device.  Use "*" (default) for broadcast messages.

   manage_heartbeat_timeout(timeout, action, repeat).  Sets the timeout interval (in secs) and action to be performed
      on expiration of a timer w/ no corresponding heart-beat messages.  Used to enable warnings/notices
      of absent heart-beats. See comments on using # noloop above.  Timeout should be set to a value
      greater than the actual device heartbeat interval. Action/timer is not repeated unless
      repeat is 1 or true.

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
    my ($object_class, $xap_class, $xap_source, @data) = @_;
    my $self = {};
    bless $self, $object_class;

    $xap_class  = '.*' if !$xap_class  or $xap_class  eq '*';
    $xap_source = '.*' if !$xap_source or $xap_source eq '*';
    $$self{state}    = '';
    $$self{class}    = $xap_class;
    $$self{source}   = $xap_source;
    $$self{protocol} = 'xAP';
    $$self{target}   = '*';
    $$self{m_timeoutHeartBeat} = 0; # don't monitor heart beats
    $$self{m_appStatus} = 'unknown';
    $$self{m_timerHeartBeat} = new Timer();

    &store_data($self, @data);

    $self->state_overload('off'); # By default, do not process ~;: strings as substate/multistate

    return $self;
}

sub class_name {

    my ($self, $p_strClassName) = @_;
    $$self{class} = $p_strClassName if defined $p_strClassName;
    return $$self{class};
}

sub source {

    my ($self, $p_strSource) = @_;
    $$self{source} = $p_strSource if defined $p_strSource;
    return $$self{source};
}

sub target {
    my ($self, $p_strTarget) = @_;
    $$self{target} = $p_strTarget if defined $p_strTarget;
    return $$self{target};
}

sub manage_heartbeat_timeout {
    my ($self, $p_timeoutHeartBeat, $p_actionHeartBeat, $p_repeatAction) = @_;
    if (defined($p_timeoutHeartBeat) and defined($p_actionHeartBeat)) {
	my $m_repeatAction = 0;
	$m_repeatAction = $p_repeatAction if $p_repeatAction;
    	$$self{m_actionHeartBeat} = $p_actionHeartBeat;
	$$self{m_timeoutHeartBeat} = $p_timeoutHeartBeat;
	$$self{m_timerHeartBeat}->set($$self{m_timeoutHeartBeat},$$self{m_actionHeartBeat}, $m_repeatAction);
    	$$self{m_timerHeartBeat}->start();
    }
}

sub dead_action {
    my ($self, $p_actionDeadApp) = @_;
    $$self{m_app_Status} = 'dead';
    if (defined $p_actionDeadApp) {
	$$self{m_actionDeadApp} = $p_actionDeadApp;
    }
    return $$self{m_actionDeadApp};
}

sub _handle_dead_app {
    my ($self) = @_;
    return eval $$self{m_actionDeadApp} if defined($$self{m_actionDeadApp});
}

sub _handle_alive_app {
    my ($self) = @_;
    $$self{m_appStatus} = 'alive';
    if ($$self{m_timeoutHeartBeat} != 0) {
	$$self{m_timerHeartBeat}->restart() unless $$self{m_timerHeartBeat}->inactive();
	return 1;
    } else {
	$$self{m_timerHeartBeat}->stop() unless $$self{m_timerHeartBeat}->inactive();
	return 0;
    }
}

sub app_status {
    my ($self) = @_;
    return $$self{m_appStatus};
}

sub send_message {
    my ($self, $p_strTarget, @p_strData) = @_;
    my ($m_strClassName, $m_strTarget);
    $m_strTarget = $p_strTarget if defined $p_strTarget;
    $m_strTarget = $$self{class} if !$p_strTarget;
    $m_strClassName = $$self{class};
    $m_strClassName = '*' if !$m_strClassName;
    &xAP::sendXap($m_strTarget, $m_strClassName, @p_strData);
}

sub store_data {
    my ($self, @data) = @_;
    while (@data) {
        my $section = shift @data;
 	if ($$self{protocol} eq 'xPL') {
	   $$self{class} = $section;
	}
        $$self{sections}{$section} = 'send';
        my $ptr = shift @data;
        my %parms = %$ptr;
        for my $key (sort keys %parms) {
            my $value = $parms{$key};
            $$self{$section}{$key} = $value;
            $$self{state_monitor} = "$section : $key" if $value eq '$state';
        }
    }
}

sub default_setstate {
    my ($self, $state, $substate, $set_by) = @_;

                                # Send data, unless we are processing incoming data
    return if $set_by eq 'xap';

    my ($section, $key) = $$self{state_monitor} =~ /(.+) : (.+)/;
    $$self{$section}{$key} = $state;

    my @parms;
    for my $section (sort keys %{$$self{sections}}) {
        next unless $$self{sections}{$section} eq 'send'; # Do not echo received data
        push @parms, $section, $$self{$section};
    }

    if ($$self{protocol} eq 'xAP') {
	# sending stat info about ourselves?
	if (lc $$self{source} eq &get_mh_source_info()) {
	    &xAP::sendXap('*', @parms, $$self{class});
	} else {
	# must be cmnd info to another device addressed by source
            &xAP::sendXap($$self{source}, @parms, $$self{class});
	}
    }
    elsif ($$self{protocol} eq 'xPL') {
	# sending stat info about ourselves?
	if (lc $$self{source} eq &get_mh_source_info()) {
	    &xAP::sendXpl('*', @parms, 'stat');
	} else {
	# must be cmnd info to another device addressed by address
            &xAP::sendXpl($$self{address}, @parms, 'cmnd');
	}
    }
}

sub state_now {
	my ($self, $section_name) = @_;
	my $state_now = $self->SUPER::state_now();
	if ($section_name) {
		# default section_state_now to undef unless it actually exists
		my $section_state_now = undef;
		for my $section (split(/\s+\|\s+/,$state_now)) {
			my @section_data = split(/\s+:\s+/,$section);
			my $section_ref = $section_data[0];
			next if $section_ref eq '';
			if ($section_ref eq $section_name) {
				if (defined($section_state_now)) {
					$section_state_now .= " | $section_data[1]";
				} else {
					$section_state_now = $section_data[1];
				}
			}
		}
		print "db xAP_Item:state_now: section data for $section_name is: $section_state_now\n"
			if $main::Debug{xap};
		$state_now = $section_state_now;
	}
	return $state_now;
}

sub current_section_names {
	my ($self) = @_;
	my $changed = $$self{changed};
	my $current_section_names = undef;
	if ($changed) {
		for my $section (split(/\s+\|\s+/,$changed)) {
			my @section_data = split(/\s+:\s+/,$section);
			if (defined($current_section_names)) {
				$current_section_names .= " | $section_data[0]";
			} else {
				$current_section_names = $section_data[0];
			}
		}

	}
	print "db xAP_Item:current_section_names : $current_section_names\n" if $main::Debug{xap};
	return $current_section_names;
}

sub tie_value_convertor {
	my ($self, $key_name, $convertor) = @_;
	$$self{_value_convertors}{$key_name} = $convertor if (defined($key_name) && defined($convertor));

}

package xPL_Item;

@xPL_Item::ISA = ('xAP_Item');


                                  # Support both send and receive objects
sub new {
    my ($object_class, $xpl_source, @data, $xpl_class) = @_;
    my $self = {};
    bless $self, $object_class;

    $xpl_source = '.*' if !$xpl_source or $xpl_source eq '*';

    $$self{state}    = '';
    $$self{address}  = $xpl_source; # left in place for legacy
    $$self{address}  = '*' if !$xpl_source;
    $$self{protocol} = 'xPL';
    $$self{target}   = '*';
    $$self{class}    = $xpl_class unless !$xpl_class;
    $$self{m_timeoutHeartBeat} = 0;
    $$self{m_appStatus} = 'unknown';
    $$self{m_timerHeartBeat} = new Timer();

    &xAP_Item::store_data($self, @data);

    $self->state_overload('off'); # By default, do not process ~;: strings as substate/multistate

    return $self;
}

sub source {
    my ($self, $p_strSource) = @_;
    $$self{address} = $p_strSource if defined $p_strSource;
    return $$self{address};
}

# DO NOT use the following sub--it exists only because this class inherits from xAP_Item
# This is largely because the concept of sending a message doesn't exist in xPL and more importantly,
#    this overriden method uses different arguments
# Instead, DO use either send_cmnd, send_trig or send_stat
sub send_message {
    my ($self, $p_strTarget, @p_data) = @_;
    $self->send_cmnd($p_strTarget, @p_data, $p_strTarget);
}

sub send_cmnd {
    my ($self, $p_strTarget, @p_data) = @_;
    my $m_strTarget = $p_strTarget if defined $p_strTarget;
    $m_strTarget = $$self{target} if !$p_strTarget;
    &xAP::sendXpl($m_strTarget, 'cmnd', @p_data);
}

sub send_stat {
    my ($self, $p_strTarget, @p_data) = @_;
    my $m_strTarget = $p_strTarget if defined $p_strTarget;
    $m_strTarget = $$self{target} if !$p_strTarget;
    &xAP::sendXpl($m_strTarget, 'stat', @p_data);
}

sub send_trig {
    my ($self, $p_strTarget, @p_data) = @_;
    my $m_strTarget = $p_strTarget if defined $p_strTarget;
    $m_strTarget = $$self{target} if !$p_strTarget;
    &xAP::sendXpl($m_strTarget, 'trig', @p_data);
}

package xPL_Rio;

@xPL_Rio::ISA = ('xPL_Item');

                                  # Support both send and receive objects
sub new {
    my ($object_class, $xpl_source, $xpl_target) = @_;
    my $self = {};
    bless $self, $object_class;

    $$self{state}    = '';
    $$self{source}  = $xpl_source;
    $$self{protocol} = 'xPL';
    $$self{target}  =  $xpl_target unless !$xpl_target;

    &xAP_Item::store_data($self, 'rio.basic' => {sel => '$state'});

    @{$$self{states}} = ('play', 'stop', 'mute' , 'volume +20' , 'volume -20', 'volume 100' ,
                         'skip', 'back', 'random' ,'power on', 'power off', 'light on', 'light off');

    return $self;

}

1;
