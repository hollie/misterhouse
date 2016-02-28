# =begin comment
# From Brian Rudy on 09/2002
#
# Hi Steve,
#
# I took a crack at this a while ago, and have included my current code.
# This may not be horribly usefull as my implimentation is only valid for
# a single house occupant.
#
# At the moment I only have Hawkeye motion sensors for detecting people,
# but imagine the use of break-beam, or true occupancy sensors could
# extend support to include multiple occupants.
#
# I use a 'context' global variable for determining if I am sleeping,
# away, working, bathing, eating, etc... At the moment I only use this for
# home/away detection for controlling the HVAC system, but I imagine you
# can see other possible uses...
#
# =cut
#
#
# Category=Tracker

# Tracking code for motion sensors, and lighting control.
#
# 8/20/2002	0.5
# Updates to reduce verbosity, support for X10_Sensor objects.
#
# 3/2/2001	0.4
# Basic context detection: home/away, Sleeping, watching TV, working,
# eating, cooking and bathing.
#
# 10/7/2000	0.3
# Simple room occupancy monitoring so timers don't expire when the
# room is occupied, but the people aren't moving much.
#
# 9/29/2000	0.2
# Basic tracking functionality
#
# 9/17/2000	0.1
# It works!
#
# To do:
# -Add more granularity for determining location.
# -Company/single occupant modes
# -Add more context detection (breakfast, awake, etc...)
# -Add activity logging (Why am I doing this?)

# This hash array stores the timestamps and location probability info
use vars '%location';

#$location{Current} = "Unknown";
use vars '%context';

# Apparently ON/OFF needs to be defined for each house code
# the motion sensors are on.
# $motion               = new Serial_Item('XCJ', ON);
#$motion->               add            ('XCK', OFF);
#$motion->               add            ('XBJ', ON);
#$motion->               add            ('XBK', OFF);

#$motion               = new X10_Sensor('XDJ', ON);
#$motion->               add            ('XDK', OFF);
#$motion->               add            ('XBJ', ON);
#$motion->               add            ('XBK', OFF);

# Light timer settings (in minutes)
my $work_room_light_timeout    = 15;
my $work_room_monitors_timeout = 30;
my $kitchen_timeout            = 10;
my $kitchenette_timeout        = 1;
my $dining_room_timeout        = 10;
my $living_room_timeout        = 10;
my $bed_room_timeout           = 5;
my $bath_room_timeout          = 10;
my $front_door_timeout         = 10;
my $back_door_timeout          = 10;

#my $coming_home_timeout = 10;
#my $going_to_bed_timeout = 10;

# Motion sensor definitions
# $work_room_motion = new X10_Sensor('CA');
$kitchen_motion     = new X10_Sensor('D4');
$kitchenette_motion = new X10_Sensor('D6');
$dining_room_motion = new X10_Sensor('D8');
$living_room_motion = new X10_Sensor('DA');
$bed_room_motion    = new X10_Sensor('DC');
$bath_room_motion   = new X10_Sensor('DE');
$front_door_motion  = new X10_Sensor('B9');
$back_door_motion   = new X10_Sensor('BB');

$Motion = new Group(
    $work_room_motion,   $kitchen_motion,     $kitchenette_motion,
    $dining_room_motion, $living_room_motion, $bed_room_motion,
    $bath_room_motion,   $front_door_motion,  $back_door_motion
);

# Light sensor definitions
# $work_room_brightness = new X10_Sensor('CB');
$kitchen_dark     = new X10_Sensor('D5');
$kitchenette_dark = new X10_Sensor('D7');
$dining_room_dark = new X10_Sensor('D9');
$living_room_dark = new X10_Sensor('DB');
$bed_room_dark    = new X10_Sensor('DD');
$bath_room_dark   = new X10_Sensor('DF');
$front_door_dark  = new X10_Sensor('BA');
$back_door_dark   = new X10_Sensor('BC');

$Dark = new Group(
    $work_room_brightness, $kitchen_dark,     $kitchenette_dark,
    $dining_room_dark,     $living_room_dark, $bed_room_dark,
    $bath_room_dark,       $front_door_dark,  $back_door_dark
);

