
# From Bill on 2/25/00

=begin comment

For what it's worth, here's the code I'm running right now; I realize there
are some dead-ends and remarked-out code in it, because I've started writing
pieces and then gotten sidetracked, but I thought it might be of interest;
especially the "state machine" part of the code.  It's pretty simple right
now, but the basic idea can be expanded easily.

=end



---------------------------------

# ***  Bill Richman's (bill_r@inetnebr.com) Mister House Control Code

# ----- Motion Sensor Definitions
------------------------------------------------------------

#$test_computer_room_movement = new Serial_Item('XG5GJ','on');
#$test_computer_room_movement -> add ('XG5GK','off');
#$test_computer_room_movement2 = new Serial_Item('XG5','motion');
#$test_computer_room_movement2 -> add ('XGJ',ON);
#$test_computer_room_movement2 -> add ('XGK',OFF);


#if (state_now $test_computer_room_movement eq 'on') {
#  print_log "test - movement detected";
#}

#print_log "Test2 state $state" if $state = state_now
$test_computer_room_movement2;

$computer_room_movement = new X10_Simple('G5');
$game_room_movement_1 = new X10_Simple('G1');
$game_room_movement_2 = new X10_Simple('G7');
$garage_movement = new X10_Simple('GB');
$living_room_movement = new X10_Simple('G3');
$master_bedroom_movement = new X10_Simple('GD');
$dining_room_movement = new X10_Simple ('GF');
$video_room_movement = new X10_Simple('J7');

# ----- Light Sensor Definitions
------------------------------------------------------------

$computer_room_dark = new X10_Simple('G6');
$game_room_dark = new X10_Simple('G2');
$garage_dark = new X10_Simple('GC');
$living_room_dark = new X10_Simple('G4');
$master_bedroom_dark = new X10_Simple('GE');
$dining_room_dark = new X10_Simple ('GG');
# ---$video_room_dark = new X10_Simple('J7');

# ----- Keypad Button Definitions
------------------------------------------------------------

$computer_room_light_keypad  = new X10_Simple('H5');
$game_room_light_macro = new X10_Simple('H3');
$entrance_hall_light_keypad = new X10_Simple('HA');
$living_room_light_keypad = new X10_Simple('H1');

# ----- X10 Module Definitions
------------------------------------------------------------

$computer_room_light = new X10_Item('F9');
$game_room_light = new X10_Appliance('F3');
$entrance_hall_light = new X10_Item('F7');
$front_porch_light=new X10_Item('F4');
$garage_light = new X10_Item('E1');
$driveway_light = new X10_Item('F1');
$dining_room_light = new X10_Item('F5');
$kitchen_light = new X10_Item('F6');
$master_bedroom_stereo = new X10_Appliance('ID');
$living_room_stereo = new X10_Appliance('I1');
$living_room_light = new X10_Appliance('FA');

# ----- Timer Definitions
------------------------------------------------------------
$entrance_hall_light_timer=new Timer();
$computer_room_timer = new Timer();
$game_room_timer = new Timer();
$garage_timer = new Timer();
$living_room_timer = new Timer();
$master_bedroom_timer = new Timer();
$dining_room_timer = new Timer();
$kitchen_timer = new Timer();
$video_room_timer = new Timer();
$going_to_bed_path_state_timer = new Timer();
$coming_home_path_state_timer=new Timer();

# ----- Time Settings
------------------------------------------------------------
my $game_room_timeout=15;
my $computer_room_timeout=30;
my $entrance_hall_light_timeout=15;
my $garage_timeout=30;
my $living_room_timeout=15;
my $dining_room_timeout=15;
my $kitchen_timeout=15;
my $video_room_timeout=15;
my $master_bedroom_timeout=15;
my $going_to_bed_path_state_timeout=15;
my $coming_home_path_state_timeout=5;


# ----- Variable Definitions & Misc. Initialization
-------------------------------------------

my $entrance_hall_light_userpref;
my $entrance_hall_light_syspref;
my $living_room_light_userpref;
my $living_room_light_syspref;
my $all_is_quiet;
my $upstairs_is_quiet;
my $downstairs_is_quiet;

# Coming home path prediction
my $coming_home_path_state;
if ($Startup||$Reload) {
  $coming_home_path_state=0;
#  $living_room_light_userpref=state $living_room_light;
#  $entrance_hall_light_userpref=state $entrance_hall_light;
}


# Computer Room
my $computer_room_light_state;
my $computer_room_light_macro_state;

# Game Room
my $game_room_light_state;
my $game_room_light_macro_state;

# Entrance Hall
# Front Porch
# Garage
my $garage_light_state;


# ----- Global motion checks
------------------------------------------------------

$all_is_quiet=((inactive $computer_room_timer) && (inactive
$game_room_timer) && (inactive $garage_timer) && (inactive
$living_room_timer) && (inactive $master_bedroom_timer) && (inactive
$dining_room_timer) && (inactive $video_room_timer));

