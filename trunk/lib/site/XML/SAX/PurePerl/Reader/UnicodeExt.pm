# $Id$

package XML::SAX::PurePerl::Reader;
use strict;

use Encode;

sub set_raw_stream {
    my ($fh) = @_;
    binmode($fh, ":bytes");
}

sub switch_encoding_stream {
    my ($fh, $encoding) = @_;
    binmode($fh, ":encoding($encoding)");
}

sub switch_encoding_string {
    Encode::from_to($_[0], $_[1], "utf-8");
}

1;

