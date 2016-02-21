# Category=Internet
#
################################################################################
#@ This is an Internet Relay Chat module for MrHouse.
#@
#@ It allows MrHouse to talk to multiple channels and multiple users on
#@ multiple IRC servers.
#
#  Author:
#      Ant Skelton <antATantDOTorg>
#  Latest version:
#      http://misterhouse.net
#
#  Change log:
#    - 21/01/04  Created
#    - 05/08/04  Resumed, tidied up, released.
#
#  This free software is licensed under the terms of the GNU public license.
#  Copyright 2004 Ant Skelton
#
# FLOODING
#
# Note that IRC servers have "antiflood" mechanisms in place: send too
# much information too quickly and the server will boot you off. Note
# also that flood control operates per server: it's the accumulation of data
# sent to all channels and all users on that server.
#
# This module does its best to avoid flooding (see config section below) but
# this results in a perceived slow data rate at the server: commands which generate
# a lot of output therefore will take a significant amount of time to send all their
# output to IRC, especially if you're sending it to multiple sources on the same IRC server.
# Output is buffered, so MrHouse is able to do other stuff while this is happening.
# At some point in the future I hope to support DCC connections to ameliorate this
# problem.
#
# COMMANDS
#
# These are the commands which the IRC module recognises in addition to the
# regular process_external_command() stuff:
#
# login <passwd>
# logon <passwd>
# Authenticate with MrHouse - uses the standard MH password mechanism
# MrHouse will ignore you completely until you have logged in.
#
# log <loglevel> [ eg log all ]
# publog <channel> <loglevel> [ eg publog #ant all ]
# Set the privmsg (log) or channel (publog) log level: see caveat above
#
# join <channel> [ eg join #foo ]
# join a channel. MrHouse will also respond to /invite
#
# part <channel> [ eg part #foo ]
# leave a channel
#
# links
# show MrHouse IRC connection information
#
# list
# list voice commands in a more irc friendly format (less redundant stuff)
#
# find <string>
# find cmds matching string
#
# You can do all the usual stuff like execute voice commands, set, speak etc
#
# CONFIG LINES
#
# You need to add some config lines to your mh.ini to configure MrHouse for IRC
#
# irc_autoconnect = true
# include this if you want MrHouse to connect automatically
#
# irc_parting = some message
# MrHouse's channel parting message
#
# irc_accept_invites = yes
# Include this if you want MrHouse to join a channel in response to an invite
#
# irc_connection1=ircserver:port:nick:comma-sep-list-of-channels-to-join:IRCname:username[:password]
# connection parameters for first connection, e.g.:
# irc_connection1=irc.nixhelp.org:6667:MrHouse:#ant,#ant2:MisterHouse:MisterHouse:
# you can specify additional connections with irc_connection2, irc_connection3 etc
#
# irc_auth1=from-regex:mh-username
# eg irc_auth1=.*:ant
#
# used to process logon requests: the from-regex is a perl regular expression which
# must match the user's hostmask. The mh-username is the user in the MH auth file whose
# password we should attempt to match.
# specify auths for additional connections with irc_auth2, irc_auth3 etc
#
# irc_buffer1=maxbytes:linelength:window
# eg irc_buffer1=2560:511:10
#
# Specify custom flood-prevention rate-control settings on a per connection basis.
# You shouldn't need to do this, as the algorithm was carefully tuned against a
# particularly strict hybrid6 ircd server, however if you do experiment, 'maxbytes'
# is the size of the ircd's client connection buffer, 'linelength' is the longest
# whole line to send to the server, and 'window' is the penalty threshold above which
# MH will not send data. See the rate pacing source at the end of the module for
# additional insight. Note that the penalty formula is pretty ircd specific, but if
# it's good enough for hybrid6, it should be good enough for you!
#
# DEBUG
# You can set the "irc" debug flag to see what's going on if you're having probs.
################################################################################
use Net::IRC;

################################################################################
# Variables local to this code member
#    (will be local to our loop_code subroutine after mh compilation)
#    indentation prevents mh from making these mh-global
################################################################################

################################################################################
# Variables global to all code members
################################################################################
my $irc     = new Net::IRC;
my $irc_ops = $irc->newconn();
my %irc_data;
my $irc_handle   = 0;
my $irc_quit_msg = "tramates!";