$upstairs_is_quiet=((inactive $computer_room_timer) && (inactive
$living_room_timer) && (inactive $master_bedroom_timer) && (inactive
$dining_room_timer) && (inactive $video_room_timer));

$downstairs_is_quiet=((inactive $game_room_timer) && (inactive
$garage_timer));

if ($all_is_quiet && $New_Minute) {
  print_log "All is quiet...";
}
else
{
  if ($upstairs_is_quiet && $New_Minute) {
    print_log "Upstairs is quiet...";
  }
  
  if ($downstairs_is_quiet && $New_Minute) {
    print_log "Downstairs is quiet...";
  }
}

# ***** Location-Specific Functions
************************************************

# ----- Entrance Hall
------------------------------------------------------------


# ----- Computer Room
------------------------------------------------------------

# Light level changed
#print_log "Computer_room_dark=".state $computer_room_dark;
if(state_now $computer_room_dark eq ON) {
  print_log "Computer Room is now Dark.";
}
if (state_now $computer_room_dark eq OFF) {
  print_log "Computer Room is now Lit.";
}

# Saw motion in the computer room...
if (state_now $computer_room_movement eq ON) {
   # If we haven't already reported the movement, do so now.
   if (inactive $computer_room_timer) {
     print_log "Movement sensed in Computer Room.  Setting timer to
$computer_room_timeout minutes.";
   }
   else {
     print_log "Movement sensed in Computer Room.";
   }
   set $computer_room_timer ($computer_room_timeout*60);
   if (state $computer_room_dark ne OFF) {
     print_log "Computer Room is Dark.  Turning on light.";
     set $computer_room_light ON;
   }
   else {
     print_log "Computer Room is Lit.  Light state will not be changed.";
   }
 }

# Has Computer Room  motion timer elapsed with no further motion?
if (expired $computer_room_timer) {
  set $computer_room_light OFF;
  print_log "No movement in Computer Room for $computer_room_timeout
minutes";
  print_log "Turning off light.";
}

# ----- Game Room
------------------------------------------------------------

# Light level changed
if(state_now $game_room_dark eq ON) {
  print_log "Game Room is now Dark.";
}
if (state_now $game_room_dark eq OFF) {
  print_log "Game Room is now lit.";
}

# Saw motion in the game room...
if ((state_now $game_room_movement_1 eq ON) || (state_now
$game_room_movement_2 eq ON)) {
   # If we haven't already reported the movement, do so now.
   if (inactive $game_room_timer) {
     print_log "Movement sensed in Game Room.  Setting timer to
$game_room_timeout minutes.";
   }
   else {
     print_log "Movement sensed in Game Room.";
   }
   set $game_room_timer ($game_room_timeout*60);
   if (state $game_room_dark eq ON) {
     print_log "Game Room is Dark.  Turning on light.";
     set $game_room_light ON;
   }
   else {
     print_log "Game Room is Lit.  Light state will not be changed.";
   }
 }

# Has Game Room  motion timer elapsed with no further motion?
if (expired $game_room_timer) {
  set $game_room_light OFF;
  print_log "No movement in Game Room for $game_room_timeout minutes";
  print_log "Turning off light.";
}

# ----- Living Room
------------------------------------------------------------

# Light level changed
if(state_now $living_room_dark eq ON) {
  print_log "Living Room is now Dark.";
}
if (state_now $living_room_dark eq OFF) {
  print_log "Living Room is now Lit.";
}

# Saw motion in the living room...
if (state_now $living_room_movement eq ON) {
   # If we haven't already reported the movement, do so now.
   if (inactive $living_room_timer) {
     print_log "Movement sensed in Living Room.  Setting timer to
$living_room_timeout minutes.";
   }
   else {
     print_log "Movement sensed in Living Room.";
   }
   set $living_room_timer ($living_room_timeout*60);
   if (state $living_room_dark eq ON) {
     print_log "Living Room is Dark";
   }
   else {
     print_log "Living Room is Lit.";
   }
 }

# ----- Master Bedroom
------------------------------------------------------------

# Light level changed
if(state_now $master_bedroom_dark eq ON) {
  print_log "Master Bedroom is now Dark.";
}
if (state_now $master_bedroom_dark eq OFF) {
  print_log "Master Bedroom is now Lit.";
}

# Saw motion in the master_bedroom...
if (state_now $master_bedroom_movement eq ON) {
   # If we haven't already reported the movement, do so now.
   if (inactive $master_bedroom_timer) {
     print_log "Movement sensed in Master Bedroom.  Setting timer to
$master_bedroom_timeout minutes.";
   }
   else {
     print_log "Movement sensed in Master Bedroom.";
   }
   set $master_bedroom_timer ($master_bedroom_timeout*60);
   if (state $master_bedroom_dark eq ON) {
     print_log "Master Bedroom is Dark";
   }
   else {
     print_log "Master Bedroom is Lit.";
   }
 }



# ----- Front Porch
------------------------------------------------------------

