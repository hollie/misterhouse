=pod

Net::OSCAR::Connection::Direct -- OSCAR direct connections

=cut

package Net::OSCAR::Connection::Direct;

$VERSION = '1.925';
$REVISION = '$Revision: 1.13 $';

use strict;
use Carp;

use vars qw(@ISA $VERSION $REVISION);
use Socket;
use Symbol;
use Net::OSCAR::Common qw(:all);
use Net::OSCAR::Constants;
use Net::OSCAR::Utility;
use Net::OSCAR::XML;
@ISA = qw(Net::OSCAR::Connection);

sub process_one($;$$$) {
	my($self, $read, $write, $error) = @_;
	my $snac;

	if($error) {
		$self->{sockerr} = 1;
		$self->disconnect();

		if($self->{rv}->{ft_state} eq "connecting" or $self->{rv}->{ft_state} eq "connected") {
			$self->log_print(OSCAR_DBG_INFO, "Couldn't connect to rendezvous peer; revising rendezvous.");
			$self->{session}->rendezvous_revise($self->{rv}->{cookie});
		}

		return;
	}

	#$self->log_printf(OSCAR_DBG_DEBUG,
	#	"Called process_one on direct connection: st=%s, fts=%s, dir=%s, acp=%s, r=$read, w=$write, e=$error",
	#	$self->{state}, $self->{rv}->{ft_state}, $self->{rv}->{direction}, $self->{rv}->{accepted}
	#);
	if($read and $self->{rv}->{ft_state} eq "listening") {
		my $newsock = gensym();

		if(accept($newsock, $self->{socket})) {
			$self->log_print(OSCAR_DBG_DEBUG, "Accepted incoming connection.");
			$self->{session}->callback_connection_changed($self, "deleted");
			close($self->{socket});
			$self->{socket} = $newsock;
			$self->set_blocking(0);

			if($self->{rv}->{direction} eq "send") {
				$self->{state} = "write";
			} else {
				$self->{state} = "read";
			}

			$self->{rv}->{ft_state} = "connected";
			$self->{session}->callback_connection_changed($self, $self->{state});

			return 1;
		} else {
			$self->log_print(OSCAR_DBG_WARN, "Failed to accept incoming connection: $!");
			return 0;
		}
	} elsif($write and $self->{rv}->{ft_state} eq "proxy_connect") {
		$self->log_print(OSCAR_DBG_DEBUG, "Connected to proxy.");
		$self->{connected} = 1;
		my $ret;

		if($self->{sent_proxy_init}++) {
			my $packet = protoparse($self->{session}, "direct_connect_proxy_init")->pack(
				msg_type => 2,
				screenname => $self->{rv}->{peer},
				cookie => $self->{rv}->{cookie},
				capability => OSCAR_CAPS()->{filexfer}->{value}
			);
			$ret = $self->write(pack("n", length($packet)) . $packet);
		} else {
			$ret = $self->write();
		}

		return $ret unless $ret;

		delete $self->{sent_proxy_init};
		$self->{rv}->{ft_state} = "proxy_ack";
		$self->{state} = "read";
		$self->{session}->callback_connection_changed($self, "read");
	} elsif($read and $self->{rv}->{ft_state} eq "proxy_ack") {
		my $ret = $self->get_proxy_header("direct_connect_proxy_reply");
		return $ret unless $ret;

		if($ret->{magic} != 1098 or $ret->{msg_type} != 3) {
			$self->{sockerr} = 1;
			$self->disconnect();

			$self->log_print(OSCAR_DBG_INFO, "Bad response from proxy; revising rendezvous.");
			$self->{session}->rendezvous_revise($self->{rv}->{cookie});

			return undef;
		} else {
			$self->{rv}->{ft_state} = "proxy_connected";
			$self->{state} = "read";
			$self->{session}->callback_connection_changed($self, "read");

		        my %protodata = (
				status => "accept",
				cookie => $self->{rv}->{cookie},
				capability => OSCAR_CAPS()->{$self->{rv}->{type}} ? OSCAR_CAPS()->{$self->{rv}->{type}}->{value} : $self->{rv}->{type},
				client_1_ip => $ret->{ip},
				port => $ret->{port}
			);
			$self->{session}->send_message($self->{rv}->{sender}, 2, protoparse($self->{session}, "rendezvous_IM")->pack(%protodata));
		}
	} elsif($read and $self->{rv}->{ft_state} eq "proxy_connect") {
		my $ret = $self->get_proxy_header();
		return $ret unless $ret;

		if($ret->{magic} != 1098 or $ret->{msg_type} != 5) {
			$self->{sockerr} = 1;
			$self->disconnect();

			$self->log_print(OSCAR_DBG_INFO, "Bad response from proxy; revising rendezvous.");
			$self->{session}->rendezvous_revise($self->{rv}->{cookie});

			return undef;
		} else {
			$self->log_print(OSCAR_DBG_DEBUG, "Rendezvous peer connected to proxy.");
			$self->{rv}->{ft_state} = "connected";
			if($self->{rv}->{direction} eq "send") {
				$self->{state} = "write";
			} else {
				$self->{state} = "read";
			}

			$self->{session}->callback_connection_changed($self, $self->{state});
		}
	} elsif($write and $self->{rv}->{ft_state} eq "connecting") {
		$self->log_print(OSCAR_DBG_DEBUG, "Connected.");
		$self->{connected} = 1;

	        my %protodata;
	        $protodata{status} = "accept";
	        $protodata{cookie} = $self->{rv}->{cookie};
		$protodata{capability} = OSCAR_CAPS()->{$self->{rv}->{type}} ? OSCAR_CAPS()->{$self->{rv}->{type}}->{value} : $self->{rv}->{type};
		$self->{session}->send_message($self->{rv}->{sender}, 2, protoparse($self->{session}, "rendezvous_IM")->pack(%protodata));

		$self->{rv}->{ft_state} = "connected";
		$self->{rv}->{accepted} = 1;
		if($self->{rv}->{direction} eq "receive") {
			$self->{state} = "read";
			$self->{session}->callback_connection_changed($self, $self->{state});
		}
	} elsif($write and $self->{rv}->{ft_state} eq "connected") {
		if($self->{rv}->{direction} eq "send") {
			return 1 unless $self->{rv}->{accepted};
		}

		$self->log_print(OSCAR_DBG_DEBUG, "Sending OFT header (SYN).");
		my $ret;
		if($self->{sent_oft_header}) {
			$self->log_print(OSCAR_DBG_DEBUG, "Flushing buffer");
			$ret = $self->write(); # Flush buffer
		} else {
			$self->log_print(OSCAR_DBG_DEBUG, "Sending initial header");
			$self->{sent_oft_header} = 1;
			if($self->{rv}->{direction} eq "send" and !$self->{got_files}) {
				$self->{checksum} = $self->checksum($self->{rv}->{data}->[0]);
				$self->{byte_count} = $self->{rv}->{total_size};
				$self->{bytes_left} = length($self->{rv}->{data}->[0]);
				$self->{filename} = $self->{rv}->{filenames}->[0];
			}
			$ret = $self->send_oft_header();
		}
		return $ret unless $ret;

		if($self->{rv}->{direction} eq "receive") {
			if($self->{rv}->{file_count} == 1 or ($self->{sent_oft_header} and $self->{sent_oft_header} >= 2)) {
				$self->{rv}->{ft_state} = "data";
			} else {
				$self->log_print(OSCAR_DBG_DEBUG, "Sending second header.");
				$self->{sent_oft_header} = 2;
				$ret = $self->send_oft_header();
				return $ret unless $ret;
				$self->{rv}->{ft_state} = "data";
			}
		}

		delete $self->{sent_oft_header};
		$self->{state} = "read";
		$self->{session}->callback_connection_changed($self, "read");
	} elsif($read and $self->{rv}->{ft_state} eq "connected") {
		$self->log_print(OSCAR_DBG_DEBUG, "Getting OFT header");
		my $ret = $self->get_oft_header();
		return $ret unless $ret;

		if($self->{rv}->{direction} eq "send") {
			$self->{rv}->{ft_state} = "data";
		} elsif($self->{got_files}) {
			$self->{sent_oft_header} = 2;
			$self->log_print(OSCAR_DBG_DEBUG, "Sending second header.");
			$ret = $self->send_oft_header();
			if($ret) {
				delete $self->{sent_oft_header};
				$self->{rv}->{ft_date} = "data";
				$self->{state} = "read";
				$self->{session}->callback_connection_changed($self, "read");
				return;
			}
		}

		$self->{state} = "write";
		$self->{session}->callback_connection_changed($self, "write");
	} elsif($self->{rv}->{ft_state} eq "data") {
		my $ret;

		if($write and $self->{rv}->{direction} eq "send") {
			$self->log_print(OSCAR_DBG_DEBUG, "Sending data");
			if($self->{sent_data}++) {
				$ret = $self->write();
			} else {
				$ret = $self->write($self->{rv}->{data}->[0]);
			}

			if($ret) {
				$self->log_print(OSCAR_DBG_DEBUG, "Done sending data");

				shift @{$self->{rv}->{data}};
				shift @{$self->{rv}->{filenames}};
				$self->{sent_data} = 0;

				$self->{rv}->{ft_state} = "fin";
				$self->{state} = "read";
				$self->{session}->callback_connection_changed($self, "read");
			} else {
				return $ret;
			}
		} elsif($read and $self->{rv}->{direction} eq "receive") {
			$self->log_printf(OSCAR_DBG_DEBUG, "Receiving %d bytes of data", $self->{read_size});
			if($self->{got_data}++) {
				$self->log_print(OSCAR_DBG_DEBUG, "Getting more data");
				$ret = $self->read();
			} else {
				$self->log_print(OSCAR_DBG_DEBUG, "Doing initial read");
				$ret = $self->read($self->{read_size});
			}

			if($ret) {
				$self->log_printf(OSCAR_DBG_DEBUG, "Got complete file, %d bytes.", length($ret));

				$self->{rv}->{data} ||= [];
				push @{$self->{rv}->{data}}, $ret;
				shift @{$self->{rv}->{filenames}};
				$self->{bytes_recv} = length($ret);
				$self->{got_data} = 0;
				$self->{received_checksum} = $self->checksum($ret);

				if($self->{received_checksum} != $self->{checksum}) {
					$self->log_printf(OSCAR_DBG_WARN, "Checksum mismatch: %lu/%lu", $self->{checksum}, $self->{received_checksum});
					$self->log_print(OSCAR_DBG_WARN, "Data: ", hexdump($ret));
					$self->{sockerr} = 1;
					$self->disconnect();
					return undef;
				} else {
					$self->log_print(OSCAR_DBG_WARN, "Data: ", hexdump($ret));
				}

				$self->{rv}->{ft_state} = "fin";
				$self->{state} = "write";
				$self->{session}->callback_connection_changed($self, "write");
			} else {
				return $ret;
			}
		}
	} elsif($self->{rv}->{ft_state} eq "fin") {
		if($read and $self->{rv}->{direction} eq "send") {
			$self->log_print(OSCAR_DBG_DEBUG, "Getting OFT fin header");
			my $ret = $self->get_oft_header();
			return $ret unless $ret;

			if(@{$self->{rv}->{data}}) {
				$self->{rv}->{ft_state} = "connected";
				$self->{state} = "write";
				$self->{session}->callback_connection_changed($self, "write");
			} else {
				$self->disconnect();
			}

			return 1;
		} elsif($write and $self->{rv}->{direction} eq "receive") {
			$self->log_print(OSCAR_DBG_DEBUG, "Sending OFT fin header");
			my $ret = $self->send_oft_header();
			return $ret unless $ret;

			if(++$self->{got_files} < $self->{rv}->{file_count}) {
				$self->{rv}->{ft_state} = "connected";
				$self->{state} = "read";
				$self->{session}->callback_connection_changed($self, "read");
			} else {
				$self->disconnect();
			}
			return 1;
		}
	}
}

