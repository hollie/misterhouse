package Net::AOLIM;

use IO::Socket;
use IO::Select;
require 5.001;

use vars qw($VERSION $AUTOLOAD);

=pod

=head1 NAME

Net::AOLIM - Object-Oriented interface to the AOL Instant Messenger TOC client protocol

=head1 SYNOPSIS

The really short form:

    use Net::AOLIM;
    $aim = Net::AOLIM->new('username' => $user,
			   'password' => $pass,
			   'callback' => \&handler);

    $aim->signon;

    $aim->toc_send_im($destuser, $message);

=cut

###################################################################
# Copyright 2000-02 Riad Wahby <rsw@jfet.org> All rights reserved #
# This program is free software.  You may redistribute it and/or  #
# modify it under the same terms as Perl itself.                  #
###################################################################

# subroutine declarations
sub new;
sub signon;
sub read_sflap_packet;
sub send_sflap_packet;
sub srv_socket;
sub pw_roast;
sub norm_uname;
sub toc_format_msg;
sub toc_format_login_msg;
sub toc_send_im;
sub add_buddies;
sub remove_buddies;
sub add_online_buddies;
sub remove_online_buddies;
sub set_srv_buddies;
sub current_buddies;
sub current_permits;
sub current_denies;
sub im_permit;
sub im_deny;
sub add_im_permit;
sub add_im_deny;
sub im_deny_all;
sub add_im_deny_all;
sub im_permit_all;
sub add_im_permit_all;
sub toc_set_config;
sub toc_evil;
sub toc_chat_join;
sub toc_chat_send;
sub toc_chat_whisper;
sub toc_chat_evil;
sub toc_chat_invite;
sub toc_chat_leave;
sub toc_chat_accept;
sub toc_get_info;
sub toc_set_info;
sub toc_set_away;
sub toc_get_dir;
sub toc_set_dir;
sub toc_dir_search;
sub toc_set_idle;
sub ui_add_fh;
sub ui_del_fh;
sub ui_all_fh;
sub ui_exists_fh;
sub ui_set_callback;
sub ui_get_callback;
sub ui_dataget;

#
# some constants to use, including error codes.
# :-) the curse of ex-C-programmers--no #defines
#

# max packet length
$MAX_PACKLENGTH = 65535;

# SFLAP types
$SFLAP_TYPE_SIGNON = 1;
$SFLAP_TYPE_DATA = 2;
$SFLAP_TYPE_ERROR = 3;
$SFLAP_TYPE_SIGNOFF = 4;
$SFLAP_TYPE_KEEPALIVE = 5;
$SFLAP_MAX_LENGTH = 1024;

# return codes
$SFLAP_SUCCESS = 0;
$SFLAP_ERR_UNKNOWN = 1;
$SFLAP_ERR_ARGS = 2;
$SFLAP_ERR_LENGTH = 3;
$SFLAP_ERR_READ = 4;
$SFLAP_ERR_SEND = 5;

# misc SFLAP constants
$SFLAP_FLAP_VERSION = 1;
$SFLAP_TLV_TAG = 1;
$SFLAP_HEADER_LEN = 6;

# Net::AOLIM version
$VERSION = "1.6";

# number of arguments that server messages have:
%SERVER_MSG_ARGS = ( 'SIGN_ON' => 1,
		     'CONFIG' => 1,
		     'NICK' => 1,
		     'IM_IN' => 3,
		     'UPDATE_BUDDY' => 6,
		     'ERROR' => 2,
		     'EVILED' => 2,
		     'CHAT_JOIN' => 2,
		     'CHAT_IN' => 4,
		     'CHAT_UPDATE_BUDDY' => 0,
		     'CHAT_INVITE' => 4,
		     'CHAT_LEFT' => 1,
		     'GOTO_URL' => 2,
		     'DIR_STATUS' => 2,
		     'PAUSE' => 0 );

=pod

=head1 NOTES

Error conditions will be stored in $main::IM_ERR, with any arguments
to the error condition stored in $main::IM_ERR_ARGS.

The hash %Net::AOLIM::ERROR_MSGS contains english translations of all of
the error messages that are either internal to the module or
particular to the TOC protocol.

Errors may take arguments indicating a more specific failure
condition.  In this case, they will either be stored in
$main::IM_ERR_ARGS or they will come from the server ERROR message.
To insert the arguments in the proper place, use a construct similar
to:

    $ERROR = $Net::AOLIM::ERROR_MSGS{$IM_ERR};
    $ERROR =~ s/\$ERR_ARG/$IM_ERR_ARGS/g;

This assumes that the error code is stored in $IM_ERR and the error
argument is stored in $IM_ERR_ARGS.

All methods will return undef on error, and will set $main::IM_ERR and
$main::IM_ERR_ARGS as appropriate.

It seems that TOC servers won't acknowledge a login unless at least
one buddy is added before toc_init_done is sent.  Thus, as of version
1.6, Net::AOLIM will add the current user to group "Me" if you don't
create your buddy list before calling signon().  Don't bother removing
this if you have added your buddies; it'll automagically disappear.

=cut

%ERROR_MSGS = ( 0 => 'Success',
		1 => 'Net::AOLIM Error: Unknown',
		2 => 'Net::AOLIM Error: Incorrect Arguments',
		3 => 'Net::AOLIM Error: Exceeded Max Packet Length (1024)',
		4 => 'Net::AOLIM Error: Reading from server',
		5 => 'Net::AOLIM Error: Sending to server',
		6 => 'Net::AOLIM Error: Login timeout',
		901 => 'General Error: $ERR_ARG not currently available',
		902 => 'General Error: Warning of $ERR_ARG not currently available',
		903 => 'General Error: A message has been dropped, you are exceeding the server speed limit',
		950 => 'Chat Error: Chat in $ERR_ARG is unavailable',
		960 => 'IM and Info Error: You are sending messages too fast to $ERR_ARG',
		961 => 'IM and Info Error: You missed an IM from $ERR_ARG because it was too big',
		962 => 'IM and Info Error: You missed an IM from $ERR_ARG because it was sent too fast',
		970 => 'Dir Error: Failure',
		971 => 'Dir Error: Too many matches',
		972 => 'Dir Error: Need more qualifiers',
		973 => 'Dir Error: Dir service temporarily unavailble',
		974 => 'Dir Error: Email lookup restricted',
		975 => 'Dir Error: Keyword ignored',
		976 => 'Dir Error: No keywords',
		977 => 'Dir Error: Language not supported',
		978 => 'Dir Error: Country not supported',
		979 => 'Dir Error: Failure unknown $ERR_ARG',
		980 => 'Auth Error: Incorrect nickname or password',
		981 => 'Auth Error: The service is temporarily unavailable',
		982 => 'Auth Error: Your warning level is too high to sign on',
		983 => 'Auth Error: You have been connecting and disconnecting too frequently.  Wait 10 minutes and try again.  If you continue to try, you will need to wait even longer.',
		989 => 'Auth Error: An unknown signon error has occurred $ERR_ARG' );

=pod

=head1 DESCRIPTION

This section documents every member function of the Net::AOLIM class.

=head2 $Net::AOLIM->new()

This is the Net::AOLIM Constructor.

It should be called with following arguments (items with default
values are optional):

    'username' => login
    'password' => password
    'callback' => \&callbackfunction
    'server' => servername (default toc.oscar.aol.com)
    'port' => port number (default 1234)
    'allow_srv_settings' => <1 | 0> (default 1)
    'login_server' => login server (default login.oscar.aol.com)
    'login_port' => login port (default 5198)
    'login_timeout' => timeout in seconds to wait for a response to the
                       toc_signon packet.  Default is 0 (infinite)
    'aim_agent' => agentname (max 200 char) 
                Default is AOLIM:$Version VERSION$
                There have been some reports that changing this 
                may cause TOC servers to stop responding to signon 
                requests

callback is the callback function that handles incoming data from the
server (already digested into command plus args).  This is the meat of
the client program.

allow_srv_settings is a boolean that dictates whether the object
should modify the user configuration on the server.  If
allow_srv_settings is false, the server settings will be ignored and
will not be modified.  Otherwise, the server settings will be read in
and parsed, and will be modified by calls that modify the buddy list.

aim_agent is the name of the client program as reported to the TOC
server

