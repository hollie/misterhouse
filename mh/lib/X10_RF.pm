
=begin comment

This routine contains common code used by the X10_MR26.pm and X10_W800.pm
(which is actually for the W80RF32 as opposed to the W800).  modules to
decode RF data and set the appropriate states.

It can read powerline control data via RF, TV/VCR control data via RF,
and security data via RF (nothing is done with the security data at
the moment).  Note that W800RF32 can read the security data but the
MR26A cannot.

To monitor keys from an X10 TV/VCR RF remote (UR47A, UR51A, J20A, etc.),
(e.g. Play,Pause, etc), you can use something like this:

 $Remote  = new X10_MR26;
 $Remote -> tie_event('print_log "MR26 key: $state"');
 set $TV $state if $state = state_now $Remote;

For a more general way to handle TV/VCR RF remotes and X10 security
devices, see RF_Item.pm.

If you want to relay all the of the incoming powerline style RF data
back out to the powerline, use mh/code/common/x10_rf_relay.pl.

=cut

use strict;

package X10_RF;

#------------------------------------------------------------------------------

# Bit masks for individual bits.
use constant BIT0 => 0x01;
use constant BIT1 => 0x02;
use constant BIT2 => 0x04;
use constant BIT3 => 0x08;
use constant BIT4 => 0x10;
use constant BIT5 => 0x20;
use constant BIT6 => 0x40;
use constant BIT7 => 0x80;

# Map of house codes sent in RF data to normal house codes.
my @hcodes = ('M','E','C','K','O','G','A','I','N','F','D','L','P','H','B','J');

# UR51A Function codes:  
#  - OK and Ent are same, PC and Subtitle are same,
#  - Chan buttons and Skip buttons are same
my %vcodes = qw(0f Power 2b PC 6b Title 5c Display 4a Enter 1b Return
	        ab Up cb Down 4b Left 8b Right 6d Menu 93 Exit 1c Rew
	        0d Play 1d FF ff Record 0e Stop 4e Pause 4f Recall
	        41 1 42 2 43 3 44 4 45 5 46 6 47 7 48 8 49 9
	        5d AB 40 0 02 Ch+ 03 Ch- 07 Vol- 06 Vol+ 05 Mute);

# Security codes.
# Descriptions have a class to for grouping the function and a description
# of the function.
my %scodes = qw(00 Sensor:AlertMax   01 Sensor:NormalMax 20 Sensor:AlertMin
		21 Sensor:NormalMin  30 Sensor:Alert     31 Sensor:Normal
		40 System:ArmAwayMax 41 System:Disarm    42 Control:LightsOn
		43 Control:LightsOff 44 System:Panic     50 System:ArmHomeMax
		60 System:ArmAwayMin 61 System:Disarm    62 Control:LightsOn
	        63 Control:LightsOff 64 System:Panic     70 System:ArmHomeMin);

#------------------------------------------------------------------------------

# decode_rf_bytes
#
# Decode the four bytes of RF data and set the appropriate states.
#
# The first parameter should be the name of the calling module (mr26 or w800).
# The second parameter is an array of the four RF data bytes (see
# http://www.wgldesigns.com/dataformat.txt).  These bytes should be in
# the form of the original stream sent by a W800RF32 unit.  This routine will
# handle changing the order of the bytes and bits as specified by the
# above document.
#
# The routine returns the state it set to indicate that it successfully
# handled the data.  If the checksum on the bytes was bad, it will return
# "BADCHECKSUM".  If it just didn't know what to do with the data it
# parsed (i.e. a new command, it will return undef).

