# NOTE: Derived from blib\lib\URI\URL.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL;

#line 358 "blib\lib\URI\URL.pm (autosplit into blib\lib\auto/URI\URL/print_on.al)"
sub print_on
{
    no strict qw(refs);  # because we use strings as filehandles
    my $self = shift;
    my $fh = shift || 'STDERR';
    my($k, $v);
    print $fh "Dump of URI::URL $self...\n";
    foreach $k (sort keys %$self){
	$v = $self->{$k};
	$v = 'UNDEF' unless defined $v;
	print $fh "  $k\t'$v'\n";
    }
}

1;


#########################################################################
#### D O C U M E N T A T I O N
#########################################################################

1;
# end of URI::URL::print_on
