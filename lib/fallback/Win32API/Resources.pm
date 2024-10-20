# Resource.pm - Use Win32::API to retrieve popular 
# 		resources from Kernel32.dll and others
#
# Created by Brad Turner
#            bsturner@sprintparanet.com
#            Friday, April 09, 1999
#
# Updated on Wednesday, July 21, 1999
#
# All functions verfied on Win95a and WinNT 4.0
# (see the notes on GetDiskFreeSpace and GetDiskFreeSpaceEx)
###############################################
package Win32API::Resources;

use Win32;
use Win32::API;
use strict qw(vars);
$Win32API::Resources::VERSION = '0.06';

#*********************************************************
#*  IsEXE16 wrapper around GetBinaryType API - based on code by Aldo Calpini
#*********************************************************
sub IsEXE16
	{
	# Simple file test - returns 1 if file is 16-bit, 0 if file is 32 bit
	# SHGetFileInfo will work on both WinNT and Win95a systems

	my $SHGFI = new Win32::API("shell32", "SHGetFileInfo", [qw(P L P I I)], 'L');
	my($file) = @_;
	my $result; 
	my $type = undef;

	if($SHGFI)
		{
		$result = $SHGFI->Call($file, 0, 0, 0, 0x2000);
		if($result)
			{
			$type .= ", " if $type;

			my $hi = $result >> 16;
			my $lo = $result & 0x0000FFFF;
			$lo = sprintf("%c%c", $lo & 0x00FF, $lo >> 8);
        
			if($hi)
				{
				$hi = sprintf("%d.%02d", $hi >> 8, $hi & 0x00FF);
				}
			if (($lo eq "NE") and ($hi ge "3.0"))
				{
				$type = 1;
				}
			elsif (($lo eq "PE") and ($hi ge "3.0"))
				{
				$type = 0;
				}
			elsif (($lo eq "PE") and ($hi eq NULL))
				{
				$type = 0;
				}
			elsif (($lo eq "MZ") and ($hi eq NULL))
				{
				$type = 1;
				}
			}
		}
	return $type;
	}
#*********************************************************
#*  IsEXE32 wrapper around GetBinaryType API - based on code by Aldo Calpini
#*********************************************************
sub IsEXE32
	{
	# Simple file test - returns 1 if file is 32-bit, 0 if file is 16 bit
	# SHGetFileInfo will work on both WinNT and Win95a systems

	my $SHGFI = new Win32::API("shell32", "SHGetFileInfo", [qw(P L P I I)], 'L');
	my($file) = @_;
	my $result; 
	my $type = undef;

	if($SHGFI)
		{
		$result = $SHGFI->Call($file, 0, 0, 0, 0x2000);
		if($result)
			{
			$type .= ", " if $type;

			my $hi = $result >> 16;
			my $lo = $result & 0x0000FFFF;
			$lo = sprintf("%c%c", $lo & 0x00FF, $lo >> 8);
        
			if($hi)
				{
				$hi = sprintf("%d.%02d", $hi >> 8, $hi & 0x00FF);
				}
			if (($lo eq "NE") and ($hi ge "3.0"))
				{
				$type = 0;
				}
			elsif (($lo eq "PE") and ($hi ge "3.0"))
				{
				$type = 1;
				}
			elsif (($lo eq "PE") and ($hi eq NULL))
				{
				$type = 1;
				}
			elsif (($lo eq "MZ") and ($hi eq NULL))
				{
				$type = 0;
				}
			}
		}
	return $type;
	}
#*********************************************************
#*  GetBinaryType API direct - by Aldo Calpini
#*********************************************************
sub GetBinaryType
	{
	# GetBinaryType has the advantage of detecting POSIX and OS/2 based applications
	# however it cannot differentiate between 32-bit apps that are console or window based

	# BOOL GetBinaryType (
	# LPCTSTR lpApplicationName,  // pointer to fully qualified path of file to test
	# LPDWORD lpBinaryType        // pointer to variable to receive binary type information);

	my $GBT = new Win32::API("kernel32", "GetBinaryType", [qw(P P)], 'N');
	my($file) = @_;
	my $result; 
	my $type = undef;
	if(Win32::IsWinNT)
		{
		my @typename = (
		"Win32 based application",
		"MS-DOS based application",
		"16-bit Windows based application",
		"PIF file that executes an MS-DOS based application",
		"POSIX based application",
		"16-bit OS/2 based application");

	        my $typeindex = pack("L", 0);
		$result = $GBT->Call($file, $typeindex);
		$type = $typename[unpack("L", $typeindex)] if $result;
		}
	else	{
		print "Win32API::Resources::GetBinaryType only works in WinNT\n";
		return 0;
		}
	return $type;
	}
#*********************************************************
#*  ExeType Wrapper around SHGetFileInfo API - by Aldo Calpini
#*********************************************************
sub ExeType
	{
	# GetBinaryType has the advantage of detecting POSIX and OS/2 based applications
	# however it cannot differentiate between 32-bit apps that are console or window based
	#
	# SHGetFileInfo will work on both WinNT and Win95a systems

	# WINSHELLAPI DWORD WINAPI SHGetFileInfo(
	# LPCTSTR pszPath,
	# DWORD dwFileAttributes,
	# SHFILEINFO FAR *psfi,
	# UINT cbFileInfo,
	# UINT uFlags);

	my $SHGFI = new Win32::API("shell32", "SHGetFileInfo", [qw(P L P I I)], 'L');
	my($file) = @_;
	my $result; 
	my $type = undef;

	if($SHGFI)
		{
		$result = $SHGFI->Call($file, 0, 0, 0, 0x2000);
		if($result)
			{
			$type .= ", " if $type;

			my $hi = $result >> 16;
			my $lo = $result & 0x0000FFFF;
			$lo = sprintf("%c%c", $lo & 0x00FF, $lo >> 8);
        
			if($hi)
				{
				$hi = sprintf("%d.%02d", $hi >> 8, $hi & 0x00FF);
				}
			if (($lo eq "NE") and ($hi ge "3.0"))
				{
				$type = "16-bit Windows based application, $lo $hi";
				}
			elsif (($lo eq "PE") and ($hi ge "3.0"))
				{
				$type = "32-bit Windows based application, $lo $hi";
				}
			elsif (($lo eq "PE") and ($hi eq NULL))
				{
				$type = "32-bit Win32 console based application, $lo $hi";
				}
			elsif (($lo eq "MZ") and ($hi eq NULL))
				{
				$type = "MS-DOS based application, $lo $hi";
				}
			else	{
				$type = "Unknown, $lo $hi";
				}
			}
		}
	return $type;
	}
