package Net::Jabber::Message;

=head1 NAME

Net::Jabber::Message - Jabber Message Module

=head1 SYNOPSIS

  Net::Jabber::Message is a companion to the Net::Jabber module.
  It provides the user a simple interface to set and retrieve all 
  parts of a Jabber Message.

=head1 DESCRIPTION

  To initialize the Message with a Jabber <message/> you must pass it 
  the XML::Parser Tree array from the Net::Jabber::Client module.  In the
  callback function for the message:

    use Net::Jabber;

    sub message {
      my $message = new Net::Jabber::Message(@_);
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new message to send to the server:

    use Net::Jabber;

    $Mess = new Net::Jabber::Message();

  Now you can call the creation functions below to populate the tag before
  sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $to         = $Mess->GetTo();
    $toJID      = $Mess->GetTo("jid");
    $from       = $Mess->GetFrom();
    $fromJID    = $Mess->GetFrom("jid");
    $etherxTo   = $Mess->GetEtherxTo();
    $etherxFrom = $Mess->GetEtherxFrom();
    $resource   = $Mess->GetResource();
    $type       = $Mess->GetType();
    $subject    = $Mess->GetSubject();
    $body       = $Mess->GetBody();
    @body       = $Mess->GetBody("full");
    $thread     = $Mess->GetThread();
    $priority   = $Mess->GetPriority();
    $error      = $Mess->GetError();
    $errCode    = $Mess->GetErrorCode();
    @xTags      = $Mess->GetX();
    @xTags      = $Mess->GetX("my:namespace");
    @xTrees     = $Mess->GetXTrees();
    @xTrees     = $Mess->GetXTrees("my:namespace");

    $str        = $Mess->GetXML();
    @message    = $Mess->GetTree();

    $date       = $Mess->GetTimeStamp();

=head2 Creation functions

    $Mess->SetMessage(TO=>"bob\@jabber.org/Working Bob",
		      Subject=>"Lunch",
		      BoDy=>"Let's go grab some lunch!",
		      priority=>100);
    $Mess->SetTo("test\@jabber.org");
    $Mess->SetFrom("me\@jabber.org");
    $Mess->SetEtherxTo("jabber.org");
    $Mess->SetEtherxFrom("transport.jabber.org");
    $Mess->SetType("groupchat");
    $Mess->SetSubject("This is a test");
    $Mess->SetBody("This is a test of the emergency broadcast system...");
    $Mess->SetThread("AE912B3");
    $Mess->SetPriority(1);

    $Mess->SetMessage(to=>"bob\@jabber.org",
                      errorcode=>403,
                      error=>"Permission Denied");
    $Mess->SetErrorCode(403);
    $Mess->SetError("Permission Denied");

    $X = $Mess->NewX("jabber:x:delay");
    $X = $Mess->NewX("my:namespace");

    $Reply = $Mess->Reply();
    $Reply = $Mess->Reply(template=>"client");
    $Reply = $Mess->Reply(template=>"transport");

=head1 METHODS

=head2 Retrieval functions

  GetTo()      - returns either a string with the Jabber Identifier,
  GetTo("jid")   or a Net::Jabber::JID object for the person who is 
                 going to receive the <message/>.  To get the JID
                 object set the string to "jid", otherwise leave
                 blank for the text string.

  GetFrom()      -  returns either a string with the Jabber Identifier,
  GetFrom("jid")    or a Net::Jabber::JID object for the person who
                    sent the <message/>.  To get the JID object set 
                    the string to "jid", otherwise leave blank for the 
                    text string.

  GetEtherxTo(string) - returns the etherx:to attribute.  This is for
                        Transport writers who need to communicate with
                        Etherx.

  GetEtherxFrom(string) -  returns the etherx:from attribute.  This is for
                           Transport writers who need to communicate with
                           Etherx.

  GetResource() - returns a string with the Jabber Resource of the 
                  person who sent the <message/>.

  GetType() - returns a string with the type <message/> this is.

  GetSubject() - returns a string with the subject of the <message/>.

  GetBody(string) - returns the data in the <body/> tag depending on the
                    value of the string passed to it.  The string
                    represents the mark up level to return.

                    none   returns a string with just the text of 
                           the <body/> (default)
                    full   returns an XML::Paser::Tree with everything
                           in the <body/>

  GetThread() - returns a string that represents the thread this
                <message/> belongs to.

  GetPriority() - returns an integer with the priority of the <message/>.

  GetError() - returns a string with the data of the <error/> tag.

  GetErrorCode() - returns a string with the code of the <error/> tag.

  GetX(string) - returns an array of Net::Jabber::X objects.  The string 
                 can either be empty or the XML Namespace you are looking
                 for.  If empty then GetX returns every <x/> tag in the 
                 <message/>.  If an XML Namespace is sent then GetX 
                 returns every <x/> tag with that Namespace.

  GetXTrees(string) - returns an array of XML::Parser::Tree objects.  The 
                      string can either be empty or the XML Namespace you 
                      are looking for.  If empty then GetXTrees returns
                      every <x/> tag in the <message/>.  If an XML
                      Namespace is sent then GetXTrees returns every
                      <x/> tag with that  Namespace.

  GetXML() - returns the XML string that represents the <message/>.
             This is used by the Send() function in Client.pm to send
             this object as a Jabber Message.

  GetTree() - returns an array that contains the <message/> tag
              in XML::Parser Tree format.

  GetTimeStamp() - returns a string that represents the time this message
                   object was created (and probably received) for sending
                   to the client.  If there is an <x/> delay tag then that
                   time is used to show when the message was sent.

=head2 Creation functions

  SetMessage(to=>string|JID,     - set multiple fields in the <message/>
             from=>string|JID,     at one time.  This is a cumulative
             type=>string,         and over writing action.  If you set
             subject=>string,      the "to" attribute twice, the second
             body=>string,         setting is what is used.  If you set
             thread=>integer,      the subject, and then set the body
             priority=>string,     then both will be in the <message/>
             errorcode=>string,    tag.  For valid settings read the
             error=>string)        specific Set functions below.

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

                    chat           defines a chat style message
                    error          defines an error message
                    groupchat      defines a chatroom message
                    normal         defines a normal message (default)

  SetSubject(string) - sets the subject of the <message/>.

  SetBody(string) - sets the body of the <message/>.

  SetThread(string) - sets the thread of the <message/>.  You should
                      copy this out of the message being replied to so
                      that the thread is maintained.

  SetPriority(integer) - sets the priority of this <message/>.  The 
                         higher the priority the more likely the client
                         will deliver the message, even if the user has
                         specified no messages.

  SetErrorCode(string) - sets the error code of the <message/>.

  SetError(string) - sets the error string of the <message/>.

  NewX(string) - creates a new Net::Jabber::X object with the namespace
                 in the string.  In order for this function to work with
                 a custom namespace, you must define and register that  
                 namespace with the X module.  For more information
                 please read the documentation for Net::Jabber::X.

  Reply(template=>string,       - creates a new Message object and
        replytransport=>string)   populates the to/from and
                                  etherxto/etherxfrom fields based
                                  the value of template.  The following
                                  templates are available:

                                  client: (default)
                                       just sets the to/from

                                  transport:
                                  transport-reply:
                                       the transport will send the
                                       reply to the sender

                                  transport-filter:
                                       the transport will send the
                                       reply to the address from the
                                       to.  ie( bob%j.org@transport.j.org
                                       would send to bob@j.org)

                                  transport-filter-reply:
                                       the transport will send the
                                       reply to the address from the
                                       to.  ie( bob%j.org@transport.j.org
                                       would send to bob@j.org) and
                                       set the from to be 
                                       sender@replytransport.  That
                                       way a two way filter can occur.

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
  $self->{TIMESTAMP} = &Net::Jabber::GetTimeStamp("local");

  bless($self, $proto);

  $self->{DEBUG} = new Net::Jabber::Debug(usedefault=>1,
                                          header=>"NJ::Message");

  if ("@_" ne ("")) {
    my @temp = @_;
    $self->{MESSAGE} = \@temp;
    my $xTree;
    foreach $xTree ($self->GetXTrees()) {
      my $xmlns = &Net::Jabber::GetXMLData("value",$xTree,"","xmlns");
      next if !exists($Net::Jabber::DELEGATES{$xmlns});
      $self->AddX($xmlns,@{$xTree});
    }
  } else {
    $self->{MESSAGE} = [ "message" , [{}]];
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
  return "message";
}


##############################################################################
#
# GetID - returns the id of the <message/>
#
##############################################################################
sub GetID {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"","id");
}


