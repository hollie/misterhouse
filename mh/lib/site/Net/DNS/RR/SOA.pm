package Net::DNS::RR::SOA;

# $Id$

use strict;
use vars qw(@ISA);

use Net::DNS::Packet;

@ISA = qw(Net::DNS::RR);

sub new {
	my ($class, $self, $data, $offset) = @_;

	if ($self->{"rdlength"} > 0) {
		my ($mname, $rname);
		($mname, $offset) = Net::DNS::Packet::dn_expand($data, $offset);
		($rname, $offset) = Net::DNS::Packet::dn_expand($data, $offset);

		my ($serial, $refresh, $retry, $expire, $minimum)
			= unpack("\@$offset N5", $$data);
	
		$self->{"mname"}   = $mname;
		$self->{"rname"}   = $rname;
		$self->{"serial"}  = $serial;
		$self->{"refresh"} = $refresh;
		$self->{"retry"}   = $retry;
		$self->{"expire"}  = $expire;
		$self->{"minimum"} = $minimum;
	}

	return bless $self, $class;
}

sub new_from_string {
	my ($class, $self, $string) = @_;

	if ($string) {
		$string =~ tr/()//d;
		$string =~ s/;.*$//mg;

		my ($mname, $rname, $serial,
		    $refresh, $retry, $expire, $minimum) = $string =~ /(\S+)/g;

		$mname =~ s/\.+$//;
		$rname =~ s/\.+$//;

		$self->{"mname"}   = $mname;
		$self->{"rname"}   = $rname;
		$self->{"serial"}  = $serial;
		$self->{"refresh"} = $refresh;
		$self->{"retry"}   = $retry;
		$self->{"expire"}  = $expire;
		$self->{"minimum"} = $minimum;
	}

	return bless $self, $class;
}

sub rdatastr {
	my $self = shift;
	my $rdatastr;

	if (exists $self->{"mname"}) {
		$rdatastr  = "$self->{mname}. $self->{rname}. (\n";
		$rdatastr .= "\t" x 5 . "$self->{serial}\t; Serial\n";
		$rdatastr .= "\t" x 5 . "$self->{refresh}\t; Refresh\n";
		$rdatastr .= "\t" x 5 . "$self->{retry}\t; Retry\n";
		$rdatastr .= "\t" x 5 . "$self->{expire}\t; Expire\n";
		$rdatastr .= "\t" x 5 . "$self->{minimum} )\t; Minimum TTL";
	}
	else {
		$rdatastr = "; no data";
	}

	return $rdatastr;
}

sub rr_rdata {
	my ($self, $packet, $offset) = @_;
	my $rdata = "";

	# Assume that if one field exists, they all exist.  Script will
	# print a warning otherwise.

	if (exists $self->{"mname"}) {
		$rdata .= $packet->dn_comp($self->{"mname"}, $offset);

		$rdata .= $packet->dn_comp($self->{"rname"},
					   $offset + length $rdata);

		$rdata .= pack("N5", $self->{"serial"},
				     $self->{"refresh"},
				     $self->{"retry"},
				     $self->{"expire"},
				     $self->{"minimum"});
	}

	return $rdata;
}

1;
__END__

=head1 NAME

Net::DNS::RR::SOA - DNS SOA resource record

=head1 SYNOPSIS

C<use Net::DNS::RR>;

=head1 DESCRIPTION

Class for DNS Start of Authority (SOA) resource records.

=head1 METHODS

=head2 mname

    print "mname = ", $rr->mname, "\n";

Returns the domain name of the original or primary nameserver for
this zone.

=head2 rname

    print "rname = ", $rr->rname, "\n";

Returns a domain name that specifies the mailbox for the person
responsible for this zone.

=head2 serial

    print "serial = ", $rr->serial, "\n";

Returns the zone's serial number.

=head2 refresh

    print "refresh = ", $rr->refresh, "\n";

Returns the zone's refresh interval.

=head2 retry

    print "retry = ", $rr->retry, "\n";

Returns the zone's retry interval.

=head2 expire

    print "expire = ", $rr->expire, "\n";

Returns the zone's expire interval.

=head2 minimum

    print "minimum = ", $rr->minimum, "\n";

Returns the minimum (default) TTL for records in this zone.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 1035 Section 3.3.13

=cut
