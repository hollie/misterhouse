package Net::AIM::Connection;

use Net::AIM::Event;
use Socket;
use Symbol;
use Carp;
use strict;               # A little anal-retention never hurt...
use vars (                # with a few exceptions...
	  '$AUTOLOAD',    #   - the name of the sub in &AUTOLOAD
	  '%_udef',       #   - the hash containing the user's global handlers
	  '%autoloaded',  #   - the hash containing names of &AUTOLOAD methods
	 );


# The names of the methods to be handled by &AUTOLOAD.
# It seems the values ought to be useful *somehow*...
my %autoloaded = (
		  'tocserver'  => undef,
		  'tocport'     => undef,
		  'authserver'  => undef,
		  'authport'     => undef,
		  'screenname' => undef,
		  'password' => undef,
		  'socket'   => undef,
		  'verbose'  => undef,
		  'parent'   => undef,
		 );

# This hash will contain any global default handlers that the user specifies.

my %_udef = ();
my %pieces = (
	eviled => 2,
	chat_join => 2,
	chat_in => 4,
	chat_update_buddy => -1,
	chat_invite => 4,
	chat_left => 1,
	im_in => 3,
	update_buddy => 6,
	error => 2
);

my %nameSlot = (
	chat_invite => 2,
	im_in => 0,
	eviled => 1,
	chat_in => 1
);

# This sub is the common backend to add_handler and add_global_handler
#
sub _add_generic_handler
{
    my ($self, $event, $ref, $rp, $hash_ref, $real_name) = @_;
    my $ev;
    my %define = ( "replace" => 0, "before" => 1, "after" => 2 );

    unless (@_ >= 3) {
	croak "Not enough arguments to $real_name()";
    }
    unless (ref($ref) eq 'CODE') {
	croak "Second argument of $real_name isn't a coderef";
    }

    # Translate REPLACE, BEFORE and AFTER.
    if (not defined $rp) {
	$rp = 0;
    } elsif ($rp =~ /^\D/) {
	$rp = $define{lc $rp} || 0;
    }

    foreach $ev (ref $event eq "ARRAY" ? @{$event} : $event) {
	# Translate numerics to names
	if ($ev =~ /^\d/) {
	    $ev = Net::AIM::Event->trans($ev);
	    unless ($ev) {
		carp "Unknown event type in $real_name: $ev";
		return;
	    }
	}

	$hash_ref->{lc $ev} = [ $ref, $rp ];
    }
    return 1;
}

# This sub will assign a user's custom function to a particular event which
# might be received by any Connection object.
# Takes 3 args:  the event to modify, as either a string or numeric code
#                   If passed an arrayref, the array is assumed to contain
#                   all event names which you want to set this handler for.
#                a reference to the code to be executed for the event
#    (optional)  A value indicating whether the user's code should replace
#                the built-in handler, or be called with it. Possible values:
#                   0 - Replace the built-in handlers entirely. (the default)
#                   1 - Call this handler right before the default handler.
#                   2 - Call this handler right after the default handler.
# These can also be referred to by the #define-like strings in %define.
sub add_global_handler {
    my ($self, $event, $ref, $rp) = @_;
        return $self->_add_generic_handler($event, $ref, $rp,
					   \%_udef, 'add_global_handler');
}

# This sub will assign a user's custom function to a particular event which
# this connection might receive.  Same args as above.
sub add_handler {
    my ($self, $event, $ref, $rp) = @_;
        return $self->_add_generic_handler($event, $ref, $rp,
					   $self->{_handler}, 'add_handler');
}

# Takes care of the methods in %autoloaded
# Sets specified attribute, or returns its value if called without args.
sub AUTOLOAD {
    my $self = @_;  ## can't modify @_ for goto &name
    my $class = ref $self;  ## die here if !ref($self) ?
    my $meth;

    ($meth = $AUTOLOAD) =~ s/^.*:://;  ## strip fully qualified portion

    unless (exists $autoloaded{$meth}) {
	croak "No method called \"$meth\" for $class object.";
    }
    
    eval <<EOSub;
sub $meth {
    my \$self = shift;
	
    if (\@_) {
	my \$old = \$self->{"_$meth"};
	
	\$self->{"_$meth"} = shift;
	
	return \$old;
    }
    else {
	return \$self->{"_$meth"};
    }
}
EOSub
    
    ## no reason to play this game every time
    goto &$meth;
}


