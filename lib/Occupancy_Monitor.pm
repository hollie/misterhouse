
=head1 B<Occupancy_Monitor>

=head2 SYNOPSIS

   ********************** IMPORTANT ***************************
   The old method of calling set_fp_nodes() on each sensor object has been
   deprecated.  For the time being, as long as you call set_fp_nodes() on
   the object BEFORE you add() it to the occupancy monitor, the nodes will
   be properly transferred.  

   In addition, where in the past you added the actual sensors to the occupancy
   monitor, now you only add the Door_Item and Motion_Item objects.

   Please switch to the new method ASAP. 

   OLD METHOD:
      In a .mht file
         X10MS, B13, x10_example_motion_detector, , MS13
         MOTION, x10_example_motion_detector, example_motion_detector
         OCCUPANCY, om
         PRESENCE, x10_example_motion_detector, om, presence_example_room

      In a .pl file:
         $x10_example_motion_detector->set_fp_nodes(1, 2, 3);
         $om->add($x10_example_motion_detector);

   NEW METHOD:
      In a .mht file:
         X10MS, B13, x10_example_motion_detector, , MS13
         MOTION, x10_example_motion_detector, example_motion_detector
         OCCUPANCY, om
         PRESENCE, example_motion_detector, om, presence_example_room

      In a .pl file:
         $om->set_edges($example_motion_detector, 1, 2, 3);

   The differences here are:
      1) In the new method, x10_example_motion_detector is only used to
         create the example_motion_detector object.  After that it is
         not used in any occupancy code.  This means you'll have to change
         all the entries for PRESENCE objects in your .mht files to refer
         to the Motion_Item and not the original sensor. 
      2) set_edges() is called on the occupancy monitor and the 
         *Motion_Item* is passed in as the first argument.  This is done
         instead of calling set_fp_nodes() on the original sensor.

   Note that calling add() is no longer necessary if you call set_edges(),
   but won't hurt anything.  

   ************************************************************

Example initialization:

  use Occupancy_Monitor;
  $om = new Occupancy_Monitor();

Draw up a diagram of house rooms and number the connected rooms
passageways add the sensors and their connections in the example as
follows.  So, if you have a motion detector in a hallway connected to two
rooms, it would have two edges, one each for the boundry between the
hallway and each room.

  $om->set_edges($garage_motion, 1);
  $om->set_edges($garage_hall_motion, 1, 2);
  $om->set_edges($basement_motion, 2);
  $om->set_edges($kitchen_motion, 2, 3);
  $om->set_edges($family_motion, 3, 4);
  $om->set_edges($foyer_motion, 4, 5, 6);
  $om->set_edges($living_motion, 2, 5);
  $om->set_edges($den_motion, 6, 7);
  $om->set_edges($hall_motion, 4, 7, 8, 9);
  $om->set_edges($robert_bedroom, 8);
  $om->set_edges($celine_bedroom, 9, 10);
  $om->set_edges($master_bedroom, 9, 11);

You can have more than one motion detector and/or door in the same room,
just be sure to set the same edges on each detector.

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

  "minimum:xxx"	- Minimum count of people.  The name to me is a bit
     confusing.  What this actually represents in the highest number
     of people seen in the house since the last 'reset' of the 
     occupancy monitor.
  "current:xxx"	- Current count of people on last sensor report,
     or the number of unique people seen recently. 
  "average:xxX" - Running average count of people (NOT IMPLEMENTED YET??)
  "last:xxx" - Last sensor to report
  "people:xxx" - A different count of people in the house based on adding
     up the number of people in each presence object.  If you are not using
     room counts, then this will be the number of unique rooms containing
     people.  If you ARE using room counts then this should provide the
     most accurate count of the number of people in the house at the current
     time.
  <input states> - All input states are echoed exactly to the output state 
     as well.

Assigning Edges: More Detail

Each unique set of edges creates one room.  If multiple objects have the
same edges they are in the same room.  If two objects do NOT have the
same edges then they are NOT in the same room.  The order of the edges
does not matter but you should NOT list the same edge twice for the same
object.

To start, you assign a number to every junction between two rooms.  So,
let's say that your house consists of three rooms all off of a single
hallway.  You then have three junctions, each one between the hallway and
one room.  So, you would do this:

  # Hallway attaches to all three rooms
  $om->set_edges($motion_hallway, 1, 2, 3);

  # Each room attaches to the hallway
  $om->set_edges($motion_room1, 1);
  $om->set_edges($motion_room2, 2);
  $om->set_edges($motion_room3, 3);

Now, doors can be confusing, because they *are* the edge.  In this simple
example, if you had a door sensor on each of the three doors, you would
just do:

  $om->set_edges($door_room1, 1);
  $om->set_edges($door_room2, 2);
  $om->set_edges($door_room3, 3);

I had a difficult sitution where I had two doors with sensors which were
the two boundries of one room.  If the room had a motion sensor, then it
would work like this:

  $om->set_edges($motion_detector, 1, 2);
  $om->set_edges($door1, 1);
  $om->set_edges($door2, 2);

But in my case I did not have a motion detector, which means that edges 1
and 2 would never be associated with eachother... which would cause
problems.  So, my rule is, when a room does not have a motion detector at
all, but has one or more door sensors, act like the door sensor is *in*
the room instead of on the boundry:

  $om->set_edges($door1, 1, 2);
  $om->set_edges($door2, 1, 2);

In fact, you really should consider all doors to be IN one room or the
other.  You can still associate the door with the light items for each
room, which is usually what you want to do.  So, let's say that we are
back to three rooms connected in a row.  Each room has a motion detector.
There is a door sensor on both doors.  You would start with the motion
detectors (where $motion2 is the middle room):

  $om->set_edges($motion1, 1);
  $om->set_edges($motion2, 1, 2);
  $om->set_edges($motion3, 2);

Now, you could "place" both door sensors in the middle room:

  $om->set_edges($door1, 1, 2);
  $om->set_edges($door2, 1, 2);

Or, you could "place" them in each end room:

  $om->set_edges($door1, 1);
  $om->set_edges($door2, 2);

Or you could put one in the middle room and one in an end room.  What you
should do is "place" the door items in the room with the poorest motion
detector coverage.  So, a room with no motion detectors would come first,
but a room with limited motion detector coverage is also a good choice.

Let's do one more door example.  We have two rooms, each with a motion
detector, and a door in between them.  So, we only have one edge:

  $om->set_edges($door, 1);
  $om->set_edges($motion_room_1, 1);
  $om->set_edges($motion_room_2, 1);

Now, what is wrong here?  Remember, if more than one object has the same
edge list then they are considered to be the same room.  So this edge
listing gives us one room only.  So, we need to make up at least one fake
edge:

  $om->set_edges($door, 1);
  $om->set_edges($motion_room_1, 1);
  $om->set_edges($motion_room_2, 1, 100);

Now there are two rooms and the door is "in" room #1.  This is great if
room #1 has the poorest motion detector coverage.  If room #2 has poorer
coverage, put the door "in" room #2:

  $om->set_edges($door, 1, 100);
  $om->set_edges($motion_room_1, 1);
  $om->set_edges($motion_room_2, 1, 100);

If the rooms on each side of the door have about equal motion detector
coverage, then determine which room you are usually entering when you
open the door and place the door into that room.  You can still
attach the door to the Light_Items on both sides of the door.

Fine-tuning occupancy tracking:

ROOM COUNTS

