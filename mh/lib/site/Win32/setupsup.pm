package Win32::Setupsup;

#
# Setupsup.pm
# by Jens Helberg, jens.helberg@pcm.bosch.de
# all comments are welcome
#
# you can use this module under GNU public licence
#
# some code is borrowed from Dave Roth's adminmisc module
# thanks to him!
#
# version 1.01 from 10/15/2000
#
# not all functions are tested completly - use this at your own risk
#
# it's only intended to work on winnt (version 4.0 with sp3 or later)
# but it should work on win95/98/me too
#

require Exporter;
require DynaLoader;
package main;

BEGIN
{
	if($] >= 5.006)
	{
		use Win32::Registry;

		$Win32::Setupsup::RegCreateKeyEx = \&Win32::Registry::RegCreateKeyEx;
		$Win32::Setupsup::RegOpenKeyEx = \&Win32::Registry::RegOpenKeyEx;
		$Win32::Setupsup::RegQueryValueEx = \&Win32::Registry::RegQueryValueEx;
		$Win32::Setupsup::RegSetValue = \&Win32::Registry::RegSetValue;
		$Win32::Setupsup::RegCloseKey = \&Win32::Registry::RegCloseKey;
	}
	else
	{
		require "nt.ph";

		$Win32::Setupsup::RegCreateKeyEx = \&Win32::RegCreateKeyEx;
		$Win32::Setupsup::RegOpenKeyEx = \&Win32::RegOpenKeyEx;
		$Win32::Setupsup::RegQueryValueEx = \&Win32::RegQueryValueEx;
		$Win32::Setupsup::RegSetValue = \&Win32::RegSetValue;
		$Win32::Setupsup::RegCloseKey = \&Win32::RegCloseKey;
	}
}

package Win32::Setupsup;

$Version = 1.01;
$Package = "Win32::Setupsup";

die "The $Package module works only on Windows NT" if(!Win32::IsWinNT());

@ISA= qw(Exporter DynaLoader);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	ERROR_TIMEOUT_ELAPSED
	INVALID_SID_ERROR
	NOT_ENOUGTH_MEMORY_ERROR
	UNKNOWN_PROPERTY_ERROR
	INVALID_PROPERTY_TYPE_ERROR

	VS_FF_DEBUG				
	VS_FF_PRERELEASE	
	VS_FF_PATCHED			
	VS_FF_PRIVATEBUILD
	VS_FF_INFOINFERRED
	VS_FF_SPECIALBUILD
	
	VOS_UNKNOWN				
	VOS_DOS						
	VOS_OS216					
	VOS_OS232					
	VOS_NT						
	
	VOS__BASE					
	VOS__WINDOWS16		
	VOS__PM16					
	VOS__PM32					
	VOS__WINDOWS32		
	
	VOS_DOS_WINDOWS16 
	VOS_DOS_WINDOWS32 
	VOS_OS216_PM16		
	VOS_OS232_PM32		
	VOS_NT_WINDOWS32	
	
	VFT_UNKNOWN				
	VFT_APP						
	VFT_DLL						
	VFT_DRV						
	VFT_FONT					
	VFT_VXD						
	VFT_STATIC_LIB		
	
	VFT2_UNKNOWN			
	VFT2_DRV_PRINTER	
	VFT2_DRV_KEYBOARD 
	VFT2_DRV_LANGUAGE 
	VFT2_DRV_DISPLAY	
	VFT2_DRV_MOUSE					
	VFT2_DRV_NETWORK				
	VFT2_DRV_SYSTEM					
	VFT2_DRV_INSTALLABLE		
	VFT2_DRV_SOUND					
	VFT2_DRV_COMM						
	VFT2_DRV_INPUTMETHOD		
	
	VFT2_FONT_RASTER				
	VFT2_FONT_VECTOR				
	VFT2_FONT_TRUETYPE			
	
	VFFF_ISSHAREDFILE				
													
	VFF_CURNEDEST						
	VFF_FILEINUSE						
	VFF_BUFFTOOSMALL				
	
	VIFF_FORCEINSTALL				
	VIFF_DONTDELETEOLD			
	
	VIF_TEMPFILE						
	VIF_MISMATCH						
	VIF_SRCOLD							
	
	VIF_DIFFLANG						
	VIF_DIFFCODEPG					
	VIF_DIFFTYPE						
	
	VIF_WRITEPROT						
	VIF_FILEINUSE						
	VIF_OUTOFSPACE					
	VIF_ACCESSVIOLATION			
	VIF_SHARINGVIOLATION		
	VIF_CANNOTCREATE				
	VIF_CANNOTDELETE				
	VIF_CANNOTRENAME				
	VIF_CANNOTDELETECUR			
	VIF_OUTOFMEMORY					
	
	VIF_CANNOTREADSRC				
	VIF_CANNOTREADDST				
	
	VIF_BUFFTOOSMALL				

);

