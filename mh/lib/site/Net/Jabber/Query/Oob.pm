package Net::Jabber::Query::Oob;

=head1 NAME

Net::Jabber::Query::Oob - Jabber Query Out Of Bandwidth File Transfer Module

=head1 SYNOPSIS

  Net::Jabber::Query::Oob is a companion to the Net::Jabber::Query module.
  It provides the user a simple interface to set and retrieve all 
  parts of a Jabber Query Oob.

=head1 DESCRIPTION

  To initialize the Oob with a Jabber <iq/> you must pass it the 
  XML::Parser Tree array from the module trying to access the <iq/>.  
  In the callback function:

    use Net::Jabber;

    sub iqCB {
      my $iq = new Net::Jabber::IQ(@_);
      my $oob = $iq->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new Oob to send to the server:

    use Net::Jabber;

    $iq = new Net::Jabber::IQ();
    $oob = $iq->NewQuery("jabber:iq:oob");

  Now you can call the creation functions below.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $url  = $oob->GetURL();
    $desc = $oob->GetDesc();

=head2 Creation functions

    $oob->SetOob(UrL=>"http://my.web.server.com/~me/pics/bob.jpg",
	         desc=>"Picture of Bob, the one and only");

    $oob->SetURL("http://my.web.server.com/~me/pics/bobandme.jpg");
    $oob->SetDesc("Bob and Me at the Open Source conference");

=head1 METHODS

=head2 Retrieval functions

  GetURL() - returns a string with the URL of the file being sent Oob.

  GetDesc() - returns a string with the description of the file being
               sent Oob.

=head2 Creation functions

  SetOob(url=>string,  - set multiple fields in the <iq/> at one
         desc=>string)   time.  This is a cumulative and over
                         writing action.  If you set the "url"
                         attribute twice, the second setting is
                         what is used.  If you set the url, and
                         then set the desc then both will be in
                         the <iq/> tag.  For valid settings read the
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
# GetURL - returns the url of the jabber:iq:oob
#
##############################################################################
sub GetURL {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"url","");
}


##############################################################################
#
# GetDesc - returns the desc of the jabber:iq:oob
#
##############################################################################
sub GetDesc {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"desc","");
}


##############################################################################
#
# SetOob - takes a hash of all of the things you can set on a jabber:iq:oob 
#          and sets each one.
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
# SetURL - sets the url in the jabber:iq:oob
#
##############################################################################
sub SetURL {
  shift;
  my $self = shift;
  my ($url) = @_;
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"url",$url,{});
}


##############################################################################
#
# SetDesc - sets the desc in the jabber:iq:oob
#
##############################################################################
sub SetDesc {
  shift;
  my $self = shift;
  my ($desc) = @_;
  
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"desc",$desc,{});
}


1;
