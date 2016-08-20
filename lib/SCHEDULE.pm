package SCHEDULE;
@SCHEDULE::ISA = ('Generic_Item');


sub new
{
   my ($class, $instance) = @_;
   my $self = new Generic_Item();
   $$self{instance} = $instance;
   bless $self, $class;
   @{$$self{states}} = ('ON','OFF');
   $self->restore_data('active_object', 'active_action', 'schedule_count');
    #for my $index (1..$self->{'schedule_count'}) {
    for my $index (1..10) {
      $self->restore_data('schedule_'.$index);
     }
   return $self;
}



sub set {
         my ($self, $p_state, $p_setby, $p_response) = @_;
         $self->SUPER::set($p_state,$p_setby,1);
        }

#sub set_schedule {
#         my ($self, $type, $p_state) = @_;
#         $$self{'schedule'}{'type'} = lc($type);
#         my @cals;
#         #$self{'type'} = 'calendar';
         #$self{'schedule'}{'7'}{'28'}{'20'}{'41'}{'action'} = 'start';
         #$self{'schedule'}{'7'}{'28'}{'20'}{'42'}{'action'} = 'stop';
#          if ($p_state =~ /-/) { @cals = split /-/, $p_state }
#          else { @cals = ($p_state) }
#          foreach my $values (@cals) {
#           my @calvals = split /,/, $values;
#            $$self{'schedule'}{$calvals[1]}{$calvals[2]}{$calvals[3]}{$calvals[4]}{'action'} = lc($calvals[0]) if ($type eq 'calendar');
#            $$self{'schedule'}{lc($calvals[1])}{$calvals[2]}{$calvals[3]}{'action'}  = lc($calvals[0]) if ($type eq 'daily');
#            $$self{'schedule'}{lc($calvals[1])}{$calvals[2]}{$calvals[3]}{'action'}  = lc($calvals[0]) if ($type eq 'wdwe');
#            $$self{'schedule'}{$calvals[1]}{$calvals[2]}{'action'} = lc($calvals[0]) if ($type eq 'time');
#          }
# }

sub set_schedule {
    my ($self,$index,$entry,$label) = @_;
    #my $index = (split /,/, $entry)[0];
    #$[ = 1;
    #@{$self->{'schedule'}}[$index] = $entry if (defined($entry));
    if ($index > $self->{'schedule_count'}) { $self->{'schedule_count'} = $index } 
    $self->{'schedule_'.$index} = $entry if (defined($entry));
    $self->{'schedule_set_flag'} = 1;
    $self->{set_time} = $main::Time;
}


sub get_schedule{
 my ($self,$label_only) = @_;
 my @schedule;
 my $count;
 my $object = @{$self->{generic_object}}[0] if (@{$self->{generic_object}}[0]);
  if ($label_only) {
         if (defined($object->{state_count})) { $count = $object->{state_count}; }
	 else {  $count = 7;}
	 for my $index (1..$count) {
    	   if (defined($object->{$index})) { $schedule[$index] = $object->{$index}; } 
           else { $schedule[$index] = $index; }
	 }
   return \@schedule;
  }
     if ((defined($object->{state_count})) && ($object->{state_count} > $self->{'schedule_count'})) { $count = $object->{state_count} }
     else { $count = $self->{'schedule_count'} } 
 
     $schedule[0][0] = 0;
     $schedule[0][1] = '0 0 5 1 1';
     $schedule[0][2] = 0;
     for my $index (1..$count) {
        #::print_log("[SCHEDULE] - index - ".$index . " entry - ". $self->{'schedule_'.$index});
        #$[ = 1;
                $schedule[$index][0] = $index;
                $schedule[$index][1] = $self->{'schedule_'.$index};
		if (defined($object->{$index})) { $schedule[$index][2] = $object->{$index}; } 
		else { $schedule[$index][2] = $index; }
      }
   return \@schedule;
}

