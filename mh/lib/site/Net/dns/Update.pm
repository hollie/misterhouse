package Net::DNS::Update;

use strict;
use vars qw($VERSION);

use Net::DNS;
# use Net::DNS::Packet;

# $Id$
$VERSION = $Net::DNS::VERSION;

=head1 NAME

Net::DNS::Update - Create a DNS update packet

=head1 SYNOPSIS

C<use Net::DNS::Update;>

=head1 DESCRIPTION

C<Net::DNS::Update> is a front-end for creating C<Net::DNS::Packet>
objects to be used for making DNS dynamic updates.  Programmers
should refer to RFC 2136 for the semantics of dynamic updates.

WARNING:  This code is still under development and shouldn't be
used to maintain a production nameserver.

=head1 METHODS

=head2 new

    $packet = new Net::DNS::Update;
    $packet = new Net::DNS::Update("foo.com");
    $packet = new Net::DNS::Update("foo.com", "HS");

Returns a C<Net::DNS::Packet> object suitable for performing a DNS
dynamic update.  Specifically, it creates a packet with the header
opcode set to UPDATE and the zone record type to SOA (per RFC 2136,
Section 2.3).

Programs must use the C<push> method to add RRs to the prerequisite,
update, and additional sections before performing the update.

Arguments are the zone name and the class.  If the zone is omitted,
the default domain will be taken from the resolver configuration.
If the class is omitted, it defaults to IN.

Future versions of C<Net::DNS> may provide a simpler interface
for making dynamic updates.

=cut

sub new {
	shift;
	my ($zone, $class) = @_;
	my ($type, $packet);

	unless ($zone) {
		my $res = new Net::DNS::Resolver;
		$zone = ($res->searchlist)[0];
		return unless $zone;
	}

	$type  = "SOA";
	$class = "IN" unless defined $class;

	$packet = new Net::DNS::Packet($zone, $type, $class);
	if (defined $packet) {
		$packet->header->opcode("UPDATE");
		$packet->header->rd(0);
	}

	return $packet;
}

=head1 EXAMPLES

The first example below shows a complete program; subsequent examples
show only the creation of the update packet.

=head2 Add a new host

    #!/usr/local/bin/perl -w
    
    use Net::DNS;
    
    # Create the update packet.
    $update = new Net::DNS::Update("bar.com");
    
    # Prerequisite is that no A records exist for the name.
    $update->push("pre", nxrrset("foo.bar.com. A"));
    
    # Add two A records for the name.
    $update->push("update", rr_add("foo.bar.com. 86400 A 192.168.1.2"));
    $update->push("update", rr_add("foo.bar.com. 86400 A 172.16.3.4"));
    
    # Send the update to the zone's primary master.
    $res = new Net::DNS::Resolver;
    $res->nameservers("primary-master.bar.com");
    $reply = $res->send($update);
    
    # Did it work?
    if (defined $reply) {
	if ($reply->header->rcode eq "NOERROR") {
	    print "Update succeeded\n";
	}
	else {
            print "Update failed: ", $reply->header->rcode, "\n";
	}
    }
    else {
        print "Update failed: ", $res->errorstring, "\n";
    }

=head2 Add an MX record for a name that already exists

    $update = new Net::DNS::Update("foo.com");
    $update->push("pre", yxdomain("foo.com"));
    $update->push("update", rr_add("foo.com MX 10 mailhost.foo.com"));

=head2 Add a TXT record for a name that doesn't exist

    $update = new Net::DNS::Update("foo.com");
    $update->push("pre", nxdomain("info.foo.com"));
    $update->push("update", rr_add("info.foo.com TXT 'yabba dabba doo'"));

=head2 Delete all A records for a name

    $update = new Net::DNS::Update("bar.com");
    $update->push("pre", yxrrset("foo.bar.com A"));
    $update->push("update", rr_del("foo.bar.com A"));

=head2 Delete all RRs for a name

    $update = new Net::DNS::Update("foo.com");
    $update->push("pre", yxdomain("byebye.foo.com"));
    $update->push("update", rr_del("byebye.foo.com"));

=head1 BUGS

This code is still under development and shouldn't be used to maintain
a production nameserver.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>, L<Net::DNS::Header>,
L<Net::DNS::Packet>, L<Net::DNS::Question>, L<Net::DNS::RR>, RFC 2136

=cut

1;
