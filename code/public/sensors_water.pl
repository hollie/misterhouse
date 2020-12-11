
=begin comment

From Jeff Pagel on 11/2002

These look like the GRI 2800's as described on this page:

  http://www.grisk.com/specialty/water_sensor2800.htm

I am currently using 2 of these with plans for 3 more.  1 to monitor a
leaky pump and 1 to make sure my water softeners don't spew water in my
basement.  They work quite well with the Weeder io boards.  The only
problem I have had with them is they 'false' trigger due to lightning.  I
used a timer to code around that problem. They are Normally Open(NO)
devices and tend to toggle a lot when they are 'on the edge' of wet, like
when it is drying due to evaporation.

I have included the code I use for them.  It is, of course, a work in
progress.    Any suggestions for improvement would be apreciatted.

No special power or anything.  I just run the black lead to GND and the
Power/signal lead to a weeder input.

I think I may have paid a little less than $15, but that is in the ballpark.

=cut

# Category=Water

#########################################################################
#
# Water sensors
#
# 10/15/02 jdp Add noloop code to init the global time vars,
#           make lightening delay only 1 second
# 10/07/02 jdp Make water softener be like water pump
# 08/11/02 jdp I think the lightning code worked.  I got a 'dry' message
#           during a storm.  To avoid that, only say dry if previously
#           had a real wet.
# 08/06/02 jdp Add code to comensate for lightning strikes
# 07/17/02 jdp Change pump input
# 06/07/02 jdp Add Water sofener and limitied logging
# 02/18/02 jdp Only try to log once per minute, so when drying it off
#               the log doesn't fill with crap.
# 02/17/02 jdp First code, Copied from doors.pl
#
#########################################################################

#########################################################################
# Notes:
#  The GRi 2800 water sensors are NO(Normally Open)
#   Open = 1 on the sensor = Dry = 0 in the log
#   Closed = 0 on the sensor = Wet = 1 in the log
#  WarningMode needs to use bitmaps or an array for multiple warnings
#
#  The GRi 2800's seem to be suspectable to lightening, giving false
#   closures indicating wetness. Try to compensate for this by starting a
#   a timer on first closure and then check it 4 seconds later.
#
#  When the sensors are 'just on the edge' of wet or dry, they toggle fast.
#  Add some 'schmidt trigger' type hystersis to keep the system from
#  overloading.
#
#
#########################################################################

#########################################################################
#
# Globals
#
#########################################################################

my $LastPumpDryTime;
my $LastPumpWetTime;
my $LastSoftDryTime;
my $LastSoftWetTime;

# noloop=start      This directive allows this code to be run on startup/reload
$LastPumpDryTime = $Time_Now;
$LastPumpWetTime = $Time_Now;
$LastSoftDryTime = $Time_Now;
$LastSoftWetTime = $Time_Now;

# noloop=stop

#########################################################################
#
#

#########################################################################
#
# Voice Commands
#
#########################################################################

#########################################################################
#
# Automatic states
#
#########################################################################

##############################################################################
# Water Pump
#
if ( state_now $WB_IL_WaterPump eq OPEN ) {
    if ( time_greater_than("$LastPumpDryTime + 0:01") ) {
        logit( "$config_parms{data_dir}/water/pump.log", "0", "12" );
        $LastPumpDryTime = $Time_Now;
        speak("Water Pump Dry");
    }
}

if ( state_now $WB_IL_WaterPump eq CLOSED ) {
    if ( time_greater_than("$LastPumpWetTime + 0:01") ) {
        set $TimerWaterPump 1, '&WarnWaterPump';
    }
}

# There was a water pump wet indication 4 seconds ago
# Check it again to see if it is still wet.
# If so, assume it is real and not a lightning strike.
sub WarnWaterPump {
    if ( CLOSED eq ( $WB_IL_WaterPump->{state} ) ) {
        print_log("WaterPump Warn WET\n");
        logit( "$config_parms{data_dir}/water/pump.log", "1", "12" );
        $LastPumpWetTime = $Time_Now;
        net_mail_send(
            server  => 'xyz',
            from    => 'xyz',
            to      => 'xyz',
            subject => 'The water pump is leaking!',
            text    => 'hello!'
        );
        speak("Water Pump Wet");
    }
    else {
        speak("Must be lightening Pump");
    }
}

##############################################################################
# Water Softener
#
# Better never happen, so don't bother logging it.
#
if ( state_now $WB_IN_WaterSoft eq OPEN ) {
    if ( time_greater_than("$LastSoftDryTime + 0:01") ) {
        $LastSoftDryTime = $Time_Now;
        speak("Water Softener Dry");

        #        $WarningMode ~= !EMERGENCY_WATER_SOFT;
    }

    #    $WarningMode = 0;
}

if ( state_now $WB_IN_WaterSoft eq CLOSED ) {
    if ( time_greater_than("$LastSoftWetTime + 0:01") ) {
        set $TimerWaterSoft 1, '&WarnWaterSoft';
    }
}

sub WarnWaterSoft {
    if ( CLOSED eq ( $WB_IN_WaterSoft->{state} ) ) {
        $LastSoftWetTime = $Time_Now;
        net_mail_send(
            server  => 'xyz',
            from    => 'xyz',
            to      => 'xyz',
            subject => 'The water softener is eaking!',
            text    => 'hello!'
        );

        #        $WarningMode = 8;
        #        $WarningMode = EMERGENCY_WATER_SOFT;
    }
    else {
        speak("Must be lightening Softener");
    }
}

