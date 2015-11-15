
=head1 B<audrey_cid>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Lib code to register with an audrey running the acid program (v2.0), and receive updates via udp messages on the LAN.  will need to be invoked via user code to be activated.

TODO: modify the status() approach to handle more than 1 configured audrey.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

use IO::Socket;
use IO::Select;
use strict;

package audrey_cid;
my $udp_fh;
my $sel;
my $srvr;
my $dflt_port          = 4550;    # default til we do the config lookup
my $last_recv          = 0;
my $last_subscribe     = 0;
my $status             = "";
my $subscribe_interval = 60;
my @srvr_list;
my $debug = 0;

=item C<BEGIN>

setup our udp filehandle for talking to audrey.

=cut

sub BEGIN {

    ## would like to let kernel pick the port, check syntax.

    $udp_fh = new IO::Socket::INET(
        LocalPort => $dflt_port,
        Proto     => "udp"
    );
    die "can't listen for audrey callerid" unless $udp_fh;

    $sel = IO::Select->new();

    $sel->add($udp_fh);

}

=item C<read>

function to be called by the user_code to check for new messages.

=cut

sub read {
    my $data;

    $debug && print STDERR "audrey_cid: read : checking\n";

    ## just get the first msg if there is more than one.
    foreach my $fh ( $sel->can_read(0) ) {

        $fh->recv( $data, 1000, 0 );
        my ( $type, $port, $cid_name, $cid_number ) = &unfmt_udp_msg($data);
        $last_recv = time();
        $debug && print STDERR "audrey_cid: read : msg type $type\n";

        if ( $type == &CID_TYPE_INCOMING_CALL() ) {

            $cid_number =~ s/[\(\)]//g;    # no parens in our format
            $cid_number =~ s/^\s*//g;      # no leading spaces
            $cid_number =~ s/\s*$//g;      # no trailing spaces
            $cid_number =~ s/\s+/ /g;      # no consecutive space
            $cid_number =~ s/\s/-/g;       # all rmng spaces will be dlm
            $debug && print STDERR "audrey_cid: got: $cid_name $cid_number\n";
            return ( $cid_name, $cid_number );
        }
    }
    ##(re) subscribe to the audrey occasionally in case she restarted.
    if ( $last_subscribe + $subscribe_interval < time() ) {
        &subscribe();
    }
}

=item C<subscribe>

function to be called to request updates from audrey.

=cut

sub subscribe {
    if ( $main::Startup || $main::Reload ) {    # (re)check config?
        &build_srvr_list();
    }
    my $buf = &fmt_udp_msg( &CID_TYPE_SUBSCRIBE, $udp_fh->sockport() );

    foreach my $paddr (@srvr_list) {
        defined( send( $udp_fh, $buf, 0, $paddr ) ) || die "udp send failed $!";
        &_ping_srvr($paddr);                    # and solicit a reply
    }
    $last_subscribe = time();
}

=item C<_ping_srvr>

function to be request a reply from audrey.  used to track the status of the acid program (up/down).  Not intended for use by user code (lib only)

=cut

sub _ping_srvr {
    my ($paddr) = @_;
    my $buf = &fmt_udp_msg( &CID_TYPE_TEST, $udp_fh->sockport() );
    $debug && print STDERR "audrey_cid: ping:", length($buf), "\n";

    defined( send( $udp_fh, $buf, 0, $paddr ) )
      || die "send udp send failed: $!";

}

=item C<status>

function to be called to request the status of the acid program (up/down)

=cut

sub status {

    if ($last_subscribe) {
        if ($last_recv) {
            if ( $last_subscribe > $last_recv ) {
                my $elapsed = $last_subscribe - $last_recv;
                if ( $elapsed > $subscribe_interval ) {
                    $status = "down";    # should have gotten an answer
                }
                else {
                    # don't step on the status if we
                    #   recently re-subscribed.
                }
            }
            else {
                $status = "up";    #  looks OK
            }
        }
        else {
            $status = "down";      # Never answered
        }

    }
    else {
        $status = "invalid";       # probably don't have valid config
    }
    return ($status);
}

=item C<fmt_udp_msg>

function to be called to format outbound messages

=cut

sub fmt_udp_msg {
    my ( $type, $p1, $p2, $p3 ) = @_;
    my $buf = pack( "I I a64 a64", $type, $p1, $p2, $p3 );
    $debug && print STDERR "audrey_cid: fmt: type: $type, p1: $p1\n";
    return $buf;
}

=item C<unfmt_udp_msg>

function to be called to parse inbound msg from acid into its components.

=cut

sub unfmt_udp_msg {
    my ($msg) = @_;
    my ( $type, $p1, $p2, $p3 ) = unpack( "I I Z64 Z64", $msg );
    $debug && print STDERR "audrey_cid: unfmt: type: $type, p1: $p1 \n";

    return ( $type, $p1, $p2, $p3 );
}

=item C<build_srvr_list>

build a list of paddr structures for udp sendto() based on the configured ip addresses.

=cut

sub build_srvr_list {

    $debug && print "audrey_cid: build_srvr_list: starting\n";
    @srvr_list = ();
    foreach my $key ( keys %main::config_parms ) {
        next if $key =~ /_MHINTERNAL_/;
        if ( $key =~ /^audrey_callerid/ ) {
            my $dest = $main::config_parms{$key};
            my $port = $dflt_port;
            my $host;
            ### dest can either be ip_addr (10.5.6.79)
            ###   or it can be ip:port    (10.5.6.79:4550)
            if ( $dest =~ /^(\d+\.\d+\.\d+\.\d+)(:\d+)?/ ) {
                $host = $1;
                $port = $2 if ($2);    # only if it was set
                $port =~ s/://g;    # get rid of delim
                my $hisiaddr = &main::inet_aton($host)
                  || warn "audrey_cid: build_srvr_list: [$host] is unknown";
                my $hispaddr = &main::sockaddr_in( $port, $hisiaddr );
                $debug && print STDERR "audrey_cid:srvr_list:[$host]:[$port]\n";
                push( @srvr_list, $hispaddr );
            }
        }
    }

}

=item C<CID_TYPE_XXXX()>

funtions that delineate the message types passed back and forth b/t acid client and servers.  Param1 contains client port for callback; Param2 is client computer name/address

=cut

sub CID_TYPE_SUBSCRIBE { return (1); }

sub CID_TYPE_UNSUBSCRIBE {
    return (2);
}    # Param2 is client computer name/address

sub CID_TYPE_INCOMING_CALL {
    return (3);
}    # Param2 is caller's name, Param3 is caller's phone #

sub CID_TYPE_ERROR_CALL {
    return (4);
}    # Equivalent of ICallerIDNotify .OnError() - Param2 is error message
sub CID_TYPE_TEST { return (5); }    # same syntax as subscribe (ping request)
1;

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

