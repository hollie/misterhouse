use strict;

package Group;

@Group::ISA = ('Generic_Item');

sub new {
    my ($class, @items) = @_;
    my $self = {state => ''};
    $$self{members} = [];
    &add($self, @items) if @items;
    bless $self, $class;
    return $self;
}

sub add {
    my ($self, @items) = @_;
    push(@{$$self{members}}, @items);

                                # Define group states according to the first item
    unless ($$self{states}) {
        my $first_item = ${$$self{members}}[0];
        @{$$self{states}} = @{$$first_item{states}} if $first_item and $$first_item{states};
        @{$$self{states}} = split ',', $main::config_parms{x10_menu_states} if $first_item->isa('X10_Item');
#       @{$$self{states}} = qw(on off)                                      if $first_item->isa('X10_Appliance');
        print "Group states: @{$$self{states}}\n" if $first_item and $$self{states} and $main::config_parms{debug}; #&?? WES
    }
}

sub set {
    my ($self, $state) = @_;
    print "Group set: $self lights set to $state members @{$$self{members}}\n" if $main::config_parms{debug};

    &Generic_Item::set_states_for_next_pass($self, $state);

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
#   print "db hc=$hc lr=$last_ref x=$$last_ref{x10_id} inter=$$last_ref{interface}\n";
    for my $ref (@group) {
        if ((ref $ref) !~ /^X10_/ or 
            $hc ne substr($$ref{x10_id}, 1, 1) or
            substr($$ref{x10_id}, 2, 1) eq '' or # Can not group set a house code
            $$ref{interface} ne 'cm11') {
            undef $hc;
#            last;
        }
    }

    if ($hc) {
        for my $ref (@group) {
            print "Group1 setting $ref to $state\n" if $main::config_parms{debug};
            set $ref 'manual';
                                # Set the real state, rather than 'manual'
                                #  - the last element of that array 
#           $ref->{state_next_pass} = $state;
            ${$ref->{state_next_pass}}[-1] = $state;
        }
        set $last_ref $state;
    }
    else {
        for my $ref (@group) {
            print "Group2 setting $ref to $state\n" if $main::config_parms{debug};
            set $ref $state if $ref;
        }
    }
}    

sub list {
    my ($self) = @_;
    print "Group list: self=$self members=@{$$self{members}}\n" if $main::config_parms{debug};
    return sort @{$$self{members}};  # Hmmm, to sort or not to sort.
}

#
# $Log$
# Revision 1.10  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.9  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.8  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.7  2000/06/24 22:10:54  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.6  2000/02/20 04:47:54  winter
# -2.01 release
#
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