First of all, you may want to experiment with a new feature where the
occupancy monitor actually keeps track of the number of people in each
room instead of just occupied/vacant.  Note that enabling this makes it
more likely that you will have false occupieds (thus leaving lights on
that don't need to be) and less likely that you will have false vacants
(thus turning lights off that need to be on).  Because of this you may
want to enable expiration of your presence objects (use the
occupancy_expire() function on each presence object). 

To enable the counting of people in each room:

  $om->room_counts(1);

NOTE: At this time, I no longer use room counts

IGNORE TIME

Next, I have many Hawkeye motion detectors that are very close together.
There are scenarios where I walk by one and it sends out 'motion'.  Then
I keep walking within its field of vision but it doesn't send out another
'motion' for about 5 seconds.  Let's say that after 3-4 seconds I walk
into another room and its motion detector sends out a 'motion'.  But then
the first motion detector finally sends out its 'motion' signal
immediately afterwards.  Now the occupancy monitor thinks I'm back in the
original room.  When I walk into the next room it thinks I'm a new
person. 

So, I added an optional "ignore time" for each detector.  I only recommend
using it for Hawkeye motion detectors and any other sensors that have a
certain amount of inherent latency.  I currently set this for ALL of my
Hawkeyes with a value of 2 seconds (which really means 2-3 seconds).
What this means is that if a room JUST went vacant within the previous
2-3 seconds (which happens when I enter a new room) and then there is a
motion signal, it will be ignored.  This could mess things up, though, if
you step into a room and then immediately step back into the previous
room.  But, if you stay in that new room within motion detector coverage
for another 5 seconds or so then another motion command should be sent
and everything should be okay.

Here is what I do for all of my Hawkeyes:

  $om->ignore_time($x10_motion_hallway, 2);

Now, my other situation is that I have soom door sensors which are
basically instantaneous.  But some of these doors have Hawkeye's pointing
right at the doors.  So, it is almost certain that when I open the door
and as I step through it the Hawkeye WILL send 'motion' after the door
indicated that it was opened.  So, for these specific motion detectors, I
set their ignore time to 10 seconds.

EXTRA ROOMS

This is another feature I added to handle my doors that so quickly send
changes to Misterhouse.  The scenario is that I am in room 1, I walk
through room 2 and open a door with a sensor before any motion detectors
in room 2 have been able to tell Misterhouse they saw motion.  So, all of
a sudden the occupancy monitor thinks I am a second person.

So, what this allows for is, if a sensor detects activity, and there is
nobody in the immediately surrounding rooms, then it will turn to these
extra rooms to check for people.  If it finds somebody in one of these
rooms it will move them to the new location.  You turn this on by doing
this:

  $om->set_extra_rooms($master_bed_door_sensor, 
  $sensor_master_bath, $sensor_hall_bedrooms);

This says that if the sensor $master_bed_door_sensor detects activity
(i.e. it is opened), and nobody is present in the two connecting rooms,
then go on and check the room containing $sensor_master_bath and the room
containing $sensor_hall_bedrooms.  

This is also useful if you have any motion detectors that frequently miss
you entering the room... especially if there is a certain path you take
from one room to another and through a third room that causes you to not
be detected my a motion detector in that third room.

Here are some details:

  1) The first argument is an actual sensor, not a Door_Item or
  Motion_Item!  This only applies to that single SENSOR and not
  to any other sensors that may be in the same room.
  2) All of the remaining objects are sensors from ROOMS from which
  the presence can be taken.  If there are multiple sensors in the 
  ROOM then only list ONE of them.  
  3) IMPORTANT: The sensor in the first argument must be separated
  from each following sensor by only ONE room.  This is because
  the algorithm will move the person from the extra room into ONE
  intermediate room and then expects them to be adjacent to the
  room containing the sensor listed as the first argument.

MAINTAIN PRESENCE

This function was added just because of my dogs.  What I have done in my
house is set up most motion detectors so that they will never see the
dogs.  This works fine most of the time.  The problem is that if two
people are in one room and one person leaves, the occupancy monitor
doesn't know if two people or one person left.  So, the initial room will
go vacant until it sees more activity in there.

The problem is that for certain rooms like the master bedroom and family
room, the person in the room might be sitting down or laying down out of
range of the motion detectors.  This means that the light will turn off
on them after the timer runs out.  

So, I have certain motion detectors that watch the entire room and
regularly pick up the dogs.  They are set, however, to only *maintain*
presence and not *establish* presence.  The way this is accomplished is:

  1) Motion from these detectors is ignored unless the occupancy
    monitor thinks the room was recently vacated (within a 
    user-specified number of seconds), in which case the room
    is switched back to "occupied".
  2) Motion from these detectors will never cause predictions nor
    will it remove people from surrounding rooms.
  3) When a room IS switched back to "occupied" because of one of these 
    sensors, the occupancy count is never increased (if you are not using 
    room counts, this will only happen if there are too many unique rooms 
    occupied as defined by expected_occupancy).  What this means is that 
    the room with the most stale presence has its room count decreased 
    (or simply marked 'vacant' if not using room counts) to account for 
    this new presence.

You enable this only for the motion detectors you want largely to be
ignored by the system:

  $om->maintain_presence($family_room_motion_maintain, 300);

In this case, if the room was vacated within the previous 300 
seconds then the specified motion detector can re-establish
presence if it detects motion.  Remember that you can also set
a minimum amount of time the room must be vacant before the
presence can be re-established using ignore_time().

NO NEW PRESENCE

      Another function added because of my animals.  In this case, you can set
      a sensor (probably a Motion_Item) that can only cause the room to become
      occupied if it is able to take occupancy from a surrounding room (or any
      extra rooms specified).  This means that occupancy can never pop up in
      this room.  In my case, I have a small bathroom with a motion detector on
      the ceiling looking straight down.  We normally keep the door cracked
      shut, but the cats get in sometimes and create motion.  Since there is
      only one connecting room to the bathroom, presence will only show up
      there if presence was already in the connecting room.

         $om->no_new_presence($hall_bath_motion_detector);

      Where $hall_bath_motion_detector is a Motion_Item in my case, and to
      me this setting only makes sense with motion detectors.  Note that if
      you have the motion item attached to the light item then the light
      will still turn on even though presence is not established.

      DOOR EDGES

      When somebody enters a room, and there are people present in more than
      one connecting room, it does not know from which room the person came.
      So, it has no choice but to assume all people entered the new room with
      the hope that motion sensor activity will return any falsely removed
      people to their appropriate rooms, with the true empty room never
      regainging occupancy, of course.

      Well, this method works pretty well, but I like to use every bit of
      information I have available to me.  So, what I realized is that if a
      particular edge is actually a door and that door has not been opened
      recently, then there is no way that any people that are behind that door
      to move into the attached room.  So, I have added a facility for you to
      tell the occupancy monitor where exactly your doors are and as such this
      knowledge can be exploited.

      The format of the call is:
         $om->door_restriction($door_object, 1, 10);

      Where $door_object is the actual Door_Item for the door you are referring
      to.  The number '1' is the one edge the door is on.  The number '10' is
      the number of seconds back that an open state will be searched for.  
      
      I'll try to put the above function call into a bit easier to understand
      English.  Basically, it is telling the occupancy monitor to NOT allow
      anybody to move across edge 1 unless the door $door_object was in an
      open state in the previous 10 seconds.

      You must call this function for every door object you want to enable this
      feature for.  By default, a door's open/closed state does not affect
      whether or not somebody can pass through its edge (plus, in many cases
      the occupancy monitor does not know which edge the door is actually on).

      Because doors can trap a fake person in a room, I recommend setting
      an expiration on the presence object.  Also, when a door restriction
      is enabled, because of this trapping possibilty, the system is a bit
      more liberal with removing people from rooms when the door was just 
      recently closed.  For that reason, I recommend that any rooms with
      such a door restrictions should either be a room that you rarely 
      remain inside with the door closed (i.e. a closet) or a room with its
      own motion detector inside.

      MAX OCCUPANCY

      In my home automation setup, I usually know how many people are in the
      house from other sources.  But I need the occupancy monitor to keep track
      of where the people actually are.  There is no point in setting a minimum
      occupancy because the occupancy monitor would have no idea where to place
      the people initially.  Besides, errors pretty much always cause too many
      people to be present, not too few.

      So, if you set a maximum here, if too many people are present in the
      house, then the "stalest" presence will be removed.  Remember, if you
      are not using room counts (which I don't currently), this will actually
      just limit the number of unique rooms containing people.

         $om->max_occupancy(3);

      This sets the absolute number of people to be tracked in the house to 
      three.  To disable, set this to -1, which is the default.

      NOTE: max_occupancy() will keep the number of people present, determined
      by adding up the occupancy count of each room, less than or equal to the
      value set.  It will NOT affect the 'minimum' count which is based only on
      activity and therefore the 'minimum' count may exceed the specified
      maximum.  The 'people' count, on the other hand, will always be less than
      the specified number.

      EXPECTED OCCUPANCY

      Sometimes we have people come over and spend the night in which case 
      I enable a guest mode which increases the maximum occupancy.  But other
      times we just have somebody come over for dinner or whatever.  So,
      what I'm trying now is to set the maximum occupancy to one higher than
      the expected occupancy.  And then I'm setting the expected occupancy
      to 1 or 2 depending on whether my wife and/or I are home.

      The idea is that the system will try to keep occupancy at the expected
      occupancy.  But if occupancy exceeds this expected value twice within
      a specified period of time, then it allows the occupancy to increase.
      Once it is increased, the expected occupancy is actually increased to the
      new value.  This means that it can increase yet again if it needs to.
      But it will never increase to above the maximum occupancy, if set.

      To reset the expected occupancy, just set it again.  This will put it
      back to the value specified and reset any timers related to it.  What
      I do is do such a reset whenever my front door is opened which is how
      our guests always come into or leave the house.

         $om->expected_occupancy(2, 300);

      This resets the expected occupancy to 2 people and allows it to increase
      whenever an increase looks necessary twice within 300 seconds.  Note that
      this does not actually affect any presence information, unless the current
      occupancy count is greater than the new expected count, in which case
      only the most recent presence is maintained.

      To turn off the expected occupancy, set it to -1:
      
         $om->expected_occupancy(-1);

      NOTE: expected_occupancy() will keep the number of people present,
      determined by adding up the occupancy count of each room, less than or
      equal to the value set.  It will NOT affect the 'minimum' count which is
      based only on activity and therefore the 'minimum' count may exceed the
      specified maximum.  The 'people' count, on the other hand, will always be
      less than the specified number.  In fact, the first time the expected
      occupancy is exceeded, 'minimum' will go up by one and 'people' will remain
      at the expected occupancy level.  If this happens again within the specified
      amount of time, 'people' will rise to the 'minimum' count at that point.

      PARTIAL PRESENCE

      I have managed to avoid detecting my dogs with the motion detectors in 
      every room in my house.  I have, however, a problem in the kitchen.
      Despite my best efforts, the cats still jump onto the counters and the
      kitchen table and therefore trigger my motion detectors.

      So, I added the ability to require more than one motion detector to
      detect motion before presence is established in the room.  This is
      done by overriding the default weight of 1 for particular motion detectors.
      Once enough unique motion detectors detect motion to cause the cumulative
      count to exceed 1, presence will be established.  

      Here is an example that should hopefully make things more clear:

         $om->set_edges($om_motion_kitchen1, 11, 13, 16);
         $om->set_edges($om_motion_kitchen2, 11, 13, 16);
         $om->set_edges($om_motion_kitchen3, 11, 13, 16);

         $om_motion_kitchen1->presence_value(0.5);
         $om_motion_kitchen3->presence_value(0.5);

         $om_auto_kitchen_light->add($om_motion_kitchen2, $only_when_fairly_dark, 
         $only_when_home, $om_presence_kitchen, $only_without_movie_lights);

      By not setting a value for $om_motion_kitchen2, it remains at the default
      of 1.  What this means is that if $om_motion_kitchen2 detects motion,
      presence is automatically established in the kitchen.  In addition, since
      $om_motion_kitchen2 is directly attached to the light object, the light
      will come on, regardless of the presence value.

      But, if $om_motion_kitchen1 detects motion, the presence will effectively
      be set to 0.5, which is not quite 1.  To establish presence in the kitchen,
      one of the other two motion detectors still need to detect motion.  Since
      both of the remaining motion detectors will push the total above 1, either
      one will cause presence to be established.

      Once presence is established in the room or a surrounding room the whole
      count is reset to zero.  
      
      An additional feature of partial presence is that if somebody walks
      through a room and doesn't trip enough motion detectors to establish
      presence, as long as they tripped at least one, presence is allowed to
      move through that room, if necessary.

      Put another way, if somebody pops up in a room, the following steps
      are taken, taking into account any door restrictions:
         1) Presence is taken from all surrounding rooms
         2) If no surrounding presence is found, but partial presence is
            found in a surrounding room *and* presence is found in a room
            adjoining that room, presence will move through the room
            with partial presence and into the new room.
         3) If extra rooms have been specified for the new room, and
            presence exists in one of those extra rooms, presence is
            taken from said room.
         4) Finally, if all else fails, new presence is created in the
            new room.

      PRESENCE EXPIRATION

      The standard presence expiration is handled through the presence object.
      Just call occupancy_expire() to set an expiration time on any of your
      presence objects (as described in Presence_Monitor.pm).  

      But, if you are using room counts (or the bounce-prevention code
      described next), there can be another problem.  Start with two people in
      one room.  Now one person goes into an adjoining room.  Then the other
      person also goes into the other room.  The problem is that, by default,
      the second person will never be moved into the other room.  That's what
      you can change here -- set an expiration time after which presence will
      be moved into another room when it detects activity, even if the other
      room already has one or more people in it.  

      The first argument is one of the sensors in the room, and the second
      argument is the expiration time, in seconds.  Be sure that you have
      called set_edges() on the sensor before calling this.

         $om->presence_move_time($sensor, 600);

      When setting this value, you should think about how long somebody would
      stay in the specified room and how good the motion detector is in that
      room, relative to the adjoining rooms.

      Remember -- in order for this to affect anything, the presence in one
      room has to be older than the specified time (which means there has been
      no motion detected) AND there has to then be activity in an adjacent room.

      PREVENT BOUNCES

      This option pretty much only makes sense to me when you are NOT using
      room counts, which I do not use at this time.  Basically, without room
      counts, there is no way, by default, that two adjoining rooms can both
      have occupancy at the same time (unless there is a closed door between
      them and you activate that restriction).

      In my house, the ktichen and family room are adjoining and if one person
      is in each room, the occupancy will keep bouncing back and forth as 
      motion detectors are triggered.  This is fine if you have a significantly
      lengthy delay before the lights turn off, but in my case I have lights or
      ceiling fans that may turn on only after a room has been continuously
      occupied for a certain amount of time.  In my case, then, I would like
      both rooms to be able to be occupied at the same time.  So, what you can
      do is this:

         $om->prevent_bounces($sensor_room1, $sensor_root2, 60, 2);

      Where $sensor_room1 is any sensor (Motion_Item or Door_Item) that is in one
      of the rooms, and $sensor_room2 is any sensor that is in the other room.  
      The rooms must be adjoining (or it wouldn't make much sense to use this
      feature).  This says that if presence leaves either of the rooms and moves
      to the other room two times within 60 seconds, then presence should be 
      allowed in both rooms at the same time.  Also note that this will NEVER 
      cause the expected occupancy count (which, when not using room counts, is 
      the expected unique rooms with presence) to be exceeded and will never 
      cause presence to be taken from elsewhere in the home to account for the 
      presence in adjoining rooms.

