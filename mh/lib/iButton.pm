use strict;

# This uses the iButton perl modules from: http://www.lothar.com/tech/iButtons/

package iButton;

my ($connection, %objects_by_id, %buttons_active, @states_from_previous_pass, @reset_states);

sub usleep {
    my($usec) = @_;
#   print "sleep2 $usec\n";
    select undef, undef, undef, ($usec / 10**6);
}

sub new {
    my ($class, $id) = @_;

                                # iButton::Device needs to see a mucked up binary string

                                # Allow for a full string, or missing button type and/or missing crc
#$ib_bruce  = new iButton '0100000546e3fc7a';
#$ib_bruce  = new iButton '0100000546e3fc';
#$ib_bruce  = new iButton '00000546e3fc';

    $id = '01' . $id if (length $id) == 12; # Assume a simple button, if prefix is missing

    my $raw_id = pack 'H16', $id;
    my $family = substr($raw_id, 0, 1);
    my $serial = substr($raw_id, 1, 6);
    my $crc    = substr($raw_id, 7, 1);

    $raw_id = unpack('b8', $family) . scalar(reverse(unpack('B48', $serial)));

                                # If the crc was not given, lets calculate it
    if (length $id == 14) {
        $crc = Hardware::iButton::Connection::crc(0, split(//, pack("b*", $raw_id)));
        $crc = pack 'c', $crc;
    }
    $raw_id .= unpack('b8', $crc);

 	my $self = Hardware::iButton::Device->new($connection, $raw_id);

    bless $self, $class;

    my $id = $self->{id};       # Get the full id
    $objects_by_id{$id} = $self;


    if ($self->{model} eq 'DS1920' ) {
        @iButton::ISA = ("Hardware::iButton::Device::DS1920");
    }
    elsif ($self->{model} eq 'DS2423') {
	@iButton::ISA = ("Hardware::iButton::Device::DS2423");
    }
    elsif ($self->{model} eq 'DS2406' ) {
        @iButton::ISA = ("Hardware::iButton::Device");
                                # Used by Tk items pulldown
        push(@{$$self{states}}, 'on', 'off'); 

    }
    else {
        @iButton::ISA = ("Hardware::iButton::Device");
    }

    return $self;
}

                                # Called on mh startup
sub connect {
    my ($port) = @_;
    if ($connection) {
        return 'iBbutton bus is already connected';
    }
    print "Creating iButton Connection on port $port\n";
    $connection = new Hardware::iButton::Connection $port or
        print "iButton connection error to port $port: $!";

    if ($connection) {
#        print "Reseting iButton connection: $connection\n";
        $connection->reset();
    }
    return 'iButton connection has been made';
}

sub disconnect {
    if (!$connection) {
        return 'iButton bus is already disconnected';
    }
    else {
        my $serialport = $connection->{s};
        $serialport->close;
        undef $connection;
        return 'iButton bus has been disconnected';
    }
}

                                # Called for each mh loop
sub monitor {
    return unless $connection;
    my (@ib_list, $count, $ib, $id, $object, %buttons_dropped);
#   @ib_list = &scan;
    @ib_list = &scan(01);       # monitor just the button devices
    $count = @ib_list;
#   print "ib count=$count l=@ib_list.\n";
    %buttons_dropped = %buttons_active;
    for $ib (@ib_list) {
        $id = $ib->id;
        $object = $objects_by_id{$id};
        if ($buttons_active{$id}) {
            delete $buttons_dropped{$id};
        }
        else {
            print "New device: $id\n";
            $buttons_active{$id}++;
            set_receive $object 'on' if $object;
        }
    }
    for my $id (sort keys %buttons_dropped) {
        print "Device dropped: $id\n";
        delete $buttons_active{$id};
        set_receive $object 'off' if $object = $objects_by_id{$id};
    }
}

sub read_switch {
    return unless $connection;
    my ($self,) = @_;

#    $Hardware::iButton::Connection::debug = 1;

    if ($self->{model} eq 'DS2406' ) {			#switch

        $self->reset;
        $self->select;
        $connection->mode("\xe1");               # DATA_MODE
        $connection->send("\xf5\x58\xff\xff");   # channel access, ccb1, ccb2
        $connection->read(3);
        my $byte = unpack("b",$connection->read(1));
        #print unpack("b",$byte);
        $connection->reset;
#        $Hardware::iButton::Connection::debug = 0;
        return $byte;
    } else {
        print "bad family for read_switch\n";
    }
#    $Hardware::iButton::Connection::debug = 0;

}

sub read_temp {
    return unless $connection;
    my ($self) = @_;
    @iButton::ISA = ("Hardware::iButton::Device::DS1920"); # ??

    my $temp = $self->read_temperature_hires();

    return if $temp < -200 or $temp > 200; # Bad data for whatever reason

    my $temp_c = sprintf("%3.2f", $temp);
    my $temp_f = sprintf("%3.2f", $temp*9/5 +32);


    set_receive $self $temp_f;

    return wantarray ? ($temp_f, $temp_c) : $temp_f;
}

sub scan {
    return unless $connection;
    my ($family) = @_;
    my @list = $connection->scan($family);
    return if $list[0] == undef;
    return @list;
}

sub scan_report {
    return unless $connection;
    my ($family) = @_;
    my @ib_list = &iButton::scan($family);
    my $report;
    for my $ib (@ib_list) {
        $report .= "Device type:" . $ib->family . "  ID:" .
            $ib->serial . "  CRC:" . $ib->crc . ": " . $ib->model() . "\n";
    }
    return $report;
}

sub set {
    return unless $connection;
    my ($self, $state) = @_;
#    $connection->reset;
    $self->select;
    $self->{state} = $state;

#    $Hardware::iButton::Connection::debug = 1;

    if ($self->{model} eq 'DS2423') {			#counter

    }
    elsif ($self->{model} eq 'DS2406' ) {			#switch

        $state = ($state eq 'on') ? "\x00\x00" : "\xff\xff";
        $connection->mode("\xe1");           # DATA_MODE
        $connection->send("\xf5\x0c\xff");
        $connection->send($state);
        usleep(10);

    }
#    $Hardware::iButton::Connection::debug = 0;
}

sub set_receive {
    my ($self, $state) = @_;
                                # Only add to the list once per pass
    push(@states_from_previous_pass, $self) unless defined $self->{state_next_pass};
    $self->{state_next_pass} = $state;

    unshift(@{$$self{state_log}}, "$main::Time_Date $state");
    pop @{$$self{state_log}} if @{$$self{state_log}} > $main::config_parms{max_state_log_entries};

}

sub reset_states {
    my $ref;
    while ($ref = shift @reset_states) {
        undef $ref->{state_now};
    }

    while ($ref = shift @states_from_previous_pass) {
        $ref->{state}     = $ref->{state_next_pass};
                                # Ignore $Startup events
        $ref->{state_now} = $ref->{state_next_pass} unless $main::Loop_Count < 5;
        undef $ref->{state_next_pass};
        push(@reset_states, $ref);
    }
}

sub state {
    return @_[0]->{state};
} 

sub state_now {
    return @_[0]->{state_now};
}

sub state_log {
    my ($self) = @_;
    return @{$$self{state_log}} if $$self{state_log};
}


return 1;           # for require


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


# $Log$
# Revision 1.1  2000/04/09 18:03:19  winter
# - 2.13 release
#
#
