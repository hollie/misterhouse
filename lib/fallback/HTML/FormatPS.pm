package HTML::FormatPS;

# ABSTRACT: Format HTML as PostScript


use 5.008;
use strict;
use warnings;
use Carp;
use Encode;
use IO::File;
use utf8;    # for the is_utf8 function

use base 'HTML::Formatter';

our $VERSION = '2.14'; # VERSION
our $AUTHORITY = 'cpan:NIGELM'; # AUTHORITY

# We now use Smart::Comments in place of the old DEBUG framework.
# this should be commented out in release versions....
##use Smart::Comments;

# ------------------------------------------------------------------------
# A few routines that convert lengths into points
sub mm { $_[0] * 72 / 25.4; }
sub in { $_[0] * 72; }

# ------------------------------------------------------------------------
my %PaperSizes = (
    A3        => [ mm(297), mm(420) ],
    A4        => [ mm(210), mm(297) ],
    A5        => [ mm(148), mm(210) ],
    B4        => [ 729,     1032 ],
    B5        => [ 516,     729 ],
    Letter    => [ in(8.5), in(11) ],
    Legal     => [ in(8.5), in(14) ],
    Executive => [ in(7.5), in(10) ],
    Tabloid   => [ in(11),  in(17) ],
    Statement => [ in(5.5), in(8.5) ],
    Folio     => [ in(8.5), in(13) ],
    "10x14"   => [ in(10),  in(14) ],
    Quarto    => [ 610,     780 ],
);

# ------------------------------------------------------------------------
my %FontFamilies = (
    Courier => [
        qw(Courier
            Courier-Bold
            Courier-Oblique
            Courier-BoldOblique)
    ],

    Helvetica => [
        qw(Helvetica
            Helvetica-Bold
            Helvetica-Oblique
            Helvetica-BoldOblique)
    ],

    Times => [
        qw(Times-Roman
            Times-Bold
            Times-Italic
            Times-BoldItalic)
    ],
);

# ------------------------------------------------------------------------
# size            0  1  2  3   4   5   6   7   8
my @FontSizes = ( 5, 6, 8, 10, 12, 14, 18, 24, 32 );

sub BOLD   { 0x01; }
sub ITALIC { 0x02; }

my %param = (
    papersize        => 'papersize',
    paperwidth       => 'paperwidth',
    paperheight      => 'paperheigth',
    leftmargin       => 'lmW',
    rightmargin      => 'rmW',
    horizontalmargin => 'mW',
    topmargin        => 'tmH',
    bottommargin     => 'bmH',
    verticalmargin   => 'mH',
    no_prolog        => 'no_prolog',
    no_trailer       => 'no_trailer',
    pageno           => 'printpageno',
    startpage        => 'startpage',
    fontfamily       => 'family',
    fontscale        => 'fontscale',
    leading          => 'leading',
);

# ------------------------------------------------------------------------


sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    # Obtained from the <title> element
    $self->{title} = "";

    # The font ID last sent to the PostScript output (this may be
    # temporarily different from the "current font" as read from
    # the HTML input).  Initially none.
    $self->{psfontid} = "";

    # Pending horizontal space.  A list [ " ", $fontid, $width ],
    # or undef if no space is pending.
    $self->{hspace} = undef;

    # add an encoder object for perl native to Latin1 output
    $self->{encoder} = find_encoding('iso-8859-1');

    $self;
}

# ------------------------------------------------------------------------
sub default_values {
    (   shift->SUPER::default_values(),

        family      => "Times",
        mH          => mm(40),
        mW          => mm(20),
        printpageno => 1,
        startpage   => 1,         # yes, you can start numbering at 10, or whatever.
        fontscale   => 1,
        leading     => 0.1,
        papersize   => 'A4',
        paperwidth  => mm(210),
        paperheight => mm(297),
    );
}