Returns a blessed instantiation of Net::AOLIM.

=cut

sub new
{
    my $whatami = shift @_;
    
    while ($key = shift @_)
    {
	if ($var = shift @_)
	{
	    $args{$key} = $var;
	}
    }
    
    unless ((defined $args{'username'}) && (defined $args{'password'}) && (defined $args{'callback'}))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }
		
    ($args{'allow_srv_settings'} = 1) unless (defined $args{'allow_srv_settings'});
    $args{'server'} ||= 'toc.oscar.aol.com';
    $args{'port'} ||= 1234;
    $args{'login_server'} ||= 'login.oscar.aol.com';
    $args{'login_port'} ||= 5198;
    $args{'aim_agent'} ||= 'AOLIM:$Version ' . $VERSION . "\$";
    $args{'login_timeout'} ||= undef();

# Make a new instance of instmsg and bless it.

    my $new_instmsg = { 'username' => $args{'username'},
			'password' => $args{'password'},
			'server' => $args{'server'},
			'port' => $args{'port'},
			'allow_srv_settings' => $args{'allow_srv_settings'},
			'roastedp' => pw_roast('', $args{'password'}),
			'unamenorm' => norm_uname('', $args{'username'}),
			'im_socket' => '',
			'client_seq_number' => time % 65536,
			'login_server' => $args{'login_server'},
			'login_port' => $args{'login_port'},
			'buddies' => {},
			'permit' => [],
			'deny' => [],
			'callback' => $args{'callback'},
			'callbacks' => {},
			'permit_mode' => '1',
			'sel' => IO::Select->new(),
			'pause' => '0',
			'aim_agent' => $args{'aim_agent'},
			'login_timeout' => $args{'login_timeout'},
		    };

    bless $new_instmsg, $whatami;
    $main::IM_ERR = 0;
    return $new_instmsg;
}

######################################################
# SOCKET LEVEL FUNCTIONS
# the functions here operate at the socket level
#
# signon is included here because it is the function
# that actually creates the socket
######################################################

=pod

=head2 $aim->signon()

Call this after calling C<new()> and after setting initial buddy
listings with C<add_buddies()>, C<im_permit()>, C<im_deny()>,
C<im_permit_all()>, and C<im_deny_all()> as necessary.

Returns undef on failure, setting $main::IM_ERR and $main::IM_ERR_ARGS
as appropriate.  Returns 0 on success.

This function is also called every time we receive a SIGN_ON packet
from the server.  This is because we are required to react in a
specific way to the SIGN_ON packet, and this method contains all
necessary functionality.  We should only receive SIGN_ON while
connected if we have first received a PAUSE (see the B<TOC(7)>
documentation included with this package for details of how PAUSE
works).

=cut

sub signon
{
#
# call this after new() to sign on to the IM service
#
# takes no arguments
#
# returns 0 on success, undef on failure.  If failure, 
# check $main::IM_ERR for reason.
#
    my $imsg = $_[0];
    my $im_socket = \$imsg->{'im_socket'};

    unless ($imsg->{'pause'})
    {
# unless we're coming off a pause, make our socket
	$$im_socket = IO::Socket::INET->new(PeerAddr => $imsg->{'server'},
					    PeerPort => $imsg->{'port'},
					    Proto => 'tcp',
					    Type => SOCK_STREAM)
	    or die "Couldn't connect to server: $!";

        $$im_socket->autoflush(1);

# add this filehandle to the select loop that we will later use
	$imsg->{'sel'}->add($$im_socket);

	my $so_srv_sflap_signon;
	my $so_srv_version;
	my $so_sflap_signon;
	my $so_toc_ascii;
	my $so_toc_srv_so;
	my $so_toc_srv_config;
        my $so_toc_srv_config_msg;
        my $so_toc_srv_config_rest;
	my $so_init_done;
	
# send a FLAPON to initiate the connection; this is the only time
# that stuff should be printed directly to the server without
# using send_sflap_packet
	syswrite $$im_socket,"FLAPON\r\n\r\n";

	return undef unless (defined ($so_srv_sflap_signon = $imsg->read_sflap_packet()));

	$ulen = length $imsg->{'unamenorm'};
	
	$so_sflap_signon = pack "Nnna".$ulen, 1, 1, $ulen, $imsg->{'unamenorm'};
	
	
	return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_SIGNON, $so_sflap_signon, 1, 1)));
	
	$so_toc_ascii = $imsg->toc_format_login_msg('toc_signon',$imsg->{'login_server'},$imsg->{'login_port'},$imsg->{'unamenorm'},$imsg->{'roastedp'},'english',$imsg->{'aim_agent'});
	
	return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $so_toc_ascii, 0, 0)));
	
	my @ready = $imsg->{'sel'}->can_read($imsg->{'login_timeout'});
	
	if (scalar(@ready) > 0)
	{
	    return undef unless (defined ($so_toc_srv_so = $imsg->read_sflap_packet()));
	}
	else
	{
	    $main::IM_ERR = 6;
	    return undef;
	}
	
	unless ($so_toc_srv_so =~  /SIGN_ON/)
	{
# we didn't sign on successfully
	    if ($so_toc_srv_so =~ /ERROR:(.*)/)
	    {
# if we get an error code from the server, send it
# back in $main::IM_ERR
		($main::IM_ERR, $main::IM_ERR_ARG) = split (/:/, $1, 2);
	    }
	    else
	    {
		$main::IM_ERR = $SFLAP_ERR_UNKNOWN;
	    }
	    return undef;
	}
    }
    
# we can't possibly be paused at this point; make sure $imsg->{'pause'} = 0
    $imsg->{'pause'} = 0;

# have to call toc_set_config before we finish init
    return undef unless (defined $imsg->toc_set_config());

# now we finish the signon with an init_done
    $so_init_done = $imsg->toc_format_msg('toc_init_done');
    
    
    return undef unless (defined $imsg->send_sflap_packet($SFLAP_TYPE_DATA, $so_init_done, 0, 0));

    return $SFLAP_SUCCESS;
}

=pod

=head2 $aim->read_sflap_packet()

This method returns data from a single waiting SFLAP packet on the
server socket.  The returned value is the payload section of the SFLAP
packet which is completely unparsed.

Most users will never need to call this method.

For more information, see B<ROLLING YOUR OWN> below and the B<TOC(7)>
manpage.

=cut

sub read_sflap_packet
{
#
# read an sflap packet, including a safe
# method of making sure that we get all
# the info in the sflap packet
#
# takes no arguments
#
# returns the read data upon success, or undef if an error
# occurs (and the errno appears in $main::IM_ERR)
#
    my $imsg = shift @_;
    my ($rsp_header, $rsp_recv_packet);
    my ($rsp_ast, $rsp_type, $rsp_seq_new, $rsp_dlen);
    my ($rsp_decoded);
    my $im_socket = \$imsg->{'im_socket'};

# unless we get a valid read, we return an unknown error

    unless (defined(sysread $$im_socket, $rsp_header, $SFLAP_HEADER_LEN, 0) && (length($rsp_header) == $SFLAP_HEADER_LEN))
    {
	$main::IM_ERR = $SFLAP_ERR_READ;
	return undef;
    }

# Now we read the info off the packet, including the data length and the
# sequence number
    ($rsp_ast,$rsp_type,$rsp_seq_new,$rsp_dlen) = unpack "aCnn", $rsp_header;

# now we pull down more bytes equal to the length field in
# the previous read

    unless (defined(sysread $$im_socket, $rsp_recv_packet, $rsp_dlen, 0) && (length($rsp_recv_packet) == $rsp_dlen))
    {
	$main::IM_ERR = $SFLAP_ERR_READ;
	return undef;
    }

# if it's a signon packet, we read the version number
    if (($rsp_type == $SFLAP_TYPE_SIGNON) && ($rsp_dlen == 4))
    {
	($rsp_decoded) = unpack "N", $rsp_recv_packet;
	$main::IM_ERR = $SFLAP_SUCCESS;
	return $rsp_decoded;
    }
# otherwise, we just read it as ASCII
    else
    {
	($rsp_decoded) = unpack "a*", $rsp_recv_packet;
	$main::IM_ERR = $SFLAP_SUCCESS;
	return $rsp_decoded;
    }

# if we fall through to here, something's wrong; return an 
# unknown error
    $main::IM_ERR = $SFLAP_ERR_UNKNOWN;
    return undef;
}

