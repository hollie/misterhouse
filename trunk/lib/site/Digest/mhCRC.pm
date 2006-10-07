package Digest::mhCRC;

# $Date$
# $Revision$

use 5.6.1;
use strict;
use warnings;
use Carp;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(crc16);
our @EXPORT = qw();
our $VERSION = '0.03';

use fields qw(crc16 size);

my @crctab = (
0x0000,  0x1021,  0x2042,  0x3063,  0x4084,  0x50a5,  0x60c6,  0x70e7,  #0x00
0x8108,  0x9129,  0xa14a,  0xb16b,  0xc18c,  0xd1ad,  0xe1ce,  0xf1ef,
0x1231,  0x210,  0x3273,  0x2252,  0x52b5,  0x4294,  0x72f7,  0x62d6,   #0x10
0x9339,  0x8318,  0xb37b,  0xa35a,  0xd3bd,  0xc39c,  0xf3ff,  0xe3de,
0x2462,  0x3443,  0x420,  0x1401,  0x64e6,  0x74c7,  0x44a4,  0x5485,   #0x20
0xa56a,  0xb54b,  0x8528,  0x9509,  0xe5ee,  0xf5cf,  0xc5ac,  0xd58d,
0x3653,  0x2672,  0x1611,  0x630,  0x76d7,  0x66f6,  0x5695,  0x46b4,   #0x30
0xb75b,  0xa77a,  0x9719,  0x8738,  0xf7df,  0xe7fe,  0xd79d,  0xc7bc,
0x48c4,  0x58e5,  0x6886,  0x78a7,  0x840,  0x1861,  0x2802,  0x3823,   #0x40
0xc9cc,  0xd9ed,  0xe98e,  0xf9af,  0x8948,  0x9969,  0xa90a,  0xb92b,
0x5af5,  0x4ad4,  0x7ab7,  0x6a96,  0x1a71,  0xa50,  0x3a33,  0x2a12,   #0x50
0xdbfd,  0xcbdc,  0xfbbf,  0xeb9e,  0x9b79,  0x8b58,  0xbb3b,  0xab1a,
0x6ca6,  0x7c87,  0x4ce4,  0x5cc5,  0x2c22,  0x3c03,  0xc60,  0x1c41,   #0x60
0xedae,  0xfd8f,  0xcdec,  0xddcd,  0xad2a,  0xbd0b,  0x8d68,  0x9d49,
0x7e97,  0x6eb6,  0x5ed5,  0x4ef4,  0x3e13,  0x2e32,  0x1e51,  0xe70,   #0x70
0xff9f,  0xefbe,  0xdfdd,  0xcffc,  0xbf1b,  0xaf3a,  0x9f59,  0x8f78,
0x9188,  0x81a9,  0xb1ca,  0xa1eb,  0xd10c,  0xc12d,  0xf14e,  0xe16f,  #0x80
0x1080,  0xa1,  0x30c2,  0x20e3,  0x5004,  0x4025,  0x7046,  0x6067,
0x83b9,  0x9398,  0xa3fb,  0xb3da,  0xc33d,  0xd31c,  0xe37f,  0xf35e,  #0x90
0x2b1,  0x1290,  0x22f3,  0x32d2,  0x4235,  0x5214,  0x6277,  0x7256,
0xb5ea,  0xa5cb,  0x95a8,  0x8589,  0xf56e,  0xe54f,  0xd52c,  0xc50d,  #0xA0
0x34e2,  0x24c3,  0x14a0,  0x481,  0x7466,  0x6447,  0x5424,  0x4405,
0xa7db,  0xb7fa,  0x8799,  0x97b8,  0xe75f,  0xf77e,  0xc71d,  0xd73c,  #0xB0
0x26d3,  0x36f2,  0x691,  0x16b0,  0x6657,  0x7676,  0x4615,  0x5634,
0xd94c,  0xc96d,  0xf90e,  0xe92f,  0x99c8,  0x89e9,  0xb98a,  0xa9ab,  #0xC0
0x5844,  0x4865,  0x7806,  0x6827,  0x18c0,  0x8e1,  0x3882,  0x28a3,
0xcb7d,  0xdb5c,  0xeb3f,  0xfb1e,  0x8bf9,  0x9bd8,  0xabbb,  0xbb9a,  #0xD0
0x4a75,  0x5a54,  0x6a37,  0x7a16,  0xaf1,  0x1ad0,  0x2ab3,  0x3a92,
0xfd2e,  0xed0f,  0xdd6c,  0xcd4d,  0xbdaa,  0xad8b,  0x9de8,  0x8dc9,  #0xE0
0x7c26,  0x6c07,  0x5c64,  0x4c45,  0x3ca2,  0x2c83,  0x1ce0,  0xcc1,
0xef1f,  0xff3e,  0xcf5d,  0xdf7c,  0xaf9b,  0xbfba,  0x8fd9,  0x9ff8,  #0xF0
0x6e17,  0x7e36,  0x4e55,  0x5e74,  0x2e93,  0x3eb2,  0xed1,  0x1ef0
);


sub new {
    my $class = shift;
    my Digest::mhCRC $self = fields::new(ref $class || $class);
    return $self->reset;
}   # new


sub reset {
    my Digest::mhCRC $self = shift;
    $self->{crc16} = $self->{size} = 0;
    return $self;
}   # reset


