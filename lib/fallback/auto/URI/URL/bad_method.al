# NOTE: Derived from blib\lib\URI\URL.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL;

#line 348 "blib\lib\URI\URL.pm (autosplit into blib\lib\auto/URI\URL/bad_method.al)"
# This is set up as an alias for various methods
sub bad_method {
    my $self = shift;
    my $scheme = $self->scheme;
    Carp::croak("Illegal method called for $scheme: URL")
	if $Strict_URL;
    # Carp::carp("Illegal method called for $scheme: URL")
    #     if $^W;
    undef;
}

# end of URI::URL::bad_method
1;