# Timer definitions
$work_room_light_timer    = new Timer();
$work_room_monitors_timer = new Timer();
$monitor_timer            = new Timer();
$kitchen_timer            = new Timer();
$kitchenette_timer        = new Timer();
$dining_room_timer        = new Timer();
$living_room_timer        = new Timer();
$bed_room_timer           = new Timer();
$bath_room_timer          = new Timer();
$front_door_timer         = new Timer();
$back_door_timer          = new Timer();
$coming_home_timer        = new Timer();
$going_to_bed_timer       = new Timer();

# Variable definitions
my $all_is_quiet;
my $indoors_is_quiet;

$all_is_quiet =
  (      ( inactive $work_room_light_timer)
      && ( inactive $work_room_monitors_timer)
      && ( inactive $kitchen_timer)
      && ( inactive $kitchenette_timer)
      && ( inactive $dining_room_timer)
      && ( inactive $living_room_timer)
      && ( inactive $bed_room_timer)
      && ( inactive $bath_room_timer)
      && ( inactive $front_door_timer)
      && ( inactive $back_door_timer) );

$indoors_is_quiet =
  (      ( inactive $work_room_light_timer)
      && ( inactive $work_room_monitors_timer)
      && ( inactive $kitchen_timer)
      && ( inactive $kitchenette_timer)
      && ( inactive $dining_room_timer)
      && ( inactive $living_room_timer)
      && ( inactive $bed_room_timer)
      && ( inactive $bath_room_timer) );

### Context detection modules

# Home/away
if ( $location{Current} eq 'away' ) {
    if ( ($New_Minute) && ( $context{Current} ne 'away' ) ) {
        print_log "Piet is not at home...";
        $context{Current} = 'away';
    }
}
else {
    if ( ($New_Minute) && ( $context{Current} eq 'away' ) ) {
        print_log "Piet is at home...";

        #$context{Current} = 'home';
    }
}

# Sleeping
if (   ( $location{Current} eq 'bed_room' )
    && ($indoors_is_quiet)
    && ( ( $Hour == 23 ) || ( $Hour == 24 ) || ( $Hour <= 11 ) )
    && ( calc_delta( $location{bed_room_occupancy_tds} ) >= ( 30 * 60 ) ) )
{
    if ( ($New_Minute) && ( $context{Current} ne 'sleeping' ) ) {
        print_log "Piet is sleeping...";
        $context{Current} = 'sleeping';
    }
}

# Watching TV
if (   ( $location{Current} eq 'living_room' )
    && ( calc_delta( $location{living_room_occupancy_tds} ) >= ( 10 * 60 ) ) )
{
    if ( ($New_Minute) && ( $context{Current} ne 'watching tv' ) ) {
        print_log "Piet is watching TV...";
        $context{Current} = 'watching tv';
    }
}

# Working
if (   ( $location{Current} eq 'work_room' )
    && ( calc_delta( $location{work_room_occupancy_tds} ) >= ( 10 * 60 ) ) )
{
    if ( ($New_Minute) && ( $context{Current} ne 'working' ) ) {
        print_log "Piet is working...";
        $context{Current} = 'working';
    }
}

# Eating
if (   ( $location{Current} eq 'dining_room' )
    && ( calc_delta( $location{dining_room_occupancy_tds} ) >= ( 5 * 60 ) ) )
{
    if ($New_Minute) {
        if ( ( $Hour <= 11 ) && ( $context{Current} ne 'eating breakfast' ) ) {
            print_log "Piet is eating breakfast...";
            $context{Current} = 'eating breakfast';
        }
        else {
            if ( $context{Current} ne 'eating' ) {
                print_log "Piet is eating...";
                $context{Current} = 'eating';
            }
        }
    }
}

# Cooking
if (
    (
           ( $location{Current} eq 'kitchen' )
        && ( calc_delta( $location{kitchen_occupancy_tds} ) >= ( 5 * 60 ) )
    )
    || (   ( $location{Current} eq 'kitchenette' )
        && ( calc_delta( $location{kitchenette_occupancy_tds} ) >= ( 5 * 60 ) )
    )
  )
{
    if ( ($New_Minute) && ( $context{Current} ne 'cooking' ) ) {
        print_log "Piet is cooking...";
        $context{Current} = 'cooking';
    }
}

