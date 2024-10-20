=pod

Net::OSCAR::Utility -- internal utility functions for Net::OSCAR

=cut

package Net::OSCAR::Utility;

$VERSION = '1.925';
$REVISION = '$Revision: 1.29 $';

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Digest::MD5 qw(md5);
use Carp;

use Net::OSCAR::TLV;
use Net::OSCAR::Common qw(:loglevels);
use Net::OSCAR::Constants;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
	randchars log_print log_printf log_print_cond log_printf_cond hexdump normalize tlv_decode tlv_encode send_error bltie
	signon_tlv encode_password send_versions hash_iter_reset millitime
);

eval {
	require Time::HiRes;
};
our $finetime = $@ ? 0 : 1;


sub millitime() {
	my $time = $finetime ? Time::HiRes::time() : time();
	return int($time * 1000);
}

sub randchars($) {
	my $count = shift;
	my $retval = "";
	for(my $i = 0; $i < $count; $i++) { $retval .= chr(int(rand(256))); }
	return $retval;
}


sub log_print($$@) {
	my($obj, $level) = (shift, shift);
	my $session = exists($obj->{session}) ? $obj->{session} : $obj;
	return unless defined($session->{LOGLEVEL}) and $session->{LOGLEVEL} >= $level;

	my $message = "";
	$message .= $obj->{description}. ": " if $obj->{description};
	$message .= join("", @_). "\n";

	if($session->{callbacks}->{log}) {
		$session->callback_log($level, $message);
	} else {
		$message = "(".$session->{screenname}.") $message" if $session->{SNDEBUG};
		print STDERR $message;
	}
}

sub log_printf($$@) {
	my($obj, $level, $fmtstr) = (shift, shift, shift);

	$obj->log_print($level, sprintf($fmtstr, @_));
}

sub log_printf_cond($$&) {
	my($obj, $level, $sub) = @_;
	my $session = exists($obj->{session}) ? $obj->{session} : $obj;
	return unless defined($session->{LOGLEVEL}) and $session->{LOGLEVEL} >= $level;

	log_printf($obj, $level, &$sub);
}

sub log_print_cond($$&) {
	my($obj, $level, $sub) = @_;
	my $session = exists($obj->{session}) ? $obj->{session} : $obj;
	return unless defined($session->{LOGLEVEL}) and $session->{LOGLEVEL} >= $level;

	log_print($obj, $level, &$sub);
}

sub hexdump($;$) {
	my $stuff = shift;
	my $forcehex = shift || 0;
	my $retbuff = "";
	my @stuff;

	return "" unless defined($stuff);
	for(my $i = 0; $i < length($stuff); $i++) {
		push @stuff, substr($stuff, $i, 1);
	}

	return $stuff unless $forcehex or grep { $_ lt chr(0x20) or $_ gt chr(0x7E) } @stuff;
	while(@stuff) {
		my $i = 0;
		$retbuff .= "\n\t";
		my @currstuff = splice(@stuff, 0, 16);

		foreach my $currstuff(@currstuff) {
			$retbuff .= " " unless $i % 4;
			$retbuff .= " " unless $i % 8;
			$retbuff .= sprintf "%02X ", ord($currstuff);
			$i++;
		}
		for(; $i < 16; $i++) {
			$retbuff .= " " unless $i % 4;
			$retbuff .= " " unless $i % 8;
			$retbuff .= "   ";
		}

		$retbuff .= "  ";
		$i = 0;
		foreach my $currstuff(@currstuff) {
			$retbuff .= " " unless $i % 4;
			$retbuff .= " " unless $i % 8;
			if($currstuff ge chr(0x20) and $currstuff le chr(0x7E)) {
				$retbuff .= $currstuff;
			} else {
				$retbuff .= ".";
			}
			$i++;
		}
	}
	return $retbuff;
}

sub normalize($) {
	my $temp = shift;
	$temp =~ tr/ //d if $temp;
	return $temp ? lc($temp) : "";
}

sub tlv_decode($;$) {
	my($tlv, $tlvcnt) = @_;
	my($type, $len, $value, %retval);
	my $currtlv = 0;
	my $strpos = 0;

	my $retval = tlv;

	$tlvcnt = 0 unless $tlvcnt;
	while(length($tlv) >= 4 and (!$tlvcnt or $currtlv < $tlvcnt)) {
		($type, $len) = unpack("nn", $tlv);
		$len = 0x2 if $type == 0x13;
		$strpos += 4;
		substr($tlv, 0, 4) = "";
		if($len) {
			($value) = substr($tlv, 0, $len, "");
		} else {
			$value = "";
		}
		$strpos += $len;
		$currtlv++ unless $type == 0;
		$retval->{$type} = $value;
	}

	return $tlvcnt ? ($retval, $strpos) : $retval;
}