sub am_i_active_object{
  my ($self,$instance) = @_;
  unless (defined($instance)) { return 1 } 
  ::print_log("[SCHEDULE] - am_i_active_object - active object: ".$Interfaces{$instance}->get_object_name." check object: ".$self->get_object_name) if (defined($Interfaces{$instance}));
  if (defined($Interfaces{$instance})) {
     if ($Interfaces{$instance}->get_object_name eq $self->get_object_name) { return 1 }
     else { $self->{'active_object'} = 0; return 0; }
  } elsif ($self->{'active_object'}) { #This is for a restart to get the saved active object.
     my $action = $self->{'active_action'} if defined($self->{'active_action'});
     $self->_set_instance_active_object($$self{instance},$action); 
     return 1;
  } else { return 0 }
}
 
sub get_instance_active_object{
   my ($instance) = @_;
   return $Interfaces{$instance} if defined($instance);
}


sub get_instance_active_action{
   my ($instance) = @_;
   return $Interfaces{$instance}{'action'} if defined($instance);
}


sub _set_instance_active_object{
   my ($self, $instance, $action) = @_;
   $self->{'active_object'} = 1;
   $self->{'active_action'} = $action if defined($action);
   $Interfaces{$instance} = $self if defined($instance);
   $Interfaces{$instance}{'action'} = $action if defined($action);
}


sub get_objects_for_instance {
   my ($self) = @_;
   my $instance = $$self{instance};
   return \@{$Shedule_objects{$instance}} if defined($instance);
}


=item C<register()>

Used to associate child objects with the interface.

=cut

sub register {
   my ($self, $object, $child, $state1, $state2) = @_;
    if ($object->isa('SCHEDULE_Generic')) {
      ::print_log("Registering a SCHEDULE Child Object type SCHEDULE_Generic" );
          push @{$self->{generic_object}}, $object;
          ::MainLoop_pre_add_hook( sub {SCHEDULE::check_date($self,$object);}, 'persistent');
     }
   if ($object->isa('SCHEDULE_Temp')) {
      my $HorC = $child;
      ::print_log("Registering a SCHEDULE Child Object type SCHEDULE_Temp" );
            $self->{temp_object}{$HorC} = $object;
	    if ((defined($self->{temp_object}{'cool'})) && (defined($self->{temp_object}{'heat'}))) {
               	  ::MainLoop_pre_add_hook( sub {SCHEDULE::check_date($self,$self->{temp_object}{'cool'});}, 'persistent' );
	     }
   }
}



#sub check_date {
# my ($self,$object) = @_;
# my $occupied_state = ($$self{occupied}->state_now) if (defined($$self{occupied})); 
# if ($occupied_state) { $self->ChangeACSetpoint if (($self->am_i_active_object($$self{instance})) && (lc(state $self) eq 'on')) }
  
# if ($::New_Minute) {
#  ::print_log("[SCHEDULE] Checking schedule for ". $self->get_object_name." Sate is ". (state $self) . " Child object is ". $object->get_object_name);
#   if (lc(state $self) eq 'on') {
#     my $Week;
#     if ($::Weekday) { $Week = 'weekday' } elsif ($::Weekend) { $Week = 'weekend' }
#     if (($$self{'schedule'}{'type'} eq 'calendar') &&
#        (defined(my $action = $$self{'schedule'}{$::Month}{$::Mday}{$::Hour}{$::Minute}{'action'}))) {
#	      &set_action($self,$object,$action);
#       }
#      elsif (($$self{'schedule'}{'type'} eq 'daily') &&
#          (defined(my $action = $$self{'schedule'}{lc($::Day)}{$::Hour}{$::Minute}{'action'}))) {
#	      &set_action($self,$object,$action);
#       }
#      elsif (($$self{'schedule'}{'type'} eq 'wdwe') &&
#          (defined(my $action = $$self{'schedule'}{$Week}{$::Hour}{$::Minute}{'action'}))) {
#	      &set_action($self,$object,$action);
#       }
#      elsif (($$self{'schedule'}{'type'} eq 'time') &&
#          (defined(my $action = $$self{'schedule'}{$::Hour}{$::Minute}{'action'}))) {
#	      &set_action($self,$object,$action);
#       }
#    }
#
#  }
#}


