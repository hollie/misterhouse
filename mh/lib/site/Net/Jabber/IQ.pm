package Net::Jabber::IQ;

=head1 NAME

Net::Jabber::IQ - Jabber Info/Query Library

=head1 SYNOPSIS

  Net::Jabber::IQ is a companion to the Net::Jabber module. It
  provides the user a simple interface to set and retrieve all 
  parts of a Jabber IQ.

=head1 DESCRIPTION

  Net::Jabber::IQ differs from the other Net::Jabber::* modules in that
  the XMLNS of the query is split out into more submodules under
  IQ.  For specifics on each module please view the documentation
  for each Net::Jabber::Query::* module.  To see the list of avilable
  namspaces and modules see Net::Jabber::Query.

  To initialize the IQ with a Jabber <iq/> you must pass it the 
  XML::Parser Tree array from the Net::Jabber::Client module.  In the
  callback function for the iq:

    use Net::Jabber;

    sub iq {
      my $iq = new Net::Jabber::IQ(@_);
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new iq to send to the server:

    use Net::Jabber;

    $IQ = new Net::Jabber::IQ();
    $IQType = $IQ->NewQuery( type );
    $IQType->SetXXXXX("yyyyy");

  Now you can call the creation functions for the IQ, and for the <query/>
  on the new Query object itself.  See below for the <iq/> functions, and
  in each query module for those functions.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $to         = $IQ->GetTo();
    $toJID      = $IQ->GetTo("jid");
    $from       = $IQ->GetFrom();
    $fromJID    = $IQ->GetFrom("jid");
    $etherxTo   = $IQ->GetEtherxTo();
    $etherxFrom = $IQ->GetEtherxFrom();
    $id         = $IQ->GetID();
    $type       = $IQ->GetType();
    $error      = $IQ->GetError();
    $errorCode  = $IQ->GetErrorCode();

    $queryTag   = $IQ->GetQuery();
    $qureyTree  = $IQ->GetQueryTree();

    $str       = $IQ->GetXML();
    @iq        = $IQ->GetTree();

=head2 Creation functions

    $IQ->SetIQ(tYpE=>"get",
	       tO=>"bob@jabber.org",
	       query=>"info");

    $IQ->SetTo("bob@jabber.org");
    $IQ->SetFrom("me\@jabber.org");
    $IQ->SetEtherxTo("jabber.org");
    $IQ->SetEtherxFrom("transport.jabber.org");
    $IQ->SetType("set");

    $IQ->SetIQ(to=>"bob\@jabber.org",
               errorcode=>403,
               error=>"Permission Denied");
    $IQ->SetErrorCode(403);
    $IQ->SetError("Permission Denied");

    $IQObject = $IQ->NewQuery("jabber:iq:auth");
    $IQObject = $IQ->NewQuery("jabber:iq:roster");

    $iqReply = $IQ->Reply();
    $iqReply = $IQ->Reply("client");
    $iqReply = $IQ->Reply("transport");

=head1 METHODS

=head2 Retrieval functions

  GetTo()      - returns either a string with the Jabber Identifier,
  GetTo("jid")   or a Net::Jabber::JID object for the person who is 
                 going to receive the <iq/>.  To get the JID
                 object set the string to "jid", otherwise leave
                 blank for the text string.

  GetFrom()      -  returns either a string with the Jabber Identifier,
  GetFrom("jid")    or a Net::Jabber::JID object for the person who
                    sent the <iq/>.  To get the JID object set 
                    the string to "jid", otherwise leave blank for the 
                    text string.

  GetEtherxTo(string) - returns the etherx:to attribute.  This is for
                        Transport writers who need to communicate with
                        Etherx.

  GetEtherxFrom(string) -  returns the etherx:from attribute.  This is for
                           Transport writers who need to communicate with
                           Etherx.

  GetType() - returns a string with the type <iq/> this is.

  GetID() - returns an integer with the id of the <iq/>.

  GetError() - returns a string with the text description of the error.

  GetErrorCode() - returns a string with the code of error.

  GetQuery() - returns a Net::Jabber::Query object that contains the data
               in the <query/> of the <iq/>.

  GetQueryTree() - returns an XML::Parser::Tree object that contains the 
                   data in the <query/> of the <iq/>.

  GetXML() - returns the XML string that represents the <iq/>. This 
             is used by the Send() function in Client.pm to send
             this object as a Jabber IQ.

  GetTree() - returns an array that contains the <iq/> tag in XML::Parser 
              Tree format.

=head2 Creation functions

  SetIQ(to=>string|JID,    - set multiple fields in the <iq/> at one
        from=>string|JID,    time.  This is a cumulative and over
        type=>string,        writing action.  If you set the "to"
        errorcode=>string,   attribute twice, the second setting is
        error=>string)       what is used.  If you set the status, and
                             then set the priority then both will be in
                             the <iq/> tag.  For valid settings read the
                             specific Set functions below.

  SetTo(string) - sets the to attribute.  You can either pass a string
  SetTo(JID)      or a JID object.  They must be a valid Jabber 
                  Identifiers or the server will return an error message.
                  (ie.  jabber:bob@jabber.org, etc...)

  SetFrom(string) - sets the from attribute.  You can either pass a string
  SetFrom(JID)      or a JID object.  They must be a valid Jabber 
                    Identifiers or the server will return an error message.
                    (ie.  jabber:bob@jabber.org, etc...)

  SetEtherxTo(string) - sets the etherx:to attribute.  This is for
                        Transport writers who need to communicate with
                        Etherx.

  SetEtherxFrom(string) -  sets the etherx:from attribute.  This is for
                           Transport writers who need to communicate with
                           Etherx.

  SetType(string) - sets the type attribute.  Valid settings are:

                    get     request information
                    set     set information

  SetErrorCode(string) - sets the error code of the <iq/>.
 
  SetError(string) - sets the error string of the <iq/>.
 
  NewQuery(string) - creates a new Net::Jabber::Query object with the 
                     namespace in the string.  In order for this function 
                     to work with a custom namespace, you must define and 
                     register that namespace with the IQ module.  For more 
                     information please read the documentation for 
                     Net::Jabber::Query.  NOTE: Jabber does not support
                     custom IQs at the time of this writing.  This was just
                     including in case they do at some point.

  Reply(template=>string, - creates a new IQ object and populates
        type=>string)       the to/from and etherxto/etherxfrom fields
                            based the value of template.  The following
                            templates are available:

                            client: (default)
                                 just sets the to/from

                            transport:
                                 the transport will send the
                                 reply to the sender

                            The type will be set in the <iq/>.

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
					  header=>"NJ::IQ");
  
  $self->{QUERY} = "";

  if ("@_" ne ("")) {
    my @temp = @_;
    $self->{IQ} = \@temp;
    my $xmlns = $self->GetQueryXMLNS();
    my @queryTree = $self->GetQueryTree();
    $self->SetQuery($xmlns,@queryTree) if ($xmlns ne "");
  } else {
    $self->{IQ} = [ "iq" , [{}]];
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
  return "iq";
}