# Bathing
if (   ( $location{Current} eq 'bath_room' )
    && ( calc_delta( $location{bath_room_occupancy_tds} ) >= ( 5 * 60 ) )
    && ( ( $Hour >= 4 ) && ( $Hour <= 11 ) ) )
{
    if ( ($New_Minute) && ( $context{Current} ne 'bathing' ) ) {
        print_log "Piet is bathing...";
        $context{Current} = 'bathing';
    }
}

###

#
# We come thru this code 20 times/second!
# Prints a lot of stuff!
#
# print_log "state of work_room_motion = ", state $work_room_motion;
# print_log "state of work_room_brightness = ",   state $work_room_brightness;

if ( $all_is_quiet && $New_Minute ) {
    print_log "All is quiet: {";
    print_log "        work_room_motion state: ", state $work_room_motion;
    print_log "        work_room_brightness state: ",
      state $work_room_brightness;
    print_log "}";
}
else {
    if ( $indoors_is_quiet && $New_Minute ) {
        print_log "Indoors is quiet...";
    }
}

$v_current_location = new Voice_Cmd('Where is Piet');

if ( $state = said $v_current_location) {
    my $temptext = $location{Current};
    $temptext =~ s/work_room/the Work Room/g;
    $temptext =~ s/bath_room/the Bath Room/g;
    $temptext =~ s/bed_room/the Bed Room/g;
    $temptext =~ s/living_room/the Living Room/g;
    $temptext =~ s/dining_room/the Dining Room/g;
    $temptext =~ s/kitchen/the Kitchen/g;
    $temptext =~ s/kitchenette/the Kitchenette/g;
    $temptext =~ s/front_door/the Front Door/g;
    $temptext =~ s/back_door/the Back Door/g;

    # These are needed because print_log can't take returned values from
    # subs directly.
    my $workroom_time    = calc_delta( $location{work_room_tds} );
    my $bathroom_time    = calc_delta( $location{bath_room_tds} );
    my $bedroom_time     = calc_delta( $location{bed_room_tds} );
    my $livingroom_time  = calc_delta( $location{living_room_tds} );
    my $diningroom_time  = calc_delta( $location{dining_room_tds} );
    my $kitchen_time     = calc_delta( $location{kitchen_tds} );
    my $kitchenette_time = calc_delta( $location{kitchenette_tds} );
    my $frontdoor_time   = calc_delta( $location{front_door_tds} );
    my $backdoor_time    = calc_delta( $location{back_door_tds} );

    print_log "Workroom: $workroom_time seconds ago.";
    print_log "Bathroom: $bathroom_time seconds ago.";
    print_log "Bedroom: $bedroom_time seconds ago.";
    print_log "Livingroom: $livingroom_time seconds ago.";
    print_log "Diningroom: $diningroom_time seconds ago. ";
    print_log "Kitchen: $kitchen_time seconds ago.";
    print_log "Kitchenette: $kitchenette_time seconds ago.";
    print_log "Front Door: $frontdoor_time seconds ago.";
    print_log "Back Door: $backdoor_time seconds ago.";

    # How long ago?
    if ( $location{Current} eq 'away' ) {
        speak "Piet is not at home.";
    }
    else {
        my $temptext_a = "$location{Current}_tds";

        # print "$temptext_b\n";
        my $howlong = &calc_delta( $location{$temptext_a} );
        speak
          "Piet's last known location is in $temptext, $howlong seconds ago.";
    }
}

# This sub calculates the difference between the current time, and the passed timestamp
# in epoch seconds.
sub calc_delta {
    my $tds = sprintf "%s", @_;

    # Need to check if passed value is null
    my $delta = $Time - $tds;
    return $delta;
}

# Work Room
if ( state_now $work_room_brightness eq "work_room_brightness" ) {
    print_log "Work Room is now Dark.";
}
if ( state_now $work_room_brightness eq "work_room_brightness_stopped" ) {
    print_log "Work Room is now Lit.";
}

