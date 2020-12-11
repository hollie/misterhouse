
=head1 B<SCHEDULE>

=head2 DESCRIPTION

Module for scheduling state changes for objects in misterhouse via the web UI.
This module is useful for scheduling for objects that do not inherit scheduleing
from the Generic_Item or do not have the states that you need by default. 

It is also very useful for thermostat scheduleing as the child object SCHEDULE_Temp
is built exactly for that and allows the scheduled temp changes to be set in real time
from the MH web UI.  

=head2 CONFIGURATION

At minimum, you must define the SCHEDULE and one of the following objects
L<SCHEDULE_Temp> or L<SCHEDULE_Generic>.

The SCHEDULE_Generic objects are for scheduling state changes for any object in misterhouse.
You can make custom states to be listed in the MH web UI.
See L<SCHEDULE_Generic>

The SCHEDULE_Temp objects are for scheduling thermostat temp changes throughout the day. Its 
linked to sets of object which hold the schedule temps and can be changed in the MH web UI
in real time. It also has several overrides such as occupancy checking and outdoor temp. 
See L<SCHEDULE_Temp>

=head2 Interface Configuration

This object has no mh.private.ini configuration.

=head2 Defining the Interface Object

The object must be defined in the user code.

In user code:

$Night = new SCHEDULE('THERMO1');

Wherein the format for the definition is:

   $Night = new SCHEDULE(INSTANCE);


=head2 NOTES

The instance is only needed when multiple schedule object are used together 
for a thermostat schedule.


An example user code for a SCHEDULE_Generic:

	#noloop=start
	use SCHEDULE;
	$SCHEDULE_LIGHT1 = new SCHEDULE();
	$SCHEDULE_SG_LIGHT1 = new SCHEDULE_Generic($SCHEDULE_LIGHT1,$light1,'on','off');  #The states (on and off in this example) are optional. 
	$SCHEDULE2->set_schedule_default(1,'00 1 * * 1-5','off');  #Optionally sets 1st the default schedule. 
	$SCHEDULE2->set_schedule_default(2,'00 5 * * 1-5','on');   #Optionally sets 2nd the default schedule. 
	#noloop=stop

	
An example user code for a SCHEDULE_Temp:

	#noloop=start
	$Night = new SCHEDULE('THERMO1');
	$Normal = new SCHEDULE('THERMO1');
	$Conserve = new SCHEDULE('THERMO1');
	$NightWinter = new SCHEDULE('THERMO1');

	# $NormalCool/$NormalHeat have an UP and DOWN states to change the temp settings in the web interface and they are linked to the Normal schedule object above.
	# $thermostat is the thermostat object that controls my Insteon thermostat, cool_setpoint and heat_setpoint are the subs that are used to set the thermostat setpoint.
	$NormalCool = new SCHEDULE_Temp($Normal,'cool',$thermostat,'cool_setpoint');
	$NormalHeat = new SCHEDULE_Temp($Normal,'heat',$thermostat,'heat_setpoint');

	$NightCool = new SCHEDULE_Temp($Night,'cool',$thermostat,'cool_setpoint');
	$NightHeat = new SCHEDULE_Temp($Night,'heat',$thermostat,'heat_setpoint');

	$NightWCool = new SCHEDULE_Temp($NightWinter,'cool',$thermostat,'cool_setpoint');
	$NightWHeat = new SCHEDULE_Temp($NightWinter,'heat',$thermostat,'heat_setpoint');

	$ConserveCool = new SCHEDULE_Temp($Conserve,'cool',$thermostat,'cool_setpoint');
	$ConserveHeat = new SCHEDULE_Temp($Conserve,'heat',$thermostat,'heat_setpoint');


	# Occupancy Override (optional, I track occupancy by checking to see if my cell is connected to wifi)
	# If the $mode_occupied state is home use the $Normal object temps (from $NormalCool/$NormalHeat), 
	# if the $mode_occupied state changes to work change the temp settings to the $Conserve object temps (from $ConserveCool/$ConserveHeat)
	$Normal->set_occpuancy('home','work',$Conserve); 
	$Night->set_occpuancy('home','work',$Normal);
	$Conserve->set_occpuancy('work','home',$Normal);

	#Forcasted temps equal or below this (50) cause the $NightWinter temps to be used. Pulled from $Weather{Forecast Tonight}.
	$Night->set_winter($NightWinter,'50');

	# Vacation mode. During any active schedule, override the linked temps with the $Conserve temps.
	$Normal->set_vacation($Conserve,'vacation');
	$Night->set_vacation($Conserve,'vacation');
	$Conserve->set_vacation($Conserve,'vacation');
	#noloop=stop

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package SCHEDULE;
@SCHEDULE::ISA = ('Generic_Item');

