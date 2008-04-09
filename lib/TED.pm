=begin comment
# $Date: 2008-03-14 22:43:50 -0400 (Fri, 14 Mar 2008) $
# $Revision: 1394 $

From David Satterfield <david_misterhouse@yahoo.com>

# Serial port that the RZC0P is connected to. Put this in your mh.private.ini.
TED_serial_port = /dev/ttyUSB0

Then, add this to your user code (I put it in ted.pl)
use TED;
$ted_interface = new TED;

That's it! Your %Electric hash should start getting filled in.

Known Issues:
It seems that TED packets can vary in size. This module only handles 280 byte packets at this point.

=cut

use strict;
use warnings;

package TED;

@TED::ISA=('Serial_Item');

my $portname = 'TED';

sub new {

    my ($class, $port_name)=@_;
    $port_name = 'TED' if !$port_name;
    $main::config_parms{"TED_break"} = "\cP\cC";

    my $self = {};
    $self->{port_name} = $port_name;

    bless $self, $class;

    &::MainLoop_pre_add_hook(\&TED::check_for_data,   1, $self);
    $self->{update_time} = time;
    $self->{good_packet_time} = time;

    return $self;
}

sub serial_startup {
    my $port  = $main::config_parms{TED_serial_port};
    &::serial_port_create($portname, $port, '19200', 'none', 'record');
}

sub check_for_data {
    my ($self) = @_;

    # check for data
    &main::check_for_generic_serial_data($portname);

    my $time = time;

    if ($main::Serial_Ports{$portname}{data_record}) {
	# go get and process the data
	&process_incoming_data($self);
	$self->{update_time} = $time;
    }
    
    if ($time > ($self->{update_time}+10)) {
	&::print_log("TED: Haven't heard from ted in 10 seconds, is something wrong?");
	return;
#	my $port = $::Serial_Ports{$portname}{port};
#	my $serial_port = $::Serial_Ports{object_by_port}{$port};
#	$serial_port->close();
#	&::serial_port_create($portname, $port, '19200', 'none', 'record');
    }

    if (($time > ($self->{good_packet_time}+30)) and 
	($time > ($self->{squawk_time}+10))) {
	$self->{squawk_time} = $time;
	&::print_log("TED: Haven't gotten a good packet from ted in 30 seconds, is something wrong? time: $time gpt:$self->{good_packet_time} st:$self->{squawk_time}") unless $::Startup;
    }
}