################################################################################
# Voice cmds controlling IRC behaviour
################################################################################
$v_irc_signon = new Voice_Cmd 'Connect to irc';
$v_irc_signon->set_info('(re)connect to IRC network');

$v_irc_signoff = new Voice_Cmd 'Disconnect from irc';
$v_irc_signoff->set_info('Disconnect from the IRC network');

################################################################################
# Startup / Reload behaviour
################################################################################
if ($Startup) {

    #$irc = new Net::IRC;
    #$irc_ops = $irc->newconn(); # unconnected container for irc global handlers
    $irc->timeout(0);

    # add irc handlers
    $irc_ops->add_global_handler( 'msg',    \&irc_on_msg );
    $irc_ops->add_global_handler( 'public', \&irc_on_public );
    $irc_ops->add_global_handler( 'join',   \&irc_on_join );
    $irc_ops->add_global_handler( 'part',   \&irc_on_part );
    $irc_ops->add_global_handler( 'quit',   \&irc_on_part );
    $irc_ops->add_global_handler( [ 251, 252, 253, 254, 302, 255 ],
        \&irc_on_init );
    $irc_ops->add_global_handler( 'disconnect', \&irc_on_disconnect );
    $irc_ops->add_global_handler( 376,          \&irc_on_connect );
    $irc_ops->add_global_handler( 433,          \&irc_on_nick_taken );
    $irc_ops->add_global_handler( 'invite',     \&irc_on_invite );

}

if ($Reload) {

    # boot off any existing connections
    irc_disconnect();

    # destroy all preexisting data
    delete $irc_data{connections};

    # find our config file lines
    {
        my ( $ref, $cline, $aline, $bline, $handle );
        foreach $cline ( grep /irc_connection\d+$/, keys(%config_parms) ) {
            $cline =~ /irc_connection(\d+)/;
            $handle = $1;
            print "CLINE $handle: $cline\n" if $main::Debug{irc};
            my ( $server, $port, $nick, $channels, $irc_name, $user_name,
                $passwd );
            if ( $config_parms{$cline} =~
                /(\S+):(\d*):(\S+):(\S+):(\S+):(\S+):(\S*)/ )
            {
                (
                    $server, $port, $nick, $channels, $irc_name, $user_name,
                    $passwd
                ) = ( $1, $2, $3, $4, $5, $6, $7 );
                $irc_data{connections}{$handle}{server} = $server;
                $ref         = $irc_data{connections}{$handle};
                $ref->{port} = $port;
                $ref->{nick} = $nick;
                foreach ( split( /,/, $channels ) ) {
                    print "CHANNEL: $_\n";
                    $ref->{channels}{$_}{start} = 1;
                }
                $ref->{ircname}  = $irc_name;
                $ref->{username} = $user_name;
                $ref->{passwd}   = $passwd;

                # some defaults, overridden by specific conf lines ff
                $ref->{auths} = '.*';    # no auth
                $ref->{queue} = [];

                $ref->{max_bytes} = 2560;    # optimised for hybrid6 ircd
                $ref->{window}    = 10;      # hybrid6
                $ref->{float}       = $ref->{max_bytes};
                $ref->{line_length} = 511;                 # hybrid6
                $ref->{last_time} = $ref->{first_time} = $ref->{since} = time();
                $ref->{last_sent} = 0;
                print
                  "$handle: $server, $port, $nick, $irc_name, $user_name, $passwd\n"
                  if $main::Debug{irc};
            }
        }

        # handle per-connection authentication config-lines
        foreach $aline ( grep /irc_auth\d+$/, keys(%config_parms) ) {
            $aline =~ /irc_auth(\d+)/;
            $handle = $1;
            $ref    = $irc_data{connections}{$handle};
            if ( defined($ref) ) {
                print "ALINE $handle: $aline\n" if $main::Debug{irc};
                $ref->{auths} = $config_parms{$aline};
                print "$handle: $config_parms{$aline}\n" if $main::Debug{irc};
            }
        }

        # handle per-connection buffer strategy config-lines
        foreach $bline ( grep /irc_buffer\d+$/, keys(%config_parms) ) {
            $bline =~ /irc_buffer(\d+)/;
            $handle = $1;
            $ref    = $irc_data{connections}{$handle};
            if ( defined($ref) ) {
                print "BLINE $handle: $bline\n" if $main::Debug{irc};

                if ( $config_parms{$bline} =~ /(\d*):(\d*):(\d*)/ ) {
                    my ( $max_bytes, $line_length, $window ) = ( $1, $2, $3 );

                    $ref->{max_bytes}   = $max_bytes   ? $max_bytes   : 2560;
                    $ref->{line_length} = $line_length ? $line_length : 511;
                    $ref->{window}      = $window      ? $window      : 10;
                    $ref->{float} = $ref->{max_bytes};
                    print "$handle: $config_parms{$bline}\n"
                      if $main::Debug{irc};
                }
            }
        }

        # autoconnect on startup?
        if ( defined( $config_parms{irc_autoconnect} )
            && ( $config_parms{irc_autoconnect} ne '' ) )
        {
            irc_connect();
        }

        if ( defined( $config_parms{irc_parting} ) ) {
            $irc_quit_msg = $config_parms{irc_parting};
        }
        else {
            $irc_quit_msg = "bye!";
        }

        &Log_add_hook( \&irc_log );
    }
}