# ------------------------------------------------------------------------
sub configure {
    my ( $self, $hash ) = @_;

    my ( $key, $val );
    while ( ( $key, $val ) = each %$hash ) {
        $key = lc $key;
        croak "Illegal parameter ($key => $val)" unless exists $param{$key};
        $key = $param{$key};
        {
            $key eq "family" && do {
                $val = "\u\L$val";
                croak "Unknown font family ($val)"
                    unless exists $FontFamilies{$val};
                $self->{family} = $val;
                last;
            };
            $key eq "papersize" && do {
                $self->papersize($val)
                    || croak sprintf "Unknown papersize '%s'.\nThe knowns are: %s.\nAborting",
                    $val,
                    join( ', ', sort keys %PaperSizes );
                last;
            };
            $self->{$key} = lc $val;
        }
    }
}

# ------------------------------------------------------------------------
sub papersize {
    my ( $self, $val ) = @_;

    $val = "\u\L$val";
    my ( $width, $height ) = @{ $PaperSizes{$val} || return 0 };
    return 0 unless defined $width;
    $self->{papersize}   = $val;
    $self->{paperwidth}  = $width;
    $self->{paperheight} = $height;
    1;
}

# ------------------------------------------------------------------------
sub fontsize {
    my $self = shift;

    my $size = $self->{font_size}[-1];
    $size = 8 if $size > 8;
    $size = 3 if $size < 0;
    $FontSizes[$size] * $self->{fontscale};
}

# Determine the current font and set font-related members.
# If $plain_with_size is given (a number), use a plain font
# of that size.  Otherwise, use the font specified by the
# HTML context.  Returns the "font ID" of the current font.

# ------------------------------------------------------------------------
sub setfont {
    my ( $self, $plain_with_size ) = @_;

    my $index  = 0;
    my $family = $self->{family} || 'Times';
    my $size   = $plain_with_size;
    unless ($plain_with_size) {
        $index |= BOLD if $self->{bold};
        $index |= ITALIC if $self->{italic} || $self->{underline};
        $family = 'Courier' if $self->{teletype};
        $size = $self->fontsize;
    }
    my $font           = $FontFamilies{$family}[$index];
    my $font_with_size = "$font-$size";
    if ( $self->{currentfont} eq $font_with_size ) {
        return $self->{currentfontid};
    }
    $self->{currentfont} = $font_with_size;
    $self->{pointsize}   = $size;
    my $fontmod = "Font::Metrics::$font";
    $fontmod =~ s/-//g;
    my $fontfile = $fontmod . ".pm";
    $fontfile =~ s,::,/,g;
    require $fontfile;
    {
        ## no critic
        no strict 'refs';
        $self->{wx} = \@{"${fontmod}::wx"};
        ## use critic
    }
    $font = $self->{fonts}{$font_with_size} || do {
        my $fontID = "F" . ++$self->{fno};
        $self->{fonts}{$font_with_size} = $fontID;
        $fontID;
    };
    $self->{currentfontid} = $font;
    return $font;
}

# ------------------------------------------------------------------------
# Construct PostScript code for setting the current font according
# to $fontid, or an empty string if no font change is needed.
# Assumes the return string will always be output as PostScript if
# nonempty, so that our notion of the current PostScript font
# stays in sync with that of the PostScript interpreter.
#
sub switchfont {
    my ( $self, $fontid ) = @_;

    if ( $self->{psfontid} eq $fontid ) {
        return "";
    }
    else {
        $self->{psfontid} = $fontid;
        return "$fontid SF";
    }
}

# ------------------------------------------------------------------------
# Like setfont + switchfont.
sub findfont {
    my ( $self, $plain_with_size ) = @_;

    return $self->switchfont( $self->setfont($plain_with_size) );
}