#*********************************************************
#*  GetDriveSpace API sub - this calls the right API depending on the OS Version
#*********************************************************
sub GetDriveSpace
	{
	# Frontend to GetDiskFreeSpace and GetDiskFreeSpaceEx -
	# Call the correct function depending on which version of the OS you have
	my $drive = $_[0];
	my (%DSpace);

	if (Win32::IsWinNT)
		{
		my $OS = "Windows NT";

		# We're on NT so we can call the good function
		%DSpace = Win32API::Resources::GetDiskFreeSpaceEx($drive) or return 0;
		}
	elsif (Win32::IsWin95)
		{
		my $OS = "Windows 95";
		my ($servicepack, $major, $minor, $buildnum, $platformid, $l, $m);

		# We're on 95 so we first need check if we're OSR2
		($servicepack, $major, $minor, $buildnum, $platformid) = Win32::GetOSVersion;
		$l = $buildnum & 0xFFFF; #get only the least significant 16
		$m = $buildnum >> 16;    #get only the most significant 16
		if (("$major, $minor, $l, $m") gt ("4, 0, 950, 1024"))
			{
			# We're OSR2 - Calling GetDiskFreeSpaceEx
			%DSpace = Win32API::Resources::GetDiskFreeSpaceEx($drive) or return 0;
			}
		elsif (("$major, $minor, $l, $m") le ("4, 0, 950, 1024"))
			{
			# We're OSR1 - Calling GetDiskFreeSpace
			%DSpace = Win32API::Resources::GetDiskFreeSpace($drive) or return 0;
			}
		else	{
			# Not sure what it is - call the safe one
			%DSpace = Win32API::Resources::GetDiskFreeSpace($drive) or return 0;
			}
		}
	return %DSpace;
	}
#*********************************************************
#*  GetDiskFreeSpace API sub
#*********************************************************
sub GetDiskFreeSpace
	{
	# The GetDiskFreeSpaceEx function lets you avoid the arithmetic required by the 
	# GetDiskFreeSpace function. However, GetDiskFreeSpaceEx will not work on Win95 OSR1

	# Windows 95: 
	# The GetDiskFreeSpace function returns incorrect values for volumes that are 
	# larger than 2 gigabytes. The function caps the values stored into *lpNumberOfFreeClusters 
	# and *lpTotalNumberOfClusters so as to never report volume sizes that are greater 
	# than 2 gigabytes. 
	# Even on volumes that are smaller than 2 gigabytes, the values stored into 
	# *lpSectorsPerCluster, *lpNumberOfFreeClusters, and *lpTotalNumberOfClusters values 
	# may be incorrect. That is because the operating system manipulates the values so that 
	# computations with them yield the correct volume size. 

	# Windows 95 OSR2 and later: 
	# The GetDiskFreeSpaceEx function is available on Windows 95 systems beginning with OEM 
	# Service Release 2 (OSR2). The GetDiskFreeSpaceEx function returns correct values for 
	# all volumes, including those that are greater than 2 gigabytes. 

	# BOOL GetDiskFreeSpace(  
	# LPCTSTR lpRootPathName,    		// pointer to root path
	# LPDWORD lpSectorsPerCluster,  	// pointer to sectors per cluster
	# LPDWORD lpBytesPerSector,  		// pointer to bytes per sector
	# LPDWORD lpNumberOfFreeClusters,	// pointer to number of free clusters
	# LPDWORD lpTotalNumberOfClusters	// pointer to total number of clusters);

	my $lpRootPathName = $_[0];
	# Windows 95: The initial release of Windows 95 does not support UNC paths for 
	# the lpRootPathName parameter. To query the free disk space using a UNC path, 
	# temporarily map the UNC path to a drive letter, query the free disk space on 
	# the drive, then remove the temporary mapping. 
	# Windows 95 OSR2 and later: UNC paths are supported. 

	my $lpSectorsPerCluster = "\0" x 32;
	my $lpBytesPerSector = "\0" x 32;
	my $lpNumberOfFreeClusters = "\0" x 32;
	my $lpTotalNumberOfClusters = "\0" x 32;

	# GetDiskFreeSpace API direct
	my $GetDiskFreeSpace = new Win32::API("kernel32", "GetDiskFreeSpaceA", [qw(P P P P P)], 'N') or return 0;
	$GetDiskFreeSpace->Call($lpRootPathName, $lpSectorsPerCluster, $lpBytesPerSector, $lpNumberOfFreeClusters, $lpTotalNumberOfClusters) or return 0;
	$lpSectorsPerCluster = unpack("L", $lpSectorsPerCluster);
	$lpBytesPerSector = unpack("L", $lpBytesPerSector);
	$lpNumberOfFreeClusters = unpack("L", $lpNumberOfFreeClusters);
	$lpTotalNumberOfClusters = unpack("L", $lpTotalNumberOfClusters);
	my $DriveSpaceTotal = $lpTotalNumberOfClusters * $lpSectorsPerCluster * $lpBytesPerSector;
	my $DriveSpaceFree = $lpNumberOfFreeClusters * $lpSectorsPerCluster * $lpBytesPerSector;
 
	my %DSpace = (	SectorsPerCluster 	=> $lpSectorsPerCluster,
			BytesPerSector 		=> $lpBytesPerSector,
			NumberOfFreeClusters 	=> $lpNumberOfFreeClusters,
			TotalNumberOfClusters 	=> $lpTotalNumberOfClusters,
			DriveSpaceTotal		=> $DriveSpaceTotal,
			DriveSpaceFree	 	=> $DriveSpaceFree);
	return %DSpace;
	}
#*********************************************************
#*  GetDiskFreeSpaceEx API sub
#*********************************************************
sub GetDiskFreeSpaceEx
	{
	# Windows 95 OSR2: The GetDiskFreeSpaceEx function is available on Windows 95 
	# systems beginning with OEM Service Release 2 (OSR2). 

	# BOOL GetDiskFreeSpaceEx(
	# LPCTSTR lpDirectoryName,                 	// pointer to the directory name
	# PULARGE_INTEGER lpFreeBytesAvailableToCaller, // receives the number of bytes on disk available to the caller
	# PULARGE_INTEGER lpTotalNumberOfBytes,    	// receives the number of bytes on disk
	# PULARGE_INTEGER lpTotalNumberOfFreeBytes 	// receives the free bytes on disk);

	my $lpDirectoryName = $_[0];
	my $lpFreeBytesAvailableToCaller = "\0" x 32;
	my $lpTotalNumberOfBytes = "\0" x 32;
	my $lpTotalNumberOfFreeBytes = "\0" x 32;

	# GetDiskFreeSpace API direct
	my $GetDiskFreeSpaceEx = new Win32::API("kernel32", "GetDiskFreeSpaceExA", [qw(P P P P)], 'N') or return 0;
	$GetDiskFreeSpaceEx->Call($lpDirectoryName, $lpFreeBytesAvailableToCaller, $lpTotalNumberOfBytes, $lpTotalNumberOfFreeBytes) or return 0;
 	$lpFreeBytesAvailableToCaller = UnpackLargeInt($lpFreeBytesAvailableToCaller);
	$lpTotalNumberOfBytes = UnpackLargeInt($lpTotalNumberOfBytes);
	$lpTotalNumberOfFreeBytes = UnpackLargeInt($lpTotalNumberOfFreeBytes);

	my %DSpace = (	DriveSpaceQuotaFree 	=> $lpFreeBytesAvailableToCaller,
			DriveSpaceTotal		=> $lpTotalNumberOfBytes,
			DriveSpaceFree	 	=> $lpTotalNumberOfFreeBytes);
	return %DSpace;
	}