# Attempts to connect to the specified AIM (server, port) with the specified
#   (nick, username, ircname). Will close current connection if already open.
sub connect {
    my $self = shift;
    my ($hostname, $password, $sock);

    if (@_) {
	my (%arg) = @_;

	$hostname = $arg{'LocalAddr'} if exists $arg{'LocalAddr'};
	$password = $arg{'Password'} if exists $arg{'Password'};
	$self->password($arg{'Password'}) if exists $arg{'Password'};
	$self->tocserver($arg{'TocServer'}) if exists $arg{'TocServer'};
	$self->tocport($arg{'TocPort'}) if exists $arg{'Port'};
	$self->authserver($arg{'AuthServer'}) if exists $arg{'AuthServer'};
	$self->authport($arg{'AuthPort'}) if exists $arg{'AuthPort'};
	$self->screenname($arg{'Screenname'}) if exists $arg{'Screenname'};
    }
    
    # Lots of error-checking claptrap first...
    unless ($self->tocserver) {
	$self->tocserver( 'toc.oscar.aol.com' );
    }

    unless ($self->tocport) {
	$self->tocport( 9898 );
    }

    unless ($self->authserver) {
	$self->authserver( 'login.oscar.aol.com' );
    }

    unless ($self->authport) {
	$self->authport( 1234 );
    }

    unless ($self->screenname) {
	$self->screenname("perlaim");
    }
    
    unless ($self->password) {
	croak "No password was specified on connect()";
    }
    
    # Now for the socket stuff...
    if ($self->connected) {
	$self->quit("Changing servers");
    }
    
#    my $sock = IO::Socket::INET->new(PeerAddr => $self->server,
#				     PeerPort => $self->port,
#				     Proto    => "tcp",
#				    );

    $sock = Symbol::gensym();
    unless (socket( $sock, PF_INET, SOCK_STREAM, getprotobyname('tcp') )) {
        carp ("Can't create a new socket: $!");
	$self->error(1);
	return;
    }


    if (connect( $sock, sockaddr_in($self->tocport, inet_aton($self->tocserver)) )) {
	$self->socket($sock);
	
    } else {
	carp (sprintf "Can't connect to %s:%s!",
	      $self->tocserver, $self->tocport);
	$self->error(1);
	return;
    }
    

    # Now, log in to the server...
    my $msg = "FLAPON\r\n\r\n";
    if (!defined(syswrite($self->{_socket}, $msg, length($msg)))) {
	carp "Couldn't send introduction to server: $!";
	$self->error(1);
	$! = "Couldn't send FLAPON introduction to " . $self->server;
	return;
    }
    
    $self->{_connected} = 1;
    $self->parent->addconn($self);
}

sub normalize {
        my $self = shift;
        my $data = shift;

	
	$data =~ s/[^A-Za-z0-9]//g;
	$data =~ tr/A-Z/a-z/;
		
	return $data;

}

sub send_im {
        my $self = shift;
        my $user = shift;
        my $msg = shift;

	$user = $self->normalize($user);
	$msg = $self->encode($msg);

	return $self->send("toc_send_im $user $msg");
}

sub set_idle {
        my $self = shift;
        my $idle = shift;

	return $self->send("toc_set_idle $idle");
}


sub remove_buddy {
        my $self = shift;
        my $group = shift;
        my @rbuddies = @_;
        my @buddies;
	

	my %removehash;
	foreach my $rbud (@rbuddies) {
		$removehash{ $self->normalize($rbud) } = 1;
	}
		
	foreach my $bud  ( @{ $self->{_config}->{$group}->{buddy} } ) {
		push @buddies, $bud if (exists $removehash{ $self->normalize($bud) });
	}

	$self->{_config}->{$group}->{buddy} = @buddies;

	my $budstring = '';
	foreach my $bud (@rbuddies) {
		$budstring .= ' ' . $self->normalize($bud);
	}

	return $self->send("toc_remove_buddy" . $budstring);
}

sub temp {
        my $self = shift;
        my $a = shift;

	return $self->send("toc_ " );
}

sub chat_invite {
        my $self = shift;
        my $room = shift;
        my $msg = shift;
	my @buddies = @_;

	$room = $self->normalize($room);
	$msg = $self->encode($msg);
	
	my $budstr = '';
	foreach my $bud (@buddies) {
		$budstr .= $self->normalize($bud) . ' ';
	}

	return $self->send("toc_chat_invite $room $msg $budstr" );
}

