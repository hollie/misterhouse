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
		    'class' => 'Hardware::iButton::Device::DS2406'
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
	   "21" => {			# STOLL
		    'model' => 'DS1921',
		    'memsize' => 2048/8, # yes, really. 2K bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "thermometer",
		    'class' => 'Hardware::iButton::Device::DS1921',
		   },
	   "22" => {
		    'model' => 'DS1822',
		    'memsize' => 16/8, # yes, really. two bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "thermometer",
		    'class' => 'Hardware::iButton::Device::DS1822',
		   },
	   "26" => {			# STOLL
		    'model' => 'DS2438',
		    'memsize' => 2048/8, # yes, really. 2K bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "Humidity",
		    'class' => 'Hardware::iButton::Device::DS2438',
		   },
	   "28" => {
		    'model' => 'DS18B20',
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
	   "96" => {			# STOLL
		    'model' => 'DS1957B-406 R2.2',
		    'memsize' => 2048/8, # yes, really. 2K bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "cryptoRSA",
		    'class' => 'Hardware::iButton::Device::DS1957B',
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
    my $c = $self->{'connection'};
    return 0 if !$c->connected();
    return 1 
      if $c->scan($self->{'family'}, $self->{'raw_id'});
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






#--------------------------------------------------------------------------
# Read a Universal Data Packet from a standard NVRAM iButton 
# and return it in the provided buffer. The page that the 
# packet resides on is 'start_page'.  Note that this function is limited 
# to single page packets. The buffer 'read_buf' must be at least 
# 29 bytes long.  
#
# The Universal Data Packet always start on page boundaries but 
# can end anywhere.  The length is the number of data bytes not 
# including the length byte and the CRC16 bytes.  There is one 
# length byte. The CRC16 is first initialized to the starting 
# page number.  This provides a check to verify the page that 
# was intended is being read.  The CRC16 is then calculated over 
# the length and data bytes.  The CRC16 is then inverted and stored 
# low byte first followed by the high byte. 
#
# Supported devices: DS1992, DS1993, DS1994, DS1995, DS1996, DS1982, 
#                    DS1985, DS1986, DS2407, and DS1971. 
#
# 'portnum'    - number 0 to MAX_PORTNUM-1.  This number is provided to
#                indicate the symbolic port number.
# 'do_access'  - flag to indicate if an 'owAccess' should be
#                peformed at the begining of the read.  This may
#                be FALSE (0) if the previous call was to read the
#                previous page (start_page-1).
# 'start_page' - page number to start the read from 
# 'read_buf'   - pointer to a location to store the data read
#
# Returns:  >=0 success, number of data bytes in the buffer
#           -1  failed to read a valid UDP 
#     
#
sub readpacket {
    my $this = shift;
    my $start_page = shift;
    my $do_access = shift;
    my $c = $this->{'connection'};

    my $send;
    my $head_len = 0;
    # check if access header is done 
    # (only use if in sequention read with one access at begining)
    if ($do_access) {
	# match command
	$send .= "\x55";
	my $serial = pack( "b*", $this->{ 'raw_id' } );
	$send .= $serial;

	# read memory command
	$send .= "\xF0";

	# write the target address
	$send .= chr(($start_page << 5) & 0xFF);    
	$send .= chr($start_page >> 3);

	# check for DS1982 exception (redirection byte)
	$send .= "\xFF" if substr( $serial, 0, 1 ) eq "\x09";

	# record the header length
	$head_len = length( $send );

	$c->reset()
    }
    # read the entire page length byte
    $send .= ("\xFF" x 32);

    # send/recieve the transfer buffer   
    my $result = $c->owBlock($send);
    if ( $result ) {
	# seed crc with page number
	my $crc = $start_page;

	# attempt to read UDP from sendpacket
	print "head_len = $head_len\n";
	print join( " ", map { uc(unpack( "H*", $_ )) } split( //, $result )), "\n";
	my $length = substr( $result, $head_len, 1 );
	$crc = $c->docrc16( $crc, $length );

	# verify length is not too large
	$length = ord( $length );
	print "Length = $length\n";
	if ($length <= 29) {
	    # loop to read packet including CRC
	    my $ret = substr( $result, 0, $length );
	    $crc = $c->docrc16( $crc, $ret );
            
	    # read and compute the CRC16 
	    $crc = $c->docrc16( $crc, substr( $result, $length + 1 + $head_len, 2 ) );
         
	    # verify the CRC16 is correct           
	    return $ret if $crc == 0xB001; 
	}  
    }

    # failed block or incorrect CRC
    return undef;
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

# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

sub read_temperature_scratchpad {
    my $this = shift;
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    my $temp;

    # access the device 
    if ($this->select() ) {
	# send the convert temperature command
	$c->owBlock( "\x44" );
	
	# set the 1-Wire Net to strong pull-up
	return undef if $c->level(&Hardware::iButton::Connection::MODE_STRONG5) ne
	  &Hardware::iButton::Connection::MODE_STRONG5;
	
	# sleep to let chip compute the temperature
	select( undef, undef, undef, $this->read_temperature_time );
	
	# turn off the 1-Wire Net strong pull-up
	return undef if $c->level(&Hardware::iButton::Connection::MODE_NORMAL) ne
	  &Hardware::iButton::Connection::MODE_NORMAL;
	
	# access the device 
	if ($this->select() ) {
	    # create a block to send that reads the temperature
	    # read scratchpad command
	    # and add the read bytes for data bytes and crc8
	    my $send = "\xBE" . ( "\xFF" x 9 );
	    
	    # now send the block
	    my $result = $c->owBlock( $send );
	    if ( $result ) {
		# perform the CRC8 on the last 8 bytes of packet
		return $result if !$c->docrc8( substr( $result, 1 ) );
	    }
	}
    }
   
    return undef;
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

sub read_temperature_time { return 0.3; }
#ub read_temperature_time { return 0.9; } # Need this for slower computers ?

sub read_temperature {
    my($self) = @_;
    my $data = $self->read_temperature_scratchpad();

    if ( $data ) {
	my @data = unpack( "C*", $data );
	my $sign = $data[2] > 128 ? -1 : 1;
	my $temp = (($data[2] & 0x07) * 256 + $data[1]) / 16 * $sign;
	return $temp;
    }
    return undef;
}

sub read_temperature_hires {
    my($self) = @_;

    my $data = $self->read_temperature_scratchpad();

    if ( $data ) {
	# calculate the high-res temperature
	my @data = unpack( "C*", $data );
	my $tmp = int($data[1]/2);
	$tmp -= 128 if $data[2] & 0x01;
	my $cr = $data[7];
	my $cpc = $data[8];
	return undef if ($cpc == 0);
	$tmp = $tmp - 0.25 + ($cpc - $cr)/$cpc;
			    
	return $tmp;
    }

    return undef;
}

############## stoll ###############################
package Hardware::iButton::Device::DS1921;

use Hardware::iButton::Connection;

# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

sub read_temperature_scratchpad {
    my $this = shift;
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    my $temp;

    # access the device 
    if ($this->select() ) {
	# send the convert temperature command
	$c->owBlock( "\x44" );
	
	# set the 1-Wire Net to strong pull-up
	return undef if $c->level(&Hardware::iButton::Connection::MODE_STRONG5) ne
	  &Hardware::iButton::Connection::MODE_STRONG5;
	
	# sleep to let chip compute the temperature
	select( undef, undef, undef, $this->read_temperature_time );
	
	# turn off the 1-Wire Net strong pull-up
	return undef if $c->level(&Hardware::iButton::Connection::MODE_NORMAL) ne
	  &Hardware::iButton::Connection::MODE_NORMAL;
	
	# access the device 
	if ($this->select() ) {
	    # create a block to send that reads the temperature
	    # read scratchpad command
	    # and add the read bytes for data bytes and crc8
	    my $send = "\xBE" . ( "\xFF" x 9 );
	    
	    # now send the block
	    my $result = $c->owBlock( $send );
	    if ( $result ) {
		# perform the CRC8 on the last 8 bytes of packet
		return $result if !$c->docrc8( substr( $result, 1 ) );
	    }
	}
    }
   
    return undef;
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

sub read_temperature_time { return 0.3; }
#ub read_temperature_time { return 0.9; } # Need this for slower computers ?

sub read_temperature {
    my($self) = @_;
    my $data = $self->read_temperature_scratchpad();

    if ( $data ) {
	my @data = unpack( "C*", $data );
	my $sign = $data[2] > 128 ? -1 : 1;
	my $temp = (($data[2] & 0x07) * 256 + $data[1]) / 16 * $sign;
	return $temp;
    }
    return undef;
}

sub read_temperature_hires {
    my($self) = @_;

    my $data = $self->read_temperature_scratchpad();

    if ( $data ) {
	# calculate the high-res temperature
	my @data = unpack( "C*", $data );
	my $tmp = int($data[1]/2);
	$tmp -= 128 if $data[2] & 0x01;
	my $cr = $data[7];
	my $cpc = $data[8];
	return undef if ($cpc == 0);
	$tmp = $tmp - 0.25 + ($cpc - $cr)/$cpc;
			    
	return $tmp;
    }

    return undef;
}

############## stoll ###############################
package Hardware::iButton::Device::DS2438;
use Hardware::iButton::Connection;

# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);
sub read_humidity
{
    my($self) = @_;

    print "\nhumidity\n";

    my $Vdd = $self->Volt_Reading(1);
    my $Vad = $self->Volt_Reading(0);


    my $temp = Get_Temperature();

    my $humid = ((($Vad/$Vdd) - 0.16)/0.0062)/(1.0546 - 0.00216 * $temp);

    print "\n\n";

    my $this = shift;
    $this->Volt( @_ );


}

sub Volt_Reading
{
	my($vdd)=@_;
    my $this = shift;	
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    if (Volt_AD($vdd))
    {
    }
}

sub Volt_AD
{
	my($vdd)=@_;
    my $this = shift;	
    my $c = $this->{'connection'};
    return undef if !$c->connected();
	# access the device 
	if ($this->select() ) 
	{
	    my $send = "\xB8\x00";
	    my $result = $c->owBlock( $send );

	    $send = "\xBE\x00" . ( "\xFF" x 9 );
	    $result = $c->owBlock( $send );
	    if ( $result ) 
		{
			# perform the CRC8 on the last 8 bytes of packet
			return $result if !$c->docrc8( substr( $result, 1 ) );

			if ( $result ) 
			{
				my @data = unpack( "C*", $result );
				my $sign = substr( $result, 2 ) > 128 ? -1 : 1;
				my $temp = ((substr( $result, 2 ) & 0x07) * 256 + substr( $result, 1 )) / 16 * $sign;
				return $temp;
			}


			return $result if !$c->docrc8( substr( $result, 1 ) );
	    }
	}
}

sub Get_Temperature
{
}


package Hardware::iButton::Device::DS1957B;
# this is a crypto button.
use Hardware::iButton::Connection;

# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);


############## stoll ###############################


package Hardware::iButton::Device::DS1822;

use Hardware::iButton::Connection;
# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device Hardware::iButton::Device::DS1920 );

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

sub read_temperature_time { return 0.75; }

sub read_temperature_hires {
    my $this = shift;
    return $this->read_temperature( @_ );
}


# this is the switch button.
package Hardware::iButton::Device::DS2406;
use Hardware::iButton::Connection;
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

#----------------------------------------------------------------------
#  SUBROUTINE - ReadSwitch12
#
#	This routine gets the Channel Info Byte and returns it.
#
#	'ClearActivity' - To reset the button
#
#	Returns: (-1) If the Channel Info Byte could not be read.
#			 (Info Byte) If the Channel Info Byte could be read.
#                                                           
sub read_switch {
    my $this = shift;
    my $ClearActivity = shift;
    $ClearActivity = 1 if !defined $ClearActivity;
    my $c = $this->{'connection'};
    return undef if !$c->connected();

    # access and verify it is there
    if ($this->select) {
	# reset CRC 
	my $crc = 0;
	
	# channel access command 
	my $send = "\xF5";
	
	# control bytes                
	$send .= $ClearActivity ? "\xD5" : "\x55";
	$send .= "\xFF";
	
	$crc = $c->docrc16( $crc, $send );
   
	# read the info byte + 3 bytes of dummy data
	$send .= ("\xFF" x 4 );
 
	my $result = $c->owBlock( $send );
	if ( $result ) {
	    # read a dummy read byte and CRC16
	    $crc = $c->docrc16( $crc, substr( $result, 3 ) );
	    return ord( substr( $result, 3, 1 ) ) if $crc == 0xB001;
	}
    }

    return undef;
}

#----------------------------------------------------------------------
#	SUBROUTINE - SetSwitch12
#
#  This routine sets the channel state of the specified DS2406
#
# 'State'       - Is a type containing what to set A and/or B to.  It 
#				   also contains the other fields that maybe written later 
#
#  Returns: TRUE(1)  State of DS2406 set and verified  
#           FALSE(0) could not set the DS2406, perhaps device is not
#                    in contact
#
sub set_switch {
    my $this = shift;
    my %ARGS = @_;
    my $c = $this->{'connection'};
    return undef if !$c->connected();

    my $crc = 0;

    # access the device 
    if ( $this->select ) {
	# write status command
	my $send = "\x55";
      
	# address of switch state
	$send .= "\x07";
	$send .= "\x00";
      
	# write state
	my $st = 0x1F;
	$st |= 0x20 if ( !$ARGS{ CHANNEL_A } );
	$st |= 0x40 if ( !$ARGS{ CHANNEL_B } );

	# more ifs can be added here for the other fields.
	   
	$send .= chr( $st );

	$crc = $c->docrc16( $crc, $send );
	
	# read CRC16
	$send .= ( "\xFF" x 2 );
	
	# now send the block
	my $result = $c->owBlock( $send );
	if ( $result ) {
	    # perform the CRC16 on the last 2 bytes of packet
	    $crc = $c->docrc16( $crc, substr( $result, 4 ) );
	      
	    # verify crc16 is correct
	    return 1 if $crc == 0xB001;
	}
    }
   
    # return the result flag rt
    return undef;
}


package Hardware::iButton::Device::DS2423;

use Hardware::iButton::Connection;

# this is the 4k RAM w/counter.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

=head2 read_counter

 $temp = $b->read_counter();

This method can be used to read the counter in DS2423 iButtons.

=cut

sub read_counter {
    my $this = shift;
    my $CounterPage = shift;

    $CounterPage = 3 if !defined $CounterPage;
    $CounterPage += 12;

    # access the device 
    if ( $this->select() ) {
	my $c = $this->{'connection'};
	return undef if !$c->connected();

	# create a block to send that reads the counter
	my $send;

	# read memory and counter command
	$send .= "\xA5";

	# address of last data byte before counter
	my $address = ($CounterPage << 5) + 31;  # (1.02)
	$send .= chr($address & 0xFF);
	$send .= chr($address >> 8);

	my $crc = $c->docrc16( 0, $send );
	# now add the read bytes for data byte,counter,zero bits, crc16
	$send .= ( "\xFF" x 11 );

	# now send the block
	my $result = $c->owBlock( $send );
	if ( $result ) {
	    # perform the CRC16 on the last 11 bytes of packet
	    $crc = $c->docrc16( $crc, substr( $result, length( $send ) - 11 ) );

	    # verify CRC16 is correct
	    if ($crc == 0xB001) {
		# extract the counter value
		return unpack( "V", substr( $result, 4, 4 ) );
            }  
	}
    }
   
    # return the result flag rt
    return undef;
} 




package Hardware::iButton::Device::JavaButton;
use strict;
use vars qw(@ISA);

use Hardware::iButton::Connection;
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

