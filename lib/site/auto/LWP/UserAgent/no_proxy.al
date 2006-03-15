# NOTE: Derived from blib\lib\LWP\UserAgent.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package LWP::UserAgent;

#line 667 "blib\lib\LWP\UserAgent.pm (autosplit into blib\lib\auto/LWP\UserAgent/no_proxy.al)"
sub no_proxy {
    my($self, @no) = @_;
    if (@no) {
	push(@{ $self->{'no_proxy'} }, @no);
    }
    else {
	$self->{'no_proxy'} = [];
    }
}

# end of LWP::UserAgent::no_proxy
1;
