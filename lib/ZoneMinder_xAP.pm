
# Package: ZoneMinder_xAP
# $Date$
# $Revision$

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Description:

	This package provides an interface to a ZoneMinder (www.zoneminder.com)
	installation via the xAP (ww.xapautomation.org) "connector": zmxap
	(www.limings.net/xap/zmxap).

Compatibility:

	Requires ZoneMinder v1.22.x and above.  Requires zmxap v0.6 (and above).

Author:
	Gregg Liming
	gregg@limings.net

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	Documentation on installing/configuring ZoneMinder is found at 
	www.zoneminder.com. Information on installing/configuring zmxap
	is found in the release package and at
	www.zoneminder.com/wiki/index.php/Zmxap.  Both ZoneMinder and zmxap
	must be run on the same system and requires a Linux distro.  This
	module may be run on any system that mh runs. 

	The xAP message convention assumes that the zoneminder connector, zmxap,
	is addressed via the target: zm.zoneminder.<devicename> 

	The default value for <devicename> as declared within zmxap is "house".
	This value may be overriden via the ini param: zoneminder_devicename.
	Ensure that there are no special characters in the devicename.

	Each zoneminder installation will be comprised of one or more "monitors".
	Each monitor will be associated with a single hardware camera.  The monitor
	implements the motion analysis and other means of controlling operation
	specific to a camera.  The ZM_MotionItem class encapsulates logic specific 
	to a zoneminder monitor. Similarly, each monitor may define one or more 
	motion analysis "zones"--defined as polygons within the camera's viewing area.
	The ZM_ZoneItem class encapsulates logic specific to zoneminder zones.
	In addition, a ZM_ZoneItem instance is intended to be compatible as a child
	of a Motion_Item--allowing zoneminder zones to participate within the 
	Motion/Presence/Occupancy suite of object witin mh.

     --------------------------------------
     ZM_MonitorItem
     --------------

     Declaration:

	ZM_MONITOR, driveway, my_monitor, Outside|Driveway; 
        # driveway is the name of the zoneminder monitor 

	# associate zones
        ZM_ZONE, near, zone_near, my_monitor
        ZM_ZONE, far, zone_far, my_monitor 
        # "near" and "far" are zoneminder zones for the driveway monitor

	Also, zones can be "wrapped" by Motion_Items so that they can participate
	in presence/occupancy logic:

	my $near_motion_item = new MotionItem($zone_near);
	my $near_presence_item = new Presence_Item($near_motion_item);

        If a Light_Item is added to the monitor, then motion analysis can be automatically
        suspended for x seconds when the Light_Item is turned on or off.  If one or more
        Photocell_Item's are added, then prevent Light_Item blanking if at least one of the 
        Photocells' state is "light" (since the Light_Item's turning on and/or off would
        no longer impact motion analysis).
 
     Properties:

	id - integer; the value assigned to the monitor by zoneminder

        external_trigger - [ enabled | disabled ] must be enabled if triggering via 
		this xAP interface is needed; default is disabled

	monitor_mode - [ triggered | continuous | disabled ] triggered is set if only 
		external triggers are used; modect (or any other form of continuous
		motion anaysis) causes continueous to be set; otherwise, disabled

	record_mode - [ ondemand | continuous | disabled ] ondemand is set if modect;
		continuous is set if "record" (as a zm mode); otherwise disabled

	monitor_state - [ on | off ] off if the monitor is disabled w/i zoneminder;
		otherwise on is the default

	light_blanking_duration - sets the duration of a motion analysis "blanking"
		period, *if* a Light_Item is added to the monitor.  This mechanism
		allows automatic motion analysis suspend and resume around the time of
		a light turning on and off based on the blanking duration.  This 
		is useful when lighting artifacts cause excess false alarms.
		The default duration is 5 seconds.  Use this method to shorten or extend
		the duration; be sure to allow for possible lighting start delays
		(e.g., like those caused by slow x10) and/or lighting "ramp" times

		An example:
			$my_monitor = new ZM_MotionItem('driveway');
			$my_monitor->add($interior_hall_light_item);
			$my_monitor->light_blanking_duration(4);

     Operations:

	IMPORTANT: zmxap v0.6 (and above) disables all zoneminder control initiated
		via xAP by default.  You must explicitly enable control via the 
		zmxap config file *before* attempting to use the following operations.
		zmxap will otherwise complain.

		There are no "guards" on the below operations that prevent or
		minimize unexpected outcomes.  This will likely change in 
		subsequent updates.

	start_alarm(reason) - starts an alarm.  The cause is marked as "xAP".  The
		optional reason is appended to the notes field of the zm event.
		WARNING!! - you must ensure that an alarm is stopped.  In addition, 
		logic does not yet exist to ensure that the monitor is not already
		in an alarm condition (TO-DO).

	stop_alarm - stops an alarm. WARNING - there is no logic to ensure that
		the monitor is in an externally-caused alarm state.

	block_alarm - prevents alarms from occurring.  (NOTE: unknown as to whether
		this will cancel existing ones as well)

	suspend_motion_analysis - temporarily suspends motion analysis.  This is an 
		exceptionally quick operation as it takes place via shared memory.
		ZoneMinder will auto resume w/i the time period defined within the
		ZoneMinder configuration.  WARNING - logic does not exist to 
		confirm that the monitor can actually be put into this mode (TO-DO)

	resume_motion_analysis - resumes any existing suspended motion analysis
		NOTE - it is possible that zoneminder may auto-resume based on default
		timeout prior to manual resume methods

	start_motion_analysis - starts motion analysis for modes of operation that permit
		this.  This operation requires several seconds for zoneminder to 
		implement; it is not as fast as suspend/resume motion analysis.
		WARNING - there is no logic to confirm that the monitor can support 
		motion analysis.  This command will be ignored by zoneminder if 
		the monitor's mode does not permit motion analysis

	stop_motion_analysis - stops motion analysis
	
     --------------------------------------
     ZM_ZoneItem
     --------------
	
     Declaration:

	$zone_near = new ZM_ZoneItem('near');

	You must then add it to a ZM_MonitorItem like so:

	$my_monitor->add($zone_near);

	States:
		motion - at start of an alarm event
		still - at completion of an alarm event ****

	**** An alarm event ends after the Post Event Image Buffer has emptied (the product
	     of the number of buffer frames and the framerate).  It is not the actual
	     end of the analyzed event.

     Properties:

	The traditional zoneminder properties exported for any given event are
	available on completion of an alarm (state eq 'still'). They are:
		- frames
		- maxscore 
		- alarmframes 
		- duration 
		- totalscore 
		- avgscore 
	

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

