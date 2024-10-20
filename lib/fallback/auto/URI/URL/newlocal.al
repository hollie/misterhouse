# NOTE: Derived from blib\lib\URI\URL.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL;

#line 254 "blib\lib\URI\URL.pm (autosplit into blib\lib\auto/URI\URL/newlocal.al)"
sub newlocal
{
    require URI::URL::file;
    my $class = shift;
    URI::URL::file->newlocal(@_);  # pass it on the the file class
}

# end of URI::URL::newlocal
1;
