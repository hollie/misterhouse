package Hardware::iButton::Connection;

use strict;
no strict "subs";
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
#require AutoLoader;

my $OS_win = ($^O eq "MSWin32") ? 1 : 0;

if ($OS_win) {
    &my_use("Win32::SerialPort");
}
else {
    &my_use("Device::SerialPort");  # Unix Posix verion of Win32 SerialPort
#   &my_use("IO::File");
}

#use Time::HiRes qw(usleep);
#use POSIX qw(tcdrain); # for drain in write()
use Hardware::iButton::Device;
#use IO::Stty;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();

( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Hardware::iButton - talk to DalSemi iButtons via a DS2480 serial widget

=head1 SYNOPSIS

  use Hardware::iButton::Connection;
  $c = new Hardware::iButton::Connection "/dev/ttyS0";
  @b = $c->scan();
  foreach $b (@b) {
      print "family: ",$b->family(), "serial number: ", $b->serial(),"\n";
      print "id: ",$b->id(),"\n"; # id = family . serial . crc
      print "reg0: ",$b->readreg(0),"\n";
  }

=head1 DESCRIPTION

This module talks to iButtons via the "active" serial interface (anything
using the DS2480, including the DS1411k and the DS 9097U). It builds up a list
of devices available, lets you read and write their registers, etc.

The connection object is an Hardware::iButton::Connection. The main
user-visible purpose of it is to provide a list of Hardware::iButton::Device
objects. These can be subclassed once their family codes are known to provide
specialized methods unique to the capabilities of that device. Those devices
will then be Hardware::iButton::Device::DS1920, etc.

iButtons and solder-mount Touch Memory devices are each identified with a
unique 64-bit number. This is broken up into 8 bits of a "family code", which
specifies the part number (and consequently the capabilities), then 48 bits
of device ID (which Dallas insures is globally unique), then 8 bits of CRC.
When you pass these IDs to and from this package, use hex strings like
"0123456789ab".

=head1 AUTHOR

Brian Warner, warner@lothar.com

=head1 SEE ALSO

http://www.ibutton.com, http://sof.mit.edu/ibuttonpunks/

=cut

# constants listed in the Book of DS19xx iButton Standards

# "Network Layer" constants
use constant READ_ROM => "\x33";
use constant SKIP_ROM => "\xcc";
use constant MATCH_ROM => "\x55";
use constant SEARCH_ROM => "\xF0";
use constant OD_SKIP_ROM => "\x3c";
use constant OD_MATCH_ROM => "\x69";
# "Transport Layer" constants
use constant READ_MEMORY => "\xf0";
use constant EXT_READ_MEMORY => "\xa5";
use constant READ_SUBKEY => "\x66";
use constant WRITE_SCRATCHPAD => "\x0f";
use constant READ_SCRATCHPAD => "\xaa";
use constant COPY_SCRATCHPAD => "\x55";
# etc..

# there are constants used by the DS2480 too.
use constant SET_DATA_MODE => "\xe1";
use constant SET_COMMAND_MODE => "\xe3";
use constant SEARCH_ACCEL_ON => "\xb1";
use constant SEARCH_ACCEL_OFF => "\xa1";

use constant DEBUG => 0;

$Hardware::iButton::Connection::debug = 0;

# devices are in one of three states: active in network layer, deselected,
# active in transport layer. In addition some devices can be "overdrive active"
# in the transport layer. We call these states "active, deselected, 
# selected, OD selected".

# after a bus reset, all devices are active in the "network layer" and you're
# only supposed to do "network layer" commands.
#  READ_ROM gets everybody's id at once. If the CRC is right then there was
#           only one device. Everyone is still active
#  SKIP_ROM selects everyone
#  MATCH_ROM selects the device with a matching ID, deselects everyone else
#  SEARCH_ROM will end up selecting one device, deselecting the others
#  OD_SKIP_ROM makes everyone OD selected
#  OD_MATCH_ROM will OD select the matching device, deselect everyone else

# Preloaded methods go here.

# we need some kind of slow substitute if Time::HiRes is not available

sub usleep {
    my($usec) = @_;
#   print "sleep0 $usec\n";
    select undef, undef, undef, ($usec / 10**6);
}

sub my_use {
    my($module) = @_;
    eval "use $module";
    if ($@) {
        print "\nError in loading module=$module:\n  $@";
    }
    return $@;
}

=head2 new

  $c = new Hardware::iButton::Connection "/dev/ttyS0";

Creates a new Hardware::iButton::Connection object by opening the given serial
port and attempting to communicate with a DS2480 chip.

=cut

sub new {
    my($class, $port) = @_;
    my $self = bless {},$class;
    $self->{'port'} = $port;

#   $self->{'s'} = new IO::File "+<$port";
    unless (( $OS_win and $self->{s} = new Win32::SerialPort ($port))or 
            (!$OS_win and $self->{s} = new Device::SerialPort ($port))) {
        print "\n\nCan't open serial port $port: $^E\n\n";
        return;
    }

    return undef unless $self->{'s'};
    #print "orig settings: ",IO::Stty::stty($self->{'s'},'-a'),"\n";
    #$self->{'s.oldstty'} = IO::Stty::stty($self->{'s'},'-g');
    $self->{'s.changed'} = 1;

#   $self->{'s'}->blocking(0);
#   $self->{'s'}->autoflush(1);
    $self->{s}->error_msg(1);     # use built-in error messages
    $self->{s}->user_msg(0);
    $self->{s}->databits(8) if $self->{s}->can_databits;
    $self->{s}->baudrate(9600);
    $self->{s}->parity("none");
    $self->{s}->stopbits(1);
#   $self->{s}->dtr_active(1);
    $self->{s}->handshake('none');  # or dtr?
#   $self->{s}->read_buf_max(4096);
#   $self->{s}->write_buf_max(4096);
    $self->{s}->write_settings;


    #IO::Stty::stty($self->{'s'}, qw(9600 raw -echo -echoe -echok));
    #print "new settings: ",IO::Stty::stty($self->{'s'},'-a'),"\n";

    # we should also do the equivalent of a 'stty raw' here
    # stty 9600 raw -onlcr -iexten -echo -echoe -echok -echoctl -echoke

    # reset
    $self->{'mode'} = SET_COMMAND_MODE;
    $self->write(SET_COMMAND_MODE);
    usleep(50 * 1000);
    $self->write("\xc1");
    usleep(50 * 1000);
    $self->write("\xf1");
    usleep(50 * 1000);
    $self->write("\xc1");
    usleep(50 * 1000);
    $self->write("\xf1");
    usleep(50 * 1000);
    my $dummy;
    $dummy = $self->read(0); # flush
    #print "dummy (",length($dummy),"): ",unpack("H*",$dummy),"\n";

    my $times = 5;
    while ($times) {
	$self->write("\xc1");
	usleep(50 * 1000);
	$dummy = $self->read(0);

#	last if (length($dummy) == 1 and ((ord($dummy) & 0xdc) == 0xc8));
	last if length($dummy) == 1; # rc=0,1,2,3,4 means we are ok (?)  Not sure what the above test is for

	print "reset, but got back (",length($dummy),"): ",unpack("H*",$dummy),"\n";
	usleep(300 * 1000); $self->read(0);
	$times--;
    }
    if (!$times) {
        warn "couldn't reset bus";
    }
    
    # we just reset.. all buttons are listening, so none is currently selected
    $self->{'selected'} = undef;

    return $self;
}

sub resetstty {
    my($self) = @_;
    #print "resetstty\n";
    #foreach my $key (keys(%$self)) {
	#print "$key: $self->{$key}\n";
    #}
    unless ($self->{'s.changed'}) {
	#print "not restoring\n";
	return;
    }
    #print "restoring..\n";
    # restore terminal parameters
    #print "current settings: ",IO::Stty::stty($self->{'s'},'-a'),"\n";
    #IO::Stty::stty($self->{'s'},$self->{'s.oldstty'});
    $self->{'s.changed'} = 0;
    #print "restored settings: ",IO::Stty::stty($self->{'s'},'-a'),"\n";
}

sub DESTROY {
    my($self) = @_;
    print "ibutton Connection DESTROY $self\n";
#   $self->resetstty();
#   $self->{s}->close;    # This does not free up the port??
#   $self->close;
    undef $self;
}

# write string, wait for output to drain, wait a bit more
sub write {
    my($self, $string) = @_;
    print "write(",length($string),": ",unpack("H*",$string),")\n"
      if $Hardware::iButton::Connection::debug;
#   $self->{'s'}->syswrite($string, length($string));
    $self->{'s'}->write($string);
    # drain
    #print "fileno: ",$self->{'s'}->fileno(),"\n";
    #my $r = tcdrain($self->{'s'}->fileno()); print "tcdrain: $r\n";
                                # bbw Not needed??
#   usleep(1000);
}

# read $bytes. If $timeout seconds goes by without anything read,
# return whatever we've got. If $timeout is unspecified, use a system default
# of 100ms. If $bytes is 0, just read whatever is available.
sub read {
    my($self, $bytes, $timeout) = @_;
    my($dummy, $input, $count);

                                # This is a brain dead way ... wait a while
#   usleep(10000);     
#   return $input = $self->{s}->input;

#   $self->{s}->read_const_time(100);       # Total time to wait

                                # read_Interval is not in the unix Device/Serialport.pm
                                # - But This works best with high speed ports and windows NT/2000
    if ($^O eq 'MSWin32') {
        $self->{s}->read_interval(20); # Time to wait after last byte received
    }
    else {
        $self->{s}->read_char_time(20); # avg time between read char
    }


    if ($bytes == 0) {
        $input = $self->{s}->input;
        return $input;
    }

    ($count, $input) = $self->{s}->read($bytes);

    print "Read $count bytes: $input\n"  if $Hardware::iButton::Connection::debug;

                                # Reset framing errors
    $self->{s}->reset_error;

    return $input;

                                # The rest of this was the original, pre SerialPort code
    if ($bytes) {
	my $start = time;


	while($bytes) {

	    my $count = $self->{'s'}->sysread($dummy, $bytes);

	    unless ($count) {
		# error. Probably EWOULDBLOCK.
		print "sleep\n" if DEBUG;
		usleep(1001);
		if (time - $start > 2) {
		    warn("read timed out, got ",length($input),
			 " still want $bytes\n");
		    print "read(",length($input),": ",unpack("H*",$input),")\n"
		      if $Hardware::iButton::Connection::debug;
		    return $input;
		}
		next;
	    }
	    $input .= $dummy; $bytes -= $count;
	}
    } else {
	$self->{'s'}->sysread($input, 10000);	
    }
    print "read(",length($input),": ",unpack("H*",$input),")\n"
      if $Hardware::iButton::Connection::debug;
    return $input;
}

sub mode {
    my($self, $newmode) = @_;
    if ($self->{'mode'} ne $newmode) {
	$self->write($newmode);
	$self->{'mode'} = $newmode;
    }
}

# send a series of bytes to the one-wire bus, as opposed to merely sending a
# series of bytes to the DS2480. This deals with making sure we're in the
# SET_DATA_MODE and escaping the SET_COMMAND_MODE chars

sub send {
    my($self, $str) = @_;
    $self->mode(SET_DATA_MODE);
    $str =~ s/\xe3/\xe3\xe3/g; # double SET_COMMAND_MODE chars
    $self->write($str);
}

# DESTROY: nothing special to do, the port will be closed for us. Once we
# start doing 'stty' stuff, though, we should really return the port to the
# way it was before

=head2 reset

 $status = $c->reset();

resets the One-Wire bus. Returns a status code:
 0: bus shorted
 1: presence pulse: at least one device is present on the bus
 2: alarming presence pulse: at least one device is alarmed
 3: no presence pulse: there are no devices on the bus

=cut

sub reset {
    my($self) = @_;

    $self->read(0);
    $self->mode(SET_COMMAND_MODE);
    $self->write("\xc1");
    $self->{'selected'} = undef;
    my $status = $self->read(1);
    $status = ord($status) & 0x03;
    return $status;
}

=head2 scan

  @buttons = $c->scan();
  @buttons = $c->scan($family_code);
  $button  = $c->scan($family_code, $serial);

scans the One-Wire bus with the ROM Search command and builds up a list of all
devices present. Hardware::iButton::Device objects are created for each, and
an array of these objects is returned. If a family code is given, the search
is restricted to devices of that family type. If a serial number is given
(which must be a 12 character string), then the bus is searched for that one
particular device (family code plus id) and, if present, an object is returned
for it.

If no buttons match the search criteria (or none are present), an empty list
or undef is returned.

=cut

# encode bits into the 16-byte string used to give the Search Accelerator
# command a preferred path
# $byte[0] = "b3XXb2XXb1XXb0XX", $byte[1] = "b7XXb6XXb5XXb4XX", etc
# $byte[0] = $bit[3] << 7 | $bit[2] << 5 | $bit[1] << 3 | $bit[0] << 1
# etc
# take an array of 0 or 1
# return a 16 character string ready to be written
# the One-Wire protocol uses ROM values that are 64 bits, LSB first, first
# the family code, then serial number, then CRC.
sub packbits {
    my($bits) = @_;  # [0 .. 63], each either 1 or 0
    print "packbits(bits=($bits)\n" if DEBUG;
    $bits =~ s/(.)/0 . $1/ge; # insert the "XX"s as zeros
    $bits = pack("b128", $bits);
    print " (",length($bits),"):",join(',',unpack("C*",$bits)),"\n" if DEBUG;
    return $bits;
}

# extract bits returned by the Search Accelerator command
# the bits are interleaved "chosen bits" and "discrepancy bits"
# first byte is r3d3r2d2r1d1r0d0
# second is r7d7r6d6r5d5r4d4
# we are given a string of 16 chars straight from read()
# generate two arrays, $r[0..63] and $d[0..63], each with 0 or 1
# find $firstconflict: the lowest $i>=$bits for which $conflict[$i] == 1,
# return $firstconflict, @r
sub unpackbits {
    my($bits, $string) = @_;
    print "unpackbits(bits=$bits,string(",length($string),"):" if DEBUG;
    print join(',',map {sprintf('0x%02x',$_)} unpack("C*",$string)),")\n" 
      if DEBUG;
    my $b1 = unpack("b128", $string);
    # now extract every other char into a separate array
    my($chosen,$d) = ($b1,$b1);
    $chosen =~ s/.(.)/$1/g;
    $d =~ s/(.)./$1/g;
    print " r: $chosen\n" if DEBUG; print " d: $d\n" if DEBUG;
    my(@conflict) = split(//,$d);
    # find $firstconflict
    my $firstconflict = -1;
    for(my $i=$bits; $i<64; $i++) {
	if ($conflict[$i]) {
	    $firstconflict = $i;
	    last;
	}
    }
    print " first=$firstconflict, chosen=$chosen\n" if DEBUG;
    return($firstconflict, $chosen);
}

# find all IDs that have substr($path, 0, $bits) in them. Recurse.
# substr($path, $bits+1) will be all "0"s
sub scan1 {
    my($self, $bits, $path) = @_;
    print "scan1(bits=$bits,path=$path)\n" if DEBUG;

    #print "str: ",join(' ', map {sprintf('0x%02x', ord($_))} (split(//,$str))),"\n" if DEBUG;
    $self->reset(); # puts us in COMMAND_MODE
    $self->mode(SET_DATA_MODE);
    $self->write(SEARCH_ROM);
    $self->mode(SET_COMMAND_MODE);
    $self->write(SEARCH_ACCEL_ON);
    $self->mode(SET_DATA_MODE);
    $self->write(packbits($path));
    $self->mode(SET_COMMAND_MODE);
    $self->write(SEARCH_ACCEL_OFF);

    my $in = $self->read(17);
    # the first byte is the echo of SEARCH_ROM. Then 16 bytes of data.
    print "read ",length($in)," bytes: " if DEBUG;
    print join(',',map{sprintf('0x%02x',$_)} unpack("C*",$in)),"\n" if DEBUG;
    $in = substr($in, 1);
    my($firstconflict, $chosen) = unpackbits($bits, $in);
    if ($firstconflict == -1) {
	# there was no conflict. That means there was only one ID with this
	# prefix. Return it.
	return ($chosen);
    } else {
	# there was a conflict at $firstconflict. Recurse and return the two
	# possible paths. The Search Accelerator has already given us the
	# lowest numerical ID with this prefix (since we gave 0's to @path)
	# but using that data would be too much of a nuisance.
	my($way0,$way1) = ($path,$path);
	substr($way0, $firstconflict, 1) = "0";
	substr($way1, $firstconflict, 1) = "1";
	return($self->scan1($firstconflict+1, $way0),
	       $self->scan1($firstconflict+1, $way1));
    }
}

sub scan {
    my($self, $family_code, $serial) = @_;
    my(@buttons);
    my(@ids);

    # scan bus. Each ID is an 8 byte list, starting with the family code,
    # then 6 ID bytes, then the CRC. The ID bytes are in the same order as
    # the label engraved on the button, which is backwards of the order
    # read from the bus.
    
    my $r = $self->reset();
    if ($r == 0 or $r == 3) {
	# short or nothing present
	return undef;
    }

    # use the DS2480's Search Accelerator function
    my(@raw_ids);
    # the raw_ids used here are 64-char strings:
    # f0f1f2f3..f7 . s0s1s2s3..s47 . c0c1..c7
    # f: family code (lsb first)
    # s: serial number (lsb first). label is printed msb first.
    # c: crc (lsb first)

    if (!defined($family_code)) {
	# find everyone
	@raw_ids = $self->scan1(0, "0" x 64);
    } else {
	my $family_bits;
	$family_bits = unpack("b8", chr(hex($family_code)));
	if (defined($serial)) {
	    my $device_bits;
	    # find this particular device
	    die 'scan(): \$serial must have 12 hex chars' 
	      unless ($serial =~ /^[0-9a-fA-f]{12}$/);
	    $device_bits = reverse(unpack("B48",pack("H12",$serial)));
	    @raw_ids = $self->scan1(8+48, $family_bits . $device_bits . "0"x8);
	    @raw_ids = grep {/^\Q$family_bits$device_bits\E/} @raw_ids;
	} else {
	    # find everyone with this family code
	    @raw_ids = $self->scan1(8, $family_bits . "0" x 56);
	    @raw_ids = grep {/^\Q$family_bits\E/} @raw_ids;
	}
    }


    foreach my $raw_id (@raw_ids) {
	# $raw_id is a 64 character string of "0" and "1"
	my $button = Hardware::iButton::Device->new($self, $raw_id);
	#print "id: ",$button->id(),"\n";
	push(@buttons, $button);
    }

    $self->reset();
    return @buttons;
}

=head2 readrom

  @id = $c->readrom(); # FIXME

Run a Read ROM command on the bus, and return the 8 bytes that result as a
string of 16 hex chars. This command is only useful if there is exactly 1
device on the bus. This is rarely the case, since most containers of DS2480
chips have solder-mount touch memory devices already on the bus (the 1411k
seems to have a DS2401 id-only device on it, and the DS9097U appears to have a
DS2502 1k add-only eprom in it).

=cut

sub readrom {
    my($self) = @_;

    $self->write("\xc1\xe1\x33\xff\xff\xff\xff\xff\xff\xff\xff\xe3\xc9");
    my $dummy = $self->read(11);
    my(@bin_id) = map {ord($_)} split(//, $dummy);
    # first byte is the reset result, second is an echo of the 0x33 Read ROM
    # code. Next 8 are familycode, id[5..0], then crc. Last is reset result.
    my(@id) = @bin_id[2,8,7,6,5,4,3,9];

    return @id;
}

# $c->select($rawid);
# activate the button with $rawid, if it isn't already.

# todo: keep track of how long it's been since we actually heard from this
# device. If it's been more than a couple of seconds, do a Search ROM
#  ($self->scan($family,$serial)) to make sure it's still there.
sub select {
    my($self, $rawid) = @_;

    if ($self->{'selected'} and $self->{'selected'} eq $rawid) {
	# already selected
	return 1;
    }

    my $r = $self->reset();
    if ($r == 0 or $r == 3) {
	# short or nothing present
	return undef;
    }

    # send Match ROM command
    my $str = MATCH_ROM . pack("b64",$rawid);
    $self->send($str);
    $self->read(length($str)); # read echos

    $self->{'selected'} = $rawid;
    # see if anyone is still there??
    # nope, no way to tell

    return 1;
}

sub crc {
    my($crc, @newbytes) = @_;
    
    sub addbit {
	my($crc, $bit) = @_;
	#printf("addbit($bit): 0x%02x -> ",$crc);;
	my $in = ($crc & 1) ^ $bit;
	$crc ^= 0x18 if $in;
	$crc >>= 1;
	$crc |= 0x80 if $in;
	#printf("0x%02x\n",$crc);
	return $crc;
    }
    
    foreach my $byte (@newbytes) {
	my $bits = unpack("b8", $byte);
	my(@bits) = split(//,$bits);
	foreach (@bits) {
	    $crc = addbit($crc, $_);
	}
    }
    return $crc;
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

