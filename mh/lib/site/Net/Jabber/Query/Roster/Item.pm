package Net::Jabber::Query::Roster::Item;

=head1 NAME

Net::Jabber::Query::Roster::Item - Jabber IQ Roster Item Module

=head1 SYNOPSIS

  Net::Jabber::Query::Roster::Item is a companion to the 
  Net::Jabber::Query::Roster module.  It provides the user a simple 
  interface to set and retrieve all parts of a Jabber Roster Item.

=head1 DESCRIPTION

  To initialize the Item with a Jabber <iq/> and then access the roster
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iq {
      my $iq = new Net::Jabber::IQ(@_);
      my $roster = $iq->GetQuery();
      my @items = $roster->GetItems();
      foreach $item (@items) {
        ...
      }
      .
      .
      .
    }

  You now have access to all of the retrieval functions available below.

  To create a new IQ Roster Item to send to the server:

    use Net::Jabber;

    $Client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $roster = $iq->NewQuery("jabber:iq:roster");
    $item = $roster->AddItem();
    ...

    $client->Send($iq);

  Using $Item you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $jid          = $item->GetJID();
    $jidJID       = $item->GetJID("jid");
    $name         = $item->GetName();
    $subscription = $item->GetSubscription();
    $ask          = $item->GetAsk();
    @groups       = $item->GetGroups();

    @item         = $item->GetTree();
    $str          = $item->GetXML();

=head2 Creation functions

    $item->SetItem(jid=>'bob@jabber.org',
		   name=>'Bob',
		   subscription=>'both',
		   groups=>[ 'friends','school' ]);

    $item->SetJID('bob@jabber.org');
    $item->SetName('Bob');
    $item->SetSubscription('both');
    $item->SetAsk('both');
    $item->SetGroups(['friends','school']);

=head1 METHODS

=head2 Retrieval functions

  GetJID()      - returns either a string with the Jabber Identifier,
  GetJID("jid")   or a Net::Jabber::JID object for the person who is 
                  listed in this <item/>.  To get the JID object set the 
                  string to "jid", otherwise leave blank for the text
                  string.

  GetName() - returns a string with the name of the jabber ID.

  GetSubscription() - returns a string with the current subscription 
                      of this <item/>.

                      none    means no one is getting <presence/> tags
                      to      means we are getting their <presence/>
                              but they are not getting ours
                      from    means we are not getting their <presence/>
                              but they are getting ours
                      both    means we are getting their <presence/>
                              and they are getting ours
                      remove  remove this jid from the roster

  GetAsk() - returns a string with the current ask of this <item/>.
             This is the pending request by you to this JID, usually
             handled by the server.

  GetGroups() - returns an array of strings with the names of the groups
               that this <item/> belongs to.

  GetXML() - returns the XML string that represents the <presence/>.
             This is used by the Send() function in Client.pm to send
             this object as a Jabber Presence.

  GetTree() - returns an array that contains the <presence/> tag
              in XML::Parser Tree format.

=head2 Creation functions

  SetItem(jid=>string|JID,      - set multiple fields in the <item/>
          name=>string,           at one time.  This is a cumulative
          subscription=>string,   and overwriting action.  If you
          ask=>string,            set the "ask" twice, the second
          groups=>array)          setting is what is used.  If you set
                                  the name, and then set the
                                  jid then both will be in the
                                  <item/> tag.  For valid settings
                                  read the specific Set functions below.
                                  Note: group does not behave in this
                                  manner.  For each group setting a
                                  new <group/> tag will be created.

  SetJID(string) - sets the Jabber Identifier.  You can either pass a
  SetJID(JID)      string or a JID object.  They must be valid Jabber 
                   Identifiers or the server will return an error message.
                   (ie.  jabber:bob@jabber.org/Silent Bob, etc...)

  SetName(string) - sets the name this roster item should show in the
                    roster.

  SetSubscription(string) - sets the subscription that this roster item
                            has.

  SetAsk(string) - sets the ask for the <item/>.

  SetGroups(array) - sets the group for each group in the array.


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

  if ("@_" ne ("")) {
    my @temp = @_;
    $self->{ITEM} = \@temp;
  } else {
    $self->{ITEM} = [ "item" , [{}]];
  }

  return $self;
}


