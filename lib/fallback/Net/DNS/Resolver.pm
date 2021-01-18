package Net::DNS::Resolver;

=head1 NAME

Net::DNS::Resolver - DNS resolver class

=head1 SYNOPSIS

C<use Net::DNS::Resolver;>

=head1 DESCRIPTION

Instances of the C<Net::DNS::Resolver> class represent resolver objects.
A program can have multiple resolver objects, each maintaining its
own state information such as the nameservers to be queried, whether
recursion is desired, etc.

Resolver configuration is read from the following files, in the
order indicated:

    /etc/resolv.conf
    $HOME/.resolv.conf
    ./.resolv.conf

The following keywords are recognized in resolver configuration files:

=over 4

=item B<domain>

The default domain.

=item B<search>

A space-separated list of domains to put in the search list.

=item B<nameserver>

A space-separated list of nameservers to query.

=back

Files except for F</etc/resolv.conf> must be owned by the effective
userid running the program or they won't be read.  In addition, several
environment variables can also contain configuration information;
see L</ENVIRONMENT>.

=head1 METHODS

=cut

use strict;
use vars qw(
	$VERSION
	$resolv_conf
	$dotfile
	@confpath
	%default
	%global
	$AUTOLOAD
);

use Carp;
use Socket;
use IO::Socket;
use IO::Select;
use Net::DNS;
use Net::DNS::Packet;

# $Id$
$VERSION = $Net::DNS::VERSION;

#------------------------------------------------------------------------------
# Configurable defaults.
#------------------------------------------------------------------------------

$resolv_conf = "/etc/resolv.conf";
$dotfile     = ".resolv.conf";

push(@confpath, $ENV{"HOME"}) if exists $ENV{"HOME"};
push(@confpath, ".");

%default = (
	"nameservers"	=> ["127.0.0.1"],
	"port"		=> "53",
	"domain"	=> "",
	"searchlist"	=> [],
	"retrans"	=> 5,
	"retry"		=> 4,
	"usevc"		=> 0,
	"stayopen"	=> 0,
	"igntc"		=> 0,
	"recurse"	=> 1,
	"defnames"	=> 1,
	"dnsrch"	=> 1,
	"debug"		=> 0,
	"errorstring"	=> "unknown error or no error",
	"answerfrom"    => "",
	"answersize"    => 0,
	"tcp_timeout"   => 120,
);

%global = (
	"id"		=> int(rand(65535)),
);

=head2 new

    $res = new Net::DNS::Resolver;

Creates a new DNS resolver object.

=cut

sub new {
	my $class = shift;
	my $self = { %default };
	return bless $self, $class;
}

#
# Some people have reported that Net::DNS dies because AUTOLOAD picks up
# calls to DESTROY.
#
sub DESTROY {}

sub res_init {
	read_config($resolv_conf) if (-f $resolv_conf) and (-r $resolv_conf);

	my $dir;
	foreach $dir (@confpath) {
		my $file = "$dir/$dotfile";
		read_config($file) if (-f $file) and (-r $file) and (-o $file);
	}

	read_env();

	if (!$default{"domain"} && @{$default{"searchlist"}}) {
		$default{"domain"} = $default{"searchlist"}[0];
	}
	elsif (!@{$default{"searchlist"}} && $default{"domain"}) {
		$default{"searchlist"} = [ $default{"domain"} ];
	}
}

