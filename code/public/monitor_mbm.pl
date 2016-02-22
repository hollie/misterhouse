# Category=Other

# in mh.private.ini:

# mbm sensors
#	mbm_fan1=cpu fan
#	mbm_fan2=chassis fan
#	mbm_temp1=cpu temp

use vars qw(%Analog);
use vars qw(%MBM);

use Win32::API;

# noloop=start
my $OpenFileMapping =
  new Win32::API( "kernel32", "OpenFileMapping", [ 'N', 'N', 'P' ], 'N' );
my $CloseHandle = new Win32::API( "kernel32", "CloseHandle", ['N'], 'N' );
my $MapViewOfFile =
  new Win32::API( "kernel32", "MapViewOfFile", [ 'N', 'N', 'N', 'N', 'N' ],
    'N' );
my $UnmapViewOfFile =
  new Win32::API( "kernel32", "UnmapViewOfFile", ['N'], 'N' );
my $CopyMemoryX =
  new Win32::API( "kernel32", "RtlMoveMemory", [ 'P', 'N', 'N' ], 'N' );

# noloop=stop

if ( $New_Second and ( $Second == 3 ) ) {
    &MBM_GetData;
    &MBM_AvgData;
}

my %mbm_data_avg_data;

sub MBM_GetData {

    use constant FILE_MAP_READ => 4;

    #die "OpenFileMapping" unless defined $OpenFileMapping;
    #die "CloseHandle" unless defined $CloseHandle;
    #die "MapViewOfFile" unless defined $MapViewOfFile;
    #die "CopyMemoryX" unless defined $CopyMemoryX;

    my $myMBMFile = $OpenFileMapping->Call( FILE_MAP_READ, 0, '$M$B$M$5$D$' );

    if ( $myMBMFile eq 0 ) {
        print "MBM Data File/Mem could not be opened. Sorry\n";
        return;
    }

    my $myMBMMem = $MapViewOfFile->Call( $myMBMFile, FILE_MAP_READ, 0, 0, 0 );

    my $myDataStruct = " " x 169;    #data structure is 169 bytes long

    $CopyMemoryX->Call( $myDataStruct, $myMBMMem, 169 );
    $UnmapViewOfFile->Call($myMBMMem);
    $CloseHandle->Call($myMBMFile);

    my @temp = unpack( "L10d10L10Lsd4", $myDataStruct );

    for $i ( 1 .. 10 ) { $MBM{"Temp_$i"}    = $temp[ $i - 1 ] }
    for $i ( 1 .. 10 ) { $MBM{"Voltage_$i"} = $temp[ $i + 9 ] }
    for $i ( 1 .. 10 ) { $MBM{"Fan_$i"}     = $temp[ $i + 19 ] }
    $MBM{"CPU_MHZ"} = $temp[30];
    $MBM{"CPUS"}    = $temp[31];
    for $i ( 1 .. 4 ) { $MBM{"CPU_$i"} = $temp[ $i + 31 ] }
}

sub MBM_AvgData {
    for my $i ( 1 .. 10 ) {    #fan readings
        print "checking fan $i\n" if $Debug{mbmx};

        next unless my $fan = $config_parms{"mbm_fan$i"};
        print "continuing with fan $i\n" if $Debug{mbmx};

        my $data = $MBM{"Fan_$i"};

        # Average the last 5 entries
        if ( defined @{ $mbm_data_avg_data{$fan} } ) {

            unshift( @{ $mbm_data_avg_data{$fan} }, $data );
            pop( @{ $mbm_data_avg_data{$fan} } );
        }
        else {
            @{ $mbm_data_avg_data{$fan} } = ($data) x 5;
        }

        my $mbm_data_avg = 0;
        grep( $mbm_data_avg += $_, @{ $mbm_data_avg_data{$fan} } );
        $mbm_data_avg /= 5;
        $Analog{$fan} = sprintf( "%d", $mbm_data_avg );
        print "Analog{$fan} = $Analog{$fan} ($data)\n" if $Debug{mbm};
    }

    for $i ( 1 .. 10 ) {    #temp readings
        print "checking temp $i\n" if $Debug{mbmx};

        next unless my $temp = $config_parms{"mbm_temp$i"};
        print "continuing with temp $i ($temp)\n" if $Debug{mbmx};

        my $data = $MBM{"Temp_$i"};

        # Average the last 5 entries
        if ( defined @{ $mbm_data_avg_data{$temp} } ) {

            unshift( @{ $mbm_data_avg_data{$temp} }, $data );
            pop( @{ $mbm_data_avg_data{$temp} } );
        }
        else {
            @{ $mbm_data_avg_data{$temp} } = ($data) x 5;
        }

        my $mbm_data_avg = 0;
        grep( $mbm_data_avg += $_, @{ $mbm_data_avg_data{$temp} } );
        $mbm_data_avg /= 5;
        $Analog{$temp} = sprintf( "%3.1f", $mbm_data_avg );
        print "Analog{$temp} = $Analog{$temp} ($data)\n" if $Debug{mbm};
    }

    # convert to F for logging
    $Analog{temp_archy_cpu} = $Analog{'cpu temp'} * 9 / 5 + 32;

}

