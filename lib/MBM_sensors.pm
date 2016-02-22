
=head1 B<MBM_sensors>

=head2 SYNOPSIS

  require 5.003;
  use Win32::MBM_sensors qw( :STAT 0.19 );
  my %Sensors = &MBM_sensors::get;

Key/Value pairs in resulting hash:

  $Sensors{error}            char if successful, undef; if failure, reason.

  $Sensors{version}          num  MBM version number
  $Sensors{timestart}        char Date/time of MBM startup
  $Sensors{timecurrent}      char Date/time of last update of all sensors
  $Sensors{path}             char Working path for MBM

  $Sensors{temperature}           Array of sensor hashes
  $Sensors{voltage}               Array of sensor hashes
  $Sensors{fan}                   Array of sensor hashes
  $Sensors{MHZ}                   Array of sensor hashes
  $Sensors{CPUbusy}               Array of sensor hashes

Each sensor hash, regardless of type, is:

  $Sensor{name}              char Name of sensor
  $Sensor{current}           num  Most recent reading, degrees celsius for Temp, RPM for fan, etc.
  $Sensor{low}               num  Minimum reading since MBM startup
  $Sensor{high}              num  Maximum reading since MBM startup
  $Sensor{count}             num  Number of times read since MBM startup
  $Sensor{total}             num  Sum of all readings since MBM startup
  $Sensor{alarm1}            num  Low alarm point for MBM action
  $Sensor{alarm2}            num  High alarm point for MBM action

Example of selecting the first temperature sensor as a complete hash:

  %Sensor = $Sensors{temperature}[1];
  print "Temp sensor 1 now $Sensor{current}";

Example of selecting the current reading of the second temperature sensor:

  print "Temp sensor 2 now $Sensors{temperature}[2]{current}";

Constants taken from MBM sensors.c sample code

  //    enum Bus
  define BusType     char
  define ISA         0
  define SMBus       1
  define VIA686Bus   2
  define DirectIO    3

  //    enum SMB
  define SMBType         char
  efine smtSMBIntel     0
  define smtSMBAMD       1
  define smtSMBALi       2
  define smtSMBNForce    3
  define smtSMBSIS       4

  // enum Sensor Types
  define SensorType      char
  define stUnknown       0
  define stTemperature   1
  define stVoltage       2
  define stFan           3
  define stMhz           4
  define stPercentage    5

Except for items indicated as I<Experimental>, I do not expect functional changes which are not fully backwards compatible.

=head2 DESCRIPTION

This module provides an interface to MBM sensors.  MBM monitors Temperature, Voltage, Fans, etc. via sensors included in many motherboards.  MBM runs on MS Windows.  MBM available at http://mbm.livewiredev.com.  MBM must be installed and correctly configured.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package MBM_sensors;

use Win32::API;
use vars qw($VERSION);
$VERSION = '0.10';

use strict;

