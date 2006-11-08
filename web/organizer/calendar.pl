#!/usr/local/bin/perl -w
#
# $Date$
# $Revision$
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
# 1.5.7-3 - 08/25/06 - Added 'vacation' checkbox
# 1.5.7-2 - 07/25/06 - Added 'holiday' checkbox
# 1.5.7-1 - 09/04/05 - Added Audrey (640x480) specific layout
# 1.5.7   - 02/15/02 - fixed missing date when inserting new event
# 1.5.6   - 02/15/02 - fixed FNF bug & improved error reporting
# 1.5.5   - 01/19/02 - failed attempt to fix FNF bug
# 1.5.4   - 10/02/01 - fixed bug in direct link
# 1.5.3   - 10/02/01 - added direct link to event & show/hide details
# 1.5.2   - 08/22/01 - added file locking
# ----------------------------------------------------------------------------

my $VERSION = "1.5.7-3";

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


eval 'use vsLock';
eval 'use vsDB';
eval 'use CGI';

my $debug = 0;
# --- get the configuration settings 
my ($configFilePath) = $ENV{"CWD"} . $ENV{"CONFIG_FILE"};
    $configFilePath = "$config_parms{organizer_dir}/calendar.cfg";
my ($objConfig) = new vsDB(
	file => $configFilePath,
	delimiter => "\t",
);
$objConfig->Open;
my ($title) = $objConfig->FieldValue("Title");
my ($bodyTag) = $objConfig->FieldValue("BodyTag");
my ($headerColor) = $objConfig->FieldValue("HeaderColor");
my ($dataDarkColor) = $objConfig->FieldValue("DataDarkColor");
my ($dataLightColor) = $objConfig->FieldValue("DataLightColor");
my ($dataDayColor) = $objConfig->FieldValue("DataDayColor");
my ($dataHighlightColor) = $objConfig->FieldValue("DataHighlightColor");
## --- Custom
my ($dataHolidayColor) = "#90EE90";
my ($dataVacationColor) = "#FFCC66";
## --- Custom
my ($detailIcon) = $objConfig->FieldValue("DetailIcon");
my ($fileName) = $objConfig->FieldValue("FileName") || "calendar.tab";
my ($delimiter) = $objConfig->FieldValue("Delimiter") || "\t";
my ($useFileLocking) = $objConfig->FieldValue("UseFileLocking") || 0;
$objConfig->Close;
undef($objConfig);
# -- end config

my ($filePath) = $ENV{"CWD"} . "/" . $fileName;
$filePath = "$config_parms{organizer_dir}/$fileName";


# print the header
print "
	<html>
	<head><title>$title</title></head>
	$bodyTag
	<font face='arial' size='2'>
	<table bgcolor='$headerColor' border='0' width='100%'><tr><td><b>$title</b></td></tr></table>
	<p>
";

my ($scriptName) = $ENV{'SCRIPT_NAME'} || "calendar.pl";
my ($objCGI) = new CGI;
my @dateArray = localtime(time);
my ($month) = $objCGI->param('vsMonth') || $dateArray[4]+1;
my ($year) = $objCGI->param('vsYear') || $dateArray[5]+1900;
my ($day) = $objCGI->param('vsDay') || $dateArray[3];
my ($command) = $objCGI->param('vsCOM') || "";
my ($id) = $objCGI->param('vsID') || "";
my ($showDefault) = 0;

#if (length($month) < 2) {$month = "0" . $month}
#if (length($day) < 2) {$month = "0" . $day}

## --- Custom
my ($showDayDetails) = $objCGI->param('vsSD') || 0;
my ($showforAudrey) = $objCGI->param('vsMA') || 0;
my ($noShowDayDetails) = 1;
my ($cellSize) = 25;
$cellSize = 60 if ($showDayDetails);
$cellSize = 75 if ($showforAudrey);
$showDayDetails = 1 if ($showforAudrey);
$noShowDayDetails = 0 if ($showDayDetails);
## --- Custom

my ($nmonth, $nyear, $pmonth, $pyear, $highlightDate);

my ($objDB) = new vsDB(
	file => $filePath,
	delimiter => $delimiter,
);

