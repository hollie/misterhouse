#!/usr/bin/perl -w
# ----------------------------------------------------------------------------
# tasks.pl
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
# 1.6.0-2 - 04/06/15 - IA7 Aware
# 1.6.0-1 - 09/24/07 - Updated to Organizer release 2.5.2 (1.6.0 js fixes, added recordcount)
# 1.4.8-4 - 08/19/07 - iCal2vsdb integration (requires v2104 database)
# 1.4.8-3 - 04/29/07 - minor fixes
# 1.4.8-2 - 08/30/06 - minor fixes
# 1.4.8-1 - 07/24/06 - added control over speech events
# 1.4.8   - 05/06/06 - added vsPS for changing page size
# 1.4.7   - 02/15/02 - fixed FNF error & improved error reporting
# 1.4.6   - 10/02/01 - fixed bug viewing pages in "show all" mode
# 1.4.5   - 08/22/01 - added file locking
# 1.4.4   - 08/05/01 - handle missing datafiles gracefully
# ----------------------------------------------------------------------------
my $VERSION = "1.6.0-1";

BEGIN {
    #	$SIG{__WARN__} = \&FatalError;
    #	$SIG{__DIE__} = \&FatalError;
    ########################################################################
    #                       Config Variables                                                                                  #
    ########################################################################

    # this is the relative path to the config file.  update only if necessary
    #   $ENV{"CONFIG_FILE"} = "/data/tasks.cfg";

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

eval 'use vsLock';
eval 'use vsDB';
eval 'use CGI';

# --- get the configuration settings
my ($configFilePath) = $ENV{"CWD"} . $ENV{"CONFIG_FILE"};
$configFilePath = "$config_parms{organizer_dir}/tasks.cfg";
my ($objConfig) = new vsDB(
    file      => $configFilePath,
    delimiter => "\t",
);
$objConfig->Open;
my ($title)          = $objConfig->FieldValue("Title");
my ($bodyTag)        = $objConfig->FieldValue("BodyTag");
my ($headerColor)    = $objConfig->FieldValue("HeaderColor");
my ($dataDarkColor)  = $objConfig->FieldValue("DataDarkColor");
my ($dataLightColor) = $objConfig->FieldValue("DataLightColor");
my ($detailIcon)     = $objConfig->FieldValue("DetailIcon");
my (@showFields)     = split( ",", $objConfig->FieldValue("ShowFields") );
my ($fileName)       = $objConfig->FieldValue("FileName") || "tasks.tab";
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

my ($command)       = $objCGI->param('vsCOM') || "";
my ($showCompleted) = $objCGI->param('vsSC')  || 0;
my ($idNum)         = $objCGI->param('vsID')  || "";
my ($scriptName)    = $ENV{'SCRIPT_NAME'}     || "tasks.pl";
$scriptName = $ia7_prefix . "/organizer/tasks.pl" if ( $web_mode eq "IA7" );
my ($filePath) = $ENV{"CWD"} . "/" . $fileName;
$filePath = "$config_parms{organizer_dir}/$fileName";
my ($activePage) = $objCGI->param('vsAP')   || "1";
my ($sortField)  = $objCGI->param('vsSORT') || "";
$pageSize = $objCGI->param('vsPS') if $objCGI->param('vsPS');

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
    die;
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
    $objDB->Commit;
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
	VerySimple Task Editor $VERSION &copy 2001, <a href='http://www.verysimple.com/'>VerySimple</a> MH Modified<br>
";
print "vsDB Module Version " . $objDB->Version . "<br>";
print "vsLock Module Version " . $objLock->Version;
print "<br>ical2vsdb sync 1.0";
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

    $objMyDB->Sort($sortField) if ( $sortField ne "" );
    $objMyDB->Filter( "Complete", "ne", "Yes" ) unless ($showCompleted);

    $objMyDB->PageSize($pageSize);
    $objMyDB->ActivePage($activePage);

    #$activePage = $objMyDB->ActivePage; # (in case we specified one out of range)
    my ($pageCount) = $objMyDB->PageCount;

    print
      "<table cellspacing='2' cellpadding='2' border='0'><tr valign='middle'><td bgcolor='$dataDarkColor'>\n";

    #if ($m_blnIsSysAdmin) {
    print
      "<input type='submit' value='Add New Task' onclick=\"self.location='$scriptName"
      . PassThrough( "vsCOM", "ADD" )
      . "';return false\">\n";

    #	print "<input type='submit' value='Logout' onclick=\"if (confirm('Logout?')) {self.location='$scriptName?vsSC=$showCompleted&vsCOM=LOGOUT';return false;} else {return false;};\">\n" if ($m_strSysAdminUserId || $m_strSysAdminPassword);
    #} else {
    #	print "<input type='hidden' name='vsCOM' value='LOGINFORM'>\n";
    #	print "<input type='submit' value='Login'>\n";
    #}

    if ($showCompleted) {
        print
          " <input type='submit' value='Hide Completed' onclick=\"self.location='$scriptName?vsSORT=$sortField&vsPS=$pageSize&"
          . $ia7_suffix
          . "';return false\">\n";
    }
    else {
        print
          " <input type='submit' value='Show Completed' onclick=\"self.location='$scriptName?vsSORT=$sortField&vsSC=1&vsPS=$pageSize&"
          . $ia7_suffix
          . "';return false\">\n";
    }
    print "</td></tr></table>\n";

    print "<p><table cellspacing='2' cellpadding='2' border='0'>\n";
    print "<tr valign='top' bgcolor='#CCCCCC'>\n";
    print "<td>&nbsp;</td>\n";
    foreach $fieldName (@showFields) {
        print
          "<td><b><font face='arial' size='2'><a href='$scriptName?vsSORT=$fieldName&vsPS=$pageSize&vsSC=$showCompleted&"
          . $ia7_suffix . "'>"
          . $fieldName
          . "</a></font></b></td>\n";
    }
    print "</tr>\n";
    my $link_open;
    my $link_close;
    while ( !$objMyDB->EOF && $count < $pageSize ) {
        print "<tr valign='top' bgcolor='$dataLightColor'>\n";
        my $icon   = $detailIcon;
        my $source = $objMyDB->FieldValue("SOURCE");
        $icon = "images/ical_2.jpg" if ( $source =~ /^ical=/ );
        $icon = $img_prefix . $icon;
        $link_open =
            "<a href='"
          . $scriptName
          . "?vsSORT=$sortField&vsPS=$pageSize&vsAP=$activePage&vsCOM=EDIT&vsID="
          . $objMyDB->FieldValue("ID") . "&"
          . $ia7_suffix . "'>";
        $link_close = "</a>";
        print "<td>"
          . $link_open
          . "<img src='$icon' alt='Details' border='0'></font>"
          . $link_close
          . "</td>\n";

        foreach $fieldName (@showFields) {
            $fieldValue = $objMyDB->FieldValue($fieldName);
            $fieldValue = "&nbsp;" if ( $fieldValue eq "" );
            if ( $fieldName eq "SpecialField" ) {

                # not used at the moment, but maybe later...
                print "<td>"
                  . $link_open
                  . "<font face='arial' size='2'>"
                  . $fieldValue
                  . "</font>"
                  . $link_close
                  . "</td>\n";
            }
            elsif ( lc $fieldName eq "SPEAK" ) {
                print "<td>"
                  . $link_open
                  . "<font face='arial' size='2'>"
                  . $fieldValue
                  . "</font>"
                  . $link_close
                  . "</td>\n";
            }
            elsif ( $fieldName eq "SOURCE" ) {
            }
            else {
                if (   ( $fieldName eq "AssignedTo" )
                    or ( $fieldName eq "DueDate" ) )
                {
                    $link_open  = "";
                    $link_close = "";
                }
                print "<td>"
                  . $link_open
                  . "<font face='arial' size='2'>"
                  . $fieldValue
                  . "</font>"
                  . $link_close
                  . "</td>\n";
            }
        }
        print "</tr>\n";
        $objMyDB->MoveNext;
        $count++;
    }
    print "</table>\n";
    print "<p>\n";

    print "Result Page ";

    print "<select name='ap' onchange=\"document.location='"
      . $scriptName
      . PassThrough("vsAP")
      . "' + this.options[this.selectedIndex].value;return true;\">\n";
    print "<option value='1'>1</option>";
    for ( my $x = 1; $x < $pageCount; $x++ ) {
        print "<option value='" . ( $x + 1 ) . "'";
        print " selected" if ( $activePage == ( $x + 1 ) );
        print ">" . ( $x + 1 ) . "</option>";
    }
    print "\n</select>\n";

    print " of $pageCount";
    print " (" . $objMyDB->RecordCount . " Records)";
    print "<p>\n";

}

