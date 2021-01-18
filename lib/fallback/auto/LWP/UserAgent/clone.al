# NOTE: Derived from blib\lib\LWP\UserAgent.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package LWP::UserAgent;

#line 499 "blib\lib\LWP\UserAgent.pm (autosplit into blib\lib\auto/LWP\UserAgent/clone.al)"
sub clone
{
    my $self = shift;
    my $copy = bless { %$self }, ref $self;  # copy most fields

    # elements that are references must be handled in a special way
    $copy->{'no_proxy'} = [ @{$self->{'no_proxy'}} ];  # copy array

    $copy;
}

# end of LWP::UserAgent::clone
1;
