package Net::DNS::RR::PX;

# $Id$

use strict;
use vars qw(@ISA);

use Net::DNS;
use Net::DNS::Packet;

@ISA = qw(Net::DNS::RR);

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		my ($preference, $map822, $mapx400);

		($preference) = unpack("\@$offset n", $$data);
		$offset += &Net::DNS::INT16SZ;

		($map822,  $offset) = Net::DNS::Packet::dn_expand($data, $offset);
		($mapx400, $offset) = Net::DNS::Packet::dn_expand($data, $offset);

		$self->{"preference"} = $preference;
		$self->{"map822"}     = $map822;
		$self->{"mapx400"}    = $mapx400;
	}

	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string && ($string =~ /^(\d+)\s+(\S+)\s+(\S+)$/)) {
		$self->{"preference"} = $1;
		$self->{"map822"}     = $2;
		$self->{"mapx400"}    = $3;
		$self->{"map822"}     =~ s/\.+$//;;
		$self->{"mapx400"}    =~ s/\.+$//;;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;

	return exists $self->{"preference"}
	       ? "$self->{preference} $self->{map822}. $self->{mapx400}."
	       : "; no data";
}

sub rr_rdata {
	my ($self, $packet, $offset) = @_;
	my $rdata = "";

	if (exists $self->{"preference"}) {
		$rdata .= pack("n", $self->{"preference"});

		$rdata .= $packet->dn_comp($self->{"map822"},
					    $offset + length $rdata);

		$rdata .= $packet->dn_comp($self->{"mapx400"},
					    $offset + length $rdata);
	}

	return $rdata;
}

1;
__END__

=head1 NAME

Net::DNS::RR::PX - DNS PX resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS X.400 Mail Mapping Information (PX) resource records.

=head1 METHODS

=head2 preference

    print "preference = ", $rr->preference, "\n";

Returns the preference given to this RR.

=head2 map822

    print "map822 = ", $rr->map822, "\n";

Returns the RFC822 part of the RFC1327 mapping information.

=head2 mapx400

    print "mapx400 = ", $rr->mapx400, "\n";

Returns the X.400 part of the RFC1327 mapping information.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 1664 Section 4, RFC 1327

=cut
