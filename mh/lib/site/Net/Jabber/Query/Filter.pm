package Net::Jabber::Query::Filter;

=head1 NAME

Net::Jabber::Query::Filter - Jabber IQ Filter Module

=head1 SYNOPSIS

  Net::Jabber::Query::Filter is a companion to the Net::Jabber::Query module.
  It provides the user a simple interface to set and retrieve all parts 
  of a Jabber IQ Filter query.

=head1 DESCRIPTION

  To initialize the IQ with a Jabber <iq/> and then access the filter
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iq {
      my $iq = new Net::Jabber::IQ(@_);
      my $filter = $iq->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new IQ filter to send to the server:

    use Net::Jabber;

    $client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $filter = $iq->NewQuery("jabber:iq:filter");
    ...

    $client->Send($iq);

  Using $filter you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    @rules     = $filter->GetRules();
    @ruleTrees = $filter->GetRuleTrees();

=head2 Creation functions

    $rule   = $filter->AddRule();
    $rule   = $filter->AddRule(jid=>"bob\@jabber.org",
                               name=>"Bob",
                               groups=>["school","friends"]);

=head1 METHODS

=head2 Retrieval functions

  GetRules() - returns an array of Net::Jabber::Query::Filter::Rule objects.
               These can be modified or accessed with the functions
               available to them.

  GetRuleTrees() - returns an array of XML::Parser objects that contain
                   the data for each rule.

=head2 Creation functions

  AddRule(hash) - creates and returns a new Net::Jabbber::Query::Filter::Rule
                  object.  The argument hash is passed to the SetRule 
                  function.  Check the Net::Jabber::Query::Filter::Rule
                  for valid values.

=head1 AUTHOR

By Ryan Eatmon in June of 2000 for http://jabber.org..

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use Carp;
use vars qw($VERSION);

$VERSION = "1.0013";

use Net::Jabber::Query::Filter::Rule;
($Net::Jabber::Query::Filter::Rule::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Filter::Rule $VERSION required--this is only version $Net::Jabber::Query::Filter::Rule::VERSION");

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
# GetRules - returns an array of Net::Jabber::Query::Filter::Rule objects.
#
##############################################################################
sub GetRules {
  shift;
  my $self = shift;

  if (!(exists($self->{RULES}))) {
    my $ruleTree;
    foreach $ruleTree ($self->GetRuleTrees()) {
      my $rule = new Net::Jabber::Query::Filter::Rule(@{$ruleTree});
      push(@{$self->{RULES}},$rule);
    }
  }

  return (exists($self->{RULES}) ? @{$self->{RULES}} : ());
}


##############################################################################
#
# GetRuleTrees - returns an array of XML::Parser trees of <rule/>s.
#
##############################################################################
sub GetRuleTrees {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("tree array",$self->{QUERY},"rule");
}


##############################################################################
#
# AddRule - creates a new Net::Jabber::Query::Filter::Rule object from the tree
#           passed to the function if any.  Then it returns a pointer to that
#           object so you can modify it.
#
##############################################################################
sub AddRule {
  shift;
  my $self = shift;
  
  my $rule = new Net::Jabber::Query::Filter::Rule();
  $rule->SetRule(@_);

  print $rule->GetXML(),"\n";

  push(@{$self->{RULES}},$rule);
  return $rule;
}


##############################################################################
#
# MergeRules - takes the <rule/>s in the Net::Jabber::Query::Filter::Rule
#              objects and pulls the data out and merges it into the <query/>.
#              This is a private helper function.  It should be used any time
#              you need to access the full <query/> so that the <rule/>s are
#              included.  (ie. GetXML, GetTree, debug, etc...)
#
##############################################################################
sub MergeRules {
  shift;
  my $self = shift;
  my (@tree);
  my $count = 1;
  my $rule;
  foreach $rule (@{$self->{RULES}}) {
    @tree = $rule->GetTree();
    $self->{QUERY}->[1]->[$count++] = "rule";
    $self->{QUERY}->[1]->[$count++] = ($rule->GetTree())[1];
  }
}


1;
