#  Copyright (c) 1998 by Mike Blazer.  All rights reserved.
#  This program is free software; you can redistribute it and/or modify
#  it under the same terms as Perl itself.

#  Full POD documentation is availible at the end of the code

package Win32::DriveInfo;

use vars qw($VERSION);
$Win32::DriveInfo::VERSION = '0.01';

use Win32::API;
use strict 'vars';

#==================
sub GetVersionEx {
#==================
# on Win95 if returning $dwBuildNumber(low word of original)
# is greater than 1000, the system is running OSR 2 or a later release.
   my $h = new Win32::API("kernel32", "GetVersionEx", [P], N);

   my ($dwOSVersionInfoSize, $dwMajorVersion, $dwMinorVersion,
       $dwBuildNumber,       $dwPlatformId,   $szCSDVersion) =
       (148, 0, 0, 0, 0, "\0"x128);

   my $OSVERSIONINFO = pack "LLLLLa128",
      ($dwOSVersionInfoSize, $dwMajorVersion, $dwMinorVersion,
       $dwBuildNumber,       $dwPlatformId,   $szCSDVersion);

   return undef if $h->Call($OSVERSIONINFO) == 0;
   ($dwOSVersionInfoSize, $dwMajorVersion, $dwMinorVersion,
    $dwBuildNumber,       $dwPlatformId,   $szCSDVersion) =
   unpack "LLLLLa128", $OSVERSIONINFO;

   $szCSDVersion =~ s/\0.*$//;
   $szCSDVersion =~ s/^\s*(.*?)\s*$/$1/;
   $dwBuildNumber = $dwBuildNumber & 0xffff if Win32::IsWin95();

   ($dwMajorVersion, $dwMinorVersion, $dwBuildNumber,
    $dwPlatformId, $szCSDVersion);
}

#==================
sub GetDiskFreeSpace {
#==================
   my $drive = shift;
   return undef unless $drive =~ s/^([a-z])(:(\\)?)?$/$1:\\/i;

   my $h = new Win32::API("kernel32", "GetDiskFreeSpace", [P,P,P,P,P], N);
   return undef unless $h =~ /Win32::API/i;

   my ($lpRootPathName, $lpSectorsPerCluster, $lpBytesPerSector,
       $lpNumberOfFreeClusters, $lpTotalNumberOfClusters) =
       ($drive, "\0\0\0\0", "\0\0\0\0", "\0\0\0\0", "\0\0\0\0");
   return undef if $h->Call(
     $lpRootPathName, $lpSectorsPerCluster, $lpBytesPerSector,
     $lpNumberOfFreeClusters, $lpTotalNumberOfClusters
   ) == 0;

   ($lpSectorsPerCluster, $lpBytesPerSector,
    $lpNumberOfFreeClusters, $lpTotalNumberOfClusters) =
   (unpack (L,$lpSectorsPerCluster),
    unpack (L,$lpBytesPerSector),
    unpack (L,$lpNumberOfFreeClusters),
    unpack (L,$lpTotalNumberOfClusters));

   ($lpSectorsPerCluster, $lpBytesPerSector,
    $lpNumberOfFreeClusters, $lpTotalNumberOfClusters);
}

#==================
sub GetDiskFreeSpaceEx {
#==================
   my $drive = shift;
   return undef unless $drive =~ s/^([a-z])(:(\\)?)?$/$1:\\/i ||
                       $drive =~ s/^(\\\\\w+\\\w+)(\\)?$/$1\\/;

   my $h = new Win32::API("kernel32", "GetDiskFreeSpaceEx", [P,P,P,P], N);
   return undef unless $h =~ /Win32::API/i;

   my ($lpDirectoryName, $lpFreeBytesAvailableToCaller,
       $lpTotalNumberOfBytes, $lpTotalNumberOfFreeBytes) =
      ($drive, "\0\0\0\0", "\0\0\0\0", "\0\0\0\0");

   return undef if $h->Call(
     $lpDirectoryName, $lpFreeBytesAvailableToCaller,
     $lpTotalNumberOfBytes, $lpTotalNumberOfFreeBytes
   ) == 0;

   ($lpFreeBytesAvailableToCaller,
    $lpTotalNumberOfBytes,
    $lpTotalNumberOfFreeBytes) =
   (unpack (L,$lpFreeBytesAvailableToCaller),
    unpack (L,$lpTotalNumberOfBytes),
    unpack (L,$lpTotalNumberOfFreeBytes));

   ($lpFreeBytesAvailableToCaller, $lpTotalNumberOfBytes,
    $lpTotalNumberOfFreeBytes);
}