##############################################################################
#
# GetTo - returns the Jabber Identifier of the person you are sending the
#         <iq/> to.
#
##############################################################################
sub GetTo {
  my $self = shift;
  my ($type) = @_;
  my $to = &Net::Jabber::GetXMLData("value",$self->{IQ},"","to");
  if ($type eq "jid") {
    return new Net::Jabber::JID($to);
  } else {
    return $to;
  }
}


##############################################################################
#
# GetFrom - returns the Jabber Identifier of the person who sent the 
#           <iq/>
#
##############################################################################
sub GetFrom {
  my $self = shift;
  my ($type) = @_;
  my $from = &Net::Jabber::GetXMLData("value",$self->{IQ},"","from");
  if ($type eq "jid") {
    return new Net::Jabber::JID($from);
  } else {
    return $from;
  }
}


##############################################################################
#
# GetEtherxTo - returns the value of the etherx:to attribute in the 
#               <iq/>.
#
##############################################################################
sub GetEtherxTo {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{IQ},"","etherx:to");
}


##############################################################################
#
# GetEtherxFrom - returns the value of the etherx:from attribute in the 
#                 <iq/>.
#
##############################################################################
sub GetEtherxFrom {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{IQ},"","etherx:from");
}


##############################################################################
#
# GetID - returns the id of the <iq/>
#
##############################################################################
sub GetID {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{IQ},"","id");
}


##############################################################################
#
# GetType - returns the type of the <iq/>
#
##############################################################################
sub GetType {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{IQ},"","type");
}


##############################################################################
#
# GetError - returns the text associated with the error in the <iq/>
#
##############################################################################
sub GetError {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{IQ},"error");
}


##############################################################################
#
# GetErrorCode - returns the code of the error in the <iq/>
#
##############################################################################
sub GetErrorCode {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{IQ},"error","code");
}


