package Net::DNS::RR::NS;

# $Id$

use strict;
use vars qw(@ISA);

use Net::DNS::Packet;

@ISA = qw(Net::DNS::RR);

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		my($nsdname) = Net::DNS::Packet::dn_expand($data, $offset);
		$self->{"nsdname"} = $nsdname;
	}

	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string) {
		$string =~ s/\.+$//;
		$self->{"nsdname"} = $string;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;

	return exists $self->{"nsdname"}
	       ? "$self->{nsdname}."
	       : "; no data";
}

sub rr_rdata {
	my ($self, $packet, $offset) = @_;
	my $rdata = "";

	if (exists $self->{"nsdname"}) {
		$rdata .= $packet->dn_comp($self->{"nsdname"}, $offset);
	}

	return $rdata;
}

1;
__END__

=head1 NAME

Net::DNS::RR::NS - DNS NS resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS Name Server (NS) resource records.

=head1 METHODS

=head2 nsdname

    print "nsdname = ", $rr->nsdname, "\n";

Returns the domain name of the nameserver.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 1035 Section 3.3.11

=cut
