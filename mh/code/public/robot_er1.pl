# Category=ER1
#@code for running ER1 robot from evolution robotics using api calls.  Also uses strabo software for pathfinding and waypoint navigation.  
#@
###########################################
#This is a code for the evolution robotics ER1 robot.  The robot has visual and speech recognition and can do lots - o 
#cool stuff. the software that comes with ER1 is very good at getting you up and running but soon falls short. 
#The Robot Control Software, RCC, provides for API interface and I have taken advantage of a misterhouse socket item.
#this program starts a client, turns on sensors, gets position and then starts listening for data from the ER1.
#data is put into variables and action is taken elsewhere in other code files.  ie, i have my robot feel like he 
#is getting attention when sensed soundlevel is above 2.
#
#$desire_social = $desire_social + 1 if state_now $soundlevel > 2 && $desire_social < 100;
#
#even though sound level remains above 2 until changed by some new input, I only increase my variable once by using state_now


#strabo is a piece of software that is used for pathfinding, you give it a map of your home, tell it where you are and it
#will tell you how to get form A to B. very cool. this code does the strabo calls. you just tell it the waypoint and of it goes.
#also code for getting data from robots digital and analog ports not done yet.


#I am using kind-of-a "SIMS" model (elsewhere) in my code. The robot has needs that slowly decay over time and his mood
#gets worse until these are met.  ie. it moves slower when  he needs  battery charge, or really wants one the lower his "energy level" gets


# If you can't already tell from my ramblings
# this is my first ever attempt at making something i plan to share with others
# because I am a NEeeeeeeWBIE, and I am sure that this could be written better, 
# I have tried to explain everything I was doing as it happens, im sure this will drive some of you crazy
 
# my name is Dave Hall whall@marshall.edu
# Bruce (mh) and Davee (Strabo) you guys rule
# version 4, the date is 6/10/04
#############################################
# to do list
# navigation
#	checkangle not working, always returns 0, worked before i made it a sub. changed the way data passed to sub, not tested.
#	need to handle error from rcc ie can't because laptop plugged in
#	need to fix commands so they don't execute if not connected, i thingk this puts mh in loop
#	do more testing and figure out if I should recalc path after each step in move, when i say move 6 inches it moves precicly 5.15 inches, tried upping power -> same, turns are little less than 90, precise
#	need a fix 'get angle' routine
# 	figure out what room er1 is in
#	need to get objects and make a goto object command
# 	maybe a calibrate routine to adjust motion to what er1 actually does
#	need to handel non n.s.e.w moves with @moves so can create move macros with smaller turns
#	make a move sub so you can just pass arugment to it with event code
# sound
# 	play item like er1_moving item [playing,stopped], so er1 doesn't try to play if already playing
# 	generic er1 say something

# interface/config stuff
# 	maybe a tie_filter to check if necessary connection available, with strabo, rcc
# 	may need config parms for paths to programs if want them to start up in not running
# 	may need config pram for strabo map if want it to starup strabo
# 	need to put in some examples of how to code events
# need to write stuff for er1's dig/analog ports, use this to get batt charge level as someone suggested in forum
#	need laptop battery level
#	need to test digital inputs
#	need digital input label for interface = done needs testing


#changed in version 4
#fixed problem where strabo coordinates were not reliably updated after move done by just passing data directly instead of from state change of er1 coordinates. I think the problems was new state was not updated by the time the code ran...???, works
#added 'get er1 wav files' in startup routine and play wav function, also ini parm for sound dir(note: you put the sound files where you always did for er1, you just have to tell mh where that is, in case mh on a diff maching)
#added er1 battery level from analog inputs
#added analog inputs - works, got digital inputs but not tested, started on dig out stuff - not yet done
#	Warning, this code decideds if data returned from er1 is dig or analog based on number of items returned.  it is possible to tell er1 to give you data which could fool this.  ie.. if you asked for objects and there were the same number as analog inputs this code would get confused.
#added a checkangle routine that computes er1 angle after a forward move with some basic trig, needs some testing

#changed in version 3
#fixed problem of config parms not being defined on initial startup by putting default that get overriden if a config parm exist
#added connect to disconnect voice command so er1 does not automatically restart when code reloads.  this saves time when continually reloading code to check changes and gives the ability to do in the web,tk interface, can also add conditions later, like, if new move and not connected then connect then do move
#made starup routine to ensure that rcc running, and remind user if not, did same for strabo
#moved strabo waypoint get to startup sub and fixed the problem with have to reload code manually.  it now takes care of it for you
#cleaned up stuff for tk. looks better on web interface

