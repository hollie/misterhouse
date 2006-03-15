# NOTE: Derived from blib\lib\URI\URL\file.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL::file;

#line 97 "blib\lib\URI\URL\file.pm (autosplit into blib\lib\auto/URI\URL\file/dos_path.al)"
sub dos_path
{
    my $self = shift;
    my @p;
    for ($self->path_components) {
	Carp::croak("Path component contains '/' or '\\'") if m|[/\\]|;
	push(@p, uc $_);
    }
    my $p = join("\\", @p);
    $p =~ s/^\\([A-Z]:)/$1/;  # Fix drive letter specification
    $p;
}

# end of URI::URL::file::dos_path
1;
