# NOTE: Derived from blib\lib\URI\URL\_generic.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL::_generic;

#line 271 "blib\lib\URI\URL\_generic.pm (autosplit into blib\lib\auto/URI\URL\_generic/params.al)"
sub params {
    my $self = shift;
    my $old = $self->_elem('params', map {uri_escape($_,$URI::URL::reserved_no_form)} @_);
    return uri_unescape($old) if defined $old;
    undef;
}

# end of URI::URL::_generic::params
1;
