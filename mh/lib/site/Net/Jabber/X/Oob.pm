package Net::Jabber::X::Oob;

=head1 NAME

Net::Jabber::X::Oob - Jabber X Out Of Bandwidth File Transfer Module

=head1 SYNOPSIS

  Net::Jabber::X::Oob is a companion to the Net::Jabber::X module.
  It provides the user a simple interface to set and retrieve all 
  parts of a Jabber X Oob.

=head1 DESCRIPTION

  To initialize the Oob with a Jabber <x/> you must pass it the 
  XML::Parser Tree array from the module trying to access the <x/>.  
  In the callback function:

    use Net::Jabber;

    sub iq {
      my $foo = new Net::Jabber::Foo(@_);

      my @xTags = $foo->GetX("jabber:x:oob");

      my $xTag;
      foreach $xTag (@xTags) {
	$xTag->....
	
      }
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new Oob to send to the server:

    use Net::Jabber;

    $foo = new Net::Jabber::Foo();
    $x = $foo->NewX("jabber:x:oob");

  Now you can call the creation functions below.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $url  = $xTag->GetURL();
    $desc = $xTag->GetDesc();

=head2 Creation functions

    $xTag->SetOob(UrL=>"http://my.web.server.com/~me/pics/bob.jpg",
	          desc=>"Picture of Bob, the one and only");

    $xTag->SetURL("http://my.web.server.com/~me/pics/bobandme.jpg");
    $xTag->SetDesc("Bob and Me at the Open Source conference");

=head1 METHODS

=head2 Retrieval functions

  GetURL() - returns a string with the URL of the file being sent Oob.

  GetDesc() - returns a string with the description of the file being
               sent Oob.

=head2 Creation functions

  SetOob(url=>string,  - set multiple fields in the <x/> at one
         desc=>string)   time.  This is a cumulative and over
                         writing action.  If you set the "url"
                         attribute twice, the second setting is
                         what is used.  If you set the url, and
                         then set the desc then both will be in
                         the <x/> tag.  For valid settings read the
                         specific Set functions below.

  SetURL(string) - sets the URL for the file being sent Oob.

  SetDesc(string) - sets the description for the file being sent Oob.

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
# GetURL - returns the url of the jabber:x:oob
#
##############################################################################
sub GetURL {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{X},"url","");
}


##############################################################################
#
# GetDesc - returns the desc of the jabber:x:oob
#
##############################################################################
sub GetDesc {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{X},"desc","");
}


##############################################################################
#
# SetOob - takes a hash of all of the things you can set on a jabber:x:oob and
#          sets each one.
#
##############################################################################
sub SetOob {
  shift;
  my $self = shift;
  my %oob;
  while($#_ >= 0) { $oob{ lc pop(@_) } = pop(@_); }

  $self->SetURL($oob{url}) if exists($oob{url});
  $self->SetDesc($oob{desc}) if exists($oob{desc});
}


##############################################################################
#
# SetURL - sets the url in the jabber:x:oob
#
##############################################################################
sub SetURL {
  shift;
  my $self = shift;
  my ($url) = @_;
  &Net::Jabber::SetXMLData("single",$self->{X},"url",$url,{});
}


##############################################################################
#
# SetDesc - sets the desc in the jabber:x:oob
#
##############################################################################
sub SetDesc {
  shift;
  my $self = shift;
  my ($desc) = @_;
  
  &Net::Jabber::SetXMLData("single",$self->{X},"desc",$desc,{});
}


1;
