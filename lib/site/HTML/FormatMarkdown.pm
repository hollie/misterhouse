package HTML::FormatMarkdown;

# ABSTRACT: Format HTML as Markdown


use 5.006_001;
use strict;
use warnings;

use parent 'HTML::Formatter';

our $VERSION = '2.14'; # VERSION
our $AUTHORITY = 'cpan:NIGELM'; # AUTHORITY

sub default_values {
    (   shift->SUPER::default_values(),
        lm => 0,
        rm => 70,
    );
}

sub configure {
    my ( $self, $hash ) = @_;

    my $lm = $self->{lm};
    my $rm = $self->{rm};

    $lm = delete $hash->{lm}          if exists $hash->{lm};
    $lm = delete $hash->{leftmargin}  if exists $hash->{leftmargin};
    $rm = delete $hash->{rm}          if exists $hash->{rm};
    $rm = delete $hash->{rightmargin} if exists $hash->{rightmargin};

    my $width = $rm - $lm;
    if ( $width < 1 ) {
        warn "Bad margins, ignored" if $^W;
        return;
    }
    if ( $width < 20 ) {
        warn "Page probably too narrow" if $^W;
    }

    for ( keys %$hash ) {
        warn "Unknown configure option '$_'" if $^W;
    }

    $self->{lm} = $lm;
    $self->{rm} = $rm;
    $self;
}

sub begin {
    my $self = shift;

    $self->SUPER::begin();
    $self->{maxpos} = 0;
    $self->{curpos} = 0;    # current output position.
}

sub end {
    shift->collect("\n");
}

sub header_start {
    my ( $self, $level ) = @_;

    $self->vspace(1);
    $self->out( '#' x $level . ' ' );
    1;
}

sub header_end {
    my ( $self, $level ) = @_;

    $self->out( ' ' . '#' x $level );
    $self->vspace(1);
}

sub bullet {
    my $self = shift;

    $self->SUPER::bullet( $_[0] . ' ' );

}

sub hr_start {
    my $self = shift;

    $self->vspace(1);
    $self->out('- - -');
    $self->vspace(1);
}

sub img_start {
    my ( $self, $node ) = @_;

    my $alt = $node->attr('alt');
    my $src = $node->attr('src');

    $self->out("![$alt]($src)");
}

sub a_start {
    my ( $self, $node ) = @_;

    # ignore named anchors
    if ( $node->attr('name') ) {
        1;
    }
    elsif ( $node->attr('href') =~ /^#/ ) {
        1;
    }
    else {
        $self->out("[");
    }

}

sub a_end {
    my ( $self, $node ) = @_;

    if ( $node->attr('name') ) {
        return;
    }
    elsif ( my $href = $node->attr('href') ) {
        if ( $href =~ /^#/ ) {
            return;
        }
        $self->out("]($href)");
    }
}

sub b_start { shift->out("**") }
sub b_end   { shift->out("**") }
sub i_start { shift->out("*") }
sub i_end   { shift->out("*") }

sub tt_start {
    my $self = shift;

    if ( $self->{pre} ) {
        return 1;
    }
    else {
        $self->out("`");
    }
}

sub tt_end {
    my $self = shift;

    if ( $self->{pre} ) {
        return;
    }
    else {
        $self->out("`");
    }
}

sub blockquote_start {
    my $self = shift;

    $self->{blockquote}++;
    $self->vspace(1);
    $self->adjust_rm(-4);

    1;
}

sub blockquote_end {
    my $self = shift;

    $self->{blockquote}--;
    $self->vspace(1);
    $self->adjust_rm(+4);

}

sub blockquote_out {
    my ( $self, $text ) = @_;

    $self->nl;
    $self->goto_lm;

    my $line = "> ";
    $self->{curpos} += 2;

    foreach my $word ( split /\s/, $text ) {
        $line .= "$word ";
        if ( ( $self->{curpos} + length($line) ) > $self->{rm} ) {
            $self->collect($line);
            $self->nl;
            $self->goto_lm;
            $line = "> ";
            $self->{curpos} += 2;
        }
    }

    $self->collect($line);
    $self->nl;

}

# Quoted from HTML::FormatText
sub pre_out {
    my $self = shift;

    if ( defined $self->{vspace} ) {
        if ( $self->{out} ) {
            $self->nl() while $self->{vspace}-- >= 0;
            $self->{vspace} = undef;
        }
    }

    my $indent = ' ' x $self->{lm};
    $indent .= ' ' x 4;
    my $pre = shift;
    $pre =~ s/^/$indent/mg;
    $self->collect($pre);
    $self->{out}++;
}

sub out {
    my $self = shift;
    my $text = shift;

    $text =~ tr/\xA0\xAD/ /d;

    if ( $text =~ /^\s*$/ ) {
        $self->{hspace} = 1;
        return;
    }

    if ( defined $self->{vspace} ) {
        if ( $self->{out} ) {
            $self->nl while $self->{vspace}-- >= 0;
        }
        $self->goto_lm;
        $self->{vspace} = undef;
        $self->{hspace} = 0;
    }

    if ( $self->{hspace} ) {
        if ( $self->{curpos} + length($text) > $self->{rm} ) {

            # word will not fit on line; do a line break
            $self->nl;
            $self->goto_lm;
        }
        else {

            # word fits on line; use a space
            $self->collect(' ');
            ++$self->{curpos};
        }
        $self->{hspace} = 0;
    }

    $self->collect($text);
    my $pos = $self->{curpos} += length $text;
    $self->{maxpos} = $pos if $self->{maxpos} < $pos;
    $self->{'out'}++;
}

sub goto_lm {
    my $self = shift;

    my $pos = $self->{curpos};
    my $lm  = $self->{lm};
    if ( $pos < $lm ) {
        $self->{curpos} = $lm;
        $self->collect( " " x ( $lm - $pos ) );
    }
}

sub nl {
    my $self = shift;

    $self->{'out'}++;
    $self->{curpos} = 0;
    $self->collect("\n");
}

sub adjust_lm {
    my $self = shift;

    $self->{lm} += $_[0];
    $self->goto_lm;
}

sub adjust_rm {
    shift->{rm} += $_[0];
}

1;

__END__

=pod

=for stopwords CPAN Markdown homepage

=for test_synopsis 1;
__END__

=head1 NAME

HTML::FormatMarkdown - Format HTML as Markdown

=head1 VERSION

version 2.14

=head1 SYNOPSIS

    use HTML::FormatMarkdown;

    my $string = HTML::FormatMarkdown->format_file(
        'test.html'
    );

    open my $fh, ">", "test.md" or die "$!\n";
    print $fh $string;
    close $fh;

=head1 DESCRIPTION

HTML::FormatMarkdown is a formatter that outputs Markdown.

HTML::FormatMarkdown is built on L<HTML::Formatter> and documentation for that
module applies to this - especially L<HTML::Formatter/new>,
L<HTML::Formatter/format_file> and L<HTML::Formatter/format_string>.

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
