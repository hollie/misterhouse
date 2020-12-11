
# This module implements a wx200d network client to access data from
# the Radio Shack WX200 weather station (aka Oregon Scientific WM918).

# By David Norwood, dnorwood2@yahoo.com

# Requires the Unix wx200d program, available here:
# https://sourceforge.net/projects/wx200d

# Use these mh.ini parameters:
# wx200d_module=Weather_wx200d
# wx200d_port=localhost:9753

use strict;
use IO::Socket;
use Weather_wx200;    # required for the read_wx200 subroutine

package Weather_wx200d;

my $wx200d_socket;

sub startup {
    wx200d_connect( split ':', $main::config_parms{wx200d_port} );
    &::MainLoop_pre_add_hook( \&Weather_wx200d::update_wx200d_weather, 1 );
}

sub wx200d_connect {
    my $remote = shift || 'localhost';
    my $port   = shift || 9753;

    printf( "wx200d connect to %s port %d\n", $remote, $port );
    $wx200d_socket = IO::Socket::INET->new(
        Proto    => "tcp",
        PeerAddr => $remote,
        PeerPort => $port,
    ) or die "cannot connect to wx200d port";
}

sub update_wx200d_weather {
    my $data;

    my ( $rin, $rout );
    $rin = '';
    vec( $rin, fileno($wx200d_socket), 1 ) = 1;

    if ( select( $rout = $rin, undef, undef, 0 ) ) {
        recv $wx200d_socket, $data, 1024, 0;
        my $debug = 1 if $main::Debug{weather};
        &Weather_wx200::read_wx200( $data, \%main::Weather, $debug );
    }
}

1;