use xAP_Items;

package ZoneMinder_xAP;

our ($device_name);

$device_name = $::config_parms{'zoneminder_devicename'};
$device_name = 'house' unless $device_name;

package ZM_MonitorItem;

@ZM_MonitorItem::ISA = ('Base_Item');

sub new {
    my ( $class, $monitor_name, @p_objects ) = @_;
    my $self = {};
    bless $self, $class;

    $$self{m_write} = 0;

    if ($monitor_name) {
        $monitor_name =
          lc $monitor_name;    # convert to lowercase to be consistent w/ xAP
        my $xap_address =
          "zm.zoneminder.$ZoneMinder_xAP::device_name:$monitor_name";
        my $xap_item = new xAP_Item( 'VMI.*', $xap_address );
        my $friendly_name = "xap_zm_$monitor_name";
        &main::store_object_data( $xap_item, 'xAP_Item', $friendly_name,
            $friendly_name );
        $$self{xap_item} = $xap_item;
        $$self{xap_item}->tie_items($self);
        $$self{monitor_name} = $monitor_name;
        $$self{m_light_blanking_duration} =
          5;    # defaults to 5 seconds to allow minor delay plus ramp
        $$self{m_light_blanking_timer} = new Timer();
        $$self{m_auto_off_duration} =
          120;    # automatically set to idle if no track reports
        $$self{m_auto_off_timer} = new Timer();
        $self->restore_data('m_id');
        $self->add(@p_objects);
    }
    else {
        &::print_log(
            "You must supply a monitor name when creating a new ZM_MonitorItem\n"
        );
    }

    return $self;
}