##############################################################################
#
# GetTo - returns the Jabber Identifier of the person you are sending the
#         <message/> to.
#
##############################################################################
sub GetTo {
  my $self = shift;
  my ($type) = @_;
  $type = "" unless defined($type);
  my $to = &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"","to");
  if ($type eq "jid") {
    return new Net::Jabber::JID($to);
  } else {
    return $to;
  }
}


##############################################################################
#
# GetFrom - returns the Jabber Identifier of the person who sent the 
#           <message/>
#
##############################################################################
sub GetFrom {
  my $self = shift;
  my ($type) = @_;
  $type = "" unless defined($type);
  my $from = &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"","from");
  if ($type eq "jid") {
    return new Net::Jabber::JID($from);
  } else {
    return $from;
  }
}


##############################################################################
#
# GetEtherxTo - returns the value of the etherx:to attribute in the 
#               <message/>.
#
##############################################################################
sub GetEtherxTo {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"","etherx:to");
}


##############################################################################
#
# GetEtherxFrom - returns the value of the etherx:from attribute in the 
#                 <message/>.
#
##############################################################################
sub GetEtherxFrom {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"","etherx:from");
}


##############################################################################
#
# GetResource - returns the Jabber Resource of the person who sent the 
#              <message/>
#
##############################################################################
sub GetResource {
  my $self = shift;
  my ($str) =
    (&Net::Jabber::GetXMLData("value",$self->{MESSAGE},"","from") =~ /^[^\/]+\/?(.*)$/);
  return $str;
}


