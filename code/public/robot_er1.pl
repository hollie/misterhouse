
=begin comment

This is a code for the evolution robotics ER1 robot.  The robot has visual and speech recognition and can do lots - o 
cool stuff. the software that comes with ER1 is very good at getting you up and running but soon falls short. 
The Robot Control Software, RCC(not ersp), provides for API interface and I have taken advantage of a misterhouse socket item.

strabo is a piece of software that is used for pathfinding, you give it a map of your home, tell it where you are and it
will tell you how to get form A to B. very cool. this code does the strabo calls. you just tell it the waypoint and of it goes.

this code file is the base layer.  anything that can be sent or recieved from the er1 api can be done from misterhouse.
in addition to handeling the data transfer, this code puts various info into ER1_Items that are stored in misterhouse for
later use/processing.  all of the commands to send the data are made for you.  
In addition to providing the interface between misterhouse and er1, this code has some built in basic checks.  if you try
to send a command to er1 and it is not connected to misterhouse, this code will connect for you.  if the connection is
lost it will try to reconnect.  also some basic prerequesite check are done to ensure the necessary things are set before
subs are executed or it will return error message with some clue as to where to start.
There are also a few examples of how to build your own webpages to look however you want.  ER1 will announce callerid if 
you have it setup in misterhouse.  you can use the standard mh webpages to control your robot.
I reccommend that you make an additional file with you own 'actions and conditions' for your er1.  my_er1.pl.  examples 
to follow.

list of included error checking:
 don't accept move if already moving
 don't accept play/speak if already playing a wav file or speaking
 if connection set and not present try to reconnect, then fail with error message
 if strabo called and misterhouse can't find, return error message
 if strabo called with undef parms, return error message
 if waypoint sent to strabo that does not exist, return error message
 if strabo not running, warn user
 if RCC not running, warn user
 if you send data to er1 with out connection established, connect then send.
 if can't find sound files keep old files and warn. same for waypoints and visual objects


ini parms and setup: #####!!!!!!! explain these
 er1_ip = ip address that Robot Control Center is running on (ex. 192.168.1.102).
 er1_port = port that you have RCC api set to in Settings->Remote control tab->allow api control of this instance (ex. 9000).
 er1_sound_dir = location of er1 files (relative to MH machine, ex  Z:/progra~1/er1/sounds).
 er1_objects_dir = location of er1 visual recognition objects. (ex Z:/progra~1/er1/objects).
 strabo_ip = ip address of computer that Strabo is running on.
 strabo_port = port that you have strabo set to.
 strabo_home_x, strabo_home_y = home position on strabo map. this with where you will start er1 and reset its x,y to zero.
 strabo_units = one block on strabo grid in inches (ex. 12, for each block in grid to equal 1 square foot. that would make each unit on strabo equal to 2.4 inches).
 colors = rgb for user defined colors, used in rotate/drive toward color.  (ex. color1 0 255 255, couch 1 50 50, red 255 0 0)

items:
 $er1client		this sends and recievs data from er1
 $er1_checkangle	holds angle from checkangle routine - if er1 moves some distance it does some trig to figure out what angle it was pointed in
 $digital_input_#	numbered 1-8	stores digtal input
 $digital_out_#  	numbered 1-8    stores what dig out pin set to
 $soundlevel		sound level that er1 hears
 $speech_text		set to what er1 voice recognition heard
 $er1_object		what object er1 sees
 $features_matched	number of features recognition object
 $total_features	total features for that object 
 $object_x		location of recognized object
 $object_y
 $object_distance	distance of recognized object in cm
 $coordinates_x		coordinates reported by er1 in cm
 $coordinates_y
 $analog_input_# 	numbered 1-16  	# analog input, see manual for pinout
 $battery_level    	this is the same as $analog input 16 to make percent
 $er1_moving		flag used so that new move commands not excuted if already moving
 $er1_playing		flag for speaking, playing wav file so that new sound not done if alreading making one.
 $er1_direction      	used to store current direction er1 is pointing in. different than measured angle stored in checkangle
 $er1_move 		state can be n,s,e,w or distance in inches. whatever this is set to gets sent to move sub
 $ER1_speak   		holds text to speak. if set er1 will speak
 $er1_stop_distance	used for drive towards object
 $er1_stop_percentage	used for drive towards color
 $er1_turn		if set er1 will turn
 $er1_collision_sensitivity
 $er1_ob_avoid_method		color,intensity
 $er1_ob_avoid_tolerance	0-100
 $er1_ob_avoid_disable_dis	cm
 $er1_ob_avoid_disable_percent	0-100
 $strabo_x		holds strabo coordinates between restarts. set by position data from er1
 $strabo_y


	examples;
		set $ER1_speak "I feel good";
		set $er1_move '-6';

commands:

ex.	set $v_er1_wav "r2d2.wav";




$v_er1_connection	this opens a socet between er1 and misterhouse.  set to [connect,disconnect], when set
			to connect, this starts up er1 connection and restores all parms that you had "save" in 
			varoius objects. ie starts "sence objects" if you have it set.....   then starts listen for
			incomming data from er1.

$v_move_er1client	this is just some test moves, really to show you how to do it.  you could changes the states of
			this item, but more useful to use $er1_move and $er1_turn


$v_er1_rotate_toward	rotate toward object.  objects are stored by er1 in ini file.  this command will list these objects
			more on this later

$v_er1_drive_toward	will drive toward an object and stop at distance set in stop distance


$v_er1_rotate_color	colors stored in config parms created by this file, see above for instructions

$v_er1_drive_color	""


$v_position_er1client	this get position from er1, when "move done" this executes.  in the handle data the position
			is stored and strabo is updated

$v_er1_stop		tell er1 to stop moving and stop playing wav file or speaking. also empties @moves array


$v_strabo_path		gets path from strabo to selected waypoint. this data is parced and put into a @moves array.  
			if the @moves array has elements they are chomped off one at a time and sent to er1.  when move
			done it chomps off next one

$v_er1_wav		plays wav file that are stored on er1 in sound dir

$v_er1_input_analog	this tells er1 to return analog data.  this data is parsed and put into analog objects

$v_er1_input_analog	same for digital

$v_er1_digital_out_1	8 of these, sets digital output high or low.  send all eight at one time, so states are stored, then
			collected and all are sent at once if this item changes


$v_er1_stop_distance	this set the stop distance item state.  this state is sent to er1 when 'drive toward' done

$v_er1_stop_percentage	same for color

$v_er1_collision_sensitivity 	when er1 motor current goes up, it thinks it has run into something.  set this to adjust

$v_er1_collision_detection	this can be on or off

$v_er1_angular_velocity		angular velocity

$v_er1_linear_velocity		linear velocity

$v_er1_power_stopped		power supplied to motors when stopped in percent

$v_er1_power_moving		" when moving

$v_er1_ob_avoid_method		obstacle avoidance method can be color or intensity

$v_er1_ob_avoid_tolerance	0-100

$v_er1_ob_avoid_disable_dis	disable distance

$v_er1_ob_avoid_disable_percent 	disable percent

$v_er1_ob_avoidance		[on,off] when set to on, gathers up all obstacle avoidance parms and send them all at once

$v_er1_recognition_threshold	set to %, for object recognition

$v_er1_color_tolerance		color recognition

$v_er1_color_percent

$v_er1_voice			[Microsoft Mary,Microsoft Mike,Microsoft Sam]


$v_er1_sence_objects 		[on,off] set if executed and stored for next er1 startup

$v_er1_sence_sound		"

$v_er1_sence_speech		"


$v_strabo_refresh_waypoints	waypoints are made in strabo map. this gets them from strabo and updates if necessary
				if they change misterhouse reload, as voice commands are made on startup

$v_er1_refresh_sounds		"

$v_er1_refresh_objects		"



web:
here is some examples of how to make you own web pages that control er1 with html: more examples in "customizing the web interface" of mh docs

<!--#include code="&html_item('v_er1_connection')"-->      'need to have v 2.95 for &html_item'
<!--#include code="&html_item('battery_level')"-->
<!--#include code="get_er1_state('$er1_moving')"-->
<!--#include code="get_er1_state('$coordinates_x')"-->
<a href="http://localhost:8080/SET;no_response?$v_position_er1client?position">update position</a>
<!--#include code="&html_item('v_strabo_path')"-->
<!--#include code="get_er1_state('$analog_input_1')"-->
<!--#include code="&html_item('v_er1_wav')"-->
these are cool, you can just type in what you want er1 to say, or how to move
<form action="http://localhost:8080/SET;no_response">move <input size=4 name="$er1_move"> inches</form>
<form action="http://localhost:8080/SUB;no_response">turn <input size=4 name="$er1_turn"> degrees</form>
<form action="http://localhost:8080/SET;no_response"><input type="text" name="$ER1_speak" size="41"><input type="submit" value="Speak"><input type="reset" value="Reset"></form>

