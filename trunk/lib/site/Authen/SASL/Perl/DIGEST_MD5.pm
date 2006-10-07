# Copyright (c) 2003 Graham Barr, Djamel Boudjerda, Paul Connolly, Julian Onions and Nexor.
# All rights reserved. This program is free software; you can redistribute 
# it and/or modify it under the same terms as Perl itself.

# See http://www.ietf.org/rfc/rfc2831.txt for details

package Authen::SASL::Perl::DIGEST_MD5;

use strict;
use vars qw($VERSION @ISA $CNONCE);
use Digest::MD5 qw(md5_hex md5);

$VERSION = "1.00";
@ISA = qw(Authen::SASL::Perl);

my %secflags = (
  noplaintext => 1,
  noanonymous => 1,
);

# some have to be quoted - some don't - sigh!
my %qdval; @qdval{qw(username realm nonce cnonce digest-uri qop)} = ();

sub _secflags {
  shift;
  scalar grep { $secflags{$_} } @_;
}

sub mechanism { 'DIGEST-MD5' }

# no initial value passed to the server
sub client_start {
  '';
}

sub client_step    # $self, $server_sasl_credentials
{
  my ($self, $challenge) = @_;
  $self->{server_params} = \my %sparams;

  # Parse response parameters
  while($challenge =~ s/^(?:\s*,)?\s*(\w+)=("([^\\"]+|\\.)*"|[^,]+)\s*//) {
    my ($k, $v) = ($1,$2);
    if ($v =~ /^"(.*)"$/s) {
      ($v = $1) =~ s/\\//g;
    }
    $sparams{$k} = $v;
  }
  die $challenge if length $challenge;

  my %response = (
    nonce        => $sparams{'nonce'},
    username     => $self->_call('user'),
    realm        => $sparams{'realm'},
    nonce        => $sparams{'nonce'},
    cnonce       => md5_hex($CNONCE || join (":", $$, time, rand)),
    'digest-uri' => $self->service . '/' . $self->host,
    qop          => $sparams{'qop'},
    nc           => sprintf("%08d",     ++$self->{nonce}{$sparams{'nonce'}}),
    charset      => $sparams{'charset'},
  );

  my $serv_name = $self->_call('serv');
  if (defined $serv_name) {
    $response{'digest_uri'} .= '/' . $serv_name;
  }

  my $password = $self->_call('pass');

  # Generate the response value

  my $A1 = join (":", 
    md5(join (":", @response{qw(username realm)}, $password)),
    @response{qw(nonce cnonce)}
  );

  my $A2 = "AUTHENTICATE:" . $response{'digest-uri'};

  $A2 .= ":00000000000000000000000000000000"
    if $response{'qop'} and $response{'qop'} =~ /^auth-(conf|int)$/;

  $response{'response'} = md5_hex(
    join (":", md5_hex($A1), @response{qw(nonce nc cnonce qop)}, md5_hex($A2))
  );

  join (",", map { _qdval($_, $response{$_}) } sort keys %response);
}

sub _qdval {
  my ($k, $v) = @_;

  if (!defined $v) {
    return;
  }
  elsif (exists $qdval{$k}) {
    $v =~ s/([\\"])/\\$1/g;
    return qq{$k="$v"};
  }

  return "$k=$v";
}

1;

__END__

=head1 NAME

Authen::SASL::Perl::DIGEST_MD5 - Digest MD5 Authentication class

=head1 SYNOPSIS

  use Authen::SASL;

  $sasl = Authen::SASL->new(
    mechanism => 'DIGEST-MD5',
    callback  => {
      user => $user, 
      pass => $pass,
      serv => $serv
    },
  );

=head1 DESCRIPTION

This method implements the DIGEST MD5 SASL algorithm, as described in RFC-2831.

=head2 CALLBACK

The callbacks used are:

=over 4

=item user

The username to be used in the response

=item pass

The password to be used in the response

=item serv

The service name when authenticating to a replicated service

=back

=head1 SEE ALSO

L<Authen::SASL>

=head1 AUTHORS
 
Graham Barr, Djamel Boudjerda (NEXOR) Paul Connolly, Julian Onions (NEXOR)

Please report any bugs, or post any suggestions, to the perl-ldap mailing list
<perl-ldap-dev@lists.sourceforge.net>

=head1 COPYRIGHT 

Copyright (c) 2003 Graham Barr, Djamel Boudjerda, Paul Connolly, Julian Onions and Nexor.
All rights reserved. This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.

=cut
