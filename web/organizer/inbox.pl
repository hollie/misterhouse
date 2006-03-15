#!/usr/local/bin/perl
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
# VERSION HISTORY:
#	1.1.3 - 10/17/01 - fixed bug when mailbox is empty
#	1.1.2 - 10/15/01 - cleaned up code
#	1.1.1 - 10/14/01 - added encrypted cookie based login w/ Crypt::RC4
#	1.1.0 - 10/10/01 - added "send" feature
#	1.0.2 - 10/02/01 - updated attachment feature to use MIME::Parser
#	1.0.1 - 10/01/01 - added attachment feature
#	1.0.1 - 08/02/01 - original release (read only)
# ----------------------------------------------------------------------------
my $VERSION = "1.1.3 BETA";

BEGIN {
#	$SIG{__WARN__} = \&FatalError;
#	$SIG{__DIE__} = \&FatalError;
	########################################################################
	#                       Config Variables                                                                                  #
	########################################################################
    
    # this is the relative path to the config file.  update only if necessary
#   $ENV{"CONFIG_FILE"} = "/data/inbox.cfg";

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

my ($HEADER_PRINTED) = 0;

eval 'use vsDB';
eval 'use CGI';


# --- get the configuration settings 
my ($configFilePath) = $ENV{"CWD"} . "/" . $ENV{"CONFIG_FILE"};
    $configFilePath = "$config_parms{organizer_dir}/inbox.cfg";
my ($objConfig) = new vsDB(
	file => $configFilePath,
	delimiter => "\t",
);
if (!$objConfig->Open) {FatalError($objConfig->LastError)};
my ($title) = $objConfig->FieldValue("Title");
my ($bodyTag) = $objConfig->FieldValue("BodyTag");
my ($headerColor) = $objConfig->FieldValue("HeaderColor");
my ($dataDarkColor) = $objConfig->FieldValue("DataDarkColor");
my ($dataLightColor) = $objConfig->FieldValue("DataLightColor");
my ($detailIcon) = $objConfig->FieldValue("DetailIcon");
my ($attachLogo) = $objConfig->FieldValue("AttachmentIcon");
my (@showFields) = split(",",$objConfig->FieldValue("ShowFields"));
my ($pageSize) = $objConfig->FieldValue("PageSize") || "10";
my ($popUserId) = $objConfig->FieldValue("PopUserId") || "";
my ($encryptKey) = $objConfig->FieldValue("EncryptKey") || "";
my ($popServer) = $objConfig->FieldValue("PopServer") || "";
my ($popEmail) = $objConfig->FieldValue("PopEmail") || "";
my ($smtpServer) = $objConfig->FieldValue("SmtpServer") || "";
my ($sendmailPath) = $objConfig->FieldValue("SendmailPath") || ""; 
my ($tempDir) = $objConfig->FieldValue("TempDir") || "";

my ($tempEmailDir) = $ENV{"CWD"} . "/" . $tempDir . "/";

$objConfig->Close;
undef($objConfig);
# -- end config 

my ($objCGI) = new CGI;
my ($command) = $objCGI->param('vsCOM') || "";
my ($msgId) = $objCGI->param('vsID') || "";
my ($attId) = $objCGI->param('vsATT') || "";
my ($message) = $objCGI->param('vsMessage') || "";
my ($to) = $objCGI->param('vsTo') || "";
my ($subject) = $objCGI->param('vsSubject') || "";
my ($scriptName) = $ENV{'SCRIPT_NAME'} || "inbox.pl";
my ($objPop);

# password cookie is ecrypted using RC4, so decrypt before using it
my ($popPassword) = $objCGI->cookie('vsPass') || "";
if ($popPassword) {
	eval 'use Crypt::RC4';
	$popPassword = RC4( $encryptKey, $popPassword )
}	

# main processing logic...
if ($command eq "LOGIN") {
	if (!$popServer || !$popUserId || $popPassword) {
		FatalError("You must configure the POP Server and User Id using Setup.");
	}
	ProcessLogin();
} elsif ($command eq "LOGOUT") {
	ProcessLogout();
} elsif ($command eq "FRAME") {
	ShowFrameSet();
} elsif ($command eq "COMPOSE") {
	ShowBlankMessage();
} elsif ($command eq "SEND") {
	SendMessage();
} else {
	# any of these actions require logging into the pop server
	ConnectPop();
	if ($command eq "READATT") {
		ShowAttachment($objPop,$msgId,$attId);
	} elsif ($command eq "READ") {
		ShowMessage($objPop,$msgId);
	} elsif ((uc($command) eq "DELETE" || uc($command) eq "DELETE SELECTED") && $msgId ne "") {
		DeleteMessages($objPop);
	} else {	
		ShowAllMessages($objPop);
	}
	$objPop->Close;
}

#______________________________________________________________________________
sub ShowFrameSet {

	if ($popPassword) {
		print "Content-type: text/html\n\n";
		$HEADER_PRINTED = 1;
		print "
		<html>
		<head><title>$title</title></head>
		<frameset rows='50%,50%'>
			<frame name='messages' src='inbox.pl?vsCOM=SHOWALL'></frame>
			<frame name='preview' src=''></frame>
		</frameset>
		</html>
		";
	} else {
	WritePageHeader();
	print "
		<form action='$scriptName' method='post'>
		<input type='hidden' name='vsCOM' value='LOGIN'>
		<input type='password' name='vsPass'>
		<input type='submit' value='Login'>
		</form>
		<p>
		<b>DISCLAIMER: BETA SOFTWARE!</b>
		<P>
		This email client is only somewhat functional.  Although it works for most basic purposes,
		it probably shouldn't be used in a production environment.  Known bugs include:
		<ul>
		<li>Some email messages appear to be blank.
		<li>Doesn't handle certain HTML formats well
		<li>Sometimes has problems with attachments
		<li>Doesn't allow you to send message with attachments
		<li>Doesn't handle large number of messages in the inbox well.
		</ul>
		<p>
		The following Perl modules must be installed on your system in order to use this program:
		<ul>
		<li>CGI
		<li>Crypt::RC4
		<li>Date::Format
		<li>Mail::Pop3Client
		<li>MIME::Parser (installed as part of MIME::Tools)
		<li>vsDB
		<li>vsEmail
		</ul>
	";
	WritePageFooter();
	}		
}	

#______________________________________________________________________________
sub WritePageHeader {
		print "Content-type: text/html\n\n";
		$HEADER_PRINTED = 1;
		print "
		<html>
		<head><title>$title</title></head>
		$bodyTag
		<font face='arial' size='2'>
		<table bgcolor='$headerColor' border='0' width='100%'><tr><td><b>$title</b></td></tr></table>
		<p>
		";
}

#______________________________________________________________________________
sub WritePageFooter {
		print "
		<hr><font size='1'>
		VerySimple Email Client $VERSION &copy 2002, <a href='http://www.verysimple.com/'>VerySimple</a><br>
		</font><p>
		</font>
		</body>
		</html>
		";
}

#______________________________________________________________________________
sub DeleteMessages {
	my ($objMyPop) = shift || return 0;
	WritePageHeader();
	# delete the message(s)
	my ($nCount, $msgId);
	my (@arrMsgIds) = $objCGI->param('vsID');
	foreach $msgId (@arrMsgIds) {
		$objMyPop->Delete($msgId);
		# print "Message " . $msgId . " deleted<br>\n";
		$nCount++;
	}

	print "<b>$nCount Message(s) Deleted...</b><br>\n";
	print "<script>\n";
	print "self.location='$scriptName';\n";
	print "</script>\n";
	WritePageFooter();
}

#______________________________________________________________________________
sub ConnectPop {
	eval 'use Mail::POP3Client';
	eval 'use MIME::Parser';
	$objPop = new Mail::POP3Client( HOST  => $popServer );
	$objPop->User( $popUserId );
	$objPop->Pass( $popPassword );
	$objPop->Connect() || &LoginFailed;
}

#______________________________________________________________________________
sub LoginFailed {

	my ($strErrMsg) = $objPop->Message;
	chop ($strErrMsg);
	
	# if the message is +OK then the login didn't really fail - there are just no messages
	# in the mailbox.
	return 0 if ($strErrMsg eq "+OK");
	
	my ($cookie) = $objCGI->cookie(-name=>'vsPass',
		 -value=>'',
		 -expires=>'+1h',
	);
    print $objCGI->header(-cookie=>$cookie);

	print "<html>";
	print "<font face='Arial,Helvetica' size='2'>";
	print "<table bgcolor='$headerColor' border='0' width='100%'><tr><td><b>$title</b></td></tr></table><p>";
	print "<b><font color='red'>Login Failed: $strErrMsg</font></b><br>\n";
	print "<form>\n";
	print "<input type='reset' value='Try Again...' onclick=\"self.parent.location='$scriptName?vsCOM=FRAME';\">\n";
	print "</form>";
	WritePageFooter();
	exit 1;
}

#______________________________________________________________________________
sub ProcessLogin {
	# RC4 encrypt the password before storing as a cookie
	eval 'use Crypt::RC4';
	my ($encrypted) = RC4( $encryptKey, $objCGI->param('vsPass') );	
	
	my ($cookie) = $objCGI->cookie(
		-name=>'vsPass',
		-value=>$encrypted,
		-expires=>'+1h',
	);
    print $objCGI->header(-cookie=>$cookie);

	print "<html>";
	print "<font face='Arial,Helvetica' size='2'>";
	print "<table bgcolor='$headerColor' border='0' width='100%'><tr><td><b>$title</b></td></tr></table><p>";
	print "<b>Logging In.  One moment Please...</b><br>\n";
	print "<script>\n";
	print "self.location='$scriptName?vsCOM=FRAME';\n";
	print "</script>\n";
	print "</form>";
	WritePageFooter();
}

#______________________________________________________________________________
sub ProcessLogout {
	my ($cookie) = $objCGI->cookie(-name=>'vsPass',
		 -value=>'',
		 -expires=>'+1h',
	);
    print $objCGI->header(-cookie=>$cookie);

	print "<html>";
	print "<font face='Arial,Helvetica' size='2'>";
	print "<table bgcolor='$headerColor' border='0' width='100%'><tr><td><b>$title</b></td></tr></table><p>";
	print "<b>Logging Out.  One moment please...</b><br>\n";
	print "<script>\n";
	print "self.location='$scriptName?vsCOM=FRAME';\n";
	print "</script>\n";
	print "</form>";
	WritePageFooter();

}

#______________________________________________________________________________
sub SendMessage {
	$|++;
	WritePageHeader();

	eval 'use vsEmail';
	my ($objMessage) = new vsEmail(
		SmtpServer		=> $smtpServer,
		SendmailPath	=> $sendmailPath,
		From				=> $popEmail,
		To					=> $to,
		Subject			=> $subject,
		Message			=> $message
	);

	print "Sending Message...";
	
	# send the message.  return value of true indicates success.
	if ($objMessage->Send) {
		print " Message Sent!\n";
	} else {
		print " <b>Send Message Failed:</b><p>\n<pre>" . $objMessage->Log . "</pre><p>\n";
		print "Smtp: " . $objMessage->SmtpServer . "<br>";
		print "To: " . $objMessage->To . "<br>";
		print "From: " . $objMessage->From . "<br>";
		print "Subject: " . $objMessage->Subject . "<p>";
	}
	
	WritePageFooter();

}

#______________________________________________________________________________
sub ShowBlankMessage {
	print "Content-type: text/html\n\n";
	$HEADER_PRINTED = 1;
	print "
		<form action='$scriptName' method='post'>
		<table bgcolor='$headerColor' border='0'>
		<tr><td><font size='2'>To:</td><td><input type='text' size='50' name='vsTo' value='$to'></td></tr>
		<tr><td><font size='2'>Subject:</td><td><input type='text' size='50' name='vsSubject' value='$subject'></td></tr>
		<tr><td colspan='2'><textarea cols='70' rows='10' name='vsMessage'>$message</textarea></td></re>
		</table>
		<p>
		<input type='hidden' name='vsCOM' value='SEND'>
		<input type='submit' value='Send Message'>
		<input type='reset' value='Reset' onclick=\"return confirm('Reset message?');\">
		</form>
		</html>
	";

}	

#______________________________________________________________________________
sub ShowAllMessages {
	my ($objMyPop) = shift || return 0;
	my ($strHeader, $nDelimPos, $strHeaderType, $strHeaderContent);
	my (%hshHeaders);

	WritePageHeader();
	print "<form action='" . $scriptName . "' method='post'>\n";

	if ($objMyPop->Count < 1) {
		print "<b>Your mailbox is currently empty</b>\n";
		print "<p>\n";
	} else {
		print "<table border='0' cellspacing='1' cellpadding='1'>\n";
		print "<tr bgcolor='$dataDarkColor'>\n";
		print "<td><font face='Arial,Helvetica' size='2'>&nbsp;</font></td>\n";
		print "<td><font face='Arial,Helvetica' size='2'>&nbsp;</font></td>\n";
		print "<td><font face='Arial,Helvetica' size='2'><b>From</b></font></td>\n";
		print "<td><font face='Arial,Helvetica' size='2'><b>Subject</b></font></td>\n";
		print "<td><font face='Arial,Helvetica' size='2'><b>Received</b></font></td>\n";
		print "</tr>\n";

		for (my $msg = $objMyPop->Count;$msg > 0; $msg--) {
			foreach $strHeader ($objMyPop->Head($msg)) {
				$nDelimPos = index($strHeader,":",0);
				$strHeaderType = lc(substr($strHeader,0,$nDelimPos));
				$hshHeaders{$strHeaderType} = substr($strHeader,$nDelimPos + 2);
				#print "$strHeaderType ### $hshHeaders{$strHeaderType}<br>\n";
			}
			print "<tr bgcolor='$dataLightColor'>\n";
			print "<td><input type='checkbox' name='vsID' value='$msg'></td>\n";
			print "<td><font face='Arial,Helvetica' size='1'><a target='preview' href='$scriptName?vsCOM=READ&vsID=$msg'><img src='$detailIcon' border='0' alt='Read Message'></a></font></td>\n";
			print "<td><font face='Arial,Helvetica' size='1'>$hshHeaders{'from'}&nbsp;</font></td>\n";
			print "<td><font face='Arial,Helvetica' size='1'>$hshHeaders{'subject'}&nbsp;</font></td>\n";
			print "<td><font face='Arial,Helvetica' size='1'>$hshHeaders{'date'}&nbsp;</font></td>\n";
			print "</tr>\n";
		}		
		print "</table>\n";
		print "<p>\n";
		print "<input type='submit' name='vsCOM' value='Delete Selected' onclick=\"return confirm('Delete Selected Messages?');\">\n";	
	}

	print "<input type='reset' value='Refresh' onclick=\"self.location='$scriptName';return false;\">\n";	
	print "<input type='reset' value='New Message' onclick=\"self.parent.frames(1).location='$scriptName?vsCOM=COMPOSE';return false;\">\n";	
	print "<input type='reset' value='Logout' onclick=\"self.parent.location='$scriptName?vsCOM=LOGOUT';return false;\">\n";	
	print "</form>\n";
	WritePageFooter();
	return 1;
}

#______________________________________________________________________________
sub ShowMessage {
	my ($objMyPop) = shift || return 0;
	my ($nMsgId) = shift || return 0;
	my ($strHeader, $nDelimPos, $strHeaderType, $strHeaderContent);
	my (%hshHeaders);
	my ($strLineBreak) = "<br>\n";

	foreach $strHeader ($objMyPop->Head($nMsgId)) {
		$nDelimPos = index($strHeader,":",0);
		$strHeaderType = lc(substr($strHeader,0,$nDelimPos));
		$hshHeaders{$strHeaderType} = substr($strHeader,$nDelimPos + 2);
		#print "$strHeaderType ### $hshHeaders{$strHeaderType}<br>\n";
	}

	print "Content-type: text/html\n\n";
	$HEADER_PRINTED = 1;
	print "<form action='$scriptName' method='post'>";
	print "<p><table bgcolor='$dataDarkColor' border='0' cellspacing='0' cellpadding='5' width='100%'><tr valign='top'><td>";
	print "<font face='Arial,Helvetica' size='2'>\n";
	print "<b>Subject:</b> $hshHeaders{'subject'}<br>\n";	
	print "<b>From:</b> $hshHeaders{'from'}<br>\n";	
	print "<input type='hidden' name='vsTo' value='" . $hshHeaders{'from'} . "'>\n";	
	print "<input type='hidden' name='vsSubject' value='RE: " . $hshHeaders{'subject'} . "'>\n";	
	print "<b>Received:</b> $hshHeaders{'date'}<br>\n";
	print "</font></td></tr></table>\n";
	print "<p><font face='Courier New' size='2'>\n";

	my ($objParser) = new MIME::Parser;
	$objParser->output_dir( $tempEmailDir );

	my $strHeadAndBody = join("\n",$objMyPop->HeadAndBody($nMsgId));
	my $objEntity = $objParser->parse_data( $strHeadAndBody );

	if ($objParser->last_error ne "") {print $objParser->last_error;}	

	if ($objEntity->is_multipart) {
		my ($objPart);
		foreach $objPart  ($objEntity->parts) {
			WritePart($objPart);	
		}
	} else {
		WritePart($objEntity);
	}

	$objEntity->purge;	
		
	print "</font>\n";	
	print "<p><table bgcolor='$dataLightColor' border='0' cellspacing='0' cellpadding='5' width='100%'><tr valign='top'><td>";
	print "<input type='hidden' name='vsID' value='$nMsgId'>\n";	
	print "<input type='hidden' name='vsCOM' value='COMPOSE'>\n";	
	print "<input type='submit' value='Reply'>\n";	
	print "<input type='submit' value='Forward' onclick=\"this.form.vsTo.value='';\">\n";	
	print "</td></tr></table>\n";
	print "</form>\n";
	print "</html>\n";

}


my ($PART_NUMBER) = 0;
my ($PRINTED_MESSAGE) = 0;
#______________________________________________________________________________
sub WritePart{
	my $objEntPart = shift || return 0;

	# see if this is an outlook style message w/ 2 parts (one html and one text version)
	if ($objEntPart->is_multipart) {
		# print "##MULTIPART##<br>\n";
		#my $objSubPart;
		#foreach $objSubPart ($objEntPart->parts) {
		#	WritePart($objSubPart);
		#}

		# if this is ms outlook style message, try to find the html version
		if ($objEntPart->parts(1)->effective_type eq "text/html") {
			$objEntPart = $objEntPart->parts(1);
		} else {
			$objEntPart = $objEntPart->parts(0);
		}			

	} # else {

		my ($strType) = $objEntPart->effective_type;

		if (($strType eq "text/html" || $strType eq "text/plain") && $PRINTED_MESSAGE < 1) {
			$PRINTED_MESSAGE++;

			my ($strBody) = $objEntPart->bodyhandle->as_string;
			
			print "<input type='hidden' name='vsMessage' value='$strBody'>\n";

			if ($strType eq "text/plain") {		
				$strBody =~ s/\n/<br>/g;
			}
			print $strBody;
		} else {

			# this is an attachment	
			print "<a href='$scriptName?vsCOM=READATT&vsID=$msgId&vsATT=$PART_NUMBER' target='ATT'>";
			print "<img src='$attachLogo' border='0' alt='Click to view/save $strType attachment...'></a>\n";
			# print "<font size='1' face='Arial,Helvetica'>Att. " . $PART_NUMBER . "</font>\n";
		}

		$PART_NUMBER++;

	# }

}	

#______________________________________________________________________________
#sub WritePart {
	# this function is used to recusively print all the sub-parts of each part.  at the moment,
	# this only seems to apply to outlook style messages where the first part contains
	# both a text and an html version of the message.  we only need to print one, so
	# let's not bother... (keep this here in case the need changes, though)
	#	my $objEntPart = shift || return 0;
	#	# recursively print all the sub-part...
	#	if ($objEntPart->is_multipart) {
	#		my $objSubPart;
	#		foreach $objSubPart ($objEntPart->parts) {
	#			WritePart($objSubPart);
	#		}
	#	} else {
	#			my ($strType) = $objEntPart->effective_type;
	#			if ($strType eq "text/html" || $strType eq "text/plain") {
	#				print "<p>" . $objEntPart->bodyhandle->as_string;
	#			} else {
	#				print "<p><a href='#'><img src='$attachLogo' border='0' alt=''></a>\n";
	#			}	
	#	}	
#}	

#______________________________________________________________________________
sub ShowAttachment {
	my ($objMyPop) = shift || return 0;
	my ($nMsgId) = shift || return 0;
	my ($nAttId) = shift || return 0;

	my ($objParser) = new MIME::Parser;
	$objParser->output_dir( $tempEmailDir );

	my $strHeadAndBody = join("\n",$objMyPop->HeadAndBody($nMsgId));
	my $objEntity = $objParser->parse_data( $strHeadAndBody );

	$objEntity->make_singlepart;	

	my ($objPart) = $objEntity->parts($nAttId);
	my ($strType) = $objPart->effective_type;
	my ($strBody) = $objPart->bodyhandle->as_string;

	if ($strType eq "text/plain") {
		$strType = "text/html";
		$strBody = "<pre>\n" . $strBody . "</pre>\n";
	}

	print "Content-type: " . $strType . "\n\n";
	print $strBody;

	$objEntity->purge;	
	
}

#_____________________________________________________________________________
sub FatalError {
    my ($strMessage) = shift || "Unknown Error";
	my ($noHeader) = $HEADER_PRINTED || 0;
    print "Content-type: text/html\n\n" unless $noHeader;
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