@EXPORT_OK = qw(
	SendKeys 
	EnumWindows 
	EnumChildWindows 
	WaitForWindow
	WaitForAnyWindow 
	WaitForAnyWindowAsynch 
	WaitForWindowClose
	SetWindowText 
	GetWindowText 
	GetDlgItem 
	SetFocus 
	GetWindowProperties
	SetWindowProperties 
	AccountToSid 
	SidToAccount 
	GetVersionInfo
	GetProcessList
	KillProcess 
	Sleep 
	DisableKeyboardAfterReboot
	EnableKeyboardAfterReboot
	DisableMouseAfterReboot
	EnableMouseAfterReboot
	GetProgramFilesDir
	GetCommonFilesDir
);


sub AUTOLOAD 
{
		# This AUTOLOAD is used to 'autoload' constants from the constant()
		# XS function.	If a constant is not found then control is passed
		# to the AUTOLOAD in AutoLoader.

		local($constname);
		($constname = $AUTOLOAD) =~ s/.*:://;
		#reset $! to zero to reset any current errors.
		$!=0;
		$val = constant($constname, @_ ? $_[0] : 0);
		if ($! != 0) 
		{
				if ($! =~ /Invalid/) 
				{
						$AutoLoader::AUTOLOAD = $AUTOLOAD;
						goto &AutoLoader::AUTOLOAD;
				}
				else
				{
						my ($file,$line) = (caller)[1,2];
						die "Your vendor has not defined $Package macro $constname, used in $file at line $line.";
				}
		}
		eval "sub $AUTOLOAD { $val }";
		goto &$AUTOLOAD;
}


# disables keyboard input after reboot
sub DisableKeyboardAfterReboot
{
	die "Usage: Win32::Setupsup::DisableKeyboardAfterReboot()\n" if($#_ != -1);

	if(!&{$Win32::Setupsup::RegCreateKeyEx}(&main::HKEY_LOCAL_MACHINE, 'SYSTEM\\CurrentControlSet\\Hardware Profiles\\' .
								'0001\\System\\CurrentControlSet\\Enum\\ROOT\\LEGACY_KBDCLASS\\0000', 
								&NULL, '', &NULL, &main::KEY_WRITE, &NULL, $hKey, $disp))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		return 0;
	}

	if(!&{$Win32::Setupsup::RegSetValueEx}($hKey, 'CSConfigFlags', &NULL, &main::REG_DWORD, 1))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		&{$Win32::Setupsup::RegCloseKey}($hKey);
		return 0;
	}

	&{$Win32::Setupsup::RegCloseKey}($hKey);
	
	return 1;
}


# enables keyboard input after reboot
sub EnableKeyboardAfterReboot
{
	die "Usage: Win32::Setupsup::EnableKeyboardAfterReboot()\n" if($#_ != -1);
		
	if(!&{$Win32::Setupsup::RegCreateKeyEx}(&main::HKEY_LOCAL_MACHINE, 'SYSTEM\\CurrentControlSet\\Hardware Profiles\\' .
								'0001\\System\\CurrentControlSet\\Enum\\ROOT\\LEGACY_KBDCLASS\\0000', 
								&NULL, '', &NULL, &main::KEY_WRITE, &NULL, $hKey, $disp))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		return 0;
	}

	if(!&{$Win32::Setupsup::RegSetValueEx}($hKey, 'CSConfigFlags', &NULL, &main::REG_DWORD, 0))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		&{$Win32::Setupsup::RegCloseKey}($hKey);
		return 0;
	}

	&{$Win32::Setupsup::RegCloseKey}($hKey);
	
	return 1;
}


# disables mouse input after reboot
sub DisableMouseAfterReboot
{
	die "Usage: Win32::Setupsup::DisableMouseAfterReboot()\n" if($#_ != -1);
		
	if(!&{$Win32::Setupsup::RegCreateKeyEx}(&main::HKEY_LOCAL_MACHINE, 'SYSTEM\\CurrentControlSet\\Hardware Profiles\\' .
								'0001\\System\\CurrentControlSet\\Enum\\ROOT\\LEGACY_MOUCLASS\\0000', 
								&NULL, '', &NULL, &main::KEY_WRITE, &NULL, $hKey, $disp))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		return 0;
	}

	if(!&{$Win32::Setupsup::RegSetValueEx}($hKey, 'CSConfigFlags', &NULL, &main::REG_DWORD, 1))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		&{$Win32::Setupsup::RegCloseKey}($hKey);
		return 0;
	}

	&{$Win32::Setupsup::RegCloseKey}($hKey);
	
	return 1;
}


