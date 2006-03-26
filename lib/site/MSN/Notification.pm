#================================================
package MSN::Notification;
#================================================

use strict;
use warnings;

# IO
use IO::Socket;

# For authenticate
use URI::Escape;
use HTTP::Request;
use LWP::UserAgent;

# For challenge
use Digest::MD5 qw(md5 md5_hex md5_base64);
use LWP::Simple;

# For DP
use Digest::SHA1 qw(sha1 sha1_hex sha1_base64);

# For RNG
use MSN::SwitchBoard;

# For errors
use MSN::Util;

use constant CVER10 => '0x0409 winnt 5.0 i386 MSNMSGR 6.1.0203 MSMSGS ';
use constant VER => 'MSNP10 MSNP9 CVR0';
my $VER = 'MSNP10 MSNP9 CVR0';

sub checksum { my $o = tell(DATA); seek DATA,0,0; local $/; my $t = unpack("%32C*",<DATA>) % 65535;seek DATA,$o,0; return $t;};


sub new
{
	my $class = shift;
	my ($msn, $host, $port, $handle, $password) = (shift, shift, shift, shift, shift);

	my $self  =
	{
		Msn				=> $msn,
		Host				=> $host,
		Port				=> $port,
		Handle			=> $handle,
		Password			=> $password,
		Socket			=> {},
		Objects			=> {},
		DPLocation		=> {},
		Type				=> 'NS',
		Calls				=> {},
		Lists				=> { 'AL' => {}, 'FL' => {}, 'BL' => {}, 'RL' => {} },
		PingTime			=> time,
		PongTime			=> time,
		PingIncrement	=> 30,
		NoPongMax		=> 60,
		TrID				=> 0,
		Objects			=> {},
		DPLocation		=> '',
		@_
	};
	bless( $self, $class );

	return $self;
}

sub DESTROY
{
	my $self = shift;

	# placeholder for possible destructor code
}

sub AUTOLOAD
{
	my $self = shift;

	my $method = $MSN::Notification::AUTOLOAD;

	if( $method =~ /CMD_(.*)$/ )
	{
		$self->cmdError( "$1 not handled in MSN::Notification" );
	}
	else
	{
		$self->error( "method $method not defined" ) if( $self->{Msn}->{AutoloadError} );
	}
}

sub debug
{
	my $self = shift;

	return $self->{Msn}->debug( @_ );
}

sub error
{
	my $self = shift;

	return $self->{Msn}->error( @_ );
}

sub serverError
{
	my $self = shift;

	return $self->{Msn}->serverError( @_ );
}

sub cmdError
{
	my $self = shift;

	return $self->{Msn}->cmdError( @_ );
}

#================================================
# connect to the Notification Server
# add the socket to the Select object
# add self to the Connections hash
# start a conversation by sending VER
#================================================

sub connect
{
	my $self = shift;
	my $host = shift || $self->{Host};
	my $port = shift || $self->{Port};

	$self->{Socket} = new IO::Socket::INET( PeerAddr => $host, PeerPort => $port, Proto	  => 'tcp' );

	# if we can't open a socket, set an error and return 0
	return $self->serverError( "Connection error: $!" ) if( !defined $self->{Socket} );

	$self->{Msn}->{Select}->add( $self->{Socket} );
	$self->{Msn}->{Connections}->{ $self->{Socket}->fileno } = $self;

	# start the conversation
	$self->send( 'VER', $VER );

	return 1;
}

sub disconnect
{
	my $self = shift;

	$self->debug( "Disconnecting from Notification Server" );

	return $self->_send( "OUT\r\n" );
}

sub getType
{
	my $self = shift;

	return 'NS';
}

sub send
{
	my $self = shift;
	my $cmd  = shift || return $self->error( "No command specified to send" );
	my $data = shift;

	# Generate TrID using global TrID value...
	my $datagram = $cmd . ' ' . $self->{TrID}++ . ' ' . $data . "\r\n";
	return $self->_send( $datagram );
}

sub sendraw
{
	my $self = shift;
	my $cmd = shift || return $self->error( "No command specified to send" );
	my $data  = shift;
	# same as send without the "\r\n"

	my $datagram = $cmd . ' ' . $self->{TrID}++ . ' ' . $data;
	return $self->_send($datagram);
}

