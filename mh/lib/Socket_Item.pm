use strict;

package Socket_Item;

my (%socket_item_by_id);

sub reset {
    undef %socket_item_by_id;   # Reset on code re-load
}

sub socket_item_by_id {
    my($id) = @_;
    return $socket_item_by_id{$id};
}

sub new {
    my ($class, $id, $state, $host_port, $port_name) = @_;

    my $self = {};
    $port_name = $host_port unless $port_name;
    print "\n\nWarning: duplicate ID codes on different socket_Item objects: id=$id\n\n" if $socket_item_by_id{$id};
    $$self{port_name} = $port_name;
    $$self{host_port} = $host_port;
    &add($self, $id, $state);
    bless $self, $class;
    return $self;
}

sub set_port {
    my ($self, $host_port) = @_;
    my $port_name = $$self{port_name};
    $$self{host_port} = $host_port;
}

sub add {
    my ($self, $id, $state) = @_;
    $$self{state_by_id}{$id} = $state if $id;
    $$self{id_by_state}{$state} = $id;           # Note: State is optional
    push(@{$$self{states}}, $state);
    $socket_item_by_id{$id} = $self if $id;
#    print "db sid=", %socket_Item::socket_item_by_id, "\n";
}

sub start {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    my $host_port = $self->{host_port};
    my ($host, $port) = $host_port =~ /(\S+)\:(\S+)/;
    if ($port) {
        print "Socket Item connecting to $host on port $port\n" if $main::config_parms{debug} eq 'socket';
        if (my $sock = new IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp')) {
            $main::Socket_Ports{$port_name}{sock}  = $sock;
            $main::Socket_Ports{$port_name}{socka} = $sock;
            $sock->autoflush(1);
        }
        else {
            print "Socket_Item client start error:  could not start a tcp client socket\n";
            print " - host=$host port=$port: $@\n";
        }
    }
    else {
        print "Socket_Item client start error:  address is not in the form host:port.  open failed.  port=$port_name address=$host_port\n";
    }
}
sub stop {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    &main::socket_close($port_name);
} 

sub is_available {
    my ($self) = @_;
    my $host_port = $self->{host_port};
    my ($host, $port) = $host_port =~ /(\S+)\:(\S+)/;
    if ($port) {
        print "Socket Item testing to $host on port $port\n" if $main::config_parms{debug} eq 'socket';
        if (my $sock = new IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp')) {
            return 1;
#            $main::Socket_Ports{$port_name}{sock}  = $sock;
#            $main::Socket_Ports{$port_name}{socka} = $sock;
#            $sock->autoflush(1);
        }
        else {
            print "Socket_Item client start error:  could not start a tcp client socket on host $host port $port: $@\n";
            return 0;
        }
    }
    else {
        print "Socket_Item client start error:  address is not in the form host:port.  open failed.  address=$host_port\n";
        return 0;
    }
}

sub state {
    return @_[0]->{state};
} 

sub state_now {
    return @_[0]->{state_now};
}

sub active {
    my $port_name = @_[0]->{port_name};
    return $main::Socket_Ports{$port_name}{socka};
}

sub active_now {
    my $port_name = @_[0]->{port_name};
    return $main::Socket_Ports{$port_name}{active_this_pass};
}

sub inactive_now {
    my $port_name = @_[0]->{port_name};
    return $main::Socket_Ports{$port_name}{inactive_this_pass};
}

sub said {
    my $port_name = @_[0]->{port_name};
    
    if (my $data = $main::Socket_Ports{$port_name}{data_record}) {
        $main::Socket_Ports{$port_name}{data_record} = ''; # Maybe this should be reset in main loop??
                                                           # Should also add said to serial item
        return $data;
#       print "db socket_data: $data.\n";
    }
    else {
        return;
    }
}

sub handle {
    my $port_name = @_[0]->{port_name};
    return $main::Socket_Ports{$port_name}{socka}; 
}

sub buffer {
    my ($self, $buffer) = @_;
    my $port_name = $self->{port_name};
    $main::Socket_Ports{$port_name}{buffer} = $buffer;
}

sub set_echo {
    my ($self, $echo) = @_;
    my $port_name = $self->{port_name};
    $self->{echo} = $echo;      # Not used, but for easy references
    $main::config_parms{"${port_name}_echo"} = $echo; # THIS is what gets quered by mh
}

sub set {
    my ($self, $state) = @_;

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

    print "Socket_Item: self=$self port=$port_name state=$state data=$socket_data\n" if $main::config_parms{debug} eq 'socket';

    return if $main::Save{mode} eq 'offline';

    unless ($main::Socket_Ports{$port_name}{sock}) {
        print "Error, socket port $port_name has not been set: data=$socket_data\n";
        return;
    }
    
    my $sock = $main::Socket_Ports{$port_name}{socka};
    unless ($sock) {
        print "Error, socket port $port_name is not active on a socket_item set for data=$socket_data\n";
        return;
    }

    print "db print to $sock: $socket_data\n" if $main::config_parms{debug} eq 'socket';

                                # Dos telnet wants to see \r.  Doesn't seem to hurt
                                # unix telnet or other pgms (e.g. viavoice_server)
    print $sock $socket_data, "\r\n";
#   print $sock $socket_data, "\n";
#   print "db port=$port_name data=$socket_data\n" if $port_name eq 'speak_server';

}    


#
# $Log$
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
