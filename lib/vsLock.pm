;    # $Id
;    #  vsLock v 0.103
;    #  Modified by Jason M. Hinkle, 2001
;    #
;    #  Based on File::Lock
;    #  Copyright (c) 1998, Raphael Manfredi
;    #
;    #  You may redistribute only under the terms of the Artistic License,
;    #  as specified in the README file that comes with the distribution.
;    #
;    # $Log: vsLock.pm,v $
;    # Revision 1.3  2004/02/01 19:24:35  winter
;    #  - 2.87 release
;    #
;    # Revision 0.1.1.1  1998/05/12  07:42:19  ram
;    # patch1: Baseline for first alpha release.
;    #

########################################################################
package vsLock;
@ISA = qw(Exporter);

#
# This package extracts the simple locking logic used by mailagent-3.0
# into a standalone Perl module to be reused in other applications.
#

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Sys::Hostname;

require Exporter;

@ISA       = qw(Exporter);
@EXPORT    = ();
@EXPORT_OK = qw(lock trylock unlock);
$VERSION   = '0.103';

$vsLock::LOCKER = undef;    # Default locking object

#
# ->make
#
# Create a file locking object, responsible for holding the locking
# parameters to be used by all the subsequent locks requested from
# this locking object.
#
# Configuration attributes:
#
#   max				max number of attempts
#	delay			seconds to wait between attempts
#	format			how to derive lockfile from file to be locked
#	hold			max amount of seconds before breaking lock (0 for never)
#	ext				lock extension
#	nfs				true if lock must "work" on top of NFS
#	warn			flag to turn warnings on
#	wmin			warn once after that many waiting seconds
#	wafter			warn every that many seconds after first warning
#	wfunc			warning function to be called
#
# The creation routine first and sole argument is a "hash table list" listing
# all the configuration attributes. Missing attributes are given a default
# value. A call to ->configure can alter the configuration parameters of
# an existing object.
#
sub new {
    my $self = bless {}, shift;
    my (@hlist) = @_;
    $self->configure(@hlist);

    # Set configuration defaults
    $self->{'max'}    = 30          unless $self->{'max'};
    $self->{'delay'}  = 2           unless $self->{'delay'};
    $self->{'hold'}   = 3600        unless $self->{'hold'};
    $self->{'ext'}    = '.lock'     unless defined $self->{'ext'};
    $self->{'nfs'}    = 0           unless defined $self->{'nfs'};
    $self->{'warn'}   = 1           unless defined $self->{'warn'};
    $self->{'wfunc'}  = \&core_warn unless defined $self->{'wfunc'};
    $self->{'wmin'}   = 15          unless $self->{'wmin'};
    $self->{'wafter'} = 20          unless $self->{'wafter'};

    return $self;
}

#
# ->configure
#
# Extract known configuration parameters from the specified hash list
# and use their values to change the object's corresponding parameters.
#
# Parameters are specified as (-warn => 1, -ext => '.lock') for instance.
#
sub configure {
    my $self    = shift;
    my (%hlist) = @_;
    my @known   = qw(max delay hold format ext nfs warn wfunc wmin wafter);
    foreach my $attr (@known) {
        $self->{$attr} = $hlist{"-$attr"} if defined $hlist{"-$attr"};
    }
}

#
# Attribute access
#

sub max     { $_[0]->{'max'} }
sub delay   { $_[0]->{'delay'} }
sub format  { $_[0]->{'format'} }
sub hold    { $_[0]->{'hold'} }
sub nfs     { $_[0]->{'nfs'} }
sub ext     { $_[0]->{'ext'} }
sub warn    { $_[0]->{'warn'} }
sub wmin    { $_[0]->{'wmin'} }
sub wafter  { $_[0]->{'wafter'} }
sub wfunc   { $_[0]->{'wfunc'} }
sub Version { return $VERSION; }

sub core_warn { CORE::warn(@_) }

#
# ->lock
#
# Lock specified file, possibly using alternate file "format".
# Returns whether file was locked or not at the end of the configured
# blocking period.
#
# For quick and dirty scripts wishing to use locks, create the locking
# object if not invoked as a method, turning on warnings.
#
sub lock {
    my $self = shift;
    unless ( ref $self ) {    # Not invoked as a method
        unshift( @_, $self );
        $self = $vsLock::LOCKER
          || vsLock->make( '-warn' => 1 );
    }
    my ( $file, $format ) = @_;    # File to be locked, lock format
    return $self->_acs_lock( $file, $format, 0 );
}

#
# ->trylock
#
# Attempt to lock specified file, possibly using alternate file "format".
# If the file is already locked, don't block and return false.
#
# For quick and dirty scripts wishing to use locks, create the locking
# object if not invoked as a method, turning on warnings.
#
sub trylock {
    my $self = shift;
    unless ( ref $self ) {    # Not invoked as a method
        unshift( @_, $self );
        $self = $vsLock::LOCKER
          || vsLock->make( '-warn' => 1 );
    }
    my ( $file, $format ) = @_;    # File to be locked, lock format
    return $self->_acs_lock( $file, $format, 1 );
}