plans:
 develop more complex behavior that are common. these would be behaviors that are independant of enviornment
 so that they could be included here for all to use if they want. examples would include things like:
	dance
	tell a joke
	say some random smarta$$ comment
	tell me the weather



stumbling blocks:
 checkagle now done, but needs thorough testing.  if turn issued with er1_turn direction not reset.
 the plan is to use checkangle to set direction.

 navigation by the er1 is done with deadreconing.  dead reaconing is keeping track of what moves you make and 
 therefor where you should be.  this is a great method as long as one stops to find an occasional fix.  currently
 i have not implemented any way of doing this.  if the er1 "drifts" over time the position will become less and less
 accurate.  you could have the er1 navigate back to some home position and perhaps use misterhouse to send keystrokes to rcc
 to reset position.  the api has no way (that i know of) to do this.  there is also the posibility of using multiple
 stationary visual objects and getting angles from the er1 to tringulate a fix.  another possibility is to make another
 interface to the 'brainstem' and add a compass to the er1.  this would greatly ease navigation.
 if one had a compass and had misterhouse keep track of position instead of er1, i could stop the backwars upsidown strabo
 thing   




 I am a NEeeeeeeWBIE, and I am sure that this could be written better, 

 
 my name is Dave Hall w_hall01@comcast.net
 Bruce (mh) and Davee (Strabo) you guys rule
 version 6, the date is 10/5/04
#############################################
 to do list

 to be tested
	test color drive
	checkangle: done, need to test
	strabo getpath x,y error handeling if not set - done needs tested
	test caller id
	error handeling if bad waypoint - done, not tested.  left er1 error reporting for sounds,objects
	need to test digital inputs

 navigation
	do more testing and figure out if I should recalc path after each step in move, when i say move 6 inches it moves precicly 5.15 inches, tried upping power -> same, turns are little less than 90, precise
	? goto object command
 	maybe a calibrate routine to adjust motion to what er1 actually does
	need to handel non n.s.e.w moves with @moves so can create move macros with smaller turn

 sound
 	need play queue, maybe
	need a way to control volume

 interface/config stuff
	process item
	need to put in some examples of how to code events
	need to clean up what happens if rcc not online and connection set
 	maybe a tie_filter to check if necessary connection available, with strabo, rcc
 	may need config pram for strabo map if want it to be able to change map
 	maybe return webpage for setup instead of ini parms. then save setup to file. dbm file
	&net_ping($host) to check if computer available

 i/o
	may need some way to set initial digout state if not set, ie, first time startup


changed in version 6
 added error check to strabo routine, if you ask for a waypoint that does not exist on current may, it will tell you
 added move rotate toward color
 added move drive toward color
 made object for strabo position.  this allows it to store strabo x,y betwen reloads.  I thinks people have been calling strabo get path without any x,y.  this should fix
 pulled out get sounds,waypoints,objects from startup routine.  these should not change all that often, now you have to go get them if they do.
 fixed problem where callerid had to be commented out before clean start.  now it enables if you have it setup
 fixed more strabo problems that were created in version 5, thanks Ron, for helping me find them.
 added 'use math::trig' so checkangle would work
 added connect check. each time data is sent to er1, it checks for connection 1st. if not, starts it. will also restart connection if set and lost, this way you can continue to listen for incomming data
 added collision detection
 added collision detection sensitivity
 finished digout sub
 colors in config parms, no action yet - maybe if reload, make color command.  since voice commands made on startup.  don't need to check file and restart each time. hash probably way to go that way could send value for key in voice command.
 emptied move queue if stop issued - before it would quit current move and start next one.
 fixed strabo problem created in version 5
 added strabo check in get_strabo_path sub
 added strabo check in strabo position call
 added lots of little print_log things so problems would be easier for us to track down
 added confidence threshold
 added obstacle avoidance commands
 added color tolerance
 added color percentage
 changed startup sub to initialize all parms that can be set.  this way settings will be saved and returned between starts.


changed in version 5
completly redone.  learned how to use sub and pass variables and updated code.  i am sure some of you will be pleased not to
 have to read that garb that was version 4.
 added subs to return data to web pages
 added er1 callerid, should probably fix so only enabled if callerid enabled
 made new "class" of items - er1 item. item is no different that generic item, but now er1 data listed on its own page in mh
 added er1_turn
 added er1_speak
 added er1_playing "flag", so would not try to play/speak if already playing something.
 added stop command
 added set voice
 added get visual recognition objects
 added set angular velocity
 added set linear velocity
 added set power stopped
 added set power moving
 added rotate toward object
 added stop distance
 added stop percentage - this will be use for drive toward color which is not done yet
 added drive towards object

changed in version 4
fixed problem where strabo coordinates were not reliably updated after move done by just passing data directly instead of from state change of er1 coordinates. I think the problems was new state was not updated by the time the code ran...???, works
added 'get er1 wav files' in startup routine and play wav function, also ini parm for sound dir(note: you put the sound files where you always did for er1, you just have to tell mh where that is, in case mh on a diff maching)
added er1 battery level from analog inputs
added analog inputs - works, got digital inputs but not tested, started on dig out stuff - not yet done
	Warning, this code decideds if data returned from er1 is dig or analog based on number of items returned.  it is possible to tell er1 to give you data which could fool this.  ie.. if you asked for objects and there were the same number as analog inputs this code would get confused.
added a checkangle routine that computes er1 angle after a forward move with some basic trig, needs some testing

changed in version 3
fixed problem of config parms not being defined on initial startup by putting default that get overriden if a config parm exist
added connect to disconnect voice command so er1 does not automatically restart when code reloads.  this saves time when continually reloading code to check changes and gives the ability to do in the web,tk interface, can also add conditions later, like, if new move and not connected then connect then do move
made starup routine to ensure that rcc running, and remind user if not, did same for strabo
moved strabo waypoint get to startup sub and fixed the problem with have to reload code manually.  it now takes care of it for you
cleaned up stuff for tk. looks better on web interface

changed  in version 2.
 commented out TK stuff and put it in another file
 got rid of some print and stuff i used for debugging
 added some stuff to get strabo waypoints automatically on startup, for now shutdown and reload mh twice for mh to reciginize new waypoints, I know ...it's a pain
	this has a few pseudo-bugs. strabo has to be running to deliever waypoint otherwise waypoints with be empty []
 added some config parms for er1client so you don't have to modify the code just change it with parm editor. howto below under #config parms#
 added config parms for strabo client
 added config parms for strabo home position
 added config parm for strabo units, this is the number of inches for each block in strabo grid, each block is 5x5 little blocks
	If you want each block in the grid to be 1 square foot, then strabo units would be 12.  this would make each little block 2.4 inches

=cut

######################################################################################################

# Category=ER1

#@code for running ER1 robot from evolution robotics using api calls.  Also uses strabo software for pathfinding and waypoint navigation.

####################  config parms ##########################
# this is where i define all of the configuration parms for misterhose
# !!!!!!!!!!!   don't edit them here !!!!!!!!!!!!!
# use browser to point to localhost:8080 on misterhouse machine
#	click MrHouse Home
#	Click Setup MrHouse
#	Click user code activation  (here you will see instructions on what you should enter in the descripton of er1robot.pl)
#	Click EDIT under er1robot.pl
#
#@ CONFIG PARMS:
#@ er1_ip = ip address that Robot Control Center is running on (ex. 192.168.1.102).
#@ er1_port = port that you have RCC api set to in Settings->Remote control tab->allow api control of this instance (ex. 9000).
#@ er1_sound_dir = location of er1 files (relative to MH machine, ex  Z:/progra~1/er1/sounds).
#@ er1_objects_dir = location of er1 visual recognition objects. (ex Z:/progra~1/er1/objects).
#@ strabo_ip = ip address of computer that Strabo is running on.
#@ strabo_port = port that you have strabo set to.
#@ strabo_home_x, strabo_home_y = home position on strabo map. this with where you will start er1 and reset its x,y to zero.
#@ strabo_units = one block on strabo grid in inches (ex. 12, for each block in grid to equal 1 square foot. that would make each unit on strabo equal to 2.4 inches).
#@ colors = rgb for user defined colors, used in rotate/drive toward color.  (ex. color1 0 255 255, couch 1 50 50, red 255 0 0)
##############################################################

