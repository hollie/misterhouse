# $Date$
# $Revision$

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
       "05" => {			# Jon Upham
            'model' => 'DS2405',
            'memsize' => 0,
            'memtype' => "none",
            'specialfuncs' => "pio",
            'class' => 'Hardware::iButton::Device::DS2405'
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
		    'mintime' => 0,
		    'maxtime' => .9,
		   },
	   "28" => {
		    'model' => 'DS18B20',
		    'memsize' => 16/8, # yes, really. two bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "thermometer",
		    'class' => 'Hardware::iButton::Device::DS18B20',
		    'mintime' => 0,
		    'maxtime' => .9,
		   },
           "20" => {			# Brian Rudy
                    'model' => 'DS2450',
                    'memsize' => 4*8/8, # 4 pages of 8 bytes.   
                    'memtype' => "??",
                    'specialfuncs' => "ADC",
                    'class' => 'Hardware::iButton::Device::DS2450'
                   },
	   "21" => {			# STOLL
		    'model' => 'DS1921',
		    'memsize' => 2048/8, # yes, really. 2K bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "thermometer",
		    'class' => 'Hardware::iButton::Device::DS1921',
		    'mintime' => 0,
		    'maxtime' => .9,
		   },
	   "22" => {
		    'model' => 'DS1822',
		    'memsize' => 16/8, # yes, really. two bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "thermometer",
		    'class' => 'Hardware::iButton::Device::DS1822',
		    'mintime' => 0,
		    'maxtime' => .9,
		   },
	   "26" => {			# STOLL
		    'model' => 'DS2438',
		    'memsize' => 2048/8, # yes, really. 2K bytes.
		    'memtype' => "EEPROM",
		    'specialfuncs' => "Humidity",
		    'class' => 'Hardware::iButton::Device::DS2438',
		   },
 	  "29" => {
		    'model' => 'DS2408',
		    'memsize' => 1024/8, 
		    'memtype' => "EEPROM",
		    'specialfuncs' => "pio",
		    'class' => 'Hardware::iButton::Device::DS2408',
		    'mintime' => 0,
		    'maxtime' => .9,
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
           "1f" => {                    #JFM
                    'model' => 'DS2409',
                    'memsize' => 0,
                    'memtype' => 'none',
                    'specialfuncs' => "Microlan Coupler",
                    'class' => 'Hardware::iButton::Device::DS2409',
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
    $self->{'coupler'}='';
    $self->{'branch'}='';

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

sub raw_id { # Added by Jon Upham
    return $_[0]->{'raw_id'};
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


package Hardware::iButton::Device::TemperatureButton;
# this is a class that other temperature devices will inherit from

use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

sub read_temperature_time {
    my $this = shift;
    my $maxTime = shift;

    if ( $maxTime ) {
	# this isn't good - it means the last calculation failed
	# if mintime and maxtime are close (within 0.1 second, add
	# additional time to each
	if ( $this->{ 'maxtime' } - $this->{ 'mintime' } < 0.02 ) {
	    $this->{ 'mintime' } += .01;
	    $this->{ 'maxtime' } += .01;
	}
    }

    if ( $maxTime || !$this->{ 'mintime' } ) {
	return $this->{ 'maxtime' };
    }
    else {
	return ( $this->{ 'mintime' } + $this->{ 'maxtime' } ) / 2;
    }
}

sub update_temperature_time {
    my $this = shift;
    my $goodTime = shift;

    if ( !$this->{ 'mintime' } ) {
	$this->{ 'mintime' } = .01 if $goodTime;
	return;
    }

    my $calcTime = $this->read_temperature_time();
    if ( $goodTime ) {
	$this->{ 'maxtime' } = $calcTime;
    }
    else {
	$this->{ 'mintime' } = $calcTime;
    }
}

sub read_temperature_scratchpad {
    my $this = shift;
    my $maxTime = shift;
    my $c = $this->{'connection'};
    return undef if !$c->connected();

    # access the device
    if ($this->select() ) {
	# send the convert temperature command
	$c->owBlock( "\x44" );

	# set the 1-Wire Net to strong pull-up
	return undef if $c->level(&Hardware::iButton::Connection::MODE_STRONG5) ne
	  &Hardware::iButton::Connection::MODE_STRONG5;

	# sleep to let chip compute the temperature
	my $time = $this->read_temperature_time( $maxTime );
#	print STDERR " $time ";
	select( undef, undef, undef, $time );
	
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

sub read_temperature {
    my($self) = @_;

    my $c = $self->{'connection'};
    return if !$c->id_on_wire( $self->id() );
    print "Reading Temperature ";
    for ( 0..1 ) {
	my $data = $self->read_temperature_scratchpad( $_ );
	if ( $data ) {
	    my @data = unpack( "C*", $data );
	    #print "Data0 $data[0] Data1 $data[1] Data2 $data[2]\n";
	    my $sign = $data[2] > 128 ? -1 : 1;
	    my $temp = (($data[2] & 0x07) * 256 + $data[1]) / 16 * $sign;
	    if ( $temp == 85 ) { # this is a result from too short of a read time
		$self->update_temperature_time( 0 );
		next;
	    }
	    elsif ( !$_ )  {
		$self->update_temperature_time( 1 );
	    }

	    return $temp;
	}
	elsif ( !$_ ) {
	    $self->update_temperature_time( 0 );
	    next;
	}
    }
    return undef;
}

sub read_temperature_18B20 {
    my($self) = @_;
    my $temp;
    my $c = $self->{'connection'};
    #return if !$c->id_on_wire( $self->id() );

    for ( 0..1 ) {
	my $data = $self->read_temperature_scratchpad( $_ );
	if ( $data ) 
	{
	 my @data = unpack( "C*", $data );
#	print "18B20: Data1 $data[1] Data2 $data[2]\n";
	my $sign = $data[2] > 128 ? 0 : 1;

		if ($sign)   #Positive Number				
		{
		$temp = ($data[2]* 256 + $data[1]) / 16;
		}
		else		#2's Compliment
		{
		$temp = ($data[2]* 256 + $data[1]);
		$temp = (~$temp +1);
		$temp = ($temp & 0x7FF);
 		$temp = ($temp /16 * -1);
		}	
	   
	if ( $temp == 85 ) { # this is a result from too short of a read time
		$self->update_temperature_time( 0 );
		next;
	}
	elsif ( !$_ )  {
	$self->update_temperature_time( 1 );
	}

	return ($temp);
	}
	elsif ( !$_ ) {
	    $self->update_temperature_time( 0 );
	    next;
	}
    }
    return undef;
}



sub read_temperature_hires {
    my $self = shift;
    #my($self) = @_;
   
    my $c = $self->{'connection'};

    #return if !$c->id_on_wire( $self->id() );
    for ( 0..1 ) {
	my $data = $self->read_temperature_scratchpad( $_ );
	if ( $data ) {
	    # calculate the high-res temperature
	    my @data = unpack( "C*", $data );
	    my $tmp = int($data[1]/2);
	    $tmp -= 128 if $data[2] & 0x01;
	    my $cr = $data[7];
	    my $cpc = $data[8];
	    if ($cpc == 0) {
		if ( !$_ ) {
		    $self->update_temperature_time( 0 );
		    next;
		}
		return undef;
	    }
	    $tmp = $tmp - 0.25 + ($cpc - $cr)/$cpc;

	    if ( $tmp == 85 ) { # this is a result from too short of a read time
		$self->update_temperature_time( 0 );
		next;
	    }
	    elsif ( !$_ )  {
		$self->update_temperature_time( 1 );
	    }
		
	    return $tmp;
	}
        
    }

    return undef;
}

package Hardware::iButton::Device::DS1920;

use Hardware::iButton::Connection;

# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device Hardware::iButton::Device::TemperatureButton);


=head2 read_temperature

 $temp = $b->read_temperature();
 $temp = $b->read_temperature_hires();

These methods can be used on DS1820/DS1920 Thermometer iButtons. They return
a temperature in degrees C. The range is -55C to +100C, the resolution of the
first is 0.5C, the resolution of the second is about 0.01C. The accuracy is
about +/- 0.5C.

Useful conversions: C<$f = $c*9/5 + 32>,   C<$c = ($f-32)*5/9> .

=cut

############## stoll ###############################
package Hardware::iButton::Device::DS1921;

use Hardware::iButton::Connection;

# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device Hardware::iButton::Device::TemperatureButton);

=head2 read_temperature

 $temp = $b->read_temperature();
 $temp = $b->read_temperature_hires();

These methods can be used on DS1820/DS1920 Thermometer iButtons. They return
a temperature in degrees C. The range is -55C to +100C, the resolution of the
first is 0.5C, the resolution of the second is about 0.01C. The accuracy is
about +/- 0.5C.

Useful conversions: C<$f = $c*9/5 + 32>,   C<$c = ($f-32)*5/9> .

=cut

############## stoll ###############################
package Hardware::iButton::Device::DS2438;
use Hardware::iButton::Connection;

# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);
#
# From SHTxx Sensmitter Humidity & Temperature Application Note 
# Dewpoint calculation 
#    1 Introduction 
# From the relative humidity and temperature the dewpoint temperature can 
# easily be calculated. 
#    2 Revision History 
# November 18, 2001    C2  URO    Revision 0.9 (Preliminary) 
#    3  Theory 
# Definition of dewpoint: 
# The temperature that the air must reach for the air to hold the maximum
# amount of moisture it can. When the temperature cools 
# to the dewpoint, the air becomes saturated and fog, or dew or frost 
# can occur. 
# 
# The  following  formula (F.A.Berry,Jr. Handbook of Meteorology, McGraw-Hill
# Book Company, 1945, page 343) calculates  the  dewpoint  from  relative  
# humidity  and  temperature.  All temperatures  are  in Celsius. 
# 
# EW = 10^ ( 0.66077+7.5*T/ (237.3+T) ) %                            saturation vapor pressure over water.
# EW_RH = EW * RH / 100 %                                            multiply with relative humidity
# Dp = ((0.66077-log10(EW_RH))*237.3) % / (log10(EW_RH)-8.16077) %   dewpoint
# Simplified:
# LogEW = ( 0.66077+7.5*T/ (237.3+T)+(log10(RH)-2)   %
# Dp = ((0.66077-logEW)*237.3) / (logEW-8.16077) % this is the dewpoint 
# Example:   RH=10% T=25C     -> EW=  23.7465 -> Dewpoint = -8.69°C 
#            RH=90% T=50C     -> EW=  92.4753 -> Dewpoint = 47.89°C 
# 
# This formula is a commonly used approximation. See Figure 1 for the 
# deviation to the actual value between .40°C and 100°C. 
# A more far more complex calculation is described in 
#     Bob Hardy, Thunder Scientific Corporation, Albuquerque, NM, USA 
#     The proceedings of the Third international Symposium on Humidity 
#     & Moisture, Teddington, London, England, April 1998. 
# 
# See DS2438 datasheet for more details on the operation of this object
#
# Bytes seem to be offset by +2 for retrieval
# Byte 0 - Status/Configuration
# Byte 1&2 - Temp
# Byte 3&4 - Voltage
# Byte 5&6 - Current
# Byte 7 Threshold
# Byte 8 CRC

sub Get_Temp_2438{
    # This is common to all DS2438 readings - in Celsius
    my $result="";
    my $this = shift;
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    if ($this->select()) {my $result = $c->owBlock("\x4E\x00\x00");}  # Write SP  - ICA CA EE act
    #if ($this->select()) {my $result = $c->owBlock("\x48\x00");}      # Copy SP
    if ($this->select()) {my $result = $c->owBlock("\x44");}          # Temp Convert
    if ($this->select()) {my $result = $c->owBlock("\xB8\x00");}      # Memory Recall Page0
    if ($this->select()) {
        my $result = $c->owBlock("\xBE\x00".("\xFF" x 9));    # Read 9 bytes from Page0
        if ($result)
        {
            # return undef if !$c->docrc8(substr ($result,1)); # Perform CRC no last eight bytes
            #collect @data[3] and @data[4] for Temp
            #compare @data[2] to 7 for proper Vad setting
            my @data = unpack("C*",$result);
            #if ((@data[2] & 7) ne 7)
            #{
            #    if ($this->select()) {
            #        my $result = $c->owBlock("\x4E\x00\x07");
            #        my $result = $c->owBlock("\x48\x00");
            #    }  # Write SP  - ICA CA EE active
            #}
            my $sign = $data[4] > 128 ? -1 : 1;
            my $temp = sprintf ("%3.2f",((($data[4] * 256) + $data[3]) * $sign * 0.03125 / 8));
            #$temp = sprintf ("%3.2f",$temp);
            return $temp;
        }
        else
        {
            return undef;
        }
    }
    else
    {
        return undef;
    }
}

sub Get_Vad_2438{
    my $this = shift;
    my $result="";
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    if ($this->select()) {my $result = $c->owBlock("\x4E\x00\x00");}  # Write SP  - ICA CA EE act
    #if ($this->select()) {my $result = $c->owBlock("\x48\x00");}      # Copy SP
    if ($this->select()) {my $result = $c->owBlock("\xB4");}          # Volt Convert A/D
    if ($this->select()) {my $result = $c->owBlock("\xB8\x00");}      # Memory Recall Page0
    if ($this->select()) {
        my $result = $c->owBlock("\xBE\x00".("\xFF" x 9));   # Read 9 bytes from Page0
        if ($result)
        {
            #collect @data[5] and @data[6] for Volt
            #compare @data[2] to 7 for proper Vad setting
            my @data = unpack("C*",$result);
            #if ((@data[2] & 7) ne 7)
            #{
            #    if ($this->select()) {my $result = $c->owBlock("\x4E\x00\x07");}  # Write SP  - ICA CA EE act
            #}
            my $volt = sprintf ("%3.2f",((($data[6] * 256) + $data[5])/100));
            return $volt;
        }
        else
        {
            return undef;
        }
    }
    else
    {
        return undef;
    }
}

sub Get_Vdd_2438{
    my $this = shift;
    my $result="";
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    if ($this->select()) {my $result = $c->owBlock("\x4E\x00\x08");}  # Write SP  - ICA CA EE AD act
    #if ($this->select()) {my $result = $c->owBlock("\x48\x00");}      # Copy SP
    if ($this->select()) {my $result = $c->owBlock("\xB4");}          # Volt Convert A/D
    if ($this->select()) {my $result = $c->owBlock("\xB8\x00");}      # Memory Recall Page0
    if ($this->select()) {
        my $result = $c->owBlock("\xBE\x00".("\xFF" x 9));    # Read 9 bytes from Page0
        if ($result)
        {
            #collect @data[5] and @data[6] for Volt
            #compare @data[2] to 15 for proper Vdd setting
            my @data = unpack("C*",$result);
            #if ((@data[2] & 15) ne 15)
            #{
            #    if ($this->select()) {my $result = $c->owBlock("\x4E\x00\x0F");}  # Write SP  - ICA CA EE act
            #}
            my $volt = sprintf ("%3.2f",((($data[6] * 256) + $data[5])/100));
                return $volt;
        }
        else
        {
            return undef;
        }
    }
    else
    {
        return undef;
    }
}

sub Get_Vsens_2438{
    my $this = shift;
    my $result="";
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    # Convert temp
    if ($this->select()) {my $result = $c->owBlock("\x4E\x00\x00");}  # Write SP  - ICA CA EE AD act
    #if ($this->select()) {my $result = $c->owBlock("\x48\x00");}      # Copy SP
    if ($this->select()) {my $result = $c->owBlock("\xB4");}          # Volt Convert A/D
    if ($this->select()) {my $result = $c->owBlock("\xB8\x00");}      # Memory Recall Page0
    if ($this->select()) {
        my $result = $c->owBlock("\xBE\x00".("\xFF" x 9));   # Read 9 bytes from Page0
        if ($result)
        {
            #collect @data[7] and @data[8] for Volt
            #compare @data[2] to 7 for proper Vad setting
            my @data = unpack("C*",$result);
            #if ((@data[2] & 7) ne 7)
            #{
            #    if ($this->select()) {my $result = $c->owBlock("\x4E\x00\x07");}  # Write SP  - ICA CA EE act
            #}
            my $volt = sprintf ("%3.2f",((($data[8] * 256) + $data[7])/100));
            return $volt;
        }
        else
		{
	       	return undef;
        }	
    }
    else
    {
        return undef;
    }
}

# adds support for the water sensor from ibuttonlink

sub Get_Vwet_2438 {
	#Get the water information for the ibuttonlink MS-TW or MS-THW
	#http://www.ibuttonlink.com/PDFs/MS-THW%20programmers%20guide.pdf
	# Returns 
	#  0: connected and dry
	#  1: no line continuity/cable detected - something wrong
	#  2: connected and wet
	my $this = shift;
	my $result="";
	my $c = $this->{'connection'};
	return undef if !$c->connected();
	#if ($this->select()) {my $result = $c->owBlock("\x00\x4E\x00\x00");}  # 0x004E Write Scratchpad (two blank spaces)
	if ($this->select()) {my $result = $c->owBlock("\x00\xB4");}               # 0x00B4 Convert Voltage (Causes Water Detection test to execute)
	#if ($this->select()) {my $result = $c->owBlock("\x00\x05");}          # 0x0005 Save the WD Threshold and WDFloor Registers to EEPROM
	#if ($this->select()) {my $result = $c->owBlock("\x00\xB8\x00");}      # 0x00B8 Recall Memory to Scratchpad (Receives 1 byte EEPROM address)
	if ($this->select()) {
		my $result = $c->owBlock("\x00\x03".("\xFF" x 10));   # 0x00BE Read Scratchpad (Returns up to 10 bytes)  0x0003 Read the contents of the WD registers (Returns up to 10 bytes)
		if ($result)
		{
			# Break out all of the data into its appropriate values
			# The detection floor and detection threshold have been set at the factory, but 
			# can be changed with 0x0004 and written to eeprom/persistent memory with 0x0005.
			# The detection floor is set to the no cable reading of the sensor.
			# The detection threshold is set to the detection floor + 55 ticks.
			# $detected is a calculation done by the DS2438 based on continuity, detected value, threshold, and floor.
			my @data = unpack("C*",$result);
			# ($data[1]*256) + $data[0] is the command sent with owBlock
			my $detected = $data[2];# detection of water - 2 is working and wet, 0 is working and dry, 1 is not working, based on detection value, continuity, and threshold.
			my $continuity = ($data[4]*256) + $data[3]; # value of line continuity/a cable attached. Close to 0 is no.
			my $det_value = ($data[6]*256) + $data[5]; # Detection value, can be used instead of $detected if you want to sense degrees of wet, and set your own thresholds. will return degree of wetness instead of absolute wet/dry.
			my $det_threshold = ($data[8]*256) + $data[7]; #Detection threshold. 
			my $det_floor = ($data[10]*256) + $data[9]; # Detection floor. 
			my $crc = $data[11]; # CRC
			#return ($detected, $continuity, $det_value, $det_threshold, $det_floor, $crc);
			return $detected;
            
			# The same thing, in hex for educational purposes.
			# Doesn't actually occur, as the decimal above does "return".
			# Break out all of the hex into characters, swap the bytes around, and convert to decimal
			my $data = unpack("H*",$result);
			my @data = split(//,$data);
			# $data[0-3] is the code of the request sent with owBlock
			my $detected = hex($data[4].$data[5]); # detection of water - 2 is working and wet, 0 is working and dry, 1 is not working, based on detection value, continuity, and threshold.
			my $continuity = hex($data[8].$data[9].$data[6].$data[7]); # value of line continuity/a cable attached. Close to 0 is no.
			my $det_value = hex($data[12].$data[13].$data[10].$data[11]); # Detection value, can be used instead of $detected if you want to sense degrees of wet, and set your own thresholds. will return degree of wetness instead of absolute wet/dry.
			my $det_threshold = hex($data[16].$data[17].$data[14].$data[15]); #Detection threshold. 
			my $det_floor = hex($data[20].$data[21].$data[18].$data[19]); # Detection floor. 
			my $crc = hex($data[22].$data[23]); # CRC
			#return ($wet, $detected, $continuity, $det_value, $det_threshold, $det_floor, $crc);
			#return $detected;
		}
		else { return -1; 
		}
	} else { return undef; 
	}
}

sub read_temperature_hires {
    my $this = shift;
    return $this->read_temperature_18B20( @_ );
}


package Hardware::iButton::Device::DS1957B;
# this is a crypto button.
use Hardware::iButton::Connection;

# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);


package Hardware::iButton::Device::DS18B20;
use Hardware::iButton::Connection;
# this is the thermometer button.
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device Hardware::iButton::Device::DS1920 );
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

sub read_temperature_hires {
    my $this = shift;
    return $this->read_temperature_18B20( @_ );
}


package Hardware::iButton::Device::DS2405;

use Hardware::iButton::Connection;

# This code supports using the DS2405's native functions: toggling and reading the state
# See the data sheet for more information on this device.  Implemented here by Jon Upham.

use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

=head2 toggle2405

Use this like other 1-wire devices in this module.

=cut

sub toggle2405{
    my $this = shift;
    my $serial = pack( "b*", $this->raw_id() );
    my $c = $this->{'connection'};
    my $send;

    # reset the 1-wire
    if ($this->reset()) {
	# create a buffer to use with block function
	# match Serial Number command 0x55
	$send .= "\x55";

	# Serial Number
	$send .= $serial;

      $send .= "\xFF"; # Added to send enough bits to read the return from the 2405

	# send/recieve the transfer buffer
	my $result = $c->owBlock( $send );

#print "Sent:  ".unpack("b*",$send)."\n";
#print "Result:".unpack("b*",$result)."\n";

      # now get the last bit of the unpacked result and that's the state!
      my $rv = unpack("b*",$result);
      my $state2405 = substr($rv,length($rv)-1,1);
#print "State: $state2405\n";
	return $state2405
    }

    # reset or match echo failed
    return -1;
}

=head2 query2405

Use this like other 1-wire devices in this module.
This code should look familiar to the FindDevices code in Connection.pm

=cut

sub query2405{
    my $this = shift;
    my $serial = pack( "b*", $this->raw_id() );
    my $c = $this->{'connection'};

	my @tmpSerial = split //, unpack( "b*", $serial );
	my $send;

	# construct the search rom
	$send .= "\xF0";

	my @tmpSend = ( 1 ) x (24 * 8);

	# now set or clear apropriate bits for search
	foreach my $i ( 0..63 ) {
	    $tmpSend[3*($i+1)-1] = $tmpSerial[$i];
	}

	$send .= pack( "b*", join( "", @tmpSend ) );

	#Add a /xFF so that we'll receive the status of the 2405 back

	$send .= "\xFF";

	# send/recieve the transfer buffer
	$this->reset();
	my $result = $c->owBlock( $send );
	if ( $result ) {
	    # check results to see if it was a success
	    my @result = split //, unpack( "b*", substr( $result, 1 ) );
	    my $cnt = 0;
	    my $goodbits = 0;
	    for (my $i = 0; $i < 192; $i += 3) {
		my $tst = ( $result[$i] << 1 ) | $result[$i+1];
		my $s = $tmpSerial[$cnt++];

		if ($tst == 0x03) {
		    # no device on line
		    $goodbits = 0;    # number of good bits set to zero
		    last;     # quit
		}

		if ( ( $s == 0x01 && $tst == 0x02 ) ||
		     ( $s == 0x00 && $tst == 0x01 ) ) {
		    # correct bit
		    $goodbits++;  # count as a good bit
		}
	    }

	    # check too see if there were enough good bits to be successful
      if ($goodbits >=8){
         my $rv = unpack("b*",$result);
         my $state2405 = substr($rv,length($rv)-1,1);
         print "State: $state2405\n";
	   return $state2405
      }
	    return ( -1) if $goodbits >= 8;
	}

	# block fail or device not present

print "problem sending reset...\n";

	return (-2);

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
    my $temp = 0;	
    my $ClearActivity = shift;
    $ClearActivity = 1 if !defined $ClearActivity;
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    my $channel = $this->{channel};
    $channel = 'A' unless $channel;
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
            $temp = ord(substr( $result, 3, 1 ));
            if ($crc == 0xB001){
                if ($channel eq "A") {
                    if (($temp & 4) eq 4) {
                        return 1;}
                    else {
                        return 0; }
                }
                if ($channel eq "B") {
                    if (($temp & 8) eq 8) {
                        return 1;}
                    else { 
                        return 0;}
                }
            } # END CRC Check
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

# this is the 8 bit i/o soip device
package Hardware::iButton::Device::DS2408;
use Hardware::iButton::Connection;
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

sub read_logic_state_2408 {
    my $this = shift;
    my $serial = pack( "b*", $this->raw_id() );
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    my $channel = $this->{channel};
    my $send;

    # reset the 1-wire
    if ($this->reset()) {
	# create a buffer to use with block function
	# match Serial Number command 0x55
	$send .= "\x55";

	# Serial Number
	$send .= $serial;

      $send .= "\xF0"; # Read PIO Register
      $send .= "\x88"; # Read Reg 0088
      $send .= "\x00";
      $send .= "\xFF"; # I don't understand this, but everyone else did it????

	# send/recieve the transfer buffer
	my $result = $c->owBlock( $send );
      my $rv = unpack("b*",$result);
      my $bits2408 = substr($rv,length($rv)-8,8);
      # OK, the bits are bass ackwards, leave them that way to make the substr easier!!
      my $state2408 = substr($bits2408,$channel,1);
      #print "State=$state2408 bits=$bits2408\n";
	return $state2408;
    }

    # reset or match echo failed
    return -1;
}

sub read_reg_state_2408 {
    my $this = shift;
    my $serial = pack( "b*", $this->raw_id() );
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    my $channel = $this->{channel};
    my $send;

    # reset the 1-wire
    if ($this->reset()) {
	# create a buffer to use with block function
	# match Serial Number command 0x55
	$send .= "\x55";

	# Serial Number
	$send .= $serial;

      $send .= "\xF0"; # Read PIO Register
      $send .= "\x88"; # Read Reg 0088
      $send .= "\x00";
      $send .= "\xFF"; # I don't understand this, but everyone else did it????

	# send/recieve the transfer buffer
	my $result = $c->owBlock( $send );
      my $rv = unpack("b*",$result);
      my $bits2408 = substr($rv,length($rv)-8,8);
      #print "Register=$bits2408\n";
      return $bits2408;
    }

    # reset or match echo failed
    return -1;
}

sub read_change_state_2408 {
    my $this = shift;
    my $serial = pack( "b*", $this->raw_id() );
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    my $channel = $this->{channel};
    my $send;

    # reset the 1-wire
    if ($this->reset()) {
	# create a buffer to use with block function
	# match Serial Number command 0x55
	$send .= "\x55";

	# Serial Number
	$send .= $serial;

      $send .= "\xF0"; # Read PIO Register
      $send .= "\x8A"; # Read Reg 008A -Activity Latch
      $send .= "\x00";
      $send .= "\xFF"; # I don't understand this, but everyone else did it????
     # send/recieve the transfer buffer
	my $result = $c->owBlock( $send );
      my $rv = unpack("b*",$result);
      my $bits2408 = substr($rv,length($rv)-8,8);
     # print "Changed=$bits2408\n";

	#Reset The Activity Latches
	$this->reset();
	$send = "\x55";
	# Serial Number
	$send .= $serial;
        $send .= "\xC3"; # Read PIO Register
	$result = $c->owBlock( $send );

	return $bits2408;
    }

    # reset or match echo failed
    return -1;
}


sub read_op_state_2408 {
    my $this = shift;
    my $serial = pack( "b*", $this->raw_id() );
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    my $channel = $this->{channel};
    my $send;

    # reset the 1-wire
    if ($this->reset()) {
	# create a buffer to use with block function
	# match Serial Number command 0x55
	$send .= "\x55";

	# Serial Number
	$send .= $serial;

      $send .= "\xF0"; # Read PIO Register
      $send .= "\x89"; # Read Reg 0088
      $send .= "\x00";
      $send .= "\x11"; # I don't understand this, but everyone else did it????

	# send/recieve the transfer buffer
      my $result = $c->owBlock( $send );
      my $rv = unpack("b*",$result);
      my $bits2408 = substr($rv,length($rv)-8,8);
      #print "Register=$bits2408\n";
      return $bits2408;
    }
}



sub write_reg_2408 {
    my ($this,$state) = @_;
    my $serial = pack( "b*", $this->raw_id() );
    my $c = $this->{'connection'};
    return undef if !$c->connected();
    my $send;
    my $sendat;
    my $sendatx;
    my $isendatx;
    $sendat=$state* 1;
    $sendatx = pack('h2',$sendat);  #Must Be Binary Data
    $isendatx = ~$sendatx;  #Bitwise Inverted for data security
   
    # reset the 1-wire
    if ($this->reset()) {
	# create a buffer to use with block function
	# match Serial Number command 0x55
	$send = "\x55";
	$send .= $serial;
	$send .= "\x5A"; # Write  Register (defaults to 88)
	$send .= $isendatx;
        $send .= $sendatx;
	# send/recieve the transfer buffer
        print "Send = $send\n";
	my $result = $c->owBlock( $send );
      $this->reset();

      my $rv = unpack("b*",$result);
      my $bits2408 = substr($rv,length($rv)-8,8);
      return $bits2408;
    }

    # reset or match echo failed
    return -1;
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


package Hardware::iButton::Device::DS2450;
        
use Hardware::iButton::Connection;

# This code supports setup, A/D conversion, memory read/write and 
# switch operations for the DS2450 quad A/D converter. There is presently 
# no support for alarm operations.
#
# Version 0.2, 4-12-2003  Brian Rudy (brudyNO@SPAMpraecogito.com)
# Added CRC support, fixed a few bugs.
#
# Version 0.1, 4-9-2003  Brian Rudy (brudyNO@SPAMpraecogito.com)
# First working version. No CRC support.

use strict;
use vars qw(@ISA);
        
@ISA = qw(Hardware::iButton::Device);
 
=head2 setup

 $b->setup($VCC,\%A,\%B,\%C,\%D);

This method can be used to set the input parameters in DS2450 iButtons. 
$VCC must be set to 1 if the device is powered by VCC. \%A-\%D are
references to the channel configuration hashes.
 $A{type} = AD or switch
 $A{resolution} = AD resolution from 1 to 16
 $A{range} = 5.12 or 2.56
 $A{state} = 1/on or 0/off (in switch mode turn the switch on or off)

=cut

sub setup {
  my ($this,$VCC,$A,$B,$C,$D) = @_;

  #print "VCC=$VCC, A mode " . $A->{type} . ", B mode " .
  # $B->{type} . ", C mode " . $C->{type} . ", D mode " . 
  # $D->{type} . ".\n";
  my $c = $this->{'connection'};
  my $crc = 0;
  my $send;
  my $result;
  my @res;
  return undef if !$c->connected();
  # access the device
  if ( $this->select ) {
    if ($VCC) {
      $send = "\x55";   # write memory
      $send .= "\x1C";	# to 001c
      $send .= "\x00";
      $send .= "\x40";	# VCC operation
      $crc = $c->docrc16( 0, $send);
      # now send the block
      $result = $c->owBlock( $send . ("\xFF" x 3));
      # Check the CRC
      $crc = $c->docrc16( $crc, substr($result,-3,2) );
      $this->reset;
      $this->select;
      if ($crc != 0xB001) {
        print "Failed CRC16 check!\n";
        return undef;
      }
    }
    $send = "\x55";    	  # write memory
    $send .= "\x08";	  # Start at address 0008
    $send .= "\x00";
    
    #### Channel A
    if ($A->{type} =~ m/ad/i) {
      $send .= pack "C", ($A->{resolution} - 1);    # How many bits?
    }
    else {
      # Set OE=1, and OC=1 or 0 
      $send .= ($A->{state} =~ m/on|1/i) ? "\x80" : "\xC0";
    }
    $result = $c->owBlock( $send . ("\xFF" x 3));

    $crc = $c->docrc16( 0, $send ); 
    # CRC16
    $crc = $c->docrc16( $crc, substr($result,-3,2) ); 
    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      $this->reset;
      return undef;
    }

    if ($A->{type} eq 'AD') {
      if ($A->{range} > 2.56) {
        $send = "\x01";   # 5.12V range
      }
      else {
        $send = "\x00";   # 2.56 range
      }
    }
    else {
      # Set the upper and lower alarm values
      # Need to set behavior somehow
      $send = "\x00";
    }
    $result = $c->owBlock( $send . ("\xFF" x 3));

    $crc = 0x0009;  # seed the CRC generator with the new address
    $crc = $c->docrc16( $crc, $send );
    # CRC16 + read back bit
    $crc = $c->docrc16( $crc, substr($result,-3,2) );
    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      $this->reset;
      return undef;
    }


    #### Channel B
    if ($B->{type} =~ m/ad/i) {
      $send = pack "C", ($B->{resolution} - 1);    # How many bits?
    }
    else {
      # Set OE=1, and OC=1 or 0 
      $send = ($B->{state} =~ m/on|1/i) ? "\x80" : "\xC0";
    }
    $result = $c->owBlock( $send . ("\xFF" x 3));

    $crc = 0x000A;  # seed the CRC generator with the new address
    $crc = $c->docrc16( $crc, $send );
    # CRC16 + read back bit
    $crc = $c->docrc16( $crc, substr($result,-3,2) );
    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      $this->reset;
      return undef;
    } 

    if ($B->{type} eq 'AD') {
      if ($B->{range} > 2.56) {
        $send = "\x01";   # 5.12V range
      }
      else {
        $send = "\x00";   # 2.56 range
      }
    }
    else {
      # Set the upper and lower alarm values
      # Need to set behavior somehow
      $send = "\x00";
    }
    $result = $c->owBlock( $send . ("\xFF" x 3));
    $crc = 0x000B;  # seed the CRC generator with the new address
    $crc = $c->docrc16( $crc, $send );
    # CRC16 + read back bit
    $crc = $c->docrc16( $crc, substr($result,-3,2) );
    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      $this->reset;
      return undef;
    } 


    #### Channel C
    if ($C->{type} =~ m/ad/i) {
      $send = pack "C", ($C->{resolution} - 1);    # How many bits?
    }
    else {
      # Set OE=1, and OC=1 or 0 
      $send = ($C->{state} =~ m/on|1/i) ? "\x80" : "\xC0";
    }
    $result = $c->owBlock( $send . ("\xFF" x 3));

    $crc = 0x000C;  # seed the CRC generator with the new address
    $crc = $c->docrc16( $crc, $send );
    # CRC16 + read back bit
    $crc = $c->docrc16( $crc, substr($result,-3,2) );
    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      $this->reset;
      return undef;
    } 

    if ($C->{type} eq 'AD') {
      if ($C->{range} > 2.56) {
        $send = "\x01";   # 5.12V range
      }
      else {
        $send = "\x00";   # 2.56 range
      }
    }
    else {
      # Set the upper and lower alarm values
      # Need to set behavior somehow
      $send = "\x00";
    }
    $result = $c->owBlock( $send . ("\xFF" x 3));

    $crc = 0x000D;  # seed the CRC generator with the new address
    $crc = $c->docrc16( $crc, $send );
    # CRC16 + read back bit
    $crc = $c->docrc16( $crc, substr($result,-3,2) );
    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      $this->reset;
      return undef;
    } 


    #### Channel D
    if ($D->{type} =~ m/ad/i) {
      $send = pack "C", ($D->{resolution} - 1);    # How many bits?
    }
    else {
      # Set OE=1, and OC=1 or 0
      $send = ($D->{state} =~ m/on|1/i) ? "\x80" : "\xC0";
    }
    $result = $c->owBlock( $send . ("\xFF" x 3));

    $crc = 0x000E;  # seed the CRC generator with the new address
    $crc = $c->docrc16( $crc, $send );
    # CRC16 + read back bit
    $crc = $c->docrc16( $crc, substr($result,-3,2) );
    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      $this->reset;
      return undef;
    } 

    if ($D->{type} =~ m/ad/i) {
      if ($D->{range} > 2.56) {
        $send = "\x01";   # 5.12V range
      }
      else {
        $send = "\x00";   # 2.56 range
      }
    }
    else {
      # Set the upper and lower alarm values
      # Need to set behavior somehow
      $send = "\x00";
    }
    $result = $c->owBlock( $send . ("\xFF" x 3));

    $crc = 0x000F;  # seed the CRC generator with the new address
    $crc = $c->docrc16( $crc, $send );
    # CRC16 + read back bit
    $crc = $c->docrc16( $crc, substr($result,-3,2) );
    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      $this->reset;
      return undef;
    } 

    # Save the setup info for this device if we are sucessful
    $this->{'VCC'} = $A->{VCC};
    $this->{'A_range'} = ($A->{range} > 2.56) ? 5.12 : 2.56;
    $this->{'B_range'} = ($B->{range} > 2.56) ? 5.12 : 2.56;
    $this->{'C_range'} = ($C->{range} > 2.56) ? 5.12 : 2.56;
    $this->{'D_range'} = ($D->{range} > 2.56) ? 5.12 : 2.56;
    
    $this->reset;
    return 1;
  }
  return undef;
}

