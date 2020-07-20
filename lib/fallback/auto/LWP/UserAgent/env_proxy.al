# NOTE: Derived from blib\lib\LWP\UserAgent.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package LWP::UserAgent;

#line 642 "blib\lib\LWP\UserAgent.pm (autosplit into blib\lib\auto/LWP\UserAgent/env_proxy.al)"
sub env_proxy {
    my ($self) = @_;
    my($k,$v);
    while(($k, $v) = each %ENV) {
	$k = lc($k);
	next unless $k =~ /^(.*)_proxy$/;
	$k = $1;
	if ($k eq 'no') {
	    $self->no_proxy(split(/\s*,\s*/, $v));
	}
	else {
	    $self->proxy($k, $v);
	}
    }
}

# end of LWP::UserAgent::env_proxy
1;
