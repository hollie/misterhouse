
=begin comment

From Gary Sanders, on 01/2003

> I have a light I want to turn on between the hours of 12:00 am and 7:00 am
> if motion is detected by one of my motion sensors.

Here's what I used to use in my previous house. It had a couple of 
functions:

Between dusk and dawn, if movement was detected on motion detector 1, it 
would turn on carport light 1 for 4 minutes.

In addition, between 9 PM and 'sunrise + 5 minutes', it would also turn 
on the screen room and walk lights for 4 minutes.

If motion was detected during the 4 minute period, the timer would be 
reset and count for another 4 minutes, leaving the lights on. At the end 
of 4 minutes with no movement detected, the timer would expire and turn 
off the screen room and walk lights. Again, there is a test for 9 PM to 
sunrise to turn off the screen room and walk lights.

Note an 'OFF' code from the motion detector is not used at all to 
control the above group of lights - they are turned off strictly by the 
timer.

------

Carport 2 is just a simple sensor and light triggered by ON and OFF codes.

-----

By the way, most of this code isn't original to me - my Perl coding 
skills are virtually nonexistent. This is modification of code either 
posted as examples on Bruce's site or culled from old postings here, 
plus MUCH trial and error testing on my part.

One other disclaimer: The description above is as I remember it's 
operation from a year ago. Since my memory is about like my Perl coding 
skills - nil, YMMV.

=cut

#  X10 motion Sensors

$motion = new Serial_Item( 'XIJ', ON );
$motion->add( 'XIK', OFF );

$motion_unit->add( 'XI5', 'carport sense 1' );
$motion_unit->add( 'XI6', 'carport sense 1 dark' );
$motion_unit->add( 'XI8', 'carport sense 2' );

#------- Carport Sensor 1 (By front screen door) ------

$timer_carport1 = new Timer();

if ( state_now $motion eq ON ) {
    if ( ( state $motion_unit) eq 'carport sense 1' ) {
        if ( inactive $timer_carport1) {
            if (   ( time_greater_than '09:00 PM' )
                or ( time_less_than("$Time_Sunrise + 0:05") ) )
            {
                set $walk_light ON;
                print "Walk light on";
                speak("walk light on");
                set $screen_room_lights '90%';
                print "screen room lights on";
                speak("screen room lights on");
            }
            set $carport_light1 ON;
            print "carport sensor 1 movement detected - carport light on";
            speak("carport sensor 1 movement detected - carport light on");
        }
        set $timer_carport1 240;
    }
}

if ( expired $timer_carport1) {
    if (   ( time_greater_than '09:00 PM' )
        or ( time_less_than("$Time_Sunrise + 0:30") ) )
    {
        set $walk_light OFF;
        print "Walk light off";
        speak("walk light off");
        set $screen_room_lights OFF;
        print "screen room lights off";
        speak("screen room lights off");
    }
    set $carport_light1 OFF;
    print "carport light 1 off";
    speak("carport light 1 off");
}

#------- Carport Sensor 2 (Front of shed) -------

$timer_carport2 = new Timer();

if ( state_now $motion eq ON ) {
    if ( ( state $motion_unit) eq 'carport sense 2' ) {
        if ( inactive $timer_carport2) {

            #set $x10_sounder ON;
            print "carport sensor 2 movement detected - light on";
            speak("carport sensor 2 movement detected - light on");
        }
        set $timer_carport2 15;
    }
}

if ( state_now $motion eq OFF ) {
    if ( ( state $motion_unit) eq 'carport sense 2' ) {

        #set $x10_sounder ON;
        print "carport sensor 2 OFF code received";
        speak("carport sensor 2 OFF code received");
    }
}

