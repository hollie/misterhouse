=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Occupancy_Monitor.pm

Description:
	Counts the number of people in a network of motion sensors.
	
Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	Example initialization:

	use Occupancy_Monitor;
	$om = new Occupancy_Monitor();

	# draw up a diagram of house rooms and number the connected rooms passageways
	# add the sensors and their connections in the example as follows
   # Note that these nodes are actually edges between rooms.  So, if you have
   # a motion detector in a hallway connected to two rooms, it would have two
   # nodes, one each for the boundry between the hallway and each room.
	$garage_motion->set_fp_nodes(1);
	$garage_hall_motion->set_fp_nodes(1,2);
	$basement_motion->set_fp_nodes(2);
	$kitchen_motion->set_fp_nodes(2,3);
	$family_motion->set_fp_nodes(3,4);
	$foyer_motion->set_fp_nodes(4,5,6);
	$living_motion->set_fp_nodes(2,5);
	$den_motion->set_fp_nodes(6,7);
	$hall_motion->set_fp_nodes(4,7,8,9);
	$robert_bedroom->set_fp_nodes(8);
	$celine_bedroom->set_fp_nodes(9,10);
	$master_bedroom->set_fp_nodes(9,11);

   # You can have more than one motion detector and/or door with the same nodes,
   # but be sure to add all of them to the $om as below:

	$om->add($Inside_Motion_Group);

	$garage_door_switch->tie_items($om,'off','reset');
	$utility_door_switch->tie_items($om,'off','reset');
	$patio_door_switch->tie_items($om,'off','reset');
	$front_door_switch->tie_items($om,'off','reset');

	$om->tie_event('info_monitor($state, $object)');

	sub info_monitor
	{
		my ($p_state, $p_setby) = @_;
		if ($p_state =~ /^min/ or $p_state =~ /^last/){
			 print_log "Current People count: $p_state";	
		}
	}

	Input states:
		on
      motion
      alertmin   - Motion or door opening
		reset      - Resets all statistics

	Output states:
		"minimum:xxx"	- Minimum count of people
		"current:xxx"	- Current count of people on last sensor report
		"average:xxX" 	- Running average count of people
		"last:xxx"	- Last sensor to report
		<input states>  - All input states are echoed exactly to the output state as 
				  well.

Bugs:
	None that I am aware of.

Special Thanks to: 
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut
use strict;

package Occupancy_Monitor;

my $room_counts = 1;

@Occupancy_Monitor::ISA = ('Generic_Item');

sub new
{
	my ($p_class,$p_obj,@p_nodes) = @_;

	my $self={};
	bless $self, $p_class;

	@{$$self{states}} = ('reset','current','min','avg');
#	$self->add($p_obj,@p_nodes) if (defined $p_obj);
	$self->add($p_obj) if (defined $p_obj);
	return $self;
}

sub reset
{
	my ($self) = @_;
	@{$$self{m_object_log}} = ();
	$$self{m_cur_count} = 0;
	$$self{m_min_count} = 0;
	#reset room presence vars as well
	for my $obj (keys %{$$self{m_objects}}) {
		$$self{m_objects}{$obj}{count} = 0;
	}
}

sub add
{
	my ($self, $p_obj) = @_;

	my @l_objs;

	if ($p_obj->isa("Group")) {
		@l_objs = @{$$p_obj{members}};
		for my $obj (@l_objs) {
			$self->add($obj);
		}				
	}
	else
	{
		$self->add_item($p_obj);
	}

}

sub add_item #add single item
{
	my ($self, $p_obj) = @_;

	my @l_nodes;

	$$self{m_objects}{$p_obj}{object} = $p_obj;
	$$self{m_objects}{$p_obj}{count} = 0;
	$p_obj->tie_items($self,'on');
	$p_obj->tie_items($self,'motion');
	$p_obj->tie_items($self,'alertmin');
	$p_obj->tie_items($self,'open');
}