# lock the datafile 
my ($objLock) = new vsLock(-warn => 1, -max => 5, delay => 1);
if ($useFileLocking) {
    $objLock->lock($filePath) || die "Couldn't Lock Datafile";
}

if (!$objDB->Open) {print $objDB->LastError;$objLock->unlock($filePath);die;};


# show the default screen if specified

# figure out following month & year    
$nmonth = $month + 1;
$nyear  = $year;
if ($nmonth > 12) {
    $nmonth = 1;
    $nyear++;
}
# figure out previous month & year    
$pmonth = $month - 1;
$pyear  = $year;
if ($pmonth < 1) {
    $pmonth = 12;
    $pyear--;
}
##$highlightDate = $year . "." . $month . "." . $day; ## Disabled 1.5.7-2 to only highlight today

# --------- Main Logic --------------
if ($command eq "UPDATE") {
    $objDB->Filter("ID","eq",$id);
    UpdateCurrentRecord($objDB,$objCGI);
    $objDB->RemoveFilter;
    $objDB->MoveFirst;
} elsif ($command eq "DELETE") {
    $objDB->Filter("ID","eq",$id);
    $objDB->Delete;
    $objDB->Commit;
    $objDB->RemoveFilter;
    $objDB->MoveFirst;
} elsif ($command eq "INSERT") {
    $objDB->AddNew;
    my ($newId) = $objDB->Max("ID") || 0;
    $newId = int($newId) + 1;
    $objDB->FieldValue("ID",$newId);
    UpdateCurrentRecord($objDB,$objCGI);
    $objDB->MoveFirst;
}

if ($useFileLocking) {
    $objLock->unlock($filePath);
}

# ----------- print everything to the browser ---
&PrintDefault;

# --- print the html footer ---
print "
	</form>
	<hr><font size='1'>
	VerySimple Calendar $VERSION &copy 2002, <a href='http://www.verysimple.com/'>VerySimple</a> Modified<br>
";
print "vsDB Module Version " . $objDB->Version . "<br>";
print "vsLock Module Version " . $objLock->Version;
print "<br>MisterAudrey Version" if ($showforAudrey);
print "
	</font><p>
	</font>
	</body>
	</html>
";
undef($objDB);
undef($objLock);
undef($objCGI);


# _____________________________________________________________________________
sub PrintDefault {
    print "<table cellspacing='0' cellpadding=10' border='0'><tr valign='top'>\n";
    print "<td>\n";
    print "<font size='2' face='arial,helvetica'>\n";

#print "h1=$highlightDate\n";
    &PrintMonth($month,$year,$objDB,$highlightDate);
    if (!$showDayDetails) {
    	&PrintMonth($nmonth,$nyear,$objDB,$highlightDate);
    }

    print "<p>\n";
    print "<a href='$scriptName?vsSD=$showDayDetails&vsMA=$showforAudrey&vsMonth=$pmonth&vsYear=$pyear'>Previous Month</a>\n";
    print "| <a href='$scriptName?vsSD=$showDayDetails&vsMA=$showforAudrey&vsMonth=$nmonth&vsYear=$nyear'>Next Month</a>\n";

    print "</font>\n";

    if (!$showforAudrey) {
    	print "</td><td>\n";
    } else {
	print "<br><br>\n";
    }

#    print "</td><td>\n"; -- Removed for Audrey
#     print "<br>\n";
    print "<font size='2' face='arial,helvetica'>\n";

    &PrintDay($year,$month,$day,$objDB);

    print "<p>\n";    
    if ($command eq "EDIT") {
	$objDB->Filter("ID","eq",$id);
	PrintCurrentRecord($objDB);
    } else {
	PrintBlankRecord($objDB);
    }    
    print "</font>\n";
    print "</td>\n";
    print "</tr></table>\n";
}

