package Net::Jabber::X::Roster;

=head1 NAME

Net::Jabber::X::Roster - Jabber IQ Roster Module

=head1 SYNOPSIS

  Net::Jabber::X::Roster is a companion to the Net::Jabber::X module.
  It provides the user a simple interface to set and retrieve all parts 
  of a Jabber IQ Roster x.

=head1 DESCRIPTION

  To initialize the IQ with a Jabber <iq/> and then access the roster
  x you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub foo {
      my $foo = new Net::Jabber::Foo(@_);

      my @xTags = $foo->GetX("jabber:x:roster");

      my $xTag;
      foreach $xTag (@xTags) {
        $xTag->....
        
      }
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new IQ roster to send to the server:

    use Net::Jabber;

    $client = new Net::Jabber::Client();
    ...

    $foo = new Net::Jabber::Foo();
    $roster = $foo->NewX("jabber:x:roster");
    ...

    $client->Send($foo);

  Using $roster you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    @items  = $roster->GetItems();

=head2 Creation functions

    $item   = $roster->AddItem();

=head1 METHODS

=head2 Retrieval functions

  GetItems() - returns an array of Net::Jabber::X::Roster::Item objects.
               These can be modified or accessed with the functions
               available to them.

=head2 Creation functions

  AddItem(XML::Parser tree) - creates a new Net::Jabbber::X::Roster::Item
                              object and populates it with the tree if one
                              was passed in.  This returns the pointer to
                              the <item/> so you can modify it with the
                              creation functions from that module.

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

use Net::Jabber::X::Roster::Item;
($Net::Jabber::X::Roster::Item::VERSION < $VERSION) &&
  die("Net::Jabber::X::Roster::Item $VERSION required--this is only version $Net::Jabber::X::Roster::Item::VERSION");

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
# GetItems - returns an array of Net::Jabber::X::Roster::Item objects.
#
##############################################################################
sub GetItems {
  shift;
  my $self = shift;

  if (!(exists($self->{ITEMS}))) {
    my $itemTree;
    foreach $itemTree ($self->GetItemTrees()) {
      my $item = new Net::Jabber::X::Roster::Item(@{$itemTree});
      push(@{$self->{ITEMS}},$item);
    }
  }

  return (exists($self->{ITEMS}) ? @{$self->{ITEMS}} : ());
}


##############################################################################
#
# AddItem - creates a new Net::Jabber::X::Roster::Item object from the tree
#           passed to the function if any.  Then it returns a pointer to that
#           object so you can modify it.
#
##############################################################################
sub AddItem {
  shift;
  my $self = shift;
  my (@tree) = @_;
  
  my $itemObj = new Net::Jabber::X::Roster::Item(@tree);
  push(@{$self->{ITEMS}},$itemObj);
  return $itemObj;
}


##############################################################################
#
# GetItemTrees - returns an array of XML::Parser trees of <item/>s.
#
##############################################################################
sub GetItemTrees {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("tree array",$self->{X},"item");
}


##############################################################################
#
# MergeItems - takes the <item/>s in the Net::Jabber::X::Roster::Item
#              objects and pulls the data out and merges it into the <x/>.
#              This is a private helper function.  It should be used any time
#              you need to access the full <x/> so that the <item/>s are
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
    $self->{X}->[1]->[$count++] = "item";
    $self->{X}->[1]->[$count++] = ($item->GetTree())[1];
  }
}


1;
