package Net::Jabber::Query::Search::Item;

=head1 NAME

Net::Jabber::Query::Search::Item - Jabber IQ Search Item Module

=head1 SYNOPSIS

  Net::Jabber::Query::Search::Item is a companion to the 
  Net::Jabber::Query::Search module.  It provides the user a simple 
  interface to set and retrieve all parts of a Jabber Search Item.

=head1 DESCRIPTION

  To initialize the Item with a Jabber <iq/> and then access the search
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iq {
      my $iq = new Net::Jabber::IQ(@_);
      my $search = $iq->GetQuery();
      my @items = $search->GetItems();
      foreach $item (@items) {
        ...
      }
      .
      .
      .
    }

  You now have access to all of the retrieval functions available below.

  To create a new IQ Search Item to send to the server:

    use Net::Jabber;

    $Client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $search = $iq->NewQuery("jabber:iq:search");
    $item = $search->AddItem();
    ...

    $client->Send($iq);

  Using $Item you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $jid    = $item->GetJID();
    $jidJID = $item->GetJID("jid");
    $name   = $item->GetName();
    $first  = $item->GetFirst();
    $given  = $item->GetGiven();
    $last   = $item->GetLast();
    $family = $item->GetFamily();
    $nick   = $item->GetNick();
    $email  = $item->GetEmail();

    %result = $item->GetResult();

    @item   = $item->GetTree();
    $str    = $item->GetXML();

=head2 Creation functions

    $item->SetItem(jid=>'bob@jabber.org',
		   name=>'Bob',
		   first=>'Bob',
		   last=>'Smith',
		   nick=>'bob',
		   email=>'bob@hotmail.com');

    $item->SetJID('bob@jabber.org');
    $item->SetName('Bob Smith');
    $item->SetFirst('Bob');
    $item->SetGiven('Bob');
    $item->SetLast('Smith');
    $item->SetFamily('Smith');
    $item->SetNick('bob');
    $item->SetEmail('bob@bobworld.com');

=head2 Test functions

    $test = $item->DefinedName();
    $test = $item->DefinedFirst();
    $test = $item->DefinedGiven();
    $test = $item->DefinedLast();
    $test = $item->DefinedFamily();
    $test = $item->DefinedNick();
    $test = $item->DefinedEmail();

=head1 METHODS

=head2 Retrieval functions

  GetJID()      - returns either a string with the Jabber Identifier,
  GetJID("jid")   or a Net::Jabber::JID object for the account that is 
                  listed in this <item/>.  To get the JID object set the 
                  string to "jid", otherwise leave blank for the text
                  string.

  GetName() - returns a string with the full name of the account being 
              returned.

  GetFirst() - returns a string with the first name of the account being 
               returned.

  GetGiven() - returns a string with the given name of the account being 
               returned.

  GetLast() - returns a string with the last name of the jabber account 
              being returned.

  GetFamily() - returns a string with the family name of the jabber 
                account being returned.

  GetNick() - returns a string with the nick of the jabber account being 
              returned.

  GetEmail() - returns a string with the email of the jabber account being 
               returned.

  GetResult() - returns a hash with all of the valid fields set.  Here is
                the way the hash might look.

                  $result{last} = "Smith";
                  $result{first} = "Bob";

  GetXML() - returns the XML string that represents the <presence/>.
             This is used by the Send() function in Client.pm to send
             this object as a Jabber Presence.

  GetTree() - returns an array that contains the <presence/> tag
              in XML::Parser Tree format.

=head2 Creation functions

  SetItem(jid=>string|JID, - set multiple fields in the <item/>
          name=>string,      at one time.  This is a cumulative
          first=>string,     and overwriting action.  If you
          given=>string,     set the "name" twice, the second
          last=>string,      setting is what is used.  If you set
          family=>string)    the first, and then set the
          nick=>string,      last then both will be in the
          email=>string)     <item/> tag.  For valid settings
                             read the specific Set functions below.

  SetJID(string) - sets the Jabber Identifier.  You can either pass a
  SetJID(JID)      string or a JID object.  They must be valid Jabber 
                   Identifiers or the server will return an error message.
                   (ie.  jabber:bob@jabber.org/Silent Bob, etc...)

  SetName(string) - sets the name this search item should show in the
                    search.

  SetFirst(string) - sets the first name this search item should show 
                     in the search.

  SetGiven(string) - sets the given name this search item should show 
                     in the search.

  SetLast(string) - sets the last name this search item should show in
                    the search.

  SetFamily(string) - sets the family name this search item should show 
                      in the search.

  SetNick(string) - sets the nick this search item should show in the
                    search.

  SetEmail(string) - sets the email this search item should show in the
                     search.

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
  $type = "" unless defined($type);
  my $jid = &Net::Jabber::GetXMLData("value",$self->{ITEM},"","jid");
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
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"name","");
}


