package Net::Jabber::Query::Agent;

=head1 NAME

Net::Jabber::Query::Agent - Jabber Query Agent Module

=head1 SYNOPSIS

  Net::Jabber::Query::Agent is a companion to the Net::Jabber::Query 
  module. It provides the user a simple interface to set and retrieve all 
  parts of a Jabber Query Agent.

=head1 DESCRIPTION

  To initialize the Agent with a Jabber <iq/> you must pass it the 
  XML::Parser Tree array from the module trying to access the <iq/>.  
  In the callback function:

    use Net::Jabber;

    sub iqCB {
      my $iq = new Net::Jabber::IQ(@_);
      my $agent = $iq->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new Agent to send to the server:

    use Net::Jabber;

    $iq = new Net::Jabber::IQ();
    $agent = $iq->NewQuery("jabber:iq:agent");

  Now you can call the creation functions below.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $jid         = $agent->GetJID();
    $name        = $agent->GetName();
    $description = $agent->GetDescription();
    $transport   = $agent->GetTransport();
    $service     = $agent->GetService();
    $register    = $agent->GetRegister();
    $search      = $agent->GetSearch();
    $groupchat   = $agent->GetGroupChat();
    $agents      = $agent->GetAgents();

=head2 Creation functions

    $agent->SetAgent(jid=>"users.jabber.org",
		     name=>"Jabber User Directory",
	             description=>"You may register and create a public 
                                   searchable profile, and search for 
                                   other registered Jabber users.",
		     service=>"jud",
		     register=>"",
		     search=>"");

    $agent->SetJID("icq.jabber.org");
    $agent->SetName("ICQ Transport");
    $agent->SetDescription("This is the ICQ Transport");
    $agent->SetTransport("ICQ#");
    $agent->SetService("icq");
    $agent->SetRegister();
    $agent->SetSearch();
    $agent->SetGroupChat();
    $agent->SetAgents();

=head1 METHODS

=head2 Retrieval functions

  GetJID() - returns a string with the JID of the agent to send 
             messages to.

  GetName() - returns a string with the name of the agent.

  GetDescription() - returns a string with the description of 
                     the agent.

  GetTransport() - returns a string with the transport of the agent.

  GetService() - returns a string with the service name of the agent.

  GetRegister() - returns a 1 if the agent supports registering, 
                  0 if not.

  GetSearch() - returns a 1 if the agent supports searching, 0 if not.

  GetGroupChat() - returns a 1 if the agent supports groupchat, 0 if not.

  GetAgents() - returns a 1 if the agent supports sub-agents, 0 if not.


=head2 Creation functions

  SetAgent(jid=>string,         - set multiple fields in the <iq/> at one
           name=>string,          time.  This is a cumulative and over
           description=>string,   writing action.  If you set the "jid"
           transport=>string,     attribute twice, the second setting is
           service=>string,       what is used.  If you set the name, and
           register=>string,      then set the search then both will be in
           search=>string,        the <iq/> tag.  For valid settings read the
           groupchat=>string)     specific Set functions below.
           agents=>string)

  SetJID(string) - sets the jid="..." of the agent.

  SetName(string) - sets the <name/> of the agent.

  SetDescription(string) - sets the <description/> of the agent.

  SetTransport(string) - sets the <transport/> of the agent.

  SetService(string) - sets the <service/> of the agent.

  SetRegister() - if the function is called then a <search/> is
                  is put in the <query/> to signify searching is
                  available.

  SetSearch() - if the function is called then a <search/> is
                is put in the <query/> to signify searching is
                available.

  SetGroupChat() - if the function is called then a <groupchat/> is
                   is put in the <query/> to signify groupchat is
                   available.

  SetAgents() - if the function is called then a <agents/> is
                is put in the <query/> to signify sub-agents are
                available.

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

  if ("@_" ne "") {
    my @temp = @_;
    $self->{AGENT} = \@temp;
  }
  
  $self->{VERSION} = $VERSION;

  bless($self, $proto);

  return $self;
}


##############################################################################
#
# GetJID - returns the jabber id of the jabber:iq:agent
#
##############################################################################
sub GetJID {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::GetXMLData("value",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"","jid");
}


##############################################################################
#
# GetName - returns the name of the jabber:iq:agent
#
##############################################################################
sub GetName {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::GetXMLData("value",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"name","");
}


##############################################################################
#
# GetDescription - returns the description of the jabber:iq:agent
#
##############################################################################
sub GetDescription {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::GetXMLData("value",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"description","");
}


##############################################################################
#
# GetTransport - returns the namr of the jabber:iq:agent
#
##############################################################################
sub GetTransport {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::GetXMLData("value",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"transport","");
}


