#!/usr/bin/perl -w
# ----------------------------------------------------------------------------
# contacts.pl
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
# 1.5.3-1 - 04/06/15 - IA7 Aware
# 1.5.3 - 09/09/05
# 1.5.2 - 02/15/02 - altered toolbar, fixed FNF Error
# 1.5.1 - 11/22/01 - added search toolbar, removed "eval" when including libs
# 1.4.4 - 10/02/01 - fixed inconsistent paging behavior
# 1.4.3 - 08/22/01 - added file locking
# ----------------------------------------------------------------------------

my $VERSION = "1.5.3-1";

BEGIN {
    #	$SIG{__WARN__} = \&FatalError;
    #	$SIG{__DIE__} = \&FatalError;
    ########################################################################
    #                       Config Variables                                                                                  #
    ########################################################################

    # this is the relative path to the config file.  update only if necessary
    #   $ENV{"CONFIG_FILE"} = "/data/contacts.cfg";

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
    push( @INC, $ENV{"CWD"} );

    sub GetCwd {

        # this function tries various methods to get the installation directory.  if it is not found,
        # an error is displayed telling the user to edit the script manually
        my ($testFile) = shift || "";
        my ( $fullPath, $curDir );

        # try these common ones first
        $fullPath = $ENV{"PATH_TRANSLATED"} || $ENV{"SCRIPT_FILENAME"} || "";
        $fullPath =~ s|\\|\/|g;
        $curDir = substr( $fullPath, 0, rindex( $fullPath, "/" ) );
        return $curDir if ( -e "$curDir/$testFile" );

        # that didn't work, this is another common one
        $fullPath =
          ( $ENV{"DOCUMENT_ROOT"} || "" ) . ( $ENV{"SCRIPT_NAME"} || "" );
        $fullPath =~ s|\\|\/|g;
        $curDir = substr( $fullPath, 0, rindex( $fullPath, "/" ) );
        return $curDir if ( -e "$curDir/$testFile" );

        # forget that, let's try the relative path
        $curDir = ".";
        return $curDir if ( -e "$curDir/$testFile" );

        # if all else fails try Cwd
        use Cwd;
        $curDir = Cwd::cwd();
        return $curDir if ( -e "$curDir/$testFile" );

        # i give up!  user is going to have to set it manually
        print "Content-type: text/html\n\n";
        print "<b>Installation path could not be determined.</b>\n";
        print
          "<p>Please edit the script and set \$ENV{\"CWD\"} to the full path in which the script is installed.";
        exit 1;
    }
}    # / BEGIN

# ----------------------------------------------------------------------------

print "Content-type: text/html\n\n";
my ($HEADER_PRINTED) = 1;

use vsLock;
use vsDB;
use CGI;

# --- get the configuration settings
my ($configFilePath) = $ENV{"CWD"} . $ENV{"CONFIG_FILE"};
$configFilePath = "$config_parms{organizer_dir}/contacts.cfg";

my ($objConfig) = new vsDB(
    file      => $configFilePath,
    delimiter => "\t",
);
if ( !$objConfig->Open ) { print $objConfig->LastError; exit 1; }
my ($title)          = $objConfig->FieldValue("Title");
my ($bodyTag)        = $objConfig->FieldValue("BodyTag");
my ($headerColor)    = $objConfig->FieldValue("HeaderColor");
my ($dataDarkColor)  = $objConfig->FieldValue("DataDarkColor");
my ($dataLightColor) = $objConfig->FieldValue("DataLightColor");
my ($detailIcon)     = $objConfig->FieldValue("DetailIcon");
my (@showFields)     = split( ",", $objConfig->FieldValue("ShowFields") );
my ($fileName)       = $objConfig->FieldValue("FileName") || "contacts.tab";
my ($delimiter)      = $objConfig->FieldValue("Delimiter") || "\t";
my ($pageSize)       = $objConfig->FieldValue("PageSize") || "10";
my ($useFileLocking) = $objConfig->FieldValue("UseFileLocking") || 0;

$objConfig->Close;
undef($objConfig);

# -- end config

# print the header
print "
	<html>
	<head><title>$title</title></head>
	$bodyTag
	<font face='arial' size='2'>
	<table bgcolor='$headerColor' border='0' width='100%'><tr><td><b>$title</b></td></tr></table>
	<p>
";

my ($objCGI) = new CGI;
my $ia7_keys = $objCGI->param('ia7');

# want to get the prefix and suffix for creating IA7 URLs
my $web_mode   = "IA5";
my $ia7_prefix = "";
my $ia7_suffix = "";
my $img_prefix = "";

