package Win32::API;

# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.

#######################################################################
#
# Win32::API - Perl Win32 API Import Facility
# ^^^^^^^^^^
# Version: 0.01 (08 Jul 1997)
# by Aldo Calpini <dada@divinf.it>
#######################################################################

require Exporter;       # to export the constants to the main:: space
require DynaLoader;     # to dynuhlode the module.
@ISA = qw( Exporter DynaLoader );

#######################################################################
# This AUTOLOAD is used to 'autoload' constants from the constant()
# XS function.  If a constant is not found then control is passed
# to the AUTOLOAD in AutoLoader.
#

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    $!=0;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
    if ($! =~ /Invalid/) {
        $AutoLoader::AUTOLOAD = $AUTOLOAD;
        goto &AutoLoader::AUTOLOAD;
    }
    else {
        ($pack,$file,$line) = caller;
        die "Your vendor has not defined Win32::API macro $constname, used at $file line $line.";
    }
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}


#######################################################################
# STATIC OBJECT PROPERTIES
#
$VERSION = "0.01";

# to keep track of the imported libraries/procedures
%Libraries = ();
%Procedures = ();

#######################################################################
# dynamically load in the API extension module.
#
bootstrap Win32::API;

#######################################################################
# PUBLIC METHODS
#
sub new {
    my $class = shift;
    my ($dll, $proc, $in, $out) = @_;
    
    my $self = {};
    
    my $hdll;
    
    # avoid loading a library more than once
    if(exists($Libraries{$dll})) {
        # print "Win32::API::new: Library $dll already loaded, handle=$Libraries{$dll}\n";
        $hdll = $Libraries{$dll};
    } else {
        # print "Win32::API::new: Loading library $dll\n";
        $hdll = Win32::API::LoadLibrary($dll);
        $Libraries{$dll} = $hdll;
    }

    return undef unless $hdll;

    my $hproc = Win32::API::GetProcAddress($hdll, $proc);

    # try with either A or W (for ASCII or Unicode)
    if(!$hproc) {
        $proc .= (IsUnicode() ? "W" : "A");
        # print "Win32::API::new: procedure not found, trying '$proc'...\n";
        $hproc = Win32::API::GetProcAddress($hdll, $proc);
    }

    return undef unless $hproc;
    
    $self->{dll} = $hdll;
    $self->{dllname} = $dll;
    $self->{proc} = $hproc;

    $Libraries{$dll} = $hdll;
    $Procedures{$dll}++;

    my @in_params = ();
    
    foreach (@$in) {
        push(@in_params, 1) if /[NL]/i;
        push(@in_params, 2) if /P/i;
        push(@in_params, 3) if /I/i;        
    }
    $self->{in} = \@in_params;
    
    $self->{out} = 0 if $out=~/V/i;
    $self->{out} = 1 if $out=~/[NL]/i;
    $self->{out} = 2 if $out=~/P/i;
    $self->{out} = 3 if $out=~/I/i;
    bless($self, $class);
    return $self;
}

#######################################################################
# PRIVATE METHODS
#
sub DESTROY {
    my($self) = @_;
    $Procedures{$self->{dllname}}--;
    # once the procedure reference count of a library 
    # reachs 0, free it
    if($Procedures{$self->{dllname}} == 0) {
        # print "Win32::API::DESTROY: Freeing library $self->{dllname}\n";
        Win32::API::FreeLibrary($Libraries{$self->{dllname}});
        delete($Libraries{$self->{dllname}});
    }    
}

#Currently Autoloading is not implemented in Perl for win32
# Autoload methods go after __END__, and are processed by the autosplit program.

1;
__END__


=head1 NAME

Win32::API - Implementation of arbitrary Win32 APIs.

=head1 SYNOPSIS

  use Win32::API;
  $function = new Win32::API($library, 
                             $functionname, 
                             \@argumenttypes, 
                             $returntype);
  $return = $function->Call(@arguments);

=head1 ABSTRACT

