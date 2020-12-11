package Net::DNS::RR::NAPTR;

# $Id$

use strict;
use vars qw(@ISA);

use Net::DNS;
use Net::DNS::Packet;

@ISA = qw(Net::DNS::RR);

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		my ($order) = unpack("\@$offset n", $$data);
		$offset += &Net::DNS::INT16SZ;
		my ($preference) = unpack("\@$offset n", $$data);
		$offset += &Net::DNS::INT16SZ;
		my ($len) = unpack("\@$offset C", $$data);
		++$offset;
		my ($flags) = unpack("\@$offset a$len", $$data);
		$offset += $len;
		$len = unpack("\@$offset C", $$data);
		++$offset;
		my ($service) = unpack("\@$offset a$len", $$data);
		$offset += $len;
		$len = unpack("\@$offset C", $$data);
		++$offset;
		my ($regexp) = unpack("\@$offset a$len", $$data);
		$offset += $len;
		my($replacement) = Net::DNS::Packet::dn_expand($data, $offset);
  
		$self->{"order"}       = $order;
		$self->{"preference"}  = $preference;
		$self->{"flags"}       = $flags;
		$self->{"service"}     = $service;
		$self->{"regexp"}      = $regexp;
		$self->{"replacement"} = $replacement;
	}
  
	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string && $string =~ /^      (\d+)      \s+
				          (\d+)      \s+
				     ['"] (.*?) ['"] \s+
				     ['"] (.*?) ['"] \s+
				     ['"] (.*?) ['"] \s+
				          (\S+) $/x) {

		$self->{"order"}       = $1;
		$self->{"preference"}  = $2;
		$self->{"flags"}       = $3;
		$self->{"service"}     = $4;
		$self->{"regexp"}      = $5;
		$self->{"replacement"} = $6;
		$self->{"replacement"} =~ s/\.+$//;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;
	my $rdatastr;

	if (exists $self->{"order"}) {
		$rdatastr = $self->{"order"}       . ' '   .
		            $self->{"preference"}  . ' "'  .
		            $self->{"flags"}       . '" "' .
		            $self->{"service"}     . '" "' .
		            $self->{"regexp"}      . '" '  .
		            $self->{"replacement"} . '.';
	}
	else {
		$rdatastr = "; no data";
	}

	return $rdatastr;
}

sub rr_rdata {
	my ($self, $packet, $offset) = @_;
	my $rdata = "";

	if (exists $self->{"order"}) {

		$rdata .= pack("n2", $self->{"order"}, $self->{"preference"});

		$rdata .= pack("C", length $self->{"flags"});
		$rdata .= $self->{"flags"};

		$rdata .= pack("C", length $self->{"service"});
		$rdata .= $self->{"service"};

		$rdata .= pack("C", length $self->{"regexp"});
		$rdata .= $self->{"regexp"};

		$rdata .= $packet->dn_comp($self->{"replacement"},
					   $offset + length $rdata);
	}

	return $rdata;
}

1;
__END__

=head1 NAME

Net::DNS::RR::NAPTR - DNS NAPTR resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS Naming Authority Pointer (NAPTR) resource records.

=head1 METHODS

=head2 order

    print "order = ", $rr->order, "\n";

Returns the order field.

=head2 preference

    print "preference = ", $rr->preference, "\n";

Returns the preference field.

=head2 flags

    print "flags = ", $rr->flags, "\n";

Returns the flags field.

=head2 service

    print "service = ", $rr->service, "\n";

Returns the service field.

=head2 regexp

    print "regexp = ", $rr->regexp, "\n";

Returns the regexp field.

=head2 replacement

    print "replacement = ", $rr->replacement, "\n";

Returns the replacement field.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

B<Net::DNS::RR::NAPTR> is based on code contributed by Ryan Moats.

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 2168

=cut