if ($ia7_keys) {
    $ia7_prefix = "/ia7/#_request=page&link=";
    $ia7_suffix = "ia7=" . $ia7_keys . "&_collection_key=" . $ia7_keys;
    $img_prefix = "/organizer/";
    $web_mode   = "IA7";
}

my ($command)    = $objCGI->param('vsCOM') || "";
my ($idNum)      = $objCGI->param('vsID')  || "";
my ($scriptName) = $ENV{'SCRIPT_NAME'}     || "contacts.pl";
$scriptName = $ia7_prefix . "/organizer/tasks.pl" if ( $web_mode eq "IA7" );
my ($filePath) = $ENV{"CWD"} . "/" . $fileName;
$filePath = "$config_parms{organizer_dir}/$fileName";
my ($activePage)    = $objCGI->param('vsAP')          || "1";
my ($sortField)     = $objCGI->param('vsSORT')        || "LastName";
my ($showAll)       = $objCGI->param('vsALL')         || 0;
my ($filterField)   = $objCGI->param('vsFilterField') || "";
my ($filterValue)   = $objCGI->param('vsFilterValue') || "";
my ($showforAudrey) = $objCGI->param('vsMA')          || 0;

$showAll = 1 if ($showforAudrey);

print "<form action='" . $scriptName . "' method='post'>\n";

my ($objDB) = new vsDB(
    file      => $filePath,
    delimiter => $delimiter,
);

# lock the datafile
my ($objLock) = new vsLock( -warn => 1, -max => 5, delay => 1 );
if ($useFileLocking) {
    $objLock->lock($filePath) || die "Couldn't Lock Datafile";
}

if ( !$objDB->Open ) {
    print $objDB->LastError;
    $objLock->unlock($filePath);
    exit 1;
}

if ( $command eq "EDIT" ) {
    $objDB->Filter( "ID", "eq", $idNum );
    PrintCurrentRecord($objDB);
}
elsif ( $command eq "UPDATE" ) {
    $objDB->Filter( "ID", "eq", $idNum );
    UpdateCurrentRecord( $objDB, $objCGI );
    $objDB->RemoveFilter;
    $objDB->MoveFirst;
    PrintAllRecords($objDB);
}
elsif ( $command eq "DELETE" ) {
    $objDB->Filter( "ID", "eq", $idNum );
    $objDB->Delete;
    if ( !$objDB->Commit ) { print "<p><b>" . $objDB->LastError . "</b><p>"; }
    $objDB->RemoveFilter;
    $objDB->MoveFirst;
    PrintAllRecords($objDB);
}
elsif ( $command eq "ADD" ) {
    PrintBlankRecord($objDB);
}
elsif ( $command eq "INSERT" ) {
    $objDB->AddNew;
    my ($newId) = $objDB->Max("ID") || 0;
    $newId = int($newId) + 1;
    $objDB->FieldValue( "ID", $newId );
    UpdateCurrentRecord( $objDB, $objCGI );
    $objDB->MoveFirst;
    PrintAllRecords($objDB);
}
else {
    PrintAllRecords($objDB);
}

if ($useFileLocking) {
    $objLock->unlock($filePath);
}

print "
	</form>
	<hr><font size='1'>
	VerySimple Contacts Editor $VERSION &copy 2002, <a href='http://www.verysimple.com/'>VerySimple</a><br>
";
print "vsDB Module Version " . $objDB->Version . "<br>";
print "vsLock Module Version " . $objLock->Version;
print "<br>MisterAudrey Version" if ($showforAudrey);
print " Web interface: " . $web_mode;

print "
	</font><p>
	</font>
	</body>
	</html>
";
undef($objDB);
undef($objLock);
undef($objCGI);