# Saw motion in the work room...
if ( state_now $work_room_motion eq "motion" ) {

    print_log "Movement sensed in Work Room.";

    if ( $location{Last} ne 'work_room' ) {
        $location{Last}                    = $location{Current};
        $location{work_room_occupancy_tds} = $Time;
    }
    $location{Current} = 'work_room';

    $location{work_room_tds} = $Time;

    # If we haven't already reported the movement, do so now.
    if ( inactive $work_room_monitors_timer) {
        print_log
          "Setting monitors timer to $work_room_monitors_timeout minutes.";
    }
    set $work_room_monitors_timer ( $work_room_monitors_timeout * 60 );

    if ( inactive $work_room_light_timer) {
        print_log "Setting light_timer to $work_room_light_timeout minutes.";
    }
    set $work_room_light_timer ( $work_room_light_timeout * 60 );

    if (
        (
               ( state $work_room_brightness eq "dark" )
            || ( time_greater_than("$Time_Sunset") )
        )
        && ( state $workrm_light ne ON )
      )
    {
        print_log "Work Room is Dark.  Turning on light.";
        set $workrm_light ON;
    }
    else {
        print_log "Work Room is Lit. State of work_room_brightness: ",
          state $work_room_brightness, ", State of workrm_light: ",
          state $workrm_light;
    }

    set $work_room_monitors_timer ( $work_room_monitors_timeout * 60 );
    if (   ( state $work_room_brightness ne "still" )
        && ( state $workrm_light ne ON ) )
    {
        print_log "Work Room Monitors are off.  Turning on monitors.";
        set $workrm_monitors ON;
    }
    else {
        print_log "Work Room Monitors are On.";
    }
}

# Has Work Room Light motion timer elapsed with no further motion?
if ( expired $work_room_light_timer) {

    #  if ($location{Current} eq 'work_room') {
    # Reset timer if the room is still occupied
    #     print_log "Light Timer expired but Work Room still occupied. Resetting light timer...";
    #     set $work_room_light_timer ($work_room_light_timeout*60);
    #  }
    #  else
    {
        set $workrm_light OFF;
        print_log
          "No movement in Work Room for $work_room_light_timeout minutes";
        print_log "Turning off Work Room Light.";
        set $work_room_light_timer ( $work_room_light_timeout * 60 );
    }
}

# Has Work Room Monitors motion timer elapsed with no further motion?
if ( expired $work_room_monitors_timer) {

    #  if ($location{Current} eq 'work_room') {
    # Reset timer if the room is still occupied
    #     print_log "Timer expired but Work Room still occupied. Resetting timers...";
    #     set $work_room_monitors_timer ($work_room_monitors_timeout*60);
    #  }
    #  else
    {
        print_log
          "No movement in Work Room for $work_room_monitors_timeout minutes";
        print_log "Turning Off Work Room Monitors.";
        set $workrm_monitors OFF;
        set $work_room_light_timer ( $work_room_light_timeout * 60 );
    }
}

# Kitchen
if ( state_now $kitchen_dark eq "kitchen_dark" ) {
    print_log "Kitchen is now Dark.";
}
if ( state_now $kitchen_dark eq "kitchen_dark_stopped" ) {
    print_log "Kitchen is now Lit.";
}

# Saw motion in the kitchen...
if ( state_now $kitchen_motion eq "kitchen_motion" ) {

    if ( $location{Last} ne 'kitchen' ) {
        $location{Last}                  = $location{Current};
        $location{kitchen_occupancy_tds} = $Time;
    }
    $location{Current} = 'kitchen';

    $location{kitchen_tds} = $Time;

    # If we haven't already reported the movement, do so now.
    if ( inactive $kitchen_timer) {
        print_log
          "Movement sensed in Kitchen.  Setting timer to $kitchen_timeout minutes.";
    }

    #else {
    #  print_log "Movement sensed in Kitchen.";
    #}
    set $kitchen_timer ( $kitchen_timeout * 60 );
    if (
        (
               ( state $kitchen_dark ne "kitchen_dark_stopped" )
            || ( time_greater_than("$Time_Sunset") )
        )
        && ( state $kitchen_light ne ON )
      )
    {
        print_log "Kitchen is Dark.  Turning on light.";
        set $kitchen_light ON;
    }

    #else {
    #  print_log "Kitchen is Lit.  Light state will not be changed.";
    #}
}

