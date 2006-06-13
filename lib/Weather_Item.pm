use strict;

package Weather_Item;

# $w_x = new Weather_Item(TempIndoor);     # returns value (eg 72)
# $w_x = new Weather_Item('TempIndoor > 99') # returns evaluated expression if defined else return value undefined

@Weather_Item::ISA = ('Generic_Item');
my @weather_item_list;

sub Init {
    &::MainLoop_pre_add_hook(  \&Weather_Item::check_weather, 1 );
}

# *** Trigger

sub check_weather {
    if($::New_Msecond_250)
    {
        for my $self (@weather_item_list) {
            my $state = $self->state; # Gets current state
            if (!defined $self->{state} or $self->{state} ne $state) {
                &Generic_Item::set_states_for_next_pass($self,  $state);
            }
        }
    }
}


sub item_transform($) {
    $_ = shift;
    ($_ =~ /^(and|or|not|eq|ne|clear|cloudy|sunny|partly|mostly)$/i)?"$_":"\$::Weather{$_}";
}

sub new {
   my ($class, $type) = @_;
   my @members;

   if ($type) {
      $type =~ s/\x20+/\x20/g; 				# consolidate spaces
      $type =~ s/([^0-9 \W]+)/item_transform($1)/egi; 	# markup items
      $type =~ s/(partly cloudy|partly sunny|mostly cloudy|mostly sunny|clear|cloudy)/"'" . ucfirst(lc($1)) . "'"/egi;	 				# normalize condition strings
      $type =~ s/ = '/ eq '/gi; 			# quote condition strings

      $type =~ s/[^<>]=/==/g;				# double equal signs (no assignments allowed)
	# *** test with super syntax as well as module function calls

      $type =~ s/&[^0-9 \W]+:{0,}[^0-9 \W]+\(.*\)//g;	# no function calls either (for safety)
      $type =~ s/(state|item_transform|check_weather)//gi; # short-circuit methods (hack)

      eval $type;					# validate
      if ($@) {
         warn "Weather_Item:$type did not evaluate (" . $@ . ')';	# error in expression
      }
      else { 						# validated, create item
	# Save weather hash keys in member list (to be checked for existence in state sub before expression is evaluated)

	    while ($type =~ /\$::Weather{(.*?)}/g) {		
		push @members, $1 if !grep $1 eq $_, @members;	
	    }
      }
   }
   else {
      warn 'Empty expression is not allowed.';
   }


    my $self = {type => $type, list => @members};
    bless $self, $class;
    push @weather_item_list, $self;
    return $self;         


}

sub state {
    my ($self) = @_;
    my $valid;

    $valid = 1;

    # check that all members are defined

    my @members = $self->{list};

    for (@members) { # short-circuit evaluation if any member is undefined
	$valid = 0 if !defined $main::Weather{$_};
    }

    # evaluate expression if so

    return eval $self->{type} if $valid;
}

sub default_setstate {
    warn "Unable to control the weather.";
    return -1;
}

1;


#
# $Log: Weather_Item.pm,v $
# Revision 1.6  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.5  2001/08/12 04:02:58  winter
# - 2.57 update
#
#