=head2 convert

 $b->convert($channel)

This method initiates a A/D conversion for the selected channel/s in 
DS2450 iButtons.

 $channel = ABCD or ALL

$channel can also be a string such as "CDA", (channel order doesn't matter.)

=cut

sub convert {
  my ($this,$channel) = @_;
  my $c = $this->{'connection'};
  my $crc = 0;
  my $send;
  my $result;
  return undef if !$c->connected();
  # access the device
  if ( $this->select ) {
    $send = "\x3C";     # convert
    if ($channel =~ m/all/i) {
      $send .= "\x0F";  # All channels
    }
    else {
      my $ch = "\x00";
      if ($channel =~ m/a/i) {
        $ch = "\x01";        # Channel A
      }
      if ($channel =~ m/b/i) {
        $ch |= "\x02";  # Channel B
      }
      if ($channel =~ m/c/i) {
        $ch |= "\x04";  # Channel C
      }
      if ($channel =~ m/d/i) {
        $ch |= "\x08";  # Channel D
      }
      #print "Channel mask = " . unpack ("C*", $ch) . ".\n";
      $send .= $ch;
    }
    #$send .= "\x01";  # Set all to zeros
    $send .= "\x00";  # leave at default
    $crc = $c->docrc16( 0, $send);

    $result = $c->owBlock( $send . ("\xFF" x 2));

    $crc = $c->docrc16( $crc, substr($result,-2,2) );
    #print "CRC16 = $crc .\n";

    if (!$this->{VCC}) {
      # set the 1-Wire Net to strong pull-up
      return undef if $c->level(&Hardware::iButton::Connection::MODE_STRONG5) ne
         &Hardware::iButton::Connection::MODE_STRONG5;
    }

    # Conversion time = (#channels * #bits * 80us) + 160us
    # ie. all channels, 16 bits = 5.280ms
    # sleep for 6ms (max conversion time) during conversion
    select( undef, undef, undef, 0.006 );

    if (!$this->{VCC}) {
      # turn off the 1-Wire Net strong pull-up
      return undef if $c->level(&Hardware::iButton::Connection::MODE_NORMAL) ne
         &Hardware::iButton::Connection::MODE_NORMAL;
    }

    # Verify that the conversion completed
    $result = $c->owBlock("\xFF" x 2);
    $this->reset;
    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      return undef;  
    }
    my @res = unpack ("C*", $result);
    if ($res[1] != "255") {
      print "Conversion error!\n";
      return undef;
    }
    return 1;
  }
  return undef;
}


