package HTML::FormatRTF;

# ABSTRACT: Format HTML as RTF


use 5.006_001;
use strict;
use warnings;

# We now use Smart::Comments in place of the old DEBUG framework.
# this should be commented out in release versions....
##use Smart::Comments;

use base 'HTML::Formatter';

our $VERSION = '2.14'; # VERSION
our $AUTHORITY = 'cpan:NIGELM'; # AUTHORITY

# ------------------------------------------------------------------------
my %Escape = (
    map( ( chr($_), chr($_) ),    # things not apparently needing escaping
        0x20 .. 0x7E ),
    map( ( chr($_), sprintf( "\\'%02x", $_ ) ),    # apparently escapeworthy things
        0x00 .. 0x1F, 0x5c, 0x7b, 0x7d, 0x7f .. 0xFF, 0x46 ),

    # We get to escape out 'F' so that we can send RTF files thru the mail
    # without the slightest worry that paragraphs beginning with "From"
    # will get munged.

    # And some refinements:
    #"\n"   => "\n\\line ",
    #"\cm"  => "\n\\line ",
    #"\cj"  => "\n\\line ",

    "\t" => "\\tab ",    # Tabs (altho theoretically raw \t's are okay)

    # "\f"   => "\n\\page\n", # Formfeed
    "-"    => "\\_",     # Turn plaintext '-' into a non-breaking hyphen
    "\xA0" => "\\~",     # Latin-1 non-breaking space
    "\xAD" => "\\-",     # Latin-1 soft (optional) hyphen

    # CRAZY HACKS:
    "\n" => "\\line\n",
    "\r" => "\n",

    # "\cb" => "{\n\\cs21\\lang1024\\noproof ",  # \\cf1
    # "\cc" => "}",
);

# ------------------------------------------------------------------------
sub default_values {
    (   shift->SUPER::default_values(),
        'lm' => 0,    # left margin
        'rm' => 0,    # right margin (actually, maximum text width)

        'head1_halfpoint_size'     => 32,
        'head2_halfpoint_size'     => 28,
        'head3_halfpoint_size'     => 25,
        'head4_halfpoint_size'     => 22,
        'head5_halfpoint_size'     => 20,
        'head6_halfpoint_size'     => 18,
        'codeblock_halfpoint_size' => 18,
        'header_halfpoint_size'    => 17,
        'normal_halfpoint_size'    => 22,
    );
}

# ------------------------------------------------------------------------
sub configure {
    my ( $self, $hash ) = shift;

    $self->{lm} = 0;
    $self->{rm} = 0;

    # include the hash parameters into self - as RT#56278
    map { $self->{$_} = $hash->{$_} } keys %$hash if ( ref($hash) );
    $self;
}

# ------------------------------------------------------------------------
sub begin {
    my $self = shift;

    ### Start document...
    $self->SUPER::begin;

    $self->collect( $self->doc_init, $self->font_table, $self->stylesheet, $self->color_table, $self->doc_info,
        $self->doc_really_start, "\n" )
        unless $self->{'no_prolog'};

    $self->{'Para'}       = '';
    $self->{'quotelevel'} = 0;

    return;
}

# ------------------------------------------------------------------------
sub end {
    my $self = shift;

    $self->vspace(0);
    $self->out('THIS IS NEVER SEEN');

    # just to force the previous para to be written out.
    $self->collect("}") unless $self->{'no_trailer'};    # ends the document

    ### End document...
    return;
}

# ------------------------------------------------------------------------
sub vspace {
    my $self = shift;

    #$self->emit_para if defined $self->{'vspace'};
    my $rv = $self->SUPER::vspace(@_);
    $self->emit_para if defined $self->{'vspace'};
    $rv;
}