##############################################################################
#
# GetType - returns the type of the <message/>
#
##############################################################################
sub GetType {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"","type");
}


##############################################################################
#
# GetSubject - returns the subject of the <message/>
#
##############################################################################
sub GetSubject {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"subject");
}


##############################################################################
#
# GetBody - returns the body of the <message/>
#
##############################################################################
sub GetBody {
  my $self = shift;
  my ($level) = @_;
  $level = "" if !defined($level);
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"body")
    if (($level eq "none") || ($level eq ""));
  return &Net::Jabber::GetXMLData("tree",$self->{MESSAGE},"body")
    if ($level eq "full");
}


##############################################################################
#
# GetThread - returns the thread of the <message/>
#
##############################################################################
sub GetThread {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"thread");
}


##############################################################################
#
# GetPriority - returns the priority of the <message/>
#
##############################################################################
sub GetPriority {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"priority");
}


##############################################################################
#
# GetError - returns the text associated with the error
#
##############################################################################
sub GetError {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"error");
}


##############################################################################
#
# GetErrorCode - returns the code of the error
#
##############################################################################
sub GetErrorCode {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{MESSAGE},"error","code");
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
  foreach $xTree (&Net::Jabber::GetXMLData("tree array",$self->{MESSAGE},"*","xmlns",$xmlns)) {
    push(@xTrees,$xTree);
  }
  return @xTrees;
}


##############################################################################
#
# GetXML -  returns the XML string that represents the data in the XML::Parser
#          Tree.
#
##############################################################################
sub GetXML {
  my $self = shift;
  $self->MergeX();
  return &Net::Jabber::BuildXML(@{$self->{MESSAGE}});
}


##############################################################################
#
# GetTree - returns the XML::Parser Tree that is stored in the guts of
#              the object.
#
##############################################################################
sub GetTree {
  my $self = shift;
  $self->MergeX();
  return %{$self->{MESSAGE}};
}


##############################################################################
#
# GetTimeStamp - returns a string with the time stamp of when this object
#                was created.
#
##############################################################################
sub GetTimeStamp {
  my $self = shift;

  my @xTags = $self->GetX("jabber:x:delay");
  if ($#xTags >= 0) {
    my $xTag = $xTags[0];
    $self->{TIMESTAMP} = &Net::Jabber::GetTimeStamp("utcdelaylocal",$xTag->GetStamp());
  }

  return $self->{TIMESTAMP};
}