#==================
sub DriveType {
#==================
   my $drive = shift;
   return undef unless $drive =~ s/^([a-z])(:(\\)?)?$/$1:\\/i ||
                       $drive =~ s/^(\\\\\w+\\\w+)(\\)?$/$1\\/;

   my $h = new Win32::API("kernel32", "GetDriveType", [P], N);
   return undef unless $h =~ /Win32::API/i;

   my ($lpDirectoryName) = $drive;

   my $type = $h->Call( $lpDirectoryName );
}

#==================
sub DriveSpace {
#==================
  my $drive = shift;
  return undef unless $drive =~ s/^([a-z])(:(\\)?)?$/$1:\\/i ||
                      $drive =~ s/^(\\\\\w+\\\w+)(\\)?$/$1\\/;

  my ($MajorVersion, $MinorVersion, $BuildNumber, $PlatformId, $BuildStr) = GetVersionEx();
  my ($FreeBytesAvailableToCaller, $TotalNumberOfBytes, $TotalNumberOfFreeBytes);

  my ($SectorsPerCluster, $BytesPerSector,
      $NumberOfFreeClusters, $TotalNumberOfClusters) = GetDiskFreeSpace($drive);

#  return undef if ! defined $BytesPerSector;

  if (Win32::IsWinNT()  || $MajorVersion > 4 ||
      $MinorVersion > 0 || $BuildNumber  > 1000) {
     ($FreeBytesAvailableToCaller,
      $TotalNumberOfBytes,
      $TotalNumberOfFreeBytes) = GetDiskFreeSpaceEx($drive);

  } elsif (defined $BytesPerSector) {
     ($FreeBytesAvailableToCaller,
      $TotalNumberOfBytes,
      $TotalNumberOfFreeBytes) = (
      $SectorsPerCluster * $BytesPerSector * $NumberOfFreeClusters,
      $SectorsPerCluster * $BytesPerSector * $TotalNumberOfClusters,
      $SectorsPerCluster * $BytesPerSector * $NumberOfFreeClusters );
  }

  ($SectorsPerCluster, $BytesPerSector,
   $NumberOfFreeClusters, $TotalNumberOfClusters,
   $FreeBytesAvailableToCaller, $TotalNumberOfBytes,
   $TotalNumberOfFreeBytes);
}

#===========================
sub DrivesInUse {
#===========================
   my (@dr, $i);
   my $h = new Win32::API("kernel32", "GetLogicalDrives", [], N);
   return undef unless $h =~ /Win32::API/i;

   my $bitmask = $h->Call();
   for $i(0..25) {
     push (@dr, (A..Z)[$i]) if $bitmask & 2**$i;
   }
   @dr;
}

#===========================
sub FreeDriveLetters {
#===========================
   my (@dr, $i);
   my $h = new Win32::API("kernel32", "GetLogicalDrives", [], N);
   return undef unless $h =~ /Win32::API/i;

   my $bitmask = $h->Call();
   for $i(0..25) {
     push (@dr, (A..Z)[$i]) unless $bitmask & 2**$i;
   }
   @dr;
}

#==================
sub VolumeInfo {
#==================
   my $drive = shift;
   return undef unless $drive =~ s/^([a-z])(:(\\)?)?$/$1:\\/i;

   my $h = new Win32::API("kernel32", "GetVolumeInformation", [P,P,N,P,P,P,P,N], N);
   return undef unless $h =~ /Win32::API/i;

   my ($lpRootPathName, $lpVolumeNameBuffer, $nVolumeNameSize,
       $lpVolumeSerialNumber, $lpMaximumComponentLength, $lpFileSystemFlags,
       $lpFileSystemNameBuffer, $nFileSystemNameSize) =
       ($drive, "\0"x256, 256, "\0\0\0\0", "\0\0\0\0", "\0\0\0\0", "\0"x256, 256);
   return undef if $h->Call(
     $lpRootPathName, $lpVolumeNameBuffer, $nVolumeNameSize,
     $lpVolumeSerialNumber, $lpMaximumComponentLength, $lpFileSystemFlags,
     $lpFileSystemNameBuffer, $nFileSystemNameSize
   ) == 0;

   ($lpVolumeSerialNumber, $lpMaximumComponentLength, $lpFileSystemFlags) =
   (unpack (L,$lpVolumeSerialNumber),
    unpack (L,$lpMaximumComponentLength),
    unpack (L,$lpFileSystemFlags));

   $lpVolumeNameBuffer     =~ s/\0.*$//;
   $lpFileSystemNameBuffer =~ s/\0.*$//;

   $lpVolumeSerialNumber = uc sprintf "%08x", $lpVolumeSerialNumber;
   $lpVolumeSerialNumber =~ s/(....)(....)/$1:$2/;

   my @attr;
   if ($lpFileSystemFlags & FS_CASE_IS_PRESERVED      () ) { push @attr, 1 }
   if ($lpFileSystemFlags & FS_CASE_SENSITIVE         () ) { push @attr, 2 }
   if ($lpFileSystemFlags & FS_UNICODE_STORED_ON_DISK () ) { push @attr, 3 }
   if ($lpFileSystemFlags & FS_PERSISTENT_ACLS        () ) { push @attr, 4 }
   if ($lpFileSystemFlags & FS_VOL_IS_COMPRESSED      () ) { push @attr, 5 }
   if ($lpFileSystemFlags & FS_FILE_COMPRESSION       () ) { push @attr, 6 }


   ($lpVolumeNameBuffer, $lpVolumeSerialNumber,
    $lpMaximumComponentLength, $lpFileSystemNameBuffer, @attr);
}

