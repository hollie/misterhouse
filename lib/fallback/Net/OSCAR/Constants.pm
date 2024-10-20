=pod

Net::OSCAR::Constants -- internal Net::OSCAR constants

=cut

package Net::OSCAR::Constants;

$VERSION = '1.925';
$REVISION = '$Revision: 1.11 $';

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Scalar::Util qw(dualvar);
use Net::OSCAR::TLV;
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	FLAP_CHAN_NEWCONN FLAP_CHAN_SNAC FLAP_CHAN_ERR FLAP_CHAN_CLOSE
	CONNTYPE_LOGIN CONNTYPE_BOS CONNTYPE_ADMIN CONNTYPE_CHAT CONNTYPE_CHATNAV CONNTYPE_ICON CONNTYPE_DIRECT_IN CONNTYPE_DIRECT_OUT CONNTYPE_SERVER
	OSCAR_CAPS OSCAR_CAPS_INVERSE OSCAR_CAPS_SHORT_INVERSE OSCAR_TOOLDATA
	GROUP_PERMIT GROUP_DENY BUDTYPES ERRORS

	ICQ_META_INFO ICQ_META_INFO_INVERSE
);


use constant FLAP_CHAN_NEWCONN => dualvar(0x01, "new connection");
use constant FLAP_CHAN_SNAC => dualvar(0x02, "SNAC");
use constant FLAP_CHAN_ERR => dualvar(0x03, "error");
use constant FLAP_CHAN_CLOSE => dualvar(0x04, "close connection");

use constant CONNTYPE_LOGIN => dualvar(0, "login service");
use constant CONNTYPE_BOS => dualvar(0x2, "basic OSCAR services");
use constant CONNTYPE_ADMIN => dualvar(0x7, "administrative service");
use constant CONNTYPE_CHAT => dualvar(0xE, "chat connection");
use constant CONNTYPE_CHATNAV => dualvar(0xD, "chat navigator");
use constant CONNTYPE_ICON => dualvar(0x10, "icon service");
use constant CONNTYPE_DIRECT_IN => dualvar(0xfe, "direct connect listener");
use constant CONNTYPE_DIRECT_OUT => dualvar(0xff, "direct connect connection");
use constant CONNTYPE_SERVER => dualvar(0xfd, "OSCAR server");

use constant GROUP_PERMIT => 0x0002;
use constant GROUP_DENY   => 0x0003;

