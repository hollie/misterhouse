
=head1 B<SMS_Item>

=head2 SYNOPSIS

  use SMS_Item;

To create the object use:

  new SMS_Item(<IntlCountryCode>, <MobileNumber>);

  $SMS_StuMobile = new SMS_Item(44, "07976123456");

And to send a message use the line:

  $SMS_StuMobile->send("Mum called your home at 13:15");

=head2 DESCRIPTION

SMS module for Misterhouse
Uses the form at www.smsboy.com to send an SMS message to your mobile.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package SMS_Item;

use LWP::UserAgent;

my $smsurl = "http://www.smsboy.com/cgi-bin/sendsms9.pl";

sub new {

    my ($class) = shift(@_);
    my ($self)  = {};

    $$self{country} = shift(@_);
    $$self{number}  = shift(@_);

    bless $self, $class;
    return $self;
}

sub send {
    my ( $self, $message ) = @_;

    my $ua = new LWP::UserAgent;
    my $req = new HTTP::Request POST => $smsurl;
    $req->content_type('application/x-www-form-urlencoded');
    $req->content("C=$$self{country}&N=$$self{number}&M=$message -- ");

    my $res = $ua->request($req);
}

sub set {
    my ( $self, $IntlCode, $Number ) = @_;
    $$self{country} = $IntlCode;
    $$self{number}  = $Number;
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Stuart Grimshaw <stuart@smgsystems.co.uk>

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

