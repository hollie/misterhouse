package Net::Jabber::Presence;

=head1 NAME

Net::Jabber::Presence - Jabber Presence Module

=head1 SYNOPSIS

  Net::Jabber::Presence is a companion to the Net::Jabber module.  
  It provides the user a simple interface to set and retrieve all 
  parts of a Jabber Presence.

=head1 DESCRIPTION

  To initialize the Presence with a Jabber <presence/> you must pass it 
  the XML::Parser Tree array from the Net::Jabber::Client module.  In the
  callback function for the presence:

    use Net::Jabber;

    sub presence {
      my $presence = new Net::Jabber::Presence(@_);
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new presence to send to the server:

    use Net::Jabber;

    $Pres = new Net::Jabber::Presence();

  Now you can call the creation functions below to populate the tag before
  sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $to         = $Pres->GetTo();
    $toJID      = $Pres->GetTo("jid");
    $from       = $Pres->GetFrom();
    $fromJID    = $Pres->GetFrom("jid");
    $etherxTo   = $Pres->GetEtherxTo();
    $etherxFrom = $Pres->GetEtherxFrom();
    $type       = $Pres->GetType();
    $status     = $Pres->GetStatus();
    $priority   = $Pres->GetPriority();
    $meta       = $Pres->GetMeta();
    $icon       = $Pres->GetIcon();
    $show       = $Pres->GetShow();
    $loc        = $Pres->GetLoc();
    @xTags      = $Pres->GetX();
    @xTags      = $Pres->GetX("my:namespace");
    @xTrees     = $Pres->GetXTrees();
    @xTrees     = $Pres->GetXTrees("my:namespace");

    $str        = $Pres->GetXML();
    @presence   = $Pres->GetTree();

=head2 Creation functions

    $Pres->SetPresence(TYPE=>"online",
		       StatuS=>"Open for Business",
		       iCoN=>"normal");
    $Pres->SetTo("bob\@jabber.org");
    $Pres->SetFrom("jojo\@jabber.org");
    $Pres->SetEtherxTo("jabber.org");
    $Pres->SetEtherxFrom("transport.jabber.org");
    $Pres->SetType("unavailable");
    $Pres->SetStatus("Taking a nap");
    $Pres->SetPriority(10);
    $Pres->SetMeta("PerlClient/1.0");
    $Pres->SetIcon("zzz");
    $Pres->SetShow("away");
    $Pres->SetLoc("Lat: 32.91206 Lon: -96.75097");

    $X = $Pres->NewX("jabber:x:delay");
    $X = $Pres->NewX("my:namespace");

    $Reply = $Pres->Reply();
    $Reply = $Pres->Reply(template=>"client");
    $Reply = $Pres->Reply(template=>"transport",
                          type=>"subscribed");

=head1 METHODS

=head2 Retrieval functions

  GetTo()      - returns either a string with the Jabber Identifier,
  GetTo("jid")   or a Net::Jabber::JID object for the person who is 
                 going to receive the <presence/>.  To get the JID
                 object set the string to "jid", otherwise leave
                 blank for the text string.

  GetFrom()      -  returns either a string with the Jabber Identifier,
  GetFrom("jid")    or a Net::Jabber::JID object for the person who
                    sent the <presence/>.  To get the JID object set 
                    the string to "jid", otherwise leave blank for the 
                    text string.

  GetEtherxTo(string) - returns the etherx:to attribute.  This is for
                        Transport writers who need to communicate with
                        Etherx.

  GetEtherxFrom(string) -  returns the etherx:from attribute.  This is for
                           Transport writers who need to communicate with
                           Etherx.

  GetType() - returns a string with the type <presence/> this is.

  GetStatus() - returns a string with the current status of the resource.

  GetPriority() - returns an integer with the priority of the resource
                  The default is 0 if there is no priority in this presence.

  GetMeta() - returns a string with the meta data of the client of the sender.

  GetIcon() - returns a string with the icon the client should display.

  GetShow() - returns a string with the state the client should show.

  GetLoc() - returns a string with the location the sender is at.

  GetX(string) - returns an array of Net::Jabber::X objects.  The string can 
                 either be empty or the XML Namespace you are looking for.  
                 If empty then GetX returns every <x/> tag in the 
                 <presence/>.  If an XML Namespace is sent then GetX 
                 returns every <x/> tag with that Namespace.

  GetXTrees(string) - returns an array of XML::Parser::Tree objects.  The 
                      string can either be empty or the XML Namespace you 
                      are looking for.  If empty then GetXTrees returns every 
                      <x/> tag in the <presence/>.  If an XML Namespace is 
                      sent then GetXTrees returns every <x/> tag with that 
                      Namespace.

  GetXML() - returns the XML string that represents the <presence/>.
             This is used by the Send() function in Client.pm to send
             this object as a Jabber Presence.

  GetTree() - returns an array that contains the <presence/> tag
              in XML::Parser Tree format.

=head2 Creation functions


#
# todo: add etherxto and from to the list...
#


  SetPresence(to=>string|JID     - set multiple fields in the <presence/>
              from=>string|JID,    at one time.  This is a cumulative
              type=>string,        and over writing action.  If you set
              status=>integer,     the "to" attribute twice, the second
              priority=>string,    setting is what is used.  If you set
              meta=>string,        the status, and then set the priority
              icon=>string,        then both will be in the <presence/>
              show=>string,        tag.  For valid settings read the
              loc=>string)         specific Set functions below.

  SetTo(string) - sets the to attribute.  You can either pass a string
  SetTo(JID)      or a JID object.  They must be valid Jabber 
                  Identifiers or the server will return an error message.
                  (ie.  jabber:bob@jabber.org/Silent Bob, etc...)

  SetFrom(string) - sets the from attribute.  You can either pass a string
  SetFrom(JID)      or a JID object.  They must be valid Jabber 
                    Identifiers or the server will return an error message.
                    (ie.  jabber:bob@jabber.org/Silent Bob, etc...)

  SetEtherxTo(string) - sets the etherx:to attribute.  This is for
                        Transport writers who need to communicate with
                        Etherx.

  SetEtherxFrom(string) -  sets the etherx:from attribute.  This is for
                           Transport writers who need to communicate with
                           Etherx.

  SetType(string) - sets the type attribute.  Valid settings are:

                    available       available to receive messages; default
                    unavailable     unavailable to receive anything
                    subscribe       ask the recipient to subscribe you
                    subscribed      tell the sender they are subscribed
                    unsubscribe     ask the recipient to unsubscribe you
                    unsubscribed    tell the sender they are unsubscribed
                    probe           probe

  SetStatus(string) - sets the status tag to be whatever string the user
                      wants associated with that resource.

  SetPriority(integer) - sets the priority of this resource.  The highest
                         resource attached to the jabber account is the
                         one that receives the messages.

  SetMeta(string) - sets the meta data that tells everyone something about
  <DRAFT)           your client.  
                    (ie. device/pager, PerlClient/1.0, etc...)

  SetIcon(string) - sets the name or URL of the icon to display for this
  (DRAFT)           resource.

  SetShow(string) - sets the name of the default symbol to display for this
  (DRAFT)           resource.

  SetLoc(string) - sets the location that the user wants associated with
  (DRAFT)          the resource.

  NewX(string) - creates a new Net::Jabber::X object with the namespace
                 in the string.  In order for this function to work with
                 a custom namespace, you must define and register that  
                 namespace with the X module.  For more information
                 please read the documentation for Net::Jabber::X.

  Reply(template=>string, - creates a new Presence object and
        type=>string)       populates the to/from and
                            etherxto/etherxfrom fields based
                            the value of template.  The following
                            templates are available:

                            client: (default)
                                 just sets the to/from

                            transport:
                            transport-reply:
                                 the transport will send the
                                 reply to the sender

                            The type will be set in the <presence/>.

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

  $self->{DEBUG} = new Net::Jabber::Debug(usedefault=>1,
					  header=>"NJ::Presence");

  if ("@_" ne ("")) {
    my @temp = @_;
    $self->{PRESENCE} = \@temp;
    my $xTree;
    foreach $xTree ($self->GetXTrees()) {
      my $xmlns = &Net::Jabber::GetXMLData("value",$xTree,"","xmlns");
      next if !exists($Net::Jabber::DELEGATES{$xmlns});
      $self->AddX($xmlns,@{$xTree}) if ($xmlns ne "");
    }
  } else {
    $self->{PRESENCE} = [ "presence" , [{}] ];
    $self->{XTAGS} = [];
  }

  return $self;
}


