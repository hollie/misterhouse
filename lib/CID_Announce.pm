use strict;

# $Revision$
# $Date$

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	CID_Announce.pm

Description:
	Announces a call.  CID with category of 'reject' will not be announced.

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	Example initialization:

		use CID_Announce;
		$cid = new CID_Announce($telephony_driver,'Call from $name $snumber.');

	Constructor Parameters:
		ex. $x = new CID_Announce($y,$z);
		$x		- Reference to the class
		$y		- Telephony driver reference
		$z		- Format for speaking
				Following variables are substitued in ""
				$name,$first,$middle,$last,$number,$fnumber
 				(formated),$snumber(speakable),$type,$category,$city,
				$state,$time,$areacode,$prefix,$suffix,$soundfile

	Input states:
		"cid"	        - Caller ID event
		"ring"     	- Ring event 'to pass along to other consumers of this object'

	Output states:
		"cid"	        - Caller ID event
		"ring"     	- Ring event 'to pass along to other consumers of this object'

	For example see g_phone.pl

Bugs:
	There isnt a whole lot of error handling currently present in this version.  Drop me
	an email if you are seeing something odd.

Special Thanks to:
	Bruce Winter - MH


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut
package CID_Announce;

@CID_Announce::ISA = ('Telephony_Item');

my $m_Speak_Format;
my $m_mod_ring;
#my %m_Speak_Parms;

sub new
{
	my ($class,$p_Telephony,$p_speak_format,$p_mod_ring) = @_;
	my $self={};

	bless $self,$class;


	$p_Telephony->tie_items($self,'cid') if defined $p_Telephony;
	if (defined $p_mod_ring) {
		$p_Telephony->tie_items($self,'ring') if defined $p_Telephony;
	}
	$self->speak_format($p_speak_format);
	$self->mod_ring($p_mod_ring);

	return $self;
}

sub add
{
	my ($self, $p_telephony) = @_;
#	print "CID ADD $p_telephony";
	$p_telephony->tie_items($self,'cid') if defined $p_telephony;
}



sub set
{
	my ($self,$p_state,$p_setby) = @_;
#	&::print_log("CIDAnn $p_state, $p_setby");
	if ($p_state =~ /^CID/i or
		(
			$p_state eq 'ring' and
			$p_setby->ring_count() % $$self{m_mod_ring} == 0 ) )
	{
		$self->cid_name($p_setby->cid_name());
		$self->cid_number($p_setby->cid_number());
		$self->cid_type($p_setby->cid_type());
		$self->address($p_setby->address());
		#if category reject, then dont announce

		if ($p_setby->isa('CID_Lookup')) {
			if (lc $p_setby->category() ne 'reject') {
				$self->announce($p_setby,$self->speak_format(),$::config_parms{local_area_code});
			}
		}
		else
		{
			$self->announce($p_setby,$self->speak_format(),$::config_parms{local_area_code});
		}
	}
	$self->SUPER::set($p_state);
}

sub speak_format
{
	my ($self,$p_speak_format) = @_;
	$$self{m_Speak_Format} = $p_speak_format if defined $p_speak_format;
	return $$self{m_Speak_Format};
}

sub mod_ring
{
	my ($self,$p_mod_ring) = @_;
	$$self{m_mod_ring}=$p_mod_ring if defined $p_mod_ring;
	return $$self{m_mod_ring};
}

sub announce
{
	my ($self,$p_telephony,$p_speak_format,$p_local_area_code) = @_;

	my $response=$self->parse_format($p_telephony,$p_speak_format,$p_local_area_code);
#	print "CID Announce $response,$p_telephony,$p_speak_format";
    return if $response =~ /MESSAGE WAITING/; # Don't announce message waiting data
    return if $response =~ /\-MSG OFF\-/;
	if ($response=~ /\.wav$/) {
		$self->play_cid($response);
	} else {
		$self->speak_cid($response);
	}
	return $response;

}

sub speak_cid
{
	my ($self,$p_cid) = @_;
#	print "CID SPEAK";
#	&::respond	('app=phone target=callerid $response');
        if ($::config_parms{'callerid_raw_numbers'}) {
		&::speak("app=phone target=callerid raw_numbers=1 $p_cid");
	} else {        
		&::speak("app=phone target=callerid $p_cid");
	}
}

sub play_cid
{
	my ($self,$p_cid) = @_;
#	print "CID PLAY";
	&::play($p_cid);
}

sub parse_format
{
	my ($self,$p_telephony,$p_speak_format,$p_local_area_code) = @_;

	my ($number, $name, $address,$city, $state, $fnumber, $type, $time,$sound_file);
	my ($first, $middle, $last,$areacode,$suffix,$prefix,$soundfile,$snumber,$category);
	my %table_types=qw(p private u unknown i internation n normal);
  	my ($format1);

	my $speak_string;

	$name = $p_telephony->cid_name();
	$number = $p_telephony->cid_number();
	$type = $table_types{lc $p_telephony->cid_type()};

	$time = $::Time_Now;

	# remove local area code
	my @areacodes = split(",",$p_local_area_code);
	my $areac = $areacodes[0];
	$number =~ s/^$areac//;

    print "CID_nnounce data: type=$type name=$name number=$number\n" if $main::Debug{phone};

	if ($p_telephony->isa('CID_Lookup')) {
#		print "CID ISA";
		$areacode = $p_telephony->areacode();
		$fnumber = $p_telephony->formated_number();
		$snumber = $p_telephony->speakable_number();
		$fnumber =~ s/^$areac//g;
		$areac =~ s/([0-9])/$1 /g;
		$snumber =~ s/^$areac//g;

		# Make other vars available
		$address = $p_telephony->address();
		$city = $p_telephony->city();
		$state = $p_telephony->cid_state();
		$soundfile = $p_telephony->file();
		$first = $p_telephony->first();

		# If first not available then default to name
		$first = $p_telephony->cid_name() if not defined $first;
		$last = $p_telephony->last();
		$middle = $p_telephony->middle();
		$prefix = $p_telephony->prefix();
		$suffix = $p_telephony->suffix();
		$category = $p_telephony->category();
#   		$format1  = "$first $middle $last";
    		$format1  = $name;
    		$format1  = $snumber if $name =~ 'UNKNOWN CALLER';
    		$format1  = "Unknown" if $type eq 'unknown' and !$snumber;
    		$format1  = $snumber unless $format1 =~ /\S/;
    		if ($areacodes[0] ne $areacode) {
        		$format1 .= " in $city" if $city =~ /\S/ and
          			(lc $city ne lc $::config_parms{city} or lc $state ne lc $::config_parms{state});
			$format1 =~ s/\s*$//;
        		$format1 .= ", $state"  if $state and lc $state ne lc $::config_parms{state} and lc $state ne lc $city;
	    	}
	}


	if (! $soundfile)
	{
		$speak_string = '$speak_string="' . $p_speak_format . '"';
		eval ($speak_string);
	}
	else
	{
		$speak_string = $soundfile;
	}
#	print "CID PARSE $speak_string";
	return $speak_string;

}


1;