sub check_date {
 my ($self,$object) = @_;
# if ($Startup||$Reload) {
  #$self->restore_data('active_object','active_action','schedule_count');
  #$self->_set_instance_active_object($$self{instance},$$self{active_action}) if (defined($$self{instance}) && $$self{active_object});
  # for my $index (1..$self->{'schedule_count'}) {
  #   $self->restore_data('schedule_'.$index) unless($self->{'schedule_set_flag'});
  # }
# }

# unless(defined($self->get_instance_active_object)) {
#  $self->_set_instance_active_object($$self{instance},$$self{active_action}) if (defined($$self{instance}) && $$self{active_object});
# }   

#  $self->restore_data('active_object') unless(defined($self->{'active_object'}));
#  $self->restore_data('active_action') unless(defined($self->{'active_action'}));
#  $self->restore_data('schedule_count') unless(defined($self->{'schedule_count'}));
 # unless($self->{'schedule_set_flag'}) { 
#    for my $index (1..$self->{'schedule_count'}) {
#      $self->restore_data('schedule_'.$index) unless(defined($self->{'schedule_'.$index}));
#     }
 #  }


# if ($::New_Minute) {
#      ::print_log("[SCHEDULE] - active object ". $self->{'active_object'} ) if (defined($self->{'active_object'}));
#   ::print_log("[SCHEDULE] - active_action ". $self->{'active_action'} ) if (defined($self->{'active_action'}));
#   ::print_log("[SCHEDULE] - schedule_count ". $self->{'schedule_count'} ) if (defined($self->{'schedule_count'}));
#
#     for my $index (1..$self->{'schedule_count'}) {
#   #    $self->set_schedule('schedule_'.$index);
#       ::print_log("[SCHEDULE] - restored schedule ".$self->{'schedule_'.$index} ." for ".$self->get_object_name);
#      }
#      #::print_log("[SCHEDULE] - restored active object ". $self->get_object_name ) if (($self->am_i_active_object($$self{instance}));
# }


 my $occupied_state = ($$self{occupied}->state_now) if (defined($$self{occupied}));
 if ($occupied_state) { $self->ChangeACSetpoint if (($self->am_i_active_object($$self{instance})) && (lc(state $self) eq 'on')) }

 if ($::New_Minute) {
  $self->am_i_active_object($$self{instance}) if (defined($$self{instance}));;
  ::print_log("[SCHEDULE] Checking schedule for ". $self->get_object_name." Sate is ". (state $self) . " Child object is ". $object->get_object_name);
   if (lc(state $self) eq 'on') {
    #foreach my $values (@{$self->{'schedule'}}) {
    for my $index (1..$self->{'schedule_count'}) {
       #my @calvals = split /,/, $self->{'schedule_'.$index};
        # if (&::time_cron($calvals[1])) { &set_action($self,$object,$calvals[0]) } 
         if (&::time_cron($self->{'schedule_'.$index})) { &set_action($self,$object,$index) }
       } 
    }

  }
}


sub setACSetpoint {
  my ($self,$object) = @_;
  my $cool_sp = $object->{temp_object}{'cool'}->state;
  my $cool_temp_control = $object->{temp_object}{'cool'}{child};
  my $cool_temp_control_sub = $object->{temp_object}{'cool'}{sub};
  my $heat_sp = $object->{temp_object}{'heat'}->state;
  my $heat_temp_control = $object->{temp_object}{'heat'}{child};
  my $heat_temp_control_sub = $object->{temp_object}{'heat'}{sub};
  $cool_temp_control->$cool_temp_control_sub($cool_sp);
  $heat_temp_control->$heat_temp_control_sub($heat_sp);
  

  ::print_log("[SCHEDULE] running ".$cool_temp_control->get_object_name."->".$cool_temp_control_sub."(".$cool_sp.")");
  ::print_log("[SCHEDULE] running ".$heat_temp_control->get_object_name."->".$heat_temp_control_sub."(".$heat_sp.")");
}

sub set_action {
    my ($self,$object,$action) = @_;
      if ($object->isa('SCHEDULE_Generic')) {
         ::print_log("[SCHEDULE] Setting ".$object->{child}->get_object_name." state to ".$object->{$action});
         $self->_set_instance_active_object($$self{instance},$action) if (defined($$self{instance}));
	 $object->{child}->SUPER::set($object->{$action},$self->get_object_name,1);
      }
         elsif ($object->isa('SCHEDULE_Temp')) {
         ::print_log("[SCHEDULE] set_action -  Temp object: ".$object->get_object_name." Parent object: ".$self->get_object_name);
         $self->_set_instance_active_object($$self{instance}) if (defined($$self{instance}));
         $self->ChangeACSetpoint;
      }
}