################################################################################
# MisterHouse hooks
################################################################################

# connect all IRC connections
sub irc_connect {
    my $handle;

    foreach $handle ( keys( %{ $irc_data{connections} } ) ) {
        print "CONNECTING $handle\n" if $main::Debug{irc};
        $irc_data{connections}{$handle}{conn} = $irc->newconn(
            Server    => $irc_data{connections}{$handle}{server},
            Port      => $irc_data{connections}{$handle}{port},
            Nick      => $irc_data{connections}{$handle}{nick},
            Ircname   => $irc_data{connections}{$handle}{ircname},
            Usernname => $irc_data{connections}{$handle}{username},
            Password  => $irc_data{connections}{$handle}{password}
        ) or print_log "IRC connection $handle failed";
    }
}

# disconnect all IRC connections
sub irc_disconnect {
    my $handle;

    foreach $handle ( keys( %{ $irc_data{connections} } ) ) {
        if ( defined( $irc_data{connections}{$handle}{conn} ) ) {
            $irc_data{connections}{$handle}
              {quit}++;    # flag the disconnect handler to abort
            $irc_data{connections}{$handle}{conn}->quit($irc_quit_msg);
        }
    }
}

# this function is our log hook: it will send log info to all channels and
# users who have requested logging, subject to their individual filtering requirements
sub irc_log {
    my ( $log_source, $text, %parms ) = @_;
    my ( $handle, $channel, $user, $mask );
    return if $parms{no_im} or !$text;
    $text = "[$log_source] $text";

    # loop over our active server connections
    foreach $handle ( keys( %{ $irc_data{connections} } ) ) {

        # for each connection, generate channel log msgs
        foreach $channel (
            keys( %{ $irc_data{connections}{$handle}{channels} } ) )
        {
            $mask = $irc_data{connections}{$handle}{channels}{$channel}{publog};
            next unless defined($mask);
            next unless ( $mask eq 'all' or $log_source =~ /$mask/ );
            queue_msg( $handle, $channel, $text );
        }

        # then do private log msgs
        foreach $user ( keys( %{ $irc_data{connections}{$handle}{userlog} } ) )
        {
            $mask = $irc_data{connections}{$handle}{userlog}{$user};
            next unless defined($mask);
            next unless ( $mask eq 'all' or $log_source =~ /$mask/ );
            $user =~ /^([^!]+)!/;
            queue_msg( $handle, $1, $text );
        }
    }
}

# this function is our respond hook: called by voice commands which respond()
# when set_by or Respond_Target is 'irc', which it is for our command handler
sub respond_irc {
    my (%parms) = @_;

    # we've stashed the handle in a global
    my $handle = $parms{handle};
    my $target = $parms{target};

    print "RESPONDER: handle=$handle, target=$target\n" if $main::Debug{irc};
    print join ",", keys %parms;
    print "\n";
    if ( $handle >= 0 ) {
        queue_msg( $handle, $target, $parms{text} );
        print "RESPONDER: QUEUES $parms{text} for $target\n"
          if $main::Debug{irc};
    }
}

