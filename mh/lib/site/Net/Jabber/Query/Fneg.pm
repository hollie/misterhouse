package Net::Jabber::Query::Fneg;

=head1 NAME

Net::Jabber::Query::Fneg - Jabber IQ Feature Negotiotation Module

=head1 SYNOPSIS

  Net::Jabber::Query::Fneg is a companion to the Net::Jabber::Query module.
  It provides the user a simple interface to set and retrieve all parts
  of a Jabber Feature Negotiotation query.

=head1 DESCRIPTION

  To initialize the IQ with a Jabber <iq/> and then access the fneg
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iqCB {
      my $iq = new Net::Jabber::IQ(@_);
      my $fneg = $iq->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new IQ fneg to send to the server:

    use Net::Jabber;

    $client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $fneg = $iq->NewQuery("jabber:iq:fneg");
    ...

    $client->Send($iq);

  Using $fneg you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions
    @namespaces = $auth->GetNS();

=head2 Creation functions
    $auth->AddNS("bar:foo:namespace");

=head1 METHODS

=head2 Retrieval functions
    GetNS() - returns an array of namespaces that the <query/> contains.

=head2 Creation functions
    AddNS(string) - adds the single namespace to the list in the <query/>.

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
# GetNS - returns the array of ns in the <query/>.
#
##############################################################################
sub GetNS {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("array",$self->{QUERY},"ns");
}

##############################################################################
#
# AddNS - adds the namespace to the list in the <query/>.
#
##############################################################################
sub AddNS {
  shift;
  my $self = shift;
  my ($ns) = @_;
  &Net::Jabber::SetXMLData("multiple",$self->{QUERY},"ns",$ns,{});
}




1;
