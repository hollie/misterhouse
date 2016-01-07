# Category=Alarm

#@ DSCMotion.pl version 1.0,
#@ Motion detection and automatic light controls
# $Revision$
# $Date$

#---------------------------------------------------------------------------------------
if ( $Startup || $Reload ) {

    #use DSC5401;		# This command will be starting by DSC5401startup.pl
    #$DSC = new DSC5401;	# This command will be starting by DSC5401startup.pl
    # if NOT, this following code are needed to operate...!

    print_log "Starting DSC Motion module...";

    #--- Define Timers Variables
    #
    $IR_Entre_Cote_Timer   = new Timer();
    $IR_Cuisine1_Timer     = new Timer();
    $IR_Salon_Timer        = new Timer();
    $IR_Corridor_Timer     = new Timer();
    $IR_Salle_Manger_Timer = new Timer();
    $IR_Toilette_Timer     = new Timer();
    $IR_Chambre_M_Timer    = new Timer();
    $IR_Chauffage_Timer    = new Timer();
    $IR_Salon_SS_Timer     = new Timer();
    $IR_Atelier_Timer      = new Timer();
    $IR_Bureau_SS_Timer    = new Timer();
    $IR_Chambre2_Timer     = new Timer();
    $IR_Rangement_Timer    = new Timer();

    my $State_Light = "";
}    #--- End of Reload or Startup

#
#---------------------------------------------------------------------------------------
#
if ( time_now '$Time_Sunset' ) {
    $Dark = 1;
}

#---------------------------------------------------------------------------------------
#-- 24 Hour motion control
#
#--- R A N G E M M E N T
#
if ( $DSC->{zone_status}{13} eq "open" ) {
    $State_Light = state $Rangement;
    if ( $State_Light eq OFF ) {
        set $Rangement ON;
    }
    if ( active $IR_Rangement_Timer) { unset $IR_Rangement_Timer }
    set $IR_Rangement_Timer 150;
}

