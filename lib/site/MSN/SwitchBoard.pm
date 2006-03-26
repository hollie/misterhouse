#================================================
package MSN::SwitchBoard;
#================================================

use strict;
use warnings;

use URI::Escape;

# For DP
use Digest::SHA1 qw(sha1 sha1_hex sha1_base64);
use MIME::Base64;
use Data::Dumper;

use POSIX;

# For errors
use MSN::Util;

sub checksum { my $o = tell(DATA); seek DATA,0,0; local $/; my $t = unpack("%32C*",<DATA>) % 65535; seek DATA,$o,0; return $t;};


sub new
{
	my $class = shift;
	my ($msn, $host, $port) = @_;

	my $self  =
	{
		Msn				=> $msn,
		Host				=> $host,
		Port				=> $port,
		Socket			=> undef,
		Members			=> {},
		Call				=> {},
		p2pQue			=> [],
		Type				=> 'SB',
		MessageStyle	=> $msn->getMessageStyle()
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

	my $method = $MSN::SwitchBoard::AUTOLOAD;

	if( $method =~ /CMD_(.*)$/ )
	{
		$self->cmdError( "$1 not handled in MSN::SwitchBoard" );
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
# Methods to connect from a RNG or XFR
#================================================

sub connectRNG
{
	my $self = shift;
	my ($key, $sid) = @_;

	$self->debug( "Connecting to SwitchBoard at $self->{Host}:$self->{Port}" );

	$self->{Socket} = new IO::Socket::INET(
								  PeerAddr => $self->{Host},
								  PeerPort => $self->{Port},
								  Proto	  => 'tcp',
								  Timeout  => 60
								) or return $self->error( "$!" );

	$self->{Msn}->{Select}->add( $self->{Socket} );
	$self->{Msn}->{Connections}->{ $self->{Socket}->fileno } = $self;
	$self->send( 'ANS', "$self->{Msn}->{Handle} $key $sid" );
}

sub connectXFR
{
	my $self = shift;
	my ($key, $handle, $message, $style) = @_;

	# store the call handle and message for later delivery
	$self->{Call}->{Handle} = $handle;
	$self->{Call}->{Message} = $message;
	$self->{Call}->{Style} = $style;

	$self->debug( "Connecting to SwitchBoard at $self->{Host}:$self->{Port}" );

	$self->{Socket} = new IO::Socket::INET(
								  PeerAddr => $self->{Host},
								  PeerPort => $self->{Port},
								  Proto	  => 'tcp'
								) or return $self->error( "$!" );

	$self->{Msn}->{Select}->add( $self->{Socket} );
	$self->{Msn}->{Connections}->{ $self->{Socket}->fileno } = $self;
	$self->send( 'USR', "$self->{Msn}->{Handle} $key" );
}

#================================================
# Main public methods to set message style,
# send messages and invite contacts into the convo
#================================================

sub setMessageStyle
{
	my $self = shift;

	$self->{MessageStyle} = { (%{$self->{MessageStyle}}), @_ };
}

sub getMessageStyle
{
	my $self = shift;

	return $self->{MessageStyle};
}

sub getMembers
{
	my $self = shift;

	return $self->{Members};
}

sub getID
{
	my $self = shift;

	return (defined $self->{Socket}) ? $self->{Socket}->fileno : 0;
}

sub getType
{
	my $self = shift;

	return 'SB';
}

sub leave
{
	my $self = shift;

	$self->debug( "Leaving SwitchBoard " . $self->{Socket}->fileno ) if( defined $self->{Socket} );

	return $self->_send( "OUT\r\n" );
}

sub sendInk
{
		  my $self = shift;
		  my $data = shift;
#		  my $user = shift;

		  my $bid;
		  my $inkheader = "MIME-Version: 1.0\r\nContent-Type: application/x-ms-ink\r\n";

		  do { $bid = 1000 + int(rand(10000000));} while( exists $self->{P2PTransfers}->{$bid});

		  if($data =~ m/\.isf/){
					 open( INK, $data ) or return $self->error( "Could not find the file '$data'" );
					 binmode(INK);
					 $data	= '';
					 while( <INK> ) { $data .= $_; }
					 close(INK);
					 $data = encode_base64($data);
					 $data =~ s/\n//gs;

		  }
		  #check num of users
		  if(scalar(keys %{$self->getMembers})==1){
		  my @members = keys %{$self->getMembers};
		  #do p2p ink
					 # UTF-16 the Data
					 my $ink_data = $inkheader . "\r\n\0base64:$data";
					 $ink_data = pack("S*", unpack("C*", $ink_data), 0);
					 my $ink_len  = length($ink_data);
							for (my $offset  = 0; $offset < $ink_len;$offset += 1202 )
					 {
	 					  my $data = substr($ink_data, $offset, 1202);
	 					  $self->_sendp2p({
											 Name				  => $members[0],
											 SessionID		  => 64,
											 BaseID			  => $bid,
	 											 Offset			  => $offset,
											 TotalSize		  => $ink_len,
	 											 Size			  => length($data),
	 											 Data			  => $data,
	 											 Footer			  => 3,
					  });
					 };
		  } else {
		  #do normal ink
				my $chunks = ceil(length( $data ) / 1202);
					if($chunks > 1){
					 for (my $chunk = 0; $chunk < $chunks; $chunk++) {
						  my $ink_data = $inkheader . "Message-ID: {CDB7FFFF-C94B-9CC9-5C09-4BFFE25FFFFF}\r\n";
			$ink_data .= ($chunk) ? "Chunk: $chunk\r\n\r\n" : "Chunks: $chunks\r\n\r\nbase64:";
			$ink_data .= substr($data, $chunk * 1202, 1202) . "\r\n";
					 $self->sendraw('MSG', 'N '.length($ink_data). "\r\n" . $ink_data);
					 };
				} else {
				  my $ink_data = $inkheader . "\r\nbase64:$data\r\n";
				  $self->sendraw('MSG', 'N '.length($ink_data). "\r\n" . $ink_data);
				  }
		  }
}

sub sendMessage
{
	my $self = shift;
	my $response = shift;

	if( !defined $response )	{ return $self->error( "You must pass the message you want to send" ); }

	# pull in the default style and overwrite with optionally passed in style
	# encode the Font name, which should only really encode spaces (maybe change this to substitute spaces with %20)
	my $style = { (%{$self->{MessageStyle}}), @_ };
	$style->{Font} = uri_escape( $style->{Font} );

	while( $response =~ /(.{1,1400})/gs )
	{
		my $message = $1;
		if( length $message )
		{
			my $objects = $self->{Msn}->{Notification}->{Objects};
			my @emotes = keys(%{$objects});
			@emotes = grep { index($message, $_) > -1 } @emotes;

			# only five allowed per message
			my $count = scalar (@emotes) < 6 ? scalar(@emotes) - 1 : 5;
			my $emomsg = join "", map {"$_\t". $objects->{$_}->{Object}."\t"} @emotes[0 .. $count] ;

			# Check
			if( $emomsg )
			{
				 my $emoheader = "MIME-Version: 1.0\r\nContent-Type: text/x-mms-emoticon\r\n\r\n$emomsg";
				 $self->sendraw("MSG", "N ".length($emoheader)."\r\n$emoheader");
			}

			my $header = qq{MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\n} .
							 qq{X-MMS-IM-Format: FN=$style->{Font}; EF=$style->{Effect}; }.
							 qq{CO=$style->{Color}; CS=$style->{CharacterSet}; } .
							 qq{PF=$style->{PitchFamily}\n};

			$header .= "P4-Context: " . $style->{Name} . "\n" if( exists $style->{Name} );
			$header .= "\n" . $message;
			$header =~ s/\n/\r\n/gs;
			$self->sendraw( 'MSG', 'U ' . length($header) . "\r\n" . $header );
	  }
	}
}

sub sendTyping
{
	my $self = shift;

	my $header = qq{MIME-Version: 1.0\nContent-Type: text/x-msmsgscontrol\nTypingUser: } . $self->{Msn}->{Handle} . qq{\n\n\n};
	$header =~ s/\n/\r\n/gs;
	$self->sendraw( 'MSG', 'N ' . length($header) . "\r\n" . $header);
}

sub sendClientCaps
{
	my $self = shift;

	return if( scalar keys %{$self->{Msn}->{ClientCaps}} == 0 );

	my $caps = '';
	foreach my $key (keys %{$self->{Msn}->{ClientCaps}})
	{
		$caps .= $key . ": " . $self->{Msn}->{ClientCaps}->{$key} . "\n";
	}

	my $header = qq{MIME-Version: 1.0\nContent-Type: text/x-clientcaps\n\n} . $caps . qq{\n\n\n};
	$header =~ s/\n/\r\n/gs;
	$self->sendraw( 'MSG', 'N ' . length($header) . "\r\n" . $header);

#	$header = qq{MIME-Version: 1.0\nContent-Type: text/x-botcaps\n\n} . 'Key: Value' . qq{\n\n\n};
#	$header =~ s/\n/\r\n/gs;
#	$self->sendraw( 'MSG', 'N ' . length($header) . "\r\n" . $header);
}

sub invite
{
	my $self = shift;
	my $handle = shift || return $self->error( "Need a handle to invite" );

	$self->send( 'CAL',  $handle );
	return 1;
}

#================================================
# Internal methods to send data to the server
#================================================

sub _send
{
	my $self = shift;
	my $msg = shift || return $self->error( "No message specified" );

	# Send the data to the socket.
	$self->{Socket}->print( $msg );
	my $fn = $self->{Socket}->fileno;
	if( $msg eq "OUT\r\n" || $msg eq "BYE\r\n" )
	{
		$self->{Msn}->{Select}->remove( $fn );
		delete $self->{Msn}->{Connections}->{ $fn };
		undef $self->{Socket};
	}
	chomp($msg);

	print( "($fn $self->{Type}) TX: $msg\n" ) if( $self->{Msn}->{ShowTX} );

	return length($msg);
}

sub send
{
	my $self = shift;
	my $cmd  = shift || return $self->error( "No command specified to send" );
	my $data = shift;

	# Generate TrID using global TrID value...
	my $datagram = $cmd . ' ' . $self->{Msn}->{Notification}->{TrID}++ . ' ' . $data . "\r\n";
	return $self->_send( $datagram );
}

sub sendraw
{
	my $self = shift;
	my $cmd = shift || return $self->error( "No command specified to send" );
	my $data  = shift;
	# same as send without the "\r\n"

	my $datagram = $cmd . ' ' . $self->{Msn}->{Notification}->{TrID}++ . ' ' . $data;
	return $self->_send( $datagram );
}

sub sendrawnoid
{
	my $self = shift;
	my $cmd = shift || return $self->error( "No command specified to send" );
	my $data  = shift;

	my $datagram = $cmd . ' ' . $data;
	return $self->_send( $datagram );
}

sub isOnline
{
	my $self = shift;
	my $handle = shift || return $self->error( "Need to send the handle of the person you want to check" );

	# try to get a new switchboard
	$self->send( 'CAL', $handle );

	# store the handle and message of this call for use after we have a switchboard (why subtract 1 here??)
#	my $TrID = $self->{TrID} - 1;
}

#================================================
# Method to dispatch server messages to the right handlers
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
		&{$c}($self,@data);
	}
}

#================================================
# MSN Server messages handled by SwitchBoard
#================================================

sub CMD_JOI
{
	my $self = shift;
	my ($user, $friendly) = @_;

	if( $self->{Call}->{Message} )
	{
		$self->sendMessage( $self->{Call}->{Message}, %{$self->{Call}->{Style}} );
		delete $self->{Call}->{Message};
		delete $self->{Call}->{Style};
	}

	$self->{Members}->{$user} = $friendly;
	$self->{Msn}->call_event( $self, "MemberJoined", $user, uri_unescape($friendly) );

	$self->sendClientCaps();
}

sub CMD_IRO
{
	my $self = shift;
	my (undef, $current, $total, $user, $friendly) = @_;

	if( $current == 1 )
	{
		$self->{Msn}->call_event( $self, "RoomOpened" );
	}

	$self->{Members}->{$user} = $friendly;
	$self->{Msn}->call_event( $self, "MemberHere", $user, uri_unescape($friendly) );

	if ($current == $total)
	{
		$self->{Msn}->call_event( $self, "RoomUpdated" );
		$self->sendClientCaps();
	}
}

sub CMD_ANS
{
	my $self = shift;
	my ($response) = @_;

	$self->{Msn}->call_event( $self, "Answer" );
}

sub CMD_CAL
{
	my $self = shift;
	my @data = @_;

}

sub CMD_BYE
{
	my $self = shift;
	my ($user) = @_;

	delete $self->{Members}->{$user} if $self->{Members}->{$user};
	$self->{Msn}->call_event( $self, "MemberLeft", $user );

	if( scalar keys %{$self->{Members}} == 0 )
	{
		$self->{Msn}->call_event( $self, "RoomClosed" );
		$self->{Msn}->{Select}->remove( $self->{Socket}->fileno() );
		delete $self->{Msn}->{Connections}->{ $self->{Socket}->fileno() };
#		undef $self;
	}
}

sub CMD_USR
{
	my $self = shift;
	my @data = @_;

	if( $data[1] eq 'OK' )
	{
		if( defined $self->{Call}->{Handle} )
		{
			$self->send( 'CAL',  $self->{Call}->{Handle} );
		}
		else
		{
			return $self->error( "Missing a call handle?\n" );
		}
	}
	else
	{
		return $self->error( 'Unsupported authentication method: "' . "@data" .'"' );
	}
}

sub CMD_MSG
{
	my $self = shift;
	my ($user, $friendly, $length) = @_;

	# we don't have the full message yet, so store it and return
	if( length( $self->{buf} ) < $length )
	{
		$self->{buf} = $self->{line} . $self->{buf};
		return "wait";
	}

	# get the message and split into header and msg content
	my ( $header, $msg ) = ( '', substr( $self->{buf}, 0, $length, "" ) );
	($header, $msg) = _strip_header($msg);

	# determine message type
	if( $header->{'Content-Type'} =~ /text\/x-msmsgscontrol/ )
	{
		$self->{Msn}->call_event( $self, "Typing", $user, uri_unescape($friendly) );
	}
	elsif( $header->{'Content-Type'} =~ /text\/x-msmsgsinvite/ )
	{
		my $settings = { map { split(/\: /,$_) } split (/\n/, $msg) };
		if( $settings->{'Invitation-Command'} eq "INVITE" && $settings->{'Application-Name'} eq "File Transfer" )
		{
			 $self->{Msn}->call_event( $self, "FileReceiveInvitation",
										$user, uri_unescape($friendly),
										$settings->{'Invitation-Cookie'},
										$settings->{'Application-File'},
										$settings->{'Application-FileSize'} );
		}
		elsif ($settings->{'Invitation-Command'} eq "ACCEPT")
		{
		}
		elsif ($settings->{'Invitation-Command'} eq "CANCEL")
		{
		}
		# other....
	}
	 elsif( $header->{'Content-Type'} =~ /text\/x-mms-emoticon/ )
	 {
		  # emoticon objects being sent
	 }
	 elsif( $header->{'Content-Type'} =~ /application\/x-ms-ink/ )
	 {
		  # normal ink message being sent
	 }
	elsif( $header->{'Content-Type'} =~ /application\/x-msnmsgrp2p/ )
	{
		$self->p2p_transfer($user, $msg);
	}
	elsif( $header->{'Content-Type'} =~ /text\/x-clientcaps/ )
	{
		my $client_caps = { map { split(/\: /,$_) } split (/\n/, $msg) };

		$self->{Msn}->call_event( $self, "ClientCaps", $user, %$client_caps );
	}
#	elsif( $header->{'Content-Type'} =~ /text\/x-botcaps/ )
#	{
#		my $bot_caps = { map { split(/\: /,$_) } split (/\n/, $msg) };

#		print( "Bot caps for $user\n" );

#		foreach my $key (keys %$bot_caps)
#		{
#			print( "$key = $bot_caps->{$key}\n" );
#		}
#	}
	elsif( $header->{'Content-Type'} =~ /application\/x-msnmsgr-sessionreqbody/ )	{}
	elsif( $msg =~ /INVITE\s+MSNMSGR/g || $msg =~ /BYE\s+MSNMSGR/g )					{}
	else
	{	 # regular hopefully
		my $format_info = $header->{'X-MMS-IM-Format'} || 'FN=; EF=; CO=; CS=; PF=';
		$format_info =~ /FN=(.*?);\s+EF=(.*?);\s+CO=(.*?);\s+CS=(.*?);\s+PF=(.*?)/;
		my %style = ( Font => $1, Effect => $2, Color => $3, CharacterSet => $4, PitchFamily => $5 );

		$self->{Msn}->call_event( $self, "Message", $user, uri_unescape($friendly), $msg, %style );
	}
}

sub p2pWaiting
{
	 my $self = shift;
	 return scalar @{$self->{p2pQue}};
}

sub p2pSendOne
{
	 my $self = shift;
	 my $msg = shift @{$self->{p2pQue}};
	 if ($msg) {
		  $self->sendraw("MSG", "D " . length($msg) . "\r\n" . $msg );
	 }
}

sub _sendp2p
{
	 my $self = shift;
	 my $args = shift;

	 my $head = "MIME-Version: 1.0\r\n" .
					"Content-Type: application/x-msnmsgrp2p\r\n".
					"P2P-Dest: " . $args->{Name} . "\r\n" .
					"\r\n";


	 my $bin = MakeDWord($args->{SessionID}	  || 0) .					  #1
					  MakeDWord($args->{BaseID}		  || 0) .					  #2
					  MakeDWord($args->{Offset}		  || 0) . MakeDWord(0)  . #3  (faked QWord)
					  MakeDWord($args->{TotalSize}	  || 0) . MakeDWord(0)  . #4  (faked QWord)
				  MakeDWord($args->{Size}			  || length($args->{Data} || '')) . #5
					  MakeDWord($args->{Flag}			  || 0) .					  #6
					  MakeDWord($args->{PrevBaseID}	  || 0) .					  #7
					  MakeDWord($args->{AckPrevBaseID} || 0) .					  #8
					  MakeDWord($args->{AckSize}		  || 0) . MakeDWord(0)  . #9  (faked QWord)
				  ($args->{Data} || '' ).
					  MakeDWord($args->{Footer}		  || 0, 1);

	 my $msg = $head . $bin;
	 push @{$self->{p2pQue}}, $msg;
#	  $self->sendraw("MSG", "D " . length($msg) . "\r\n" . $msg );
};



sub p2p_transfer
{
	my $self = shift;
	my $user = shift;
	my $data = shift;

	my $notification = $self->{Msn}->{Notification};

	# get p2p header and footer info.
	my $header = substr($data, 0, 48);
	my %fields;
	$fields{1} = substr($header, 0, 4);
	$fields{2} = substr($header, 4, 4);
	$fields{4} = substr($header, 16, 8);
	$fields{7} = substr($header, 32, 4);
	$fields{8} = substr($header, 36, 4);

	# Grab parameters if this is an invitation

			 if(index($data, "x\0-\0m\0s\0-\0i\0n\0k")+index($data, "x-ms-ink") > 0){
			 $data =~ s/\0//gs;
			 $data =~ m/base64:(.*?)\W$/gsi;
			 $self->{Msn}->call_event($self, "Ink", $user, $1);

			 my $bin = (MakeDWord(64).MakeDWord(1000 + int(rand(100000000))).(chr(0) x 8).$fields{4}.(chr(0) x 4).MakeDWord(2).$fields{2}.$fields{7}.$fields{4}.(chr(0) x 4));
			 $bin = "MIME-Version: 1.0\r\nContent-Type: application/x-msnmsgrp2p\r\nP2P-Dest: $user\r\n\r\n$bin";
			 $self->sendraw("MSG", "D ".length($bin)."\r\n$bin");
			 }
	  my $params = {};
	  if ( index($data, "INVITE MSNMSGR:") ){
			foreach my $line ( split("\n", $data) ) {
					 next unless length $line;
					 my ($key, $value) = split(' ', $line, 2);
					 $params->{$key} = $value;
		  }
	 }

	  $params->{'Context:'} = decode_base64($params->{'Context:'} || '');

	 # Check if this a start of a new transfer
	if($params->{'EUF-GUID:'})
	 {
		  # Make a unique BID
		  my $bid;
		  do { $bid = 1000 + int(rand(10000000));} while( exists $self->{P2PTransfers}->{$bid});

		  # Then send the BaseID message
		my $temp = GetDWord(substr($fields{4},0,4));

		  $self->_sendp2p({ Name			 => $user,
									 BaseID			=> $bid,
															  TotalSize		 => $temp,
															  AckSize		 => $temp,
															  Flag			 => 2,
															  PrevBaseID	 => GetDWord($fields{2}),
															  AckPrevBaseID => GetDWord($fields{7}),
								  } );

		  # Check if this is a Emote/DP/FTP
		if ($params->{'EUF-GUID:'} eq '{A4268EEC-FEC5-49E5-95C3-F126696BDBF6}')
		  {
				# DP or Emote
				# Store information we need later on
				$self->{P2PTransfers}->{$bid}->{SessionID} = $params->{'SessionID:'};
				($self->{P2PTransfers}->{$bid}->{Location}) = $params->{'Context:'} =~ /Location="(.*?)"/;

				my $okdata = "SessionID: " . $params->{'SessionID:'} . "\r\n\0";

	 			$okdata = "MSNSLP/1.0 200 OK"														  . "\r\n" .
								  "To: <msnmsgr:"		 . $user												. "\r\n" .
								  "From: <msnmsgr:"	 . $self->{Msn}->{Handle}						. "\r\n" .
								  "Via: "				 . $params->{'Via:'}								. "\r\n" .
								  "CSeq: "				 . '1 '												 . "\r\n" .
								  "Call-ID: "			 . $params->{'Call-ID:'}						. "\r\n" .
								  "Max-Forwards: "	 . '0'												. "\r\n" .
								  "Content-Type: "	 . "application/x-msnmsgr-sessionreqbody" . "\r\n" .
								  "Content-Length: "  . length($okdata)								. "\r\n" .
								  "\r\n" .
								  $okdata;

				$self->_sendp2p({ Name		  => $user,
											 BaseID		=> $bid - 3,
																		TotalSize  => length($okdata),
																		PrevBaseID => 100,
											 Data			=> $okdata,
																	  });
		  }
		elsif($params->{'EUF-GUID:'} eq '{5D3E02AB-6190-11D3-BBBB-00C04F795683}')
		{
				# ToDo: FTP
		}
	 }
	 else
	 {
		  my $bid	  = GetDWord($fields{7});
		  my $process = GetDWord($fields{8});

		  if($process == 100)
		  {
				# Send the DataPrep message
				$bid+=3;
				my $session = $self->{P2PTransfers}->{$bid}->{SessionID};
					 $self->debug( "Sending Ack" );
				$self->_sendp2p({ Name		  => $user,
											 SessionID  => $session,
																				BaseID	  => $bid - 2,
																				TotalSize  => 4,
																				PrevBaseID => 101,
											 Footer		=> 4,
											 Data			=> MakeDWord(0),
																			 });
		  }
		  elsif($process == 101)
		  {
				# Send the actual DP data :)
				$bid+=2;

				# Predefined values (this saves time instead of having to create them in each loop)
				my $location = $self->{P2PTransfers}->{$bid}->{Location};
				my $FileD	= $notification->{Objects}->{$location}->{Data};
				my $FileL	= length($FileD);
				my $session = $self->{P2PTransfers}->{$bid}->{SessionID};

				for (my $offset = 0; $offset < $FileL; $offset += 1202) {
					 my $TFileD = substr($FileD, $offset, 1202);
					 $self->_sendp2p( { Name		 => $user,
													 SessionID  => $session,
																				BaseID	 => $bid - 1,
																				Offset	 => $offset,
																				TotalSize => $FileL,
																				Flag		 => 32,
																				PrevBaseID => 102,
													 Footer		=> 4,
													 Data			=> $TFileD,
																			  });
				}

				# Remove object from p2ptransfers hash
				# We are done *big smile*
				delete $self->{P2PTransfers}->{$bid};
		  }
	 }
}

sub MakeDWord
{
	 my ($word,$little) = @_;
	MSN::error(undef, $word) if $word =~ /[^0-9]/;
	 return $little ? pack("N", $word) : pack("V", $word);
}

sub GetDWord
{
	 my ($word,$little) = @_;
	 return $little ? unpack("N", $word) : unpack("V", $word);
}


#================================================
# Utility function for removing header from a message
#================================================

sub _strip_header
{
	my $msg = shift;

	$msg =~ s/\r//gs;	  # fix newlines
	if ($msg =~ /^(.*?)\n\n(.*?)$/s)
	{
		my ($head, $msg) = ($1,$2);
		my @temp = split (/\n/, $head);
		my $header = {};
		foreach my $item (@temp)
		{
			my ($key,$value) = split(/:\s*/,$item);
			$header->{$key} = $value || "";
		}

		return $header,$msg;
	}
	return {}, $msg;
}


return 1;
__DATA__