# noloop=start      This directive allows this code to be run on startup/reload of misterhouse

my $er1_ip = 'localhost';
$er1_ip = $config_parms{er1_ip} if ( $config_parms{er1_ip} );
my $er1_port = 9000;
$er1_port = $config_parms{er1_port} if ( $config_parms{er1_port} );
my $er1client_address = "$er1_ip" . ":" . "$er1_port";    #'192.168.1.102:9000';
my $er1_sound_dir     = 'Z:/progra~1/er1/sounds';
$er1_sound_dir = $config_parms{er1_sound_dir}
  if ( $config_parms{er1_sound_dir} );
my $er1_objects_dir = 'Z:/progra~1/er1/objects';
$er1_objects_dir = $config_parms{er1_objects_dir}
  if ( $config_parms{er1_objects_dir} );
my $strabo_ip = 'localhost';
$strabo_ip = $config_parms{strabo_ip} if ( $config_parms{strabo_ip} );
my $strabo_port = 80;
$strabo_port = $config_parms{strabo_port} if ( $config_parms{strabo_port} );
my $strabo_home_x = 16;
$strabo_home_x = $config_parms{strabo_home_x}
  if ( $config_parms{strabo_home_x} );
my $strabo_home_y = 6;
$strabo_home_y = $config_parms{strabo_home_y}
  if ( $config_parms{strabo_home_y} );
my $strabo_units = 12;
$strabo_units = $config_parms{strabo_units} if ( $config_parms{strabo_units} );
my $er1_colors;
$er1_colors = $config_parms{er1_colors} if ( $config_parms{er1_colors} );

@ER1_Item::ISA = ('Generic_Item');

# @ER1_Analog_Item::ISA = ('ER1_Item');  #use this if going to subdivide items

#get colors from ini data
my @colors;
my @col;
my %colors;
my $colors;
my $color;
@colors = split( /,/, $er1_colors );    #each element should have (color 4 4 4)
foreach $colors (@colors) {
    @col = split( / /, $colors );
    $colors{"$col[0]"} = "$col[1] $col[2] $col[3]";

}
@colors = keys %colors;
$colors = join( ',', @colors );

# noloop=stop

use Math::Trig;

my @moves
  ; #this is set by strabo path call. used to hold values of @dir and @dis in order that the should be executed.... s,4,n,6....

set $er1_moving 'stopped' if ($Reread);
set $er1_direction 360
  if ($Reread)
  ; #not always true but gets me started   !!!!!!! need more work here!!!!!!! maybe put initial dir in ini
set $er1_playing 'stopped' if ($Reread);

###############    items    #############

$er1client           = new Socket_Item( undef, undef, $er1client_address );
$er1_checkangle      = new ER1_Item;
$digital_input_1     = new ER1_Item;
$digital_input_2     = new ER1_Item;
$digital_input_3     = new ER1_Item;
$digital_input_4     = new ER1_Item;
$digital_input_5     = new ER1_Item;
$digital_input_6     = new ER1_Item;
$digital_input_7     = new ER1_Item;
$digital_input_8     = new ER1_Item;
$digital_out_1       = new ER1_Item;
$digital_out_2       = new ER1_Item;
$digital_out_3       = new ER1_Item;
$digital_out_4       = new ER1_Item;
$digital_out_5       = new ER1_Item;
$digital_out_6       = new ER1_Item;
$digital_out_7       = new ER1_Item;
$digital_out_8       = new ER1_Item;
$soundlevel          = new ER1_Item;
$speech_text         = new ER1_Item;
$er1_object          = new ER1_Item;
$features_matched    = new ER1_Item;
$total_features      = new ER1_Item;
$object_x            = new ER1_Item;
$object_y            = new ER1_Item;
$object_distance     = new ER1_Item;
$coordinates_x       = new ER1_Item;
$coordinates_y       = new ER1_Item;
$analog_input_1      = new ER1_Item;
$analog_input_2      = new ER1_Item;
$analog_input_3      = new ER1_Item;
$analog_input_4      = new ER1_Item;
$analog_input_5      = new ER1_Item;
$analog_input_6      = new ER1_Item;
$analog_input_7      = new ER1_Item;
$analog_input_8      = new ER1_Item;
$analog_input_9      = new ER1_Item;
$analog_input_10     = new ER1_Item;
$analog_input_11     = new ER1_Item;
$analog_input_12     = new ER1_Item;
$analog_input_13     = new ER1_Item;
$analog_input_14     = new ER1_Item;
$analog_input_15     = new ER1_Item;
$analog_input_16     = new ER1_Item;
$battery_level       = new ER1_Item;
$er1_moving          = new ER1_Item;
$er1_playing         = new ER1_Item;
$er1_direction       = new ER1_Item;
$er1_move            = new ER1_Item;
$ER1_speak           = new ER1_Item;
$er1_stop_distance   = new ER1_Item;
$er1_stop_percentage = new ER1_Item;
$er1_turn            = new ER1_Item;
$er1_collision_sensitivity    = new ER1_Item;
$er1_ob_avoid_method          = new ER1_Item;
$er1_ob_avoid_tolerance       = new ER1_Item;
$er1_ob_avoid_disable_dis     = new ER1_Item;
$er1_ob_avoid_disable_percent = new ER1_Item;
$strabo_x                     = new ER1_Item;
$strabo_y                     = new ER1_Item;

#########     commands    ###########

#disconnect/connect
$v_er1_connection = new Voice_Cmd("[connect,disconnect] Er1");
set_icon $v_er1_connection 'er1';
if ( $state = said $v_er1_connection) {
    if ( $state eq 'disconnect' ) {
        print_log "Disconnecting from ER1";
        stop $er1client;
    }
    elsif ( $state eq 'connect' ) {
        &er1_startup();
    }
}
if ( $state = state $v_er1_connection)
{ #this will run every loop, if er1 is supposed to be connected and not, it will connect
    if ( $state eq 'connect' ) {    #is er1 supposed to be connected?
        &er1_startup()
          if ( !$main::Socket_Ports{$er1client_address}{sock} )
          ;                         #reconnect if not
    }
}

## navigation

#test moves
$v_move_er1client = new Voice_Cmd(
    "move: [forward 6 inches,forward 6 feet,backward 6 inches,backward 6 feet,turn left,turn left 45,turn right]"
);
if ( $state = said $v_move_er1client) {
    print_log "Running $state";
    send_er1_data('move 6 i')   if ( $state eq 'forward 6 inches' );
    send_er1_data('move 6 f')   if ( $state eq 'forward 6 feet' );
    send_er1_data('move -6 i')  if ( $state eq 'backward 6 inches' );
    send_er1_data('move -6 f')  if ( $state eq 'backward 6 feet' );
    send_er1_data('move 90 d')  if ( $state eq 'turn left' );
    send_er1_data('move 45 d')  if ( $state eq 'turn left 45' );
    send_er1_data('move -90 d') if ( $state eq 'turn right' );
}

$v_er1_rotate_toward = new Voice_Cmd("rotate toward: [$Save{er1_objects}]");

#!!!!!need to add contengency for what to do if er1 does not see object
if ( $state = said $v_er1_rotate_toward) {
    if ( state $er1_moving eq "moving" ) {
        print_log "er1 is busy moving";
        return;
    }
    if ( state $er1_moving eq "stopped" ) {
        print_log "rotating toward $state";
        set $er1_moving "moving";
        send_er1_data( 'move rotate toward object "' . $state . '"' );
    }
}

$v_er1_drive_toward = new Voice_Cmd("drive toward: [$Save{er1_objects}]");

#need to add contengency for what to do if er1 does not see object
if ( $state = said $v_er1_drive_toward) {
    if ( state $er1_moving eq "moving" ) {
        print_log "er1 is busy moving";
        return;
    }
    if ( state $er1_moving eq "stopped" ) {
        my $stop = state $er1_stop_distance;
        print_log "driving toward $state";
        set $er1_moving "moving";
        send_er1_data(
            'move drive toward object "' . $state . '" stop ' . $stop . ' in' );
    }
}

$v_er1_rotate_color = new Voice_Cmd("rotate toward color: [$colors]");

#!!!!!need to add contengency for what to do if er1 does not see color
if ( $state = said $v_er1_rotate_color) {
    if ( state $er1_moving eq "moving" ) {
        print_log "er1 is busy moving";
        return;
    }
    if ( state $er1_moving eq "stopped" ) {
        print_log "rotating toward $state";
        set $er1_moving "moving";
        send_er1_data("move rotate toward color $colors{$state}");
    }
}

