=pod

=head1 NAME

SVG::XML - Handle the XML generation bits for SVG.pm

=head1 AUTHOR

Ronan Oger, ronan@roasp.com

=head1 SEE ALSO

perl(1),L<SVG>,L<SVG::XML>,L<SVG::Element>,L<SVG::Parser>, L<SVG::Manual>
http://www.roasp.com/
http://www.perlsvg.com/
http://www.roitsystems.com/
http://www.w3c.org/Graphics/SVG/

=cut

package SVG::XML;
use strict;
use vars qw($VERSION @ISA @EXPORT );

$VERSION = "2.26";

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
    xmlescp
    cssstyle
    xmlattrib
    xmlcomment
    xmlpi
    xmltag
    xmltagopen
    xmltagclose
    xmltag_ln
    xmltagopen_ln
    xmltagclose_ln
    processtag
    xmldecl
    dtddecl
);

sub xmlescp ($) {
    my $s=shift;
    $s = '0' unless defined $s;
    $s=join(', ',@{$s}) if(ref($s) eq 'ARRAY');
	$s=~s/&(?!#(x\w\w|\d+?);)/&amp;/g;
    $s=~s/>/&gt;/g;
    $s=~s/</&lt;/g;
    $s=~s/\"/&quot;/g;
    $s=~s/\'/&apos;/g;
    $s=~s/\`/&apos;/g;
    $s=~s/([\x00-\x1f])/sprintf('&#x%02X;',chr($1))/eg;
	#per suggestion from Adam Schneider
	$s=~s/([\200-\377])/'&#'.ord($1).';'/ge;

    return $s;
}

sub cssstyle {
    my %attrs=@_;
    return(join('; ',map { qq($_: ).$attrs{$_} } keys(%attrs)));
}

# Per suggestion from Adam Schneider
#sub xmlattrib {
#    my %attrs=@_;
#    return(join(' ',map { qq($_=").$attrs{$_}.q(") } keys(%attrs)));
#}

sub xmlattrib {
    my %attrs=@_;
    return(join(' ',map { qq($_=").xmlescp($attrs{$_}).q(") } keys(%attrs)));
}

sub xmltag ($$;@) {
    my ($name,$ns,%attrs)=@_;
    $ns=$ns?"$ns:":'';
    my $at=' '.xmlattrib(%attrs)||'';
    return qq(<$ns$name$at />);
}

sub xmltag_ln ($$;@) {
    my ($name,$ns,%attrs)=@_;
    return xmltag($name,$ns,%attrs);
}

sub xmltagopen ($$;@) {
    my ($name,$ns,%attrs)=@_;
    $ns=$ns?"$ns:":'';
    my $at=' '.xmlattrib(%attrs)||'';
    return qq(<$ns$name$at>);
}

sub xmltagopen_ln ($$;@) {
    my ($name,$ns,%attrs)=@_;
    return xmltagopen($name,$ns,%attrs);
}

sub xmlcomment ($$) {
    my ($self,$r_comment) = @_;
    my $ind = $self->{-docref}->{-elsep}.$self->{-docref}->{-indent} x $self->{-docref}->{-level};
    return(join($ind,map { qq(<!-- $_ -->)} @$r_comment));
}

sub xmlpi ($$) {
    my ($self,$r_pi) = @_;
    my $ind = $self->{-docref}->{-elsep}.$self->{-docref}->{-indent} x $self->{-docref}->{-level};
    return(join($ind,map { qq(<?$_?>)} @$r_pi));
}

*processinginstruction=\&xmlpi;

sub xmltagclose ($$) {
    my ($name,$ns)=@_;
    $ns=$ns?"$ns:":'';
    return qq(</$ns$name>);
}

sub xmltagclose_ln ($$) {
    my ($name,$ns)=@_;
    return xmltagclose($name,$ns);
}

sub dtddecl ($) {
    my $self = shift;
    my $docroot = $self->{-docroot} || 'svg';
    my $id;

    if ($self->{-pubid}) {
        $id = 'PUBLIC "'.$self->{-pubid}.'"';
        $id .= ' "'.$self->{-sysid}.'"' if ($self->{-sysid});
    } elsif (
        $self->{-sysid}) {
        $id      = 'SYSTEM "'.$self->{-sysid}.'"';
    } else {
        $id =  'PUBLIC "-//W3C//DTD SVG 1.0//EN"' .
        $self->{-docref}->{-elsep}.
        "\"$self->{-docref}->{-dtd}\""
    }

    my $at=join(' ',($docroot, $id));

    #>>>TBD: add internal() method to return this
    my $extension = (exists $self->{-internal})?$self->{-internal}->render():"";
    if (exists $self->{-extension} and $self->{-extension}) {
        $extension .= $self->{-docref}{-elsep}.
                      $self->{-extension}.
                      $self->{-docref}{-elsep};
    }
    $extension = " [".$self->{-docref}{-elsep}.$extension."]" if $extension;

    return qq[<!DOCTYPE $at$extension>];
}

sub xmldecl ($) {
    my $self = shift;

    my $version= $self->{-version} || '1.0';
    my $encoding = $self->{-encoding} || 'UTF-8';
    my $standalone = $self->{-standalone} ||'yes';

    return qq§<?xml version="$version" encoding="$encoding" standalone="$standalone"?>§
           .$self->{-docref}{-elsep};
}

#-------------------------------------------------------------------------------

1;