#
# ->unlock
#
# Unlock file.
# Returns true if file was unlocked.
#
sub unlock {
    my $self = shift;
    unless ( ref $self ) {    # Not invoked as a method
        unshift( @_, $self );
        $self = $vsLock::LOCKER
          || vsLock->make( '-warn' => 1 );
    }
    my ( $file, $format ) = @_;    # File to be unlocked, lock format
    return $self->_acs_unlock( $file, $format );
}

#
# ->lockfile
#
# Return the name of the lockfile, given the file name to lock and the custom
# string provided by the user. The following macros are substituted:
#	%D: the file dir name
#   %f: the file name (full path)
#   %F: the file base name (last path component)
#   %p: the process's pid
#   %%: a plain % character
#
sub lockfile {
    my $self = shift;
    my ( $file, $format ) = @_;
    local $_ = defined($format) ? $format : $self->format;
    s/%%/\01/g;               # Protect double percent signs
    s/%/\02/g;                # Protect against substitutions adding their own %
    s/\02f/$file/g;           # %f is the full path name
    s/\02D/&dir($file)/ge;    # %D is the dir name
    s/\02F/&base($file)/ge;   # %F is the base name
    s/\02p/$$/g;              # %p is the process's pid
    s/\02/%/g;                # All other % kept as-is
    s/\01/%/g;                # Restore escaped % signs
    $_;
}

# Return file basename (last path component)
sub base {
    my ($file) = @_;
    my ($base) = $file =~ m|^.*/(.*)|;
    $base;
}

# Return dirname
sub dir {
    my ($file) = @_;
    my ($dir)  = $file =~ m|^(.*)/.*|;
    $dir;
}

#
# _acs_lock			-- private
#
# Internal locking routine.
#
# If $try is true, don't wait if the file is already locked.
# Returns true if the file was locked.
#
sub _acs_lock {    ## private
    my $self = shift;
    my ( $file, $format, $try ) = @_;
    my $max   = $self->max;
    my $delay = $self->delay;
    my $stamp = $$;

    # For NFS, we need something more unique than the process's PID
    $stamp .= hostname if $self->nfs;

    # Compute locking file name -- hardwired default format is "%f.lock"
    my $lockfile = $file . $self->ext;
    $format = $self->format unless defined $format;
    $lockfile = $self->lockfile( $file, $format ) if defined $format;

    # Break lock if held for too long
    $self->_acs_check( $file, $lockfile ) if $self->hold;

    my $waited   = 0;             # Amount of time spent sleeping
    my $lastwarn = 0;             # Last time we warned them...
    my $warn     = $self->warn;
    my ( $wmin, $wafter, $wfunc );
    ( $wmin, $wafter, $wfunc ) = ( $self->wmin, $self->wafter, $self->wfunc )
      if $warn;
    my $locked = 0;
    my $mask   = umask(0333);     # No write permission
    local *FILE;

    while ( $max-- > 0 ) {
        if ( -f $lockfile ) {
            next unless $try;
            umask($mask);
            return 0;             # Already locked
        }

        # Attempt to create lock
        if ( open( FILE, ">$lockfile" ) ) {
            print FILE "$stamp\n";
            close FILE;
            open( FILE, $lockfile );    # Check lock
            my $l;
            chop( $l = <FILE> );
            $locked = $l eq $stamp;
            $l      = <FILE>;            # Must be EOF
            $locked = 0 if defined $l;
            close FILE;
            last if $locked;             # Lock seems to be ours
        }
        elsif ($try) {
            umask($mask);
            return 0;                    # Already locked, or cannot create lock
        }
    }
    continue {
        sleep($delay);                   # Busy: wait
        $waited += $delay;

        # Warn them once after $wmin seconds and then every $wafter seconds
        if (
            $warn
            && (   ( !$lastwarn && $waited > $wmin )
                || ( $waited - $lastwarn ) > $wafter )
          )
        {
            my $waiting = $lastwarn    ? 'still waiting' : 'waiting';
            my $after   = $lastwarn    ? 'after'         : 'since';
            my $s       = $waited == 1 ? ''              : 's';
            &$wfunc("WARNING $waiting for $file lock $after $waited second$s");
            $lastwarn = $waited;
        }
    }

    umask($mask);
    return $locked;
}

