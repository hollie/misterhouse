package Net::AIM::Event;

use strict;
my %_names;

# Sets or returns an argument list for this event.
# Takes any number of args:  the arguments for the event.
sub args {
    my $self = shift;

    if (@_) {
		my (@q, $i) = @_;       # This line is solemnly dedicated to \mjd.

		$self->{'args'} = [ ];
		while (@q) {
		    $i = shift @q;
		    next unless defined $i;

		    if ($i =~ /^:/) {                        # Concatenate :-args.
				$i = join ' ', (substr($i, 1), @q);
				push @{$self->{'args'}}, $i;
				last;
		    }
		    push @{$self->{'args'}}, $i;
		}
    }

    return @{$self->{'args'}};
}

# Dumps the contents of an event to STDERR so you can see what's inside.
# Takes no args.
sub dump {
    my ($self, $arg, $counter) = (shift, undef, 0);   # heh heh!

    printf STDERR "TYPE: %-30s    FORMAT: %-30s\n",
        $self->{'type'}, $self->{'format'};
    print STDERR "FROM: ", $self->{'from'}, "\n";
    print STDERR "TO: ", join(", ", @{$self->{'to'}}), "\n";
    foreach $arg (@{$self->{'args'}}) {
		print "Arg ", $counter++, ": ", $arg, "\n";
    }
}


# Sets or returns the format string for this event.
# Takes 1 optional arg:  the new value for this event's "format" field.
sub format {
    my $self = shift;

    $self->{'format'} = $_[0] if @_;
    return $self->{'format'};
}

# Sets or returns the originator of this event
# Takes 1 optional arg:  the new value for this event's "from" field.
sub from {
    my $self = shift;
    my @part;
    
    if (@_) {
	# avoid certain irritating and spurious warnings from this line...
	{ local $^W;
	  @part = split /[\@!]/, $_[0], 3;
        }
	
	$self->nick(defined $part[0] ? $part[0] : '');
	$self->user(defined $part[1] ? $part[1] : '');
	$self->host(defined $part[2] ? $part[2] : '');
	defined $self->user ?
	    $self->userhost($self->user . '@' . $self->host) :
	    $self->userhost($self->host);
	$self->{'from'} = $_[0];
    }
    return $self->{'from'};
}

# -- #perl was here! --
#    <\mjd>  So, I just heard that some people use their dolls to act out
#            their childhood traumas.
#   <jjohn>  \mjd, I've heard of that.
# <Abigail>  I do that too. Every night before I go to sleep, I whip my dolls.
#    <\mjd>  Yesterday Lorrie and I had one of our plush octopuses make us
#            promise that we would never take it to Syms. 


# Sets or returns the hostname of this event's initiator
# Takes 1 optional arg:  the new value for this event's "host" field.
sub host {
    my $self = shift;

    $self->{'host'} = $_[0] if @_;
    return $self->{'host'};
}