sub new {
    my ( $class, $instance ) = @_;
    my $self = new Generic_Item();
    $$self{instance} = $instance;
    bless $self, $class;
    @{ $$self{states} } = ( 'ON', 'OFF' );
    $self->restore_data( 'active_object', 'active_action', 'schedule_count' );

    #for my $index (1..$self->{'schedule_count'}) {
    for my $index ( 1 .. 20 ) {
	$self->restore_data( 'schedule_' . $index, 'schedule_label_' . $index, 'schedule_once_' . $index );
    }
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    $self->SUPER::set( $p_state, $p_setby, 1 );
}

sub set_schedule {
    my ( $self, $index, $entry, $label ) = @_;
    ::print_log( "[SCHEDULE] - DEBUG - set_schedule - Index " . $index . " Schedule: " . $entry . " Label " . $label ) if $main::Debug{'schedule'};
    if ( $index > $self->{'schedule_count'} ) { $self->{'schedule_count'} = $index }
    $self->{ 'schedule_' . $index }       = $entry if ( defined($entry) );
    $self->{ 'schedule_label_' . $index } = $label if ( defined($label) );
    if ( defined( $self->{ 'schedule_' . $index } ) ) { # the UI deletes all entries and adds them back which sets this flag to 2.
        $self->{ 'schedule_once_' . $index } = 1 if ( $self->{ 'schedule_once_' . $index } eq 2 );    # We only want real deleted entries set to 2, so set to 1.
    }
    unless ($entry) {
        undef $self->{ 'schedule_label_' . $index };
        undef $self->{ 'schedule_' . $index };
        $self->{ 'schedule_once_' . $index } = 2 if ( $self->{ 'schedule_once_' . $index } );
    }
    $self->{set_time} = $::Time;
}

sub set_schedule_default {
    my ( $self, $index, $entry, $label ) = @_;
    unless ( $self->{ 'schedule_once_' . $index } eq 1 ) {
        if (   ( defined( $self->{ 'set_timer_' . $index } ) ) && ( $self->{ 'set_timer_' . $index }->expired ) ) {
            $self->{ 'schedule_once_' . $index } = 1;
            $self->set_schedule( $index, $entry, $label );
        }
        else {
            $self->{ 'set_timer_' . $index } = ::Timer::new();
            $self->{ 'set_timer_' . $index }->set(
                10,
                sub {
                    $self->set_schedule_once( $index, $entry, $label );
                }
            );
        }
    }
}

sub delete_schedule {
    my ( $self, $index ) = @_;
    $self->set_schedule($index);
}

sub reset_schedule {
    my ($self) = @_;
    my $count = $self->{'schedule_count'};
    for my $index ( 1 .. $count ) {
        $self->set_schedule($index);
    }
    $self->{'schedule_count'} = 0;
    $self->{set_time} = $::Time;
}

