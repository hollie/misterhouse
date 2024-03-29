# Category=Chuck_demo

#@ Demo control of lights using the occupied mode

=begin comment 
This code provides a demo for using the occupied mode variable to program
lights on and off according to a schedule.  Written by piper_chuck@yahoo.com

First, some basic setup information.  

Light control - This code assumes that you have already setup light control using X-10 or some other kind of interface.  The lights or other devices you want to control are setup by clicking MrHouse Home->Setup MrHouse->Edit Items.  Once you've defined the light, gone to the lights menu to confirm you can control it, you can use it here.

The code that follows are some of the pieces I used while I was figuring out how this stuff works.  Once I got the schedule working correctly, I actually moved it all to a comment section and then resurrected it to build this demo module.  Note also that much of this code could be optimized to improve efficiency.  
=cut

# Various variables.  Some are only local and others are global.  It is possible
# that some are no longer used.
 
 my $light_states = "on,brighten,dim,off";
 my $state;
 my $outdoor_lights_on;
 my $outdoor_lights;
 my $vacation_set = "no";
 our $New_min_set;
 
 our $demo_occupied_state;
 our $demo_last_state;
 my $state_changed;

# get the current value of the occupied setting

 $demo_occupied_state = state $mode_occupied;

# Compare with the last setting to determine if the state changed

 if ($demo_last_state ne $demo_occupied_state) {
   $demo_last_state = $demo_occupied_state;
   $state_changed = 1;
 }
 else {
    $state_changed = 0;
 }

=begin comment
The following code toggles lights based on changes to occupied mode.  This is most likely not the way one would use the mode values, but it does allow you to see immediate results from changing the value.
=cut

 if ($state_changed & $demo_occupied_state eq 'vacation'){
       print_log "Changed to vacation mode, turn on lights";
       set $Hall_down ON;
       set $Dining_room OFF;
 }
  if ($state_changed & $demo_occupied_state eq 'home'){
       print_log "home mode, turn lights off";
       set $Office_lamp OFF;
       set $Dining_room ON;
       #print_log "Turned dining room light off";
 }

  if ($state_changed & $demo_occupied_state eq 'work'){
       print_log "home mode, turn lights off";
       set $Office_lamp ON;
       set $Hall_down OFF;
       #print_log "Turned downstairs hall on";
 }

=begin comment
# This code toggles lights on and off at specific times.  Again, it is setup 
# for demo purposes.  Change the minute values, reload the code and then try 
# it out.  Note that if this were put in "production" one would probably use
# $New_Hour and $Hour variables rather than minutes.  While I was testing I wasn't 
# going to wait around for hours to see if it worked or not. 

 if ($New_Minute & $demo_occupied_state eq 'vacation') {
    if ($Day = 'Fri' or $Day = 'Sat' or $Day = 'Mon') {
       #print "new minute setting is $New_min_set\n";
       
       if ($Minute eq '19') {
         set $Hall_down ON;
         set $Dining_room ON;
         print "turning lights on\n";
       }
       if ($Minute eq '20') {
         set $Hall_down OFF;
         set $Dining_room OFF;  
         $New_min_set = 'off';
         print "turning lights off\n";
       }
    }
    if ($Day = 'Sat') {

    }
 }    
# Move the cut to before the code to try it out
=cut

=begin comment
# This code is designed to toggle lights on and off every minute.  

 if ($New_Minute & $demo_occupied_state eq 'vacation') {
    if ($Day = 'Mon') {
       print "new minute setting is $New_min_set\n";
       
       if ($New_min_set eq 'off') {
         set $Hall_down ON;
         set $Dining_room ON;
         $New_min_set = 'on';
         print_log "turning lights on\n";
       }
       else {
         set $Hall_down OFF;
         set $Dining_room OFF;  
         $New_min_set = 'off';
         print_log "turning lights off\n";
       }
    }
 } 
# Move the cut to before the code to try it out
=cut