$v_er1_drive_color = new Voice_Cmd("drive toward color: [$colors]");

#need to add contengency for what to do if er1 does not see color
if ( $state = said $v_er1_drive_color) {
    if ( state $er1_moving eq "moving" ) {
        print_log "er1 is busy moving";
        return;
    }
    if ( state $er1_moving eq "stopped" ) {
        my $stop = state $er1_stop_percentage;
        print_log "driving toward $state";
        set $er1_moving "moving";
        send_er1_data(
            "move drive toward color $colors{$state} stop $er1_stop_percentage"
        );
    }
}

#get position, results put into coordinates when listening for events, mh automatically updates position for itself and strabo when "move done" recieved
$v_position_er1client = new Voice_Cmd("get: [position]");
set_icon $v_position_er1client 'er1';
if ( $state = said $v_position_er1client) {
    print_log "Running $state";
    send_er1_data('position') if ( $state eq 'position' );
}

$v_er1_stop = new Voice_Cmd("[stop] and hush");
if ( $state = said $v_er1_stop) {
    @moves = ();
    send_er1_data("stop") if ( $state eq 'stop' );
    set $er1_moving 'stopped';
    set $er1_playing 'stopped';
}

$v_strabo_path = new Voice_Cmd("goto: [$Save{waypoints}]");
&get_strabo_path("$state") if ( $state = said $v_strabo_path);

## sound

#play wav files
$v_er1_wav = new Voice_Cmd("play: [$Save{er1_sounds}]");
set_icon $v_er1_wav 'er1-play';
if ( $state = said $v_er1_wav) {
    my $er1_sound = "sounds\\" . $state;
    if ( state $er1_playing eq "playing" ) {
        print_log "er1 is busy playing a sound";
        return;
    }
    if ( state $er1_playing eq "stopped" ) {
        print_log "playing $state";
        set $er1_playing "playing";
        send_er1_data( 'play file "' . $er1_sound . '"' );
    }
}

## i/o

$v_er1_input_analog = new Voice_Cmd("get: [analog] inputs");
if ( $state = said $v_er1_input_analog) {
    send_er1_data('input analog');    # if ($state eq 'analog');
}
$v_er1_input_digital = new Voice_Cmd("get: [digital] inputs");
if ( $state = said $v_er1_input_digital) {
    send_er1_data('input digital') if ( $state eq 'digital' );
}

$v_er1_digital_out_1 = new Voice_Cmd("set digital output 1 [On,Off]");
if ( $state = said $v_er1_digital_out_1) {
    set $digital_out_1 $state;
    &digout();
}
$v_er1_digital_out_2 = new Voice_Cmd("set digital output 2 [On,Off]");
if ( $state = said $v_er1_digital_out_2) {
    set $digital_out_2 $state;
    &digout();
}
$v_er1_digital_out_3 = new Voice_Cmd("set digital output 3 [On,Off]");
if ( $state = said $v_er1_digital_out_3) {
    set $digital_out_3 $state;
    &digout();
}
$v_er1_digital_out_4 = new Voice_Cmd("set digital output 4 [On,Off]");
if ( $state = said $v_er1_digital_out_4) {
    set $digital_out_4 $state;
    &digout();
}
$v_er1_digital_out_5 = new Voice_Cmd("set digital output 5 [On,Off]");
if ( $state = said $v_er1_digital_out_5) {
    set $digital_out_5 $state;
    &digout();
}
$v_er1_digital_out_6 = new Voice_Cmd("set digital output 6 [On,Off]");
if ( $state = said $v_er1_digital_out_6) {
    set $digital_out_6 $state;
    &digout();
}
$v_er1_digital_out_7 = new Voice_Cmd("set digital output 7 [On,Off]");
if ( $state = said $v_er1_digital_out_7) {
    set $digital_out_7 $state;
    &digout();
}
$v_er1_digital_out_8 = new Voice_Cmd("set digital output 8 [On,Off]");
if ( $state = said $v_er1_digital_out_8) {
    set $digital_out_8 $state;
    &digout();
}

## config

$v_er1_stop_distance =
  new Voice_Cmd("set stop distance [2,4,8,12,16,20,24,36] inches");
if ( $state = said $v_er1_stop_distance) {
    set $er1_stop_distance $state;
}

$v_er1_stop_percentage =
  new Voice_Cmd("set stop percentage [10,20,30,40,50,60,70,80,90,100] %");
if ( $state = said $v_er1_stop_percentage) {
    set $er1_stop_percentage $state;
}

$v_er1_collision_sensitivity =
  new Voice_Cmd("set collision sensitivity [10,20,30,40,50,60,70,80,90,100]");
if ( $state = said $v_er1_collision_sensitivity) {
    set $er1_collision_sensitivity $state;
}

$v_er1_collision_detection = new Voice_Cmd("set collision dectection [ON,OFF]");
if ( $state = said $v_er1_collision_detection) {
    if ( $state eq 'OFF' ) {
        send_er1_data("set collision detection off");
    }
    if ( $state eq 'ON' ) {
        my $sensitivity;
        $sensitivity = state $er1_collision_sensitivity;
        send_er1_data("set collision detection on sensitivity $sensitivity");
    }
}

$v_er1_angular_velocity =
  new Voice_Cmd("set angular velocity: [5,10,20,30,45] degrees/sec");
set_web_style $v_er1_angular_velocity 'dropdown';
if ( $state = said $v_er1_angular_velocity) {
    send_er1_data("set angular velocity $state");
}

$v_er1_linear_velocity =
  new Voice_Cmd("set linear velocity: [5,10,20,30,40,50] cm/sec");
set_web_style $v_er1_linear_velocity 'dropdown';
if ( $state = said $v_er1_linear_velocity) {
    send_er1_data("set linear velocity $state");
}

$v_er1_power_stopped =
  new Voice_Cmd("set power stopped: [zero,10,20,30,40,50,60,70,80,90,100] %");
set_web_style $v_er1_power_stopped 'dropdown';
if ( $state = said $v_er1_power_stopped) {
    send_er1_data("set power stopped 0") if ( $state eq "zero" );
    send_er1_data("set power stopped $state") if ( $state ne "zero" );
}

$v_er1_power_moving =
  new Voice_Cmd("set power moving: [0,10,20,30,40,50,60,70,80,90,100] %");
set_web_style $v_er1_power_moving 'dropdown';
if ( $state = said $v_er1_power_moving) {
    send_er1_data("set power moving $state");
}

$v_er1_ob_avoid_method =
  new Voice_Cmd("set advoidance method [color,intensity]");
if ( $state = said $v_er1_ob_avoid_method) {
    set $er1_ob_avoid_method $state;
}

$v_er1_ob_avoid_tolerance =
  new Voice_Cmd("set advoidance tolerance [1,10,20,40,50,60,70,80,90,100]");
if ( $state = said $v_er1_ob_avoid_tolerance) {
    set $er1_ob_avoid_tolerance $state;
}

$v_er1_ob_avoid_disable_dis = new Voice_Cmd(
    "set advoidance disable distance [4,10,20,40,50,60,70,80,90,100] cm");
if ( $state = said $v_er1_ob_avoid_disable_dis) {
    set $er1_ob_avoid_disable_dis $state;
}

$v_er1_ob_avoid_disable_percent =
  new Voice_Cmd("set advoidance disable % [1,10,20,40,50,60,70,80,90,100] %");
if ( $state = said $v_er1_ob_avoid_disable_percent) {
    set $er1_ob_avoid_disable_percent $state;
}

$v_er1_ob_avoidance = new Voice_Cmd("set obstacle avoidance [ON,OFF]");
if ( $state = said $v_er1_ob_avoidance) {
    if ( $state eq 'OFF' ) {
        send_er1_data("set obstacle avoidance off");
    }
    if ( $state eq 'ON' ) {
        my $method;
        my $tolerance;
        my $dis_dis;
        my $dis_percent;
        $method      = state $er1_ob_avoid_method;
        $tolerance   = state $er1_ob_avoid_tolerance;
        $dis_dis     = state $er1_ob_avoid_disable_dis;
        $dis_percent = state $er1_ob_avoid_disable_percent;
        send_er1_data(
            "set obstacle avoidance on tolerance $tolerance method $method disable distance $dis_dis disable percentage $dis_percent"
        );
    }
}

$v_er1_recognition_threshold =
  new Voice_Cmd("set recognition threshold [1,10,20,40,50,60,70,80,90,100] %");
send_er1_data("set confidence threshold $state")
  if ( $state = said $v_er1_recognition_threshold);