##############################################################################
#
# GetFirst - returns the first of the <item/>
#
##############################################################################
sub GetFirst {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"first","");
}


##############################################################################
#
# GetGiven - returns the given of the <item/>
#
##############################################################################
sub GetGiven {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"given","");
}


##############################################################################
#
# GetLast - returns the last of the <item/>
#
##############################################################################
sub GetLast {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"last","");
}


##############################################################################
#
# GetFamily - returns the family of the <item/>
#
##############################################################################
sub GetFamily {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"family","");
}


##############################################################################
#
# GetNick - returns the nick of the <item/>
#
##############################################################################
sub GetNick {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"nick","");
}


##############################################################################
#
# GetEmail - returns the email of the <item/>
#
##############################################################################
sub GetEmail {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{ITEM},"email","");
}


##############################################################################
#
# GetResult - returns a hash that contains the set fields.
#
##############################################################################
sub GetResult {
  my $self = shift;

  my %result;
  $result{name} = $self->GetName() if ($self->DefinedName());
  $result{first} = $self->GetFirst() if ($self->DefinedFirst());
  $result{given} = $self->GetGiven() if ($self->DefinedGiven());
  $result{last} = $self->GetLast() if ($self->DefinedLast());
  $result{family} = $self->GetFamily() if ($self->DefinedFamily());
  $result{nick} = $self->GetNick() if ($self->DefinedNick());
  $result{email} = $self->GetEmail() if ($self->DefinedEmail());

  return %result;
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
  $self->SetFirst($item{first}) if exists($item{first});
  $self->SetGiven($item{given}) if exists($item{given});
  $self->SetLast($item{last}) if exists($item{last});
  $self->SetFamily($item{family}) if exists($item{family});
  $self->SetNick($item{nick}) if exists($item{nick});
  $self->SetEmail($item{email}) if exists($item{email});
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
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"name","$name",{});
}


##############################################################################
#
# SetFirst - sets the first of the <item/>
#
##############################################################################
sub SetFirst {
  my $self = shift;
  my ($first) = @_;
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"first","$first",{});
}


##############################################################################
#
# SetGiven - sets the given of the <item/>
#
##############################################################################
sub SetGiven {
  my $self = shift;
  my ($given) = @_;
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"given","$given",{});
}


##############################################################################
#
# SetLast - sets the last of the <item/>
#
##############################################################################
sub SetLast {
  my $self = shift;
  my ($last) = @_;
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"last","$last",{});
}


##############################################################################
#
# SetFamily - sets the family of the <item/>
#
##############################################################################
sub SetFamily {
  my $self = shift;
  my ($family) = @_;
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"family","$family",{});
}


##############################################################################
#
# SetNick - sets the nick of the <item/>
#
##############################################################################
sub SetNick {
  my $self = shift;
  my ($nick) = @_;
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"nick","$nick",{});
}


##############################################################################
#
# SetEmail - sets the email of the <item/>
#
##############################################################################
sub SetEmail {
  my $self = shift;
  my ($email) = @_;
  &Net::Jabber::SetXMLData("single",$self->{ITEM},"email","$email",{});
}


##############################################################################
#
# DefinedName - returns the name of the <item/>
#
##############################################################################
sub DefinedName {
  my $self = shift;
  return &Net::Jabber::GetXMLData("existence",$self->{ITEM},"name","");
}


##############################################################################
#
# DefinedFirst - returns the first of the <item/>
#
##############################################################################
sub DefinedFirst {
  my $self = shift;
  return &Net::Jabber::GetXMLData("existence",$self->{ITEM},"first","");
}


##############################################################################
#
# DefinedGiven - returns the given of the <item/>
#
##############################################################################
sub DefinedGiven {
  my $self = shift;
  return &Net::Jabber::GetXMLData("existence",$self->{ITEM},"given","");
}


##############################################################################
#
# DefinedLast - returns the last of the <item/>
#
##############################################################################
sub DefinedLast {
  my $self = shift;
  return &Net::Jabber::GetXMLData("existence",$self->{ITEM},"last","");
}


##############################################################################
#
# DefinedFamily - returns the family of the <item/>
#
##############################################################################
sub DefinedFamily {
  my $self = shift;
  return &Net::Jabber::GetXMLData("existence",$self->{ITEM},"family","");
}


##############################################################################
#
# DefinedNick - returns the nick of the <item/>
#
##############################################################################
sub DefinedNick {
  my $self = shift;
  return &Net::Jabber::GetXMLData("existence",$self->{ITEM},"nick","");
}


##############################################################################
#
# DefinedEmail - returns the email of the <item/>
#
##############################################################################
sub DefinedEmail {
  my $self = shift;
  return &Net::Jabber::GetXMLData("existence",$self->{ITEM},"email","");
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
