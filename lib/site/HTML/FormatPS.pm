package HTML::FormatPS;

# $Id$

=head1 NAME

HTML::FormatPS - Format HTML as postscript

=head1 SYNOPSIS

  require HTML::FormatPS;
  $html = parse_htmlfile("test.html");
  $formatter = new HTML::FormatPS
		   FontFamily => 'Helvetica',
		   PaperSize  => 'Letter';
  print $formatter->format($html);

=head1 DESCRIPTION

The HTML::FormatPS is a formatter that outputs PostScript code.
Formatting of HTML tables and forms is not implemented.

You might specify the following parameters when constructing the formatter:

=over 4

=item PaperSize

What kind of paper should we format for.  The value can be one of
these: A3, A4, A5, B4, B5, Letter, Legal, Executive, Tabloid,
Statement, Folio, 10x14, Quarto.

The default is "A4".

=item PaperWidth

The width of the paper in points.  Setting PaperSize also defines this
value.

=item PaperHeight

The height of the paper in points.  Setting PaperSize also defines
this value.

=item LeftMargin

The left margin in points.

=item RightMargin

The right margin in points.

=item HorizontalMargin

Both left and right margin at the same time.  The default value is 4 cm.

=item TopMargin

The top margin in points.

=item BottomMargin

The bottom margin in points.

=item VerticalMargin

Both top and bottom margin at the same time.  The default value is 2 cm.

=item PageNo

The parameter determines if we should put page numbers on the pages.
The default is yes, so you have to set this value to 0 in order to
suppress page numbers.

=item FontFamily

The parameter specifies which family of fonts to use for the formatting.
Legal values are "Courier", "Helvetica" and "Times".  The default is
"Times".

=item FontScale

All fontsizes might be scaled by this factor.

=item Leading

How much space between lines.  This is a factor of the fontsize used
for that line.  Default is 0.1.

=back

=head1 SEE ALSO

L<HTML::Formatter>

=head1 COPYRIGHT

Copyright (c) 1995-1998 Gisle Aas. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Gisle Aas <aas@sn.no>

=cut

use Carp;
use strict;
use vars qw(@ISA $VERSION);

require HTML::Formatter;
@ISA = qw(HTML::Formatter);

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

use vars qw(%PaperSizes %FontFamilies @FontSizes %param $DEBUG);

# A few routines that convert lengths into points
sub mm { $_[0] * 72 / 25.4; }
sub in { $_[0] * 72; }

%PaperSizes =
(
 A3        => [mm(297), mm(420)],
 A4        => [mm(210), mm(297)],
 A5        => [mm(148), mm(210)],
 B4        => [729,     1032   ],
 B5        => [516,     729    ],
 Letter    => [in(8.5), in(11) ],
 Legal     => [in(8.5), in(14) ],
 Executive => [in(7.5), in(10) ],
 Tabloid   => [in(11),  in(17) ],
 Statement => [in(5.5), in(8.5)],
 Folio     => [in(8.5), in(13) ],
 "10x14"   => [in(10),  in(14) ],
 Quarto    => [610,     780    ],
);

%FontFamilies =
(
 Courier   => [qw(Courier
		  Courier-Bold
		  Courier-Oblique
		  Courier-BoldOblique)],

 Helvetica => [qw(Helvetica
		  Helvetica-Bold
		  Helvetica-Oblique
		  Helvetica-BoldOblique)],

 Times     => [qw(Times-Roman
		  Times-Bold
		  Times-Italic
		  Times-BoldItalic)],
);

      # size   0   1   2   3   4   5   6   7
@FontSizes = ( 5,  6,  8, 10, 12, 14, 18, 24, 32);

sub BOLD   { 0x01; }
sub ITALIC { 0x02; }

%param =
(
 papersize        => 'papersize',
 paperwidth       => 'paperwidth',
 paperheight      => 'paperheigth',
 leftmargin       => 'lmW',
 rightmargin      => 'rmW',
 horizontalmargin => 'mW',
 topmargin        => 'tmH',
 bottommargin     => 'bmH',
 verticalmargin   => 'mH',
 pageno           => 'printpageno',
 fontfamily       => 'family',
 fontscale        => 'fontscale',
 leading          => 'leading',
);


sub new
{
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
    
    $self;
}

sub default_values
{
    (
     family      => "Times",
     mH          => mm(40),
     mW          => mm(20),
     printpageno => 1,
     fontscale   => 1,
     leading     => 0.1,
     papersize   => 'A4',
     paperwidth  => mm(210),
     paperheight => mm(297),
    )
}

