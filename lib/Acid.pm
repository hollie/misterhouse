
=head1 B<Acid>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Sends callerid to Audrey acid program for dispaly.

This is called from CID_Server, which is called from code/common/callerid.pl

=head2 INHERITS

NONE

=head2 METHODS

=over

=item C<UnDoc>

=cut

use strict;
use IO::Socket;
use IO::Select;

package Acid;

my $sel;
my $udp_fh;
my %clientList = ();

BEGIN {
    $main::config_parms{Acid_UDP_Port} = 4550
      unless $main::config_parms{Acid_UDP_Port};
    $udp_fh = IO::Socket::INET->new(
        LocalPort => $main::config_parms{Acid_UDP_Port},
        Proto     => 'udp'
    ) or warn "Cant open socket  : $@\n";
    $sel = IO::Select->new();
    $sel->add($udp_fh);
}

sub read {
    my $data;
    foreach my $fh ( $sel->can_read(0) ) {
        $fh->recv( $data, 256, 0 );
        my ( $type, $port, $cid_name, $cid_number ) = &unfmt_udp_msg($data);
        my ( $clientport, $client_ip_addr ) =
          Socket::sockaddr_in( $fh->peername );
        my ( $a, $b, $c, $d ) = unpack( 'C4', $client_ip_addr );
        my $dottedip = "$a.$b.$c.$d";
        if ( $type == &CID_TYPE_SUBSCRIBE ) {
            &subscribeClient( $clientport, $dottedip );
        }
        elsif ( $type == &CID_TYPE_UNSUBSCRIBE ) {
            &unsubscribeClient($dottedip);
        }
        elsif ( $type == &CID_TYPE_INCOMING_CALL ) {
        }
        elsif ( $type == &CID_TYPE_ERROR_CALL ) {
        }
        elsif ( $type == &CID_TYPE_TEST ) {
            &pong( $dottedip, $data );
        }
        return ( $type, $port, $cid_name, $cid_number );
    }
}

sub pong {
    my ( $dottedip, $data ) = @_;
    my $ipaddr = Socket::inet_aton("$dottedip");
    my $portaddr = Socket::sockaddr_in( $clientList{$dottedip}, $ipaddr );
    defined( send( $udp_fh, $data, 0, $portaddr ) )
      || warn "send udp send failed: $!";
}

sub ping {
    my ( $dottedip, $parm1, $parm2, $parm3 ) = @_;
    my $data = fmt_udp_msg( &CID_TYPE_TEST, $parm1, $parm2, $parm3 );
    &pong( $dottedip, $data );
}

sub write {
    my ( $PacketType, $CIDName, $CIDNumber ) = @_;
    print "Sending acid $PacketType , $CIDName , $CIDNumber\n"
      if $main::Debug{phone};
    foreach my $key ( keys %clientList ) {
        my $ipaddr = Socket::inet_aton("$key");
        my $portaddr = Socket::sockaddr_in( $clientList{$key}, $ipaddr );
        my $buf = &fmt_udp_msg( $PacketType, $main::config_parms{Acid_UDP_Port},
            $CIDName, $CIDNumber );
        print "Sending data to $ipaddr, $portaddr: $buf" if $main::Debug{phone};
        defined( send( $udp_fh, $buf, 0, $portaddr ) )
          || warn "send udp failed: $!";
    }
}

sub subscribeClient {
    my ( $port, $dottedip ) = @_;
    $clientList{$dottedip} = $port;
}

sub subscribeList {
    foreach my $key ( keys %clientList ) {
        print "$key - $clientList{$key} \n";
    }
}

sub unsubscribeClient {
    my ($dottedip) = @_;
    delete $clientList{$dottedip} if ( defined( $clientList{$dottedip} ) );
}

sub fmt_udp_msg {
    my ( $type, $p1, $p2, $p3 ) = @_;
    my $buf = pack( "I I a64 a64", $type, $p1, $p2, $p3 );
    return $buf;
}

sub unfmt_udp_msg {
    my ($msg) = @_;
    my ( $type, $p1, $p2, $p3 ) = unpack( "I I Z64 Z64", $msg );
    return ( $type, $p1, $p2, $p3 );
}

sub CID_TYPE_SUBSCRIBE { return (1); }

sub CID_TYPE_UNSUBSCRIBE {
    return (2);
}    # Param2 is client computer name/address
sub CID_TYPE_INCOMING_CALL { return (3); }    # Param2 is caller's name
                                              # Param3 is caller's phone #
sub CID_TYPE_ERROR_CALL { return (4); }   # Same as of ICallerIDNotify.OnError()
                                          # Param2 is error message
sub CID_TYPE_TEST { return (5); }    # same syntax as subscribe (ping request)

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Andrew Drummond on 01/2003

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

