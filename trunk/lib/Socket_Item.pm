# $Date$
# $Revision$

use strict;

package Socket_Item;

@Socket_Item::ISA = ('Generic_Item');

my (%socket_item_by_id);

sub reset {
    undef %socket_item_by_id;   # Reset on code re-load
}

sub socket_item_by_id {
    my($id) = @_;
    return $socket_item_by_id{$id};
}

sub new {
    my ($class, $id, $state, $host_port, $port_name, $host_proto, $datatype, $break, $broadcast) = @_;

#    print "dbx1 creating socket on port $host_port name=$port_name\n";
    my $self = {state => ''};

    $port_name = $host_port unless $port_name;
    print "\n\nWarning: duplicate ID codes on different socket_Item objects: id=$id\n\n" if $id and $socket_item_by_id{$id};
    $$self{port_name} = $port_name;
    $$self{host_port} = $host_port;
    $$self{server} = 1 if $host_port and $host_port !~ /(\S+)\:(\S+)/;
    $$self{host_protocol} = $host_proto;
    $main::Socket_Ports{$port_name}{host_port} = $host_port if $host_port;
    $main::Socket_Ports{$port_name}{datatype}  = $datatype  if $datatype;
    $main::Socket_Ports{$port_name}{break}     = $break     if $break;
    $$self{broadcast} = $broadcast if $broadcast;
    &add($self, $id, $state);
    bless $self, $class;
    $self->state_overload('off'); # By default, do not process ~;: strings as substate/multistate
    return $self;
}

sub set_port {
    my ($self, $host_port) = @_;
    $$self{host_port} = $host_port;
}

sub add {
    my ($self, $id, $state) = @_;
    $$self{state_by_id}{$id} = $state if $id;
    $$self{id_by_state}{$state} = $id if $state; # Note: State is optional
    push(@{$$self{states}}, $state);
    $socket_item_by_id{$id} = $self if $id;
#    print "db sid=", %socket_Item::socket_item_by_id, "\n";
}

sub start {
    my ($self) = @_;
    my $port_name  = $self->{port_name};
    my $host_port  = $self->{host_port};
    my $host_proto = $self->{host_protocol};
    my $broadcast = $self->{broadcast};
    $host_proto = 'tcp' unless $host_proto;
    $broadcast = 0 unless $broadcast;
    my ($host, $port) = $host_port =~ /(\S+)\:(\S+)/;
    if ($port) {
        if ($main::Socket_Ports{$port_name}{sock}) {
            &::print_log("Socket already opened for $port_name");
            return $main::Socket_Ports{$port_name}{sock};
        }
        print "Socket Item connecting to $host on port $port\n" if $main::Debug{socket};
        if (my $sock = new IO::Socket::INET->new(PeerAddr => $host,
                                                 PeerPort => $port,
                                                 Proto => $host_proto,
                                                 Broadcast => $broadcast
                                                 )) {
# Timeout => 0,  # Does not help with 2 second pauses on unavailable  addresses :(
            $main::Socket_Ports{$port_name}{sock}  = $sock;
            $main::Socket_Ports{$port_name}{socka} = $sock;
            $main::Socket_Ports{$port_name}{active_this_pass_flag} = 1;
            $sock->autoflush(1);
            return $sock;
        }
        else {
            print "Socket_Item client start error:  could not start a tcp client socket\n" .
              " - host=$host port=$port: $@\n";
        }
    }
    else {
        print "Socket_Item client start error:  address is not in the form host:port.  open failed.  port=$port_name address=$host_port\n";
    }
    return 0;
}

sub stop {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    &main::socket_close($port_name);
}

sub is_available {
    my ($self) = @_;
    my $host_port  = $self->{host_port};
    my $host_proto = $self->{host_protocol};
    return &net_socket_check($host_port, $host_proto);
}

sub active {
    my $port_name = $_[0]->{port_name};
    return $main::Socket_Ports{$port_name}{socka};
#     or  scalar @{$main::Socket_Ports{$port_name}{clients}}
}

sub active_now {
    my $port_name = $_[0]->{port_name};
    return $main::Socket_Ports{$port_name}{active_this_pass};
}

sub inactive_now {
    my $port_name = $_[0]->{port_name};
    return $main::Socket_Ports{$port_name}{inactive_this_pass};
}

# checks the active socket and returns the far end point if connected, undef if not
# note that the far end is returned as "ipaddress:port"
# useful for confirming whether a client socket is still "alive"
sub connected {
	my $self=shift;
	my $socket=$self->active;

	if (!$socket) {
		return 0;
	}

	my $peerAddress=$socket->connected;

	if (defined ($peerAddress)) {
		my ($port, $iaddr) = &Socket::sockaddr_in($peerAddress);
		$peerAddress=&Socket::inet_ntoa($iaddr).":$port";
	}
	return $peerAddress;
}

