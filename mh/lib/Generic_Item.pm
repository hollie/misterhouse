use strict;

package Generic_Item;

my (@reset_states, @states_from_previous_pass);

sub new {
    my ($class) = @_;
    my $self = {};
    $$self{state} = '';
    bless $self, $class;
    return $self;
}

sub state {
    return @_[0]->{state};
} 

sub state_now {
    return @_[0]->{state_now};
} 

sub set {
    my ($self, $state) = @_;
    $self->{state_next_pass} = $state;
    push(@states_from_previous_pass, $self);
}

sub reset_states {
    my $ref;
    while ($ref = shift @reset_states) {
        undef $ref->{state_now};
    }

    while ($ref = shift @states_from_previous_pass) {
        $ref->{state}     = $ref->{state_next_pass};
        $ref->{state_now} = $ref->{state_next_pass};
        undef $ref->{state_next_pass};
        push(@reset_states, $ref);
    }
}


#
# $Log$
# Revision 1.1  2000/01/19 14:00:52  winter
# Initial revision
#
# Revision 1.3  1999/02/16 02:04:27  winter
# - add set method
#
# Revision 1.2  1999/01/30 19:50:51  winter
# - add state_now and reset_states loop
#
# Revision 1.1  1999/01/24 20:04:13  winter
# - created
#
#

1;