Examples:

   I want to provide some example scenarios here from my house to show how
   I use these various tuning options to improve occupancy tracking in my
   house.  I'll add these as I find time and reasons to add them.

   SCENARIO: Very close motion detectors in different rooms

   I have a couple of doorways in my house with motion detectors on each side.
   As I walk through the doorway, I trigger the two motion detectors perhaps
   within 1/10 to 1/5 of a second apart.  Because my Hawkeye motion detectors
   have not completely predictable latency associated with the first sign of
   motion and the sending of the signal, it is entirely possible that as I walk
   past detector 1 and then detector 2, Misterhouse receives the signal from
   detector 2 before the signal from detector 1.  So, without any modification,
   it will think that I ended up in the first room when in fact I ended up in
   the second room.

   So, I use the ignore_time() function to prevent this problem from occurring.
   By using this feature, the belated motion signal from detector 1 will be
   ignored because the room containing detector 1 just went vacant let's say 1
   second before the signal was received (room 1 went vacant when detector 2
   sent its motion signal).  This will properly leave my presence in room 2.

      $om->ignore_time($motion_detector_1, 4);
      $om->ignore_time($motion_detector_2, 4);

   Now, regardless of which way I walk through the doorway, a belated (out of
   order) signal from one of the detectors won't errantly move my presence back
   into the first room.  In fact, I use a delay of 2 (which means 2-3 seconds)
   for ALL of my Hawkeye motion detectors just in case.

   SCENARIO: Two doorways close together

   In one of my rooms, I have the previous scenario (two motion detectors in
   different rooms very close together) but also with a hallway entering room 1
   right outside the doorway.  The hallway does NOT have a motion detector
   close to this intersection.  So, what can happen here is that I'm in the
   hallway, I walk through room 1, and into room 2, and the scenario happens as
   described above.

   But the fix above doesn't fully solve the problem on its own.  Since I
   started out in the hallway, and then it got motion 2 activity, I was never
   in room 1, so the ignore time for motion 1 won't take effect.  So, even with
   the ignore time set, when Misterhouse receives the motion 2 signal, it
   assumes there is a new person in room 2 (and still thinks somebody is in the
   hallway).  Then, when the belated motion1 comes through, it moves both
   people into room 1.  So, not only is the presence removed from room 2, where
   it should be, but there are now too many people present (which only matters
   if you are using room counts). 

   So, we can add another setting in addition to the ignore_time() calls in the
   previous scenario.  We can specify that if motion 2 sees motion (in room 2)
   but there is nobody in any adjoining rooms (i.e. room 1), then if somebody
   is in the hallway they should automatically moved THROUGH room 1 and into
   room 2.  The moving through the room is important because presence is indeed
   briefly established in room 1 which makes the ignore time properly ignore
   the belated motion signal from motion 1.

      $om->set_extra_rooms($motion_detector_2, $motion_detector_hallway);

   This says that when motion_detector_2 detects motion and there is no
   presence in any adjoining rooms, to take presence from whatever room
   $motion_detector_hallway is in (if possible).  I don't have a rule for going
   the other way (room 2 into the hallway) because the motion detector in the
   hallway is sufficiently far away from the other motion detectors that it
   works just fine on its own.

   SCENARIO: Outside doors

   I have four outside doors on my house.  I treat the garage itself as a room
   of my house, so the external door there is the garage door.  Then I have my
   front door which is connected to my living room.  And I have two back doors
   both connected to my patio.  I actually treat the back patio as a room in my
   house as well.  I have X10 wireless door/window sensors on each of these
   doors.  I also have a gate between the front and back of my house with a
   sensor on it.  I have motion detectors in my garage but not anywhere
   outside of my house.

   I use the following user code to handle any occupancy issues related to any
   movement outside the house.  

   # First, handle movement in and out of the front door and garage
   if (state_now $om_door_front eq 'open') {
      # Front door was opened, remove presence from living room, counting
      # on motion detectors in the living room to re-establish presence
      $om_presence_living_room->set_count(0);
      # Also, if garage door is open, somebody might have gone from
      # the garage to the front door, so clear occupancy there.  Again,
      # motion detectors are in the garage to re-establish presence
      if (state $garage_door eq 'open') {
         $om_presence_garage->set_count(0);
      }
   }
   
   # Now, handle movement between the front yard and the back yard
   if (state_now $side_gate eq 'open') {
      # Gate was opened... remove presence from front and back yards
      # as appropriate, allowing it to be re-established only if
      # somebody re-enters one of the rooms
      $om_presence_back_patio->set_count(0);
      if (state $garage_door eq 'open') {
         $om_presence_garage->set_count(0);
      }
   }

