package Net::Jabber::Query::Agents;

=head1 NAME

Net::Jabber::Query::Agents - Jabber Query Agents Module

=head1 SYNOPSIS

  Net::Jabber::Query::Agents is a companion to the Net::Jabber::Query 
  module. It provides the user a simple interface to set and retrieve all 
  parts of a Jabber Query Agents.

=head1 DESCRIPTION

  To initialize the Agents with a Jabber <iq/> you must pass it the 
  XML::Parser Tree array from the module trying to access the <iq/>.  
  In the callback function:

    use Net::Jabber;

    sub iqCB {
      my $iq = new Net::Jabber::IQ(@_);
      my $agents = $iq->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new Agents request to send to the server:

    use Net::Jabber;

    $client = new Net::Jabber::Client();

    $iq = new Net::Jabber::IQ();
    $agents = $iq->NewQuery("jabber:iq:agents");

    $client->Send($iq);

  Or you can call the creation functions below before sending.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    @agents      = $agents->GetAgents();
    @agentTreess = $agents->GetAgentTrees();

=head2 Creation functions

    $agent = $agents->NewAgent();
    $agent = $agents->NewAgent(jid=>"icq.jabber.org",
			       name=>"ICQ Transport",
			       description=>"This is the ICQ Transport",
			       transport=>"ICQ#",
			       service=>"icq",
			       register=>"",
			       search=>"");

=head1 METHODS

=head2 Retrieval functions

  GetAgents() - returns an array of Net::Jabber::Query::Agent
                objects.  For more info on this object see the
                docs for Net::Jabber::Query::Agent.

  GetAgentTrees() - returns an array of XML::Parser objects that
                    contain the data for each agent.

=head2 Creation functions

  NewAgent(hash) - creates and returns a new Net::Jabber::Query::Agent
                   object.  The argument hash is passed to the SetAgent
                   function.  Check the Net::Jabber::Query::Agent 
                   man page for the valid values.

=head1 AUTHOR

By Ryan Eatmon in May of 2000 for http://jabber.org..

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use Carp;
use vars qw($VERSION);

$VERSION = "1.0013";

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { };
  
  $self->{VERSION} = $VERSION;

  bless($self, $proto);

  return $self;
}


##############################################################################
#
# GetAgents - returns an array of Net::Jabber::Query::Agent objects containing
#             the list of available Transport/Agents on the server.
#
##############################################################################
sub GetAgents {
  shift;
  my $self = shift;

  if (!(exists($self->{AGENTS}))) {
    my $agentTree;
    foreach $agentTree ($self->GetAgentTrees()) {
      my $agent = new Net::Jabber::Query::Agent(@{$agentTree});
      push(@{$self->{AGENTS}},$agent);
    }
  }

  return (exists($self->{AGENTS}) ? @{$self->{AGENTS}} : ());
}


##############################################################################
#
# GetAgentTrees - returns an array of XML::Parser trees of <agent/>s.
#
##############################################################################
sub GetAgentTrees {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("tree array",$self->{QUERY},"agent","","");
}


##############################################################################
#
# AddAgent - returns a Net::Jabber::Query::Agent object afte pushing it onto
#            the AGENTS list.
#
##############################################################################
sub AddAgent {
  shift;
  my $self = shift;

  my $agent = new Net::Jabber::Query::Agent("agent",[{}]);
  $agent->SetAgent(@_);
  push(@{$self->{AGENTS}},$agent);
  return $agent;
}


##############################################################################
#
# MergeAgents - takes the <agents/>s in the Net::Jabber::Query::Agent objects
#               and pulls the data out and merges it into the <query/>.
#               This is a private helper function.  It should be used any time
#               you need to access the full <query/> so that the <item/>s are
#               included.  (ie. GetXML, GetTree, debug, etc...)
#
##############################################################################
sub MergeAgents {
  shift;
  my $self = shift;
  my @tree;
  my $count = 1;
  my $agent;
  foreach $agent (@{$self->{AGENTS}}) {
    @tree = $agent->GetTree();
    $self->{QUERY}->[1]->[$count++] = "agent";
    $self->{QUERY}->[1]->[$count++] = ($agent->GetTree())[1];
  }
}


1;