sub add {
    use integer;
    my Digest::mhCRC $self = shift;
    my $crc16 = $self->{crc16};
    my $size = $self->{size};

    while(@_) {
        my $n = length $_[0];

        for(my $i = 0; $i < $n; ++$i) {
            my $c = unpack 'C', substr $_[0], $i, 1;
#            printf "c= %X, crc16 << 8 = %X, \n crc16 >> 8 = %X, crc16 >> 8 ^ c = %X, crctab[]= %X\n",$c, $crc16 << 8, ($crc16 >> 8), (($crc16 >> 8) ^ $c) & 0xFF, $crctab[(($crc16 >> 8) ^ $c) & 0xFF ];
            $crc16 = (($crc16 << 8) ^ $crctab[(($crc16 >> 8) ^ $c) & 0xFF]) & 0xffff;
#            printf " i=%X c=%X crc16=%X\n", $i, $c, $crc16;
            ++$size;
        }

    }
    continue { shift }

    $self->{crc16} = $crc16;
    $self->{size} = $size;

    return $self;
}   # add


sub addfile {
    my Digest::mhCRC $self = shift;
    my $stat;

    local $_;
    while(my $ifd = shift) {
        $self->add($_) while $stat = read $ifd, $_, 4096;

        if(! defined $stat) {
            croak "error reading from filehandle: $!";
        }
    }

    return $self;
}   # addfile

sub crc16(@) {
    my $sum = Digest::mhCRC->new;

    while(@_) {
        if(ref $_[0])
            { $sum->addfile($_[0]) }
        else
            { $sum->add($_[0]) }
    }
    continue { shift }

   # printf ("\n\ncrc16 before result = $self->{crc16}\n\n");

    return $sum->{crc16};
}   # crc16

1;

__END__

=head1 NAME

Digest::mhCRC - Perl extension for calculating crc16s
in a manner compatible with the POSIX cksum program.  Modified 
for use with Misterhouse

$Date$
$Revision$

=head1 SYNOPSIS

B<OO style>:
  use Digest::mhCRC;

  $crc16 = Digest::mhCRC->new;
  $crc16_1 = $crc16->new;     # clone (clone is reset)

  $crc16->add("string1");
  $crc16->add("string2");
  $crc16->add("string3", "string4", "string5", ...);
  ...
  ($crc16, $size) = $crc16->peek;
  $crc16->add("string6", ...);
  ...
  ($crc16, $size) = $crc16->result;

  $crc16_1->addfile(\*file1);     # note: adding many files
  $crc16_1->addfile(\*file2);     # is probably a silly thing
  $crc16_1->addfile(\*file3);     # to do, but you *could*...
  ...

B<Functional style>:
  use Digest::CRC qw(crc16);

  $crc16 = crc16("string1", "string2", ...);

  ($crc16, $size) = crc16("string1", "string2", ...);

  $crc16 = crc16(\*FILE);

  ($crc16, $size) = crc16(\*FILE);

=head1 DESCRIPTION

The Digest::mhCRC module calculates a 16 bit CRC,

If called in a list context, returns the length of the data
object as well, which is useful for fully emulating
the cksum program. The returned crc16 will always be
a non-negative integral number in the range 0..2^16-1.

Despite its name, this module is able to compute the
crc16 of files as well as of strings.
Just pass in a reference to a filehandle,
or a reference to any object that can respond to
a read() call and eventually return 0 at "end of file".

Beware: consider proper use of binmode()
if you are on a non-UNIX platform
or processing files derived from other platforms.

The object oriented interface can be used
to progressively add data into the crc16
before yielding the result.

The functional interface is a convenient way
to get a crc16 of a single data item.

None of the routines make local copies of passed-in strings
so you can safely crc16 large strings safe in the knowledge
that there won't be any memory issues.

Passing in multiple files is acceptable,
but perhaps of questionable value.
However I don't want to hamper your creativity...

=head1 FUNCTIONS                                                        

The following functions are provided
by the "Digest::mhCRC" module.
None of these functions are exported by default.

=over 4

=item B<new()>

Creates a new Digest::mhCRC object
which is in a reset state, ready for action.
If passed an existing Digest::mhCRC object,
it takes only the class -
ie yields a fresh, reset object.

=item B<reset()>

Resets the mhCRC object to the intialized state.
An interesting phenomenom is,
the CRC is not zero but 0xFFFFFFFF
for a reset mhCRC object.
The returned size of a reset item will be zero.

=item B<add("string", ...)>

Progressively inject data into the mhCRC object
prior to requesting the final result.

=item B<addfile(\*FILE, ...)>

Progressively inject all (remaining) data from the file
into the mhCRC object prior to requesting the final result.
The file handle passed in
need only respond to the read() function to be usable,
so feel free to pass in IO handles as needed.
[hmmm - methinks I should have a test for that]

=item B<peek($)>

Yields the mhCRC crc16
(and optionally the total size in list context)
but does not reset the mhCRC object.
Repeated calls to peek() may be made
and more data may be added.

=item B<result($)>

Yields the crc16
(and optionally the total size in list context)
and then resets the mhCRC object.

=item B<crc16(@)>

A convenient functional interface
that may be passed a list of strings and filehandles.
It will instantiate a mhCRC object,
apply the data and return the result
in one swift, sweet operation.
See how much I'm looking after you?

NOTE: the filehandles must be passed as \*FD
because I'm detecting a file handle using the ref() function.
Therefore any blessed IO handle will also satisfy ref()
and be interpreted as a file handle.

=back

=head2 EXPORT

None by default.

=head1 SEE ALSO

manpages: cksum(1) or cksum(C) depending on your flavour of UNIX.

http://www.opengroup.org/onlinepubs/007904975/utilities/cksum.html

=head1 ORIGINAL AUTHOR

Andrew Hamm, E<lt>ahamm@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright disclaimed 2003 by Andrew Hamm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Since I collected the algorithm
from the Open Group web pages,
they might have some issues but I doubt it.
Let better legal minds than mine
determine the issues if you need.
[hopefully the CPAN and PAUSE administrators and/or testers
will understand the issues better,
and will replace this entire section
with something reasonable - hint hint.]

=cut
