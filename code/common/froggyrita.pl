# Category = HVAC

use strict;
use FroggyRita;

my $command_waiting;    #noloop

$Froggy = new FroggyRita;
$v_froggy_indoor_temperature =
  new Voice_Cmd( '[What is] the indoor temperature', 0 );
$v_froggy_indoor_humidity = new Voice_Cmd( '[What is] the indoor humidity', 0 );
$v_froggy_indoor_check    = new Voice_Cmd( 'Check indoor conditions',       0 );

if ( said $v_froggy_indoor_check) {
    respond "app=frog Checking indoor conditions...";
    $command_waiting = $v_froggy_indoor_check;
    set $Froggy 'status', $v_froggy_indoor_check;
}

if ( said $v_froggy_indoor_temperature) {

    if ( defined $Weather{TempIndoor} ) {
        respond
          "app=frog It is $Weather{TempIndoor} degrees fahrenheit indoors.";
    }
    else {
        respond
          "app=frog I don't know the temperature at the moment. Try again in a few minutes...";
    }

}

if ( my $state = said $v_froggy_indoor_humidity) {
    if ( defined $Froggy->humidity() ) {
        respond "app=frog It is " . $Froggy->humidity() . "% indoors.";
    }
    else {
        respond
          "app=frog I do not know at the moment. Try again in a few minutes...";
    }

}

if ( my $state = state_now $Froggy) {
    my $temperature = $Froggy->temperature();

    $temperature =
        ( $config_parms{weather_uom_temp} eq 'C' )
      ? ( int( $temperature * 100 + .5 ) / 100 )
      : int( ( ( $temperature * 180 ) + 3200 ) + .5 ) / 100
      if defined $temperature;

    if ( $command_waiting and $state ne 'status' ) {
        if ( defined $temperature ) {
            $command_waiting->respond(
                    'app=frog connected=0 Indoor temperature is '
                  . $temperature
                  . ' degrees fahrenheit. Humidity is '
                  . $Froggy->humidity()
                  . '%' );
        }
        else {
            $command_waiting->respond(
                'app=frog connected=0 I do not know at the moment. Try again in a few minutes...'
            );

        }
        $command_waiting = undef;
    }
    $Weather{TempIndoor}  = $temperature        if defined $temperature;
    $Weather{HumidIndoor} = $Froggy->humidity() if defined $Froggy->humidity();
}

sub get_froggy_status {
    set $Froggy 'status', 'time';
}

# trigger

if ($Reload) {
    &trigger_set(
        "new_minute 5", "&get_froggy_status()",
        'NoExpire',     'get frog status'
    ) unless &trigger_get('get frog status');
}
