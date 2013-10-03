#!/usr/bin/perl

use IO::Socket;
use Getopt::Long;

$MH_ADDRESS = '192.168.0.51';
$MH_PORT = '5252';
$username = 'mythtv_mh';
$password = 'mythtv_mh';

GetOptions("h" => \$help, "c=s" => \$chanid, "s=s" => \$starttime, "e=s" => \$endtime, "t=s" => \$title, "st=s" => \$subtitle, "d=s" => \$description );


# Try to create a TCP socket to Misterhouse to establish communications with MisterHouse.
$remote = IO::Socket::INET->new(Proto => "tcp", PeerAddr => "$MH_ADDRESS", PeerPort => "$MH_PORT",)
	or die "cannot connect to misterhouse on port $MH_PORT at $MH_ADDRESS";

# Do a simple login to Misterhouse.  Not really needed if you are behind a firewall but just in case you are not
# it is included.  Keep in mind this is all plain text so if you are worried about that you should be aware.
print $remote "Login: $username\n";
print $remote "Secret: $password\n";

print $remote "chanid: $chanid\n";
print $remote "starttime: $starttime\n";
print $remote "endtime: $endtime\n";
print $remote "title: $title\n";
print $remote "subtitle: $subtitle\n";
print $remote "description: $description\n";
print $remote ":done:\n";
 
close($remote);

system qq [echo $chanid,$starttime,$endtime,$title,$subtitle,$description >> /tmp/mynotify.txt];
