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

my ($started, $xap_listen, $xap_send, $hub_flag, %hub_ports);
use vars '$xap_data';

                                # Create sockets and add hook to check incoming data
sub startup {
    return if $started++;       # Allows us to call with $Reload or with xap_module mh.ini parm
    return if $::config_parms{xap_disable}; # In case you don't want xap for some reason

    my ($port);

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
    print " - mh in xAP/xPL Hub mode\n" if $hub_flag;
    
    $xap_listen = new Socket_Item(undef, undef, 'xap_listen');
    $xap_send   = new Socket_Item(undef, undef, 'xap_send');

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
        print "\nError:  Could not start a udp xAP send server on $port: $@\n\n" if $send_listen eq 'send';
        return 0;
    }

    printf " - creating %-15s on %3s %5s %s\n", $port_name, 'udp', $port, $send_listen if $verbose;

    $::Socket_Ports{$port_name}{protocol} = 'udp';
    $::Socket_Ports{$port_name}{datatype} = 'raw';
    $::Socket_Ports{$port_name}{port}     = $port;
    $::Socket_Ports{$port_name}{sock}     = $sock;
    $::Socket_Ports{$port_name}{socka}    = $sock;  # UDP ports are always "active"
    
    return $sock;
}


sub check_for_data {
    undef $xap_data;
    if (my $data = said $xap_listen) {
        $xap_data = &parse_data($data);

        my ($protocol, $source, $class);
        if ($$xap_data{'xap-header'} or $$xap_data{'xap-hbeat'}) {
            $protocol = 'xAP';
            $source   = $$xap_data{'xap-header'}{source};
            $class    = $$xap_data{'xap-header'}{class};
            $source   = $$xap_data{'xap-hbeat'}{source} unless $source;
            $class    = $$xap_data{'xap-hbeat'}{class}  unless $class;
        }
        else {
            $protocol = 'xPL';
            $source   = $$xap_data{'xpl-stat'}{source};
            $source   = $$xap_data{'xpl-cmnd'}{source} unless $source;
            $source   = $$xap_data{'xpl-trig'}{source} unless $source;
        }
        print "db1 xap check: p=$protocol s=$source c=$class d=$data\n" if $main::Debug{xap} and $main::Debug{xap} == 1;

        return unless $source;

        if ($hub_flag) {
            my ($port, $source);
                                  # As a hub, echo data to other listeners (no need to distinguish xAP and xPL?)
            for $port (keys %hub_ports) {
                my $sock = $::Socket_Ports{"xap_send_$port"}{sock};
                print "db2 xap hub: sending $protocol data to p=$port s=$sock d=\n$data.\n" if $main::Debug{xap} and $main::Debug{xap} == 2;
                print $sock $data;
            }
                                  # Log hearbeats of other apps
            if ($protocol eq 'xAP' and $$xap_data{'xap-hbeat'}) {
                $port   = $$xap_data{'xap-hbeat'}{port};
                $source = $$xap_data{'xap-hbeat'}{source};
            }
            elsif ($protocol eq 'xPL' and $$xap_data{'hbeat.app'}) {
                $port    = $$xap_data{'hbeat.app'}{port};
                $source  = $$xap_data{'hbeat.app'}{source};
            }

                                # Open/re-open the port on every hbeat if it posts a listening port.
                                # Skip if it is our own hbeat (port = listen port)
            if ($port and $port ne $::Socket_Ports{'xap_listen'}{port}) {
                $hub_ports{$port} = $source;
                my $port_name = "xap_send_$port";
                my $msg = ($::Socket_Ports{$port_name}{sock}) ? 'renewing' : 'registering';
                print "$protocol $msg port=$port to xAP client $source" if $main::Debug{xap};
                                  # xAP apps want local, but xPL apps do not?
                &open_port($port, 'send', $port_name, $protocol eq 'xAP', $msg eq 'registering');
            }
        }

                                  # Set states in matching xAP objects
        for my $name (&::list_objects_by_type('xAP_Item'), &::list_objects_by_type('xPL_Item')) {
            my $o = &main::get_object_by_name($name);
            $o = $name unless $o; # In case we stored object directly (e.g. lib/Telephony_xAP.pm)
            next unless $protocol eq $$o{protocol};
            if ($protocol eq 'xAP') {
                print "db3 xap test  o=$name s=$source os=$$o{source} c=$class oc=$$o{class}\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
                next unless $source  =~ /$$o{source}/i;
                next unless $class   =~ /$$o{class}/i;
            }
            elsif ($protocol eq 'xPL') {
                print "db3 xpl test  o=$name s=$source oa=$$o{address}\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
                next unless $source  =~ /$$o{address}/i;
            }
            print "db3 xap match o=$name\n" if $main::Debug{xap} and $main::Debug{xap} == 3;

                                  # Find and set the state variable
            my $state_value;
            $$o{changed} = '';
            for my $section (keys %{$xap_data}) {
                $$o{sections}{$section} = 'received' unless $$o{sections}{$section};
                for my $key (keys %{$$xap_data{$section}}) {
                    my $value = $$xap_data{$section}{$key};
                    $$o{$section}{$key} = $value;
                                  # Monitor what changed (real data, not hbeat).  
                    $$o{changed} .= "$section : $key = $value | " 
                        unless $section eq 'xap-header' or $section eq 'xap-hbeat' or $section eq 'xpl-stat';

                    print "db3 xap state check m=$$o{state_monitor} key=$section : $key  value=$value\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
                    if ($$o{state_monitor} and "$section : $key" eq $$o{state_monitor} and defined $value) {
                        print "db3 xap setting state to $value\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
                        $state_value = $value;
                    }
                }
            }
            $state_value = $$o{changed} unless defined $state_value;
	    print "db3 xap set: n=$name to state=$state_value\n\n" if $main::Debug{xap} and $main::Debug{xap} == 3;
#	    $$o{state} = $$o{state_now} = $$o{said} == $state_value if defined $state_value;
# Can not use Generic_Item set method, as state_next_path only carries state, not all other $section data, to the next pass
#           $o -> SUPER::set($state_value, 'xap') if defined $state_value;
            $o -> SUPER::set_now($state_value, 'xap') if defined $state_value;
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
            $value = lc $value if $data_type =~ /^xap/; # Do not lc real data;
            $d{$data_type}{$key} = $value;
            print "db4 xap parsed c=$data_type k=$key v=$value\n" if $main::Debug{xap} and $main::Debug{xap} == 4;
        }
                                  # data_type (e.g. xap-header, xap-heartbeat, source.instance
        else {
            $data_type = lc $r;
        }
    }
    return \%d;
}