# ------------------------------------------------------------------------
sub width {
    my $self = shift;
    my $str  = shift;

    my $w  = 0;
    my $wx = $self->{wx};
    my $sz = $self->{pointsize};

    # need to encode to same encoding as font before getting width
    for ( unpack( "C*", $self->encode_string($str) ) ) {

        # if the character is outside the table, assume its m sized
        $w += ( ( $_ > $#{$wx} ) ? $wx->[ ord('m') ] : $wx->[$_] ) * $sz    # unless  $_ eq 0xAD; # optional hyphen
    }
    $w;
}

# ------------------------------------------------------------------------
sub begin {
    my $self = shift;

    $self->SUPER::begin;

    # Margins are in points
    $self->{lm} = $self->{lmW} || $self->{mW};
    $self->{rm} = $self->{paperwidth} -  ( $self->{rmW} || $self->{mW} );
    $self->{tm} = $self->{paperheight} - ( $self->{tmH} || $self->{mH} );
    $self->{bm} = $self->{bmH} || $self->{mH};

    $self->{'orig_margins'} =    # used only by the debug-mode print-area marker
        [ map { sprintf "%.1f", $_ } @{$self}{qw(lm bm rm tm)} ];

    # Font setup
    $self->{fno}   = 0;
    $self->{fonts} = {};
    $self->{en}    = 0.55 * $self->fontsize(3);

    # Initial position
    $self->{xpos} = $self->{lm};    # top of the current line
    $self->{ypos} = $self->{tm};

    $self->{pageno}              = 1;
    $self->{visible_page_number} = $self->{startpage};

    $self->{line}              = "";
    $self->{showstring}        = "";
    $self->{currentfont}       = "";
    $self->{prev_currentfont}  = "";
    $self->{largest_pointsize} = 0;

    $self->newpage;
}

# ------------------------------------------------------------------------
sub end {
    my $self = shift;

    $self->showline;
    $self->endpage if $self->{'out'};
    my $pages = $self->{pageno} - 1;

    my @prolog = ();
    push( @prolog, "%!PS-Adobe-3.0\n" );

    #push(@prolog,"%%Title: No title\n"); # should look for the <title> element
    push( @prolog, "%%Creator: " . $self->version_tag . "\n" );
    push( @prolog, "%%CreationDate: " . localtime() . "\n" );
    push( @prolog, "%%Pages: $pages\n" );
    push( @prolog, "%%PageOrder: Ascend\n" );
    push( @prolog, "%%Orientation: Portrait\n" );
    my ( $pw, $ph ) = map { int($_); } @{$self}{qw(paperwidth paperheight)};

    push( @prolog, "%%DocumentMedia: Plain $pw $ph 0 white ()\n" );
    push( @prolog, "%%DocumentNeededResources: \n" );
    my %seenfont;
    for my $full ( sort keys %{ $self->{fonts} } ) {
        $full =~ s/-\d+$//;
        next if $seenfont{$full}++;
        push( @prolog, "%%+ font $full\n" );
    }
    push( @prolog, "%%DocumentSuppliedResources: procset newencode 1.0 0\n" );
    push( @prolog, "%%+ encoding ISOLatin1Encoding\n" );
    push( @prolog, "%%EndComments\n" );
    push( @prolog, <<'EOT');

%%BeginProlog
/S/show load def
/M/moveto load def
/SF/setfont load def

%%BeginResource: encoding ISOLatin1Encoding
systemdict /ISOLatin1Encoding known not {
    /ISOLatin1Encoding [
    /space /space /space /space /space /space /space /space
    /space /space /space /space /space /space /space /space
    /space /space /space /space /space /space /space /space
    /space /space /space /space /space /space /space /space

    /space /exclam /quotedbl /numbersign /dollar /percent /ampersand
        /quoteright
    /parenleft /parenright /asterisk /plus /comma /minus /period /slash
    /zero /one /two /three /four /five /six /seven
    /eight /nine /colon /semicolon /less /equal /greater /question
    /at /A /B /C /D /E /F /G
    /H /I /J /K /L /M /N /O
    /P /Q /R /S /T /U /V /W
    /X /Y /Z /bracketleft /backslash /bracketright /asciicircum /underscore
    /quoteleft /a /b /c /d /e /f /g
    /h /i /j /k /l /m /n /o
    /p /q /r /s /t /u /v /w
    /x /y /z /braceleft /bar /braceright /asciitilde /space

    /space /space /space /space /space /space /space /space
    /space /space /space /space /space /space /space /space
    /dotlessi /grave /acute /circumflex /tilde /macron /breve /dotaccent
    /dieresis /space /ring /cedilla /space /hungarumlaut /ogonek /caron

    /space /exclamdown /cent /sterling /currency /yen /brokenbar /section
    /dieresis /copyright /ordfeminine /guillemotleft /logicalnot /hyphen
        /registered /macron
    /degree /plusminus /twosuperior /threesuperior /acute /mu /paragraph
        /periodcentered
    /cedillar /onesuperior /ordmasculine /guillemotright /onequarter
        /onehalf /threequarters /questiondown
    /Agrave /Aacute /Acircumflex /Atilde /Adieresis /Aring /AE /Ccedilla
    /Egrave /Eacute /Ecircumflex /Edieresis /Igrave /Iacute /Icircumflex
        /Idieresis
    /Eth /Ntilde /Ograve /Oacute /Ocircumflex /Otilde /Odieresis /multiply
    /Oslash /Ugrave /Uacute /Ucircumflex /Udieresis /Yacute /Thorn
        /germandbls
    /agrave /aacute /acircumflex /atilde /adieresis /aring /ae /ccedilla
    /egrave /eacute /ecircumflex /edieresis /igrave /iacute /icircumflex
        /idieresis
    /eth /ntilde /ograve /oacute /ocircumflex /otilde /odieresis /divide
    /oslash /ugrave /uacute /ucircumflex /udieresis /yacute /thorn
        /ydieresis
    ] def
} if
%%EndResource
%%BeginResource: procset newencode 1.0 0
/NE { %def
   findfont begin
      currentdict dup length dict begin
     { %forall
        1 index/FID ne {def} {pop pop} ifelse
     } forall
     /FontName exch def
     /Encoding exch def
     currentdict dup
      end
   end
   /FontName get exch definefont pop
} bind def
%%EndResource
%%EndProlog
EOT

    push( @prolog, "\n%%BeginSetup\n" );
    for my $full ( sort keys %{ $self->{fonts} } ) {
        my $short = $self->{fonts}{$full};
        $full =~ s/-(\d+)$//;
        my $size = $1;
        push( @prolog, "ISOLatin1Encoding/$full-ISO/$full NE\n" );
        push( @prolog, "/$short/$full-ISO findfont $size scalefont def\n" );
    }
    push( @prolog, "%%EndSetup\n" );

    $self->collect("\n%%Trailer\n%%EOF\n")
        unless $self->{'no_trailer'};

    unshift( @{ $self->{output} }, @prolog )
        unless $self->{'no_prolog'};
}

# ------------------------------------------------------------------------
sub header_start {
    my ( $self, $level ) = @_;

    # If we are close enough to be bottom of the page, start a new page
    # instead of this:
    ### Heading of level: $level
    $self->vspace( 1 + ( 6 - $level ) * 0.4 );
    $self->{bold}++;
    push( @{ $self->{font_size} }, 8 - $level );
    1;
}

# ------------------------------------------------------------------------
sub header_end {
    my ($self) = @_;

    $self->vspace(1);
    $self->{bold}--;
    pop( @{ $self->{font_size} } );
    1;
}

# ------------------------------------------------------------------------
sub hr_start {
    my $self = shift;

    ### Making an HR...
    $self->showline;
    $self->vspace(0.5);
    $self->skip_vspace;
    my $lm = $self->{lm};
    my $rm = $self->{rm};
    my $y  = $self->{ypos};
    $self->collect( sprintf "newpath %.1f %.1f M %.1f %.1f lineto stroke\n", $lm, $y, $rm, $y );
    $self->vspace(0.5);
}

# ------------------------------------------------------------------------
sub skip_vspace {
    my $self = shift;

    ### Skipping some amount of vspace...
    if ( defined $self->{vspace} ) {
        $self->showline;
        if ( $self->{'out'} ) {
            $self->{ypos} -= $self->{vspace} * 10 * $self->{fontscale};

            if ( $self->{ypos} < $self->{bm} ) {
                ### vspace skip forced new page...
                $self->newpage;
            }
            else {
                ### Skipped vspace making y: $self->{'ypos'},
            }
        }
        else {
            ### Not skipping vspace as out is false: $self->{ypos}
        }
        $self->{xpos}   = $self->{lm};
        $self->{vspace} = undef;
        $self->{hspace} = undef;
    }
    else {
        ### No vspace to skip...
    }

    return;
}

# ------------------------------------------------------------------------
sub show {
    my $self = shift;

    my $str = $self->{showstring};
    $str =~ tr/\x01//d;
    return unless length $str;

    # must escape parentheses and backslash
    $str =~ s/([\(\)\\])/\\$1/g;

    # encode output to latin1 when pushing it out
    $self->{line} .= "(" . $self->encode_string($str) . ")S\n";
    $self->{showstring} = "";
}

# ------------------------------------------------------------------------
sub showline {
    my $self = shift;

    $self->show;
    my $line = $self->{line};
    unless ( length $line ) {
        ### Showline is a no-op because line buffer is empty...
        return;
    }

    ### Showline emitting: $line

    $self->{ypos} -= $self->{largest_pointsize} || $self->{pointsize};
    if ( $self->{ypos} < $self->{bm} ) {
        ### Showline forcing new page...
        $self->newpage;

        # newpage might alter currentfont!
        ### Showline sets vspace: $self->{vspace} || 0

        $self->{ypos} -= $self->{pointsize};
        #### Showline/Newpage x: $self->{xpos}
        #### Showline/Newpage y: $self->{ypos}

        # must set current font again
        my $font = $self->{prev_currentfont};
        if ($font) {
            $self->collect("$self->{fonts}{$font} SF\n\n");
        }

        ### End of doing newpage...
    }

    my $lm = $self->{lm};
    my $x  = $lm;
    if ( $self->{center} ) {

        # Unfortunately, the center attribute is gone when we get here,
        # so this code is never activated
        my $linewidth = $self->{xpos} - $lm;
        $x += ( $self->{rm} - $lm - $linewidth ) / 2;
    }

    $self->collect( sprintf "%.1f %.1f M\n", $x, $self->{ypos} );    # moveto
    $line =~ s/\s\)S$/)S/;                                           # many lines will end uselessly with space
    $self->collect($line);
    $self->{'out'}++;

    if ( $self->{bullet} ) {

        # Putting this behind the first line of the list item
        # makes it more likely that we get the right font.  We should
        # really set the font that we want to use.
        my $bullet = $self->{bullet};
        if ( $bullet eq '*' ) {

            # There is no character that is really suitable.  Let's make
            # a medium-sized filled circle ourself.
            my $radius = $self->{pointsize} / 8;
            ### Adding code for a '*' bullet for that line...

            $self->collect(
                sprintf "newpath %.1f %.1f %.1f 0 360 arc fill\n",
                $self->{bullet_pos} + $radius,
                $self->{ypos} + $radius * 2, $radius,
            );
        }
        else {
            ### Adding code for other bullet for that line...

            $self->collect(
                sprintf "%.1f (%s) stringwidth pop sub %.1f add %.1f M\n",    # moveto
                $self->{bullet_pos},
                $bullet,
                $self->{pointsize} * 0.62,
                $self->{ypos},
            );
            $self->collect("($bullet)S\n");
        }
        $self->{bullet} = '';

    }

    $self->{prev_currentfont}  = $self->{currentfont};
    $self->{largest_pointsize} = 0;
    $self->{line}              = "";
    $self->{xpos}              = $lm;

    # Additional linespacing

    $self->{ypos} -= $self->{leading} * $self->{pointsize};
    #### Showline/end x: $self->{xpos}
    #### Showline/end y: $self->{ypos}

    return;
}

