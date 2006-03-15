=pod

Net::OSCAR::Connection -- individual Net::OSCAR service connection

=cut

package Net::OSCAR::Connection;

$VERSION = '1.907';
$REVISION = '$Revision$';

use strict;
use vars qw($VERSION);
use Carp;
use Socket;
use Symbol;
use Digest::MD5;
use Fcntl;
use POSIX qw(:errno_h);
use Scalar::Util qw(weaken);

use Net::OSCAR::Common qw(:all);
use Net::OSCAR::Constants;
use Net::OSCAR::Utility;
use Net::OSCAR::TLV;
use Net::OSCAR::Callbacks;
use Net::OSCAR::XML;

if($^O eq "MSWin32") {
	eval '*F_GETFL = sub {0};';
	eval '*F_SETFL = sub {0};';
	eval '*O_NONBLOCK = sub {0}; ';
}

sub new($@) {
	my($class, %data) = @_;
	$class = ref($class) || $class || "Net::OSCAR::Connection";
	my $self = { %data };

	# Avoid circular references
	weaken($self->{session});

	bless $self, $class;
	$self->{seqno} = 0;
	$self->{icq_seqno} = 0;
	$self->{paused} = 0;
	$self->{outbuff} = "";
	$self->{state} ||= "write";

	$self->connect($self->{peer}) if exists($self->{peer});

	return $self;
}

sub proto_send($%) {
	my($self, %data) = @_;
	$data{protodata} ||= {};

	my %snac = protobit_to_snac($data{protobit}); # or croak "Couldn't find protobit $data{protobit}";
	confess "BAD SELF!" unless ref($self);
	confess "BAD DATA!" unless ref($data{protodata});

	$snac{data} = protoparse($self->{session}, $data{protobit})->pack(%{$data{protodata}});
	foreach (qw(reqdata reqid flags1 flags2)) {
		$snac{$_} = $data{$_} if exists($data{$_});
	}

	if(exists($snac{family})) {
		$self->log_printf(OSCAR_DBG_DEBUG, "Put SNAC 0x%04X/0x%04X: %s", $snac{family}, $snac{subtype}, $data{protobit});
		$self->snac_put(%snac);
	} else {
		$snac{channel} ||= 0+FLAP_CHAN_SNAC;
		$self->log_printf(OSCAR_DBG_DEBUG, "Putting raw FLAP: %s", $data{protobit});
		$self->flap_put($snac{data}, $snac{channel});
	}
}



sub fileno($) {
	my $self = shift;
	return undef unless $self->{socket};
	return fileno $self->{socket};
}

sub flap_encode($$;$) {
	my ($self, $msg, $channel) = @_;

	$channel ||= FLAP_CHAN_SNAC;
	return protoparse($self->{session}, "flap")->pack(
		channel => $channel,
		seqno => ++$self->{seqno},
		msg => $msg
	);
}

sub write($$) {
	my($self, $data) = @_;

	my $had_outbuff = 1 if $self->{outbuff};
	$self->{outbuff} .= $data;

	my $nchars = syswrite($self->{socket}, $self->{outbuff}, length($self->{outbuff}));
	if(!defined($nchars)) {
		return "" if $! == EAGAIN;
		$self->log_print(OSCAR_DBG_NOTICE, "Couldn't write to socket: $!");
		$self->{sockerr} = 1;
		$self->disconnect();
		return undef;
	}

	my $wrote = substr($self->{outbuff}, 0, $nchars, "");

	if($self->{outbuff}) {
		$self->log_print(OSCAR_DBG_NOTICE, "Couldn't do complete write - had to buffer ", length($self->{outbuff}), " bytes.");
		$self->{state} = "readwrite";
		$self->{session}->callback_connection_changed($self, "readwrite");
		return 0;
	} elsif($had_outbuff) {
		$self->{state} = "read";
		$self->{session}->callback_connection_changed($self, "read");
		return 1;
	}
	$self->log_print_cond(OSCAR_DBG_PACKETS, sub { "Put '", hexdump($wrote), "'" });

	return 1;
}