##############################################################################
#
# GetTag - returns the Jabber tag of this object
#
##############################################################################
sub GetTag {
  my $self = shift;
  return "presence";
}


##############################################################################
#
# GetID - returns the id of the <presence/>.
#
##############################################################################
sub GetID {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"","id");
}


##############################################################################
#
# GetTo - returns the Jabber Identifier of the person you are sending the
#         <presence/> to.
#
##############################################################################
sub GetTo {
  my $self = shift;
  my ($type) = @_;
  $type = "" unless defined($type);
  my $to = &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"","to");
  if ($type eq "jid") {
    return new Net::Jabber::JID($to);
  } else {
    return $to;
  }
}


##############################################################################
#
# GetFrom - returns the Jabber Identifier of the person who sent the 
#           <presence/>
#
##############################################################################
sub GetFrom {
  my $self = shift;
  my ($type) = @_;
  $type = "" unless defined($type);
  my $from = &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"","from");
  if ($type eq "jid") {
    return new Net::Jabber::JID($from);
  } else {
    return $from;
  }
}


##############################################################################
#
# GetEtherxTo - returns the value of the etherx:to attribute in the 
#               <presence/>.
#
##############################################################################
sub GetEtherxTo {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"","etherx:to");
}


##############################################################################
#
# GetEtherxFrom - returns the value of the etherx:from attribute in the 
#                 <presence/>.
#
##############################################################################
sub GetEtherxFrom {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"","etherx:from");
}


