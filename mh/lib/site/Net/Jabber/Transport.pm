package Net::Jabber::Transport;

=head1 NAME

Net::Jabber::Transport - Jabber Transport Library

=head1 SYNOPSIS

  Net::Jabber::Transport is a module that provides a developer easy access
  to tranports in the Jabber Instant Messaging protocol.

=head1 DESCRIPTION

  Transport.pm seeks to provide enough high level APIs and automation of 
  the low level APIs that writing a Jabber Transport in Perl is trivial.
  For those that wish to work with the low level you can do that too, 
  but those functions are covered in the documentation for each module.

  Net::Jabber::Transport provides functions to connect to a Jabber server,
  login, send and receive messages, set personal information, create
  a new user account, manage the roster, and disconnect.  You can use
  all or none of the functions, there is no requirement.

  For more information on how the details for how Net::Jabber is written
  please see the help for Net::Jabber itself.

  For a full list of high level functions available please see 
  Net::Jabber::Protocol.

=head2 Basic Functions

    use Net::Jabber;

    $Con = new Net::Jabber::Transport();

    $Con->Connect(hostname=>"jabber.org");

    if ($Con->Connected()) {
      print "We are connected to the server...\n";
    }

    #
    # For the list of available function see Net::Jabber::Protocol.
    #

    $Con->Disconnect();

=head1 METHODS

=head2 Basic Functions

    new(debuglevel=>0|1|2, - creates the Transport object.  debugfile
        debugfile=>string)   should be set to the path for the debug
                             log to be written.  If set to "stdout" 
                             then the debug will go there.  debuglevel 
                             controls the amount of debug.  For more
                             information about the valid setting for
                             debuglevel and debugfile see 
                             Net::Jabber::Debug.

    Connect(hostname=>string,      - opens a connection to the server
	    port=>integer,           listedt in the hostname value,
	    secret=>string,          on the port listed.  The defaults
	    transportname=>string)   for the two are localhost and 5222.
				     The secret is the password needed
                                     to attach the hostname, and the
                                     transportname is the name that
                                     server and clients will know the
                                     transport by.

    Disconnect() - closes the connection to the server.

    Connected() - returns 1 if the Transport is connected to the server,
                  and 0 if not.

=head1 AUTHOR

By Ryan Eatmon in May of 2000 for http://jabber.org.

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use XML::Stream 1.05;
use IO::Select;
use vars qw($VERSION $AUTOLOAD);

$VERSION = "1.0013";

use Net::Jabber::Protocol;
($Net::Jabber::Protocol::VERSION < $VERSION) &&
  die("Net::Jabber::Protocol $VERSION required--this is only version $Net::Jabber::Protocol::VERSION");

use Net::Jabber::Key;
($Net::Jabber::Key::VERSION < $VERSION) &&
  die("Net::Jabber::Key $VERSION required--this is only version $Net::Jabber::Key::VERSION");

