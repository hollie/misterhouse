package Net::Jabber::Query::Filter::Rule;

=head1 NAME

Net::Jabber::Query::Filter::Rule - Jabber IQ Filter Rule Module

=head1 SYNOPSIS

  Net::Jabber::Query::Filter::Rule is a companion to the 
  Net::Jabber::Query::Filter module.  It provides the user a simple 
  interface to set and retrieve all parts of a Jabber Filter Rule.

=head1 DESCRIPTION

  To initialize the Rule with a Jabber <iq/> and then access the filter
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iq {
      my $iq = new Net::Jabber::IQ(@_);
      my $filter = $iq->GetQuery();
      my @rules = $filter->GetRules();
      foreach $rule (@rules) {
        ...
      }
      .
      .
      .
    }

  You now have access to all of the retrieval functions available below.

  To create a new IQ Filter Rule to send to the server:

    use Net::Jabber;

    $Client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $filter = $iq->NewQuery("jabber:iq:filter");
    $rule = $filter->AddRule();
    ...

    $client->Send($iq);

  Using $rule you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    %conditions  = $rule->GetConditions();
    $body        = $rule->GetBody();
    $from        = $rule->GetFrom();
    $resource    = $rule->GetResource();
    $show        = $rule->GetShow();
    $size        = $rule->GetSize();
    $subject     = $rule->GetSubject();
    $time        = $rule->GetTime();
    $type        = $rule->GetType();
    $unavailable = $rule->GetUnavailable();

    %actions     = $rule->GetActions();
    $drop        = $rule->GetDrop();
    $edit        = $rule->GetEdit();
    $error       = $rule->GetError();
    $reply       = $rule->GetReply();
    $forward     = $rule->GetForward();
    $offline     = $rule->GetOffline();

    $continue    = $rule->GetContinue();

=head2 Creation functions

    $rule->SetRule(unavailable=>1,
                   offline=>1);
    $rule->SetRule(from=>"bob\@jabber.org",
                   forward=>"me\@jabber.org/Pager");
    $rule->SetRule(from=>"ex-wife\@jabber.org",
                   reply=>"I don't want to talk you...");

    $rule->SetBody("free");                              # Future condition
    $rule->SetFrom("bob");                               # Future condition
    $rule->SetResource("Home");                          # Future condition
    $rule->SetShow("dnd");                               # Future condition
    $rule->SetSize(1024);                                # Future condition
    $rule->SetSubject("sex");                            # Future condition
    $rule->SetTime("20000502T01:01:01");                 # Future condition
    $rule->SetType("chat");                              # Future condition
    $rule->SetUnavailable();

    $rule->SetDrop();
    $rule->SetEdit();                                    # Future Action
    $rule->SetError("This JID is not a valid address");
    $rule->SetForward("foo\@bar.com/FooBar");
    $rule->SetOffline();
    $rule->SetReply("I don't want to talk you...");

    $rule->SetContinue();

=head2 Defined functions

    $test = $rule->DefinedBody();
    $test = $rule->DefinedFrom();
    $test = $rule->DefinedResource();
    $test = $rule->DefinedShow();
    $test = $rule->DefinedSize();
    $test = $rule->DefinedSubject();
    $test = $rule->DefinedTime();
    $test = $rule->DefinedType();
    $test = $rule->DefinedUnavailable();

    $test = $rule->DefinedDrop();
    $test = $rule->DefinedEdit();
    $test = $rule->DefinedError();
    $test = $rule->DefinedForward();
    $test = $rule->DefinedOffline();
    $test = $rule->DefinedReply();

    $test = $rule->DefinedContinue();

=head1 METHODS

