# NOTE: Derived from blib\lib\URI\URL.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL;

#line 330 "blib\lib\URI\URL.pm (autosplit into blib\lib\auto/URI\URL/abs.al)"
# These are overridden by _generic (this is just a noop for those schemes that
# do not wish to be a subclass of URI::URL::_generic)
sub abs { shift->clone; }
# end of URI::URL::abs
1;