$v_er1_color_tolerance =
  new Voice_Cmd("set color tolerance [1,10,20,40,50,60,70,80,90,100]");
send_er1_data("set color tolerance $state")
  if ( $state = said $v_er1_color_tolerance);

$v_er1_color_percent =
  new Voice_Cmd("set color percent [1,10,20,40,50,60,70,80,90,100] %");
send_er1_data("set color percentage $state")
  if ( $state = said $v_er1_color_percent);

$v_er1_voice =
  new Voice_Cmd("set voice [Microsoft Mary,Microsoft Mike,Microsoft Sam]");
if ( $state = said $v_er1_voice) {
    send_er1_data( 'set voice "' . $state . '"' );
}

$v_er1_sence_objects = new Voice_Cmd("sence objects [on,off]");
send_er1_data("sence objects $state") if ( $state = said $v_er1_sence_objects);

$v_er1_sence_sound = new Voice_Cmd("sence sound level [on,off]");
send_er1_data("sence sound level $state")
  if ( $state = said $v_er1_sence_sound);

$v_er1_sence_speech = new Voice_Cmd("sence speech [on,off]");
send_er1_data("sence speech $state") if ( $state = said $v_er1_sence_speech);

$v_strabo_refresh_waypoints = new Voice_Cmd("refresh strabo [waypoints]");
get_strabo_waypoints() if ( $state = said $v_strabo_refresh_waypoints);

$v_er1_refresh_sounds = new Voice_Cmd("refresh er1 [sounds]");
get_er1_sounds() if ( $state = said $v_er1_refresh_sounds);

$v_er1_refresh_objects = new Voice_Cmd("refresh er1 visual [objects]");
get_er1_visual_objects() if ( $state = said $v_er1_refresh_objects);

##############  things that are not set by voice commands  ##################

#&ER1_speak($state) if $state = state_now $ER1_speak;  #this is a little easier to understand but format below does the same thing and is more mh-ish
$ER1_speak->tie_event('&ER1_speak($state)') if $Reload;
$er1_move->tie_event('&er1_move($state)')   if $Reload;
$er1_turn->tie_event('&er1_turn($state)')   if $Reload;
eval('$cid_item -> tie_event(\'Er1_cid($state, $object)\', \'cid\')')
  if ( $Reload && $Run_Members{'callerid'} )
  ;    #will announce callerid if you have it setup in misterhouse
&handle_er1_data($state) if $state = said $er1client;

#move if @moves has elements, maybe can move this into move sub then use tie event
if ( state $er1_moving eq 'stopped' && @moves ) {
    set $er1_moving 'moving';
    set $er1_move shift @moves;
}

###############    subs  ##############

sub er1_startup
{ #used to start all the things you need to have mh run er1, this will be called with "connect"
    print_log "starting er1";

    #check Rcc running
    if ( active $er1client) {
        print_log "already connected to ER1";
        return;
    }

    if ( start $er1client) {
        set $er1_moving 'stopped';
        set $er1_playing 'stopped';
        send_er1_data( 'set voice "' . $state . '"' )
          if ( $state = state $v_er1_voice);
        if ( $state = state $v_er1_collision_detection) {
            if ( $state eq 'OFF' ) {
                send_er1_data("set collision detection off");
            }
            if ( $state eq 'ON' ) {
                my $sensitivity;
                $sensitivity = state $er1_collision_sensitivity;
                send_er1_data(
                    "set collision detection on sensitivity $sensitivity");
            }
        }
        send_er1_data("set angular velocity $state")
          if ( $state = state $v_er1_angular_velocity);
        send_er1_data("set linear velocity $state")
          if ( $state = state $v_er1_linear_velocity);
        if ( $state = state $v_er1_power_stopped) {
            send_er1_data("set power stopped 0") if ( $state eq "zero" );
            send_er1_data("set power stopped $state") if ( $state ne "zero" );
        }
        send_er1_data("set power moving $state")
          if ( $state = state $v_er1_power_moving);
        if ( $state = state $v_er1_ob_avoidance) {
            if ( $state eq 'OFF' ) {
                send_er1_data("set obstacle avoidance off");
            }
            if ( $state eq 'ON' ) {
                my $method;
                my $tolerance;
                my $dis_dis;
                my $dis_percent;
                $method      = state $er1_ob_avoid_method;
                $tolerance   = state $er1_ob_avoid_tolerance;
                $dis_dis     = state $er1_ob_avoid_disable_dis;
                $dis_percent = state $er1_ob_avoid_disable_percent;
                send_er1_data(
                    "set obstacle avoidance on tolerance $tolerance method $method disable distance $dis_dis disable percentage $dis_percent"
                );
            }
        }
        send_er1_data("set confidence threshold $state")
          if ( $state = state $v_er1_recognition_threshold);
        send_er1_data("set color tolerance $state")
          if ( $state = state $v_er1_color_tolerance);
        send_er1_data("set color percentage $state")
          if ( $state = state $v_er1_color_percent);
        send_er1_data("sense objects $state")
          if ( $state = state $v_er1_sence_objects);
        send_er1_data("sense sound level $state")
          if ( $state = state $v_er1_sence_sound);
        send_er1_data("sense speech $state")
          if ( $state = state $v_er1_sence_speech);
        send_er1_data('input analog');
        send_er1_data('input digital');
        &digout();
        send_er1_data('position');

        print_log "listening on ER1 port";

    }
    else {
        print_log
          "Can't find RCC, is it running and configured correctly? ...disconnecting";
        set $v_er1_connection 'disconnect'
          ; #don't keep trying to connect if cant find rcc, since this routine will be called every loop if connect set and no connection
         #can start programs if running on local maching, but don't know how to start on another machine, for now just remind user that they are not running
         #this part of sub a little ugly, if things not setup.  will try twice to connect, and disconnect if unable. gives you alot of errors because it is trying to do this twice.  Twice was not on purpose, mh gets throught 2 loops before all the stuff gets sorted out.  i left it so it would try again.
    }
}