##############################################################################
#
# GetType - returns the type of the <presence/>
#
##############################################################################
sub GetType {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"","type");
}


##############################################################################
#
# GetStatus - returns the status of the <presence/>
#
##############################################################################
sub GetStatus {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"status");
}


##############################################################################
#
# GetPriority - returns the priority of the <presence/>
#
##############################################################################
sub GetPriority {
  my $self = shift;
  my $priority = &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"priority");
  $priority = 0 if ($priority eq "");
  return $priority;
}


##############################################################################
#
# GetMeta - returns the meta data of the <presence/>
#
##############################################################################
sub GetMeta {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"meta");
}


##############################################################################
#
# GetIcon - returns the icon of the <presence/>
#
##############################################################################
sub GetIcon {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"icon");
}


##############################################################################
#
# GetShow - returns the show of the <presence/>
#
##############################################################################
sub GetShow {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"show");
}


##############################################################################
#
# GetLoc - returns the loc of the <presence/>
#
##############################################################################
sub GetLoc {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{PRESENCE},"loc");
}


##############################################################################
#
# GetX - returns an array of Net::Jabber::X objects.  If a namespace is 
#        requested then only objects from that name space are returned.
#
##############################################################################
sub GetX {
  my $self = shift;
  my($xmlns) = @_;
  my @xTags;
  my $xTag;
  foreach $xTag (@{$self->{XTAGS}}) {
    push(@xTags,$xTag) if (($xmlns eq "") || ($xTag->GetXMLNS() eq $xmlns));
  }
  return @xTags;
}


##############################################################################
#
# GetXTrees - returns an array of XML::Parser::Tree objects of the <x/> tags
#
##############################################################################
sub GetXTrees {
  my $self = shift;
  $self->MergeX();
  my ($xmlns) = @_;
  my $xTree;
  my @xTrees;
  foreach $xTree (&Net::Jabber::GetXMLData("tree array",$self->{PRESENCE},"*","xmlns",$xmlns)) {
    push(@xTrees,$xTree);
  }
  return @xTrees;
}


##############################################################################
#
# GetXML - returns the XML string that represents the data in the XML::Parser
#          Tree.
#
##############################################################################
sub GetXML {
  my $self = shift;
  $self->MergeX();
  return &Net::Jabber::BuildXML(@{$self->{PRESENCE}});
}


##############################################################################
#
# GetTree - returns the XML::Parser Tree that is stored in the guts of
#               the object.
#
##############################################################################
sub GetTree {
  my $self = shift;
  $self->MergeX();
  return @{$self->{PRESENCE}};
}


##############################################################################
#
# SetPresence - takes a hash of all of the things you can set on a <presence/>
#               and sets each one.
#
##############################################################################
sub SetPresence {
  my $self = shift;
  my %presence;
  while($#_ >= 0) { $presence{ lc pop(@_) } = pop(@_); }

  $self->SetID($presence{id}) if exists($presence{id});
  $self->SetTo($presence{to}) if exists($presence{to});
  $self->SetFrom($presence{from}) if exists($presence{from});
  $self->SetEtherxTo($presence{etherxto}) if exists($presence{etherxto});
  $self->SetEtherxFrom($presence{etherxfrom}) if exists($presence{etherxfrom});
  $self->SetType($presence{type}) if exists($presence{type});
  $self->SetStatus($presence{status}) if exists($presence{status});
  $self->SetPriority($presence{priority}) if exists($presence{priority});
  $self->SetMeta($presence{meta}) if exists($presence{meta});
  $self->SetIcon($presence{icon}) if exists($presence{icon});
  $self->SetShow($presence{show}) if exists($presence{show});
  $self->SetLoc($presence{loc}) if exists($presence{loc});
}


##############################################################################
#
# SetID - sets the id attribute in the <presence/>
#
##############################################################################
sub SetID {
  my $self = shift;
  my ($id) = @_;
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"","",{id=>$id});
}


