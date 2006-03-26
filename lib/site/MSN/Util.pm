#================================================
package MSN::Util;
#================================================

use strict;
use warnings;


sub convertError
{
	my $err = shift;
	my %errlist;

	$errlist{200} = 'Invalid Syntax';
	$errlist{201} = 'Invalid parameter';
	$errlist{205} = 'Invalid user';
	$errlist{206} = 'Domain name missing';
	$errlist{207} = 'Already logged in';
	$errlist{208} = 'Invalid User Name';
	$errlist{209} = 'Invlaid Friendly Name';
	$errlist{210} = 'List Full';
	$errlist{215} = 'User already on list';
	$errlist{216} = 'User not on list';
	$errlist{217} = 'User not online';						 #<--
	$errlist{218} = 'Already in that mode';
	$errlist{219} = 'User is in the opposite list';
	$errlist{223} = 'Too Many Groups';						 #<--
	$errlist{224} = 'Invalid Groups ';						 #<--
	$errlist{225} = 'User Not In Group';					 #<--
	$errlist{229} = 'Group Name too long';					 #<--
	$errlist{230} = 'Cannont Remove Group Zero';			 #<--
	$errlist{231} = 'Invalid Group';							 #<--
	$errlist{280} = 'Switchboard Failed';					 #<--
	$errlist{281} = 'Transfer to Switchboard failed';	 #<--

	$errlist{300} = 'Required Field Missing';
	$errlist{301} = 'Too Many Hits to FND';				 #<--
	$errlist{302} = 'Not Logged In';

	$errlist{500} = 'Internal Server Error';
	$errlist{501} = 'Database Server Error';
	$errlist{502} = 'Command Disabled';
	$errlist{510} = 'File Operation Failed';
	$errlist{520} = 'Memory Allocation Failed';
	$errlist{540} = 'Challenge Responce Failed';

	$errlist{600} = 'Server Is Busy';
	$errlist{601} = 'Server Is Unavailable';
	$errlist{602} = 'Peer Name Server is Down';
	$errlist{603} = 'Database Connection Failed';
	$errlist{604} = 'Server Going Down';
	$errlist{605} = 'Server Unavailable';

	$errlist{707} = 'Could Not Create Connection';
	$errlist{710} = 'Bad CVR Parameter Sent';
	$errlist{711} = 'Write is Blocking';
	$errlist{712} = 'Session is Overloaded';
	$errlist{713} = 'Too Many Active Users';
	$errlist{714} = 'Too Many Sessions';
	$errlist{715} = 'Command Not Expected';
	$errlist{717} = 'Bad Friend File';
	$errlist{731} = 'Badly Formated CVR';

	$errlist{800} = 'Friendly Name Change too Rapidly';

	$errlist{910} = 'Server Too Busy';
	$errlist{911} = 'Authentication Failed';
	$errlist{912} = 'Server Too Busy';
	$errlist{913} = 'Not allowed While Offline';
	$errlist{914} = 'Server Not Available';
	$errlist{915} = 'Server Not Available';
	$errlist{916} = 'Server Not Available';
	$errlist{917} = 'Authentication Failed';
	$errlist{918} = 'Server Too Busy';
	$errlist{919} = 'Server Too Busy';
	$errlist{920} = 'Not Accepting New Users';
	$errlist{921} = 'Server Too Busy: User Digest';
	$errlist{922} = 'Server Too Busy';
	$errlist{923} = 'Kids Passport Without Parental Consent';	#<--K
	$errlist{924} = 'Passport Account Not Verified';

	return ( $errlist{$err} || 'unknown error' );
}

sub convertFromCid
{
	my $cid = shift;

	my $info = {};

	if( $cid >= 1073741824 )		{ $info->{Client} = 'MSNC5'; }
	elsif( $cid >= 805306368 )		{ $info->{Client} = 'MSNC3'; }
	elsif( $cid >= 536870912 )		{ $info->{Client} = 'MSNC2'; }
	elsif( $cid >= 268435456 )		{ $info->{Client} = 'MSNC1'; }
	else									{ $info->{Client} = 'unknown'; }

	$info->{WinMobile} = ($cid & 1) ? 1 : 0;
	$info->{Unknown} = ($cid & 2) ? 1 : 0;
	$info->{ViewInk} = ($cid & 4) ? 1 : (($cid & 8) ? 1 : 0);
	$info->{CreateInk} = ($cid & 8) ? 1 : 0;
	$info->{Video} = ($cid & 16) ? 1 : 0;
	$info->{MultiPacket} = ($cid & 32) ? 1 : 0;
	$info->{MSNMobile} = ($cid & 64) ? 1 : 0;
	$info->{MSNDirect} = ($cid & 128) ? 1 : 0;

	return $info;
}

sub convertToCid
{
	my %info = @_;

	my $cid = 0;

	if( !defined $info{Client} )			{ $cid = 536870912; }
	elsif( $info{Client} eq 'MSNC5' )	{ $cid = 1073741824; }
	elsif( $info{Client} eq 'MSNC3' )	{ $cid = 805306368; }
	elsif( $info{Client} eq 'MSNC2' )	{ $cid = 536870912; }
	elsif( $info{Client} eq 'MSNC1' )	{ $cid = 268435456; }
	else											{ $cid = 268435456; }

	$cid += 1 if( $info{WinMobile} );
	$cid += 2 if( $info{Unknown} );
	$cid += 4 if( $info{ViewInk} );
	$cid += 8 if( $info{CreateInk} );
	$cid += 16 if( $info{Video} );
	$cid += 32 if( $info{MultiPacket} );
	$cid += 64 if( $info{MSNMobile} );
	$cid += 128 if( $info{MSNDirect} );

	return $cid;
}


1;