sub get_schedule {
    my ($self) = @_;
    my @schedule;
    my $count;
    my @states;
    my $object = @{ $self->{generic_object} }[0] if ( @{ $self->{generic_object} }[0] );
    if ( defined( $object->{state_count} ) ) {
        $count = $object->{state_count};
        if ( $count eq 0 ) {
            @states = $object->{child}->get_states;
        }
        else {
            for my $index ( 1 .. $count ) {
                $states[ $index - 1 ] = $object->{$index};
            }
        }
    }
    else { $states[0] = undef }

    $count          = $self->{'schedule_count'};
    $schedule[0][0] = 0;                           #Index
    $schedule[0][1] = '0 0 5 1 1';                 #schedule
    $schedule[0][2] = 0;                           #Label
    $schedule[0][3] = \@states;
    my $nullcount = 0;
    for my $index ( 1 .. $count ) {
        unless ( defined( $self->{ 'schedule_' . $index } ) ) {
            if ( $self->{ 'schedule_once_' . $index } ) {
                $self->{ 'schedule_once_' . $index }  = 2;
                $self->{ 'schedule_label_' . $index } = undef;
            }
            else {
                $nullcount++;
                $self->{ 'schedule_label_' . $index } = undef;
                $self->{ 'schedule_once_' . $index }  = undef;
                next;
            }
        }

        if ( defined( $self->{ 'schedule_' . $index } ) ) { # the UI deletes all entries and adds them back which sets this flag to 2.
            $self->{ 'schedule_once_' . $index } = 1
              if ( $self->{ 'schedule_once_' . $index } eq 2 );    # We only want real deleted entries set to 2, so set to 1.
        }

        if ( ( defined( $self->{ 'schedule_' . $index } ) ) || ( $self->{ 'schedule_once_' . $index } eq 2 ) ) {
             $self->{ 'schedule_' .       ( $index - $nullcount ) } = $self->{ 'schedule_' . $index };
             $self->{ 'schedule_label_' . ( $index - $nullcount ) } = $self->{ 'schedule_label_' . $index };
             $self->{ 'schedule_once_' .  ( $index - $nullcount ) } = $self->{ 'schedule_once_' . $index };
             $schedule[ ( $index - $nullcount ) ][0] = ( $index - $nullcount );
            if ( $self->{ 'schedule_once_' . $index } eq 2 ) {
                $schedule[ ( $index - $nullcount ) ][1] = undef;
            }
            else {
                $schedule[ ( $index - $nullcount ) ][1] = $self->{ 'schedule_' . $index };
            }

            if ( defined( $self->{ 'schedule_label_' . $index } ) ) {
                $schedule[ ( $index - $nullcount - $schoncecnt ) ][2] = $self->{ 'schedule_label_' . $index };
            }
            else { $schedule[ ( $index - $nullcount ) ][2] = ( $index - $nullcount ) }

            unless ( ( $index - $nullcount ) eq $index ) {
                $self->{ 'schedule_' . $index }       = undef;
                $self->{ 'schedule_label_' . $index } = undef;
                $self->{ 'schedule_once_' . $index }  = undef;
            }
        }
    }
    $self->{'schedule_count'} = scalar @schedule;
    return \@schedule;
}

sub am_i_active_object {
    my ( $self, $instance ) = @_;
    unless ( defined($instance) ) { return 1 }
    ::print_log("[SCHEDULE] - DEBUG - am_i_active_object - current active object: ".$Interfaces{$instance}->get_object_name." checked object: ".$self->get_object_name ) if ( ( defined( $Interfaces{$instance} ) )
        && ( $main::Debug{'schedule'} ) );
    if ( defined( $Interfaces{$instance} ) ) {
        if ( $Interfaces{$instance}->get_object_name eq $self->get_object_name ) { return 1 }
        else { $self->{'active_object'} = 0; return 0; }
    }
    elsif ( $self->{'active_object'} ) {    #This is for a restart to get the saved active object.
        my $action = $self->{'active_action'} if defined( $self->{'active_action'} );
        $self->_set_instance_active_object( $$self{instance}, $action );
        return 1;
    }
    else { return 0 }
}

sub get_instance_active_object {
    my ($instance) = @_;
    return $Interfaces{$instance} if defined($instance);
}

sub get_instance_active_action {
    my ($instance) = @_;
    return $Interfaces{$instance}{'action'} if defined($instance);
}

sub _set_instance_active_object {
    my ( $self, $instance, $action ) = @_;
    $self->{'active_object'} = 1;
    $self->{'active_action'} = $action if defined($action);
    $Interfaces{$instance} = $self if defined($instance);
    $Interfaces{$instance}{'action'} = $action if defined($action);
    my $active_schedule_name = $self->get_object_name if defined($instance);
    $active_schedule_name =~ s/\$//;
    ::print_log( "[SCHEDULE] - Tracking object - ".$Tracking_object{$instance}->get_object_name." Active schedule: ".$active_schedule_name." Instance: ".$instance );
    $Tracking_object{$instance}->set("$active_schedule_name") if ( defined( $Tracking_object{$instance} ) );
}

sub _set_instance_active_tracking_object {
    my ( $child, $instance ) = @_;
    ::print_log( "Registering a SCHEDULE_Temp Child Object type SCHEDULE_Temp_Active");
    $Tracking_object{$instance} = $child;
}

sub get_objects_for_instance {
    my ($self) = @_;
    my $instance = $$self{instance};
    return \@{ $Shedule_objects{$instance} } if defined($instance);
}