sub process_incoming_data {
    my ($self)=@_;

    my $input=$main::Serial_Ports{$portname}{data_record};

    my $hex = unpack "H*", $input;

    my @pkt=unpack("C*", $input);
    my $tedchars = $#pkt+3;
    print "TED chars: $tedchars\n" if $main::Debug{ted};

    my $output;
    foreach my $i (@pkt) {
	my $char=sprintf "%x ", $i;
	$output.=$char;
    }

    my $tedstr = substr($input,113,4);
    my $start = substr($input,0,2);    

    my @values = split (/ /, $output);

    for my $i (0..13) {
	my $line_index = $i*20;
	my $prline = '';
	for my $j (0..19) {
	    my $char_index = $line_index + $j;
	    if ($char_index < 278) {
		my $char = $values[$char_index];
		$prline .= $char . " ";
	    }
	}
	print "$line_index:$prline\n" if $main::Debug{ted};
    }

    if (($start eq "\cP\cD") and ($tedstr eq "TED ") and $#values == 277) {
        $main::Electric{CurrentRate} = (($pkt[85] * 256) + $pkt[84])/10000;
        $main::Electric{SalesTax}    = (($pkt[105] * 256) + $pkt[104])/10000;
        $main::Electric{MeterRead}   = $pkt[106] + 1;
	$main::Electric{Calibrate}   = (($pkt[108] * 256) + $pkt[107])/1000;
	$main::Electric{HouseCode}   = $pkt[110]; # good
        $main::Electric{LoValarm}    = (($pkt[131] * 256) + $pkt[130])/10; 
        $main::Electric{DlrPkKwHAlarm} = (($pkt[123] * 256) + $pkt[122])/100;
        $main::Electric{PkKwAlarm}    = (($pkt[125] * 256) + $pkt[124])/100;
        $main::Electric{DlrMthAlarm} = (($pkt[127] * 256) + $pkt[126])/10; 
        $main::Electric{KwMtdAlarm}  = (($pkt[129] * 256) + $pkt[128]); 
        $main::Electric{HiValarm}    = (($pkt[133] * 256) + $pkt[132])/10; 
        $main::Electric{LoVrmsTdy}   = (($pkt[135] * 256) + $pkt[134])/10; 
        $main::Electric{stLoVtimTdy} = &get_time((($pkt[137] * 256) + $pkt[136])); 
	$main::Electric{HiVrmsTdy}   = (($pkt[139] * 256) + $pkt[138])/10; 
	$main::Electric{stHiVtimTdy} = &get_time((($pkt[141] * 256) + $pkt[140])); 
	$main::Electric{HiVrmsMtd}   = (($pkt[146] * 256) + $pkt[145])/10; 
	$main::Electric{KwPeakTdy}   = (($pkt[149] * 256) + $pkt[148])/100; 
	$main::Electric{DlrPeakTdy}  = (($pkt[151] * 256) + $pkt[150])/100;
	$main::Electric{KwPeakMtd}   = (($pkt[153] * 256) + $pkt[152])/100; 
	$main::Electric{DlrPeakMtd}  = (($pkt[155] * 256) + $pkt[154])/100;
	$main::Electric{WattTdySum}  = (($pkt[163] * 256 * 256 * 256) + 
					($pkt[162] * 256 * 256) +
					($pkt[161] * 256) + 
					($pkt[160]));
	$main::Electric{KwhMtdCnt}   = (($pkt[165] * 256) + $pkt[164]);
	$main::Electric{KWNow}       = (($pkt[250] * 256) + $pkt[249])/100;
        $main::Electric{DlrNow}      = (($pkt[252] * 256) + $pkt[251])/100;
	$main::Electric{VrmsNowDsp}  = (($pkt[254] * 256) + $pkt[253])/10;
	$main::Electric{DlrMtd}      = (($pkt[256] * 256) + $pkt[255])/10;
	$main::Electric{DlrProj}     = (($pkt[258] * 256) + $pkt[257])/10;
        $main::Electric{KWProj}      = (($pkt[260] * 256) + $pkt[259]);

	if ($main::Debug{ted}) {
	    print "HouseCode:$main::Electric{HouseCode}\n";
	    print "Calibration:${main::Electric{Calibrate}}%\n";
	    print "Meter Read Day:$main::Electric{MeterRead}\n";
	    print "KWNow:$main::Electric{KWNow}\n";
	    print "VrmsNowDsp:$main::Electric{VrmsNowDsp}\n";
	    print "Current Rate: $main::Electric{CurrentRate}\n";
	    print "LoVrmsTdy: $main::Electric{LoVrmsTdy} at $main::Electric{stLoVtimTdy}\n";
	    print "HiVrmsTdy: $main::Electric{HiVrmsTdy} at $main::Electric{stHiVtimTdy}\n";
	    print "HiVrmsMtd: $main::Electric{HiVrmsMtd}\n";
	    print "DlrPeakTdy: $main::Electric{DlrPeakTdy}\n";
	    print "KwPeakMtd: $main::Electric{KwPeakMtd}\n";
	    print "KwPeakTdy: $main::Electric{KwPeakTdy}\n";
	    print "DlrPeakMtd: $main::Electric{DlrPeakMtd}\n";
	    print "WattTdySum: $main::Electric{WattTdySum}\n";
	    print "KwhMtdCnt: $main::Electric{KwhMtdCnt}\n";
	    print "DlrNow: $main::Electric{DlrNow}\n";
	    print "DlrMtd: $main::Electric{DlrMtd}\n";
	    print "KWProj: $main::Electric{KWProj}\n";
	    print "DlrProj: $main::Electric{DlrProj}\n";
	    print "LoValarm: $main::Electric{LoValarm}\n";
	    print "HiValarm: $main::Electric{HiValarm}\n";
	    print "DlrMthAlarm: $main::Electric{DlrMthAlarm}\n";
	    print "PkKwAlarm: $main::Electric{PkKwAlarm}\n";
	    print "DlrPkKwHAlarm: $main::Electric{DlrPkKwHAlarm}\n";
	    print "KwMtdwAlarm: $main::Electric{KwMtdAlarm}\n";
	}
	print "KWNow:$main::Electric{KWNow}\n" if $main::Debug{ted};
	$self->{good_packet_time} = time;

    }
    else { 
#	print "housecode:$pkt[110]\n"; # add some more recovery here...
	print "bad ted pkt\n" if $::Debug{ted}; 
    }
    $main::Serial_Ports{$portname}{data_record} = undef;
}

sub get_time {
    my ($minutes) = @_;
    my $hours = int ($minutes / 60);
    my $mins = $minutes % 60;
    my $suffix = 'am';
    if ($hours > 12) {
	$hours = $hours - 12;
	$suffix = 'pm';
    }
    $hours = 12 if $hours == 0;

    $mins=sprintf "%02d ", $mins;    
	
    my $time = "${hours}:${mins}$suffix";
    return $time;
}

# do not remove the following line, packages must return a true value
1;
# =========== Revision History ==============
# Revision 1.0  -- 4/08/2008 -- David Satterfield
# - First Release
#