sub add_item {
    my ( $self, $p_object ) = @_;
    if ( $p_object->isa('ZM_ZoneItem') ) {

        #      push @{$$self{m_zones}}, $p_object;
        $self->SUPER::add_item($p_object);
    }
    elsif ( $p_object->isa('Light_Item') ) {
        print "Adding "
          . $p_object->{object_name} . " to "
          . $self->name
          . " for use in suspend/resume motion analysis\n"
          if $main::Debug{zone_minder};
        $p_object->tie_items($self)
          ; # tie--don't add since we don't need to do lookup and don't want to cascade state
    }
    elsif ( $p_object->isa('Photocell_Item') ) {
        print "Adding "
          . $p_object->{object_name} . " to "
          . $self->name
          . " for use in suspend/resume motion analysis\n"
          if $main::Debug{zone_minder};
        $self->SUPER::add_item($p_object);
    }
    else {
        print "WARNING!! objects of type "
          . ref($p_object)
          . " cannot be added to ZM_MonitorItems!"
          if $main::Debug{zone_minder};
    }

}

sub light_blanking_duration {
    my ( $self, $duration ) = @_;
    $$self{m_light_blanking_duration} = $duration if defined($duration);
    return $$self{m_light_blanking_duration};
}

sub id {
    my ( $self, $id ) = @_;
    $$self{m_id} = $id if defined($id);
    return $$self{m_id};
}

sub external_trigger {
    my ( $self, $external_trigger ) = @_;
    $$self{m_external_trigger} = $external_trigger if $external_trigger;
    return $$self{m_external_trigger};
}

sub monitor_mode {
    my ( $self, $mode ) = @_;
    $$self{m_monitor_mode} = $mode if $mode;
    return $$self{m_monitor_mode};
}

sub record_mode {
    my ( $self, $record_mode ) = @_;
    $$self{m_record_mode} = $record_mode if $record_mode;
    return $$self{m_record_mode};
}

sub monitor_state {
    my ( $self, $monitor_state ) = @_;
    $$self{m_monitor_state} = $monitor_state if $monitor_state;
    return $$self{m_monitor_state};
}

sub position_x {
    my ( $self, $posx ) = @_;
    $$self{m_posx} = $posx if defined($posx);
    return $$self{m_posx};
}

sub position_y {
    my ( $self, $posy ) = @_;
    $$self{m_posy} = $posy if defined($posy);
    return $$self{m_posy};
}

sub position_count {
    my ( $self, $count ) = @_;
    $$self{m_poscount} = $count if defined($count);
    return $$self{m_poscount};
}