=item C<register()>

Used to associate child objects with the interface.

=cut

sub register {
    my ( $self, $object, $child, $HorC ) = @_;
    $self->{schedule_object}   = 1;
    $object->{schedule_object} = 1;
    $child->{schedule_object}  = 1;
    if ( $object->isa('SCHEDULE_Generic') ) {
        ::print_log( "Registering a SCHEDULE Child Object type SCHEDULE_Generic");
        push @{ $self->{generic_object} }, $object;

        #::MainLoop_pre_add_hook( sub {SCHEDULE::check_date($self,$object);}, 'persistent');
        ::MainLoop_pre_add_hook( sub { SCHEDULE::check_date( $self, $object ); } );
    }
    if ( $object->isa('SCHEDULE_Temp') ) {
        ::print_log("Registering a SCHEDULE Child Object type SCHEDULE_Temp");
        $self->{temp_object}{$HorC} = $object;
        if (   ( defined( $self->{temp_object}{'cool'} ) ) && ( defined( $self->{temp_object}{'heat'} ) ) ) {
            #::MainLoop_pre_add_hook( sub {SCHEDULE::check_date($self,$self->{temp_object}{'cool'});}, 'persistent' );
            ::MainLoop_pre_add_hook( sub { SCHEDULE::check_date( $self, $self->{temp_object}{'cool'} ); } );
        }
    }
}

sub check_date {
    my ( $self, $object ) = @_;
    my $occupied_state = ( $$self{occupied}->state_now ) if ( defined( $$self{occupied} ) );

    if ($occupied_state) {
        $self->CheckOverRide if ( ( $self->am_i_active_object( $$self{instance} ) ) && ( lc( state $self) eq 'on' ) );
    }
    elsif ( $$self{winter_mode_type} eq 'track' ) {
        if ( $self->CheckTempOutdoor ) {
            $self->CheckOverRide('temp_track') if ( ( $self->am_i_active_object( $$self{instance} ) ) && ( lc( state $self) eq 'on' ) );
        }
    }

    if ($::New_Minute) {
        $self->am_i_active_object( $$self{instance} ) if ( defined( $$self{instance} ) );
        ::print_log( "[SCHEDULE] - DEBUG - Checking schedule for ".$self->get_object_name." State is ".( state $self)." Child object is ".$object->get_object_name ) if $main::Debug{'schedule'};
        if ( lc( state $self) eq 'on' ) {
            for my $index ( 1 .. $self->{'schedule_count'} ) {
                if ( defined( $self->{ 'schedule_' . $index } ) ) {
                    if ( &::time_cron( $self->{ 'schedule_' . $index } ) ) { &set_action( $self, $object, $index ) }
                }
            }
        }

    }
}

sub setACSetpoint {
    my ( $self, $object ) = @_;
    my $cool_sp               = $object->{temp_object}{'cool'}->state;
    my $cool_temp_control     = $object->{temp_object}{'cool'}{child};
    my $cool_temp_control_sub = $object->{temp_object}{'cool'}{sub};
    my $heat_sp               = $object->{temp_object}{'heat'}->state;
    my $heat_temp_control     = $object->{temp_object}{'heat'}{child};
    my $heat_temp_control_sub = $object->{temp_object}{'heat'}{sub};
    $cool_temp_control->$cool_temp_control_sub($cool_sp);
    ::print_log( "[SCHEDULE] running ".$cool_temp_control->get_object_name."->".$cool_temp_control_sub."(".$cool_sp.")");
    $self->{'set_temp_timer'} = ::Timer::new();
    $self->{'set_temp_timer'}->set(
        '7',
        sub {
            $heat_temp_control->$heat_temp_control_sub($heat_sp);
            ::print_log( "[SCHEDULE] running ".$heat_temp_control->get_object_name."->".$heat_temp_control_sub."(".$heat_sp.")");
        }
    );
}