##############################################################################
#
# GetJID - returns the JID of the <item/>
#
##############################################################################
sub GetJID {
  my $self = shift;
  my ($type) = @_;
  my $jid = &Net::Jabber::GetXMLData("value",$self->{ITEM},"","jid");
  $type = "" unless defined($type);
  if ($type eq "jid") {
    return new Net::Jabber::JID($jid);
  } else {
    return $jid;
  }
}


##############################################################################
#
# GetName - returns the name of the <item/>
#
##############################################################################
sub GetName {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"","name");
}


##############################################################################
#
# GetSubscription - returns the subscription of the <item/>
#
##############################################################################
sub GetSubscription {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"","subscription");
}


##############################################################################
#
# GetAsk - returns the ask of the <item/>
#
##############################################################################
sub GetAsk {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"","ask");
}


##############################################################################
#
# GetGroups - returns an array of the groups of the <item/>
#
##############################################################################
sub GetGroups {
  my $self = shift;

  my @groups = &Net::Jabber::GetXMLData("value array",$self->{ITEM},"group");
  my $index;
  foreach $index (0..$#groups) {
    splice(@groups,$index,1) if ($groups[$index] eq "");
  }
  return @groups;
}


##############################################################################
#
# GetXML - returns the XML string that represents the data in the XML::Parser
#          Tree.
#
##############################################################################
sub GetXML {
  my $self = shift;
  return &Net::Jabber::BuildXML(@{$self->{ITEM}});
}


##############################################################################
#
# GetTree - returns the XML::Parser Tree that is stored in the guts of
#           the object.
#
##############################################################################
sub GetTree {
  my $self = shift;  
  return @{$self->{ITEM}};
}


##############################################################################
#
# SetItem - takes a hash of all of the things you can set on an item <query/>
#           and sets each one.
#
##############################################################################
sub SetItem {
  my $self = shift;
  my %item;
  while($#_ >= 0) { $item{ lc pop(@_) } = pop(@_); }
  
  $self->SetJID($item{jid}) if exists($item{jid});
  $self->SetName($item{name}) if exists($item{name});
  $self->SetSubscription($item{subscription}) if exists($item{subscription});
  $self->SetAsk($item{ask}) if exists($item{ask});
  $self->SetGroups($item{groups}) if exists($item{groups});
}


##############################################################################
#
# SetJID - sets the JID of the <item/>
#
##############################################################################
sub SetJID {
  my $self = shift;
  my ($jid) = @_;
  if (ref($jid) eq "Net::Jabber::JID") {
    $jid = $jid->GetJID();
  }
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"","",{jid=>$jid});
}


##############################################################################
#
# SetName - sets the name of the <item/>
#
##############################################################################
sub SetName {
  my $self = shift;
  my ($name) = @_;
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"","",{name=>$name});
}


##############################################################################
#
# SetSubscription - sets the subscription of the <item/>
#
##############################################################################
sub SetSubscription {
  my $self = shift;
  my ($subscription) = @_;
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"","",{subscription=>$subscription});
}


##############################################################################
#
# SetAsk - sets the ask of the <item/>
#
##############################################################################
sub SetAsk {
  my $self = shift;
  my ($ask) = @_;
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"","",{ask=>$ask});
}


##############################################################################
#
# SetGroups - sets the groups of the <item/>
#
##############################################################################
sub SetGroups {
  my $self = shift;
  my ($groups) = @_;
  my ($group);

  foreach $group (@{$groups}) {
    &Net::Jabber::SetXMLData("multiple",$self->{ITEM},"group",$group,{});
  }
}


##############################################################################
#
# debug - prints out the XML::Parser Tree in a readable format for debugging
#
##############################################################################
sub debug {
  my $self = shift;

  print "debug ITEM: $self\n";
  &Net::Jabber::printData("debug: \$self->{ITEM}->",$self->{ITEM});
}

1;