#changed  in version 2.
# commented out TK stuff and put it in another file
# got rid of some print and stuff i used for debugging
# added some stuff to get strabo waypoints automatically on startup, for now shutdown and reload mh twice for mh to reciginize new waypoints, I know ...it's a pain
#	this has a few pseudo-bugs. strabo has to be running to deliever waypoint otherwise waypoints with be empty []
# added some config parms for er1client so you don't have to modify the code just change it with parm editor. howto below under #config parms#
# added config parms for strabo client
# added config parms for strabo home position
# added config parm for strabo units, this is the number of inches for each block in strabo grid, each block is 5x5 little blocks
#	If you want each block in the grid to be 1 square foot, then strabo units would be 12.  this would make each little block 2.4 inches



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
#@ er1_sound_dir = location of er1 files (relative to MH machine).
#@ strabo_ip = ip address of computer that Strabo is running on.
#@ strabo_port = port that you have strabo set to.
#@ strabo_home_x, strabo_home_y = home position on strabo map. this with where you will start er1 and reset its x,y to zero.
#@ strabo_units = one block on strabo grid in inches (ex. 12, for each block in grid to equal 1 square foot. that would make each unit on strabo equal to 2.4 inches).

# noloop=start      This directive allows this code to be run on startup/reload
my $er1_ip = 'localhost';
$er1_ip = $config_parms{er1_ip} if ($config_parms{er1_ip});  
my $er1_port = 9000;
$er1_port = $config_parms{er1_port} if ($config_parms{er1_port});
my $er1_sound_dir = 'Z:/progra~1/er1/sounds';
$er1_sound_dir = $config_parms{er1_sound_dir} if ($config_parms{er1_sound_dir});
my $strabo_ip = 'localhost';
$strabo_ip = $config_parms{strabo_ip} if ($config_parms{strabo_ip});
my $strabo_port = 80;
$strabo_port = $config_parms{strabo_port} if ($config_parms{strabo_port});
my $strabo_home_x = 16;
$strabo_home_x = $config_parms{strabo_home_x} if ($config_parms{strabo_home_x});
my $strabo_home_y = 6;
$strabo_home_y = $config_parms{strabo_home_y} if ($config_parms{strabo_home_y});
my $strabo_units = 12;
$strabo_units = $config_parms{strabo_units} if ($config_parms{strabo_units});
# noloop=stop
##############################################################