sub set_action {
    my ( $self, $object, $index ) = @_;
    if ( $object->isa('SCHEDULE_Generic') ) {
        my $sub = 'set';
        $sub = $$self{sub} if defined( $$self{sub} );
        ::print_log( "[SCHEDULE] Running ".$object->{child}->get_object_name."->".$sub."(".$self->{ 'schedule_label_'.$index }.")" );
        $self->_set_instance_active_object( $$self{instance}, $index ) if ( defined( $$self{instance} ) );
        $object->{child}->$sub( $self->{ 'schedule_label_' . $index }, $self->get_object_name, 1 );
    }
    elsif ( $object->isa('SCHEDULE_Temp') ) {
	::print_log( "[SCHEDULE] - DEBUG - set_action -  Temp object: ".$object->get_object_name." Parent object: ".$self->get_object_name ) 
           if $main::Debug{'schedule'};
        $self->_set_instance_active_object( $$self{instance} ) if ( defined( $$self{instance} ) );
        $$self{winter_mode_track_flag} = 0;    # reset the temp track flag because the schedule changed.
        $self->CheckOverRide;
    }
}

sub set_occpuancy {
    my ( $self, $normal_state, $setback_state, $setback_object, $delay,$delay_setback, $tracked_object ) = @_;
    $$self{occ_state}                  = $normal_state;
    $$self{occ_setback_state}          = $setback_state;
    $$self{occ_setback_object}         = $setback_object;
    $$self{thermo_timer_delay}         = '60';
    $$self{thermo_timer_delay}         = $delay if ( defined $delay );
    $$self{thermo_timer_delay_setback} = '60';
    $$self{thermo_timer_delay_setback} = $delay_setback if ( defined $delay_setback );
    $$self{occupied} = $::mode_occupied unless ( defined $$self{occupied} );
    $$self{occupied} = $tracked_object if ( defined $tracked_object );
    $$self{thermo_timer} = ::Timer::new();
}

sub set_winter {
    my ( $self, $object, $temp, $type, $high ) = @_;
    $$self{winter_mode_object} = $object;
    $$self{winter_mode_temp}   = $temp;
    $$self{winter_mode_type}   = lc($type);    # night, day, now
    $$self{winter_mode_type}      = 'night' unless ( defined $type );
    $$self{winter_mode_temp_high} = $high;
}

sub set_vacation {
    my ( $self, $object, $state ) = @_;
    $$self{vacation_mode_object} = $object;
    $$self{vacation_mode_state}  = $state;
    $self->set_occpuancy( undef, undef, undef ) unless ( defined $$self{occupied} );    # Allows the use of vacation mode with out occpuancy
}

sub CheckTempOutdoor {
    unless ( defined( $::Weather{'TempOutdoor'} ) ) { return 0 }
    unless ( defined( $$self{LastTempOutdoor} ) ) {
        $$self{LastTempOutdoor} = $::Weather{'TempOutdoor'};
        return 0;
    }
    if ( $$self{LastTempOutdoor} ne $::Weather{'TempOutdoor'} ) {
        $$self{LastTempOutdoor} = $::Weather{'TempOutdoor'};
        return 1;
    }
}

sub CheckOverRide {
    my ( $self, $checktype ) = @_;
    unless ( $self->am_i_active_object( $$self{instance} ) ) { return 0 }
    my $action = $self->get_instance_active_action( $$self{instance} );
    my $occ_setback_object = $$self{occ_setback_object};
    my $occ_setback_state  = $$self{occ_setback_state};
    my $occ_state          = $$self{occ_state};
    my $object             = $self;
    my $occupied_state     = ( $$self{occupied}->state ) if ( defined( $$self{occupied} ) );

    if ( $self->OverRide ) {
         $occ_setback_object = $$self{override_mode_setback_object} if defined( $$self{override_mode_setback_object} );
         $occ_setback_state  = $$self{override_mode_setback_state}  if defined( $$self{override_mode_setback_state} );
         $occ_state          = $$self{override_mode_occ_state}      if defined( $$self{override_mode_occ_state} );
         $object             = $$self{override_mode_object}         if defined( $$self{override_mode_object} );
    }
    elsif ( $checktype eq 'temp_track' ) { return }
    elsif ( $$self{winter_mode_track_flag} ) { $object = $$self{winter_mode_object} }

    ::print_log( "[SCHEDULE] - INFO - CheckOverRide - Current occupied state:".$occupied_state." Current active object:".$object->get_object_name." state to match: $occ_state" );
    if (   ( defined( $$self{occupied} ) ) && ( $$self{occupied}->state eq $occ_state ) ) {
        if ( $$self{thermo_timer}->expired ) {
            ::print_log( "[SCHEDULE] - INFO - setting ".$object->get_object_name." setpoints, you are now $occ_state" );
            $self->setACSetpoint($object);
        }
        else {
            $$self{thermo_timer}->set(
                $$self{thermo_timer_delay},
                sub {
                    $self->CheckOverRide;
                }
            );
        }
    }
    elsif (( defined( $$self{occupied} ) ) && ( $$self{occupied}->state eq $occ_setback_state ) ) {
        if ( $$self{thermo_timer}->expired ) {
            ::print_log( "[SCHEDULE] - INFO - setting setback ".$occ_setback_object->get_object_name." setpoints, you are now $occ_setback_state" );
            $self->setACSetpoint($occ_setback_object);
        }
        else {
            $$self{thermo_timer}->set(
                $$self{thermo_timer_delay_setback},
                sub {
                    $self->CheckOverRide;
                }
            );
        }
    }
    else {
        $self->setACSetpoint($object);
    }
}