# returns the ipaddress:port that sent the latest received data
sub peer {
	my $self=shift;

    my $host_proto = $self->{host_protocol};
    $host_proto = 'tcp' unless $host_proto;
    my $port_name=$self->{port_name};
    my $sock=$::Socket_Ports{$port_name}{socka};

    if (!$sock) {
    	return undef;
	}

    if ($host_proto eq 'tcp') {
    	# if we are a server, then return the IP address of the latest client
    	# to send data
    	if ($self->{server}) {
    		my $port=
    		return $::Socket_Ports{$port_name}{client_ip_address}.':'.
    			$::Socket_Ports{$port_name}{client_port};
		}
		# we are a client, ask the socket to return the IP address of our peer
		return $sock->peerhost.':'.$sock->peerport;;
    } else {
    	# if we are a server, then return the IP address of the latest client
    	# to send data
    	if ($self->{server}) {
    		return &Socket::inet_ntoa($::Socket_Ports{$port_name}{from_ip}).':'.
    			$::Socket_Ports{$port_name}{from_port};
		}
		# we are a client, ask the socket to return the IP address of our peer
		return $sock->peerhost.':'.$sock->peerport;;
	}
	return "That's unpossible";
}

sub said {
    my $port_name = $_[0]->{port_name};

    my $data;
    my $datatype  = $main::Socket_Ports{$port_name}{datatype};
    if ($datatype and $datatype eq 'raw') {
        $data = $main::Socket_Ports{$port_name}{data};
#       $main::Socket_Ports{$port_name}{data} = '';
        $main::Socket_Ports{$port_name}{data} = undef;
    }
    else {
        $data = $main::Socket_Ports{$port_name}{data_record};
        $main::Socket_Ports{$port_name}{data_record} = undef; # Maybe this should be reset in main loop??
    }
    return $data;
}

sub said_next {
    my $port_name = $_[0]->{port_name};
    my $sock = $main::Socket_Ports{$port_name}{socka};
    my $data;
    my $datatype  = $main::Socket_Ports{$port_name}{datatype};
    my $break     = $main::Socket_Ports{$port_name}{break};
                 # Assume break on \n unless we specify datatype or break char
    unless ($datatype eq 'raw' or $break) {
        $data = <$sock>;
        chomp $data;
    }
    else {
        recv($sock, $data, 1500, 0);
    }
    return $data;
}

sub handle {
    my $port_name = $_[0]->{port_name};
    return $main::Socket_Ports{$port_name}{socka};
}

sub set_echo {
    my ($self, $echo) = @_;
    my $port_name = $self->{port_name};
    $self->{echo} = $echo;      # Not used, but for easy references
    $main::config_parms{"${port_name}_echo"} = $echo; # THIS is what gets quered by mh
}

sub set {
    my ($self, $state, $ip_address) = @_;

    return if &main::check_for_tied_filters($self, $state);

    $self->{state} = $state;

    return unless %main::Socket_Ports;

    my $socket_data;
    if (defined $self->{id_by_state}{$state}) {
        $socket_data = $self->{id_by_state}{$state};
    }
    else {
        $socket_data = $state;
    }

    my $port_name = $self->{port_name};

    print "Socket_Item: self=$self port=$port_name state=$state ip=$ip_address data=$socket_data\n" if $main::Debug{socket};

    return if $main::Save{mode} and $main::Save{mode} eq 'offline';

    unless ($main::Socket_Ports{$port_name}{sock}) {
        print "Error, socket port $port_name has not been set: data=$socket_data\n";
        return;
    }

    my @sockets;
    if ($ip_address) {
        if ($main::Socket_Ports{$port_name}{clients}) {
            if ($ip_address =~ /^\d+$/) {
                if (defined $main::Socket_Ports{$port_name}{clients}[$ip_address]) {
                    push @sockets, $main::Socket_Ports{$port_name}{clients}[$ip_address][0];
                }
                else {
                    print "Socket_Item: Error, set client ip number $ip_address is not active\n";
                }
            }
            else {
                for my $ptr (@{$main::Socket_Ports{$port_name}{clients}}) {
                    my ($socka, $client_ip_address, $client_port, $data) = @{$ptr};
                    print "Testing socket client ip address: $client_ip_address:$client_port\n" if $main::Debug{socket};
                    push @sockets, $socka if $socka and $client_ip_address =~ /$ip_address/ or
                      $ip_address eq 'all' or $ip_address eq $socka;
                }
            }
        }
        else {
            push @sockets, $main::Socket_Ports{$port_name}{socka} if $main::Socket_Ports{$port_name}{socka};
        }
    }
    else {
        push @sockets, $main::Socket_Ports{$port_name}{socka} if $main::Socket_Ports{$port_name}{socka};
    }

    unless (@sockets) {
        print "Error, socket port $port_name is not active on a socket_item set for data=$socket_data\n";
        return;
    }

                                # Dos telnet wants to see \r.  Doesn't seem to hurt
                                # unix telnet or other pgms (e.g. viavoice_server)
    my $datatype  = $main::Socket_Ports{$port_name}{datatype};
    my $break     = $main::Socket_Ports{$port_name}{break};
    $break = "\r\n" unless $break or ($datatype and $datatype =~ 'raw');
    $socket_data .= $break if defined $break;

    for my $sock (@sockets) {
        next unless $sock; # Shouldn't need this ?
        print "db print to $sock: $socket_data\n" if $main::Debug{socket};
        print $sock $socket_data;
    }

}