With this module you can import and call arbitrary functions
from Win32's Dynamic Link Libraries (DLL). 

The current version of Win32::API is available at:

  http://www.divinf.it/dada/perl/api/

It is also available on your nearest CPAN mirror 
(but allow a few days for worldwide spreading of the latest version) 
reachable at:

  http://www.perl.com/CPAN/authors/Aldo_Calpini/

=head1 CREDITS

All the credits go to Andrea Frosini ( I<frosini@programmers.net> ),
for his bits of magic - eg. the assembler trick that make this thing work.
A big thank you also to Gurusamy Sarathy ( I<gsar@engin.umich.edu> ) for his
help in XS development C<:)>

=head1 INSTALLATION

This module comes with pre-built binaries for:

=over 4

=item The Perl for Win32 port by ActiveWare: 
Build 300 or higher (EXCEPT 304!)

=item The core Perl 5.004 distribution: 
Built on the Win32 platform, of course...

=back

To install the package, just change to the directory in which you 
uncompressed it and type the following:

    install

This will take care of copying the right files to the right 
places for use by all your perl scripts.

If you're running the core Perl 5.004 distribution, you can
also build the extension by yourself with the following procedure:

    perl Makefile.PL
    nmake
    nmake install

If you are instead running the ActiveWare Perl for Win32 port, the 
sources to rebuild the extension are in the F<ActiveWare/source> directory.
You should put those files in the following directory:

    (perl-src)\ext\Win32\API

Where C<(perl-src)> is the location of your Perl-Win32 source files.

=head1 DESCRIPTION

To use this module put the following line at the beginning of your script:

    use Win32::API;

You can now use the new() function of the Win32::API module to create a
new API object (see L<IMPORTING A FUNCTION>) and then invoke the 
Call() method on this object to perform a call to the imported API
(see L<CALLING AN IMPORTED FUNCTION>).

=head2 IMPORTING A FUNCTION

You can import a function from a Dynamic Link Library (DLL) file with
the new() function. This will create a Perl object that contains the
reference to that function, which you can later Call().
You need to pass 4 parameters:

=over 4

=item 1.
The name of the library from which you want to import the function.

=item 2.
The name of the function (as exported by the library).

=item 3.
The number and types of the arguments the function expects as input.

=item 4.
The type of the value returned by the function.

=back

To explain better their meaning, let's make an example:
I want to import and call the Win32 API C<GetTempPath()>.
This function is defined in C as:

    DWORD WINAPI GetTempPathA( DWORD nBufferLength, LPSTR lpBuffer );

This is documented in the B<Win32 SDK Reference>; look
for it on the Microsoft's WWW site. If you own Visual C++,
searching in the include files is much faster.

B<1.>