################################################################################
# IRC hooks
################################################################################

# someone sent us a privmsg
sub irc_on_msg {
    my ( $self, $event ) = @_;
    my $handle = find_handle($self);
    my ($nick) = $event->nick;
    my ($cmd)  = $event->args;
    my ($from) = $event->from;

    print "on_msg: *$nick*$from* $cmd\n" if $main::Debug{irc};
    irc_interpret( $self, $nick, $from, $cmd );
}

# channel msg received
sub irc_on_public {
    my ( $self, $event ) = @_;
    my $handle = find_handle($self);
    my @to     = $event->to;
    my ( $nick, $mynick ) = ( $event->nick, $self->nick );
    my ($arg) = ( $event->args );
    my $from = $event->from;
    my $cmd;

    # Note that $event->to() returns a list (or arrayref, in scalar
    # context) of the message's recipients, since there can easily be
    # more than one.
    my ($channel) = ( $event->to )[0];

    print "on_public: <$nick><$from> $arg\n" if $main::Debug{irc};

    if ( $arg =~ /^$mynick[:,]\s*(.*)/ ) {    #were we addressed?
        if ( irc_check_auth( $handle, $from ) )
        {    # only hear channel msgs from authenticated users
            $cmd = $1;
            print "addressed by $nick -> $cmd\n" if $main::Debug{irc};

            irc_interpret( $self, $channel, $from, $cmd );
        }
    }
}

# someone (maybe me) joined a channel we're on
sub irc_on_join {
    my ( $self, $event ) = @_;
    my $handle  = find_handle($self);
    my $channel = ( $event->to )[0];
    my ( $nick, $mynick ) = ( $event->nick, $self->nick );

    printf "on_join: *** %s (%s) has joined channel %s\n",
      $event->nick, $event->userhost, $channel
      if $main::Debug{irc};

    if ( $nick eq $mynick ) {    # it's about me
        if ( defined( $irc_data{connections}{$handle}{channels}{$channel} ) ) {
            $irc_data{connections}{$handle}{channels}{$channel}{joined} = 1;
            print "on_join: joined $channel\n" if $main::Debug{irc};
        }
        else {
            # bogus. maybe a nick collision
            print
              "on_join: got told I joined $channel, but I'm not on that channel!\n"
              if $main::Debug{irc};
        }
    }
}

# someone (maybe me) left a channel we're on
sub irc_on_part {
    my ( $self, $event ) = @_;
    my $handle = find_handle($self);
    my ($channel) = ( $event->to )[0];
    my ( $nick, $mynick ) = ( $event->nick, $self->nick );

    printf "on_part: *** %s has left channel %s\n", $event->nick, $channel
      if $main::Debug{irc};

    if ( $nick eq $mynick ) {    # it's about me
        if (
            defined(
                $irc_data{connections}{$handle}{channels}{$channel}{joined}
            )
          )
        {
            delete $irc_data{connections}{$handle}{channels}{$channel}{joined};
            print "on_part: left $channel\n" if $main::Debug{irc};
        }
        else {
            # bogus. maybe a nick collision
            print
              "on_join: got told I left $channel, but I'm not on that channel!\n"
              if $main::Debug{irc};
        }
    }
}

# we got disconnected - attempt to reconnect
sub irc_on_disconnect {
    my ( $self, $event ) = @_;
    my $handle = find_handle($self);

    print_log "Disconnected from ", $event->from(), " (",
      ( $event->args() )[0], ")\n";

    if ( defined($handle) ) {
        if ( defined( $irc_data{connections}{$handle}{quit} ) ) {

            # deliberate kill - tidy up
            print_log "IRC connection terminated\n";

            $irc->removeconn( $irc_data{connections}{$handle}{conn} );
            delete $irc_data{connections}{$handle}{conn};
            delete $irc_data{connections}{$handle}{quit};
            delete $irc_data{connections}{$handle}{authenticated};
        }
        else {
            # conn died for some other reason - reconnect
            print_log "Attempting to reconnect...\n";
            $self->connect();
        }
    }
}

# handle initial connection messages
sub irc_on_init {
    my ( $self, $event ) = @_;
    my (@args) = ( $event->args );
    shift(@args);

    print "on_init: *** @args\n" if $main::Debug{irc};
}

