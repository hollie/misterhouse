package Net::Jabber::Key;

=head1 NAME

Net::Jabber::Key - Jabber Key Library

=head1 SYNOPSIS

  Net::Jabber::Key is a module that provides a developer easy access
  to generating, caching, and comparing keys.

=head1 DESCRIPTION

  Key.pm is a helper module for the Net::Jabber::Transport.  When the
  Transport talks to a Client it sends a key and expects to get that
  key back from the Client.  This module provides an API to generate,
  cache, and then compare the key send from the Client.

=head2 Basic Functions

    $Key = new Net::Jabber::Key();

    $key = $Key->Generate();

    $key = $Key->Create("bob\@jabber.org");

    $test = $Key->Compare("bob\@jabber.org","some key");

=head1 METHODS

=head2 Basic Functions

    new(debug=>string,       - creates the Key object.  debug should
        debugfh=>FileHandle,   be set to the path for the debug
        debuglevel=>integer)   log to be written.  If set to "stdout" 
                               then the debug will go there.  Also, you
                               can specify a filehandle that already
                               exists and use that.  debuglevel controls
                               the amount of debug.  0 is none, 1 is
                               normal, 2 is all.

    Generate() - returns a key in Digest SHA1 form based on the current
                 time and the PID.

    Create(cacheString) - generates a key and caches it with the key 
                          of cacheString.  Create returns the key.

    Compare(cacheString, - compares the key stored in the cache under
            keyString)     cacheString with the keyString.  Returns 1
                           if they match, and 0 otherwise.

=head1 AUTHOR

By Ryan Eatmon in May of 2000 for http://jabber.org.

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use FileHandle;
use vars qw($VERSION);

$VERSION = "1.0013";

sub new {
  srand( time() ^ ($$ + ($$ << 15)));

  my $proto = shift;
  my $self = { };

  $self->{DEBUG} = new Net::Jabber::Debug(usedefault=>1,
					  header=>"NJ::Key");

  $self->{VERSION} = $VERSION;
  
  $self->{CACHE} = {};

  if (eval "require Digest::SHA1") {
    $self->{DIGEST} = 1;
    Digest::SHA1->import(qw(sha1 sha1_hex sha1_base64));
  } else {
    print "ERROR:  You cannot use Key.pm unless you have Digest::SHA1 installed.\n";
    exit(0);
  }

  bless($self, $proto);
  return $self;
}


###########################################################################
#
# Generate - returns a random string based on the PID and time and a 
#            random number.  Then it creates an SHA1 Digest of that 
#            string and returns it.
#
###########################################################################
sub Generate {
  my $self = shift;

  my $string = $$.time.rand(1000000);
  $string = Digest::SHA1::sha1_hex($string);
  $self->{DEBUG}->Log1("Generate: key($string)");
  return $string;
}


##############################################################################
#
# Create - Creates a key and caches the id for comparison later.
#
##############################################################################
sub Create {
  my $self = shift;
  my ($cacheString) = @_;

  $self->{DEBUG}->Log1("Create: cacheString($cacheString)");
  my $key = $self->Generate();
  $self->{DEBUG}->Log1("Create: key($key)");
  $self->{CACHE}->{$cacheString} = $key;
  return $key;
}


##############################################################################
#
# Compare - Compares the key with the key in the cache.
#
##############################################################################
sub Compare {
  my $self = shift;
  my ($cacheString,$key) = @_;

  $self->{DEBUG}->Log1("Compare: cacheString($cacheString) key($key)");
  my $cacheKey = delete($self->{CACHE}->{$cacheString});
  $self->{DEBUG}->Log1("Compare: cacheKey($cacheKey)");
  return ($key eq $cacheKey);
}



1;