sub add_log
{
	my ($self, $p_obj) = @_;
	
	my @l_tmpAry;
	my $l_Result = 0;
	my @l_ary1;
	my @l_ary2;

	# check for duplicate nodes
	if (defined @{$$self{m_object_log}}[0]) {
		@l_ary1 = @{$$self{m_object_log}}[0]->get_fp_nodes(),
		@l_ary2 = $p_obj->get_fp_nodes();
#		&::print_log("Compare ". @{$$self{m_object_log}}[0]->{object_name} . " to " . $p_obj->{object_name} );
		$l_Result = $self->compare_array(
			\@l_ary1,
			\@l_ary2 );
		if ($l_Result == 1) { 
#			&::print_log( "**Duplicate**");
			return 0; 
		}	#if nodes match then dont add object, duplicate
		
	}
	@l_tmpAry = @{$$self{m_object_log}};
#	&::print_log("Log:" . $p_obj->{object_name} . ",$p_obj:@l_tmpAry:");
	unshift @{$$self{m_object_log}}, $p_obj;
	@{$$self{m_object_log}} = @{$$self{m_object_log}}; # re-sequence indexes 0+
	@l_tmpAry = @{$$self{m_object_log}};
#	&::print_log("Log:" . $p_obj->{object_name} . ",$p_obj:@l_tmpAry:");
		
	#limit 20 log items (can only resolv up to 20 people)
	if (@{$$self{m_object_log}} > 20) { pop(@{$$self{m_object_log}}); }
	return 1;
}

sub set
{
	my ($self, $p_state, $p_setby) = @_;	
	
	$_ = $p_state;
	if (/on/i or /motion/i or /alertmin/i or /open/i) {
		if (defined $p_setby and $p_setby ne '') {
			if ($self->add_log($p_setby)) {	
				$self->calc_presence($p_setby);
				$$self{m_cur_count} = $self->calc_total();
				if ($$self{m_cur_count} > $$self{m_min_count}) {
					$$self{m_min_count} = $$self{m_cur_count};
					$self->SUPER::set('changed:'. $$self{m_min_count}, $p_setby);	
				}
				$p_state = "current:" . $self->cur_count() . ";minimum:" . $self->min_count() . ";last:" . $p_setby->{object_name};
			}
		}		
	} elsif (/reset/i) {
		$self->reset();
		$p_state = 'changed:0';
	}
	$self->SUPER::set($p_state, $p_setby);	
}

sub calc_presence
{
	my ($self, $p_obj) = @_;

	my @l_ary1;
	my @l_ary2;
	my $l_obj2;

	@l_ary1 = $p_obj->get_fp_nodes();
#	&::print_log("Presence Check:" . $$p_obj{object_name});

	#decrement any connected nodes
		#only decrement if first entering the node
	if ($$self{m_objects}{$p_obj}{count} <= 0 or $$self{m_objects}{$p_obj}{count} eq '') {
	 	for my $obj ( keys %{$$self{m_objects}} ) {
			$l_obj2 = $$self{m_objects}{$obj}{object};
			if ($l_obj2 ne '') {
#				&::print_log("iter:$obj:$l_obj2->{object_name}");
#				&::print_log("checking: " . $l_obj2->{object_name});
				@l_ary2 = $l_obj2->get_fp_nodes();
				if ($self->compare_array_elements(\@l_ary1,\@l_ary2)) {
#					&::print_log("Destroy:" . $l_obj2->{object_name});
					# clear nodes that had presence before, and mark -1 
					# prediction for nodes that havent been visited yet
					if ( $$self{m_objects}{$obj}{count} > 0 ) {
						$$self{m_objects}{$obj}{count} = 0;
						#Recurse and clear previous predictions
#						for my $obj_i ( keys %{$$self{m_objects}} ) {
#							$obj2_i = $$self{m_objects}{$obj_i}{object};
#							my @ary2_i = $obj2_i->get_fp_nodes();
#							if ($$self{m_objects}{obj_i}{count} < 0 and 
#								$self->compare_array_elements(\@l_ary2,\@ary2_i)) {
#								$$self{m_objects}{obj_i}{count} = 0;
#							}
#						}
					} else { #these nodes havent been visited. mark with -1
						$$self{m_objects}{$obj}{count} = -1;
					}
				}
			}
		}
	}

	#increment current motion
 	for my $obj ( keys %{$$self{m_objects}} ) {
		$l_obj2 = $$self{m_objects}{$obj}{object};
		if ($l_obj2 ne '') {
			@l_ary2 = $l_obj2->get_fp_nodes();
			if ($self->compare_array(\@l_ary1, \@l_ary2)) {
#				&::print_log("Add:" . $l_obj2->{object_name});
				$$self{m_objects}{$obj}{count} = 1;
				$$self{m_objects}{$obj}{time} = $::Time_Date;
			}
		}
	}

}