#*********************************************************
#*  GlobalMemoryStatus API sub
#*********************************************************
sub GlobalMemoryStatus
	{
	# VOID GlobalMemoryStatus(
	# LPMEMORYSTATUS lpBuffer   // pointer to the memory status structure);

	my $GMSBuffer = "\0" x 32;
	my %GMStatus;

	# GlobalMemoryStatus API direct
	my $GlobalMemoryStatus = new Win32::API("kernel32", "GlobalMemoryStatus", [qw(P)], 'N') or return 0;
	$GlobalMemoryStatus->Call($GMSBuffer) or return 0;
	my @GMSBuffer= unpack("L*", $GMSBuffer);

	# MEMORYSTATUS structure - tip o' the hat to Win32::AdminMisc
	%GMStatus = (	Load 		=> $GMSBuffer[1],
			RAMTotal 	=> $GMSBuffer[2],
			RAMAvail 	=> $GMSBuffer[3],
			PageTotal 	=> $GMSBuffer[4],
			PageAvail 	=> $GMSBuffer[5],
			VirtTotal 	=> $GMSBuffer[6],
			VirtAvail 	=> $GMSBuffer[7]);

	return %GMStatus;
	}
#*********************************************************
#*  LoadString API sub
#*********************************************************
sub LoadString
	{
	# int LoadString(
	# HINSTANCE hInstance,  // handle to module containing string resource
	# UINT uID,             // resource identifier
	# LPTSTR lpBuffer,      // pointer to buffer for resource
	# int nBufferMax        // size of buffer);

	my $file = $_[0];					# The file passed from main (DLL/EXE)
	my $uID = $_[1];					# The resource identifier
	my $LLHandle = "\0" x 32;
	my $lpBuffer = "\0" x 64;
	my ($LSBuffer);

	# Win32::LoadLibrary method - requires use Win32
	$LLHandle = Win32::LoadLibrary($file);			# Map the DLL into memory

	# LoadString API direct
	my $LoadString = new Win32::API("user32", "LoadStringA", [qw(N I P I)], 'I') or return 0;
	$LSBuffer = $LoadString->Call($LLHandle, $uID, $lpBuffer, 64) or return 0;
	$lpBuffer = ((split(/\0/, $lpBuffer))[0]);		# Strip out the excess buffer

	return $lpBuffer;
	}
#*********************************************************
#*  EnumString API wrapper around LoadString to Enumerate table
#*********************************************************
sub EnumString
	{
	# Place a wrapper around LoadString to Enumerate all entries

	# int LoadString(
	# HINSTANCE hInstance,  // handle to module containing string resource
	# UINT uID,             // resource identifier
	# LPTSTR lpBuffer,      // pointer to buffer for resource
	# int nBufferMax        // size of buffer);

	my $file = $_[0];					# The file passed from main (DLL/EXE)
	my $uID = 1;						# The resource identifier
	my $L = 1;
	my $LLHandle = "\0" x 32;
	my $lpBuffer = "\0" x 64;
	my (@lpBuffer, $LSBuffer);

	# Win32::LoadLibrary method - requires use Win32
	$LLHandle = Win32::LoadLibrary($file);			# Map the DLL into memory

	# LoadString API direct
	my $LoadString = new Win32::API("user32", "LoadStringA", [qw(N I P I)], 'I') or return 0;

	while ($L)
		{
		$LSBuffer = $LoadString->Call($LLHandle, $uID, $lpBuffer, 64) or $L = undef;
		push(@lpBuffer, ((split(/\0/, $lpBuffer))[0]));	# Strip out the excess buffer and place it in the list
		$uID++;
		}		

	return @lpBuffer;
	}
