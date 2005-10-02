use strict;

package Group;

@Group::ISA = ('Generic_Item');

sub new {
    my ($class, @items) = @_;
    my $self = {state => undef};
    $$self{members} = [];
    &add($self, @items) if @items;
    bless $self, $class;
    return $self;
}

sub add {
    my ($self, @items) = @_;

                                # Dang, no way to get $self->{object_name} here (it is saved later in user_code)
                                # Not much use without it ... who would do this anyway :)
#   &main::display("Warning, Group containts itself! $self.  Bad idea.") if grep $_ eq $self, @items;

    push(@{$$self{members}}, @items);

                                # This allows us to monitor changed members
	for my $ref (@items) {
		$ref->tie_items($self, undef, 'member changed');
	}

                                # Define group states according to the first item
    unless ($$self{states}) {
        my $first_item = ${$$self{members}}[0];
        @{$$self{states}} = @{$$first_item{states}} if $first_item and $$first_item{states};
        @{$$self{states}} = split ',', $main::config_parms{x10_menu_states} if $first_item->isa('X10_Item');
#       @{$$self{states}} = qw(on off)                                      if $first_item->isa('X10_Appliance');
        print "Group states: @{$$self{states}}\n" if $first_item and $$self{states} and $main::Debug{group};
    }
}

sub set {
    my ($self, $state, $set_by) = @_;
    print "Group set: $self lights set to $state members @{$$self{members}}\n" if $main::Debug{group};

                                # This means we were called by the above
                                # tie_items when a member changed
    if ($state =~ /member changed/) {
        $state = $set_by->{state};

        print "Group member set: set_by=$set_by member=$set_by->{object_name} state=$state\n" if $main::Debug{group};

        &Generic_Item::set_states_for_next_pass($self, "member $state", $set_by);

                                # Log only when a different member fires
                                # This allows us to do stuff like movement direction detection easier
    	if (!$$self{member_changed_log} or $set_by ne ${$$self{member_changed_log}}[0]) {
           unshift(@{$$self{member_changed_log}}, $set_by);
           pop @{$$self{member_changed_log}} if @{$$self{member_changed_log}} > 20;
        }
        return;
    }

    return if &main::check_for_tied_filters($self, $state);
    &Generic_Item::set_states_for_next_pass($self, $state, $set_by);


    unshift(@{$$self{state_log}}, "$main::Time_Date $state");
    pop @{$$self{state_log}} if @{$$self{state_log}} > $main::config_parms{max_state_log_entries};

                                # If we are using a CM11 or similar (and not a CM17),
                                # and they are all X10 objects with the same house code,
                                # then we can get fancy and control X10 devices all at once by
                                # defering the set command for the group to the last object
                                # This will be slightly faster and will result in simultaneous
                                # rather then sequential results.
    my @group = @{$$self{members}};
    my @like_group;
    my @unlike_group;
    my $house_codes = "ABCDEFGHIJKLMNOP";
    my %house_code_last_ref = qw(A undef B undef C undef D undef E undef F undef G undef H undef I undef J undef K undef L undef M undef N undef O undef P undef);
    my $like_group_flag = 0;
    my $last_ref = $group[-1];
    my $i = 0;
    my $hc;

    for my $ref (@group) {
	if ($$ref{x10_id} and substr($$ref{x10_id}, 2, 1) ne '' and $$ref{interface} =~ /cm11|ncpuxa|homebase|stargate/) {
		$hc = substr($$ref{x10_id}, 1, 1);
		$house_code_last_ref{$hc} = $ref;		
	}
    }

    for my $hc (keys %house_code_last_ref) {
	 my $last_ref = $house_code_last_ref{$hc};

	
	 if ($last_ref ne 'undef') {

		for my $ref (@group) {
			if (substr($$ref{x10_id},1,1) eq $hc and $$ref{x10_id} ne $$last_ref{x10_id} and $$ref{interface} =~ /cm11|ncpuxa|homebase|stargate/) {
            			print "Group setting $$ref{x10_id} to $state\n" if $main::Debug{group};
		            	set $ref 'manual';
                                # Set the real state, rather than 'manual'
                                #  - the last element of that array
			        #$ref->{state_next_pass} = $state;
		                ${$ref->{state_next_pass}}[-1] = $state;
		        }
			
		}
	        print "Group setting $$last_ref{x10_id} to $state\n" if $main::Debug{group};
        	set $last_ref $state, $set_by;		

	 }	


    }

  
}

sub list {
    my ($self) = @_;
    print "Group list: self=$self members=@{$$self{members}}\n" if $main::Debug{group};
    return sort @{$$self{members}};  # Hmmm, to sort or not to sort.
}


sub member_changed {
	my ($self) = @_;
    if ($self->{state_now} =~ /^member /) {
#       print "dbx1 s=$self sn=$self->{state_now}  sb=$self->{set_by}\n";
        return $self->{set_by};
    }
}

sub member_changed_log {
	my ($self) = @_;
    return unless $$self{member_changed_log};
	return @{$$self{member_changed_log}};
}


sub remove {
    my ($self, @items) = @_;

    for my $ref(@items) {
	$ref->untie_items($self, undef);
		     # this is definitely not the best way to do it...
		     # in fact it is probably the worse way possible
	@{$$self{members}} = grep { $_ != $ref} @{$$self{members}};
    }
}


#
# $Log$
# Revision 1.21  2005/10/02 17:24:47  winter
# *** empty log message ***
#
# Revision 1.20  2004/11/22 22:57:26  winter
# *** empty log message ***
#
# Revision 1.19  2004/04/25 18:19:52  winter
# *** empty log message ***
#
# Revision 1.18  2003/02/08 05:29:23  winter
#  - 2.78 release
#
# Revision 1.17  2002/09/22 01:33:23  winter
# - 2.71 release
#
# Revision 1.16  2001/08/12 04:02:58  winter
# - 2.57 update
#
# Revision 1.15  2001/04/15 16:17:21  winter
# - 2.49 release
#
# Revision 1.14  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.13  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.12  2000/12/21 18:54:15  winter
# - 2.38 release
#
# Revision 1.11  2000/11/12 21:02:38  winter
# - 2.34 release
#
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