#
# ->_acs_unlock		-- private
#
# Unlock file. If lock format is specified, it must match the one used
# at lock time.
#
# Return true if file was indeed locked by us and is now properly unlocked.
#
sub _acs_unlock {    ## private
    my $self = shift;
    my ( $file, $format ) = @_;    # Locked file, locking format
    my $stamp = $$;
    $stamp .= hostname if $self->nfs;

    # Compute locking file name -- hardwired default format is "%f.lock"
    my $lockfile = $file . $self->ext;
    $format = $self->format unless defined $format;
    $lockfile = $self->lockfile( $file, $format ) if defined $format;

    local *FILE;
    my $unlocked = 0;

    if ( -f $lockfile ) {
        open( FILE, $lockfile );
        my $l;
        chop( $l = <FILE> );
        close FILE;
        if ( $l eq $stamp ) {    # Pid (plus hostname possibly) is OK
            $unlocked = 1;
            unlink $lockfile or $unlocked = 0;
        }
    }

    # It's reasonable to expect $! to be meaningful at this point
    &{ $self->wfunc }("WARNING did not unlock $file: $!")
      if !$unlocked && $self->warn;

    return $unlocked;            # Did we successfully unlock?
}

#
# ->_acs_check
#
# Make sure lock lasts only for a reasonable time. If it has expired,
# then remove the lockfile.
#
sub _acs_check {
    my $self = shift;
    my ( $file, $lockfile ) = @_;
    return unless -f $lockfile;

    my $mtime = ( stat($lockfile) )[9];
    my $hold  = $self->hold;

    # If file too old to be considered stale?
    if ( ( time - $mtime ) > $hold ) {
        unlink $lockfile;
        if ( $self->warn ) {
            $file =~ s|.*/(.*)|$1|;    # Keep only basename
            my $s = $hold == 1 ? '' : 's';
            &{ $self->wfunc }
              ("UNLOCKED $file (lock older than $hold second$s)");
        }
    }
}

1;

########################################################################

=head1 NAME

vsLock - simple file locking scheme

=head1 SYNOPSIS

 use vsLock qw(lock trylock unlock);

 # Simple locking using default settings
 lock("/some/file") || die "can't lock /some/file\n";
 warn "already locked\n" unless trylock("/some/file");
 unlock("/some/file");

 # Build customized locking manager object
 $lockmgr = new vsLock(-format => '%f.lck',
	-max => 20, -delay => 1, -nfs => 1);

 $lockmgr->lock("/some/file") || die "can't lock /some/file\n";
 $lockmgr->trylock("/some/file");
 $lockmgr->unlock("/some/file");

 $lockmgr->configure(-nfs => 0);

=head1 DESCRIPTION

This simple locking scheme is not based on any file locking system calls
such as C<flock()> or C<lockf()> but rather relies on basic file system
primitives and properties, such as the atomicity of the C<write()> system
call. It is not meant to be exempt from all race conditions, especially over
NFS. The algorithm used is described below in the B<ALGORITHM> section.

It is possible to customize the locking operations to attempt locking
once every 5 seconds for 30 times, or delete stale locks (files that are
deemed too ancient) before attempting the locking.

=head1 ALGORITHM

The locking alogrithm attempts to create a I<lockfile> using a temporarily
redefined I<umask> (leaving only read rights to prevent further create
operations). It then writes the process ID (PID) of the process and closes
the file. That file is then re-opened and read. If we are able to read the
same PID we wrote, and only that, we assume the locking is successful.

When locking over NFS, i.e. when the one of the potentially locking processes
could access the I<lockfile> via NFS, then writing the PID is not enough.
We also write the hostname where locking is attempted to ensure the data
are unique.

=head1 CUSTOMIZING

Customization is only possible by using the object-oriented interface,
since the configuration parameters are stored within the object. The
object creation routine C<make> can be given configuration parmeters in
the form a "hash table list", i.e. a list of key/value pairs. Those
parameters can later be changed via C<configure> by specifying a similar
list of key/value pairs.

To benefit from the bareword quoting Perl offers, all the parameters must
be prefixed with the C<-> (minus) sign, as in C<-format> for the I<format>
parameter..  However, when querying the object, the minus must be omitted,
as in C<$obj-E<gt>format>.

Here are the available configuration parmeters along with their meaning,
listed in alphabetical order:

=over 4

=item I<delay>

The amount of seconds to wait between locking attempts when the file appears
to be already locked. Default is 2 seconds.

=item I<ext>

The locking extension that must be added to the file path to be locked to
compute the I<lockfile> path. Default is C<.lock> (note that C<.> is part
of the extension and can therefore be changed). Ignored when I<format> is
also used.

=item I<format>

Using this parmeter supersedes the I<ext> parmeter. The formatting string
specified is run through a rudimentary macro expansion to derive the
I<lockfile> path from the file to be locked. The following macros are
available:

	%%	A real % sign
	%f	The full file path name
	%D	The directory where the file resides
	%F	The base name of the file
	%p	The process ID (PID)