##############################################################################
#
# GetQuery - returns a Net::Jabber::Query object that contains the <query/>
#
##############################################################################
sub GetQuery {
  my $self = shift;
  $self->{DEBUG}->Log2("GetQuery: return($self->{QUERY})");
  return $self->{QUERY} if ($self->{QUERY} ne "");
  return;
}


##############################################################################
#
# GetQueryTree - returns an XML::Parser::Tree object of the <query/> tag
#
##############################################################################
sub GetQueryTree {
  my $self = shift;
  $self->MergeQuery();
  return &Net::Jabber::GetXMLData("tree",$self->{IQ},"*");
}


##############################################################################
#
# GetQueryXMLNS - returns the xmlns of the <query/> tag
#
##############################################################################
sub GetQueryXMLNS {
  my $self = shift;
  $self->MergeQuery();
  return &Net::Jabber::GetXMLData("value",$self->{IQ},"*","xmlns");
}


##############################################################################
#
# GetXML - returns the XML string that represents the data in the XML::Parser
#          Tree.
#
##############################################################################
sub GetXML {
  my $self = shift;
  $self->MergeQuery();
  return &Net::Jabber::BuildXML(@{$self->{IQ}});
}


##############################################################################
#
# GetTree - returns the XML::Parser Tree that is stored in the guts of
#           the object.
#
##############################################################################
sub GetTree {
  my $self = shift;
  $self->MergeQuery();
  return @{$self->{IQ}};
}