sub read_config {
	my $file = shift;
	my @ns;
	my @searchlist;
	local *FILE;

	open(FILE, $file) or Carp::confess "can't open $file: $!";
	while (<FILE>) {
		s/\s*[;#].*//;
		next if /^\s*$/;

		SWITCH: {
			/^\s*domain\s+(\S+)/ && do {
				$default{"domain"} = $1;
				last SWITCH;
			};

			/^\s*search\s+(.*)/ && do {
				push(@searchlist, split(" ", $1));
				last SWITCH;
			};

			/^\s*nameserver\s+(.*)/ && do {
				my $ns;
				foreach $ns (split(" ", $1)) {
					$ns = "0.0.0.0" if $ns eq "0";
					push @ns, $ns;
				}
				last SWITCH;
			};
		}
	}
	close FILE;

	$default{"nameservers"} = [ @ns ]         if @ns;
	$default{"searchlist"}  = [ @searchlist ] if @searchlist;
}

sub read_env {
	$default{"nameservers"} = [ split(" ", $ENV{"RES_NAMESERVERS"}) ]
		if exists $ENV{"RES_NAMESERVERS"};

	$default{"searchlist"} = [ split(" ", $ENV{"RES_SEARCHLIST"}) ]
		if exists $ENV{"RES_SEARCHLIST"};
	
	$default{"domain"} = $ENV{"LOCALDOMAIN"}
		if exists $ENV{"LOCALDOMAIN"};

	if (exists $ENV{"RES_OPTIONS"}) {
		my @env = split(" ", $ENV{"RES_OPTIONS"});
		foreach (@env) {
			my ($name, $val) = split(/:/);
			$val = 1 unless defined $val;
			$default{$name} = $val if exists $default{$name};
		}
	}
}

=head2 print

    $res->print;

Prints the resolver state on the standard output.

=cut

sub print {
	my $self = shift;
	print $self->string;
}

=head2 string

    print $res->string;

Returns a string representation of the resolver state.

=cut

sub string {
	my $self = shift;

	return	";; RESOLVER state:\n"				.
		";;  domain       = $self->{domain}\n"		.
		";;  searchlist   = @{$self->{searchlist}}\n"	.
		";;  nameservers  = @{$self->{nameservers}}\n"	.
		";;  port         = $self->{port}\n"		.
		";;  tcp_timeout  = " .
		(defined $self->{"tcp_timeout"} ? $self->{"tcp_timeout"} : "indefinite") . "\n" .
		";;  retrans  = $self->{retrans}  "		.
		"retry    = $self->{retry}\n"			.
		";;  usevc    = $self->{usevc}  "		.
		"stayopen = $self->{stayopen}    "		.
		"igntc = $self->{igntc}\n"			.
		";;  defnames = $self->{defnames}  "		.
		"dnsrch   = $self->{dnsrch}\n"			.
		";;  recurse  = $self->{recurse}  "		.
		"debug    = $self->{debug}\n";
}

sub nextid {
	return $global{"id"}++;
}

=head2 searchlist

    @searchlist = $res->searchlist;
    $res->searchlist("foo.com", "bar.com", "baz.org");

Gets or sets the resolver search list.

=cut

sub searchlist {
	my $self = shift;
	$self->{"searchlist"} = [ @_ ] if @_;
	return @{$self->{"searchlist"}};
}

=head2 nameservers

    @nameservers = $res->nameservers;
    $res->nameservers("192.168.1.1", "192.168.2.2", "192.168.3.3");

Gets or sets the nameservers to be queried.

=head2 port

    print "sending queries to port ", $res->port, "\n";
    $res->port(9732);

Gets or sets the port to which we send queries.  This can be useful
for testing a nameserver running on a non-standard port.  The
default is port 53.

=cut

sub nameservers {
	my $self = shift;
	my $defres = new Net::DNS::Resolver;

	if (@_) {
		my @a;
		my $ns;
		foreach $ns (@_) {
			#if ($ns =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
			if ($ns =~ /^\d+(\.\d+){0,3}$/) {
				push @a, ($ns eq "0") ? "0.0.0.0" : $ns;
			}
			else {
				my @names;

				if ($ns !~ /\./) {
					if (defined $defres->searchlist) {
						@names = map { $ns . "." . $_ }
							    $defres->searchlist;
					}
					elsif (defined $defres->domain) {
						@names = ($ns . "." . $defres->domain);
					}
				}
				else {
					@names = ($ns);
				}

				my $packet = $defres->search($ns);
				$self->errorstring($defres->errorstring);
				if (defined($packet)) {
					push @a, cname_addr([@names], $packet);
				}
			}
		}
		$self->{"nameservers"} = [ @a ];
	}

	return @{$self->{"nameservers"}};
}

sub cname_addr {
	my $names = shift;
	my $packet = shift;
	my $rr;
	my @addr;
	my @names = @{$names};

	foreach $rr ($packet->answer) {
		next unless grep {$rr->name} @names;
		if ($rr->type eq "CNAME") {
			@names = ($rr->cname);
		}
		elsif ($rr->type eq "A") {
			push @addr, $rr->address;
		}
	}
	return @addr;
}

=head2 search

    $packet = $res->search("mailhost");
    $packet = $res->search("mailhost.foo.com");
    $packet = $res->search("192.168.1.1");
    $packet = $res->search("foo.com", "MX");
    $packet = $res->search("user.passwd.foo.com", "TXT", "HS");

Performs a DNS query for the given name, applying the searchlist
if appropriate.  The search algorithm is as follows:

=over 4

=item 1.

If the name contains at least one dot, try it as is.

=item 2.

If the name doesn't end in a dot then append each item in
the search list to the name.  This is only done if B<dnsrch>
is true.

=item 3.

If the name doesn't contain any dots, try it as is.

=back

The record type and class can be omitted; they default to A and
IN.  If the name looks like an IP address (4 dot-separated numbers),
then an appropriate PTR query will be performed.

Returns a C<Net::DNS::Packet> object, or C<undef> if no answers
were found.

=cut

sub search {
	my $self = shift;
	my ($name, $type, $class) = @_;
	my $ans;

	$type  = "A"  unless defined($type);
	$class = "IN" unless defined($class);

	# If the name looks like an IP address then do an appropriate
	# PTR query.
	if ($name =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
		$name = "$4.$3.$2.$1.in-addr.arpa.";
		$type = "PTR";
	}

	# If the name contains at least one dot then try it as is first.
	if (index($name, ".") >= 0) {
		print ";; search($name, $type, $class)\n" if $self->{"debug"};
		$ans = $self->query($name, $type, $class);
		return $ans if (defined $ans) && ($ans->header->ancount > 0);
	}

	# If the name doesn't end in a dot then apply the search list.
	my $domain;
	if (($name !~ /\.$/) && $self->{"dnsrch"}) {
		foreach $domain (@{$self->{"searchlist"}}) {
			my $newname = "$name.$domain";
			print ";; search($newname, $type, $class)\n"
				if $self->{"debug"};
			$ans = $self->query($newname, $type, $class);
			return $ans if (defined $ans) && ($ans->header->ancount > 0);
		}
	}

	# Finally, if the name has no dots then try it as is.
	if (index($name, ".") < 0) {
		print ";; search($name, $type, $class)\n" if $self->{"debug"};
		$ans = $self->query("$name.", $type, $class);
		return $ans if (defined $ans) && ($ans->header->ancount > 0);
	}

	# No answer was found.
	return undef;
}

=head2 query

    $packet = $res->query("mailhost");
    $packet = $res->query("mailhost.foo.com");
    $packet = $res->query("192.168.1.1");
    $packet = $res->query("foo.com", "MX");
    $packet = $res->query("user.passwd.foo.com", "TXT", "HS");

Performs a DNS query for the given name; the search list is not
applied.  If the name doesn't contain any dots and B<defnames>
is true then the default domain will be appended.

The record type and class can be omitted; they default to A and
IN.  If the name looks like an IP address (4 dot-separated numbers),
then an appropriate PTR query will be performed.

Returns a C<Net::DNS::Packet> object, or C<undef> if no answers
were found.

=cut

sub query {
	my $self = shift;
	my ($name, $type, $class) = @_;

	$type  = "A"  unless defined($type);
	$class = "IN" unless defined($class);

	# If the name doesn't contain any dots then append the default domain.
	if ((index($name, ".") < 0) && $self->{"defnames"}) {
		$name .= ".$self->{domain}";
	}

	# If the name looks like an IP address then do an appropriate
	# PTR query.
	if ($name =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
		$name = "$4.$3.$2.$1.in-addr.arpa";
		$type = "PTR";
	}

	print ";; query($name, $type, $class)\n" if $self->{"debug"};
	my $packet = new Net::DNS::Packet($name, $type, $class);
	my $ans = $self->send($packet);

	return (defined($ans) && ($ans->header->ancount > 0)) ? $ans : undef;
}

=head2 send

    $packet = $res->send($packet_object);
    $packet = $res->send("mailhost.foo.com");
    $packet = $res->send("foo.com", "MX");
    $packet = $res->send("user.passwd.foo.com", "TXT", "HS");

Performs a DNS query for the given name.  Neither the searchlist
nor the default domain will be appended.  

The argument list can be either a C<Net::DNS::Packet> object or a list
of strings.  The record type and class can be omitted; they default to
A and IN.  If the name looks like an IP address (4 dot-separated numbers),
then an appropriate PTR query will be performed.

Returns a C<Net::DNS::Packet> object whether there were any answers or not.
Use C<$packet>->C<header>->C<ancount> or C<$packet>->C<answer> to find out
if there were any records in the answer section.  Returns C<undef> if there
was an error.

=cut

sub send {
	my $self = shift;
	my $packet = $self->make_query_packet(@_);
	my $packet_data = $packet->data;

	my $ans;

	if ($self->{"usevc"} || length $packet_data > &Net::DNS::PACKETSZ) {
		$ans = $self->send_tcp($packet, $packet_data);
	}
	else {
		$ans = $self->send_udp($packet, $packet_data);

		if ($ans && $ans->header->tc && !$self->{"igntc"}) {
			print ";;\n;; packet truncated: retrying using TCP\n"
				if $self->{"debug"};
			$ans = $self->send_tcp($packet, $packet_data);
		}
	}

	return $ans;
}

sub send_tcp {
	my ($self, $packet, $packet_data) = @_;

	unless (@{$self->{"nameservers"}}) {
		$self->{"errorstring"} = "no nameservers";
		print ";; ERROR: no nameservers\n" if $self->{"debug"};
		return;
	}

	$self->errorstring($default{"errorstring"});
	my $timeout = $self->{"tcp_timeout"};

	my $ns;
	foreach $ns (@{$self->{"nameservers"}}) {
		# IO::Socket carps on errors if Perl's -w flag is turned on.
		# Uncomment the next two lines and the line following the "new"
		# call to turn off these messages.

		my $old_wflag = $^W;
		$^W = 0;

		print ";; send_tcp($ns:", $self->{"port"}, ")\n"
			if $self->{"debug"};

		my $sock = IO::Socket::INET->new(PeerAddr => $ns,
				                 PeerPort => $self->{"port"},
				                 Proto    => "tcp",
						 Timeout  => $timeout);
		$^W = $old_wflag;

		unless ($sock) {
			$self->errorstring("connection failed");
			print ";; ERROR: connection failed\n"
				if $self->{"debug"};
			next;
		}

		my $lenmsg = pack("n", length($packet_data));
		print ";; sending ", length($packet_data), " bytes\n"
			if $self->{"debug"};

		unless ($sock->send($lenmsg)) {
			$self->errorstring($!);
			print ";; ERROR: length send failed: $!\n"
				if $self->{"debug"};
			next;
		}

		unless ($sock->send($packet_data)) {
			$self->errorstring($!);
			print ";; ERROR: data send failed: $!\n"
				if $self->{"debug"};
			next;
		}

		my $sel = new IO::Select($sock);
		if ($sel->can_read($timeout)) {
			my $buf = read_tcp($sock, &Net::DNS::INT16SZ);
			next unless length($buf);
			my ($len) = unpack("n", $buf);
			next unless $len;

			unless ($sel->can_read($timeout)) {
				$self->errorstring("timeout");
				print ";; TIMEOUT\n" if $self->{"debug"};
				next;
			}

			$buf = read_tcp($sock, $len);

			$self->answerfrom($sock->peerhost);
			$self->answersize(length $buf);

			print ";; received ", length($buf), " bytes\n"
				if $self->{"debug"};

			unless (length($buf) == $len) {
				$self->errorstring("expected $len bytes, " .
						   "received " . length($buf));
				next;
			}

			my ($ans, $err) = new Net::DNS::Packet(\$buf, $self->{"debug"});
			if (defined $ans) {
				$self->errorstring($ans->header->rcode);
				$ans->answerfrom($self->answerfrom);
				$ans->answersize($self->answersize);
			}
			elsif (defined $err) {
				$self->errorstring($err);
			}

			return $ans;
		}
		else {
			$self->errorstring("timeout");
			next;
		}
	}

	return;
}

sub send_udp {
	my ($self, $packet, $packet_data) = @_;
	my $retrans = $self->{"retrans"};
	my $timeout = $retrans;
	my ($ns, @ns);
	my ($i, $j);

	$self->errorstring($default{"errorstring"});

	# IO::Socket carps on errors if Perl's -w flag is turned on.
	# Uncomment the next two lines and the line following the "new"
	# call to turn off these messages.

	my $old_wflag = $^W;
	$^W = 0;

	@ns = grep { $_ } map {
		IO::Socket::INET->new(PeerAddr => $_,
				      PeerPort => $self->{"port"},
				      Proto    => "udp");
	} @{$self->{"nameservers"}};

	$^W = $old_wflag;

	unless (@ns) {
		$self->errorstring("no nameservers");
		return;
	}

	my $sel = new IO::Select(@ns);

	# Perform each round of retries.
	for ($i = 0;
	     $i < $self->{"retry"};
	     ++$i, $retrans *= 2, $timeout = int($retrans / ($#ns + 1))) {

		$timeout = 1 if ($timeout < 1);

		# Try each nameserver.
		foreach $ns ($sel->handles) {
			print ";; send_udp(", $ns->peerhost, ":", $ns->peerport, ")\n"
				if $self->{"debug"};

			unless ($ns->send($packet_data)) {
				print ";; send error: $!\n" if $self->{"debug"};
				$sel->remove($ns);
				next;
			}

			my @ready = $sel->can_read($timeout);

			my $ready;
			foreach $ready (@ready) {
				my $buf = "";
				if ($ready->recv($buf, &Net::DNS::PACKETSZ)) {
					$self->answerfrom($ready->peerhost);
					$self->answersize(length $buf);
					print ";; answer from ",
					      $ready->peerhost, ":",
					      $ready->peerport, " : ",
					      length($buf), " bytes\n"
						if $self->{"debug"};
					my ($ans, $err) = new Net::DNS::Packet(\$buf, $self->{"debug"});
					if (defined $ans) {
						next unless $ans->header->qr;
						next unless $ans->header->id == $packet->header->id;
						$self->errorstring($ans->header->rcode);
						$ans->answerfrom($self->answerfrom);
						$ans->answersize($self->answersize);
					}
					elsif (defined $err) {
						$self->errorstring($err);
					}
					return $ans;
				}
				else {
					$self->errorstring($!);
					print ";; recv ERROR(",
					      $ready->peerhost, ":",
					      $ready->peerport, "): ",
					      $self->errorstring, "\n"
						if $self->{"debug"};

					$sel->remove($ready);
					return unless $sel->handles;
				}
			}
		}
	}

	$self->errorstring("query timed out");
	return;
}

=head2 bgsend

    $socket = $res->bgsend($packet_object);
    $socket = $res->bgsend("mailhost.foo.com");
    $socket = $res->bgsend("foo.com", "MX");
    $socket = $res->bgsend("user.passwd.foo.com", "TXT", "HS");

Performs a background DNS query for the given name, i.e., sends a
query packet to the first nameserver listed in C<$res>->C<nameservers>
and returns immediately without waiting for a response.  The program
can then perform other tasks while waiting for a response from the 
nameserver.

The argument list can be either a C<Net::DNS::Packet> object or a list
of strings.  The record type and class can be omitted; they default to
A and IN.  If the name looks like an IP address (4 dot-separated numbers),
then an appropriate PTR query will be performed.

Returns an C<IO::Socket> object.  The program must determine when
the socket is ready for reading and call C<$res>->C<bgread> to get
the response packet.  You can use C<$res>->C<bgisready> or C<IO::Select>
to find out if the socket is ready before reading it.

=cut

sub bgsend {
	my $self = shift;

	unless (@{$self->{"nameservers"}}) {
		$self->errorstring("no nameservers");
		return;
	}

	$self->errorstring($default{"errorstring"});
	my $packet = $self->make_query_packet(@_);
	my $ns = $self->{"nameservers"}->[0];

	my $sock = IO::Socket::INET->new(PeerAddr => $ns,
					 PeerPort => $self->{"port"},
					 Proto    => "udp");

	unless ($sock) {
		$self->errorstring("couldn't get socket");
		return;
	}

	print ";; bgsend(", $ns->peerhost, ":", $ns->peerport, ")\n"
		if $self->{"debug"};

	unless ($sock->send($packet->data)) {
		my $err = $!;
		print ";; send ERROR($ns): $err\n";
		$self->errorstring($err);
		return;
	}

	return $sock;
}

=head2 bgread

    $packet = $res->bgread($socket);
    undef $socket;

Reads the answer from a background query (see L</bgsend>).  The argument
is an C<IO::Socket> object returned by C<bgsend>.

Returns a C<Net::DNS::Packet> object or C<undef> on error.

The programmer should close or destroy the socket object after reading it.

=cut

sub bgread {
	my $self = shift;
	my $sock = shift;

	my $buf = "";

	if ($sock->recv($buf, &Net::DNS::PACKETSZ)) {
		print ";; answer from ", $sock->peerhost, ":",
		      $sock->peerport, " : ", length($buf), " bytes\n"
			if $self->{"debug"};

		my ($ans, $err) = new Net::DNS::Packet(\$buf, $self->{"debug"});
		if (defined $ans) {
			$self->errorstring($ans->header->rcode);
		}
		elsif (defined $err) {
			$self->errorstring($err);
		}
		return $ans;
	}
	else {
		$self->errorstring($!);
		return;
	}
}

=head2 bgisready

    $socket = $res->bgsend("foo.bar.com");
    until ($res->bgisready($socket)) {
	# do some other processing
    }
    $packet = $res->bgread($socket);
    $socket = undef;

Determines whether a socket is ready for reading.  The argument is
an C<IO::Socket> object returned by C<$res>->C<bgsend>.

Returns true if the socket is ready, false if not.

=cut

sub bgisready {
	my $self = shift;
	my $sel = new IO::Select(@_);
	my @ready = $sel->can_read(0.0);
	return @ready > 0;
}

sub make_query_packet {
	my $self = shift;
	my $packet;

	if (ref($_[0]) eq "Net::DNS::Packet") {
		$packet = shift;
	}
	else {
		my ($name, $type, $class) = @_;

		$type  = "A"  unless defined($type);
		$class = "IN" unless defined($class);

		# If the name looks like an IP address then do an appropriate
		# PTR query.
		if ($name =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
			$name = "$4.$3.$2.$1.in-addr.arpa.";
			$type = "PTR";
		}

		$packet = new Net::DNS::Packet($name, $type, $class);
	}

	$packet->header->rd($self->{"recurse"});

	return $packet;
}

=head2 axfr

    @zone = $res->axfr;
    @zone = $res->axfr("foo.com");
    @zone = $res->axfr("passwd.foo.com", "HS");

Performs a zone transfer from the first nameserver listed in C<nameservers>.
If the zone is omitted, it defaults to the first zone listed in the resolver's
search list.  If the class is omitted, it defaults to IN.

Returns a list of C<Net::DNS::RR> objects, or C<undef> if the zone
transfer failed.

The redundant SOA record that terminates the zone transfer is not
returned to the caller.

Here's an example that uses a timeout:

    $res->tcp_timeout(10);
    @zone = $res->axfr("foo.com");
    if (@zone) {
        foreach $rr (@zone) {
            $rr->print;
        }
    }
    else {
        print "Zone transfer failed: ", $res->errorstring, "\n";
    }

=cut

sub axfr {
	my $self = shift;
	my ($dname, $class) = @_;
	$dname ||= $self->{"searchlist"}->[0];
	$class ||= "IN";

	unless ($dname) {
		print ";; ERROR: axfr: no zone specified\n" if $self->{"debug"};
		$self->{"errorstring"} = "no zone";
		return;
	}

	print ";; axfr($dname, $class)\n" if $self->{"debug"};

	unless (@{$self->{"nameservers"}}) {
		$self->{"errorstring"} = "no nameservers";
		print ";; ERROR: no nameservers\n" if $self->{"debug"};
		return;
	}

	my $packet = new Net::DNS::Packet($dname, "AXFR", $class);
	my $data   = $packet->data;
	my $ns     = $self->{"nameservers"}->[0];

	print ";; axfr nameserver = $ns\n" if $self->{"debug"};

	# IO::Socket carps on errors if Perl's -w flag is turned on.
	# Uncomment the next two lines and the line following the "new"
	# call to turn off these messages.

	my $old_wflag = $^W;
	$^W = 0;

	my $sock = new IO::Socket::INET(PeerAddr => $ns,
					PeerPort => $self->{"port"},
					Proto    => "tcp",
					Timeout  => $self->{"tcp_timeout"});

	$^W = $old_wflag;

	unless ($sock) {
		$self->errorstring("couldn't connect");
		return;
	}

	my $lenmsg = pack("n", length($data));

	unless ($sock->send($lenmsg)) {
		$self->errorstring($!);
		return;
	}

	unless ($sock->send($data)) {
		$self->errorstring($!);
		return;
	}

	my $sel = new IO::Select;
	$sel->add($sock);

	my @zone;
	my $soa_count = 0;
	my $timeout = $self->{"tcp_timeout"};

	while (1) {
		my @ready = $sel->can_read($timeout);
		unless (@ready) {
			$self->errorstring("timeout");
			return;
		}

		my $buf = read_tcp($sock, &Net::DNS::INT16SZ);
		last unless length($buf);
		my ($len) = unpack("n", $buf);
		last unless $len;

		@ready = $sel->can_read($timeout);
		unless (@ready) {
			$self->errorstring("timeout");
			return;
		}

		$buf = read_tcp($sock, $len);

		print ";; received ", length($buf), " bytes\n"
			if $self->{"debug"};

		unless (length($buf) == $len) {
			$self->errorstring("expected $len bytes, " .
					   "received " . length($buf));
			return;
		}

		my ($ans, $err) = new Net::DNS::Packet(\$buf, $self->{"debug"});

		if (defined $ans) {
			if ($ans->header->ancount < 1) {
				$self->errorstring($ans->header->rcode);
				last;
			}
		}
		elsif (defined $err) {
			$self->errorstring($err);
			last;
		}

		foreach ($ans->answer) {
			# $_->print if $self->{"debug"};
			if ($_->type eq "SOA") {
				++$soa_count;
				push @zone, $_ unless $soa_count >= 2;
			}
			else {
				push @zone, $_;
			}
		}

		last if $soa_count >= 2;
	}

	return @zone;
}

#
# Usage:  $data = read_tcp($socket, $nbytes);
#
sub read_tcp {
	my ($sock, $nbytes) = @_;
	my $buf = "";
	my $buf2;

	while (length($buf) < $nbytes) {
		$sock->recv($buf2, $nbytes - length($buf));
		last unless length($buf2);
		$buf .= $buf2;
	}
	return $buf;
}

=head2 tcp_timeout

    print "TCP timeout: ", $res->tcp_timeout, "\n";
    $res->tcp_timeout(10);

Get or set the TCP timeout in seconds.  A timeout of C<undef> means
indefinite.  The default is 120 seconds (2 minutes).

=head2 retrans

    print "retrans interval: ", $res->retrans, "\n";
    $res->retrans(3);

Get or set the retransmission interval.  The default is 5.

=head2 retry

    print "number of tries: ", $res->retry, "\n";
    $res->retry(2);

Get or set the number of times to try the query.  The default is 4.

=head2 recurse

    print "recursion flag: ", $res->recurse, "\n";
    $res->recurse(0);

Get or set the recursion flag.  If this is true, nameservers will
be requested to perform a recursive query.  The default is true.

=head2 defnames

    print "defnames flag: ", $res->defnames, "\n";
    $res->defnames(0);

Get or set the defnames flag.  If this is true, calls to B<query> will
append the default domain to names that contain no dots.  The default
is true.

=head2 dnsrch

    print "dnsrch flag: ", $res->dnsrch, "\n";
    $res->dnsrch(0);

Get or set the dnsrch flag.  If this is true, calls to B<search> will
apply the search list.  The default is true.

=head2 debug

    print "debug flag: ", $res->debug, "\n";
    $res->debug(1);

Get or set the debug flag.  If set, calls to B<search>, B<query>,
and B<send> will print debugging information on the standard output.
The default is false.

=head2 usevc

    print "usevc flag: ", $res->usevc, "\n";
    $res->usevc(1);

Get or set the usevc flag.  If true, then queries will be performed
using virtual circuits (TCP) instead of datagrams (UDP).  The default
is false.

=head2 igntc

    print "igntc flag: ", $res->igntc, "\n";
    $res->igntc(1);

Get or set the igntc flag.  If true, truncated packets will be
ignored.  If false, truncated packets will cause the query to
be retried using TCP.  The default is false.

=head2 errorstring

    print "query status: ", $res->errorstring, "\n";

Returns a string containing the status of the most recent query.

=head2 answerfrom

    print "last answer was from: ", $res->answerfrom, "\n";

Returns the IP address from which we received the last answer in
response to a query.

=head2 answersize

    print "size of last answer: ", $res->answersize, "\n";

Returns the size in bytes of the last answer we received in
response to a query.

=cut

sub AUTOLOAD {
	my $self = shift;
	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	Carp::confess "$name: no such method" unless exists $self->{$name};
	$self->{$name} = shift if @_;
	return $self->{$name};
}

=head1 ENVIRONMENT

The following environment variables can also be used to configure
the resolver:

=head2 RES_NAMESERVERS

    # Bourne Shell
    RES_NAMESERVERS="192.168.1.1 192.168.2.2 192.168.3.3"
    export RES_NAMESERVERS

    # C Shell
    setenv RES_NAMESERVERS "192.168.1.1 192.168.2.2 192.168.3.3"

A space-separated list of nameservers to query.

=head2 RES_SEARCHLIST

    # Bourne Shell
    RES_SEARCHLIST="foo.com bar.com baz.org"
    export RES_SEARCHLIST

    # C Shell
    setenv RES_SEARCHLIST "foo.com bar.com baz.org"

A space-separated list of domains to put in the search list.

=head2 LOCALDOMAIN

    # Bourne Shell
    LOCALDOMAIN=foo.com
    export LOCALDOMAIN

    # C Shell
    setenv LOCALDOMAIN foo.com

The default domain.

=head2 RES_OPTIONS

    # Bourne Shell
    RES_OPTIONS="retrans:3 retry:2 debug"
    export RES_OPTIONS

    # C Shell
    setenv RES_OPTIONS "retrans:3 retry:2 debug"

A space-separated list of resolver options to set.  Options that
take values are specified as I<option>:I<value>.

=head1 BUGS

Error reporting and handling needs to be improved.

=head1 COPYRIGHT

Copyright (c) 1997 Michael Fuhr.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself. 

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Packet>, L<Net::DNS::Update>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
L<resolver(5)>, RFC 1035, RFC 1034 Section 4.3.5

=cut

res_init();
1;