# we've successfully connected
sub irc_on_connect {    # actually on endmotd
    my $self   = shift;
    my $handle = find_handle($self);

    if ( defined($handle) ) {

        #my $channel=$irc_data{connections}{$handle}{channel};
        my $channel;

        foreach $channel ( keys %{ $irc_data{connections}{$handle}{channels} } )
        {
            if ( $irc_data{connections}{$handle}{channels}{$channel}{start} ) {
                print_log "on_connect: Joining $channel...\n";
                $self->join($channel);

                #$self->topic($channel);
            }
        }
    }
}

# nick collision, try permutations
sub irc_on_nick_taken {
    my ($self) = shift;
    my $handle = find_handle($self);
    my $nick = substr( $self->nick, -1 ) . substr( $self->nick, 0, 8 );

    if ( defined($handle) ) {
        $irc_data{connections}{$handle}{nick} = $nick;
        $self->nick($nick);
    }

    $self->nick( substr( $self->nick, -1 ) . substr( $self->nick, 0, 8 ) );
}

# invited to a channel
sub irc_on_invite {
    my ( $self, $event ) = @_;
    my $handle = find_handle($self);
    my ( $nick, $mynick ) = ( $event->nick, $self->nick );
    my $channel = ( $event->args )[0];
    my $from    = $event->from;

    print_log "invited to $channel by $nick\n";

    if ( defined( $config_parms{irc_accept_invites} )
        && ( $config_parms{irc_accept_invites} ne '' ) )
    {
        # we don't accept invites from strangers!
        if ( irc_check_auth( $handle, $from ) ) {
            irc_cmd_join( $self, $nick, $from, $handle, $channel );
        }
    }
    else {
        #$self->privmsg($nick, "Sorry, I don't accept invites\n");
        queue_msg( $handle, $nick, "Sorry, I don't accept invites\n" );
    }
}

################################################################################
# IRC msg interpreter
################################################################################
sub irc_interpret {
    my ( $obj, $nick, $from, $cmd ) = @_;
    my $handle = find_handle($obj);

    if ( defined($handle) ) {

        # check for builtin commands first

        # first do cmds requiring no authentication
        if ( $cmd =~ /^log[oi]n\s+(\S+)/ ) {
            irc_cmd_login( $obj, $nick, $from, $handle );
        }

        # now do authorised cmds
        if ( irc_check_auth( $handle, $from ) ) {
            if ( $cmd eq 'quit' ) {    #### QUIT ####
                irc_cmd_quit( $obj, $nick, $from, $handle );
            }
            elsif ( $cmd =~ /^log(?:$|\s+(.*))/ )
            {                          #### LOG #### logging via privmsg
                irc_cmd_log( $obj, $nick, $from, $handle, $1 );
            }
            elsif ( $cmd =~ /^publog(?:$|\s+(\S*)\s*(.*))/ )
            {                          #### PUBLOG #### logging via channel msg
                irc_cmd_publog( $obj, $nick, $from, $handle, $1, $2 );
            }
            elsif ( $cmd eq 'links' ) {    #### LINKS ####
                irc_cmd_links( $obj, $nick, $from, $handle );
            }
            elsif ( $cmd eq 'test' ) {     #### TEST ####
                irc_cmd_test( $obj, $nick, $from, $handle );
            }
            elsif ( $cmd =~ /^join\s+(\S+)/ ) {    #### JOIN ####
                irc_cmd_join( $obj, $nick, $from, $handle, $1 );
            }
            elsif ( $cmd =~ /^part\s+(\S+)/ ) {    #### PART ####
                irc_cmd_part( $obj, $nick, $from, $handle, $1 );
            }
            elsif ( $cmd eq 'list' ) {             #### LIST ####
                irc_cmd_list( $obj, $nick, $from, $handle );
            }
            elsif ( $cmd =~ /^find\s+(.+)/ ) {     #### FIND ####
                irc_cmd_find( $obj, $nick, $from, $handle, $1 );
            }
            else {
                &process_external_command( $cmd, 0, '',
                    "irc handle=$handle target=$nick" );
            }
        }    # end authorised
    }
}