sub set {

    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $state = 'unknown';
    if ( $p_setby eq $$self{xap_item} ) {
        my $xap_class = lc $$p_setby{'xap-header'}{class};
        if ( $xap_class eq 'vmi.monitorinfo' ) {
            $self->id( $$p_setby{'monitor'}{'monitorid'} );
            $self->external_trigger( $$p_setby{'monitor'}{'externaltrigger'} );
            $self->record_mode( $$p_setby{'monitor'}{'recordmode'} );
            $self->monitor_state( $$p_setby{'monitor'}{'state'} );
            $self->monitor_mode( $$p_setby{'monitor'}{'mode'} );
            print "ZM_MonitorItem::("
              . $self->name . ") ["
              . $self->id . "]"
              . " external_trigger:"
              . $self->external_trigger
              . ", record_mode:"
              . $self->record_mode
              . ", monitor_state:"
              . $self->monitor_state
              . ", monitor_mode:"
              . $self->monitor_mode . "\n"
              if $main::Debug{zone_minder};

        }
        elsif ( $xap_class eq 'vmi.alarmevent' ) {
            if ( $$p_setby{'alarm'}{cause} eq 'Motion' ) {
                my $id = $$p_setby{'alarm'}{alarmid};
                my (@zone_names) = split( /,/, $$p_setby{'alarm'}{zonedata} )
                  if $$p_setby{'alarm'}{zonedata};

                #               my (@zones) = @{$$self{m_zones}} if $$self{m_zones};
                my @zones = $self->find_members('ZM_ZoneItem');
                if ( !(@zone_names) && @zones ) {
                    push @zone_names, $zones[0]->name;
                }
                my %zone_data;
                $zone_data{state} = $$p_setby{'alarm'}{state};
                if ( $zone_data{state} eq 'off' ) {
                    $zone_data{frames}      = $$p_setby{'alarm'}{frames};
                    $zone_data{maxscore}    = $$p_setby{'alarm'}{maxscore};
                    $zone_data{alarmframes} = $$p_setby{'alarm'}{alarmframes};
                    $zone_data{duration}    = $$p_setby{'alarm'}{duration};
                    $zone_data{totalscore}  = $$p_setby{'alarm'}{totalscore};
                    $zone_data{avgscore}    = $$p_setby{'alarm'}{avgscore};
                    $state                  = 'idle';
                    $$self{m_auto_off_timer}->unset();
                }
                else {
                    $self->position_count(0);
                    $self->position_x(0);
                    $self->position_y(0);
                    $state = 'alarm';
                }
                if (@zone_names) {
                    for my $zone_name (@zone_names) {
                        if (@zones) {
                            for my $zone (@zones) {
                                if ( lc $zone_name eq lc $zone->name ) {
                                    $zone->set_alarm_event( $id, $self,
                                        %zone_data );
                                }
                            }
                        }
                    }
                }
            }
            elsif ( $$p_setby{'alarm'}{cause} eq 'Linked' ) {
                my $id = $$p_setby{'alarm'}{alarmid};

                my $linked_monitor_names = $$p_setby{'alarm'}{linkeddata};
                if ( $$p_setby{'alarm'}{state} eq 'on' ) {
                    $state = 'alarm';
                }
                elsif ( $$p_setby{'alarm'}{state} eq 'off' ) {
                    $state = 'idle';
                }
            }
        }
        elsif ( $xap_class eq 'vmi.trackingevent' ) {
            $self->position_x( $$p_setby{'telemetry'}{'positionx'} );
            $self->position_y( $$p_setby{'telemetry'}{'positiony'} );
            $self->position_count( $self->position_count + 1 );
            $$self{m_auto_off_timer}->set( $$self{m_auto_off_duration}, $self );
            print "ZM_MonitorItem::("
              . $self->name . ") ["
              . $self->id . "]"
              . " pos_x:"
              . $self->position_x
              . ", pos_y:"
              . $self->position_y
              . ", count:"
              . $self->position_count . "\n"
              if $main::Debug{zone_minder};
        }
    }
    elsif ( $p_setby->isa('ZM_ZoneItem') && $self->is_member($p_setby) ) {
        $state = $p_setby->state;
    }
    elsif ( $p_setby->isa('Light_Item') ) {
        my $photo_continue = 1;

        # check to see if any Photocell_Items exist; if so and they are light then
        # don't perform any blanking operation
        for my $photocell ( my @photocells =
            $self->find_members('Photocell_Item') )
        {
            if ( $photocell->state eq 'light' ) {
                $photo_continue = 0;
                last;
            }
        }
        if ( $photo_continue && $self->light_blanking_duration ) {
            $$self{m_light_blanking_timer}
              ->set( $self->light_blanking_duration, $self );
            $self->suspend_motion_analysis();
        }
    }
    elsif ( $p_setby == $$self{m_light_blanking_timer} ) {
        $$self{m_light_blanking_timer}->stop();
        $self->resume_motion_analysis();
    }
    elsif ( $p_setby eq $$self{m_auto_off_timer} ) {
        $state = 'idle';

        #      for my $zone (@{$$self{m_zones}}) {
        for my $zone ( $self->find_members('ZM_ZoneItem') ) {
            $zone->set( 'still', $self ) if $zone;
        }
    }
    else {
        $state = 'unknown';
    }

    $self->SUPER::set( $state, $p_setby, $p_response )
      unless $state eq 'unknown';

    return;
}

sub name {
    my ($self) = @_;
    return $$self{monitor_name};
}

