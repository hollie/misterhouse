package IR_Utils;

# generate codes from IRD protocol specifications and OFA devices database 
# by David Norwood (dnorwood2@yahoo.com) Dec, 2002

my $fields = 'Type	Sub	Code	?	P-id	Protocol	dev1	dev2	dev3	data1	data2	data3	Data	94	C7	P8	Mfgs	blank	0	1	2	3	4	5	6	7	8	9	VOL +	VOL -	MUTE	CH +	CH -	POWER	ENTER	TV/VCR	LAST	MENU	GUIDE	Up	Down	Left	Right	SELECT	SLEEP	PIP	DISPLAY	SWAP	MOVE	PLAY	PAUSE	REW	FFWD	STOP	REC	EXIT	SURR		bin1	bin2	bin3	332	TV0000';
my $buttons = '0	1	2	3	4	5	6	7	8	9	VOL +	VOL -	MUTE	CH +	CH -	POWER	ENTER	TV/VCR	LAST	MENU	GUIDE	Up	Down	Left	Right	SELECT	SLEEP	PIP	DISPLAY	SWAP	MOVE	PLAY	PAUSE	REW	FFWD	STOP	REC	EXIT	SURR';
my %devices; 
my $device_file = "../data/infrared/Devices4.csv";
my $irp_spreadsheet = "../data/infrared/comparison matrix.csv";
my $devicelib_dir = "../data/infrared/devicelib";
my %protocols;
my %protocol_names;
my @efc2obc; 


sub init_ir_utils {
	unless (-f $device_file and -f $irp_spreadsheet) {
		print "Missing file $device_file and/or $irp_spreadsheet\n";
		return;
	}
	read_devices();
	read_irp_spreadsheet();
	foreach (0 .. 255) {$efc2obc[obc2efc($_)] = $_} 
}

sub read_devices {
	open DEVICES, $device_file; 
	my $tmp = <DEVICES>;
	while (my $line = <DEVICES>) {
		chomp $line; 
		my %device; 
		@device{split "\t", $fields} = split_csv($line);
		next unless $device{'P-id'};
		my $type = $device{'Type'}; 
		my $code = $device{'Code'}; 
		my $key = "$type$;$code";
		$devices{$key} = { %device };
	}
	close DEVICES; 
}

sub ofa_bysub {
	my @bysub; 
	foreach (keys %devices) {
		my $type = $devices{$_}{'Type'}; 
		my $code = $devices{$_}{'Code'}; 
		my $sub  = $devices{$_}{'Sub'};
		next unless $protocols{$devices{"$type$;$code"}{'P-id'}}{'Form'};
		next unless &get_ofa_keys($type, $code); 
		foreach (split ',\s*', $devices{$_}{'Mfgs'}) {
			next if /^#/;
			push @bysub, "$sub$;$type$;$_$;$code";
		}
	}
	return sort @bysub; 
}

# code for parsing IRP descriptions and generating codes 

sub read_irp_spreadsheet {
	open IRP, $irp_spreadsheet;
	my $tmp = <IRP>;
	my @fields = split_csv($tmp);
	while (my $line = <IRP>) {
		chomp $line; 
		my %protocol; 
		@protocol{@fields} = split_csv($line);
		$protocol{'Freq Hz'} =~ s/,//;
		$protocol{'Form'} =~ s/\s*'.*//;
		next unless $protocol{'Form'}; 
		$protocols{$protocol{'UEIC Protocol ID'}} = { %protocol } if $protocol{'UEIC Protocol ID'};
		$protocol_names{$protocol{'Protocol Name in Devices4.xls'}} = { %protocol } if $protocol{'Protocol Name in Devices4.xls'};
	} 
	close IRP;
}

sub read_irp_files {
	opendir IRPDIR, $devicelib_dir;
	foreach (grep {/\.IRP$/i} readdir IRPDIR) {
		print "Reading $_";
		my %protocol; 
		open IRP, "$devicelib_dir/$_";
		while (<IRP>) {
			my ($key, $value) = /^(.+)\s*:\s*(.+)\s*$/;
			$protocol{$key} = $value if $key;
		}
		my $tmp = lc $protocol{Protocol};
		$protocols{$tmp} = { %protocol } if $tmp;
		close IRP;
	} 
	closedir IRPDIR;
}