sub configure
{
    my($self, $hash) = @_;
    my($key,$val);
    while (($key, $val) = each %$hash) {
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
		$self->papersize($val) || croak "Unknown papersize ($val)";
		last;
	    };
	    $self->{$key} = lc $val;
	}
    }
}

sub papersize
{
    my($self, $val) = @_;
    $val = "\u\L$val";
    my($width, $height) = @{$PaperSizes{$val}};
    return 0 unless defined $width;
    $self->{papersize} = $val;
    $self->{paperwidth} = $width;
    $self->{paperheight} = $height;
    1;
}


sub fontsize
{
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

sub setfont
{
    my($self, $plain_with_size) = @_;
    my $index = 0;
    my $family = $self->{family} || 'Times';
    my $size = $plain_with_size;
    unless ($plain_with_size) {
	$index |= BOLD   if $self->{bold};
	$index |= ITALIC if $self->{italic} || $self->{underline};
	$family = 'Courier' if $self->{teletype};
	$size = $self->fontsize;
    }
    my $font = $FontFamilies{$family}[$index];
    my $font_with_size = "$font-$size";
    if ($self->{currentfont} eq $font_with_size) {
	return $self->{currentfontid};
    }
    $self->{currentfont} = $font_with_size;
    $self->{pointsize} = $size;
    my $fontmod = "Font::Metrics::$font";
    $fontmod =~ s/-//g;
    my $fontfile = $fontmod . ".pm";
    $fontfile =~ s,::,/,g;
    require $fontfile;
    {
	no strict 'refs';
	$self->{wx} = \@{ "${fontmod}::wx" };
    }
    $font = $self->{fonts}{$font_with_size} || do {
	my $fontID = "F" . ++$self->{fno};
	$self->{fonts}{$font_with_size} = $fontID;
	$fontID;
    };
    $self->{currentfontid} = $font;
    return $font;
}

# Construct PostScript code for setting the current font according 
# to $fontid, or an empty string if no font change is needed.
# Assumes the return string will always be output as PostScript if
# nonempty, so that our notion of the current PostScript font
# stays in sync with that of the PostScript interpreter.

sub switchfont
{
    my($self, $fontid) = @_;
    if ($self->{psfontid} eq $fontid) {
	return "";
    } else {
	$self->{psfontid} = $fontid;
	return "$fontid SF";
    }
}

# Like setfont + switchfont.

sub findfont
{
    my($self, $plain_with_size) = @_;
    return $self->switchfont($self->setfont($plain_with_size));
}

sub width
{
    my $self = shift;
    my $w = 0;
    my $wx = $self->{wx};
    my $sz = $self->{pointsize};
    for (unpack("C*", $_[0])) {
	$w += $wx->[$_] * $sz;
    }
    $w;
}


sub begin
{
    my $self = shift;
    $self->HTML::Formatter::begin;

    # Margins is points
    $self->{lm} = $self->{lmW} || $self->{mW};
    $self->{rm} = $self->{paperwidth}  - ($self->{rmW} || $self->{mW});
    $self->{tm} = $self->{paperheight} - ($self->{tmH} || $self->{mH});
    $self->{bm} = $self->{bmH} || $self->{mH};

    # Font setup
    $self->{fno} = 0;
    $self->{fonts} = {};
    $self->{en} = 0.55 * $self->fontsize(3);

    # Initial position
    $self->{xpos} = $self->{lm};  # top of the current line
    $self->{ypos} = $self->{tm};

    $self->{pageno} = 1;

    $self->{line} = "";
    $self->{showstring} = "";
    $self->{currentfont} = "";
    $self->{prev_currentfont} = "";
    $self->{largest_pointsize} = 0;

    $self->newpage;
}


sub end
{
    my $self = shift;
    $self->showline;
    $self->endpage if $self->{out};
    my $pages = $self->{pageno} - 1;

    my @prolog = ();
    push(@prolog, "%!PS-Adobe-3.0\n");
    #push(@prolog,"%%Title: No title\n"); # should look for the <title> element
    push(@prolog, "%%Creator: HTML::FormatPS (libwww-perl)\n");
    push(@prolog, "%%CreationDate: " . localtime() . "\n");
    push(@prolog, "%%Pages: $pages\n");
    push(@prolog, "%%PageOrder: Ascend\n");
    push(@prolog, "%%Orientation: Portrait\n");
    my($pw, $ph) = map { int($_); } @{$self}{qw(paperwidth paperheight)};

    push(@prolog, "%%DocumentMedia: Plain $pw $ph 0 white ()\n");
    push(@prolog, "%%DocumentNeededResources: \n");
    my($full, %seenfont);
    for $full (sort keys %{$self->{fonts}}) {
	$full =~ s/-\d+$//;
	next if $seenfont{$full}++;
	push(@prolog, "%%+ font $full\n");
    }
    push(@prolog, "%%DocumentSuppliedResources: procset newencode 1.0 0\n");
    push(@prolog, "%%+ encoding ISOLatin1Encoding\n");
    push(@prolog, "%%EndComments\n");
    push(@prolog, <<'EOT');

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

    push(@prolog, "\n%%BeginSetup\n");
    for $full (sort keys %{$self->{fonts}}) {
	my $short = $self->{fonts}{$full};
	$full =~ s/-(\d+)$//;
	my $size = $1;
	push(@prolog, "ISOLatin1Encoding/$full-ISO/$full NE\n");
	push(@prolog, "/$short/$full-ISO findfont $size scalefont def\n");
    }
    push(@prolog, "%%EndSetup\n");

    $self->collect("\n%%Trailer\n%%EOF\n");
    unshift(@{$self->{output}}, @prolog);
}


sub header_start
{
    my($self, $level, $node) = @_;
    # If we are close enough to be bottom of the page, start a new page
    # instead of this:
    $self->vspace(1 + (6-$level) * 0.4);
    $self->{bold}++;
    push(@{$self->{font_size}}, 8 - $level);
    1;
}


sub header_end
{
    my($self, $level, $node) = @_;
    $self->vspace(1);
    $self->{bold}--;
    pop(@{$self->{font_size}});
    1;
}

sub hr_start
{
    my $self = shift;
    $self->showline;
    $self->vspace(0.5);
    $self->skip_vspace;
    my $lm = $self->{lm};
    my $rm = $self->{rm};
    my $y = $self->{ypos};
    $self->collect(sprintf "newpath %.1f %.1f M %.1f %.1f lineto stroke\n",
		   $lm, $y, $rm, $y);
    $self->vspace(0.5);
}


sub skip_vspace
{
    my $self = shift;
    if (defined $self->{vspace}) {
	$self->showline;
	if ($self->{out}) {
	    $self->{ypos} -= $self->{vspace} * 10 * $self->{fontscale};
	    if ($self->{ypos} < $self->{bm}) {
		$self->newpage;
	    }
	}
	$self->{xpos} = $self->{lm};
	$self->{vspace} = undef;
	$self->{hspace} = undef;
    }
}


sub show
{
    my $self = shift;
    my $str = $self->{showstring};
    return unless length $str;
    $str =~ s/([\(\)\\])/\\$1/g;    # must escape parentesis
    $self->{line} .= "($str)S\n";
    $self->{showstring} = "";
}


sub showline
{
    my $self = shift;
    $self->show;
    my $line = $self->{line};
    return unless length $line;
    $self->{ypos} -= $self->{largest_pointsize} || $self->{pointsize};
    if ($self->{ypos} < $self->{bm}) {
	$self->newpage;
	$self->{ypos} -= $self->{pointsize};
	# must set current font again
	my $font = $self->{prev_currentfont};
	if ($font) {
	    $self->collect("$self->{fonts}{$font} SF\n");
	}
    }
    my $lm = $self->{lm};
    my $x = $lm;
    if ($self->{center}) {
	# Unfortunately, the center attribute is gone when we get here,
	# so this code is never activated
	my $linewidth = $self->{xpos} - $lm;
	$x += ($self->{rm} - $lm - $linewidth) / 2;
    }

    $self->collect(sprintf "%.1f %.1f M\n", $x, $self->{ypos});  # moveto
    $line =~ s/\s\)S$/)S/;  # many lines will end with space
    $self->collect($line);

    if ($self->{bullet}) {
	# Putting this behind the first line of the list item
	# makes it more likely that we get the right font.  We should
	# really set the font that we want to use.
	my $bullet = $self->{bullet};
	if ($bullet eq '*') {
	    # There is no character that is really suitable.  Lets make
	    # filled cirle ourself.
	    my $radius = $self->{pointsize} / 4;
	    $self->collect(sprintf "newpath %.1f %.1f %.1f 0 360 arc fill\n",
		       $self->{bullet_pos} + $radius,
		       $self->{ypos} + $radius, $radius);
	} else {
	    $self->collect(sprintf "%.1f %.1f M\n", # moveto
			   $self->{bullet_pos},
			   $self->{ypos});
	    $self->collect("($bullet)S\n");
	}
	$self->{bullet} = '';

    }

    $self->{prev_currentfont} = $self->{currentfont};
    $self->{largest_pointsize} = 0;
    $self->{line} = "";
    $self->{xpos} = $lm;
    # Additional linespacing
    $self->{ypos} -= $self->{leading} * $self->{pointsize};
}