# enables mouse input after reboot
sub EnableMouseAfterReboot
{
	die "Usage: Win32::Setupsup::EnableMouseAfterReboot()\n" if($#_ != -1);
		
	if(!&{$Win32::Setupsup::RegCreateKeyEx}(&main::HKEY_LOCAL_MACHINE, 'SYSTEM\\CurrentControlSet\\Hardware Profiles\\' .
								'0001\\System\\CurrentControlSet\\Enum\\ROOT\\LEGACY_MOUCLASS\\0000', 
								&NULL, '', &NULL, &main::KEY_WRITE, &NULL, $hKey, $disp))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		return 0;
	}

	if(!&{$Win32::Setupsup::RegSetValueEx}($hKey, 'CSConfigFlags', &NULL, &main::REG_DWORD, 0))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		&{$Win32::Setupsup::RegCloseKey}($hKey);
		return 0;
	}

	Win32::Registry::RegCloseKey($hKey);
	
	return 1;
}


# gets the program files directory from registry
sub GetProgramFilesDir
{
	die "Usage: Win32::Setupsup::GetProgramFilesDir(\\\$dir)\n" if($#_);
	
	if(!&{$Win32::Setupsup::RegOpenKeyEx}(&main::HKEY_LOCAL_MACHINE, 'Software\Microsoft\Windows\CurrentVersion',
							&NULL, &main::KEY_READ, $hKey))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		return 0;
	}

	if(!&{$Win32::Setupsup::RegQueryValueEx}($hKey, 'ProgramFilesDir', &NULL, &NULL, $_[0]))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		&{$Win32::Setupsup::RegCloseKey}($hKey);
		return 0;
	}

	&{$Win32::Setupsup::RegCloseKey}($hKey);
 
	return 1;
}


# gets the common files directory from registry
sub GetCommonFilesDir
{
	die "Usage: Win32::Setupsup::GetCommonFilesDir(\\\$dir)\n" if($#_);
	
	if(!&{$Win32::Setupsup::RegOpenKeyEx}(&main::HKEY_LOCAL_MACHINE, 'Software\Microsoft\Windows\CurrentVersion',
								&NULL, &main::KEY_READ, $hKey))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		return 0;
	}

	if(!&{$Win32::Setupsup::RegQueryValueEx}($hKey, 'CommonFilesDir', &NULL, &NULL, $_[0]))
	{
		Win32::Setupsup::SetLastError(Win32::GetLastError());
		&{$Win32::Setupsup::RegCloseKey}($hKey);
		return 0;
	}

	&{$Win32::Setupsup::RegCloseKey}($hKey);
 
	return 1;
}


bootstrap $Package;

# Preloaded methods go here.

# Autoload methods go after __END__, and are processed by the autosplit program.

1;

__END__

=head1 NAME

Win32::Setupsup - implements some functions to automate setups which have no silent mode


=head1 SYNOPSIS

	use Win32::Setupsup;


=head1 DESCRIPTION

This module supports you in automate setup routines. You can get window list, window properties
and you can send key stroke to windows like VB's SendKey.


=head1 CONSTANTS


=head1 FUNCTIONS

SendKeys($window, $keystr, $activate, [$timeout])
EnumWindows(\@windows)
EnumChildWindows($window, \\@childs)
WaitForWindow($title, \$window, $timeout, [$refresh])
WaitForAnyWindow($title, \$window, $timeout, [$refresh])
WaitForAnyWindowAsynch($title, \$thread, \@actions, $timeout, [$refresh])
WaitForWindowClose($window, $timeout, [$refresh])
GetWindowText($window, \$windowtext)
SetWindowText($window, $windowtext)
GetDlgItem($window, $id, \$item)
SetFocus($window)
GetWindowProperties($window, @proptoget, \%windowprop)
SetWindowProperties($window, \%windowprop)
AccountToSid($server, $account, \$sid)
SidToAccount($server, $sid, \$account)
GetVersionInfo($filename, \%fileinfo)
GetProcessList(\@proc, \@thread)
KillProcess($proc, [$exitval, [$systemproc]])
Sleep([$time])


=head2 NOTE:

All of the functions return false if they fail. You can call Win32::Setupsup::GetLastError() 
to get more error information. 

Note: the module defines some own error codes. You cannot call "net helpmsg" for a description
and these errors are currently not exported.


=over 10