=head2 DESCRIPTION

Counts the number of people in a network of motion sensors and, with
the use of Presence_Items, can keep track of the occupancy state of
each room.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Occupancy_Monitor;

@Occupancy_Monitor::ISA = ('Generic_Item');

sub new {
    my ( $p_class, $p_obj, @p_edges ) = @_;

    my $self = {};
    bless $self, $p_class;

    @{ $$self{states} } = ( 'reset', 'current', 'min', 'avg' );

    #	$self->add($p_obj,@p_edges) if (defined $p_obj);
    $self->add($p_obj) if ( defined $p_obj );
    $self->{room_counts}              = 0;
    $$self{m_max_occupancy}           = -1;
    $$self{m_expected_occupancy}      = -1;
    $$self{m_expected_occupancy_time} = 0;
    return $self;
}

sub reset {
    my ($self) = @_;
    @{ $$self{m_object_log} } = ();
    $$self{m_cur_count} = 0;
    $$self{m_min_count} = 0;
    $$self{m_people}    = 0;

    #reset room presence vars as well
    foreach my $obj ( keys %{ $$self{m_objects} } ) {
        $$self{m_objects}{$obj}{count} = 0;
    }
}

sub add {
    my ( $self, $p_obj ) = @_;

    my @l_objs;

    if ( $p_obj->isa("Group") ) {
        @l_objs = @{ $$p_obj{members} };
        foreach my $obj (@l_objs) {
            $self->add($obj);
        }
    }
    else {
        $self->add_item($p_obj);
    }

}

sub add_item    #add single item
{
    my ( $self, $p_obj ) = @_;

    # Backwards compatibility -- to be removed
    if ( ref $$p_obj{nodes} ) {
        @{ $$self{m_objects}{$p_obj}{edges} } =
          ( sort { $a <=> $b } @{ $$p_obj{nodes} } );
    }
    else {
        @{ $$self{m_objects}{$p_obj}{edges} } = ();
    }

    if ( $p_obj->isa('Motion_Item') ) {
        $p_obj->tie_items( $self, 'motion' );
    }
    elsif ( $p_obj->isa('Door_Item') ) {
        $p_obj->tie_items( $self, 'open' );
    }
    elsif ( $p_obj->isa('Light_Switch_Item') ) {
        $p_obj->tie_items( $self, 'pressed' );
    }
    else {
        # Backwards compatibilty for people that add non-Base_Item-related objects
        # Should be reduced (to just 'on'?) or removed in the future.
        $p_obj->tie_items( $self, 'on' );
        $p_obj->tie_items( $self, 'motion' );
        $p_obj->tie_items( $self, 'alertmin' );
        $p_obj->tie_items( $self, 'open' );
    }
    $$self{m_objects}{$p_obj}{object}        = $p_obj;
    $$self{m_objects}{$p_obj}{count}         = 0;
    $$self{m_objects}{$p_obj}{m_ignore_time} = 0;
    $$self{m_objects}{$p_obj}{m_maintain}    = 0;
    @{ $$self{m_objects}{$p_obj}{extra_rooms} } = ();
}

sub check_log {
    my ( $self, $p_obj ) = @_;

    if ( $main::Debug{occupancy} ) {
        foreach ( @{ $$self{m_object_log} } ) {
            &::print_log(
                "Log: $$self{m_objects}{$_}{object}->{object_name} [@{$$self{m_objects}{$_}{edges}}]"
            );
        }
        &::print_log(
            "Log check: $$p_obj{object_name} [@{$$self{m_objects}{$p_obj}{edges}}]"
        );
    }

    # check for duplicate edges
    if ( $$self{m_object_log}->[0] and $$self{m_objects}{$p_obj} ) {
        if (
            $self->compare_array(
                \@{ $$self{m_objects}{ $$self{m_object_log}->[0] }{edges} },
                \@{ $$self{m_objects}{$p_obj}{edges} }
            )
          )
        {
            return 1 if $self->need_to_steal_old_presence($p_obj);
            return 0;
        }
    }
    return 1;
}

sub add_log {
    my ( $self, $p_obj ) = @_;

    # check for duplicate edges
    if ( $$self{m_object_log}->[0] and $$self{m_objects}{$p_obj} ) {
        if (
            $self->compare_array(
                \@{ $$self{m_objects}{ $$self{m_object_log}->[0] }{edges} },
                \@{ $$self{m_objects}{$p_obj}{edges} }
            )
          )
        {
            # Top log entry matches, return without adding a duplicate
            return;
        }
    }

    unshift @{ $$self{m_object_log} }, $p_obj;

    # Jason: I don't see that the next line is necessary...
    @{ $$self{m_object_log} } =
      @{ $$self{m_object_log} };    # re-sequence indexes 0+

    #limit 20 log items (can only resolv up to 20 people)
    if ( @{ $$self{m_object_log} } > 20 ) { pop( @{ $$self{m_object_log} } ); }
    return 1;
}

sub reduce_occupancy_count {
    my ( $self, $desired_count ) = @_;
    return 0 unless ( $desired_count >= 0 );
    my $actual_count = $self->count_people();
    while ( $actual_count > $desired_count ) {
        $self->remove_oldest_person();
        $actual_count = $self->count_people();
    }
    return $actual_count;
}

sub generate_state {
    my ( $self, $p_setby ) = @_;
    $$self{m_people} = $self->count_people();

    # First, check for max occupancy
    if (    ( $$self{m_max_occupancy} >= 0 )
        and ( $$self{m_people} > $$self{m_max_occupancy} ) )
    {
        &::print_log(
            "Occupancy of $$self{m_people} exceeds set maximum ($$self{m_max_occupancy}): removing oldest presence"
        ) if $main::Debug{occupancy};
        $$self{m_people} =
          $self->reduce_occupancy_count( $$self{m_max_occupancy} );
    }

    # Now check expected occupancy
    if (    ( $$self{m_expected_occupancy} >= 0 )
        and ( $$self{m_people} > $$self{m_expected_occupancy} ) )
    {
        &::print_log(
            "Occupancy of $$self{m_people} exceeds the expected occupancy ($$self{m_expected_occupancy})"
        ) if $main::Debug{occupancy};
        if (
            $$self{m_expected_occupancy_last_time}
            and (
                (
                    $$self{m_expected_occupancy_last_time} +
                    $$self{m_expected_occupancy_time}
                ) > $::Time
            )
          )
        {
            &::print_log(
                "Expected occupancy was exceeded twice within $$self{m_expected_occupancy_time} seconds, allowing increase"
            ) if $main::Debug{occupancy};
            $$self{m_expected_occupancy}++;
            $$self{m_expected_occupancy_last_time} = 0;
        }
        else {
            $$self{m_expected_occupancy_last_time} = $::Time;
            $self->remove_oldest_person();
            $$self{m_people} = $self->count_people();
        }
    }
    $$self{m_cur_count} = $self->calc_total();
    if ( $$self{m_cur_count} > $$self{m_min_count} ) {
        $$self{m_min_count} = $$self{m_cur_count};
        $self->SUPER::set( 'changed:' . $$self{m_min_count}, $p_setby );
    }
    return
        'current:'
      . $self->cur_count()
      . ';minimum:'
      . $self->min_count()
      . ';last:'
      . $p_setby->{object_name}
      . ';people:'
      . $self->people();
}

sub get_last_motion {
    my ( $self, $p_obj ) = @_;
    return 0 unless ref $$self{m_objects}{$p_obj}{edges};
    my @array = @{ $$self{m_objects}{$p_obj}{edges} };
    return $$self{m_timing}{"@array"}{time};
}

sub record_motion {
    my ( $self, $p_obj ) = @_;
    my @array = @{ $$self{m_objects}{$p_obj}{edges} };
    $$self{m_timing}{"@array"}{time}   = $::Time;
    $$self{m_timing}{"@array"}{object} = $p_obj;
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    $_ = $p_state;
    if ( /on/i or /motion/i or /alertmin/i or /open/i or /pressed/i ) {
        if ( defined $p_setby and $p_setby ne '' ) {
            if ( $p_state eq 'motion' ) {
                $self->record_motion($p_setby);
            }
            unless ( $self->check_ignore($p_setby) ) {
                unless ( $self->check_maintain($p_setby) ) {
                    if ( $self->check_log($p_setby) ) {

                        # Regular object
                        if ( $self->calc_presence($p_setby) ) {
                            $self->add_log($p_setby);
                            $p_state = $self->generate_state($p_setby);
                        }
                        else {
                            $p_state = undef;
                        }
                    }
                }
            }
        }
    }
    elsif (/reset/i) {
        $self->reset();
        $p_state = 'changed:0';
    }
    $self->SUPER::set( $p_state, $p_setby ) if $p_state;
}