sub _send
{
	my $self = shift;
	my $msg = shift || return $self->error( "No message specified" );

	return $self->error( "Trying to print '$msg' on an undefined socket" ) if( !defined $self->{Socket} );

	# Send the data to the socket.
	$self->{Socket}->print( $msg );
	my $fn = $self->{Socket}->fileno;
	if( $msg eq "OUT\r\n" || $msg eq "BYE\r\n" )
	{
		$self->{Msn}->{Select}->remove( $self->{Socket}->fileno() );
		delete $self->{Msn}->{Connections}->{ $self->{Socket}->fileno() };
		undef $self->{Socket};
	}
	chomp($msg);

	print( "($fn $self->{Type}) TX: $msg\n" ) if( $self->{Msn}->{ShowTX} );

	return length($msg);
}

sub setName
{
	my $self = shift;
	my $name = shift || return $self->error( "Must be passed new name." );

	if( length $name > 129 )
	{
		return $self->error( "Display name to long to set" );
	}

	$self->send( 'PRP', 'MFN ' . uri_escape( $name ) );

	return 1;
}

sub setDisplayPicture
{
	my $self = shift;
	my $filename = shift;

	if( !$filename )
	{
		# Remove DP
		$self->{DPData} = '';
		$self->{MSNObject} = '';
		$self->setStatus( $self->{Msn}->{Status} );
		return 1;
	}

	if( $filename !~ /\.png$/ )
	{
		return $self->error( "File must be a PNG file" );
	}

	# append the time so we get a unique hash everytime
	# makes debuging easier because MSN can't cache it
	my $location = "msndp.dat". time;
	$self->{DPLocation} = $location;
	($self->{Objects}->{$location}->{Object},
	$self->{Objects}->{$location}->{Data}) = $self->create_msn_Object($filename,$location);
	# Set new status & return
	$self->setStatus( $self->{Msn}->{Status} );
	$self->debug( "Done With Dp!" );
	return 1;
}

sub setStatus
{
	my $self = shift;
	my $status = shift || 'NLN';

	# save our current status for use in setDisplayPicture
	$self->{Msn}->{Status} = $status;

	my $object = '';
	if (defined $self->{DPLocation} && exists $self->{Objects}->{$self->{DPLocation}} ) {
		$object = uri_escape($self->{Objects}->{$self->{DPLocation}}->{Object});
	}
	$self->send( 'CHG', $status . " " . $self->{Msn}->{ClientID} . " " . $object);
}

sub addEmoticon
{
	my $self = shift;
	my $shortcut = shift;
	my $filename = shift;
	
	if((-e $filename) && $filename =~ /png$/)
	{
		($self->{Objects}->{$shortcut}->{Object},
		$self->{Objects}->{$shortcut}->{Data}) = $self->create_msn_Object($filename,$shortcut);
		return 1;
	}
	else
	{
		return $self->error( "Could not find the file '$filename', or it is not a PNG file" );
	}	
}