=pod

=head2 $aim->send_sflap_packet($type, $data, $formatted, $noterm)

This method sends an SFLAP packet to the server.  

C<$type> is one of the SFLAP types (see B<TOC(7)>).

C<$data> is the payload to send.  

If C<$formatted> evaluates to true, the data is assumed to be the
completely formed payload of the SFLAP packet; otherwise, the payload
will be packed as necessary.  This defaults to 0.  In either case, the
header is prepended to the payload.

If C<$noterm> evaluates to true, the payload will not be terminated
with a '\0'.  Otherwise, it will be terminated.  If C<$formatted> is
true, this option is ignored and no null is appended.  This defaults
to 0.

Most users will never need to use this method.

For more information, see B<TOC(7)> and B<ROLLING YOUR OWN> below.

=cut

sub send_sflap_packet
{
#
# take data, manufacture an SFLAP header,
# and send off the info.
#
# takes four arguments:
#
# sflap_type: gives the type to include in the header
# sflap_data: either ASCII or a preformatted string to
#             send as the payload
# already_formatted: set to 1 to prevent the formatting
#             of sflap_data as ASCII (if it has already
#             been formatted).  Defaults to 0
# no_null_terminate: set to 1 to prevent the addition of
#             a null terminator to the data. Default 0.
#             No null termination is added if already_formatted
#             is set.
#
# returns undef if unsuccessful, and puts the error in $main::IM_ERR
# otherwise returns 0
#

    my $imsg = shift @_;
    my $im_socket = \$imsg->{'im_socket'};

# arguments
    my $sflap_type = $_[0];
    my $sflap_data = $_[1];
    my $already_formatted = $_[2];
    my $no_null_terminate = $_[3];

    unless ((defined $sflap_type) && (defined $sflap_data) && (defined $already_formatted) && (defined $no_null_terminate))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

# internal variables
    my ($ssp_header, $ssp_data, $ssp_packet, $ssp_datalen);

    if ($already_formatted)
    {	
# we don't have to modify the data
	$ssp_data = $sflap_data;
	$ssp_datalen = length $sflap_data;
	$ssp_header = pack "aCnn", "*", $sflap_type, $imsg->{'client_seq_number'}, $ssp_datalen;
	$ssp_packet = $ssp_header . $ssp_data;
    }
    else
    {
	unless ($no_null_terminate)
	{
# we need to be sure that there's only one \0 at the end of
# the string
	$sflap_data =~ s/\0*$//;
	$sflap_data .= "\0";
        }
	
# now we calculate the length and make the packet
	$ssp_datalen = length $sflap_data;
	$ssp_data = pack "a".$ssp_datalen, $sflap_data;
	$ssp_header = pack "aCnn", "*", $sflap_type, $imsg->{'client_seq_number'}, $ssp_datalen;
	$ssp_packet = $ssp_header . $ssp_data;
    }

# if the packet is too long, return an error
# our connection will be dropped otherwise
    if ((length $ssp_packet) >= $SFLAP_MAX_LENGTH)
    {
	$main::IM_ERR = $SFLAP_ERR_LENGTH;
	return undef;
    }

# if we are successful we return 0
    if (syswrite $$im_socket,$ssp_packet)
    {
        $$im_socket->flush();
	$imsg->{'client_seq_number'}++;
	return $SFLAP_SUCCESS;
    }

# if we fall through to here, we have a problem
    $main::IM_ERR = $SFLAP_ERR_SEND;
    return undef;
}

=cut

=head2 $aim->srv_socket()

This method returns a reference to the socket to which the server is
connected.  It must be dereferenced before it can be used.  Thus:

C<$foo = $aim-E<gt>srv_socket();>
C<recv($$foo, $recv_buffer, $length, $flags);>

Most users will never need to directly access the server socket.

For more information, see the B<TOC(7)> manpage and B<ROLLING YOUR
OWN> below.

=cut

sub srv_socket
{
#
# takes no arguments
#
# returns a reference to the socket on which we communicate
# with the server
#
    my $imsg = shift @_;

    return \$imsg->{'im_socket'};
}

########################################################
# MISCELLANEOUS FUNCTIONS
# these serve important functions, but
# are not directly accessed by the user 
# of the Net::AOLIM package
########################################################

=pod

=head2 $aim->pw_roast($password)

This method returns the 'roasted' version of a password.  A roasted
password is the original password XORed with the roast string
'Tic/Toc' (which is repeated until the length is the same as the
password length).

This method is called automatically in $aim->signon.  Most users will
never need this method.

For more information, see the B<TOC(7)> manpage and B<ROLLING YOUR
OWN> below.

=cut

sub pw_roast
{
#
# this takes one argument, the
# password, and returns the roasted 
# string
#
    my $imsg = shift @_;
    my $pr_password = $_[0];
    my $pr_len = (length $pr_password) * 8;
    my $pr_roasted;
    my $pr_roasted_bits;
    my $pr_roast_string = '01010100011010010110001100101111010101000110111101100011';
    my $pr_password_bits = unpack("B*", pack("a".$pr_len, $pr_password));

    unless (defined $pr_password)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }
    
    for ($i = 0; $i < $pr_len; $i++)
    {
	my $bit1 = substr $pr_password_bits, $i, 1;
	my $bit2 = substr $pr_roast_string, ($i % 56), 1;
	my $newbit = $bit1 ^ $bit2;
	$pr_roasted_bits .= $newbit;
    }

    $pr_roasted = "0x" . (unpack "H*", (pack "B*", $pr_roasted_bits));

    return $pr_roasted;
}

=pod

=head2 $aim->norm_uname($username)

This method returns the 'normalized' version of a username.  A
normalized username has all spaces removed and is all lowercase.  All
usernames sent to the server should be normalized first if they are an
argument to a TOC command.

All methods in this class automatically normalize username arguments
to the server; thus, most users will never use this method.

For more information, see the B<TOC(7)> manpage and B<ROLLING YOUR
OWN> below.

=cut

sub norm_uname
{
#
# this takes one argument, the
# username to normalize
#
# returns the normalized username
#
    my $imsg = shift @_;
    my $nu_username = $_[0];

    unless (defined $nu_username)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    $nu_username =~ s/ //g;
    $nu_username = "\L$nu_username\E";
}

=pod

=head2 $aim->toc_format_msg($command[, $arg1[, arg2[, ...]]])

This method formats a message properly for sending to the TOC server.
That is, it is escaped and quoted, and the fields are appended with
spaces as specified by the protocol.

Note that all methods in this class automatically format messages
appropriately; most users will never need to call this method.

See B<TOC(7)> and B<ROLLING YOUR OWN> below.

=cut

