package Net::Jabber::Query::AutoUpdate::Release;

=head1 NAME

Net::Jabber::Query::AutoUpdate::Release - Jabber IQ AutoUpdate Release Module

=head1 SYNOPSIS

  Net::Jabber::Query::AutoUpdate::Release is a companion to the 
  Net::Jabber::Query::AutoUpdate module.  It provides the user a simple 
  interface to set and retrieve all parts of a Jabber AutoUpdate Release.

=head1 DESCRIPTION

  To initialize the Item with a Jabber <iq/> and then access the auth
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iq {
      my $iq = new Net::Jabber::IQ(@_);
      my $autoupdate = $iq->GetQuery();
      my $release = $roster->GetRelease();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available below.

  To create a new IQ Roster Item to send to the server:

    use Net::Jabber;

    $Client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $autoupdate = $iq->NewQuery("jabber:iq:autoupdate");
    $release = $roster->AddRelease(type=>"beta");
    ...

    $client->Send($iq);

  Using $release you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $version     = $release->GetVersion();
    $description = $release->GetDesc();
    $url         = $release->GetURL();
    $priority    = $release->GetPriority();

    @release     = $release->GetTree();
    $str          = $release->GetXML();

=head2 Creation functions

    $release->SetRelease(version=>"1.3.2",
		         desc=>"Bob's Client for Jabber",
		         url=>"http://www.bobssite.com/client.1.3.2.tar.gz",
		         priority=>"optional");
    $release->SetVersion('5.6');
    $release->SetDesc('A description of the client');
    $release->SetURL('http://somesite/path/client.tar.gz');
    $release->SetPriority("mandatory");

=head1 METHODS

=head2 Retrieval functions

  GetVersion() - returns a string with the version number of this release.

  GetDesc() - returns a string with the description of this release.

  GetURL() - returns a string with the URL for downloading this release.

  GetPriority() - returns a string with the priority of this release.

                    optional  - The user can get it if they want to
                    mandatory - The user must get this version

  GetXML() - returns the XML string that represents the <presence/>.
             This is used by the Send() function in Client.pm to send
             this object as a Jabber Presence.

  GetTree() - returns an array that contains the <presence/> tag
              in XML::Parser Tree format.

=head2 Creation functions

  SetRelease(version=>string,  - set multiple fields in the release
             desc=>string,       at one time.  This is a cumulative
             url=>string,        and overwriting action.  If you
             priority=>string,   set the "url" twice, the second
                                 setting is what is used.  If you set
                                 the desc, and then set the
                                 priority then both will be in the
                                 release tag.  For valid settings
                                 read the specific Set functions below.

  SetVersion(string) - sets the version number of this release.

  SetDesc(string) - sets the description of this release.

  SetURL(string) - sets the url for downloading this release.

  SetPriotity(string) - sets the priority of this release.  If "" or not
                        "optional" or "mandatory" then this defaults to
                        "optional".


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
    if ($#_ == 1) {
      my @temp = @_;
      $self->{RELEASE} = \@temp;
    } else {
      $self->{RELEASE} = [ "@_", [ {} ]];
    }
  } else {
    print "ERROR: You must specify a type for Net::Jabber::Query::AutoUpdate::Release.\n";
    print "       (release,dev,beta)\n";
    exit(0);
  }

  return $self;
}


##############################################################################
#
# GetVersion - returns the version of this release
#
##############################################################################
sub GetVersion {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{RELEASE},"version","");
}


##############################################################################
#
# GetDesc - returns the description of this release
#
##############################################################################
sub GetDesc {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{RELEASE},"desc","");
}


##############################################################################
#
# GetURL - returns the url of this release
#
##############################################################################
sub GetURL {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{RELEASE},"url","");
}


##############################################################################
#
# GetPriority - returns the priority of this release
#
##############################################################################
sub GetPriority {
  my $self = shift;
  return &Net::Jabber::GetXMLData("value",$self->{RELEASE},"","priority");
}


##############################################################################
#
# GetXML - returns the XML string that represents the data in the XML::Parser
#          Tree.
#
##############################################################################
sub GetXML {
  my $self = shift;
  return &Net::Jabber::BuildXML(@{$self->{RELEASE}});
}


##############################################################################
#
# GetTree - returns the XML::Parser Tree that is stored in the guts of
#           the object.
#
##############################################################################
sub GetTree {
  my $self = shift;  
  return @{$self->{RELEASE}};
}


##############################################################################
#
# SetRelease - takes a hash of all of the things you can set on a release 
#              <query/> and sets each one.
#
##############################################################################
sub SetRelease {
  my $self = shift;
  my %release;
  while($#_ >= 0) { $release{ lc pop(@_) } = pop(@_); }
  
  $self->SetVersion($release{version}) if exists($release{version});
  $self->SetDesc($release{desc}) if exists($release{desc});
  $self->SetURL($release{url}) if exists($release{url});
  $self->SetPriority($release{priority}) if exists($release{priority});
}


##############################################################################
#
# SetVersion - sets the version number of this release
#
##############################################################################
sub SetVersion {
  my $self = shift;
  my ($version) = @_;
  &Net::Jabber::SetXMLData("single",$self->{RELEASE},"version","$version",{});
}


##############################################################################
#
# SetDesc - sets the description of this release
#
##############################################################################
sub SetDesc {
  my $self = shift;
  my ($desc) = @_;
  &Net::Jabber::SetXMLData("single",$self->{RELEASE},"desc","$desc",{});
}


##############################################################################
#
# SetURL - sets the downlaod URL of this release
#
##############################################################################
sub SetURL {
  my $self = shift;
  my ($url) = @_;
  &Net::Jabber::SetXMLData("single",$self->{RELEASE},"url","$url",{});
}


##############################################################################
#
# SetPriority - sets the priority of this release
#
##############################################################################
sub SetPriority {
  my $self = shift;
  my ($priority) = @_;
  $priority = "optional" if ($priority ne "mandatory");
  &Net::Jabber::SetXMLData("single",$self->{RELEASE},"","",{priority=>$priority});
}


##############################################################################
#
# debug - prints out the XML::Parser Tree in a readable format for debugging
#
##############################################################################
sub debug {
  my $self = shift;

  print "debug RELEASE: $self\n";
  &Net::Jabber::printData("debug: \$self->{RELEASE}->",$self->{RELEASE});
}

1;
