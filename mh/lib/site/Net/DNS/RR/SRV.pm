package Net::DNS::RR::SRV;

# $Id$

use strict;
use vars qw(@ISA);

use Net::DNS;
use Net::DNS::Packet;

@ISA = qw(Net::DNS::RR);

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		my ($priority, $weight, $port) = unpack("\@$offset n3", $$data);
		$offset += 3 * &Net::DNS::INT16SZ;
		my($target) = Net::DNS::Packet::dn_expand($data, $offset);

		$self->{"priority"} = $priority;
		$self->{"weight"}   = $weight;
		$self->{"port"}     = $port;
		$self->{"target"}   = $target;
	}

	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string && ($string =~ /^(\d+)\s+(\d+)\s+(\d+)\s+(\S+)$/)) {
		$self->{"priority"} = $1;
		$self->{"weight"}   = $2;
		$self->{"port"}     = $3;
		$self->{"target"}   = $4;
		$self->{"target"}   =~ s/\.+$//;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;
	my $rdatastr;

	if (exists $self->{"priority"}) {
		$rdatastr = "$self->{priority} $self->{weight} " .
			    "$self->{port} $self->{target}.";
	}
	else {
		$rdatastr = "; no data";
	}

	return $rdatastr;
}

sub rr_rdata {
	my ($self, $packet, $offset) = @_;
	my $rdata = "";

	if (exists $self->{"priority"}) {
		$rdata .= pack("n3", $self->{"priority"}, $self->{"weight"},
				     $self->{"port"});
		$rdata .= $packet->dn_comp($self->{"target"},
					   $offset + length $rdata);
	}

	return $rdata;
}

1;
__END__

=head1 NAME

Net::DNS::RR::SRV - DNS SRV resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS Service (SRV) resource records.

=head1 METHODS

=head2 priority

    print "priority = ", $rr->priority, "\n";

Returns the priority for this target host.

=head2 weight

    print "weight = ", $rr->weight, "\n";

Returns the weight for this target host.

=head2 port

    print "port = ", $rr->port, "\n";

Returns the port on this target host for the service.

=head2 target

    print "target = ", $rr->target, "\n";

Returns the target host.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 2052

=cut
