#!/usr/bin/perl
# -*- Perl -*-
#---------------------------------------------------------------------------
#  File:
#      hammernode_ip
#  Description:
#      Updates Dynamic IP address on Hammernode (hn.org) DNS servers
#
#      -You must have a dynamic DNS vanity account on Hammernode (http://hn.org)
#      -Your Hammernode account must be properly setup and configured.
#
#      -set hammernode_user=<username> in mh.private.ini
#      -set hammernode_pwd=<password> in mh.private.ini
#
#   Examples:
#
#   hammernode_ip			#Updates hammernode with your current IP address
#   hammernode_ip -update=192.168.1.1	#Updates hammernode with specified IP address
#
#   Use -update option if behind a firewall.
#
#  Author:
#      Joseph Gaston
#
#      Adapted from perl script from hn.org
#---------------------------------------------------------------------------

use strict;

BEGIN {
    ( $Pgm_Path, $Pgm_Name ) = $0 =~ /(.*)[\\\/](.+)\.?/;
    ($Pgm_Name) = $0 =~ /([^.]+)/, $Pgm_Path = '.' unless $Pgm_Name;
    eval "use lib '$Pgm_Path/../lib'";   # Use BEGIN eval to keep perl2exe happy
}

use Getopt::Long;
use vars qw(%config_parms %config_parms_startup);

&main::read_mh_opts( \%config_parms, "c:/joseph/mh/bin" );

if (  !&GetOptions( \%config_parms_startup, 'update=s', 'h', 'help' )
    or @ARGV
    or $config_parms_startup{h}
    or $config_parms_startup{help} )
{
    print <<eof;

  $Pgm_Name updates Hammernode Dynamic DNS server with your IP address.

  Usage: 
    $Pgm_Name 
    $Pgm_Name [-[h]elp]] [-update=new_ip_address]

eof

    exit;
}

my $target   = "dup.hn.org";
my $version  = "v0.22pl2";
my $username = $config_parms{hammernode_user};
my $password = $config_parms{hammernode_pwd};

if ( !$username or !$password ) {
    print("(UPDATE_IP) Failed.  No username or password specified.\n");
    exit;
}

my ( $myip, $pass, $url, $sock, @result, $result, $code );

use MIME::Base64 ();
use IO::Socket;

if ( $config_parms_startup{update} ) {  # If account in cmd line arg, compare it
    $myip = $config_parms_startup{update};
}

#$myip = "current address" if !$myip;

$pass = MIME::Base64::encode_base64("$username:$password");

if ($myip) {
    $url = "/vanity/update/?VER=1&IP=$myip";
}
else {
    $url = "/vanity/update/?VER=1";
}

$sock = new IO::Socket::INET(
    PeerAddr => "$target",
    PeerPort => 'http(80)'
);

if ( !$sock ) {
    print("(UPDATE_IP) Failed: Can`t connect to $target, port 80\n");
    exit;
}

$sock->autoflush(1);

$sock->print("GET $url HTTP/1.0\r\n");
$sock->print("User-Agent: hammenode.pl $version\r\n");
$sock->print("Host: $target\r\n");
$sock->print("Authorization: Basic $pass\r\n\r\n");

# Legacy sleep from v0.21.  May be necessary on some slow PC platforms.
# If you are having problems, try uncommenting this first.
#
sleep 3;

@result = $sock->getlines();

undef $sock;    #Close the socket

$result = join '', @result;
$result =~ m/DDNS_Response_Code=(\d+)/i;
$code = $1;
$result =~ m/.*>(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})<.*/i;
$myip = $1;

if ( $code == 101 ) {
    print("(UPDATE_IP) Success. Hammernode DNS dynamic IP set to $myip.\n");
}
elsif ( $code == 201 ) {
    print(
        "(UPDATE_IP) Failed. Previous update occured less than 300 seconds ago.\n"
    );
}
elsif ( $code == 202 ) {
    print("(UPDATE_IP) Failed. Server error.\n");
}
elsif ( $code == 203 ) {
    print("(UPDATE_IP) Failed. Account frozen by Hammernode admin.\n");
}
elsif ( $code == 204 ) {
    print("(UPDATE_IP) Failed. IP address locked by account user.\n");
}
else {
    print("(UPDATE_IP) Failed. Unknows failure. Code $code.\n");
    exit;
}