# WARNING!! - you must ensure that there are no current active events and more
#             importantly that you stop the alarm.  There is no current automatic
#             fail-safe to turn off the alarm after some elapsed time.  The
#             block alarm is a potentical candidate for stopping any existing alarms
sub start_alarm {
    my ( $self, $reason ) = @_;
    my @data;
    my $alarm_block;
    $alarm_block->{'Action'} = 'start';
    $alarm_block->{'Reason'} = $reason if $reason;
    push @data, 'Alarm', $alarm_block;
    &xAP::sendXap( $$self{xap_item}{source}, 'VMI.AlarmCmd', @data );
}

sub stop_alarm {
    my ($self) = @_;
    my @data;
    my $alarm_block;
    $alarm_block->{'Action'} = 'cancel';
    push @data, 'Alarm', $alarm_block;
    &xAP::sendXap( $$self{xap_item}{source}, 'VMI.AlarmCmd', @data );
}

# stops alarms from occurring--much like suspend_motion_analysis can work
# WARNING!!! - use with extreme caution as this may create unintended side affects
sub block_alarm {
    my ($self) = @_;
    my @data;
    my $alarm_block;
    $alarm_block->{'Action'} = 'block';
    push @data, 'Alarm', $alarm_block;
    &xAP::sendXap( $$self{xap_item}{source}, 'VMI.AlarmCmd', @data );
}

# IMPORTANT: ZoneMinder will automatically resume suspended monitors based on
#            a user definable timeout
sub suspend_motion_analysis {
    my ($self) = @_;
    my @data;
    my $alarm_block;
    $alarm_block->{'Action'} = 'motion-suspend';
    push @data, 'Alarm', $alarm_block;
    &xAP::sendXap( $$self{xap_item}{source}, 'VMI.AlarmCmd', @data );
}

sub resume_motion_analysis {
    my ($self) = @_;
    my @data;
    my $alarm_block;
    $alarm_block->{'Action'} = 'motion-resume';
    push @data, 'Alarm', $alarm_block;
    &xAP::sendXap( $$self{xap_item}{source}, 'VMI.AlarmCmd', @data );
}

sub start_motion_analysis {
    my ($self) = @_;
    my @data;
    my $alarm_block;
    $alarm_block->{'Action'} = 'start';
    push @data, 'Monitor', $alarm_block;
    &xAP::sendXap( $$self{xap_item}{source}, 'VMI.MonitorCmd', @data );
}

sub stop_motion_analysis {
    my ($self) = @_;
    my @data;
    my $alarm_block;
    $alarm_block->{'Action'} = 'stop';
    push @data, 'Monitor', $alarm_block;
    &xAP::sendXap( $$self{xap_item}{source}, 'VMI.MonitorCmd', @data );
}

package ZM_ZoneItem;

@ZM_ZoneItem::ISA = ('Base_Item');

sub new {
    my ( $class, $zone_name ) = @_;
    my $self = {};
    bless $self, $class;
    $$self{m_write} = 0;
    $self->name( lc $zone_name );
    $$self{m_frames}               = undef;
    $$self{m_maxscore}             = undef;
    $$self{m_alarmframes}          = undef;
    $$self{m_duration}             = undef;
    $$self{m_totalscore}           = undef;
    $$self{m_avgscore}             = undef;
    $$self{m_delayMotionTimer}     = new Timer();
    $$self{m_delayMotionTimerTime} = 0;
    $$self{m_delayStillTimer}      = new Timer();
    $$self{m_delayStillTimerTime}  = 0;
    $$self{m_validationTimer}      = new Timer();
    $$self{m_validationTimerTime}  = 10;
    return $self;
}

sub name {
    my ( $self, $name ) = @_;
    $$self{m_name} = $name if $name;
    return $$self{m_name};
}

sub frames {
    my ( $self, $frames ) = @_;
    $$self{m_frames} = $frames if defined($frames);
    return $$self{m_frames};
}

sub maxscore {
    my ( $self, $maxscore ) = @_;
    $$self{m_maxscore} = $maxscore if defined($maxscore);
    return $$self{m_maxscore};
}

