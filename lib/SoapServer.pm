
=head1 B<SoapServer>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This is the SOAP Transport for misterhouse.  It just subclasses the
SOAP::Transport::HTTP::CGI class from SOAP::Lite.  The major difference
being that it reads from passed variables and returns the results
instead of using STDIN and STDOUT.

Requires:

  SOAP::Lite - available from CPAN
  http://search.cpan.org/~byrne/SOAP-Lite-0.69/lib/OldDocs/SOAP/Lite.pm

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

package SoapServer;

use SOAP::Transport::HTTP;

use vars qw(@ISA);
@ISA = qw(SOAP::Transport::HTTP::CGI);

=item C<handle>

The handle method is the only thing that needs to be changed from the
standard CGI transport class.  Just get the request from passed variables
and return the results.  Everything else is almost identical to the parent 
class

=cut

sub handle {
    my $self    = shift;
    my $content = shift;
    my $headers = shift;

    my $results = '';

    my $length =
      $headers->{'Content-Length'} || $headers->{'Content-length'} || 0;

    if ( !$length ) {
        $self->response( HTTP::Response->new(411) )    # LENGTH REQUIRED
    }
    elsif ( defined $SOAP::Constants::MAX_CONTENT_SIZE
        && $length > $SOAP::Constants::MAX_CONTENT_SIZE )
    {
        $self->response( HTTP::Response->new(413) )   # REQUEST ENTITY TOO LARGE
    }
    else {
        # This appears to be broken.  MS .Net by default trys to use the HTTP 1.1 Continue header
        # and SOAP::Lite seems to support it but I don't think we can keep the socket open in misterhouse.
        # I think this should probably return a 417 Status instead of the 100.  .Net always complains that
        # connection was unexpectedly closed.
        if ( $headers->{'Expect'} =~ /\b100-Continue\b/i ) {
            return "HTTP/1.1 100 Continue\r\n\r\n";
        }

        # stole this line from the http_server.pl file.  Just need to break the request down
        # I think SOAP will almost always be a POST request but better be sure
        my ( $req_typ, $uri, $get_arg ) =
          $headers->{'request'} =~ m|^(GET\|POST) (\/[^ \?]*)\??(\S+)? HTTP|;

        # Create  a new HTTP::Request to pass to the SOAP::Transport::HTTP::Server class
        $self->request(
            HTTP::Request->new(
                $req_typ, $uri,
                HTTP::Headers->new(
                    map {
                            (m/SOAPACTION/i)
                          ? ('SOAPAction')
                          : ($_) => $headers->{$_}
                    } keys %$headers
                ),
                $content
            )
        );
        $self->SOAP::Transport::HTTP::Server::handle;
    }

    my $crlf = "\015\012";
    my $code = $self->response->code;

    $results .=
        "HTTP/1.0 $code "
      . HTTP::Status::status_message($code)
      . $crlf
      . $self->response->headers_as_string($crlf)
      . $crlf
      . $self->response->content;
    return $results;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Mike Wiebke mw65@yahoo.com

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

