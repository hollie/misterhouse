# NOTE: Derived from blib\lib\URI\URL\_generic.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL::_generic;

#line 237 "blib\lib\URI\URL\_generic.pm (autosplit into blib\lib\auto/URI\URL\_generic/epath.al)"
sub epath {
     my $self = shift;
     my $old = $self->_elem('path', @_);
     return '/' if !defined($old) || !length($old);
     return "/$old" if $old !~ m|^/| && defined $self->{'netloc'};
     $old;
}

# end of URI::URL::_generic::epath
1;