sub get_er1_sounds {

    #get wav files for er1 if changed
    my @er1_sound_files = &file_read_dir($er1_sound_dir)
      ;    #used to get wav files in er1 sound directory
    if (@er1_sound_files) {
        my $er1_sounds = "";       #build from scratch
        shift @er1_sound_files;    #get rid of . and ..
        shift @er1_sound_files;
        shift @er1_sound_files;
        shift @er1_sound_files;
        my $er1_sound_files;
        foreach $er1_sound_files (@er1_sound_files) {    #clean up
            $_ = $er1_sound_files;

            #print "cleaning up sound file $_ \n";
            $er1_sounds = "$er1_sounds" . ",$er1_sound_files"
              if !(m#$er1_sound_dir#);
        }
        $er1_sounds =~ s/,//;    # removes the first the leading comma
        if ( $er1_sounds ne $Save{er1_sounds} ) {
            $Save{er1_sounds} = $er1_sounds;
            print_log "er1 sound files have changed, restarting mh code";
            &read_code_forced
              ; # have to reload code here because voice commands are autogenerated on startup
        }
        else {
            print_log "no change in sound files";
        }
    }
    else {
        print_log "can't find sound files, will keep current sounds";
    }
}

sub get_er1_visual_objects {

    #get visual objects - reads these from
    my @er1_objects = file_read( "$er1_objects_dir" . "/er1lib.ini" );
    if (@er1_objects) {
        my $er1_object_items = "";
        shift @er1_objects;    #get rid of 1st 4 lines
        shift @er1_objects;
        shift @er1_objects;
        shift @er1_objects;
        my $er1_objects;
        foreach $er1_objects (@er1_objects) {    #clean up
            $_ = $er1_objects;
            $er1_objects =~ s/\w+=//;
            $er1_objects =~ s/\|.*$//;
            $er1_object_items = "$er1_object_items" . ",$er1_objects";
        }
        $er1_object_items =~ s/,//;    # removes the first the leading comma
        if ( $er1_object_items ne $Save{er1_objects} ) {
            $Save{er1_objects} = $er1_object_items;
            print_log "er1 objects have changed, restarting mh code";
            &read_code_forced
              ; # have to reload code here because voice commands are autogenerated on startup
        }
        else {
            print_log "no change in visual objects";
        }
    }
    else {
        print_log "can't find object file, will keep current visual objects";
    }
}

sub get_strabo_waypoints {

    #check strabo running then check for waypoint changes
    my $strabo_address = "$strabo_ip" . ":" . "$strabo_port";
    if ( &net_socket_check($strabo_address) ) {
        print_log "strabo connected, getting waypoints.";
        my $waypoints;
        $waypoints = get "http://$strabo_ip:$strabo_port/listwaypoints";
        $waypoints =~ s/OK//;     #gets rid of OK
        $waypoints =~ s/\s//g;    #gets rid of all newline characters
        $waypoints =~ s/W://g;    #gets rid of all those W: labels
        if ( $waypoints ne $Save{waypoints} ) {
            $Save{waypoints} = $waypoints;
            print_log "waypoints have changed, restarting mh code";
            &read_code_forced
              ; # have to reload code here because voice commands are autogenerated on startup
        }
        else {
            print_log "no change in waypoints";
        }

    }
    else {
        print_log
          "Can't find strabo, is it running and configured? waypoints not changed.";

        #run 'X:\progra~1/strabo~1/strabo.exe'; # test start, starts it but on calling machine
    }
}

sub send_er1_data {
    &er1_startup()
      if ( !$main::Socket_Ports{$er1client_address}{sock} )
      ; #connect check, could not use regular net_connect_check. did funny things to rcc
    my $data = @_[0];
    print_log "sending er1 data = $data";

    #set   $er1client "\n"; #recommened (in er1 manual) to use blank line in manual for "programmer confusion issues" works fine without.  either way, i remain confused :)
    set $er1client "$data";
    set $er1client "events";
}

sub checkangle
{ #don't know if this works, strabo expired (wife has yet to approve purchase, strange woman thinks i spend too much money on robots) can still test with other moves, no longer get data from state

    my ( $new_x, $new_y, $old_x, $old_y ) = @_;
    print_log "doing checkangle with ($new_x,$new_y) and ($old_x,$old_y)";
    my $angle;
    my $hyp;
    my $sin_ratio;
    my $delta_y;
    my $delta_x;

    $hyp = sqrt( ( $new_y - $old_y )**2 + ( $new_x - $old_x )**2 );

    #print "hyp $hyp\n";
    return if ( $hyp < 4 );    # dont do this if only a turn was done
    $delta_y   = $new_y - $old_y;
    $delta_x   = $new_x - $old_x;
    $sin_ratio = $delta_y / $hyp
      if ($hyp);               #this makes sure to not do this if hyp is 0
    $angle = asin($sin_ratio);
    $angle = rad2deg($angle);
    $angle = round $angle, 0;

    #print "angle $angle \n";
    $angle = $angle + 90 if ( $delta_x < 0 && $delta_y > 0 );

    #print "angle90 $angle \n";
    $angle = $angle + 270 if ( $delta_x < 0 && $delta_y < 0 );

    #print "angle270 $angle \n";
    $angle = $angle + 360 if ( $delta_x > 0 && $delta_y < 0 );

    #print "angle360 $angle \n";
    set $er1_checkangle $state if ( $state = $angle );
    print_log "calculated angle = $angle\n";
}

sub handle_er1_data
{ # parse into mh items, (almost) no action taken on events here, data just gathered
    my ($er1data) = @_;
    my @er1data = split( / /, $er1data );
    print_log "er1 data: @_ ";

    if ( @er1data[0] eq 'sound' ) {
        set $soundlevel $state if $state = @er1data[2];

        #use state_now to act on data for current pass
        #print_log "heard sound level @er1data[2]";
    }
    elsif ( @er1data[0] eq 'speech' ) {
        shift @er1data;
        set $speech_text $state if $state = "@er1data";    #works
              #will keep text until replaced, use state_now for current pass
        print_log "heard speach $state";
    }
    elsif ( @er1data[0] eq 'object' ) {
        my @objectsplit = split( /"/, $er1data );
        shift @objectsplit;
        set $er1_object $state if $state = $objectsplit[0];
        my @parmsplit = split( / /, $objectsplit[1] );
        shift @parmsplit;
        set $features_matched $state if $state = $parmsplit[0];
        set $total_features $state   if $state = $parmsplit[1];
        set $object_x $state         if $state = $parmsplit[2];
        set $object_y $state         if $state = $parmsplit[3];
        set $object_distance $state  if $state = $parmsplit[4];

        #keeps object even if no longer sees
        print_log "er1 sees $state" if $state = state_now $er1_object;

    }
    elsif ( @er1data[0] eq 'OK' )
    { #for some reason this works (to get position), even when nothing follows the 'OK'
            #print_log "er1 data: @_";
        my @oksplit = split( / /, @er1data );
        if ( @er1data == 4 )
        { #true if position returned, !!! careful here, if you send a request for only 2 analog inputs, this will think they are x,y, really no need to do this
            print_log "updating positions";
            my $old_x = state $coordinates_x;    #use for checkangle sub
            my $old_y = state $coordinates_y;
            set $coordinates_x $state if $state = $er1data[1];
            set $coordinates_y $state if $state = $er1data[2];
            &checkangle( $er1data[1], $er1data[2], $old_x, $old_y );
            my $x;
            $x = ( $er1data[2] ) / ( $strabo_units * .51 ) +
              $strabo_home_x;    #convert to units use on strabo map
            $x = round $x, 1;
            set $strabo_x "$x";
            my $y;
            $y = ( $er1data[1] ) / ( $strabo_units * .51 ) +
              $strabo_home_y;    #convert to units use on strabo map
            $y = round $y, 1;
            set $strabo_y "$y";

            if ( &net_socket_check("$strabo_ip:$strabo_port") ) {
                my $strabo_html =
                    get "http://$strabo_ip:$strabo_port/Setposition?"
                  . $x . ","
                  . $y;          #tells strabo to update position
                print_log
                  "position: er1($er1data[1],$er1data[2]) strabo ($x,$y)";
            }
            else {
                print_log
                  "could not find strabo while trying to set strabo position";
            }
        }
        if ( @er1data[0] eq 'Error:' ) {
            print_log "ER1 ERROR: @_";
        }
        if ( @er1data == 2 ) {    #true if digital input
            print_log "er1: digitals inputs are set to $er1data[1]";
            my $hex_digital = $er1data[1];
            &digital($hex_digital);
        }
        if ( @er1data == 17 ) {    #true if analog input
            set $analog_input_1 $state  if $state = $er1data[1];
            set $analog_input_2 $state  if $state = $er1data[2];
            set $analog_input_3 $state  if $state = $er1data[3];
            set $analog_input_4 $state  if $state = $er1data[4];
            set $analog_input_5 $state  if $state = $er1data[5];
            set $analog_input_6 $state  if $state = $er1data[6];
            set $analog_input_7 $state  if $state = $er1data[7];
            set $analog_input_8 $state  if $state = $er1data[8];
            set $analog_input_9 $state  if $state = $er1data[9];
            set $analog_input_10 $state if $state = $er1data[10];
            set $analog_input_11 $state if $state = $er1data[11];
            set $analog_input_12 $state if $state = $er1data[12];
            set $analog_input_13 $state if $state = $er1data[13];
            set $analog_input_14 $state if $state = $er1data[14];
            set $analog_input_15 $state if $state = $er1data[15];
            set $analog_input_16 $state if $state = $er1data[16];
            my $battery = ( $er1data[16] / 65535 ) * 100;
            $battery = round $battery, 0;
            print_log "er1 battery level: $battery";
            set $battery_level $battery;
        }
    }
    elsif ( $er1data eq 'move done' )
    { #when move done, get new position and then start listening, position data is not retrieved here, it is retrieved in the code directly above this, this only tells er1 to send it.
        print_log "move done";

        set $er1_moving "stopped";    #can now move again
        send_er1_data('position');

    }
    elsif ( $er1data eq 'play done' ) {
        print_log "play done";
        set $er1_playing "stopped";

    }
}

sub digital
{ #this is to convert to binary, i am sure there is a better way, this is called from event handler
        #digital input stuff done, not tested !!!!!!!!
        #split $hex_digital and then convert, object for each pin
    my $first_char;
    my $second_char;
    my $bin_1;
    my $bin_2;
    my $bin;

    my $hex_digital = @_;

    $first_char  = substr( $hex_digital, 0, 1 );
    $second_char = substr( $hex_digital, 1, 1 );

    $bin_1 = '0000' if ( $first_char eq '0' );
    $bin_1 = '0001' if ( $first_char eq '1' );
    $bin_1 = '0010' if ( $first_char eq '2' );
    $bin_1 = '0011' if ( $first_char eq '3' );
    $bin_1 = '0100' if ( $first_char eq '4' );
    $bin_1 = '0101' if ( $first_char eq '5' );
    $bin_1 = '0110' if ( $first_char eq '6' );
    $bin_1 = '0111' if ( $first_char eq '7' );
    $bin_1 = '1000' if ( $first_char eq '8' );
    $bin_1 = '1001' if ( $first_char eq '9' );
    $bin_1 = '1010' if ( $first_char eq 'A' );
    $bin_1 = '1011' if ( $first_char eq 'B' );
    $bin_1 = '1100' if ( $first_char eq 'C' );
    $bin_1 = '1101' if ( $first_char eq 'D' );
    $bin_1 = '1110' if ( $first_char eq 'E' );
    $bin_1 = '1111' if ( $first_char eq 'F' );

    $bin_2 = '0000' if ( $second_char eq '0' );
    $bin_2 = '0001' if ( $second_char eq '1' );
    $bin_2 = '0010' if ( $second_char eq '2' );
    $bin_2 = '0011' if ( $second_char eq '3' );
    $bin_2 = '0100' if ( $second_char eq '4' );
    $bin_2 = '0101' if ( $second_char eq '5' );
    $bin_2 = '0110' if ( $second_char eq '6' );
    $bin_2 = '0111' if ( $second_char eq '7' );
    $bin_2 = '1000' if ( $second_char eq '8' );
    $bin_2 = '1001' if ( $second_char eq '9' );
    $bin_2 = '1010' if ( $second_char eq 'A' );
    $bin_2 = '1011' if ( $second_char eq 'B' );
    $bin_2 = '1100' if ( $second_char eq 'C' );
    $bin_2 = '1101' if ( $second_char eq 'D' );
    $bin_2 = '1110' if ( $second_char eq 'E' );
    $bin_2 = '1111' if ( $second_char eq 'F' );

    $bin = join( '', $bin_1, $bin_2 );

    if ( substr( $bin, 0, 1 ) ) {
        set $digital_input_1 "On";
    }
    else {
        set $digital_input_1 "Off";
    }
    if ( substr( $bin, 1, 1 ) ) {
        set $digital_input_2 "On";
    }
    else {
        set $digital_input_2 "Off";
    }
    if ( substr( $bin, 2, 1 ) ) {
        set $digital_input_3 "On";
    }
    else {
        set $digital_input_3 "Off";
    }
    if ( substr( $bin, 3, 1 ) ) {
        set $digital_input_4 "On";
    }
    else {
        set $digital_input_4 "Off";
    }
    if ( substr( $bin, 4, 1 ) ) {
        set $digital_input_5 "On";
    }
    else {
        set $digital_input_5 "Off";
    }
    if ( substr( $bin, 5, 1 ) ) {
        set $digital_input_6 "On";
    }
    else {
        set $digital_input_6 "Off";
    }
    if ( substr( $bin, 6, 1 ) ) {
        set $digital_input_7 "On";
    }
    else {
        set $digital_input_7 "Off";
    }
    if ( substr( $bin, 7, 1 ) ) {
        set $digital_input_8 "On";
    }
    else {
        set $digital_input_8 "Off";
    }
}

sub digout
{ #all digital outs sent at same time, so this checks all states and makes into hex for sending
    my $bin1;
    my $bin2;
    my $bin3;
    my $bin4;
    my $bin5;
    my $bin6;
    my $bin7;
    my $bin8;
    my $bin_a;
    my $bin_b;
    my $hex_1;
    my $hex_2;
    my $hex;

    $bin1  = state $digital_out_1;
    $bin2  = state $digital_out_2;
    $bin3  = state $digital_out_3;
    $bin4  = state $digital_out_4;
    $bin5  = state $digital_out_5;
    $bin6  = state $digital_out_6;
    $bin7  = state $digital_out_7;
    $bin8  = state $digital_out_8;
    $bin1  = "0" if ( $bin1 eq "off" );
    $bin1  = "1" if ( $bin1 eq "on" );
    $bin2  = "0" if ( $bin2 eq "off" );
    $bin2  = "1" if ( $bin2 eq "on" );
    $bin3  = "0" if ( $bin3 eq "off" );
    $bin3  = "1" if ( $bin3 eq "on" );
    $bin4  = "0" if ( $bin4 eq "off" );
    $bin4  = "1" if ( $bin4 eq "on" );
    $bin5  = "0" if ( $bin5 eq "off" );
    $bin5  = "1" if ( $bin5 eq "on" );
    $bin6  = "0" if ( $bin6 eq "off" );
    $bin6  = "1" if ( $bin6 eq "on" );
    $bin7  = "0" if ( $bin7 eq "off" );
    $bin7  = "1" if ( $bin7 eq "on" );
    $bin8  = "0" if ( $bin8 eq "off" );
    $bin8  = "1" if ( $bin8 eq "on" );
    $bin_a = "$bin1" . "$bin2" . "$bin3" . "$bin4";
    $bin_b = "$bin5" . "$bin6" . "$bin7" . "$bin8";

    $hex_1 = '0' if ( $bin_a eq "0000" );
    $hex_1 = '1' if ( $bin_a eq "0001" );
    $hex_1 = '2' if ( $bin_a eq "0010" );
    $hex_1 = '3' if ( $bin_a eq "0011" );
    $hex_1 = '4' if ( $bin_a eq "0100" );
    $hex_1 = '5' if ( $bin_a eq "0101" );
    $hex_1 = '6' if ( $bin_a eq "0110" );
    $hex_1 = '7' if ( $bin_a eq "0111" );
    $hex_1 = '8' if ( $bin_a eq "1000" );
    $hex_1 = '9' if ( $bin_a eq "1001" );
    $hex_1 = 'A' if ( $bin_a eq "1010" );
    $hex_1 = 'B' if ( $bin_a eq "1011" );
    $hex_1 = 'C' if ( $bin_a eq "1100" );
    $hex_1 = 'D' if ( $bin_a eq "1101" );
    $hex_1 = 'E' if ( $bin_a eq "1110" );
    $hex_1 = 'F' if ( $bin_a eq "1111" );

    $hex_2 = '0' if ( $bin_b eq '0000' );
    $hex_2 = '1' if ( $bin_b eq '0001' );
    $hex_2 = '2' if ( $bin_b eq '0010' );
    $hex_2 = '3' if ( $bin_b eq '0011' );
    $hex_2 = '4' if ( $bin_b eq '0100' );
    $hex_2 = '5' if ( $bin_b eq '0101' );
    $hex_2 = '6' if ( $bin_b eq '0110' );
    $hex_2 = '7' if ( $bin_b eq '0111' );
    $hex_2 = '8' if ( $bin_b eq '1000' );
    $hex_2 = '9' if ( $bin_b eq '1001' );
    $hex_2 = 'A' if ( $bin_b eq '1010' );
    $hex_2 = 'B' if ( $bin_b eq '1011' );
    $hex_2 = 'C' if ( $bin_b eq '1100' );
    $hex_2 = 'D' if ( $bin_b eq '1101' );
    $hex_2 = 'E' if ( $bin_b eq '1110' );
    $hex_2 = 'F' if ( $bin_b eq '1111' );

    $hex = join( '', $hex_2, $hex_1 );

    send_er1_data("output digital $hex");

}

sub get_strabo_path {

    my $waypoint = @_[0];
    my $x;
    $x = state $strabo_x;
    my $y;
    $y = state $strabo_y;
    print_log "Getting strabo path to $waypoint";
    if ( &net_socket_check("$strabo_ip:$strabo_port") && $x && $y )
    {    #is strabo connected and x,y defined?
        my $strabo_html =
            get "http://$strabo_ip:$strabo_port/getpath?"
          . $x . ","
          . $y . ","
          . $waypoint;    #get route
        $_ = $strabo_html;
        if (m/ERROR/) {
            print_log
              "ERROR:could not find strabo waypoint ($waypoint). check: proper map, or refresh waypoints";
            return;
        }
        my @strabo_html = split( /\n/, $strabo_html );    #split into lines
        $_ = $strabo_html[3];    #this line has cardinal directions
        s/\[//;                  # get rid of [
        s/\]//;                  # get rid of ]
        my @dirs = split( /,/, $_ )
          ;   #new array with elements = dir cardinal directions, without commas
        print_log "strabo path = @dirs";

        #sort through "smooth" data (not path), gets two arrays with directions and distance in that direction
        my @dir = ();    #new array with each direction only once
        my @dis =
          ();    #array with distances corresponding to each element of @dir
        my $olddir = $dirs[0];
        push( @dir, $dirs[0] );
        push( @dis, 0 );
        my $counter = 0;
        while ( $counter <= @dirs ) {
            my $newdir = $dirs[$counter];
            if ( $olddir eq $newdir ) {
                $dis[$#dis]++;
            }
            if ( $olddir ne $newdir ) {
                push( @dir, $newdir );
                push( @dis, 1 );
            }
            $olddir = $newdir;
            $counter++;
        }
        pop @dis;    #gets rid of extra element
        my $dis;
        foreach $dis (@dis) {    #convert to inches
            $dis = $dis * 2.4;    #size of my little blocks in strabo
        }
        while (@dis) {
            @moves = ( @moves, shift @dir );
            @moves = ( @moves, shift @dis );
        }
    }
    else {
        print_log "can't find strabo, while trying to get path. or x,y not set";
    }

    #   @moves which is sent to er1 if not moving, each time it moves it deletes member of array
}

sub er1_move {

    #if turn set and different than current dir => turn and set new direction, also set moving
    # remember diections are reversed the way i set up er1 and strabo
    $state = @_[0];
    print_log "running er1 move: $state";
    if ( $state eq 's' ) {
        if ( state $er1_direction == 180 ) {
            send_er1_data('move 180 d');
            set $er1_direction '360';
        }
        elsif ( state $er1_direction == 270 ) {
            send_er1_data('move 90 d');
            set $er1_direction '360';
        }
        elsif ( state $er1_direction == 90 ) {
            send_er1_data('move -90 d');
            set $er1_direction '360';
        }
        elsif ( state $er1_direction == 360 ) {
            set $er1_moving 'stopped';
        }
    }
    elsif ( $state eq 'n' ) {
        if ( state $er1_direction == 360 ) {
            send_er1_data('move 180 d');
            set $er1_direction '180';
        }
        elsif ( state $er1_direction == 270 ) {
            send_er1_data('move -90 d');
            set $er1_direction '180';
        }
        elsif ( state $er1_direction == 90 ) {
            send_er1_data('move 90 d');
            set $er1_direction '180';
        }
        elsif ( state $er1_direction == 180 ) {
            set $er1_moving 'stopped';
        }
    }
    elsif ( $state eq 'e' ) {
        if ( state $er1_direction == 180 ) {
            send_er1_data('move -90 d');
            set $er1_direction '90';
        }
        elsif ( state $er1_direction == 270 ) {
            send_er1_data('move 180 d');
            set $er1_direction '90';
        }
        elsif ( state $er1_direction == 360 ) {
            send_er1_data('move 90 d');
            set $er1_direction '90';
        }
        elsif ( state $er1_direction == 90 ) {
            set $er1_moving 'stopped';
        }
    }
    elsif ( $state eq 'w' ) {
        if ( state $er1_direction == 180 ) {
            send_er1_data('move 90 d');
            set $er1_direction '270';
        }
        elsif ( state $er1_direction == 360 ) {
            send_er1_data('move -90 d');
            set $er1_direction '270';
        }
        elsif ( state $er1_direction == 90 ) {
            send_er1_data('move 180 d');
            set $er1_direction '270';
        }
        elsif ( state $er1_direction == 270 ) {
            set $er1_moving 'stopped';
        }
    }
    else {
        send_er1_data("move $state i");
    }
}

sub er1_turn
{  #called with html from web page, you could make voice command to control this
    my ($deg) = @_;
    send_er1_data("move $deg d");
}

sub ER1_speak
{  #called with html from web page, you could make voice command to control this
        #need condition to not do this if we are asleep
    my ($er1_text) = @_;
    if ( state $er1_playing eq "playing" ) {
        print_log "er1 is busy playing a sound";
        return;
    }
    if ( state $er1_playing eq "stopped" ) {
        print_log "speaking $er1_text";    #not returned, need to check web call
        set $er1_playing "playing";
        send_er1_data( "play phrase '" . $er1_text . "'" );
    }
}

sub Er1_cid {    #have to have callerid stuff working in mh
                 #need way to not do this if we are asleep
    my ( $p_state, $p_setby ) = @_;
    my $er1_cid;
    $er1_cid = "you have a call from " . $p_setby->cid_name();
    set $ER1_speak "$er1_cid";
}

sub web_icon_state
{ #testing this, returns image to web pages that call it. this works if graphics are in the right place and named correctly
    my ($item) = @_;
    my $obj    = &get_object_by_name($item);
    my $state  = $obj->state;
    my $icon   = "$main::config_parms{html_dir}/graphics/$state.jpg";
    print "db icon=$icon s=$state i=$item\n";
    my $image = file_read $icon;
    return $image;
}

sub get_er1_state {    #use this to return data to web pages
    my ($object) = @_;
    my $state = eval "state $object";
    return $state;
}

####################################### tk labels ########################################
#I am thinking of getting rid of these, you can make you own web pages now to see the state of whatever you want
#you can also now browse 'er1 objects' to see their state

#this is so you can see what is happening
#awful lot-o code just to get one line of data to show up, but if you I try to define things in one line it dosn't work

my $angle;
$angle = state $er1_checkangle;
my $er1_coordinates_x;    #coordinates reported by er1 in cm
$er1_coordinates_x = state $coordinates_x;
my $er1_coordinates_y;
$er1_coordinates_y = state $coordinates_y;
my $x;
$x = state $strabo_x;
my $y;
$y = state $strabo_y;
my $er1_angle;
$er1_angle = state $er1_direction;
my $er1_label_position;
$er1_label_position =
  "Position: ER1: $er1_coordinates_x,$er1_coordinates_y  Angle set=$er1_angle measured=$angle | Strabo: $x,$y"
  ;    # $x,y defined elsewhere in code
&tk_label( \$er1_label_position );

my $er1_obj;
$er1_obj = state $er1_object;
my $er1_features_matched;
$er1_features_matched = state $features_matched;
my $er1_total_features;
$er1_total_features = state $total_features;
my $er1_object_x;
$er1_object_x = state $object_x;
my $er1_object_y;
$er1_object_y = state $object_y;
my $er1_object_distance;
$er1_object_distance = state $object_distance;
my $label_seen;
$label_seen =
  "Object Recognition: $er1_obj with $er1_features_matched/$er1_total_features matched. Position  $er1_object_x,$er1_object_y @ $er1_object_distance cm";
&tk_label( \$label_seen );

my $er1_soundlevel;
$er1_soundlevel = state $soundlevel;
my $er1_speech_text;
$er1_speech_text = state $speech_text;
my $er1_label_sound;
$er1_label_sound =
  "Sound: Soundlevel $er1_soundlevel | Speech $er1_speech_text";
&tk_label( \$er1_label_sound );

my $er1_battery;
$er1_battery = state $battery_level;
my $er1_label_battery;
$er1_label_battery = "Power:  Er1 battery $er1_battery %";
&tk_label( \$er1_label_battery );

my $a1;
$a1 = state $analog_input_1;
my $a2;
$a2 = state $analog_input_2;
my $a3;
$a3 = state $analog_input_3;
my $a4;
$a4 = state $analog_input_4;
my $a5;
$a5 = state $analog_input_5;
my $a6;
$a6 = state $analog_input_6;
my $a7;
$a7 = state $analog_input_7;
my $a8;
$a8 = state $analog_input_8;
my $a9;
$a9 = state $analog_input_9;
my $a10;
$a10 = state $analog_input_10;
my $a11;
$a11 = state $analog_input_11;
my $a12;
$a12 = state $analog_input_12;
my $a13;
$a13 = state $analog_input_13;
my $a14;
$a14 = state $analog_input_14;
my $a15;
$a15 = state $analog_input_15;
my $er1_label_analog_a;
my $er1_label_analog_b;
$er1_label_analog_a =
  "Anaolg Inputs:  A1:$a1  A2:$a2  A3:$a3  A4:$a4  A5:$a5  A6:$a6  A7:$a7  A8:$a8";
$er1_label_analog_b =
  "Anaolg Inputs:  A9:$a9  A10:$a10  A11:$a11  A12:$a12  A13:$a13  A14:$a14  A15:$a15";
&tk_label( \$er1_label_analog_a );
&tk_label( \$er1_label_analog_b );

my $d1;
$d1 = state $digital_input_1;
my $d2;
$d2 = state $digital_input_2;
my $d3;
$d3 = state $digital_input_3;
my $d4;
$d4 = state $digital_input_4;
my $d5;
$d5 = state $digital_input_5;
my $d6;
$d6 = state $digital_input_6;
my $d7;
$d7 = state $digital_input_7;
my $d8;
$d8 = state $digital_input_8;

my $er1_label_digital;
$er1_label_digital =
  "Digital Inputs:  D1:$d1  D2:$d2  D3:$d3  D4:$d4  D5:$d5  D6:$d6  D7:$d7  D8:$d8";
&tk_label( \$er1_label_digital );
