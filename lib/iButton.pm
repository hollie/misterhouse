
=head1 B<iButton_Item>

=head2 SYNOPSIS

        $v_iButton_connect = new Voice_Cmd "[Connect,Disconnect] to the iButton bus";
        if ($state = said $v_iButton_connect) {
          if ($state eq 'Connect') {
            print_log &iButton::connect($config_parms{iButton_serial_port});
            print_log &iButton::connect($config_parms{iButton_2_serial_port});
          }
          else {
            print_log &iButton::disconnect;
            print_log &iButton::disconnect, $config_parms{iButton_2_serial_port};
          }
        }

        $ib_bruce  = new iButton '010000012345ef';
        speak 'Hi Bruce'  if ON  eq state_now $ib_bruce;
        speak 'Later'     if OFF eq state_now $ib_bruce;

        $ib_relay1 = new iButton '12000000123456ff', undef, 'A';
        $ib_relay2 = new iButton '12000000123456ff', undef, 'B';
        $v_iButton_relay1    = new Voice_Cmd "Turn relay1 [on,off]";
        if ($state = said $v_iButton_relay1) {
           print_log "Setting iButton relay1 to $state";
           set $ib_relay1 $state;
        }

        $ib_temp1  = new iButton '1000000029a14f', $config_parms{iButton_2_serial_port};
        $ib_temp2  = new iButton '1000000029f5d6';
        my @ib_temps = ($ib_temp1, $ib_temp2);

        $v_iButton_readtemp  = new Voice_Cmd "Read the iButton temperature [1,2]";
        if ($state = said $v_iButton_readtemp) {
           my $b = $ib_temps[$state-1];
           my $temp = read_temp $b;
           print_log "Temp for sensor $state: $temp F";
           logit("$config_parms{data_dir}/iButton_temps.log",  "$state: $temp");
        }
        if ($New_Second and !($Minute % 5)) {
           run_voice_cmd 'Read the iButton temperature 1' if $Second == 11;
           run_voice_cmd 'Read the iButton temperature 2' if $Second == 22;
        }

=head2 DESCRIPTION

This is used to query and/or control an iButton device

For more information on iButton see the hardware section

This uses the iButton perl modules from: http://www.lothar.com/tech/iButtons/

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over 

=item C<new($id, $port, $channel)>

If $port is not specified, the port of the first iButton::connect will be used.
$channel (used for switches like the DS2406) defaults to A

=item C<set($state)>

Sets the item to the specified state.

=item C<state)>

Returns the last state that was received or sent

=item C<state_now>

Returns the state that was received or sent in the current pass.

=item C<state_log>

Returns a list array of the last max_state_log_entries (mh.ini parm) time_date stamped states.

=item C<read_temp>

Returns the temperature of temperature devices.

=item C<read_switch>

Reads iButton switch data

=item C<read_windspeed>

Reads iButton weather station wind speed

=item C<read_dir>

Reads iButton weather station wind direction

=back

In addition to the above, all of the methods provided by the Hardware/iButton/Device.pm module are available (documented in mh/lib/site/Hardware/iButton/Device.pm).

These functions are also part of the iButton module, but not associated with an object:

=over

=item C<scan($family, $port)>

Returns a object list of iButton devices that match $family

=item C<scan_report($family, $port)>

Returns a report of iButton devices that match $family

=item C<monitor($family, $port)>

Checks the one wire bus for iButton activity

=item C<connect($port)>

Connect to the one wire bus.  Note you can now have multiple iButton interfaces on multiple COM ports.

=item C<disconnect>

Disconnect to the one wire bus

=back

Note, all of these functions take an optional $port parm (required for connect). If not specified, the port of the first connect record will be used.

The $id required when creating new iButton_Item is the 16 hex character (64 bit) iButton id that is unique to every device. This is often printed on the larger devices. If not, you can use:

        $v_iButton_list      = new Voice_Cmd "List all the iButton buttons";
        print_log &iButton::scan_report if said $v_iButton_list;

The last 2 characters are CRC bits and are optional. If missing (i.e. you only specify the first 14 characters), mh will calculate it.