=item SendKeys($window, $keystr, $activate, [$timeout])

Sends some key strokes to a window. $window must be a valid window handle or null. If $window
is not valid the results are undefined. $keystr contains the keys to send. Some special keys
are defined (see below). They must be enclosed in backslashes (you have to write two backslashes 
in perl). If you send alt, ctrl or shift down keys (f.e. \\alt+\\) don't forget the up key 
(\\alt-\\). If $activate is not null, $window will be activated everytime before a key will be
sent. $timeout is the (optional) time between two key strokes. It's useful for debugging.

special keys:
ALT+  alt down
ALT-  alt up
CTRL+ ctrl down
CTRL- ctrl up
SHIFT+  shift down
SHIFT-  shift up
TAB tabulator
RET return
ESC escape
BACK  backspace
DEL delete
INS insert
HELP  help
LEFT  arrow left
RIGHT arrow right
UP  arrow up
DN  arrow down
PGUP  page up
PGDN  page down
BEG pos1
END end
F1  function 1
...
F12 function 12
NUM0  0 on the num block
...
NUM9  9 on the num block
NUM*  multiply key on the num block
NUM+  add key on the num block
NUM-  minus key on the num block
NUM/  divide key on the num block


=item EnumWindows(\@windows)

Enumerates all desktop windows on the screen and returns the handles in the @windows array. 
@windows must be an array reference.


=item EnumChildWindows($window, \\@childs)

Enumerates all child windows that belong to $window and returns the handles in the @childs array. 
$window must be a valid window handle @childs must be an array reference.


=item WaitForWindow($title, \$window, $timeout, [$refresh])

Waits for a window title and returns the app. window handle. Search is case insensitive. Returns if
a window was found or $timeout elapsed (whatever happens earlier). $refresh is optional but you 
should specify a value (f.e. 100ms). Otherwise the function loops and consumes about 70 - 90% 
cpu time. If $timeout elapses GetLastError() returns ERROR_TIMEOUT_ELAPSED.

=item WaitForAnyWindow($title, \$window, $timeout, [$refresh])

Waits for a window title and returns the app. window handle. Search is case insensitive. $title could
be a regular expression. Returns if a window was found or $timeout elapsed (whatever happens earlier). 
$refresh is optional but you should specify a value (f.e. 100ms). Otherwise the function loops and 
consumes about 70 - 90% cpu time. If $timeout elapses GetLastError() returns ERROR_TIMEOUT_ELAPSED.

=item WaitForAnyWindowAsynch($title, \$thread, \@actions, $timeout, [$refresh])

Creates a thread which waits for a window title. Function returns immediatly. If a app. window is 
catched, all actions defined in @actions will be applied. The thread handle is returned in $thread. 
$title could be a regular expression. Search is case insensitive. No actions are carried out if
$timeout elapesed before a window was found. $refresh is optional but you should specify a value 
(f.e. 100ms). Otherwise the function loops and consumes about 70 - 90% cpu time. 

The following actions are defined:

keys	: sends key strokes to the window
close	: closes the window (sends a WM_CLOSE message)
wait	: simply waits 
kill	: kills the process the window belongs to

=item WaitForWindowClose($window, $timeout, [$refresh])

Waits until a window will be closed. $window must be a valid window handle. Returns if $window is closed
or $timeout elapsed (whatever happens earlier). $refresh is optional but you should specify a value 
(f.e. 100ms). Otherwise the function loops and consumes about 70 - 90% cpu time. If $timeout elapses 
GetLastError() returns ERROR_TIMEOUT_ELAPSED.


=item GetWindowText($window, \$windowtext)

Returns the caption of a window. $window must be a valid window handle and $windowtext a salar reference.
There is no check if $window is valid. The function fail if there is not enougth memory. GetLastError() 
returns NOT_ENOUGTH_MEMORY_ERROR.


=item SetWindowText($window, $windowtext)

Sets the caption of a window. $window must be a valid window handle and $windowtext a salar value. You can
use also SetWindowProp.


=item GetDlgItem($window, $id, \$item)

Gets the window handle of a dialog item. $window is the parent window and $id the id. $item contains the
window handle if the function succeeds.


=item SetFocus($window)

Sets the focus to $window. It does not activate the window (the foreground application will not be changed 
if $windows belongs to another application).


=item GetWindowProperties($window, @proptoget, \%windowprop)

Gets the properties of a window. Specify all properties you wish in @proptoget. See the supported properties
below. %windowprop will contain the properties on success. If you specify an unknown property GetLastError()
returns UNKNOWN_PROPERTY_ERROR. 

