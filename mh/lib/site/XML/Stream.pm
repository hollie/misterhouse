package XML::Stream;

=head1 NAME

XML::Stream - Creates and XML Stream connection and parses return data

=head1 SYNOPSIS

  XML::Stream is an attempt at solidifying the use of XML via streaming.

=head1 DESCRIPTION

  This module provides the user with methods to connect to a remote server,
  send a stream of XML to the server, and receive/parse an XML stream from
  the server.  It is primarily based work for the Etherx XML router  
  developed by the Jabber Development Team.  For more information about
  this project visit http://etherx.jabber.org/stream/.

  XML::Stream gives the user the ability to define a central callback
  that will be used to handle the tags received from the server.  These
  tags are passed in the format of an XML::Parser::Tree object.  After
  the closing tag of an object is seen, the tree is finished and passed
  to the call back function.  What the user does with it from there is up
  to them.

  For a detailed description of how this module works, and about the data
  structure that it returns, please view the source of Stream.pm and 
  look at the detailed description at the end of the file.

=head1 METHODS

  new(debug=>string,       - creates the XML::Stream object.  debug should
      debugfh=>FileHandle)   be set to the path for the debug log to be
                             written.  If set to "stdout" then the debug
                             will go there.   Also, you can specify a 
                             filehandle that already exists and use that.

  Connect(hostname=>string,  - opens a tcp connection to the specified
          port=>integer,       server and sends the proper opening XML
          myhostname=>string,  Stream tag.  hostname, port, and namespace
          namespace=>array,    are required.  namespaces allows you
          namespaces=>array)   to use XML::Stream::Namespace objects.
                               myhostname should not be needed but if 
                               the module cannot determine your hostname 
                               properly (check the debug log), set this 
                               to the correct value, or if you want
                               the other side of the stream to think that
                               you are someone else.

  Disconnect() - sends the proper closing XML tag and closes the socket
                 down.

  Process(integer) - waits for data to be available on the socket.  If 
                     a timeout is specified then the Process function
                     waits that period of time before returning nothing.  
                     If a timeout period is not specified then the
                     function blocks until data is received.

  OnNode(function pointer) - sets the callback used to handle the
                             XML::Parser::Tree trees that are built
                             for each top level tag.

  GetRoot() - returns the attributes that the stream:stream tag sent by
              the other end listed in a hash.

  GetSock() - returns a pointer to the IO::Socket object.

  Send(string) - sends the string over the connection as is.  This
                 does no checking if valid XML was sent or not.  Best
                 behavior when sending information.

  GetErrorCode() - returns a string that will hopefully contain some
                   useful information about why Process or Connect
                   returned an undef to you.

=head1 EXAMPLES

  ##########################
  # simple example

  use XML::Stream;

  $stream = new XML::Stream;

  my $status = $stream->Connect(hostname => "jabber.org", 
                                port => 5222, 
                                namespace => "jabber:client");

  if (!defined($status)) {
    print "ERROR: Could not connect to server\n";
    print "       (",$stream->GetErrorCode(),")\n";
    exit(0);
  }

  while($node = $stream->Process()) {
    # do something with $node
  }

  $stream->Disconnect();


  ###########################
  # example using a handler

  use XML::Stream;

  $stream = new XML::Stream;
  $stream->OnNode(\&noder);
  $stream->Connect(hostname => "jabber.org",
		   port => 5222,
		   namespace => "jabber:client",
		   timeout => undef) || die $!;

  # Blocks here forever, noder is called for incoming 
  # packets when they arrive.
  while(defined($stream->Process())) { }

  print "ERROR: Stream died (",$stream->GetErrorCode(),")\n";
  
  sub noder
  {
    my $node = shift;
    # do something with $node
  }

=head1 AUTHOR

Tweaked, tuned, and brightness changes by Ryan Eatmon, reatmon@ti.com
in May of 2000.
Colorized, and Dolby Surround sound added by Thomas Charron,
tcharron@jabber.org
By Jeremie in October of 1999 for http://etherx.jabber.org/streams/

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use Socket;
use Sys::Hostname;
use IO::Socket;
use IO::Select;
use XML::Parser;
use vars qw($VERSION $STREAMERROR);

