#!/usr/local/bin/perl -w
# ----------------------------------------------------------------------------
# vsDB.pl DataFile Editor
# Copyright (c) 2001 Jason M. Hinkle. All rights reserved. This script is
# free software; you may redistribute it and/or modify it under the same
# terms as Perl itself.
# For more information see: http://www.verysimple.com/scripts/
#
# LEGAL DISCLAIMER:
# This software is provided as-is.  Use it at your own risk.  The
# author takes no responsibility for any damages or losses directly
# or indirectly caused by this software.
# 
# Version History
# 1.5 - 02/15/02 - more error checking
# 1.4 - 02/15/02 - fixed FNF error, better reporting, adding inbox
# 1.3 - 08/22/01 - original release 
# ----------------------------------------------------------------------------
my $VERSION = "1.5";

BEGIN {
#	$SIG{__WARN__} = \&FatalError;
#	$SIG{__DIE__} = \&FatalError;
	########################################################################
	#                       Config Variables                                                                                  #
	########################################################################
    
    # this is the relative path to the config file.  update only if necessary
#   $ENV{"CONFIG_FILE"} = "/data/calendar.cfg";

    # This is the installation path for the script.  If you recieve an error telling you to manually set
    # the path, replace GetCwd($ENV{"CONFIG_FILE"}) with the full path to your script for example:
    #		$ENV{"CWD"} = "C:/wwwroot/cgi-bin/myscript";
    # Leave off any trailing slashes, and replace all backslashes "\" with forward slashes "/"
    
#   $ENV{"CWD"} = GetCwd($ENV{"CONFIG_FILE"});
    $ENV{"CWD"} = '../web/organizer';

    
    # uncomment this line if you are experiencing 404 errors
    # $ENV{"SCRIPT_NAME"} = "contacts.pl";
    
    # uncomment for to disable buffering for faster perceived performance
    # (warning: may cause script to hang on some servers)
    # $| = 1;  

	########################################################################
	#                       End Config Variables                                                                            #
	########################################################################
    
    # add the current directory to the perl path so our libraries can be found
    push(@INC,$ENV{"CWD"});

    sub GetCwd {
		# this function tries various methods to get the installation directory.  if it is not found,
		# an error is displayed telling the user to edit the script manually
		my ($testFile) = shift || "";
		my ($fullPath,$curDir);
		# try these common ones first
		$fullPath = $ENV{"PATH_TRANSLATED"} || $ENV{"SCRIPT_FILENAME"} || "";
		$fullPath =~ s|\\|\/|g;
		$curDir = substr($fullPath,0, rindex($fullPath,"/"));
		return $curDir if (-e "$curDir/$testFile");
		# that didn't work, this is another common one
		$fullPath =  ($ENV{"DOCUMENT_ROOT"} || "") . ($ENV{"SCRIPT_NAME"} || "");
		$fullPath =~ s|\\|\/|g;
		$curDir = substr($fullPath,0, rindex($fullPath,"/"));
		return $curDir if (-e "$curDir/$testFile");
		# forget that, let's try the relative path
		$curDir = ".";
		return $curDir if (-e "$curDir/$testFile");
		# if all else fails try Cwd
		use Cwd;
		$curDir = Cwd::cwd();
		return $curDir if (-e "$curDir/$testFile") ;
	    	# i give up!  user is going to have to set it manually
		print "Content-type: text/html\n\n";
		print "<b>Installation path could not be determined.</b>\n";
		print "<p>Please edit the script and set \$ENV{\"CWD\"} to the full path in which the script is installed.";
		exit 1;
    }
} # / BEGIN
# ----------------------------------------------------------------------------

print "Content-type: text/html\n\n";
my ($HEADER_PRINTED) = 1;

print "
	<html>
	<head><title>VerySimple Organizer 2.0 Setup</title></head>
	<body bgcolor='#FFFFFF' link='blue' vlink='blue' alink='blue'>
	<font face='arial' size='2'>
	<table bgcolor='#BBBBBB' border='0' width='100%'><tr><td><b>VerySimple Organizer 2.0 Setup</b></td></tr></table>
	<p>
";


eval 'use vsDB';
eval 'use CGI';

my ($objCGI) = new CGI;
my ($command) = $objCGI->param('vsCOM') || "";
my ($rowNum) = $objCGI->param('vsRN') || "";
my ($fileName) = $objCGI->param('vsFILE') || "data/inbox.cfg";
my ($delimiter) = $objCGI->param('vsDEL') || "\t";
my ($pageSize) = 10;
my ($activePage) = $objCGI->param('vsAP') || 1;



my ($scriptName) = $ENV{'SCRIPT_NAME'} || "setup.pl";
my ($filePath) = $ENV{"CWD"} . "/" . $fileName;

print "<form action='" . $scriptName . "' method='post'>\n";
print "<input type='hidden' name='vsFILE' value='" . $fileName . "'>\n";
print "<input type='hidden' name='vsDEL' value='" . $delimiter . "'>\n";
print "<p>\n";
print "<table bgcolor='#DDDDDD' border='1' cellspacing='0' cellpadding='2'><tr>\n";

