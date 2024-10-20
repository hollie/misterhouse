# NOTE: Derived from blib\lib\URI\URL.pm.
# Changes made here will be lost when autosplit again.
# See AutoSplit.pm.
package URI::URL;

#line 339 "blib\lib\URI\URL.pm (autosplit into blib\lib\auto/URI\URL/eq.al)"
# Compare two URLs, subclasses will provide a more correct implementation
sub eq {
    my($self, $other) = @_;
    $other = URI::URL->new($other, $self) unless ref $other;
    ref($self) eq ref($other) &&
      $self->scheme eq $other->scheme &&
      $self->as_string eq $other->as_string;  # Case-sensitive
}

# end of URI::URL::eq
1;
