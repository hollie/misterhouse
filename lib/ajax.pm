
=head1 B<ChangeWaiter>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

A object to hold the update waiting information

=head2 INHERITS

NONE

=head2 METHODS

=over

=cut

# Here are the ajax support functions
#

use strict;

#use diagnostics;

sub html_ajax_long_poll () {
    my ( $socket, $get_req, $get_arg, $client_number, $requestnum, $delay_passes ) = @_;

    my $waiter = new ChangeWaiter( $socket, $get_arg, $client_number, $requestnum, $delay_passes );

    ChangeChecker::addWaiter($waiter);

    return 1;
}

package ChangeWaiter;

sub new {
    my ( $class, $socket, $sub, $client_number, $requestnum, $delay_passes ) = @_;
    my $self = {};

    bless $self, $class;

    &main::print_log("ajax: creating ChangeWaiter object for socket $socket and sub $sub")
      if $main::Debug{ajax};

    $sub =~ s/^/&main::/;
    ${ $$self{waitingSocket} } = $socket;
    ${ $$self{expireTime} }    = time() + 60;
    ${ $$self{changed} }       = 0;                                                # Flag if at least on state is changed
    ${ $$self{event} }         = "&ChangeChecker::setWaiterToChanged ('$self')";
    ${ $$self{sub} }           = $sub;
    ${ $$self{checkTime} }     = 1;
    ${ $$self{passes} }        = 0;
    ${ $$self{client_number} } = $client_number;
    ${ $$self{requestnum} }    = $requestnum;
    ${ $$self{delay_passes} }  = $delay_passes;


    return $self;
}

# Function to set the changed flag
sub flagStateChange {
    ( my $self ) = @_;

    ${ $$self{changed} } = 1;
}

=item C<checkForUpdate>

Function to check for changes in the objects state on change a message is sent to the socket, the socket is closed and 1 is returned else 0 is returne

=cut

sub checkForUpdate {
    my ($self) = @_;
    my $client_number = ${$$self{client_number}};
    my $requestnum = ${$$self{requestnum}};
    my ( $port, $iaddr, $client_ip_address );
    my %HttpHeader = &::http_get_headers($client_number,$requestnum);

    if ( $main::Debug{ajax} ) {
       my $peer = ${ $$self{waitingSocket} }->peername;
       ( $port, $iaddr ) = &main::unpack_sockaddr_in($peer) if $peer;
       $client_ip_address = &main::inet_ntoa($iaddr) if $iaddr;
    }



    if ( ${ $$self{expireTime} } < time() ) {

	if ( $main::Debug{ajax} ) {
	   if ( &::http_close_socket(%HttpHeader) ) {
             &main::print_log("ajax: checkForUpdate - waiter for sub ${$$self{sub}} timed out, responding with 204, closing socket - Client: $client_ip_address Port: $port");
	    } else {
	     &main::print_log("ajax: checkForUpdate - waiter for sub ${$$self{sub}} timed out, responding with 204 - Client: $client_ip_address Port: $port");
	   }
	}
	
        # Sending a status code makes it easier to distinish No Content from a lost
        # connection on the client end.
	 my $html_head = "HTTP/1.1 204 No Content\r\n";
	 $html_head .= "Server: MisterHouse\r\n";
	 $html_head .= "Connection: close\r\n" if &::http_close_socket(%HttpHeader);
	 $html_head .= "Date: " . ::time2str(time) . "\r\n";
	 $html_head .= "\r\n";
         &::print_socket_fork( ${ $$self{waitingSocket} }, $html_head, $client_number, $requestnum, &::http_close_socket(%HttpHeader) );
        return 1;
    }

    if ( ${$$self{sub}} =~ /(.*\:\:json\(\'.*\',\'.*\',\'.*\',\'.*\')\)/ ) {  
        ${$$self{sub}} = $1.',$client_number,$requestnum )'; 
        &main::print_log ("ajax: checkForUpdate - sub updated to ${$$self{sub}}") if $main::Debug{ajax};
    }
    elsif ( ${$$self{sub}} =~ /(.*\:\:json\(\'.*\',\'.*\',\'.*\')\)/ ) {  
        ${$$self{sub}} = $1.',"",$client_number,$requestnum )';
        &main::print_log ("ajax: checkForUpdate - sub updated to ${$$self{sub}}") if $main::Debug{ajax};
    }

    my $xml = eval ${ $$self{sub} };
    if ($@) {
        &main::print_log("ajax: checkForUpdate - syntax error in sub ${$$self{sub}}\n\t$@") if $main::Debug{ajax};
        return 1;
    }

    if ($xml) {
        if ( $main::Debug{ajax} ) {
           if ( &::http_close_socket(%HttpHeader) ) {
		&main::print_log("ajax: checkForUpdate - sub: ${$$self{sub}} returned data, closing socket,  Client: $client_ip_address Port: $port");
            } else {
        	&main::print_log("ajax: checkForUpdate - sub: ${$$self{sub}} returned data, Client: $client_ip_address Port: $port");
           }
        }

        &::print_socket_fork( ${ $$self{waitingSocket} }, $xml, $client_number, $requestnum, &::http_close_socket(%HttpHeader) );
        ${ $$self{changed} } = 1;
    }
    else {
        ${ $$self{changed} } = 0;
    }
    return ${ $$self{changed} };
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.









=head1 B<ChangeChecker>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

A class wich contains the checker for update waiter

=head2 INHERITS

NONE

=head2 METHODS

=over

=item B<UnDoc>

=cut

# A class wich contains the checker for update waiter
package ChangeChecker;

my %waiters;
my $started;    # True if running already

sub startup {
    return if $started++;
    printf " - initializing state tracker ...\n";
    %waiters = ();
    &main::print_log("ajax: adding hook for checkWaiters") if $main::Debug{ajax};
    &::MainLoop_post_add_hook( \&ChangeChecker::checkWaiters, 1 );
}

sub addWaiter {
    my ($waiter) = @_;

    $waiters{$waiter} = $waiter;
    &main::print_log("ajax: addWaiter - waiter '$waiter' added") if $main::Debug{ajax};
}

sub checkWaiters {
    my ($class) = @_;
    my $delay = 250;
    my $currenttime = &main::get_tickcount;
    #my $push_flag = &::get_waiter_flags('push_flag');
    foreach my $key ( keys %waiters ) {
	my $self = $waiters{$key};
	${ $$self{passes} }++;
    	my $push_flag = 0;
    	$push_flag = 1 if ( ${ $$self{delay_passes} } && ( ${ $$self{passes} } >= ${ $$self{delay_passes} }) );
	next unless ( ( ($currenttime - ${ $$self{checkTime} }) >= $delay ) || $push_flag );
	${ $$self{checkTime} } = $currenttime; 
	#&main::print_log("waiter: checkWaiters Push flag: $push_flag checking sub sub ".${$$self{sub}} ) if $main::Debug{ajax} and $push_flag;
        if ( $waiters{$key}->checkForUpdate ) {
            # waiter can be removed
            delete $waiters{$key};
            &main::print_log("ajax: checkWaiters - waiter '$key' removed") if $main::Debug{ajax};
        }
    }
  &::set_waiter_flags('push_flag',0);
}

sub setWaiterToChanged {
    my ($hash) = @_;

    #print "Accessing hash '$hash'\n";
    $waiters{$hash}->flagStateChange;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

