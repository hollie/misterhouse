
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Telephony_Item.pm

Description:
	Inheritable class driver interface for any telephony related device drivers.
	Not intended to be used directly, but more as a base class for all things 
	to do with the telephone.   This object is inherited from the Generic_Item
	class so all of these methods are also available at your disposal.
	

Author:
	Jason Sharpee
	jason@sharpee.com

Contributors:
	Bill Sobel
	Craig Schaeffer

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	Example initialization:

	
	Constructor Parameters:

	Input states:

	Output states:
		"ring"		- Ring
		"cid"		- Caller ID received
		"busy"		- Busy signal
		"voice"		- Voice detected
		"notone"	- No dialtone detected
		"dtmf"		- DTMF received
		"onhook"	- Device went on hook
		"offhook"	- Device went off hook

	For DTMF input and output examples, see code/public/ivr.pl

Bugs:
	There isnt a whole lot of error handling currently present in this version.  Drop me
	an email if you are seeing something odd.

Special Thanks to: 
	Bruce Winter - MH
		

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Telephony_Item;

@Telephony_Item::ISA = ('Generic_Item');

my $m_Address;
my $m_CIDName;
my $m_CIDNumber;
my $m_CIDType;
my $m_RingCount;
my $m_DTMFDigit;
my $m_DTMFBuffer;
my $m_Hook;

sub new {
    my ( $class, $p_address ) = @_;
    my $self = {};
    bless $self, $class;

    #	&::print_log("New TI");
    $m_Address = $p_address;
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    #	&::print_log("Telephony state:$p_state:$p_setby");
    $p_state = lc $p_state;
    if ( $p_state =~ /^offhook/ ) {
        $$self{m_Hook} = 'off';
    }
    elsif ( $p_state =~ /^onhook/ ) {
        $$self{m_Hook} = 'on';
    }
    elsif ( $p_state =~ /^hook/ ) {
        if ( $self->hook() eq 'off' ) {
            $$self{m_DTMFBuffer} = '';
        }
        elsif ( $self->hook() eq 'on' and $$self{m_DTMFBuffer} ne '' ) {
            $self->set( "dialed::" . $$self{m_DTMFBuffer} );

            #print "DTMF sequence: " . $$self{m_DTMFBuffer} . "\n";
        }
    }
    elsif ( $p_state =~ /^dtmf/ ) {
        my $tempdtmf = $self->dtmf();
        $$self{m_DTMFBuffer} .= $tempdtmf
          if defined $tempdtmf and $self->hook() eq 'off';
    }

    $self->SUPER::set( $p_state, $p_setby );
}

#CID name
sub cid_name {
    my ( $self, $p_CIDName ) = @_;
    $$self{m_CIDName} = $p_CIDName if defined $p_CIDName;
    return $$self{m_CIDName};
}

#CID number
sub cid_number {
    my ( $self, $p_CIDNumber ) = @_;
    $$self{m_CIDNumber} = $p_CIDNumber if defined $p_CIDNumber;
    return $$self{m_CIDNumber};
}

#CID valid types should be N-Normal, P-Private / Restricted, U-Unknown / Unavailable, I- international
sub cid_type {
    my ( $self, $p_CIDType ) = @_;
    $$self{m_CIDType} = $p_CIDType if defined $p_CIDType;
    return $$self{m_CIDType};
}

#Hardware Address
sub address {
    my ( $self, $p_Address ) = @_;
    $$self{m_Address} = $p_Address if defined $p_Address;
    return $$self{m_Address};
}

#Ring number if available
sub ring_count {
    my ( $self, $p_RingCount ) = @_;
    $$self{m_RingCount} = $p_RingCount if defined $p_RingCount;
    return $$self{m_RingCount};
}

#Duration ( HH:MM:SS format )
sub call_duration {
    my ( $self, $p_duration ) = @_;
    $$self{m_CallDuration} = $p_duration if defined $p_duration;
    return $$self{m_CallDuration};
}

#Extension ( string - could be in numeric format )
sub extension {
    my ( $self, $p_extension ) = @_;
    $$self{m_Extension} = $p_extension if defined $p_extension;
    return $$self{m_Extension};
}

#Call Type (POTS, VOIP )
sub call_type {
    my ( $self, $p_callType ) = @_;
    $$self{m_CallType} = $p_callType if defined $p_callType;
    return $$self{m_CallType};
}

#Send or received tone
sub dtmf {
    my ( $self, $p_DTMFDigit ) = @_;

    #print "setting dtmf=" . $p_DTMFDigit . "\n"  if defined $p_DTMFDigit;
    $$self{m_DTMFDigit} = $p_DTMFDigit if defined $p_DTMFDigit;

    return $$self{m_DTMFDigit};
}

#get the current hookstate of the device
sub hook {
    my ( $self, $p_Hook ) = @_;
    $$self{m_Hook} = $p_Hook if defined $p_Hook;
    return $$self{m_Hook};
}

#send dtmf sequence
sub dtmf_sequence {
    my ( $self, $p_DTMFSequence ) = @_;

    # for $p_DTMFSequence
    # call $self->dtmf($digit)
    # next
}

# dtmf buffer
sub dtmf_buffer {
    my ( $self, $p_DTMFBuffer ) = @_;
    $$self{m_DTMFBuffer} = $p_DTMFBuffer if defined $p_DTMFBuffer;
    return $$self{m_DTMFBuffer};
}

# Connect the PC sound card to the telephone
sub patch {
    my ( $self, $p_patch ) = @_;
}

sub play    #Play sound file to device
{
    my ( $self, $p_FileName ) = @_;
}

sub record    #Record sound file from device
{
    my ( $self, $p_FileName, $p_MaxTime ) = @_;
}

sub speak     #TTS to device
{
    my ( $self, $p_FileName, $p_MaxTime ) = @_;
}
1;
