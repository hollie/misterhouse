
=head1 B<ncpuxa>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This module implements a network client to access the CPU-XA,
Ocelot, and Leopard controlers from Applied Digital Inc:
http://www.appdig.com/adicon_new/index.htm

Requires cpuxad, part of the XALIB package by Mark A. Day available
here: http://mywebpages.comcast.net/ncherry/common/cpuxad/xalib-0.48.tgz

The cpuxad daemon was written to run on Unix/Linux, but Neil Cherry
has compiled the xalib package on Windows using the Cygwin tools and
made it available here:
http://mywebpages.comcast.net/ncherry/common/cpuxad/xalib-0.48_bin.tgz

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package ncpuxa;

require "ncpuxa.ph";

#use strict;
use Socket;

my @houses = ( "A" .. "P" );

my @units = ( "1" .. "16" );

my @actions = (
    "All Units Off",    # X-10 actions
    "All Lights On",
    "On",  "Off",
    "Dim", "Bright",
    "All Lights Off",
    "Extended Code",
    "Hail Request",
    "Hail Ack",
    "Preset Dim 0",
    "Extended Data",
    "Status On",
    "Status Off",
    "Status Request",
    "Preset Dim 1",
);

my @keys = ( @units, @actions );

my @states = ( "Off", "On", );    # module/point states

my @dow = (
    "Sunday",   "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday", "Saturday"
);

my @unittype =
  ( "SECU-16", "SECU-16I", "RLY08-XA", "Speak Easy", "CPU-XA", "Unknown" );

my $quiet = 1;

sub write_int {
    my $s     = shift;
    my $i     = shift;
    my $bytes = send( $s, pack( "N", $i ), 0 );
    return -ERR_SOCKWRITE() if $! < 0;
    $bytes;
}

sub read_int {
    my $s = shift;
    my $tmp;
    recv( $s, $tmp, 4, 0 );
    my $status = $!;
    my $bytes  = length($tmp);
    return -ERR_SOCKREAD() if ( $status < 0 || $bytes != 4 );
    my $i = unpack( "N", $tmp );
    $_[0] = $i;
    $bytes;
}

sub read_buf {
    my $s      = shift;
    my $length = $_[1];
    my $bytes  = recv( $s, $_[0], $length, 0 );
    return -ERR_SOCKREAD() if $! < 0;
    $bytes;
}

sub check_read_error {
    my $ret = shift;
    my $i   = shift;

    $i = -1 if ( !defined($i) );

    #printf("ncpuxa read failed: error %d, %d\n", $ret, $i) if $i != 0;
    $i != 0;
}

sub check_write_error {
    my $bytes = shift;
    $bytes != 4;
}

sub check_buf_error {
    my $ret    = shift;
    my $length = shift;
    my $buf    = shift;
    length($buf) != $length;
}

my $socket_no = 0;

sub cpuxa_connect {
    my $remote = shift || 'localhost';
    my $port   = shift || 2000;

    if ( !$quiet ) {
        printf( "cpuxa connect to %s port %d\n", $remote, $port );
    }
    my ( $iaddr, $paddr, $proto );
    if ( $port =~ /\D/ ) { $port = getservbyname( $port, 'tcp' ) }
    die "No port" unless $port;
    $iaddr = inet_aton($remote) || die "no host: $remote";
    $paddr = sockaddr_in( $port, $iaddr );

    $proto = getprotobyname('tcp');

    #	socket(SOCK, PF_INET, SOCK_STREAM, $proto) || die "socket: $!";
    #	connect(SOCK, $paddr) || die "connect: $!";
    #	read_int(*SOCK);

    #	return *SOCK;
    my $sock = $socket_no++;
    socket( $sock, PF_INET, SOCK_STREAM, $proto ) || die "socket: $!";
    connect( $sock, $paddr ) || die "connect: $!";
    read_int($sock);

    return $sock;
}

sub send_x10 {
    my $s      = shift;
    my $house  = shift;
    my $key    = shift;
    my $repeat = shift;
    my $ret;
    my $result;

    if ( !$quiet ) {
        printf( "send X-10 %s/%s\n", $houses[$house], $keys[$key] );
    }

    $ret = write_int( $s, XA_SEND_X10() );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $house );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $key );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $repeat );
    if ( check_write_error($ret) ) { return; }

    $ret = read_int( $s, $result );
    if ( check_read_error( $ret, $result ) ) { return; }

}

sub send_x10_leviton_level {
    my $s     = shift;
    my $house = shift;
    my $key   = shift;
    my $level = shift;
    my $ret;
    my $result;

    if ( !$quiet ) {
        printf( "send X-10 leviton level %s/%s %d\n",
            $houses[$house], $keys[$key], $level );
    }

    $ret = write_int( $s, XA_X10_LEVEL() );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $house );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $key );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $level );
    if ( check_write_error($ret) ) { return; }

    $ret = read_int( $s, $result );
    if ( check_read_error( $ret, $result ) ) { return; }

}

sub set_relay {
    my $s      = shift;
    my $module = shift;
    my $point  = shift;
    my $state  = shift;
    my $ret;
    my $result;

    if ( !$quiet ) {
        printf( "set relay module#%d point#%d to %d\n",
            $module, $point, $state );
    }

    $ret = write_int( $s, XA_SET_RELAY() );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $module );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $point );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $state );
    if ( check_write_error($ret) ) { return; }

    $ret = read_int( $s, $result );
    if ( check_read_error( $ret, $result ) ) { return; }
}