The default is to use the locking extension, which itself is C<.lock>, so
it is as if the format used was C<%f.lock>, but one could imagine things
like C</var/run/%F.%p>, i.e. the I<lockfile> does not necessarily lie besides
the locked file (which could even be missing).

When locking, the locking format can be specified to supersede the object
configuration itself. Be sure to use the same locking format when unlocking!
For instance, you can say:

	$obj->lock('ppp', '/var/run/ppp.%p');
	$obj->configure(-format => '/var/run/ppp.%p');
	$obj->unlock('ppp');	# Okay, since format changed

This also works when the calling C<lock()> without an object, and this is
where it is most useful since in that case you have no object to configure!
The example above becomes:

	lock('ppp', '/var/run/ppp.%p');    # file ppp may not even exist!
	<do whatever>
	unlock('ppp', '/var/run/ppp.%p');  # MUST specify here

=item I<hold>

Maximum amount of seconds we may hold a lock. Past that amount of time,
an existing I<lockfile> is removed, being taken for a stale lock. Default
is 3600 seconds. Specifying 0 prevents any forced unlocking.

=item I<max>

Amount of times we retry locking when the file is busy, sleeping I<delay>
seconds between attempts. Defaults to 30.

=item I<nfs>

A boolean flag, false by default. Setting it to true means we could lock
over NFS and therefore the hostname must be included along with the process
ID in the stamp written to the lockfile.

=item I<wafter>

Stands for I<warn after>. It is the number of seconds past the first
warning during locking time after which a new warning should be emitted.
See I<warn> and I<wmin> below. Default is 20.

=item I<warn>

A boolean flag, true by default. To suppress any warning, set it to false.

=item I<wfunc>

A function pointer to dereference when a warning is to be issued. By default,
it points to Perl's C<warn()> function.

=item I<wmin>

The minimal amount of time when waiting for a lock after which a first
warning must be emitted, if I<warn> is true. After that, a warning will
be emitted every I<wafter> seconds. Defaults to 15.

=back

Each of those configuration attributes can be queried on the object directly:

	$obj = vsLock->make(-nfs => 1);
	$on_nfs = $obj->nfs;

Those are pure query routines, i.e. you cannot say:

	$obj->nfs(0);			# WRONG
	$obj->configure(-nfs => 0);	# Right

to turn of the NFS attribute. That is because my OO background chokes
at having querying functions with side effects.

=head1 INTERFACE

The OO interface documented below specifies the signature and the
semantics of the operations. Only the C<lock>, C<trylock> and
C<unlock> operation can be imported and used via a non-OO interface,
with the exact same signature nonetheless.

The interface contains all the attribute querying routines, one for
each configuration parmeter documented in the B<CUSTOMIZING> section
above, plus, in alphabetical order:

=over 4

=item configure(I<-key =E<gt> value, -key2 =E<gt> value2, ...>)

Change the specified configuration parameters and silently ignore
the invalid ones.

=item lock(I<file>, I<format>)

Attempt to lock the file, using the optional locking I<format> if
specified, otherwise using the default I<format> scheme configured
in the object, or by simply appending the I<ext> extension to the file.

If the file is already locked, sleep I<delay> seconds before retrying,
repeating try/sleep at most I<max> times. If warning is configured,
a first warning is emitted after waiting for I<wmin> seconds, and
then once every I<wafter> seconds, via  the I<wfunc> routine.

Before the first attempt, and if I<hold> is non-zero, any existing
I<lockfile> is checked for being too old, and it is removed if found
to be stale. A warning is emitted via the I<wfunc> routine in that
case, if allowed.

Returns true if the file has been successfully locked.

=item lockfile(I<file>, I<format>)

Simply compute the path of the I<lockfile> that would be used by the
I<lock> procedure if it were passed the same parameters.

=item make(I<-key =E<gt> value, -key2 =E<gt> value2, ...>)

The creation routine for the simple lock object. Returns a blessed hash
reference.

=item trylock(I<file>, I<format>)

Same as I<lock> except that it immediately returns false and does not
sleep if the to-be-locked file is busy, i.e. already locked. Any
stale locking file is removed, as I<lock> would do anyway.

Returns true if the file has been successfully locked.

=item unlock(I<file>, I<format>)

Unlock the I<file>. If the optional I<format> parameter is given, it
must be the same as the one that was used at I<lock> time.

=back

=head1 BUGS

The algorithm is not bullet proof.  It's only reasonably safe.  Don't bet
the integrity of a mission-critical database on it though.

The sysopen() call should probably be used with the C<O_EXCL|O_CREAT> flags
to be on the safer side. Still, over NFS, this is not an atomic operation
anyway.

=head1 AUTHOR

Raphael Manfredi F<E<lt>Raphael_Manfredi@grenoble.hp.comE<gt>>

=head1 SEE ALSO

File::Flock(3).

=cut

