# NOTE: Derived from blib\lib\URI\URL\_generic.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL::_generic;

#line 305 "blib\lib\URI\URL\_generic.pm (autosplit into blib\lib\auto/URI\URL\_generic/frag.al)"
# No efrag method because the fragment is always stored unescaped
sub frag     { shift->_elem('frag', @_); }

# end of URI::URL::_generic::frag
1;