# ------------------------------------------------------------------------
sub stylesheet {

    # TODO: maybe actually /use/ the character styles?

    return sprintf <<'END',    # snazzy styles
{\stylesheet
{\snext0 Normal;}
{\*\cs1 \additive Default Paragraph Font;}
{\*\cs2 \additive \i\sbasedon1 html-ital;}
{\*\cs3 \additive \b\sbasedon1 html-bold;}
{\*\cs4 \additive \f1\sbasedon1 html-code;}

{\s20\ql \f1\fs%s\lang1024\noproof\sbasedon0 \snext0 html-pre;}

{\s31\ql \keepn\sb90\sa180\f2\fs%s\ul\sbasedon0 \snext0 html-head1;}
{\s32\ql \keepn\sb90\sa180\f2\fs%s\ul\sbasedon0 \snext0 html-head2;}
{\s33\ql \keepn\sb90\sa180\f2\fs%s\ul\sbasedon0 \snext0 html-head3;}
{\s34\ql \keepn\sb90\sa180\f2\fs%s\ul\sbasedon0 \snext0 html-head4;}
{\s35\ql \keepn\sb90\sa180\f2\fs%s\ul\sbasedon0 \snext0 html-head5;}
{\s36\ql \keepn\sb90\sa180\f2\fs%s\ul\sbasedon0 \snext0 html-head6;}
}

END

        @{ $_[0] }{
        qw<
            codeblock_halfpoint_size
            head1_halfpoint_size
            head2_halfpoint_size
            head3_halfpoint_size
            head4_halfpoint_size
            head5_halfpoint_size
            head6_halfpoint_size
            >
        };
}

# ------------------------------------------------------------------------
# Override these as necessary for further customization

sub font_table {
    my $self = shift;

    return sprintf <<'END' ,    # text font, code font, heading font
{\fonttbl
{\f0\froman %s;}
{\f1\fmodern %s;}
{\f2\fswiss %s;}
}

END

        map {
        ;                       # custom-dumb escaper:
        my $x = $_;
        $x =~ s/([\x00-\x1F\\\{\}\x7F-\xFF])/sprintf("\\'%02x", $1)/g;
        $x =~ s/([^\x00-\xFF])/'\\uc1\\u'.((ord($1)<32768)?ord($1):(ord($1)-65536)).'?'/eg;
        $x;
        }
        $self->{'fontname_body'}     || 'Times',
        $self->{'fontname_code'}     || 'Courier New',
        $self->{'fontname_headings'} || 'Arial',
        ;
}

