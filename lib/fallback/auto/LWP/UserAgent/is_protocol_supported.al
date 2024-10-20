# NOTE: Derived from blib\lib\LWP\UserAgent.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package LWP::UserAgent;

#line 519 "blib\lib\LWP\UserAgent.pm (autosplit into blib\lib\auto/LWP\UserAgent/is_protocol_supported.al)"
sub is_protocol_supported
{
    my($self, $scheme) = @_;
    if (ref $scheme) {
	# assume we got a reference to an URI::URL object
	$scheme = $scheme->abs->scheme;
    } else {
	Carp::croak("Illeal scheme '$scheme' passed to is_protocol_supported")
	    if $scheme =~ /\W/;
	$scheme = lc $scheme;
    }
    return LWP::Protocol::implementor($scheme);
}

# end of LWP::UserAgent::is_protocol_supported
1;