sub get_protocols {
	return sort keys %protocols;
}

sub get_protocol_names {
	return sort keys %protocol_names;
}

# routines for generating codes 

sub generate_ofa_device {
	my $type = shift; 
	my $code = shift; 
	my $repeat; 
	my %prontos;
	my %keys = get_ofa_keys($type, $code);
	while (my ($key, $efc) = each %keys) {
		my ($protocol, $device, $function) = get_function($type, $code, $efc);
		print "$type $code $key protocol $protocol efc $efc device $device function $function\n";
		($prontos{$key}, $repeat) = generate_pronto(uc $protocol, $device, $function);
	}
	return ($repeat, %prontos);
}

sub generate_pronto {
	my %vars;		
	my $tmp = shift; 
	my %protocol = %{ $protocols{$tmp} };
	%protocol = %{ $protocol_names{$tmp} } unless %protocol;
	print "Can't find protocol $tmp" unless %protocol; 
	$vars{D} = shift; 
	$vars{F} = shift; 
	my $modulation = $protocol{'Modulation'};
	$vars{C} = ($vars{F} < 64) ? 3 : 2 if $modulation eq 'PPM';
	my $current_phase = -1; 
	my $units = $protocol{'Freq Hz'} ? 1000000 / $protocol{'Freq Hz'} : 25;
	my $frequency = $units / .241246;
	my $repeat = 2;
	$repeat = 3 if $tmp eq '00 CA' or $tmp eq 'Sony'; 
	my $time = $protocol{'Time Base'};
	$time = $time ? $time / $units : 1;
	my @one = map abs($_ * $time), split ',', $protocol{One};
	my @zero = map abs($_ * $time), split ',', $protocol{Zero};
	my $msb = $protocol{'First Bit'} eq 'MSB';
	foreach ($protocol{'Default'}, $protocol{'Define'}) {
		my $equation = $_;
		next unless $equation;
		$equation =~ 
		  s/([A-Z])\((\d)\.\.(\d)\)/(ord pack 'b*', join '', (split '', unpack 'b8', pack 's', $1)[$2..$3])/g;
		$equation =~ s/([A-Z])/\$vars{"$1"}/g;
		eval $equation;
	}
	$protocol{Form} =~ s/D:5/D:8/ if ($tmp eq '00 CA' or $tmp eq 'Sony') and $vars{D} > 31;
	my ($first, $second) = split ';', $protocol{Form};
	my @data; 
	push @data, 0, $frequency, 0, 0;
	foreach ($first, $second) {
		next unless $_;
		s/([A-Z])/$vars{"$1"}/g;
		my $length; 
		foreach my $part (split ',', $_) {
			#print "part $part\n";
			if (my ($string) = $part =~ /\[(.+)\]/) {
				# handle [^45000]
				if (my ($duration) = $string =~ /^\^(\d+)$/) {
					foreach (@data[4 .. $#data - 1]) {$duration -= $_ * $units}
					if ($modulation eq 'PPM') {
						if ($current_phase == 1) {
							push @data, $time;
							$length++; 
							$current_phase = 0;
						}
					}
					$data[$#data] = $duration / $units; 
				}
				# handle [1 ^100000]
				elsif (my ($pulse, $duration) = $string =~ /^(\d+)\s+\^(\d+)$/) {
					push @data, abs($pulse * $time), 0 if $pulse;
					$length++ if $pulse;
					foreach (@data[4 .. $#data - 1]) {$duration -= $_ * $units}
					$data[$#data] = $duration / $units; 
				}
				# handle [1 -4]
				else {
					foreach my $a (split ' ', $string) {		
						my $phase = $a > 0;
						if ($modulation eq 'PPM') {
							unless ($current_phase == -1) {
								if ($current_phase == $phase) {
									push @data, abs($a * $time);
									$length++ if $current_phase; 
								}
								else {
									$data[$#data] += abs($a * $time);
								}
							}
							push @data, abs($_ * $time);
							$current_phase = $phase;
							$length++ unless $current_phase; 
						}
						else {
							push @data, abs($a * $time);
							$length++ if $phase; 
						}
					}
				}
			}
				# handle 25:8 (variables already substituted)
			elsif (my ($inverse, $value, $width) = $part =~ /(~?)(\d*):(\d+)/) {
				$value = 0xff & ~ (0 + $value) if $inverse; 
				$value = (0 + $value) << (8 - $width) if $msb and $width < 8; 
				my $format = ($msb ? 'B' : 'b') . $width;
				foreach my $bit (split '', unpack $format, pack 'C', 0 + $value) {
					#print "bit $bit\n";
					if ($modulation eq 'PPM') {
						unless ($current_phase == -1) {
							if ($current_phase == $bit) {
								push @data, $time;
								$length++ if $current_phase; 
							}
							else {
								$data[$#data] += $time;
							}
						}
						push @data, $time;
						$current_phase = $bit;
						$length++ unless $current_phase; 
					}
					else {
						push @data, ($bit ? @one : @zero);
						$length++; 
					}
				}
			}
			else {
				print "IR_Utils: error parsing form part $part\n";
			}
		}
		$data[ $_ eq $first ? 2 : 3 ] = $length; 
	}
	my $code = join(" ", map { sprintf "%04x", $_ } @data); 
	return ($code, $repeat); 
}

sub get_ofa_keys {
	my $type = shift; 
 	my $code = shift; 
	my %keys;
	print "Could not find protocol for $type $code\n" unless $protocols{$devices{"$type$;$code"}{'P-id'}}{'Form'};
   
	foreach (split "\t", $buttons) {
		my $key = $_;
		my $efc = $devices{"$type$;$code"}{$key};
		$keys{$key} = $efc if $efc =~ /\d+/;
	}
	return %keys; 
}

sub get_function {
	my $type = shift; 
	my $code = shift; 
	my $efc = shift; 
	my $protocol = uc $devices{"$type$;$code"}{'P-id'};
	my $device = $devices{"$type$;$code"}{'dev1'};
	my $device2 = $devices{"$type$;$code"}{'dev2'};
	$device = 0 unless $device =~ /^\d+$/;
	my $efc_conv = $protocols{$protocol}{'EFC Conversion'};
	my $function;
	if ($efc_conv eq 'Sony') {
		$function = 255 - $efc2obc[$efc];
	}
	elsif ($efc_conv eq 'Panold') {
		$function = 63 - $efc2obc[$efc];
	}
	elsif ($efc_conv eq 'MSB') {
		$function = 255 - $efc2obc[$efc];
	}
	elsif ($efc_conv eq '~MSB') {
		$function = 0xff & ~ (255 - $efc2obc[$efc]);
	}
	elsif ($efc_conv eq 'LSB') {
		$function = $efc2obc[$efc];
	}
	elsif ($efc_conv eq '~LSB') {
		$function = 0xff & ~ $efc2obc[$efc];
	}
	else {
		$function = $efc2obc[$efc];
	}
	if ($function > 127 and $device2 =~ /^\d+$/) {
		$function -= 128;
		$device = $device2;
	}
	return ($protocol, $device, $function);
}

sub obc2efc {
	my $obc = shift; 

	# Reverse the order of bits
	$obc = ($obc<<4) + ($obc>>4);
	$obc = (($obc&0x33)<<2) + (($obc&0xCC)>>2);
	$obc = (($obc&0x55)<<1) + (($obc&0xAA)>>1);

	# Rotate left three places  (ignoring affect on bits 8-10)
	$obc = ($obc<<3) + ($obc>>5);

	# XOR with 0x51;
	$obc ^= 0x51;

	# Add 100 (ignoring affect on bits 8-10)
	$obc += 100;

	# Return only low 8 bits
	return $obc & 0xFF;
}

sub split_csv {
	my $line = shift; 
	my @parts = split '"', $line, -1;
	my $i = -1;
	my @list;
	foreach my $part (@parts) {
		$i++;
		next if ($i == 0 or $i == $#parts) and $part eq '';
		if ($i % 2) {
			push @list, $part;
		}
		else {
			unless ($i == 0 or $i == $#parts) {
				if ($part eq ',') {
					next; 
				}
			}
			$part =~ s/^,// if ($i > 0);
			$part =~ s/,$// if ($i < $#parts);
			push @list, split ',', $part, -1;
		}
	}
	return @list; 
}
1; 