##############################################################################
#
# SetIQ - takes a hash of all of the things you can set on an <iq/> and sets
#         each one.
#
##############################################################################
sub SetIQ {
  my $self = shift;
  my %iq;
  while($#_ >= 0) { $iq{ lc pop(@_) } = pop(@_); }

  $self->SetID($iq{id}) if exists($iq{id});
  $self->SetTo($iq{to}) if exists($iq{to});
  $self->SetFrom($iq{from}) if exists($iq{from});
  $self->SetEtherxTo($iq{etherxto}) if exists($iq{etherxto});
  $self->SetEtherxFrom($iq{etherxfrom}) if exists($iq{etherxfrom});
  $self->SetType($iq{type}) if exists($iq{type});
  $self->SetErrorCode($iq{errorcode}) if exists($iq{errorcode});
  $self->SetError($iq{error}) if exists($iq{error});
}


##############################################################################
#
# SetID - sets the id attribute in the <iq/>
#
##############################################################################
sub SetID {
  my $self = shift;
  my ($id) = @_;
  &Net::Jabber::SetXMLData("single",$self->{IQ},"","",{id=>$id});
}


##############################################################################
#
# SetTo - sets the to attribute in the <iq/>
#
##############################################################################
sub SetTo {
  my $self = shift;
  my ($to) = @_;
  if (ref($to) eq "Net::Jabber::JID") {
    $to = $to->GetJID("full");
  }
  &Net::Jabber::SetXMLData("single",$self->{IQ},"","",{to=>$to});
}


##############################################################################
#
# SetFrom - sets the from attribute in the <iq/>
#
##############################################################################
sub SetFrom {
  my $self = shift;
  my ($from) = @_;
  if (ref($from) eq "Net::Jabber::JID") {
    $from = $from->GetJID("full");
  }
  &Net::Jabber::SetXMLData("single",$self->{IQ},"","",{from=>$from});
}


##############################################################################
#
# SetEtherxTo - sets the etherx:to attribute in the <iq/>
#
##############################################################################
sub SetEtherxTo {
  my $self = shift;
  my ($etherxto) = @_;
  &Net::Jabber::SetXMLData("single",$self->{IQ},"","",{"etherx:to"=>$etherxto});
}


##############################################################################
#
# SetEtherxFrom - sets the etherx:from attribute in the <iq/>
#
##############################################################################
sub SetEtherxFrom {
  my $self = shift;
  my ($etherxfrom) = @_;
  &Net::Jabber::SetXMLData("single",$self->{IQ},"","",{"etherx:from"=>$etherxfrom});
}


##############################################################################
#
# SetType - sets the type attribute in the <iq/>
#
##############################################################################
sub SetType {
  my $self = shift;
  my ($type) = @_;
  &Net::Jabber::SetXMLData("single",$self->{IQ},"","",{type=>$type});
}


##############################################################################
#
# SetErrorCode - sets the code attribute in the error tag of the <iq/>
#
##############################################################################
sub SetErrorCode {
  my $self = shift;
  my ($code) = @_;
  &Net::Jabber::SetXMLData("single",$self->{IQ},"error","",{code=>$code});
}


##############################################################################
#
# SetError - sets the error of the <iq/>
#
##############################################################################
sub SetError {
  my $self = shift;
  my ($error) = @_;
  &Net::Jabber::SetXMLData("single",$self->{IQ},"error",$error,{});
}


##############################################################################
#
# NewQuery - calls SetQuery to create a new Net::Jabber::Query object, sets 
#            the xmlns and returns a pointer to the new object.
#
##############################################################################
sub NewQuery {
  my $self = shift;
  my ($xmlns) = @_;
  return if !exists($Net::Jabber::DELEGATES{$xmlns});
  my $query = $self->SetQuery($xmlns);
  $query->SetXMLNS($xmlns) if $xmlns ne "";
  return $query;
}


##############################################################################
#
# SetQuery - creates a new Net::Jabber::Query object, sets the internal
#            pointer to it, and returns a pointer to the new object.  This 
#            is a private helper function.
#
##############################################################################
sub SetQuery {
  my $self = shift;
  my ($xmlns,@queryTree) = @_;
  return if !exists($Net::Jabber::DELEGATES{$xmlns});
  $self->{DEBUG}->Log2("SetQuery: xmlns($xmlns) tree(",\@queryTree,")");
  eval("\$self->{QUERY} = new ".$Net::Jabber::DELEGATES{$xmlns}->{parent}."(\@queryTree);");
  $self->{DEBUG}->Log2("SetQuery: return($self->{QUERY})");
  return $self->{QUERY};
}
  

##############################################################################
#
# MergeQuery - rebuilds the <query/>in memory and merges it into the current
#              IQ tree. This is a private helper function.  It should be used
#              any time you need access the full <iq/> so that the <query/> 
#              tag is included.  (ie. GetXML, GetTree, debug, etc...)
#
##############################################################################
sub MergeQuery {
  my $self = shift;

  $self->{DEBUG}->Log2("MergeQuery: start");

  my $replaced = 0;

  return if ($self->{QUERY} eq "");

  $self->{DEBUG}->Log2("MergeQuery: selfQuery($self->{QUERY})");

  my $query = $self->{QUERY};
  my @queryTree = $query->GetTree();

  $self->{DEBUG}->Log2("MergeQuery: Check the old tags");
  $self->{DEBUG}->Log2("MergeQuery: length(",$#{$self->{IQ}->[1]},")");

  my $i;
  foreach $i (1..$#{$self->{IQ}->[1]}) {
    $self->{DEBUG}->Log2("MergeQuery: i($i)");
    $self->{DEBUG}->Log2("MergeQuery: data(",$self->{IQ}->[1]->[$i],")");
    if ((ref($self->{IQ}->[1]->[($i+1)]) eq "ARRAY") &&
	exists($self->{IQ}->[1]->[($i+1)]->[0]->{xmlns})) {
      $replaced = 1;
      $self->{IQ}->[1]->[$i] = $queryTree[0];
      $self->{IQ}->[1]->[($i+1)] = $queryTree[1];
    }
  }

  if ($replaced == 0) {
    $self->{DEBUG}->Log2("MergeQuery: new tag");
    $self->{IQ}->[1]->[($#{$self->{IQ}->[1]}+1)] = $queryTree[0];
    $self->{IQ}->[1]->[($#{$self->{IQ}->[1]}+1)] = $queryTree[1];
  }

  $self->{DEBUG}->Log2("MergeQuery: end");
}


##############################################################################
#
# Reply - returns a Net::Jabber::IQ object with the proper fields
#         already populated for you.
#
##############################################################################
sub Reply {
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  my $reply = new Net::Jabber::IQ();

  $reply->SetID($self->GetID()) if ($self->GetID() ne "");
  $reply->SetType(exists($args{type}) ? $args{type} : "result");

  my $selfQuery = $self->GetQuery();
  $reply->NewQuery($selfQuery->GetXMLNS());

  if (exists($args{template})) {
    if ($args{template} eq "transport") {
      my $fromJID = $self->GetFrom("jid");
      
      $reply->SetIQ(to=>$self->GetFrom(),
		    from=>$self->GetTo(),
		    etherxto=>$fromJID->GetServer(),
		    etherxfrom=>$self->GetEtherxTo(),
		   );
    } else {
      $reply->SetIQ(to=>$self->GetFrom(),
		    from=>$self->GetTo());
    }	
  } else {
    $reply->SetIQ(to=>$self->GetFrom(),
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

  print "debug IQ: $self\n";
  $self->MergeQuery();
  &Net::Jabber::printData("debug: \$self->{IQ}->",$self->{IQ});
}

1;