sub count_people {
    my ($self) = @_;
    my $count = 0;
    my %rooms_seen;
    foreach my $obj ( keys %{ $$self{m_objects} } ) {
        unless ( ref $$self{m_objects}{$obj}{edges} ) {
            &::print_log(
                "Occupancy Monitor ERROR: Object has no edges set: $$obj{object_name}"
            );
            return 0;
        }
        my @array = @{ $$self{m_objects}{$obj}{edges} };

        #&::print_log("count_people: checking object $$self{m_objects}{$obj}{object}->{object_name} (@array): $$self{m_objects}{$obj}{count}") if $main::Debug{occupancy};
        unless ( $rooms_seen{"@array"} ) {
            if ( $$self{m_objects}{$obj}{count} >= 1 ) {
                &::print_log(
                    "count_people: counting object $$self{m_objects}{$obj}{object}->{object_name} (@array): $$self{m_objects}{$obj}{count} (count=$count)"
                ) if $main::Debug{occupancy};
                $count += $$self{m_objects}{$obj}{count};
            }
            $rooms_seen{"@array"}++;
        }
    }
    return $count;
}

# Takes presence (or one person if using room counts) from
# the room with the "stalest" presence
sub remove_oldest_person {
    my ($self)      = @_;
    my $oldest_time = $::Time;
    my $oldest_obj  = undef;
    foreach my $obj ( keys %{ $$self{m_objects} } ) {
        if ( $$self{m_objects}{$obj}{count} >= 1 ) {
            if ( $$self{m_objects}{$obj}{time} <= $oldest_time ) {
                $oldest_time = $$self{m_objects}{$obj}{time};
                $oldest_obj  = $obj;
            }
        }
    }
    if ($oldest_obj) {
        foreach my $obj ( keys %{ $$self{m_objects} } ) {
            if (
                $self->compare_array(
                    \@{ $$self{m_objects}{$oldest_obj}{edges} },
                    \@{ $$self{m_objects}{$obj}{edges} }
                )
              )
            {
                &::print_log(
                    "Removing most stale person from room: $$self{m_objects}{$obj}{object}->{object_name}"
                ) if $main::Debug{occupancy};
                if ( $self->{room_counts} and $$self{m_objects}{$obj}{count} ) {
                    $$self{m_objects}{$obj}{count}--;
                }
                else {
                    $$self{m_objects}{$obj}{count} = 0;
                }
            }
        }
        $self->SUPER::set('stale_removed');
    }
}

sub check_maintain {
    my ( $self, $p_obj ) = @_;
    unless ( $$self{m_objects}{$p_obj} ) {
        return 0;
    }
    unless ( $$self{m_objects}{$p_obj}{m_maintain} > 0 ) {
        return 0;
    }

    # This object can only maintain but not establish presence
    # This means that the count only goes up if it recently was
    # changed to zero.  Does not activate any prediction.  Takes
    # presence from the stalest room.
    &::print_log( "Maintain Check: " . $$p_obj{object_name} )
      if $main::Debug{occupancy};
    my $maintain = 0;
    foreach my $obj ( keys %{ $$self{m_objects} } ) {
        if (
            $self->compare_array(
                \@{ $$self{m_objects}{$p_obj}{edges} },
                \@{ $$self{m_objects}{$obj}{edges} }
            )
          )
        {
            if (
                (
                    (
                        $$self{m_objects}{$obj}{last_decrease} +
                        $$self{m_objects}{$p_obj}{m_maintain}
                    ) >= $::Time
                )
                and ( $$self{m_objects}{$obj}{count} < 1 )
              )
            {
                # Okay, the object was decreased recently... and is down to zero
                # so we want to re-establish presence
                &::print_log(
                    "Sensor $$p_obj{object_name} re-establishing presence in $$self{m_objects}{$obj}{object}->{object_name}"
                ) if $main::Debug{occupancy};
                $maintain++;
                $$self{m_objects}{$obj}{count} = 1;
                $$self{m_objects}{$obj}{time}  = $::Time;
            }
        }
    }
    if ($maintain) {
        if ( $self->{room_counts} ) {

            # If using room counts, always remove one other person from house
            $self->remove_oldest_person();
        }
        else {
            # Otherwise, remove oldest person only if there are too many unique
            # rooms occupied
            $self->reduce_occupancy_count( $$self{m_expected_occupancy} );
        }
    }
    return 1;
}

# Determine if this room needs to steal old presence from an adjoining room
sub need_to_steal_old_presence {
    my ( $self, $p_obj ) = @_;
    my $edge;
    foreach my $obj ( keys %{ $$self{m_objects} } ) {
        if (
            $edge = $self->compare_array_elements(
                \@{ $$self{m_objects}{$p_obj}{edges} },
                \@{ $$self{m_objects}{$obj}{edges} }
            )
          )
        {
            if ( $$self{m_objects}{$obj}{count} >= 1 ) {
                unless (
                        $$self{door_edges}
                    and $$self{door_edges}{$edge}
                    and $self->was_door_closed(
                        $edge, @{ $$self{m_objects}{$obj}{edges} }
                    )
                  )
                {
                    if (
                        $self->{room_counts}
                        and $self->is_presence_too_old(
                            @{ $$self{m_objects}{$obj}{edges} }
                        )
                      )
                    {
                        return 1;
                    }
                }
            }
        }
    }
    return 0;
}

sub check_ignore {
    my ( $self, $p_obj ) = @_;
    unless ( $$self{m_objects}{$p_obj} ) {
        return 0;
    }
    unless ( $$self{m_objects}{$p_obj}{m_ignore_time} > 0 ) {

        # If no ignore time set, always return not ignored
        return 0;
    }
    &::print_log( "Ignore Check: " . $$p_obj{object_name} )
      if $main::Debug{occupancy};

    if ( $$self{m_objects}{$p_obj}{used} ) {
        &::print_log(
            "Ignored duplicate activity from: " . $$p_obj{object_name} )
          if $main::Debug{occupancy};
        return 1;
    }

    # Make sure we don't want to ignore this
    foreach my $obj ( keys %{ $$self{m_objects} } ) {
        if (
            $self->compare_array(
                \@{ $$self{m_objects}{$p_obj}{edges} },
                \@{ $$self{m_objects}{$obj}{edges} }
            )
          )
        {
            if (
                (
                    $$self{m_objects}{$obj}{last_decrease} +
                    $$self{m_objects}{$p_obj}{m_ignore_time}
                ) >= $::Time
              )
            {
                # The object was decreased within the specified ignore time,
                # so ignore this acitvity
                &::print_log( "Ignored activity from: " . $$p_obj{object_name} )
                  if $main::Debug{occupancy};
                return 1;
            }
        }
    }
    return 0;
}

# Return 1 if the door was closed within the previous X seconds
# But returns 0 if there was motion that was more recent in the specified
# room, taking into account any ignore time.  This is used for edges with
# a door restriction enabled but with room counts enabled to provide a
# "last-chance" method for somebody to exit the room before the door restriction
# locks them inside.  Of course, it is also possible for somebody to get locked
# out of the room and therefore cause another presence to appear in the room.
sub was_door_just_closed {
    my ( $self, $edge, @room_edges ) = @_;
    my $object    = $$self{door_edges}{$edge}{object};
    my $seconds   = $$self{door_edges}{$edge}{seconds};
    my $last_time = $object->get_last_close_time();
    if ( ( $last_time + $seconds ) > $::Time ) {
        &::print_log("Door $$object{object_name} was recently closed")
          if $main::Debug{occupancy};
        if ( $$self{m_timing} and $$self{m_timing}{"@room_edges"} ) {
            if (
                (
                    $$self{m_timing}{"@room_edges"}{time} -
                    $$self{m_objects}
                    { $$self{m_timing}{"@room_edges"}{object} }{m_ignore_time}
                ) > $last_time
              )
            {
                # Motion detector inside room since the door change,
                &::print_log(
                    "Door $$object{object_name} was recently closed, but there was recent motion from "
                      . $$self{m_timing}{"@room_edges"}{object}->{object_name} )
                  if $main::Debug{occupancy};
                return 0;
            }
        }
        return 1;
    }

    # If we are here then the door was NOT closed within the specified
    # time, or there was motion in the room since the time the door was closed
    return 0;
}

sub is_presence_too_old {
    my ( $self, @room_edges ) = @_;
    my $time = $$self{m_timing}{"@room_edges"}{move_time};
    return 0 unless ( $time and ( $time > 0 ) );
    if ( $$self{m_timing}{"@room_edges"}{time} + $time < $::Time ) {
        return 1;
    }
    return 0;
}

# Return 0 if the door was open within the previous X seconds
sub was_door_closed {
    my ( $self, $edge, @room_edges ) = @_;
    my $object  = $$self{door_edges}{$edge}{object};
    my $seconds = $$self{door_edges}{$edge}{seconds};
    if (   ( state $object eq 'open' )
        or ( $object->get_last_close_time + $seconds > $::Time ) )
    {
        # Return that door was opened within the specified time frame,
        # thus allowing presence to be transferred across the edge
        &::print_log(
            "Door $$object{object_name} was opened so occupancy transfer is allowed"
        ) if $main::Debug{occupancy};
        if (    ( state $object ne 'open' )
            and $$self{m_timing}
            and $$self{m_timing}{"@room_edges"} )
        {
            if (
                (
                    $$self{m_timing}{"@room_edges"}{time} -
                    $$self{m_objects}
                    { $$self{m_timing}{"@room_edges"}{object} }{m_ignore_time}
                ) > $object->get_last_close_time
              )
            {
                # Sure, the door was open within the time period, but there was motion
                # in the other room after the door was shut, even after taking into
                # account the ignore time, so we won't allow occupancy transfer
                return 1;
            }
        }
        return 0;
    }

    # If we are here then the door was NOT opened within the specified
    # time.  Return 1 to indicate that the door is closed
    &::print_log(
        "Door $$object{object_name} was not opened so occupancy transfer is not allowed"
    ) if $main::Debug{occupancy};
    return 1;
}

