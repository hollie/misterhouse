# Category = Master Bedroom

##################################################################
#  Master bedroom items & actions                                #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$Master_Ceiling_Light   = new X10_Item('M1');
$Master_Ceiling_Fan     = new X10_Item('M2');
$Master_Fireplace_Light = new X10_Item('M3');
$Debbie_Lamp            = new X10_Item('M4');
$Debbie_Fan             = new X10_Appliance('M5');
$Danal_Lamp             = new X10_Item('M6');
$Danal_Fan              = new X10_Appliance('M7');
$Master_TV              = new X10_Appliance('M8');

$Master_Bedroom = new Group($Master_Ceiling_Light);
$Master_Bedroom->add($Master_Ceiling_Fan);
$Master_Bedroom->add($Master_Fireplace_Light);
$Master_Bedroom->add($Debbie_Lamp);
$Master_Bedroom->add($Debbie_Fan);
$Master_Bedroom->add($Danal_Lamp);
$Master_Bedroom->add($Danal_Fan);
$Master_Bedroom->add($Master_TV);

$Master_Control = new Serial_Item( 'XC1CJ', 'Read' );
$Master_Control->add( 'XC1CK', 'Sleep' );
$Master_Control->add( 'XC2CJ', 'Sunset' );
$Master_Control->add( 'XC2CK', 'MasterOff' );
$Master_Control->add( 'XC3CJ', 'DanalRead' );
$Master_Control->add( 'XC3CK', 'FerretRead' );
$Master_Control->add( 'XC4CJ', 'R' );
$Master_Control->add( 'XC4CK', 'PublicOff' );
$Master_Control->add( 'XC5CJ', 'CamFront' );
$Master_Control->add( 'XC5CK', 'CamBack' );
$Master_Control->add( 'XC6CJ', 'CamReserved' );
$Master_Control->add( 'XC6CK', 'CamDrive' );
$Master_Control->add( 'XC7CJ', 'WeatherCond' );
$Master_Control->add( 'XC7CK', 'WeatherFcst' );
$Master_Control->add( 'XC8CJ', 'SecurityIn' );
$Master_Control->add( 'XC8CK', 'SecurityAll' );

if ($New_Minute) {
    if ( time_now("$Time_Sunset - 0:30") ) {
        print_log
          "Sunset at $Time_Sunset; now dusk, set up Master Bedroom for evening";
        set $Debbie_Lamp ON;
        set $Danal_Lamp ON;
    }
    &master_morning if ( time_cron '0,5 8 * * 1-5' );     #  8 AM on weekdays
    &master_morning if ( time_cron '0,5 11 * * 0,6' );    # 11 AM on weekends
}    # End of New Minute code

if ( state_now $Master_Control) {
    my $state = state $Master_Control;
    print_log "Master Bedroom Button $state";
    if ( $state eq 'Read' ) {
        set $Debbie_Lamp ON;
        set $Danal_Lamp ON;
        set $Debbie_Fan ON;
        set $Danal_Fan ON;
    }
    if ( $state eq 'Sleep' ) {
        set $Debbie_Lamp OFF;
        set $Danal_Lamp OFF;
        set $Debbie_Fan ON;
        set $Danal_Fan ON;
        &speak(
            mode   => 'unmuted',
            volume => 10,
            text   => "Good Night, sleep tight. Don't let the bed bugs bite!"
        );
        $Save{mode} = 'mute';
    }
    if ( $state eq 'Sunset' ) {
        set $Debbie_Lamp ON;
        set $Danal_Lamp ON;
        set $Debbie_Fan OFF;
        set $Danal_Fan OFF;
    }
    if ( $state eq 'MasterOff' ) {
        set $Debbie_Lamp OFF;
        set $Danal_Lamp OFF;
        set $Debbie_Fan OFF;
        set $Danal_Fan OFF;
        $Save{mode} = 'normal';
        &speak(
            mode   => 'unmuted',
            volume => 60,
            text   => "Djeeni is set to $Save{mode} speech mode"
        );
    }
    if ( $state eq 'DanalRead' ) {
        set $Debbie_Lamp OFF;
        set $Danal_Lamp ON;
        set $Debbie_Fan ON;
        set $Danal_Fan ON;
    }
    if ( $state eq 'FerretRead' ) {
        set $Debbie_Lamp ON;
        set $Danal_Lamp OFF;
        set $Debbie_Fan ON;
        set $Danal_Fan ON;
    }
    if ( $state eq 'PublicOff' ) {
        set $Kitchen OFF;
    }
    if ( $state eq 'CamBack' ) {
        run_voice_cmd 'Camera Back';
    }
    if ( $state eq 'CamFront' ) {
        run_voice_cmd 'Camera Front';
    }
    if ( $state eq 'CamDrive' ) {
        run_voice_cmd 'Camera Drive';
    }
    if ( $state eq 'WeatherCond' ) {
        run_voice_cmd 'Read internet weather conditions';
    }
    if ( $state eq 'WeatherFcst' ) {
        run_voice_cmd 'Read internet weather forecast';
    }
    if ( $state eq 'SecurityIn' ) {
        set $Kitchen ON;
    }
    if ( $state eq 'SecurityAll' ) {
        set $Kitchen ON;
        run_voice_cmd 'Camera Front';
    }

}    # End of button pressed on master control

sub master_morning {
    print_log "Master Bedroom Morning routine";
    my ( $date, $time, $state ) =
      ( state_log $Master_Control)[0] =~ /(\S+) (\S+) *(.*)/;
    use Time::ParseDate;
    my $tnow  = parsedate('now');
    my $tmst  = parsedate("$date $time");
    my $tdiff = $tnow - $tmst;
    print_log
      "Master Control Timers: Last date/time $date $time, seconds $tmst, secs now $tnow, diff $tdiff";

    if ( $tdiff < 6 * 60 * 60 ) {
        print_log
          "Master Control manipulated this morning; morning routine automation canceled";
    }
    else {
        set $Debbie_Fan OFF;
        set $Danal_Fan OFF;
        set $Debbie_Lamp OFF;
        set $Danal_Lamp OFF;
        $Save{mode} = 'normal';
        &speak(
            mode   => 'unmuted',
            volume => 60,
            text   => "Djeeni is set to $Save{mode} speech mode"
        );
    }
}    # End of sub master_morning