if (time_now "$Time_Sunset+0:15"){
  print_log "It's after sunset - turning Front Porch light ON.";
  set $front_porch_light ON;
}

if (time_now "$Time_Sunrise+0:30"){
  print_log "It's after sunrise - turning Front Porch light OFF";
  set $front_porch_light OFF;
}


 
# ----- Garage ------------------------------------------------------------

# Light level changed
if(state_now $garage_dark eq ON) {
  print_log "Garage is now Dark.";
}
if (state_now $garage_dark eq OFF) {
  print_log "Garage is now Lit.";
}

# Saw motion in the garage...
if (state_now $garage_movement eq ON) {
   # If we haven't already reported the movement, do so now.
   if (inactive $garage_timer) {
     print_log "Movement sensed in Garage.  Setting timer to $garage_timeout
minutes.";
   }
   else {
     print_log "Movement sensed in Garage.";
     set $garage_timer ($garage_timeout*60);
     set $garage_light ON;
   }
 }
# Has Garage  motion timer elapsed with no further motion?
if (expired $garage_timer) {
  set $garage_light OFF;
  print_log "No movement in Garage for $garage_timeout minutes";
  print_log "Turning off lights.";
}


# **** Movement Path Dependent Actions
******************************************************


# ----- Coming Home Action
-------------------------------------------------------

# If someone comes into the garage, and then the basement, assume they just
got home and
# are going upstairs, so turn on the entrance hall light.

my $coming_home_path_state;

# If the garage has recently detected motion, set state to 1 and start a
timer.
if (($all_is_quiet) && ($coming_home_path_state eq 0) && (state_now
$garage_movement eq ON)) {
  $coming_home_path_state=1;
  set $coming_home_path_state_timer ($coming_home_path_state_timeout*60);
}
else {
  # If the garage has recently detected motion, and now the game room
detects motion,
  # turn on the entrance hall light, and reset the state.
  if (($coming_home_path_state eq 1) && ((state_now $game_room_movement_1 eq
ON)||(state_now $game_room_movement_2 eq ON))) {
    print_log "Someone has come home through the garage.  Turning on
entrance hall light.";
    set $entrance_hall_light ON;
    set $entrance_hall_light_timer ($entrance_hall_light_timeout*60);
    $coming_home_path_state=0;    
  }
}

if (expired $coming_home_path_state_timer) {
  # False alarm - forget it.
  print_log "Oops - apparently nobody came in through the garage after
all!";
  $coming_home_path_state=0;
}


# ----- Going to Bed Action
-------------------------------------------------------

# If motion in kitchen/dining room/living room, then in master bedroom, and
it's after 10:00pm, 
# we're probably going to bed.

my $going_to_bed_path_state;

# If there's no movement anywhere except the master bedroom, we're probably
going to bed...

if ($downstairs_is_quiet && ($going_to_bed_path_state eq 0) && (state_now
$master_bedroom_movement eq ON)) {
  $going_to_bed_path_state=1;
  set $going_to_bed_path_state_timer ($going_to_bed_path_state_timeout*60);
}
else {
  if (($going_to_bed_path_state eq 1) && (time_greater_than "22:00" &&
time_less_than "03:00")) {
    $going_to_bed_path_state=2;
    #speak "Goodnight everybody!";
  }
}

if (expired $going_to_bed_path_state_timer) {
  print_log "Guess they weren't going to bed after all!";
  $going_to_bed_path_state=0;
}


# ----- User Inputs -------------------------------------------------------

# ----- Keypads  --------------------------------------------

$entrance_hall_light_userpref=state $entrance_hall_light_keypad;
$living_room_light_userpref=state $living_room_light_keypad;


# ----- Arbitration Rules between user and system
--------------------------------------------

# System sets _system preference for each device, while user input sets
_user preference for each device.
# This code must arbitrate between the two to determine what the actual
state should be set to
# for each device.  For example, if the system wants the porch light _on_
based on its rules, but the
# user manually turns it _off_, it should stay that way until the user
leaves,
# goes to bed, or otherwise indicates they wish to return to automatic
operation.

# Example house condition codes: home, sleeping, out, vacation
my $new_state;

if (state $entrance_hall_light ne $entrance_hall_light_userpref) {
  #print_log "state entrance_hall_light=".state $entrance_hall_light.".";
  #print_log "entrance_hall_light_userpref=$entrance_hall_light_userpref.";
  #print_log "Setting entrance hall light $entrance_hall_light_userpref.";
  $new_state=$entrance_hall_light_userpref;
  print_log "Setting entrance hall light $new_state.";
  set $entrance_hall_light $new_state;
  speak "Entrance hall light is now ".$new_state.".";
}

if (state $living_room_light ne $living_room_light_userpref) {
  $new_state=$living_room_light_userpref;
  print_log "Setting living room light $new_state.";
  set $living_room_light $new_state;
  speak "Living room light is now ".$new_state.".";
}




