
=head1 B<ncpuxa_mh>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This module is an interface for Misterhouse to access the CPU-XA,
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

package ncpuxa_mh;

use ncpuxa;
use ControlX10::CM11;    # required for dim_level_convert

my %controlsock;
my %monitorsock;
my $save_unit = 1;
my %funcs     = (
    ALL_OFF,        H,    # aka All Units OFF
    ALL_ON,         I,    # aka All Lights ON
    P,              H,    # aka All Units OFF
    O,              I,    # aka All Lights ON
    ON,             J,
    OFF,            K,
    DIM,            L,
    BRIGHT,         M,
    ALL_LIGHTS_OFF, N,
    EXTENDED_CODE,  O,
    HAIL_REQUEST,   P,
    HAIL_ACK,       Q,
    PRESET_DIM1,    R,    # aka Preset Dim 0
    EXTENDED_DATA,  S,
    STATUS_ON,      T,
    STATUS_OFF,     U,
    STATUS,         V,
    PRESET_DIM2,    W,    # aka Preset Dim 1
    L,              M,    # Misterhouse has L and M backwards
    M,              L,
);

sub init {
    my $hostport = shift;
    my ( $host, $port ) = split( ":", $hostport );
    $port = int($port);
    $controlsock{$hostport} = ncpuxa::cpuxa_connect( $host, $port );
    $monitorsock{$hostport} = ncpuxa::cpuxa_connect( $host, $port );
    ncpuxa::cpuxa_monitor( $monitorsock{$hostport} );
}

sub send {
    my $hostport = shift;
    my $data     = shift;

    if ( my ( $house, $action ) = $data =~ /^X([A-P])(.+)$/ ) {
        $data = "X" . $house . $funcs{$action} if $funcs{$action};
    }

    #Preset dim level for LM14A and Leviton units
    if ( my ( $house, $level ) = $data =~ /^X([A-P])&P(\d+)$/ ) {
        $house = unpack( 'C', $house ) - 65;    #Get code from ASCII
        $level = int($level) - 1;
        ncpuxa::send_x10_leviton_level( $controlsock{$hostport},
            $house, $save_unit, $level );
        return;
    }

    #X10 Unit code
    if ( my ( $house, $unit ) = $data =~ /^X([A-P])([0-9A-G])$/ ) {
        $house = unpack( 'C', $house ) - 65;    #Get code from ASCII
        $unit = int($unit) - 1 if $unit =~ /[1-9]/;
        $unit = unpack( 'C', $unit ) - 56 if $unit =~ /[A-G]/;
        $save_unit = $unit;
        ncpuxa::send_x10( $controlsock{$hostport}, $house, $unit, 1 );
        return;
    }

    #Standard X10 function
    if ( my ( $house, $func ) = $data =~ /^X([A-P])([H-W])$/ ) {
        $house = unpack( 'C', $house ) - 65;        #Get code from ASCII
        $func  = unpack( 'C', $func ) - 72 + 16;    #Get code from ASCII
        ncpuxa::send_x10( $controlsock{$hostport}, $house, $func, 1 );
        return;
    }

    #Dim/Bright n-percent
    if ( my ( $house, $sign, $percent ) = $data =~ /^X([A-P])([\+\-])(\d+)$/ ) {
        $house = unpack( 'C', $house ) - 65;        #Get code from ASCII
        my $repeat = int( $percent / 6.5 );
        $func = ( $sign eq '-' ? "20" : "21" );
        ncpuxa::send_x10( $controlsock{$hostport}, $house, $func, $repeat );
        return;
    }

    #Send local IR
    if ( my ($irnum) = $data =~ /^IRSlot([0-9]+)$/ ) {
        $irnum = int($irnum);
        ncpuxa::local_ir( $controlsock{$hostport}, $irnum );
        return;
    }

    #Send remote IR
    if ( my ( $irnum, $module, $zone ) =
        $data =~ /^IRSlot([0-9]+)@([0-9]+):([0-9]+)$/ )
    {
        $irnum  = int($irnum);
        $module = int($module);
        $zone   = int($zone);
        ncpuxa::remote_ir( $controlsock{$hostport}, $module, $zone, $irnum );
        return;
    }

    #Set Relay
    if ( my ( $relay, $state, undef, $module ) =
        $data =~ /^OUTPUT([0-9]+)(high|low)(@([0-9]+))?$/i )
    {
        $module = 1 unless defined $module;
        $relay  = int($relay);
        $state  = ( $state =~ /high/i ? "1" : "0" );
        ncpuxa::set_relay( $controlsock{$hostport}, $module, $relay, $state );
        return;
    }

    #Unimplemented
    print "ncpuxa_mh::send unimplemented command $data\n";
    return;
}

my $ret;
my $data;
my $code;

# 11/27/05, changed "All Lights Off" to report as O to be consistent with other modules
my %funcs = (
    '1',              '1',             '2',             '2',
    '3',              '3',             '4',             '4',
    '5',              '5',             '6',             '6',
    '7',              '7',             '8',             '8',
    '9',              '9',             '10',            'A',
    '11',             'B',             '12',            'C',
    '13',             'D',             '14',            'E',
    '15',             'F',             '16',            'G',
    'All Lights On',  'O',             'All Units Off', 'P',
    'On',             'J',             'Off',           'K',
    'Bright',         'L',             'Dim',           'M',
    'Preset Dim 0',   'PRESET_DIM1',   'Preset Dim 1',  'PRESET_DIM2',
    'All Lights Off', 'P',             'Extended Code', 'EXTENDED_CODE',
    'Hail Request',   'HAIL_REQUEST',  'Hail Ack',      'HAIL_ACK',
    'Extended Data',  'EXTENDED_DATA', 'Status On',     'STATUS_ON',
    'Status Off',     'STATUS_OFF',    'Status',        'STATUS'
);

sub read {
    my $hostport = shift;
    my $data;

    return
      unless $data = ncpuxa::cpuxa_process_monitor( $monitorsock{$hostport} );

    #foreach (keys %funcs) {print "db k=$_ v=$funcs{$_} data=$data-\n";}
    return if $data =~ /^X-10 Rx: no data available/;
    return if $data =~ /^X-10 .x: .\/Extended/;
    return if $data =~ /^IR Tx:/;
    if ( my ( $house, $func ) = $data =~ /^X-10 [RT]x: ([A-P])\/(.*)/ ) {

        #print "db data=$data h=$house f=$func fs=$funcs{$func}\n";
        $code = "X" . $house . $funcs{$func};
        return $code;
    }
    elsif ( my ($irnum) = $data =~ /^IR Rx: #([0-9]+)/ ) {
        $code = "IRSlot" . $irnum;
        return $code;
    }
    else {
        return $data;
    }
}

1;

=back

=head2 INI PARAMETERS

  ncpuxa_port=localhost:3000

Where localhost:3000 is the host and network port where cpuxad is
running.

=head2 AUTHOR

By David Norwood, dnorwood2@yahoo.com
for Misterhouse, http://www.misterhouse.com
by Bruce Winter and many contributors

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