=head2 readAD

 $b->readAD($channel)

This method reads the last converted AD values from memory for the selected 
channel/s in DS2450 iButtons.

 $channel = A/B/C/D/ALL

=cut

sub readAD {
  my ($this,$channel) = @_;
  my $c = $this->{'connection'};
  my $crc = 0;
  my $send;
  my $result;
  return undef if !$c->connected();
  # access the device
  if ( $this->select ) {
    $send = "\xAA";        # Read memory
    $send .= "\x00\x00";   # Address 0000
    $send .= "\xFF" x 10;  # 8 bytes per page +CRC16

    # Read memory page 0
    # Bytes 0-2 = \xAA\x00\x00
    # Byte 3 = LSB A
    # Byte 4 = MSB A
    # Byte 5 = LSB B
    # Byte 6 = MSB B
    # Byte 7 = LSB C
    # Byte 8 = MSB C
    # Byte 9 = LSB D
    # Byte 10 = MSB D
    # Bytes 11-12 = CRC16

    $result = $c->owBlock( $send );
    $crc = $c->docrc16( 0, substr($result,0,11) );
    $crc = $c->docrc16( $crc, substr($result,-2,2) );

    my @res = unpack ("C*", $result);
    my $Va = $this->{A_range} * (($res[4] << 8) + $res[3])/65536; 
    my $Vb = $this->{B_range} * (($res[6] << 8) + $res[5])/65536; 
    my $Vc = $this->{C_range} * (($res[8] << 8) + $res[7])/65536; 
    my $Vd = $this->{D_range} * (($res[10] << 8) + $res[9])/65536; 

    $this->reset;

    if ($crc != 0xB001) {
      print "Failed CRC16 check!\n";
      return undef;
    }
    if ($channel =~ m/all/i) {
      return($Va,$Vb,$Vc,$Vd);
    }
    elsif ($channel =~ m/a/i) {
      return($Va);
    }
    elsif ($channel =~ m/b/i) {
      return($Vb);
    }
    elsif ($channel =~ m/c/i) {
      return($Vc);
    }
    elsif ($channel =~ m/d/i) {
      return($Vd);
    }
  }
}


