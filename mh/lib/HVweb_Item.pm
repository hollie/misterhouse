#
# HVweb_Item.pm
#
# Package to control Homevision controller via the Homevision web server
#
# Set homevision_url=<your homevision web server url> in mh.ini
#
# Create items as follows: 
#
#     $kitchen_light    =  new HVweb_Item('On','X10 G1 On','X10 G1 state level%','Main Kitchen Light');
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

@HVweb_Item::ISA = ('Generic_Item');

sub new {
    my ($class, $state, $cmd, $status_tag, $desc) = @_;
    my $self = {};

    &add($self, $state, $cmd, $status_tag, $desc);
    bless $self, $class;

    return $self;
}

sub add {
    my ($self, $state, $cmd, $status_tag, $desc) = @_;

    $state = lc($state);
    $self->{$state} = $cmd;                                #Homevision html tag to set item state
    $self->{defined_states} .= "," if ( defined($self->{defined_states}) ); # comma delimiter 
    $self->{defined_states} .= "$state";                   #List of all states defined for this item
    $self->{state}      = '?';                             #Item state returned by Homeivision
    $self->{state_info} = '';                              #Addt'l state info from Homeiviosn (Ex. X10 Brightness level)
    $self->{status_tag} = $status_tag  if ( $status_tag ); #Homevision html tag to read item state
    $self->{desc} = $desc  if ( $desc );                   #Descriptive text for this item
 }

sub default_setstate {
    my ($self, $state) = @_;
    my $url = "$main::config_parms{homevision_url}";
    $state = lc($state);
    my ($cmd) = $$self{$state};
    my $desc = $$self{desc};

    if ($cmd eq '') {
         &main::print_log ("(HVWEB_ITEM) Error: Command '$desc' - '$state' not defined\n");
         return;
    }

    use LWP::UserAgent;
    my $ua  = new LWP::UserAgent;
    my $req = new HTTP::Request POST => $url;
    $cmd =~ tr/?/ /;

    $req->content_type('application/x-www-form-urlencoded');
    $req->content("$cmd");

    my $res = $ua->request($req);

    if ($res->is_success) {
         my ($status) = $res->as_string =~ /<BR>(.*)<BR>/;
         &main::print_log ("(HVWEB_ITEM) '$desc' - '$state' ($cmd) $status\n");
         $self->{state} = $state;
    }
    else {
         &main::print_log ("(HVWEB_ITEM) '$desc' - '$state' ($cmd) Error: " . $res->status_line . "\n");
    }
return;
}

sub set_state {
    my ($self, $state, $state_info) = @_;
    $self->{state} = lc($state);
    $self->{state_info} = $state_info if ( $state_info );
return;
}

sub get_state {
    my ($self) = @_;
    my $state = $self->{state};
return $state;
}


sub list {       ### Some web functions (list_items.pl) need this routine
    my ($self) = @_;
    return $self; 
}

return 1;

