#  By: Bill Sobel
#  E-Mail: bsobel@vipmail.com
#
#  Based on original code by José Pedro Oliveira
#     http://gsd.di.uminho.pt/jpo/software/wakeonlan/
#     jpo@di.uminho.pt

use strict;

package WakeOnLan;

use IO::Socket qw(AF_INET SOCK_DGRAM SOL_SOCKET SO_BROADCAST);
use Socket;

my (@list_objects);

@WakeOnLan::ISA = ('Generic_Item');

sub new {
    my ( $class, $mac_address ) = @_;
    my $self = {};
    $$self{state}       = '';
    $$self{mac_address} = $mac_address;
    bless $self, $class;
    push @list_objects, $self;
    $self->set_states(qw(on));
    return $self;
}

sub setstate_on {
    my ( $self, $substate ) = @_;
    #
    # wake
    #
    # The 'magic packet' consists of 6 times 0xFF followed by 16 times
    # the hardware address of the NIC. This sequence can be encapsulated
    # in any kind of packet, in this case UDP to the discard port (9).
    #

    my $hwaddr = $self->{mac_address};
    my $ipaddr = '255.255.255.255';
    my $port   = getservbyname( 'discard', 'udp' );

    my ( $raddr, $them, $proto );
    my ( $hwaddr_re, $pkt );

    # Validate hardware address (ethernet address)

    $hwaddr_re = join( ':', ('[0-9A-Fa-f]{1,2}') x 6 );
    if ( $hwaddr !~ m/^$hwaddr_re$/ ) {
        warn "Invalid hardware address: $hwaddr\n";
        return undef;
    }

    # Generate magic sequence

    foreach ( split /:/, $hwaddr ) {
        $pkt .= chr( hex($_) );
    }
    $pkt = chr(0xFF) x 6 . $pkt x 16;

    # Alocate socket and send packet

    $raddr = gethostbyname($ipaddr);
    $them  = pack_sockaddr_in( $port, $raddr );
    $proto = getprotobyname('udp');

    socket( S, AF_INET, SOCK_DGRAM, $proto ) or die "socket : $!";
    setsockopt( S, SOL_SOCKET, SO_BROADCAST, 1 ) or die "setsockopt : $!";

    print "Sending magic packet to $ipaddr:$port with $hwaddr\n";

    send( S, $pkt, 0, $them ) or die "send : $!";
    close S;
}

sub default_setstate {
    my ( $self, $state ) = @_;

    print "WakeOnLan currently only supports the ON state\n";
    return -1;

}

#
# $Log: WakeOnLan.pm,v $
# Revision 1.3  2004/02/01 19:24:35  winter
#  - 2.87 release
#
#

1;