sub endpage
{
    my $self = shift;
    # End previous page
    $self->collect("showpage\n");
    $self->{pageno}++;
}


sub newpage
{
    my $self = shift;
    if ($self->{'out'}) {
	$self->endpage;
    }
    $self->{'out'} = 0;
    my $pageno = $self->{pageno};
    $self->collect("\n%%Page: $pageno $pageno\n");

    # Print area marker (just for debugging)
    if ($DEBUG) {
	my($llx, $lly, $urx, $ury) = map { sprintf "%.1f", $_}
				     @{$self}{qw(lm bm rm tm)};
	$self->collect("gsave 0.1 setlinewidth\n");
	$self->collect("clippath 0.9 setgray fill 1 setgray\n");
	$self->collect("$llx $lly moveto $urx $lly lineto $urx $ury lineto $llx $ury lineto closepath fill\n");
	$self->collect("grestore\n");
    }

    # Print page number
    if ($self->{printpageno}) {
	$self->collect("%% Title and pageno\n");
	my $f = $self->findfont(8);
	$self->collect("$f\n") if $f;
        my $x = $self->{paperwidth};
        if ($x) { $x -= 30; } else { $x = 30; }
        $self->collect(sprintf "%.1f 30.0 M($pageno)S\n", $x);
	$x = $self->{lm};
	$self->collect(sprintf "%.1f 30.0 M($self->{title})S\n", $x);
    }
    $self->collect("\n");

    $self->{xpos} = $self->{lm};
    $self->{ypos} = $self->{tm};
}


