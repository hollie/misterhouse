use strict;

package Group;

sub new {
    my ($class, @items) = @_;
    my $self = {};
    $$self{members} = [@items];
    bless $self, $class;
    my $first_item = $items[0];
    @{$$self{states}} = @{$$first_item{states}} if $first_item;
    print "Group states: @{$$self{states}}\n" if $main::config_parms{debug};
    return $self;
}

sub add {
	my ($self, @items) = @_;
    push(@{$$self{members}}, @items);
                                # Define group states according to the first item
}

sub set {
    my ($self, $state) = @_;
    print "Group set: $self lights set to $state members @{$$self{members}}\n" if $main::config_parms{debug};

    $self->{state} = $state;
    unshift(@{$$self{state_log}}, "$main::Time_Date $state");
    pop @{$$self{state_log}} if @{$$self{state_log}} > $main::config_parms{max_state_log_entries};

                                # If we are using a CM11 (and not a CM17),
                                # and they are all X10 objects with the same house code, 
                                # then we can get fancy and control X10 devices all at once by 
                                # defering the set command for the group to the last object
                                # This will be slightly faster and will result in simultaneous
                                # rather then sequential results.
    my @group = @{$$self{members}};
    my $last_ref = $group[-1];
    my $hc = substr($$last_ref{x10_id}, 1, 1);
#   print "db hc=$hc lr=$last_ref x=$$last_ref{x10_id}\n";
    for my $ref (@group) {
        if ((ref $ref) !~ /^X10_/ or 
            $hc ne substr($$ref{x10_id}, 1, 1)) {
            undef $hc;
            last;
        }
    }
    if ($hc and $main::config_parms{cm11_port}) {
        for my $ref (@group) {
            print "Group 1 setting $ref to $state\n" if $main::config_parms{debug};
            set $ref 'none';
            $ref->{state_next_pass} = $state; # Set the real state, rather than none
        }
        set $last_ref $state;
    }
    else {
        for my $ref (@group) {
            print "Group 2 setting $ref to $state\n" if $main::config_parms{debug};
            set $ref $state if $ref;
        }
    }
}    

sub state {
    return @_[0]->{state};
} 

sub state_log {
    my ($self) = @_;
    return @{$$self{state_log}} if $$self{state_log};
}

sub list {
    my ($self) = @_;
    print "Group list: self=$self members=@{$$self{members}}\n" if $main::config_parms{debug};
    return sort @{$$self{members}};  # Hmmm, to sort or not to sort.
}

#
# $Log$
# Revision 1.5  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.4  2000/01/27 13:40:26  winter
# - update version number
#
# Revision 1.3  2000/01/09 18:49:02  winter
# - add set_next_pass to CM11 set
#
# Revision 1.2  2000/01/02 23:44:00  winter
# - add the X10-CM11-on-same-house-code check in set method
#
# Revision 1.1  1999/02/16 02:04:07  winter
# - created
#
#

1;