##############################################################################
#
# GetService - returns the namr of the jabber:iq:agent
#
##############################################################################
sub GetService {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::GetXMLData("value",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"service","");
}


##############################################################################
#
# GetRegister - returns the namr of the jabber:iq:agent
#
##############################################################################
sub GetRegister {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::GetXMLData("existence",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"register","");
}


##############################################################################
#
# GetSearch - returns the namr of the jabber:iq:agent
#
##############################################################################
sub GetSearch {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::GetXMLData("existence",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"search","");
}


##############################################################################
#
# GetGroupChat - returns the namr of the jabber:iq:agent
#
##############################################################################
sub GetGroupChat {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::GetXMLData("existence",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"groupchat","");
}


##############################################################################
#
# GetAgents - returns the namr of the jabber:iq:agent
#
##############################################################################
sub GetAgents {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::GetXMLData("existence",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"agents","");
}


##############################################################################
#
# GetXML - returns the XML string that represents the data in the XML::Parser
#          Tree.
#
##############################################################################
sub GetXML {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return &Net::Jabber::BuildXML(@{$self->{AGENT}});
}


##############################################################################
#
# GetTree - returns the XML::Parser Tree that is stored in the guts of
#           the object.
#
##############################################################################
sub GetTree {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  return @{$self->{AGENT}};
}


##############################################################################
#
# SetAgent - takes a hash of all of the things you can set on a 
#            jabber:iq:agent and sets each one.
#
##############################################################################
sub SetAgent {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  my %agent;
  while($#_ >= 0) { $agent{ lc pop(@_) } = pop(@_); }

  $self->SetJID($agent{jid}) if exists($agent{jid});
  $self->SetName($agent{name}) if exists($agent{name});
  $self->SetDescription($agent{description}) if exists($agent{description});
  $self->SetTransport($agent{transport}) if exists($agent{transport});
  $self->SetService($agent{service}) if exists($agent{service});
  $self->SetRegister() if exists($agent{register});
  $self->SetSearch() if exists($agent{search});
  $self->SetGroupChat() if exists($agent{groupchat});
  $self->SetAgents() if exists($agent{agents});
}


##############################################################################
#
# SetJID - sets the jid in the jabber:iq:agent
#
##############################################################################
sub SetJID {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  my ($jid) = @_;
  &Net::Jabber::SetXMLData("single",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"","",{jid=>$jid});
}


##############################################################################
#
# SetName - sets the name in the jabber:iq:agent
#
##############################################################################
sub SetName {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  my ($name) = @_;
  &Net::Jabber::SetXMLData("single",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"name",$name,{});
}


##############################################################################
#
# SetDescription - sets the description in the jabber:iq:agent
#
##############################################################################
sub SetDescription {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  my ($description) = @_;
  
  &Net::Jabber::SetXMLData("single",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"description",$description,{});
}


##############################################################################
#
# SetTransport - sets the transport in the jabber:iq:agent
#
##############################################################################
sub SetTransport {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  my ($transport) = @_;
  &Net::Jabber::SetXMLData("single",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"transport",$transport,{});
}


##############################################################################
#
# SetService - sets the service in the jabber:iq:agent
#
##############################################################################
sub SetService {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  my ($service) = @_;
  &Net::Jabber::SetXMLData("single",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"service",$service,{});
}


##############################################################################
#
# SetRegister - sets the register in the jabber:iq:agent
#
##############################################################################
sub SetRegister {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  &Net::Jabber::SetXMLData("single",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"register","",{});
}


##############################################################################
#
# SetSearch - sets the search in the jabber:iq:agent
#
##############################################################################
sub SetSearch {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  &Net::Jabber::SetXMLData("single",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"search","",{});
}


##############################################################################
#
# SetGroupChat - sets the groupchat in the jabber:iq:agent
#
##############################################################################
sub SetGroupChat {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  &Net::Jabber::SetXMLData("single",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"groupchat","",{});
}


##############################################################################
#
# SetAgents - sets the agents in the jabber:iq:agent
#
##############################################################################
sub SetAgents {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});
  &Net::Jabber::SetXMLData("single",(!exists($self->{AGENT}) ? $self->{QUERY} : $self->{AGENT}),"agents","",{});
}


##############################################################################
#
# debug - prints out the XML::Parser Tree in a readable format for debugging
#
##############################################################################
sub debug {
  my $self = shift;
  $self = shift if !exists($self->{AGENT});

  print "debug AGENT: $self\n";
  &Net::Jabber::printData("debug: \$self->{AGENT}->",$self->{AGENT});
}

1;