#deine er1 client
my $er1client_address = "$er1_ip" . ":" . "$er1_port";     #'192.168.1.102:9000';
$er1client = new  Socket_Item(undef, undef, $er1client_address);


	
####################  startup and initialize all necessary stuff for er1 ##################################3
my @er1_sound_files;  #used to get wav files in er1 sound directory
my $er1_sound_files;  #ditto
my $er1_sounds;	      #dito
sub er1_startup {    #used to start all the things you need to have mh run er1, this will be called with "connect"
	#get wav file for er1 if changed
	@er1_sound_files = &file_read_dir($er1_sound_dir);
	$er1_sounds ="";  #build from scratch
	shift @er1_sound_files;  #get rid of . and ..
	shift @er1_sound_files;
	shift @er1_sound_files;
	shift @er1_sound_files;
	foreach $er1_sound_files (@er1_sound_files) {   #clean up
		$_ = $er1_sound_files;
		$er1_sounds = "$er1_sounds" . ",$er1_sound_files" if !(m#$er1_sound_dir#);
	}
	$er1_sounds =~ s/,//;  # removes the first the leading comma
	if ($er1_sounds ne $Save{er1_sounds}) {
			$Save{er1_sounds} = $er1_sounds;
			print_log "er1 sound files have changed, restarting mh code";
			&read_code_forced;  # have to reload code here because voice commands are autogenerated on startup
	}

	#check strabo running then check for waypoint changes
	my $strabo_address = "$strabo_ip" . ":" . "$strabo_port";
	if (&net_socket_check($strabo_address)) {
		print_log "strabo connected, getting waypoints.";
		my $waypoints;
		$waypoints = get "http://$strabo_ip:$strabo_port/listwaypoints";
		$waypoints =~ s/OK//;   #gets rid of OK
		$waypoints =~ s/\s//g;  #gets rid of all newline characters
		$waypoints =~ s/W://g;  #gets rid of all those W: labels
		if ($waypoints ne $Save{waypoints}) {
			$Save{waypoints} = $waypoints;
			print_log "waypoints have changed, restarting mh code";
			&read_code_forced;  # have to reload code here because voice commands are autogenerated on startup
		}
		
	} else {
		print_log "Can't find strabo, is it running and configured?";
	}

	#check Rcc running
	if (active $er1client) {
		print_log "already connected to ER1";
		return;
	}
	#&net_socket_check("192.168.1.102:9000"); # works to check, but starts rcc connections, gets ugly after that, so used below instead, there is also a "socket_close 'http';" in mh control.pl that might work, havent tried it
	if (start $er1client) {
		set $er1client "\n";
		set $er1client "sense objects";
		set $er1client "sense sound level";
		set $er1client "sense speech";
		set $er1client "position";
		set $er1client "events";
		print_log "listening on ER1 port";
		return;
	}
	print_log "Can't find RCC, is it running and configured correctly?";


#can start programs if running on local maching, but don't know how to start on another machine, for now just remind user that they are not running
}



###########  some testing stuff I wan't in the tk interface  ############

#disconnect/connect
$v_er1_connection = new  Voice_Cmd("[connect,disconnect] Er1");
if ($state = said $v_er1_connection) {
	if ($state eq 'disconnect') {
		print_log "Disconnecting from ER1";
		stop  $er1client;
	}
	elsif ($state eq 'connect') {
		&er1_startup();
	}
}

#test moves
$v_move_er1client = new  Voice_Cmd("move: [forward 6 inches,forward 6 feet,backward 6 inches,backward 6 feet,turn left,turn left 45,turn right]");
if ($state = said $v_move_er1client) {
    print_log "Running $state";
    if ($state eq 'forward 6 inches') {
       #start $er1client;
       set   $er1client "\n";   # this assumes that client is running and listening for events.  to stop listening for events use \n, then restart "events" after command issued 
       set   $er1client "move 6 i";
       set   $er1client "events";
    }
    if ($state eq 'forward 6 feet') {
       #start $er1client;
       set   $er1client "\n";
       set   $er1client "move 6 f";
       set   $er1client "events";
    }
    elsif ($state eq 'backward 6 inches') {
       print_log "Running $state";
       #start $er1client;
       set   $er1client "\n";
       set   $er1client "move -6 i";
       set   $er1client "events";
    }
    elsif ($state eq 'backward 6 feet') {
       print_log "Running $state";
       #start $er1client;
       set   $er1client "\n";
       set   $er1client "move -6 f";
       set   $er1client "events";
    }
    elsif ($state eq 'turn left') {
       print_log "Running $state";
       #start $er1client;
       set   $er1client "\n";
       set   $er1client "move 90 d";
       set   $er1client "events";
    }
    elsif ($state eq 'turn left 45') {
       print_log "Running $state";
       #start $er1client;
       set   $er1client "\n";
       set   $er1client "move 45 d";
       set   $er1client "events";
    }
    elsif ($state eq 'turn right') {
       print_log "Running $state";
       #start $er1client;
       set   $er1client "\n";
       set   $er1client "move -90 d";
       set   $er1client "events";
    }

}

#play wav files
$v_er1_wav = new  Voice_Cmd("play: [$Save{er1_sounds}]"); 
if ($state = said $v_er1_wav) {
	my $er1_sound = "sounds\\" . $state;
    print_log "Running $state";
       set   $er1client "\n";
       set   $er1client 'play file "' . $er1_sound . '"';   #had to do this so that " would be sent, required if space in file
       set   $er1client "events";
    
}


#get position, results put into coordinates when listening for events, mh automatically updates position for itself and strabo when move done recieved
$v_position_er1client = new  Voice_Cmd("get: [position]");
if ($state = said $v_position_er1client) {
    print_log "Running $state";
    if ($state eq 'position') {
       set   $er1client "\n";
       set   $er1client "position";
       set   $er1client "events";
    }
}

#testing analog input, might do a if new second then check
$v_er1_input = new Voice_Cmd("get: [analog,digital] inputs");
if ($state = said $v_er1_input) {
	if ($state eq 'analog') {
		set $er1client "\n";
		set $er1client "input analog";
		set $er1client "events";
	}
	if ($state eq 'digital') {
		set $er1client "\n";
		set $er1client "input digital";
		set $er1client "events";
	}	
}


##########test get angle, need to figure out way to do this if move done and move was not a turn, maybe when move done and position called, could compare x,y - dont do calc if delta is small (true for turn), sould like to do as sub so would be easy to modify

$er1_checkangle = new Generic_Item; 
my $old_x;
my $old_y;
my $new_x;
my $new_y;
my $angle;
my $hyp;
my $sin_ratio;
my $delta_y;
my $delta_x;

#$V_er1_getangle = new Voice_Cmd("check [angle]");
#if ($state = said $V_er1_getangle) {
#	if ($state = 'angle') {
#		$old_x = state $coordinates_x;
#		$old_y = state $coordinates_y;
#		set   $er1client "\n";
#	        set   $er1client "move 6 i";
#	        set   $er1client "events";
#	}
#}

sub checkangle {  #don't know if this works, strabo quit can still test with other moves, no longer get data from state
	print "doing checkangle\n";
	($new_x, $new_y) = @_;
	#$new_x = state $coordinates_x;
	#$new_y = state $coordinates_y;
	
	$hyp = sqrt(($new_y - $old_y)**2 + ($new_x - $old_x)**2);
	print "hyp $hyp\n";
	#return if ($hyp < 4); # dont do this if only a turn was done
	$delta_y = $new_y - $old_y;
	$delta_x = $new_x - $old_x;
	$sin_ratio = $delta_y/$hyp if ($hyp);  #this makes sure to not do this if hyp is 0
	$angle = asin($sin_ratio);
	$angle = rad2deg($angle);
	$angle = round $angle,0;
	#print "angle $angle \n";
	$angle = $angle + 90 if ($delta_x < 0 && $delta_y > 0);
	#print "angle90 $angle \n";
	$angle = $angle + 270 if ($delta_x < 0 && $delta_y < 0);
	#print "angle270 $angle \n";
	$angle = $angle + 360 if ($delta_x > 0 && $delta_y < 0);
	print "angle360 $angle \n";
	set $er1_checkangle $state if ($state = $angle);
}


######## digital i/o stuff ###########  !!!!!!!! needs work  !!!!!!!!!

#digital input stuff done, not tested !!!!!!!!

my $first_char;
my $second_char;
my $bin_1;
my $bin_2;
my $bin;
$digital_input_1 = new Generic_Item;
$digital_input_2 = new Generic_Item;
$digital_input_3 = new Generic_Item;
$digital_input_4 = new Generic_Item;
$digital_input_5 = new Generic_Item;
$digital_input_6 = new Generic_Item;
$digital_input_7 = new Generic_Item;
$digital_input_8 = new Generic_Item;

sub digital {  #this is to convert to binary, i am sure there is a better way, this is called from event handler
	#need to split $hex_digital and then convert, object for each pin	
	$first_char = substr( $hex_digital, 0, 1 );
	$second_char = substr( $hex_digital, 1, 1 );

	$bin_1 = '0000' if ($first_char eq '0');
	$bin_1 = '0001' if ($first_char eq '1');
	$bin_1 = '0010' if ($first_char eq '2');
	$bin_1 = '0011' if ($first_char eq '3');
	$bin_1 = '0100' if ($first_char eq '4');
	$bin_1 = '0101' if ($first_char eq '5');
	$bin_1 = '0110' if ($first_char eq '6');
	$bin_1 = '0111' if ($first_char eq '7');
	$bin_1 = '1000' if ($first_char eq '8');
	$bin_1 = '1001' if ($first_char eq '9');
	$bin_1 = '1010' if ($first_char eq 'A');
	$bin_1 = '1011' if ($first_char eq 'B');
	$bin_1 = '1100' if ($first_char eq 'C');
	$bin_1 = '1101' if ($first_char eq 'D');
	$bin_1 = '1110' if ($first_char eq 'E');
	$bin_1 = '1111' if ($first_char eq 'F');

	$bin_2 = '0000' if ($second_char eq '0');
	$bin_2 = '0001' if ($second_char eq '1');
	$bin_2 = '0010' if ($second_char eq '2');
	$bin_2 = '0011' if ($second_char eq '3');
	$bin_2 = '0100' if ($second_char eq '4');
	$bin_2 = '0101' if ($second_char eq '5');
	$bin_2 = '0110' if ($second_char eq '6');
	$bin_2 = '0111' if ($second_char eq '7');
	$bin_2 = '1000' if ($second_char eq '8');
	$bin_2 = '1001' if ($second_char eq '9');
	$bin_2 = '1010' if ($second_char eq 'A');
	$bin_2 = '1011' if ($second_char eq 'B');
	$bin_2 = '1100' if ($second_char eq 'C');
	$bin_2 = '1101' if ($second_char eq 'D');
	$bin_2 = '1110' if ($second_char eq 'E');
	$bin_2 = '1111' if ($second_char eq 'F');

	$bin = join($bin_1,$bin_2);

	if (substr( $bin, 0, 1 )) {
		set $digital_input_1 "On";
	} else {
		set $digital_input_1 "Off";
	}
	if (substr( $bin, 1, 1 )) {
		set $digital_input_2 "On";
	} else {
		set $digital_input_2 "Off";
	}
	if (substr( $bin, 2, 1 )) {
		set $digital_input_3 "On";
	} else {
		set $digital_input_3 "Off";
	}
	if (substr( $bin, 3, 1 )) {
		set $digital_input_4 "On";
	} else {
		set $digital_input_4 "Off";
	}
	if (substr( $bin, 4, 1 )) {
		set $digital_input_5 "On";
	} else {
		set $digital_input_5 "Off";
	}
	if (substr( $bin, 5, 1 )) {
		set $digital_input_6 "On";
	} else {
		set $digital_input_6 "Off";
	}
	if (substr( $bin, 6, 1 )) {
		set $digital_input_7 "On";
	} else {
		set $digital_input_7 "Off";
	}
	if (substr( $bin, 7, 1 )) {
		set $digital_input_8 "On";
	} else {
		set $digital_input_8 "Off";
	}


}

# for dig output need voice commands for each output pin, then check all states and make hex to send to er1
$digital_out_1 = new Generic_Item;
$digital_out_2 = new Generic_Item;
$digital_out_3 = new Generic_Item;
$digital_out_4 = new Generic_Item;
$digital_out_5 = new Generic_Item;
$digital_out_6 = new Generic_Item;
$digital_out_7 = new Generic_Item;
$digital_out_8 = new Generic_Item;


$v_er1_digital_out_1 = new Voice_Cmd("set digital output 1 [On,Off]");
if ($state = said $v_er1_digital_out_1) {
	set $digital_out_1 $state;
	&digout();
}
$v_er1_digital_out_2 = new Voice_Cmd("set digital output 2 [On,Off]");
if ($state = said $v_er1_digital_out_2) {
	set $digital_out_2 $state;
	&digout();
}
$v_er1_digital_out_3 = new Voice_Cmd("set digital output 3 [On,Off]");
if ($state = said $v_er1_digital_out_3) {
	set $digital_out_3 $state;
	&digout();
}
$v_er1_digital_out_4 = new Voice_Cmd("set digital output 4 [On,Off]");
if ($state = said $v_er1_digital_out_4) {
	set $digital_out_4 $state;
	&digout();
}
$v_er1_digital_out_5 = new Voice_Cmd("set digital output 5 [On,Off]");
if ($state = said $v_er1_digital_out_5) {
	set $digital_out_5 $state;
	&digout();
}
$v_er1_digital_out_6 = new Voice_Cmd("set digital output 6 [On,Off]");
if ($state = said $v_er1_digital_out_6) {
	set $digital_out_6 $state;
	&digout();
}
$v_er1_digital_out_7 = new Voice_Cmd("set digital output 7 [On,Off]");
if ($state = said $v_er1_digital_out_7) {
	set $digital_out_7 $state;
	&digout();
}
$v_er1_digital_out_8 = new Voice_Cmd("set digital output 8 [On,Off]");
if ($state = said $v_er1_digital_out_8) {
	set $digital_out_8 $state;
	&digout();
}

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

sub digout { #all digital outs sent at same time, so check all states and make into hex for sending
	$bin1 = state $digital_out_1;
	$bin2 = state $digital_out_2;
	$bin3 = state $digital_out_3;
	$bin4 = state $digital_out_4;
	$bin5 = state $digital_out_5;
	$bin6 = state $digital_out_6;
	$bin7 = state $digital_out_7;
	$bin8 = state $digital_out_8;
	$bin1 = "0" if ($bin1 eq "Off");
	$bin1 = "1" if ($bin1 eq "On");	
	$bin2 = "0" if ($bin2 eq "Off");
	$bin2 = "1" if ($bin2 eq "On");	
	$bin3 = "0" if ($bin3 eq "Off");
	$bin3 = "1" if ($bin3 eq "On");	
	$bin4 = "0" if ($bin4 eq "Off");
	$bin4 = "1" if ($bin4 eq "On");	
	$bin5 = "0" if ($bin5 eq "Off");
	$bin5 = "1" if ($bin5 eq "On");	
	$bin6 = "0" if ($bin6 eq "Off");
	$bin6 = "1" if ($bin6 eq "On");	
	$bin7 = "0" if ($bin7 eq "Off");
	$bin7 = "1" if ($bin7 eq "On");	
	$bin8 = "0" if ($bin8 eq "Off");
	$bin8 = "1" if ($bin8 eq "On");
	$bin_a = "$bin1" . "$bin2" . "$bin3" . "$bin4";
	$bin_b = "$bin5" . "$bin6" . "$bin7" . "$bin8";
	####this is where you stopped   !!!!!!!!!!!!!!!!!!!!!!need to finish this after some sleep  !!!!!!!!!!!		

}
##################  handle er1 events    ##############################################

# handle events - parse into mh items, (almost) no action taken on events here, data just gathered
my $er1data;
$soundlevel = new Generic_Item;
$speech_text = new Generic_Item;
$object = new Generic_Item;
$features_matched = new Generic_Item;
$total_features = new Generic_Item;
$object_x = new Generic_Item;
$object_y = new Generic_Item;
$object_distance = new Generic_Item; #in centimeters
$coordinates_x = new Generic_Item; #coordinates reported by er1 in cm
$coordinates_y = new Generic_Item;
$analog_input_1 = new Generic_Item;  # analog input, see manual for pinout
$analog_input_2 = new Generic_Item;
$analog_input_3 = new Generic_Item;
$analog_input_4 = new Generic_Item;
$analog_input_5 = new Generic_Item;
$analog_input_6 = new Generic_Item;
$analog_input_7 = new Generic_Item;
$analog_input_8 = new Generic_Item;
$analog_input_9 = new Generic_Item;
$analog_input_10 = new Generic_Item;
$analog_input_11 = new Generic_Item;
$analog_input_12 = new Generic_Item;
$analog_input_13 = new Generic_Item;
$analog_input_14 = new Generic_Item;
$analog_input_15 = new Generic_Item;
$analog_input_16 = new Generic_Item;  #this connected to batt and used to get charge level
$battery_level = new Generic_Item;    #redudant but clear
my $battery;
my $hex_digital;


if (my $er1data = said $er1client) {
    #print_log "er1 data: $er1data";
    @_ =  split ' ', $er1data;

    if (@_[0] eq 'sound') {
	set $soundlevel $state if $state = @_[2];
	#use state_now to act on data for current pass
    }
    elsif (@_[0] eq 'speech') {
	shift @_;
	set $speech_text $state if $state = "@_" ; #works
	#will keep text until replaced, use state_now for current pass
    }
    elsif (@_[0] eq 'object') {
	my @objectsplit = split(/"/, $er1data);
	shift @objectsplit;
	set $object $state if $state = $objectsplit[0];
	my @parmsplit = split(/ /, $objectsplit[1]);
	shift @parmsplit;
	set $features_matched $state if $state = $parmsplit[0];
	set $total_features $state if $state = $parmsplit[1];
	set $object_x $state if $state = $parmsplit[2];
	set $object_y $state if $state = $parmsplit[3];
	set $object_distance $state if $state = $parmsplit[4];
	#keeps object even if no longer sees
	#speak "I see $state" if $state = state_now $object;

    }
    elsif (@_[0] eq 'OK') {   #for some reason this works (to get position), even when nothing follows the 'OK'
	my @oksplit = split(/ /, $er1data);
	if (@oksplit == 4) {  #true if position returned, !!! careful here, if you send a request for only 2 analog inputs, this will think they are x,y, really no need to do this
		$old_x = state $coordinates_x; #use for checkangle sub
		$old_y = state $coordinates_y;
		set $coordinates_x $state if $state = $oksplit[1];
		set $coordinates_y $state if $state = $oksplit[2];
		&checkangle($oksplit[1],$oksplit[2]);
		$x = ($oksplit[2])/($strabo_units * .51) + $strabo_home_x; #convert to units use on strabo map
		$x = round $x,1;
		$y = ($oksplit[1])/($strabo_units * .51) + $strabo_home_y; #convert to units use on strabo map
		$y = round $y,1;
		$strabo_html = get "http://$strabo_ip:$strabo_port/Setposition?" . $x . "," . $y; #tells strabo to update position
		#print_log "strabo data: $strabo_html";
		#print_log state $coordinates_x;
		}
	if (@oksplit == 2) {  #true if digital input
		#do digital input stuff
		$hex_digital = $oksplit[2];
		&digital();
	}
	if (@oksplit == 17) { #true if analog input
		set $analog_input_1 $state if $state = $oksplit[1];
		set $analog_input_2 $state if $state = $oksplit[2];
		set $analog_input_3 $state if $state = $oksplit[3];
		set $analog_input_4 $state if $state = $oksplit[4];
		set $analog_input_5 $state if $state = $oksplit[5];
		set $analog_input_6 $state if $state = $oksplit[6];
		set $analog_input_7 $state if $state = $oksplit[7];
		set $analog_input_8 $state if $state = $oksplit[8];
		set $analog_input_9 $state if $state = $oksplit[9];
		set $analog_input_10 $state if $state = $oksplit[10];
		set $analog_input_11 $state if $state = $oksplit[11];
		set $analog_input_12 $state if $state = $oksplit[12];
		set $analog_input_13 $state if $state = $oksplit[13];
		set $analog_input_14 $state if $state = $oksplit[14];
		set $analog_input_15 $state if $state = $oksplit[15];
		set $analog_input_16 $state if $state = $oksplit[16];
		$battery = ($oksplit[16]/65535)*100;
		$battery = round $battery,0;
		set $battery_level $battery;
		print_log state $battery_level;
	}		
    }
    elsif (@_[0] eq 'move') { #when move done, get new position and then start listening, position data is not retrieved here, it is retrieved in the code directly above this, this only tells er1 to send it.
	if (@_[1] eq 'done') {
		print_log "move done";
		set   $er1client "\n";
		set   $er1client "position";
		set   $er1_moving "stopped";  #can now move again
		set   $er1client "events";
	} 
    }
    elsif (@_[0] eq 'play') {
	if (@_[1] eq 'done') {
		#play done can play new file   *****needs play item like moving item*******
	}
    }
}
	

############################ end of event handling section  ############################





####################################### tk labels ########################################

#this is so you can see what is happening
#awful lot-o code just to get one line of data to show up, but if you I try to define things in one line it dosn't work

my $er1_coordinates_x; #coordinates reported by er1 in cm
$er1_coordinates_x = state $coordinates_x;
my $er1_coordinates_y;
$er1_coordinates_y = state $coordinates_y
my $er1_angle;
$er1_angle = state $er1_direction;
my $er1_label_position;
$er1_label_position = "Position: ER1: $er1_coordinates_x,$er1_coordinates_y  Angle set=$er1_angle measured=$angle | Strabo: $x,$y";  # $x,y defined elsewhere in code
&tk_label(\$er1_label_position);


my $er1_object;
$er1_object = state $object;
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
$label_seen = "Object Recognition: $er1_object with $er1_features_matched/$er1_total_features matched. Position  $er1_object_x,$er1_object_y @ $er1_object_distance cm";
&tk_label(\$label_seen);


my $er1_soundlevel;
$er1_soundlevel = state $soundlevel;
my $er1_speech_text;
$er1_speech_text = state $speech_text;
my $er1_label_sound;
$er1_label_sound = "Sound: Soundlevel $er1_soundlevel | Speech $er1_speech_text";
&tk_label(\$er1_label_sound);

my $er1_battery;
$er1_battery = state $battery_level;
my $er1_label_battery;
$er1_label_battery = "Power:  Er1 battery $er1_battery %";
&tk_label(\$er1_label_battery);



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
$er1_label_analog_a = "Anaolg Inputs:  A1:$a1  A2:$a2  A3:$a3  A4:$a4  A5:$a5  A6:$a6  A7:$a7  A8:$a8";
$er1_label_analog_b = "Anaolg Inputs:  A9:$a9  A10:$a10  A11:$a11  A12:$a12  A13:$a13  A14:$a14  A15:$a15";
&tk_label(\$er1_label_analog_a);
&tk_label(\$er1_label_analog_b);


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
$er1_label_digital = "Digital Inputs:  D1:$d1  D2:$d2  D3:$d3  D4:$d4  D5:$d5  D6:$d6  D7:$d7  D8:$d8";
&tk_label(\$er1_label_digital);




######## strabo stuff, gets path to waypoint and puts into @move array ##################

my $strabo_html; #data returned from strabo route call
my @strabo_html; #same data split into an array
my $strabodata;  #not sure where(if) this is used anymore
my @dirs;        #array of directions for path without commas
my $olddir;	 #used to sort through @dirs
my $newdir;	 #dito
my @dir;	 #new array with each direction only once
my @dis;	 #array with distances corresponding to each element of @dir 
my $counter;     #used to count through @dirs, and other loops
$counter = 0;
my $dis;	 #used so that I can use it in foreach loop to modify @dis
my @moves;	 #use to hold values of @dir and @dis in order that the should be executed.... s,4,n,6....
my $x; 		 #coordinates sent to strabo, they are reversed and offset
my $y;




# sends waypoint stuff to strabo to get route
$v_strabo_path = new  Voice_Cmd("goto: [$Save{waypoints}]");


if ($state = said $v_strabo_path) {
    print_log "Getting strabo path";
    $strabo_html = get "http://$strabo_ip:$strabo_port/getpath?" . $x . "," . $y . "," . $state; #get route
    @strabo_html = split(/\n/, $strabo_html);  #split into lines
    $_ = $strabo_html[3];  #this line has cardinal directions
    s/\[//; # get rid of [
    s/\]//; # get rid of ]
    @dirs = split(/,/, $_);  #new array with elements = dir cardinal directions
    #print @dirs;
    #print "\n";
	#sort through "smooth" data (not path), gets two arrays with directions and distance in that direction
	@dir = ();
	@dis = ();
	$olddir = $dirs[0];
	push (@dir, $dirs[0]);
	push (@dis, 0);	
	while ($counter <= @dirs) {
		$newdir = $dirs[$counter];
			if ($olddir eq $newdir) {
				$dis[$#dis]++
			}
			if ($olddir ne $newdir) {
				push (@dir, $newdir);
				push (@dis, 1);
			}
		$olddir = $newdir;
		$counter++;
	} 
	pop @dis; #gets rid of extra element
	foreach $dis (@dis) {   #convert to inches
		$dis = $dis * 2.4;  #size of my little blocks in strabo
	}
		
	while (@dis) {
		@moves = (@moves , shift @dir);
		@moves = (@moves , shift @dis);
	}


}
#   @moves which is sent to er1 if not moving, each time it moves it deletes member of array


########################### end good strabo get path stuff  ############################################3







############ handle er1 move, get info from strabo array @moves     ##########################
#
#
#	idea here is to know if er is moving and what dir it is pointed in
#	if it is not moving it chews off 1st element of @moves and sends it to er1_move
#	state_now is used in er1_move so it only gets done once
#
###############################################################################################


#move if @move has elements
if (state $er1_moving eq 'stopped' && @moves) {
	set $er1_moving 'moving';
	set $er1_move shift @moves;
}

#item to keep track of weather er1 is moving or not so new moves are only sent if stopped
$er1_moving = new Generic_Item;
my  $er1_moving_states = 'moving,stopped';
set_states  $er1_moving split ',', $er1_moving_states;
set $er1_moving 'stopped' if ($Reread);

#used to store current direction er1 is pointing in  ******needs work*********
$er1_direction = new Generic_Item;
#need to put initial dir and get dir if move toward... executed, plan is to execute short move and calc angle based on start and finish x,y
set $er1_direction 360 if ($Reread);  #not always true but gets me started   !!!!!!! need more work here!!!!!!!



#big daddy, if you change the state of this one, er1 will move
$er1_move = new Generic_Item; 		#state can be n,s,e,w or distance in inches
#if turn set and different than current dir => turn and set new direction, also set moving
# remember diections are reversed the way i set up er1 and strabo
if ($state = state_now $er1_move) {
	if ($state eq 's') {
		if (state $er1_direction == 180) {
			set $er1client "\n";
			set $er1client "move 180 d";
			set $er1client "events";
			set $er1_direction '360';
		}
		elsif (state $er1_direction == 270) {
			set $er1client "\n";
			set $er1client "move 90 d";
			set $er1client "events";
			set $er1_direction '360';
		} 
		elsif (state $er1_direction == 90) {
			set $er1client "\n";
			set $er1client "move -90 d";
			set $er1client "events";
			set $er1_direction '360';
		}
		elsif (state $er1_direction == 360) {
			set $er1_moving 'stopped';
		}
	}
	elsif ($state eq 'n') {
		if (state $er1_direction == 360) {
			set $er1client "\n";
			set $er1client "move 180 d";
			set $er1client "events";
			set $er1_direction '180';
		}
		elsif (state $er1_direction == 270) {
			set $er1client "\n";
			set $er1client "move -90 d";
			set $er1client "events";
			set $er1_direction '180';
		} 
		elsif (state $er1_direction == 90) {
			set $er1client "\n";
			set $er1client "move 90 d";
			set $er1client "events";
			set $er1_direction '180';
		}
		elsif (state $er1_direction == 180) {
			set $er1_moving 'stopped';
		}
	}
	elsif ($state eq 'e') {
		if (state $er1_direction == 180) {
			set $er1client "\n";
			set $er1client "move -90 d";
			set $er1client "events";
			set $er1_direction '90';
		}
		elsif (state $er1_direction == 270) {
			set $er1client "\n";
			set $er1client "move 180 d";
			set $er1client "events";
			set $er1_direction '90';
		} 
		elsif (state $er1_direction == 360) {
			set $er1client "\n";
			set $er1client "move 90 d";
			set $er1client "events";
			set $er1_direction '90';
		}
		elsif (state $er1_direction == 90) {
			set $er1_moving 'stopped';
		}
	}
	elsif ($state eq 'w') {
		if (state $er1_direction == 180) {
			set $er1client "\n";
			set $er1client "move 90 d";
			set $er1client "events";
			set $er1_direction '270';
		}
		elsif (state $er1_direction == 360) {
			set $er1client "\n";
			set $er1client "move -90 d";
			set $er1client "events";
			set $er1_direction '270';
		} 
		elsif (state $er1_direction == 90) {
			set $er1client "\n";
			set $er1client "move 180 d";
			set $er1client "events";
			set $er1_direction '270';
		}
		elsif (state $er1_direction == 270) {
			set $er1_moving 'stopped';
		}
	} else {
		set $er1client "\n";
		set $er1client "move " . $state . " i";
		set $er1client "events";
	}
}