=head2 set_switch

 $b->set_switch($channel,$state);
    
This method can be used to set switch outputs on DS2450 iButtons.
 $channel = ABCD (Which channel?) 
 $state = 1/on or 0/off (Turn the switch on or off)

=cut
       
sub set_switch {
  my ($this,$channel,$state) = @_;
          
  my $c = $this->{'connection'};
  my $send;
  my $result;
  my $crc = 0;
  return undef if !$c->connected();
  # access the device
  if ( $this->select ) {
    $send = "\x55";   # write memory
    if ($channel =~ m/a/i) {
      $send .= "\x08\x00";  # to 0008
    }
    elsif ($channel =~ m/b/i) {
      $send .= "\x0A\x00";  # to 000A
    }
    elsif ($channel =~ m/c/i) {
      $send .= "\x0C\x00";  # to 000C
    }
    elsif ($channel =~ m/d/i) {
      $send .= "\x0E\x00";  # to 000E
    }
    # Set OE=1, and OC=1 or 0
    $send .= ($state =~ m/on|1/i) ? "\x80" : "\xC0";

    # now send the block
    $result = $c->owBlock( $send . ("\xFF" x 3));

    $crc = $c->docrc16( 0, $send );
    $crc = $c->docrc16( $crc, substr($result,-3,2) );

    $this->reset;

    if ($crc == 0xB001) {
      return 1;
    }
  }
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


# this is the DS2490 Microlan Coupler (Used in many 1-wire hubs)
package Hardware::iButton::Device::DS2409;
use Hardware::iButton::Connection;
use strict;
use vars qw(@ISA);

@ISA = qw(Hardware::iButton::Device);

#----------------------------------------------------------------------
 
sub set_coupler {
    my ($this, $Hubmode) = @_;
    #my $this = shift;
    my $serial = pack( "b*", $this->raw_id() );
    my $c = $this->{'connection'};
    my $CmdByte;
    return undef if !$c->connected();

    if ($c->{'2409Internal'} eq $this) {
        if ($c->{'2409IntBranch'} eq $Hubmode) { return undef; }
    }
    $c->{'2409Internal'} = $this;
    $c->{'2409IntBranch'} = $Hubmode;

    my $channel = $this->{channel};
    $channel = 'A' unless $channel;
    #print "Setting Coupler $this  $Hubmode\n";
    
    if ($Hubmode eq 'OFF') { $CmdByte="\x66"; }
    if ($Hubmode eq 'MAIN') { $CmdByte="\xA5"; }
    if ($Hubmode eq 'AUX') { $CmdByte="\x33"; }


    if($this->reset()) {    
    my $send = "\x55";
       $send .= $serial;
       $send .= $CmdByte;
	
        my $result = $c->owBlock( $send );
#print "Sent:  ".unpack("h*",$send)."\n";
#print "Result:".unpack("h*",$result)."\n";
        if ( $result ) {
            
        }
    }

    my $send .= "\x55";
       $send .= $serial;
       $send .= "\x5A";
        
    my $result = $c->owBlock( $send );
    return undef;
}

#----------------------------------------------------------------------

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