sub flap_put($;$$) {
	my($self, $msg, $channel) = @_;
	my $had_outbuff = 0;

	$channel ||= FLAP_CHAN_SNAC;

	return unless $self->{socket} and CORE::fileno($self->{socket}) and getpeername($self->{socket}); # and !$self->{socket}->error;

	$msg = $self->flap_encode($msg, $channel) if $msg;
	$self->write($msg);
}

sub read($$) {
	my($self, $len) = @_;

	$self->{buffsize} ||= $len;
	$self->{buffer} ||= "";

	my $buffer = "";
	my $nchars = sysread($self->{socket}, $buffer, $self->{buffsize} - length($self->{buffer}));
	if(!defined($nchars)) {
		return "" if $! == EAGAIN;
		$self->log_print(OSCAR_DBG_NOTICE, "Couldn't read from socket: $!");
		$self->{sockerr} = 1;
		$self->disconnect();
		return undef;
	} elsif($nchars == 0) { # EOF
		$self->log_print(OSCAR_DBG_NOTICE, "Got EOF on socket");
		$self->{sockerr} = 1;
		$self->disconnect();
		return undef;
	} else {
		$self->log_print_cond(OSCAR_DBG_PACKETS, sub { "Got '", hexdump($buffer), "'" });
		$self->{buffer} .= $buffer;
	}

	if(length($self->{buffer}) < $self->{buffsize}) {
		return "";
	} else {
		delete $self->{buffsize};
		return delete $self->{buffer};
	}
}

sub flap_get($) {
	my $self = shift;
	my $socket = $self->{socket};
	my ($buffer, $channel, $len);
	my $nchars;

	if(!$self->{buff_gotflap}) {
		my $header = $self->read(6);
		return $header unless $header;

		$self->{buff_gotflap} = 1;
		(undef, $self->{channel}, undef, $self->{buffsize}) = unpack("CCnn", $header);
	}

	my $data = $self->read($self->{buffsize});
	return $data unless $data;

	$self->log_print_cond(OSCAR_DBG_PACKETS, sub { "Got ", hexdump($self->{buffer}) });
	delete $self->{buff_gotflap};
	return $data;
}

sub snac_encode($%) {
	my($self, %snac) = @_;

	$snac{family} ||= 0;
	$snac{subtype} ||= 0;
	$snac{flags1} ||= 0;
	$snac{flags2} ||= 0;
	$snac{data} ||= "";
	$snac{reqdata} ||= "";
	$snac{reqid} ||= ($snac{subtype}<<16) | (unpack("n", randchars(2)))[0];
	$self->{reqdata}->[$snac{family}]->{pack("N", $snac{reqid})} = $snac{reqdata} if $snac{reqdata};

	my $snac = protoparse($self->{session}, "snac")->pack(%snac);
	return $snac;
}

sub snac_put($%) {
	my($self, %snac) = @_;
	$snac{channel} ||= 0+FLAP_CHAN_SNAC;
	confess "No family/subtype" unless exists($snac{family}) and exists($snac{subtype});
	$self->flap_put($self->snac_encode(%snac), $snac{channel});
}

sub snac_get($) {
	my($self) = shift;
	my $snac = $self->flap_get() or return 0;
	return $self->snac_decode($snac);
}

sub snac_decode($$) {
	my($self, $snac) = @_;
	my(%data) = protoparse($self->{session}, "snac")->unpack($snac);

	if($data{flags1} & 0x80) {
		my($minihdr_len) = unpack("n", $data{data});
		$self->log_print(OSCAR_DBG_DEBUG, "Got miniheader of length $minihdr_len");
		substr($data{data}, 0, 2+$minihdr_len) = "";
	}

	return \%data;
}