################################################################################
# IRC command handlers
################################################################################
sub irc_cmd_login {
    my ( $obj, $nick, $from, $handle ) = @_;

    if ( irc_authenticate( $handle, $from, $1 ) ) {
        queue_msg( $handle, $nick, "login successful\n" );
    }    # deliberately returning no response on unsuccessful auth`
}

sub irc_cmd_quit {
    my ( $obj, $nick, $from, $handle ) = @_;

    $irc_data{connections}{$handle}
      {quit}++;    # flag the disconnect handler to abort
    $obj->quit($irc_quit_msg);
}

sub irc_cmd_log {
    my ( $obj, $nick, $from, $handle, $mask ) = @_;

    if ( $mask ne '' ) {
        $irc_data{connections}{$handle}{userlog}{$from} = $mask;
    }
    else {
        $mask = $irc_data{connections}{$handle}{userlog}{$from};
    }
    $mask = ( $mask eq '' ) ? "none" : $mask;
    queue_msg( $handle, $nick, "logging for $from set to  '$mask'\n" );
}

sub irc_cmd_publog {
    my ( $obj, $nick, $from, $handle, $channel, $mask ) = @_;
    my @channels;

    if ( ( $channel ne '' ) && ( $mask ne '' ) ) {    # publog channel mask
        if ( defined( $irc_data{connections}{$handle}{channels}{$channel} ) ) {
            $irc_data{connections}{$handle}{channels}{$channel}{publog} = $mask;
            queue_msg( $handle, $nick,
                "channel logging for $channel set to '$mask'\n" );
        }
        else {
            queue_msg( $handle, $nick, "I'm not on channel $channel\n" );
        }
    }
    elsif ( $channel ne '' ) {                        # publog mask
        $mask    = $channel;
        $channel = '';

        # need to find a channel to apply this mask to -
        # if it was a public msg on a channel, use that one
        if ( $nick =~ /^#/ ) {
            $channel = $nick;
        }
        else {
            # if we're only on one channel, use that
            @channels = keys( %{ $irc_data{connections}{$handle}{channels} } );
            if ( @channels == 1 ) {
                $channel = shift @channels;
            }
        }

        if ( $channel ne '' ) {
            $irc_data{connections}{$handle}{channels}{$channel}{publog} = $mask;
            queue_msg( $handle, $nick,
                "channel logging for  $channel set to '$mask'\n" );
        }
        else {
            queue_msg( $handle, $nick,
                "I don't know which channel you're referring to\n" );
        }
    }
    else {    # publog

        # generate a list of channel log masks

        @channels = keys( %{ $irc_data{connections}{$handle}{channels} } );
        if ( @channels > 0 ) {
            foreach $channel (@channels) {
                $mask =
                  $irc_data{connections}{$handle}{channels}{$channel}{publog};
                $mask = ( defined($mask) ) ? $mask : 'none';
                queue_msg( $handle, $nick,
                    "channel logging for $channel set to '$mask'\n" );
            }
        }
        else {
            queue_msg( $handle, $nick,
                "I'm not currently logging to any channels\n" );
        }
    }
}

sub irc_cmd_links {
    my ( $obj, $nick, $from ) = @_;

    my ( $text, $channel, $user, $ref, $handle );
    my $qsize;
    my $penalty;

    foreach $handle ( sort keys %{ $irc_data{connections} } ) {
        $ref   = $irc_data{connections}{$handle};
        $qsize = $#{ $ref->{queue} } + 1;

        $penalty = $ref->{since} - $ref->{last_time};

        $text = sprintf(
            "%4d: %s%s as %s (%s)\n",
            $handle, $ref->{server}, $ref->{port} ? ":$ref->{port}" : "",
            $ref->{nick}, $ref->{username}
        );
        $text .= "      channels: "
          . join( ', ', sort keys( %{ $ref->{channels} } ) ) . "\n";
        $text .= "      admins: "
          . join( ', ', sort keys( %{ $ref->{authenticated} } ) ) . "\n";
        $text .=
          "      buffer: $ref->{float} / $ref->{max_bytes} bytes used , $ref->{line_length} cpl, penalty $penalty\n";
        $text .= sprintf( "      $qsize entr%s in queue\n",
            $qsize == 1 ? "y" : "ies" );
        queue_msg( $handle, $nick, $text );
    }
}

