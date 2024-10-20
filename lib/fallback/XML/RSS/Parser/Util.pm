package XML::RSS::Parser::Util;
use strict;

use Exporter;
@XML::RSS::Parser::Util::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( as_xml encode_xml );

use XML::Elemental::Util qw( process_name );

# This has its limitations, but should suffice
sub as_xml {
    my($node,$dec,$encoding) = @_;
    $encoding ||= 'utf-8';
    my $xml = $dec ? qq(<?xml version="1.0" encoding="$encoding"?>\n) : '';
    my $dumper;
    $dumper = sub {
        my $node = shift;
        return encode_xml($node->data)
          if (ref($node) eq 'XML::RSS::Parser::Characters');

        # it must be an element then.
        my ($name, $ns) = process_name($node->name);
        my $prefix = $XML::RSS::Parser::xpath_ns{$ns};    # missing namespace???
        $name = "$prefix:$name" if ($prefix && $prefix ne '#default');
        my $xml      = "<$name";
        my $a        = $node->attributes;
        my $children = $node->contents;
        foreach (keys %$a) {
            my ($aname, $ans) = process_name($_);
            if ($ans ne $ns) {
                my $aprefix =
                  $XML::RSS::Parser::xpath_ns{$ans};      # missing namespace???
                $aname = "$aprefix:$aname"
                  if ($aprefix && $aprefix ne '#default');
            }
            $xml .= " $aname=\"" . encode_xml($a->{$_}, 1) . "\"";
        }
        if ($children) {
            $xml .= '>';
            map { $xml .= $dumper->($_) } @$children;
            $xml .= "</$name>";
        } else {
            $xml .= '/>';
        }
        $xml;
    };
    $xml .= $dumper->($node);
    $xml;
}

my %Map = (
           '&'  => '&amp;',
           '"'  => '&quot;',
           '<'  => '&lt;',
           '>'  => '&gt;',
           '\'' => '&#39;'
);
my $RE = join '|', keys %Map;

sub encode_xml {
    my ($str, $nocdata) = @_;
    return unless defined($str);
    if (
        !$nocdata
        && $str =~ m/
        <[^>]+>  ## HTML markup
        |        ## or
        &(?:(?!(\#([0-9]+)|\#x([0-9a-fA-F]+))).*?);
                 ## something that looks like an HTML entity.
    /x
      ) {
        ## If ]]> exists in the string, encode the > to &gt;.
        $str =~ s/]]>/]]&gt;/g;
        $str = '<![CDATA[' . $str . ']]>';
      } else {
        $str =~ s!($RE)!$Map{$1}!g;
    }
    $str;
}

1;

__END__

=begin

=head1 NAME

XML::RSS::Parser::Util - utility methods for working with
L<XML::RSS::Parser>.

=head1 METHODS

All utility methods are exportable.

=over

=item as_xml($node[,$dec,$encoding])

Creates XML output markup for the element object including
its siblings. This method is not a full featured XML
generator, and has its limitations, but should suffice in
most cases. Use with caution.

Passing a second optional parameter with the value of true
will add an XML 1.0 standard declaration to the returned
XML. The third parameter (also optional) parameter defines
the encoding to be used in the declaration. The default is
'utf-8'.

=item encode_xml ($string[, $nocdata])

XML encodes any characters in the string that are required
to be represented as entities. This method will attempt to
identify anything that looks like markup and CDATA encodes
it. This can optional be turned off by passing a second
parameter with a true value. The markup will be entity
encoded instead.

=back

=head1 AUTHOR & COPYRIGHT

Please see the XML::RSS::Parser manpage for author, copyright,
and license information.

=cut

=end