sub toc_format_msg
{
#
# this takes at least one argument.
# the first argument will be returned unaltered
# at the beginning of the string which is a
# join (with spaces) of the remaining arguments
# after they have been properly escaped and quoted.
#
    my $imsg = shift @_;
    my $toc_command = shift @_;
    my $escaped;
    my $finalmsg;
    
    unless (defined $toc_command)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    if (@_)
    {
	foreach $arg (@_)
	{
	    $escaped = $arg;
	    $escaped =~ s/([\$\{\}\[\]\(\)\"\\\'])/\\$1/g;
	    $finalmsg .= ' "' . $escaped. '"';
	}
    }
    else
    {
	$finalmsg = "";
    }

    $finalmsg = $toc_command . $finalmsg;
    
    return $finalmsg;
}

=pod

=head2 $aim->toc_format_login_msg($command[, $arg1[, arg2[, ...]]])

This method formats a login message properly for sending to the TOC
server.  That is, all fields are escaped, but only the user_agent
field is quoted.  Fields are separated with spaces as specified in the
TOC protocol.

Note that the login procedure calls this function automatically; the
user will probably never need to use it.

See B<TOC(7)> and B<ROLLING YOUR OWN> below.

=cut

sub toc_format_login_msg
{
#
# this takes at least one argument.
# the first argument will be returned unaltered
# at the beginning of the string which is a
# join (with spaces) of the remaining arguments
# after they have been properly escaped and quoted.
#
    my $imsg = shift @_;
    my $toc_command = shift @_;
    my $useragentstr = pop @_;
    my $escaped;
    my $finalmsg;
    
    unless (defined $toc_command)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    if (@_)
    {
	foreach $arg (@_)
	{
	    $escaped = $arg;
	    $escaped =~ s/([\$\{\}\[\]\(\)\"\\\'])/\\$1/g;
	    $finalmsg .= ' ' . $escaped. '';
	}
    }
    else
    {
	$finalmsg = "";
    }

    $useragentstr =~ s/([\$\{\}\[\]\(\)\"\\\'])/\\$1/g;

    $finalmsg = $toc_command . $finalmsg . ' "' . $useragentstr . '"';
    
    return $finalmsg;
}

############################################################
# TOC Interface functions
#
# These are the functions that the Net::AOLIM package user
# will most often interface with; these are basically
# directly mapped to TOC functions of the same name
############################################################

=pod

=head2 $aim->toc_send_im($uname, $msg, $auto)

This method sends an IM message C<$msg> to the user specified by
C<$uname>.  The third argument indicates whether or not this IM should
be sent as an autoreply, which may produce different behavior from the
remote client (but has no direct effect on the content of the IM).

=cut

sub toc_send_im
{
#
# takes three arguments:
#
# tsi_uname: the username to send the packet to
# tsi_msg: the message to send
# tsi_auto: if this should be an autoreply packet, set
#           this to true
#
# returns $TOC_SUCCESS on success, or undef on
# error (and $main::IM_ERR is set with an error code)
#
    my $imsg = shift @_;
    my $tsi_uname = $_[0];
    my $tsi_msg = $_[1];

    unless ((defined $imsg) && (defined $tsi_uname) && (defined $tsi_msg))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tsi_full_msg = $imsg->toc_format_msg("toc_send_im",$imsg->norm_uname($tsi_uname),$tsi_msg);

    if ($tsi_auto)
    {
	$tsi_full_msg .= " auto";
    }

    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tsi_full_msg, 0, 0)));

    return $TOC_SUCCESS;
}

#*****************************************************
# Buddy functions
#
# all of these have to do with buddy functions, such
# as adding and removing buddies from your buddy list
#*****************************************************

=pod

=head2 $aim->add_buddies($group, $buddy1[, $buddy2[, ...]])

This method, which should only be called B<before signon()>, adds
buddies to the initial local buddy list in group C<$group>.  Once
C<signon()> is called, use add_online_buddies instead.

=cut

sub add_buddies
{
#
# takes at least two arguments.
#
# the first argument is the name of
# the group that the names after it will
# be added to.
# 
# each arg is taken to be a buddy
# in the user's buddy list which is
# sent during signon.
#
    my $imsg = shift @_;
    my $ib_group = shift @_;
    
    unless ((defined $ib_group) && (defined $_[0]))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    ($ { $imsg->{'buddies'} }{$ib_group} = []) unless (scalar @{$ { $imsg->{'buddies'} }{$ib_group}});
    
    my @norm_buddies;

    foreach $buddy (@_)
    {
	my $norm_buddy = $imsg->norm_uname($buddy);
	unshift @norm_buddies, $norm_buddy;
    }

    my %union;

    foreach $e (@norm_buddies, @ { $ { $imsg->{'buddies'}}{$ib_group}})
    {
	$union{$e}++;
    }

    @ { $ { $imsg->{'buddies'}}{$ib_group}} = keys %union;
}

sub remove_buddies
{
#
# takes at least one argument
#
# each argument is taken to be
# a buddy which will be removed
# from the buddy list
#
    my $imsg = shift @_;

    unless (defined $_[0])
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my @norm_buddies;

    foreach $buddy (@_)
    {
	my $norm_buddy = $imsg->norm_uname($buddy);
	unshift @norm_buddies, $norm_buddy;
    }

    foreach $group (keys %{$imsg->{'buddies'}})
    {
	my %temp;
	
	map {$temp{$_} = 1;} @ { $ { $imsg->{'buddies'} } {$group} };
	map {delete $temp{$_};} @norm_buddies;
	
	@ { $ { $imsg->{'buddies'} } {$group} } = keys %temp;

	unless (scalar @ { $ { $imsg->{'buddies'} } {$group} })
	{
	    delete $ { $imsg->{'buddies'} }{$group};
	}
    }
}

=pod

=head2 $aim->add_online_buddies($group, $buddy1[, $buddy2[, ...]])

This method takes the same arguments as C<add_buddies()>, but is
intended for use after C<signon()> has been called.

If allow_srv_settings is true (see C<new()>), it will also set the
settings on the server to the new settings.

=cut

sub add_online_buddies
{
#
# takes at least two arguments
#
# this should be called only after signon
# adds all arguments after the firist as buddies 
# to the buddy list.  the first argument is
# the name of the group in which to add them
# 
# if you want to add people to your initial buddy
# list, us im_buddies()
#
# returns undef on error
#
    my $imsg = shift @_;

    return undef unless (defined $imsg->add_buddies(@_));

    $imsg->toc_set_config();
}

=pod

=head2 $aim->remove_online_buddies($buddy1[, $buddy2[, ...]])

Removes all arguments from the buddy list (removes from all groups).

If allow_srv_settings is true (see C<new()>), it will also set the
settings on the server to the new settings.

=cut

sub remove_online_buddies
{
#
# takes at least one argument
#
# this should be called only after signon
# removes all arguments from the buddy list.  
#
# returns undef on error
#
    my $imsg = shift @_;
    
    return undef unless (defined $imsg->remove_buddies(@_));

    my $rob_message = $imsg->toc_format_msg('toc_remove_buddy', @_);

    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $rob_message, 0, 0)));
    
    if ($imsg->{'allow_srv_settings'})
    {
	$imsg->toc_set_config();
    }
}

sub set_srv_buddies
{
#
# adds buddies in our list from the server
#
# takes one argument, the CONFIG string from the 
# server
#
    my $imsg = shift @_;
    my $srv_buddy_list = $_[0];
    
    return unless ($imsg->{'allow_srv_settings'});

    $srv_buddy_list =~ s/^CONFIG://;

    return unless (@srv_buddies = split "\n", $srv_buddy_list);

    for ($i=0; $i < scalar (@srv_buddies); $i++)
    {
	if ($srv_buddies[$i] =~ /^g\s*(.*)/)
	{
	    my $group = $1;
	    my $continue = 1;
	    $i++;

	    my @buddylist;

	    while ($continue)
	    {
		if ($srv_buddies[$i] =~ /^b\s*(.*)/)
		{
		    unshift @buddylist, $1;
		    $i++;
		}
		else
		{
		    $i--;
		    $continue = 0;
		}
	    }

	    my %union;

	    foreach $e (@buddylist, @ { $ { $imsg->{'buddies'}}{$group}})
	    {
		$union{$e}++;
	    }

	    @{ $ { $imsg->{'buddies'}}{$group}} = keys %union;
	}
    }
}

=pod

=head2 $aim->current_buddies(\%buddyhash)

This method fills the hash referenced by C<\%buddyhash> with the
currently stored buddy information.  Each key in the returned hash is
the name of a buddy group, and the corresponding value is a list of
the members of that group.

=cut

sub current_buddies
{
#
# takes one argument, a pointer to a hash that should
# be filled with the current users such that each hash
# key is a buddy group and the corresponding value is a
# list of buddies in that group.  Thus, 
#
# @{$hash{"foo"}}
#
# is the list of users in the group called foo
#
    my $imsg = shift @_;
    my $buddyhash = $_[0];

    unless (defined $buddyhash)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    %$buddyhash = % { $imsg->{'buddies'}};
}

=pod

=head2 $aim->current_permits()

This method takes no arguments.  It returns the current 'permit' list.

=cut

sub current_permits
{
#
# takes no arguments
#
# returns a list of the people currently on the "permit" list
#
    my $imsg = shift @_;
    
    return @ {$imsg->{'permit'}};
}

=pod

=head2 $aim->current_denies()

This method takes no arguments.  It returns the current 'deny' list.

=cut

sub current_denies
{
#
# takes no arguments
#
# returns a list of the people currently on the "deny" list
#
    my $imsg = shift @_;
    
    return @ {$imsg->{'deny'}};
}