sub OverRide {
    my ($self) = @_;
    my $occupied_state = ( $$self{occupied}->state ) if ( defined( $$self{occupied} ) );
    undef $$self{override_mode_setback_object};
    undef $$self{override_mode_setback_state};
    undef $$self{override_mode_occ_state};
    undef $$self{override_mode_object};
    ::print_log("[SCHEDULE] - DEBUG --- IN OVERRIDE") if $main::Debug{'schedule'};
    if ( $occupied_state eq $$self{vacation_mode_state} ) {
        ::print_log("[SCHEDULE] - DEBUG --- IN OVERRIDE --- VACATION")  if $main::Debug{'schedule'};
        $$self{override_mode_object} = $$self{vacation_mode_object};    # override the setpoint if in vacation mode
        return 1;
    }
    elsif ( $self->WinterMode ) { return 1 }
    return 0;
}

sub WinterMode {

    #return 1;  # temp for testing
    #$::Weather{'Forecast Today'} = 'Sunny. Patchy fog in the morning. Highs in the lower 90s. East winds to 10 mph.';
    my ($self) = @_;
    ::print_log("[SCHEDULE] - DEBUG --- IN WINTERMODE") if $main::Debug{'schedule'};
    if (   ( $$self{winter_mode_type} eq 'night' ) && ( $::Weather{'Forecast Tonight'} =~ /lows in the ([\w ]+) (\d+)/i ) ) {
        ::print_log( "[SCHEDULE] - DEBUG --- IN WINTERMODE --- FORCAST --- $1 $2") if $main::Debug{'schedule'};
        my $fc = $2;
        if ( lc($1) =~ /mid/ ) { $fc = $fc + 3 }    # Translate low, mid, and upper to a value
        if ( lc($1) =~ /up/ ) { $fc = $fc + 6 }
        ##if the value we got from the weather script is equal
        #or lower than our defined value, return the defined winter mode
        if ( $fc <= ( $$self{winter_mode_temp} ) ) {
            ::print_log( "[SCHEDULE] - DEBUG --- IN WINTERMODE  ---- M1 --- LOWS -- $fc -- $$self{winter_mode_temp}" ) if $main::Debug{'schedule'};
            $$self{override_mode_object} = $$self{winter_mode_object};    # override the setpoint if forcast temp is below config
            return 1;
        }
        return 0;
    }
    if (
        ( $$self{winter_mode_type} eq 'day' )
        && ( ( $::Weather{'Forecast Today'} =~ /Highs in the ([\w ]+) (\d+)/i )
            || ( $::Weather{'Forecast Today'} =~ /Highs ([\w ]+) (\d+)/i ) )
      )
    {
        ::print_log( "[SCHEDULE] - DEBUG --- IN WINTERMODE --- FORCAST --- $1 $2") if $main::Debug{'schedule'};
        my $fc = $2;
        if    ( lc($1) =~ /around/ ) { $fc = $fc + 0 }
        elsif ( lc($1) =~ /low/ )    { $fc = $fc + 0 }
        elsif ( lc($1) =~ /mid/ ) { $fc = $fc + 3 }    # Translate low, mid, and upper to a value
        elsif ( lc($1) =~ /up/ ) { $fc = $fc + 6 }
        else { ::print_log( "[SCHEDULE] - NOTICE --- WINTERMODE --- Unknown forecast modifier: $1 -- full text: $::Weather{'Forecast Today'}" ) }
        ##if the value we got from the weather script is equal
        #or lower than our defined value, return the defined winter mode
        if ( $fc <= ( $$self{winter_mode_temp} ) ) {
            ::print_log( "[SCHEDULE] - DEBUG --- IN WINTERMODE  ---- M1 --- LOWS -- $fc -- $$self{winter_mode_temp}") if $main::Debug{'schedule'};
            $$self{override_mode_object} = $$self{winter_mode_object};    # override the setpoint if forcast temp is below config
            return 1;
        }
        return 0;
    }
    if ( ( $$self{winter_mode_type} eq 'now' ) && ( $::Weather{'TempOutdoor'} =~ /(\d+)/i ) ) {
        ::print_log("[SCHEDULE] - DEBUG --- IN WINTERMODE --- TEMP NOW --- $1") if $main::Debug{'schedule'};
        my $fc = $1;
        if ( $fc <= ( $$self{winter_mode_temp} ) ) {
            ::print_log( "[SCHEDULE] - DEBUG --- IN WINTERMODE  --- TEMP NOW -- $fc -- $$self{winter_mode_temp}" ) if $main::Debug{'schedule'};
            $$self{override_mode_object} = $$self{winter_mode_object};    # override the setpoint if current temp is below config
            return 1;
        }
        return 0;
    }
    if (   ( $$self{winter_mode_type} eq 'track' ) && ( $::Weather{'TempOutdoor'} =~ /(\d+)/i ) ) {
        ::print_log("[SCHEDULE] - DEBUG --- IN WINTERMODE --- TEMP TRACK --- $1") if $main::Debug{'schedule'};
        my $fc = $1;
        if (   ( $fc <= ( $$self{winter_mode_temp} ) ) && ( not $$self{winter_mode_track_flag} ) ) {
            $$self{winter_mode_track_flag} = 1;
            ::print_log("[SCHEDULE] - DEBUG --- IN WINTERMODE  --- TEMP TRACK -- TempOutdoor: $fc -- Config low: $$self{winter_mode_temp}") 
               if $main::Debug{'schedule'};
            $$self{override_mode_object} = $$self{winter_mode_object};    # override the setpoint if current temp is below config
            return 1;
        }
        elsif (( $fc > ( $$self{winter_mode_temp_high} ) ) && ( $$self{winter_mode_track_flag} ) ) {
            $$self{winter_mode_track_flag} = 0;
            ::print_log("[SCHEDULE] - DEBUG --- IN WINTERMODE  --- TEMP TRACK -- TempOutdoor: $fc -- Config high: $$self{winter_mode_temp}") 
               if $main::Debug{'schedule'};
            $$self{override_mode_object} = $self;  # set the setpoint back to normal if temp is higher than config
            return 1;
        }
        return 0;
    }
}

