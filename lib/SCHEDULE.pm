package SCHEDULE;
@SCHEDULE::ISA = ('Generic_Item');


sub new
{
   my ($class) = @_;
   my $self = new Generic_Item();
   bless $self, $class;
   @{$$self{states}} = ('ON','OFF');
   return $self;
}



sub set {
         my ($self, $p_state, $p_setby, $p_response) = @_;
         $self->SUPER::set($p_state,$p_setby,1);
        }

sub set_schedule {
	 my ($self, $type, $p_state) = @_;
         $self{'schedule'}{'type'} = lc($type);
         my @cals;
	 #$self{'type'} = 'calendar';
	 #$self{'schedule'}{'7'}{'28'}{'20'}{'41'}{'action'} = 'start';
	 #$self{'schedule'}{'7'}{'28'}{'20'}{'42'}{'action'} = 'stop';
	  if ($p_state =~ /-/) { @cals = split /-/, $p_state } 
	  else { @cals = ($p_state) } 
	  foreach my $values (@cals) {
	   my @calvals = split /,/, $values;
	    $self{'schedule'}{$calvals[1]}{$calvals[2]}{$calvals[3]}{$calvals[4]}{'action'} = lc($calvals[0]) if ($type eq 'calendar');
	    $self{'schedule'}{lc($calvals[1])}{$calvals[2]}{$calvals[3]}{'action'}  = lc($calvals[0]) if ($type eq 'daily');
            $self{'schedule'}{lc($calvals[1])}{$calvals[2]}{$calvals[3]}{'action'}  = lc($calvals[0]) if ($type eq 'wdwe');
            $self{'schedule'}{$calvals[1]}{$calvals[2]}{'action'} = lc($calvals[0]) if ($type eq 'time');
	  }
 }



=item C<register()>

Used to associate child objects with the interface.

=cut

sub register {
   my ($self, $object, $child, $start, $stop) = @_;
   if ($object->isa('SCHEDULE_Generic')) {
      ::print_log("Registering a SCHEDULE Child Object type SCHEDULE_Generic" );
	  push @{$self->{generic_object}}, $object;
	  ::MainLoop_pre_add_hook( sub {SCHEDULE::check_date($self,$object);}, 'persistent');
   }
}



sub check_date { 
  my ($self,$object) = @_;
  if ($::New_Minute) {
  ::print_log("[SCHEDULE] Checking schedule for ". $self->get_object_name." Sate is ". (state $self) . " Child object is ". $object->get_object_name);
  if (lc(state $self) eq 'on') {
     my $Week;
     if ($::Weekday) { $Week = 'weekday' } elsif ($::Weekend) { $Week = 'weekend' }
     if (($self{'schedule'}{'type'} eq 'calendar') &&
	   (defined(my $action = $self{'schedule'}{$::Month}{$::Mday}{$::Hour}{$::Minute}{'action'}))) {
         ::print_log("[SCHEDULE] Setting ".$object->{child}->get_object_name." state to ".$object->{$action});
         $object->{child}->SUPER::set($object->{$action},$self->get_object_name,1);
       }
      elsif (($self{'schedule'}{'type'} eq 'daily') &&
	  (defined(my $action = $self{'schedule'}{lc($::Day)}{$::Hour}{$::Minute}{'action'}))) {
         ::print_log("[SCHEDULE] Setting ".$object->{child}->get_object_name." state to ".$object->{$action});
         $object->{child}->SUPER::set($object->{$action},$self->get_object_name,1);
       }
      elsif (($self{'schedule'}{'type'} eq 'wdwe') &&
	  (defined(my $action = $self{'schedule'}{$Week}{$::Hour}{$::Minute}{'action'}))) {
         ::print_log("[SCHEDULE] Setting ".$object->{child}->get_object_name." state to ".$object->{$action});
         $object->{child}->SUPER::set($object->{$action},$self->get_object_name,1);
       }
      elsif (($self{'schedule'}{'type'} eq 'time') &&
	  (defined(my $action = $self{'schedule'}{$::Hour}{$::Minute}{'action'}))) {
         ::print_log("[SCHEDULE] Setting ".$object->{child}->get_object_name." state to ".$object->{$action});
         $object->{child}->SUPER::set($object->{$action},$self->get_object_name,1);
       }
    }

  }
}
	
	
package SCHEDULE_Generic;
@SCHEDULE_Generic::ISA = ('Generic_Item');


sub new
{
   my ($class, $parent, $child, $start, $stop) = @_;
   my $self = new Generic_Item();
   bless $self, $class;
   $$self{parent} = $parent;
   $$self{child} = $child;
   $$self{start} = $start;
   $$self{stop} = $stop;
   $parent->register($self,$child,$start,$stop);
   if (defined($start)) {
    @{$$self{states}} = ($start,$stop);
   } else { 
    @{$$self{states}} = ($child->get_states()); 
   }
   return $self;
}



sub set {
    my ($self, $p_state, $p_setby, $p_response) = @_;
    $self->SUPER::set($p_state,$p_setby,1);
}