=head2 Retrieval functions

  GetConditions() - returns a hash with the condition name and the value
                    of the tag as the value in the hash.  For example:

                      $conditions{unavailable} = 1;
                      $conditions{resource} = "Pager";
                      $conditions{type} = "chat";

  GetBody() - returns the string that the <rule/> uses to match in the body
              for this condition.
              **** This condition is still under development ****
              **** in mod_filter.                            ****

  GetFrom() - returns the string that the <rule/> uses to match in the from
              for this condition.
              **** This condition is still under development ****
              **** in mod_filter.                            ****

  GetResource() - returns the string that the <rule/> uses to match in the
                  resource of the to for this condition.
                  **** This condition is still under development ****
                  **** in mod_filter.                            ****

  GetShow() - returns the string that the <rule/> uses to match in the show
              for this condition.
              **** This condition is still under development ****
              **** in mod_filter.                            ****

  GetSize() - returns the string that the <rule/> uses to match in the size
              for this condition.
              **** This condition is still under development ****
              **** in mod_filter.                            ****

  GetSubject() - returns the string that the <rule/> uses to match in the
                 subject for this condition.
                 **** This condition is still under development ****
                 **** in mod_filter.                            ****

  GetTime() - returns the string that the <rule/> uses to match the time
              for this condition.
              **** This condition is still under development ****
              **** in mod_filter.                            ****

  GetType() - returns the string that the <rule/> uses to match the type
              for this condition.
              **** This condition is still under development ****
              **** in mod_filter.                            ****

  GetUnavailable() - returns 1 if this condition is set, 0 otherwise.
                     This condition is used to specify that you are
                     unavailable.

  GetActions() - returns a hash with the condition name and the value
                 of the tag as the value in the hash.  For example:
    
                    $actions{reply} = "I'm not in the office right now.";
                    $actions{continue} = 1;

  GetDrop() - returns 1 if the message is to be dropped, 0 otherwise.

  GetEdit() - **** This condition is still under development ****
              **** in mod_filter.                            ****

  GetError() - returns the string that the <rule/> uses to return in
               error message.

  GetReply() - returns the string that is sent for this action.

  GetForward() - returns the JID of the account to forward the message
                 to for this action.

  GetOffline() - returns 1 if the message is to go to the offline message
                 list, 0 otherwise.

  GetContinue() - returns 1 if there is a <continue/> tag in the <rule/>,
                  0 otherwise.  This allows you to chain multiple actions
                  in order for one set of conditions.

=head2 Creation functions

  SetRule(body=>string,      - set multiple fields in the <rule/>
          from=>string,        at one time.  This is a cumulative
          resource=>string,    and overwriting action.  If you
          show=>string,        set the "body" twice, the second
          size=>string,        setting is what is used.  If you set
          time=>string,        the show, and then set the
          type=>string,        offline then both will be in the
          unavailable=>0|1,    <rule/> tag.  For valid settings
          edit=>string,        read the specific Set functions below.
          error=>string,       
          forward=>string,
          offline=>0|1,
          reply=>string,
          continue=>0|1)

  SetBody(string) - sets the string that the <rule/> uses to match against
                    in the body.

  SetFrom(string) - sets the string that the <rule/> uses to match against
                    in the from.

  SetResource(string) - sets the string that the <rule/> uses to match
                        against in the resource of the from JID.

  SetShow(string) - sets the string that the <rule/> uses to match against
                    in the show.

  SetSize(string) - sets the string that the <rule/> uses to match against
                    for the size of the message.

  SetSubject(string) - sets the string that the <rule/> uses to match against
                       in the subject.

  SetTime(string) - sets the string that the <rule/> uses to match against
                    for the time the message is received.

  SetType(string) - sets the string that the <rule/> uses to match against
                    for the type of message.

  SetUnavailable() - adds an <unavailable/> to the <rule/> to match if you
                     are offline.

  SetDrop() - sets that the <rule/> should drop the message from the queue.

  SetEdit(string) - sets the string that the <rule/> uses to execute the edit
                    action on.

  SetError(string) - sets the string that goes into the error message for
                     this action.

  SetForward(string) - sets the JID that the message is forwarded to for
                       this action.

  SetOffline() - sets that the message goes into the offline queue.

  SetReply(string) - sets the string that goes into the reply message for
                     this action.

  SetContinue() - sets that this <rule/> is continued in the next <rule/>.