sub new {
  srand( time() ^ ($$ + ($$ << 15)));

  my $proto = shift;
  my $self = { };

  my %args;
  while($#_ >= 0) { $args{ lc(pop(@_)) } = pop(@_); }

  bless($self, $proto);

  $self->{DELEGATE} = new Net::Jabber::Protocol();

  $self->{DEBUG} = 
    new Net::Jabber::Debug(level=>exists($args{debuglevel}) ? $args{debuglevel} : -1,
			   file=>exists($args{debugfile}) ? $args{debugfile} : "stdout",
			   setdefault=>1,
			   header=>"NJ::Transport"
			  );
  
  $self->{SERVER} = {hostname => "localhost",
		     port => 5269,
		     transportname => ""};

  $self->{CONNECTED} = 0;

  $self->{STREAM} = new XML::Stream(debugfh=>$self->{DEBUG}->GetHandle(),
				    debuglevel=>$self->{DEBUG}->GetLevel());

  $self->{VERSION} = $VERSION;
  
  $self->{LIST}->{currentID} = 0;

  if (eval "require Digest::SHA1") {
    $self->{DIGEST} = 1;
    Digest::SHA1->import(qw(sha1 sha1_hex sha1_base64));
  } else {
    print "ERROR:  You cannot use Transport.pm unless you have Digest::SHA1 installed.\n";
    exit(0);
  }

  return $self;
}


##############################################################################
#
# AUTOLOAD - This function calls the delegate with the appropriate function
#            name and argument list.
#
##############################################################################
sub AUTOLOAD {
  my $self = $_[0];
  return if ($AUTOLOAD =~ /::DESTROY$/);
  $AUTOLOAD =~ s/^.*:://;
  $self->{DELEGATE}->$AUTOLOAD(@_);
}


###########################################################################
#
# Connect - Takes a has and opens the connection to the specified server.
#           Registers CallBack as the main callback for all packets from
#           the server.
#
#           NOTE:  Need to add some error handling if the connection is
#           not made because the server hostname is wrong or whatnot.
#
###########################################################################
sub Connect {
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  $self->{DEBUG}->Log1("Connect: hostname($args{hostname}) secret($args{secret}) transportname($args{transportname})");

  if (!exists($args{hostname})) {
    $self->SetErrorCode("No hostname specified.");
    return;
  }

  if (!exists($args{secret})) {
    $self->SetErrorCode("No secret specified.");
    return;
  }

  if (!exists($args{transportname})) {
    $self->SetErrorCode("No transport name specified.");
    return;
  }

  $self->{SERVER}->{hostname} = delete($args{hostname});
  $self->{SERVER}->{port} = delete($args{port}) if exists($args{port});
  $self->{SERVER}->{transportname} = delete($args{transportname});

  $self->{SERVER}->{id} = rand(1000000);
  $self->{SERVER}->{id} =~ s/\.//;
  ($self->{SERVER}->{id}) = 
    ($self->{SERVER}->{id} =~ /(\d\d\d\d\d\d\d\d\d\d)/);
  $self->{SERVER}->{digest} =
    Digest::SHA1::sha1_hex($self->{SERVER}->{id}.$args{secret});

  $self->{NAMESPACE} = new XML::Stream::Namespace("etherx");
  $self->{NAMESPACE}->SetXMLNS("http://etherx.jabber.org/");
  $self->{NAMESPACE}->SetAttributes(secret=>$self->{SERVER}->{digest});

  $self->{DEBUG}->Log1("Connect: id($self->{SERVER}->{id}) digest($self->{SERVER}->{digest})");

  $self->{SESSION} = 
    $self->{STREAM}->
      Connect(hostname=>$self->{SERVER}->{hostname},
	      port=>$self->{SERVER}->{port},
	      myhostname=>$self->{SERVER}->{transportname},
	      id=>$self->{SERVER}->{id},
	      namespace=>"jabber:server",
	      namespaces=> [ $self->{NAMESPACE} ]
	     ) || (($self->SetErrorCode($self->{STREAM}->GetErrorCode())) &&
	           return);

  $self->{DEBUG}->Log1("Connect: connection made");

  $self->{STREAM}->OnNode(sub{ $self->CallBack(@_) });
  $self->{CONNECTED} = 1;
  return 1;
}


###########################################################################
#
# Disconnect - Sends the string to close the connection cleanly.
#
###########################################################################
sub Disconnect {
  my $self = shift;
  $self->{STREAM}->Disconnect() if ($self->{CONNECTED} == 1);
  $self->{CONNECTED} = 0;
  $self->{DEBUG}->Log1("Disconnect: bye bye");
}


###########################################################################
#
# Connected - returns 1 if the Transport is connected to the server, 0
#             otherwise.
#
###########################################################################
sub Connected {
  my $self = shift;

  $self->{DEBUG}->Log1("Connected: ($self->{CONNECTED})");
  return $self->{CONNECTED};
}


1;