sub snac_dump($$) {
	my($self, $snac) = @_;
	return "family=".$snac->{family}." subtype=".$snac->{subtype};
}

sub disconnect($) {
	my($self) = @_;

	$self->{session}->delconn($self);
}

sub set_blocking($$) {
	my $self = shift;
	my $blocking = shift;
	my $flags = 0;

	if($^O ne "MSWin32") {
		fcntl($self->{socket}, F_GETFL, $flags);
		if($blocking) {
			$flags &= ~O_NONBLOCK;
		} else {
			$flags |= O_NONBLOCK;
		}
		fcntl($self->{socket}, F_SETFL, $flags);
	} else {
		# Cribbed from http://nntp.x.perl.org/group/perl.perl5.porters/42198
		ioctl($self->{socket},
			0x80000000 | (4 << 16) | (ord('f') << 8) | 126,
			$blocking
		) or warn "Couldn't set Win32 blocking: $!\n";
	}

	return $self->{socket};
}

sub connect($$) {
	my($self, $host) = @_;
	my $temp;
	my $port;

	return $self->{session}->crapout($self, "Empty host!") unless $host;
	$host =~ s/:(.+)//;
	if(!$1) {
		if(exists($self->{session})) {
			$port = $self->{session}->{port};
		} else {
			return $self->{session}->crapout($self, "No port!");
		}
	} else {
		$port = $1;
		if($port =~ /^[^0-9]/) {
			$port = $self->{session}->{port};
		}
	}
	$self->{host} = $host;
	$self->{port} = $port;

	$self->log_print(OSCAR_DBG_NOTICE, "Connecting to $host:$port.");
	if(defined($self->{session}->{proxy_type})) {
		if($self->{session}->{proxy_type} eq "SOCKS4" or $self->{session}->{proxy_type} eq "SOCKS5") {
			require Net::SOCKS or die "SOCKS proxying not available - couldn't load Net::SOCKS: $!\n";

			my $socksver;
			if($self->{session}->{proxy_type} eq "SOCKS4") {
				$socksver = 4;
			} else {
				$socksver = 5;
			}

			my %socksargs = (
				socks_addr => $self->{session}->{proxy_host},
				socks_port => $self->{session}->{proxy_port} || 1080,
				protocol_version => $socksver
			);
			$socksargs{user_id} = $self->{session}->{proxy_username} if exists($self->{session}->{proxy_username});
			$socksargs{user_password} = $self->{session}->{proxy_password} if exists($self->{session}->{proxy_password});
		        $self->{socks} = new Net::SOCKS(%socksargs) or return $self->{session}->crapout($self, "Couldn't connect to SOCKS proxy: $@");

			$self->{socket} = $self->{socks}->connect(peer_addr => $host, peer_port => $port) or return $self->{session}->crapout({}, "Couldn't establish connection via SOCKS: $@\n");

			$self->{ready} = 0;
			$self->{connected} = 1;
			$self->set_blocking(0);
		} elsif($self->{session}->{proxy_type} eq "HTTP" or $self->{session}->{proxy_type} eq "HTTPS") {
			$self->{ready} = 0;
			$self->{connected} = 1;
		} else {
			die "Unknown proxy_type $self->{session}->{proxy_type} - valid types are SOCKS4, SOCKS5, HTTP, and HTTPS\n";
		}
	} else {
		$self->{socket} = gensym;
		socket($self->{socket}, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
		if($self->{session}->{local_ip}) {
			bind($self->{socket}, sockaddr_in(0, inet_aton($self->{session}->{local_ip}))) or croak "Couldn't bind to desired IP: $!\n";
		}
		$self->set_blocking(0);

		my $addr = inet_aton($host) or return $self->{session}->crapout($self, "Couldn't resolve $host.");
		if(!connect($self->{socket}, sockaddr_in($port, $addr))) {
			return 1 if $! == EINPROGRESS;
			return $self->{session}->crapout($self, "Couldn't connect to $host:$port: $!");
		}

		$self->{ready} = 0;
		$self->{connected} = 0;
	}

	return 1;
}

sub get_filehandle($) { shift->{socket}; }

# $read/$write tell us if select indicated readiness to read and/or write
# Dittor for $error
sub process_one($;$$$) {
	my($self, $read, $write, $error) = @_;
	my $snac;

	if($error) {
		$self->{sockerr} = 1;
		return $self->disconnect();
	}

	$read ||= 1;
	$write ||= 1;

	if($write && $self->{outbuff}) {
		$self->log_print(OSCAR_DBG_DEBUG, "Flushing output buffer.");
		$self->flap_put();
	}

	if($write && !$self->{connected}) {
		$self->log_print(OSCAR_DBG_NOTICE, "Connected.");
		$self->{connected} = 1;
		$self->{state} = "read";
		$self->{session}->callback_connection_changed($self, "read");
		return 1;
	} elsif($read && !$self->{ready}) {
		$self->log_print(OSCAR_DBG_DEBUG, "Getting connack.");
		my $flap = $self->flap_get();
		if(!defined($flap)) {
			$self->log_print(OSCAR_DBG_NOTICE, "Couldn't connect.");
			return 0;
		} else {
			$self->log_print(OSCAR_DBG_DEBUG, "Got connack.");
		}

		return $self->{session}->crapout($self, "Got bad connack from server") unless $self->{channel} == FLAP_CHAN_NEWCONN;

		if($self->{conntype} == CONNTYPE_LOGIN) {
			$self->log_print(OSCAR_DBG_DEBUG, "Got connack.  Sending connack.");
			$self->flap_put(pack("N", 1), FLAP_CHAN_NEWCONN) unless $self->{session}->{svcdata}->{hashlogin};
			$self->log_print(OSCAR_DBG_SIGNON, "Connected to login server.");
			$self->{ready} = 1;

			if(!$self->{session}->{svcdata}->{hashlogin}) {
				$self->proto_send(protobit => "initial signon request",
					protodata => {screenname => $self->{session}->{screenname}}
				);
			} else {
				$self->proto_send(protobit => "ICQ signon request",
					protodata => {signon_tlv($self->{session}, $self->{auth})}
				);
			}
		} else {
			$self->log_print(OSCAR_DBG_NOTICE, "Sending BOS-Signon.");
			$self->proto_send(protobit => "BOS signon",
				reqid => 0x01000000 | (unpack("n", substr($self->{auth}, 0, 2)))[0],
				protodata => {cookie => substr($self->{auth}, 2)}
			)
		}
		$self->log_print(OSCAR_DBG_DEBUG, "SNAC time.");
		return $self->{ready} = 1;
	} elsif($read) {
		if(!$self->{session}->{svcdata}->{hashlogin}) {
			$snac = $self->snac_get() or return 0;
			return Net::OSCAR::Callbacks::process_snac($self, $snac);
		} else {
			my $data = $self->flap_get() or return 0;
			$snac = {data => $data, reqid => 0, family => 0x17, subtype => 0x3};
			if($self->{channel} == FLAP_CHAN_CLOSE) {
				$self->{conntype} = CONNTYPE_LOGIN;
				$self->{family} = 0x17;
				$self->{subtype} = 0x3;
				$self->{data} = $data;
				$self->{reqid} = 0;
				$self->{reqdata}->[0x17]->{pack("N", 0)} = "";
				return Net::OSCAR::Callbacks::process_snac($self, $snac);
			} else {
				my $snac = $self->snac_decode($data);
				if($snac) {
					return Net::OSCAR::Callbacks::process_snac($self, $snac);
				} else {
					return 0;
				}
			}
		}
	}
}

sub ready($) {
	my($self) = shift;

	return if $self->{sentready}++;
	send_versions($self, 1);
}

sub session($) { return shift->{session}; }

1;