The first 2 characters are the iButton family type. Here is a list of family types:

         Field Index:
          ------------
          (1) Family code in hex
          (2) Number of regular memory pages
          (3) Length of regular memory page in bytes
          (4) Number of status memory pages
          (5) Length of status memory page in bytes
          (6) Max communication speed (0 regular, 1 Overdrive)
          (7) Memory type (see below)
          (8) Part number in iButton package
          (9) Part number in non-iButton package
          (10) Brief descriptions

          (1)   (2)  (3)  (4)  (5)  (6)  (7)   (8)   (9)   (10)
          -------------------------------------------------------
          01,    0,   0,   0,   0,   1,   0, DS1990A,DS2401,Unique Serial Number
          02,    0,   0,   0,   0,   0,   0, DS1991,DS1205, MultiKey iButton
          04,   16,  32,   0,   0,   0,   1, DS1994,DS2404,4K-bit NVRAM with Clock
          05,    0,   0,   0,   0,   0,   0, DS2405,,Single Addressable Switch
          06,   16,  32,   0,   0,   0,   1, DS1993,DS2403,4K-bit NVRAM
          08,    4,  32,   0,   0,   0,   1, DS1992,DS2402,1K-bit NVRAM
          09,    4,  32,   1,   8,   1,   2, DS1982,DS2502,1K-bit EPROM
          0A,   64,  32,   0,   0,   1,   1, DS1995,DS2416,16K-bit NVRAM
          0B,   64,  32,  40,   8,   1,   3, DS1985,DS2505,16K-bit EPROM
          0C,  256,  32,   0,   0,   1,   1, DS1996,DS2464,64K-bit NVRAM
          0F,  256,  32,  64,   8,   1,   3, DS1986,DS2506,64K-bit EPROM
          10,    0,   0,   0,   0,   0,   0, DS1920,DS1820,Temperature iButton with Trips
          11,    2,  32,   1,   8,   0,   2, DS1981,DS2501,512-bit EPROM
          12,    4,  32,   1,   8,   0,   4, DS2407,,Dual Addressable Switch
          13,   16,  32,  34,   8,   0,   3, DS1983,DS2503,4K-bit EPROM
          14,    1,  32,   0,   0,   0,   5, DS1971,DS2430A,256-bit EEPROM, plus
          64-bit
          OTP
          15,    0,   0,   0,   0,   1,   0, DS87C900,,Lock Processor
          16,    0,   0,   0,   0,   0,   0, DS1954,,Crypto iButton
          18,    4,  32,   0,   0,   1,   6, DS1963S,4K-bit Transaction iButton with
          SHA
          1A,   16,  32,   0,   0,   1,   6, DS1963,,4K-bit Transaction iButton
          1C,    4,  32,   0,   0,   1,   6, DS2422,,1K-bit EconoRAM with Counter
          Input
          1D,   16,  32,   0,   0,   1,   6, DS2423,,4K-bit EconoRAM with Counter
          Input
          1F,    0,  32,   0,   0,   0,   0, DS2409,,One-Wire Net Coupler
          20,    3,   8,   0,   0,   1,   9, DS2450,,Quad A-D Converter
          21,   16,  32,   0,   0,   1,   8, DS1921,,Temperature Recorder iButton
          23,   16,  32,   0,   0,   1,   7, DS1973,DS2433,4K-bit EEPROM
          22                                 DS1822 temperature button
          40,   16,  32,   0,   0,   0,   1, DS1608,,Battery Pack Clock

=cut

use strict;

package iButton;

@iButton::ISA = ('Generic_Item');

my ( %connections, %objects_by_id, %buttons_active );

#
#  Create serial port(s) according to mh.ini
#

use Hardware::iButton::Connection;

sub serial_startup {
    my ($instance) = @_;
    my $port = $main::config_parms{ $instance . "_serial_port" };
    &iButton::connect($port) if $port;
}

sub usleep {
    my ($usec) = @_;

    #   print "sleep2 $usec\n";
    select undef, undef, undef, ( $usec / 10**6 );
}

