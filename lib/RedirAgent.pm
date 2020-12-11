package RedirAgent;

require LWP::Simple;
require LWP::UserAgent;
require HTTP::Cookies;
require HTTP::Request::Common;
use LWP::UserAgent;

@ISA = qw/LWP::UserAgent/;

sub new {
    my $self = LWP::UserAgent::new(@_);
    $self;
}

sub redirect_ok {
    1;
}