sub irc_cmd_test {
    my ( $obj, $nick, $from, $handle ) = @_;
    queue_msg( $handle, $nick, "foo bar baz\n" );
}

sub irc_cmd_join {
    my ( $obj, $nick, $from, $handle, $channel ) = @_;

    if (
        defined( $irc_data{connections}{$handle}{channels}{$channel}{joined} ) )
    {
        queue_msg( $handle, $nick, "I'm already on $channel\n" );
    }
    else {
        queue_msg( $handle, $nick, "Joining $channel...\n" );
        $obj->join($channel);
    }
}

sub irc_cmd_part {
    my ( $obj, $nick, $from, $handle, $channel ) = @_;

    if (
        defined( $irc_data{connections}{$handle}{channels}{$channel}{joined} ) )
    {
        queue_msg( $handle, $nick, "Leaving $channel...\n" );
        $obj->part($channel);
    }
    else {
        queue_msg( $handle, $nick, "I'm not on $channel\n" );
    }
}

sub irc_cmd_list {
    my ( $obj, $nick, $from, $handle, $channel ) = @_;
    my ( @cmds, @cmds2, $cmd );

    @cmds = &Voice_Cmd::voice_items();

    for $cmd (@cmds) {
        $cmd =~ s/^[^:]+: //
          ;    #Trim the category ("Other: ", etc) from the front of the command
        $cmd =~ s/\s*$//;
        my ($ref) = &Voice_Cmd::voice_item_by_text( lc($cmd) );
        my $authority = $ref->get_authority if $ref;
        print "AUTHORITY: $authority\n" if $main::Debug{irc};
        push @cmds2, $cmd
          if lc $authority eq 'im'
          or lc $authority eq 'anyone'
          or $authority eq '';
    }

    $cmd = sprintf( "Found %d command%s\n",
        scalar(@cmds2), scalar(@cmds2) == 1 ? "" : "s" );
    queue_msg( $handle, $nick, $cmd );
    queue_msg( $handle, $nick, join( ', ', @cmds2 ) );
}

sub irc_cmd_find {
    my ( $obj, $nick, $from, $handle, $search ) = @_;
    my ( @cmds, @cmds2, $cmd );

    $search =~ s/^\s+//;
    $search =~ s/\s+$//;

    @cmds = &list_voice_cmds_match($search);

    for $cmd (@cmds) {
        $cmd =~ s/^[^:]+: //
          ;    #Trim the category ("Other: ", etc) from the front of the command
        $cmd =~ s/\s*$//;
        my ($ref) = &Voice_Cmd::voice_item_by_text( lc($cmd) );
        my $authority = $ref->get_authority if $ref;
        push @cmds2, $cmd
          if lc $authority eq 'im'
          or lc $authority eq 'anyone'
          or $authority eq '';
    }

    $cmd = sprintf( "Found %d command%s\n",
        scalar(@cmds2), scalar(@cmds2) == 1 ? "" : "s" );
    queue_msg( $handle, $nick, $cmd );
    for $cmd (@cmds2) {
        queue_msg( $handle, $nick, "    $cmd\n" );
    }
}

################################################################################
# Utility routines
################################################################################

# find a local handle for an IRC::Connection object
sub find_handle {
    my $conn = shift @_;
    my $handle;

    foreach $handle ( keys %{ $irc_data{connections} } ) {
        if ( $irc_data{connections}{$handle}{conn} == $conn ) {
            return $handle;
        }
    }
    return undef;
}

# check whether nick!user@host authenticated for given connection
sub irc_check_auth {
    my ( $handle, $from ) = @_;
    my $auth;

    if ( defined( $irc_data{connections}{$handle}{authenticated}{$from} ) ) {
        if ( $irc_data{connections}{$handle}{authenticated}{$from} > 0 ) {
            return 1;
        }
        else {
            return 0;
        }
    }

    $auth = irc_authenticate( $handle, $from );
    $irc_data{connections}{$handle}{authenticated}{$from} = $auth;
    return $auth;
}