sub set_occpuancy {
  my ($self, $normal_state, $setback_state, $setback_object, $delay, $delay_setback, $tracked_object) = @_;
  $$self{occ_state} = $normal_state;
  $$self{occ_setback_state} = $setback_state;
  $$self{occ_setback_object} = $setback_object;
  $$self{thermo_timer_delay} = '60';
  $$self{thermo_timer_delay} = $delay if (defined $delay);
  $$self{thermo_timer_delay_setback} = '60';
  $$self{thermo_timer_delay_setback} = $delay_setback if (defined $delay_setback);
  $$self{occupied} = $::mode_occupied unless (defined $$self{occupied});
  $$self{occupied} = $tracked_object if (defined $tracked_object);
  $$self{thermo_timer} = ::Timer::new();
}


sub set_winter {
  my ($self, $object, $temp) = @_;
  $$self{winter_mode_object} = $object;
  $$self{winter_mode_temp} = $temp
}


sub set_vacation {
  my ($self, $object, $state) = @_;
  $$self{vacation_mode_object} = $object;
  $$self{vacation_mode_state} = $state;
}

 
sub ChangeACSetpoint {
my ($self,$object) = @_;
unless ($self->am_i_active_object($$self{instance})) { return 0 }
my $action = $self->get_instance_active_action($$self{instance});
my $occ_setback_object = $$self{occ_setback_object};
my $occ_setback_state = $$self{occ_setback_state};
my $occ_state = $$self{occ_state};
my $object = $self;
my $occupied_state = ($$self{occupied}->state) if (defined($$self{occupied}));

print_log("[THERMO] - DEBUG --- in ChangeACSetpoint") if ($config_parms{"thermo_schedule"} eq 'debug');

    if (&OverRide($self)) {
	   $occ_setback_object = $$self{override_mode_setback_object} if defined($$self{override_mode_setback_object});
	   $occ_setback_state = $$self{override_mode_setback_state} if defined($$self{override_mode_setback_state});
	   $occ_state = $$self{override_mode_occ_state} if defined($$self{occ_state});
	   $object = $$self{override_mode_object} if defined($$self{override_mode_object});
    }
	&main::print_log("[THERMO] - INFO - ChangeACSetpoint - " . $occupied_state ." ". $object->get_object_name ." state match:  $occ_state");
       if ((defined($$self{occupied})) && ($$self{occupied}->state eq $occ_state)) {
	    &main::print_log("[THERMO] - INFO - ChangeACSetpoint - occ state match ". $object->get_object_name ." setpoints, you are now $occ_state");
           if ($$self{thermo_timer}->expired) {
                &main::print_log("[THERMO] - INFO - setting ". $object->get_object_name ." setpoints, you are now $occ_state");
                $self->setACSetpoint($object);
            } else {  
                $$self{thermo_timer}->set($$self{thermo_timer_delay}, sub {
                   $self->ChangeACSetpoint;
                });
            }
       } elsif ((defined($$self{occupied})) && ($$self{occupied}->state eq $occ_setback_state)) {
           if ($$self{thermo_timer}->expired) {
                &main::print_log("[THERMO] - INFO - setting setback ". $occ_setback_object->get_object_name ."setpoints, you are now $occ_setback_state");
                $self->setACSetpoint($occ_setback_object);
            } else { 
                $$self{thermo_timer}->set($$self{thermo_timer_delay_setback}, sub {
                   $self->ChangeACSetpoint;
                });
            }
       } else {
                $self->setACSetpoint($object);
      }
}