# Has Kitchen motion timer elapsed with no further motion?
if ( expired $kitchen_timer) {
    if ( $location{Current} eq 'kitchen' ) {

        # Reset timer if the room is still occupied
        print_log
          "Timer expired but Kitchen still occupied. Resetting timer...";
        set $kitchen_timer ( $kitchen_timeout * 60 );
    }
    else {
        set $kitchen_light OFF;
        print_log "No movement in Kitchen for $kitchen_timeout minutes";
        print_log "Turning off light.";
    }
}

# Living Room
if ( state_now $living_room_dark eq "living_room_dark" ) {
    print_log "Living Room is now Dark.";
}
if ( state_now $living_room_dark eq "living_room_dark_stopped" ) {
    print_log "Living Room is now Lit.";
}

# Saw motion in the living room...
if ( state_now $living_room_motion eq "living_room_motion" ) {

    if ( $location{Last} ne 'living_room' ) {
        $location{Last}                      = $location{Current};
        $location{living_room_occupancy_tds} = $Time;
    }
    $location{Current} = 'living_room';

    $location{living_room_tds} = $Time;

    # If we haven't already reported the movement, do so now.
    if ( inactive $living_room_timer) {
        print_log
          "Movement sensed in Living Room.  Setting timer to $living_room_timeout minutes.";
    }

    #else {
    #  print_log "Movement sensed in Living Room.";
    #}
    set $living_room_timer ( $living_room_timeout * 60 );
    if (
        (
               ( state $living_room_dark ne "living_room_dark_stopped" )
            || ( time_greater_than("$Time_Sunset") )
        )
        && ( state $livingrm_light1 ne ON )
      )
    {
        print_log "Living Room is Dark.  Turning on light.";
        set $livingrm_light1 ON;
    }

    #else {
    #  print_log "Living Room is Lit.  Light state will not be changed.";
    #}
}

# Has Living Room  motion timer elapsed with no further motion?
if ( expired $living_room_timer) {
    if ( $location{Current} eq 'living_room' ) {

        # Reset timer if the room is still occupied
        print_log
          "Timer expired but Living Room still occupied. Resetting timer...";
        set $living_room_timer ( $living_room_timeout * 60 );
    }
    else {
        set $livingrm_light1 OFF;
        print_log "No movement in Living Room for $living_room_timeout minutes";
        print_log "Turning off light.";
    }
}

# Dining Room
if ( state_now $dining_room_dark eq "dining_room_dark" ) {
    print_log "Dining Room is now Dark.";
}
if ( state_now $dining_room_dark eq "dining_room_dark_stopped" ) {
    print_log "Dining Room is now Lit.";
}

# Saw motion in the dining room...
if ( state_now $dining_room_motion eq "dining_room_motion" ) {

    if ( $location{Last} ne 'dining_room' ) {
        $location{Last}                      = $location{Current};
        $location{dining_room_occupancy_tds} = $Time;
    }
    $location{Current} = 'dining_room';

    $location{dining_room_tds} = $Time;

    # If we haven't already reported the movement, do so now.
    if ( inactive $dining_room_timer) {
        print_log
          "Movement sensed in Dining Room.  Setting timer to $dining_room_timeout minutes.";
    }

    #else {
    #  print_log "Movement sensed in Dining Room.";
    #}
    set $dining_room_timer ( $dining_room_timeout * 60 );
    if (
        (
               ( state $dining_room_dark ne "dining_room_dark_stopped" )
            || ( time_greater_than("$Time_Sunset") )
        )
        && ( state $diningrm_light ne ON )
      )
    {
        print_log "Dining Room is Dark.  Turning on light.";
        set $diningrm_light ON;
    }

    #else {
    #  print_log "Dining Room is Lit.  Light state will not be changed.";
    #}
}

# Has Dining Room  motion timer elapsed with no further motion?
if ( expired $dining_room_timer) {
    if ( $location{Current} eq 'dining_room' ) {

        # Reset timer if the room is still occupied
        print_log
          "Timer expired but Dining Room still occupied. Resetting timer...";
        set $dining_room_timer ( $dining_room_timeout * 60 );
    }
    else {
        set $diningrm_light OFF;
        print_log "No movement in Dining Room for $dining_room_timeout minutes";
        print_log "Turning off light.";
    }
}