# ------------------------------------------------------------------------
sub doc_init {
    return <<'END';
{\rtf1\ansi\deff0

END
}

# ------------------------------------------------------------------------
sub color_table {
    return <<'END';
{\colortbl;\red255\green0\blue0;\red0\green0\blue255;}
END
}

# ------------------------------------------------------------------------
sub doc_info {
    my $self = $_[0];

    return sprintf <<'END', $self->version_tag;
{\info{\doccomm generated by %s}
{\author [see doc]}{\company [see doc]}{\operator [see doc]}
}

END

}

# ------------------------------------------------------------------------
sub doc_really_start {
    my $self = $_[0];

    return sprintf <<'END',
\deflang%s\widowctrl
{\header\pard\qr\plain\f2\fs%s
p.\chpgn\par}
\fs%s

END
        $self->{'document_language'} || 1033, $self->{"header_halfpoint_size"}, $self->{"normal_halfpoint_size"},;
}

# ------------------------------------------------------------------------
sub emit_para {    # rather like showline in FormatPS
    my $self = shift;

    my $para = $self->{'Para'};
    $self->{'Para'} = undef;

    #### emit_para called by: (caller(1) )[3];

    unless ( defined $para ) {
        #### emit_para with empty buffer...
        return;
    }

    $para =~ s/^ +//s;
    $para =~ s/ +$//s;

    # And now: a not terribly clever algorithm for inserting newlines
    # at a guaranteed harmless place: after a block of whitespace
    # after the 65th column.  This was copied from RTF::Writer.
    $para =~ s/(
       [^\cm\cj\n]{65}        # Snare 65 characters from a line
       [^\cm\cj\n\x20]{0,50}  #  and finish any current word
      )
      (\x20{1,10})(?![\cm\cj\n]) # capture some spaces not at line-end
     /$1$2\n/gx    # and put a NL before those spaces
        ;

    $self->collect(
        sprintf(
            '{\pard\sa%d\li%d\ri%d%s\plain' . "\n",

            #100 +
            10 * $self->{'normal_halfpoint_size'} * ( $self->{'vspace'} || 0 ),

            $self->{'lm'},
            $self->{'rm'},

            $self->{'center'} ? '\qc' : '\ql',
        ),

        defined( $self->{'next_bullet'} )
        ? do {
            my $bullet = $self->{'next_bullet'};
            $self->{'next_bullet'} = undef;
            sprintf "\\fi-%d\n%s",
                4.5 * $self->{'normal_halfpoint_size'},
                ( $bullet eq '*' ) ? "\\'95 " : ( rtf_esc($bullet) . ". " );
            }
        : (),

        $para,
        "\n\\par}\n\n",
    );

    $self->{'vspace'} = undef;    # we finally get to clear it here!

    return;
}

# ------------------------------------------------------------------------
sub new_font_size {
    my $self = $_[0];

    $self->out( \sprintf "{\\fs%u\n", $self->scale_font_for( $self->{'normal_halfpoint_size'} ) );
}

# ------------------------------------------------------------------------
sub restore_font_size { shift->out( \'}' ) }

# ------------------------------------------------------------------------
sub hr_start {
    my $self = shift;

    # A bit of a hack:

    $self->vspace(.3);
    $self->out( \( '\qc\ul\f1\fs20\nocheck\lang1024 ' . ( '\~' x ( $self->{'hr_width'} || 50 ) ) ) );
    $self->vspace(.7);
    1;
}

# ------------------------------------------------------------------------

sub br_start {
    $_[0]->out( \"\\line\n" );
}

# ------------------------------------------------------------------------
sub header_start {
    my ( $self, $level ) = @_;

    # for h1 ... h6's
    # This really should have been called heading_start, but it's too late
    #  to change now.

    ### Heading of level: $level
    #$self->adjust_lm(0); # assert new paragraph
    $self->vspace(1.5);

    $self->out(
        \(  sprintf '\s3%s\ql\keepn\f2\fs%s\ul' . "\n", $level, $self->{ 'head' . $level . '_halfpoint_size' }, $level,
        )
    );

    return 1;
}

# ------------------------------------------------------------------------
sub header_end {

    # This really should have been called heading_end but it's too late
    #  to change now.

    $_[0]->vspace(1);
    1;
}

# ------------------------------------------------------------------------
sub bullet {
    my ( $self, $bullet ) = @_;

    $self->{'next_bullet'} = $bullet;
    return;
}

# ------------------------------------------------------------------------
sub adjust_lm {
    $_[0]->emit_para();
    $_[0]->{'lm'} += $_[1] * $_[0]->{'normal_halfpoint_size'} * 5;
    1;
}

# ------------------------------------------------------------------------
sub adjust_rm {
    $_[0]->emit_para();
    $_[0]->{'rm'} -= $_[1] * $_[0]->{'normal_halfpoint_size'} * 5;
    1;
}    # Yes, flip the sign on the right margin!

# BTW, halfpoints * 10 = twips

# ------------------------------------------------------------------------
sub pre_start {
    my $self = shift;

    $self->SUPER::pre_start(@_);
    $self->out( \sprintf '\s20\f1\fs%s\noproof\lang1024\lang1076 ', $self->{'codeblock_halfpoint_size'}, );
    return 1;
}

# ------------------------------------------------------------------------
sub b_start      { shift->out( \'{\b ' ) }
sub b_end        { shift->out( \'}' ) }
sub i_start      { shift->out( \'{\i ' ) }
sub i_end        { shift->out( \'}' ) }
sub tt_start     { shift->out( \'{\f1\noproof\lang1024\lang1076 ' ) }
sub tt_end       { shift->out( \'}' ) }
sub sub_start    { shift->out( \'{\sub ' ) }
sub sub_end      { shift->out( \'}' ) }
sub sup_start    { shift->out( \'{\super ' ) }
sub sup_end      { shift->out( \'}' ) }
sub strike_start { shift->out( \'{\strike ' ) }
sub strike_end   { shift->out( \'}' ) }

# ------------------------------------------------------------------------
sub q_start {
    my $self = $_[0];

    $self->out( ( ( ++$self->{'quotelevel'} ) % 2 ) ? \'\ldblquote ' : \'\lquote ' );
}

# ------------------------------------------------------------------------
sub q_end {
    my $self = $_[0];

    $self->out( ( ( --$self->{'quotelevel'} ) % 2 ) ? \'\rquote ' : \'\rdblquote ' );
}

# ------------------------------------------------------------------------
sub pre_out { $_[0]->out( ref( $_[1] ) ? $_[1] : \rtf_esc_codely( $_[1] ) ) }

# ------------------------------------------------------------------------
sub out {    # output a word (or, if escaped, chunk of RTF)
    my $self = shift;

    #return $self->pre_out(@_) if $self->{pre};

    #### out called by: $_[0], (caller(1) )[3]

    return unless defined $_[0];    # and length $_[0];

    $self->{'Para'} = '' unless defined $self->{'Para'};
    $self->{'Para'} .= ref( $_[0] ) ? ${ $_[0] } : rtf_esc( $_[0] );

    return 1;
}

# ------------------------------------------------------------------------
use integer;

sub rtf_esc {
    my $x;                          # scratch
    if ( !defined wantarray ) {     # void context: alter in-place!
        for (@_) {
            s/([F\x00-\x1F\-\\\{\}\x7F-\xFF])/$Escape{$1}/g;    # ESCAPER
            s/([^\x00-\xFF])/'\\uc1\\u'.((ord($1)<32768)?ord($1):(ord($1)-65536)).'?'/eg;
        }
        return;
    }
    elsif (wantarray) {                                         # return an array
        return map {
            ;
            ( $x = $_ ) =~ s/([F\x00-\x1F\-\\\{\}\x7F-\xFF])/$Escape{$1}/g;    # ESCAPER
            $x =~ s/([^\x00-\xFF])/'\\uc1\\u'.((ord($1)<32768)?ord($1):(ord($1)-65536)).'?'/eg;

            # Hyper-escape all Unicode characters.
            $x;
        } @_;
    }
    else {                                                                     # return a single scalar
        ( $x = ( ( @_ == 1 ) ? $_[0] : join '', @_ ) ) =~ s/([F\x00-\x1F\-\\\{\}\x7F-\xFF])/$Escape{$1}/g;    # ESCAPER
                 # Escape \, {, }, -, control chars, and 7f-ff.
        $x =~ s/([^\x00-\xFF])/'\\uc1\\u'.((ord($1)<32768)?ord($1):(ord($1)-65536)).'?'/eg;

        # Hyper-escape all Unicode characters.
        return $x;
    }
}

# ------------------------------------------------------------------------
sub rtf_esc_codely {

    # Doesn't change "-" to hard-hyphen, nor apply computerese style

    my $x;    # scratch
    if ( !defined wantarray ) {    # void context: alter in-place!
        for (@_) {
            s/([F\x00-\x1F\\\{\}\x7F-\xFF])/$Escape{$1}/g;
            s/([^\x00-\xFF])/'\\uc1\\u'.((ord($1)<32768)?ord($1):(ord($1)-65536)).'?'/eg;

            # Hyper-escape all Unicode characters.
        }
        return;
    }
    elsif (wantarray) {            # return an array
        return map {
            ;
            ( $x = $_ ) =~ s/([F\x00-\x1F\\\{\}\x7F-\xFF])/$Escape{$1}/g;
            $x =~ s/([^\x00-\xFF])/'\\uc1\\u'.((ord($1)<32768)?ord($1):(ord($1)-65536)).'?'/eg;

            # Hyper-escape all Unicode characters.
            $x;
        } @_;
    }
    else {                         # return a single scalar
        ( $x = ( ( @_ == 1 ) ? $_[0] : join '', @_ ) ) =~ s/([F\x00-\x1F\\\{\}\x7F-\xFF])/$Escape{$1}/g;

        # Escape \, {, }, -, control chars, and 7f-ff.
        $x =~ s/([^\x00-\xFF])/'\\uc1\\u'.((ord($1)<32768)?ord($1):(ord($1)-65536)).'?'/eg;

        # Hyper-escape all Unicode characters.
        return $x;
    }
}

1;

__END__

=pod

=for test_synopsis 1;
__END__

=for stopwords arial bookman lm pagenumber prolog rtf tahoma verdana CPAN
    homepage rm sans serif twentieths

=head1 NAME

HTML::FormatRTF - Format HTML as RTF

=head1 VERSION

version 2.14

=head1 SYNOPSIS

  use HTML::FormatRTF;

  my $out_file = "test.rtf";
  open(RTF, ">$out_file")
   or die "Can't write-open $out_file: $!\nAborting";

  print RTF HTML::FormatRTF->format_file(
    'test.html',
      'fontname_headings' => "Verdana",
  );
  close(RTF);

=head1 DESCRIPTION

HTML::FormatRTF is a class for objects that you use to convert HTML to RTF.
There is currently no proper support for tables or forms.

This is a subclass of L<HTML::Formatter>, whose documentation you should
consult for more information on underlying methods such as C<new>, C<format>,
C<format_file> etc

You can specify any of the following parameters in the call to C<new>,
C<format_file>, or C<format_string>:

=over

=item lm

Amount of I<extra> indenting to apply to the left margin, in twips
(I<tw>entI<i>eths of a I<p>oint). Default is 0.

So if you wanted the left margin to be an additional half inch larger, you'd
set C<< lm => 720 >> (since there's 1440 twips in an inch). If you wanted it to
be about 1.5cm larger, you'd set C<< lw => 850 >> (since there's about 567
twips in a centimeter).

=item rm

Amount of I<extra> indenting to apply to the left margin, in twips
(I<tw>entI<i>eths of a I<p>oint).  Default is 0.

=item normal_halfpoint_size

This is the size of normal text in the document, in I<half>-points. The default
value is 22, meaning that normal text is in 11 point.

=item header_halfpoint_size

This is the size of text used in the document's page-header, in I<half>-points.
The default value is 17, meaning that normal text is in 7.5 point.  Currently,
the header consists just of "p. I<pagenumber>" in the upper-right-hand corner,
and cannot be disabled.

=item head1_halfpoint_size ... head6_halfpoint_size

These control the font size of each heading level, in half-twips.  For example,
the default for head3_halfpoint_size is 25, meaning that HTML C<< <h3>...</h3>
>> text will be in 12.5 point text (in addition to being underlined and in the
heading font).

=item codeblock_halfpoint_size

This controls the font size (in half-points) of the text used for C<<
<pre>...</pre> >> text.  By default, it is 18, meaning 9 point.

=item fontname_body

This option controls what font is to be used for the body of the text -- that
is, everything other than heading text and text in pre/code/tt elements. The
default value is currently "Times".  Other handy values I can suggest using are
"Georgia" or "Bookman Old Style".

=item fontname_code

This option controls what font is to be used for text in pre/code/tt elements.
The default value is currently "Courier New".

=item fontname_headings

This option controls what font name is to be used for headings.  You can use
the same font as fontname_body, but I prefer a sans-serif font, so the default
value is currently "Arial".  Also consider "Tahoma" and "Verdana".

=item document_language

This option controls what Microsoft language number will be specified as the
language for this document. The current default value is 1033, for US English.
Consult an RTF reference for other language numbers.

=item hr_width

This option controls how many underline characters will be used for rendering a
"<hr>" tag. Its default value is currently 50. You can usually leave this
alone, but under some circumstances you might want to use a smaller or larger
number.

=item no_prolog

If this option is set to a true value, HTML::FormatRTF will make a point of
I<not> emitting the RTF prolog before the document.  By default, this is off,
meaning that HTML::FormatRTF I<will> emit the prolog.  This option is of
interest only to advanced users.

=item no_trailer

If this option is set to a true value, HTML::FormatRTF will make a point of
I<not> emitting the RTF trailer at the end of the document.  By default, this
is off, meaning that HTML::FormatRTF I<will> emit the bit of RTF that ends the
document.  This option is of interest only to advanced users.

=back

=head1 SEE ALSO

L<HTML::Formatter>, L<RTF::Writer>

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
