# NOTE: Derived from blib\lib\URI\URL.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL;

#line 312 "blib\lib\URI\URL.pm (autosplit into blib\lib\auto/URI\URL/crack.al)"
sub crack
{
    # should be overridden by subclasses
    my $self = shift;
    ($self->scheme,  # 0: scheme
     undef,          # 1: user
     undef,          # 2: passwd
     undef,          # 3: host
     undef,          # 4: port
     undef,          # 5: path
     undef,          # 6: params
     undef,          # 7: query
     undef           # 8: fragment
    )
}

# end of URI::URL::crack
1;