use constant OSCAR_CAPS => {
	chat => {description => "chatrooms", value => pack("C*", map{hex($_)} split(/[ \t\n]+/,
		"0x74 0x8F 0x24 0x20 0x62 0x87 0x11 0xD1 0x82 0x22 0x44 0x45 0x53 0x54 0x00 0x00"))},
	interoperate => {description => "ICQ/AIM interoperation", value => pack("C*", map{hex($_)} split(/[ \t\n]+/,
		"0x09 0x46 0x13 0x4d 0x4c 0x7f 0x11 0xd1 0x82 0x22 0x44 0x45 0x53 0x54 0x00 0x00"))},
	extstatus => {description => "iChat extended status messages", value => pack("C*", map{hex($_)} split(/[ \t\n]+/,
		"0x09 0x46 0x00 0x00 0x4c 0x7f 0x11 0xd1 0x82 0x22 0x44 0x45 0x53 0x54 0x00 0x00"))},
	buddyicon => {description => "buddy icons", value => pack("C*", map{hex($_)} split(/[ \t\n]+/,
		"0x09 0x46 0x13 0x46 0x4c 0x7f 0x11 0xd1 0x82 0x22 0x44 0x45 0x53 0x54 0x00 0x00"))},
	fileshare => {description => "file sharing", value => pack("C*", map{hex($_)} split(/[ \t\n]+/,
		"0x09 0x46 0x13 0x48 0x4c 0x7f 0x11 0xd1 0x82 0x22 0x44 0x45 0x53 0x54 0x00 0x00"))},
	filexfer => {description => "file transfers", value => pack("C*", map{hex($_)} split(/[ \t\n]+/,
		"0x09 0x46 0x13 0x43 0x4c 0x7f 0x11 0xd1 0x82 0x22 0x44 0x45 0x53 0x54 0x00 0x00"))},
        secureim => {description => "encrypted IM", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x00, 0x01, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	hiptop => {description => "hiptop", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x23, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	voice => {description => "voice chat", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x41, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	icq => {description => "EveryBuddy ICQ support", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x44, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	directim => {description => "direct IM", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x45, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	addins => {description => "add-ins", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x47, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	icqrelay => {description => "ICQ server relay", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x49, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	games => {description => "games", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x4a, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	games2 => {description => "games 2", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x4a, 0x4c, 0x7f, 0x11, 0xd1, 0x22, 0x82, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	sendlist => {description => "buddy list sending", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x4b, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	icqutf8 => {description => "ICQ UTF-8", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09, 0x46, 0x13, 0x4e, 0x4c, 0x7f, 0x11, 0xd1, 0x82, 0x22, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00"))},
	icqutf8old => {description => "old ICQ UTF-8", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x2e, 0x7a, 0x64, 0x75, 0xfa, 0xdf, 0x4d, 0xc8, 0x88, 0x6f, 0xea, 0x35, 0x95, 0xfd, 0xb6, 0xdf"))},
	icqrtf => {description => "ICQ RTF", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x97, 0xb1, 0x27, 0x51, 0x24, 0x3c, 0x43, 0x34, 0xad, 0x22, 0xd6, 0xab, 0xf7, 0x3f, 0x14, 0x92"))},
	apinfo => {description => "AP info", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0xaa, 0x4a, 0x32, 0xb5, 0xf8, 0x84, 0x48, 0xc6, 0xa3, 0xd7, 0x8c, 0x50, 0x97, 0x19, 0xfd, 0x5b"))},
	trilliancrypt => {description => "Trillian encryption", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0xf2, 0xe7, 0xc7, 0xf4, 0xfe, 0xad, 0x4d, 0xfb, 0xb2, 0x35, 0x36, 0x79, 0x8b, 0xdf, 0x00, 0x00"))},
	secureim => {description => "SecureIM encryption", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09 0x46 0x01 0xff 0x4c 0x7f 0x11 0xd1 0x82 0x22 0x44 0x45 0x53 0x54 0x00 0x00"))},
	video => {description => "A/V chat", value => pack("C*", map{hex($_)} split(/[ \t\n,]+/,
		"0x09 0x46 0x01 0x05 0x4c 0x7f 0x11 0xd1 0x82 0x22 0x44 0x45 0x53 0x54 0x00 0x00"))},
};
use constant OSCAR_CAPS_INVERSE => { map { OSCAR_CAPS()->{$_}->{value} => $_ } keys %{OSCAR_CAPS()} };
use constant OSCAR_CAPS_SHORT_INVERSE => { map { substr(OSCAR_CAPS()->{$_}->{value}, 2, 2) => $_ } keys %{OSCAR_CAPS()} };

use constant OSCAR_TOOLDATA => tlv(
	0x0001 => {version => 0x0004, toolid => 0x0110, toolversion => 0x08E5},
	0x0013 => {version => 0x0003, toolid => 0x0110, toolversion => 0x08E5},
	0x0002 => {version => 0x0001, toolid => 0x0110, toolversion => 0x08E5},
	0x0003 => {version => 0x0001, toolid => 0x0110, toolversion => 0x08E5},
	0x0004 => {version => 0x0001, toolid => 0x0110, toolversion => 0x08E5},
	0x0005 => {version => 0x0001, toolid => 0x0001, toolversion => 0x0001, nobos => 1},
	0x0006 => {version => 0x0001, toolid => 0x0110, toolversion => 0x08E5},
	0x0007 => {version => 0x0001, toolid => 0x0010, toolversion => 0x08E5, nobos => 1},
	0x0008 => {version => 0x0001, toolid => 0x0104, toolversion => 0x0001},
	0x0009 => {version => 0x0001, toolid => 0x0110, toolversion => 0x08E5},
	0x000A => {version => 0x0001, toolid => 0x0110, toolversion => 0x08E5},
	0x000B => {version => 0x0001, toolid => 0x0110, toolversion => 0x08E5},
	0x000C => {version => 0x0001, toolid => 0x0104, toolversion => 0x0001, nobos => 1},
	0x000D => {version => 0x0001, toolid => 0x0010, toolversion => 0x08E5, nobos => 1},
	0x000E => {version => 0x0001, toolid => 0x0010, toolversion => 0x08E5, nobos => 1},
	0x000F => {version => 0x0001, toolid => 0x0010, toolversion => 0x08E5, nobos => 1},
	0x0010 => {version => 0x0001, toolid => 0x0010, toolversion => 0x08E5, nobos => 1},
	0x0015 => {version => 0x0001, toolid => 0x0110, toolversion => 0x047C, nobos => 1},
	0x0017 => {version => 0x0000, toolid => 0x0000, toolversion => 0x0000, nobos => 1},
	0x0018 => {version => 0x0001, toolid => 0x0010, toolversion => 0x08E5, nobos => 1},
	0xFFFF => {version => 0x0000, toolid => 0x0000, toolversion => 0x0000, nobos => 1},
);

use constant BUDTYPES => ("buddy", "group", "permit entry", "deny entry", "visibility/misc. data", "presence", undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, "buddy icon data");

use constant ERRORS => split(/\n/, <<EOF);
Invalid error
Invalid SNAC
Sending too fast to host
Sending too fast to client
%s is not logged in, so the attempted operation (sending an IM, getting user information) was unsuccessful
Service unavailable
Service not defined
Obsolete SNAC
Not supported by host
Not supported by client
Refused by client
Reply too big
Responses lost
Request denied
Busted SNAC payload
Insufficient rights
%s is in your permit or deny list
Too evil (sender)
Too evil (receiver)
User temporarily unavailable
No match
List overflow
Request ambiguous
Queue full
Not while on AOL
Unknown error 25
Unknown error 26
Unknown error 27
Unknown error 28
There have been too many recent signons from this address.  Please wait a few minutes and try again.
EOF


use constant ICQ_META_INFO => {
	basic => 200,
	office => 210,
	background => 220,
	notes => 230,
	email => 235,
	interests => 240,
	affiliations => 250,
	homepage => 270
};
use constant ICQ_META_INFO_INVERSE => { map { ICQ_META_INFO()->{$_} => $_ } keys %{ICQ_META_INFO()} };

1;