The first parameter is the name of the library file that 
exports this function; our function resides in the F<KERNEL32.DLL>
system file.
When specifying this name as parameter, the F<.dll> extension
is implicit, and if no path is given, the file is searched through
the Windows directories. So I don't have to write 
F<C:\windows\system\kernel32.dll>; only F<kernel32> is enough:

    $GetTempPath = new Win32::API("kernel32", ...

B<2.>

Now for the second parameter: the name of the function.
It must be written exactly as it is exported 
by the library (case is significant here). 
If you are using Windows 95 or NT 4.0, you can use the B<Quick View> 
command on the DLL file to see the function it exports. 
Note that many Win32 APIs are exported twice, with the addition of
a final B<A> or B<W> to their name, for - respectively - the ASCII 
and the Unicode version.
Win32::API, when a function name is not found, will actually append
an B<A> to the name and try again. If you are using Unicode, you
will just need to rebuild the module; then Win32::API will 
try with the B<W>.
So my function name will be:

    $GetTempPath = new Win32::API("kernel32", "GetTempPath", ...

Note that C<GetTempPath> is really loaded as C<GetTempPathA>.

B<3.>

The third parameter, the input parameter list, specifies how many 
arguments the function wants, and their types. It B<MUST> be passed 
as a list reference. The following forms are valid:

    [a, b, c, d]
    \@LIST

But those are not:

    (a, b, c, d)
    @LIST

The number of elements in the list specifies the number of parameters,
and each element in the list specifies the type of an argument; allowed
types are:

=over 4

=item C<I>: 
value is an integer

=item C<N>: 
value is a number (long)

=item C<P>: 
value is a pointer (to a string, structure, etc...)

=back

Our function needs two parameters: a number (C<DWORD>) and a pointer to a 
string (C<LPSTR>):

    $GetTempPath = new Win32::API("kernel32", "GetTempPath", [N, P], ...

B<4.>

The fourth and final parameter is the type of the value returned by the 
function. It can be one of the types seen above, plus another type named B<V> 
(that stands for C<void>) to indicate that the function doesn't return a value.
In our example the value returned by GetTempPath() is a C<DWORD>, so 
our return type will be B<N>:

    $GetTempPath = new Win32::API("kernel32", "GetTempPath", [N, P], N);

Now the line is complete, and the API GetTempPath() is available for use 
in Perl. Before you can call it, you should test that $GetTempPath is 
C<defined>, otherwise either the function or the library has not been found.

=head2 CALLING AN IMPORTED FUNCTION

To effectively make a call to an imported function you must use the
Call() method on the Win32::API object you created.
To continue with the example from the previous paragraph, I can
call the GetTempPath() API via the method:

    $GetTempPath->Call(...

Of course I have to pass the parameters as defined in the import phase.
In particular, if the number of parameters does not match (in the example,
if I call GetTempPath() with more or less than two parameters), 
Perl will C<croak> an error message and C<die>.

So I need two parameters here: the first is the length of the buffer
that will hold the returned temporary path, the second is the buffer
itself.
For numerical parameters you can use either a constant expression
or a variable, while B<for pointers you must use a variable name> (no 
reference, just a plain variable name).
Also note that B<memory must be allocated before calling the function>.
For example, if I want to pass a buffer of 80 characters to GetTempPath(),
I have to initialize it before with:

    $lpBuffer = " " x 80;

This allocates a string of 80 characters. If you don't do so, you'll
probably get 'C<Runtime exception>' errors, and generally nothing will 
work. My call should therefore include:

    $lpBuffer = " " x 80;
    $GetTempPath->Call(80, $lpBuffer);

And the result will be stored in the $lpBuffer variable.
Note, however, that Perl does not trim the variable, so $lpBuffer
will contain 80 characters in return; the exceeding characters
will be spaces, since I initialized the variable with C<" " x 80>.
In this case I'm lucky enough, because the value returned by 
the GetTempPath() function is the length of the string, so to get
the actual temporary path I write:

    $lpBuffer = " " x 80;
    $return = $GetTempPath->Call(80, $lpBuffer);
    $TempPath = substr($lpBuffer, 0, $return);

If you don't know the length of the string, you can usually
cut it at the \0 (ASCII zero) character, which is the string
delimiter in C:

    $TempPath = ((split(/\0/, $lpBuffer))[0];
    
    # or
    
    $lpBuffer =~ s/\0.*$//;
    $TempPath = $lpBuffer;

Another note: to pass a pointer to a structure in C, you'll have
to pack() the required elements in a variable. And of course, to 
access the values stored in a structure, unpack() it as required.
An example of how it works: we have the C<POINT> structure 
defined in C as:

    typedef struct {
        LONG  x;
        LONG  y;
    } POINT;

Thus, to call a function that uses a C<POINT> structure you
will need the following lines:

    $GetCursorPos = new Win32::API("user32", "GetCursorPos", [P], V);
    
    $lpPoint = pack("LL", 0, 0); # store two LONGs
    $GetCursorPos->Call($lpPoint);
    ($x, $y) = unpack("LL", $lpPoint); # get the actual values

The rest is left as an exercise to the reader...

=head1 AUTHOR

Aldo Calpini ( I<dada@divinf.it> ).


=cut


