
# This module is an interface for Misterhouse to access the CPU-XA, 
# Ocelot, and Leopard controlers from Applied Digital Inc: 
# http://www.appdig.com/adicon.html

# By David Norwood, dnorwood2@yahoo.com
#               for Misterhouse, http://www.misterhouse.net
#               by Bruce Winter and many contributors

# Requires cpuxad, part of the XALIB package by Mark A. Day.  The 
# ftp server for XALIB has been down for a while, so email me if you 
# need it.  I also have a patch to cpuxad to allow it to work with 
# this module.  The cpuxad daemon only runs on Unix/Linux. 
 
# To use this interface, add the following line to your mh.ini file:

# ncpuxa_port=localhost:2000

# Where localhost:2000 is the host and network port where cpuxad is
# running.


package ncpuxa_mh;


use ncpuxa;

my %controlsock;
my %monitorsock;

sub init {
	my $hostport = shift;
	my ($host, $port) = split(":", $hostport);
	$port = int($port);
	$controlsock{$hostport} = ncpuxa::cpuxa_connect($host, $port);
	$monitorsock{$hostport} = ncpuxa::cpuxa_connect($host, $port);
	ncpuxa::cpuxa_monitor($monitorsock{$hostport});
}

sub send {
	my $hostport = shift;
	my $data = shift;

	if (my ($house, $unit, $func) = $data =~ /^X([A-P])([0-9A-G]).(.*)/) {
		my $repeat = 1;
		$house = unpack('C', $house) - 65; #Get code from ASCII
		$unit = int($unit) - 1 if $unit =~ /[1-9]/;
		$unit = unpack('C', $unit) - 56 if $unit =~ /[A-G]/;
		{
			$func = 18, last if $func eq "J"; #On
			$func = 19, last if $func eq "K"; #Off
			$func = 21, last if $func eq "L"; #Brighten once
			$func = 20, last if $func eq "M"; #Dim once

			#Dim n-times
			$func = 20, $repeat = int($1/6.5), last if $func =~ /^\-([0-9]*)/;

			#Brighten n-times
			$func = 21, $repeat = int($1/6.5), last if $func =~ /^\+([0-9]*)/;


			#else (if it falls through to here...
			print "ncpuxa_mh::send X10 data $data unimplemented\n";
			return;
		}
		ncpuxa::send_x10($controlsock{$hostport}, $house, $unit, 1);
		ncpuxa::send_x10($controlsock{$hostport}, $house, $func, $repeat);
		return;
	}
	elsif (my ($irnum) = $data =~ /^IRSlot([0-9]+)$/) {
		$irnum = int($irnum);
		ncpuxa::local_ir($controlsock{$hostport}, $irnum);
		return;
	}
	elsif (my ($relay, $state) = $data =~ /^OUTPUT([0-9]+)(high|low)/i) {
		my $module = 1;
		$relay = int($relay);
		$state = ($state =~ /high/i ? "1" : "0");
		ncpuxa::set_relay($controlsock{$hostport}, $module, $relay, $state);
		return;
	}
	else {
		# Unimplemented
		print "ncpuxa_mh::send unimplemented command $data\n";
		return;
	}

	# not reached
	return;
}

my $ret;
my $data;
my $code;

my %funcs = qw (
	1  1  2  2  3  3  4  4  5  5  6  6  7  7  8  8  9  9  
	10  A  11  B  12  C  13  D  14  E  15  F  16  G 
	"All On"  H  "All Off"  I  On  J  Off  K  Bright  L  Dim  M 
);

sub read {
	my $hostport = shift;
	my $data;

	return unless $data = ncpuxa::cpuxa_process_monitor($monitorsock{$hostport});
	if (my ($house, $func) = $data =~ /^X-10 Rx: ([A-P])\/(.*)/) {
		$code = "X" . $house . $funcs{$func};
		return $code;
	}
	if (my ($irnum) = $data =~ /^IR Rx: #([0-9]+)/) {
		$code = "IRSlot" . $irnum;
		return $code;
	}
}


1;
