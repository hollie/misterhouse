# Category=ER1

#This is a code for the evolution robotics ER1 robot.  The robot has visual and speech recognition and can do lots - o 
#cool stuff. the software that comes with ER1 is very good at getting you up and running but soon falls short. 
#The Robot Control Software, RCC, provides for API interface and I have taken advantage of a misterhouse socket item.
#this program starts a client, turns on sensors, gets position and then starts listening for data from the ER1.
#data is put into variables and action is taken elsewhere in other code files.  ie, i have my robot feel like he 
#is getting attention when sensed soundlevel is above 2.

#$desire_social = $desire_social + 1 if state_now $soundlevel > 2 && $desire_social < 100;

#even though sound level remains above 2 until changed by some new input, I only increase my variable once by using state_now


#strabo is a piece of software that is used for pathfinding, you give it a map of your home, tell it where you are and it
#will tell you how to get form A to B. very cool. this code, if it does not already have the strabo call, it will soon.
#also code for getting data from robots digital and analog ports not done yet.


#I am using kind-of-a "SIMS" model (elsewhere) in my code. The robot has needs that slowly decay over time and his mood
#gets worse until these are met.  ie. it moves slower when  he needs  battery charge, or really wants one the lower his "energy level" gets


# If you can't already tell from my ramblings
# this is my first ever attempt at making something i plan to share with others
# because I am a NEeeeeeeWBIE, and I am sure that this could be written better, 
# I have tried to explain everything I was doing as it happens, im sure this will drive some of you crazy
 
# my name is Dave Hall whall@marshall.edu
# Bruce (mh) and Davee (Strabo) you guys rule
# we'll call this version 1, the date is 3/29/04

# to do list
# get angle
# parse strabo data and change it to move command - done, needs testing
# need a 'get angle' routine, er1 manual says it sends it but (according to my experiments and whats on the er1 fourum) it doesn't, it does know the angle because it properly keeps track of x,y
# play item like er1_moving item [playing,stopped]







#change ip address, can use local host if running on same machine
my $er1client_address = '192.168.1.102:9000';
$er1client = new  Socket_Item(undef, undef, $er1client_address);



	
####################    do on startup  ##################################3

	stop $er1client if active $er1client && ($Reread); #this way, always starts from same place, the error from trying to open port that is already open, messes up some of "timing" these rapid fire commands, not really sure what i am talking about, but it works if you do it this way.
	print_log "Starting conncetion to ER1" if ($Reread);
	start $er1client if ($Reread);
	print_log "Turning on ER1 object sense" if ($Reread);
	set   $er1client "sense objects" if ($Reread);
	print_log "Turning on ER1 sound sense" if ($Reread);
	set $er1client "sense sound level" if ($Reread);
	print_log "Turning on ER1 speech sense" if ($Reread);
	set   $er1client "sense speech" if ($Reread);
	print_log "listening on ER1 port" if ($Reread);
	set   $er1client "position" if ($Reread);
	set   $er1client "events" if ($Reread);




###########  some testing stuff I wan't in the tk interface  ############

#disconnect
$v_er1_disconnect = new  Voice_Cmd("disconnect");
if ($state = said $v_er1_disconnect) {
    print_log "Disconnecting from ER1";
    stop  $er1client;
    }