=back

=head1 B<SCHEDULE_Generic>

=head2 SYNOPSIS

User code:

    $SCHEDULE_SG_LIGHT1 = new SCHEDULE_Generic($SCHEDULE_LIGHT1,$light1,'on','off'); 

     Wherein the format for the definition is:
    $SCHEDULE_SG_LIGHT1 = new SCHEDULE_Generic(MASTER_SCHEDULE_OBJECT,CONTROLLED_OBJECT,STATES);


=head2 NOTES

The master schedule object (SCHEDULE object) holds the scheduling data which is set using the MH web UI. 
The SCHEDULE_Generic object links the master schedule object to the controlled object and optionally allows the 
user to set custom states to be used in the schedules in the MH web.
The controlled object can be any MH object such as a light.

=head2 DESCRIPTION

Links the master schedule object to the controlled object and optionally allows the user to set custom states 
to be used in the schedules in the MH web.

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package SCHEDULE_Generic;
@SCHEDULE_Generic::ISA = ('Generic_Item');

sub new {
    my $class = @_[0];
    my $self  = new Generic_Item();
    bless $self, $class;
    $$self{parent}      = @_[1];
    $$self{child}       = @_[2];
    $$self{state_count} = ( ( scalar @_ ) - 3 );
    my @states;
    for my $i ( 3 .. ( scalar @_ ) ) {

        if ( defined @_[$i] ) { $self->{ $i - 2 } = @_[$i]; push( @states, @_[$i] ); }
    }
    @{ $$self{states} } = @states if (@states);
    $$self{parent}->register( $self, $$self{child} );
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    $self->SUPER::set( $p_state, $p_setby, 1 );
}

=item C<set_sub()>