# _____________________________________________________________________________
sub PrintDay {
    my $year = shift || return 0 ;
    my $month = shift || return 0 ;
    my $day = shift || return 0 ;
    my $objMyDb = shift || return 0;

    my $thisDate = "$year.$month.$day";
     
    # my @days = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');
    my @months = ('January','February','March','April','May','June','July','August','September','October','November','December');

    $objMyDb->RemoveFilter;	
    $objMyDb->Filter("DATE","eq",$thisDate);

    print "<table border='1' cellspacing='0' cellpadding='2' width='350' >\n";
    print "<font size='2' face='arial,helvetica'><b>Details For $months[$month-1] $day, $year</b></font><br>\n";
    print "<tr bgcolor='$dataHighlightColor'><td width='25'>&nbsp;</td>\n";
    print "<td width='75'><font size='2' face='arial,helvetica'><b>Time</b></font></td>\n";
    print "<td width='250'><font size='2' face='arial,helvetica'><b>Event</b></font></td></tr>\n";

    while (!$objMyDb->EOF) {
	my $custcolor = "";
	$custcolor = " bgcolor='$dataHolidayColor' " if ($objMyDb->FieldValue("HOLIDAY") eq "on");
	$custcolor = " bgcolor='$dataVacationColor' " if (($objMyDb->FieldValue("VACATION") eq "on") and (!$custcolor)); # if a day is both vacation and holiday, holiday trumps vacation for display.
	print "<tr $custcolor><td><a href='$scriptName?vsSD=$showDayDetails&vsMA=$showforAudrey&vsCOM=EDIT&vsMonth=$month&vsYear=$year&vsDay=$day&vsID=" . $objMyDb->FieldValue("ID") . "'><img src='$detailIcon' border='0'></a></td>";
	print "<td><font size='2' face='arial,helvetica'>" . $objMyDb->FieldValue("TIME") . "&nbsp;</font></td>";
	print "<td><font size='2' face='arial,helvetica'>";

	print $objMyDb->FieldValue("EVENT") . "&nbsp;</font></td></tr>\n";
	$objMyDb->MoveNext;
    }

    print "</table>\n";
    # print "<p><font size='2' face='arial,helvetica'><a href='$scriptName?vsCOM=ADD&vsMonth=$month&vsYear=$year&vsDay=$day'>Add New Event</a></font>\n";
}    

# _____________________________________________________________________________
sub PrintMonth {

    my $month = shift || 1;
    my $year = shift || 2001;
    my $objMyDb = shift || return 0;
    
    my ($firstDay,$numDays,$numWeeks) = &GetMonthInfo($month,$year);

    my @days = ('Su','M','Tu','W','Th','F','Sa');
    my @months = ('January','February','March','April','May','June','July','August','September','October','November','December');
    my $temp;
    my $dayCount = 0;
    my $weekDayCount = 0;
    my $thisDate;
    my $style;
    
    my @dateArray = localtime(time);
    $dateArray[5]+=1900;
    $dateArray[4]+=1;
    my $today = $dateArray[5] . "." . $dateArray[4] . "." . $dateArray[3];

    my $highlightDate = shift || $today;

    print "<p>\n";
    print "<font face='arial,helvetica' size='2'><b>$months[$month-1] $year</b></font>\n";
	if ($showDayDetails) {
		print " <font size='1'>[<a href='$scriptName?vsSD=0&vsMA=$showforAudrey&vsMonth=$month&vsYear=$year'>Hide Details</a>]</font>\n"
	} else {
		print " <font size='1'>[<a href='$scriptName?vsSD=1&vsMA=$showforAudrey&vsMonth=$month&vsYear=$year'>Show Details</a>]</font>\n"
	}		
    print "<table border='1' cellspacing='0' cellpadding='2'>\n";

    
    # print the days of the week 
    print "<tr>\n";
    foreach $temp (@days) {
	print "<td bgcolor='$dataDarkColor'><font face='arial,helvetica' size='2'><b>$temp</b></font></td>";
    }    
    print "</tr>\n";



    for (my $cellCount = 1;$cellCount <= $numWeeks; $cellCount++) {
	print "<tr valign='top'>\n";
	foreach $temp (@days) {
	    if (($dayCount > $firstDay-1) && ($weekDayCount < $numDays)) {
		$weekDayCount++;

		$thisDate = $year . "." . $month . "." . $weekDayCount;

		$objMyDb->RemoveFilter;	
		$objMyDb->Filter("DATE","eq",$thisDate);

if ($debug) {
my $tmp=$objMyDb->FieldValue("HOLIDAY");
print "\ndb: t=$thisDate,  fv=$tmp\n" unless ($tmp eq "EOF");
}
		my $bgcolor=undef;

	        while (!$objMyDb->EOF) {
		   if ($objMyDb->FieldValue("VACATION") eq "on") { 
		   	$bgcolor=$dataVacationColor;
		       }
		   if ($objMyDb->FieldValue("HOLIDAY") eq "on") {
		   	$bgcolor=$dataHolidayColor;
		       }
		   $objMyDb->MoveNext;
		}
	

		$objMyDb->MoveFirst;

		if ($thisDate eq $highlightDate) {
			$bgcolor=$dataHighlightColor;
		}

		if (defined $bgcolor) {
		    print "<td width='$cellSize' height='$cellSize' bgcolor='$bgcolor'><font face='arial,helvetica' size='2'>";
		} else {
		    print "<td width='$cellSize' height='$cellSize'><font face='arial,helvetica' size='2'>";
		}
		
		if ($thisDate eq $today) {
		    $style = "style=\"color:$dataDayColor\"";
		} else {
		    $style = "";
		}		    



		if ($objMyDb->EOF) {
		    print "<a $style href='$scriptName?vsSD=$showDayDetails&vsMA=$showforAudrey&vsMonth=$month&vsYear=$year&vsDay=$weekDayCount'>$weekDayCount</a><br>";
		} else {
	#$style = "style=\"color:$dataHolidayColor\"" if ($objMyDb->FieldValue("HOLIDAY") eq "on");
		    print "<b><a $style href='$scriptName?vsSD=$showDayDetails&vsMA=$showforAudrey&vsMonth=$month&vsYear=$year&vsDay=$weekDayCount'>$weekDayCount</a></b><br>";
		}			

		if ($showDayDetails) {
		    print "<font size='1'>";
		    while (!$objMyDb->EOF) {
			print "<a href='$scriptName?vsSD=$showDayDetails&vsMA=$showforAudrey&vsCOM=EDIT&vsMonth=$month&vsYear=$year&vsDay=$weekDayCount&vsID=" . $objMyDb->FieldValue("ID") . "'>" .$objMyDb->FieldValue("EVENT") . "</a><br>";
			$objMyDb->MoveNext;
		    }
		    print "</font>";
		}
		
	    # if ($thisDate eq $today) {print "*"}

		print "</font></td>\n";
	    } else {
		print "<td bgcolor='$dataLightColor'><font face='arial,helvetica' size='1'>&nbsp;</font></td>\n";
	    }
	    
	    $dayCount++;
	}    
	print "</tr>\n";
    }    
    print "</table>\n";
}


