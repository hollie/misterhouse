package Net::DNS::RR::MG;

# $Id$

use strict;
use vars qw(@ISA);

use Net::DNS::Packet;

@ISA = qw(Net::DNS::RR);

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		my ($mgmname) = Net::DNS::Packet::dn_expand($data, $offset);
		$self->{"mgmname"} = $mgmname;
	}
	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string) {
		$string =~ s/\.+$//;
		$self->{"mgmname"} = $string;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;

	return exists $self->{"mgmname"}
	       ? "$self->{mgmname}."
	       : "; no data";
}

sub rr_rdata {
	my ($self, $packet, $offset) = @_;
	my $rdata = "";

	if (exists $self->{"mgmname"}) {
		$rdata .= $packet->dn_comp($self->{"mgmname"}, $offset);
	}

	return $rdata;
}

1;
__END__

=head1 NAME

Net::DNS::RR::MG - DNS MG resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS Mail Group (MG) resource records.

=head1 METHODS

=head2 mgmname

    print "mgmname = ", $rr->mgmname, "\n";

Returns the RR's mailbox field.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 1035 Section 3.3.6

=cut