sub get_info {
        my $self = shift;
        my $user = shift;

	$user = $self->normalize($user);
	return $self->send("toc_get_info $user" );
}

sub set_away {
        my $self = shift;
        my $msg = shift;

	return $self->send("toc_set_away") unless($msg);

	$msg = $self->encode($msg);
	return $self->send("toc_set_away $msg" );
}



sub chat_accept {
        my $self = shift;
        my $id = shift;
        my $room = shift;

	$self->{_chat_rooms}->{$id} = $room;

	$room = $self->normalize($room);
	return $self->send("toc_chat_accept $room" );
}


sub chat_left {
        my $self = shift;
        my $id = shift;

	delete $self->{_chat_rooms}->{$id} if (exists $self->{_chat_rooms}->{$id});

	return $self->send("toc_chat_leave $id" );
}

sub chat_leave {
        my $self = shift;
        my $id = shift;

	return $self->send("toc_chat_leave $id" );
}

sub chat_whisper {
        my $self = shift;
        my $room = shift;
        my $user = shift;
        my $msg = shift;

	$room = $self->normalize($room);
	$user = $self->normalize($user);
	$msg = $self->encode($msg);

	return $self->send("toc_chat_whisper $room $user $msg" );
}

sub chat_send {
        my $self = shift;
        my $room = shift;
        my $msg = shift;

	$room = $self->normalize($room);
	$msg = $self->encode($msg);

	return $self->send("toc_chat_send $room $msg" );
}


sub get_roomname {
	my $self = shift;
	my $id = shift;

	return ($self->{_chat_rooms}->{$id});
}

sub chat_joined {
        my $self = shift;
        my $id = shift;
        my $room = shift;

	$self->{_chat_rooms}->{$id} = $room;
}

sub chat_join {
        my $self = shift;
        my $id = shift;
        my $room = shift;

	# I wonder why we don't normalize this also...
	$room = $self->encode($room);
	return $self->send("toc_chat_join 4 $room" );
}

sub evil {
        my $self = shift;
        my $user = shift;
        my $anon = shift;
		
	$user = $self->normalize($user);

	if ($anon) {
		$anon = "anon";
	} else {
		$anon = "norm";
	}

	return $self->send("toc_evil $user $anon" );
}

sub add_buddy {
        my $self = shift;
        my $group = shift;
        my @buddies = @_;
		
	push @{ $self->{_config}->{$group}->{buddy} }, @buddies;

	my $budstring = '';
	foreach my $bud (@buddies) {
		$budstring .= ' ' . $self->normalize($bud);
	}

	return $self->send("toc_add_buddy" . $budstring);
}


sub set_info {
        my $self = shift;
        my $info = shift;

	$info = $self->encode($info);
	return $self->send("toc_set_info $info");
}

sub send {
        my $self = shift;
        my $msg = shift;

        my $data = pack "acnna*c", ('*', 2, $self->{"_outseq"}++, (length($msg) + 1), $msg, 0);

	### DEBUG DEBUG DEBUG
	if ($self->{_debug}) {
		print ">>> $msg\n";
	}
    
        my $rv = syswrite($self->{_socket}, $data, length($data));

	unless ($rv) {
		$self->handler("sockerror");
                carp "syswrite: $!";
		return;
	}

	return $rv;
}


# Returns a boolean value based on the state of the object's socket.
sub connected {
    my $self = shift;
    return ( $self->{_connected} and $self->socket() );
}

# Sets or returns the debugging flag for this object.
# Takes 1 optional arg: a new boolean value for the flag.
sub debug {
    my $self = shift;
    if (@_) {
	$self->{_debug} = $_[0];
    }
    return $self->{_debug};
}


# Standard destructor method for the GC routines. (HAHAHAH! DIE! DIE! DIE!)
sub DESTROY {
    my $self = shift;
    $self->handler("destroy", "nobody will ever use this");
    $self->quit();
    # anything else?
}


# Disconnects this Connection object cleanly from the server.
# Takes at least 1 arg:  the format and args parameters to Event->new().
sub disconnect {
    my $self = shift;
    
    $self->{_connected} = 0;
    $self->parent->removeconn($self);
    $self->socket( undef );
    $self->handler(Net::AIM::Event->new( "disconnect",
					 $self->server,
					 '',
					 @_  ));
}


