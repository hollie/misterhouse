use strict;

# This is the parent object for all state-based mh objects.  
# It can also be used stand alone.

package Generic_Item;

my (@reset_states, @states_from_previous_pass);
use vars qw(@items_with_tied_times);

sub new {
    my ($class) = @_;
    my $self = {};
                                # Use undef ... '' will return as defined
    $$self{state}     = undef;
    $$self{said}      = undef;
    $$self{state_now} = undef;
    bless $self, $class;
    return $self;
}

sub set {
    my ($self, $state) = @_;
    return if &main::check_for_tied_filters($self, $state);
    if ($state eq 'toggle') {
        if ($$self{state} eq 'on') {
            $state = 'off';
        }
        else {
            $state = 'on';
        }
        &main::print_log("Toggling X10_Item object $self->{object_name} from $$self{state} to $state");
    }
    &set_states_for_next_pass($self, $state);
}

sub get_changed_by {
    return $_[0]->{changed_by};
}

                                # This is called by mh on exit to save persistant data
sub restore_string {
    my ($self) = @_;

    my $state       = $self->{state};
    my $restore_string = $self->{object_name} . "->{state} = q~$state~;\n" if $state;

    if ($self->{state_log} and my $state_log = join($;, @{$self->{state_log}})) {
        $state_log =~ s/\n/ /g; # Avoid new-lines on restored vars
        $restore_string .= '@{' . $self->{object_name} . "->{state_log}} = split(\$;, q~$state_log~);";
    }
    
                                # Allow for dynamicaly/user defined save data
    for my $restore_var (@{$$self{restore_data}}) {
        my $restore_value = $self->{$restore_var};
        $restore_string .= $self->{object_name} . "->{$restore_var} = q~$restore_value~;\n" if $restore_value;
    }

    return $restore_string;
}

sub restore_data {
    return unless $main::Reload;
    my ($self, @restore_vars) = @_;
    push @{$$self{restore_data}}, @restore_vars;
}


sub hidden {
    return unless $main::Reload;
    my ($self, $flag) = @_;
                                # Set it
    if (defined $flag) {
        $self->{hidden} = $flag;
    }
    else {                      # Return it, but this currently only will work on $Reload.
        return $self->{hidden};
    }
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
                                # Set it
    if (defined $icon) {
        $self->{icon} = $icon;
    }
    else {                      # Return it
        return $self->{icon};
    }
}

sub set_info {
    return unless $main::Reload;
    my ($self, $text) = @_;
                                # Set it
    if (defined $text) {
        $self->{info} = $text;
    }
    else {                      # Return it
        return $self->{info};
    }
}

sub set_authority {
    return unless $main::Reload;
    my ($self, $who) = @_;
    $self->{authority} = $who;
}
sub get_authority {
    return $_[0]->{authority};
}

sub set_states {
    return unless $main::Reload;
    my ($self, @states) = @_;
    @{$$self{states}} = @states;
}
sub add_states {
    return unless $main::Reload;
    my ($self, @states) = @_;
    push @{$$self{states}}, @states;
}
sub get_states {
    return unless $main::Reload;
    my ($self) = @_;
    return @{$$self{states}};
}

sub set_states_for_next_pass {
    my ($ref, $state) = @_;
    push @states_from_previous_pass, $ref unless $ref->{state_next_pass} and @{$ref->{state_next_pass}};
    push @{$ref->{state_next_pass}}, $state;

                                # Set the state_log
    $state  = '' if !$state or $state eq '1';
                                # Log non-blank states
    unshift(@{$$ref{state_log}}, "$main::Time_Date $state") if $state or (ref $ref) eq 'Voice_Cmd';
    pop @{$$ref{state_log}} if $$ref{state_log} and @{$$ref{state_log}} > $main::config_parms{max_state_log_entries};

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
        $ref->{state_prev}  = $ref->{state};
        $ref->{change_pass} = $main::Loop_Count;
        $ref->{state}       = $state;
        $ref->{said}        = $state;
        $ref->{state_now}   = $state;
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
    my ($self, $object, $state, $desiredstate, $log_msg) = @_;
    $state         = 'all_states' unless defined $state;
    $desiredstate  = $state       unless defined $desiredstate;
    $log_msg = 1            unless $log_msg;
    return if $$self{tied_objects}{$object}{$state};
    $$self{tied_objects}{$object}{$state}{$desiredstate} = [$object, $log_msg];
}

sub tie_event {
#   return unless $main::Reload;
    my ($self, $event, $state, $log_msg) = @_;
    $state   = 'all_states' unless defined $state;
    $log_msg = 1            unless $log_msg;
    $$self{tied_events}{$event}{$state} = $log_msg;
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

sub tie_filter {
#   return unless $main::Reload;
    my ($self, $filter, $state, $log_msg) = @_;
    $state   = 'all_states' unless defined $state;
    $log_msg = 1            unless $log_msg;
    $$self{tied_filters}{$filter}{$state} = $log_msg;
}
sub untie_filter {
    my ($self, $filter, $state) = @_;
    if ($state) {
        delete $self->{tied_filters}{$filter}{$state};
    }
    elsif ($filter) {
        delete $self->{tied_filters}{$filter}; # Untie all states
    }
    else {
        delete $self->{tied_filters}; # Untie em all
    }        
}

sub tie_time {
    my ($self, $time, $state, $log_msg) = @_;
    $state   = 'on' unless defined $state;
    $log_msg = 1    unless $log_msg;
    push @items_with_tied_times, $self unless $$self{tied_times};
    $$self{tied_times}{$time}{$state} = $log_msg;
}
sub untie_time {
    my ($self, $time, $state) = @_;
    if ($state) {
        delete $self->{tied_times}{$time}{$state};
    }
    elsif ($time) {
        delete $self->{tied_times}{$time}; # Untie all states
    }
    else {
        delete $self->{tied_times}; # Untie em all
    }        
}
sub delete_old_tied_times {
    undef @items_with_tied_times;
}


#
# $Log$
# Revision 1.13  2001/04/15 16:17:21  winter
# - 2.49 release
#
# Revision 1.12  2001/02/24 23:26:40  winter
# - 2.45 release
#
# Revision 1.11  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.10  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.9  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.8  2000/09/09 21:19:11  winter
# - 2.28 release
#
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
