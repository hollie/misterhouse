package Net::Jabber::X;

=head1 NAME

Net::Jabber::X - Jabber X Module

=head1 SYNOPSIS

  Net::Jabber::X is a companion to the Net::Jabber module. It
  provides the user a simple interface to set and retrieve all 
  parts of a Jabber X.

=head1 DESCRIPTION

  Net::Jabber::X differs from the other Net::Jabber::* modules in that
  the XMLNS of the query is split out into more submodules under
  X.  For specifics on each module please view the documentation
  for each Net::Jabber::X::* module.  The available modules are:

    Net::Jabber::X::AutoUpdate - Auto Update information
    Net::Jabber::X::Delay      - Message Routing and Delay Information
    Net::Jabber::X::GC         - GroupChat
    Net::Jabber::X::Ident      - Rich Identification
    Net::Jabber::X::Oob        - Out Of Band File Transfers
    Net::Jabber::X::Roster     - Roster Items for embedding in messages

  Each of these modules provide Net::Jabber::X with the functions
  to access the data.  By using delegates and the AUTOLOAD function
  the functions for each namespace is used when that namespace is
  active.

  To access an X object you must create a Message object and use the
  access functions there to get to the X.  To initialize the Message with 
  a Jabber <message/> you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the message
  you can access the x tags for the namespace "my:namespace" by doing
  the following:

    use Net::Jabber;

    sub messageCB {
      my $message = new Net::Jabber::Message(@_);
      my @xTags = $mesage->GetX("my:namespace");
      my $xTag;
      foreach $xTag (@xTags) {
        .
        .
        .
      }
    }

  You now have access to all of the retrieval functions available.

  To create a new x to send to the server:

    use Net::Jabber;

    my $message = new Net::Jabber::Message();
    my $x = $message->NewX("jabber:x:ident");

  Now you can call the creation functions for the X as defined in the
  proper namespace.  See below for the general <x/> functions, and in 
  each query module for those functions.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $xmlns     = $X->GetXMLNS();

    $str       = $X->GetXML();
    @x         = $X->GetTree();

=head2 Creation functions

    $X->SetXMLNS("jabber:x:delay");

=head1 METHODS

=head2 Retrieval functions

  GetXMLNS() - returns a string with the namespace of the query that
               the <x/> contains.

  GetXML() - returns the XML string that represents the <x/>. This 
             is used by the Send() function in Client.pm to send
             this object as a Jabber X.

  GetTree() - returns an array that contains the <x/> tag in XML::Parser 
              Tree format.

=head2 Creation functions

  SetXMLNS(string) - sets the xmlns of the <x/> to the string.

=head1 CUSTOM X MODULES

  Part of the flexability of this module is that you can write your own
  module to handle a new namespace if you so choose.  The SetDelegates
  function is your way to register the xmlns and which module will
  provide the missing access functions.

  To register your namespace and module, you can either create an X
  object and register it once, or you can use the SetDelegates
  function in Client.pm to do it for you:

    my $Client = new Net::Jabber::Client();
    $Client->AddDelegate(namespace=>"blah:blah",
			 parent=>"Net::Jabber::X",
			 delegate=>"Blah::Blah");
    
  or

    my $Transport = new Net::Jabber::Transport();
    $Transport->AddDelegate(namespace=>"blah:blah",
			    parent=>"Net::Jabber::X",
			    delegate=>"Blah::Blah");
    
  Once you have the delegate registered you need to define the access
  functions.  Here is a an example module:

    package Blah::Blah;

    sub new {
      my $proto = shift;
      my $class = ref($proto) || $proto;
      my $self = { };
      $self->{VERSION} = $VERSION;
      bless($self, $proto);
      return $self;
    }

    sub SetBlah {
      shift;
      my $self = shift;
      my ($blah) = @_;
      return &Net::Jabber::SetXMLData("single",$self->{X},"blah","$blah",{});
    }

    sub GetBlah {
      shift;
      my $self = shift;
      return &Net::Jabber::GetXMLData("value",$self->{X},"blah","");
    }

    1;

  Now when you create a new X object and call GetBlah on that object
  it will AUTOLOAD the above function and handle the request.