# ------------------------------------------------------------------------
sub endpage {
    my $self = shift;

    ### End page: $self->{pageno}
    # End previous page
    $self->collect("showpage\n");
    $self->{visible_page_number}++;
    $self->{pageno}++;
}

# ------------------------------------------------------------------------
sub newpage {
    my $self = shift;

    local $self->{'pointsize'} = $self->{'pointsize'};

    # That's needed for protecting against one bit of the
    # potential side-effects from page-numbering code

    if ( $self->{'out'} ) {    # whether we've sent anything to the current page so far.
        ### Newpage calls endpage...
        $self->endpage;
        $self->collect( sprintf "%% %s has sent %s write-events to the above page.\n", ref($self), $self->{'out'}, );
    }

    $self->{'out'} = 0;
    my $pageno              = $self->{pageno};
    my $visible_page_number = $self->{visible_page_number};

    $self->collect("\n%%Page: $pageno $pageno\n");
    ### Starting page: $pageno

    # Print page number
    if ( $self->{printpageno} ) {
        ### Printing page number: $visible_page_number
        $self->collect("%% Title and pageno\n");
        my $f = $self->findfont(8);
        $self->collect("$f\n") if $f;
        my $x = $self->{paperwidth};
        if ($x) { $x -= 30; }
        else    { $x = 30; }
        $self->collect( sprintf "%.1f 30.0 M($visible_page_number)S\n", $x );
        $x = $self->{lm};
        $self->{title} =~ tr/\x01//d;
        $self->collect( sprintf "%.1f 30.0 M($self->{title})S\n", $x );
    }
    else {
        ### Pointedly not printing page number...
    }
    $self->collect("\n");

    $self->{xpos} = $self->{lm};
    $self->{ypos} = $self->{tm};
    #### Newpage/end x: $self->{xpos}
    #### Newpage/end y: $self->{ypos}
}