sub decode_rf_bytes {
    my($module, @bytes) = @_;

    my $uc_module = uc $module;
    my $lc_module = lc $module;

    # Take the input data and convert it as specified X-10 wireless units
    # protocol document (note that the bits in the bytes are reversed and
    # that the bytes themselves are swapped - byte 1 is the 3rd physical
    # byte and byte 3 is the 1st physical byte).  Store the converted bytes
    # as integers instead of characters.
    my @nbytes;
    for (my $i = 0; $i < 4; $i++) {
	my $j = ($i < 2) ? 2 + $i : $i - 2;
	$nbytes[$j] = ord(pack("B8", unpack("b*", $bytes[$i])));
    }

     # It appears that the bytes returned by the W800RF32AE for the Digimax 210
     # thermostat do not need as much conversion. Bytes 0&1 are the ID, 2 is the 
     # status and 3 is the current temperature.  Unfortunately the setpoint set on
     # the Digimax's interface is not available via the W800RF32AE. (Chris Barrett)
    my @rbytes; 
    for (my $i = 0; $i < 4; $i++) {
 	$rbytes[$i] = ord(pack("b8", unpack("b*", $bytes[$i])));
    }
 


    # Since the MR26 doesn't have the checksum bytes, we'll just manufacture
    # them here.  We can't just strip them out of the decode_rf_bytes routine
    # because decode_rf_bytes can also handle security data sent by a W800RF32,
    # which requires a unique forth byte.  Since the mr26 can't handle security
    # data, we don't need to worry about it.
    if ($lc_module eq 'mr26') {
	$nbytes[1] = $nbytes[0] ^ 0xff;
	$nbytes[3] = $nbytes[2] ^ 0xff;
    }

    # Come up with binary representations of the bytes for use in messages.
    my @bbytes;
    for (my $i = 0; $i < 4; $i++) {
	$bbytes[$i] = unpack("B*", chr($nbytes[$i]));
    }

    if ($main::Debug{$lc_module}) {
	printf "%s: reordered data: %02x %02x %02x %02x\n",
	       $uc_module, $nbytes[0], $nbytes[1], $nbytes[2], $nbytes[3];
    }

     # Do we have a Digimax 210?
    if (   (($rbytes[2] == 0x1e)  			# state = fan on
	    ||  ($rbytes[2] == 0x2d)  			# state = fan off
	    ||  ($rbytes[2] == 0x3c)) 			# state = initialising 
	   && (($rbytes[3] >= 0) && ($rbytes[3] <= 40))	# temp between 0 and 40 degrees Celcius
	   ) {
	my($device_id, $state, $temperature);
	
	# Unlike other X-10 security devices, the Digimax's ID is 2 bytes long
	$device_id = $rbytes[0] * 256 + $rbytes[1];     
	
	if ($rbytes[2] == 0x1e) {
	    $state = "fan on";
	} elsif ($rbytes[2] == 0x2d) {
	    $state = "fan off";
	} elsif ($rbytes[2] == 0x3c) {
	    $state = "initialising";
	} else { 
	    $state = "unknown";		# this is redundant because of the test above.
	}
	
	$temperature = $rbytes[3];
	
         # I'm not sure if this is the right way to do this.  It means that state and 
         # state_now will return "status:temperature", for example, if the fan is 
         # off and it's 26C then state* will return "fan off:26"
	$state .= ":".$temperature;
 
 	my $item_id  = lc sprintf "%04x", $device_id;
 
 	# Set the state of any items or classes associated with this device.
 	my $matched;
 	for my $name (&main::list_objects_by_type('RF_Item')) {
 	    my $object = &main::get_object_by_name($name);
 	    my $id     = $object->{rf_id};
 	    if ($id eq $item_id) {
 		$object->set($state);
 		$matched = 1;
 	    }
 	}
 	unless ($matched) {
 	    printf "%s: digimax210: unmatched device %02x (state = $state)\n",
	    $uc_module, $device_id, $state;
 	}
	
	return $state; 
    }
 


    # Make sure the data looks valid.  Normal X10 data has two pairs with each
    # pair of bytes complementing each other.  Normal X10 data has zeros in the
    # three bits of the first byte and zeros in the top two bits of the third
    # byte.
    #
    # Non powerline devices (i.e. security devices and TV style remotes) have
    # some ones in the top two bits of the third byte.  The first pair of bytes
    # is the command and it's complement.  For TV style remotes, byte 3 is 0x77
    # and byte 4 is 0x88.  For security devices, the second pair of bytes is
    # the 8 bit device code and a check sum byte where the high nibble is a
    # complement and the low nibble is a copy.

    # The first two bytes are always complements.
    if (($nbytes[0] ^ $nbytes[1]) != 0xff) {
	printf "%s: bad initial checksum: %s %s %s %s\n",
	       $uc_module, $bbytes[0], $bbytes[1], $bbytes[2], $bbytes[3];

	return "BADCHECKSUM";
    }

    # Determine if the command looks like a powerline command.
    my $is_powerline_cmd = (    ($nbytes[0] & (BIT5 | BIT6 | BIT7)) == 0
			    and ($nbytes[2] & (       BIT6 | BIT7)) == 0
	                    and ($nbytes[2] ^ $nbytes[3]) == 0xff       );

    my($cmd, $device_id, $state);

    $state = undef;

    if ($is_powerline_cmd) {				# Power line data
	# Layout of bytes/bits for powerline commands:
	#
	# 1st byte:
	#
	# NORMAL                             INTENSITY BIT SET
	# ---------------------------------- -----------------------------------
	# 7 always 0
	# 6 always 0
	# 5 always 0
	# 4 unit code bit 1                   0=bright/dim, 1=alloff/on
	# 3 unit code bit 0                   0=bright or alloff, 1=dim or allon
	# 2 off (0=off command, 1=on command) 0
	# 1 unit code bit 2 for all but RW724 0
	# 0 intensity (0=on/off cmd, 1=bri/dim/allon/alloff cmd)
	#
	# 2nd byte:
	#
	# complement of 1st byte
	#
	# 3rd byte:
	#
	# 7 always 0
	# 6 always 0
	# 5 unit  code bit 3
	# 4 unit  code bit 2 for RW724   
	# 3 house code bit 3
	# 2 house code bit 2
	# 1 house code bit 1
	# 0 house code bit 0
	#
	# 4th byte:
	#
	# complement of 3rd byte

	# Check to see if this sequence is something that we can handle.  The
	# X-10 wireless units protocol document specifies that bits 5-7 of the
	# 1st byte are supposed to always be zero.  Also, it seems that nothing
	# uses bits 6-7 of the 3rd byte (tested above to indicate we're in
	# powerline mode).  Bit 1 of 1st byte is bit 2 of the unit code for the
	# HR12A, but bit 4 of 3rd byte is used for bit 2 of the unit code on
	# the RW724.  So, we'll make sure that they are not both on.
	if (   ($nbytes[0] & (BIT5 | BIT6 | BIT7))
	    or (($nbytes[0] & BIT1) and ($nbytes[2] & BIT4))) {

	    printf "%s: invalid powerline data: %s %s %s %s\n",
		   $uc_module, $bbytes[0], $bbytes[1], $bbytes[2], $bbytes[3];
	    return undef;
	}

	my($off_bit, $intensity_bit, $not_all_bit, $dim_bit, $hn, $un);

	# Get the house code number.
	$hn = $nbytes[2] & 0x0F;

	# Determine if this is an ON/OFF command or a BRIGHT/DIM command
	# and what unit it applies to.
	$intensity_bit = ($nbytes[0] & BIT0) != 0;
	if ($intensity_bit) {					# Bright/Dim
	    $un = 0;

	    $off_bit     = 'N/A';
	    $dim_bit     = ($nbytes[0] & BIT3) != 0; # Dim
	    $not_all_bit = ($nbytes[0] & BIT4) != 0; # Not all on/off
	    if ($not_all_bit) {
		$cmd = $dim_bit ? 'dim'   : 'bright';
	    } else {
		$cmd = $dim_bit ? 'allon' : 'alloff';
	    }
	} else {						# On/Off
	    # Build up the unit number.  Note that different RF
	    # transmitters use different bits for bit 2.
	    $un = 0;

	    # From byte 1.
	    $un = $un | BIT0 if $nbytes[0] & BIT3;
	    $un = $un | BIT1 if $nbytes[0] & BIT4;
	    $un = $un | BIT2 if $nbytes[0] & BIT1; # HR12A (normal)

	    # From byte 3.
	    $un = $un | BIT2 if $nbytes[2] & BIT4; # RW724 (abnormal)
	    $un = $un | BIT3 if $nbytes[2] & BIT5;

	    $un++;				# Increment to make 1 based

	    $dim_bit     = 'N/A';
	    $not_all_bit = 'N/A';
	    $off_bit     = ($nbytes[0] & BIT2) != 0;
	    $cmd         = $off_bit ? 'off' : 'on';
	}

	if ($main::Debug{$lc_module}) {
	    printf "%s: reordered: byte 1: %s (0x%02x)\n",
		   $uc_module, $bbytes[0], $nbytes[0];
	    printf "%s: reordered: byte 3: %s (0x%02x)\n",
		   $uc_module, $bbytes[2], $nbytes[2];
	    printf "%s: intensity_bit = %s\n",
		   $uc_module, $intensity_bit ? $intensity_bit : 0;
	    printf "%s: not_all_bit   = %s\n",
		   $uc_module, $not_all_bit ? $not_all_bit : 0;
	    printf "%s: dim_bit       = %s\n",
		   $uc_module, $dim_bit ? $dim_bit : 0;
	    printf "%s: off_bit       = %s\n",
		   $uc_module, $off_bit ? $off_bit : 0;
	}

	# Build the state to send off for processing.
	my($h, $u);

	$h = $hcodes[$hn];
	$u = ($un <= 9) ? $un : chr(ord('A') + $un - 10);

	   if ($cmd eq 'on'    ) { $state = "X${h}${u}${h}J"; }
	elsif ($cmd eq 'off'   ) { $state = "X${h}${u}${h}K"; }
	elsif ($cmd eq 'bright') { $state = "X${h}L";         }
	elsif ($cmd eq 'dim'   ) { $state = "X${h}M";         }
	elsif ($cmd eq 'allon' ) { $state = "X${h}O";         }
	elsif ($cmd eq 'alloff') { $state = "X${h}P";         }
	else {
	    printf "%s: unimplemented X10 command: %s %s %s %s\n",
		   $uc_module, $bbytes[0], $bbytes[1], $bbytes[2], $bbytes[3];
	    return undef;
	}

	if ($main::Debug{$lc_module}) {
	    printf "%s: STATE %s%s %s (%s)\n",
		   $uc_module, $h, ($un == 0) ? '' : $un, $state, $cmd;
	}

	# Set states on X10_Items
	&main::process_serial_data($state, undef, 'rf');

    } elsif ($nbytes[2] == 0x77 and $nbytes[3] == 0x88) {	# TV remote data

	# Layout of bytes for TV remote commands:
	#
	# 1st byte: Command
	# 2nd byte: Complement of 1st byte
	# 3rd byte: 0x77
	# 4th byte: Complement of 3rd byte (0x88)

	# TV/VCR style remote control (UR51A, etc.)
	$cmd   = $nbytes[0];
	$state = $vcodes{unpack("H2", chr($cmd))};
	unless (defined $state) {
	    printf   "%s: unimplemented tv remote command: "
		   . "0x%02x (%s %s %s %s)\n", $uc_module, $cmd,
		   $bbytes[0], $bbytes[1], $bbytes[2], $bbytes[3];
	    return undef;
	}

	if ($main::Debug{$lc_module}) {
	    printf "%s: tv remote: state = %s (0x%02x)\n",
		   $uc_module, $state, $cmd;
	}

	# Set the state of the item.
	my $matched;
	for my $name (&main::list_objects_by_type('RF_Item')) {
	    my $object = &main::get_object_by_name($name);
	    my $id     = $object->{rf_id};
	    if ($id eq 'remote') {
		$object->set($state);
		$matched = 1;
	    }
	}
	unless ($matched) {
	    printf "%s: tv remote: no remote defined (state = $state)\n",
	           $uc_module, $device_id, $state;
	}

    } elsif ($lc_module ne 'mr26') {				# Security data

	# Layout of bytes for security commands:
	#
	# 1st byte: Command
	# 2nd byte: Complement of 1st byte
	# 3rd byte: Device ID
	# 4th byte: Top nibble is complement of top nibble of 3rd byte,
	#           bottom nibble is copy of bottom nibble of 3rd byte

	if (   ($nbytes[2] & 0xf0) != (($nbytes[3] & 0xf0) ^ 0xf0)
	    or ($nbytes[2] & 0x0f) !=  ($nbytes[3] & 0x0f)        ) {

	    printf "%s: bad checksum: %s %s %s %s\n",
		   $uc_module, $bbytes[0], $bbytes[1], $bbytes[2], $bbytes[3];

	    return "BADCHECKSUM";
	}

	# Determine the ID of the device and the command being requested.
	$cmd       = $nbytes[0];
	$device_id = $nbytes[2];

	my $scode = $scodes{unpack("H2", chr($cmd))};
	unless (defined $scode) {
	    printf   "%s: unimplemented security cmd "
		   . "device_id = 0x%02x, cmd = 0x%02x "
		   . "(%s %s %s %s)\n", $uc_module, $device_id, $cmd,
		   $bbytes[0], $bbytes[1], $bbytes[2], $bbytes[3];
	    return undef;
	}

	my($class, $function) = split(/:/, $scode);

	# Build the state to send off for processing.
	$state = $function;

	my $class_id = lc $class;
	my $item_id  = lc sprintf "%02x", $device_id;

	if ($main::Debug{$lc_module}) {
	    printf "%s: security: device_id = 0x%02x, cmd = 0x%02x\n",
		   $uc_module, $device_id, $cmd;
	    printf "%s: security: class_id = %s, item_id = %s, state = %s\n",
		   $uc_module, $class_id, $item_id, $state;
	}

	# Set the state of any items or classes associated with this device.
	my $matched;
	for my $name (&main::list_objects_by_type('RF_Item')) {
	    my $object = &main::get_object_by_name($name);
	    my $id     = $object->{rf_id};
	    if ($id eq $item_id or $id eq $class_id) {
		$object->set($state);
		$matched = 1;
	    }
	}
	unless ($matched) {
	    printf "%s: security: unmatched device %02x (state = $state)\n",
	           $uc_module, $device_id, $state;
	}

    } else {
	printf "%s: bad RF data: %s %s %s %s\n",
	       $uc_module, $bbytes[0], $bbytes[1], $bbytes[2], $bbytes[3];

	return "BADCHECKSUM";
    }

    # Set state of all MR26/W800 and X10_RF_Receiver objects
    for my $name (&main::list_objects_by_type('X10_' . $uc_module),
		  &main::list_objects_by_type('X10_RF_Receiver'  ) ) {

	my $object = &main::get_object_by_name($name);
	$object -> set($state);
    }

    return $state;
}

#------------------------------------------------------------------------------

# Data format info on here:  http://www.wgldesigns.com/dataformat.txt

#
# $Log$
# Revision 1.3  2004/02/01 19:24:35  winter
#  - 2.87 release
#
#

# vim: sw=4

1;