sub get_rtc {
    my $s = shift;
    my $ret;
    my $rtc;
    my $tmp;

    if ( !$quiet ) { printf("get CPU-XA rtc\n"); }

    $ret = write_int( $s, XA_GET_RTC() );
    if ( check_write_error($ret) ) { return; }

    $ret = read_buf( $s, $tmp, LEN_DATE() );
    if ( check_buf_error( $ret, LEN_DATE(), $rtc ) ) { return; }

    ($rtc) = $tmp =~ /([^\000]*)/;
    printf( "%s\n", $rtc );
}

sub learn_ir {
    my $s     = shift;
    my $irnum = shift;
    my $freq  = shift;
    my $ret;
    my $result;

    if ( !$quiet ) { printf( "learn IR %d at %dKhz\n", $irnum, $freq ); }

    $ret = write_int( $s, XA_LEARN_IR() );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $irnum );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $freq );
    if ( check_write_error($ret) ) { return; }

    $ret = read_int( $s, $result );
    if ( check_read_error( $ret, $result ) ) { return; }
}

sub local_ir {
    my $s     = shift;
    my $irnum = shift;
    my $ret;
    my $result;

    if ( !$quiet ) { printf( "send local IR %d\n", $irnum ); }

    $ret = write_int( $s, XA_LOCAL_IR() );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $irnum );
    if ( check_write_error($ret) ) { return; }

    $ret = read_int( $s, $result );
    if ( check_read_error( $ret, $result ) ) { return; }
}

sub remote_ir {
    my $s      = shift;
    my $module = shift;
    my $zone   = shift;
    my $irnum  = shift;
    my $ret;
    my $result;

    if ( !$quiet ) {
        printf( "send remote IR module:%d zone:%d irnum:%d\n",
            $module, $zone, $irnum );
    }

    $ret = write_int( $s, XA_REMOTE_IR() );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $module );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $zone );
    if ( check_write_error($ret) ) { return; }

    $ret = write_int( $s, $irnum );
    if ( check_write_error($ret) ) { return; }

    $ret = read_int( $s, $result );
    if ( check_read_error( $ret, $result ) ) { return; }
}

sub get_x10_states_all {
    my $s = shift;
    my $ret;
    my $h;
    my $u;
    my $state;
    my $x10states;

    if ( !$quiet ) { printf("X-10 states\n"); }

    $ret = write_int( $s, XA_X10STATES() );
    if ( check_write_error($ret) ) { return; }

    $ret = read_buf( $s, $x10states, LEN_DATA() );
    if ( check_buf_error( $ret, LEN_DATA(), $x10states ) ) { return; }

    my @states = unpack( "c*", $x10states );

    printf("\n	 ");
    for ( $u = 0; $u < LEN_X10(); $u++ ) {
        printf( "%2d  ", $u + 1 );
    }
    printf("\n");
    for ( $h = 0; $h < LEN_X10(); $h++ ) {
        printf( " %s  ", $houses[$h] );
        for ( $u = 0; $u < LEN_X10(); $u++ ) {
            if ( $states[ ( $h * LEN_X10() ) + $u ] == 1 ) {
                printf( "%-4s", "ON" );
            }
            else {
                printf( "%-4s", "--" );
            }
        }
        printf("\n");
    }
    printf("\n");
}

sub get_x10_buffered {
    my $s = shift;
    my $ret;
    my $empty = 1;
    my $h;
    my $u;
    my $x10cmd;

    while (1) {
        $ret = write_int( $s, XA_GET_X10() );
        if ( check_write_error($ret) ) { return; }

        $ret = read_buf( $s, $x10cmd, 2 );
        if ( check_buf_error( $ret, 2, $x10cmd ) ) { return; }

        ( $h, $u ) = unpack( "cc", $x10cmd );

        if ( ( $h == -1 ) || ( $u == -1 ) ) {
            if ($empty) {
                printf("X-10: buffer empty\n");
            }
            return;
        }

        if ( ( $u & 0x40 ) || ( $u & 0x80 ) ) { next; }

        $u &= 0x1f;

        if ( $u > 15 ) {
            printf( "X-10: %s/%s\n", $houses[$h], $actions[ $u - 16 ] );
        }
        else {
            printf( "X-10: %s/%d\n", $houses[$h], $u + 1 );
        }
        $empty = 0;
    }
}

sub cpuxa_monitor {
    my $s = shift;
    my $ret;

    $ret = write_int( $s, XA_MONITOR() );
    if ( check_write_error($ret) ) { return; }
}

sub cpuxa_process_monitor {
    my $s = shift;
    my $ret;
    my $data = '';

    my ( $rin, $rout );
    $rin = '';
    vec( $rin, fileno($s), 1 ) = 1;

    if ( select( $rout = $rin, undef, undef, 0 ) ) {

        # 11/20/05 dnorwood, removed MSG_DONTWAIT() in the following line because
        # it didn't work in Windows
        $ret = recv( $s, $data, LEN_PAG(), 0 );
        ($data) = $data =~ /([^\000\r\n]*)/;
    }
    return $data;
}

sub cpuxa_close {
    my $s = shift;

    write_int( $s, XA_HANGUP() );
    close($s) || die "close: $!";
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

By David Norwood, dnorwood2@yahoo.com

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