# Bed Room
if ( state_now $bed_room_dark eq "bed_room_dark" ) {
    print_log "Bed Room is now Dark.";
}
if ( state_now $bed_room_dark eq "bed_room_dark_stopped" ) {
    print_log "Bed Room is now Lit.";
}

# Saw motion in the bed room, but only turn on light if sane to do so.
# ie. Don't turn the damn lights on when I roll over in bed!
if ( state_now $bed_room_motion eq "bed_room_motion" ) {

    if ( $location{Last} ne 'bed_room' ) {
        $location{Last}                      = $location{Current};
        $location{dining_room_occupancy_tds} = $Time;
    }
    $location{Current} = 'bed_room';

    $location{bed_room_tds} = $Time;

    # If we haven't already reported the movement, do so now.
    if ( inactive $bed_room_timer) {
        print_log
          "Movement sensed in Bed Room.  Setting timer to $bed_room_timeout minutes.";
    }

    #else {
    #  print_log "Movement sensed in Bed Room.";
    #}
    if (
        (
               ( state $bed_room_dark ne "bed_room_dark_stopped" )
            || ( time_greater_than("$Time_Sunset") )
        )
        && ( state $bedrm_light ne ON )
      )
    {
        if ( !$indoors_is_quiet ) {
            set $bed_room_timer ( $bed_room_timeout * 60 );
            print_log "Bed Room is Dark.  Turning on light.";
            set $bedrm_light ON;
        }
    }

    #else {
    #  print_log "Bed Room is Lit.  Light state will not be changed.";
    #}
}

# Has Bed Room  motion timer elapsed with no further motion?
if ( expired $bed_room_timer) {
    set $bedrm_light OFF;
    print_log "No movement in Bed Room for $bed_room_timeout minutes";
    print_log "Turning off light.";
}

# Bath Room
if ( state_now $bath_room_dark eq "bath_room_dark" ) {
    print_log "Bath Room is now Dark.";
}
if ( state_now $bath_room_dark eq "bath_room_dark_stopped" ) {
    print_log "Bath Room is now Lit.";
}

# Saw motion in the bath room...
if ( state_now $bath_room_motion eq "bath_room_motion" ) {

    if ( $location{Last} ne 'bath_room' ) {
        $location{Last}                    = $location{Current};
        $location{bath_room_occupancy_tds} = $Time;
    }
    $location{Current} = 'bath_room';

    $location{bath_room_tds} = $Time;

    # If we haven't already reported the movement, do so now.
    if ( inactive $bath_room_timer) {
        print_log
          "Movement sensed in Bath Room.  Setting timer to $bath_room_timeout minutes.";
    }

    #else {
    #  print_log "Movement sensed in Bath Room.";
    #}
    set $bath_room_timer ( $bath_room_timeout * 60 );
    if (
        (
               ( state $bath_room_dark ne "bath_room_dark_stopped" )
            || ( time_greater_than("$Time_Sunset") )
        )
        && ( state $bathrm_light ne ON )
      )
    {
        print_log "Bath Room is Dark.  Turning on light.";
        set $bathrm_light ON;
    }

    #else {
    #  print_log "Bath Room is Lit.  Light state will not be changed.";
    #}
}

# Has Bath Room  motion timer elapsed with no further motion?
if ( expired $bath_room_timer) {
    if ( $location{Current} eq 'bath_room' ) {

        # Reset timer if the room is still occupied
        print_log
          "Timer expired but Bath Room still occupied. Resetting timer...";
        set $bath_room_timer ( $bath_room_timeout * 60 );
    }
    else {
        set $bathrm_light OFF;
        print_log "No movement in Bath Room for $bath_room_timeout minutes";
        print_log "Turning off light.";
    }
}

# Kitchenette
# No lighting control here yet.
if ( state_now $kitchenette_dark eq "kitchenette_dark" ) {
    print_log "Kitchenette is now Dark.";
}
if ( state_now $kitchenette_dark eq "kitchenette_dark_stopped" ) {
    print_log "Kitchenette is now Lit.";
}