#*********************************************************
# ACCESS PERMISSION OPTIONS
#
# these functions affect the users that are permitted to 
# see you; interfaces are provided for both online and
# offline specification of permissions

=pod

=head2 $aim->im_permit($user1[, $user2[, ...]])

This method should only be called B<before signon()>.  It adds all
arguments to the current permit list and deletes the current deny
list.  It also sets the permit mode to 'permit some'.

If you would like to do this while online, use the C<add_im_permit()>
method instead.

=cut

sub im_permit
{
#
# takes at least one argument
#
# each arg is one person to be added
# to the user's permit list.  If a permit
# list is used, only people on the permit
# list will be allowed
#
    my $imsg = shift @_;
    $imsg->{'permit_mode'} = 3;
# if we permit, we can't deny
    $imsg->{'deny'} = [];

    unless (defined $_[0])
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my @norm_permits;

    foreach $permit (@_)
    {
	my $norm_permit = $imsg->norm_uname($permit);
	unshift @norm_permits, $norm_permit;
    }

    my %union;

    foreach $e (@norm_permits, @{ $imsg->{'permit'}})
    {
	$union{$e}++;
    }

    @{ $imsg->{'permit'}} = keys %union;
}

=pod

=head2 $aim->im_deny($user1[, $user2[, ...]])

This method should only be called B<before signon()>.  It adds all
arguments to the current deny list and deletes the current permit
list.  It also sets the permit mode to 'deny some'.

If you would like to do this while online, use the C<add_im_permit()>
method instead.

=cut

sub im_deny
{
#
# takes at least one argument
#
# each arg is one person to be added
# to the user's deny list.  If a deny
# list is used, only people on the deny
# list will be denied
#
    my $imsg = shift @_;
    $imsg->{'permit_mode'} = 4;
# if we deny, we can't permit
    $imsg->{'permit'} = [];

    unless (defined $_[0])
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my @norm_denies;

    foreach $deny (@_)
    {
	my $norm_deny = $imsg->norm_uname($deny);
	unshift @norm_denies, $norm_deny;
    }

    my %union;

    foreach $e (@norm_denies, @ { $imsg->{'deny'}})
    {
	$union{$e}++;
    }

    @ { $imsg->{'deny'}} = keys %union;
}

=pod

=head2 $aim->add_im_permit($user1[, $user2[, ...]])

This is the method that should be called if you are online and wish to
add users to the permit list.  It will, as a consequence, delete the
current deny list and set the current mode to 'permit some'.

=cut

sub add_im_permit
{
#
# takes at least one argument
#
# each argument is added to the permit
# list.  If a permit list is used, only
# the people on the permit list will
# be allowed.
#
# this should only be called after signon is completed
# if you want to do permit before then, use im_permit
# 
    my $imsg = shift @_;

    return undef unless (defined $imsg->im_permit(@_));
    
    $imsg->toc_set_config();
}

=pod

=head2 $aim->add_im_deny($user1[, $user2[, ...]])

This is the method that should be used if you are online and wish to
add users to the deny list.  It will, as a consequence, delete the
current permit list and set the current mode to 'deny some'.

=cut

sub add_im_deny
{
#
# takes at least one argument
#
# each argument is added to the deny
# list.  If a deny list is used, only
# the people in the deny list will be
# banned
#
# this should be called after signon is completed
# if you want to do deny before then, use im_deny
# 
    my $imsg = shift @_;

    return undef unless (defined $imsg->im_deny(@_));
    
    $imsg->toc_set_config();
}

=pod

=head2 $aim->im_deny_all()

This method should be called only B<before signon()>.  It will delete
both the permit and deny list and set the mode to 'deny all'.

=cut

sub im_deny_all
{
#
# takes no arguments
#
# sets mode to deny all
#
    my $imsg = shift @_;
    $imsg->{'permit_mode'} = 2;

# clear the permit and deny lists
    $imsg->{'permit'} = [];
    $imsg->{'deny'} = [];
}

=pod

=head2 $aim->im_permit_all()

This method should be called only B<before signon()>.  It will delete
both the permit and deny list and set the mode to 'permit all'.

=cut

sub im_permit_all
{
#
# takes no arguments
#
# sets mode to allow all
#
    my $imsg = shift @_;
    $imsg->{'permit_mode'} = 1;

    $imsg->{'permit'} = [];
    $imsg->{'deny'} = [];
}

=pod

=head2 $aim->add_im_deny_all()

This is the method that should be used if you are online and wish to
go into 'deny all' mode.  It will also delete both the permit and deny
lists.

=cut

sub add_im_deny_all
{
#
# takes no arguments
#
# sets mode to deny all
#
# use this only when connected; otherwise,
# if you want to set before connecting, use
# im_deny_all
#
    my $imsg = shift @_;
    
    $imsg->im_deny_all;

    my $aida_message = $imsg->toc_format_msg('toc_add_permit');

    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $aida_message, 0, 0)));

    if ($imsg->{'allow_srv_settings'})
    {
	$imsg->toc_set_config;
    }
}

=pod

=head2 $aim->add_im_permit_all()

This is the method that should be used if you are online and wish to
go into 'permit all' mode.  It will also delete both the permit and
deny lists.

=cut

sub add_im_permit_all
{
#
# takes no arguments
#
# sets mode to allow all
#
# use this only when connected; otherwise,
# if you want to set before connecting, use
# im_permit_all
#
    my $imsg = shift @_;

    $imsg->im_permit_all;
    
    my $aipa_message = $imsg->toc_format_msg('toc_add_deny');

    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $aipa_message, 0, 0)));

    if ($imsg->{'allow_srv_settings'})
    {
	$imsg->toc_set_config;
    }
}

sub toc_set_config
{
#
# takes no arguments
#
# sets the config on the server
# so that it is carried from session
# to session by the server
#
# this is called at signon and
# after each call to add_im_buddies 
# or remove_im_buddies
#
# In V1.6, this function was modified so that
# if there are no currently defined buddies,
# the current user is set as a buddy in group
# "Me".  This is necessary because an empty
# buddy list will cause signon to fail.
#
# returns undef on error
#
    my $imsg = shift @_;
    
    my $tsc_config_info;
    my $tsc_packet;
    my $tsc_permit_mode = $imsg->{'permit_mode'};

    if (scalar(keys %{$imsg->{'buddies'}}))
    {
        foreach $group (keys %{$imsg->{'buddies'}})
        {
            my $aob_message = $imsg->toc_format_msg('toc_add_buddy', $group, @ { $ { $imsg->{'buddies'} } {$group} });

            return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $aob_message, 0, 0)));
            
            if ($imsg->{'allow_srv_settings'})
            {
                $tsc_config_info .= "g $group\n";
                
                foreach $buddy (@ { $ { $imsg->{'buddies'} } {$group} })
                {
                    $tsc_config_info .= "b $buddy\n";
                }
            }
        }
    }
    else
    {
        my $aob_message = $imsg->toc_format_msg('toc_add_buddy', 'Me', $imsg->{'username'});
        return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $aob_message, 0, 0)));
    }
        
    if (scalar @ { $imsg->{'permit'} })
    {
	my $aip_message = $imsg->toc_format_msg('toc_add_permit', @ { $imsg->{'permit'} });
	
	return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $aip_message, 0, 0)));
	
	if ($imsg->{'allow_srv_settings'})
	{
	    foreach $permit (@ { $imsg->{'permit'} })
	    {
		$tsc_config_info .= "p $permit\n";
	    }
	}
    }

    if (scalar @ { $imsg->{'deny'} })
    {
	my $aid_message = $imsg->toc_format_msg('toc_add_deny', @_);
	
	
	return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $aid_message, 0, 0,)));
	
	if ($imsg->{'allow_srv_settings'})
	{
	    foreach $deny (@ { $imsg->{'deny'} })
	    {
		$tsc_config_info .= "d $deny\n";
	    }
	}
    }

    if ($imsg->{'allow_srv_settings'})
    {
	$tsc_config_info .= "m $tsc_permit_mode\n";
        $tsc_config_info = "{" . $tsc_config_info . "}";

	$tsc_packet = 'toc_set_config ' . $tsc_config_info . "\0";
	
	return undef unless (defined $imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tsc_packet, 1, 1));
    }
}

=pod

