# NOTE: Derived from blib\lib\URI\URL.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL;

#line 261 "blib\lib\URI\URL.pm (autosplit into blib\lib\auto/URI\URL/strict.al)"
sub strict
{
    return $Strict_URL unless @_;
    my $old = $Strict_URL;
    $Strict_URL = $_[0];
    $old;
}

# end of URI::URL::strict
1;