sub calc_total
{
	my ($self) = @_;

	my $l_Index = 0;
	my $l_Ubound;
	my $l_Result;
	my @l_NodePool;

	my $l_obj1;
	my $l_obj2;

	my @l_ary1;
	my @l_ary2;

	$l_Ubound = @{$$self{m_object_log}};

	#Seed the node pool before the search
	if ($l_Ubound > 0) {
		push @l_NodePool, @{$$self{m_object_log}}[0]->get_fp_nodes();
	} else { # bail out if object is not found
		return 0;
	}

	for ($l_Index = 0; $l_Index < $l_Ubound - 1; $l_Index++)
	{
		$l_obj1 = @{$$self{m_object_log}}[$l_Index];
		$l_obj2 = @{$$self{m_object_log}}[$l_Index+1];
		@l_ary2 = $l_obj2->get_fp_nodes();

		$l_Result = $self->compare_array_elements(
			\@l_NodePool,
			\@l_ary2
			);

		if ($l_Result == 1) { #If nodes not distinct then done counting
			return $l_Index + 1;
		}
		push @l_NodePool, @l_ary2; #add previous nodes together to search all
 
	}
	return $l_Index + 1;
}

sub min_count
{
	my ($self) = @_;
	return $$self{m_min_count};	
}

sub cur_count
{
	my ($self) = @_;
	return $$self{m_cur_count};	
}

sub sensor_count
{
	my ($self, $p_obj, $p_count) = @_;

	$$self{m_objects}{$p_obj}{count} = $p_count if defined $p_count;
	return $$self{m_objects}{$p_obj}{count};
}

sub list_presence_string
{
	my ($self)= @_;

	my @sensor_names;
	my $l_obj2;
	my $l_tmp;
	my $l_time;

	for my $obj ( keys %{$$self{m_objects}} ) {
		$l_obj2 = $$self{m_objects}{$obj}{object};
		if ($$self{m_objects}{$obj}{count} > 0 ) {
			$l_tmp=$l_obj2->{object_name};
			$l_time=&::my_str2time($::Time_Date) - &::my_str2time($$self{m_objects}{$obj}{time});
			$l_tmp=~ s/\$//;
			$l_tmp=~ s/_/ /g;
			push @sensor_names, $l_tmp . " $l_time seconds, ";
		}
	}
	return "@sensor_names";			
}


sub compare_array # compare arrays to see if all elements are present in the other
{
	my ($self, $p_ary1, $p_ary2) = @_[0,1,2];
	
	my @l_ary1;
	my @l_ary2;
	
	my $l_match = 0;

	@l_ary1 = @{$p_ary1};
	@l_ary2 = @{$p_ary2};

	if (@l_ary1 != @l_ary2) { #if the number of elements doesnt match then they are obviously not the same
		return 0;
	}
#	&::print_log( "CmpA: @l_ary1 : @l_ary2");
	foreach my $item1 (@{$p_ary2})
	{
		$l_match=0;
		foreach my $item2 (@{$p_ary1})
		{
			if ($item1 == $item2)
			{
				$l_match=1;
			}
		}
		if ($l_match ne 1) { #didnt find an element in the other then bail out, dont match
			return 0;
		}
	}
	return 1;
}

sub compare_array_elements #find any array elements in any elements of other array
{
	my ($self, $p_ary1, $p_ary2) = @_[0,1,2];
	
	my @l_ary1;
	my @l_ary2;
	
	@l_ary1 = @{$p_ary1};
	@l_ary2 = @{$p_ary2};

#	&::print_log("Cmp: @l_ary1 : @l_ary2");
	foreach my $item1 (@{$p_ary2})
	{
		foreach my $item2 (@{$p_ary1})
		{
			if ($item1 == $item2)
			{
				return 1;
			}
		}
	}
	return 0;
}

sub writable
{
	return 0;
}

1;