=head2 $aim->toc_evil($user, $anon)

This method will apply 'evil' to the specified user C<$user>.  If
C<$anon> evaluates to true, the evil will be done anonymously.

=cut

sub toc_evil
{
#
# takes two arguments
#
# the first argument is the
# username to evil
# the second argument should be
# 1 if the evil should be sent
# anonymously
#
# returns undef if an error occurs
#
    my $imsg = shift @_;
    my $te_user = $_[0];
    my $te_anon = ($_[1] ? 'anon' : 'norm');

    unless ((defined $te_user) && (defined $te_anon))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $te_evil_msg = $imsg->toc_format_msg('toc_evil', $imsg->norm_uname($te_user), $te_anon);

    
    return undef unless (defined $imsg->send_sflap_packet($SFLAP_TYPE_DATA, $te_evil_msg, 0, 0));
}

=pod

=head2 $aim->toc_chat_join($exchange, $room_name)

This method will join the chat room specified by C<$exchange> and
C<$room_name>.  Currently, the only valid value for C<$exchange> is 4.

See the B<TOC(7)> manpage included with this package for more
information on chatting.

=cut

sub toc_chat_join
{
#
# takes two arguments
#
# exchange  : the chat room exchange number to use
# room_name : the name of the room to join
#
# returns undef on error
#
# this function does not get the chat room ID; 
# that is handled when the server sends back the
# CHAT_JOIN packet, and we have a handler for that
# in the incoming handler
#
    my $imsg = shift @_;
    my $tcj_exchange = $_[0];
    my $tcj_room_name = $_[1];

    $tcj_room_name =~ s/\s+/ /g;


    unless ((defined $tcj_exchange) && (defined $tcj_room_name))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tcj_message = $imsg->toc_format_msg('toc_chat_join', $tcj_exchange, $tcj_room_name);

    
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tcj_message, 0, 0)));
}

=pod

=head2 $aim->toc_chat_send($roomid, $message)

This method will send the message C<$message> to the room C<$roomid>
(which should be the room ID provided by the server in response to a
toc_chat_join or toc_accept_invite).

You will receive this message back from the server as well, so your UI
does not have to handle this message in a special way.

=cut

sub toc_chat_send
{
#
# takes two arguments
#
# roomid : the chat room ID as returned by the CHAT_JOIN server message
# message: the message to send to the chat room
#
# no mirroring is necessary; the message will come to you by way of the
# server, so you'll see your own message automatically
#
# returns undef on error
#
    my $imsg = shift @_;
    my $tcs_roomid = $_[0];
    my $tcs_msgtext = $_[1];

    unless ((defined $tcs_roomid) && (defined $tcs_msgtext))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tcs_message = $imsg->toc_format_msg('toc_chat_send', $tcs_roomid, $tcs_msgtext);

    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tcs_message, 0, 0)));
}

=pod

=head2 $aim->toc_chat_whisper($roomid, $dstuser, $message)

This method sends the message C<$message> to C<$dstuser> in the room
C<$roomid>.

The server will B<not> send you a copy of this message, so your user
interface should have a special case for displaying outgoing whispers.

=cut

sub toc_chat_whisper
{
#
# takes three arguments:
#
# roomid : the chat room ID as returned by the CHAT_JOIN server message
# dstuser: the user to whom the whisper should be directed
# message: the message to send to the user as a whisper
#
# you should mirror this to your UI if you want to see it go there as well,
# because the server will not send you a copy of this message as it does with
# regular chat messages.
#
    my $imsg = shift @_;
    my $tcw_roomid = $_[0];
    my $tcw_dstuser = $_[1];
    my $tcw_msgtext = $_[2];

    unless ((defined $tcw_roomid) && (defined $tcw_dstuser) && (defined $tcw_msgtext))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tcw_message = $imsg->toc_format_msg('toc_chat_whisper', $tcw_roomid, $imsg->norm_uname($tcw_dstuser), $tcw_msgtext);
    
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tcs_message, 0, 0)));
}

=pod

=head2 $aim->toc_chat_evil($roomid, $dstuser, $anon)

This will apply evil to the user C<$dstuser> in room C<$room>.  If
C<$anon> evaluates to true, it will be applied anonymously.

Please note that this functionality is currently disabled by the TOC
servers.

=cut

sub toc_chat_evil
{
#
# takes three arguments:
#
# roomid : the chat room ID as returned by the CHAT_JOIN server message
# dstuser: the user that should be eviled
# isanon : should be 1 if the evil should be registered anonymously
#
# returns undef on error
#
# the chat evil functionality is currently disabled at the server end
#
    my $imsg = shift @_;
    my $tce_roomid = $_[0];
    my $tce_dstuser = $_[1];
    my $tce_anon = ($_[2] ? 'anon' : 'norm');

    unless ((defined $tce_roomid) && (defined $tce_dstuser) && (defined $tce_anon))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tce_message = $imsg->toc_format_msg('toc_chat_evil', $tce_roomid, $imsg->norm_uname($tce_dstuser), $tce_anon);
    
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tce_message, 0, 0)));
}

=pod

=head2 $aim->toc_chat_invite($roomid, $msgtext, $buddy1[, $buddy2[, ...]])

This method will invite all users C<$buddy1..$buddyN> to room
C<$roomid> with invitation text C<$msgtext>.

=cut

sub toc_chat_invite
{
#
# takes at least three arguments:
#
# roomid : the chat room ID as returned by the CHAT_JOIN server message
# msgtext: the text of the invitation message
# buddy1...buddyn : the buddies to invite to the room.  You can have as many
#                   as you'd like, up to the max message length (1024)
#
# returns undef on error
#
    my $imsg = shift @_;
    my $tci_roomid = shift @_;
    my $tci_msgtext = shift @_;
    my @tci_buddies = @_;

    unless ((defined $tci_roomid) && (defined $tci_msgtext) && (@tci_buddies))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    while (my $tci_tmp_buddy = shift @_)
    {
	push @tci_buddies, $imsg->norm_uname($tci_tmp_buddy);
    }

    my $tci_message = $imsg->toc_format_msg('toc_chat_invite', $tci_roomid, $tci_msgtext, @tci_buddies);

    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tci_message, 0, 0)));
}

=pod

=head2 $aim->toc_chat_leave($roomid)

This method will notify the server that you have left room C<$roomid>.

=cut

sub toc_chat_leave
{
#
# takes one argument:
#
# roomid : the room ID as returned by the CHAT_JOIN server message
#
# returns undef on error
#
    my $imsg = shift @_;
    my $tcl_roomid = $_[0];

    unless (defined $tcl_roomid)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
    }

    my $tcl_message = $imsg->toc_format_msg('toc_chat_leave', $tcl_roomid);

    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tcl_message, 0, 0)));
}

=pod

=head2 $aim->toc_chat_accept($roomid)

This method accepts a chat invitation to room C<$roomid>.  You do not
have to send a C<toc_chat_join()> message if you have been invited and
accept with this method.

=cut

sub toc_chat_accept
{
#
# takes one argument:
#
# roomid : the room ID as given by the CHAT_INVITE server message
#
# returns undef on error
#
    my $imsg = shift @_;
    my $tca_roomid = $_[0];

    unless (defined $tca_roomid)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tcl_message = $imsg->toc_format_msg('toc_chat_accept', $tca_roomid);
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tcl_message, 0, 0)));
}

=pod

=head2 $aim->toc_get_info($username)

This method requests info on user C<$username>.  See B<TOC(7)> for more
information on what the server returns.

=cut

sub toc_get_info
{
#
# takes one argument:
#
# username: the username of the person on whom to get info
#
# returns undef on error
#
    my $imsg = shift @_;
    my $tgi_username = $_[0];

    unless (defined $tgi_username)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tgi_message = $imsg->toc_format_msg('toc_get_info', $tgi_username);
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tgi_message, 0, 0)));
}

=pod

=head2 $aim->toc_set_info($info)

This method sets the information for the current user to the ASCII
text (HTML formatted) contained in C<$info>.

=cut

sub toc_set_info
{
#
# takes one argument:
#
# information : the information of the user as HTML
#
# returns undef on error
#
    my $imsg = shift @_;
    my $tsi_info = $_[0];

    unless (defined $tsi_info)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tsi_message = $imsg->toc_format_msg('toc_set_info', $tsi_info);
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tsi_message, 0, 0)));
}