if ($fileName eq "data/inbox.cfg") {
	print "<td align='center'><font size='2'><b><a href='$scriptName?vsFILE=data/inbox.cfg&vsCOM=EDIT&vsRN=1'>Inbox</a></b></font></td>\n";
} else {
	print "<td align='center' bgcolor='#BBBBBB'><font size='2'><a href='$scriptName?vsFILE=data/inbox.cfg&vsCOM=EDIT&vsRN=1'>Inbox</a></font></td>\n";
}	
if ($fileName eq "data/calendar.cfg") {
	print "<td align='center'><font size='2'><b><a href='$scriptName?vsFILE=data/calendar.cfg&vsCOM=EDIT&vsRN=1'>Calendar</a></b></font></td>\n";
} else {
	print "<td align='center' bgcolor='#BBBBBB'><font size='2'><a href='$scriptName?vsFILE=data/calendar.cfg&vsCOM=EDIT&vsRN=1'>Calendar</a></font></td>\n";
}	
if ($fileName eq "data/contacts.cfg") {
	print "<td align='center'><font size='2'><b><a href='$scriptName?vsFILE=data/contacts.cfg&vsCOM=EDIT&vsRN=1'>Contacts</a></b></font></td>\n";
} else {
	print "<td align='center' bgcolor='#BBBBBB'><font size='2'><a href='$scriptName?vsFILE=data/contacts.cfg&vsCOM=EDIT&vsRN=1'>Contacts</a></font></td>\n";
}	
if ($fileName eq "data/tasks.cfg") {
	print "<td align='center'><font size='2'><b><a href='$scriptName?vsFILE=data/tasks.cfg&vsAP=1&vsDEL=&vsCOM=EDIT&vsRN=1'>Tasks</a></b></font></td>\n";
} else {
	print "<td align='center' bgcolor='#BBBBBB'><font size='2'><a href='$scriptName?vsFILE=data/tasks.cfg&vsCOM=EDIT&vsRN=1'>Tasks</a></font></td>\n";
}	

print "<tr><td colspan='4'>\n";

# default to tab character 
$delimiter = "\t" unless ($delimiter);
my ($objDB) = new vsDB(
	file => $filePath,
	delimiter => $delimiter,
);

if ($fileName) {

	if (!$objDB->Open) {FatalError($objDB->LastError)};

	#$objDB->Sort("ID");
	#$objDB->Commit;

	if ($command eq "EDIT") {
		$objDB->AbsolutePosition($rowNum);
	} elsif ($command eq "UPDATE") {
		$objDB->AbsolutePosition($rowNum);
		UpdateCurrentRecord($objDB,$objCGI);
		print "<script>\n";
		print "alert('Settings Updated');\n";
		print "</script>\n";
	}
	PrintCurrentRecord($objDB);
}

print "
	</td></tr></table>
	</form>
	<hr><font size='1'>
	VerySimple Organizer 2.0 Setup $VERSION &copy 2002, <a href='http://www.verysimple.com/'>VerySimple</a><br>
";
print "vsDB Module Version " . $objDB->Version;
print "
	</font><p>
	</font>
	</body>
	</html>
";
undef($objDB);

#_____________________________________________________________________________
sub PrintCurrentRecord {
	my ($objMyDB) = shift;
	my ($fieldName, $fieldValue);
	print "<table cellspacing='2' cellpadding='2' border='0'>\n";
	foreach $fieldName ($objMyDB->FieldNames) {
		print "<tr valign='top' bgcolor='#DDDDDD'>\n";
		print "<td><font face='arial' size='2'>" . $fieldName . "</font></td>\n";

		if ($fieldName eq "Password") {
			print "<td><input type=\"password\" size=\"50\" name=\"" . $fieldName . "\" value=\"";
		} else {			
			print "<td><input size=\"50\" name=\"" . $fieldName . "\" value=\"";
		}

		$fieldValue = $objMyDB->FieldValue($fieldName);
		$fieldValue =~ s/\"/&quot;/g;		

		print $fieldValue . "\"></td>\n";
		print "</tr>\n";
	}
	print "</table>\n";
	print "<p>\n";
	print "<input type='hidden' name='vsFILE' value='$fileName'>\n";
	print "<input type='hidden' name='vsRN' value='" . $objMyDB->AbsolutePosition . "'>\n";
	print "<input type='hidden' name='vsCOM' value='UPDATE'>\n";
	print "<input type='hidden' name='vsAP' value='$activePage'>\n";
	print "<input type='submit' value='Apply'>\n";
	print "<input type='reset' value='Cancel' onclick=\"window.history.go(-1);return false;\">\n";
}


#_____________________________________________________________________________
sub UpdateCurrentRecord {
	my ($objMyDB) = shift;
	my ($objMyCGI) = shift;
	my ($fieldName,$fieldValue);
	foreach $fieldName ($objMyDB->FieldNames) {
		$fieldValue = $objMyCGI->param($fieldName);
		$objMyDB->FieldValue($fieldName,$fieldValue);
	}
	if (!$objMyDB->Commit) {print "</td></tr></table>\n"; FatalError($objMyDB->LastError)};
}

#_____________________________________________________________________________
sub FatalError {
    my ($strMessage) = shift || "Unknown Error";
    print "Content-type: text/html\n\n" unless defined($HEADER_PRINTED);
    print "<p><font face='arial,helvetica' size='2'>\n";
    print "<b>A fatal error occured.  The script cannot continue.  Details are below:</b>";
    print "<p><font color='red'>" . $strMessage . "</font>";
    print "<p>The most common causes of fatal errors are:\n";
    print "<ol>\n";
    print "<li>One of the script files was uploaded via FTP in Binary mode instead of ASCII\n";
    print "<li>The file permissions for the data directory and all .tab and .cfg files is not readable/writable\n";
    print "</ol>\n";
    print "<p>If you have already tried these, you may want to visit the ";
    print "<a href='http://www.verysimple.com/support/'>VerySimple Support Forum</a> \n";
    print "to see if there is a solution available.\n";
    print "</font>\n";
    exit 1;
}