=head2 Defined functions

  DefinedBody() - returns 1 if there is a <body/> tag in the <rule/>,
                  0 otherwise.

  DefinedFrom() - returns 1 if there is a <from/> tag in the <rule/>,
                  0 otherwise.

  DefinedResource() - returns 1 if there is a <resource/> tag in the 
                      <rule/>, 0 otherwise.

  DefinedShow() - returns 1 if there is a <show/> tag in the <rule/>,
                  0 otherwise.

  DefinedSize() - returns 1 if there is a <size/> tag in the <rule/>,
                  0 otherwise.

  DefinedSubject() - returns 1 if there is a <subject/> tag in the 
                     <rule/>, 0 otherwise.

  DefinedTime() - returns 1 if there is a <time/> tag in the <rule/>,
                  0 otherwise.

  DefinedType() - returns 1 if there is a <type/> tag in the <rule/>,
                  0 otherwise.

  DefinedUnavailable() - returns 1 if there is a <unavailable/> tag 
                         in the <rule/>, 0 otherwise.

  DefinedDrop() - returns 1 if there is a <drop/> tag in the <rule/>,
                  0 otherwise.

  DefinedEdit() - returns 1 if there is a <edit/> tag in the <rule/>,
                  0 otherwise.

  DefinedError() - returns 1 if there is a <error/> tag in the <rule/>,
                  0 otherwise.

  DefinedForward() - returns 1 if there is a <forward/> tag in the <rule/>,
                  0 otherwise.

  DefinedOffline() - returns 1 if there is a <offline/> tag in the <rule/>,
                  0 otherwise.

  DefinedReply() - returns 1 if there is a <reply/> tag in the <rule/>,
                  0 otherwise.

  DefinedContinue() - returns 1 if there is a <continue/> tag in the <rule/>,
                  0 otherwise.

=head1 AUTHOR

By Ryan Eatmon in June of 2000 for http://jabber.org..

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use Carp;
use vars qw($VERSION $AUTOLOAD %FUNCTIONS);

$VERSION = "1.0013";

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { };
  
  $self->{VERSION} = $VERSION;

  bless($self, $proto);

  if ("@_" ne ("")) {
    my @temp = @_;
    $self->{RULE} = \@temp;
  } else {
    $self->{RULE} = [ "rule" , [{}]];
  }

  return $self;
}


##############################################################################
#
# AUTOLOAD - This function calls the delegate with the appropriate function
#            name and argument list.
#
##############################################################################
sub AUTOLOAD {
  my $self = shift;
  return if ($AUTOLOAD =~ /::DESTROY$/);
  $AUTOLOAD =~ s/^.*:://;
  my ($type,$value) = ($AUTOLOAD =~ /^(Get|Set|Defined)(.*)$/);

  $type = "" unless defined($type);

  return $self->Get($value,@_) if ($type eq "Get");
  $self->Set($value,@_) if ($type eq "Set");
  return $self->Defined($value,@_) if ($type eq "Defined");
}


$FUNCTIONS{get}->{Body}        = ["value","body",""];
$FUNCTIONS{get}->{From}        = ["value","from",""];
$FUNCTIONS{get}->{Resource}    = ["value","resource",""];
$FUNCTIONS{get}->{Show}        = ["value","show",""];
$FUNCTIONS{get}->{Size}        = ["value","size",""];
$FUNCTIONS{get}->{Subject}     = ["value","subject",""];
$FUNCTIONS{get}->{Time}        = ["value","time",""];
$FUNCTIONS{get}->{Type}        = ["value","type",""];
$FUNCTIONS{get}->{Unavailable} = ["value","unavailable",""];
$FUNCTIONS{get}->{Drop}        = ["value","drop",""];
$FUNCTIONS{get}->{Edit}        = ["value","edit",""];
$FUNCTIONS{get}->{Error}       = ["value","error",""];
$FUNCTIONS{get}->{Forward}     = ["value","forward",""];
$FUNCTIONS{get}->{Offline}     = ["value","offline",""];
$FUNCTIONS{get}->{Reply}       = ["value","reply",""];
$FUNCTIONS{get}->{Continued}   = ["value","continued",""];

