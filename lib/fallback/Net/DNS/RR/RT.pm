package Net::DNS::RR::RT;

# $Id$

use strict;
use vars qw(@ISA);

use Net::DNS;
use Net::DNS::Packet;

@ISA = qw(Net::DNS::RR);

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		my ($preference) = unpack("\@$offset n", $$data);
		$offset += &Net::DNS::INT16SZ;
		my ($intermediate) = Net::DNS::Packet::dn_expand($data, $offset);
		$self->{"preference"} = $preference;
		$self->{"intermediate"} = $intermediate;
	}

	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string && ($string =~ /^(\d+)\s+(\S+)$/)) {
		$self->{"preference"}   = $1;
		$self->{"intermediate"} = $2;
		$self->{"intermediate"} =~ s/\.+$//;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;

	return exists $self->{"preference"}
	       ? "$self->{preference} $self->{intermediate}."
	       : "; no data";
}

sub rr_rdata {
	my ($self, $packet, $offset) = @_;
	my $rdata = "";

	if (exists $self->{"preference"}) {
		$rdata .= pack("n", $self->{"preference"});
		$rdata .= $packet->dn_comp($self->{"intermediate"},
					   $offset + length $rdata);
	}

	return $rdata;
}

1;
__END__

=head1 NAME

Net::DNS::RR::RT - DNS RT resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS Route Through (RT) resource records.

=head1 METHODS

=head2 preference

    print "preference = ", $rr->preference, "\n";

Returns the preference for this route.

=head2 intermediate

    print "intermediate = ", $rr->intermediate, "\n";

Returns the domain name of the intermediate host.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 1183 Section 3.3

=cut