#*********************************************************
#*  GetFileVersion sub
#*	with help from blazer@mail.nevalink.ru
#*********************************************************
sub GetFileVersion
	{
	# GetFileVersionInfoSize is used to find the size of record to retrieve
	# DWORD GetFileVersionInfoSize(
	# LPTSTR lptstrFilename,  	// pointer to filename string
	# LPDWORD lpdwHandle      	// pointer to variable to receive zero);

	# GetFileVersionInfo is used to retrieve the record itself
	# BOOL GetFileVersionInfo(  
	# LPTSTR lptstrFilename,  	// pointer to filename string
	# DWORD dwHandle,         	// ignored
	# DWORD dwLen,			// size of buffer
	# LPVOID lpData           	// pointer to buffer to receive file-version info.);

	my $filename = shift(@_);
	my $switch = shift(@_);
	my (%PAT);
	my ($lpBufferSize, $lpHandle, $lpBuffer);
	
	my $GetFileVersionInfoSize = new Win32::API("version", "GetFileVersionInfoSizeA", [qw(P P)], 'N');
	$lpHandle = DWORD_NULL;
	$lpBufferSize = $GetFileVersionInfoSize->Call($filename, $lpHandle);
	$lpBuffer = "\0" x $lpBufferSize;

	my $GetFileVersionInfo = new Win32::API("version", "GetFileVersionInfoA", [qw(P N N P)], 'N');
	if (!-e $filename and $switch)
		{
		# If the filename is not found and the Optional switch is used, 
		# return an array of zero valued keys
		return %PAT = (	Comments		=> 0,
				CharacterSet		=> 0,
				Language		=> 0,
				ProductName 		=> 0,
				OriginalFilename 	=> 0,
				LegalCopyright 		=> 0,
				LegalTrademarks		=> 0,
				InternalName 		=> 0,
				FileDescription 	=> 0,
				CompanyName 		=> 0,
				SpecialBuild		=> 0,
				PrivateBuild		=> 0,
				FileVersion 		=> 0,
				FileVersionMS 		=> 0,
				FileVersionLS 		=> 0,
				FileVersion64 		=> 0,
				ProductVersion  	=> 0,
				ProductVersionMS 	=> 0,
				ProductVersionLS 	=> 0,
				ProductVersion64	=> 0,
				FileType 		=> 0,
				FileSubtype 		=> 0,
				FileOS 			=> 0,
				FileFlags		=> 0);
		}
	elsif (!-e $filename)
		{
		# If the filename is not found and no switch is specified
		# return undefined
		return;
		}
	elsif (-e $filename)
		{
		if(!$GetFileVersionInfo->Call($filename, 0, $lpBufferSize, $lpBuffer))
			{
			# The file does not contain a FixedFile or StringFile Info block
			# return undefined
			return;
			}
		}

	# VerQueryValue function returns selected version information from the specified 
	# version-information resource
	# BOOL VerQueryValue(
	# const LPVOID pBlock, // address of buffer for version resource
	# LPTSTR lpSubBlock,   // address of value to retrieve
	# LPVOID *lplpBuffer,  // address of buffer for version value pointer
	# PUINT puLen          // address of length buffer);

	my ($lplpBuffer, $puLen) = (DWORD_NULL, DWORD_NULL);
 	my $VerQueryValue = new Win32::API("version", "VerQueryValueA", [qw(P P P P)], 'N');

	# Searching "\\" gets us the VS_FIXEDFILEINFO block which has to be unpacked carefully
	$VerQueryValue->Call($lpBuffer, "\\", $lplpBuffer, $puLen);

	$puLen = unpack("L", $puLen);
	my $buffer = unpack("P$puLen", $lplpBuffer);
	my (	$dwFileVersionMS, $dwFileVersionLS, $dwProductVersionMS, $dwProductVersionLS, 
		$dwFileFlagsMask, $dwFileFlags, $dwFileOS, $dwFileType, $dwFileSubtype, 
		$dwFileDateMS, $dwFileDateLS) = unpack("x8LLLLLLLLLLL", $buffer);

	# Reverse Lookup Tables
	my %FileOS = (	0x00000000 => VOS_UNKNOWN,
			0x00010000 => VOS_DOS,
			0x00020000 => VOS_OS216,
			0x00030000 => VOS_OS232,
			0x00040000 => VOS_NT,
			0x00010001 => VOS_DOS_WINDOWS16,
			0x00010004 => VOS_DOS_WINDOWS32,
			0x00020002 => VOS_OS216_PM16,
			0x00030003 => VOS_OS232_PM32,
			0x00040004 => VOS_NT_WINDOWS32,
			0x00000000 => VOS__BASE,
			0x00000001 => VOS__WINDOWS16,
			0x00000002 => VOS__PM16,
			0x00000003 => VOS__PM32,
			0x00000004 => VOS__WINDOWS32);
	my %FileFlags = (0x00000000 => VS_UNKNOWN,
			0xFEEF04BD => VS_FFI_SIGNATURE,
			0x00010000 => VS_FFI_STRUCVERSION,
			0x0000003F => VS_FFI_FILEFLAGSMASK,
			0x00000001 => VS_FF_DEBUG,
			0x00000002 => VS_FF_PRERELEASE,
			0x00000004 => VS_FF_PATCHED,
			0x00000008 => VS_FF_PRIVATEBUILD,
			0x00000010 => VS_FF_INFOINFERRED,
			0x00000020 => VS_FF_SPECIALBUILD);
	my %FileType = (0x00000000 => VFT_UNKNOWN,
			0x00000001 => VFT_APP,
			0x00000002 => VFT_DLL,
			0x00000003 => VFT_DRV,
			0x00000004 => VFT_FONT,
			0x00000005 => VFT_VXD,
			0x00000007 => VFT_STATIC_LIB);
	my %VFT_DRV = (	0x00000000 => VFT2_UNKNOWN,
			0x00000001 => VFT2_DRV_PRINTER,
			0x00000002 => VFT2_DRV_KEYBOARD,
			0x00000003 => VFT2_DRV_LANGUAGE,
			0x00000004 => VFT2_DRV_DISPLAY,
			0x00000005 => VFT2_DRV_MOUSE,
			0x00000006 => VFT2_DRV_NETWORK,
			0x00000007 => VFT2_DRV_SYSTEM,
			0x00000008 => VFT2_DRV_INSTALLABLE,
			0x00000009 => VFT2_DRV_SOUND,
			0x0000000A => VFT2_DRV_COMM,
			0x0000000B => VFT2_DRV_INPUTMETHOD);
	my %VFT_FONT = (0x00000001 => VFT2_FONT_RASTER,
			0x00000002 => VFT2_FONT_VECTOR,
			0x00000003 => VFT2_FONT_TRUETYPE);

	my ($t);
	$PAT{FileVersionMS} 	= $dwFileVersionMS;
	$PAT{FileVersionLS} 	= $dwFileVersionLS;
	$PAT{FileVersion64} 	= sprintf ("%.1d.%.2d", ($dwFileVersionMS >> 16),($dwFileVersionMS & 0xFFFF)).(($t = $dwFileVersionLS >> 16) ? sprintf (".%.1d", $t) : "").sprintf (".%.1d",($dwFileVersionLS & 0xFFFF));
	$PAT{ProductVersionMS} 	= $dwProductVersionMS;
	$PAT{ProductVersionLS} 	= $dwProductVersionLS;
	$PAT{ProductVersion64}	= sprintf ("%.1d.%.2d", ($dwProductVersionMS >> 16),($dwProductVersionMS & 0xFFFF)).(($t = $dwProductVersionLS >> 16) ? sprintf (".%.1d", $t) : "").sprintf (".%.1d",($dwProductVersionLS & 0xFFFF));
	$PAT{FileType} 		= $FileType{$dwFileType};
	$PAT{FileSubtype} 	= ${$FileType{$dwFileType}}{$dwFileSubtype} if (${$FileType{$dwFileType}}{$dwFileSubtype});
	$PAT{FileOS} 		= $FileOS{$dwFileOS};
	$PAT{FileFlags}		= $FileFlags{$dwFileFlags};

	($lplpBuffer, $puLen) = (DWORD_NULL, DWORD_NULL);

	# Searching "\\VarFileInfo\\Translation" is an attempt to find the Language and Character Set of the file
	$VerQueryValue->Call($lpBuffer, "\\VarFileInfo\\Translation", $lplpBuffer, $puLen);

	$puLen = unpack("L", $puLen);
	my $lang_charset = unpack("P$puLen", $lplpBuffer);
	$lang_charset = unpack("H*", $lang_charset);
	$lang_charset =~ s/(..)(..)/$2$1/g;

	# If the Language is "Language Neutral" (0000) then the following call will fail, so set it artificially to
	# English (United States) (0409)
	# NOTE: This may not work if another language is configured, may have to ask the OS for Language and
	# append here...
	$lang_charset = '040904e4' if (substr($lang_charset, 0, 4) == 0000);
	my $Language = substr($lang_charset, 0, 4);
	my $CharSet = substr($lang_charset, 4, 8);

	# Reverse lookup tables for Character Set and Language
	my %CharSet = (	'0000' => '7-bit ASCII',
			'03a4' => 'Japan (Shift - JIS X-0208)',
			'03b5' => 'Korea (Shift - KSC 5601)',
			'03b6' => 'Taiwan (Big5)',
			'04b0' => 'Unicode',
			'04e2' => 'Latin-2 (Eastern European)',
			'04e3' => 'Cyrillic',
			'04e4' => 'Multilingual',
			'04e5' => 'Greek',
			'04e6' => 'Turkish',
			'04e7' => 'Hebrew',
			'04e8' => 'Arabic');
	$PAT{CharacterSet}	= $CharSet{$CharSet};
	my %Language = ('0000' => 'Language Neutral', 
			'0400' => 'Process Default Language',
			'0401' => 'Arabic (Saudi Arabia)',
			'0801' => 'Arabic (Iraq)', 
			'0c01' => 'Arabic (Egypt)', 
			'1001' => 'Arabic (Libya)', 
			'1401' => 'Arabic (Algeria)', 
			'1801' => 'Arabic (Morocco)', 
			'1c01' => 'Arabic (Tunisia)', 
			'2001' => 'Arabic (Oman)', 
			'2401' => 'Arabic (Yemen)', 
			'2801' => 'Arabic (Syria)', 
			'2c01' => 'Arabic (Jordan)', 
			'3001' => 'Arabic (Lebanon)', 
			'3401' => 'Arabic (Kuwait)', 
			'3801' => 'Arabic (U.A.E.)', 
			'3c01' => 'Arabic (Bahrain)', 
			'4001' => 'Arabic (Qatar)', 
			'0402' => 'Bulgarian', 
			'0403' => 'Catalan', 
			'0404' => 'Chinese (Taiwan Region)',
			'0804' => 'Chinese (PRC)', 
			'0c04' => 'Chinese (Hong Kong SAR, PRC)',
			'1004' => 'Chinese (Singapore)', 
			'0405' => 'Czech', 
			'0406' => 'Danish', 
			'0407' => 'German (Standard)', 
			'0807' => 'German (Swiss)', 
			'0c07' => 'German (Austrian)', 
			'1007' => 'German (Luxembourg)', 
			'1407' => 'German (Liechtenstein)', 
			'0408' => 'Greek', 
			'0409' => 'English (United States)',
			'0809' => 'English (United Kingdom)', 
			'0c09' => 'English (Australian)', 
			'1009' => 'English (Canadian)', 
			'1409' => 'English (New Zealand)', 
			'1809' => 'English (Ireland)', 
			'1c09' => 'English (South Africa)', 
			'2009' => 'English (Jamaica)', 
			'2409' => 'English (Caribbean)', 
			'2809' => 'English (Belize)', 
			'2c09' => 'English (Trinidad)', 
			'040a' => 'Spanish (Traditional Sort)', 
			'080a' => 'Spanish (Mexican)', 
			'0c0a' => 'Spanish (Modern Sort)', 
			'100a' => 'Spanish (Guatemala)', 
			'140a' => 'Spanish (Costa Rica)', 
			'180a' => 'Spanish (Panama)', 
			'1c0a' => 'Spanish (Dominican Republic)',
			'200a' => 'Spanish (Venezuela)', 
			'240a' => 'Spanish (Colombia)', 
			'280a' => 'Spanish (Peru)', 
			'2c0a' => 'Spanish (Argentina)',
			'300a' => 'Spanish (Ecuador)', 
			'340a' => 'Spanish (Chile)', 
			'380a' => 'Spanish (Uruguay)', 
			'3c0a' => 'Spanish (Paraguay)', 
			'400a' => 'Spanish (Bolivia)', 
			'440a' => 'Spanish (El Salvador)', 
			'480a' => 'Spanish (Honduras)', 
			'4c0a' => 'Spanish (Nicaragua)', 
			'500a' => 'Spanish (Puerto Rico)', 
			'040b' => 'Finnish', 
			'040c' => 'French (Standard)',
			'080c' => 'French (Belgian)', 
			'0c0c' => 'French (Canadian)', 
			'100c' => 'French (Swiss)', 
			'140c' => 'French (Luxembourg)', 
			'040d' => 'Hebrew', 
			'040e' => 'Hungarian', 
			'040f' => 'Icelandic', 
			'0410' => 'Italian (Standard)', 
			'0810' => 'Italian (Swiss)', 
			'0411' => 'Japanese', 
			'0412' => 'Korean', 
			'0812' => 'Korean (Johab)', 
			'0413' => 'Dutch (Standard)', 
			'0813' => 'Dutch (Belgian)', 
			'0414' => 'Norwegian (Bokmal)', 
			'0814' => 'Norwegian (Nynorsk)', 
			'0415' => 'Polish', 
			'0416' => 'Portuguese (Brazilian)', 
			'0816' => 'Portuguese (Standard)', 
			'0418' => 'Romanian', 
			'0419' => 'Russian', 
			'041a' => 'Croatian', 
			'081a' => 'Serbian (Latin)',
			'0c1a' => 'Serbian (Cyrillic)', 
			'041b' => 'Slovak', 
			'041c' => 'Albanian', 
			'041d' => 'Swedish', 
			'081d' => 'Swedish (Finland)',
			'041e' => 'Thai',
			'041f' => 'Turkish', 
			'0421' => 'Indonesian', 
			'0422' => 'Ukrainian', 
			'0423 '=> 'Belarusian', 
			'0424 '=> 'Slovenian', 
			'0425 '=> 'Estonian', 
			'0426' => 'Latvian', 
			'0427' => 'Lithuanian', 
			'0429' => 'Farsi', 
			'042a' => 'Vietnamese', 
			'042d' => 'Basque', 
			'0436' => 'Afrikaans', 
			'0438' => 'Faeroese'); 
	$PAT{Language}		= $Language{$Language};

	my $String;
	my @StringFileInfo = qw(Comments CompanyName FileDescription FileVersion InternalName LegalCopyright LegalTrademarks OriginalFilename PrivateBuild ProductName ProductVersion SpecialBuild);
	foreach $String (@StringFileInfo)
		{
		($lplpBuffer, $puLen) = (DWORD_NULL, DWORD_NULL);
		$VerQueryValue->Call($lpBuffer, "\\StringFileInfo\\$lang_charset\\$String", $lplpBuffer, $puLen) or next;
		$puLen = unpack("L", $puLen);
		$PAT{$String} = unpack("P$puLen", $lplpBuffer);
		$PAT{$String} =~ s/\0+$//;
		}
	return %PAT;
	}
