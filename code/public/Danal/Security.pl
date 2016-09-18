# Category = Security

if ($New_Minute) {
    if ( time_cron '32,38 23 * * *' ) {
        print_log "Security Master Bedroom OFF";
        set $Debbie_Fan OFF;
        set $Danal_Fan OFF;
        set $Debbie_Lamp OFF;
        set $Danal_Lamp OFF;
    }
    if ( time_cron '12,14 18 * * *' ) {
        print_log "Security Danal Office ON";
        set $Danal_Can_Light ON;
    }
    if ( time_cron '3,14 23 * * *' ) {
        print_log "Security Danal Office OFF";
        set $Danal_Can_Light OFF;
    }

    if ( time_cron '17,26 17 * * *' ) {
        print_log "Security Kitchen ON";
        set $Kitchen_Breakfast_Light ON;
    }
    if ( time_cron '28,57 22 * * *' ) {
        print_log "Security Kitchen OFF";
        set $Kitchen_Breakfast_Light OFF;
    }

}    # End of New Minute code

