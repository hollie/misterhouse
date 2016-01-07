
=head1 B<HVweb_Item>

=head2 SYNOPSIS

  $kitchen_light    =  new HVweb_Item('On',    'X10 G1 On');
  $kitchen_light    -> add           ('Off',   'X10 G1 Off');
  $vcr              =  new HVweb_Item('Power', 'IR 45 1 time');
  $vcr              -> add           ('Play',  'IR 46 1 time');

  set $kitchen_light 'On';
  set $vcr 'Play';

=head2 DESCRIPTION

Control Homevision controller via the Homevision web server

See Homevision documentation for complete list of command formats
Configure Homevision Webserver to report command results

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item <UnDoc>

=cut

use strict;

package HVweb_Item;

@HVweb_Item::ISA = ('Generic_Item');

sub new {
    my ( $class, $state, $cmd, $status_tag, $desc ) = @_;
    my $self = {};

    &add( $self, $state, $cmd, $status_tag, $desc );
    bless $self, $class;

    return $self;
}

sub add {
    my ( $self, $state, $cmd, $status_tag, $desc ) = @_;

    $state = lc($state);
    $self->{$state} = $cmd;    #Homevision html tag to set item state
    $self->{defined_states} .= ","
      if ( defined( $self->{defined_states} ) );    # comma delimiter
    $self->{defined_states} .=
      "$state";    #List of all states defined for this item
    $self->{state} = '?';    #Item state returned by Homeivision
    $self->{state_info} =
      '';    #Addt'l state info from Homeiviosn (Ex. X10 Brightness level)
    $self->{status_tag} = $status_tag
      if ($status_tag);    #Homevision html tag to read item state
    $self->{desc} = $desc if ($desc);    #Descriptive text for this item
}

sub default_setstate {
    my ( $self, $state ) = @_;
    my $url = "$main::config_parms{homevision_url}";
    $state = lc($state);
    my ($cmd) = $$self{$state};
    my $desc = $$self{desc};

    if ( $cmd eq '' ) {
        &main::print_log(
            "(HVWEB_ITEM) Error: Command '$desc' - '$state' not defined\n");
        return;
    }

    use LWP::UserAgent;
    my $ua = new LWP::UserAgent;
    my $req = new HTTP::Request POST => $url;
    $cmd =~ tr/?/ /;

    $req->content_type('application/x-www-form-urlencoded');
    $req->content("$cmd");

    my $res = $ua->request($req);

    if ( $res->is_success ) {
        my ($status) = $res->as_string =~ /<BR>(.*)<BR>/;
        &main::print_log("(HVWEB_ITEM) '$desc' - '$state' ($cmd) $status\n");
        $self->{state} = $state;
    }
    else {
        &main::print_log( "(HVWEB_ITEM) '$desc' - '$state' ($cmd) Error: "
              . $res->status_line
              . "\n" );
    }
    return;
}

sub set_state {
    my ( $self, $state, $state_info ) = @_;
    $self->{state} = lc($state);
    $self->{state_info} = $state_info if ($state_info);
    return;
}

sub get_state {
    my ($self) = @_;
    my $state = $self->{state};
    return $state;
}

sub list {    ### Some web functions (list_items.pl) need this routine
    my ($self) = @_;
    return $self;
}

return 1;

=back

=head2 INI PARAMETERS

Set homevision_url=<your homevision web server url> in mh.ini

=head2 AUTHOR

Joseph Gaston (gastoniere@yahoo.com)

=head2 SEE ALSO

See Homevision documentation for complete list of command formats

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

