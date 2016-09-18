
# This code is called by mh/lib/http_server.pl to do a simulated fork
# on socket write on windows systems.
# Yucky stuff, but better than no fork at all.

# Magic simulated fork using copied file handles from
#  Example: 7.22 of "Win32 Perl Scripting: Administrators Handbook" by Dave Roth
#  Published by New Riders Publishing  ISBN # 1-57870-215-1

my ( $Pgm_Path, $Pgm_Name ) = $0 =~ /(.*)[\\\/](.*)\.?/;
$Pgm_Path = '.' unless $Pgm_Path;

require "$Pgm_Path/../lib/handy_utilities.pl";
use strict;
use IO::Socket;

# Use a crude lock file to avoid 2 processes printing at once
#  - it seems somehow STDOUT is related between 2 forks :(
#  - Dang, seems this does not help.  Must avoid parallel
#    forks within mh :(
#my $lock_file = "$Pgm_Path/../data/http_fork.lock";
#while (-e $lock_file) {
#    select undef, undef, undef, 0.2;
#}
#open LOCK, ">$lock_file";
#print LOCK "hi";

my $file = shift @ARGV;
my $html = &file_read($file);

unlink $file;
my $socket_handle = fileno(STDOUT);

#my $l = length $html;
#print STDERR "dbx l=$l sh=$socket_handle\n";

if ( my $socket = IO::Socket::INET->new_from_fd( $socket_handle, "+>" ) ) {
    $socket->send($html);
    $socket->close();
}

#close LOCK;
#unlink $lock_file;