sub FS_CASE_IS_PRESERVED      { 0x00000002 }
sub FS_CASE_SENSITIVE         { 0x00000001 }
sub FS_UNICODE_STORED_ON_DISK { 0x00000004 }
sub FS_PERSISTENT_ACLS        { 0x00000008 }
sub FS_VOL_IS_COMPRESSED      { 0x00008000 }
sub FS_FILE_COMPRESSION       { 0x00000010 }


1;

__END__

=head1 NAME

Win32::DriveInfo - drives on Win32 systems

=head1 SYNOPSIS

    use Win32::DriveInfo;

    ($SectorsPerCluster,
     $BytesPerSector,
     $NumberOfFreeClusters,
     $TotalNumberOfClusters,
     $FreeBytesAvailableToCaller,
     $TotalNumberOfBytes,
     $TotalNumberOfFreeBytes) = Win32::DriveInfo::DriveSpace('f');

     $TotalNumberOfFreeBytes = (Win32::DriveInfo::DriveSpace('c:'))[6];

     $TotalNumberOfBytes = (Win32::DriveInfo::DriveSpace("\\\\serv\\share"))[5];

     @drives = Win32::DriveInfo::DrivesInUse();

     @freelet = Win32::DriveInfo::FreeDriveLetters();

     $type = Win32::DriveInfo::DriveType('a');

     ($VolumeName,
      $VolumeSerialNumber,
      $MaximumComponentLength,
      $FileSystemName, @attr) = Win32::DriveInfo::VolumeInfo('g');

     ($MajorVersion, $MinorVersion, $BuildNumber,
      $PlatformId, $BuildStr) = Win32::DriveInfo::GetVersionEx();

=head1 ABSTRACT

With this module you can get total/free space on Win32 drives,
volume names, architecture, filesystem type, drive attributes,
list of all available drives and free drive-letters. Additional
function to determine Windows version info.

The intention was to have a part of Dave Roth's Win32::AdminMisc
functionality on Win95/98.

The current version of Win32::DriveInfo is available at:

  http://www.dux.ru/guest/fno/perl/

=head1 DESCRIPTION

=over4

Module provides few functions:

=item DriveSpace ( drive )

C<($SectorsPerCluster, $BytesPerSector, $NumberOfFreeClusters,>
C<$TotalNumberOfClusters, $FreeBytesAvailableToCaller,>
C<$TotalNumberOfBytes, $TotalNumberOfFreeBytes) =>
B<Win32::DriveInfo::DriveSpace>( drive );

   drive - drive-letter in either 'c' or 'c:' or 'c:\\' form or UNC path
           in either "\\\\server\\share" or "\\\\server\\share\\" form.
   $SectorsPerCluster          - number of sectors per cluster.
   $BytesPerSector             - number of bytes per sector.
   $NumberOfFreeClusters       - total number of free clusters on the disk.
   $TotalNumberOfClusters      - total number of clusters on the disk.
   $FreeBytesAvailableToCaller - total number of free bytes on the disk that
                                 are available to the user associated with the
                                 calling thread, b.
   $TotalNumberOfBytes         - total number of bytes on the disk, b.
   $TotalNumberOfFreeBytes     - total number of free bytes on the disk, b.

B<Note:> in case that UNC path was given first 4 values are C<undef>.

B<Win 95 note:> Win32 API C<GetDiskFreeSpaceEx()> function that is realized
by internal (not intended for users) C<GetDiskFreeSpaceEx()> subroutine
is available on Windows 95 OSR2 (OEM Service Release 2) only. This means build
numbers (C<$BuildNumber>
in C<GetVersionEx ( )> function, described here later) greater then 1000.

