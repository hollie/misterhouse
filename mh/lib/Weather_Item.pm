use strict;

package Weather_Item;

# $x = new Weather_Item(TempIndoor);     # returns e.g. 68/82/etc
# $x = new Weather_Item(TempIndoor, '>' ,99) # returns e.g. false/true

@Weather_Item::ISA = ('Generic_Item');
my @weather_item_list;

sub Init {
    &::MainLoop_pre_add_hook(  \&Weather_Item::check_weather, 1 );
}

sub check_weather {
    if($::New_Msecond_250)
    {
        for my $self (@weather_item_list) {
            next unless defined $main::Weather{$self->{type}};
            my $state = $self->state; # Gets current state
            if (!defined $self->{state} or $self->{state} ne $state) {
                &Generic_Item::set_states_for_next_pass($self,  $state);
            }
        }
    }
}

sub new {
    my ($class, $type) = @_;

                                # Allow for 'Wind > 10' type tests
    my ($comparison, $limit);
    if ($type =~ /(\S+) *([\=\<\>]) *(\S+)/) {
        $type       = $1;
        $comparison = $2;
        $limit      = $3;
    }
                                # Simple check for blanks (in case we used a bad operated above)
                                # Too early to check for a valid %Weather key :(
    if($type =~ / /) {
        print "Invalid Weather_Item type: $type.\n";
        return;
    }

    my $self = {type => $type, comparison => $comparison, limit => $limit};
    bless $self, $class;
    push @weather_item_list, $self;
    return $self;
}

sub state {
    my ($self) = @_;
    return undef unless defined $main::Weather{$self->{type}};
    return $main::Weather{$self->{type}} unless $self->{comparison};
    return ($main::Weather{$self->{type}} <  ($self->{limit}) ? 1 : 0) if $self->{comparison} eq '<';
    return ($main::Weather{$self->{type}} >  ($self->{limit}) ? 1 : 0) if $self->{comparison} eq '>';
    return ($main::Weather{$self->{type}} == ($self->{limit}) ? 1 : 0) if $self->{comparison} eq '=';
}

sub set {
    print "Sorry, unable to control the weather.\n";
}

1;


#
# $Log$
# Revision 1.5  2001/08/12 04:02:58  winter
# - 2.57 update
#
#