$VERSION = "1.05";
$STREAMERROR = "";

use XML::Stream::Namespace;
($XML::Stream::Namespace::VERSION < $VERSION) &&
  die("XML::Stream::Namespace $VERSION required--this is only version $XML::Stream::Namespace::VERSION");

sub new {
  my $self = { };

  bless($self);

  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  $self->{DEBUGLEVEL} = 1;
  $self->{DEBUGLEVEL} = $args{debuglevel} if exists($args{debuglevel});

  if (exists($args{debugfh}) && ($args{debugfh} ne "")) {
    $self->{DEBUGFILE} = $args{debugfh};
    $self->{DEBUG} = 1;
  }
  if ((exists($args{debugfh}) && ($args{debugfh} eq "")) && 
       (exists($args{debug}) && ($args{debug} ne ""))) {
    $self->{DEBUG} = 1;
    if (lc($args{debug}) eq "stdout") {
      open(DEBUG, ">STDOUT");
      $self->{DEBUGFILE} = \*DEBUG;
    } else {
      if (-e $args{debug}) {
	if (-w $args{debug}) {
	  open(DEBUG, ">$args{debug}");
	  $self->{DEBUGFILE} = \*DEBUG;
	} else {
	  print "WARNING: debug file ($args{debug}) is not writable by you\n";
	  print "         No debug information being saved.\n";
	  $self->{DEBUG} = 0;
	}
      } else {
	if (open(DEBUG, ">$args{debug}")) {
	  $self->{DEBUGFILE} = \*DEBUG;
	} else {
	  print "WARNING: debug file ($args{debug}) does not exist \n";
	  print "         and is not writable by you.\n";
	  print "         No debug information being saved.\n";
	  $self->{DEBUG} = 0;
	}
      }
    }
  }

  my $hostname = hostname();
  my $address = gethostbyname($hostname) || 
    die("Cannot resolve $hostname: $!");
  my $fullname = gethostbyaddr($address,AF_INET) || $hostname;

  $self->debug(1,"new: hostname = ($fullname)");

  #---------------------------------------------------------------------------
  # Setup the defaults that the module will work with.
  #---------------------------------------------------------------------------
  $self->{SERVER} = {hostname => "",
		     port => "", 
		     sock => 0, 
		     namespace => "",
		     myhostname => $fullname,
		     derivedhostname => $fullname,
		     id => ""};
  
  #---------------------------------------------------------------------------
  # We are only going to use one callback, let the user call other callbacks
  # on his own.
  #---------------------------------------------------------------------------
  $self->{NODE} = sub { $self->_node(@_) };

  #---------------------------------------------------------------------------
  # Set the default STATUS so that we can keep track of it throughout the
  # session.  1 = no errors, -1 = error from handlers, 0 = no data has been
  # received yet.
  #---------------------------------------------------------------------------
  $self->{STATUS} = 0;

  #---------------------------------------------------------------------------
  # A storage place for when we don't have a callback registered and we need
  # to stockpile the nodes we receive until Process is called and we return 
  # them.
  #---------------------------------------------------------------------------
  $self->{NODES} = ();

  #---------------------------------------------------------------------------
  # A storage place for when we don't have a callback registered and we need
  # to stockpile the nodes we receive until Process is called and we return 
  # them.
  #---------------------------------------------------------------------------
  $self->{XML} = "";

  #---------------------------------------------------------------------------
  # Flag to determine if we are alrady parsing and need to store the incoming
  # XML until later.
  #---------------------------------------------------------------------------
  $self->{PARSING} = 0;

  return $self;
}


###########################################################################
#
# debug - prints the arguments to the debug log if debug is turned on.
#
###########################################################################
sub debug {
  my $self = shift;
  my ($limit,@args) = @_;
  return if ($limit > $self->{DEBUGLEVEL});
  my $fh = $self->{DEBUGFILE};
  print $fh "XML::Stream: @args\n";
}