=pod

=head2 $aim->toc_set_away($msg)

This method sets or unsets the away message.  If C<$msg> is undefined,
away is unset.  Otherwise, away is set with the message in C<$msg>.

=cut

sub toc_set_away
{
#
# takes zero or one arguments:
#
# awaymsg: the away message.  If not specified, the away status is unset
#
    my $imsg = shift @_;
    my $tsa_awaymsg = $_[0];

    my $tsa_message = $imsg->toc_format_msg('toc_set_away', $tsa_awaymsg);
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tsa_message, 0, 0)));
}

=pod

=head2 $aim->toc_get_dir($username)

This method sends a request to the server for directory information on
C<$username>.  See B<TOC(7)> for information on what the server will return.

=cut

sub toc_get_dir
{
#
# takes one argument
#
# username : the username of the person whose dir info to retrieve
#
    my $imsg = shift @_;
    my $tgd_username = $_[0];

    unless (defined $tgd_username)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tgd_message = $imsg->toc_format_msg('toc_get_dir', $imsg->norm_uname($tgd_username));
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tgd_message, 0, 0)));
}

=pod

=head2 $aim->toc_set_dir($userinfo)

This method sets the information on the current user to the string
provided as C<$userinfo>.  See B<TOC(7)> for more information on the
format of the C<$userinfo> string.

=cut

sub toc_set_dir
{
#
# takes one argument
#
# userinfo : the user information for the TOC directory.  This should be specified as
# "first name":"middle name":"last name":"maiden name":"city":"state":"country":"email":"allow web searches"
#
    my $imsg = shift @_;
    my $tsd_userinfo = $_[0];

    unless (defined $tsd_userinfo)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tsd_message = $imsg->toc_format_msg('toc_set_dir', $tsd_userinfo);
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tsd_message, 0, 0)));
}

=pod

=head2 $aim->toc_dir_search($searchstr)

This method will search the directory using C<$searchstr>.  See
B<TOC(7)> for more information on how this string should look.

=cut

sub toc_dir_search
{
#
# takes one argument
#
# searchstr : the string of information to search for.  This should be specified as
# "first name":"middle name":"last name":"maiden name":"city":"state":"country":"email"
#
    my $imsg = shift @_;
    my $tds_searchstr = $_[0];

    unless (defined $tds_searchstr)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    my $tds_message = $imsg->toc_format_msg('toc_dir_search', $tds_searchstr);
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tds_message, 0, 0)));
}

=pod

=head2 $aim->toc_set_idle($seconds)

This method sets the number of seconds that the client has been idle.
If it is 0, the idle is cleared.  Otherwise, the idle is set and the
server will continue to count up the idle time (thus, you need only
call C<idle()> once in order to become idle).

=cut

sub toc_set_idle
{
#
# takes one argument:
#
# seconds : the number of seconds the user has been idle.  use 0 to clear the
#           idle counter and stop idle counting.  Setting it to any other
#           value will make the server set that idle time and continue to increment
#           the idle time, so only one is necessary to start idle timing
#
# returns undef on error
#
    my $imsg = shift @_;
    my $tsi_seconds = $_[0];

    unless (defined $tsi_seconds)
    {
	$tsi_seconds = 0;
    }

    my $tsi_message = $imsg->toc_format_msg('toc_set_idle', $tsi_seconds);
    
    return undef unless (defined ($imsg->send_sflap_packet($SFLAP_TYPE_DATA, $tsi_message, 0, 0)));
}

#*****************************************************
# Module interface/data movement functions
#
# these functions have to do with checking whether input
# is ready and allowing the user to request that we block
# on the filehandles that we have in our select loop 
# (including user-added filehandles) until something happens
#*****************************************************

=pod

=head2 $aim->ui_add_fh($filehandle, \&callback)

This method will add a filehandle to the C<select()> loop that will be
called with C<ui_dataget()>.  If information is found to be on that
filehandle, the callback will be executed.  It is the responsibility
of the callback to read the data off the socket.

B<As always, the use of buffered IO on filehandles being select()ed
is unreliable at best.  Avoid the use of read(), E<lt>FHE<gt>, and print();
instead, use sysread() and syswrite()>

=cut

sub ui_add_fh
{
#
# takes two arguments:
#
# filehandle : a filehandle to add to the select loop
#              this should be a reference to the filehandle (or
#              a scalar containing the reference, such as the one
#              returned by IO::Socket)
# callback   : the callback function to call when data comes
#              over the selected filehandle.  This function will
#              be called with the data that came over the filehandle
#              as the argument.  This should be passed as a reference
#              to the function
#
    my $imsg = shift @_;
    my $fh = $_[0];
    my $cb = $_[1];

    unless ((defined $fh) && (defined $cb))
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    $imsg->{'sel'}->add($fh);
    $ { $imsg->{'callbacks'} }{$fh} = $cb;
}

=pod

=head2 $aim->ui_del_fh($filehandle)

The filehandle C<$filehandle> will be removed from the C<select()>
loop and it will no longer be checked for input nor its callback
activated.

=cut

sub ui_del_fh
{
#
# takes one argument:
#
# filehandle : the filehandle to delete from the select loop
#              this should be the same reference or scalar that
#              was passed to ui_add_fh
#
    my $imsg = shift @_;
    my $fh = $_[0];

    unless (defined $fh)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }
	
    $imsg->{'sel'}->remove($fh);
    delete $ { $imsg->{'callbacks'} }{$fh};
}

=pod

=head2 $aim->ui_all_fh()

This method returns a list of all filehandles currently in the
C<select()> loop.

=cut

sub ui_all_fh
{
#
# takes no arguments
#
# returns a list of all the current filehandles
# in the select loop
#
    my $imsg = shift @_;

    return $imsg->{'sel'}->handles();
}

=pod

=head2 $aim->ui_exists_fh($filehandle)

This method will return true if C<$filehandle> is in the select loop.
Otherwise, it will return undefined.

=cut

sub ui_exists_fh
{
#
# takes one argument
#
# filehandle : the filehandle to check for existence in 
#              the select loop
#
# returns a true value if filehandle is in the loop, and
# undefined otherwise
#
    my $imsg = shift @_;
    my $fh = $_[0];

    return $imsg->{'sel'}->exists($fh);
}

=pod

=head2 $aim->ui_set_callback(\&callback)

This method will change the callback function for the server socket to
the method referenced by \&callback.  This allows you to change the
callback from the one specified when the object was created.  (Imagine
the possibilities--dynamically created callback functions using
C<eval()>... mmmm...)

=cut

sub ui_set_callback
{
#
# takes one argument:
#
# callback : a reference to the callback function
#            for incoming remote data
#
# to set the callback for a user-defined filehandle,
# use the ui_add_fh function
#
    my $imsg = shift @_;
    my $callback = $_[0];
    my $im_socket = \$imsg->{'im_socket'};

    unless (defined $callback)
    {
	$main::IM_ERR = $SFLAP_ERR_ARGS;
	return undef;
    }

    $imsg->{'callback'} = $callback;
}

=pod

=head2 $aim->ui_get_callback($filehandle)

This method returns a reference to the callback associated with
$filehandle, or the callback associated with the server socket if
$filehandle is undefined.

=cut

sub ui_get_callback
{
#
# takes zero or one arguments:
#
# filehandle : the filehandle whose callback should be returned
#
# if filehandle is not specified, the a reference to the callback
# for the server socket is returned
#
    my $imsg = shift @_;
    my $fh = $_[0];

    if (defined $fh)
    {
	return $ { $imsg->{'callbacks'}}{$fh};
    }
    else
    {
	return $imsg->{'callback'};
    }
}

=pod

=head2 $aim->ui_dataget($timeout)

This is the workhorse method in this object.  When this method is
called, it will go through a single C<select()> loop to find if any
filehandles are ready for reading.  If $timeout is defined, the
C<select()> timeout will be that number of seconds (fractions are OK).
Otherwise, C<select()> will block.