sub get_presence_value {
    my ( $self, $p_obj ) = @_;
    my $presence_value = 1;
    if ( $p_obj->can('presence_value') ) {
        $presence_value = $p_obj->presence_value();
    }
    unless ( $presence_value and ( $presence_value > 0 ) ) {
        $presence_value = 1;
    }
    return $presence_value;
}

sub determine_new_count {
    my ( $self, $p_obj, $presence_value ) = @_;
    unless ($presence_value) {
        $presence_value = $self->get_presence_value($p_obj);
    }
    if ( $$self{m_objects}{$p_obj}{count} < 0 ) {
        return $presence_value;
    }
    return ( $$self{m_objects}{$p_obj}{count} + $presence_value );
}

# Return 1 to allow the presence to be decreased/removed
# Return 0 if the decrease has occurred too many times in past X seconds
sub check_decrease_count {
    my ( $self, $p_obj, $source_edges ) = @_;
    unless (
            $$self{m_bounce_prevent}
        and $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
        and $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
        {"@{$source_edges}"}
        and
        ( $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
            {"@{$source_edges}"}{'time'} > 0 )
        and
        ( $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
            {"@{$source_edges}"}{'count'} > 0 )
      )
    {
        return 1;
    }
    if ( $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
        {"@{$source_edges}"}{'array'}[0] == $::Time )
    {
        # Same exact time, assume it is another object in the same room
        return 1;
    }
    for (
        my $i = (
            $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
              {"@{$source_edges}"}{'count'} - 1
        );
        $i > 0;
        $i--
      )
    {
        $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
          {"@{$source_edges}"}{'array'}[$i] =
          $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
          {"@{$source_edges}"}{'array'}[ $i - 1 ];
    }
    &::print_log(
        "Checking for bouncing in $$self{m_objects}{$p_obj}{object}{object_name} [source @{$source_edges}]: "
          . $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
          {"@{$source_edges}"}{'array'}[
          $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
          {"@{$source_edges}"}{'count'} - 1
          ]
          . ', '
          . (
            $::Time -
              $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
              {"@{$source_edges}"}{'time'}
          )
    ) if $main::Debug{occupancy};
    if (
        $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
        {"@{$source_edges}"}{'array'}[
        $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
          {"@{$source_edges}"}{'count'} - 1
        ] > (
            $::Time -
              $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
              {"@{$source_edges}"}{'time'}
        )
      )
    {
        &::print_log(
            "Checking for bouncing: expected_occupancy=$$self{m_expected_occupancy}, people=$$self{m_people}"
        ) if $main::Debug{occupancy};
        if (   ( $$self{m_expected_occupancy} < 0 )
            or ( $$self{m_people} < $$self{m_expected_occupancy} ) )
        {
            # Bounced too many times in the specified amount of time... and we have room to expand without exceeding the expected occupancy
            foreach ( keys %{ $$self{m_bounce_prevent} } ) {
                if ( $$self{m_bounce_prevent}{$_}
                    {"@{$$self{m_objects}{$p_obj}{edges}}"} )
                {
                    for (
                        my $i = 0;
                        $i < $$self{m_bounce_prevent}{$_}
                        {"@{$$self{m_objects}{$p_obj}{edges}}"}{'count'};
                        $i++
                      )
                    {
                        $$self{m_bounce_prevent}{$_}
                          {"@{$$self{m_objects}{$p_obj}{edges}}"}{'array'}[$i]
                          = 0;
                    }
                }
            }
            for (
                my $i = 0;
                $i <
                $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
                {"@{$source_edges}"}{'count'};
                $i++
              )
            {
                $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
                  {"@{$source_edges}"}{'array'}[$i] = 0;
            }
            &::print_log(
                "Preventing bouncing by leaving presence in $$self{m_objects}{$p_obj}{object}{object_name}: @{$source_edges}"
            ) if $main::Debug{occupancy};
            return 0;
        }
    }
    $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj}{edges}}"}
      {"@{$source_edges}"}{'array'}[0] = $::Time;
    return 1;
}

sub prevent_bounces {
    my ( $self, $p_obj1, $p_obj2, $p_time, $p_count ) = @_;
    $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj1}{edges}}"}
      {"@{$$self{m_objects}{$p_obj2}{edges}}"}{'time'} = $p_time;
    $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj2}{edges}}"}
      {"@{$$self{m_objects}{$p_obj1}{edges}}"}{'time'} = $p_time;
    $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj1}{edges}}"}
      {"@{$$self{m_objects}{$p_obj2}{edges}}"}{'count'} = $p_count;
    $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj2}{edges}}"}
      {"@{$$self{m_objects}{$p_obj1}{edges}}"}{'count'} = $p_count;
    for ( my $i = 0; $i < $p_count; $i++ ) {
        $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj1}{edges}}"}
          {"@{$$self{m_objects}{$p_obj2}{edges}}"}{'array'}[$i] = 0;
        $$self{m_bounce_prevent}{"@{$$self{m_objects}{$p_obj2}{edges}}"}
          {"@{$$self{m_objects}{$p_obj1}{edges}}"}{'array'}[$i] = 0;
    }
}

