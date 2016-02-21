
=head1 B<Group>

=head2 SYNOPSIS

  $outside_lights = new Group($light1, $light2, $light3);
  $outside_lights-> add($light4, $light5);
  $outside_lights-> add($light6);
  set $outside_lights ON if time_now("$Time_Sunset + 0:15");

  for my $item (list $outside_lights) {
    print "member = $item->{object_name}\n";
  }

  if (my $member_name = member_changed $outside_lights) {
    my $member = &get_object_by_name($member_name);
    print_log "Group member $member_name changed to $member->{state}"
  }

  my @members = member_changed_log $sensors;

  # turn off all but the bedroom light when we are getting ready for bed
  if( state_now $bedroom_control eq ON ) {
    my $all = new Group(list $All_Lights);
    $all -> remove ( $master_bedroom );
    set $master_bedroom ON;
    set $all OFF;
  }

See mh/code/examples/test_group.pl and mh/code/public/monitor_occupancy_jason.pl for more examples.

=head2 DESCRIPTION

You can use this object to group and operate on groups of items:

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;

package Group;

@Group::ISA = ('Generic_Item');

=item C<new(@item_list)>

=cut

sub new {
    my ( $class, @items ) = @_;
    my $self = new Generic_Item();
    $$self{members} = [];
    &add( $self, @items ) if @items;
    bless $self, $class;
    return $self;
}

=item C<add(@item_list)>

=cut

sub add {
    my ( $self, @items ) = @_;
    my @item_states = ();

    # No way to get $self->{object_name} here (it is saved later in user_code)
    # Not much use without it ... who would do this anyway :)
    #   &main::display("Warning, Group contains itself! $self.  Bad idea.") if grep $_ eq $self, @items;

    push( @{ $$self{members} }, @items );

    # This allows us to monitor changed members
    for my $ref (@items) {
        $ref->tie_items( $self, undef, 'member changed' );

        if ( $ref->isa('X10_Item') ) {
            if ( can_dim($ref) ) {
                @item_states = split ',', $main::config_parms{x10_menu_states};
            }
            else {
                if ( $ref->isa('X10_Camera') ) {
                    @item_states = qw(on off);
                }
                elsif ($ref->isa('X10_Appliance')
                    or $ref->isa('X10_Appliancelinc') )
                {
                    @item_states = qw(on off status);
                }

                else {
                    @item_states = @{ $ref->{states} };
                }
            }

            #			if ($ref->isa('X10_Appliance')) {
            #		        	@item_states = qw(on off status);
            #			}
            #			elsif ($ref->isa('X10_Camera')) { #***Others don't use standard X10 menus (like Scenemaster, Keypadlinc, etc.) Need central function to return menu list per type!
            #				@item_states = qw(on off);
            #			}
            #			else {
            #				@item_states = split ',', $main::config_parms{x10_menu_states};
            #			}
            #
        }

        @item_states = @{ $ref->{states} }
          if $ref
          and $ref->{states}
          and !$ref->isa('X10_Sensor')
          and !$ref->isa('X10_Item')
          ; #***Use the first item found with states for the moment (Need to fix this to aggregate states!)

    }
    my $count = 1;

    for my $state (@item_states) {
        if ( grep $_ eq $state, @{ $$self{states} } ) {

            #			print "***Dupe state: $state\n";
        }
        elsif ( $state and $state !~ /degrees/i ) {

            #			print "***Push state: $state\n";
            push( @{ $$self{states} }, $state );
        }

        #		print "$count. $state\n";
        $count++;
    }

    print "Group states: @{$$self{states}}\n"
      if $$self{states} and $main::Debug{group};

}

sub fancy_controller {    #check if controller is type to combine

}

sub include_in_group {    #check if X10 item is affected by group
                          #check that length > 2 (don't set controllers)
                          #check it is not a transmitter (?)
}

=item C<set>

=cut

