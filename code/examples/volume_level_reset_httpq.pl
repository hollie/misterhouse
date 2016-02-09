# Comment at the bottom

# Category=All

$movement_sensor = new Serial_Item( 'XAJ', ON );    # Need ON and OFF
$movement_sensor->add( 'XAK', OFF );    # Just once to control all Hawkeyes
$movement_sensor_unit = new Serial_Item( 'XA4', 'office' )
  ;    # Add one line per Hawkeye, Set code to Hawkeye
$movement_sensor_unit->add( 'XA5', 'frontdoor' );
$movement_sensor_unit->add( 'XA6', 'pool' );
$movement_sensor_unit->add( 'XA7', 'serverroom' );

$timer_office      = new Timer();    # Set one timer per Hawkeye
$timer_front_door  = new Timer();
$timer_pool        = new Timer();
$timer_server_room = new Timer();

if ( state_now $movement_sensor eq ON ) {
    if ( ( state $movement_sensor_unit) eq 'frontdoor' ) {
        if ( inactive $timer_front_door) {
            my $mp3_status = get "http://ipaddress:port/isplaying?p=password";
            print_log $mp3_status ;
            if ( $mp3_status == 1 ) {
                get "http://ipaddress:port/PAUSE?p=password";
            }
            play( 'file' => $config_parms{front_door} );
            if ( active $timer_pool) {
                set $pool_chimes ON;
            }
            sleep 3;
            play( 'file' => $config_parms{front_door} );
            sleep 2;
            if ( $mp3_status == 1 ) {
                get "http://ipaddress:port/volumedown?p=password";
                get "http://ipaddress:port/PLAY?p=password";
                get "http://ipaddress:port/volumeup?p=password";
            }
        }
        set $timer_front_door 90;
    }
    if ( ( state $movement_sensor_unit) eq 'pool' ) {
        if ( inactive $timer_pool) {

            # Don't need the Winamp routines here since I already have it in mh_sound.pl
            speak("Someone is in the pool area");
        }
        set $timer_pool 60 * 25;
    }
}

=begin comment


Next problem I had was if Winamp was playing at my desired sound level, and
MH made any sounds, the Winamp level went way up.  I had to either click on
the volume control slider of Winamp or have MH lower and then raise the
volume level to have it go back to the previous desired level.  Tonight I
added in some lines to mh_sound.pl and my own hawkeyes.pl routines.

NOTE:  This works only if you control Winamp with HTTPQ!
(I hard coded my IP address, port, and password, so you will need to make
those changes).


Quick explanation of the above code:
Lines 42 - 48 is for the pool timer...if someone is detected in the pool
area, the timer is set for 25 minutes (60 * 25).  This is important for the
front door sensor. (by the way, because of the placement of 'set $timer_pool
60 * 25;', every time movement is detected in the pool area, the timer is
reset for 25 minutes, irregardless if the timer is active or inactive.)

Line 20 - 32 will be whenever the front door Hawkeye kicks off...and the
timer is not active (see line 39 for active status).  We also check the
status of Winamp.  Since the timer is inactive, we set the Winamp to pause
(if it was playing, make the sound, and check the status of the pool timer,
making it kickoff if someone is there, and then playing the sound again
(yes, I know the door sound goes off twice in this routine...I found that
when I was WATCHING a star trek show, and someone walked up to a door in the
show (making the sound of someone at the door) I would get up and check MY
front door, only to find no one there ;-)  Line 33 - 37 will start Winamp
back up if it was playing prior to the Hawkeye's starting up.

Line 39 will reset the front door timer to 90 seconds irregardless if the
timer was active or inactive (this way, if your teenage son is sitting out
there with his girlfriend, the sound won't be kicking off every 90 seconds!)

=cut

