package Net::Jabber::X::AutoUpdate;

=head1 NAME

Net::Jabber::X::AutoUpdate - Jabber X AutoUpdate Delegate

=head1 SYNOPSIS

  Net::Jabber::X::AutoUpdate is a companion to the Net::Jabber::X module.
  It provides the user a simple interface to set and retrieve all 
  parts of a Jabber X AutoUpdate.

=head1 DESCRIPTION

  To initialize the AutoUpdate with a Jabber <x/> you must pass it the 
  XML::Parser Tree array from the module trying to access the <x/>.  
  In the callback function:

    use Net::Jabber;

    sub iq {
      my $foo = new Net::Jabber::Foo(@_);

      my @xTags = $foo->GetX("jabber:x:autoupdate");

      my $xTag;
      foreach $xTag (@xTags) {
	$xTag->....
	
      }
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new AutoUpdate to send to the server:

    use Net::Jabber;

    $foo = new Net::Jabber::Foo();
    $x = $foo->NewX("jabber:x:autoupdate");

  Now you can call the creation functions below.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $jid = $xTag->GetJID();

=head2 Creation functions

    $xTag->SetX(jid=>"update.jabber.org");

    $xTag->SetJID("update.jabber.com");

=head1 METHODS

=head2 Retrieval functions

  GetJID() - returns a string with the Jabber Identifier of the 
             agent that is going to handle the update.

=head2 Creation functions

  SetX(jid=>string) - set multiple fields in the <x/> at one
                      time.  This is a cumulative and over
                      writing action.  If you set the "jid"
                      attribute twice, the second setting is
                      what is used.  For valid settings read the
                      specific Set functions below.

  SetJID(string) - sets the JID of the agent that is going to handle the
                   update.

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

  return $self;
}


##############################################################################
#
# GetJID - returns the JID of the agent that is going to handle the update
#
##############################################################################
sub GetJID {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{X},"","");
}

##############################################################################
#
# SetX - takes a hash of all of the things you can set on a 
#        jabber:x:autoupdate and sets each one.
#
##############################################################################
sub SetX {
  shift;
  my $self = shift;
  my %x;
  while($#_ >= 0) { $x{ lc pop(@_) } = pop(@_); }

  $self->SetJID($x{jid}) if exists($x{jid});
}


##############################################################################
#
# SetJID - sets the cdata of the jabber:x:autoupdate
#
##############################################################################
sub SetJID {
  shift;
  my $self = shift;
  my ($jid) = @_;
  &Net::Jabber::SetXMLData("single",$self->{X},"","$jid",{});
}


1;