sub set {
    my ( $self, $state, $set_by ) = @_;
    print "Group set: $self set to $state members @{$$self{members}}\n"
      if $main::Debug{group};

    # This means we were called by the above
    # tie_items when a member changed
    if ( $state =~ /member changed/ ) {
        $state = $set_by->{state};

        print
          "Group member set: set_by=$set_by member=$set_by->{object_name} state=$state\n"
          if $main::Debug{group};

        &Generic_Item::set_states_for_next_pass( $self, "member $state",
            $set_by );

        # Log only when a different member fires
        # This allows us to do stuff like movement direction detection easier
        if (  !$$self{member_changed_log}
            or $set_by ne ${ $$self{member_changed_log} }[0] )
        {
            unshift( @{ $$self{member_changed_log} }, $set_by );
            pop @{ $$self{member_changed_log} }
              if @{ $$self{member_changed_log} } > 20;
        }
        return;
    }

    return if &main::check_for_tied_filters( $self, $state );
    &Generic_Item::set_states_for_next_pass( $self, $state, $set_by );

    unshift( @{ $$self{state_log} }, "$main::Time_Date $state" );
    pop @{ $$self{state_log} }
      if @{ $$self{state_log} } > $main::config_parms{max_state_log_entries};

    my $ref = $self;
    my $x10_state;
    my $x10_dim_state;
    my $item;
    my $controller;

    $x10_state = grep $_ eq $state,
      ( split ',', $main::config_parms{x10_menu_states} );

    my @fancy_controllers;    #cm11, stargate, etc.
    my @group = @{ $ref->{members} };
    print 'Number of Members: ' . ( $#group + 1 ) . "\n"
      if ( $main::Debug{group} );
    print 'State:' . $state . "\n" if ( $main::Debug{group} );
    print "$state is an X10 command\n" if ( $x10_state && $main::Debug{group} );

    for $item (@group) {
        push @fancy_controllers, $item->{interface}
          if can_combine($item)
          and !( grep $_ eq $item->{interface}, @fancy_controllers );
        print $item->{object_name} . "\n" if ( $main::Debug{group} );
    }
    print 'Interfaces: ' . ( $#fancy_controllers + 1 ) . "\n"
      if ( $main::Debug{group} );

    if ($x10_state) {
        $x10_dim_state =
          !( $state =~ /^on$/i or $state =~ /^off$/i or $state =~ /^status/i );
        if ( $#fancy_controllers == -1 ) {
            set_group_items( $ref, $state );
        }
        else {

            my $house_codes = "ABCDEFGHIJKLMNOP";
            my %house_code_last_ref =
              qw(A 0 B 0 C 0 D 0 E 0 F 0 G 0 H 0 I 0 J 0 K 0 L 0 M 0 N 0 O 0 P 0);

            #count of X10 items in house code
            my %house_code_item_count =
              qw(A 0 B 0 C 0 D 0 E 0 F 0 G 0 H 0 I 0 J 0 K 0 L 0 M 0 N 0 O 0 P 0);

            #count of X10 items in house code for this group
            my %house_code_group_item_count =
              qw(A 0 B 0 C 0 D 0 E 0 F 0 G 0 H 0 I 0 J 0 K 0 L 0 M 0 N 0 O 0 P 0);

            #count of X10 appliances in house code for this group
            my %house_code_group_appliance_count =
              qw(A 0 B 0 C 0 D 0 E 0 F 0 G 0 H 0 I 0 J 0 K 0 L 0 M 0 N 0 O 0 P 0);

            #count of LM14's in house code for this group (these love to lock up the cm11 when sending back extended status while the cm11 is busy, so do them last) (***Not currently implemented as LM14 extended status can be turned off with config command)
            my %house_code_group_lm14_count =
              qw(A 0 B 0 C 0 D 0 E 0 F 0 G 0 H 0 I 0 J 0 K 0 L 0 M 0 N 0 O 0 P 0);
            my $last_ref = $group[-1];
            my $i        = 0;
            my $hc;

            #count up all X10 items per house code
            #only count if item affected by group X10 processing (not a transmitter, controller, TempLinc, etc.)

            for my $object_name ( &main::list_objects_by_type('X10_Item') ) {
                my $object = &main::get_object_by_name($object_name);

                if ( is_group_x10_item($object) ) {
                    my ($house) = $object->{x10_id} =~ /^X(\S)/;
                    $house_code_item_count{$house}++;
                }
            }

            for my $object_name ( &main::list_objects_by_type('X10_Appliance') )
            {
                my $object = &main::get_object_by_name($object_name);
                my ($house) = $object->{x10_id} =~ /^X(\S)/;
                $house_code_item_count{$house}++;
            }

            for $controller (@fancy_controllers) {
                print "Processing group members on interface:$controller\n"
                  if ( $main::Debug{group} );

                for my $ref (@group) {
                    if ( is_group_x10_item($ref) ) {
                        $hc = substr( $$ref{x10_id}, 1, 1 );
                        if ($x10_dim_state) {
                            $house_code_last_ref{$hc} = $ref if can_dim($ref);
                        }
                        else {
                            $house_code_last_ref{$hc} = $ref;
                        }

                        #		$house_code_group_lm14_count{$hc}++ if ($ref->{type} =~ /lm14/i)

                        $house_code_group_item_count{$hc}++;
                        $house_code_group_appliance_count{$hc}++
                          if !can_dim($ref);

                    }
                }

                #testing...

                #    for my $hc (keys %house_code_last_ref) {
                #    	print "$hc: " . $house_code_item_count{$hc} . ' ' . $house_code_group_item_count{$hc} . ' '  . $house_code_group_appliance_count{$hc} . "\n"
                #    }

                for my $hc ( keys %house_code_last_ref ) {
                    if (    $house_code_group_item_count{$hc}
                        and $house_code_last_ref{$hc} )
                    { #Are there any items at all in this group for this house code
                        print "House code: $hc\n" if ( $main::Debug{group} );

                        my $last_ref = $house_code_last_ref{$hc};

                        #If the group's items in this house code are all that exist we can use "all lights on" (only if there are no appliances) or "all off"
                        #Only done if all items in group are on the same controller and there is more than one item to set for this house code (no need to optimize A1AJ to AO.)  Note that this optimization assumes that all X10 items are defined in items.mht.

                        if (
                            $house_code_item_count{$hc} ==
                            $house_code_group_item_count{$hc}
                            and (
                                $state eq 'off'
                                or (    $state eq 'on'
                                    and $house_code_group_appliance_count{$hc}
                                    == 0 )
                            )
                            and $#fancy_controllers == 0
                            and $house_code_item_count{$hc} > 1
                          )
                        {
                            print "Setting $hc to $state with "
                              . (
                                ( $state eq 'on' )
                                ? 'All Lights On'
                                : 'All Off'
                              )
                              . "\n"
                              if ( $main::Debug{group} );
                            &Serial_Item::send_x10_data( $controller,
                                    'X'
                                  . $hc
                                  . ( ( $state eq 'on' ) ? 'O' : 'P' ) );

                        }
                        else {
                            if (    $house_code_item_count{$hc} == 1
                                and $last_ref )
                            {
                                if ( $last_ref->{interface} eq $controller ) {
                                    if ($x10_dim_state) {
                                        print
                                          "Group dimming $$last_ref{object_name} ($$last_ref{x10_id}) to $state on interface $controller\n"
                                          if can_dim($ref)
                                          and $main::Debug{group};
                                        set $last_ref $state, $set_by
                                          if can_dim($ref);
                                    }
                                    else {
                                        print
                                          "Group setting $$last_ref{object_name} ($$last_ref{x10_id}) to $state on interface $controller\n"
                                          if $main::Debug{group};
                                        set $last_ref $state, $set_by;
                                    }
                                }

                            }
                            elsif ($last_ref)
                            { #may not exist if dim command and no dimmers in current house code

                                for my $ref (@group) {
                                    if (    substr( $$ref{x10_id}, 1, 1 ) eq $hc
                                        and $$ref{x10_id} ne $$last_ref{x10_id}
                                        and $$ref{interface} eq $controller
                                        and is_group_x10_item($ref) )
                                    {
                                        if ($x10_dim_state) {
                                            print
                                              "Group setting $ref->{object_name} to manual and ultimately dimming $ref->{object_name}"
                                              if can_dim($ref)
                                              and $main::Debug{group};
                                            set $ref 'manual', $set_by
                                              if can_dim($ref);
                                        }
                                        else {
                                            print
                                              "Group setting $ref->{object_name} to manual and ultimately $state... on interface $controller\n"
                                              if $main::Debug{group};
                                            set $ref 'manual', $set_by;
                                        }

                                        # Set the real state, rather than 'manual'
                                        #  - the last element of that array
                                        #$ref->{state_next_pass} = $state;
                                        ${ $ref->{state_next_pass} }[-1] =
                                          $state;
                                    }
                                }
                                print "Group "
                                  . ( ($x10_dim_state) ? 'dimming' : 'setting' )
                                  . " $$last_ref{object_name} ($$last_ref{x10_id}) to $state on interface $controller\n"
                                  if $main::Debug{group};
                                set $last_ref $state, $set_by;
                            }

                        }
                    }

                }

            }

            #Set non-X10 items and items on controllers not capable of multiple addressing (cm17, etc.)
            for $item (@group) {
                set_group_item( $item, $state )
                  if !can_combine($item)
                  and is_group_item($item);
            }
        }
    }
    else {
        #set one at a time as all items are on old controllers
        set_group_items( $ref, $state );

    }

}

sub aggregate_states {
    my $ref = shift;

    my $item;
    my $state;

    my @group = @{ $ref->{members} };
    my @aggregate_states;

    for $item (@group) {
        if ( $item->isa('Group') ) {
            push @aggregate_states, aggregate_states($item);
            for $state ( @{ $item->{states} } ) {
                push @aggregate_states, $state;
            }
        }

    }
    for $state (@aggregate_states) {
        push @{ $ref->{states} }, $state
          if !( grep $_ eq $state, @{ $ref->{states} } )
          and $state
          and $state !~ /\x20degrees$/i;

    }
    return @aggregate_states;
}

#X10 lamps, wall switches and appliances, TempLinc's and non-X10 items

sub is_group_item {
    my $ref = shift;
    return (
             is_group_x10_item($ref)
          or $ref->isa('X10_TempLinc')
          or !$ref->isa('X10_Item')
    );
}

#x10 controllers, sensors and transmitters are not included in group processing
#Controllers have two character id's
#TempLinc's are not included in group X10 processing as they are two characters as well (they are set by standard group processing if the state set is status.)

sub is_group_x10_item {
    my $ref;

    $ref = shift;
    return (  $ref->{x10_id}
          and length( $ref->{x10_id} ) > 2
          and !$ref->isa('X10_Transmitter')
          and !$ref->isa('X10_Sensor') );

}

#Used to exclude X10 appliances, cameras, etc. from dim state processing

sub can_dim {
    my $ref;
    $ref = shift;
    return ( grep $_ =~ /^dim/i, @{ $ref->{states} } );
}

#X10 lamps, wall switches and appliances on controllers that support manual addressing
#Currently looks for cm11, ncpuxa, homebase, stargate or lynx (ini parameter needed for this!)

sub can_combine {
    my $ref;
    my $can_combine;

    $ref = shift;

    $can_combine = 0;
    $can_combine =
      ( $ref->{interface} =~ /cm11|ncpuxa|homebase|stargate|lynx/i )
      if is_group_x10_item($ref);
    return $can_combine;
}

#Used to determine whether a state is supported for a specific item

sub set_group_item {
    my $ref   = shift;
    my $state = shift;
    print "Desired state is $state\n" if $main::Debug{group};
    print $ref->{object_name}
      . " has states "
      . join( ', ', @{ $ref->{states} } ) . "\n"
      if ( $ref->{states} && $main::Debug{group} );
    print "$ref->{object_name}:$state\n"
      if ( item_state_exists( $ref, $state ) && $main::Debug{group} );
    $ref->set($state) if item_state_exists( $ref, $state );
}

sub item_state_exists {
    my $ref   = shift;
    my $state = shift;
    return ( grep $_ eq $state, @{ $ref->{states} } );
}

#Sets group member item state if applicable

#Sets all applicable group member items using set_group_item

sub set_group_items {
    my $ref   = shift;
    my $state = shift;
    my @group = @{ $ref->{members} };
    my $item;

    for $item (@group) {
        set_group_item $item, $state if is_group_item($item);
    }
}

=item C<list>

=cut

sub list {
    my ( $self, $memberList, $groupList, $no_child_members ) = @_;

    # Not sure if we need to initialize these array refs, but it seems like
    # a good practice to me.
    if ( !defined($memberList) ) {
        $memberList = [];
    }
    if ( !defined($groupList) ) {
        $groupList = [];
    }

    # record that we've started looking at ourselves
    push( @$groupList, $self );
    foreach my $member ( @{ $$self{members} } ) {
        if ( ref($member) eq 'Group' ) {

            # if we've already looked at this group, then we don't need or want to look at it again (avoids infinite loops)
            if ( grep { $_ == $member } @$groupList ) {
                &::print_log( "Warning: detected group loop!  parent: "
                      . $self->get_object_name
                      . ", child: "
                      . $member->get_object_name );
                next;
            }
            push( @$groupList, $member );

            # recursive call, passing along the members that we know about already
            # and the groups that we have looked at
            if ($no_child_members) {
                push( @$memberList, $member );
            }
            else {
                $member->list( $memberList, $groupList );
            }
        }
        else {
            # if the item is already in the list, then we don't need to add it again!
            if ( grep { $_ == $member } @$memberList ) {
                &::print_log( "Warning: detected duplicate member!  group: "
                      . $self->get_object_name
                      . ",  member: "
                      . $member->get_object_name );
                next;
            }
            push( @$memberList, $member );
        }
    }
    return sort @$memberList;    # Hmmm, to sort or not to sort.
}

=item C<member_changed>

Returns a member object name whenever one changes

=cut

sub member_changed {
    my ($self) = @_;
    if ( $self->{state_now} =~ /^member / ) {

        #       print "dbx1 s=$self sn=$self->{state_now}  sb=$self->{set_by}\n";
        return $self->{set_by};
    }
}

=item C<member_changed_log>

Returns a list of recenty changed members.  The first one was the most recently changed.

=cut

sub member_changed_log {
    my ($self) = @_;
    return unless $$self{member_changed_log};
    return @{ $$self{member_changed_log} };
}

=item C<remove>

Remove an item from a group

=cut

sub remove {
    my ( $self, @items ) = @_;

    for my $ref (@items) {
        $ref->untie_items( $self, undef );

        # this is definitely not the best way to do it...
        # in fact it is probably the worse way possible
        @{ $$self{members} } = grep { $_ != $ref } @{ $$self{members} };
    }
}

=back

=head2 INHERITED METHODS

=over

=item C<state>

=item C<state_now>

Like the Generic_Item methods, these return the last state that the group was set to.  If a group member changed, these methods will return 'member $state_name' rather than just '$state_name'.  You can use the member_changed or get_set_by methods to see which member changed.

=item C<state_log>

Returns a list array of the last max_state_log_entries (mh.ini parm) time_date stamped states.

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

#
# $Log: Group.pm,v $
# Revision 1.22  2006/01/29 20:30:17  winter
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
