# Category = Seasonal

##################################################################
#  Christmas Lights                                              #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$Christmas_Lights          = new X10_Item('OG');
$Stairway_Christmas_Lights = new X10_Item('KC');    # On Stairs

if ($New_Minute) {
    if ( time_now("$Time_Sunset - 0:20") ) {
        print_log "Sunset at $Time_Sunset; now dusk, turn on Christmas Lights";
        set $Christmas_Lights ON          if time_cron '* * * 11,12 *';
        set $Stairway_Christmas_Lights ON if time_cron '* * * 11,12 *';
    }
    set $Christmas_Lights OFF if ( time_cron '3,6 0 * * *' );    # Midnight
    set $Stairway_Christmas_Lights OFF if ( time_cron '4,7 1 * * *' );  # One AM
}    # End of New Minute code