# Tells AIM.pm if there was an error opening this connection. It's just
# for sane error passing.
# Takes 1 optional arg:  the new value for $self->{'iserror'}
sub error {
    my $self = shift;

    $self->{'iserror'} = $_[0] if @_;
    return $self->{'iserror'};
}

# Lets the user set or retrieve a format for a message of any sort.
# Takes at least 1 arg:  the event whose format you're inquiring about
#           (optional)   the new format to use for this event
sub format {
    my ($self, $ev) = splice @_, 0, 2;
    
    unless ($ev) {
        croak "Not enough arguments to format()";
    }
    
    if (@_) {
        $self->{'_format'}->{$ev} = $_[0];
    } else {
        return ($self->{'_format'}->{$ev} ||
                $self->{'_format'}->{'default'});
    }
}

# Calls the appropriate handler function for a specified event.
# Takes 2 args:  the name of the event to handle
#                the arguments to the handler function
sub handler {
    my ($self, $event) = splice @_, 0, 2;

    unless (defined $event) {
	croak 'Too few arguments to Connection->handler()';
    }
    
    # Get name of event.
    my $ev;
    if (ref $event) {
	$ev = $event->type;
    } elsif (defined $event) {
	$ev = $event;
	$event = Net::AIM::Event->new($event, '', '', '');
    } else {
	croak "Not enough arguments to handler()";
    }
	
    print STDERR "Trying to handle event '$ev'.\n" if $self->{_debug};
    
    my $handler = undef;
    if (exists $self->{_handler}->{$ev}) {
	$handler = $self->{_handler}->{$ev};
    } elsif (exists $_udef{$ev}) {
	$handler = $_udef{$ev};
    } else {
	return $self->_default($event, @_);
    }
    
    my ($code, $rp) = @{$handler};
    
    # If we have args left, try to call the handler.
    if ($rp == 0) {                      # REPLACE
	&$code($self, $event, @_);
    } elsif ($rp == 1) {                 # BEFORE
	&$code($self, $event, @_);
	$self->_default($event, @_);
    } elsif ($rp == 2) {                 # AFTER
	$self->_default($event, @_);
	&$code($self, $event, @_);
    } else {
	confess "Bad parameter passed to handler(): rp=$rp";
    }
	
    warn "Handler for '$ev' called.\n" if $self->{_debug};
    
    return 1;
}

# Gets and/or sets the max line length.  The value previous to the sub
# call will be returned.
# Takes 1 (optional) arg: the maximum line length (in bytes)
sub maxlinelen {
    my $self = shift;

    my $ret = $self->{_maxlinelen};

    $self->{_maxlinelen} = shift if @_;

    return $ret;
}

# Creates a new AIM object and assigns some default attributes.
sub new {
    my $proto = shift;

    # my $class = ref($proto) || $proto;             # Man, am I confused...
    
    my $self = {                # obvious defaults go here, rest are user-set
		_debug      => $_[0]->{_debug},
		_port       => 6667,
		# Evals are for non-UNIX machines, just to make sure.
		_screenname   => "perlaim",
		_password   => '',
		_ignore     => {},
		_config     => {},
		_handler    => {},
		_verbose    =>  0,       # Is this an OK default?
		_outseq     =>  0,
		_inseq      =>  0,
		_chat_rooms =>  {},
		_parent     =>  shift,
		_frag       =>  '',
		_connected  =>  0,
		_maxlinelen =>  2048,     # The RFC says we shouldn't exceed this.
		_format     => {
		    'default' => "[%f:%t]  %m  <%d>",
		},
	      };
    
    bless $self, $proto;
    # do any necessary initialization here
    $self->connect(@_) if @_;
    
    return $self;
}

sub _signOn {
	my $self = shift;
	my $data = shift;

	my $screenname = $self->normalize($self->screenname);
print "Starting SignOn process...\n";
	my $seq = (rand() * 0xffff);
	my $msg = pack "acnnNnna*", ('*', 1, $seq, (8 + length($screenname)), 1, 1, length($screenname), $screenname);
	
	if (!defined(syswrite($self->{_socket}, $msg, length($msg)))) {
                carp "syswrite: $!";
                return 0;
        }

	$self->{"_outseq"} = ++$seq & 0xffff;

	my $pass = $self->encodePass($self->password);
	#TODO fix this...
	my $version = 'TIK:$Revision$';

	$self->send("toc_signon " . $self->authserver . " " .
                $self->authport . " " . $screenname . " " .
                $pass . " english " . $self->encode($version));

	sleep(5);
	$self->send("toc_init_done");

}

