package Net::Jabber::Query::AutoUpdate;

=head1 NAME

Net::Jabber::Query::AutoUpdate - Jabber IQ AutoUpdate Module

=head1 SYNOPSIS

  Net::Jabber::Query::AutoUpdate is a companion to the Net::Jabber::Query
  module.  It provides the user a simple interface to set and retrieve
  all parts of a Jabber AutoUpdate query.

=head1 DESCRIPTION

  To initialize the Query with a Jabber <iq/> and then access the autoupdate
  query you must pass it the XML::Parser Tree array from the 
  Net::Jabber::Client module.  In the callback function for the iq:

    use Net::Jabber;

    sub iqCB {
      my $iq = new Net::Jabber::IQ(@_);
      my $autoupdate = $iq->GetQuery();
      .
      .
      .
    }

  You now have access to all of the retrieval functions available.

  To create a new Query autoupdate to send to the server:

    use Net::Jabber;

    $client = new Net::Jabber::Client();
    ...

    $iq = new Net::Jabber::IQ();
    $autoupdate = $iq->NewQuery("jabber:iq:autoupdate");
    ...

    $client->Send($iq);

  Using $autoupdate you can call the creation functions below to populate the 
  tag before sending it.

  For more information about the array format being passed to the CallBack
  please read the Net::Jabber::Client documentation.

=head2 Retrieval functions

    $release     = $autoupdate->GetRelease();
    $release     = $autoupdate->GetRelease("beta");
    $release     = $autoupdate->GetRelease("dev");

    @releaseTree = $autoupdate->GetReleaseTree();
    @releaseTree = $autoupdate->GetReleaseTree("beta");
    @releaseTree = $autoupdate->GetReleaseTree("dev");

=head2 Creation functions

    $release = $autoupdate->AddRelease();
    $release = $autoupdate->AddRelease(type=>"beta",
                                       version=>"1.0b",
                                       desc=>"Beta...",
                                       url=>"http://xxx.yyy/zzz.tar.gz",
                                       priority=>"optional");

=head1 METHODS

=head2 Retrieval functions

  GetRelease(string) - returns a Net::Jabber::Query::AutoUpdate::Release
                       object that contains the data for that release.
                       The string determines which release is returned:
 
                         release - returns the latest stable release 
                         beta    - returns the latest beta release
                         dev     - returns the latest dev release in CVS
 
                       If string is blank or undefined, then the "release"
                       version is returned.

  GetReleaseTree(string) - returns an XML::Parser tree that contains the
                           release specified in string.  If string is
                           empty or undefined then it defaults to 
                           "release".

=head2 Creation functions

  AddRelease(type=>string, - created a new Release object and populates
             hash)           it with the hash.  The has is passed to the
                             SetRelease function, check the module for
                             valid settings.  The valid setting for type
                             are:

                               release - to indicate the latest stable
                                         release
                               beta    - to indicate the latest beta
                                         release
                               dev     - to indicate the latest dev release 
                                         in CVS

                             If type is blank or undefined, then "release"
                             is assumed.

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

use Net::Jabber::Query::AutoUpdate::Release;
($Net::Jabber::Query::AutoUpdate::Release::VERSION < $VERSION) &&
  die("Net::Jabber::Query::AutoUpdate::Release $VERSION required--this is only version $Net::Jabber::Query::AutoUpdate::Release::VERSION");

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
# GetReleases - returns an array of Net::Jabber::Query::AutoUpdate::Release 
#               objects
#
##############################################################################
sub GetReleases {
  shift;
  my $self = shift;
  my ($type) = @_;
  $type = "release" if (!defined($type) || 
			(($type ne "dev") && ($type ne "beta")));
  
  if (!(exists($self->{uc($type)}))) {
    my @releaseTrees = $self->GetReleaseTrees($type);
    if ("@releaseTrees" ne "") {
      my $releaseTree;
      foreach $releaseTree (@releaseTrees) {
	my $release = new Net::Jabber::Query::AutoUpdate::Release(@{$releaseTree});
	splice(@{$self->{uc($type)}},$#{$self->{uc($type)}}+1,0,$release);
	$self->{RELEASES} = 1;
      }
    }
  }

  return (exists($self->{uc($type)}) ? @{$self->{uc($type)}} : ());
}


##############################################################################
#
# GetReleaseTrees - returns an XML::Parser tree for the specified release
#
##############################################################################
sub GetReleaseTrees {
  shift;
  my $self = shift;
  my ($type) = @_;
  $type = "release" if (!defined($type) || 
			(($type ne "dev") && ($type ne "beta")));
  
  return &Net::Jabber::GetXMLData("tree array",$self->{QUERY},"$type");
}


##############################################################################
#
# AddRelease - creates a new Net::Jabber::Query::AutoUpdate::Release object 
#              from the hash passed to the function if any.  Then it returns 
#              a pointer to that object so you can modify it.
#
##############################################################################
sub AddRelease {
  shift;
  my $self = shift;
  my %args;
  while( $#_ > 0 ) { $args{ lc(pop(@_)) } = pop(@_); }
  my $type = delete($args{type});
  $type = "release" if (!defined($type) || 
			(($type ne "dev") && ($type ne "beta")));

  my $release = new Net::Jabber::Query::AutoUpdate::Release($type);
  $release->SetRelease(%args);

  splice(@{$self->{uc($type)}},$#{$self->{uc($type)}}+1,0,$release);
  $self->{RELEASES} = 1;

  return $release;
}


##############################################################################
#
# MergeReleases - takes the Net::Jabber::Query::AutoUpdate::Release objects
#                 and pulls the data out and merges it into the <query/>.
#                 This is a private helper function.  It should be used any
#                 time you need to access the full <query/> so that the
#                 releases are included.  (ie. GetXML, GetTree, debug, etc...)
#
##############################################################################
sub MergeReleases {
  shift;
  my $self = shift;
  my $count = 1;

  my $release;
  foreach $release ($self->GetReleases("release")) {
    if (ref($release) eq "Net::Jabber::Query::AutoUpdate::Release") {
      $self->{QUERY}->[1]->[$count++] = "release";
      $self->{QUERY}->[1]->[$count++] = ($release->GetTree())[1];
    }
  }    

  my $beta;
  foreach $beta ($self->GetReleases("beta")) {
    if (ref($beta) eq "Net::Jabber::Query::AutoUpdate::Release") {
      $self->{QUERY}->[1]->[$count++] = "beta";
      $self->{QUERY}->[1]->[$count++] = ($beta->GetTree())[1];
    }	    
  }

  my $dev;
  foreach $dev ($self->GetReleases("dev")) {
    if (ref($dev) eq "Net::Jabber::Query::AutoUpdate::Release") {
      $self->{QUERY}->[1]->[$count++] = "dev";
      $self->{QUERY}->[1]->[$count++] = ($dev->GetTree())[1];
    }	    
  }
}


1;