valid properties are:
checked         : is window checked (checkboxes only)
class           : window class name
classatom       : class atom that $window belongs (see RegisterClass in win32 api)
classbrush      : handle to class background brush that $window belongs
classcursor     : handle to class cursor that $window belongs
classicon       : handle to class icon that $window belongs
classiconsmall  : handle to class small icon that $window belongs
classmenu       : handle to class menu that $window belongs
classmodule     : handle to class module that $window belongs
classproc       : pointer to class procedure that $window belongs
classstyle      : class style that $window belongs
client          : $window's client rectangle
desktop					: handle to desktop window
dlgproc					: pointer to $window's dialog procedure (if $window belongs to a dialog)
enabled         : is $window enabled or not
extstyle        : $window's extended style
focused					: is $window focused or not
foreground			: is $window the foreground window or not
iconic					: is $window iconic or not
id							: $window's id
instance        : application instance that $window belongs
lastactivepopup : handle to the last active popup window owned by $window
menu            : handle to $window's menu
next						: handle to $window's next window in z order
parent          : handle to $window's parent window
prev						: handle to $window's previous window in z order
pid             : process id that $window belongs
rect            : $window's rectangle on the desktop
style						: $window's style
text            : $window's caption
tid							: thread id that $window belongs
top							: handle to $window's top window in z order
unicode         : is $window unicoded or not
valid           : is $window a valid window or not
visible         : is $window visible or not
wndproc         : pointer to $window's procedure
zoomed					: is $window zoomed or not


=item SetWindowProperties($window, \%windowprop)

Sets the properties of a window. Specify all properties you want to set in %windowprop. Some properties
from GetWindowProperties cannot be set. These are:

class
classatom
classproc
client
desktop
focused
lastactivepopup
pid
tid
unicode
valid

If you specify some of them, they are ignored.


=item AccountToSid($server, $account, \$sid)

Converts an account name to a sid in a textual form (S-1-5-21- ...). The command will be executed on 
server $server. If $server is empty the local machine is used. If you need an account from a specific 
domain or server, you should specify domain\account or server\account. Otherwise the account will
be resolved from trusted domains too. The first try will be made on $server. If it could not be resolved 
the next try is the domain $server belongs. After that all trusted domains will be tried. If you need a 
well known account (like system or everyone) don't specify a server or domain name. Otherwise the function 
will fail.


=item SidToAccount($server, $sid, \$account)

Converts a sid in a textual form to an account name. The command will be executed on server $server. If 
$server is empty the local machine is used. 


=item GetVersionInfo($filename, \%fileinfo)

Gets the file information record stored in a file with version information. The following information will
be retrieved:

FileVersionMS
FileVersionLS
ProductVersionMS
ProductVersionLS
FileFlagsMask
FileFlags
FileOS
FileType
FileSubtype
FileDateMS
FileDateLS
Language
Comments
CompanyName
FileDescription
FileVersion
InternalName
LegalCopyright
LegalTrademarks
OriginalFilename
PrivateBuild
ProductName
ProductVersion
SpecialBuild

See also GetFileVersionInfo in Win32-SDK.


=item GetProcessList($server, \@proc, \@thread)

Gets all process and thread id's running on $server. $server must be a valid machine name or '' if you
need data from the local machine. @proc contains the process id's and process names and @thread the
thread id's and app. process index the tread belongs to. @proc and @thread are arrays. Each array element
is a hash reference. To access the hash values see the example GetProcessList below.


=item KillProcess($proc, [$exitval, [$systemproc]])

Kills a process with pid $proc. The process ends with $exitval or 0 if omitted. If $systemproc is not null
you can kill system processes too. But you need the app. rigths to do that (debug process must be enabled).


=item Sleep([$time])

Slepps $time milliseconds. If $time is omitted, your process sleeps forever.


=item CaptureMouse([$refresh])

Captures mouse pointer in the upper left corner. Mouse will be captured until UnCaptureMouse is called. 
Optionally, you can specify a refresh value. This means, every $refresh milliseconds the mouse pointer
is moved to the upper left corner. Default is 100 ms. 


=item UnCaptureMouse([$refresh])

Uncaptures a captured mouse pointer.


=head1 GetProcessList($server, \@proc, \@thread)

die if(!Win32::Setupsup::GetProcessList('', \@proc, \@threads));

foreach $item (@proc) 
	{ print "name: ${$item}{'name'}; pid: ${$item}{'pid'}\n";}

foreach $item (@threads) 
	{ print "tid: ${$item}{'tid'}; pidx: ${$item}{'process'}; process: ${$proc[${$item}{'process'}]}{'name'}\n"; }


