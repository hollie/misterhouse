
package Override_print;
use strict;
require 5.004;
sub TIEHANDLE { bless $_[1], $_[0]; }
sub PRINT  { my $coderef = shift; $coderef->(@_); }
sub PRINTF { my $coderef = shift; $coderef->(@_); }
sub define_print (&) { tie( *STDOUT, "Override_print", @_ ); }
sub undefine_print (&) { untie(*STDOUT); }
1;

