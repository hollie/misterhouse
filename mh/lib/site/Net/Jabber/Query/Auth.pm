package Net::Jabber::Query::Auth;

=head1 NAME

Net::Jabber::Query::Auth - Jabber IQ Authentication Module

=head1 SYNOPSIS

  Net::Jabber::Query::Auth is a companion to the Net::Jabber::Query module.
  It provides the user a simple interface to set and retrieve all parts
  of a Jabber Authentication query.

=head1 DESCRIPTION

  To initialize the Query with a Jabber <iq/> and then access the auth
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iqCB {
      my $iq = new Net::Jabber::IQ(@_);
      my $auth = $iq->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new Query auth to send to the server:

    use Net::Jabber;

    $client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $auth = $iq->NewQuery("jabber:iq:auth");
    ...

    $client->Send($iq);

  Using $auth you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $username = $auth->GetUsername();
    $password = $auth->GetPassword();
    $digest   = $auth->GetDigest();
    $resource = $auth->GetResource();

=head2 Creation functions

    $auth->SetAuth(resource=>'Anonymous');
    $auth->SetAuth(username=>'test',
                   password=>'user',
                   resource=>'Test Account');

    $auth->SetUsername('bob');
    $auth->SetPassword('bobrulez');
    $auth->SetDigest('');
    $auth->SetResource('Bob the Great');

=head1 METHODS

=head2 Retrieval functions

  GetUsername() - returns a string with the username in the <query/>.

  GetPassword() - returns a string with the password in the <query/>.

  GetDigest() - returns a string with the SHA-1 digest in the <query/>.

  GetResource() - returns a string with the resource in the <query/>.

=head2 Creation functions

  SetAuth(username=>string, - set multiple fields in the <iq/> at one
          password=>string,   time.  This is a cumulative and over
          digest=>string,     writing action.  If you set the "username" 
          resource=>string)   twice, the second setting is what is
                              used.  If you set the password, and then
                              set the resource then both will be in the
                              <query/> tag.  For valid settings read 
                              the specific Set functions below.

  SetUsername(string) - sets the username for the account you are
                        trying to connect with.  Leave blank for
                        an anonymous account.

  SetPassword(string) - sets the password for the account you are
                        trying to connect with.  Leave blank for
                        an anonymous account.

  SetDigest(string) - sets the SHA-1 digest for the account you are
                      trying to connect with.  Leave blank for
                      an anonymous account.

  SetResource(string) - sets the resource for the account you are
                        trying to connect with.  Leave blank for
                        an anonymous account.

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
# GetUsername - returns the username in the <query/>.
#
##############################################################################
sub GetUsername {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"username");
}


##############################################################################
#
# GetPassword - returns the password in the <query/>.
#
##############################################################################
sub GetPassword {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"password");
}


##############################################################################
#
# GetDigest - returns the SHA1 digest in the <query/>.
#
##############################################################################
sub GetDigest {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"digest");
}


##############################################################################
#
# GetResource - returns the resource in the <query/>.
#
##############################################################################
sub GetResource {
  shift;
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{QUERY},"resource");
}


##############################################################################
#
# SetAuth - takes a hash of all of the things you can set on an auth <query/>
#           and sets each one.
#
##############################################################################
sub SetAuth {
  shift;
  my $self = shift;
  my %auth;
  while($#_ >= 0) { $auth{ lc pop(@_) } = pop(@_); }
  
  $self->SetUsername($auth{username}) if exists($auth{username});
  $self->SetPassword($auth{password}) if exists($auth{password});
  $self->SetDigest($auth{digest}) if exists($auth{digest});
  $self->SetResource($auth{resource}) if exists($auth{resource});
  $self->SetResource("Anonymous") if !exists($auth{resource});
}


##############################################################################
#
# SetUsername - sets the username of the account you want to connect with.
#
##############################################################################
sub SetUsername {
  shift;
  my $self = shift;
  my ($username) = @_;
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"username",$username,{});
}


##############################################################################
#
# SetPassword - sets the password of the account you want to connect with.
#
##############################################################################
sub SetPassword {
  shift;
  my $self = shift;
  my ($password) = @_;
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"password",$password,{});
}


##############################################################################
#
# SetDigest - sets the SHA-1 digest of the password of the account you want
#             to connect with.
#
##############################################################################
sub SetDigest {
  shift;
  my $self = shift;
  my ($digest) = @_;
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"digest",$digest,{});
}


##############################################################################
#
# SetResource - sets the resource of the account you want to connect with.
#
##############################################################################
sub SetResource {
  shift;
  my $self = shift;
  my ($resource) = @_;
  &Net::Jabber::SetXMLData("single",$self->{QUERY},"resource",$resource,{});
}

1;