For each filehandle that is ready for reading, this function will call
the appropriate callback function.  It is the responsibility of the
callback to read the data off the filehandle and handle it
appropriately.  The exception to this rule is the server socket, whose
data will be read and passed to the server socket callback function.
All pasrsing of data from the server into edible chunks will be done
for you before the server socket callback function is called.  From
there, it is up to to the client program to parse the server responses
appropriately.  They will be passed such that each field in the server
response is one argument to the callback (the number of arguments will
be correct).  For more information on the information coming from the
server, see B<TOC(7)>.

This method returns undef on an error (including errors from
callbacks, which should be signified by returning undef) and returns
the number of filehandles that were read otherwise.

=cut

sub ui_dataget
{
#
# takes zero or one arguments:
#
# time : the time in seconds to wait for the selects to return
#
# if time is undef(), then the call will block
#
# for each filehandle that returns something, the matching
# callback function will be called to read the data and handle
# it.
#
# returns undef on error
#
    my $imsg = shift @_;
    my $timeout = $_[0];
    my $recv_buffer = "";
    my @ready = ();
    my $im_socket = \$imsg->{'im_socket'};

    @ready = $imsg->{'sel'}->can_read($timeout);

    foreach $rfh (@ready)
    {
	if ($rfh == $$im_socket)
	{
            return undef unless defined($recv_buffer = $imsg->read_sflap_packet());
	    ($tp_type, $tp_tmp) = split(/:/, $recv_buffer, 2);
            
# pause if we've been told to by the server
            if ($tp_type eq 'PAUSE')
            {
                $imsg->{'pause'} = 1;
            }
# re-run signon if we're getting a new SIGN_ON packet
	    elsif ($tp_type eq 'SIGN_ON')
	    {
		$imsg->signon;
	    }
# handle CONFIG packets from the server, respecting
# the allow_srv_settings flag from the user
            elsif ($tp_type eq 'CONFIG')
            {
                $imsg->set_srv_buddies($tp_tmp);
            }
            
            &{$imsg->{'callback'}}($tp_type, split(/:/,$tp_tmp,$SERVER_MSG_ARGS{$tp_type}));
	}
	else
	{
	    return undef unless (&{$ { $imsg->{'callbacks'}}{$rfh}});
	}
    }
    return scalar(@ready);
}

=pod

=head1 ROLLING YOUR OWN

This section deals with usage that deals directly with the server
connection and bypasses the ui_* interface and/or the toc_* interface.
If you are happy calling ui_dataget et al., do not bother reading this
section.  If, however, you plan not to use the provided interfaces, or
if you want to know more of what is going on, continue on.

First of all, if you do not plan to use the provided interface to the
server socket, you will need to be able to access the server socket
directly.  In order to do this, use $aim-E<gt>srv_socket:

    $srv_sock = $aim->srv_socket;

This will return a B<pointer> to the socket.  You will need to
dereference it in order to use it.

In general, however, even if you are rolling your own, you will
probably not need to use C<recv()> or the like.
C<read_sflap_packet()> will handle unwrapping the data coming from the
server and will return the payload of the packet as a single scalar.
Using this will give you the data coming from the server in a form
that you can C<split()> to get the message and its arguments.  In
order to facilitate such splitting, C<%Net::AOLIM::SERVER_MSG_ARGS> is
supplied.  For each valid server message,
C<$Net::AOLIM::SERVER_MSG_ARGS{$msg}> will return one less than the
proper number of splits to perform on the data coming from the server.
The intended use is such:

    ($msg, $rest) = split(/:/, $aim->read_sflap_packet(), 2);
    @msg_args = split(/:/, $rest, $Net::AOLIM::SERVER_MSG_ARGS{$msg});

Now you have the server message in C<$msg> and the arguments in
C<@msg_args>.

To send packets to the server without having to worry about making
SFLAP packets, use C<send_sflap_packet()>.  If you have a string to
send to the server (which is not formatted), you would use:

    $aim->send_sflap_packet($SFLAP_TYPE_DATA, $message, 0, 0);

The SFLAP types (listed in B<TOC(7)> are:

    $SFLAP_TYPE_SIGNON
    $SFLAP_TYPE_DATA
    $SFLAP_TYPE_ERROR
    $SFLAP_TYPE_SIGNOFF
    $SFLAP_TYPE_KEEPALIVE

Most of the time you will use $SFLAP_TYPE_DATA.

If you want to roll your own messages, read the code for
C<send_sflap_packet()> and you should be able to figure it out.  Note
that the header is always supplied by C<send_sflap_packet()>.
Specifying C<formatted> will only make C<send_sflap_data()> assume
that C<$message> is a preformatted payload.  Specifying C<$noterm>
will prevent C<send_sflap_packet()> from adding a trailing '\0' to the
payload.  If it is already formatted, C<send_sflap_packet> will ignore
C<$noterm>.

Messages sent to the server should be escaped and formatted properly
as defined in B<TOC(7)>.  C<$aim-E<gt>toc_format_msg> will do just this;
supply it with the TOC command and the arguments to the TOC command
(each as separate strings) and it will return a single string that is
formatted appropriately.

All usernames sent as TOC command arguments must be normalized (see
B<TOC(7)>).  C<$aim-E<gt>norm_uname()> will do just this.  Make sure to
normalize usernames before passing them as arguments to
C<$aim-E<gt>toc_format_msg()>.

C<pw_roast> performs roasting as defined in B<TOC(7)>.  It is not very
exciting.  I do not see why it is that you would ever need to do this,
as C<$aim-E<gt>signon()> handles this for you (and the roasted password is
stored in C<$aim-E<gt>{'roastedp'}>).  However, if you want to play with
it, there it is.

=head1 EXAMPLES

See the file F<example.pl> for an example of how to interact with
this class.

=head1 FILES

F<example.pl>
    
    A sample client that demonstrates how this object could be used.

=head1 SEE ALSO

See also B<TOC(7)>.

=head1 AUTHOR

Copyright 2000-02 Riad Wahby E<lt>B<rsw@jfet.org>E<gt> All rights reserved
This program is free software.  You may redistribute it and/or
modify it under the same terms as Perl itself.

=head1 HISTORY

B<0.01>

    Initial Beta Release. (7/7/00)

B<0.1>

    First public (CPAN) release. (7/14/00)

B<0.11>

    Re-release under a different name with minor changes to the 
    documentation. (7/16/00)

B<0.12>

    Minor modification to fix a condition in which the server's
    connection closing could cause an infinite loop.

B<1.0>

    Changed the client agent string to TOC1.0 to fix a problem where
    connections were sometimes ignored.  Also changed the default signon
    port to 5198 and the login port to 1234.

B<1.1>

    Changed the client agent string again, this time to what seems
    like the "correct" format, which is
            PROGRAM:$Version info$
    Also added the ability to set a login timeout in case the SIGN_ON
    packet never comes.

B<1.2>

    Fixed a bug in toc_chat_invite that made it ignore some of its
    arguments.  This should fix various problems with using this
    subroutine.  Thanks to Mike Golvach for pointing this out.

B<1.3>

    Changed (defined @tci_buddies) to (@tci_buddies) in toc_chat_invite.
    Fixed a potential infinite loop in set_srv_buddies involving an
    off-by-one error in a for() test.  Thanks to Bruce Winter for
    pointing this out.

B<1.4> 

    Changed the way that Net::AOLIM sends the login command string
    because AOL apparently changed their server software, breaking the
    previous implementation.  The new method requires that only the
    user agent string be in double quotes; all other fields should not
    be quoted.  Note that this does not affect the user interface at
    all---it's all handled internally.  Thanks to Bruce Winter, Fred
    Frey, Aryeh Goldsmith, and tik for help in tracking down and
    fixing this error.

    Also added additional checks to read_sflap_packet so that if the
    other end of the connection dies we don't go into an infinite
    loop.  Thanks to Chris Nelson for pointing this out.

B<1.5>

    Added a very simple t/use.t test script that just makes sure
    the module loads properly.

B<1.6>

    Patched around yet another undocumented "feature" of the TOC
    protocol---namely, in order to successfully sign on, you must have
    at least one buddy in your buddy list.  At sign-on, in the absence
    of a real buddy list, Net::AOLIM inserts the current user as a
    buddy in group "Me."  Don't bother removing this buddy, as it
    doesn't really exist---as soon as you add any real buddies, this
    one will go away.  Thanks to Galen Johnson and Jay Luker for
    emailing with the symptoms.

=cut