#_____________________________________________________________________________
sub PrintCurrentRecord {
    my ($objMyDB) = shift;
    my ( $fieldName, $fieldValue );
    my $source;
    print "<table cellspacing='2' cellpadding='2' border='0'>\n";
    foreach $fieldName ( $objMyDB->FieldNames ) {
        if ( $fieldName eq "ID" ) {
            print "<input type='hidden' name='vsID' value='"
              . $objMyDB->FieldValue("ID") . "'>\n";
        }
        else {
            print "<tr valign='top' bgcolor='$dataLightColor'>\n";
            print "<td><font face='arial' size='2'>"
              . $fieldName
              . "</font></td>\n"
              if ( $fieldName ne "SOURCE" );
            if ( $fieldName eq "Complete" ) {
                my ($yes) = "";
                my ($no)  = "";
                $yes = "checked"
                  if ( $objMyDB->FieldValue("Complete") eq "Yes" );
                $no = "checked" if ( $objMyDB->FieldValue("Complete") eq "No" );
                print "<td><font face='arial' size='2'>";
                print
                  "<input type=\"radio\" name=\"Complete\" value=\"Yes\" $yes>Yes\n";
                print
                  "<input type=\"radio\" name=\"Complete\" value=\"No\" $no>No\n";
                print "</font></td>";
            }
            elsif ( $fieldName eq "Notes" ) {
                print "<td><textarea name='Notes' cols='47' rows='8'>";
                $fieldValue = $objMyDB->FieldValue("Notes");
                $fieldValue =~ s/\"/&quot;/g;
                print $fieldValue . "</textarea></td>\n";
            }
            elsif ( $fieldName eq "SPEAK" ) {
                $fieldValue = $objMyDB->FieldValue($fieldName);
                print
                  "<td><input name='SPEAK' type=\"checkbox\" value=\"Yes\" ";
                if ( $fieldValue eq "Yes" ) {
                    print "CHECKED > ";
                }
                else {
                    print "> ";
                }

            }
            elsif ( $fieldName eq "SOURCE" ) {
                $fieldValue = $objMyDB->FieldValue($fieldName);
                $source     = $fieldValue;
                $source     = "local" if ( !$source );

            }
            else {
                print "<td><input size=\"50\" name=\""
                  . $fieldName
                  . "\" value=\"";
                $fieldValue = $objMyDB->FieldValue($fieldName);
                $fieldValue =~ s/\"/&quot;/g;
                print $fieldValue . "\"></td>\n";
            }
            print "</tr>\n";
        }
    }
    if ( $source eq "local" ) {
        print "</table>\n";
        print "<p>\n";
        print "<input type='hidden' name='vsSC' value='$showCompleted'>\n";
        print "<input type='hidden' name='vsAP' value='$activePage'>\n";
        print "<input type='hidden' name='vsSORT' value='$sortField'>\n";
        print "<input type='hidden' name='vsPS' value='$pageSize'>\n";
        print "<input type='hidden' name='vsCOM' value='UPDATE'>\n";
        print "<input type='hidden' name='SOURCE' value='local'>\n";
        print "<input type='hidden' name='ia7' value='$ia7_keys'>\n";
        print "<input type='submit' value='Update' >\n";
        print
          "<input style=\"COLOR: maroon;\" type='reset' value='Delete'  onclick=\"if (confirm('Permenantly delete this task?')) {self.location='$scriptName?vsSORT=$sortField&vsAP=$activePage&vsPS=$pageSize&vsSC=$showCompleted&vsCOM=DELETE&vsID="
          . $objMyDB->FieldValue("ID")
          . "';return false;} else {return false;};\">\n";
        print
          "<input type='reset' value='Cancel' onclick=\"window.history.go(-1);return false;\">\n";
        print "<p>\n";
    }
    else {
        $source =~ /^ical=(\S*)\ssync=(.*)/;
        my $icalname = $1;
        my $icalsync = $2;
        print
          "<tr><td colspan=4><font face='arial' size='2'>iCal2vsdb (ical $icalname) $icalsync\n";
        print "</font></td></tr></table>\n";
    }
}

