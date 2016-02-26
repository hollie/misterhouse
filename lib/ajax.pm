
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
    my ( $socket, $get_req, $get_arg ) = @_;

    my $waiter = new ChangeWaiter( $socket, $get_arg );

    ChangeChecker::addWaiter($waiter);

    #ChangeChecker::checkWaiters();

    return 1;
}

package ChangeWaiter;

sub new {
    my ( $class, $socket, $sub ) = @_;
    my $self = {};

    bless $self, $class;

    &main::print_log(
        "creating ChangeWaiter object for socket $socket and sub $sub")
      if $main::Debug{ajax};

    $sub =~ s/^/&main::/;
    ${ $$self{waitingSocket} } = $socket;
    ${ $$self{expireTime} }    = time() + 60;
    ${ $$self{changed} } = 0;    # Flag if at least on state is changed
    ${ $$self{event} } = "&ChangeChecker::setWaiterToChanged ('$self')";
    ${ $$self{sub} }   = $sub;

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

    if ( ${ $$self{expireTime} } < time() ) {
        &main::print_log(
            "checkForUpdate waiter for sub ${$$self{sub}} timed out, closing socket"
        ) if $main::Debug{ajax};

        # Sending a status code makes it easier to distinish No Content from a lost
        # connection on the client end.
        &::print_socket_fork( ${ $$self{waitingSocket} },
            "HTTP/1.0 204 No Content\n\n" );
        ${ $$self{waitingSocket} }->close;
        return 1;
    }

    my $xml = eval ${ $$self{sub} };
    if ($@) {
        &main::print_log(
            "checkForUpdate syntax error in sub ${$$self{sub}}\n\t$@")
          if $main::Debug{ajax};
        return 1;
    }

    if ($xml) {
        &main::print_log("checkForUpdate sub ${$$self{sub}} returned $xml")
          if $main::Debug{ajax};
        &::print_socket_fork( ${ $$self{waitingSocket} }, $xml );
        ${ $$self{waitingSocket} }->close;
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
    &main::print_log("adding hook for checkWaiters") if $main::Debug{ajax};
    &::MainLoop_post_add_hook( \&ChangeChecker::checkWaiters, 1 );
}

sub addWaiter {
    my ($waiter) = @_;

    $waiters{$waiter} = $waiter;
    &main::print_log("waiter '$waiter' added") if $main::Debug{ajax};
}

sub checkWaiters {
    my ($class) = @_;

    foreach my $key ( keys %waiters ) {
        if ( $waiters{$key}->checkForUpdate ) {

            # waiter can be removed
            delete $waiters{$key};
            &main::print_log("waiter '$key' removed") if $main::Debug{ajax};
        }
    }
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

