
=head1 NAME

B<IR_Utils>

=head1 SYNOPSIS

NONE

=head1 DESCRIPTION

generate codes from IRD protocol specifications and OFA devices database

=head1 INHERITS

B<NONE>

=head1 METHODS

=over

=item B<UnDoc>

=cut

package IR_Utils;

my $fields =
  'Type	Sub	Code	?	P-id	Protocol	dev1	dev2	dev3	data1	data2	data3	Data	94	C7	P8	Mfgs	blank	0	1	2	3	4	5	6	7	8	9	VOL +	VOL -	MUTE	CH +	CH -	POWER	ENTER	TV/VCR	LAST	MENU	GUIDE	Up	Down	Left	Right	SELECT	SLEEP	PIP	DISPLAY	SWAP	MOVE	PLAY	PAUSE	REW	FFWD	STOP	REC	EXIT	SURR		bin1	bin2	bin3	332	TV0000';
my $buttons =
  '0	1	2	3	4	5	6	7	8	9	VOL +	VOL -	MUTE	CH +	CH -	POWER	ENTER	TV/VCR	LAST	MENU	GUIDE	Up	Down	Left	Right	SELECT	SLEEP	PIP	DISPLAY	SWAP	MOVE	PLAY	PAUSE	REW	FFWD	STOP	REC	EXIT	SURR';
my %devices;

my $device_file = "$::config_parms{data_dir}/infrared/Devices4.csv";
my $irp_spreadsheet =
  "$::config_parms{data_dir}/infrared/comparison_matrix.csv";
my $devicelib_dir = "$::config_parms{data_dir}/infrared/devicelib";

my %protocols;
my %protocol_names;
my @efc2obc;

sub init_ir_utils {
    unless ( -f $device_file and -f $irp_spreadsheet ) {
        print "Missing file $device_file and/or $irp_spreadsheet\n";
        return;
    }
    read_devices();
    read_irp_spreadsheet();
    foreach ( 0 .. 255 ) { $efc2obc[ obc2efc($_) ] = $_ }
}

sub read_devices {
    open DEVICES, $device_file;
    my $tmp = <DEVICES>;
    while ( my $line = <DEVICES> ) {
        chomp $line;
        my %device;
        @device{ split "\t", $fields } = split_csv($line);
        next unless $device{'P-id'};
        my $type = $device{'Type'};
        my $code = $device{'Code'};
        my $key  = "$type$;$code";
        $devices{$key} = {%device};
    }
    close DEVICES;
}

sub ofa_bysub {
    my @bysub;
    foreach ( keys %devices ) {
        my $type = $devices{$_}{'Type'};
        my $code = $devices{$_}{'Code'};
        my $sub  = $devices{$_}{'Sub'};
        next unless $protocols{ $devices{"$type$;$code"}{'P-id'} }{'Form'};
        next unless &get_ofa_keys( $type, $code );
        foreach ( split ',\s*', $devices{$_}{'Mfgs'} ) {
            next if /^#/;
            push @bysub, "$sub$;$type$;$_$;$code";
        }
    }
    return sort @bysub;
}

# code for parsing IRP descriptions and generating codes

sub read_irp_spreadsheet {
    open IRP, $irp_spreadsheet;
    my $tmp    = <IRP>;
    my @fields = split_csv($tmp);
    while ( my $line = <IRP> ) {
        chomp $line;
        my %protocol;
        @protocol{@fields} = split_csv($line);
        $protocol{'Freq Hz'} =~ s/,//;
        $protocol{'Form'} =~ s/\s*'.*//;
        next unless $protocol{'Form'};
        $protocols{ $protocol{'UEIC Protocol ID'} } = {%protocol}
          if $protocol{'UEIC Protocol ID'};
        $protocol_names{ $protocol{'Protocol Name in Devices4.xls'} } =
          {%protocol}
          if $protocol{'Protocol Name in Devices4.xls'};
    }
    close IRP;
}

sub read_irp_files {
    opendir IRPDIR, $devicelib_dir;
    foreach ( grep { /\.IRP$/i } readdir IRPDIR ) {
        print "Reading $_";
        my %protocol;
        open IRP, "$devicelib_dir/$_";
        while (<IRP>) {
            my ( $key, $value ) = /^(.+)\s*:\s*(.+)\s*$/;
            $protocol{$key} = $value if $key;
        }
        my $tmp = lc $protocol{Protocol};
        $protocols{$tmp} = {%protocol} if $tmp;
        close IRP;
    }
    closedir IRPDIR;
}