sub send_oft_header($) {
	my $self = shift;

	my $total_size = 0;
	$total_size += length($_) foreach @{$self->{rv}->{data}};

	my $type;
	my $cookie;
	if($self->{rv}->{ft_state} eq "connected" and ($self->{sent_oft_header} and $self->{sent_oft_header} != 2)) {
		if($self->{rv}->{direction} eq "send") {
			$type = 0x101;
			$cookie = chr(0) x 8;
		} else {
			$type = 0x202;
			$cookie = $self->{rv}->{cookie};
		}
	} else {
		$type = 0x204;
		$cookie = $self->{rv}->{cookie};
	}

	my %protodata = (
		type => $type,
		cookie => $cookie,
		file_count => $self->{rv}->{file_count},
		files_left => scalar(@{$self->{rv}->{data}}),
		byte_count => $self->{byte_count},
		bytes_left => $self->{bytes_left},
		mtime => time(),
		ctime => 0,
		bytes_received => $self->{bytes_recv},
		checksum => $self->{checksum},
		received_checksum => $self->{received_checksum},
		filename => $self->{filename}
	);
	$self->write(protoparse($self->{session}, "file_transfer_header")->pack(%protodata));
}

sub get_oft_header($) {
	my $self = shift;

	my $header = $self->read(6);
	return $header unless $header;
	my($magic, $length) = unpack("a4 n", $header);

	if($magic ne "OFT2") {
		$self->log_print(OSCAR_DBG_WARN, "Got unexpected data while reading file transfer header!");
                $self->{sockerr} = 1;
                $self->disconnect();
		return undef;
	}

	my $data = $self->read($length - 6);
	return $data unless $data;
	
	my %protodata = protoparse($self->{session}, "file_transfer_header")->unpack($header . $data);
	if($self->{rv}->{direction} eq "receive") {
		if(
		  $protodata{file_count} != $self->{rv}->{file_count} or
		  $protodata{byte_count} != $self->{rv}->{total_size}
		) {
			$self->log_print(OSCAR_DBG_WARN, "Rendezvous header data doesn't match initial proposal!");
			$self->{sockerr} = 1;
			$self->disconnect();
			return undef;
		} else {
			$self->{read_size} = $protodata{bytes_left};
			$self->{checksum} = $protodata{checksum};
			$self->{byte_count} = $protodata{byte_count};
			$self->{bytes_left} = $protodata{bytes_left};
			$self->{filename} = $protodata{filename};
		}
	} else {
		if($protodata{cookie} ne $self->{rv}->{cookie}) {
			$self->log_print(OSCAR_DBG_WARN, "Rendezvous header cookie doesn't match initial proposal!");
			$self->{sockerr} = 1;
			$self->disconnect();
			return undef;
		}
	}

	$self->log_print(OSCAR_DBG_DEBUG, "Got OFT header.");
	return 1;
}

