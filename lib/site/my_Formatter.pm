
# 11/29/98 bwinter ... modified to allow for tables.  Other HTML code is in perl directory
#  - make sure this replaces the HTML/Formatter.pm file, so tables will be parsed

package HTML::Formatter;

# $Id$

=head1 NAME

HTML::Formatter - Base class for HTML formatters

=head1 SYNOPSIS

 package HTML::FormatXX;
 require HTML::Formatter;
 @ISA=qw(HTML::Formatter);

=head1 DESCRIPTION

HTML formatters are able to format a HTML syntax tree into various
printable formats.  Different formatters produce output for different
output media.  Common for all formatters are that they will return the
formatted output when the format() method is called.  Format() takes a
HTML::Element as parameter.

=head1 SEE ALSO

L<HTML::FormatText>, L<HTML::FormatPS>, L<HTML::Element>

=head1 COPYRIGHT

Copyright (c) 1995-1998 Gisle Aas. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Gisle Aas <aas@sn.no>

=cut


require HTML::Element;

use strict;
use Carp;
use UNIVERSAL qw(can);

use vars qw($VERSION);
($VERSION) = q$Revision$ =~ /: (\d+)/;


sub new
{
    my($class,%arg) = @_;
    my $self = bless { $class->default_values }, $class;
    $self->configure(\%arg) if scalar(%arg);
    $self;
}

sub default_values
{
    ();
}

sub configure
{
    my($self, $arg) = @_;
    for (keys %$arg) {
	warn "Unknown configure argument '$_'" if $^W;
    }
    $self;
}

sub format
{
    my($self, $html) = @_;
    $self->begin();
    $html->traverse(
	sub {
	    my($node, $start, $depth) = @_;
	    if (ref $node) {
		my $tag = $node->tag;
		my $func = $tag . '_' . ($start ? "start" : "end");
		# Use UNIVERSAL::can so that we can recover if
		# a handler is not defined for the tag.
		if (can($self, $func)) {
		    return $self->$func($node);
		} else {
		    return 1;
		}
	    } else {
		$self->textflow($node);
	    }
	    1;
	}
     );
    $self->end();
    join('', @{$self->{output}});
}

sub begin
{
    my $self = shift;

    # Flags
    $self->{anchor}    = 0;
    $self->{underline} = 0;
    $self->{bold}      = 0;
    $self->{italic}    = 0;
    $self->{center}    = 0;
    $self->{nobr}      = 0;

    $self->{font_size}     = [3];   # last element is current size
    $self->{basefont_size} = [3];

    $self->{markers} = [];          # last element is current marker
    $self->{vspace} = undef;        # vertical space (dimension)

    $self->{output} = [];
}

sub end
{
}

sub html_start { 1; }  sub html_end {}
sub head_start { 0; }
sub body_start { 1; }  sub body_end {}

sub header_start
{
    my($self, $level, $node) = @_;
    my $align = $node->attr('align');
    if (defined($align) && lc($align) eq 'center') {
	$self->{center}++;
    }
    1,
}

sub header_end
{
    my($self, $level, $node) = @_;
    my $align = $node->attr('align');
    if (defined($align) && lc($align) eq 'center') {
	$self->{center}--;
    }
}

sub h1_start { shift->header_start(1, @_) }
sub h2_start { shift->header_start(2, @_) }
sub h3_start { shift->header_start(3, @_) }
sub h4_start { shift->header_start(4, @_) }
sub h5_start { shift->header_start(5, @_) }
sub h6_start { shift->header_start(6, @_) }

sub h1_end   { shift->header_end(1, @_) }
sub h2_end   { shift->header_end(2, @_) }
sub h3_end   { shift->header_end(3, @_) }
sub h4_end   { shift->header_end(4, @_) }
sub h5_end   { shift->header_end(5, @_) }
sub h6_end   { shift->header_end(6, @_) }

sub br_start
{
    my $self = shift;
    $self->vspace(0, 1);
}

sub hr_start
{
    my $self = shift;
    $self->vspace(1);
}

sub img_start
{
    shift->out(shift->attr('alt') || "[IMAGE]");
}

sub a_start
{
    shift->{anchor}++;
    1;
}

sub a_end
{
    shift->{anchor}--;
}

sub u_start
{
    shift->{underline}++;
    1;
}

sub u_end
{
    shift->{underline}--;
}

sub b_start
{
    shift->{bold}++;
    1;
}

sub b_end
{
    shift->{bold}--;
}

sub tt_start
{
    shift->{teletype}++;
    1;
}

sub tt_end
{
    shift->{teletype}--;
}

sub i_start
{
    shift->{italic}++;
    1;
}

sub i_end
{
    shift->{italic}--;
}

sub center_start
{
    shift->{center}++;
    1;
}

sub center_end
{
    shift->{center}--;
}

sub nobr_start
{
    shift->{nobr}++;
    1;
}

sub nobr_end
{
    shift->{nobr}--;
}

sub wbr_start
{
    1;
}

sub font_start
{
    my($self, $elem) = @_;
    my $size = $elem->attr('size');
    return 1 unless defined $size;
    if ($size =~ /^\s*[+\-]/) {
	my $base = $self->{basefont_size}[-1];
	$size = $base + $size;
    }
    push(@{$self->{font_size}}, $size);
    1;
}

sub font_end
{
    my($self, $elem) = @_;
    my $size = $elem->attr('size');
    return unless defined $size;
    pop(@{$self->{font_size}});
}