#---------------------------------------------------------------------------------------
#-- Night Only motion control
#
if ( $Dark eq 1 ) {

    #--- Execute Zone Motion with Light

    #--- S A L O N  S O U S - S O L
    #
    if ( $DSC->{zone_status}{10} eq "open" ) {

        #print_log "activite DSC motion zone 10";
        $State_Light = state $Cinema_Lumiere_Sofa;
        if ( $State_Light eq OFF ) {
            set $Cinema_Lumiere_Sofa -40
              if Time_Schedule( $Time_Sunset, "23:59" );
            set $Cinema_Lumiere_Sofa -50
              if Time_Schedule( "00:00", $Time_Sunrise );
        }

        $State_Light = state $Cinema_Lumiere_Foyer;
        if ( $State_Light eq OFF ) {
            set $Cinema_Lumiere_Foyer -40
              if Time_Schedule( $Time_Sunset, "23:59" );
            set $Cinema_Lumiere_Foyer -50
              if Time_Schedule( "00:00", $Time_Sunrise );
        }

        if ( active $IR_Salon_SS_Timer) {
            unset $IR_Salon_SS_Timer;
        }
        set $IR_Salon_SS_Timer 600 if Time_Schedule( $Time_Sunset, "23:59" );
        set $IR_Salon_SS_Timer 180
          if ( Time_Schedule( "00:00", $Time_Sunrise ) && ( $Weekday == 1 ) );
        set $IR_Salon_SS_Timer 300
          if ( Time_Schedule( "00:00", $Time_Sunrise ) && ( $Weekday == 0 ) );
    }

    #--- B U R E A U
    #
    if ( $DSC->{zone_status}{12} eq "open" ) {

        #print_log "Bureau motion is Now:($Time)" if time_between '8 pm', '11 pm';

        #	$State_Light = state $Chambre_2;
        #	if ($State_Light eq OFF)
        #	{
        #		set $Chambre_2 ON;
        #	}
        #	if (active $IR_Chambre2_Timer) { unset $IR_Chambre2_Timer }
        #	   set $IR_Chambre2_Timer 15;
    }

    #--- C O R R I D O R
    #
    if ( $DSC->{zone_status}{4} eq "open" ) {
        $State_Light = state $Corridor_Lumiere;
        if ( $State_Light == -95 ) {
            set $Corridor_Lumiere +25 if Time_Schedule( $Time_Sunset, "22:00" );
            set $Corridor_Lumiere +15 if Time_Schedule( "22:00",      "23:00" );

            #set $Corridor_Lumiere +15 if Time_Schedule("00:00",$Time_Sunrise);
        }
        if ( $State_Light eq OFF ) {
            set $Corridor_Lumiere -95;
        }
        if ( active $IR_Corridor_Timer) {
            unset $IR_Corridor_Timer;
        }
        set $IR_Corridor_Timer 300;
    }

    #--- C U I S I N E
    #
    if ( $DSC->{zone_status}{2} eq "open" ) {
        $State_Light = state $Cuisine_Lumiere;
        if ( $State_Light eq OFF ) {
            set $Cuisine_Lumiere -40 if Time_Schedule( $Time_Sunset, "22:00" );
            set $Cuisine_Lumiere -45 if Time_Schedule( "22:00",      "23:59" );
            set $Cuisine_Lumiere -50 if Time_Schedule( "00:00", $Time_Sunrise );
        }
        if ( active $IR_Cuisine1_Timer) { unset $IR_Cuisine1_Timer }
        set $IR_Cuisine1_Timer 600 if Time_Schedule( $Time_Sunset, "21:00" );
        set $IR_Cuisine1_Timer 300 if Time_Schedule( "21:00",      "23:59" );
        set $IR_Cuisine1_Timer 120 if Time_Schedule( "00:00", $Time_Sunrise );
    }

    #--- T O I L E T T E
    #
    if ( $DSC->{zone_status}{6} eq "open" ) {
        my $State_Light = state $Toilette;
        if ( $State_Light == -95 ) {
            set $Toilette +45 if Time_Schedule( $Time_Sunset, "22:30" );
            set $Toilette +15 if Time_Schedule( "22;30",      "23:59" );
            set $Toilette +15 if Time_Schedule( "00:00",      $Time_Sunrise );
        }
        if ( $State_Light eq OFF ) {
            set $Toilette -95;
        }
        if ( active $IR_Toilette_Timer) { unset $IR_Toilette_Timer }
        set $IR_Toilette_Timer 600 if Time_Schedule( $Time_Sunset, "23:00" );
        set $IR_Toilette_Timer 300 if Time_Schedule( "23:00",      "23:59" );
        set $IR_Toilette_Timer 200 if Time_Schedule( "00:00", $Time_Sunrise );
    }

    #--- E N T R E   C O T E
    #
    if ( $DSC->{zone_status}{1} eq "open" ) {
        $State_Light = state $Entre_Cote;
        if ( $State_Light eq OFF ) {
            set $Entre_Cote -50 if Time_Schedule( $Time_Sunset, "22:00" );
            set $Entre_Cote -50 if Time_Schedule( "22:00",      "23:59" );
            set $Entre_Cote -60 if Time_Schedule( "00:00",      $Time_Sunrise );
        }
        if ( active $IR_Entre_Cote_Timer) { unset $IR_Entre_Cote_Timer }
        set $IR_Entre_Cote_Timer 600 if Time_Schedule( $Time_Sunset, "21:00" );
        set $IR_Entre_Cote_Timer 300 if Time_Schedule( "21:00",      "23:59" );
        set $IR_Entre_Cote_Timer 200 if Time_Schedule( "00:00", $Time_Sunrise );
    }
}    #--- If Dark
#
#---------------------------------------------------------------------------------------
#--- EXPIRED TIME SETUP
#--- Closing Light with when Timeout
#
if ($New_Minute) {
    if ( expired $IR_Salon_SS_Timer && $Holiday eq 0 ) {
        set $Cinema_Lumiere_Sofa OFF  if Time_Schedule( "16:00", "19:00" );
        set $Cinema_Lumiere_Foyer OFF if Time_Schedule( "16:00", "19:00" );

        set $Cinema_Lumiere_Sofa OFF
          if ( Time_Schedule( "23:31", "23:59" ) && ( $Weekday == 1 ) );
        set $Cinema_Lumiere_Foyer OFF
          if ( Time_Schedule( "23:31", "23:59" ) && ( $Weekday == 1 ) );

        set $Cinema_Lumiere_Sofa OFF if Time_Schedule( "00:00", $Time_Sunrise );
        set $Cinema_Lumiere_Foyer OFF
          if Time_Schedule( "00:00", $Time_Sunrise );
    }

    if ( expired $IR_Corridor_Timer) {
        set $Corridor_Lumiere -95;
    }

    if ( expired $IR_Cuisine1_Timer && $Holiday eq 0 ) {
        set $Cuisine_Lumiere OFF if Time_Schedule( $Time_Sunset, "23:59" );

        #set $Cuisine_Lumiere OFF if Time_Schedule("21:00","23:59");
        set $Cuisine_Lumiere OFF if Time_Schedule( "00:00", $Time_Sunrise );
    }

    if ( expired $IR_Toilette_Timer) {
        set $Toilette -95;
    }

    if ( expired $IR_Entre_Cote_Timer) {
        set $Entre_Cote OFF;
    }

    if ( expired $IR_Rangement_Timer) {
        set $Rangement OFF;
    }

    #if (expired $IR_Chambre2_Timer)
    #{
    #      set $Chambre_2 OFF if Time_Schedule("20:00","22:00");
    #}

}    # New minutes for Timers

#---------------------------------------------------------------------------------------

sub Time_Schedule {

    #-- Setup Variable
    #
    my ( $time1, $time2 ) = @_;
    my $Time_Start = my_str2time($time1);
    my $Time_Stop  = my_str2time($time2);

    if ( $Time_Stop <= $Time_Start ) {
        print_log
          "Error Time Schedule Stop:($Time_Stop) <= Start:($Time_Start)";
        return 0;
    }
    elsif ( ( $Time >= $Time_Start ) && ( $Time <= $Time_Stop ) ) {

        #print_log "Match for Time Schedule Now:($Time) Start:($Time_Start) Stop:($Time_Stop)";
        return 1;
    }
    else {
        #print_log "Out of Time Schedule Now:($Time) Start:($Time_Start) Stop:($Time_Stop)";
        return 0;
    }
}

#---------------------------------------------------------------------------------------