# ------------------------------------------------------------------------
sub encode_string {    # converts string into latin1 charset
    my ( $self, $str ) = @_;

    # the string from the parser is normally unicode, and may contain
    # some punctuation characters in the 'General Punctuation' block
    # which can be expressed in latin1, but Encode module fails on them
    # so we will manually hack these...
    # Theres no usable latin1 for the double quote chars so map to "
    if ( utf8::is_utf8($str) ) {
        $str =~ tr/\x{2018}\x{2019}\x{201A}\x{201C}\x{201D}\x{201F}\x{2033}\x{2036}/`',"""""/;
    }

    return $self->{encoder}->encode($str);
}

# ------------------------------------------------------------------------
sub out {    # Output a word
    my ( $self, $text ) = @_;

    $text =~ tr/\xA0\xAD/ /d;
    ### Trapping new word: $text

    if ( $self->{collectingTheTitle} ) {

        # Both collect and print the title
        $text =~ s/([\(\)\\])/\\$1/g;    # Escape parens and the backslash
        $self->{title} .= $text;
        return;
    }

    my $fontid = $self->setfont();
    my $w      = $self->width($text);

    if ( $text =~ /^\s*$/ ) {
        $self->{hspace} = [ " ", $fontid, $w ];
        return;
    }

    $self->skip_vspace;

    # determine spacing / line breaks needed before text
    if ( $self->{hspace} ) {
        my ( $stext, $sfont, $swidth ) = @{ $self->{hspace} };
        if ( $self->{xpos} + $swidth + $w > $self->{rm} ) {

            # line break
            $self->showline;
        }
        else {

            # no line break; output a space
            $self->show_with_font( $stext, $sfont, $swidth );
        }
        $self->{hspace} = undef;
    }

    # output the text
    $self->show_with_font( $text, $fontid, $w );
}

# ------------------------------------------------------------------------
sub show_with_font {
    my ( $self, $text, $fontid, $w ) = @_;

    my $fontps = $self->switchfont($fontid);
    if ( length $fontps ) {
        $self->show;
        $self->{line} .= "$fontps\n";
    }

    $self->{xpos} += $w;
    $self->{showstring} .= $text;

    #### Append to string buffer: $text
    #### with font: $fontid
    #### with xpos: $self->{xpos}

    $self->{largest_pointsize} = $self->{pointsize}
        if $self->{largest_pointsize} < $self->{pointsize};
    $self->{'out'}++;
}

# ------------------------------------------------------------------------
sub pre_out {
    my ( $self, $text ) = @_;

    $self->skip_vspace;
    $self->tt_start;
    my $font = $self->findfont();
    if ( length $font ) {
        $self->show;
        $self->{line} .= "$font\n";
    }
    while ( $text =~ s/(.*)\n// ) {
        $self->{'out'}++;
        $self->{showstring} .= $1;
        $self->showline;
    }
    $self->{showstring} .= $text;
    $self->tt_end;
    1;
}

# ------------------------------------------------------------------------
sub bullet {
    my ( $self, $bullet ) = @_;

    $self->{bullet}     = $bullet;
    $self->{bullet_pos} = $self->{lm};
}

# ------------------------------------------------------------------------
sub adjust_lm {
    my $self = shift;

    $self->showline;

    $self->{lm} += $_[0] * $self->{en};
    1;
}

# ------------------------------------------------------------------------
sub adjust_rm {
    my $self = shift;

    $self->showline;

    $self->{rm} += $_[0] * $self->{en};
}

# ------------------------------------------------------------------------
sub head_start { 1; }
sub head_end   { 1; }

sub title_start {
    my ($self) = @_;

    $self->{collectingTheTitle} = 1;
    1;
}

sub title_end {
    my ($self) = @_;

    $self->{collectingTheTitle} = 0;
    1;
}

# ------------------------------------------------------------------------
my ( $counter, $last_state_filename );

# For use in circumstances of total desperation:

sub dump_state {
    my $self = shift;
    require Data::Dumper;

    ++$counter;
    my $filename = sprintf( "state%04d.txt", $counter );
    my $state = IO::File->new( $filename, 'w' ) or die "Can't write-open $filename: $!";
    $state->printf( "%s line %s\n", ( caller(1) )[ 3, 2 ] );
    {
        local ( $self->{'wx'} )     = '<SUPPRESSED>';
        local ( $self->{'output'} ) = '<SUPPRESSED>';
        $state->print( Data::Dumper::Dumper($self) );
    }
    $state->close;
    sleep 0;

    if ($last_state_filename) {
        system("perl -S diff.bat $last_state_filename $filename > $filename.diff");
    }

    $last_state_filename = $filename;
    return 1;
}

# ------------------------------------------------------------------------


1;

__END__

=pod

=for test_synopsis 1;
__END__

=for stopwords bottommargin fontfamily fontscale helvetica
    horizontalmargin leftmargin noprolog notrailer pageno
    paperheight papersize paperwidth postscript rightmargin
    startpage topmargin verticalmargin ledding leeding prolog
    CPAN Quarto Tabloid Unicode homepage

=head1 NAME

HTML::FormatPS - Format HTML as PostScript

=head1 VERSION

version 2.14

=head1 SYNOPSIS

    use HTML::TreeBuilder;
    $tree = HTML::TreeBuilder->new->parse_file("test.html");

    use HTML::FormatPS;
    $formatter = HTML::FormatPS->new(
        FontFamily => 'Helvetica',
        PaperSize  => 'Letter',
    );
    print $formatter->format($tree);

Or, for short:

    use HTML::FormatPS;
    print HTML::FormatPS->format_file(
        "test.html",
        'FontFamily' => 'Helvetica',
        'PaperSize'  => 'Letter',
    );

=head1 DESCRIPTION

The HTML::FormatPS is a formatter that outputs PostScript code. Formatting of
HTML tables and forms is not implemented.

HTML::FormatPS is built on top of L<HTML::Formatter> and so further detail may
be found in the documentation for L<HTML::Formatter>.

You might specify the following parameters when constructing the formatter
object (or when calling format_file or format_string):

=over 4

=item PaperSize

What kind of paper should we format for.  The value can be one of these: A3,
A4, A5, B4, B5, Letter, Legal, Executive, Tabloid, Statement, Folio, 10x14,
Quarto.

The default is "A4".

=item PaperWidth

The width of the paper, in points.  Setting PaperSize also defines this value.

=item PaperHeight

The height of the paper, in points.  Setting PaperSize also defines this value.

=item LeftMargin

The left margin, in points.

=item RightMargin

The right margin, in points.

=item HorizontalMargin

Both left and right margin at the same time.  The default value is 4 cm.

=item TopMargin

The top margin, in points.

=item BottomMargin

The bottom margin, in points.

=item VerticalMargin

Both top and bottom margin at the same time.  The default value is 2 cm,

=item PageNo

This parameter determines if we should put page numbers on the pages. The
default value is true; so you have to set this value to 0 in order to suppress
page numbers.  (The "No" in "PageNo" means number/numero!)

=item FontFamily

This parameter specifies which family of fonts to use for the formatting. Legal
values are "Courier", "Helvetica" and "Times".  The default is "Times".

=item FontScale

This is a scaling factor for all the font sizes.  The default value is 1.

For example, if you want everything to be almost three times as large, you
could set this to 2.7.  If you wanted things just a bit smaller than normal,
you could set it to .92.

=item Leading

This option (pronounced "ledding", not "leeding") controls how much is space
between lines. This is a factor of the font size used for that line.  Default
is 0.1 -- so between two 12-point lines, there will be 1.2 points of space.

=item StartPage

Assuming you have PageNo on, StartPage controls what the page number of the
first page will be. By default, it is 1. So if you set this to 87, the first
page would say "87" on it, the next "88", and so on.

=item NoProlog

If this option is set to a true value, HTML::FormatPS will make a point of
I<not> emitting the PostScript prolog before the document. By default, this is
off, meaning that HTML::FormatPS I<will> emit the prolog. This option is of
interest only to advanced users.

=item NoTrailer

If this option is set to a true value, HTML::FormatPS will make a point of
I<not> emitting the PostScript trailer at the end of the document. By default,
this is off, meaning that HTML::FormatPS I<will> emit the bit of PostScript
that ends the document. This option is of interest only to advanced users.

=back

=head1 METHODS

=head2 new

    my $formatter = FormatterClass->new(
        option1 => value1, option2 => value2, ...
    );

This creates a new formatter object with the given options.

=head1 SEE ALSO

L<HTML::Formatter>

=head1 ISSUES

=over

=item *

Output is in ISO Latin1 format. The underlying HTML parsers tend to now work in
Unicode (perl native) code points. There is an impedance mismatch between
these, which may give issues with complex characters within HTML.

=back

=head1 TO DO

=over

=item *

Support for some more character styles, notably including: strike-through,
underlining, superscript, and subscript.

=item *

Support for Unicode.

=item *

Support for Win-1252 encoding, since that's what most people mean when they use
characters in the range 0x80-0x9F in HTML.

=item *

And, if it's ever even reasonably possible, support for tables.

=back

I would welcome email from people who can help me out or advise me on the
above.

=head1 INSTALLATION

See perlmodinstall for information and options on installing Perl modules.

=head1 BUGS AND LIMITATIONS

You can make new bug reports, and view existing ones, through the
web interface at L<http://rt.cpan.org/Public/Dist/Display.html?Name=HTML-Formatter>.

=head1 AVAILABILITY

The project homepage is L<https://metacpan.org/release/HTML-Formatter>.

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see L<https://metacpan.org/module/HTML::Formatter/>.

=head1 AUTHORS

=over 4

=item *

Nigel Metheringham <nigelm@cpan.org>

=item *

Sean M Burke <sburke@cpan.org>

=item *

Gisle Aas <gisle@ActiveState.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Nigel Metheringham, 2002-2005 Sean M Burke, 1999-2002 Gisle Aas.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
