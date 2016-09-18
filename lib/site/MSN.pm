#================================================
package MSN;
#================================================

=head1 MSN v2.0

=cut

use strict;
use warnings;

# IO
use IO::Select;

use MSN::Notification;
use MSN::SwitchBoard;
use MSN::Util;

use constant CVER10 => '0x0409 winnt 5.0 i386 MSNMSGR 6.1.0203 MSMSGS ';
use constant VER => 'MSNP10 MSNP9 CVR0';

my $REVISION = '$Rev: 84 $';
$REVISION =~ s/\$//g;
my $VER = 'MSNP10 MSNP9 CVR0';

# print out the version and checksum
my $strVERSION = "MSN 2.0 (01/21/2005) $REVISION";
sub checksum { my $o = tell(DATA); seek DATA,0,0; local $/; my $t = unpack("%32C*",<DATA>) % 65535;seek DATA,$o,0; return $t;};
print $strVERSION . " - Checksum: " . checksum() . "-NS" . MSN::Notification::checksum() . "-SB" . MSN::SwitchBoard::checksum() . "\n\n";


=head2 Methods

=item
new

Creates an instance of the MSN object used to communicate with MSN Servers.

=cut

sub new
{
	my $class = shift;

	my $self  =
	{
		Host					=> 'messenger.hotmail.com',
		Port					=> 1863,
		Handle				=> '',
		Password				=> '',
		Debug					=> 0,
		ServerError			=> 1,
		Error					=> 1,
		AutoloadError		=> 0,
		CMDError				=> 0,
		ShowTX				=> 0,
		ShowRX				=> 0,
		AutoReconnect		=> 1,
		Select				=> new IO::Select(),
		Notification		=> undef,
		Connections			=> {},
		Connected			=> 0,
		Status				=> 'NLN',
		LastError			=> '',
		MessageStyle		=> { Font			=> "MS Shell Dlg",
									  Effect			=> "",
									  Color			=> "000000",
									  CharacterSet => 0,
									  PitchFamily  => 0
									},
		ClientID				=> 536870920,
		ClientCaps			=> { },
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

	$self->error( "method $MSN::AUTOLOAD not defined" ) if( $self->{AutoloadError} );
}

sub toggle
{
	my $self = shift;
	my $flag = shift || return $self->error( "Flag is missing" );

	return $self->error( "Unknown flag (check spelling or case?)" ) if( $flag !~ /^Debug|ServerError|Error|AutoloadError|CMDError|ShowTX|ShowRX|AutoReconnect$/ );

	$self->{$flag} = !$self->{$flag};

	return 1;
}

sub setKey
{
	my $self = shift;
	my $key = shift || return $self->error( "Key is missing" );
	my $value = shift;

	if( $key =~ /^Debug|ServerError|Error|AutoloadError|CMDError|ShowTX|ShowRX|AutoReconnect$/ )
	{
		return $self->error( "Invalid value for $key (should be 0 or 1)" ) if( $value != 1 && $value != 0 );
		$self->{$key} = $value;
	}
	elsif( $key =~ /^PingIncrement|NoPongMax$/ )
	{
		return $self->error( "Invalid value for $key (should be greater than 0)" ) if( $value <= 0 );
		$self->{Notification}->{$key} = $value;
	}
	else
	{
		return $self->error( "Unknown key (check spelling or case?)" );
	}

	return 1;
}

sub debug
{
	my $self = shift;
	my $message = shift || '';

	if( defined $self->{handler}->{Debug} )
	{
		$self->call_event( $self, 'Debug', $message );
	}
	elsif( $self->{Debug} )
	{
		print( "$message\n" );
	}

	return 1;
}

sub serverError
{
	my $self = shift;
	my $message = shift || '';

	if( defined $self->{handler}->{ServerError} )
	{
		$self->call_event( $self, 'ServerError', $message );
	}
	elsif( $self->{ServerError} )
	{
		print( "SERVER ERROR : $message\n" );
	}

	return 0;
}

sub error
{
	my $self = shift;
	my $message = shift || '';

	$self->{LastError} = $message;

	if( defined $self->{handler}->{Error} )
	{
		$self->call_event( $self, 'Error', $message );
	}
	elsif( $self->{Error} )
	{
		print( "ERROR : $message\nCaller trace:\n" );

		for( my $i=0; $i<20; $i++ )
		{
			my ($package, $filename, $line, $subroutine, @more ) = caller($i);
			last if( !defined $package );
			$filename =~ s/.*MSN/MSN/gi;
			print( "  $i: $subroutine ($filename, line $line)\n" );
		}
	}

	return 0;
}

sub cmdError
{
	my $self = shift;
	my $message = shift || '';

	print( "UNDEFINED CMD : $message\n" ) if( $self->{CMDError} );

	return 0;
}

sub getLastError
{
	my $self = shift;

	return $self->{LastError};
}


=item
connect

Connect to MSN. Call this after your object is created and your event handlers are set.

=cut

sub connect
{
	my $self = shift;

	$self->debug( "Connecting to $self->{Host}:$self->{Port} as $self->{Handle}/$self->{Password}" );

	$self->{Notification} = new MSN::Notification( $self, $self->{Host}, $self->{Port}, $self->{Handle}, $self->{Password} );

	if( $self->{Notification}->connect() )
	{
		$self->{Connected} = time;
	}
}

=item
disconnect

Disconnect from MSN.

=cut

sub disconnect
{
	my $self = shift;

	foreach my $convo (values %{$self->getConvoList()})
	{
		$convo->leave();
	}

	$self->{Notification}->disconnect();

	$self->{Connected} = 0;

	return 1;
}

=item
isConnected()

Checks if the connection is active.

=cut

sub isConnected
{
	my $self = shift;

	return $self->{Connected};
}

=item
uptime()

Get the current uptime in seconds (since the last connection).

=cut

sub uptime
{
	my $self = shift;

	return ($self->{Connected}) ? (time - $self->{Connected}) : 0;
}

#================================================
# Set and Get methods
#================================================

=item
setName

Set the display name.

=cut

sub setName
{
	my $self = shift;

	return $self->{Notification}->setName( @_ );
}

=item
setDisplayPicture($file)

Set the display picture. This must be passed a png file and resets your status to NLN so that your Display picture gets sent out.

=cut

sub setDisplayPicture
{
	my $self = shift;

	return $self->{Notification}->setDisplayPicture( @_ );
}

=item
setMessageStyle(%hash)

Set the default style information (font, effect, etc) for sending messages.

=cut

sub setMessageStyle
{
	my $self = shift;

	$self->{MessageStyle} = { (%{$self->{MessageStyle}}), @_ };
}

=item
getMessageStyle()

Get the default style information (font, effect, etc) for sending messages.

=cut

sub getMessageStyle
{
	my $self = shift;

	return $self->{MessageStyle};
}

=item
setClientInfo(%hash)

Set the client info. This is the client id and flags that make up the cid.

=cut

sub setClientInfo
{
	my $self = shift;
	my %info = @_;

	$self->{ClientID} = MSN::Util::convertToCid( %info );

	return 1;
}

=item
getClientInfo()

Get the client info. This is the client id and flags that make up the cid.

=cut

sub getClientInfo
{
	my $self = shift;

	return MSN::Util::convertFromCid( $self->{ClientID} );
}

=item
setClientCaps(%hash)

Set the client caps. These are the x-clientcaps data.

=cut

sub setClientCaps
{
	my $self = shift;
	my %caps = @_;

	$self->{ClientCaps} = \%caps;

	return 1;
}

=item
getClientCaps()

Get the client caps. These are the x-clientcaps data.

=cut

sub getClientCaps
{
	my $self = shift;

	return $self->{ClientCaps};
}

=item
setStatus

Set the status.

=cut

sub setStatus
{
	my $self = shift;

	return $self->{Notification}->setStatus( @_ );
}

#================================================
# Contact methods
#================================================

=item
blockContact($email)

Puts $email on your block list.

=cut

sub blockContact
{
	my $self = shift;

	return $self->{Notification}->blockContact( @_ );
}

=item
unblockContact($email)

Removes $email from your block list.

=cut

sub unblockContact
{
	my $self = shift;

	return $self->{Notification}->unblockContact( @_ );
}

=item
addContact($email)

Puts $email on your contact list. This allows you to recieve status messages about this individual.

=cut

sub addContact
{
	my $self = shift;

	return $self->{Notification}->addContact( @_ );
}

=item
remContact($email)

Removes $email from your contact list.

=cut

sub remContact
{
	my $self = shift;

	return $self->{Notification}->remContact( @_ );
}

=item
allowContact($email)

Puts $email on your allow list. This is generaly automatic but there might be some cases where it is useful.
If you do not want to automatically allow contacts to see you online, you can set a handler for the "ContactAddingUs"
event and return 0.

=cut

sub allowContact
{
	my $self = shift;

	return $self->{Notification}->allowContact( @_ );
}

=item
disallowContact($email)

Removes $email from your allow list.  They will no longer be able to see you or talk to you.

=cut

sub disallowContact
{
	my $self = shift;

	return $self->{Notification}->disallowContact( @_ );
}

=item
getContactList($list)

Expects $list to be one of FL, RL, AL, or BL.  Returns the email addresses on said list.

=cut

sub getContactList
{
	my $self = shift;

	return $self->{Notification}->getContactList( @_ );
}

=item
getContact($email)

Returns a hash containing all known info for this contact.

=cut

sub getContact
{
	my $self = shift;

	return $self->{Notification}->getContact( @_ );
}

=item
getContactName($email)

Returns the friendly name used by this contact, if they are on your FL list.

=cut

sub getContactName
{
	my $self = shift;

	return $self->{Notification}->getContactName( @_ );
}

=item
getContactStatus($email)

Returns the status of this contact, if they are on your FL list.

=cut

sub getContactStatus
{
	my $self = shift;

	return $self->{Notification}->getContactStatus( @_ );
}

=item
getContactClientInfo($email)

Returns the client info of this contact, if they are on your FL list.

=cut

sub getContactClientInfo
{
	my $self = shift;

	return $self->{Notification}->getContactClientInfo( @_ );
}

#================================================
# Other
#================================================

=item
findMember($email)

Looks for a member in an active SwitchBoard and returns the SB or undef, if not found.

=cut

sub findMember
{
	my $self = shift;
	my $email = shift || '';

	foreach my $convo (values %{$self->getConvoList()})
	{
		my $members = $convo->getMembers();

		return $convo if( defined $members->{$email} );
	}

	return undef;
}

=item
addEmoticon($shortcut, $filename)

Adds an emoticon to your connection. This loads the file and prepares it. Anytime you use the text form $shortcut in an outgoing message it will be replaced with the appropriate emoticon. You can only use 5 different emoticons per message.

=cut

sub addEmoticon
{
	my $self = shift;

	return return $self->{Notification}->addEmoticon( @_ );
}

=item
broadcast($msg,%style)

Broadcasts the message to all open conversations.

=cut

sub broadcast
{
	my $self = shift;
	my @data = @_;		# probably don't have to do this, but just to be safe

	foreach my $convo (values %{$self->getConvoList()})
	{
		$convo->sendMessage( @data );
	}
}

=item
call($email,$msg,%style)

Calls the contact, starting a conversation with them.

=cut

sub call
{
	my $self = shift;

    print "db in call for $self\n";

	$self->{Notification}->call( @_ );
}

sub isOnline
{
	my $self = shift;

}

=item
do_one_loop()

Process a single cycle's worth of incoming and outgoing messages.  This should be done at a regular intervals, preferably under a second.

=cut

sub do_one_loop
{
	my $self = shift;

	# return immediately if we are not connected
	return if( !$self->{Connected} );

	$self->{Notification}->ping( );

	foreach my $convo (values %{$self->getConvoList()})
	{
		$convo->p2pSendOne() if $convo->p2pWaiting;
	}

	my @ready = $self->{Select}->can_read(.1);
	foreach my $fh ( @ready )
	{
		# get the filenumber for this filehandle
		my $fn = $fh->fileno;

		# get the object assocatied with this filenumber
		my $connection = $self->{Connections}->{$fn};

		# DO WE NEED THIS CODE? if the connection is really dead, will it even be showing up in the list of filehandles that can be read from??
		# if the connection is dead, remove it from the select, delete it from the Connections list and output a warn
		if( !$connection->{Socket}->connected() )
		{
			$self->{Select}->remove( $fn );
			delete( $self->{Connections}->{fn} );
			warn "Killing dead socket";
			next;
		}

		sysread( $fh, $connection->{buf}, 2048, length( $connection->{buf} || '' ) );

		while( $connection->{buf} =~ s/^(.*?\n)// )
		{
			$connection->{line}= $1;
			my $incomingdata = $connection->{line};
			$incomingdata =~ s/[\r\n]//g;

			print( "($fn $connection->{Type}) RX: $incomingdata\n" ) if( $self->{ShowRX} );

			my $result = $connection->dispatch( $incomingdata );
			last if( $result && $result eq "wait" );
		}
	}
}


=item
setHandler($event, $handler)

$event should be an event listed in the events section.  These are called based on information sent by MSN,
receiving a message is an event, status changes are events, getting a call is an event, etc.

	 $msn->setHandler( Connected => \&connected );

	 sub connected {
		 my $self = shift;
		 print "Yay we connected";
	 }

=cut

sub setHandler
{
	my $self = shift;
	my ($event, $handler) = @_;

	$self->{handler}->{$event} = $handler;
}

=item
setHandlers( $event1 => $handler1, $event2 => $handler2)

Expects a list of events and handlers.

	  my $msn = new MSN;
	  $msn->setHandlers( Connected	  => \&connected,
								 Disconnected => \&disconnected );

=cut

sub setHandlers
{
	my $self = shift;
	my $handlers = { @_ };
	for my $event (keys %$handlers)
	{
		$self->setHandler( $event, $handlers->{$event} );
	}
}

sub call_event
{
	my $self = shift;
	my $receiver = shift;
	my $event = shift;

	# get and run the handler if it is defined
	my $function = $self->{handler}->{$event};
	return &$function( $receiver, @_ ) if( defined $function );

	# get and run the default handler if it is defined
	$function = $self->{handler}->{Default};
	return &$function( $receiver, $event, @_ ) if( defined $function );

	return undef;
}

=item
getNotification

Returns the MSN::Notification object if you have a need to interact with it directly.

=cut

sub getNotification
{
	my $self = shift;

	return $self->{Notification};
}

=item
getConvoList

Returns a hash of conversations (MSN::SwitchBoard objects) keyed by file number of the socket they are on.

=cut

sub getConvoList
{
	my $self = shift;

	my $convos = {};

	foreach my $fn (keys %{$self->{Connections}} )
	{
		if( $self->{Connections}->{$fn}->getType() eq 'SB' )
		{
			$convos->{$fn} = $self->{Connections}->{$fn};
		}
	}

	return $convos;
}

=item
getConvo

Returns a conversation (MSN::SwitchBoard object) found by socket number.

=cut

sub getConvo
{
	my $self = shift;
	my $key = shift;

	if( defined $self->{Connections}->{$key} && $self->{Connections}->{$key}->getType() eq 'SB' )
	{
		return $self->{Connections}->{$key};
	}

	return undef;
}


return 1;
__DATA__
