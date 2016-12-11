
=head1 B<Network_Item>

=head2 SYNOPSIS

  use Network_Item;

  $network_house = new Network_Item('192.168.0.2',  10);
  $network_hp    = new Network_Item('192.168.0.66', 20);

  print_log "house just changed to $state" if      $state = state_changed $network_house;
  print_log "house is $state" if new_second 15 and $state = state $network_house;

Example mht entry:

  #NETWORK        IP_ADDRESS      NAME            Grouplist       Interval        MAC_ADDRESS
  NETWORK,        192.168.4.25,   HTPC_Mini,      HTPC|HomeGym,   120,    00:1C:C0:AB:CD:AE

=head2 DESCRIPTION

This object simply pings the specified address and sets its state according to status

2011-07-30 MKB Enhanced with WakeOnLan functionality

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

package Network_Item;

@Network_Item::ISA = ('Generic_Item');

use IO::Socket qw(AF_INET SOCK_DGRAM SOL_SOCKET SO_BROADCAST);
use Socket;

=item C<new($address, $interval)>

$address:  Ip address of the box you want to ping
$interval: How often to ping (in seconds)

=cut

sub new {
    my ( $class, $address, $interval, $mac_address ) = @_;
    my $self = {};
    bless $self, $class;

    my $ping_test_cmd = ($::OS_win) ? 'ping -n 1 ' : 'ping -c 1 ';
    my $ping_test_file = "$::config_parms{data_dir}/ping_results.$address.txt";

    $self->{address}     = $address;
    $self->{interval}    = $interval;
    $self->{mac_address} = $mac_address;
    $self->add_states('start');

    $self->{timer} = new Timer;
    $self->{timer}
      ->set( $self->{interval}, sub { &Network_Item::ping_check($self) }, -1 );

    $self->{process} = new Process_Item( $ping_test_cmd . $address );
    $self->{process}->set_output($ping_test_file);
    unlink $ping_test_file;
    return $self;
}

sub ping_check {
    my ($self) = @_;
    my $address = $self->{address};
    &::print_log("Network_Item ping on ip=$address") if $::Debug{network};

    $self->{process}->stop();

    my $ping_test_file = "$::config_parms{data_dir}/ping_results.$address.txt";
    if ( -e $ping_test_file ) {
        my $ping_results = &::file_read($ping_test_file);
        print "db ping_results for $address f=$ping_test_file: $ping_results\n"
          if $::Debug{network};
        my $state = ( $ping_results =~ /ttl=/i ) ? 'up' : 'down';
        if ( $self->state ne $state ) { $self->set($state); }
        unlink $ping_test_file;
    }

    $self->{process}->start();

}

sub default_setstate {
    my ( $self, $state ) = @_;
    if ( $state !~ m/^up|down|start$/i ) {
        &::print_log("Invalid state for Network_Item: $state")
          if $::Debug{network};
        return -1;
    }
    else {
        &::print_log( "Setting " . $self->{address} . " as " . $state )
          if $::Debug{network};
    }
}

sub setstate_start {
    my ( $self, $substate, $state ) = @_;
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
        &::print_log( "Missing or invalid MAC address for "
              . $self->{address} . " ( "
              . $hwaddr
              . " )" )
          if $::Debug{network};
        $state = 'down';
        $self->set_states_for_next_pass($state);
        return -1;

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

    if ( $self->state eq "start" ) {
        $state eq "down";
        $self->set($state);
    }
    &::print_log( "Setting " . $self->{address} . " substate as " . $state )
      if $::Debug{network};

    &::print_log( "Setting " . $self->{address} . " state as " . $state )
      if $::Debug{network};

}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