$FUNCTIONS{set}->{Body}        = ["single","body","*","",""];
$FUNCTIONS{set}->{From}        = ["single","from","*","",""];
$FUNCTIONS{set}->{Resource}    = ["single","resource","*","",""];
$FUNCTIONS{set}->{Show}        = ["single","show","*","",""];
$FUNCTIONS{set}->{Size}        = ["single","size","*","",""];
$FUNCTIONS{set}->{Subject}     = ["single","subject","*","",""];
$FUNCTIONS{set}->{Time}        = ["single","time","*","",""];
$FUNCTIONS{set}->{Type}        = ["single","type","*","",""];
$FUNCTIONS{set}->{Unavailable} = ["single","unavailable","*","",""];
$FUNCTIONS{set}->{Drop}        = ["single","drop","*","",""];
$FUNCTIONS{set}->{Edit}        = ["single","edit","*","",""];
$FUNCTIONS{set}->{Error}       = ["single","error","*","",""];
$FUNCTIONS{set}->{Forward}     = ["single","forward","*","",""];
$FUNCTIONS{set}->{Offline}     = ["single","offline","*","",""];
$FUNCTIONS{set}->{Reply}       = ["single","reply","*","",""];
$FUNCTIONS{set}->{Continued}   = ["single","continued","*","",""];

$FUNCTIONS{defined}->{Body}        = ["existence","body",""];
$FUNCTIONS{defined}->{From}        = ["existence","from",""];
$FUNCTIONS{defined}->{Resource}    = ["existence","resource",""];
$FUNCTIONS{defined}->{Show}        = ["existence","show",""];
$FUNCTIONS{defined}->{Size}        = ["existence","size",""];
$FUNCTIONS{defined}->{Subject}     = ["existence","subject",""];
$FUNCTIONS{defined}->{Time}        = ["existence","time",""];
$FUNCTIONS{defined}->{Type}        = ["existence","type",""];
$FUNCTIONS{defined}->{Unavailable} = ["existence","unavailable",""];
$FUNCTIONS{defined}->{Drop}        = ["existence","drop",""];
$FUNCTIONS{defined}->{Edit}        = ["existence","edit",""];
$FUNCTIONS{defined}->{Error}       = ["existence","error",""];
$FUNCTIONS{defined}->{Forward}     = ["existence","forward",""];
$FUNCTIONS{defined}->{Offline}     = ["existence","offline",""];
$FUNCTIONS{defined}->{Reply}       = ["existence","reply",""];
$FUNCTIONS{defined}->{Continued}   = ["existence","continued",""];


##############################################################################
#
# Get - returns the string that is contained in this tag/attribute.
#
##############################################################################
sub Get {
  my $self = shift;
  my $tag = shift;

  croak("Undefined function Get$tag in package ".ref($self))
    unless exists($FUNCTIONS{get}->{$tag});

  return &Net::Jabber::GetXMLData($FUNCTIONS{get}->{$tag}->[0],
				  $self->{RULE},
				  $FUNCTIONS{get}->{$tag}->[1],
				  $FUNCTIONS{get}->{$tag}->[2]);
}


##############################################################################
#
# Set - sets the XML data for this tag
#
##############################################################################
sub Set {
  my $self = shift;
  my $tag = shift;

  croak("Undefined function Set$tag in package ".ref($self))
    unless exists($FUNCTIONS{set}->{$tag});

  &Net::Jabber::SetXMLData($FUNCTIONS{set}->{$tag}->[0],
			   $self->{RULE},
			   $FUNCTIONS{set}->{$tag}->[1],
			   (($FUNCTIONS{set}->{$tag}->[2] eq "*") ? shift : ""),
			   (($FUNCTIONS{set}->{$tag}->[3] ne "") ?
			    {
			     $FUNCTIONS{set}->{$tag}->[3]=>
			     (($FUNCTIONS{set}->{$tag}->[4] eq "*") ? shift : ""),
			    } :
			    {}
			   )
			  );
}