sub get {

    my $i;
    my $rc;
    my %MBM_sensors;

    # Perl pack/upack equivalent of MBM's sensors.c struct.
    # There are other ways to derive the lengths we need,
    # but when the MBM struct changes, this will be easy to maintain.

    my $MBMSharedIndexPattern = 'C' .    # iType
      'N';                               # iCount
    my $MBMSharedIndexLen = length pack $MBMSharedIndexPattern;
    $MBMSharedIndexLen += 4 - ( $MBMSharedIndexLen % 4 )
      if ( $MBMSharedIndexLen % 4 );

    my $MBMSharedSensorPattern = 'C' .    # ssType
      'A12' .                             # ssName
      'x3' .                              # ssPad
      'd' .                               # ssCurrent value
      'd' .                               # ssLowest readout
      'd' .                               # ssHighest readout
      'l' .                               # ssCount of readout
      'x4' .                              # ssPad2
      'H20'
      . # ssTotal - Note: Perl unpack has no equivalent to Delphi "Extended" 10 byte floating; So return ssTotal in hex for further processing in the parser
      'x6' .    # ssPad3
      'd' .     # ssAlarm1 Temp&Fan: high alarm; voltage: %off
      'd';      # ssAlarm2 Temp: low alarm
    my $MBMSharedSensorLen = length pack $MBMSharedSensorPattern;
    $MBMSharedSensorLen += 4 - ( $MBMSharedSensorLen % 4 )
      if ( $MBMSharedSensorLen % 4 );

    my $MBMSharedInfoPattern = 'S' .    # siSMB_Base SMBus base address
      'C' .                             # siSMB_Type SMBus how accessed
      'C' .      # siSMB_Code SMBus sub type Intel, AMD, ALi, etc.
      'C' .      # siSMB_Addr Address of sensor chip on bus
      'A41' .    # siSMB_Name Nice name for SMBus
      'S' .      # siISA_Base ISA base address of sensor chip
      'N' .      # siChipType
      'C';       # siVoltageSubType
    my $MBMSharedInfoLen = length pack $MBMSharedInfoPattern;
    $MBMSharedInfoLen += 4 - ( $MBMSharedInfoLen % 4 )
      if ( $MBMSharedInfoLen % 4 );

    my $MBMSharedMemPattern = 'd' .    # sdVersion
      $MBMSharedIndexPattern x 10
      . $MBMSharedSensorPattern x 100
      . $MBMSharedInfoPattern . 'A41'
      .                                # sdStart    Start Time
      'A41' .                          # sdCurrent  Current Time
      'A256C';                         # sdPath

    # Due to Delphi field alignment, overall length not equal length pack $MBMSharedMemPattern
    # Instead, it is:
    my $MBMSharedMemLen =
      ( length pack 'd' ) +
      $MBMSharedIndexLen * 10 +
      $MBMSharedSensorLen * 100 +
      $MBMSharedInfoLen +
      ( length pack 'A41' ) +
      ( length pack 'A41' ) +
      ( length pack 'A256' );
    $MBMSharedMemLen += 4 - ( $MBMSharedMemLen % 4 )
      if ( $MBMSharedMemLen % 4 );

    #print "MBM_sensors.pm: Length of MBM shared memory= $MBMSharedMemLen\n";

##
    # Create objects for all the API calls we need
##

    my $OpenFileMapping =
      new Win32::API( 'kernel32', 'OpenFileMapping', 'NNP', 'N' );
    if ( not defined $OpenFileMapping ) {
        die "MBM_sensors.pm: Can't import 'OpenFileMapping' API";
    }

    my $CloseHandle = new Win32::API( 'kernel32', 'CloseHandle', 'N', 'N' );
    if ( not defined $CloseHandle ) {
        die "MBM_sensors.pm: Can't import 'CloseHandle' API";
    }

    my $MapViewOfFile =
      new Win32::API( 'kernel32', 'MapViewOfFile', 'NNNNN', 'N' );
    if ( not defined $MapViewOfFile ) {
        die "MBM_sensors.pm: Can't import 'MapViewOfFile' API";
    }

    my $UnmapViewOfFile =
      new Win32::API( 'kernel32', 'UnmapViewOfFile', 'N', 'N' );
    if ( not defined $UnmapViewOfFile ) {
        die "MBM_sensors.pm: Can't import 'UnmapViewOfFile' API";
    }

    my $RtlMoveMemory =
      new Win32::API( 'kernel32', 'RtlMoveMemory', 'PNN', 'V' );
    if ( not defined $RtlMoveMemory ) {
        die "MBM_sensors.pm: Can't import 'RtlMoveMemory' API";
    }

##
    # Make the API calls to copy MBM shared memory
##

    my $MBMhandle = $OpenFileMapping->Call( 0x4, 0, '$M$B$M$5$S$D$' );

    #print "MBM_sensors.pm: MBM Handle " . $MBMhandle . "\n";
    if ( !$MBMhandle ) {
        $MBM_sensors{error} =
          "MBM_sensors.pm: Could not obtain MBM shared memory handle. Is MBM running?";
        warn $MBM_sensors{error};
        return %MBM_sensors;
    }

    my $MBMSharedMemPtr = $MapViewOfFile->Call( $MBMhandle, 0x4, 0, 0, 0 );

    #print "MBM_sensors.pm: MBM memory " . $MBMSharedMemPtr . "\n";
    die "MBM_sensors.pm: Could not map MBM memory handle" if !$MBMSharedMemPtr;

    my $MBMSharedMem = chr(00) x $MBMSharedMemLen;
    $RtlMoveMemory->Call( $MBMSharedMem, $MBMSharedMemPtr, $MBMSharedMemLen );

    #print "MBM_sensors.pm: MBM Shared Mem Dump\n";
    #for ($i =0 ; $i <= $MBMSharedMemLen ; $i +=16) {
    #  printf "%4.4X %8.8X %8.8X %8.8X %8.8X *%16.16s*\n",
    #         $i,
    #         (unpack "x$i".'NNNN', $MBMSharedMem),
    #         (unpack "x$i".'A32', $MBMSharedMem) ;
    #}

    $rc = $UnmapViewOfFile->Call($MBMSharedMemPtr);
    die "MBM_sensors.pm: Could not unmap MBM memory pointer rc=$rc" if !$rc;

    $rc = $CloseHandle->Call($MBMhandle);
    die "MBM_sensors.pm: Could not close MBM memory handle rc=$rc" if !$rc;

##
    # Parse and Decode the MBM structure
##

    # Same comment as above: There are "tighter" ways to do this, for
    # example by not using intermediate variables but instead
    # assigning unpack directly to the hash.  The following code is
    # intended to be easy to understand and maintain when MBM changes.

    my $offset = 0;

    my $MBMsdVersion = unpack 'd', $MBMSharedMem;

    #print "MBM_sensors.pm: MBMsdVersion = $MBMsdVersion\n";
    $MBM_sensors{version} = $MBMsdVersion;
    $offset = +8;

    my $SensorTotalCount = 0;
    for ( $i = 0; $i < 10; $i++ ) {
        my ( $iType, $iCount ) = unpack "x$offset$MBMSharedIndexPattern",
          $MBMSharedMem;

        #printf "MBM_sensors.pm: At offset of %2.1d: iType=%2.2X, iCount=%2.1d\n", $offset, $iType, $iCount;
        $offset           += $MBMSharedIndexLen;
        $SensorTotalCount += $iCount;
    }

    for ( $i = 0; $i < $SensorTotalCount; $i++ ) {
        my (
            $ssType,  $ssName,  $ssCurrent, $ssLow, $ssHigh,
            $ssCount, $ssTotal, $ssAlarm1,  $ssAlarm2
        ) = unpack "x$offset$MBMSharedSensorPattern", $MBMSharedMem;

        #print "MBM_sensors.pm: $ssType, $ssName, $ssCurrent, $ssLow, $ssHigh, $ssCount, $ssTotal, $ssAlarm1, $ssAlarm2\n";
        $offset += $MBMSharedSensorLen;
        $ssType = qw(unknown temperature voltage fan MHZ CPUbusy) [$ssType];
        my $j = ++$MBM_sensors{$ssType}{num};
        $MBM_sensors{$ssType}{name}[$j]    = $ssName;
        $MBM_sensors{$ssType}{current}[$j] = $ssCurrent;
        $MBM_sensors{$ssType}{low}[$j]     = $ssLow;
        $MBM_sensors{$ssType}{high}[$j]    = $ssHigh;
        $MBM_sensors{$ssType}{count}[$j]   = $ssCount;
        $MBM_sensors{$ssType}{total}[$j] =
          $ssTotal;    # Need more work for this extended float
        $MBM_sensors{$ssType}{alarm1}[$j] = $ssAlarm1;
        $MBM_sensors{$ssType}{alarm2}[$j] = $ssAlarm2;
    }

    # Restart the offset, as we did not necessarily loop through all possible sensor slots.
    $offset = 8 + $MBMSharedIndexLen * 10 + $MBMSharedSensorLen * 100;

    my (
        $siSMB_Base, $siSMB_Type, $siSMBCode,  $siSMB_Addr,
        $siSMB_Name, $siISA_Base, $siChipType, $siVoltageSubType
    ) = unpack "x$offset$MBMSharedInfoPattern", $MBMSharedMem;

    #print "MBM_sensors.pm: Shared Info $siSMB_Base, $siSMB_Type, $siSMBCode, $siSMB_Addr, $siSMB_Name, $siISA_Base, $siChipType, $siVoltageSubType\n";
    $offset += $MBMSharedInfoLen;

    my ( $sdStart, $sdCurrent, $sdPath ) = unpack "x$offset" . "A41A41A256",
      $MBMSharedMem;

    #print "MBM_sensors.pm: Shared last part $sdStart, $sdCurrent, $sdPath\n";
    $MBM_sensors{timestart}   = $sdStart;
    $MBM_sensors{timecurrent} = $sdCurrent;
    $MBM_sensors{path}        = $sdPath;

    return %MBM_sensors;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Danal Estes, danal@earthling.net, http://www.desquared.org.

=head2 SEE ALSO

Win32::API - Aldo Calpini's "Magic", http://www.divinf.it/dada/perl/

=head2 LICENSE

Copyright (C) 2003, Danal Estes. All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

