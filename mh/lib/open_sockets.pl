#---------------------------------------------------------------------------
#  File:
#      open_sockets.pl       
#  Description:
#      perl functions for socket functions
#  Author:
#      Bruce Winter    winter@isl.net  http://www.isl.net/~winter
#  Latest version:
#      http://www.isl.net/~winter/house/programs
#  Change log:
#    11/09/96  Created.
#---------------------------------------------------------------------------

package open_sockets;

# Should add use strict or use a cleaner socket package (use net?)

sub main::open_client_socket {
    my(%parms) = @_;

    $handle = 'main::' . $parms{'handle'};
    $port = $parms{'port'};
    $addr_server = $parms{'server'};
#   $addr_client = $parms{'client'};  not needed ??

    $| = 1;
    $AF_INET = 2;
    $SOCK_STREAM = 1;
#   $SIG{'INT'} = 'dokill';
    $sockaddr = 'S n a4 x8';
    ($name, $aliases, $proto) = getprotobyname('tcp');
#   print "name=$name aliases=$aliases proto=$proto\n";
#   ($name, $aliases, $proto) = ('tcp', 'TCP', 6);

    if ($addr_server =~ /^[\d\.]+$/) {
	$thataddr = pack ('C4', split (/\./, $addr_server));
    }
    else {
	($name, $aliases, $type, $len, $thataddr) = gethostbyname($addr_server);
    }
#   $thisaddr = pack ('C4', split (/\./, $addr_client));

#return 1;

    $that = pack($sockaddr, $AF_INET, $port, $thataddr);
    $this = pack($sockaddr, $AF_INET, 0, $thisaddr);

    socket($handle, $AF_INET, $SOCK_STREAM, $proto) or return "Died making socket: $!";
    bind($handle, $this) or return "Died binding socket: $!";
#   print "Connecting to socket\n";            # This is where win95 autodial kicks in
    connect($handle, $that) or return "Died connecting to socket: $!";
    select($handle); $| = 1; select(main::STDOUT);

    return 0;                 # rc=0 means we opened the socket OK.

}

sub main::open_server_socket {

    my(%parms) = @_;

    $socket = 'main::' . $parms{'socket'};
    $port = $parms{'port'};

    $AF_INET = 2;
    $SOCK_STREAM = 1;
    $sockaddr = 'S n a4 x8';

    ($name, $aliases, $proto) = getprotobyname('tcp');
    if ($port !~ /^\d+$/) {
	($name, $aliases, $port) = getservbyport($port, 'tcp');
    }
    $this = pack($sockaddr, $AF_INET, $port, "\0\0\0\0");
    
    socket($socket, $AF_INET, $SOCK_STREAM, $proto) || return "Socket error on port $port: $!";
    bind($socket,$this) || return "Bind error on socket port $port: $!";
    listen($socket,5) || return "Connect error on socket port $port: $!";
    select($socket); $| = 1; select(main::STDOUT);
    return 0;			# success
    
#   ($af,$port,$inetaddr) = unpack($sockaddr,$addr);
#   @inetaddr = unpack('C4',$inetaddr);
#   print "$pgm: af=$af port=$port addr=@inetaddr\n";
}

sub main::write_socket {
    my($server, $parms, $data) = @_;
 print "db write_socket called with server=$server\n";
    my @caller = caller;
    print "called from @caller\n";

    if ($server eq 'speak' or $server eq 'play') {
                                                 # Use localhost if we can so we can run while DUN is running
	$server_host = 'localhost'; # We should read the parms file for this
	$port = 58070;
#	$data = join(' ', 'speak', $data);
	$data = "$server $parms\n$data";
    }
    elsif ($server eq 'serial') {
                                                 # Use localhost if we can so we can run while DUN is running
	$server_host = 'localhost';
	$port = 58071;
	print "Sending serial data:$data\n" if $main::opt_verbose;
    }
    elsif ($server eq 'house_menu') {
                                                 # Use localhost if we can so we can run while DUN is running
	$server_host = 'localhost';
	$port = 58072;
	print "Sending serial data:$data\n";
    }
    else {
	print "Unrecognized server command: $server\n";
	return 1;
    }
#print  "$main::date_now $main::time_now opening $server socket for write\n";
#print main::SERIALLOG "$main::date_now $main::time_now opening $server socket for write\n";

    $handle = "CLIENT";
    $socket_error = &main::open_client_socket('handle' => $handle, 'port' => $port, 'server' => $server_host);
#return 1;

    unless ($socket_error) {
	print "Calling server=$server server_host=$server_host data=$data\n" if $main::opt_verbose;
#print "  write_data=$data";
	print main::CLIENT $data;
#print "  ... data written, closing socket ";
#	print "Shutting down sends and sleeping a bit\n" if $server eq 'serial';
#	shutdown(main::CLIENT, 1);  # "how":  0=no more receives, 1=sends, 2=both
#	sleep 1 if $server eq 'serial';
#	print "Waiting for response\n" if $main::opt_verbose;
##	while ($response = <main::CLIENT>) {
##	    print "echo=$response" if $main::opt_debug;
##	}
#	print "Closeing socket\n" if $server eq 'serial';
	close main::CLIENT;
#print "  ... socket closed\n";
#	print "all done ... returning\n" if $server eq 'serial';
	return 0;
    }
    else {
	print "Error opening socket to server=$server server_host=$server_host port=$port: $socket_error\n";
	return 1;
    }
}    


sub dokill {
    kill 9,$child if $child;
}


1;