# Saw motion in the kitchenette...
if ( state_now $kitchenette_motion eq "kitchenette_motion" ) {

    if ( $location{Last} ne 'kitchenette' ) {
        $location{Last}                      = $location{Current};
        $location{kitchenette_occupancy_tds} = $Time;
    }
    $location{Current} = 'kitchenette';

    $location{kitchenette_tds} = $Time;

    # If we haven't already reported the movement, do so now.
    if ( inactive $kitchenette_timer) {
        print_log
          "Movement sensed in Kitchenette.  Setting timer to $kitchenette_timeout minutes.";
    }

    #else {
    #  print_log "Movement sensed in Kitchenette.";
    #}
    set $kitchenette_timer ( $kitchenette_timeout * 60 );

    #   if (((state $kitchenette_dark ne "kitchenette_dark_stopped") || (time_greater_than("$Time_Sunset"))) && (state $kitchentte_light ne ON)) {
    #     print_log "Bath Room is Dark.  Turning on light.";
    #     set $bathrm_light ON;
    #   }
    #   else {
    #     print_log "Bath Room is Lit.  Light state will not be changed.";
    #   }
}

# Has Kitchenette  motion timer elapsed with no further motion?
if ( expired $kitchenette_timer) {

    #  set $bathrm_light OFF;
    print_log "No movement in Kitchenette for $kitchenette_timeout minutes";

    #  print_log "Turning off light.";
}

# Front Door
# No lighting control here yet.
if ( state_now $front_door_dark eq "front_door_dark" ) {
    print_log "Front Door is now Dark.";
}
if ( state_now $front_door_dark eq "front_door_dark_stopped" ) {
    print_log "Front Door is now Lit.";
}

# Saw motion at the front door...
if ( state_now $front_door_motion eq "front_door_motion" ) {
    if ( $location{Current} eq 'kitchen' ) {
        $location{Current} = 'away';
    }

    #   $location{Current} = "front_door";
    $location{front_door_tds} = $Time;

    # If we haven't already reported the movement, do so now.
    if ( inactive $front_door_timer) {
        print_log
          "Movement sensed at Front Door.  Setting timer to $front_door_timeout minutes.";
    }
    else {
        print_log "Movement sensed at the Front Door.";
    }
    set $front_door_timer ( $front_door_timeout * 60 );

    #   if (((state $front_door_dark ne "front_door_dark_stopped") || (time_greater_than("$Time_Sunset"))) && (state $front_door_light ne ON)) {
    #     print_log "Bath Room is Dark.  Turning on light.";
    #     set $bathrm_light ON;
    #   }
    #   else {
    #     print_log "Bath Room is Lit.  Light state will not be changed.";
    #   }
}

# Has front door motion timer elapsed with no further motion?
if ( expired $front_door_timer) {

    #  set $bathrm_light OFF;
    print_log "No movement at Front Door for $front_door_timeout minutes";

    #  print_log "Turning off light.";
}

# Back Door
# No lighting control here yet.
if ( state_now $back_door_dark eq "back_door_dark" ) {
    print_log "Back Door is now Dark.";
}
if ( state_now $back_door_dark eq "back_door_dark_stopped" ) {
    print_log "Back Door is now Lit.";
}

# Saw motion at the back door...
if ( state_now $back_door_motion eq "back_door_motion" ) {

    if ( $location{Current} eq 'living_room' ) {
        $location{Current} = 'away';
    }

    #   $location{Current} = "back_door";
    $location{back_door_tds} = $Time;

    # If we haven't already reported the movement, do so now.
    if ( inactive $back_door_timer) {
        print_log
          "Movement sensed at the Back Door.  Setting timer to $back_door_timeout minutes.";
    }
    else {
        print_log "Movement sensed at the Back Door.";
    }
    set $back_door_timer ( $back_door_timeout * 60 );

    #   if (((state $back_door_dark ne "back_door_dark_stopped") || (time_greater_than("$Time_Sunset"))) && (state $back_door_light ne ON)) {
    #     print_log "Bath Room is Dark.  Turning on light.";
    #     set $bathrm_light ON;
    #   }
    #   else {
    #     print_log "Bath Room is Lit.  Light state will not be changed.";
    #   }
}

# Has back door motion timer elapsed with no further motion?
if ( expired $back_door_timer) {

    #  set $bathrm_light OFF;
    print_log "No movement at the Back Door for $back_door_timeout minutes";

    #  print_log "Turning off light.";
}

