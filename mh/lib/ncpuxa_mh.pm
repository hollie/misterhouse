
# This module is an interface for Misterhouse to access the CPU-XA, 
# Ocelot, and Leopard controlers from Applied Digital Inc: 
# http://www.appdig.com/adicon.html

# By David Norwood, dnorwood2@yahoo.com
#               for Misterhouse, http://www.misterhouse.net
#               by Bruce Winter and many contributors

# Requires cpuxad, part of the XALIB package by Mark A. Day available 
# here: http://members.home.net/ncherry/common/cpuxad
# The cpuxad daemon only runs on Unix/Linux. 
 
# To use this interface, add the following line to your mh.ini file:

# ncpuxa_port=localhost:2000

# Where localhost:2000 is the host and network port where cpuxad is
# running.


package ncpuxa_mh;


use ncpuxa;
use ControlX10::CM11;		# required for dim_level_convert 

my %controlsock;
my %monitorsock;
my $save_unit = 1;

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

	#Preset dim level for LM14A and Leviton units
	if (my ($house, $level) = $data =~ /^X([A-P])&P(\d+)$/) {
		$house = unpack('C', $house) - 65; #Get code from ASCII
		$level = int($level) - 1;
		ncpuxa::send_x10_leviton_level($controlsock{$hostport},
			$house, $save_unit, $level);
		return;
	}

	#X10 Unit code
	if (my ($house, $unit) = $data =~ /^X([A-P])([0-9A-G])$/) {
		$house = unpack('C', $house) - 65; #Get code from ASCII
		$unit = int($unit) - 1 if $unit =~ /[1-9]/;
		$unit = unpack('C', $unit) - 56 if $unit =~ /[A-G]/;
		$save_unit = $unit;
		ncpuxa::send_x10($controlsock{$hostport}, $house, $unit, 1);
		return;
	}
	
	#Standard X10 function
	if (my ($house, $func) = $data =~ /^X([A-P])([H-W])$/) {
		if    ($func eq 'L') {
			$func = 'M';
		}
		elsif ($func eq 'M') {
			$func = 'L';
		}
		$house = unpack('C', $house) - 65; #Get code from ASCII
		$func  = unpack('C', $func ) - 72 + 16; #Get code from ASCII
		ncpuxa::send_x10($controlsock{$hostport}, $house, $func, 1);
		return;
	}

	#Dim/Bright n-times
	if (my ($house, $sign, $percent) = $data =~ /^X([A-P])([\+\-])(\d+)$/) {
		$house = unpack('C', $house) - 65; #Get code from ASCII
		my $repeat = int($percent/6.5);
		$func = ($sign eq '-' ? "20" : "21");
		ncpuxa::send_x10($controlsock{$hostport}, $house, $func, $repeat);
		return;
	}
	
	#Send local IR
	if (my ($irnum) = $data =~ /^IRSlot([0-9]+)$/) {
		$irnum = int($irnum);
		ncpuxa::local_ir($controlsock{$hostport}, $irnum);
		return;
	}
	
	#Set Relay
	if (my ($relay, $state) = $data =~ /^OUTPUT([0-9]+)(high|low)$/i) {
		my $module = 1;
		$relay = int($relay);
		$state = ($state =~ /high/i ? "1" : "0");
		ncpuxa::set_relay($controlsock{$hostport}, $module, $relay, $state);
		return;
	}

	#Unimplemented
	print "ncpuxa_mh::send unimplemented command $data\n";
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