sub new {
    my ( $class, $id, $port, $channel ) = @_;

    # add the iButton class as a parent of the Hardware::iButton::Device class
    my $parentAdded = 0;
    foreach my $i (@Hardware::iButton::Device::ISA) {
        $parentAdded = 1 if $i eq $class;
    }
    push @Hardware::iButton::Device::ISA, $class if !$parentAdded;

    # iButton::Device needs to see a mucked up binary string

    # Allow for a full string, or missing button type and/or missing crc
    #$ib_bruce  = new iButton '0100000546e3fc7a';
    #$ib_bruce  = new iButton '0100000546e3fc';
    #$ib_bruce  = new iButton '00000546e3fc';

    $id = '01' . $id
      if ( length $id ) == 12;    # Assume a simple button, if prefix is missing

    my $raw_id = pack 'H16', $id;
    my $family = substr( $raw_id, 0, 1 );
    my $serial = substr( $raw_id, 1, 6 );
    my $crc    = substr( $raw_id, 7, 1 );

    $raw_id =
      unpack( 'b8', $family ) . scalar( reverse( unpack( 'B48', $serial ) ) );

    # If the crc was not given, lets calculate it
    if ( length $id == 14 ) {
        $crc = Hardware::iButton::Connection::crc( 0,
            split( //, pack( "b*", $raw_id ) ) );
        $crc = pack 'C', $crc;
    }
    $raw_id .= unpack( 'b8', $crc );

    $port = $connections{default} unless $port;
    my $connection = $connections{$port} if $port;

    my $self = Hardware::iButton::Device->new( $connection, $raw_id );

    $self->{port}    = $port;
    $self->{channel} = $channel;

    $id = $self->id();             # Get the full id
    $objects_by_id{$id} = $self;

    $$self{state} = '';    # Will only be listed on web page if state is defined

    if ( $self->model() eq 'DS2406' ) {
        push( @{ $$self{states} }, 'on', 'off' );
    }

    return $self;
}

# Called on mh startup
sub connect {
    my ($port) = @_;

    $port = '\\\\.\\' . $port
      if $main::Info{OS_name} eq 'NT' and $port =~ /^com\d{2}\z/i;

    # The first port used is the default
    $connections{default} = $port unless $connections{default};

    if ( $port =~ /proxy/i ) {
        $connections{$port} = 'proxy';
        return 'iButton Proxy used';
    }

    if ( $connections{$port} && $connections{$port}->connected() ) {
        return 'iBbutton bus is already connected';
    }
    elsif ( !$connections{$port} ) {
        printf " - creating %-15s object on port %s\n", 'Ibutton', $port;
        $connections{$port} = new Hardware::iButton::Connection(
            $port, $main::Debug{ibutton},
            $main::config_parms{ibutton_tweak},
            uc( $main::config_parms{ibutton_line_length} )
        ) or print "iButton connection error to port $port: $!";
    }
    else {
        $connections{$port}->openPort;
    }

    return 'iButton connection has been made';
}

sub disconnect {
    my ($port) = @_;
    $port = $connections{default} unless $port;

    return 'Have never connected to iButton bus' unless $connections{$port};
    return 'Proxy used, disconnect ignored' if $connections{$port} eq 'proxy';

    if ( !$connections{$port}->connected() ) {
        return 'iButton bus is already disconnected';
    }
    else {
        $connections{$port}->closePort();
        return 'iButton bus has been disconnected';
    }
}

# This is called to monitor state changes (e.g. mh/code/common/iButton.pl)
sub monitor {
    my ( $family, $port ) = @_;
    $port = $connections{default} unless $port;
    return unless $connections{$port};
    return if $connections{$port} eq 'proxy';

    my ( @ib_list, $count, $ib, $id, $object, %buttons_dropped );

    #   @ib_list = &scan;
    #   print "db calling scan\n";
    @ib_list = &scan( $family, $port );    # monitor just the button devices
    $count = @ib_list;

    #   print "ib count=$count l=@ib_list.\n";
    %buttons_dropped = %{ $buttons_active{$port} } if $buttons_active{$port};

    #   print "db read $count devices\n";
    for $ib (@ib_list) {
        $id     = $ib->id;
        $object = $objects_by_id{$id};
        if ( $buttons_active{$port}{$id} ) {
            delete $buttons_dropped{$id};
        }
        else {
            print "New device: $id\n";
            $buttons_active{$port}{$id}++;
            set_receive $object 'on' if $object;
        }
    }
    for my $id ( sort keys %buttons_dropped ) {
        print "Device dropped: $id\n";
        delete $buttons_active{$port}{$id};
        set_receive $object 'off' if $object = $objects_by_id{$id};
    }
}

# This method is implemented in lib/site/Hardware/iButton/Device.pm, which has precidence ?
sub read_switch {
    my ($self) = @_;
    my $connection;
    return unless $connection = $connections{ $self->{port} };

    #    $Hardware::iButton::Connection::debug = 1;

    if ( $self->model() eq 'DS2406' ) {    #switch

        $self->reset;
        $self->select;
        $connection->mode("\xe1");                # DATA_MODE
        $connection->send("\xf5\x58\xff\xff");    # channel access, ccb1, ccb2
        $connection->read(3);
        my $byte = unpack( "b", $connection->read(1) );

        #print unpack("b",$byte);
        $connection->reset;

        #        $Hardware::iButton::Connection::debug = 0;
        return $byte;
    }
    else {
        print "bad family for read_switch\n";
    }

    #    $Hardware::iButton::Connection::debug = 0;

}

sub toggle_switch_2405 {
    my ($self) = @_;
    my $connection;
    return unless $connection = $connections{ $self->{port} };

    #    $Hardware::iButton::Connection::debug = 1;

    if ( $self->model() eq 'DS2405' ) {    #switch

        $self->reset;
        $self->select;
        $connection->mode("\xe3");         # COMMAND_MODE (is this correct?)
        $connection->send("\x55");         # This should toggle the switch
        $connection->read(3);              # How many bytes should I read here?
        my $byte = unpack( "b", $connection->read(1) )
          ;                                # This reads one more byte, I think.
        print unpack( "b", $byte );
        $connection->reset;

        #        $Hardware::iButton::Connection::debug = 0;
        return $byte;
    }
    else {
        print "bad family for toggle_switch_2405\n";
    }

    #    $Hardware::iButton::Connection::debug = 0;

}

sub read_temp {
    my ($self) = @_;
    return unless $connections{ $self->{port} };

    if ( $connections{ $self->{port} } eq 'proxy' ) {
        &main::proxy_send( $self->{port}, 'ibutton', 'read_temp',
            $$self{object_name} );
        return $self->{state}
          ;    # This is the previous  temp, but better than nothing.
    }

    my $temp = $self->read_temperature_hires();
    return wantarray ? () : undef if !defined $temp;

    my $temp_c = sprintf( "%3.2f", $temp );
    my $temp_f = sprintf( "%3.2f", &::convert_c2f($temp) );
    my $temp_def =
      ( $main::config_parms{weather_uom_temp} eq 'C' ) ? $temp_c : $temp_f;

    set_receive $self $temp_def;

    return wantarray ? ( $temp_f, $temp_c ) : $temp_def;
}

sub scan {
    my ( $family, $port ) = @_;
    $port = $connections{default} unless $port;
    return unless $connections{$port};

    if ( $connections{$port} eq 'proxy' ) {
        return 'not implemented';
    }

    my @list = $connections{$port}->scan($family);
    return if $list[0] == undef;
    return @list;
}

sub scan_report {
    my ( $family, $port ) = @_;
    $port = $connections{default} unless $port;
    return unless $connections{$port};

    if ( $connections{$port} eq 'proxy' ) {
        return
          unless &main::proxy_send( $port, 'ibutton', 'scan_report', $family );
        return join( "\n", &main::proxy_receive($port) );
    }

    my @ib_list = &iButton::scan( $family, $port );
    my $report;
    for my $ib (@ib_list) {
        $report .=
            "Device type:"
          . $ib->family() . "  ID:"
          . $ib->serial
          . "  CRC:"
          . $ib->crc . ": "
          . $ib->model() . "\n";
    }
    return $report;
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    my $connection;

    return -1 unless $connection = $connections{ $self->{port} };

    #   $connection->reset;
    $self->select;
    $self->{state} = $state;

    #   $Hardware::iButton::Connection::debug = 1;
    if ( $self->model() eq 'DS2406' ) {

        # New way
        my $channel = $self->{channel};
        $channel = 'A' unless $channel;
        $channel = 'CHANNEL_' . uc $channel;
        $state   = ( $state eq 'off' ) ? 0 : 1;

        #       print "dbx setting relay $channel to $state\n";
        $self->set_switch( $channel => $state )

          # Old way
          #       $state = ($state eq 'on') ? "\x00\x00" : "\xff\xff";
          #       $connection->mode("\xe1");           # DATA_MODE
          #       $connection->send("\xf5\x0c\xff");
          #       $connection->send($state);
          #       usleep(10);

    }

    #   $Hardware::iButton::Connection::debug = 0;
}

sub set_receive {
    my ( $self, $state ) = @_;

    &main::iButton_receive_hooks( $self, $state );    # Created by &add_hooks

    &Generic_Item::set_states_for_next_pass( $self, $state );
}

sub _connections {
    return %connections;
}

package iButton::Weather;
@iButton::Weather::ISA = ('iButton');

sub new {
    my $class       = shift;
    my %ARGS        = @_;
    my %connections = iButton::_connections();

    my $this;

    my $port = $ARGS{PORT} ? $ARGS{PORT} : $connections{default};
    $this->{PORT} = $port;

    # Check to see that we have enough 01 chips
    my @windsensors;
    my @windcounters;
    my @windswitch;
    my @tempsensors;
    foreach my $i ( @{ $ARGS{"CHIPS"} } ) {
        my $ibutton = new iButton( $i, $port );

        push @windsensors,  $ibutton if uc( substr( $i, 0, 2 ) ) eq "01";
        push @windswitch,   $ibutton if uc( substr( $i, 0, 2 ) ) eq "12";
        push @windcounters, $ibutton if uc( substr( $i, 0, 2 ) ) eq "1D";
        push @tempsensors,  $ibutton if uc( substr( $i, 0, 2 ) ) eq "10";
    }

    die "Need 8 01 chips!\n"              if $#windsensors != 7;
    die "Need a 1D counter!\n"            if $#windcounters != 0;
    die "Need a 12 switch!\n"             if $#windswitch != 0;
    die "Need a 10 temperature sensor!\n" if $#tempsensors != 0;

    $this->{"01"} = [@windsensors];
    $this->{"1D"} = $windcounters[0];
    $this->{"12"} = $windswitch[0];
    $this->{"10"} = $tempsensors[0];

    my %dirs;
    my $count = 0;
    foreach my $i (@windsensors) {
        $dirs{ $i->id() } = $count;
        $count += 2;
    }

    $this->{"DIRS"} = \%dirs;

    bless $this, $class;
}

sub read_temp {
    my $this = shift;

    my $temp = $this->{"10"}->read_temperature_hires();

    return if !defined $temp;

    my $temp_c = sprintf( "%3.2f", $temp );
    my $temp_f = sprintf( "%3.2f", &::convert_c2f($temp) );
    my $temp_def =
      ( $main::config_parms{weather_uom_temp} eq 'C' ) ? $temp_c : $temp_f;

    $this->set_receive($temp_def);

    return wantarray ? ( $temp_f, $temp_c ) : $temp_def;
}

sub read_windspeed {
    my $this = shift;

    # use these constants to multiply with the revolutions
    #define METER_PER_SECOND        1.096
    #define KMS_PER_HOUR                    3.9477
    #define MILES_PER_HOUR                  2.453
    #define KNOTS                                   2.130

    if ( !defined $this->{PREVCOUNT} ) {
        $this->{PREVCOUNT} = $this->{"1D"}->read_counter(3);
        return undef if !defined $this->{PREVCOUNT};

        $this->{PREVTIME} = &main::get_tickcount() / 1000;
        select undef, undef, undef, 0.5;
    }

    my $count = $this->{"1D"}->read_counter(3);
    return undef if !defined $count;

    my $time = &main::get_tickcount() / 1000;

    my $rev =
      ( ( $count - $this->{PREVCOUNT} ) / ( $time - $this->{PREVTIME} ) ) / 2.0;
    $this->{PREVTIME}  = $time;
    $this->{PREVCOUNT} = $count;

    my $speed = $rev * 2.453;    # This is the MPH constant
    $this->set_receive($speed);
    return $speed;
}

sub read_dir {
    my $this        = shift;
    my %connections = iButton::_connections();

    $this->{"12"}->set_switch( CHANNEL_B => 1 );
    my $c = $connections{ $this->{PORT} };

    my @iButtons = $c->scan("01");
    $this->{"12"}->set_switch( CHANNEL_B => 1 );

    my @dirs;
    for ( 1 .. 10 ) {
        my @iButtons = $c->scan("01");
        foreach my $i (@iButtons) {
            my $id = $i->id();
            push @dirs, $this->{DIRS}->{$id} if defined $this->{DIRS}->{$id};
        }

        last if $#dirs >= 0;
    }

    $this->{"12"}->set_switch( CHANNEL_B => 0 );

    my $dir;
    if ( $#dirs == 0 ) {
        $dir = $dirs[0];
    }
    elsif ( $#dirs == 1 ) {
        @dirs = sort @dirs;
        if ( $dirs[0] == 0 && $dirs[1] == 14 ) {
            $dir = 15;
        }
        else {
            $dir = ( $dirs[0] + $dirs[1] ) / 2;
        }
    }
    else {
        warn "Got $#dirs direction readings\n";
        $this->{"12"}->set_switch( CHANNEL_B => 0 );
        return undef;
    }

    my %DIRS = (
        0  => "N",
        1  => "NNE",
        2  => "NE",
        3  => "ENE",
        4  => "E",
        5  => "ESE",
        6  => "SE",
        7  => "SSE",
        8  => "S",
        9  => "SSW",
        10 => "SW",
        11 => "WSW",
        12 => "W",
        13 => "WNW",
        14 => "NW",
        15 => "NNW",
    );

    $this->set_receive( $DIRS{$dir} );
    $this->{"12"}->set_switch( CHANNEL_B => 0 );
    return $DIRS{$dir};
}

return 1;    # for require

__END__

Got this from the tini@ibutton.com list on 3/00:

Field Index:
------------
(1) Family code in hex
(2) Number of regular memory pages
(3) Length of regular memory page in bytes
(4) Number of status memory pages
(5) Length of status memory page in bytes
(6) Max communication speed (0 regular, 1 Overdrive)
(7) Memory type (see below)
(8) Part number in iButton package
(9) Part number in non-iButton package
(10) Brief descriptions

(1)   (2)  (3)  (4)  (5)  (6)  (7)   (8)   (9)   (10)
-------------------------------------------------------
01,    0,   0,   0,   0,   1,   0, DS1990A,DS2401,Unique Serial Number
02,    0,   0,   0,   0,   0,   0, DS1991,DS1205, MultiKey iButton
04,   16,  32,   0,   0,   0,   1, DS1994,DS2404,4K-bit NVRAM with Clock
05,    0,   0,   0,   0,   0,   0, DS2405,,Single Addressable Switch
06,   16,  32,   0,   0,   0,   1, DS1993,DS2403,4K-bit NVRAM
08,    4,  32,   0,   0,   0,   1, DS1992,DS2402,1K-bit NVRAM
09,    4,  32,   1,   8,   1,   2, DS1982,DS2502,1K-bit EPROM
0A,   64,  32,   0,   0,   1,   1, DS1995,DS2416,16K-bit NVRAM
0B,   64,  32,  40,   8,   1,   3, DS1985,DS2505,16K-bit EPROM
0C,  256,  32,   0,   0,   1,   1, DS1996,DS2464,64K-bit NVRAM
0F,  256,  32,  64,   8,   1,   3, DS1986,DS2506,64K-bit EPROM
10,    0,   0,   0,   0,   0,   0, DS1920,DS1820,Temperature iButton with
Trips
11,    2,  32,   1,   8,   0,   2, DS1981,DS2501,512-bit EPROM
12,    4,  32,   1,   8,   0,   4, DS2407,,Dual Addressable Switch
13,   16,  32,  34,   8,   0,   3, DS1983,DS2503,4K-bit EPROM
14,    1,  32,   0,   0,   0,   5, DS1971,DS2430A,256-bit EEPROM, plus
64-bit
OTP
15,    0,   0,   0,   0,   1,   0, DS87C900,,Lock Processor
16,    0,   0,   0,   0,   0,   0, DS1954,,Crypto iButton
18,    4,  32,   0,   0,   1,   6, DS1963S,4K-bit Transaction iButton with
SHA
1A,   16,  32,   0,   0,   1,   6, DS1963,,4K-bit Transaction iButton
1C,    4,  32,   0,   0,   1,   6, DS2422,,1K-bit EconoRAM with Counter
Input
1D,   16,  32,   0,   0,   1,   6, DS2423,,4K-bit EconoRAM with Counter
Input
1F,    0,  32,   0,   0,   0,   0, DS2409,,One-Wire Net Coupler
20,    3,   8,   0,   0,   1,   9, DS2450,,Quad A-D Converter
21,   16,  32,   0,   0,   1,   8, DS1921,,Temperature Recorder iButton
23,   16,  32,   0,   0,   1,   7, DS1973,DS2433,4K-bit EEPROM
40,   16,  32,   0,   0,   0,   1, DS1608,,Battery Pack Clock


Memory Types:
--------------
0 NOMEM - no user storage space or with
          non-standard structure.
1 NVRAM - non-volatile rewritable RAM.
2 EPROM1- EPROM (OTP).
          Contains an onboard 8-bit CRC data check.
3 EPROM2 - EPROM (OTP). TMEX Bitmap starting on status page 8
           Contains an onboard 16-bit CRC.
4 EPROM3 - EPROM (OTP). TMEX Bitmap in upper nibble of byte 0 of status
memory
           Contains an onboard 16-bit CRC data check.
5 EEPROM1 - EEPROM, one address byte
6 MNVRAM - non-volatile rewritable RAM with read-only non rolling-over page
           write cycle counters associated with last 1/4 of pages
           (3 minimum)
7 EEPROM2 - EEPROM. On board CRC16 for Write/Read memory.
            Copy Scratchpad returns an authentication byte (alternating
1/0).
8 NVRAM2 - non-volatile RAM. Contains an onboard 16-bit CRC.
9 NVRAM3 - non-volatile RAM with bit accessible memory.  Contains an onboard

           16-bit CRC.
----------------------------------------------------------------------------


=head2 INI PARAMETERS

To enable iButton support in mh, set the mh.ini parm ibutton_serial_port.

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut


# $Log: iButton.pm,v $
# Revision 1.24  2005/01/23 23:21:46  winter
# *** empty log message ***
#
# Revision 1.23  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.22  2003/04/20 21:44:08  winter
#  - 2.80 release
#
# Revision 1.21  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.20  2002/12/02 04:55:21  winter
# - 2.74 release
#
# Revision 1.19  2002/10/13 02:07:59  winter
#  - 2.72 release
#
# Revision 1.18  2002/09/22 01:33:24  winter
# - 2.71 release
#
# Revision 1.17  2002/05/28 13:07:52  winter
# - 2.68 release
#
# Revision 1.16  2002/03/02 02:36:51  winter
# - 2.65 release
#
# Revision 1.15  2002/01/19 21:11:12  winter
# - 2.63 release
#
# Revision 1.14  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.13  2001/10/21 01:22:32  winter
# - 2.60 release
#
# Revision 1.12  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.11  2001/08/12 04:02:58  winter
# - 2.57 update
#
# Revision 1.10  2001/05/06 21:07:26  winter
# - 2.51 release
#
# Revision 1.9  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.8  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.7  2001/01/20 17:47:50  winter
# - 2.41 release
#
# Revision 1.6  2000/11/12 21:02:38  winter
# - 2.34 release
#
# Revision 1.5  2000/10/09 02:31:13  winter
# - 2.30 update
#
# Revision 1.4  2000/08/19 01:25:08  winter
# - 2.27 release
#
# Revision 1.3  2000/06/24 22:10:55  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.2  2000/05/06 16:34:32  winter
# - 2.15 release
#
# Revision 1.1  2000/04/09 18:03:19  winter
# - 2.13 release
#
#