#*********************************************************
#*  ShowKeys subroutine - list the contents of a hash with optional sorting
#*********************************************************
sub ShowKeys
	{
	# A quick and easy sub to display the contents of a Hash
	# sorted or unsorted

	my $key;
	my $title = $_[0];		# Prints the title of the Hash
	my $sort = $_[1];		# 0 = no sort, 1 = sort
	my %main = %{$_[2]};		# the reference to the Hash (\%hash)

	print "\n$title\n\n";
	if ($sort)
		{
		foreach $key (sort keys (%main))
			{
			print "$key = $main{$key}\n";
			}
		}
	else	{
		foreach $key (keys (%main))
			{
			print "$key = $main{$key}\n";
			}
		}
	}
#*********************************************************
#*  GetDrives
#*********************************************************
sub GetDrives
	{
	# In List context GetDrives returns a list of drive assignments on the local system
	# In Scalar context GetDrives returns the number of valid drive assignments
	# Passing GetDrives one of the Drive Type Constants will return:
	# 	In List context, a list of drive assignments that match the passed constant
	# 	In Scalar context, the number of valid drive assignments that match the passed constant

	# The GetLogicalDriveStrings function fills a buffer with strings that specify valid drives in the system. 

	# DWORD GetLogicalDriveStrings(
	# DWORD nBufferLength,  // size of buffer
	# LPTSTR lpBuffer       // pointer to buffer for drive strings);

	# The GetDriveType function determines whether a disk drive is a removable, fixed, CD-ROM, RAM disk, or network drive. 

	# UINT GetDriveType(
	# LPCTSTR lpRootPathName   // pointer to root path);

	# DRIVE_UNKNOWN 	The drive type cannot be determined. 
	# DRIVE_NO_ROOT_DIR 	The root directory does not exist. 
	# DRIVE_REMOVABLE 	The disk can be removed from the drive. 
	# DRIVE_FIXED 		The disk cannot be removed from the drive. 
	# DRIVE_REMOTE 		The drive is a remote (network) drive. 
	# DRIVE_CDROM 		The drive is a CD-ROM drive. 
	# DRIVE_RAMDISK 	The drive is a RAM disk. 

	my $DriveType = $_[0];				# Pass a drive type string to parse by
	my $nBufferLength = "128";
	my $lpBuffer = "\0" x 128;
	my @matchlist;
	my %DriveType = (	0x00000000 => "DRIVE_UNKNOWN",
				0x00000001 => "DRIVE_NO_ROOT_DIR",
				0x00000002 => "DRIVE_REMOVABLE",
				0x00000003 => "DRIVE_FIXED",
				0x00000004 => "DRIVE_REMOTE",
				0x00000005 => "DRIVE_CDROM",
				0x00000006 => "DRIVE_RAMDISK");

	# GetLogicalDriveStrings API direct
	my $GetLogicalDriveStrings = new Win32::API("kernel32", "GetLogicalDriveStringsA", [qw(L P)], 'N') or return 0;
	$GetLogicalDriveStrings->Call($nBufferLength, $lpBuffer) or return 0;
	my @lpBuffer = split(/\0/, $lpBuffer);		# Strip out the excess buffer and convert to list context

	# GetDriveType API direct
	my $GetDriveType = new Win32::API("kernel32", "GetDriveTypeA", [qw(P)], 'N') or return 0;
	my ($lpRootPathName);
	foreach $lpRootPathName (@lpBuffer)
		{
		my $Return = $GetDriveType->Call($lpRootPathName) or return 0;
		if ($DriveType)
			{
			if ($DriveType eq $DriveType{$Return})
				{
				push (@matchlist, $lpRootPathName);
				}
			else	{
				next;
				}
			return @matchlist;
			}
		else	{
			return @lpBuffer;
			}
		}
	}