#_____________________________________________________________________________
sub PrintBlankRecord {
    my ($objMyDB) = shift;
    my ($fieldName);
    print "<table cellspacing='2' cellpadding='2' border='0'>\n";
    foreach $fieldName ( $objMyDB->FieldNames ) {
        if ( $fieldName ne "ID" ) {
            print "<tr valign='top' bgcolor='$dataLightColor'>\n";
            if ( $fieldName eq "Complete" ) {
                print "<td><font face='arial' size='2'>"
                  . $fieldName
                  . "</font></td>\n";
                print "<td><font face='arial' size='2'>";
                print
                  "<input type=\"radio\" name=\"Complete\" value=\"Yes\">Yes\n";
                print
                  "<input type=\"radio\" name=\"Complete\" value=\"No\" checked>No\n";
                print "</font></td>";
            }
            elsif ( $fieldName eq "Notes" ) {
                print "<td><font face='arial' size='2'>"
                  . $fieldName
                  . "</font></td>\n";
                print
                  "<td><textarea name='Notes' cols='38' rows='3'></textarea></td>\n";
            }
            elsif ( $fieldName eq "SPEAK" ) {
                print "<td><font face='arial' size='2'>"
                  . $fieldName
                  . "</font></td>\n";
                print
                  "<td><input name='SPEAK' type=\"checkbox\" value=\"Yes\" >";
                print "</tr>\n";
            }
            elsif ( $fieldName eq "SOURCE" ) {    #do nothing
            }
            else {
                print "<td><font face='arial' size='2'>"
                  . $fieldName
                  . "</font></td>\n";
                print "<td><input size=\"50\" name=\""
                  . $fieldName
                  . "\" value=\"\"></td>\n";
            }
            print "</tr>\n";
        }
    }
    print "</table>\n";
    print "<p>\n";
    print "<input type='hidden' name='vsSC' value='$showCompleted'>\n";
    print "<input type='hidden' name='vsAP' value='$activePage'>\n";
    print "<input type='hidden' name='vsSORT' value='$sortField'>\n";
    print "<input type='hidden' name='vsPS' value='$pageSize'>\n";
    print "<input type='hidden' name='SOURCE' value='local'>\n";
    print "<input type='hidden' name='vsCOM' value='INSERT'>\n";
    print "<input type='hidden' name='ia7' value='$ia7_keys'>\n";

    print "<input type='submit' value='Add'>\n";
    print
      "<input type='reset' value='Cancel' onclick=\"window.history.go(-1);return false;\">\n";
    print "<p>\n";
}

