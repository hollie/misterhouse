=pod

Net::OSCAR::Connection -- individual Net::OSCAR service connection

=cut

package Net::OSCAR::Connection;

$VERSION = '1.925';
$REVISION = '$Revision: 1.95 $';

use strict;
use vars qw($VERSION);
use Carp;
use Socket;
use Symbol;
use Digest::MD5;
use Fcntl;
use POSIX qw(:errno_h);
use Scalar::Util qw(weaken);
use List::Util qw(max);

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
	$self->{outbuff} = "";
	$self->{state} ||= "write";
	$self->{paused} = 0 unless $self->{paused};
	$self->{families} = {};
	$self->{buffsize} = 65535;
	$self->{buffer} = \"";

	$self->connect($self->{peer}) if exists($self->{peer});

	return $self;
}

sub pause($) {
	my $self = shift;
	$self->{pause_queue} ||= [];
	$self->{paused} = 1;
}

sub unpause($) {
	my $self = shift;
	return unless $self->{paused};
	$self->{paused} = 0;

	$self->log_print(OSCAR_DBG_WARN, "Flushing pause queue");
	foreach my $item(@{$self->{pause_queue}}) {
		$self->log_printf(OSCAR_DBG_WARN, "Flushing SNAC 0x%04X/0x%04X", $item->{family}, $item->{subtype});
		$self->snac_put(%$item);
	}
	$self->log_print(OSCAR_DBG_WARN, "Pause queue flushed");

	delete $self->{pause_queue};
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
		if($snac{family} == -1 and exists($data{family})) {
			$snac{family} = $data{family};
		}

		if($self->{paused} and !$data{nopause}) {
			$self->log_printf(OSCAR_DBG_WARN, "Adding SNAC 0x%04X/0x%04X to pause queue", $snac{family}, $snac{subtype});
			push @{$self->{pause_queue}}, \%snac;
		} else {
			$self->log_printf(OSCAR_DBG_DEBUG, "Put SNAC 0x%04X/0x%04X: %s", $snac{family}, $snac{subtype}, $data{protobit});
			$self->snac_put(%snac);
		}
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

# We need to do non-buffered reading so that stdio's buffers don't screw up select, poll, etc.
# Thus, for efficiency, we do our own buffering.
# To prevent a single OSCAR conneciton from monopolizing processing time, for instance if it has
# a flood of incoming data wide enough that we never run out of stuff to read, we'll only fill
# the buffer once per call to process_one.
#
# no_reread value of 2 indicates that we should only read if we have to
sub read($$;$) {
	my($self, $len, $no_reread) = @_;
	$no_reread ||= 0;

	$self->{buffsize} ||= $len;
	my $buffsize = $self->{buffsize};
	$buffsize = $len if $len > $buffsize;
	my $readlen;
	if($no_reread == 2) {
		$readlen = $len - length(${$self->{buffer}});
	} else {
		$readlen = $buffsize - length(${$self->{buffer}});
	}

	if($readlen > 0 and $no_reread != 1) {
		my $buffer = "";
		my $nchars = sysread($self->{socket}, $buffer, $buffsize - length(${$self->{buffer}}));
		if(${$self->{buffer}}) {
			${$self->{buffer}} .= $buffer;
		} else {
			$self->{buffer} = \$buffer;
		}

		if(!${$self->{buffer}} and !defined($nchars)) {
			return "" if $! == EAGAIN;
			$self->log_print(OSCAR_DBG_NOTICE, "Couldn't read from socket: $!");
			$self->{sockerr} = 1;
			$self->disconnect();
			return undef;
		} elsif(!${$self->{buffer}} and $nchars == 0) { # EOF
			$self->log_print(OSCAR_DBG_NOTICE, "Got EOF on socket");
			$self->{sockerr} = 1;
			$self->disconnect();
			return undef;
		}
	}

	if(length(${$self->{buffer}}) < $len) {
		return "";
	} else {
		my $ret;
		delete $self->{buffsize};
		if(length(${$self->{buffer}}) == $len) {
			$ret = $self->{buffer};
			$self->{buffer} = \"";
		} else {
			$ret = \substr(${$self->{buffer}}, 0, $len, "");
		}
		$self->log_print_cond(OSCAR_DBG_PACKETS, sub { "Got '", hexdump($$ret), "'" });
		return $$ret;
	}
}

sub flap_get($;$) {
	my ($self, $no_reread) = @_;
	my $socket = $self->{socket};
	my ($buffer, $channel, $len);
	my $nchars;

	if(!$self->{buff_gotflap}) {
		my $header = $self->read(6, $no_reread);
		if(!defined($header)) {
			return undef;
		} elsif($header eq "") {
			return "";
		}

		$self->{buff_gotflap} = 1;
		(undef, $self->{channel}, undef, $self->{flap_size}) =
			unpack("CCnn", $header);
	}

	if($self->{flap_size} > 0) {
		my $data = $self->read($self->{flap_size}, $no_reread || 2);
		if(!defined($data)) {
			return undef;
		} elsif($data eq "") {
			return "";
		}

		$self->log_print_cond(OSCAR_DBG_PACKETS, sub { "Got ", hexdump($data) });
		delete $self->{buff_gotflap};
		return $data;
	} else {
		delete $self->{buff_gotflap};
		return "";
	}
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

	if($snac{family} and !$self->{families}->{$snac{family}}) {
		$self->log_printf(OSCAR_DBG_WARN, "Tried to send unsupported SNAC 0x%04X/0x%04X", $snac{family}, $snac{subtype});

		my $newconn = $self->{session}->connection_for_family($snac{family});
		if($newconn) {
			return $newconn->snac_put(%snac);
		} else {
			$self->{session}->crapout($self, "Couldn't find supported connection for SNAC 0x%04X/0x%04X", $snac{family}, $snac{subtype});
		}
	} else {
		$snac{channel} ||= 0+FLAP_CHAN_SNAC;
		confess "No family/subtype" unless exists($snac{family}) and exists($snac{subtype});

		if($self->{session}->{rate_manage_mode} != OSCAR_RATE_MANAGE_NONE and $self->{rate_limits}) {
			my $key = $self->{rate_limits}->{classmap}->{pack("nn", $snac{family}, $snac{subtype})};
			if($key) {
				my $rinfo = $self->{rate_limits}->{$key};
				if($rinfo) {
					$rinfo->{current_state} = max(
						$rinfo->{max},
						$self->{session}->_compute_rate($rinfo)
					);
					$rinfo->{last_time} = millitime() - $rinfo->{time_offset};
				}
			}
		}

		$self->flap_put($self->snac_encode(%snac), $snac{channel});
	}
}

sub snac_get($;$) {
	my($self, $no_reread) = @_;
	my $snac = $self->flap_get($no_reread) or return 0;
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

			require MIME::Base64;

			my $authen   =  $self->{session}->{proxy_username};
			   $authen  .= ":$self->{session}->{proxy_password}"  if $self->{session}->{proxy_password};
			   $authen   = encode_base64 $authen if $authen;

			my $request  = "CONNECT $host:$port HTTP/1.1\r\n";
			   $request .= "Proxy-Authorization: Basic $authen\r\n" if $authen;
			   $request .= "User-Agent: Net::OSCAR\r\n";
			   $request .= "\r\n";

			$self->{socket} = gensym;
			socket($self->{socket}, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
			if($self->{session}->{local_ip}) {
				bind($self->{socket}, sockaddr_in(0, inet_aton($self->{session}->{local_ip}))) or croak "Couldn't bind to desired IP: $!\n";
			}
			$self->set_blocking(0);

			my $addr = inet_aton($self->{session}{proxy_host}) or return $self->{session}->crapout($self, "Couldn't resolve $self->{session}{proxy_host}.");
			if(!connect($self->{socket}, sockaddr_in($self->{session}{proxy_port}, $addr))) {
				return $self->{session}->crapout($self, "Couldn't connect to $self->{session}{proxy_host}:$self->{session}{proxy_port}: $!")
				    unless $! == EINPROGRESS;
			}

			# TODO: I don't know what happens if authentication or connection fails
			#
			my $buffer;
			syswrite ($self->{socket}, $request); 
			sysread  ($self->{socket}, $buffer, 1024)
				or return $self->{session}->crapout($self, "Couldn't read from $self->{session}{proxy_host}:$self->{session}{proxy_port}: $!");

			return $self->{session}->crapout($self, "Couldn't connect to proxy: $self->{session}{proxy_host}:$self->{session}{proxy_port}: $!")
				unless $buffer =~ /connection\s+established/i;

			$self->set_blocking(0);
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

	binmode($self->{socket}) or return $self->{session}->crapout($self, "Couldn't set binmode: $!");
	return 1;
}

sub listen($$) {
	my($self, $port) = @_;
	my $temp;

	$self->{host} = $self->{local_addr} || "0.0.0.0";
	$self->{port} = $port;

	$self->log_print(OSCAR_DBG_NOTICE, "Listening.");
	if(defined($self->{session}->{proxy_type})) {
		die "Proxying not support for listening sockets.\n";
	} else {
		$self->{socket} = gensym;
		socket($self->{socket}, PF_INET, SOCK_STREAM, getprotobyname('tcp'));

		setsockopt($self->{socket}, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) or return $self->{session}->crapout($self, "Couldn't set listen socket options: $!");
		
		my $sockaddr = sockaddr_in($self->{session}->{local_port} || $port || 0, inet_aton($self->{session}->{local_ip} || 0));
		bind($self->{socket}, $sockaddr) or return $self->{session}->crapout("Couldn't bind to desired IP: $!");
		$self->set_blocking(0);
		listen($self->{socket}, SOMAXCONN) or return $self->{session}->crapout("Couldn't listen: $!");

		$self->{state} = "read";
		$self->{rv}->{ft_state} = "listening";
	}

	binmode($self->{socket}) or return $self->{session}->crapout("Couldn't set binmode: $!");
	return 1;
}



sub get_filehandle($) { shift->{socket}; }

# $read/$write tell us if select indicated readiness to read and/or write
# Ditto for $error
sub process_one($;$$$) {
	my($self, $read, $write, $error) = @_;
	my $snac;

	if($error) {
		$self->{sockerr} = 1;
		return $self->disconnect();
	}

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
			$self->{families} = {23 => 1};

			if(!$self->{session}->{svcdata}->{hashlogin}) {
				$self->proto_send(protobit => "initial_signon_request",
					protodata => {screenname => $self->{session}->{screenname}},
					nopause => 1
				);
			} else {
				$self->proto_send(protobit => "ICQ_signon_request",
					protodata => {signon_tlv($self->{session}, delete($self->{auth}))},
					nopause => 1
				);
			}
		} else {
			$self->log_print(OSCAR_DBG_NOTICE, "Sending BOS-Signon.");
			$self->proto_send(protobit => "BOS_signon",
				reqid => 0x01000000 | (unpack("n", substr($self->{auth}, 0, 2)))[0],
				protodata => {cookie => substr(delete($self->{auth}), 2)},
				nopause => 1
			);
		}
		$self->log_print(OSCAR_DBG_DEBUG, "SNAC time.");
		$self->{ready} = 1;
	} elsif($read) {
		my $no_reread = 0;
		while(1) {
			if(!$self->{session}->{svcdata}->{hashlogin}) {
				$snac = $self->snac_get($no_reread) or return 0;
				Net::OSCAR::Callbacks::process_snac($self, $snac);
			} else {
				my $data = $self->flap_get($no_reread) or return 0;
				$snac = {data => $data, reqid => 0, family => 0x17, subtype => 0x3};
				if($self->{channel} == FLAP_CHAN_CLOSE) {
					$self->{conntype} = CONNTYPE_LOGIN;
					$self->{family} = 0x17;
					$self->{subtype} = 0x3;
					$self->{data} = $data;
					$self->{reqid} = 0;
					$self->{reqdata}->[0x17]->{pack("N", 0)} = "";
					Net::OSCAR::Callbacks::process_snac($self, $snac);
				} else {
					my $snac = $self->snac_decode($data);
					if($snac) {
						Net::OSCAR::Callbacks::process_snac($self, $snac);
					} else {
						return 0;
					}
				}
			}
		} continue {
			$no_reread = 1;
		}
	}
}

sub ready($) {
	my($self) = shift;

	return if $self->{sentready}++;
	send_versions($self, 1);
	$self->unpause();
}

sub session($) { return shift->{session}; }

sub peer_ip($) {
	my($self) = @_;

	my $sockaddr = getpeername($self->{socket});
	my($port, $iaddr) = sockaddr_in($sockaddr);
	return inet_ntoa($iaddr);
}

sub local_ip($) {
	my($self) = @_;

	my $sockaddr = getsockname($self->{socket});
	my($port, $iaddr) = sockaddr_in($sockaddr);
	return inet_ntoa($iaddr);
}

1;
