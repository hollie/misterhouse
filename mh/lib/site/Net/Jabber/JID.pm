package Net::Jabber::JID;

=head1 NAME

Net::Jabber::JID - Jabber JID Module

=head1 SYNOPSIS

  Net::Jabber::JID is a companion to the Net::Jabber module.
  It provides the user a simple interface to set and retrieve all 
  parts of a Jabber JID (userid on a server).

=head1 DESCRIPTION

  To initialize the JID you must pass it the string that represents the
  jid from the Jabber XML packet.  Inside the Jabber modules this is
  done automatically and the JID object is returned instead of a string.
  For example, in the callback function for the Jabber object foo:

    use Net::Jabber;

    sub foo {
      my $foo = new Net::Jabber::Foo(@_);
      my $from = $foo->GetFrom();
      my $JID = new Net::Jabber::JID($from);
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new JID to send to the server:

    use Net::Jabber;

    $JID = new Net::Jabber::JID();

  Now you can call the creation functions below to populate the tag before
  sending it.

=head2 Retrieval functions

    $userid   = $JID->GetUserID();
    $server   = $JID->GetServer();
    $resource = $JID->GetResource();

    $JID      = $JID->GetJID();
    $fullJID  = $JID->GetJID("full");

=head2 Creation functions

    $JID->SetJID(userid=>"bob",
		 server=>"jabber.org",
		 resource=>"Work");

    $JID->SetJID("blue@moon.org/Home");

    $JID->SetUserID("foo");
    $JID->SetServer("bar.net");
    $JID->SetResource("Foo Bar");

=head1 METHODS

=head2 Retrieval functions

  GetUserID() - returns a string with the Jabber userid of the JID.
                If the string is an address (bob%jabber.org) then
                the function will return it as an address 
                (bob@jabber.org).

  GetServer() - returns a string with the Jabber server of the JID.

  GetResource() - returns a string with the Jabber resource of the JID. 

  GetJID()       - returns a string that represents the JID stored
  GetJID("full")   within.  If the "full" string is specified, then
                   you get the full JID, including Resource, which
                   should be used to send to the server.

=head2 Creation functions

  SetJID(userid=>string,   - set multiple fields in the jid at
         server=>string,     one time.  This is a cumulative
         resource=>string)   and over writing action.  If you set
  SetJID(string)             the "userid" attribute twice, the second
                             setting is what is used.  If you set
                             the server, and then set the resource
                             then both will be in the jid.  If all
                             you pass is a string, then that string
                             is used as the JID.  For valid settings 
                             read the specific Set functions below.

  SetUserID(string) - sets the userid.  Must be a valid userid or the
                      server will complain if you try to use this JID
                      to talk to the server.  If the string is an 
                      address then it will be converted to the %
                      form suitable for using as a Jabber User ID.

  SetServer(string) - sets the server.  Must be a valid host on the 
                      network or the server will not be able to talk
                      to it.

  SetResource(string) - sets the resource of the userid to talk to.

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

  if ("@_" ne ("")) {
    my ($jid) = @_;
    $self->{JID} = $jid;
  } else {
    $self->{JID} = "";
  }
  $self->ParseJID();

  return $self;
}


##############################################################################
#
# ParseJID - private helper function that takes the JID and sets the
#            the three parts of it.
#
##############################################################################
sub ParseJID {
  my $self = shift;
  if ($self->{JID} =~ /\@/) {
    ($self->{USERID}) = ($self->{JID} =~ /^([^\@]+)\@[^\/]+\/?.*$/);
    ($self->{SERVER}) = ($self->{JID} =~ /^[^\@]+\@([^\/]+)\/?.*$/);
    ($self->{RESOURCE}) = ($self->{JID} =~ /^[^\@]+\@[^\/]+\/?(.*)$/);
  } else {
    $self->{USERID} = "";
    ($self->{SERVER}) = ($self->{JID} =~ /^([^\/]+)\/?.*$/);
    ($self->{RESOURCE}) = ($self->{JID} =~ /^[^\/]+\/?(.*)$/);
  }
}


##############################################################################
#
# BuildJID - private helper function that takes the three parts and sets the
#            JID from them.
#
##############################################################################
sub BuildJID {
  my $self = shift;
  $self->{JID} = $self->{USERID}."\@".$self->{SERVER};
  $self->{JID} .= "/".$self->{RESOURCE} if ($self->{RESOURCE} ne "");
}


##############################################################################
#
# GetUserID - returns the userid of the JID.
#
##############################################################################
sub GetUserID {
  my $self = shift;
  my $userid = $self->{USERID};
  $userid =~ s/\%/\@/;
  return $userid;
}


##############################################################################
#
# GetServer - returns the server of the JID.
#
##############################################################################
sub GetServer {
  my $self = shift;
  return $self->{SERVER};
}


##############################################################################
#
# GetResource - returns the resource of the JID.
#
##############################################################################
sub GetResource {
  my $self = shift;
  return $self->{RESOURCE};
}


##############################################################################
#
# GetJID - returns the full jid of the JID.
#
##############################################################################
sub GetJID {
  my $self = shift;
  my ($type) = @_;
  $type = "" unless defined($type);
  return $self->{JID} if ($type eq "full");
  return $self->{USERID}."\@".$self->{SERVER};
}


##############################################################################
#
# SetJID - takes a hash of all of the things you can set on a JID and sets
#          each one.
#
##############################################################################
sub SetJID {
  my $self = shift;
  my %jid;

  if ($#_ > 0 ) { 
    while($#_ >= 0) { $jid{ lc pop(@_) } = pop(@_); }

    $self->SetUserID($jid{userid}) if exists($jid{userid});
    $self->SetServer($jid{server}) if exists($jid{server});
    $self->SetResource($jid{resource}) if exists($jid{resource});
  } else {
    ($self->{JID}) = @_;
    $self->ParseJID();
  }
}


##############################################################################
#
# SetUserID - sets the userid of the JID.
#
##############################################################################
sub SetUserID {
  my $self = shift;
  my ($userid) = @_;
  $userid =~ s/\@/\%/;
  $self->{USERID} = $userid;
  $self->BuildJID();
}


##############################################################################
#
# SetServer - sets the server of the JID.
#
##############################################################################
sub SetServer {
  my $self = shift;
  my ($server) = @_;
  $self->{SERVER} = $server;
  $self->BuildJID();
}


##############################################################################
#
# SetResource - sets the resource of the JID.
#
##############################################################################
sub SetResource {
  my $self = shift;
  my ($resource) = @_;
  $self->{RESOURCE} = $resource;
  $self->BuildJID();
}


##############################################################################
#
# debug - prints out the contents of the JID
#
##############################################################################
sub debug {
  my $self = shift;

  print "debug JID: $self\n";
  print "UserID:   (",$self->{USERID},")\n";
  print "Server:   (",$self->{SERVER},")\n";
  print "Resource: (",$self->{RESOURCE},")\n";
  print "JID:      (",$self->{JID},")\n";
}


1;