sub out
{
    my($self, $text) = @_;
    if ($self->{collectingTheTitle}) {
        # Both collect and print the title
    	$text =~ s/([\(\)\\])/\\$1/g; # Escape parens.
        $self->{title} .= $text;
	return;
    }

    my $fontid = $self->setfont();
    my $w = $self->width($text);

    if ($text =~ /^\s*$/) {
        $self->{hspace} = [ " ", $fontid, $w ];
        return;
    }

    $self->skip_vspace;

    # determine spacing / line breaks needed before text
    if ($self->{hspace}) {
	my ($stext, $sfont, $swidth) = @{$self->{hspace}};
	if ($self->{xpos} + $swidth + $w > $self->{rm}) {
	    # line break
	    $self->showline;
	} else {
	    # no line break; output a space
            $self->show_with_font($stext, $sfont, $swidth);
	}
	$self->{hspace} = undef;
    }

    # output the text
    $self->show_with_font($text, $fontid, $w);
}


sub show_with_font {
    my ($self, $text, $fontid, $w) = @_;

    my $fontps = $self->switchfont($fontid);
    if (length $fontps) {
	$self->show;
	$self->{line} .= "$fontps\n";
    }

    $self->{xpos} += $w;
    $self->{showstring} .= $text;
    $self->{largest_pointsize} = $self->{pointsize}
      if $self->{largest_pointsize} < $self->{pointsize};
    $self->{'out'}++;
}


sub pre_out
{
    my($self, $text) = @_;
    $self->skip_vspace;
    $self->tt_start;
    my $font = $self->findfont();
    if (length $font) {
	$self->show;
	$self->{line} .= "$font\n";
    }
    while ($text =~ s/(.*)\n//) {
    	$self->{'out'}++;
	$self->{showstring} .= $1;
	$self->showline;
    }
    $self->{showstring} .= $text;
    $self->tt_end;
}

sub bullet
{
    my($self, $bullet) = @_;
    $self->{bullet} = $bullet;
    $self->{bullet_pos} = $self->{lm};
}

sub adjust_lm
{
    my $self = shift;
    $self->showline;
    $self->{lm} += $_[0] * $self->{en};
}


sub adjust_rm
{
    my $self = shift;
    $self->showline;
    $self->{rm} += $_[0] * $self->{en};
}

sub head_start {
    1;
}

sub head_end {
    1;
}

sub title_start {
    my($self) = @_;
    $self->{collectingTheTitle} = 1;
    1;
}

sub title_end {
    my($self) = @_;
    $self->{collectingTheTitle} = 0;
    1;
}

1;