sub OverRide {
my ($self) = @_;
my $occupied_state = ($$self{occupied}->state) if (defined($$self{occupied}));
undef $$self{override_mode_setback_object};
undef $$self{override_mode_setback_state};
undef $$self{override_mode_occ_state};
undef $$self{override_mode_object};
  print_log("[THERMO] - DEBUG --- IN OVERRIDE") if ($config_parms{"thermo_schedule"} eq 'debug');
  if ($occupied_state eq 'vacation') {
         print_log("[THERMO] - DEBUG --- IN OVERRIDE --- VACATION") if ($config_parms{"thermo_schedule"} eq 'debug');
		 $$self{override_mode_setback_object} = $$self{vacation_mode_object}; # override the setpoint if in vacation mode
		 $$self{override_mode_setback_state} = $$self{vacation_mode_state}; # override the setback state if in vacation mode
         return 1;
  } elsif ($self->WinterMode) {
        print_log("[THERMO] - DEBUG --- IN OVERRIDE --- WINTERMODE") if ($config_parms{"thermo_schedule"} eq 'debug');
		$$self{override_mode_object} = $$self{winter_mode_object}; # override the setpoint if forcast temp is below config
        return 1;
  }
 return 0;
}


sub WinterMode {
#return 1;  # temp for testing
my ($self) = @_;
    print_log("[THERMO] - DEBUG --- IN WINTERMODE") if ($config_parms{"thermo_schedule"} eq 'debug');
   if ($::Weather{'Forecast Tonight'} =~ /lows in the ([\w ]+) (\d+)/i) {
        print_log("[THERMO] - DEBUG --- IN WINTERMODE --- FORCAST --- $1 $2") if ($config_parms{"thermo_schedule"} eq 'debug');
        my $fc = $2;
        if (lc($1) =~ /mid/) { $fc = $fc + 3 } # Translate low, mid, and upper to a value
        if (lc($1) =~ /up/) { $fc = $fc + 6 }
           ##if the value we got from the weather script is equal
            #or lower than our defined value, return the defined winter mode
       if ($fc <= ($$self{winter_mode_temp})) {
         ::print_log("[THERMO] - DEBUG --- IN WINTERMODE  ---- M1 --- LOWS -- $fc -- $$self{winter_mode_temp}") if ($config_parms{"thermo_schedule"} eq 'debug');
         return 1;
       }
     return 0;
   }
 }
 

package SCHEDULE_Generic;
@SCHEDULE_Generic::ISA = ('Generic_Item');


sub new
{
   my $class = @_[0];
   my $self = new Generic_Item();
   bless $self, $class;
   $$self{parent} = @_[1];
   $$self{child} = @_[2];
   $$self{state_count} = ((scalar @_) - 3);
   my @states;
   for my $i (3..(scalar @_)) { if (defined @_[$i]) { $self->{$i-2}=@_[$i]; push (@states, @_[$i]); } }
   @{$$self{states}} = @states;
   $$self{parent}->register($self,$child);
   return $self;
}



sub set {
    my ($self, $p_state, $p_setby, $p_response) = @_;
    $self->SUPER::set($p_state,$p_setby,1);
}


package SCHEDULE_Temp;
@SCHEDULE_Temp::ISA = ('Generic_Item');


sub new
{
   my ($class, $parent, $HorC, $child, $sub) = @_;
   my $self = new Generic_Item();
   bless $self, $class;
   $$self{parent} = $parent;
   $$self{HorC} = $HorC;
   $$self{child} = $child;
   $$self{sub} = $sub;
   $$self{state_count} = 7;
   @{$$self{states}} = ('up','down');
   $parent->register($self,$HorC);
   return $self;
}



sub set {
    my ($self, $p_state, $p_setby, $p_response) = @_;
	my $current_state = $self->state; 
	unless (defined($current_state)) { $current_state = '70' }
        if ($p_state eq 'up') {
         ::print_log("[SCHEDULE::TEMP] Received request "
           . $p_state ." for ". $self->get_object_name); 
                 $p_state = $current_state + 1;
         $self->SUPER::set($p_state,$p_setby,1);
        }
        if ($p_state eq 'down') {
         ::print_log("[SCHEDULE::TEMP] Received request "
            . $p_state ." for ". $self->get_object_name);
                 $p_state = $current_state - 1;
         $self->SUPER::set($p_state,$p_setby,1);
       }
        if ($p_state =~ /(\d+)/) {
         ::print_log("[SCHEDULE::TEMP] Received request "
           . $p_state ." for ". $self->get_object_name,1);
         $self->SUPER::set($p_state,$p_setby,1);;
       }
}