##############################################################################
#
# SetMessage - takes a hash of all of the things you can set on a <message/>
#              and sets each one.
#
##############################################################################
sub SetMessage {
  my $self = shift;
  my %message;
  while($#_ >= 0) { $message{ lc pop(@_) } = pop(@_); }

  $self->SetID($message{id}) if exists($message{id});
  $self->SetTo($message{to}) if exists($message{to});
  $self->SetFrom($message{from}) if exists($message{from});
  $self->SetEtherxTo($message{etherxto}) if exists($message{etherxto});
  $self->SetEtherxFrom($message{etherxfrom}) if exists($message{etherxfrom});
  $self->SetType($message{type}) if exists($message{type});
  $self->SetSubject($message{subject}) if exists($message{subject});
  $self->SetBody($message{body}) if exists($message{body});
  $self->SetThread($message{thread}) if exists($message{thread});
  $self->SetPriority($message{priority}) if exists($message{priority});
  $self->SetErrorCode($message{errorcode}) if exists($message{errorcode});
  $self->SetError($message{error}) if exists($message{error});
}


##############################################################################
#
# SetID - sets the to attribute in the <message/>
#
##############################################################################
sub SetID {
  my $self = shift;
  my ($id) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"","",{id=>$id});
}


##############################################################################
#
# SetTo - sets the to attribute in the <message/>
#
##############################################################################
sub SetTo {
  my $self = shift;
  my ($to) = @_;
  if (ref($to) eq "Net::Jabber::JID") {
    $to = $to->GetJID("full");
  }
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"","",{to=>$to});
}


##############################################################################
#
# SetFrom - sets the from attribute in the <message/>
#
##############################################################################
sub SetFrom {
  my $self = shift;
  my ($from) = @_;
  if (ref($from) eq "Net::Jabber::JID") {
    $from = $from->GetJID("full");
  }
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"","",{from=>$from});
}


##############################################################################
#
# SetEtherxTo - sets the etherx:to attribute in the <message/>
#
##############################################################################
sub SetEtherxTo {
  my $self = shift;
  my ($etherxto) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"","",{"etherx:to"=>$etherxto});
}


##############################################################################
#
# SetEtherxFrom - sets the etherx:from attribute in the <message/>
#
##############################################################################
sub SetEtherxFrom {
  my $self = shift;
  my ($etherxfrom) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"","",{"etherx:from"=>$etherxfrom});
}


##############################################################################
#
# SetType - sets the type attribute in the <message/>
#
##############################################################################
sub SetType {
  my $self = shift;
  my ($type) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"","",{type=>$type});
}


##############################################################################
#
# SetSubject - sets the subject of the <message/>
#
##############################################################################
sub SetSubject {
  my $self = shift;
  my ($subject) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"subject",$subject,{});
}


##############################################################################
#
# SetBody - sets the body of the <message/>
#
##############################################################################
sub SetBody {
  my $self = shift;
  my ($body) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"body",$body,{});
}


##############################################################################
#
# SetThread - sets the thread of the <message/>
#
##############################################################################
sub SetThread {
  my $self = shift;
  my ($thread) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"thread",$thread,{});
}


##############################################################################
#
# SetPriority - sets the priority of the <message/>
#
##############################################################################
sub SetPriority {
  my $self = shift;
  my ($priority) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"priority",$priority,{});
}


##############################################################################
#
# SetErrorCode - sets the code attribute in the error tag of the <message/>
#
##############################################################################
sub SetErrorCode {
  my $self = shift;
  my ($code) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"error","",{code=>$code});
}