#_____________________________________________________________________________
sub UpdateCurrentRecord {
    my ($objMyDB)  = shift;
    my ($objMyCGI) = shift;
    my ( $fieldName, $fieldValue );
    foreach $fieldName ( $objMyDB->FieldNames ) {
        $fieldValue = $objMyCGI->param($fieldName);
        $fieldValue = "No"
          if ( ( $fieldName eq "SPEAK" ) and ( not( $fieldValue eq "Yes" ) ) );

        #print "db: fn=$fieldName fv=$fieldValue\n";
        $objMyDB->FieldValue( $fieldName, $fieldValue );
    }
    $objMyDB->Commit;
}

#_____________________________________________________________________________
sub PassThrough {
    my ($fieldName)  = shift || return '';
    my ($fieldValue) = shift || "";
    my (@params)     = $objCGI->param;
    my ($appendChar) = "?";
    my ($param);
    my ($queryString);
    my ($val);
    foreach $param (@params) {

        unless ( $fieldName eq $param ) {
            $val = $objCGI->param($param) || "";
            $val =~ s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
            $queryString .= $appendChar . $param . "=" . $val;
            $appendChar = "&";
        }
    }
    $queryString .= $appendChar . $fieldName . "=" . $fieldValue;
    return $queryString;
}

#_____________________________________________________________________________
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