sub received_data {
    return $xap_data;
}

sub send {
    my ($protocol, $class_address, @data) = @_;
    my $uid      = $::config_parms{xap_uid};
    my $instance = $::config_parms{title};
#   $uid = 'FF200301' unless $uid;
    $uid = 'FF123400' unless $uid;
    $instance =~ tr/ /_/;
    print "db5 $protocol send: ca=$class_address d=@data xap_send=$xap_send\n" if $main::Debug{xap} and $main::Debug{xap} == 5;

    my ($parms, $msg);
    if ($protocol eq 'xAP') {
        $msg  = "xap-header\n{\nv=12\nhop=1\nuid=$uid\nsource=MHOUSE.mh.$instance\n";
        $msg .= "class=$class_address\n}\n";
    }
    elsif ($protocol eq 'xPL') {
        $msg  = "xpl-cmnd\n{\nhop=1\nsource=MHOUSE.mh.$instance\n";
        $msg .= "target=$class_address\n}\n";
    }

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
        print "Error in xAP_Item::send, not xap_send socket not set\n";
    }
}

sub send_heartbeat {
    my ($protocol) = @_;
    my $port = $::Socket_Ports{xap_listen}{port};
    my $uid      = $::config_parms{xap_uid};
    my $instance = $::config_parms{title};
#   $uid = 'FF200301' unless $uid;
    $uid = 'FF123400' unless $uid;
    $instance =~ tr/ /_/;
    my $ip_address = $::Info{IPAddress_local};
    my $msg;
    if ($protocol eq 'xAP') {
        $msg = "xap-hbeat\n{\nv=12\nhop=1\nuid=$uid\nclass=xap-hbeat.alive\n";
        $msg .= "source=MHOUSE.mh.$instance\ninterval=60\nport=$port\npid=$$\n}\n";
    }
    elsif ($protocol eq 'xPL') {
        $msg  = "xpl-stat\n{\nhop=1\nsource=MHOUSE.mh.$instance\n}\n";
        $msg .= "hbeat.app\n{\ninterval=1\nport=$port\nremote-ip=$ip_address\npid=$$\n}\n";
    }
    $xap_send->set($msg);
    print "db6 $protocol heartbeat: $msg.\n" if $main::Debug{xap} and $main::Debug{xap} == 6;
}

package xAP_Item;

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

    &store_data($self, @data);

    $self->state_overload('off'); # By default, do not process ~;: strings as substate/multistate

    return $self;
}

sub store_data {
    my ($self, @data) = @_;
    while (@data) {
        my $section = shift @data;
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
        &xAP::send('xAP', $$self{class}, @parms);
    }
    elsif ($$self{protocol} eq 'xPL') {
        &xAP::send('xPL', $$self{address}, @parms);
    }
}


package xPL_Item;

@xPL_Item::ISA = ('xAP_Item');


                                  # Support both send and receive objects
sub new {
    my ($object_class, $xpl_address, @data) = @_;
    my $self = {};
    bless $self, $object_class;

    $xpl_address = '.*' if !$xpl_address or $xpl_address eq '*';

    $$self{state}    = '';
    $$self{address}  = $xpl_address;
    $$self{protocol} = 'xPL';

    &xAP_Item::store_data($self, @data);

    $self->state_overload('off'); # By default, do not process ~;: strings as substate/multistate

    return $self;
}

package xPL_Rio;

@xPL_Rio::ISA = ('xPL_Item');

                                  # Support both send and receive objects
sub new {
    my ($object_class, $xpl_address) = @_;
    my $self = {};
    bless $self, $object_class;

    $$self{state}    = '';
    $$self{address}  = $xpl_address;
    $$self{protocol} = 'xPL';

    &xAP_Item::store_data($self, 'rio.basic' => {sel => '$state'});

    @{$$self{states}} = ('play', 'stop', 'mute' , 'volume +20' , 'volume -20', 'volume 100' ,
                         'skip', 'back', 'random' ,'power on', 'power off', 'light on', 'light off');

    return $self;

}

1;

