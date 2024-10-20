# NOTE: Derived from blib\lib\URI\URL\file.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL::file;

#line 110 "blib\lib\URI\URL\file.pm (autosplit into blib\lib\auto/URI\URL\file/mac_path.al)"
sub mac_path
{
    my $self = shift;
    my @p;
    for ($self->path_components) {
	Carp::croak("Path component contains ':'") if /:/;
	# XXX: Should probably want to do something about ".." and "."
	# path segments.  I don't know how these are represented in
	# the Machintosh file system.  If these are valid file names
	# then we should split the path ourself, as $u->path_components
	# loose the distinction between '.' and '%2E'.
	push(@p, $_);
    }
    if (@p && $p[0] eq '') {
	shift @p;
    } else {
	unshift(@p, '');
    }
    join(':', @p);
}

# end of URI::URL::file::mac_path
1;