sub alarmframes {
    my ( $self, $alarmframes ) = @_;
    $$self{m_alarmframes} = $alarmframes if defined($alarmframes);
    return $$self{m_alarmframes};
}

sub duration {
    my ( $self, $duration ) = @_;
    if ( defined($duration) ) {
        my ( $minutes, $seconds ) = $duration =~ /(.+)\:(.+)/;
        $seconds = ( $minutes * 60 ) + $seconds;
        print "duration is $seconds\n";
        $$self{m_duration} = $seconds;
    }
    return $$self{m_duration};
}

sub totalscore {
    my ( $self, $totalscore ) = @_;
    $$self{m_totalscore} = $totalscore if defined($totalscore);
    return $$self{m_totalscore};
}

sub avgscore {
    my ( $self, $avgscore ) = @_;
    $$self{m_avgscore} = $avgscore if defined($avgscore);
    return $$self{m_avgscore};
}

sub still_timer_time {
    my ( $self, $still_time ) = @_;
    $$self{m_delayStillTimerTime} = $still_time if defined($still_time);
    return $$self{m_delayStillTimerTime};
}

sub motion_timer_time {
    my ( $self, $motion_time ) = @_;
    $$self{m_delayMotionTimerTime} = $motion_time if defined($motion_time);
    return $$self{m_delayMotionTimerTime};
}

sub set {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;

    my $final_state = $p_state;

    if ( $p_setby eq $$self{m_delayMotionTimer} ) {
        $final_state = 'motion';
    }
    elsif ( $p_setby eq $$self{m_delayStillTimer} ) {
        $final_state = 'still';
    }

    if ( defined($final_state) ) {
        $self->SUPER::set( $final_state, $p_setby, $p_respond );
    }
}

sub set_alarm_event {
    my ( $self, $alarm_id, $p_setby, %zone_data ) = @_;
    if ( $zone_data{state} eq 'on' ) {
        if ( $$self{m_delayMotionTimerTime} ) {
            $$self{m_delayMotionTimer}
              ->set( $$self{m_delayMotionTimerTime}, $self );
            print "zm_ZoneItem("
              . $self->name
              . "):: [$alarm_id] started motion w/ delay: $$self{m_delayMotionTimerTime}\n"
              if $main::Debug{zone_minder};
        }
        else {
            $$self{m_delayStillTimer}->unset();    # cancel the still timer
            print "zm_ZoneItem("
              . $self->name
              . "):: [$alarm_id] started motion w/o delay\n"
              if $main::Debug{zone_minder};
            $self->set( 'motion', $p_setby );    # be consistent w/ Motion_Item
        }
    }
    else {
        $self->frames( $zone_data{frames} );
        $self->maxscore( $zone_data{maxscore} );
        $self->alarmframes( $zone_data{alarmframes} );
        $self->duration( $zone_data{duration} );
        $self->totalscore( $zone_data{totalscore} );
        $self->avgscore( $zone_data{avgscore} );
        if ( $$self{m_delayStillTimerTime} ) {
            $$self{m_delayStillTimer}
              ->set( $$self{m_delayStillTimerTime}, $self );
            print "zm_ZoneItem("
              . $self->name
              . "):: [$alarm_id] stopped w/ delay: $$self{m_delayStillTimerTime}; "
              . "maxscore:$zone_data{maxscore}, frames:$zone_data{frames}, alarmframes:$zone_data{alarmframes}, "
              . "duration:$zone_data{duration}, totalscore:$zone_data{totalscore}, avgscore:$zone_data{avgscore}\n"
              if $main::Debug{zone_minder};

        }
        else {
            $$self{m_delayMotionTimer}->unset();    # cancel the startup timer
            print "zm_ZoneItem("
              . $self->name
              . "):: [$alarm_id] stopped w/o delay; "
              . "maxscore:$zone_data{maxscore}, frames:$zone_data{frames}, alarmframes:$zone_data{alarmframes}, "
              . "duration:$zone_data{duration}, totalscore:$zone_data{totalscore}, avgscore:$zone_data{avgscore}\n"
              if $main::Debug{zone_minder};
            $self->set( 'still', $p_setby );    # be consistent w/ Motion_Item
        }
    }
}

1;