#*********************************************************
# Enumerate the Open RAS Connections
#*********************************************************
sub RasEnumConnections
	{
	# DWORD RasEnumConnections(
	# LPRASCONN lprasconn,		// buffer to receive connections data
	# LPDWORD lpcb,			// size in bytes of buffer
	# LPDWORD lpcConnections	// number of connections written to buffer);
 
	my $lprasconn = pack("L*", 32, 0, 0, 0, 0);
	my $lpcb = pack("L", 32);
	my $lpcConnections = pack("L", 0);

	# RasEnumConnections API direct
	my $RasEnumConnections = new Win32::API("rasapi32", "RasEnumConnectionsA", [qw(P P P)], 'N');
	my $Return = $RasEnumConnections->Call($lprasconn, $lpcb, $lpcConnections);
	if ($Return == 0)
		{
		$lpcConnections = unpack("L", $lpcConnections);
		return $lpcConnections;
		}
	else	{
		return undef;
		}
	}
#*********************************************************
#*  DWORD_NULL - packs a NULL string
#*	based on code by blazer@mail.nevalink.ru
#*********************************************************
sub DWORD_NULL	{pack("L",0)}
#*********************************************************
#*  UnpackLargInt sub - unpacks a LARGE_INTEGER value
#*	based on code by blazer@mail.nevalink.ru
#*********************************************************
sub UnpackLargeInt
	{
	my $PackedValue = shift(@_);

	my ($b, $a) = unpack("LL", $PackedValue);
	my $UnpackedValue = $a*2**32+$b;

	return $UnpackedValue
	}
1;
__END__


=head1 NAME

Win32API::Resources - Use Win32::API to retrieve popular resources from Kernel32.dll and others

=head1 SYNOPSIS

  use Win32API::Resources;

  my $file = "c:\\winnt\\system32\\cmd.exe";
  my %DSpace = Win32API::Resources::GetDiskFreeSpace("C:\\");
  my %DRVSpace = Win32API::Resources::GetDriveSpace("C:\\");
  my %File = Win32API::Resources::GetFileVersion($file, 1);
  my %Mem = Win32API::Resources::GlobalMemoryStatus();
  my $Notes = Win32API::Resources::LoadString("c:\\notes\\nstrings.dll", 1);
  my @list = Win32API::Resources::EnumString("c:\\notes\\nstrings.dll");
  my $type = Win32API::Resources::ExeType($file);
  my @drives = Win32API::Resources::GetDrives(DRIVE_CDROM);
  my $Connections = Win32API::Resources::RasEnumConnections();

  if (Win32API::Resources::IsEXE16($file))
	{
	print "The file $file is 16-bit - ($type)\n";
	}
  elsif (Win32API::Resources::IsEXE32($file))
	{
	print "The file $file is 32-bit - ($type)\n";
	}
  print "There are $Connections open RAS Connections\n";
  print "The following are valid CD-Rom drives: @drives\n";
  Win32API::Resources::ShowKeys("File Information:", 1, \%File);
  Win32API::Resources::ShowKeys("Disk Space:", 0, \%DSpace);
  Win32API::Resources::ShowKeys("Drive Space:", 1, \%DRVSpace);
  Win32API::Resources::ShowKeys("Memory Stats:", 1, \%Mem);

=head1 ABSTRACT

With this module you can access a series of Win32 API's directly or via provided 
wrappers that are exported from KERNEL32.DLL, SHELL32.DLL, USER32.DLL & VERSION.DLL. 

The current version of Win32API::Resources is available at:

  http://home.earthlink.net/~bsturner/perl/index.html

=head1 CREDITS

Thanks go to Aldo Calpini for making the Win32::API module accessible as well as some 
help with GetBinaryType and ExeType functions and to Dave Roth and Jens Helberg for 
providing direction on the GetFileVersion function.  Thanks to Mike Blazer and Aldo Calpini
for fixes to the GetFileVersion function and the UnpackLargeInt function that fixes a bug
in the GetDiskFreeSpaceEx function

=head1 HISTORY

	0.06	Fixed bug with GetDiskFreeSpaceEx that reported drives over 4GB incorrectly
		Fixed and extended functionality of GetFileVersion function to correctly 
		view and return all available information
		Now runs with 'use strict qw(vars)'
		Added two new internal helper subroutines - UnpackLargeInt and DWORD_NULL
	0.05	Added RasEnumConnections function and fixed bug with GetDrives on Win95
	0.04	Added GetDrives function
	0.03	Cleaned up and fixed bug with GetDiskFreeSpaceEx
	0.02	Added some new EXEType functions
	0.01	First release

=head1 INSTALLATION

This module is shipped as a basic PM file that should be installed in your
Perl\site\lib\Win32API dir.  Written and tested for the ActivePerl 5xx
distribution, but should work in any Win32 capable port that has Win32::API.

REQUIRES Win32::API be installed

=head1 DESCRIPTION

To use this module put the following line at the beginning of your script:

	use Win32API::Resources;

Any one of the functions can be referenced by:

	var = Win32API::Resources::function

except for Win32API::Resources::ShowKeys() which does not return a value.

=head1 RETURN VALUES

Unless otherwise specified, all functions return 0 if unsuccessful and non-zero data if successful.

=head1 FUNCTIONS

=head2 Win32API::Resources::GetDiskFreeSpace

	%Hash = Win32API::Resources::GetDiskFreeSpace($drive);

$drive must refer to the root of a target drive and be followed by \\

	$drive = "C:\\";
	$drive = "$ENV{SystemDrive}\\";

Windows 95: 
The GetDiskFreeSpace function returns incorrect values for volumes that are 
larger than 2 gigabytes. 
Even on volumes that are smaller than 2 gigabytes, the values may be incorrect. 
That is because the operating system manipulates the values so that 
computations with them yield the correct volume size. 