#_____________________________________________________________________________
sub PrintAllRecords {
    my ($objMyDB) = shift;
    my ( $fieldName, $fieldValue );
    my ($count) = 0;

    my ($visiblePageSize) = $pageSize;
    if ($showAll) { $visiblePageSize = 999 }

    $objMyDB->Sort($sortField);

    if ( $filterField && $filterValue ) {
        $objMyDB->Filter( $filterField, "like", $filterValue );
    }

    $objMyDB->PageSize($visiblePageSize);
    $objMyDB->ActivePage($activePage);
    $activePage =
      $objMyDB->ActivePage;    # (in case we specified one out of range)

    my ($pageCount) = $objMyDB->PageCount;

    print "<form action='$scriptName' method='GET'>\n";
    print
      "<table cellspacing='2' cellpadding='2' border='0'><tr valign='middle'><td bgcolor='$dataDarkColor'>\n";
    if ( !$showforAudrey ) {
        if ($showAll) {
            print
              "<input type='button' onclick=\"window.location='$scriptName?vsALL=0&"
              . $ia7_suffix
              . "';\" value='Show $pageSize Per Page'>";
        }
        else {
            print
              "<input type='button' onclick=\"window.location='$scriptName?vsALL=1&"
              . $ia7_suffix
              . "';\" value='Show All'>";
        }
    }
    print
      "&nbsp;<input type='button' onclick=\"window.location='$scriptName?vsSORT=$sortField&vsMA=$showforAudrey&vsAP=$activePage&vsCOM=ADD&"
      . $ia7_suffix
      . "';\" value='New Contact'>\n";
    print "</td><td>\n";
    print "</td><td bgcolor='$dataDarkColor'>\n";
    print "<select name='vsFilterField'>\n";
    print "<option value='LastName'";
    print " selected" if ( $filterField eq "LastName" );
    print ">Last Name</option>\n";
    print "<option value='Company'";
    print " selected" if ( $filterField eq "Company" );
    print ">Company</option>\n";
    print "<option value='FirstName'";
    print " selected" if ( $filterField eq "FirstName" );
    print ">First Name</option>\n";
    print "</select>&nbsp;";
    print
      "<font face='Arial,Helvetica' size='2'><b>&nbsp;~=&nbsp;</b></font>\n";
    print
      "<input type='text' size='10' name='vsFilterValue' value='$filterValue'>&nbsp;";
    print "<input type='hidden' name='vsMA' value='$showforAudrey'>\n";
    print "<input type='submit' value='Search'>&nbsp;";

    if ( $filterField && $filterValue ) {
        print
          "<input type='submit' value='Clear' onclick=\"this.form.vsFilterValue.value = ''; return true;\">";
    }
    print "</td></tr></table>\n";
    print "</form>\n";

    print "<p>\n";
    print "<table cellspacing='2' cellpadding='2' border='0'>\n";
    print "<tr valign='top' bgcolor='#CCCCCC'>\n";
    print "<td>&nbsp;</td>\n";
    foreach $fieldName (@showFields) {
        print
          "<td><b><font face='arial' size='2'><a href='$scriptName?vsALL=$showAll&vsMA=$showforAudrey&vsSORT=$fieldName&vsFilterField=$filterField&vsFilterValue=$filterValue&"
          . $ia7_suffix . "'>"
          . $fieldName
          . "</a></font></b></td>\n";
    }
    print "</tr>\n";
    while ( !$objMyDB->EOF && $count < $visiblePageSize ) {
        print "<tr valign='top' bgcolor='$dataLightColor'>\n";
        print "<td><font face='arial' size='1'><a href='"
          . $scriptName
          . "?vsAP=$activePage&vsMA=$showforAudrey&vsSORT=$sortField&vsCOM=EDIT&vsID="
          . $objMyDB->FieldValue("ID") . "&"
          . $ia7_suffix
          . "'><img src='"
          . $img_prefix
          . "$detailIcon' alt='Details' border='0'></a></font></td>\n";
        foreach $fieldName (@showFields) {
            $fieldValue = $objMyDB->FieldValue($fieldName);
            $fieldValue = "&nbsp;" if ( $fieldValue eq "" );
            if ( $fieldName eq "PrimaryEmail" && $fieldValue ne "&nbsp;" ) {
                print "<td><font face='arial' size='2'><a href='mailto:"
                  . $fieldValue . "'>"
                  . $objMyDB->FieldValue($fieldName)
                  . "</a></font></td>\n";
            }
            else {
                print "<td><font face='arial' size='2'>"
                  . $fieldValue
                  . "</font></td>\n";
            }
        }
        print "</tr>\n";
        $objMyDB->MoveNext;
        $count++;
    }
    print "</table>\n";
    print "<p>\n";

    print "Result Page " . $activePage . " of " . $pageCount;
    if ( $activePage > 1 ) {
        print
          " <a href='?vsALL=$showAll&vsMA=$showforAudrey&vsSORT=$sortField&vsAP="
          . ( $activePage - 1 )
          . "&vsFilterField=$filterField&vsFilterValue=$filterValue&"
          . $ia7_suffix
          . "'>Previous</a>";
    }
    if ( $activePage < $pageCount ) {
        print
          " <a href='?vsALL=$showAll&vsMA=$showforAudrey&vsSORT=$sortField&vsAP="
          . ( $activePage + 1 )
          . "&vsFilterField=$filterField&vsFilterValue=$filterValue&"
          . $ia7_suffix
          . "'>Next</a>";
    }
    print " (" . $objMyDB->RecordCount . " Records)\n";
}

