#
# HVweb_Item.pm
#
# Package to control Homevision controller via the Homevision web server
#
# Set homevision_url=<your homevision web server url> in mh.ini
#
# Create items as follows: 
#
#     $kitchen_light    =  new HVweb_Item('On',    'X10 G1 On');
#     $kitchen_light    -> add           ('Off',   'X10 G1 Off');
#     $vcr              =  new HVweb_Item('Power', 'IR 45 1 time');
#     $vcr              -> add           ('Play',  'IR 46 1 time');
#
# See Homevision documentation for complete list of command formats
# Configure Homevision Webserver to report command results
#
# Operate devices as follows:
#
#     set $kitchen_light 'On';
#     set $vcr 'Play';
#
# By Joseph Gaston (gastoniere@yahoo.com)
#
#

use strict;

package HVweb_Item;

@Serial_Item::ISA = ('Generic_Item');


sub new {
    my ($class, $state, $cmd) = @_;
    my $self = {};

    &add($self, $state, $cmd);
    bless $self, $class;

    return $self;
}

sub add {
    my ($self, $state, $cmd) = @_;

    $self->{$state} = $cmd;
}

sub set {
    my ($self, $state) = @_;
    my $url = "$main::config_parms{homevision_url}";
    my ($cmd) = $$self{$state};
    use LWP::UserAgent;
    my $ua  = new LWP::UserAgent;
    my $req = new HTTP::Request POST => $url;

    $req->content_type('application/x-www-form-urlencoded');
    $req->content("$cmd");

    my $res = $ua->request($req);

    if ($res->is_success) {
        my ($status) = $res->as_string =~ /<BR>(.*)<BR>/;
        &main::print_log ("(HVWEB_ITEM) Homevision '$cmd' $status\n");
    }
    else {
        &main::print_log ("(HVWEB_ITEM) Homevision '$cmd' Error: " .
                           $res->status_line . "\n");
    }
    return;
}

return 1;
