use strict;

# This is the parent object for all state-based mh objects.  
# It can also be used stand alone.

package Generic_Item;

my (@reset_states, @states_from_previous_pass);


sub new {
    my ($class) = @_;
    my $self = {};
    $$self{state}     = '';
    $$self{said}      = '';
    $$self{state_now} = '';
    bless $self, $class;
    return $self;
}

sub set {
    my ($self, $state) = @_;
    &set_states_for_next_pass($self, $state);
}

sub get_changed_by {
    return $_[0]->{changed_by};
}

sub state {
    return $_[0]->{state};
#   my $state = $_[0]->{state}
#   return ($state) ? $state : ''; # Avoid -w unintialized variable errors
} 

sub said {
    return $_[0]->{said};
}

sub state_now {
    return $_[0]->{state_now};
}

sub state_log {
    my ($self) = @_;
    return @{$$self{state_log}} if $$self{state_log};
}

sub set_icon {
    return unless $main::Reload;
    my ($self, $icon) = @_;
    $self->{icon} = $icon;
}

sub set_info {
    return unless $main::Reload;
    my ($self, $text) = @_;
    $self->{info} = $text;
}

sub set_states_for_next_pass {
    my ($ref, $state) = @_;
    push @states_from_previous_pass, $ref unless $ref->{state_next_pass} and @{$ref->{state_next_pass}};
    push @{$ref->{state_next_pass}}, $state;

                                # Set the state_log
    $state  = '' if !$state or $state eq '1';
    unshift(@{$$ref{state_log}}, "$main::Time_Date $state");
    pop @{$$ref{state_log}} if @{$$ref{state_log}} > $main::config_parms{max_state_log_entries};

                                # Reset this (used to detect which tied item triggered the set)
                                #  - Default to self, rather than blank
    $ref->{changed_by} = $ref;
}

                                # Reset, then set, states from previous pass
sub reset_states {
    my $ref;
    while ($ref = shift @reset_states) {
        undef $ref->{state_now};
        undef $ref->{said};
    }

                                # Allow for multiple sets from the same pass
                                #  - each will get run, one per subsequent pass
    my @items_with_more_states;
    while ($ref = shift @states_from_previous_pass) {
        my $state = shift @{$ref->{state_next_pass}};
        $ref->{state}     = $state;
        $ref->{said}      = $state;
        $ref->{state_now} = $state;
        push @reset_states, $ref;
        push @items_with_more_states, $ref if @{$ref->{state_next_pass}};
    }
    @states_from_previous_pass = @items_with_more_states;

                                # Set/fire tied objects/events
                                #  - do it in main, so eval works ok
    &main::check_for_tied_events(@reset_states);
}

sub tie_items {
#   return unless $main::Reload;
    my ($self, $object, $state, $desiredstate) = @_;
    $state = 'all_states' unless defined $state;
    return if $$self{tied_objects}{$object}{$state};
    $$self{tied_objects}{$object}{$state} = [$object, $desiredstate];
}

sub tie_event {
#   return unless $main::Reload;
    my ($self, $event, $state) = @_;
    $state = 'all_states' unless defined $state;
    $$self{tied_events}{$event}{$state} = 1;
}

sub untie_items {
    my ($self, $object, $state) = @_;
#   $state = 'all_states' unless $state;
    if ($state) {
        delete $self->{tied_objects}{$object}{$state};
    }
    elsif ($object) {
        delete $self->{tied_objects}{$object}; # Untie all states
    }
    else {
        delete $self->{tied_objects}; # Untie em all
    }
}

sub untie_event {
    my ($self, $event, $state) = @_;
#   $state = 'all_states' unless $state;
    if ($state) {
        delete $self->{tied_events}{$event}{$state};
    }
    elsif ($event) {
        delete $self->{tied_events}{$event}; # Untie all states
    }
    else {
        delete $self->{tied_events}; # Untie em all
    }        
}

#
# $Log$
# Revision 1.7  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.6  2000/06/24 22:10:54  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.5  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.4  2000/01/27 13:39:27  winter
# - update version number
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
