package Net::Jabber::Query::Roster;

=head1 NAME

Net::Jabber::Query::Roster - Jabber IQ Roster Module

=head1 SYNOPSIS

  Net::Jabber::Query::Roster is a companion to the Net::Jabber::Query module.
  It provides the user a simple interface to set and retrieve all parts 
  of a Jabber IQ Roster query.

=head1 DESCRIPTION

  To initialize the IQ with a Jabber <iq/> and then access the roster
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iq {
      my $iq = new Net::Jabber::IQ(@_);
      my $roster = $iq->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new IQ roster to send to the server:

    use Net::Jabber;

    $client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $roster = $iq->NewQuery("jabber:iq:roster");
    ...

    $client->Send($iq);

  Using $roster you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    @items     = $roster->GetItems();
    @itemTrees = $roster->GetItemTrees();

=head2 Creation functions

    $item   = $roster->AddItem();
    $item   = $roster->AddItem(jid=>"bob\@jabber.org",
                               name=>"Bob",
                               groups=>["school","friends"]);

=head1 METHODS

=head2 Retrieval functions

  GetItems() - returns an array of Net::Jabber::Query::Roster::Item objects.
               These can be modified or accessed with the functions
               available to them.

  GetItemTrees() - returns an array of XML::Parser objects that contain
                   the data for each item.

=head2 Creation functions

  AddItem(hash) - creates and returns a new Net::Jabbber::Query::Roster::Item
                  object.  The argument hash is passed to the SetItem 
                  function.  Check the Net::Jabber::Query::Roster::Item
                  for valid values.

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

use Net::Jabber::Query::Roster::Item;
($Net::Jabber::Query::Roster::Item::VERSION < $VERSION) &&
  die("Net::Jabber::Query::Roster::Item $VERSION required--this is only version $Net::Jabber::Query::Roster::Item::VERSION");

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
# GetItems - returns an array of Net::Jabber::Query::Roster::Item objects.
#
##############################################################################
sub GetItems {
  shift;
  my $self = shift;

  if (!(exists($self->{ITEMS}))) {
    my $itemTree;
    foreach $itemTree ($self->GetItemTrees()) {
      my $item = new Net::Jabber::Query::Roster::Item(@{$itemTree});
      push(@{$self->{ITEMS}},$item);
    }
  }

  return (exists($self->{ITEMS}) ? @{$self->{ITEMS}} : ());
}


##############################################################################
#
# GetItemTrees - returns an array of XML::Parser trees of <item/>s.
#
##############################################################################
sub GetItemTrees {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("tree array",$self->{QUERY},"item");
}


##############################################################################
#
# AddItem - creates a new Net::Jabber::Query::Roster::Item object from the tree
#           passed to the function if any.  Then it returns a pointer to that
#           object so you can modify it.
#
##############################################################################
sub AddItem {
  shift;
  my $self = shift;
  
  my $item = new Net::Jabber::Query::Roster::Item("item",[{}]);
  $item->SetItem(@_);
  push(@{$self->{ITEMS}},$item);
  return $item;
}


##############################################################################
#
# MergeItems - takes the <item/>s in the Net::Jabber::Query::Roster::Item
#              objects and pulls the data out and merges it into the <query/>.
#              This is a private helper function.  It should be used any time
#              you need to access the full <query/> so that the <item/>s are
#              included.  (ie. GetXML, GetTree, debug, etc...)
#
##############################################################################
sub MergeItems {
  shift;
  my $self = shift;
  my (@tree);
  my $count = 1;
  my ($item);
  foreach $item (@{$self->{ITEMS}}) {
    @tree = $item->GetTree();
    $self->{QUERY}->[1]->[$count++] = "item";
    $self->{QUERY}->[1]->[$count++] = ($item->GetTree())[1];
  }
}


1;
