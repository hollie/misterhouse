package Net::Jabber::Query::Version;

=head1 NAME

Net::Jabber::Query::Version - Jabber IQ Version Module

=head1 SYNOPSIS

  Net::Jabber::Query::Version is a companion to the Net::Jabber::Query module.
  It provides the user a simple interface to set and retrieve all parts
  of a Jabber Version query.

=head1 DESCRIPTION

  To initialize the Query with a Jabber <iq/> and then access the version
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iqCB {
      my $iq = new Net::Jabber::IQ(@_);
      my $version = $iq->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new Query version to send to the server:

    use Net::Jabber;

    $client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $version = $iq->NewQuery("jabber:iq:version");
    ...

    $client->Send($iq);

  Using $version you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $name = $version->GetName();
    $ver  = $version->GetVer();
    $os   = $version->GetOS();

=head2 Creation functions

    $version->SetVersion(name=>'Net::Jabber',
                         ver=>'1.0',
                         os=>'Perl');

    $version->SetName('JabberClient');
    $version->SetVer('0.1');
    $version->SetOS('Perl/Tk');

=head1 METHODS

=head2 Retrieval functions

  GetName() - returns a string with the name in the <query/>.

  GetVer() - returns a string with the version in the <query/>.

  GetOS() - returns a string with the os in the <query/>.

=head2 Creation functions

  SetVersion(name=>string, - set multiple fields in the <iq/> at one
             ver=>string,    time.  This is a cumulative and over
             os=>string)     writing action.  If you set the "name" 
                             twice, the second setting is what is
                             used.  If you set the ver, and then
                             set the os then both will be in the
                             <query/> tag.  For valid settings read 
                             the specific Set functions below.

  SetName(string) - sets the name of the local client for the <query/>.

  SetVer(string) - sets the version of the local client in the <query/>.

  SetOS(string) - sets the os, or cross-platform language, of the local
                  client in the <query/>.

=head1 AUTHOR

By Ryan Eatmon in May of 2000 for http://jabber.org..

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use POSIX;
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
# GetName - returns the name in the <query/>.
#
##############################################################################
sub GetName {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"name");
}


##############################################################################
#
# GetVer - returns the version in the <query/>.
#
##############################################################################
sub GetVer {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"version");
}


##############################################################################
#
# GetOS - returns the os in the <query/>.
#
##############################################################################
sub GetOS {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"os");
}


##############################################################################
#
# SetVersion - takes a hash of all of the things you can set on an version 
#              <query/> and sets each one.
#
##############################################################################
sub SetVersion {
  shift;
  my $self = shift;
  my %version;
  while($#_ >= 0) { $version{ lc pop(@_) } = pop(@_); }
  
  $self->SetName($version{name}) if exists($version{name});
  $self->SetVer($version{ver}) if exists($version{ver});
  $self->SetOS($version{os});
}


##############################################################################
#
# SetName - sets the name of your local client.
#
##############################################################################
sub SetName {
  shift;
  my $self = shift;
  my ($name) = @_;
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"name",$name,{});
}


##############################################################################
#
# SetVer - sets the timezone of your local client.
#
##############################################################################
sub SetVer {
  shift;
  my $self = shift;
  my ($version) = @_;
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"version",$version,{});
}


##############################################################################
#
# SetOS - sets the os time that the remote client should use.
#
##############################################################################
sub SetOS {
  shift;
  my $self = shift;
  my ($os) = @_;
  if ($os eq "") {
    my @uname = &POSIX::uname();
    $os = $uname[0];
  }
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"os",$os,{});
}

1;