# Constructor method for Net::AIM::Event objects.
# Takes at least 4 args:  the type of event
#                         the person or server that initiated the event
#                         the recipient(s) of the event, as arrayref or scalar
#                         the name of the format string for the event
#            (optional)   any number of arguments provided by the event
sub new {
    my $class = shift;

    # -- #perl was here! --
    #   \mjd: Under the spreading foreach loop, the lexical variable stands.
    #   \mjd: The my is a mighty keyword, with abcessed anal glands.
    #   \mjd: Apologies to Mr. Longfellow.


    my $self = { 'type'   =>  $_[0],
		 'from'   =>  $_[1],
		 'to'     =>  ref($_[2]) eq 'ARRAY'  ?  $_[2]  :  [ $_[2] ],
		 'format' =>  $_[3],
		 'args'   =>  [ @_[4..$#_] ],
	       };
    
    bless $self, $class;
    
    # Take your encapsulation and shove it!
    if ($self->{'type'} !~ /\D/) {
		$self->{'type'} = $self->trans($self->{'type'});
    } else {
		$self->{'type'} = lc $self->{'type'};
    }

    #  ChipDude: "Beware the method call, my son!  The subs that grab, the
    #             args that shift!"
    #      \mjd: That's pretty good.

    $self->from($self->{'from'});     # sets nick, user, and host
    $self->args(@{$self->{'args'}});  # strips colons from args
    
    return $self;
}

# Sets or returns the nick of this event's initiator
# Takes 1 optional arg:  the new value for this event's "nick" field.
sub nick {
    my $self = shift;

    $self->{'nick'} = $_[0] if @_;
    return $self->{'nick'};
}

# Sets or returns the recipient list for this event
# Takes any number of args:  this event's list of recipients.
sub to {
    my $self = shift;
    
    $self->{'to'} = [ @_ ] if @_;
    return wantarray ? @{$self->{'to'}} : $self->{'to'};
}

# Simple sub for translating server numerics to their appropriate names.
# Takes one arg:  the number to be translated.
sub trans {
    shift if (ref($_[0]) || $_[0]) =~ /^Net::AIM/;
    my $ev = shift;
    
    return (exists $_names{$ev} ? $_names{$ev} : undef);
}

# Sets or returns the type of this event
# Takes 1 optional arg:  the new value for this event's "type" field.
sub type {
    my $self = shift;
    
    $self->{'type'} = $_[0] if @_;
    return $self->{'type'};
}

# Sets or returns the username of this event's initiator
# Takes 1 optional arg:  the new value for this event's "user" field.
sub user {
    my $self = shift;

    $self->{'user'} = $_[0] if @_;
    return $self->{'user'};
}



# Just $self->user plus '@' plus $self->host, for convenience.
sub userhost {
    my $self = shift;
    
    $self->{'userhost'} = $_[0] if @_;
    return $self->{'userhost'};
}



%_names = (
	   # suck!  these aren't treated as strings --
	   # 001 ne 1 for the purpose of hash keying, apparently.
	   '001' => "welcome",
	   '002' => "yourhost",
	   '003' => "created",
	   '004' => "myinfo",
	   '005' => "map", 		# Undernet Extension, Kajetan@Hinner.com, 17/11/98
	   '006' => "mapmore", 		# Undernet Extension, Kajetan@Hinner.com, 17/11/98
	   '007' => "mapend", 		# Undernet Extension, Kajetan@Hinner.com, 17/11/98	   	   
	   '008' => "snomask", 		# Undernet Extension, Kajetan@Hinner.com, 17/11/98	   
	   '009' => "statmemtot", 	# Undernet Extension, Kajetan@Hinner.com, 17/11/98	   
	   '010' => "statmem", 		# Undernet Extension, Kajetan@Hinner.com, 17/11/98	   

	   200 => "tracelink",
	   201 => "traceconnecting",
	   202 => "tracehandshake",
	   203 => "traceunknown",
	   204 => "traceoperator",
	   205 => "traceuser",
	   206 => "traceserver",
	   208 => "tracenewtype",
	   209 => "traceclass",
	   211 => "statslinkinfo",
	   212 => "statscommands",
	   213 => "statscline",
	   214 => "statsnline",
	   215 => "statsiline",
	   216 => "statskline",
	   217 => "statsqline",
	   218 => "statsyline",
	   219 => "endofstats",
	   221 => "umodeis",
	   231 => "serviceinfo",
	   232 => "endofservices",
	   233 => "service",
	   234 => "servlist",
	   235 => "servlistend",
	   241 => "statslline",
	   242 => "statsuptime",
	   243 => "statsoline",
	   244 => "statshline",
	   245 => "statssline",		# Reserved, Kajetan@Hinner.com, 17/10/98
	   246 => "statstline",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   247 => "statsgline",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   248 => "statsuline",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   249 => "statsdebug",		# Unspecific Extension, Kajetan@Hinner.com, 17/10/98
	   250 => "statsconn",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   
	  

	   250 => "luserconns",   # 1998-03-15 -- tkil
	   251 => "luserclient",
	   252 => "luserop",
	   253 => "luserunknown",
	   254 => "luserchannels",
	   255 => "luserme",
	   256 => "adminme",
	   257 => "adminloc1",
	   258 => "adminloc2",
	   259 => "adminemail",
	   261 => "tracelog",
	   262 => "endoftrace",  # 1997-11-24 -- archon
	   265 => "n_local",     # 1997-10-16 -- tkil
	   266 => "n_global",    # 1997-10-16 -- tkil
	   271 => "silelist",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   272 => "endofsilelist",	# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   275 => "statsdline",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   280 => "glist",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   281 => "endofglist",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98

	   
	   300 => "none",
	   301 => "away",
	   302 => "userhost",
	   303 => "ison",
	   305 => "unaway",
	   306 => "nowaway",
	   307 => "userip",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   311 => "whoisuser",
	   312 => "whoisserver",
	   313 => "whoisoperator",
	   314 => "whowasuser",
	   315 => "endofwho",
	   316 => "whoischanop",
	   317 => "whoisidle",
	   318 => "endofwhois",
	   319 => "whoischannels",
	   321 => "liststart",
	   322 => "list",
	   323 => "listend",
	   324 => "channelmodeis",
	   329 => "channelcreate",  # 1997-11-24 -- archon
	   331 => "notopic",
	   332 => "topic",
	   333 => "topicinfo",      # 1997-11-24 -- archon
	   334 => "listusage",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   341 => "inviting",
	   342 => "summoning",
	   351 => "version",
	   352 => "whoreply",
	   353 => "namreply",
	   354 => "whospcrpl",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   361 => "killdone",
	   362 => "closing",
	   363 => "closeend",
	   364 => "links",
	   365 => "endoflinks",
	   366 => "endofnames",
	   367 => "banlist",
	   368 => "endofbanlist",
	   369 => "endofwhowas",
	   371 => "info",
	   372 => "motd",
	   373 => "infostart",
	   374 => "endofinfo",
	   375 => "motdstart",
	   376 => "endofmotd",
	   377 => "motd2",        # 1997-10-16 -- tkil
	   381 => "youreoper",
	   382 => "rehashing",
	   384 => "myportis",
	   385 => "notoperanymore",	# Unspecific Extension, Kajetan@Hinner.com, 17/10/98
	   391 => "time",
	   392 => "usersstart",
	   393 => "users",
	   394 => "endofusers",
	   395 => "nousers",
	   
	   401 => "nosuchnick",
	   402 => "nosuchserver",
	   403 => "nosuchchannel",
	   404 => "cannotsendtochan",
	   405 => "toomanychannels",
	   406 => "wasnosuchnick",
	   407 => "toomanytargets",
	   409 => "noorigin",
	   411 => "norecipient",
	   412 => "notexttosend",
	   413 => "notoplevel",
	   414 => "wildtoplevel",
	   416 => "querytoolong",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   421 => "unknowncommand",
	   422 => "nomotd",
	   423 => "noadmininfo",
	   424 => "fileerror",
	   431 => "nonicknamegiven",
	   432 => "erroneusnickname",   # This iz how its speld in thee RFC.
	   433 => "nicknameinuse",
	   436 => "nickcollision",
	   437 => "bannickchange",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   438 => "nicktoofast",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   439 => "targettoofast",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98

	   441 => "usernotinchannel",
	   442 => "notonchannel",
	   443 => "useronchannel",
	   444 => "nologin",
	   445 => "summondisabled",
	   446 => "usersdisabled",
	   451 => "notregistered",
	   461 => "needmoreparams",
	   462 => "alreadyregistered",
	   463 => "nopermforhost",
	   464 => "passwdmismatch",
	   465 => "yourebannedcreep", # I love this one...
	   466 => "youwillbebanned",
	   467 => "keyset",
	   468 => "invalidusername",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   471 => "channelisfull",
	   472 => "unknownmode",
	   473 => "inviteonlychan",
	   474 => "bannedfromchan",
	   475 => "badchannelkey",
	   476 => "badchanmask",
	   478 => "banlistfull",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   481 => "noprivileges",
	   482 => "chanoprivsneeded",
	   483 => "cantkillserver",
	   484 => "ischanservice",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   491 => "nooperhost",
	   492 => "noservicehost",
	   
	   501 => "umodeunknownflag",
	   502 => "usersdontmatch",

	   511 => "silelistfull",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   513 => "nosuchgline",		# Undernet Extension, Kajetan@Hinner.com, 17/10/98
	   513 => "badping",			# Undernet Extension, Kajetan@Hinner.com, 17/10/98

# AIM ERRORS
   901   => '$0 not currently available',
   902   => 'Warning of $0 not currently available',
   903   => 'A message has been dropped, you are exceeding the server speed limit',
#   * Chat Errors  *',
   950   => 'Chat in $0 is unavailable.',

#   * IM & Info Errors *',
   960   => 'You are sending message too fast to $0',
   961   => 'You missed an im from $0 because it was too big.',
   962   => 'You missed an im from $0 because it was sent too fast.',

#   * Dir Errors *',
   970   => 'Failure',
   971   => 'Too many matches',
   972   => 'Need more qualifiers',
   973   => 'Dir service temporarily unavailable',
   974   => 'Email lookup restricted',
   975   => 'Keyword Ignored',
   976   => 'No Keywords',
   977   => 'Language not supported',
   978   => 'Country not supported',
   979   => 'Failure unknown $0',

#  * Auth errors *',
   980   => 'Incorrect nickname or password.',
   981   => 'The service is temporarily unavailable.',
   982   => 'Your warning level is currently too high to sign on.',
   983   => 'You have been connecting and disconnecting too frequently.  Wait 10 minutes and try again.  If you continue to try, you will need to wait even longer.',
   989   => 'An unknown signon error has occurred $0'


	  );

1;