##############################################################################
#
# Connect - starts the stream by connecting to the server, sending the opening
#           stream tag, and then waiting for a response and verifying that it
#           is correct for this stream.  Server name, port, and namespace are
#           required otherwise we don't know where to send the stream to...
#
##############################################################################
sub Connect {
  my $self = shift;
  my $timeout = exists $_{timeout} ? delete $_{timeout} : "";
  while($#_ >= 0) { $self->{SERVER}{ lc pop(@_) } = pop(@_); }

  #---------------------------------------------------------------------------
  # Check some things that we have to know in order get the connection up
  # and running.  Server hostname, port number, namespace, etc...
  #---------------------------------------------------------------------------
  if ($self->{SERVER}{hostname} eq "") {
    $self->SetErrorCode("Server hostname not specified");
    return;
  }
  if ($self->{SERVER}{port} eq "") {
    $self->SetErrorCode("Server port not specified");
    return;
  }
  if ($self->{SERVER}{namespace} eq "") {
    $self->SetErrorCode("Namespace not specified");
    return;
  }
  if ($self->{SERVER}{myhostname} eq "") {
    $self->{SERVER}{myhostname} = $self->{SERVER}{derivedhostname};
  }
  
  #---------------------------------------------------------------------------
  # Open the connection to the listed server and port.  If that fails then
  # abort ourselves and let the user check $! on his own.
  #---------------------------------------------------------------------------
  $self->{SERVER}{sock} = 
    new IO::Socket::INET(PeerAddr => $self->{SERVER}{hostname}, 
			 PeerPort => $self->{SERVER}{port}, 
			 Proto => 'tcp');
  return unless $self->{SERVER}{sock};
  $self->{SERVER}{sock}->autoflush(1);
  
  #---------------------------------------------------------------------------
  # Next, we build the opening handshake.
  #---------------------------------------------------------------------------
  my $stream = '<?xml version="1.0"?>';
  $stream .= '<stream:stream ';
  $stream .= 'xmlns:stream="http://etherx.jabber.org/streams" ';
  $stream .= 'to="'.$self->{SERVER}{hostname}.'" ';
  $stream .= 'from="'.$self->{SERVER}{myhostname}.'" ' if ($self->{SERVER}{myhostname} ne "");
  $stream .= 'xmlns="'.$self->{SERVER}{namespace}.'" ';
  $stream .= 'id="'.$self->{SERVER}{id}.'"' if (exists($self->{SERVER}{id}) && ($self->{SERVER}{id} ne ""));
  my $namespaces = "";
  my $ns;
  foreach $ns (@{$self->{SERVER}{namespaces}}) {
    $namespaces .= " ".$ns->GetStream();
    $stream .= " ".$ns->GetStream();
  }
  $stream .= ">";

  #---------------------------------------------------------------------------
  # Then we send the opening handshake.
  #---------------------------------------------------------------------------
  $self->Send($stream) || return;

  #---------------------------------------------------------------------------
  # Create the XML::Parser and register our callbacks
  #---------------------------------------------------------------------------
  my $expat = 
    new XML::Parser(Handlers => { Start => sub { $self->_handle_root(@_) }, 
				  End   => sub { $self->_handle_close(@_) }, 
				  Char  => sub { $self->_handle_cdata(@_) }
				});
  $self->{SERVER}{parser} = $expat->parse_start();
  $self->{SERVER}{select} = new IO::Select($self->{SERVER}{sock});

  #---------------------------------------------------------------------------
  # Before going on let's make sure that the server responded with a valid
  # root tag and that the stream is open.
  #---------------------------------------------------------------------------
  my $buff;
  my $timeStart = time();
  while($self->{STATUS} == 0) {
    if ($self->{SERVER}{select}->can_read(0)) {
      $buff = $self->Read();
      return unless ($self->ParseStream($buff) == 1);
    } else {
      if ($timeout ne "") {
	$timeout -= (time() - $timeStart);
	if ($timeout <= 0) {
	  $self->SetErrorCode("Timeout limit reached");
	  return;
	}
      }
    }
    
    return if($self->{SERVER}{select}->has_error(0));
  }
  return if($self->{STATUS} != 1);
  return $self->GetRoot();
}


##############################################################################
#
# Disconnect - sends the closing XML tag and shuts down the socket.
#
##############################################################################
sub Disconnect {
  my $self = shift;

  $self->Send("</stream:stream>");
  close($self->{SERVER}{sock});
}


##############################################################################
#
# Process - checks for data on the socket and returns a status code depending
#           on if there was data or not.  If a timeout is not defined in the
#           call then the timeout defined in Connect() is used.  If a timeout
#           of 0 is used then the call blocks until it gets some data,
#           otherwise it returns after the timeout period.
#
##############################################################################
# checks for data on the socket, uses timeout passed to Connect()
sub Process {
  my $self = shift;
  my($timeout) = @_;
  $timeout = "" if !defined($timeout);
  
  #---------------------------------------------------------------------------
  # We need to keep track of what's going on in the function and tell the
  # outside world about it so let's return something useful:
  #     0    connection open but no data received.
  #     1    connection open and data received.
  #   undef  connection closed and error
  #   array  connection open and the data that has been collected 
  #          over time (No CallBack specified)
  #---------------------------------------------------------------------------
  my ($status) = 0;
  
  #---------------------------------------------------------------------------
  # Make sure the connection is active.
  #---------------------------------------------------------------------------
  return unless ($self->{STATUS} == 1);
  
  #---------------------------------------------------------------------------
  # Either block until there is data and we have parsed it all, or wait a 
  # certain period of time and then return control to the user.
  #---------------------------------------------------------------------------
  my $block = 1;
  my $timeStart = time();
  while($block == 1) {
    if($self->{SERVER}{select}->can_read(0)) {
      my $buff;
      while($self->{SERVER}{select}->can_read(0)) {
	$status = 1;
	$self->{STATUS} = -1 if (!defined($buff = $self->Read()));
	return unless($self->{STATUS} == 1);
	return unless($self->ParseStream($buff) == 1);
      }
      $block = 0;
    }

    if ($timeout ne "") {
      my $time = time;
      $timeout -= ($time - $timeStart);
      $timeStart = $time;
      $block = 0 if ($timeout <= 0);
    }
                                # 09/04/00 winter :: added unless check, so we don't sleep here in a gui call
    select(undef,undef,undef,.25) unless $timeout == 0;
    
    $block = 1 if $self->{SERVER}{select}->can_read(0);
  }

  #---------------------------------------------------------------------------
  # If the Select has an error then shut this party down.
  #---------------------------------------------------------------------------
  return if($self->{SERVER}{select}->has_error(0));
  
  #---------------------------------------------------------------------------
  # If there are XML::Parser::Tree objects that have not been collected return
  # those, otherwise return the status which indicates if nodes were read or 
  # not.
  #---------------------------------------------------------------------------
  if($#{$self->{NODES}} > -1) {
    return shift @{$self->{NODES}};
  } else {
    return $status; # signal that we're ok
  }
}


##############################################################################
#
# ParseStream - takes the incoming stream and makes sure that only full
#               XML tags gets passed to the parser.  If a full tag has not
#               read yet, then the Stream saves the incomplete part and
#               sends the rest to the parser.
#
##############################################################################
sub ParseStream {
  my $self = shift;
  my ($stream) = @_;

  $self->debug(2,"ParseStream: incoming($stream) current($self->{XML})");

  $self->{XML} .= $stream;

  if ($self->{PARSING} == 1) {
    $self->debug(2,"ParseStream: we are in the middle of a parse!!!!!  BAIL!!!!!");
    return 1;
  }

  $self->{PARSING} = 1;

  my $goodXML = "";
  my $badXML = "";

  while($badXML ne $self->{XML}) {  
    ($goodXML,$badXML) = ($self->{XML} =~ /^([\w\W]+)(\<[^\>]+)$/);
    
    $goodXML = $badXML = "" if (!defined($goodXML) && !defined($badXML));

    $self->debug(2,"ParseStream: goodXML($goodXML) badXML($badXML)");
    
    if (($goodXML eq "") && ($badXML eq "")) {
      $goodXML = $self->{XML};
      $self->{XML} = "";
    } else {
      $self->{XML} = $badXML;
    }
    
    $self->debug(2,"ParseStream: parse($goodXML) save($self->{XML})");
    
    $self->{SERVER}{parser}->parse_more($goodXML);
    
    if ($STREAMERROR ne "") {
      $self->debug(2,"ParseStream: ERROR($STREAMERROR)");
      $self->SetErrorCode($STREAMERROR);
      return;
    }
    
    $self->debug(2,"ParseStream: test badXML($badXML) current($self->{XML})");
    if ($badXML ne $self->{XML}) {
      $self->debug(2,"ParseStream: someone tried to parse while we were running");
      $self->debug(2,"ParseStream: let's run again to clear out that XML");
    }
  }	
  $self->debug(2,"ParseStream: returning");
    
  $self->{PARSING} = 0;
  return 1;
}



##############################################################################
#
# OnNode - registers a callback for when a node is received.  This is used so
#          that the user can write his own functions to handle the incoming
#          data.  If one is not defined then the internal callback _node is
#          used.
#
##############################################################################
sub OnNode {
  my $self = shift;
  $self->{NODE} = shift;
}


##############################################################################
#
# GetRoot - returns the hash of attributes for the root <stream:stream/> tag
#           so that any attributes returned can be accessed.  from and any
#           xmlns:foobar might be important.
#
##############################################################################
sub GetRoot {
  my $self = shift;
  return $self->{ROOT};
}


##############################################################################
#
# GetSock - returns the Socket so that an outside function can access it if
#           desired.
#
##############################################################################
sub GetSock {
  my $self = shift;
  return $self->{SERVER}{sock};
}


##############################################################################
#
# Send - Takes the data string and sends it to the server
#
##############################################################################
sub Send {
  my $self = shift;
  $self->debug(1,"Send: (@_)");
  $self->{SERVER}{sock}->print(@_) || return;
  return 1;
}


##############################################################################
#
# Read - Takes the data from the server and returns a string
#
##############################################################################
sub Read {
  my $self = shift;
  my $buff;
  my $status = $self->{SERVER}{sock}->sysread($buff,1024);
  $self->debug(1,"Read: ($buff)");
  return $buff unless $status == 0;
  $self->debug(1,"Read: ERROR");
  return;
}


##############################################################################
#
# GetErrorCode - if you are returned an undef, you can call this function
#                and hopefully learn more information about the problem.
#
##############################################################################
sub GetErrorCode {
  my $self = shift;
  return (($self->{ERRORCODE} ne "") ? $self->{ERRORCODE} : $!);
}


##############################################################################
#
# SetErrorCode - sets the error code so that the caller can find out more
#                information about the problem
#
##############################################################################
sub SetErrorCode {
  my $self = shift;
  my ($errorcode) = @_;
  $self->{ERRORCODE} = $errorcode;
}


##############################################################################
#
# _handle_root - handles a root tag and checks that it is a stream:stream tag
#                with the proper namespace.  If not then it sets the STATUS to
#                -1 and let's the outer code know that an error occurred.
#                Then it changes the Start tag handler to _handle_element.
#
##############################################################################
sub _handle_root {
  my $self = shift;
  my ($expat, $tag, %att) = @_;

  $self->debug(2,"_handle_root: expat($expat) tag($tag) att(",%att,")");
  
  #---------------------------------------------------------------------------
  # Make sure we are receiving a valid stream on the same namespace.
  #---------------------------------------------------------------------------
  $self->{STATUS} = 
    (($tag eq "stream:stream") && exists($att{'xmlns'}) &&
     ($att{'xmlns'} eq $self->{SERVER}{namespace})) ? 1 : -1;

  
  #---------------------------------------------------------------------------
  # Get the root tag attributes and save them for later.  You never know when
  # you'll need to check the namespace or the from attributes sent by the 
  # server.
  #---------------------------------------------------------------------------
  $self->{ROOT} = \%att;

  #---------------------------------------------------------------------------
  # Now that we have gotten a root tag, let's look for the tags that make up
  # the stream.  Change the handler for a Start tag to another function.
  #---------------------------------------------------------------------------
  $expat->setHandlers(Start => sub { $self->_handle_element(@_)});
}


##############################################################################
#
# _handle_element - handles the main tag elements sent from the server.  On
#                   an open tag it creates a new XML::Parser::Tree so that
#                   _handle_cdata and _handle_element can add data and tags
#                   to it later.
#
##############################################################################
sub _handle_element {
  my $self = shift;
  my ($expat, $tag, %att) = @_;

  $self->debug(2,"_handle_element: expat($expat) tag($tag) att(",%att,")");

  my @NEW;
  if($#{$self->{TREE}} < 0) {
    push @{$self->{TREE}}, $tag;
  } else {
    push @{ $self->{TREE}[ $#{$self->{TREE}}]}, $tag;
  }
  push @NEW, \%att;
  push @{$self->{TREE}}, \@NEW;
}


##############################################################################
#
# _handle_cdata - handles the CDATA that is encountered.  Also, in the spirit
#                 of XML::Parser::Tree it any sequential CDATA into one tag.
#
##############################################################################
sub _handle_cdata {
  my $self = shift;
  my ($expat, $cdata) = @_;

  $self->debug(2,"_handle_cdata: expat($expat) cdata($cdata)");
  
  my $pos = $#{$self->{TREE}};
  $self->debug(2,"_handle_cdata: pos($pos)");

  if ($pos > 0 && $self->{TREE}[$pos - 1] eq "0") {
    $self->debug(2,"_handle_cdata: append cdata");
    $self->{TREE}[$pos - 1] .= $cdata;
  } else {
    $self->debug(2,"_handle_cdata: new cdata");
    push @{$self->{TREE}[$#{$self->{TREE}}]}, 0;
    push @{$self->{TREE}[$#{$self->{TREE}}]}, $cdata;
  }	
}


##############################################################################
# 
# _handle_close - when we see a close tag we need to pop the last element from
#                 the list and push it onto the end of the previous element.
#                 This is how we build our hierarchy.
#
##############################################################################
sub _handle_close {
  my $self = shift;
  my ($expat, $tag) = @_;

  $self->debug(2,"_handle_close: expat($expat) tag($tag)");
  
  my $CLOSED = pop @{$self->{TREE}};
  
  $self->debug(2,"_handle_close: check(",$#{$self->{TREE}},")");

  if($#{$self->{TREE}} < 1) {
    push @{$self->{TREE}}, $CLOSED;

    if($self->{TREE}->[0] eq "stream:error") {
      $STREAMERROR = $self->{TREE}[1]->[2];
    } else {
      my @tree = @{$self->{TREE}};
      $self->{TREE} = [];
      &{$self->{NODE}}(@tree);
    }
  } else {
    push @{$self->{TREE}[$#{$self->{TREE}}]}, $CLOSED;
  }
}


##############################################################################
#
# _node - internal callback for nodes.  All it does is place the nodes in a
#         list so that Process() can return them later.
#
##############################################################################
sub _node {
  my $self = shift;
  my @PassedNode = @_;
  push @{$self->{NODES}}, ${@PassedNode};
} 

1;









##############################################################################
#
# XML::Stream Tree Building 101
#
#   In order to not reinvent the wheel, XML::Stream uses the XML::Parser::Tree
# object as the data structure it passes around and stores.  Two things need
# to be covered in order to understand what the data looks like when you get
# it from XML::Stream.
#
#
#
# Section 1:  What does an XML::Parser::Tree object look like?
#
#   The original documentation for XML::Parser::Tree can be a little hard to
# understand so we will go over the structure here for completeness.  The
# that is built is essentially a big nested array.  This guarantees that you
# see the tags in the order receded from the stream, and that the nesting of
# tags is maintained.  The actual structure of the tree is complicated so
# let's cover an example:
#
#   <A n='1>First<B n='2' m='bob'>Second</B>Third<C/></A>
#
#   What we are working with is a nested <B/> tag inside the CDATA of <A/>.
# There are attributes on both tags that must be stored.  To do this we use
# an array.  The first element of the array is the root tag, or A.
#
#   [ 'A' ]
#
#   The second element is a list of all the things contained in <A/>.
#
#   [ 'A', [ ] ]
#
#   That new list is recursively built as you go down the hierarchy, so let's
# examine the structure.  The first element of that new list is a hash of
# key/value pairs that represent the attributes of the tag you are looking
# at.  In the case of the root tag <A/> the hash would be { 'n' => '1' }.  So
# adding that to the list we get:
#
#   [ 'A', [ { 'n' => '1' } ] ]
#
#   Now, the rest of the new list is a set of two elements added at a time.
# Either a tag name followed by a list that represents the new tag, or a 
# "0" (zero) followed by a string.  This might be confusing so let's go to
# the example.  As we parse the <A/> tag we see the string "First".  So
# according to the rule we add a "0" and "First" to the list:
#
#   [ 'A', [ { 'n' => '1' }, 0, "First" ] ]
#
#   The next element is the <B/> tag.  So the rules says that we add the
# tag and then a list that contains that tag:
#
#   [ 'A', [ { 'n' => '1' }, 0, "First", 'B', [ ] ] ]
#
#   Parsing the <B/> tag we see an attributes n = '2' and m = 'bob.  So
# those go into a hash and that hash becomes the first element in the list
# for B:
#
#   [ 
#     'A', [ { 'n' => '1' }, 
#            0, "First", 
#            'B', [ { 'n' => '2', 'm' => 'bob' } ]
#          ] 
#   ]
#
#   Next we see that <B/> contains the CDATA "Second" so that goes into
# the list for B:
#
#   [ 
#     'A', [ { 'n' => '1' }, 
#            0, "First", 
#            'B', [ { 'n' => '2', 'm' => 'bob' } 
#                   0, "Second"
#                 ]
#          ] 
#   ]
#
#   <B/> closes and we leave this list and return to the list for <A/>.
# The next element there is CDATA so add a '0' and "Third" onto the list
# for A:
#
#   [ 
#     'A', [ { 'n' => '1' }, 
#            0, "First", 
#            'B', [ { 'n' => '2', 'm' => 'bob' } 
#                   0, "Second"
#                 ]
#            0, "Third"
#          ] 
#   ]
#
#   Now we see another tag, <C/>.  So we add C and a list onto the A's list:
#
#   [ 
#     'A', [ { 'n' => '1' }, 
#            0, "First", 
#            'B', [ { 'n' => '2', 'm' => 'bob' } 
#                   0, "Second"
#                 ]
#            0, "Third",
#            'C', [ ]
#          ] 
#   ]
#
#   Parsing <C/> we see that it has no attributes so we add an empty hash
# to the list for C:
#
#   [ 
#     'A', [ { 'n' => '1' }, 
#            0, "First", 
#            'B', [ { 'n' => '2', 'm' => 'bob' } 
#                   0, "Second"
#                 ]
#            0, "Third",
#            'C', [ { } ]
#          ] 
#   ]
#
#   Next we see that <C/> contains no other data and ends in a />.  This
# means that the tag is finished and contains no data.  So close C and go
# back to <A/>.  There is no other data in A so we close <A/> and we have
# our finished tree:
#
#   [ 
#     'A', [ { 'n' => '1' }, 
#            0, "First", 
#            'B', [ { 'n' => '2', 'm' => 'bob' } 
#                   0, "Second"
#                 ]
#            0, "Third",
#            'C', [ { } ]
#          ] 
#   ]
#
#
#
# Section II:  How do we build the XML::Parser::Tree?
#
#   For those who are interested in how we build a tree read on, for those
# that got enough out of the previous section, read anyway.
#
#   Recursion would be too difficult to do in this linear problem so we
# looked at the problem and engineered a way to use a single list to build
# the structure.  Every time a new tag is encountered a new list is added to
# end of the main list.  When that list closes it is removed from the main
# list and then added onto the end of the previous element in the list,
# which is usually another list.  In other words:
#
#   The current list looks like this:
#
#   [aaa]
#
#   We see a new tag and make a new list:
#
#   [aaa], [bbb]
#
#   Populate that list and then close it.  When we close we remove from the
# list and make it the last element in the previous list elements list.  
# Confused?  Watch:
#
#   [aaa], [bbb] -->  [aaa, [bbb] ]
#
#   As we "recurse" the hierarchy and close tags we push the new list back
# up to the previous list element and create the proper nesting.
#
#   Let's go over the same example from Section I.
#
#   <A n='1>First<B n='2' m='bob'>Second</B>Third<C/></A>
#
#   We start and push A on the list:
#
#   [ 'A' ]
#
#   Next we create a new list for the <A/> tag and populate the attribute
# hash:
#
#   [ 'A',
#     [ { 'n'=>'1' } ]
#   ]
#
#   Now we see the CDATA:
#
#   [ 'A',
#     [ { 'n'=>'1' }, 0, "First" ]
#   ]
#
#   Next it's the <B/> tag, so push B on the list and make a new list on
# the end of the main list:
#
#   [ 'A', 
#     [ { 'n'=>'1' }, 0, "First", 'B' ], 
#     [ ]
#   ]
#
#   Parsing the <B/> tag we see that is has attributes and CDATA:
#
#   [ 'A', 
#     [ { 'n'=>'1' }, 0, "First", 'B' ], 
#     [ {'n'=>'2','m'=>"bob"}, 0, "Second" ]
#   ]
#
#   Now <B/> closes and the magic begins...  With the closing of <B/> we
# pop the last element off the list.  Then we take that element and push it
# onto the last element of the main list.  So we aren't pushing it onto the
# main list, but onto the last element of the main list:
#
#   Popped value: [ {'n'=>'2','m'=>"bob"}, 0, "Second" ]
#
#   List:         [ 'A', 
#                   [ { 'n'=>'1' }, 0, "First", 'B' ]
#                 ]
#
#   Push value on last element of list:
#   [ 'A', 
#     [ { 'n'=>'1' }, 0, "First", 'B', [ {'n'=>'2','m'=>"bob"}, 0, "Second" ] ]
#   ]
#  
#   Now we see a CDATA and push that onto the last element in the list:
#
#   [ 'A', 
#     [ { 'n'=>'1' }, 
#       0, "First", 
#       'B', [ {'n'=>'2','m'=>"bob"}, 
#              0, "Second" 
#            ],
#       0, "Third"
#     ]
#   ]
#  
#   Finally we see the <C/> tag, so a 'C' is pushed onto the list, and then
# a new list is created to contain the new tag:
#
#   [ 'A', 
#     [ { 'n'=>'1' }, 
#       0, "First", 
#       'B', [ {'n'=>'2','m'=>"bob"}, 
#              0, "Second" 
#            ],
#       0, "Third",
#       'C'
#     ],
#     [ ]
#   ]
#  
#   <C/> no attributes so an empty hash is pushed onto the list:
#
#   [ 'A', 
#     [ { 'n'=>'1' }, 
#       0, "First", 
#       'B', [ {'n'=>'2','m'=>"bob"}, 
#              0, "Second" 
#            ],
#       0, "Third",
#       'C'
#     ],
#     [ { } ]
#   ]
#
#   <C/> contains no data so nothing is to be done there.  The tag closes
# and we do the magic again.  Pop the last element off the main list and 
# push it onto the previous element's list:
#
#   [ 'A', 
#     [ { 'n'=>'1' }, 
#       0, "First", 
#       'B', [ {'n'=>'2','m'=>"bob"}, 
#              0, "Second" 
#            ],
#       0, "Third",
#       'C', [ { } ]
#     ]
#   ]
#
#   Now <A/> closes so we pop the last element off the main list and push
# is onto a list with the previous element, which is the string 'A':
#
#   [ 'A', 
#     [ { 'n'=>'1' }, 
#       0, "First", 
#       'B', [ {'n'=>'2','m'=>"bob"}, 
#              0, "Second" 
#            ],
#       0, "Third",
#       'C', [ { } ]
#     ]
#   ]
#
#   And voila!  The tree is complete.  We now call the callback function,
# pass it the tree, and then reset the tree for the next tag to be parsed.
#
##############################################################################