# authenticate user for connection
sub irc_authenticate {
    my ( $handle, $from, $trypasswd ) = @_;
    my ( $aline, $mask, $mhuser, $user, $pwd );

    if ( defined( $aline = $irc_data{connections}{$handle}{auths} ) ) {
        for ( split /,/, $aline ) {
            if (/([^:]+):(.+)/) {
                next unless defined($trypasswd);
                ( $mask, $mhuser ) = ( $1, $2 );
                if ( $from =~ /$mask/ ) {
                    ( $user, $pwd ) = password_check2($trypasswd);
                    if ( $user eq $mhuser ) {
                        $irc_data{connections}{$handle}{authenticated}{$from} =
                          2;
                        print_log
                          "authenticated $from as $mhuser with password $pwd\n";
                        return 1;
                    }
                }
            }
            else {
                $mask = $_;
                if ( $from =~ /$mask/ ) {
                    $irc_data{connections}{$handle}{authenticated}{$from} = 1;
                    return 1;
                }
            }
        }
    }
    return 0;
}

# push a msg onto a connection's rate-controlled buffer management queue
sub queue_msg {
    my ( $handle, $target, $msg ) = @_;
    my $connref = $irc_data{connections}{$handle};
    my $hashref;
    my $line;
    my $line_length;
    my $queue;
    my $sub_msg;

    if ( defined($connref) ) {
        $line_length = $connref->{line_length};
        $queue       = $connref->{queue};

        # split into lines, ensure no line exceeds max length
        foreach $sub_msg ( split '\n', $msg ) {
            while ($sub_msg) {
                ( $line, $sub_msg ) = unpack( "a$line_length a*", $sub_msg );
                push @{$queue}, { 'target' => $target, 'msg' => $line };
                print "QUEUED $target -> $line on handle $handle\n"
                  if $main::Debug{irc};
            }
        }
    }
}

# poll a connection's rate-controlled buffer management queue
# hand-off one queued message if we can make our QoS guarantee
sub poll_queue {
    my $handle  = shift @_;
    my $connref = $irc_data{connections}{$handle};
    my ( $time_now, $interval, $refill );
    my $qref;

    if ( defined($connref) ) {
        $qref = $connref->{queue};
        my $msgref = $qref->[0];

        if ( $#{$qref} >= 0 ) {    # data on queue
            $connref->{last_time} = time();

            if ( $connref->{since} < $connref->{last_time} ) {
                $connref->{since} = $connref->{last_time};
            }

            #printf "penalty: %d buffer ;%d\n", $connref->{since} - $connref->{last_time}, $connref->{float} if $main::Debug{irc};

            if (
                $connref->{since} - $connref->{last_time} < $connref->{window} )
            {
                # we're not penalised
                $connref->{float} += $connref->{last_sent};
                $connref->{last_sent} = 0;

                my $len =
                  length( $msgref->{msg} ) +
                  length( $msgref->{target} ) +
                  length("privmsg") + 12;  # 12 byte overhead in IRC::Connection
                my $to_send =
                  $len > $connref->{float} ? 0 : $len;   # only send whole lines

                if ($to_send) {
                    my $msg = shift @{$qref};

                    #print "DEQUEUED \"$msg->{target} -> $msg->{msg}\" ($to_send bytes)\n" if $main::Debug{irc};
                    for ( split( /\n/, $msg->{msg} ) ) {
                        $connref->{conn}->privmsg( $msg->{target}, $_ . "\n" );

                        #print "SENT: $_\n" if $main::Debug{irc};
                    }

                    $connref->{last_sent} = $to_send;
                    $connref->{float} -= $to_send;
                    $connref->{since} +=
                      ( 2 + $to_send / 120 );    # hybrid6 magic formula
                }
                else {
                    # buffer full
                }
            }
        }
    }
}

# poll buffer management queues for all active connections
sub poll_all_queues {
    my $handle;

    # loop over our active server connections
    foreach $handle ( keys( %{ $irc_data{connections} } ) ) {
        poll_queue($handle);
    }
}

################################################################################
# code inserted into the MH event loop
################################################################################

# handle Voice commands
if ( $state = $v_irc_signon->said() ) {
    irc_disconnect($state);
    irc_connect($state);
}

if ( $state = $v_irc_signoff->said() ) {
    irc_disconnect($state);
}

# poll the IRC framework
$irc->do_one_loop();

# poll buffer management strategy rate-pacing thingy (tm)
poll_all_queues();