##############################################################################
#
# SetError - sets the error of the <message/>
#
##############################################################################
sub SetError {
  my $self = shift;
  my ($error) = @_;
  &Net::Jabber::SetXMLData("single",$self->{MESSAGE},"error",$error,{});
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
# MergeX - runs through the list of <x/> in the current message and replaces
#          them with the list of <x/> in the internal list.  If any old <x/>
#          in the <message/> are left, then they are removed.  If any new <x/>
#          are left in the interanl list, then they are added to the end of
#          the message.  This is a private helper function.  It should be 
#          used any time you need access the full <message/> so that all of
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
  $self->{DEBUG}->Log2("MergeX: length(",$#{$self->{MESSAGE}->[1]},")");


  my $i;
  foreach $i (1..$#{$self->{MESSAGE}->[1]}) {
    $self->{DEBUG}->Log2("MergeX: i($i)");
    $self->{DEBUG}->Log2("MergeX: data(",$self->{MESSAGE}->[1]->[$i],")");

    if ((ref($self->{MESSAGE}->[1]->[($i+1)]) eq "ARRAY") &&
	exists($self->{MESSAGE}->[1]->[($i+1)]->[0]->{xmlns})) {
      $self->{DEBUG}->Log2("MergeX: found a namespace xmlns(",$self->{MESSAGE}->[1]->[($i+1)]->[0]->{xmlns},")");
      next if !exists($Net::Jabber::DELEGATES{$self->{MESSAGE}->[1]->[($i+1)]->[0]->{xmlns}});
      $self->{DEBUG}->Log2("MergeX: merge index($i)");
      my $xTag = pop(@xTags);
      $self->{DEBUG}->Log2("MergeX: merge xTag($xTag)");
      my @xTree = $xTag->GetTree();
      $self->{DEBUG}->Log2("MergeX: merge xTree(",\@xTree,")");
      $self->{MESSAGE}->[1]->[($i+1)] = $xTree[1];
    }
  }

  $self->{DEBUG}->Log2("MergeX: Insert new tags");
  foreach $xTag (@xTags) {
    $self->{DEBUG}->Log2("MergeX: new tag");
    my @xTree = $xTag->GetTree();
    $self->{MESSAGE}->[1]->[($#{$self->{MESSAGE}->[1]}+1)] = "x";
    $self->{MESSAGE}->[1]->[($#{$self->{MESSAGE}->[1]}+1)] = $xTree[1];
  }

  $self->{DEBUG}->Log2("MergeX: end");
}


##############################################################################
#
# Reply - returns a Net::Jabber::Message object with the proper fields
#         already populated for you.
#
##############################################################################
sub Reply {
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  my $reply = new Net::Jabber::Message();

  if (($self->GetType() eq "") || ($self->GetType() eq "normal")) {
    my $subject = $self->GetSubject();
    $subject =~ s/re\:\s+//i;
    $reply->SetSubject("re: $subject");
  }
  $reply->SetThread($self->GetThread()) if ($self->GetThread() ne "");
  $reply->SetID($self->GetID()) if ($self->GetID() ne "");
  $reply->SetType($self->GetType()) if ($self->GetType() ne "");
  $reply->SetType($args{type}) if exists($args{type});


  if (exists($args{template})) {
    if (($args{template} eq "transport") || ($args{template} eq "transport-reply")) {
      my $fromJID = $self->GetFrom("jid");

      $reply->SetMessage(to=>$self->GetFrom(),
			 from=>$self->GetTo(),
			 etherxto=>$fromJID->GetServer(),
			 etherxfrom=>$self->GetEtherxTo(),
			);
    } else {
      if ($args{template} eq "transport-filter") {
	my $toJID = $self->GetTo("jid");
	my $fromJID = $self->GetFrom("jid");

	my $filterToJID = new Net::Jabber::JID($toJID->GetUserID());

	$reply->SetMessage(to=>$filterToJID,
			   from=>$fromJID,
			   etherxto=>$filterToJID->Server(),
			   etherxfrom=>$fromJID->Server());
      } else {
	if ($args{template} eq "transport-filter-reply") {
	  my $toJID = $self->GetTo("jid");
	  my $fromJID = $self->GetFrom("jid");
	  
	  my $filterToJID = new Net::Jabber::JID($toJID->GetUserID());
	  my $filterFromJID = new Net::Jabber::JID($fromJID->GetUserID()."\%".$fromJID->GetServer()."\@".$args{replytransport});
	  
	  $reply->SetMessage(to=>$filterToJID,
			     from=>$filterFromJID,
			     etherxto=>$filterToJID->Server(),
			     etherxfrom=>$self->GetEtherxTo());
	} else {
	  $reply->SetMessage(to=>$self->GetFrom(),
			     from=>$self->GetTo());
	}	
      }
    }
  } else {
    $reply->SetMessage(to=>$self->GetFrom(),
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

  print "debug MESSAGE: $self\n";
  $self->MergeX();
  &Net::Jabber::printData("debug: \$self->{MESSAGE}->",$self->{MESSAGE});
}

1;