$v_move_er1client = new  Voice_Cmd("move: [forward,backward,turn left,turn right]");
if ($state = said $v_move_er1client) {
    print_log "Running $state";
    if ($state eq 'forward') {
       #start $er1client;
       set   $er1client "\n";   # this assumes that client is running and listening for events.  to stop listening for events use \n, then restart "events" after command issued 
       set   $er1client "move 6 i";
       set   $er1client "events";
    }

    elsif ($state eq 'backward') {
       print_log "Running $state";
       #start $er1client;
       set   $er1client "\n";
       set   $er1client "move -6 i";
       set   $er1client "events";
    }
    elsif ($state eq 'turn left') {
       print_log "Running $state";
       #start $er1client;
       set   $er1client "\n";
       set   $er1client "move 90 d";
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



#get position, results put into coordinates when listening for events, mh automatically updates position for itself and strabo when move done recieved
$v_position_er1client = new  Voice_Cmd("get: [position]");
if ($state = said $v_position_er1client) {
    print_log "Running $state";
    if ($state eq 'position') {
       #start $er1client;
       set   $er1client "\n";
       set   $er1client "position";
       set   $er1client "events";
    }
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
$coordinates_x = new Generic_Item;
$coordinates_y = new Generic_Item;
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
	set $coordinates_x $state if $state = $oksplit[1];
	set $coordinates_y $state if $state = $oksplit[2];
	$x = (state $coordinates_y)/6.1 + 16; #convert to units use on my  strabo map
	$x = round $x,1;
	$y = (state $coordinates_x)/6.1 + 6; #convert to units use on my strabo map
	$y = round $y,1;
	$strabo_html = get "http://localhost:80/Setposition?" . $x . "," . $y; #tells strabo to update position
	#print_log "strabo data: $strabo_html";
	#print_log state $coordinates_x; 
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





####################################### tk stuff   ########################################

#this is so you can see what is happening, I don't know why but my tk interface never shows the last entry item, so i just put last one twice.
&tk_entry(
	"sndlvl", $soundlevel,
	"heard", $speech_text,
	"x", $coordinates_x,
	"y", $coordinates_y,
	"y", $coordinates_y
	);
&tk_entry(
	"seen", $object,
	"@", $object_distance,
	"@", $object_distance
	);

#&tk_entry ("angle state",$er1_direction);



######## strabo stuff, gets path to waypoint and puts into @move array ##################

my $strabo_html; #data returned from strabo route call
my @strabo_html; #same data split into an array
my $strabodata;  #not sure where this is used
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



$v_strabo_path = new  Voice_Cmd("goto: [charging,bedroom,hallway1,hallway2]"); #states are waypoints, have to match strabo

if ($state = said $v_strabo_path) {
    print_log "Getting strabo path";
    $strabo_html = get "http://localhost:80/getpath?" . $x . "," . $y . "," . $state; #get route
    @strabo_html = split(/\n/, $strabo_html);  #split into lines
    $_ = $strabo_html[3];  #this line has cardinal directions
    s/\[//; # get rid of [
    s/\]//; # get rid of ]
    @dirs = split(/,/, $_);  #new array with elements = dir cardinal directions
    #print @dirs;
    #print "\n";
	#sort through "smooth" data, gets two arrays with directions and distance in that direction
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
	#foreach (@moves) {
	#	print $_;
	#	print "\n";
	#}

}
#@moves which is sent to er1 if not moving, each time it moves it deletes member of array


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
	print_log "?? stopped," . state $er1_moving;
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
set $er1_direction 360 if ($Reread);  #not always true but gets me started


#big daddy, if you change the state of this one, er1 will move
$er1_move = new Generic_Item; 		#state can be n,s,e,w or distance in inches
#if turn set and different than current dir => turn and set new direction, also set moving
# remember diections are reversed the way i set up er1 and strabo
if ($state = state_now $er1_move) {
	print_log "i am " . state $er1_moving;
	if ($state eq 's') {
		print_log "turning $state";
		if (state $er1_direction == 180) {
			set $er1client "\n";
			set $er1client "move 180 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '360';
		}
		elsif (state $er1_direction == 270) {
			set $er1client "\n";
			set $er1client "move 90 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '360';
		} 
		elsif (state $er1_direction == 90) {
			set $er1client "\n";
			set $er1client "move -90 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '360';
		}
		elsif (state $er1_direction == 360) {
			set $er1_moving 'stopped';
		}
	}
	elsif ($state eq 'n') {
		print_log "turning $state";
		if (state $er1_direction == 360) {
			set $er1client "\n";
			set $er1client "move 180 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '180';
		}
		elsif (state $er1_direction == 270) {
			set $er1client "\n";
			set $er1client "move -90 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '180';
		} 
		elsif (state $er1_direction == 90) {
			set $er1client "\n";
			set $er1client "move 90 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '180';
		}
		elsif (state $er1_direction == 180) {
			set $er1_moving 'stopped';
		}
	}
	elsif ($state eq 'e') {
		print_log "turning $state";
		if (state $er1_direction == 180) {
			set $er1client "\n";
			set $er1client "move -90 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '90';
		}
		elsif (state $er1_direction == 270) {
			set $er1client "\n";
			set $er1client "move 180 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '90';
		} 
		elsif (state $er1_direction == 360) {
			set $er1client "\n";
			set $er1client "move 90 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '90';
		}
		elsif (state $er1_direction == 90) {
			set $er1_moving 'stopped';
		}
	}
	elsif ($state eq 'w') {
		print_log "turning $state";
		if (state $er1_direction == 180) {
			set $er1client "\n";
			set $er1client "move 90 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '270';
		}
		elsif (state $er1_direction == 360) {
			set $er1client "\n";
			set $er1client "move -90 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '270';
		} 
		elsif (state $er1_direction == 90) {
			set $er1client "\n";
			set $er1client "move 180 d";
			#set $er1_moving 'moving';
			set $er1client "events";
			set $er1_direction '270';
		}
		elsif (state $er1_direction == 270) {
			set $er1_moving 'stopped';
		}
	} else {
		print_log "moving $state";
		set $er1client "\n";
		set $er1client "move " . $state . " i";
		#set $er1_moving 'moving';
		set $er1client "events";
	}
}

