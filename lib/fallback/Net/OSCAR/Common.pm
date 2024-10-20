=pod

Net::OSCAR::Common -- Net::OSCAR public constants

=cut

package Net::OSCAR::Common;

$VERSION = '1.925';
$REVISION = '$Revision: 1.67 $';

use strict;
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS $VERSION);
use Scalar::Util qw(dualvar);
require Exporter;
@ISA = qw(Exporter);

%EXPORT_TAGS = (
	standard => [qw(
		ADMIN_TYPE_PASSWORD_CHANGE
		ADMIN_TYPE_EMAIL_CHANGE
		ADMIN_TYPE_SCREENNAME_FORMAT
		ADMIN_TYPE_ACCOUNT_CONFIRM
		ADMIN_ERROR_UNKNOWN
		ADMIN_ERROR_DIFFSN
		ADMIN_ERROR_BADPASS
		ADMIN_ERROR_BADINPUT
		ADMIN_ERROR_BADLENGTH
		ADMIN_ERROR_TRYLATER
		ADMIN_ERROR_REQPENDING
		ADMIN_ERROR_CONNREF
		ADMIN_ERROR_EMAILLIM
		ADMIN_ERROR_EMAILBAD
		VISMODE_PERMITALL
		VISMODE_DENYALL
		VISMODE_PERMITSOME
		VISMODE_DENYSOME
		VISMODE_PERMITBUDS
		MODBL_ACTION_ADD
		MODBL_ACTION_DEL
		MODBL_WHAT_BUDDY
		MODBL_WHAT_GROUP
		MODBL_WHAT_PERMIT
		MODBL_WHAT_DENY
		TYPINGSTATUS_STARTED
		TYPINGSTATUS_TYPING
		TYPINGSTATUS_FINISHED
		RATE_CLEAR
		RATE_ALERT
		RATE_LIMIT
		RATE_DISCONNECT
		OSCAR_RATE_MANAGE_NONE
		OSCAR_RATE_MANAGE_AUTO
		OSCAR_RATE_MANAGE_MANUAL
		GROUPPERM_OSCAR
		GROUPPERM_AOL
		OSCAR_SVC_AIM
		OSCAR_SVC_ICQ
		OSCAR_DIRECT_IM
		OSCAR_DIRECT_FILESHARE
		OSCAR_DIRECT_FILEXFER
		OSCAR_RV_AUTO
		OSCAR_RV_NOPROXY
		OSCAR_RV_NODIRECT
		OSCAR_RV_MANUAL
	)],
	loglevels => [qw(
		OSCAR_DBG_NONE
		OSCAR_DBG_WARN
		OSCAR_DBG_INFO
		OSCAR_DBG_SIGNON
		OSCAR_DBG_NOTICE
		OSCAR_DBG_DEBUG
		OSCAR_DBG_PACKETS
		OSCAR_DBG_XML
		OSCAR_DBG_XML2
	)]
);
$EXPORT_TAGS{all} = [@{$EXPORT_TAGS{standard}}, @{$EXPORT_TAGS{loglevels}}];
@EXPORT_OK = @{$EXPORT_TAGS{all}};

# Log levels
use constant OSCAR_DBG_NONE => 0;
use constant OSCAR_DBG_WARN => 1;
use constant OSCAR_DBG_INFO => 2;
use constant OSCAR_DBG_SIGNON => 3;
use constant OSCAR_DBG_NOTICE => 4;
use constant OSCAR_DBG_DEBUG => 6;
use constant OSCAR_DBG_PACKETS => 10;
use constant OSCAR_DBG_XML => 30;
use constant OSCAR_DBG_XML2 => 35;

# Buddylist modification
use constant MODBL_ACTION_ADD => dualvar(1, "add");
use constant MODBL_ACTION_DEL => dualvar(2, "delete");
use constant MODBL_WHAT_BUDDY => dualvar(1, "buddy");
use constant MODBL_WHAT_GROUP => dualvar(2, "group");
use constant MODBL_WHAT_PERMIT => dualvar(3, "permit");
use constant MODBL_WHAT_DENY => dualvar(4, "deny");

# Typing statuses
use constant TYPINGSTATUS_STARTED => dualvar(2, "typing started");
use constant TYPINGSTATUS_TYPING => dualvar(1, "typing in progress");
use constant TYPINGSTATUS_FINISHED => dualvar(0, "typing completed");

