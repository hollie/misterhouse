package Net::Jabber::Query;

=head1 NAME

Net::Jabber::Query - Jabber Query Library

=head1 SYNOPSIS

  Net::Jabber::Query is a companion to the Net::Jabber::IQ module. It
  provides the user a simple interface to set and retrieve all 
  parts of a Jabber IQ Query.

=head1 DESCRIPTION

  Net::Jabber::Query differs from the other Net::Jabber::* modules in that
  the XMLNS of the query is split out into more submodules under
  Query.  For specifics on each module please view the documentation
  for each Net::Jabber::Query::* module.  The available modules are:

    Net::Jabber::Query::Agent      - Agent Namespace
    Net::Jabber::Query::Agents     - Supported Agents list from server
    Net::Jabber::Query::Auth       - Simple Client Authentication
    Net::Jabber::Query::AutoUpdate - Auto-Update for clients
    Net::Jabber::Query::Filter     - Messaging Filter
    Net::Jabber::Query::Fneg       - Feature Negotiation
    Net::Jabber::Query::Oob        - Out of Bandwidth File Transfers
    Net::Jabber::Query::Register   - Registration requests
    Net::Jabber::Query::Roster     - Buddy List management
    Net::Jabber::Query::Search     - Searching User Directories
    Net::Jabber::Query::Time       - Client Time
    Net::Jabber::Query::Version    - Client Version

  Each of these modules provide Net::Jabber::Query with the functions
  to access the data.  By using delegates and the AUTOLOAD function
  the functions for each namespace is used when that namespace is
  active.

  To access a Query object you must create an IQ object and use the
  access functions there to get to the Query.  To initialize the IQ with 
  a Jabber <iq/> you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq
  you can access the query tag by doing the following:

    use Net::Jabber;

    sub iqCB {
      my $iq = new Net::Jabber::IQ(@_);
      my $query = $mesage->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new iq to send to the server:

    use Net::Jabber;

    my $iq = new Net::Jabber::IQ();
    $query = $iq->NewQuery("jabber:iq:register");

  Now you can call the creation functions for the Query as defined in the
  proper namespaces.  See below for the general <query/> functions, and
  in each query module for those functions.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $xmlns     = $IQ->GetXMLNS();

    $str       = $IQ->GetXML();
    @iq        = $IQ->GetTree();

=head2 Creation functions

    $Query->SetXMLNS("jabber:iq:roster");

=head1 METHODS

=head2 Retrieval functions

  GetXMLNS() - returns a string with the namespace of the query that
               the <iq/> contains.

  GetXML() - returns the XML string that represents the <iq/>. This 
             is used by the Send() function in Client.pm to send
             this object as a Jabber IQ.

  GetTree() - returns an array that contains the <iq/> tag in XML::Parser 
              Tree format.

=head2 Creation functions

  SetXMLNS(string) - sets the xmlns of the <query/> to the string.

=head1 CUSTOM Query MODULES

  Part of the flexability of this module is that you can write your own
  module to handle a new namespace if you so choose.  The SetDelegates
  function is your way to register the xmlns and which module will
  provide the missing access functions.

  To register your namespace and module, you can either create an IQ
  object and register it once, or you can use the SetDelegates
  function in Client.pm to do it for you:

    my $Client = new Net::Jabber::Client();
    $Client->AddDelegate(namespace=>"blah:blah",
			 parent=>"Net::Jabber::Query",
			 delegate=>"Blah::Blah");
    
  or

    my $Transport = new Net::Jabber::Transport();
    $Transport->AddDelegate(namespace=>"blah:blah",
			    parent=>"Net::Jabber::Query",
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
      return &Net::Jabber::SetXMLData("single",$self->{QUERY},"blah","$blah",{});
    }

    sub GetBlah {
      shift;
      my $self = shift;
      return &Net::Jabber::GetXMLData("value",$self->{QUERY},"blah","");
    }

    1;

  Now when you create a new Query object and call GetBlah on that object
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

use Net::Jabber::Query::Agent;
($Net::Jabber::Query::Agent::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Agent $VERSION required--this is only version $Net::Jabber::Query::Agent::VERSION");

use Net::Jabber::Query::Agents;
($Net::Jabber::Query::Agents::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Agents $VERSION required--this is only version $Net::Jabber::Query::Agents::VERSION");

use Net::Jabber::Query::Auth;
($Net::Jabber::Query::Auth::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Auth $VERSION required--this is only version $Net::Jabber::Query::Auth::VERSION");

use Net::Jabber::Query::AutoUpdate;
($Net::Jabber::Query::AutoUpdate::VERSION < $VERSION) &&
  die("Net::Jabber::Query::AutoUpdate $VERSION required--this is only version $Net::Jabber::Query::AutoUpdate::VERSION");

use Net::Jabber::Query::Filter;
($Net::Jabber::Query::Filter::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Filter $VERSION required--this is only version $Net::Jabber::Query::Filter::VERSION");

use Net::Jabber::Query::Fneg;
($Net::Jabber::Query::Fneg::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Fneg $VERSION required--this is only version $Net::Jabber::Query::Fneg::VERSION");

use Net::Jabber::Query::Oob;
($Net::Jabber::Query::Oob::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Oob $VERSION required--this is only version $Net::Jabber::Query::Oob::VERSION");

use Net::Jabber::Query::Register;
($Net::Jabber::Query::Register::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Register $VERSION required--this is only version $Net::Jabber::Query::Register::VERSION");

use Net::Jabber::Query::Roster;
($Net::Jabber::Query::Roster::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Roster $VERSION required--this is only version $Net::Jabber::Query::Roster::VERSION");

use Net::Jabber::Query::Search;
($Net::Jabber::Query::Search::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Search $VERSION required--this is only version $Net::Jabber::Query::Search::VERSION");

use Net::Jabber::Query::Time;
($Net::Jabber::Query::Time::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Time $VERSION required--this is only version $Net::Jabber::Query::Time::VERSION");

use Net::Jabber::Query::Version;
($Net::Jabber::Query::Version::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Version $VERSION required--this is only version $Net::Jabber::Query::Version::VERSION");

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { };
  
  $self->{VERSION} = $VERSION;

  bless($self, $proto);

  if ("@_" ne ("")) {
    my @temp = @_;
    $self->{QUERY} = \@temp;
    $self->GetDelegate();
  } else {
    $self->{QUERY} = [ "query" , [{}]];
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
# GetXMLS - returns the namespace of the query in the <iq/>
#
##############################################################################
sub GetXMLNS {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"","xmlns");
}


##############################################################################
#
# GetXML - returns the XML string that represents the data in the XML::Parser
#          Tree.
#
##############################################################################
sub GetXML {
  my $self = shift;
  $self->MergeItems() if (exists($self->{ITEMS}));
  $self->MergeAgents() if (exists($self->{AGENTS}));
  $self->MergeReleases() if (exists($self->{RELEASES}));
  $self->MergeRules() if (exists($self->{RULES}));
  return &Net::Jabber::BuildXML(@{$self->{QUERY}});
}


##############################################################################
#
# GetTree - returns the XML::Parser Tree that is stored in the guts of
#           the object.
#
##############################################################################
sub GetTree {
  my $self = shift;
  $self->MergeItems() if (exists($self->{ITEMS}));
  $self->MergeAgents() if (exists($self->{AGENTS}));
  $self->MergeReleases() if (exists($self->{RELEASES}));
  $self->MergeRules() if (exists($self->{RULES}));
  return @{$self->{QUERY}};
}


##############################################################################
#
# SetXMLS - sets the namespace of the <query/>
#
##############################################################################
sub SetXMLNS {
  my $self = shift;
  my ($xmlns) = @_;
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"","",{"xmlns"=>$xmlns});
  $self->GetDelegate();
}


##############################################################################
#
# debug - prints out the XML::Parser Tree in a readable format for debugging
#
##############################################################################
sub debug {
  my $self = shift;

  print "debug Query: $self\n";
  $self->MergeItems() if (exists($self->{ITEMS}));
  $self->MergeAgents() if (exists($self->{AGENTS}));
  $self->MergeReleases() if (exists($self->{RELEASES}));
  $self->MergeRules() if (exists($self->{RULES}));
  &Net::Jabber::printData("debug: \$self->{QUERY}->",$self->{QUERY});
}

1;