##############################################################################
#
# SetTo - sets the to attribute in the <presence/>
#
##############################################################################
sub SetTo {
  my $self = shift;
  my ($to) = @_;
  if (ref($to) eq "Net::Jabber::JID") {
    $to = $to->GetJID("full");
  }
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"","",{to=>$to});
}


##############################################################################
#
# SetFrom - sets the from attribute in the <presence/>
#
##############################################################################
sub SetFrom {
  my $self = shift;
  my ($from) = @_;
  if (ref($from) eq "Net::Jabber::JID") {
    $from = $from->GetJID("full");
  }
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"","",{from=>$from});
}


##############################################################################
#
# SetEtherxTo - sets the etherx:to attribute in the <presence/>
#
##############################################################################
sub SetEtherxTo {
  my $self = shift;
  my ($etherxto) = @_;
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"","",{"etherx:to"=>$etherxto});
}


##############################################################################
#
# SetEtherxFrom - sets the etherx:from attribute in the <presence/>
#
##############################################################################
sub SetEtherxFrom {
  my $self = shift;
  my ($etherxfrom) = @_;
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"","",{"etherx:from"=>$etherxfrom});
}


##############################################################################
#
# SetType - sets the type attribute in the <presence/>
#
##############################################################################
sub SetType {
  my $self = shift;
  my ($type) = @_;
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"","",{type=>$type});
}


##############################################################################
#
# SetStatus - sets the status of the <presence/>
#
##############################################################################
sub SetStatus {
  my $self = shift;
  my ($status) = @_;
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"status",$status,{});
}


##############################################################################
#
# SetPriority - sets the priority of the <presence/>
#
##############################################################################
sub SetPriority {
  my $self = shift;
  my ($priority) = @_;
  $priority = 0 if ($priority eq "");
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"priority",$priority,{});
}


##############################################################################
#
# SetMeta - sets the meta data of the <presence/>
#
##############################################################################
sub SetMeta {
  my $self = shift;
  my ($meta) = @_;
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"meta",$meta,{});
}


##############################################################################
#
# SetIcon - sets the icon of the <presence/>
#
##############################################################################
sub SetIcon {
  my $self = shift;
  my ($icon) = @_;
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"icon",$icon,{});
}


##############################################################################
#
# SetShow - sets the show of the <presence/>
#
##############################################################################
sub SetShow {
  my $self = shift;
  my ($show) = @_;
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"show",$show,{});
}


##############################################################################
#
# SetLoc - sets the location of the <presence/>
#
##############################################################################
sub SetLoc {
  my $self = shift;
  my ($loc) = @_;
  &Net::Jabber::SetXMLData("single",$self->{PRESENCE},"loc",$loc,{});
}


##############################################################################
#
# NewX - calls AddX to create a new Net::Jabber::X object, sets the xmlns and 
#        returns a pointer to the new object.
#
##############################################################################
sub NewX {
  my $self = shift;
  my ($xmlns) = @_;
  return if !exists($Net::Jabber::DELEGATES{$xmlns});
  my $xTag = $self->AddX($xmlns);
  $xTag->SetXMLNS($xmlns) if $xmlns ne "";
  return $xTag;
}


##############################################################################
#
# AddX - creates a new Net::Jabber::X object, pushes it on the list, and 
#        returns a pointer to the new object.  This is a private helper 
#        function. 
#
##############################################################################
sub AddX {
  my $self = shift;
  my ($xmlns,@xTree) = @_;
  return if !exists($Net::Jabber::DELEGATES{$xmlns});
  $self->{DEBUG}->Log2("AddX: xmlns($xmlns) xTree(",\@xTree,")");
  my $xTag;
  eval("\$xTag = new ".$Net::Jabber::DELEGATES{$xmlns}->{parent}."(\@xTree);");
  $self->{DEBUG}->Log2("AddX: xTag(",$xTag,")");
  push(@{$self->{XTAGS}},$xTag);
  return $xTag;
}
  

