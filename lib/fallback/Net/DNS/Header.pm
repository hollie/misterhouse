package Net::DNS::Header;

use strict;
use vars qw($VERSION $AUTOLOAD);

use Net::DNS;

# $Id$
$VERSION = $Net::DNS::VERSION;

=head1 NAME

Net::DNS::Header - DNS packet header class

=head1 SYNOPSIS

C<use Net::DNS::Header;>

=head1 DESCRIPTION

A C<Net::DNS::Header> object represents the header portion of a DNS
packet.

=head1 METHODS

=head2 new

    $header = new Net::DNS::Header;
    $header = new Net::DNS::Header(\$data);

Without an argument, C<new> creates a header object appropriate
for making a DNS query.

If C<new> is passed a reference to a scalar containing DNS packet
data, it creates a header object from that data.

Returns B<undef> if unable to create a header object (e.g., if
the data is incomplete).

=cut

sub new {
	my $class = shift;
	my %self;

	if (@_) {
		my $data = shift;

		if (length($$data) < &Net::DNS::HFIXEDSZ) {
			return undef;
		}

		my @a = unpack("n C2 n4", $$data);
		%self = (
			"id"		=> $a[0],
			"qr"		=> ($a[1] >> 7) & 0x1,
			"opcode"	=> ($a[1] >> 3) & 0xf,
			"aa"		=> ($a[1] >> 2) & 0x1,
			"tc"		=> ($a[1] >> 1) & 0x1,
			"rd"		=> $a[1] & 0x1,
			"ra"		=> ($a[2] >> 7) & 0x1,
			"rcode"		=> $a[2] & 0xf,
			"qdcount"	=> $a[3],
			"ancount"	=> $a[4],
			"nscount"	=> $a[5],
			"arcount"	=> $a[6],
		);
	}
	else {
		%self = (
			"id"		=> Net::DNS::Resolver::nextid(),
			"qr"		=> 0,
			"opcode"	=> 0,
			"aa"		=> 0,
			"tc"		=> 0,
			"rd"		=> 1,
			"ra"		=> 0,
			"rcode"		=> 0,
			"qdcount"	=> 1,
			"ancount"	=> 0,
			"nscount"	=> 0,
			"arcount"	=> 0,
		);
	}

	$self{"opcode"} = $Net::DNS::opcodesbyval{$self{"opcode"}}
		if exists $Net::DNS::opcodesbyval{$self{"opcode"}};
	$self{"rcode"} = $Net::DNS::rcodesbyval{$self{"rcode"}}
		if exists $Net::DNS::rcodesbyval{$self{"rcode"}};

	return bless \%self, $class;
}

#
# Some people have reported that Net::DNS dies because AUTOLOAD picks up
# calls to DESTROY.
#
sub DESTROY {}

=head2 print

    $header->print;

Dumps the header data to the standard output.

=cut

sub print {
	my $self = shift;
	print $self->string;
}

=head2 string

    print $header->string;

Returns a string representation of the header object.

=cut

sub string {
	my $self = shift;
	my $retval = "";

	$retval .= ";; id = $self->{id}\n";

	if ($self->{"opcode"} eq "UPDATE") {
		$retval .= ";; qr = $self->{qr}    "      .
		           "opcode = $self->{opcode}    " .
		           "rcode = $self->{rcode}\n";

		$retval .= ";; zocount = $self->{qdcount}  " .
		           "prcount = $self->{ancount}  "    .
		           "upcount = $self->{nscount}  "    .
		           "adcount = $self->{arcount}\n";
	}
	else {
		$retval .= ";; qr = $self->{qr}    "      .
		           "opcode = $self->{opcode}    " .
		           "aa = $self->{aa}    "         .
		           "tc = $self->{tc}    "         .
		           "rd = $self->{rd}\n";

		$retval .= ";; ra = $self->{ra}    " .
		           "rcode  = $self->{rcode}\n";

		$retval .= ";; qdcount = $self->{qdcount}  " .
		           "ancount = $self->{ancount}  "    .
		           "nscount = $self->{nscount}  "    .
		           "arcount = $self->{arcount}\n";
	}
}

