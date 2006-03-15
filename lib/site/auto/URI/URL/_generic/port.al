# NOTE: Derived from blib\lib\URI\URL\_generic.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL::_generic;

#line 208 "blib\lib\URI\URL\_generic.pm (autosplit into blib\lib\auto/URI\URL\_generic/port.al)"
sub port {
    my $self = shift;
    my $old = $self->_netloc_elem('port', @_);
    defined($old) ? $old : $self->default_port;
}

# end of URI::URL::_generic::port
1;