sub get_dvc_files {
    opendir DVCDIR, $devicelib_dir;
    my @dvc_list;
    foreach ( grep { /\.DVC$/i } readdir DVCDIR ) {
        push @dvc_list, $_;
    }
    closedir DVCDIR;
    return sort @dvc_list;
}

sub read_dvc_file {
    my $file = shift;
    open DVC, "$devicelib_dir/$file";
    my ( %parms, %prontos, $in_keys );
    $parms{repeat} = 3;
    while (<DVC>) {
        next if /^#/;
        chomp;
        s/\r//gs;
        $in_keys = 1 if /\[Key Codes\]/;
        if ($in_keys) {
            if ( my ( $key, $pronto ) = /(.+?)\s*=\s*(0000 .+)/ ) {
                $key = uc $key;
                $prontos{$key} = $pronto;
            }
            elsif ( my ( $key, $device_code, $function_code ) =
                /(.+?)\s*=\s*(\d+)\s*[,;]\s*(\d+)\s*$/ )
            {
                $key = uc $key;
                ( $prontos{$key} ) =
                  &IR_Utils::generate_pronto( $parms{protocol}, $device_code,
                    $function_code );
            }
            elsif ( my ( $key, $function_code ) =
                /(.+?)\s*=\s*[,;]?\s*(\d+)\s*$/ )
            {
                $key = uc $key;
                ( $prontos{$key} ) =
                  &IR_Utils::generate_pronto( $parms{protocol},
                    $parms{'device code'}, $function_code );

                #print "k $prontos{$key}, p $parms{protocol}, d $parms{'device code'}, f $function_code\n";
            }
        }
        else {
            if ( my ( $key, $value ) = /(.+)\s*=\s*(.+)\s*/ ) {
                $key         = lc $key;
                $value       = "Sony" if $value eq "Sony12";
                $parms{$key} = $value;
            }
        }
    }
    close DVC;
    my $device = "unknown";
    $device = $parms{manufacturer} if $parms{manufacturer};
    $device .= " $parms{model}"  if $parms{model};
    $device .= " $parms{device}" if $parms{device};
    return uc $device, $parms{repeat}, %prontos;
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
    my %keys = get_ofa_keys( $type, $code );
    while ( my ( $key, $efc ) = each %keys ) {
        my ( $protocol, $device, $function ) =
          get_function( $type, $code, $efc );
        print
          "$type $code $key protocol $protocol efc $efc device $device function $function\n";
        ( $prontos{$key}, $repeat ) =
          generate_pronto( uc $protocol, $device, $function );
    }
    return ( $repeat, %prontos );
}