sub tlv_encode($) {
	my $tlv = shift;
	my($buffer, $type, $value) = ("", 0, "");

	confess "You must use a tied Net::OSCAR::TLV hash!" unless defined($tlv) and ref($tlv) eq "HASH" and defined(%$tlv) and defined(tied(%$tlv)) and tied(%$tlv)->isa("Net::OSCAR::TLV");
	while (($type, $value) = each %$tlv) {
		$value ||= "";
		$buffer .= pack("nna*", $type, length($value), $value);

	}
	return $buffer;
}

sub send_error($$$$$;@) {
	my($oscar, $connection, $error, $desc, $fatal, @reqdata) = @_;
	$desc = sprintf $desc, @reqdata;
	$oscar->callback_error($connection, $error, $desc, $fatal);
}

sub bltie(;$) {
	my $retval = {};
	tie %$retval, "Net::OSCAR::Buddylist", @_;
	return $retval;
}

sub signon_tlv($;$$) {
	my($session, $password, $key) = @_;

	my %protodata = (
		screenname => $session->{screenname},
		clistr => $session->{svcdata}->{clistr},
		supermajor => $session->{svcdata}->{supermajor},
		major => $session->{svcdata}->{major},
		minor => $session->{svcdata}->{minor},
		subminor => $session->{svcdata}->{subminor},
		build => $session->{svcdata}->{build},
		subbuild => $session->{svcdata}->{subbuild},
	);

	if($session->{svcdata}->{hashlogin}) {
		$protodata{password} = encode_password($session, $password);
	} else {
		if($session->{auth_response}) {
			$protodata{auth_response} = delete $session->{auth_response};
		} else {
			# As of AIM 5.5, the password can be MD5'd before
			# going into the things-to-cat-together-and-MD5.
			# This lets applications that store AIM passwords
			# store the MD5'd password.  We do it by default
			# because, well, AIM for Windows does.  We support
			# the old way to preserve compatibility with
			# our auth_challenge/auth_response API.

			$protodata{pass_is_hashed} = "";
			my $hashpass = $session->{pass_is_hashed} ? $password : md5($password);

			$protodata{auth_response} = encode_password($session, $hashpass, $key);
		}
	}

	return %protodata;
}

sub encode_password($$;$) {
	my($session, $password, $key) = @_;

	if(!$session->{svcdata}->{hashlogin}) { # Use new SNAC-based method
		my $md5 = Digest::MD5->new;

		$md5->add($key);
		$md5->add($password);
		$md5->add("AOL Instant Messenger (SM)");
		return $md5->digest();
	} else { # Use old roasting method.  Courtesy of SDiZ Cheng.
		my $ret = "";
		my @pass = map {ord($_)} split(//, $password);

		my @encoding_table = map {hex($_)} qw(
			F3 26 81 C4 39 86 DB 92 71 A3 B9 E6 53 7A 95 7C
		);

		for(my $i = 0; $i < length($password); $i++) {
			$ret .= chr($pass[$i] ^ $encoding_table[$i]);
		}

		return $ret;
	}
}

sub send_versions($$;$) {
	my($connection, $send_tools, $server) = @_;
	my $conntype = $connection->{conntype};
	my @services;

	if($conntype != CONNTYPE_BOS and !$server) {
		@services = (1, $conntype);
	} else {
		@services = sort {$b <=> $a} grep {not OSCAR_TOOLDATA()->{$_}->{nobos}} keys %{OSCAR_TOOLDATA()};
	}

	my %protodata = (service => []);
	foreach my $service (@services) {
		my %service = (
			service_id => $service,
			service_version => OSCAR_TOOLDATA->{$service}->{version}
		);
		if($send_tools) {
			$service{tool_id} = OSCAR_TOOLDATA->{$service}->{toolid};
			$service{tool_version} = OSCAR_TOOLDATA->{$service}->{toolversion};
		}

		push @{$protodata{service}}, \%service;
	}

	if($send_tools) {
		$connection->proto_send(protobit => "set_tool_versions", protodata => \%protodata, nopause => 1);
	} elsif($server) {
		$connection->proto_send(protobit => "host_versions", protodata => \%protodata, nopause => 1);
	} else {
		$connection->proto_send(protobit => "set_service_versions", protodata => \%protodata, nopause => 1);
	}
}

# keys(%foo) in void context, the standard way of reseting
# a hash iterator, appears to leak memory.
#
sub hash_iter_reset($) {
	while((undef, undef) = each(%{$_[0]})) {}
}

1;
