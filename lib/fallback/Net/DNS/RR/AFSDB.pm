package Net::DNS::RR::AFSDB;

# $Id$

use strict;
use vars qw(@ISA);

use Net::DNS;
use Net::DNS::Packet;

@ISA = qw(Net::DNS::RR);

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		my ($subtype) = unpack("\@$offset n", $$data);
		$offset += &Net::DNS::INT16SZ;
		my($hostname) = Net::DNS::Packet::dn_expand($data, $offset);
		$self->{"subtype"} = $subtype;
		$self->{"hostname"} = $hostname;
	}

	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string && ($string =~ /^(\d+)\s+(\S+)$/)) {
		$self->{"subtype"}  = $1;
		$self->{"hostname"} = $2;
		$self->{"hostname"} =~ s/\.+$//;;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;

	return exists $self->{"subtype"}
	       ? "$self->{subtype} $self->{hostname}."
	       : "; no data";
}

sub rr_rdata {
	my ($self, $packet, $offset) = @_;
	my $rdata = "";

	if (exists $self->{"subtype"}) {
		$rdata .= pack("n", $self->{"subtype"});
		$rdata .= $packet->dn_comp($self->{"hostname"},
					   $offset + length $rdata);
	}

	return $rdata;
}

1;
__END__

=head1 NAME

Net::DNS::RR::AFSDB - DNS AFSDB resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS AFS Data Base (AFSDB) resource records.

=head1 METHODS

=head2 subtype

    print "subtype = ", $rr->subtype, "\n";

Returns the RR's subtype field.  Use of the subtype field is documented
in RFC 1183.

=head2 hostname

    print "hostname = ", $rr->hostname, "\n";

Returns the RR's hostname field.  See RFC 1183.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 1183 Section 1

=cut