=head2 id

    print "query id = ", $header->id, "\n";
    $header->id(1234);

Gets or sets the query identification number.

=head2 qr

    print "query response flag = ", $header->qr, "\n";
    $header->qr(0);

Gets or sets the query response flag.

=head2 opcode

    print "query opcode = ", $header->opcode, "\n";
    $header->opcode("UPDATE");

Gets or sets the query opcode (the purpose of the query).

=head2 aa

    print "answer is ", $header->aa ? "" : "non-", "authoritative\n";
    $header->aa(0);

Gets or sets the authoritative answer flag.

=head2 tc

    print "packet is ", $header->tc ? "" : "not ", "truncated\n";
    $header->tc(0);

Gets or sets the truncated packet flag.

=head2 rd

    print "recursion was ", $header->rd ? "" : "not ", "desired\n";
    $header->rd(0);

Gets or sets the recursion desired flag.

=head2 ra

    print "recursion is ", $header->ra ? "" : "not ", "available\n";
    $header->ra(0);

Gets or sets the recursion available flag.

=head2 rcode

    print "query response code = ", $header->rcode, "\n";
    $header->rcode("SERVFAIL");

Gets or sets the query response code (the status of the query).

=head2 qdcount, zocount

    print "# of question records: ", $header->qdcount, "\n";
    $header->qdcount(2);

Gets or sets the number of records in the question section of the packet.
In dynamic update packets, this field is known as C<zocount> and refers
to the number of RRs in the zone section.

=head2 ancount, prcount

    print "# of answer records: ", $header->ancount, "\n";
    $header->ancount(5);

Gets or sets the number of records in the answer section of the packet.
In dynamic update packets, this field is known as C<prcount> and refers
to the number of RRs in the prerequisite section.

=head2 nscount, upcount

    print "# of authority records: ", $header->nscount, "\n";
    $header->nscount(2);

Gets or sets the number of records in the authority section of the packet.
In dynamic update packets, this field is known as C<upcount> and refers
to the number of RRs in the update section.

=head2 arcount, adcount

    print "# of additional records: ", $header->arcount, "\n";
    $header->arcount(3);

Gets or sets the number of records in the additional section of the packet.
In dynamic update packets, this field is known as C<adcount>.

=cut

sub AUTOLOAD {
	my $self = shift;
	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	Carp::confess "$name: no such method"
		unless exists $self->{$name};

	$self->{$name} = shift if @_;
	return $self->{$name};
}

sub zocount { my $self = shift; $self->qdcount(@_); }
sub prcount { my $self = shift; $self->ancount(@_); }
sub upcount { my $self = shift; $self->nscount(@_); }
sub adcount { my $self = shift; $self->arcount(@_); }

=head2 data

    $hdata = $header->data;

Returns the header data in binary format, appropriate for use in a
DNS query packet.

=cut

sub data {
	my $self = shift;

	my $opcode = $Net::DNS::opcodesbyname{$self->{"opcode"}};
	my $rcode  = $Net::DNS::rcodesbyname{$self->{"rcode"}};

	my $byte2 = ($self->{"qr"} << 7)
	          | ($opcode << 3)
	          | ($self->{"aa"} << 2)
	          | ($self->{"tc"} << 1)
	          | $self->{"rd"};

	my $byte3 = ($self->{"ra"} << 7)
	          | $rcode;

	return pack("n C2 n4", $self->{"id"},
			       $byte2,
			       $byte3,
			       $self->{"qdcount"},
			       $self->{"ancount"},
			       $self->{"nscount"},
			       $self->{"arcount"});
}

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>,
L<Net::DNS::Update>, L<Net::DNS::Question>, L<Net::DNS::RR>,
RFC 1035 Section 4.1.1

=cut

1;