# _____________________________________________________________________________
sub GetMonthInfo {

    my $month = shift || 1;
    my $year = shift || 2001;

    my($firstDow,$numDays);

    require Time::Local;

    # convert user input into approp format for proc4essing
    --$month;
    $year -= 1900;

    # figure out following month & year    
    my $nmonth = $month + 1;
    my $nyear  = $year;
    if ($nmonth > 11) {
	$nmonth = 0;
	$nyear++;
    }

    # ready to grab first day of the month (0 based array)
    $firstDow  = (localtime(Time::Local::timelocal(0,0,0,1,$month,$year)))[6];
    # numDays is one day prior to 1st of month after
    $numDays = (localtime(Time::Local::timelocal(0,0,0,1,$nmonth,$nyear) - 60*60*24))[3];

    # figure out the number of weeks the month spans across
    my $numWeeks = ($numDays + $firstDow) / 7;
    $numWeeks = int($numWeeks) + 1 unless ($numWeeks == int($numWeeks));

    return ($firstDow,$numDays, $numWeeks);
}


#_____________________________________________________________________________
sub PrintCurrentRecord {
	my ($objMyDB) = shift;
	my ($fieldName, $fieldValue);
	print "<form action='$scriptName' method='post'>\n";
	print "<p>\n";
	print "<b>Update This Event:</b><br>\n";
	print "<table cellspacing='2' cellpadding='2' border='0'>\n";
	foreach $fieldName ($objMyDB->FieldNames) {
		if ($fieldName eq "ID") {
		    print "<input type='hidden' name='vsID' value='" . $objMyDB->FieldValue("ID") . "'>\n";
		} elsif ($fieldName eq "DATE") {
			if ($objMyDB->FieldValue("ID")) {
				print "<input type='hidden' name='DATE' value='" . $objMyDB->FieldValue("DATE") . "'>\n";
			}
		} elsif ($fieldName eq "DETAILS") {
		    print "<tr valign='top' bgcolor='#DDDDDD'>\n";
		    print "<td><font face='arial' size='2'>" . $fieldName . "</font></td>\n";
		    print "<td><textarea name='DETAILS' cols='30' rows='3'>";
		    $fieldValue = $objMyDB->FieldValue($fieldName);
		    $fieldValue =~ s/\"/&quot;/g;		
		    print $fieldValue . "</textarea></td>\n";
		    print "</tr>\n";

		} elsif ($fieldName eq "HOLIDAY") {
		    print "<tr valign='top' bgcolor='#DDDDDD'>\n";
		    print "<td><font face='arial' size='2'>" . $fieldName . "</font></td>\n";
		    $fieldValue = $objMyDB->FieldValue($fieldName);
		    print "<td><input name='HOLIDAY' type=\"checkbox\" value=\"on\" ";
		    print "checked " if ($fieldValue eq "on");
		    print ">";
		    print "</tr>\n";

		} elsif ($fieldName eq "VACATION") {
		    print "<tr valign='top' bgcolor='#DDDDDD'>\n";
		    print "<td><font face='arial' size='2'>" . $fieldName . "</font></td>\n";
		    $fieldValue = $objMyDB->FieldValue($fieldName);
		    print "<td><input name='VACATION' type=\"checkbox\" value=\"on\" ";
		    print "checked " if ($fieldValue eq "on");
		    print ">";
		    print "</tr>\n";

		} else {
		    print "<tr valign='top' bgcolor='#DDDDDD'>\n";
		    print "<td><font face='arial' size='2'>" . $fieldName . "</font></td>\n";
		    print "<td><input size=\"40\" name=\"" . $fieldName . "\" value=\"";
		    $fieldValue = $objMyDB->FieldValue($fieldName);
		    $fieldValue =~ s/\"/&quot;/g;		
		    print $fieldValue . "\"></td>\n";
		    print "</tr>\n";
		}
	}
	print "</table>\n";
	print "<p>\n";
	print "<input type='hidden' name='vsSD' value='$showDayDetails'>\n";
	print "<input type='hidden' name='vsDay' value='$day'>\n";
	print "<input type='hidden' name='vsMonth' value='$month'>\n";
	print "<input type='hidden' name='vsYear' value='$year'>\n";
	if ($objMyDB->FieldValue("ID")) {
	    print "<input type='hidden' name='vsCOM' value='UPDATE'>\n";
	    print "<input type='submit' value='Update'>\n";
	    print "<input type='submit' value='Delete' onclick=\"if (confirm('Delete This Record?')) {self.location='$scriptName?vsCOM=DELETE&vsSD=$showDayDetails&vsMA=$showforAudrey&vsMonth=$month&vsYear=$year&vsDay=$day&vsID=" . $objMyDB->FieldValue("ID") . "';return false;} else {return false;};\">\n";
	} else {
		print "<input type='hidden' name='DATE' value='$year.$month.$day'>\n";
	    print "<input type='hidden' name='vsCOM' value='INSERT'>\n";
	    print "<input type='submit' value='Add'>\n";
	}
	print "<input type='reset' value='Cancel' onclick=\"window.history.go(-1);return false;\">\n";
	print "</form>\n";
}	

#_____________________________________________________________________________
sub PrintBlankRecord {
	my ($objMyDB) = shift;
	$objMyDB->AddNew;
	PrintCurrentRecord($objMyDB); # this won't be committed, so no big deal
	return 1;
}

#_____________________________________________________________________________
sub UpdateCurrentRecord {
	my ($objMyDB) = shift;
	my ($objMyCGI) = shift;
	my ($fieldName,$fieldValue);
	foreach $fieldName ($objMyDB->FieldNames) {
		$fieldValue = $objMyCGI->param($fieldName);
		$fieldValue = "off" if (($fieldName eq "HOLIDAY" ) and (not ($fieldValue eq "on")));
		$fieldValue = "off" if (($fieldName eq "VACATION" ) and (not ($fieldValue eq "on")));
#print "db: fn=$fieldName fv=$fieldValue\n";
		$objMyDB->FieldValue($fieldName,$fieldValue);
	}
	$objMyDB->Commit;
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