Windows 95 OSR2 and later: 
The GetDiskFreeSpaceEx function is available on Windows 95 systems beginning with OEM 
Service Release 2 (OSR2). The GetDiskFreeSpaceEx function returns correct values for 
all volumes, including those that are greater than 2 gigabytes. 

=head2 Win32API::Resources::GetDiskFreeSpaceEx

	%Hash = Win32API::Resources::GetDiskFreeSpaceEx($drive);

B<GetDiskFreeSpaceEx will not work on Win95 OSR1>.  This function is provided for direct 
access, however it is safer to use the I<Win32API::Resources::GetDriveSpace> wrapper instead.

$drive must refer to the root of a target drive and be followed by \\

	$drive = "C:\\";
	$drive = "$ENV{SystemDrive}\\";

Windows 95 OSR2: The GetDiskFreeSpaceEx function is available on Windows 95 
systems beginning with OEM Service Release 2 (OSR2). 

=head2 Win32API::Resources::GetDriveSpace

	%Hash = Win32API::Resources::GetDriveSpace($drive);

$drive must refer to the root of a target drive and be followed by \\

	$drive = "C:\\";
	$drive = "$ENV{SystemDrive}\\";

Wrapper around GetDiskFreeSpace and GetDiskFreeSpaceEx - GetDriveSpace will 
always call the correct function depending on which version of the OS you have.

=head2 Win32API::Resources::GetFileVersion

	%Hash = Win32API::Resources::GetFileVersion($file, $return);

GetFileVersion will return all available information in both Win95 and WinNT.  

	$file is the full path to the EXE or DLL to be examined
	$return is an optional boolean switch to return the array as zero valued keys

Returns a hash with the following keys:

	CharacterSet		The character set the Language is based on
	Comments 		Comments, from the StringFileInfo block
	CompanyName		Company Name, from the StringFileInfo block
	FileDescription 	File Description, from the StringFileInfo block
	FileFlags		<see table>
	FileOS			<see table>
	FileType		<see table>
	FileSubtype		<see table>
	FileVersion 		File Version, from the StringFileInfo block
	FileVersionMS		Specifies the most significant 32 bits of the file's binary version number. 
				This member is used with FileVersionLS to form a 64-bit value used for numeric 
				comparisons. From FixedFileInfo block
	FileVersionLS		Specifies the least significant 32 bits of the file's binary version number. 
				This member is used with FileVersionMS to form a 64-bit value used for numeric 
				comparisons. From FixedFileInfo block
	FileVersion64		The 64-bit File Version representation, from FileVersionMS & LS
	InternalName 		Internal Name, from the StringFileInfo block
	Language		The internal Language version
	LegalCopyright 		Legal Copyright, from the StringFileInfo block
	LegalTrademarks 	Legal Trademarks, from the StringFileInfo block
	OriginalFilename 	Original Filename, from the StringFileInfo block
	PrivateBuild 		Private Build, from the StringFileInfo block
	ProductName 		Product Name, from the StringFileInfo block
	ProductVersion 		Produc Version, from the StringFileInfo block
	ProductVersionMS	Specifies the most significant 32 bits of the binary version number of the 
				product with which this file was distributed. This member is used with 
				ProductVersionLS to form a 64-bit value used for numeric comparisons. 
				From the FixedFileInfo block
	ProductVersionLS	Specifies the least significant 32 bits of the binary version number of the 
				product with which this file was distributed. This member is used with 
				ProductVersionMS to form a 64-bit value used for numeric comparisons. 
				From FixedFileInfo block
	ProductVersion64	The 64-bit Product Version representation, from ProductVersionMS & LS
	SpecialBuild		Special Build, from the StringFileInfo block

=head3 FileFlags Table

Contains a bitmask that specifies the Boolean attributes of the file. 
This member can include one or more of the following values: 

	Flag 			Description 
	VS_FF_DEBUG 		The file contains debugging information or is compiled with debugging features enabled. 
	VS_FF_INFOINFERRED	The file's version structure was created dynamically; therefore, some of the members 
				in this structure may be empty or incorrect. This flag should never be set in a file's 
				VS_VERSIONINFO data. 
	VS_FF_PATCHED 		The file has been modified and is not identical to the original shipping file of the 
				same version number. 
	VS_FF_PRERELEASE 	The file is a development version, not a commercially released product. 
	VS_FF_PRIVATEBUILD 	The file was not built using standard release procedures. If this flag is set, the 
				StringFileInfo structure should contain a PrivateBuild entry. 
	VS_FF_SPECIALBUILD 	The file was built by the original company using standard release procedures but is 
				a variation of the normal file of the same version number. If this flag is set, the 
				StringFileInfo structure should contain a SpecialBuild entry. 

=head3 FileOS Table

Specifies the operating system for which this file was designed. This member can be one of the following values: 

	Flag 			Description 
	VOS_DOS 		The file was designed for MS-DOS. 
	VOS_NT 			The file was designed for Windows NT. 
	VOS__WINDOWS16 		The file was designed for 16-bit Windows. 
	VOS__WINDOWS32 		The file was designed for the Win32 API. 
	VOS_OS216 		The file was designed for 16-bit OS/2. 
	VOS_OS232 		The file was designed for 32-bit OS/2. 
	VOS__PM16 		The file was designed for 16-bit Presentation Manager. 
	VOS__PM32 		The file was designed for 32-bit Presentation Manager. 
	VOS_UNKNOWN 		The operating system for which the file was designed is unknown to the system. 

An application can combine these values to indicate that the file was designed for one operating system running on 
another. The following FileOS values are examples of this, but are not a complete list: 

	Flag 			Description 
	VOS_DOS_WINDOWS16 	The file was designed for 16-bit Windows running on MS-DOS. 
	VOS_DOS_WINDOWS32 	The file was designed for the Win32 API running on MS-DOS. 
	VOS_NT_WINDOWS32 	The file was designed for the Win32 API running on Windows NT. 
	VOS_OS216_PM16 		The file was designed for 16-bit Presentation Manager running on 16-bit OS/2. 
	VOS_OS232_PM32 		The file was designed for 32-bit Presentation Manager running on 32-bit OS/2. 

=head3 FileType Table

Specifies the general type of file. This member can be one of the following values: 

	Flag 			Description 
	VFT_UNKNOWN 		The file type is unknown to the system. 
	VFT_APP 		The file contains an application. 
	VFT_DLL 		The file contains a dynamic-link library (DLL). 
	VFT_DRV 		The file contains a device driver. If FileType is VFT_DRV, FileSubtype contains a 
				more specific description of the driver. 
	VFT_FONT 		The file contains a font. If FileType is VFT_FONT, FileSubtype contains a 
				more specific description of the font file. 
	VFT_VXD 		The file contains a virtual device. If FileType is VFT_VXD, FileSubtype contains 
				the virtual device identifier included in the virtual device control block. 
	VFT_STATIC_LIB 		The file contains a static-link library. 

=head3 FileSubtype Table

Specifies the function of the file. The possible values depend on the value of FileType. For all values of FileType 
not described in the following list, FileSubtype is I<undefined>. 