=head1 AUTHOR

By Ryan Eatmon in May of 2000 for http://jabber.org..

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use Carp;
use vars qw($VERSION $AUTOLOAD);

$VERSION = "1.0013";

use Net::Jabber::X::AutoUpdate;
($Net::Jabber::X::AutoUpdate::VERSION < $VERSION) &&
  die("Net::Jabber::X::AutoUpdate $VERSION required--this is only version $Net::Jabber::X::AutoUpdate::VERSION");

use Net::Jabber::X::Delay;
($Net::Jabber::X::Delay::VERSION < $VERSION) &&
  die("Net::Jabber::X::Delay $VERSION required--this is only version $Net::Jabber::X::Delay::VERSION");

use Net::Jabber::X::GC;
($Net::Jabber::X::GC::VERSION < $VERSION) &&
  die("Net::Jabber::X::GC $VERSION required--this is only version $Net::Jabber::X::GC::VERSION");

#use Net::Jabber::X::Ident;
#($Net::Jabber::X::Ident::VERSION < $VERSION) &&
#  die("Net::Jabber::X::Ident $VERSION required--this is only version $Net::Jabber::X::Ident::VERSION");

use Net::Jabber::X::Oob;
($Net::Jabber::X::Oob::VERSION < $VERSION) &&
  die("Net::Jabber::X::Oob $VERSION required--this is only version $Net::Jabber::X::Oob::VERSION");

use Net::Jabber::X::Roster;
($Net::Jabber::X::Roster::VERSION < $VERSION) &&
  die("Net::Jabber::X::Roster $VERSION required--this is only version $Net::Jabber::X::Roster::VERSION");

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { };
  
  $self->{VERSION} = $VERSION;

  bless($self, $proto);

  if ("@_" ne ("")) {
    my @temp = @_;
    $self->{X} = \@temp;
    $self->GetDelegate();
  } else {
    $self->{X} = [ "x" , [{}]];
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


##############################################################################
#
# GetDelegate - sets the delegate for the AUTOLOAD function based on the
#               namespace.
#
##############################################################################
sub GetDelegate {
  my $self = shift;
  my $xmlns = $self->GetXMLNS();
  return if $xmlns eq "";
  if (exists($Net::Jabber::DELEGATES{$xmlns})) {
    eval("\$self->{DELEGATE} = new ".$Net::Jabber::DELEGATES{$xmlns}->{delegate}."()");
  }
}


##############################################################################
#
# GetXMLS - returns the namespace of the <x/>
#
##############################################################################
sub GetXMLNS {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{X},"","xmlns");  
}


##############################################################################
#
# GetXML - returns the XML string that represents the data in the XML::Parser
#          Tree.
#
##############################################################################
sub GetXML {
  my $self = shift;
  return &Net::Jabber::BuildXML(@{$self->{X}});
}


##############################################################################
#
# GetTree - returns the XML::Parser Tree that is stored in the guts of
#           the object.
#
##############################################################################
sub GetTree {
  my $self = shift;
  return @{$self->{X}};
}


##############################################################################
#
# SetXMLS - sets the namespace of the <x/>
#
##############################################################################
sub SetXMLNS {
  my $self = shift;
  my ($xmlns) = @_;
  
  &Net::Jabber::SetXMLData("single",$self->{X},"","",{"xmlns"=>$xmlns});
  $self->GetDelegate();
}


##############################################################################
#
# debug - prints out the XML::Parser Tree in a readable format for debugging
#
##############################################################################
sub debug {
  my $self = shift;

  print "debug X: $self\n";
  &Net::Jabber::printData("debug: \$self->{X}->",$self->{X});
}

1;