sub create_msn_Object
{
	 my $self = shift;
	 my $file = shift;
	 my $location = shift;

	 my $data = '';

	 open( DP, $file ) || return $self->error( "Could not find the file '$file'" );
	 binmode(DP);
	 while( <DP> ) { $data .= $_; }
	 close(DP);

	 # SHA1D and the Display Picture Data
	 my $sha1d = sha1_base64( $data ) . '=';

	 # Compile the object from its keys + sha1d
	 my $object = 'Creator="'  . $self->{Handle} . '" ' .
					  'Size="'     . (-s $file)      . '" ' .
					  'Type="3" '  .
					  'Location="' . $location       . '" ' .
					  'Friendly="AAA=" ' .
					  'SHA1D="'    . $sha1d          . '"';

	 # SHA1C - this is a checksum of all the key value pairs
	 my $sha1c = $object =~ s/(\"=\s)*//g;
	 $sha1c = sha1_base64( $sha1c ) . '=';

	 # Put it all in its nice msnobj wrapper.
	 $object = '<msnobj ' . $object . ' SHA1C="' . $sha1c . '" />';

	 return ($object, $data);

}

#================================================
# Contact methods
#================================================

sub blockContact
{
	my $self = shift;
	my $email = shift || return $self->error( "Need an email address to block" );

	return 0 if( defined $self->{Lists}->{'BL'}->{$email} );

	$self->remContact($email);
	$self->disallowContact($email);
	$self->send( "ADC", "BL N=$email" );

	return 1;
}

sub unblockContact
{
	my $self = shift;
	my $email = shift || return $self->error( "Need an email address to unblock" );

	return 0 if( !defined $self->{Lists}->{'BL'}->{$email} );

	$self->send( "REM", "BL $email" );
	$self->allowContact($email);

	return 1;
}

sub addContact
{
	my $self = shift;
	my $email = shift || return $self->error( "Need an email address to add" );

	return 0 if( defined $self->{Lists}->{'FL'}->{$email} );

	$self->send( "ADC", "FL N=$email F=$email" );

	return 1;
}

sub remContact
{
	my $self = shift;
	my $email = shift || return $self->error( "Need an email address to remove" );

	return 0 if( !defined $self->{Lists}->{'FL'}->{$email} );

	my $user = $self->{Lists}->{'FL'}->{$email};
	$self->send( "REM", "FL " . ($user->{guid} || $email) . $user->{group} );

	return 1;
}

sub allowContact
{
	my $self = shift;
	my $email = shift || return $self->error( "Need an email address to add" );

	return 0 if( defined $self->{Lists}->{'AL'}->{$email} );

	$self->send( "ADC", "AL N=$email" );

	return 1;
}

sub disallowContact
{
	my $self = shift;
	my $email = shift || return $self->error( "Need an email address to remove" );

	return 0 if( !defined $self->{Lists}->{'AL'}->{$email} );

	$self->send( "REM", "AL $email" );

	return 1;
}

sub getContactList
{
	my $self = shift;
	my $list = shift || return $self->error( "You must specify a list to check" );

	if( !exists $self->{Lists}->{$list} )
	{
		return $self->error( "That list ($list) does not exists. Please try RL, BL, AL or FL" );
	}

	return keys %{$self->{Lists}->{$list}};
}

sub getContact
{
	my $self = shift;
	my $email = shift || return $self->error( "No email given" );

	if( !defined $self->{Lists}->{AL}->{$email} && !defined $self->{Lists}->{FL}->{$email} && !defined $self->{Lists}->{BL}->{$email} && !defined $self->{Lists}->{RL}->{$email} )
	{
		return $self->error( "Contact doesn't exist" );
	}

	my $contact = { Email			=> $email,
						 Friendly		=> $self->{Lists}->{FL}->{$email}->{Friendly} || '',
						 Status			=> $self->{Lists}->{FL}->{$email}->{Status} || '',
						 CID				=> $self->{Lists}->{FL}->{$email}->{ClientID} || 0,
						 ClientInfo		=> MSN::Util::convertFromCid( $self->{Lists}->{FL}->{$email}->{ClientID} || 0 ),
						 AL				=> defined( $self->{Lists}->{AL}->{$email} ) ? 1 : 0,
						 FL				=> defined( $self->{Lists}->{FL}->{$email} ) ? 1 : 0,
						 BL				=> defined( $self->{Lists}->{BL}->{$email} ) ? 1 : 0,
						 RL				=> defined( $self->{Lists}->{RL}->{$email} ) ? 1 : 0
					  };

	return $contact;
}

sub getContactName
{
	my $self = shift;
	my $email = shift || return $self->error( "No email given" );

	if( !defined $self->{Lists}->{FL}->{$email} || !defined $self->{Lists}->{FL}->{$email}->{Friendly} )
	{
		return $self->error( "Contact doesn't exist" );
	}

	return $self->{Lists}->{FL}->{$email}->{Friendly};
}

sub getContactStatus
{
	my $self = shift;
	my $email = shift || return $self->error( "No email given" );

	if( !defined $self->{Lists}->{FL}->{$email} || !defined $self->{Lists}->{FL}->{$email}->{Status} )
	{
		return $self->error( "Contact doesn't exist" );
	}

	return $self->{Lists}->{FL}->{$email}->{Status};
}

sub getContactClientInfo
{
	my $self = shift;
	my $email = shift || return $self->error( "No email given" );

	if( !defined $self->{Lists}->{FL}->{$email} || !defined $self->{Lists}->{FL}->{$email}->{ClientID} )
	{
		return $self->error( "Contact doesn't exist" );
	}

	my $cid = $self->{Lists}->{FL}->{$email}->{ClientID};

	my $info = MSN::Util::convertFromCid( $cid );

	return $info;
}

sub call
{
	my $self = shift;
	my $handle = shift || return $self->error( "Need to send the handle of the person you want to call" );
	my $message = shift;
	my %style = @_;

	# see if we already have a conversation going with the contact being called
	my $convo = $self->{Msn}->findMember( $handle );

	# if so, simply send them this message
	if( $convo )
	{
		$convo->sendMessage( $message, %style );
	}
	# otherwise, open a switchboard and save the message for later delivery
	else
	{
		# try to get a new switchboard
		$self->send( 'XFR', 'SB' );

		# store the handle and message of this call for use after we have a switchboard (why subtract 1 here??)
		my $TrID = $self->{TrID} - 1;
		$self->{Calls}->{$TrID}->{Handle} = $handle;
		$self->{Calls}->{$TrID}->{Message} = $message;
		$self->{Calls}->{$TrID}->{Style} = \%style;
	}
}

sub ping
{
	my $self = shift;

	if( time >= $self->{PingTime} + $self->{PingIncrement} )
	{
		$self->{Msn}->call_event( $self, "Ping" );

		# send PNG with no TrID
		$self->_send( "PNG\r\n" );

		$self->{PingTime} = time;

		# if no pong is received within the required time limit, assume we are disconnected
		if( time - $self->{PongTime} > $self->{NoPongMax} )
		{
			# disconnect
			$self->debug( "Disconnected : No pong received from server" );
			$self->{Msn}->disconnect();

			# call the Disconnected handler
			$self->{Msn}->call_event( $self, "Disconnected", "No pong received from server" );

			# reconnect if AutoReconnect is true
			$self->{Msn}->connect() if( $self->{Msn}->{AutoReconnect} );
		}
	}
}

#================================================
# internal method for updating a contact's info
#================================================

sub set_contact_status
{
	my $self = shift;
	my $email = shift || return $self->error( "No email given" );
	my $status = shift || return $self->error( "No status given" );
	my $friendly = shift || '';
	my $cid = shift || 0;

	$self->{Msn}->call_event( $self, "Status", $email, $status );
	$self->{Lists}->{FL}->{$email}->{Status} = $status;
	$self->{Lists}->{FL}->{$email}->{Friendly} = $friendly;
	$self->{Lists}->{FL}->{$email}->{ClientID} = $cid;
	$self->{Lists}->{FL}->{$email}->{LastChange} = time;
}

#================================================
# dispatch a server event to this object
#================================================

sub dispatch
{
	my $self = shift;
	my $incomingdata = shift || '';

	my ($cmd, @data) = split( / /, $incomingdata );

	if( !defined $cmd )
	{
		return $self->serverError( "Empty event received from server : '" . $incomingdata . "'" );
	}
	elsif( $cmd =~ /[0-9]+/ )
	{
		return $self->serverError( MSN::Util::convertError( $cmd ) . " : " . @data );
	}
	else
	{
		my $c = "CMD_" . $cmd;

		no strict 'refs';
		&{$c}($self, @data);
	}
}

#================================================
# MSN Server messages handled by Notification
#================================================

sub CMD_VER
{
	 my $self = shift;
	 my @data = @_;

	$self->{protocol} = $data[1];
	$self->send( 'CVR', CVER10 . $self->{Handle} );

	return 1;
}

sub CMD_CVR
{
	my $self = shift;
	my @data = @_;

	$self->send( 'USR', 'TWN I ' . $self->{Handle});

	return 1;
}

sub CMD_USR
{
	my $self = shift;
	my @data = @_;

	if ($data[1] eq 'TWN' && $data[2] eq 'S')
	{
		my $token = $self->authenticate( $data[3] );
		if (!defined $token ) {
			 $self->disconnect;
			 return;
		}
		$self->send('USR', 'TWN S ' . $token);
	}
	elsif( $data[1] eq 'OK' )
	{
		my $friendly = $data[3];
		$self->send( 'SYN', "0 0" );
	}
	else
	{
		return $self->serverError( 'Unsupported authentication method: "' . "@data" .'"' );
	}
}

#================================================
# Get the number of contacts on our contacts list
#================================================

sub CMD_SYN
{
	my $self = shift;
	my @data = @_;

	$self->{Lists}->{SYN}->{Total} = $data[3];
	$self->debug( "Syncing lists with $self->{Lists}->{SYN}->{Total} contacts" );
}

#================================================
# This value is only stored on the server and has no effect
# it's here to tell the client what to do with new contacts
# we don't need any particular value and can do whatever we want
# but we'll just set the value to automatic to be good
#================================================

sub CMD_GTC
{
	my $self = shift;
	my @data = @_;

	if( $data[0] eq 'A' )
	{
		# Tell the server that we don't need confirmation for people to add us to their contact lists
		$self->send( 'GTC', 'N' );
	}
}

#================================================
# As we are a bot, we want anyone to be able to invite and chat with us
# this could be an option in future clients
#================================================

sub CMD_BLP
{
	my $self = shift;
	my @data = @_;

	if ( $data[0] eq 'BL' )
	{
		# Tell the server we want to allow anyone to invite and chat with us
		$self->send( 'BLP', 'AL' );
	}
}

#================================================
# Getting our list of contact groups
#================================================

sub CMD_LSG
{
	my $self = shift;
	my ($group, $guid) = @_;

#	$self->debug( "Group $group ($guid) added" );
	$self->{Groups}->{$group} = $guid;
}

#================================================
# Getting our list of contacts
#================================================

sub CMD_LST
{
	my $self = shift;

	my ($email, $friendly, $guid, $bitmask, $group);

	my @items = grep { /=/ } @_;
	my @masks = grep { !/=/ } @_;

	my $settings = {};
	foreach my $item (@items)
	{
		my ($what,$value) = split (/=/,$item);
		$settings->{$what} = $value;
	}

	$bitmask = pop @masks;
	if( $bitmask =~ /[a-z]/ )
	{
		$group = $bitmask;
		$bitmask = pop @masks;
	}

	$email	 = $settings->{N};
	$friendly = $settings->{F} || '';
	$guid		 = $settings->{C} || '';

	my $contact = { email	 => $email,
						 Friendly => $friendly,
						 guid		 => $guid,
						 group	 => $group };

#	$self->debug( "'$email', '$friendly', '$bitmask', '$guid'" );	# , '$group'" );

	$self->{Lists}->{SYN}->{Current}++;

	my $current = $self->{Lists}->{SYN}->{Current};
	my $total = $self->{Lists}->{SYN}->{Total};

	$self->{Lists}->{RL}->{$email} = 1			if ($bitmask & 16);  # <-- seems to be set for users who have added you while you were offline
	$self->{Lists}->{RL}->{$email} = 1			if ($bitmask & 8);
	$self->{Lists}->{BL}->{$email} = 1			if ($bitmask & 4);
	$self->{Lists}->{AL}->{$email} = 1			if ($bitmask & 2);
	$self->{Lists}->{FL}->{$email} = $contact if ($bitmask & 1);
	if ($current == $total)
	{
		my $RL = $self->{Lists}->{RL};
		my $AL = $self->{Lists}->{AL};
		my $BL = $self->{Lists}->{BL};

		foreach my $handle (keys %$RL)
		{
			if( !defined $AL->{$handle} && !defined $BL->{$handle} )
			{
				# This contact wants to be allowed, ask if we should
				my $do_add = $self->{Msn}->call_event( $self, "ContactAddingUs", $handle );
				$self->allowContact( $handle ) unless( defined $do_add && !$do_add );
			}
		}

		$self->send( 'CHG', 'NLN ' . $self->{Msn}->{ClientID} );
		$self->{Msn}->call_event( $self, "Connected" );
	}
}

sub CMD_NLN
{
	my $self = shift;
	my ($status, $email, $friendly, $cid) = @_;

	$self->set_contact_status( $email, $status, $friendly, $cid );
}

sub CMD_FLN
{
	my $self = shift;
	my ($email) = @_;

	$self->set_contact_status( $email, 'FLN' );
}

sub CMD_ILN
{
	my $self = shift;
	my ($trid, $status, $email, $friendly, $cid) = @_;

	$self->set_contact_status( $email, $status, $friendly, $cid );
 }

sub CMD_CHG
{
	my $self = shift;
	my @data = @_;
}

sub CMD_ADC
{
	my $self = shift;
	my ($TrID, $list, $handle, $name) = @_;
	(undef, $handle) = split( /=/, $handle );

	if( $list eq 'RL' )		# a user is adding us to their contact list (our RL list)
	{
		$self->{Lists}->{'RL'}->{$handle} = 1;
		# ask for approval before we add this contact (default to approved)
		my $do_add = $self->{Msn}->call_event( $self, "ContactAddingUs", $handle );				  
		$self->allowContact( $handle ) unless( defined $do_add && !$do_add );
	}
	elsif( $list eq 'AL' )  # server telling us we successfully added someone to our AL list
	{
		$self->{Lists}->{'AL'}->{$handle} = 1;
	}
	elsif( $list eq 'BL' )  # server telling us we successfully added someone to our BL list
	{
		$self->{Lists}->{'BL'}->{$handle} = 1;
	}	  
	elsif( $list eq 'FL' )  # server telling us we successfully added someone to our FL list
	{
		my @items = grep { /=/ } @_;
		my $settings = {};	 
		foreach my $item (@items)
		{
			my ($what,$value) = split (/=/,$item);
			$settings->{$what} = $value;
		}

		my $contact = { email	 => $settings->{N},
							 Friendly => $settings->{F},
							 guid		 => $settings->{C},
							 group	 => '' };

		$self->{Lists}->{'FL'}->{$handle} = $contact;
	}
}

sub CMD_REM
{
	my $self = shift;
	my ($TrID, $list, $handle) = @_;

	if( $list eq 'RL' )		# a user is removing us from their contact list (our RL list)
	{
		delete $self->{Lists}->{'RL'}->{$handle};
		$self->{Msn}->call_event( $self, "ContactRemovingUs", $handle );
		$self->disallowContact( $handle);
#		$self->remContact( $handle);
	}
	elsif( $list eq 'AL' )  # server telling us we successfully removed someone from our AL list
	{
		$handle =~ s/^N=//gi;
		delete $self->{Lists}->{'AL'}->{$handle};
	}
	elsif( $list eq 'BL' )  # server telling us we successfully removed someone from our BL list
	{
		delete $self->{Lists}->{'BL'}->{$handle};
	}
	elsif( $list eq 'FL' )  # server telling us we successfully removed someone from our FL list
	{
		foreach my $mail (keys %{$self->{Lists}->{'FL'}})
		{
			 if ($self->{Lists}->{'FL'}->{$mail}->{guid} eq $handle)
			 {
				  delete $self->{Lists}->{'FL'}->{$mail};
				  return;
			 }
		}
	}
}

sub CMD_XFR
{
	my $self = shift;
	my @data = @_;

	if( $data[1] eq 'NS' )
	{
		my ($host, $port) = split( /:/, $data[2] );
		$self->{Socket}->close();
		$self->{Msn}->{Select}->remove( $self->{Socket} );

		# why wouldn't this be defined??
		if( defined $self->{Socket}->fileno )
		{
			delete( $self->{Msn}->{Connections}->{ $self->{Socket}->fileno } );
		}

		$self->connect( $host, $port );
	}
	elsif( $data[1] eq 'SB' )
	{
		if( defined $self->{Calls}->{$data[0]}->{Handle} )
		{
			my ( $host, $port ) = split( /:/, $data[2] );

			# get a switchboard and connect, passing along the call handle and message
			my $switchboard = new MSN::SwitchBoard( $self->{Msn}, $host, $port );
			$switchboard->connectXFR( $data[4], $self->{Calls}->{$data[0]}->{Handle}, $self->{Calls}->{$data[0]}->{Message}, $self->{Calls}->{$data[0]}->{Style} );
		}
		else
		{
			$self->serverError( 'Received XFR SB request, but there are no pending calls!' );
		}
	}
}

#================================================
# someone is calling us
#================================================

sub CMD_RNG
{
	my $self = shift;
	my ($sid, $addr, undef, $key, $user, $friendly) = @_;

	# ask for approval before we answer this ring (default to approved)
	my $do_accept = $self->{Msn}->call_event( $self, "Ring", $user, uri_unescape($friendly) );

	if( !defined $do_accept || $do_accept )
	{
		my ($host, $port) = split ( /:/, $addr );

		my $switchboard = new MSN::SwitchBoard( $self->{Msn}, $host, $port );
		$switchboard->connectRNG( $key, $sid );
	}
}

#================================================
# a challenge (ping) from the server
#================================================

sub CMD_CHL
{
	my $self = shift;
	my @data = @_;
	my $digest = md5_hex( $data[1] . 'JXQ6J@TUOGYV@N0M' );

	$self->sendraw( 'QRY', 'PROD0061VRRZH@4F 32' . "\r\n" . $digest );
}

#================================================
# a response to our QRY
#================================================

sub CMD_QRY
{
	 my $self = shift;
	 my @data = @_;
}

#================================================
# a response to our PNG
#================================================

sub CMD_QNG
{
	my $self = shift;
	my @data = @_;

	$self->{PongTime} = time;
}

#================================================
# Internal methods for authentication
#================================================

sub authenticate
{
	my ($self, $challenge)  = @_;
	$challenge = {map { split '=' } split(',', $challenge)} ;

	$self->debug( "Authenticating : https://nexus.passport.com/rdr/pprdr.asp" );

	my $ua = new LWP::UserAgent;
	my $response = $ua->get('https://nexus.passport.com/rdr/pprdr.asp');
	 unless ($response->is_success) {
		 $self->serverError( "Authentication Error: No response from Passport server" );
			 return undef;
	}
	my %passport_urls = map { split '=' }
							  split(',',($response->headers->header('PassportURLs')));
	my $DALogin = $passport_urls{'DALogin'};

	my ($username,$password) = (uri_escape($self->{Handle}), uri_escape($self->{Password}));

	my $auth_string = "Passport1.4 OrgVerb=GET,OrgURL=$challenge->{ru}}," .
							"sign-in=$username,pwd=$password,lc=$challenge->{lc},".
							"id=$challenge->{id},tw=$challenge->{tw}," .
							"fs=$challenge->{fs},ct=$challenge->{ct}," .
							"kpp=$challenge->{kpp},kv=$challenge->{kv}," .
							"ver=$challenge->{ver},tpf=$challenge->{tpf}";

	return _do_authenticate_loop( $self, 'https://' . $DALogin, $auth_string );
}

sub _do_authenticate_loop
{
	my $self = shift;
	my ($redir,$auth) = @_;
	if ($redir =~ /ru=([^\&]+)/) { $redir = $1; }

	$self->debug( "Authenticating : $redir" );

	my $ua = new LWP::UserAgent;
	my @requests = ();
	$ua->requests_redirectable( \@requests );
	$ua->agent('MSMSGS');

	my $request = new HTTP::Request( GET => $redir );
	$request->headers->header('Authorization' => $auth);
	my $response = $ua->request($request);
	 unless ($response->is_success) {
			$self->serverError( "Authentication Error: No response from Passport server" );
#			return undef;
	 }
	 
	$redir = $response->header('location') || undef;
	my $info = $response->header('authentication-info') || undef;

	if( defined $info )
	{
		my ($Version,$pairs) = $info =~ /^(.*?) (.*)$/;
		my $settings = {map { split('=',$_,2) } split(',' , $pairs)};
		if( $settings->{'da-status'} =~ /^success|redir$/ )
		{
			if( $settings->{'da-status'} eq 'success' )
			{
				$settings->{'from-PP'} =~ s/'//g;
				return $settings->{'from-PP'};
			}
			elsif( $settings->{'da-status'} eq 'redir' )
			{
				return _do_authenticate_loop( $self, $redir,$auth );
			}
			else
			{
				$self->serverError( "Authentication Error: Unexpected return: $info" );
			}
		}
	}
	elsif( defined $redir )
	{
		  return _do_authenticate_loop( $self, $redir, $auth );
	}
	elsif( my $error_info = $response->header('www-authenticate') )
	{
		 $error_info =~ s/^.+cbtxt=(.+)$/$1/;
		 $error_info =~ tr/+/ /;
		 $error_info =~ s/%(..)/pack("c",hex($1))/ge;
		 $self->serverError( "Authentication Error: $error_info" );
	}
	else
	{
		 $self->serverError( "Authentication Error: No expected reply recieved" );
	}
}


return 1;
__DATA__