If FileType is VFT_DRV, FileSubtype can be one of the following values: 

	Flag 			Description 
	VFT2_UNKNOWN 		The driver type is unknown by the system. 
	VFT2_DRV_COMM 		The file contains a communications driver. 
	VFT2_DRV_PRINTER 	The file contains a printer driver. 
	VFT2_DRV_KEYBOARD 	The file contains a keyboard driver. 
	VFT2_DRV_LANGUAGE 	The file contains a language driver. 
	VFT2_DRV_DISPLAY 	The file contains a display driver. 
	VFT2_DRV_MOUSE 		The file contains a mouse driver. 
	VFT2_DRV_NETWORK 	The file contains a network driver. 
	VFT2_DRV_SYSTEM 	The file contains a system driver. 
	VFT2_DRV_INSTALLABLE 	The file contains an installable driver. 
	VFT2_DRV_SOUND 		The file contains a sound driver. 

If FileType is VFT_FONT, FileSubtype can be one of the following values: 

	Flag 			Description 
	VFT2_UNKNOWN 		The font type is unknown by the system. 
	VFT2_FONT_RASTER 	The file contains a raster font. 
	VFT2_FONT_VECTOR 	The file contains a vector font. 
	VFT2_FONT_TRUETYPE 	The file contains a TrueType font. 

If the function fails and the optional switch I<is not> specified, then it returns undef.
If the function fails and the optional switch I<is> specified, then the same hash is returned but the key values 
will be set to 0.

=head2 Win32API::Resources::GlobalMemoryStatus

	%Hash = Win32API::Resources::GlobalMemoryStatus();

Returns a hash filled with memory information from the current system.  The
structure of the hash is the same as Win32::AdminMisc::GetMemoryInfo:

	Load		Specifies a number between 0 and 100 that gives a general 
			idea of current memory utilization
	RAMTotal 	Indicates the total number of bytes of physical memory
	RAMAvail 	Indicates the number of bytes of physical memory available
	PageTotal 	Indicates the total number of bytes that can be stored in the 
			paging file. Note that this number does not represent the actual 
			physical size of the paging file on disk.
	PageAvail 	Indicates the number of bytes available in the paging file
	VirtTotal 	Indicates the total number of bytes that can be described in the 
			user mode portion of the virtual address space of the calling process
	VirtAvail 	Indicates the number of bytes of unreserved and uncommitted memory in 
			the user mode portion of the virtual address space of the calling process

=head2 Win32API::Resources::LoadString

	$Scalar = Win32API::Resources::LoadString($file, $rid);

	$file is full path to the EXE or DLL to examine
	$rid is the resource element to query where 1 is the first element in the table

Some EXE's and DLL's have a Resource Table that lists strings that are referenced for various
purposes.  These sometimes contain version information or error messages.  In the case of Lotus Notes
the first element of NSTRINGS.DLL contains the version of Notes installed.

By default all strings are limited to 64 character wide.

To Enumerate the table, use I<Win32API::Resources::EnumString>

=head2 Win32API::Resources::EnumString

	@List = Win32API::Resources::EnumString($file);

Just as I<Win32API::Resources::LoadString> will load a specific element from the resource
table of a file, EnumString uses the same method but returns an enumerated list of the contents
of the resource table.

By default all strings are limited to 64 character wide.

=head2 Win32API::Resources::ExeType

	$Scalar = Win32API::Resources::ExeType($file);

ExeType is a wrapper around the SHGetFileInfo API.  This will return:

	16-bit Windows based application, NE <OS Version>
	32-bit Windows based application, PE <OS Version>
	32-bit Win32 console based application, PE <NULL>
	MS-DOS based application, MZ <NULL>
	Unknown, <Type> <OS Version>

	NE designates 16 bit applications
	PE designates 32 bit applications
	MZ designates MS-DOS applications
	<OS Version> is the version of the OS it was compiled to run on (3.0, 3.1, 3.51, etc)

SHGetFileInfo will work on both WinNT and Win95a systems

I<Thanks to Aldo Calpini for the code!>

=head2 Win32API::Resources::IsEXE16

	Win32API::Resources::IsEXE16($file);

IsEXE16 is a wrapper around the SHGetFileInfo API.  It is provided as a simple file test 
that returns a true (1) or false (0) based on the target file.  

	$file is the full path to the EXE in question

=head2 Win32API::Resources::IsEXE32

	Win32API::Resources::IsEXE32($file);

IsEXE32 is a wrapper around the SHGetFileInfo API.  It is provided as a simple file test 
that returns a true (1) or false (0) based on the target file.  

	$file is the full path to the EXE in question

=head2 Win32API::Resources::GetBinaryType

	Win32API::Resources::GetBinaryType($title, 1, \%File);

GetBinary type B<only works in Windows NT>.  It does, however, have the added benefit over 
SHGetFileInfo in that it will also reveal EXE types based on other NT subsystems.  It will return:

	Win32 based application
	MS-DOS based application
	16-bit Windows based application
	PIF file that executes an MS-DOS based application
	POSIX based application
	16-bit OS/2 based application

I<Thanks to Aldo Calpini for the code!>

=head2 Win32API::Resources::GetDrives

	[$Scalar] or [@List] = Win32API::Resources::GetDrives($type);

In List context GetDrives returns a list of drive assignments on the local system
In Scalar context GetDrives returns the number of valid drive assignments
Passing GetDrives one of the Drive Type Constants will return:
In List context, a list of drive assignments that match the passed constant
In Scalar context, the number of valid drive assignments that match the passed constant

	$type is one of the following constants - optional

	DRIVE_NO_ROOT_DIR 	The root directory does not exist. 
	DRIVE_REMOVABLE 	The disk can be removed from the drive. 
	DRIVE_FIXED 		The disk cannot be removed from the drive. 
	DRIVE_REMOTE 		The drive is a remote (network) drive. 
	DRIVE_CDROM 		The drive is a CD-ROM drive. 
	DRIVE_RAMDISK 		The drive is a RAM disk. 

=head2 Win32API::Resources::RasEnumConnections

	$Scalar = Win32API::Resources::RasEnumConnections();

RasEnumConnections returns the number of active RAS/Dial-Up connections on the local machine.

	$Scalar is the number of open connections

Returns undef on a failure (RAS is not installed), or 0-x for the number of connections.

=head2 Win32API::Resources::DWORD_NULL

	$Scalar = Win32API::Resources::DWORD_NULL();

DWORD_NULL is a way to pack a null string easily.  Based on code by Mike Blazer.

	$Scalar is the packed value

=head2 Win32API::Resources::UnpackLargeInt

	$Scalar = Win32API::Resources::UnpackLargeInt($PackedLargeInteger);

UnpackLargeInt is a way to unpack a LARGE_INTEGER easily.  Based on code by Mike Blazer.

	$Scalar is the unpacked value

=head2 Win32API::Resources::ShowKeys

	Win32API::Resources::ShowKeys($title, $sort, \%Hash);

ShowKeys is provided as a simple way to show the contents of a hash with optional sorting.

	$title is a printed title to the hash
	$sort is a boolean switch that will optionally sort the Keys
	\%Hash is a Hash reference that you wish to display

=head1 AUTHOR

Brad Turner ( I<bsturner@sprintparanet.com> ).

=cut