#_____________________________________________________________________________
sub PrintCurrentRecord {
    my ($objMyDB) = shift;
    my ( $fieldName, $fieldValue );
    print "<table cellspacing='2' cellpadding='2' border='0'>\n";
    foreach $fieldName ( $objMyDB->FieldNames ) {
        $fieldValue = $objMyDB->FieldValue($fieldName);
        $fieldValue =~ s/\"/&quot;/g;
        if ( $fieldName eq "ID" ) {
            print "<input type='hidden' name='vsID' value='$fieldValue'>\n";
        }
        elsif ( $fieldName eq "Notes" ) {
            print "<tr valign='top' bgcolor='$dataLightColor'>\n";
            print "<td><font face='arial' size='2'>$fieldName</font></td>\n";
            print
              "<td><textarea cols=\"38\" rows='3' name=\"$fieldName\">$fieldValue</textarea></td>\n";
            print "</tr>\n";
        }
        else {
            print "<tr valign='top' bgcolor='$dataLightColor'>\n";
            print "<td><font face='arial' size='2'>$fieldName</font></td>\n";
            print
              "<td><input size=\"50\" name=\"$fieldName\" value=\"$fieldValue\"></td>\n";
            print "</tr>\n";
        }
    }
    print "</table>\n";
    print "<p>\n";
    print "<input type='hidden' name='vsALL' value='$showAll'>\n";
    print "<input type='hidden' name='vsMA' value='$showforAudrey'>\n";
    print "<input type='hidden' name='vsAP' value='$activePage'>\n";
    print "<input type='hidden' name='vsSORT' value='$sortField'>\n";

    if ( $objMyDB->FieldValue("ID") ) {
        print "<input type='hidden' name='vsCOM' value='UPDATE'>\n";
        print "<input type='submit' value='Update'>\n";
        print "<input type='hidden' name='vsMA' value='$showforAudrey'>\n";
        print
          "<input style=\"COLOR: maroon;\" type='reset' value='Delete'  onclick=\"if (confirm('Permenantly delete this contact?')) {self.location='$scriptName?vsSORT=$sortField&vsAP=$activePage&vsALL=$showAll&vsMA=$showforAudrey&vsCOM=DELETE&vsID="
          . $objMyDB->FieldValue("ID")
          . "';return false;} else {return false;};\">\n";
    }
    else {
        print "<input type='hidden' name='vsCOM' value='INSERT'>\n";
        print "<input type='submit' value='Add'>\n";
    }
    print "<input type='hidden' name='ia7' value='$ia7_keys'>\n";
    print
      "<input type='reset' value='Cancel' onclick=\"window.history.go(-1);return false;\">\n";
    print "<p>\n";
}

#_____________________________________________________________________________
sub PrintBlankRecord {
    my ($objMyDB) = shift;
    $objMyDB->AddNew;
    PrintCurrentRecord($objMyDB);    # this won't be committed, so no big deal
    return 1;
}

#_____________________________________________________________________________
sub UpdateCurrentRecord {
    my ($objMyDB)  = shift;
    my ($objMyCGI) = shift;
    my ( $fieldName, $fieldValue );
    foreach $fieldName ( $objMyDB->FieldNames ) {
        $fieldValue = $objMyCGI->param($fieldName);
        $objMyDB->FieldValue( $fieldName, $fieldValue );
    }
    if ( !$objMyDB->Commit ) {
        print "<p><b>" . $objMyDB->LastError . "</b><p>";
    }

}

sub FatalError {
    my ($strMessage) = shift || "Unknown Error";
    print "Content-type: text/html\n\n" unless defined($HEADER_PRINTED);
    print "<p><font face='arial,helvetica' size='2'>\n";
    print
      "<b>A fatal error occured.  The script cannot continue.  Details are below:</b>";
    print "<p><font color='red'>" . $strMessage . "</font>";
    print "<p>The most common causes of fatal errors are:\n";
    print "<ol>\n";
    print
      "<li>One of the script files was uploaded via FTP in Binary mode instead of ASCII\n";
    print
      "<li>The file permissions for the data directory and all .tab and .cfg files is not readable/writable\n";
    print "</ol>\n";
    print "<p>If you have already tried these, you may want to visit the ";
    print
      "<a href='http://www.verysimple.com/support/'>VerySimple Support Forum</a> \n";
    print "to see if there is a solution available.\n";
    print "</font>\n";
    exit 1;
}