##############################################################################
#
# MergeX - runs through the list of <x/> in the current presence and replaces
#          them with the list of <x/> in the internal list.  If any old <x/>
#          in the <presence/> are left, then they are removed.  If any new <x/>
#          are left in the interanl list, then they are added to the end of
#          the presence.  This is a private helper function.  It should be 
#          used any time you need access the full <presence/> so that all of
#          the <x/> tags are included.  (ie. GetXML, GetTree, debug, etc...)
#
##############################################################################
sub MergeX {
  my $self = shift;

  $self->{DEBUG}->Log2("MergeX: start");

  return if !(exists($self->{XTAGS}));

  $self->{DEBUG}->Log2("MergeX: xTags(",$self->{XTAGS},")");

  my $xTag;
  my @xTags;
  foreach $xTag (@{$self->{XTAGS}}) {
    push(@xTags,$xTag);
  }

  $self->{DEBUG}->Log2("MergeX: xTags(",\@xTags,")");
  $self->{DEBUG}->Log2("MergeX: Check the old tags");
  $self->{DEBUG}->Log2("MergeX: length(",$#{$self->{PRESENCE}->[1]},")");

  my $i;
  foreach $i (1..$#{$self->{PRESENCE}->[1]}) {
    $self->{DEBUG}->Log2("MergeX: i($i)");
    $self->{DEBUG}->Log2("MergeX: data(",$self->{PRESENCE}->[1]->[$i],")");

    if ((ref($self->{PRESENCE}->[1]->[($i+1)]) eq "ARRAY") &&
	exists($self->{PRESENCE}->[1]->[($i+1)]->[0]->{xmlns})) {
      $self->{DEBUG}->Log2("MergeX: found a namespace xmlns(",$self->{PRESENCE}->[1]->[($i+1)]->[0]->{xmlns},")");
      next if !exists($Net::Jabber::DELEGATES{$self->{PRESENCE}->[1]->[($i+1)]->[0]->{xmlns}});
      $self->{DEBUG}->Log2("MergeX: merge index($i)");
      my $xTag = pop(@xTags);
      $self->{DEBUG}->Log2("MergeX: merge xTag($xTag)");
      my @xTree = $xTag->GetTree();
      $self->{DEBUG}->Log2("MergeX: merge xTree(",\@xTree,")");
      $self->{PRESENCE}->[1]->[$i] = $xTree[0];
      $self->{PRESENCE}->[1]->[($i+1)] = $xTree[1];
    }
  }

  $self->{DEBUG}->Log2("MergeX: Insert new tags");
  foreach $xTag (@xTags) {
    $self->{DEBUG}->Log2("MergeX: new tag");
    my @xTree = $xTag->GetTree();
    $self->{PRESENCE}->[1]->[($#{$self->{PRESENCE}->[1]}+1)] = $xTree[0];
    $self->{PRESENCE}->[1]->[($#{$self->{PRESENCE}->[1]}+1)] = $xTree[1];
  }

  $self->{DEBUG}->Log2("MergeX: end");
}


##############################################################################
#
# Reply - returns a Net::Jabber::Presence object with the proper fields
#         already populated for you.
#
##############################################################################
sub Reply {
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  my $reply = new Net::Jabber::Presence();

  $reply->SetID($self->GetID()) if ($self->GetID() ne "");
  $reply->SetType(exists($args{type}) ? $args{type} : "");

  if (exists($args{template})) {
    if ($args{template} eq "transport") {
      my $fromJID = $self->GetFrom("jid");
      
      $reply->SetPresence(to=>$self->GetFrom(),
			  from=>$self->GetTo(),
			  etherxto=>$fromJID->GetServer(),
			  etherxfrom=>$self->GetEtherxTo(),
			 );
    } else {
      $reply->SetPresence(to=>$self->GetFrom(),
			  from=>$self->GetTo());
    }
  } else {
    $reply->SetPresence(to=>$self->GetFrom(),
			from=>$self->GetTo());
  }

  return $reply;
}


##############################################################################
#
# debug - prints out the XML::Parser Tree in a readable format for debugging
#
##############################################################################
sub debug {
  my $self = shift;

  print "debug PRESENCE: $self\n";
  $self->MergeX();
  &Net::Jabber::printData("debug: \$self->{PRESENCE}->",$self->{PRESENCE});
}

1;