sub set_expect {
    my ($self, @set_expect_cmds) = @_;
    if (active $self) {
        &main::print_log("set_expect: $$self{port_name} is already active");
    }
    else {
        &main::print_log("set_expect: $$self{port_name} start");
        $self->start;
        @{$$self{set_expect_cmds}}  = @set_expect_cmds;
        $$self{set_expect_timer} = new Timer;
        $$self{set_expect_timer}-> set(10);
        &::MainLoop_pre_add_hook( \&Socket_Item::set_expect_check, 0, $self );
    }
}

sub set_expect_check {
    my ($self) = @_;
    if (my $data = said $self) {
        print "set_expect: $$self{port_name} said $data\n";
        my $prompt = quotemeta ${$$self{set_expect_cmds}}[0];
        if ($data =~ /$prompt/i) {
            my ($prompt, $cmd) =  splice @{$$self{set_expect_cmds}}, 0, 2;
            &main::print_log("set_expect: $$self{port_name} $prompt");
            $self->set($cmd . "\n");
            unless (@{$$self{set_expect_cmds}}) {
                &main::print_log("set_expect: $$self{port_name} done");
                $self->stop;
                $$self{set_expect_timer}->unset;
                &::MainLoop_pre_drop_hook( \&Socket_Item::set_expect_check );
            }
        }
    }
    if ($$self{set_expect_timer}->expired) {
        &main::print_log("set_expect: $$self{port_name} timed out");
        $self->stop;
        &::MainLoop_pre_drop_hook( \&Socket_Item::set_expect_check );
    }
}



#
# $Log: Socket_Item.pm,v $
# Revision 1.32  2004/07/18 22:16:37  winter
# *** empty log message ***
#
# Revision 1.31  2003/12/22 00:25:06  winter
#  - 2.86 release
#
# Revision 1.30  2003/04/20 21:44:07  winter
#  - 2.80 release
#
# Revision 1.29  2003/02/08 05:29:23  winter
#  - 2.78 release
#
# Revision 1.28  2003/01/12 20:39:20  winter
#  - 2.76 release
#
# Revision 1.27  2002/12/24 03:05:08  winter
# - 2.75 release
#
# Revision 1.26  2002/12/02 04:55:19  winter
# - 2.74 release
#
# Revision 1.25  2002/11/10 01:59:57  winter
# - 2.73 release
#
# Revision 1.24  2002/10/13 02:07:59  winter
#  - 2.72 release
#
# Revision 1.23  2002/09/22 01:33:23  winter
# - 2.71 release
#
# Revision 1.22  2002/07/01 22:25:28  winter
# - 2.69 release
#
# Revision 1.21  2002/03/31 18:50:39  winter
# - 2.66 release
#
# Revision 1.20  2002/03/02 02:36:51  winter
# - 2.65 release
#
# Revision 1.19  2001/06/27 03:45:14  winter
# - 2.54 release
#
# Revision 1.18  2001/02/24 23:26:40  winter
# - 2.45 release
#
# Revision 1.17  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.16  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.15  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.14  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.13  2000/06/24 22:10:54  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.12  2000/05/27 16:40:10  winter
# - 2.20 release
#
# Revision 1.11  2000/05/14 16:19:20  winter
# - add check for datatype raw
#
# Revision 1.10  2000/01/27 13:43:00  winter
# - update version number
#
# Revision 1.9  1999/12/12 23:59:12  winter
# - rename $port_name to $host_port, and allow for new $port_name parm.
#   put \r back into print $sock.
#
# Revision 1.8  1999/11/08 02:19:54  winter
# - drop \r from set print (not sure why we had that)
#
# Revision 1.7  1999/09/27 03:17:12  winter
# - add set_port, is_available, and handle methods
#
# Revision 1.6  1999/07/21 21:14:34  winter
# - add buffer methode.  Add autoflush (probably the default anyway)
#
# Revision 1.5  1999/07/05 22:34:21  winter
# - fix up debug
#
# Revision 1.4  1999/01/30 19:56:05  winter
# - enable debug only if debug parm set
#
# Revision 1.3  1999/01/24 20:03:53  winter
# - no change
#
# Revision 1.2  1999/01/23 16:30:48  winter
# - add inactive methode
#
# Revision 1.1  1999/01/13 14:10:04  winter
# - created
#
#

1;