Allows the user to change the sub used to set the state of the controlled object. By default 'set' is used.

User code:

    $SCHEDULE_SG_LIGHT1->set_sub('set_cool')
	
	 Wherein the format for the definition is:
	$SCHEDULE_SG_LIGHT1->set_sub(SUB)

=cut

sub set_sub {
    my ( $self, $sub ) = @_;
    $$self{sub} = $sub;
}

=back

=head1 B<SCHEDULE_Temp>

=head2 SYNOPSIS

User code:

    $NormalCool = new SCHEDULE_Temp($Normal,'cool',$thermostat,'cool_setpoint'); 

     Wherein the format for the definition is:
    $NormalCool = new SCHEDULE_Temp(MASTER_SCHEDULE_OBJECT,cool/heat,CONTROLLED_THERMOSTAT_OBJECT,SUB);


=head2 NOTES

The master schedule object (SCHEDULE object) holds the scheduling data which is set using the MH web UI. 
The SCHEDULE_Temp object holds the temp setting for the schedule and links the master schedule object to 
the controlled object.
The controlled object is the thermostat object used to change your thermostat set points. 
cool/heat is literally 'heat' or 'cool', you should have 1 SCHEDULE_Temp object set to 'cool' and 1 set to 'heat'.

=head2 DESCRIPTION

This object holds the temp setting and links the master schedule object to the controlled thermostat object, its also 
where the user can easily change the temp settings for the schedule in the MH web UI.

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package SCHEDULE_Temp;
@SCHEDULE_Temp::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent, $HorC, $child, $sub ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent}      = $parent;
    $$self{HorC}        = $HorC;
    $$self{child}       = $child;
    $$self{sub}         = $sub;
    $$self{state_count} = 7;
    #@{ $$self{states} } = ( 'up', 'down' );
    push @{ $$self{states} }, 'up';
    push @{ $$self{states} }, 'down';
    for my $i (50..85) { push @{ $$self{states} }, "$i"; } # so the UI will add the slider in the object.
    $parent->register( $self, $child, $HorC );
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $current_state = $self->state;
    unless ( defined($current_state) ) { $current_state = '70' }
    if ( $p_state eq 'up' ) {
        ::print_log( "[SCHEDULE::TEMP] Received request ".$p_state." for ".$self->get_object_name );
        $p_state = $current_state + 1;
        $self->SUPER::set( $p_state, $p_setby, 1 );
    }
    if ( $p_state eq 'down' ) {
        ::print_log( "[SCHEDULE::TEMP] Received request ".$p_state." for ".$self->get_object_name );
        $p_state = $current_state - 1;
        $self->SUPER::set( $p_state, $p_setby, 1 );
    }
    if ( $p_state =~ /(\d+)/ ) {
	 $p_state =~ s/\%//;
        ::print_log( "[SCHEDULE::TEMP] Received request ".$p_state." for ".$self->get_object_name, 1);
        $self->SUPER::set( $p_state, $p_setby, 1 );
    }
}

=item C<set_sub()>

Allows the user to change the sub used to set the state of the controlled object. By default 'set' is used.
This can also be set in the SCHEDULE_Temp definition. 

User code:

	$NormalCool->set_sub('set_cool');

	Wherein the format for the definition is:
	$NormalCool->set_sub(SUB)

=cut

sub set_sub {
    my ( $self, $sub ) = @_;
    $$self{sub} = $sub;
}

=back

=head1 B<SCHEDULE_Temp_Active>

=head2 SYNOPSIS

User code:

    $TEMP1_ACTIVE = new SCHEDULE_Temp_Active('THERMO1');

     Wherein the format for the definition is:
    $TEMP1_ACTIVE = new SCHEDULE_Temp_Active(INSTANCE);


=head2 NOTES


The SCHEDULE_Temp_Active object is used to track the active temp schedule for the defined instance.

=head2 DESCRIPTION


=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package SCHEDULE_Temp_Active;
@SCHEDULE_Temp_Active::ISA = ('Generic_Item');

sub new {
    my ( $class, $instance ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    ::SCHEDULE::_set_instance_active_tracking_object( $self, $instance );

    #$Interfaces{$instance}{'temp_active_object'} = $self;
    return $self;
}

=back

=head2 NOTES

=head2 AUTHOR

Wayne Gatlin <wayne@razorcla.ws>

=head2 SEE ALSO

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