# Administrative functions
use constant ADMIN_TYPE_PASSWORD_CHANGE => dualvar(1, "password change");
use constant ADMIN_TYPE_EMAIL_CHANGE => dualvar(2, "email change");
use constant ADMIN_TYPE_SCREENNAME_FORMAT => dualvar(3, "screenname format");
use constant ADMIN_TYPE_ACCOUNT_CONFIRM => dualvar(4, "account confirm");

# Adminsitrative responses
use constant ADMIN_ERROR_UNKNOWN => dualvar(0, "unknown error");
use constant ADMIN_ERROR_BADPASS => dualvar(1, "incorrect password");
use constant ADMIN_ERROR_BADINPUT => dualvar(2, "invalid input");
use constant ADMIN_ERROR_BADLENGTH => dualvar(3, "screenname/email/password is too long or too short");
use constant ADMIN_ERROR_TRYLATER => dualvar(4, "request could not be processed; wait a few minutes and try again");
use constant ADMIN_ERROR_REQPENDING => dualvar(5, "request pending");
use constant ADMIN_ERROR_CONNREF => dualvar(6, "couldn't connect to the admin server");
use constant ADMIN_ERROR_DIFFSN => dualvar(7, "the new screenname is not equivalent to the old screenname");
use constant ADMIN_ERROR_EMAILLIM => dualvar(8, "the email address has too many screennames");
use constant ADMIN_ERROR_EMAILBAD => dualvar(9, "the email address is invalid");

# Direct connect types
use constant OSCAR_DIRECT_IM => dualvar(1, "direct IM");
use constant OSCAR_DIRECT_FILESHARE => dualvar(2, "file sharing");
use constant OSCAR_DIRECT_FILEXFER => dualvar(3, "file transfer");

# Rendezvous autonegotiate modes
use constant OSCAR_RV_AUTO => "auto";
use constant OSCAR_RV_NOPROXY => "never proxy";
use constant OSCAR_RV_NODIRECT => "always proxy";
use constant OSCAR_RV_MANUAL => "manual negotiation";


# Visibility modes
use constant VISMODE_PERMITALL  => dualvar(0x1, "permit all");
use constant VISMODE_DENYALL    => dualvar(0x2, "deny all");
use constant VISMODE_PERMITSOME => dualvar(0x3, "permit some");
use constant VISMODE_DENYSOME   => dualvar(0x4, "deny some");
use constant VISMODE_PERMITBUDS => dualvar(0x5, "permit buddies");

# Rate warning types
use constant RATE_CLEAR => dualvar(1, "clear");
use constant RATE_ALERT => dualvar(2, "alert");
use constant RATE_LIMIT => dualvar(3, "limit");
use constant RATE_DISCONNECT => dualvar(4, "disconnect");

# Rate handling modes
use constant OSCAR_RATE_MANAGE_NONE => dualvar(0, "none");
use constant OSCAR_RATE_MANAGE_AUTO => dualvar(1, "auto");
use constant OSCAR_RATE_MANAGE_MANUAL => dualvar(2, "manual");

# Group permissions
use constant GROUPPERM_OSCAR => dualvar(0x18, "AOL Instant Messenger users");
use constant GROUPPERM_AOL => dualvar(0x04, "AOL subscribers");

# Services - deprecated, modules should no longer use these directly
use constant OSCAR_SVC_AIM => (
	host => 'login.oscar.aol.com',
	port => 5190,
	supermajor => 0x0109,
	major => 5,
	minor => 5,
	subminor => 0,
	build => 0x0E0B,
	subbuild => 0x00000104,
	clistr => "AOL Instant Messenger, version 5.5.3595/WIN32",
	hashlogin => 0,
	betainfo => "",
);
use constant OSCAR_SVC_ICQ => ( # Courtesy of SDiZ Cheng
	host => 'login.icq.com',
	port => 5190,
	supermajor => 0x010A,
	major => 5,
	minor => 0x2D,
	subminor => 0,
	build => 0xEC1,
	subbuild => 0x55,
	clistr => "ICQ Inc. - Product of ICQ (TM).2003a.5.45.1.3777.85",
	hashlogin => 1,
);	

1;
