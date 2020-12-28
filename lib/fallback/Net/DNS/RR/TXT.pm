package Net::DNS::RR::TXT;

# $Id$

use strict;
use vars qw(@ISA);

use Net::DNS::Packet;

@ISA = qw(Net::DNS::RR);

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		my ($len) = unpack("\@$offset C", $$data);
		++$offset;
		my $txtdata = substr($$data, $offset, $len);
		$offset += $len;

		$self->{"txtdata"} = $txtdata;
	}

	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string && $string =~ /^\s*["']?(.*?)["']?\s*$/) {
		$self->{"txtdata"} = $1;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;

	return exists $self->{"txtdata"}
	       ? qq("$self->{txtdata}")
	       : "; no data";
}

sub rr_rdata {
	my $self = shift;
	my $rdata = "";

	if (exists $self->{"txtdata"}) {
		$rdata .= pack("C", length $self->{"txtdata"});
		$rdata .= $self->{"txtdata"};
	}

	return $rdata;
}

1;
__END__

=head1 NAME

Net::DNS::RR::TXT - DNS TXT resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS Text (TXT) resource records.

=head1 METHODS

=head2 txtdata

    print "txtdata = ", $rr->txtdata, "\n";

Returns the descriptive text.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 1035 Section 3.3.14

=cut