##############################################################################
#
# Defined - returns 1 if the tag exists, 0 other else.
#
##############################################################################
sub Defined {
  my $self = shift;
  my $tag = shift;

  croak("Undefined function Defined$tag in package ".ref($self))
    unless exists($FUNCTIONS{defined}->{$tag});

  return &Net::Jabber::GetXMLData($FUNCTIONS{defined}->{$tag}->[0],
				  $self->{RULE},
				  $FUNCTIONS{defined}->{$tag}->[1],
				  $FUNCTIONS{defined}->{$tag}->[2]);
}


##############################################################################
#
# GetConditions - returns a hash of the conditions that are set for this rule.
#
##############################################################################
sub GetConditions {
  my $self = shift;

  my %conditions;

  $conditions{body} = $self->GetBody() if ($self->DefinedBody());
  $conditions{from} = $self->GetFrom() if ($self->DefinedFrom());
  $conditions{resource} = $self->GetResource() if ($self->DefinedResource());
  $conditions{show} = $self->GetShow() if ($self->DefinedShow());
  $conditions{size} = $self->GetSize() if ($self->DefinedSize());
  $conditions{subject} = $self->GetSubject() if ($self->DefinedSubject());
  $conditions{time} = $self->GetTime() if ($self->DefinedTime());
  $conditions{type} = $self->GetType() if ($self->DefinedType());
  $conditions{unavailable} = 1 if ($self->DefinedUnavailable());

  return %conditions;
}


##############################################################################
#
# GetActions - returns a hash of the actions that are set for this rule.
#
##############################################################################
sub GetActions {
  my $self = shift;

  my %actions;

  $actions{drop} = $self->GetDrop() if ($self->DefinedDrop());
  $actions{edit} = $self->GetEdit() if ($self->DefinedEdit());
  $actions{error} = $self->GetError() if ($self->DefinedError());
  $actions{forward} = $self->GetForward() if ($self->DefinedForward());
  $actions{offline} = 1 if ($self->DefinedOffline());
  $actions{reply} = $self->GetReply() if ($self->DefinedReply());

  return %actions;
}


##############################################################################
#
# GetXML - returns the XML string that represents the data in the XML::Parser
#          Tree.
#
##############################################################################
sub GetXML {
  my $self = shift;
  return &Net::Jabber::BuildXML(@{$self->{RULE}});
}


##############################################################################
#
# GetTree - returns the XML::Parser Tree that is stored in the guts of
#           the object.
#
##############################################################################
sub GetTree {
  my $self = shift;  
  return @{$self->{RULE}};
}


##############################################################################
#
# SetRule - takes a hash of all of the things you can set on an rule <query/>
#           and sets each one.
#
##############################################################################
sub SetRule {
  my $self = shift;
  my %rule;
  while($#_ >= 0) { $rule{ lc pop(@_) } = pop(@_); }
  
  $self->SetBody($rule{body}) if exists($rule{body});
  $self->SetFrom($rule{from}) if exists($rule{from});
  $self->SetResource($rule{resource}) if exists($rule{resource});
  $self->SetShow($rule{show}) if exists($rule{show});
  $self->SetSize($rule{size}) if exists($rule{size});
  $self->SetSubject($rule{subject}) if exists($rule{subject}); 
  $self->SetTime($rule{time}) if exists($rule{time});
  $self->SetType($rule{type}) if exists($rule{type});
  $self->SetUnavailable() if (exists($rule{unavailable}) && ($rule{unavailable} == 1));
  $self->SetDrop() if (exists($rule{drop}) && ($rule{drop} == 1));
  $self->SetEdit($rule{edit}) if exists($rule{edit});
  $self->SetError($rule{error}) if exists($rule{error});
  $self->SetForward($rule{forward}) if exists($rule{forward});
  $self->SetOffline() if (exists($rule{offline}) && ($rule{offline} == 1));
  $self->SetReply($rule{reply}) if exists($rule{reply});
  $self->SetContinue() if (exists($rule{continue}) && ($rule{continue} == 1));
}


##############################################################################
#
# debug - prints out the XML::Parser Tree in a readable format for debugging
#
##############################################################################
sub debug {
  my $self = shift;

  print "debug RULE: $self\n";
  &Net::Jabber::printData("debug: \$self->{RULE}->",$self->{RULE});
}

1;
