package Hardware::iButton::Device;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
#require AutoLoader;
#use Time::HiRes qw(usleep);
sub usleep {
    my($usec) = @_;
    print "sleep1 $usec\n";
    select undef, undef, undef, ($usec / 10**6);
}


@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);

( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Hardware::iButton::Device - object to represent iButtons

=head1 SYNOPSIS

  use Hardware::iButton::Connection;
  $c = new Hardware::iButton::Connection "/dev/ttyS0";
  @b = $c->scan();
  foreach $b (@b) {
      print "id: ", $b->id(), ", reg0: ",$b->readreg(0),"\n";
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

=head1 AUTHOR

Brian Warner, warner@lothar.com

=head1 SEE ALSO

http://www.ibutton.com, http://sof.mit.edu/ibuttonpunks/

=cut

# Preloaded methods go here.

use vars qw(%models);
%models = (
	   "01" => {
		    'model' => 'DS1990A',
		    'memsize' => 0,
		    'memtype' => "none",
		    'specialfuncs' => "",
		   },
	   "02" => {
		    'model' => 'DS1991',
		    'memsize' => 512/8,
		    'memtype' => "NVRAM",
		    'specialfuncs' => "protected nvram 3*384bits",
		   },
	   "08" => {
		    'model' => 'DS1992',
		    'memsize' => 1024/8,
		    'memtype' => "NVRAM",
		    'specialfuncs' => "",
		   },
	   "06" => {
		    'model' => 'DS1993',
		    'memsize' => 4096/8,
		    'memtype' => "NVRAM",
		    'specialfuncs' => "",
		   },
	   "04" => {
		    'model' => 'DS1994',
		    'memsize' => 4096/8,
		    'memtype' => "NVRAM",
		    'specialfuncs' => "clock/counter",
		   },
	   "0a" => {
		    'model' => 'DS1995',
		    'memsize' => 16*1024/8,
		    'memtype' => "NVRAM",
		    'specialfuncs' => "",
		   },
	   "0c" => {
		    'model' => 'DS1996',
		    'memsize' => 64*1024/8,
		    'memtype' => "NVRAM",
		    'specialfuncs' => "",
		   },
	   "09" => {
		    'model' => 'DS1982',
		    'memsize' => 1024/8,
		    'memtype' => "EPROM",
		    'specialfuncs' => "",
		   },
	   "12" => {
		    'model' => 'DS2406',
		    'memsize' => 1024/8,
		    'memtype' => "EPROM",
		    'specialfuncs' => "pio",
		   },
	   "0b" => {
		    'model' => 'DS1985',
		    'memsize' => 16*1024/8,
		    'memtype' => "EPROM",
		    'specialfuncs' => "",
		   },
	   "0f" => {
		    'model' => 'DS1986',
		    'memsize' => 64*1024/8,
		    'memtype' => "EPROM",
		    'specialfuncs' => "",
		   },
	   "10" => {
		    'model' => 'DS1920',
		    'memsize' => 16/8, # yes, really. two bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "thermometer",
		    'class' => 'Hardware::iButton::Device::DS1920',
		   },
	   "22" => {
		    'model' => 'DS1822',
		    'memsize' => 16/8, # yes, really. two bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "thermometer",
		    'class' => 'Hardware::iButton::Device::DS1822',
		   },

	   "14" => {
		    'model' => 'DS1971',
		    'memsize' => 256/8,
		    'memtype' => "EPROM",
		    'specialfuncs' => "??",
		   },
	   "16" => {
		    'model' => 'javabutton',
		    'memsize' => 0,
		    'memtype' => "??",
		    'specialfuncs' => "Java processor",
		    'class' => 'Hardware::iButton::Device::JavaButton',
		   },
	   "1d" => {
		    'model' => 'DS2423',
		    'memsize' => 4096/8,
		    'memtype' => "??",
		    'specialfuncs' => "Counter",
		    'class' => 'Hardware::iButton::Device::DS2423',
		   },
	  );


# new is the constructor, called by Hardware::iButton::Connection::scan() to
# create the new Hardware::iButton::Device instance to return to the user
sub new {
    my($class, $connection, $raw_id) = @_;
    my $self = bless {}, $class;
    # we'll rebless ourselves into a device-specific class once we set up some
    # basic stuff
    $self->{'connection'} = $connection;
    $self->{'raw_id'} = $raw_id;

    # things the user can query about, all derived from the raw_id
    $self->{'family'} = unpack("H2",pack("b8",substr($raw_id,0,8)));
    $self->{'serial'} = unpack("H12",
			       pack("B48",
				    scalar(reverse(substr($raw_id,8,48)))));
    $self->{'crc'} = unpack("H2",pack("b8",substr($raw_id,56,8)));
    $self->{'id'} = join("",
			 $self->{'family'},$self->{'serial'},$self->{'crc'});

    # check CRC
    my $crc = Hardware::iButton::Connection::crc(0, split(//, pack("b*", 
								   $raw_id)));
    if ($crc != 0) {
	warn("crc didn't match");
    }

    # model-specific stuff
    if (defined($models{$self->{'family'}})) {
	my $m = $models{$self->{'family'}};
	foreach (keys(%$m)) {
	    #print "  $_ -> ",$m->{$_},"\n";
	    $self->{$_} = $m->{$_};
	}
	if ($m->{'class'}) {
	    bless $self, $m->{'class'};
	}
    } else {
	warn "unknown model, family code $self->{'family'}";
    }

    return $self;
}

=head2 accessors

 $family = $b->family();  # "01" for DS1990A/DS2401 "id only" buttons
 $serial = $b->serial();  # "000001F1F1F3", as stamped on button
 $crc = $b->crc();        # "E5" error check byte
 $id = $b->id();   # the previous three joined together: "01000001F1F1F3E5"

=cut

sub family {
    return $_[0]->{'family'};
}

sub serial {
    return $_[0]->{'serial'};
}

sub crc {
    return $_[0]->{'crc'};
}

sub id {
    return $_[0]->{'id'};
}


=head2 select

  $b->select();

Activate this button (in Dallas terms, "move it to the Transport Layer"). All
other buttons will be idled and will not respond to commands until the bus is
reset with C<$c->reset()>. Returns 1 for success, undef if the button is no
longer on the bus.

=cut

sub select {
    my($self) = @_;
    return $self->{'connection'}->select($self->{'raw_id'});
}

sub reset {
    return $_[0]->{'connection'}->reset();
}


=head2 is_present

 $button->is_present();

Checks to see if the given button is still present, using the Search ROM
command. Returns 1 if it is, 0 if not.

=cut

sub is_present {
    my($self) = @_;
    return 1 
      if $self->{'connection'}->scan($self->{'family'}, $self->{'serial'});
    return 0;
}

=head2 Button Introspection

or, how not to get lost in your own navel

 $model = $b->model();    # "DS1992"
 $bytes = $b->memsize(); # 128 bytes
 $type = $b->memtype();   # "NVRAM"
 $special = $b->specialfuncs();   # "thermometer", "clock", "java", "crypto"

=cut

sub model {
    return $_[0]->{'model'};
}
sub memsize {
    return $_[0]->{'memsize'};
}
sub memtype {
    return $_[0]->{'memtype'};
}
sub specialfuncs {
    return $_[0]->{'specialfuncs'};
}


# common actions that all buttons can do

=head2 read_memory

 $data = $b->read_memory($start, $length);

Reads memory from the iButton. Acts like C<$data = substr(memory, $start, 
$length)>. If you read beyond the end of the device, you will get all ones
in the unimplemented addresses.

=cut

sub read_memory {
    my($self, $addr, $length) = @_;
    my $c = $self->{'connection'};
    $self->select();
    my $str = &Hardware::iButton::Connection::READ_MEMORY . pack("v",$addr)
      . "\xff" x $length;
    $c->send($str);
    $c->read(1+2);
    my $buf;
    $buf = $c->read($length);
    $self->reset();
    return $buf;
}

=head2 write_memory

 $b->write_memory($start, $data);

Writes memory to the iButton NVRAM. Acts like C<substr(memory, $start,
length($data)) = $data;>. Writes in chunks to separate 32-byte pages, each
chunk going to the scratchpad first, verified there, then copied into
NVRAM. Returns the number of bytes successfully written.

=cut

sub write_memory_page {
    my($self, $pageaddr, $chunk) = @_;
    # the data does not span a page, 
    #  i.e. ($pageaddr % 32) == (($pageaddr+length($chunk)) % 32)
    # length($chunk) <= 32
    
    my $c = $self->{'connection'};
    
    $c->reset();
    $self->select();
    my $str = &Hardware::iButton::Connection::WRITE_SCRATCHPAD . pack("v",$pageaddr);
    $str .= $chunk;
    $c->send($str);
    $c->read(length($str));
    $c->reset();

    # verify the scratchpad
    $self->select();
    $str = &Hardware::iButton::Connection::READ_SCRATCHPAD . "\xff" x 3;
    $c->send($str); $c->read(1);
    my $buf;
    $buf = $c->read(3);
    # check it! 
    #   ("right foot red.. yellow foot blue.. left right yellow blue green!")
    # the first two bytes are the address we wrote. The third is a status byte.
    my $readback_addr = unpack("v", substr($buf, 0, 2));
    if ($readback_addr != $pageaddr) {
	# address got garbled in transit
	print "address not correct: $readback_addr instead of $pageaddr\n";
	$c->reset();
	return 0; # try again
    }
    my $status = unpack("C", substr($buf, 2, 1));
    # $status byte is (AA OF PF E4 E3 E2 E1 E0)
    # AA: authorization accepted: set once COPY_SCRATCHPAD happens
    # OF: overflow flag, if data ran beyond a page
    # PF: partial flag, if we didn't send a full byte
    # E: end address, should be ($pageaddr+$length-1)%32
    if ($status & 0x80) {
	# AA flag still set, so the WRITE_SCRATCHPAD hasn't happened since
	# the last COPY_SCRATCHPAD
	print "AA flag set\n";
	$c->reset();
	return 0;
    }
    if ($status & 0x40) {
	# OF flag set, maybe we sent too many bytes, or the pageaddr got
	# garbled to make it look closer to the end of the page
	print "OF flag set\n";
	$c->reset();
	return 0;
    }
    if ($status & 0x20) {
	# PF set, some bits got dropped
	print "PF flag set\n";
	$c->reset();
	return 0;
    }
    if (($status & 0x1f) != ($pageaddr+length($chunk)-1)%32) {
	# addr isn't right
	print "addr is ",($status & 0x1f),", should be ",
	($pageaddr+length($chunk)-1)%32,"\n";
	$c->reset();
	return 0;
    }
    
    # read data out and check it
    $c->send("\xff" x length($chunk));
    $buf = $c->read(length($chunk));
    if ($buf ne $chunk) {
	# data got corrupted
	print "data readback was wrong\n";
	$c->reset();
	return 0;
    }
    $c->reset();

    # looks good
    
    # copy from scratchpad to NVRAM
    $self->select();
    $str = &Hardware::iButton::Connection::COPY_SCRATCHPAD
      . pack("v",$pageaddr) . pack("C", $status);
    $c->send($str);
    $c->read(1+2+1);
    
    # wait for it to program.. data book says 30us typ.
    # the device will respond with 1's if it's still programming
    usleep(50);
    while(1) {
	$c->send("\xff");
	$buf = $c->read(1);
	last if $buf eq "\x00";
	usleep(50*1000); # 50ms
    }
    
    # read back and verify
    
    $c->reset();
}

sub write_memory_page_loop {
    my($self, $pageaddr, $chunk) = @_;
    # try a couple of times to write
    my $times = 3;
    my $nwritten;
    while ($times) {
	print "write(times=$times,pageaddr=$pageaddr,length=",length($chunk),")\n";
	$nwritten = $self->write_memory_page($pageaddr, $chunk);
	last if $nwritten == length($chunk);
	$times--;
    }
    return $nwritten;
}

sub write_memory {
    my($self, $addr, $data) = @_;
    my $nwritten = 0;
    
    # find the first chunk boundaries: the scratchpad is like a direct-mapped
    # cache, so we can only copy to a single "page" (32-bytes) at a time.
    
    # do we need to write a partial chunk first
    if ($addr % 32) {
	# yup
	my $chunklen = 32 - ($addr % 32);
	print "chunklen is $chunklen\n";
	$nwritten += 
	  $self->write_memory_page_loop($addr, substr($data, 0, $chunklen));
	$addr += $chunklen;
	substr($data, 0, $chunklen) = '';
    }
    
    # write chunks
    while(length($data)) {
	my $chunklen = (length($data) > 32) ? 32 : length($data); # max 32
	print "chunklen is $chunklen\n";
	$nwritten += 
	  $self->write_memory_page_loop($addr, substr($data, 0, $chunklen));
	$addr += $chunklen;
	substr($data, 0, $chunklen) = '';
    }

    # done!
    return $nwritten;
}

package Hardware::iButton::Device::eeprom;
# this is a class that implements read-eeprom and write-eeprom commands.
# other device classes can inherit from this one
use strict;
use vars qw(@ISA);

# read one byte
sub read_eeprom {
    my($self, $addr) = @_;
}

# write one byte
sub write_eeprom {
    my($self, $addr, $data) = @_;
}



package Hardware::iButton::Device::DS1920;

use Hardware::iButton::Connection;
#use Time::HiRes qw(usleep);
sub usleep {
    my($usec) = @_;
#   print "sleep2 $usec\n";
    select undef, undef, undef, ($usec / 10**6);
}


# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

sub read_temperature_scratchpad {
    my($self) = @_;
    my $c = $self->{'connection'};

    my $trys = 6;               # dpl mod

    for (my $loop=1;$loop <= $trys;$loop++) {
#       print "read_temperature_scratchpad: pass $loop of $trys\n";
        $c->reset();
        $c->mode(&Hardware::iButton::Connection::SET_COMMAND_MODE);
        $c->write("\x39"); # set a 524ms pullup
        $c->read(1); # response to config command
        $c->reset();
        $self->select();
        $c->mode(&Hardware::iButton::Connection::SET_COMMAND_MODE);
        $c->write("\xef"); # arm the pullup
        $c->write("\xf1"); # terminate pulse (??)
        $c->read(1); # response to 0xf1
        $c->mode(&Hardware::iButton::Connection::SET_DATA_MODE);
        $c->send("\x44"); # start conversion. need to do a 0.5s strong pullup.
        $c->read(1); # read back 0x44
                                # wait
        usleep(750*1000); # wait .75s
        $c->mode(&Hardware::iButton::Connection::SET_COMMAND_MODE);
        $c->write("\xed"); # disarm pullup
        $c->write("\xf1"); # terminate pulse
        $c->read(1); # response??

        $c->reset();
        $self->select();

                                # read scratchpad, bytes 0 and 1 (LSB and MSB)
        $c->send("\xbe"); $c->read(1);
        $c->send("\xff" x 9);
        my $scratchpad = $c->read(9);
        $c->reset();
                                # check CRC in last byte.
        if (Hardware::iButton::Connection::crc(0, split(//,$scratchpad))) {
            warn("scratchpadcrc was wrong on pass $loop");
        }
        else {
            print "scratchpad correct on pass $loop of $trys\n" if $loop > 1;
            return $scratchpad;
        }
    }
}


=head2 read_temperature

 $temp = $b->read_temperature();
 $temp = $b->read_temperature_hires();

These methods can be used on DS1820/DS1920 Thermometer iButtons. They return
a temperature in degrees C. The range is -55C to +100C, the resolution of the
first is 0.5C, the resolution of the second is about 0.01C. The accuracy is
about +/- 0.5C.

Useful conversions: C<$f = $c*9/5 + 32>,   C<$c = ($f-32)*5/9> .

=cut


sub read_temperature {
    my($self) = @_;
    my $scratchpad = $self->read_temperature_scratchpad($self);
    my $tempnumber = unpack("v",substr($scratchpad, 0, 2));
    # now, that's really supposed to be a signed 16-bit little-endian
    # quantity, but there isn't a pack() code for such things.
    #printf("tempnumber as read is 0x%04x\n",$tempnumber);
    printf("tempnumber as read is 0x%04x 0x%04x\n",$tempnumber,$tempnumber>> 4);
    $tempnumber -= 0x10000 if $tempnumber > 0x8000;
#   my $temp = $tempnumber / 2;
    my $temp = $tempnumber >> 4;
    return $temp;
}

sub read_temperature_hires {
    my($self) = @_;
    my $scratchpad = $self->read_temperature_scratchpad($self);
    my $tempnumber = unpack("v",substr($scratchpad, 0, 2));
    # now, that's really supposed to be a signed 16-bit little-endian
    # quantity, but there isn't a pack() code for such things.
    my $count_per_c = ord(substr($scratchpad, 7, 1));
    my $count_remaining = ord(substr($scratchpad, 6, 1));
    #printf("tempnumber as read is 0x%04x\n",$tempnumber);
    $tempnumber &= 0xfffe; # truncate LSB
    $tempnumber -= 0x10000 if $tempnumber > 0x8000;
    my $temp = ($tempnumber / 2) - 0.25 + 
        ($count_per_c - $count_remaining) / $count_per_c if $count_per_c;
    return $temp;
}



package Hardware::iButton::Device::DS1822;

use Hardware::iButton::Connection;
#use Time::HiRes qw(usleep);
sub usleep {
    my($usec) = @_;
#   print "sleep2 $usec\n";
    select undef, undef, undef, ($usec / 10**6);
}


# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

sub read_temperature_scratchpad {
    my($self) = @_;
    my $c = $self->{'connection'};

    $c->reset();
    $c->mode(&Hardware::iButton::Connection::SET_COMMAND_MODE);
    $c->write("\x39"); # set a 524ms pullup
    $c->read(1); # response to config command
    $c->reset();
    $self->select();
    $c->mode(&Hardware::iButton::Connection::SET_COMMAND_MODE);
    $c->write("\xef"); # arm the pullup
    $c->write("\xf1"); # terminate pulse (??)
    $c->read(1); # response to 0xf1
    $c->mode(&Hardware::iButton::Connection::SET_DATA_MODE);
    $c->send("\x44"); # start conversion. need to do a 0.5s strong pullup.
    $c->read(1); # read back 0x44
    # wait
    usleep(750*1000); # wait .75s
    $c->mode(&Hardware::iButton::Connection::SET_COMMAND_MODE);
    $c->write("\xed"); # disarm pullup
    $c->write("\xf1"); # terminate pulse
    $c->read(1); # response??

    $c->reset();
    $self->select();

    # read scratchpad, bytes 0 and 1 (LSB and MSB)
    $c->send("\xbe"); $c->read(1);
    $c->send("\xff" x 9);
    my $scratchpad = $c->read(9);
    $c->reset();
    # check CRC in last byte.
    if (Hardware::iButton::Connection::crc(0, split(//,$scratchpad))) {
	warn("scratchpadcrc was wrong");
    }
    return $scratchpad;
}

=head2 read_temperature

 $temp = $b->read_temperature();

This methods can be used on DS1822 1-Wire Thermometer. It returns
a temperature in degrees C. The range is -55C to +125C, the resolution
of the returned value is 1 degree C. The measured value has a resolution of
.0625C, which is truncated.  The value returned by the device is contained
in a 12 bit signed integer, which has a binary point at 4 bits.  To be able
to use integer arithmetic, we shift the returned value 4 bits and use just
the integral part of the number.

Useful conversions: C<$f = $c*9/5 + 32>,   C<$c = ($f-32)*5/9> .

=cut


sub read_temperature {
    my $sign = 0x0;
    my($self) = @_;
    my $scratchpad = $self->read_temperature_scratchpad($self);
    my $tempnumber = unpack("v",substr($scratchpad, 0, 2));
    # now, that's really supposed to be a signed 16-bit little-endian
    # quantity, but there isn't a pack() code for such things.
    #printf("tempnumber as read is 0x%04x 0x%04x\n",$tempnumber,$tempnumber>> 4);
    # check the sign
    $sign = 0x1000 if $tempnumber > 0x8000;
    #printf("returning 0x%04x\n",($tempnumber >> 4) - $sign );
    return ($tempnumber >> 4) - $sign;
}


package Hardware::iButton::Device::DS2423;

use Hardware::iButton::Connection;
#use Time::HiRes qw(usleep);
sub usleep {
    my($usec) = @_;
#   print "sleep2 $usec\n";
    select undef, undef, undef, ($usec / 10**6);
}


# this is the 4k RAM w/counter.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

=head2 read_counter

 $temp = $b->read_counter();

This method can be used to read the counter in DS2423 iButtons.

=cut

sub read_counter{
    my($self) = @_;
    my $c = $self->{'connection'};

    $c->reset;
    $self->select;
    $c->write(&Hardware::iButton::Connection::EXT_READ_MEMORY);
    $c->write("\xff\x01\xff\xff\xff\xff\xff\xff\xff\xff\xff");
    $c->read(4);

    usleep(25000);              # dpl Needed for reliable counter reads

    my $buf = $c->read(4);
    my $counter= unpack("V", $buf);

    $c->reset();

    return $counter;
}


package Hardware::iButton::Device::JavaButton;
use strict;
use vars qw(@ISA);

use Hardware::iButton::Connection;
#use Time::HiRes qw(usleep);
sub usleep {
    my($usec) = @_;
    print "sleep3 $usec\n";
    select undef, undef, undef, ($usec / 10**6);
}


# this is the Java button.
@ISA = qw(Hardware::iButton::Device);

sub send_apdu {
}

# an APDU is just a specially formatted buffer. a Command APDU is sent to the
# button, which responds with a Response APDU.
#  Command APDU:
#   byte header[4];  // CLA, INS, P1, P2
#   byte Lc;
#   byte *Data;
#   byte Le;
#  Response APDU
#   word Len;
#   byte *Data;
#   word SW;  // status word

# wrappers for those APDUs
#  Command Packet
#   byte len;
#   byte cmdbyte;
#   byte groupid;
#   byte cmddata[max=255]
#  Return Packet
#   byte CSB
#   byte groupid
#   byte datalen
#   byte cmddata[max=2048]

sub get_firmware_version_string {
    # apdu: class 0xd0, instruction 0x95, parm1 0x01, parm2 0x00
    # header = "\xd0\x95\x01\x00"
    # Lc = "\x00", data is uninitialized
    # Le = "\x00"

    # cmdbyte = 137, groupid = 0, len = 3+4 (3+apdu header) + 1 + lc + 1
    # data = header . lc . [lc bytes of data] . le

    # SendAPDU()
    # so arg to sendcibmessage is:
    #  len . cmdbyte(137) . groupid(0) . 
    #    [header(4bytes) . lc . data(lc bytes) . le]
    # sendcibmessage(data, len+1)
    # recvcibmessage

#an apdu has a 4-byte header: class, instruction, parm1, parm2. then lots
#of random data. class >= 0xd0 is for the ring itself, otherwise it is passed
#to the applet (which one?)

}



# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

