#@Doorbell

=begin comment
Doorbell control.

This code handles both the pressing of a doorbell button and then ringing
the doorbell chime.  Both the button and the chime are connected to a
Weeder DIO board.

The button is actually on a device called a Doorbell Fon which causes the
telephone to ring three times when pressed.  Another device is connected
to the phone line that provides a contact closure when the phone line
rings (the phone line is a dedicated phone line going into a phone system,
not the main phone line for the house).  This code makes sure only one
ring gets through so that the doorbell doesn't ring multiple times.
The weeder module needs the doorbell button input line to be set for
switch input to work in this application.

The chime is connected to the Weeder board via a relay module.

Bill Young
=cut

#----------------------------------------------------------------------------

$doorbell_chime = new Serial_Item( 'AHB', ON, 'weeder' );
$doorbell_chime->add( 'ALB', OFF,      'weeder' );
$doorbell_chime->add( 'ARB', 'status', 'weeder' );

$doorbell_button = new Serial_Item( 'AAH', ON, 'weeder' );
$doorbell_button->add( 'AAL', OFF,     'weeder' );
$doorbell_button->add( 'A!',  'reset', 'weeder' );
$doorbell_button->add( 'ASA', 'init',  'weeder' );

$doorbell_ringing = new Timer;

#----------------------------------------------------------------------------

# At startup, initialize the weeder port for the doorbell (to act as an
# switch input).
if ($Startup) {
    set $doorbell_button 'init';
}

# Just in case the weeder board got disconnected and the reset signal got
# garbled when it came back on, re-initialize it every day.
if ($New_Day) {
    set $doorbell_button 'init';
}

# If we got a reset signal from the weeder board, then we need to initialize
# the port for the doorbell.
if ( state_now $doorbell_button eq 'reset' ) {
    print_log "Resetting doorbell button";
    set $doorbell_button 'init';
}

# If the doorbell button was pressed, then ring the doorbell chime.  The
# DoorBell Fon will ring the the phone line (which is what the weeder
# is connected to) three times.  The doorbell_ringing timer will be set
# on for 10 seconds to make it so that we only get one ring from the
# doorbell chime.
if ( state_now $doorbell_button eq ON ) {
    print_log "Doorbell pressed";
    if ( inactive $doorbell_ringing) {
        set $doorbell_ringing 10;

        $doorbell_chime->set_with_timer( ON, 1, OFF );

        # Turn the porch light on and turn the entry light on for 5 minutes
        # if it's dark.
        if ($Dark) {
            set $porch_light ON;
            $entry_light->set_with_timer( ON, 5 * 60, OFF );
        }
    }
}

# Turn the porch light off at 2am if it was left on.  We don't want to go off
# with a timer based on when the doorbell was pressed in case we are having a
# party and we want to leave the porch light on while people are coming and
# going.
if ( time_now("2:00 AM") ) {
    set $porch_light OFF;
}

#----------------------------------------------------------------------------
