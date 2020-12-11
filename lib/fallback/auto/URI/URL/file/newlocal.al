# NOTE: Derived from blib\lib\URI\URL\file.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL::file;

#line 55 "blib\lib\URI\URL\file.pm (autosplit into blib\lib\auto/URI\URL\file/newlocal.al)"
sub newlocal {
    my($class, $path) = @_;

    Carp::croak("Only implemented for Unix and OS/2 file systems")
      unless $ostype eq "unix" or $^O =~ /os2|mswin32/i;
    # XXX: Should implement the same thing for other systems

    my $url = new URI::URL "file:";
    unless (defined $path and
    	    ($path =~ m:^/: or 
	     ($^O eq 'os2' and Cwd::sys_is_absolute($path)) or
	     ($^O eq 'MSWin32' and $path =~ m<^[A-Za-z]:[\\/]|^[\\/]{2}>))) {
	require Cwd;
	my $cwd = Cwd::fastcwd();
	$cwd =~ s:/?$:/:; # force trailing slash on dir
	$path = (defined $path) ? $cwd . $path : $cwd;
    }
    $url->path($path);
    $url;
}

# end of URI::URL::file::newlocal
1;
