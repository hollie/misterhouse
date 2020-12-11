#!/usr/bin/perl -w
# mhmms-server.pl - a server that reads from
# the local machine and writes results to a client
#
# Pete Flaherty - pj@cape.com
# V0.05  - initial test
# V0.06  - fixed search
# V0.10  - made search skip proc dev spool dirs
# V0.11  - fixup to make warnings go away (scalar evals)

use strict;
use IO::Socket;
use Sys::Hostname;

my $mru = "0.11, 6 Apr 2005";

our $search_path  = '/home/pjf/music';
our @search_types = qw(mp3 mpg ogg mpeg avi vob mov mp4 rma wav asf wmv wma);
our $search_this  = $search_path;
our ( @files, @dirs );

# You may need to change these depending on your config
my $HostName = hostname();
my $HostIP   = gethostbyname($HostName);
my $IP       = inet_ntoa($HostIP);

#my $IP       = '192.168.1.1";

print "
Multimedia search service for remote machines
Ver $mru 

Search for files of type(s):\n";
for my $file ( sort @search_types ) {
    print " $file";
}
print "\n\nThe local Host is '$HostName' with an ip of '$IP' 
Server Startup FAILED \r";

my $sock = new IO::Socket::INET(
    LocalHost => $IP,
    LocalPort => 6790,
    Proto     => 'tcp',
    Listen    => SOMAXCONN,
    Reuse     => 1
);

$sock or die "no socket :$!";
STDOUT->autoflush(1);
my ( $new_sock, $cmd );
my $EOL = "\015\012";
print "Server is up and ready  \n";

while ( $new_sock = $sock->accept() ) {

    # got a client connection, so read
    # line by line until end-of-file
    while ( defined( $cmd = <$new_sock> ) ) {

        # respond to client request using
        # a cleverly disgned switch
        # statement

        foreach ($cmd) {
            tr/A-Z/a-z/ for $cmd;
            my $args;
            my $buf;

            $cmd = substr( $cmd, 0, length($cmd) - 2 );
            ( $buf, $args ) = split( / /, $cmd );
            ##$buf = $cmd unless $args;
            #print ">$buf<, $args\n";

            if ( $buf eq 'hello' ) {
                print( $new_sock "Hi\n" );
            }

            elsif ( $buf eq 'host' ) {
                print( $new_sock hostname(), "\n" );
            }

            elsif ( $buf eq 'search' ) {

                # be sure we start with cleared arrays
                print "Searching $args\n";
                @files = ();
                @dirs  = ();

                # print "Searching $args \n";
                $search_this = $search_path;
                $search_this = $args if ($args);
                @dirs        = $search_this;

                &search();

                print( $new_sock "DONE\n" );

                @files = ();
                @dirs  = ();
                print "Done\n";
                $buf = '';
            }

            elsif ( $buf eq 'date' ) {
                print( $new_sock scalar(localtime), "\n" );
            }

            elsif ( $buf eq 'quit' ) {
                print( $new_sock "Bye\n" );
                close $new_sock;
                exit;
            }

            # default case:
            else {
                print $new_sock "Command Not recognized\n";
            }

        }

    }
    close $new_sock;
}

sub search() {

    # this is where we search teh local drive for media
    # optionally we could accept a starting path to dive into

    if ( -f $search_this ) {
        print "Can Not Find \'$search_this'\n";
        return " No Directory named $search_this";
    }
    chdir($search_this);
    &recurse_dirs;
    return;
}

sub recurse_dirs() {
    for my $dirs (@dirs) {
        $search_this = "$dirs";
        my $last_search = $search_this;
        my ( $dir, $dirNm ) = split( /\/(\w*)\z/, $dirs );
        $dir   = '' if ( !$dir );
        $dirNm = '' if ( !$dirNm );

        #print "DIR >> |$dirNm| \n";
        if (    $dirNm ne ''
            and $dirNm ne 'proc'
            and $dirNm ne 'spool'
            and $dirNm ne 'dev' )
        {
            &get_dir;
            &ret_types;
        }
        $search_this = $last_search;
    }
}

sub get_dir() {

    # get the directory listing
    opendir( DIRHANDLE, $search_this );
    @files = readdir DIRHANDLE;
    closedir(DIRHANDLE);
    return;
}

sub ret_types() {

    #now sort through it and return valid types
    for my $file ( sort @files ) {
        next if ( $file =~ /^\./ );    #no dor dirs
        my $name = "";
        my $extn = "dir";
        ( $name, $extn ) = split( /\./, $file );

        if ($extn) {
            ##print "extension $extn\n";
            # and save off the sub dirs for later
            for my $match (@search_types) {
                if ( $extn eq $match ) {
                    print $new_sock "$search_this//$file \n";
                }
            }
        }
        else {
            # push the sub dirs onto the recurse stack
            push @dirs, "$search_this/$name";
        }
    }
    return;
}