sub generate_pronto {
    my %vars;
    my $tmp      = shift;
    my %protocol = %{ $protocols{$tmp} };
    %protocol = %{ $protocol_names{$tmp} } unless %protocol;
    print "Can't find protocol $tmp\n" unless %protocol;
    $vars{D} = shift;
    $vars{F} = shift;
    my $modulation = $protocol{'Modulation'};
    $vars{C} = ( $vars{F} < 64 ) ? 3 : 2 if $modulation eq 'PPM';
    my $first_length;
    my $current_phase = -1;
    my $units = $protocol{'Freq Hz'} ? 1000000 / $protocol{'Freq Hz'} : 25;

    #$units = 27.019552;
    my $frequency = $units / .241246;
    my $repeat    = 2;
    $repeat = 3 if $tmp eq '00 CA' or $tmp eq 'Sony';
    my $time = $protocol{'Time Base'};
    $time = $time ? $time / $units : 1;
    my @one  = map abs( $_ * $time ), split ',', $protocol{One};
    my @zero = map abs( $_ * $time ), split ',', $protocol{Zero};
    my $msb  = $protocol{'First Bit'} eq 'MSB';
    foreach ( $protocol{'Default'}, $protocol{'Define'} ) {
        my $equation = $_;
        next unless $equation;
        $equation =~
          s/([A-Z])\((\d)\.\.(\d)\)/(ord pack 'b*', join '', (split '', unpack 'b8', pack 's', $1)[$2..$3])/g;
        $equation =~ s/([A-Z])/\$vars{"$1"}/g;
        eval $equation;
    }
    $protocol{Form} =~ s/D:5/D:8/
      if ( $tmp eq '00 CA' or $tmp eq 'Sony' )
      and $vars{D} > 31;
    my ( $first, $second ) = split ';', $protocol{Form};
    my @data;
    push @data, 0, $frequency, 0, 0;
    foreach ( $first, $second ) {
        next unless $_;
        s/([A-Z])/$vars{"$1"}/g;
        my $length;
        foreach my $part ( split ',', $_ ) {
            print "part $part\n";
            if ( my ($string) = $part =~ /\[(.+)\]/ ) {

                # handle [^45000]
                if ( my ($duration) = $string =~ /^\^(\d+)$/ ) {
                    foreach ( @data[ 4 .. $#data - 1 ] ) {
                        $duration -= $_ * $units;
                    }
                    if ( $modulation eq 'PPM' ) {
                        if ( $current_phase == 1 ) {
                            push @data, $time;
                            $length++;
                            $current_phase = 0;
                        }
                    }
                    $data[$#data] = $duration / $units;
                }

                # handle [1 ^100000]
                elsif ( my ( $pulse, $duration ) =
                    $string =~ /^(\d+)\s+\^(\d+)$/ )
                {
                    push @data, abs( $pulse * $time ), 0 if $pulse;
                    $length++ if $pulse;
                    foreach ( @data[ 4 .. $#data - 1 ] ) {
                        $duration -= $_ * $units;
                    }
                    $data[$#data] = $duration / $units;
                }

                # handle [1 -4] PPM
                elsif ( $modulation eq 'PPM'
                    and my ( $a, $b ) = $string =~ /^(-?\d+)\s+(-?\d+)$/ )
                {
                    my $phase = $a > 0;

                    #print "db $a $phase $current_phase $time $data[$#data - 1] \n";
                    if ( $current_phase == -1 ) {
                        push @data, 0;
                        $current_phase = 1;
                    }
                    if ( $current_phase == $phase ) {
                        $data[$#data] = abs( $a * $time );
                    }
                    else {
                        push @data, abs( $a * $time );

                        #						$data[$#data] += abs($a * $time);
                    }
                    $phase = $b > 0;
                    push @data, abs( $b * $time );
                    $current_phase = $phase;
                }

                # handle [-189] PPM
                elsif ( $modulation eq 'PPM'
                    and my ($a) = $string =~ /^(-?\d+)$/ )
                {
                    my $phase = $a > 0;
                    if ( $current_phase == $phase ) {
                        $data[$#data] = abs( $a * $time );
                    }
                    else {
                        push @data, abs( $a * $time );
                    }
                    $current_phase = $phase;
                }

                # handle [1 -4] PWM
                else {
                    foreach my $a ( split ' ', $string ) {
                        my $phase = $a > 0;
                        push @data, abs( $a * $time );
                        $length++ if $phase == 1;
                    }
                }
            }

            # handle 25:8 (variables already substituted)
            elsif ( my ( $inverse, $value, $width ) =
                $part =~ /(~?)(\d*):(\d+)/ )
            {
                $value = 0xff & ~( 0 + $value ) if $inverse;
                $value = ( 0 + $value ) << ( 8 - $width )
                  if $msb and $width < 8;
                my $format = ( $msb ? 'B' : 'b' ) . $width;
                foreach
                  my $bit ( split '', unpack $format, pack 'C', 0 + $value )
                {
                    #print "bit $bit\n";
                    if ( $modulation eq 'PPM' ) {
                        my $phase = (
                            $bit
                            ? ( split ',', $protocol{One} )[1]
                            : ( split ',', $protocol{Zero} )[1]
                        ) > 0;

                        #print "db $bit ph $phase c $current_phase \n";
                        if (1) {
                            if ( $current_phase == $phase ) {
                                push @data, $time;
                            }
                            else {
                                $data[$#data] += $time;
                            }
                        }
                        push @data, $time;
                        $current_phase = $phase;
                    }
                    else {
                        push @data, ( $bit ? @one : @zero );
                    }
                }
            }
            else {
                print "IR_Utils: error parsing form part $part\n";
            }

            #my $code = join(" ", map { sprintf "%04x", $_ } @data);
            #print "$code \n";
        }
        if ( $_ eq $first ) {
            $first_length = $#data - 3;
            $data[2] = $first_length / 2;
        }
        else {
            $data[3] = ( $#data - 3 - $first_length ) / 2;
        }
    }
    my $code = join( " ", map { sprintf "%04x", $_ } @data );
    print "$code \n";
    return ( $code, $repeat );
}

sub get_ofa_keys {
    my $type = shift;
    my $code = shift;
    my %keys;
    print "Could not find protocol for $type $code\n"
      unless $protocols{ $devices{"$type$;$code"}{'P-id'} }{'Form'};

    foreach ( split "\t", $buttons ) {
        my $key = $_;
        my $efc = $devices{"$type$;$code"}{$key};
        $keys{$key} = $efc if $efc =~ /\d+/;
    }
    return %keys;
}

sub get_function {
    my $type     = shift;
    my $code     = shift;
    my $efc      = shift;
    my $protocol = uc $devices{"$type$;$code"}{'P-id'};
    my $device   = $devices{"$type$;$code"}{'dev1'};
    my $device2  = $devices{"$type$;$code"}{'dev2'};
    $device = 0 unless $device =~ /^\d+$/;
    my $efc_conv = $protocols{$protocol}{'EFC Conversion'};
    my $function;

    if ( $efc_conv eq 'Sony' ) {
        $function = 255 - $efc2obc[$efc];
    }
    elsif ( $efc_conv eq 'Panold' ) {
        $function = 63 - $efc2obc[$efc];
    }
    elsif ( $efc_conv eq 'MSB' ) {
        $function = unpack 'C', pack 'b8', unpack 'B8', pack 'C',
          0 + $efc2obc[$efc];
    }
    elsif ( $efc_conv eq '~MSB' ) {
        $function = unpack 'C', pack 'b8', unpack 'B8', pack 'C',
          0 + ( 255 - $efc2obc[$efc] );
    }
    elsif ( $efc_conv eq 'LSB' ) {
        $function = $efc2obc[$efc];
    }
    elsif ( $efc_conv eq '~LSB' ) {
        $function = 0xff & ~$efc2obc[$efc];
    }
    else {
        print "Missing efc conversion key, using default \n";
        $function = $efc2obc[$efc];
    }
    if ( $function > 127 and $device2 =~ /^\d+$/ ) {
        $function -= 128;
        $device = $device2;
    }
    return ( $protocol, $device, $function );
}

sub obc2efc {
    my $obc = shift;

    # Reverse the order of bits
    $obc = ( $obc << 4 ) + ( $obc >> 4 );
    $obc = ( ( $obc & 0x33 ) << 2 ) + ( ( $obc & 0xCC ) >> 2 );
    $obc = ( ( $obc & 0x55 ) << 1 ) + ( ( $obc & 0xAA ) >> 1 );

    # Rotate left three places  (ignoring affect on bits 8-10)
    $obc = ( $obc << 3 ) + ( $obc >> 5 );

    # XOR with 0x51;
    $obc ^= 0x51;

    # Add 100 (ignoring affect on bits 8-10)
    $obc += 100;

    # Return only low 8 bits
    return $obc & 0xFF;
}

sub split_csv {
    my $line  = shift;
    my @parts = split '"', $line, -1;
    my $i     = -1;
    my @list;
    foreach my $part (@parts) {
        $i++;
        next if ( $i == 0 or $i == $#parts ) and $part eq '';
        if ( $i % 2 ) {
            push @list, $part;
        }
        else {
            unless ( $i == 0 or $i == $#parts ) {
                if ( $part eq ',' ) {
                    next;
                }
            }
            $part =~ s/^,// if ( $i > 0 );
            $part =~ s/,$// if ( $i < $#parts );
            push @list, split ',', $part, -1;
        }
    }
    return @list;
}
1;

=back

=head1 INI PARAMETERS

NONE

=head1 AUTHOR

David Norwood (dnorwood2@yahoo.com) Dec, 2002

=head1 SEE ALSO

NONE

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