sub basefont_start
{
    my($self, $elem) = @_;
    my $size = $elem->attr('size');
    return unless defined $size;
    push(@{$self->{basefont_size}}, $size);
    1;
}

sub basefont_end
{
    my($self, $elem) = @_;
    my $size = $elem->attr('size');
    return unless defined $size;
    pop(@{$self->{basefont_size}});
}

# Aliases for logical markup
BEGIN {
    *cite_start   = \&i_start;
    *cite_end     = \&i_end;
    *code_start   = \&tt_start;
    *code_end     = \&tt_end;
    *em_start     = \&i_start;
    *em_end       = \&i_end;
    *kbd_start    = \&tt_start;
    *kbd_end      = \&tt_end;
    *samp_start   = \&tt_start;
    *samp_end     = \&tt_end;
    *strong_start = \&b_start;
    *strong_end   = \&b_end;
    *var_start    = \&tt_start;
    *var_end      = \&tt_end;
}

sub p_start
{
    my $self = shift;
    $self->vspace(1);
    1;
}

sub p_end
{
    shift->vspace(1);
}

sub pre_start
{
    my $self = shift;
    $self->{pre}++;
    $self->vspace(1);
    1;
}

sub pre_end
{
    my $self = shift;
    $self->{pre}--;
    $self->vspace(1);
}

BEGIN {
    *listing_start = \&pre_start;
    *listing_end   = \&pre_end;
    *xmp_start     = \&pre_start;
    *xmp_end       = \&pre_end;
}

sub blockquote_start
{
    my $self = shift;
    $self->vspace(1);
    $self->adjust_lm( +2 );
    $self->adjust_rm( -2 );
    1;
}

sub blockquote_end
{
    my $self = shift;
    $self->vspace(1);
    $self->adjust_lm( -2 );
    $self->adjust_rm( +2 );
}

sub address_start
{
    my $self = shift;
    $self->vspace(1);
    $self->i_start(@_);
    1;
}

sub address_end
{
    my $self = shift;
    $self->i_end(@_);
    $self->vspace(1);
}

# Handling of list elements

sub ul_start
{
    my $self = shift;
    $self->vspace(1);
    push(@{$self->{markers}}, "*");
    $self->adjust_lm( +2 );
    1;
}

sub ul_end
{
    my $self = shift;
    pop(@{$self->{markers}});
    $self->adjust_lm( -2 );
    $self->vspace(1);
}

sub li_start
{
    my $self = shift;
    $self->bullet($self->{markers}[-1]);
    $self->adjust_lm(+2);
    1;
}

sub bullet
{
    shift->out(@_);
}

sub li_end
{
    my $self = shift;
    $self->vspace(1);
    $self->adjust_lm( -2);
    my $markers = $self->{markers};
    if ($markers->[-1] =~ /^\d+/) {
	# increment ordered markers
	$markers->[-1]++;
    }
}

BEGIN {
    *menu_start = \&ul_start;
    *menu_end   = \&ul_end;
    *dir_start  = \&ul_start;
    *dir_end    = \&ul_end;
}

sub ol_start
{
    my $self = shift;

    $self->vspace(1);
    push(@{$self->{markers}}, 1);
    $self->adjust_lm(+2);
    1;
}

sub ol_end
{
    my $self = shift;
    $self->adjust_lm(-2);
    pop(@{$self->{markers}});
    $self->vspace(1);
}


sub dl_start
{
    my $self = shift;
    $self->adjust_lm(+2);
    $self->vspace(1);
    1;
}

sub dl_end
{
    my $self = shift;
    $self->adjust_lm(-2);
    $self->vspace(1);
}

sub dt_start
{
    my $self = shift;
    $self->vspace(1);
    1;
}

sub dt_end
{
}

sub dd_start
{
    my $self = shift;
    $self->adjust_lm(+6);
    $self->vspace(0);
    1;
}

sub dd_end
{
    shift->adjust_lm(-6);
}


#-----------------------------
# 11/29/98 bwinter Updated the following to allow for table text data
#sub table_start { shift->out('[TABLE NOT SHOWN]'); 0; }
sub table_start { 
    shift->vspace(1);
    1;
}
sub table_end {
    shift->vspace(1);
}

sub tr_start { 
    shift->vspace(1);
    1;
}
sub tr_end {}
#-----------------------------


# Things not formated at all
sub form_start  { shift->out('[FORM NOT SHOWN]');  0; }



sub textflow
{
    my $self = shift;
    if ($self->{pre}) {
	# strip leading and trailing newlines so that the <pre> tags 
	# may be placed on lines of their own without causing extra
	# vertical space as part of the preformatted text
	$_[0] =~ s/\n$//;
	$_[0] =~ s/^\n//;
	$self->pre_out($_[0]);
    } else {
	for (split(/(\s+)/, $_[0])) {
	    next unless length $_;
	    $self->out($_);
	}
    }
}



sub vspace
{
    my($self, $min, $add) = @_;
    my $old = $self->{vspace};
    if (defined $old) {
	my $new = $old;
	$new += $add || 0;
	$new = $min if $new < $min;
	$self->{vspace} = $new;
    } else {
	$self->{vspace} = $min;
    }
    $old;
}

sub collect
{
    push(@{shift->{output}}, @_);
}

sub out
{
    confess "Must be overridden my subclass";
}

sub pre_out
{
    confess "Must be overridden my subclass";
}

1;