sub calc_presence {
    my ( $self, $p_obj, $presence_value ) = @_;
    my $dec_count = 0;
    my %rooms_seen;

    &::print_log( "Presence Check: " . $$p_obj{object_name} )
      if $main::Debug{occupancy};

    $presence_value = $self->get_presence_value($p_obj)
      unless defined $presence_value;

    # Run checks if partial presence is being used for this room
    if ( ( $$self{m_objects}{$p_obj}{count} < 1 ) and ( $presence_value < 1 ) )
    {
        # The current count is between 0 and 1 which indicates a partial presence
        # So, we need to see how this new activity affects the total...
        &::print_log(
            "Object $$p_obj{object_name} contributing $presence_value to presence"
        ) if $main::Debug{occupancy};
        $$self{m_objects}{$p_obj}{used} = 1;
        foreach my $obj ( keys %{ $$self{m_objects} } ) {
            if (
                $self->compare_array(
                    \@{ $$self{m_objects}{$p_obj}{edges} },
                    \@{ $$self{m_objects}{$obj}{edges} }
                )
              )
            {
                $$self{m_objects}{$obj}{count} =
                  $self->determine_new_count( $obj, $presence_value );
            }
        }
        if ( $$self{m_objects}{$p_obj}{count} < 1 ) {

            # Nope, still not high enough... exit.
            &::print_log(
                "Object $$p_obj{object_name} presence still not high enough: $$self{m_objects}{$p_obj}{count}"
            ) if $main::Debug{occupancy};
            return 0;
        }
        else {
            # Okay, we are above one... so now, return to 0 so that things can proceed like normal
            foreach my $obj ( keys %{ $$self{m_objects} } ) {
                if (
                    $self->compare_array(
                        \@{ $$self{m_objects}{$p_obj}{edges} },
                        \@{ $$self{m_objects}{$obj}{edges} }
                    )
                  )
                {
                    $$self{m_objects}{$obj}{count} = 0;
                }
            }
        }
    }

    #decrement any connected nodes
    my $edge;
    my $partial = undef;
    my %decrease_prevented;
    foreach my $obj ( keys %{ $$self{m_objects} } ) {

        #		&::print_log("checking: " . $$self{m_objects}{$obj}{object}->{object_name});
        if (
            (
                $edge = $self->compare_array_elements(
                    \@{ $$self{m_objects}{$p_obj}{edges} },
                    \@{ $$self{m_objects}{$obj}{edges} }
                )
            )
            and (
                not $self->compare_array(
                    \@{ $$self{m_objects}{$p_obj}{edges} },
                    \@{ $$self{m_objects}{$obj}{edges} }
                )
            )
          )
        {
            #			&::print_log("Destroy:" . $$self{m_objects}{$obj}{object}->{object_name});
            # clear nodes that had presence before, and mark -1
            # prediction for nodes that havent been visited yet
            $$self{m_objects}{$obj}{used} = 0;
            if ( $$self{m_objects}{$obj}{count} >= 1 ) {
                &::print_log( "Object "
                      . $$self{m_objects}{$obj}{object}->{object_name}
                      . " has common edge: $edge" )
                  if $main::Debug{occupancy};
                if ( $$self{door_edges} and $$self{door_edges}{$edge} ) {
                    &::print_log( "Object "
                          . $$self{m_objects}{$obj}{object}->{object_name}
                          . " was marked as a door with timeout: $$self{door_edges}{$edge}{seconds}"
                    ) if $main::Debug{occupancy};
                }
                unless (
                        $$self{door_edges}
                    and $$self{door_edges}{$edge}
                    and $self->was_door_closed(
                        $edge, @{ $$self{m_objects}{$obj}{edges} }
                    )
                  )
                {
                    &::print_log( "Object "
                          . $$self{m_objects}{$obj}{object}->{object_name}
                          . " no door edge restriction active" )
                      if $main::Debug{occupancy};
                    if (
                           ( $$self{m_objects}{$p_obj}{count} < 1 )
                        or ( $$self{m_objects}{$p_obj}{count} eq '' )
                        or $self->is_presence_too_old(
                            @{ $$self{m_objects}{$obj}{edges} }
                        )
                        or (
                                $$self{door_edges}
                            and $$self{door_edges}{$edge}
                            and $self->was_door_just_closed(
                                $edge, @{ $$self{m_objects}{$obj}{edges} }
                            )
                        )
                      )
                    {
                        # only decrement if first entering the node, or if this is a door
                        # edge and the door was just and there has not been recent activity
                        # inside the other room (was_door_just_closed() tells us that)
                        if (
                            (
                                not $decrease_prevented{
                                    "@{$$self{m_objects}{$obj}{edges}}"}
                            )
                            and $self->check_decrease_count(
                                $obj, \@{ $$self{m_objects}{$p_obj}{edges} }
                            )
                          )
                        {
                            if ( $self->{room_counts} ) {
                                $$self{m_objects}{$obj}{count}--;
                            }
                            else {
                                $$self{m_objects}{$obj}{count} = 0;
                            }
                        }
                        else {
                            $decrease_prevented{
                                "@{$$self{m_objects}{$obj}{edges}}"}++;
                        }
                        unless (
                            $rooms_seen{"@{$$self{m_objects}{$obj}{edges}}"} )
                        {
                            $dec_count++;
                            $rooms_seen{"@{$$self{m_objects}{$obj}{edges}}"}++;
                        }
                        $$self{m_objects}{$obj}{last_decrease} = $::Time;
                        &::print_log( "Connecting room "
                              . $$self{m_objects}{$obj}{object}->{object_name}
                              . " count decremented ($dec_count total)" )
                          if $main::Debug{occupancy};
                    }
                }
            }
            else {    #these nodes havent been visited. mark with -1
                if ( $$self{m_objects}{$obj}{count} > 0 ) {

                    # Mark this as a potential room to take partial presence from
                    $partial = $obj;
                }
                if (   ( $$self{m_objects}{$p_obj}{count} < 1 )
                    or ( $$self{m_objects}{$p_obj}{count} eq '' ) )
                {
                    $$self{m_objects}{$obj}{count} = -1;
                }
            }
        }
    }

    # An adjoining room had partial presence -- move presence to the room with partial
    # presence from a surrounding room and then take presence from that room
    if (
        (
               ( $$self{m_objects}{$p_obj}{count} < 1 )
            or ( $$self{m_objects}{$p_obj}{count} eq '' )
        )
        and ( $dec_count == 0 )
        and $partial
      )
    {
        my $proceed = 0;
        foreach my $obj ( keys %{ $$self{m_objects} } ) {
            unless (
                $self->compare_array(
                    \@{ $$self{m_objects}{$p_obj}{edges} },
                    \@{ $$self{m_objects}{$obj}{edges} }
                )
              )
            {
                unless (
                    $self->compare_array(
                        \@{ $$self{m_objects}{$partial}{edges} },
                        \@{ $$self{m_objects}{$obj}{edges} }
                    )
                  )
                {
                    if (
                        $edge = $self->compare_array_elements(
                            \@{ $$self{m_objects}{$partial}{edges} },
                            \@{ $$self{m_objects}{$obj}{edges} }
                        )
                      )
                    {
                        unless (
                                $$self{door_edges}
                            and $$self{door_edges}{$edge}
                            and $self->was_door_closed(
                                $edge, @{ $$self{m_objects}{$obj}{edges} }
                            )
                          )
                        {
                            &::print_log(
                                "Moving to intermediate room that already had partial presence: "
                                  . $$self{m_objects}{$partial}{object}
                                  ->{object_name} )
                              if $main::Debug{occupancy};
                            if (
                                $self->calc_presence(
                                    $$self{m_objects}{$partial}{object}, 1
                                )
                              )
                            {
                                $self->add_log(
                                    $$self{m_objects}{$partial}{object} );
                                $proceed = 1;
                                last;
                            }
                        }
                    }
                }
            }
        }
        if ($proceed) {

            # Now, call calc_presence again and return
            return $self->calc_presence($p_obj);
        }
    }

    # Now check any extra rooms specified to take presence from
    if (
        (
               ( $$self{m_objects}{$p_obj}{count} < 1 )
            or ( $$self{m_objects}{$p_obj}{count} eq '' )
        )
        and ( $dec_count == 0 )
        and ( @{ $$self{m_objects}{$p_obj}{extra_rooms} } )
      )
    {
        my $proceed = 0;

        # Nobody was found in connected rooms and the user specified a
        # extra list of possible rooms to steal presence from, so check them.
        foreach my $obj ( @{ $$self{m_objects}{$p_obj}{extra_rooms} } ) {
            if ( $$self{m_objects}{$obj}{count} >= 1 ) {
                &::print_log(
                    "Stealing presence from extra room $obj->{object_name}")
                  if $main::Debug{occupancy};

                # First, move a person to an intermediate room...
                foreach my $obj2 ( keys %{ $$self{m_objects} } ) {
                    unless (
                        $self->compare_array(
                            \@{ $$self{m_objects}{$p_obj}{edges} },
                            \@{ $$self{m_objects}{$obj2}{edges} }
                        )
                      )
                    {
                        unless (
                            $self->compare_array(
                                \@{ $$self{m_objects}{$obj}{edges} },
                                \@{ $$self{m_objects}{$obj2}{edges} }
                            )
                          )
                        {
                            if (
                                $edge = $self->compare_array_elements(
                                    \@{ $$self{m_objects}{$p_obj}{edges} },
                                    \@{ $$self{m_objects}{$obj2}{edges} }
                                )
                              )
                            {
                                unless (
                                        $$self{door_edges}
                                    and $$self{door_edges}{$edge}
                                    and $self->was_door_closed(
                                        $edge,
                                        @{ $$self{m_objects}{$obj2}{edges} }
                                    )
                                  )
                                {
                                    if (
                                        $edge = $self->compare_array_elements(
                                            \@{
                                                $$self{m_objects}{$obj}{edges}
                                            },
                                            \@{
                                                $$self{m_objects}{$obj2}{edges}
                                            }
                                        )
                                      )
                                    {
                                        unless (
                                                $$self{door_edges}
                                            and $$self{door_edges}{$edge}
                                            and $self->was_door_closed(
                                                $edge,
                                                @{
                                                    $$self{m_objects}{$obj}
                                                      {edges}
                                                }
                                            )
                                          )
                                        {
                                            &::print_log(
                                                "Moving to intermediate room "
                                                  . $$self{m_objects}{$obj2}
                                                  {object}->{object_name} )
                                              if $main::Debug{occupancy};
                                            if (
                                                $self->calc_presence(
                                                    $$self{m_objects}{$obj2}
                                                      {object},
                                                    1
                                                )
                                              )
                                            {
                                                $self->add_log(
                                                    $$self{m_objects}{$obj2}
                                                      {object} );
                                                $proceed = 1;
                                                last;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if ($proceed) {

                    # Now, call calc_presence again and return
                    return $self->calc_presence($p_obj);
                }
            }
        }
    }

    # At this point, if the sensor is marked with no_new_presence, and
    # we don't yet have $dec_count, then we need to ignore this activity
    if ( $$self{m_objects}{$p_obj}{m_no_new_presence} and ( $dec_count < 1 ) ) {
        return 0;
    }

    #increment current motion
    foreach my $obj ( keys %{ $$self{m_objects} } ) {
        if (
            $self->compare_array(
                \@{ $$self{m_objects}{$p_obj}{edges} },
                \@{ $$self{m_objects}{$obj}{edges} }
            )
          )
        {
            &::print_log(
                "Clearing used flag for $$p_obj{object_name} (presence)")
              if $main::Debug{occupancy};
            $$self{m_objects}{$obj}{used} = 0;
            &::print_log( "Adding $dec_count to room "
                  . $$self{m_objects}{$obj}{object}->{object_name} )
              if $main::Debug{occupancy};
            if ( $self->{room_counts}
                and ( $$self{m_objects}{$obj}{count} >= 1 ) )
            {
                $$self{m_objects}{$obj}{count} += $dec_count;
            }
            else {
                $$self{m_objects}{$obj}{count} = $dec_count;
            }
            unless ( $$self{m_objects}{$obj}{count} >= 1 ) {

                # Make sure at least one person is now present
                $$self{m_objects}{$obj}{count} = 1;
            }
            $$self{m_objects}{$obj}{time} = $::Time;
        }
    }
    return 1;
}

sub calc_total {
    my ($self) = @_;

    my $l_Index = 0;
    my $l_Ubound;
    my @l_NodePool;

    $l_Ubound = @{ $$self{m_object_log} };

    #Seed the node pool before the search
    if ( $l_Ubound > 0 ) {
        push @l_NodePool,
          @{ $$self{m_objects}{ $$self{m_object_log}->[0] }{edges} };
    }
    else {    # bail out if object is not found
        return 0;
    }

    for ( $l_Index = 0; $l_Index < $l_Ubound - 1; $l_Index++ ) {
        if (
            $self->compare_array_elements(
                \@l_NodePool,
                \@{
                    $$self{m_objects}{ $$self{m_object_log}->[ $l_Index + 1 ] }
                      {edges}
                }
            ) > 0
          )
        {
            return $l_Index + 1;
        }

        #add previous edges together to search all
        push @l_NodePool,
          @{ $$self{m_objects}{ $$self{m_object_log}->[ $l_Index + 1 ] }{edges}
          };

    }
    return $l_Index + 1;
}

sub people {
    my ($self) = @_;
    return $$self{m_people};
}

sub min_count {
    my ($self) = @_;
    return $$self{m_min_count};
}

sub cur_count {
    my ($self) = @_;
    return $$self{m_cur_count};
}

sub sensor_count {
    my ( $self, $p_obj, $p_count ) = @_;
    if ( defined $p_count ) {
        if ( $$self{m_objects}{$p_obj}{count} > $p_count ) {
            $$self{m_objects}{$p_obj}{last_decrease} = $::Time;
        }
        $$self{m_objects}{$p_obj}{count} = $p_count;

        # Jason: I'm not sure what should be done here to maintain
        # the integrity of the event log... at the very least, when
        # the count is set to 0, the top entry better not be the same
        # room otherwise occupancy can not be re-obtained
        if ( $p_count == 0 ) {

            # Remove matching log entry (only top one or all entries?)
            if ( $$self{m_object_log}->[0] and $$self{m_objects}{$p_obj} ) {
                if (
                    $self->compare_array(
                        \@{
                            $$self{m_objects}{ $$self{m_object_log}->[0] }
                              {edges}
                        },
                        \@{ $$self{m_objects}{$p_obj}{edges} }
                    )
                  )
                {
                    shift @{ $$self{m_object_log} };
                }
            }
        }
        elsif ( $p_count > 1 ) {

            # Call add_log like normal
            $self->add_log($p_obj);
        }
    }
    return $$self{m_objects}{$p_obj}{count};
}

sub list_presence_string {
    my ($self) = @_;

    my @sensor_names;
    my $l_tmp;
    my $l_time;

    foreach my $obj ( keys %{ $$self{m_objects} } ) {
        if ( $$self{m_objects}{$obj}{count} >= 1 ) {
            $l_tmp  = $$self{m_objects}{$obj}{object}->{object_name};
            $l_time = $::Time - $$self{m_objects}{$obj}{time};
            $l_tmp =~ s/\$//;
            $l_tmp =~ s/_/ /g;
            push @sensor_names, $l_tmp . " $l_time seconds, ";
        }
    }
    return "@sensor_names";
}

sub compare_array # compare arrays to see if all elements are present in the other
{
    my ( $self, $p_ary1, $p_ary2 ) = @_[ 0, 1, 2 ];

    # This is less code... but is it more efficient?  I'm not sure...
    # but it works now that the arrays are sorted
    return ( "@{$p_ary1}" eq "@{$p_ary2}" );

    my @l_ary1;
    my @l_ary2;

    my $l_match = 0;

    @l_ary1 = @{$p_ary1};
    @l_ary2 = @{$p_ary2};

    if ( @l_ary1 != @l_ary2 )
    { #if the number of elements doesnt match then they are obviously not the same
        return 0;
    }

    #	&::print_log( "CmpA: @l_ary1 : @l_ary2");
    foreach my $item1 ( @{$p_ary2} ) {
        $l_match = 0;
        foreach my $item2 ( @{$p_ary1} ) {
            if ( $item1 == $item2 ) {
                $l_match = 1;
            }
        }
        if ( $l_match ne 1 )
        {    #didnt find an element in the other then bail out, dont match
            return 0;
        }
    }
    return 1;
}

sub compare_array_elements #find any array elements in any elements of other array
{
    my ( $self, $p_ary1, $p_ary2 ) = @_[ 0, 1, 2 ];

    my @l_ary1;
    my @l_ary2;

    @l_ary1 = @{$p_ary1};
    @l_ary2 = @{$p_ary2};

    #	&::print_log("Cmp: @l_ary1 : @l_ary2");
    foreach my $item1 ( @{$p_ary2} ) {
        foreach my $item2 ( @{$p_ary1} ) {
            if ( $item1 == $item2 ) {
                if ( $item1 == 0 ) {
                    &::print_log(
                        "Occupancy Monitor: WARNING: Use of 0 for an edge number will cause problems"
                    );
                    return 1;
                }
                else {
                    return $item1;
                }
            }
        }
    }
    return 0;
}

sub set_extra_rooms() {
    my ( $self, $p_obj, @extras ) = @_;
    if (@extras) {
        my %rooms_seen;
        @{ $$self{m_objects}{$p_obj}{extra_rooms} } = ();
        foreach my $obj (@extras) {
            if (
                $self->compare_array(
                    \@{ $$self{m_objects}{$p_obj}{edges} },
                    \@{ $$self{m_objects}{$obj}{edges} }
                )
              )
            {
                &::print_log(
                    "Occupancy_Monitor::set_extra_rooms($p_obj->{object_name}): WARNING: ignoring $obj->{object_name} because it has the same edges (@{$$self{m_objects}{$obj}{edges}}) as $p_obj->{object_name}"
                );
            }
            else {
                if ( $rooms_seen{"@{$$self{m_objects}{$obj}{edges}}"} ) {
                    &::print_log(
                        "Occupancy_Monitor::set_extra_rooms($p_obj->{object_name}): WARNING: ignoring $obj->{object_name} because it has the same edges (@{$$self{m_objects}{$obj}{edges}}) as another extra room (rooms_seen{@{$$self{m_objects}{$obj}{edges}}})"
                    );
                }
                else {
                    $rooms_seen{"@{$$self{m_objects}{$obj}{edges}}"} =
                      $obj->{object_name};
                    push @{ $$self{m_objects}{$p_obj}{extra_rooms} }, $obj;
                }
            }
        }
    }
    return @{ $$self{m_objects}{$p_obj}{extra_rooms} };
}

sub door_restriction {
    my ( $self, $door_obj, $edge, $seconds ) = @_;
    $$self{door_edges}{$edge}{object}  = $door_obj;
    $$self{door_edges}{$edge}{seconds} = $seconds;
}

sub max_occupancy {
    my ( $self, $p_max ) = @_;
    $$self{m_max_occupancy} = $p_max if defined $p_max;
    return $$self{m_max_occupancy};
}

sub expected_occupancy {
    my ( $self, $p_expected, $p_time ) = @_;
    if ( defined $p_expected ) {
        &::print_log("Expected occupancy reset to $p_expected")
          if $main::Debug{occupancy};
        $$self{m_expected_occupancy_last_time} = 0;
        $$self{m_expected_occupancy}           = $p_expected;
        $self->reduce_occupancy_count($p_expected);

        # Reset minimum count
        $$self{m_min_count} = 0;
    }
    $$self{m_expected_occupancy_time} = $p_time if defined $p_time;
    return $$self{m_expected_occupancy};
}

sub ignore_time {
    my ( $self, $p_obj, $p_time ) = @_;
    $$self{m_objects}{$p_obj}{m_ignore_time} = $p_time if defined $p_time;
    return $$self{m_objects}{$p_obj}{m_ignore_time};
}

sub presence_move_time {
    my ( $self, $p_obj, $p_time ) = @_;
    unless ( ref $$self{m_objects}{$p_obj}{edges} ) {
        &::print_log(
            "Occupancy_Monitor::presence_move_time ERROR: object $$p_obj{object_name} has no edges defined"
        );
        return undef;
    }
    my @array = @{ $$self{m_objects}{$p_obj}{edges} };
    $$self{m_timing}{"@array"}{move_time} = $p_time if defined $p_time;
    return $$self{m_timing}{"@array"}{move_time};
}

sub set_edges {
    my ( $self, $p_obj, @edges ) = @_;
    if (@edges) {
        unless ( $$self{m_objects}{$p_obj} ) {
            $self->add_item($p_obj);
        }
        @{ $$self{m_objects}{$p_obj}{edges} } = ( sort { $a <=> $b } @edges );
    }
    return @{ $$self{m_objects}{$p_obj}{edges} };
}

sub no_new_presence {
    my ( $self, $p_obj ) = @_;
    $$self{m_objects}{$p_obj}{m_no_new_presence} = 1;
}

sub maintain_presence {
    my ( $self, $p_obj, $p_time ) = @_;
    $$self{m_objects}{$p_obj}{m_maintain} = $p_time if defined $p_time;
    return $$self{m_objects}{$p_obj}{m_maintain};
}

sub room_counts {
    my ( $self, $val ) = @_;
    $$self{room_counts} = $val if defined $val;
    return $$self{room_counts};
}

sub writable {
    return 0;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee  jason@sharpee.com

Special Thanks to:  Bruce Winter - MH

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