sub encode {
        my $self = shift;
        my $str = shift;
        $str =~ s/([\\\}\{\(\)\[\]\$\"])/\\$1/g;
        return ('"' . $str . '"');
}

sub encodePass {
   my $self = shift;
   my $password = shift;

   my @table = unpack "c*" , 'Tic/Toc';
   my @pass = unpack "c*", $password;

   my $encpass = '0x';
   foreach my $c (0 .. $#pass) {
            $encpass.= sprintf "%02x", $pass[$c] ^ $table[ ( $c % 7) ];
   }

   return $encpass;
}

sub send_config {
	my $self = shift;

	my $configstr = 'm ';
	if ( defined $self->{_config} &&
		exists $self->{_config}->{mode} &&
		$self->{_config}->{mode} =~ /^\d$/ ) {
		$configstr .= $self->{_config}->{mode};
	} else {
		$configstr .= '1';
	}
	
	$configstr .= "\n";
	foreach my $group ( keys %{ $self->{_config} } ) {
		next if ($group eq 'mode');  # we did this already

		$configstr .= "g $group\n";
		foreach my $grouptype (qw/buddy permit deny/) {
			my $char = substr($grouptype,0,1);
		if (exists $self->{_config}->{$group}->{$grouptype}) {
		foreach my $item ( @{ $self->{_config}->{$group}->{$grouptype} }  ) {
			$configstr .= "$char " . $self->normalize($item) . "\n";
		}
		}
		}
	}

#	$self->send("toc_set_config $configstr\n");
	print "toc_set_config $configstr\n" ;

}

sub add_config_buddies {
	my $self = shift;

	my $configstr='';

	foreach my $group ( keys %{ $self->{_config} } ) {
		next if ($group eq 'mode');  # we did this already

		if (exists $self->{_config}->{$group}->{buddy}) {
		foreach my $item ( @{ $self->{_config}->{$group}->{buddy} }  ) {
			$configstr .= $self->normalize($item) . " ";
		}
		}
	}

	$self->send("toc_add_buddy $configstr");

#####

}

sub set_config {
	my $self = shift;
	my $str = shift;
	my $add = shift;
	my $group = undef;

	$self->{_config} = {} unless($add);

	foreach (split(/\n/, $str))  {
		my ($char, $item);

		($char, $item) = split(/\s/, $_, 2);
		if ($char eq 'm') {
			$self->{_config}->{mode} = $item; 
		} elsif ($char eq 'g') {
			$group = $item;
		} elsif ($char eq 'p') {
			push @{ $self->{_config}->{$group}->{permit} }, $item;
		} elsif ($char eq 'd') {
			push @{ $self->{_config}->{$group}->{deny} }, $item;
		} elsif ($char eq 'b') {
			push @{ $self->{_config}->{$group}->{buddy} }, $item;
		}

	}

}

sub parse {
    my ($self) = shift;
    my ($from, $type, $seq, @stuff, $to, $cmd, $ev, $marker,
	$len, $header, $line, $data, $arg);
    
#print STDERR "In parse routine..\n";
    if (defined recv($self->socket, $header, 6, 0) and
		length($header) > 0)  {

		($marker, $type, $seq, $len) = unpack "acnn", $header;
	
    } else {	
	# um, if we can read, i say we should read more than 0
	# besides, recv isn't returning undef on closed
	# sockets.  getting rid of this connection...
	$self->disconnect('error', 'Connection reset by peer');
	return;
    }

	$seq &= 0x0000ffff;
	my $inseq = ($self->{"_inseq"} + 1) & 0x0000ffff;
	$self->{"_inseq"} = $seq;

        unless (recv($self->socket, $data, $len, 0)) {
#print STDERR "Socket received no data!...\n" if ($debug > 0);
                return undef;
        }

	if ($type == 1) {
		$self->_signOn($data);
		return;
	}

	print STDERR "<<< $data\n" if $self->{_debug};

	return if ($data !~ /\w/);
	
	($cmd, $arg) = split(/:/, $data, 2);
	$cmd =~ tr/A-Z/a-z/;
	$from = $self->tocserver;
	$to = $self->screenname;

	if (exists $pieces{$cmd}) {
		@stuff = split(/:/, $arg, $pieces{$cmd});

		$from = $stuff[$nameSlot{$cmd}] if (exists $nameSlot{$cmd});
		$to = $stuff[0] if ($cmd eq 'chat_in');

		$ev = (Net::AIM::Event->new( $cmd,	
					$from, 
					$to,
					$cmd,
					@stuff));
	} else {
		$ev = (Net::AIM::Event->new( $cmd,	
					$from, 
					$to,
					$cmd,
					$arg));
	}


	if ($ev) {

            # We need to be able to fall through if the handler has
            # already been called (i.e., from within disconnect()).

            $self->handler($ev) unless $ev eq 'done';

        } else {
            # If it gets down to here, it's some exception I forgot about.
            carp "Funky parse case: $line\n";
        }

}

# This function splits apart a raw server line into its component parts
# (message, target, message type, CTCP data, etc...) and passes it to the
# appropriate handler. Takes no args, really.
sub old_parse {
    my ($self) = shift;
    my ($from, $type, $message, @stuff, $itype, $ev, @lines, $line);
    
    if (defined recv($self->socket, $line, 10240, 0) and
		(length($self->{_frag}) + length($line)) > 0)  {
	# grab any remnant from the last go and split into lines
	my $chunk = $self->{_frag} . $line;
	@lines = split /\012/, $chunk;
	
	# if the last line was incomplete, pop it off the chunk and
	# stick it back into the frag holder.
	$self->{_frag} = (substr($chunk, -1) ne "\012" ? pop @lines : '');
	
    } else {	
	# um, if we can read, i say we should read more than 0
	# besides, recv isn't returning undef on closed
	# sockets.  getting rid of this connection...
	$self->disconnect('error', 'Connection reset by peer');
	return;
    }
    
    foreach $line (@lines) {
		
	# Clean the lint filter every 2 weeks...
	$line =~ s/[\012\015]+$//;
	next unless $line;
	
	print STDERR "<<< $line\n" if $self->{_debug};
	
	# Like the RFC says: "respond as quickly as possible..."
	if ($line =~ /^PING/) {
	    $ev = (Net::AIM::Event->new( "ping",
					 $self->server,
					 $self->nick,
					 "serverping",   # FIXME?
					 substr($line, 5)
					 ));
	    
	    # Had to move this up front to avoid a particularly pernicious bug.
	} elsif ($line =~ /^NOTICE/) {
	    $ev = Net::AIM::Event->new( "snotice",
					$self->server,
					'',
					'server',
					(split /:/, $line, 2)[1] );
	    
	    
	    # Spurious backslashes are for the benefit of cperl-mode.
	    # Assumption:  all non-numeric message types begin with a letter
	} elsif ($line =~ /^:?
		 ([][}{\w\\\`^|\-]+?      # The nick (valid nickname chars)
		  !                       # The nick-username separator
		  .+?                     # The username
		  \@)?                    # Umm, duh...
		 \S+                      # The hostname
		 \s+                      # Space between mask and message type
		 [A-Za-z]                 # First char of message type
		 [^\s:]+?                 # The rest of the message type
		 /x)                      # That ought to do it for now...
	{
	    $line = substr $line, 1 if $line =~ /^:/;
	    ($from, $line) = split ":", $line, 2;
	    ($from, $type, @stuff) = split /\s+/, $from;
	    $type = lc $type;
	    
	    # This should be fairly intuitive... (cperl-mode sucks, though)
	    if (defined $line and index($line, "\001") >= 0) {
		$itype = "ctcp";
		unless ($type eq "notice") {
		    $type = (($stuff[0] =~ tr/\#\&//) ? "public" : "msg");
		}
	    } elsif ($type eq "privmsg") {
		$itype = $type = (($stuff[0] =~ tr/\#\&//) ? "public" : "msg");
	    } elsif ($type eq "notice") {
		$itype = "notice";
	    } elsif ($type eq "join" or $type eq "part" or
		     $type eq "mode" or $type eq "topic" or
		     $type eq "kick") {
		$itype = "channel";
	    } elsif ($type eq "nick") {
		$itype = "nick";
	    } else {
		$itype = "other";
	    }
	    
	    # This goes through the list of ignored addresses for this message
	    # type and drops out of the sub if it's from an ignored hostmask.
	    
	    study $from;
	    foreach ( $self->ignore($itype), $self->ignore("all") ) {
		$_ = quotemeta; s/\\\*/.*/g;
		return 1 if $from =~ /$_/;
	    }
	    
	    # It used to look a lot worse. Here was the original version...
	    # the optimization above was proposed by Silmaril, for which I am
	    # eternally grateful. (Mine still looks cooler, though. :)
	    
	    # return if grep { $_ = join('.*', split(/\\\*/,
	    #                  quotemeta($_)));  /$from/ }
	    # ($self->ignore($type), $self->ignore("all"));
	    
	    # Add $line to @stuff for the handlers
	    push @stuff, $line if defined $line;
	    
	    # Now ship it off to the appropriate handler and forget about it.
	    if ( $itype eq "ctcp" ) {       # it's got CTCP in it!
		$self->parse_ctcp($type, $from, $stuff[0], $line);
		return 1;
		
	    }  elsif ($type eq "public" or $type eq "msg"   or
		      $type eq "notice" or $type eq "mode"  or
		      $type eq "join"   or $type eq "part"  or
		      $type eq "topic"  or $type eq "invite" ) {
		
		$ev = Net::AIM::Event->new( $type,
					    $from,
					    shift(@stuff),
					    $type,
					    @stuff,
					    );
	    } elsif ($type eq "quit" or $type eq "nick") {
		
		$ev = Net::AIM::Event->new( $type,
					    $from,
					    $from,
					    $type,
					    @stuff,
					    );
	    } elsif ($type eq "kick") {
		
		$ev = Net::AIM::Event->new( $type,
					    $from,
					    $stuff[1],
					    $type,
					    @stuff[0,2..$#stuff],
					    );
		
	    } elsif ($type eq "kill") {
		$ev = Net::AIM::Event->new($type,
					   $from,
					   '',
					   $type,
					   $line);   # Ahh, what the hell.
	    } elsif ($type eq "wallops") {
		$ev = Net::AIM::Event->new($type,
					   $from,
					   '',
					   $type,
					   $line);  
	    } else {
	       carp "Unknown event type: $type";
	    }
	}

	elsif ($line =~ /^:?       # Here's Ye Olde Numeric Handler!
	       \S+?                 # the servername (can't assume RFC hostname)
	       \s+?                # Some spaces here...
	       \d+?                # The actual number
	       \b/x                # Some other crap, whatever...
	       ) {
	    $ev = $self->parse_num($line);

	} elsif ($line =~ /^:(\w+) MODE \1 /) {
	    $ev = Net::AIM::Event->new( 'umode',
					$self->server,
					$self->nick,
					'server',
					substr($line, index($line, ':', 1) + 1));

    } elsif ($line =~ /^:?       # Here's Ye Olde Server Notice handler!
	         .+?                 # the servername (can't assume RFC hostname)
	         \s+?                # Some spaces here...
	         NOTICE              # The server notice
	         \b/x                # Some other crap, whatever...
	        ) {
	$ev = Net::AIM::Event->new( 'snotice',
				    $self->server,
				    '',
				    'server',
				    (split /\s+/, $line, 3)[2] );
	
	
    } elsif ($line =~ /^ERROR/) {
	if ($line =~ /^ERROR :Closing [Ll]ink/) {   # is this compatible?
	    
	    $ev = 'done';
	    $self->disconnect( 'error', ($line =~ /(.*)/) );
	    
	} else {
	    $ev = Net::AIM::Event->new( "error",
					$self->server,
					'',
					'error',
					(split /:/, $line, 2)[1]);
	}
    } elsif ($line =~ /^Closing [Ll]ink/) {
	$ev = 'done';
	$self->disconnect( 'error', ($line =~ /(.*)/) );
	
    }
	
	if ($ev) {
	    
	    # We need to be able to fall through if the handler has
	    # already been called (i.e., from within disconnect()).
	    
	    $self->handler($ev) unless $ev eq 'done';
	    
	} else {
	    # If it gets down to here, it's some exception I forgot about.
	    carp "Funky parse case: $line\n";
	}
    }
}

# Tells what's on the other end of a connection. Returns a 2-element list
# consisting of the name on the other end and the type of connection.
# Takes no args.
sub peer {
    my $self = shift;

    return ($self->server(), "AIM connection");
}

# Prints a message to the defined error filehandle(s).
# No further description should be necessary.
sub printerr {
    shift;
    print STDERR @_, "\n";
}

# Prints a message to the defined output filehandle(s).
sub print {
    shift;
    print STDOUT @_, "\n";
}

# Closes connection to AIM server.  (Corresponding function for /QUIT)
# Takes 1 optional arg:  parting message, defaults to "Leaving" by custom.
sub quit {
    my $self = shift;

    # Do any user-defined stuff before leaving
    $self->handler("leaving");

    unless ( $self->connected ) {  return (1)  }
    
    # Why bother checking for sl() errors now, after all?  :)
    # We just send the QUIT command and leave. The server will respond with
    # a "Closing link" message, and parse() will catch it, close the
    # connection, and throw a "disconnect" event. Neat, huh? :-)
    
    return 1;
}


# Schedules an event to be executed after some length of time.
# Takes at least 2 args:  the number of seconds to wait until it's executed
#                         a coderef to execute when time's up
# Any extra args are passed as arguments to the user's coderef.
sub schedule {
    my ($self, $time, $code) = splice @_, 0, 3;

    unless ($code) {
	croak 'Not enough arguments to Connection->schedule()';
    }
    unless (ref $code eq 'CODE') {
	croak 'Second argument to schedule() isn\'t a coderef';
    }

    $time = time + int $time;
    $self->parent->queue($time, $code, $self, @_);
}


# Sets/changes the AIM server which this instance should connect to.
# Takes 1 arg:  the name of the server (see below for possible syntaxes)
#                                       ((syntaxen? syntaxi? syntaces?))
sub server {
    my ($self) = shift;
    
    if (@_)  {
	# cases like "irc.server.com:6668"
	if (index($_[0], ':') > 0) {
	    my ($serv, $port) = split /:/, $_[0];
	    if ($port =~ /\D/) {
		carp "$port is not a valid port number in server()";
		return;
	    }
	    $self->{_server} = $serv;
	    $self->port($port);

        # cases like ":6668"  (buried treasure!)
	} elsif (index($_[0], ':') == 0 and $_[0] =~ /^:(\d+)/) {
	    $self->port($1);

	# cases like "irc.server.com"
	} else {
	    $self->{_server} = shift;
	}
	return (1);

    } else {
	return $self->{_server};
    }
}


# Sends a raw AIM line to the server.
# Corresponds to the internal sirc function of the same name.
# Takes 1 arg:  string to send to server. (duh. :)
sub sl {
    my $self = shift;
    my $line = CORE::join '', @_;
	
    unless (@_) {
	croak "Not enough arguments to sl()";
    }
    
    ### DEBUG DEBUG DEBUG
    if ($self->{_debug}) {
	print ">>> $line\n";
    }
    
    # RFC compliance can be kinda nice...
    my $rv = &send( $self->{_socket}, "$line\015\012", 0 );
    unless ($rv) {
	$self->handler("sockerror");
	return;
    }
    return $rv;
}

# handlers. It's all in one sub so that we don't have to make a bunch of
# separate anonymous subs stuffed in a hash.
sub _default {
    my ($self, $event) = @_;
    my $verbose = $self->verbose;

    # Users should only see this if the programmer (me) fucked up.
    unless ($event) {
	croak "You EEEEEDIOT!!! Not enough args to _default()!";
    }

    if ($event->type eq "disconnect") {

	# I violate OO tenets. (It's consensual, of course.)
	unless (keys %{$self->parent->{_connhash}} > 0) {
	    die "No active connections left, exiting...\n";
	}
    }

    return 1;
}

1;
__END__

=head1 NAME

Net::AIM::Connection - Stolen Object-oriented interface to a single AIM connection

=head1 SYNOPSIS

=head1 DESCRIPTION

Basically this module handles the connection and communications between us
and the server.  It parses the incoming data and queues it.  It follows the 
defined protocol and contains methods to send out our information and messages. 

=head1 AUTHORS

Shreded by Aryeh Goldsmith E<lt>aryeh@ironarmadillo.comE<gt>.

Conceived and initially developed by Greg Bacon E<lt>gbacon@adtran.comE<gt> and
Dennis Taylor E<lt>dennis@funkplanet.comE<gt>.

Ideas and large amounts of code donated by Nat "King" Torkington E<lt>gnat@frii.comE<gt>.

Net::IRC developers mailing list:
	http://www.execpc.com/~corbeau/irc/list.html .

=head1 URL

Up-to-date source and information about the Net::IRC project can be found at
http://netirc.betterbox.net/ .

Up-to-date source and information about the Net::AIM project can be found at
http://projects.aryeh.net/Net-AIM/ .

=head1 SEE ALSO

perl(1), Net::IRC.


=cut