On lower Win95 builds
C<$FreeBytesAvailableToCaller, $TotalNumberOfBytes, $TotalNumberOfFreeBytes> are
realized through the internal C<GetDiskFreeSpace()> function that is claimed less
trustworthy in Win32 SDK documentation.

That's why on lower Win 95 builds this function will return 7 C<undef>'s
for UNC drives.

To say in short: B<don't use C<DriveSpace ( )> for UNC paths on early Win 95!>
Where possible use

  net use * \\server\share

and then usual '\w:' syntax.

=item DrivesInUse ( )

Returns sorted array of all drive-letters in use.

=item FreeDriveLetters ( )

Returns sorted array of all drive-letters that are available for allocation.

=item DriveType ( drive )

Returns integer value:

   0     - the drive type cannot be determined.
   1     - the root directory does not exist.
   2     - the drive can be removed from the drive (removable).
   3     - the disk cannot be removed from the drive (fixed).
   4     - the drive is a remote (network) drive.
   5     - the drive is a CD-ROM drive.
   6     - the drive is a RAM disk.
 
   drive - drive-letter in either 'c' or 'c:' or 'c:\\' form or UNC path
           in either "\\\\server\\share" or "\\\\server\\share\\" form.

In case of UNC path 4 will be returned that means that
networked drive is available (1 - if not available).

=item VolumeInfo ( drive )

C<($VolumeName, $VolumeSerialNumber, $MaximumComponentLength,>
C<$FileSystemName, @attr) => B<Win32::DriveInfo::VolumeInfo> ( drive );

   drive - drive-letter in either 'c' or 'c:' or 'c:\\' form.

   $VolumeName             - name of the specified volume.
   $VolumeSerialNumber     - volume serial number.
   $MaximumComponentLength -
        filename component supported by the specified file system.
        A filename component is that portion of a filename between backslashes.
        Indicate that long names are supported by the specified file system.
        For a FAT file system supporting long names, the function stores
        the value 255, rather than the previous 8.3 indicator. Long names can
        also be supported on systems that use the New Technology file system
        (NTFS).
   $FileSystemName         - name of the file system (such as FAT or NTFS).
   @attr                   - array of integers 1-6
     1 - file system preserves the case of filenames
     2 - file system supports case-sensitive filenames
     3 - file system supports Unicode in filenames as they appear on disk
     4 - file system preserves and enforces ACLs (access-control lists).
         For example, NTFS preserves and enforces ACLs, and FAT does not.
     5 - file system supports file-based compression
     6 - specified volume is a compressed volume; for ex., a DoubleSpace volume

=item GetVersionEx ( )

This function provides version of the OS in use.

C<($MajorVersion, $MinorVersion, $BuildNumber, $PlatformId, $BuildStr) =>
B<Win32::DriveInfo::GetVersionEx> ( );

   $MajorVersion - major version number of the operating system. For Windows NT
                   version 3.51, it's 3; for Windows NT version 4.0, it's 4.

   $MinorVersion - minor version number of the operating system. For Windows NT
                   version 3.51, it's 51; for Windows NT version 4.0, it's 0.
   $BuildNumber  - build number of the operating system.
   $PlatformId   - 0 for Win32s, 1 for Win95/98 (? - not verified), 2 for Win NT
   $BuildStr     - Windows NT: Contains string, such as "Service Pack 3".
                   Indicates the latest Service Pack installed on the system.
                   If no Service Pack has been installed, the string is empty.
                   Windows 95: Contains a null-terminated string that provides
                   arbitrary additional information about the operating system.

=back

You need B<Win32::API.pm> by C<Aldo Calpini> for this module.

Nothing is exported by default. All functions return C<undef> on errors.

=head1 INSTALLATION

As this is just a plain module no special installation is needed. Just put
it into /Win32 subdir somewhere in your @INC.

=head1 CAVEATS

This module has been created and tested in a Win95 environment on GS port
of Perl 5.004_02.  Although I expect it to function correctly on other Win32
platforms and other ports, that fact has not been confirmed.

=head1 BUGS

Please report.

=head1 VERSION

This man page documents Win32::DriveInfo.pm version 0.01.

November 7, 1998.

=head1 AUTHOR

Mike Blazer C<<>blazer@mail.nevalink.ruC<>>

=head1 COPYRIGHT

Copyright (C) 1998 by Mike Blazer. All rights reserved.

=head1 LICENSE

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
