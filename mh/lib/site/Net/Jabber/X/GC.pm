package Net::Jabber::X::GC;

=head1 NAME

Net::Jabber::X::GC - Jabber X GroupChat Delegate

=head1 SYNOPSIS

  Net::Jabber::X::GC is a companion to the Net::Jabber::X module.
  It provides the user a simple interface to set and retrieve all 
  parts of a Jabber X GroupChat.
 
  The main purpose for this module is to handle nick changes from
  a groupchat server (i.e. IRC, etc...)

=head1 DESCRIPTION

  To initialize the GC with a Jabber <x/> you must pass it the 
  XML::Parser Tree array from the module trying to access the <x/>.  
  In the callback function:

    use Net::Jabber;

    sub iq {
      my $foo = new Net::Jabber::Foo(@_);

      my @xTags = $foo->GetX("jabber:x:gc");

      my $xTag;
      foreach $xTag (@xTags) {
	$xTag->....
	
      }
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new GC to send to the server:

    use Net::Jabber;

    $foo = new Net::Jabber::Foo();
    $xTag = $foo->NewX("jabber:x:gc");

  Now you can call the creation functions below.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $nick = $xTag->GetNick();

=head2 Creation functions

    $xTag->SetGC(nick=>"bob");

    $xTag->SetNick("bob_");

=head1 METHODS

=head2 Retrieval functions

  GetNick() - returns a string with the Jabber Identifier of the 
              person who added the gc.

=head2 Creation functions

  SetGC(nick=>string) - set multiple fields in the <x/> at one
                        time.  This is a cumulative and over
                        writing action.  If you set the "nick"
                        attribute twice, the second setting is
                        what is used.  If you set the nick, and
                        then set another field then both will be in
                        the <x/> tag.  For valid settings read the
                        specific Set functions below.

  SetNick(string) - sets the new nick sent from the server.

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
# GetNick - returns from of the jabber:x:gc
#
##############################################################################
sub GetNick {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{X},"nick","");
}


##############################################################################
#
# SetGC - takes a hash of all of the things you can set on a jabber:x:gc
#         and sets each one.
#
##############################################################################
sub SetGC {
  shift;
  my $self = shift;
  my %gc;
  while($#_ >= 0) { $gc{ lc pop(@_) } = pop(@_); }

  $self->SetNick($gc{nick}) if exists($gc{nick});
}


##############################################################################
#
# SetNick - sets the nick field in the jabber:x:gc
#
##############################################################################
sub SetNick {
  shift;
  my $self = shift;
  my ($nick) = @_;
  &Net::Jabber::SetXMLData("single",$self->{X},"nick","$nick",{});
}


1;