# Adopted from Gaim's implementation
sub checksum($$) {
	my($self, $part) = @_;
	my $check = sprintf("%lu", (0xFFFF0000 >> 16) & 0xFFFF);

	for(my $i = 0; $i < length($part); $i++) {
		my $oldcheck = $check;

		my $byte = ord(substr($part, $i, 1));
		my $val = ($i & 1) ? $byte : ($byte << 8);
		$check -= $val;
		$check = sprintf("%lu", $check);

		if($check > $oldcheck) {
			$check--;
			$check = sprintf("%lu", $check);
		}
	}

	$check = (($check & 0x0000FFFF) + ($check >> 16));
	$check = (($check & 0x0000FFFF) + ($check >> 16));
	$check = $check << 16;

	return sprintf("%lu", $check);
}

sub get_proxy_header($;$) {
	my ($self, $protobit) = @_;
	my $socket = $self->{socket};
	my ($buffer, $len);
	my $nchars;
	$protobit ||= "direct_connect_proxy_hdr";

	if(!$self->{buff_gotproxy}) {
		my $header = $self->read(2);
		if(!defined($header)) {
			return undef;
		} elsif($header eq "") {
			return "";
		}

		$self->{buff_gotproxy} = 2;
		($self->{proxy_size}) = unpack("n", $header);
	}

	if($self->{proxy_size} > 0) {
		my $data = $self->read($self->{proxy_size}, 2);
		if(!defined($data)) {
			return undef;
		} elsif($data eq "") {
			return "";
		}

		$self->log_print_cond(OSCAR_DBG_PACKETS, sub { "Got ", hexdump($data) });
		delete $self->{buff_gotproxy};
		return {protoparse($self->{session}, $protobit)->unpack($data)};
	} else {
		delete $self->{buff_gotproxy};
		return "";
	}
}

1;
