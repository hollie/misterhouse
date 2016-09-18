# Category = iButtons
use iButton;

$v_iButton_list = new Voice_Cmd "List all the iButton buttons";
$v_iButton_list->set_info(
    'Lists the family and ID codes of all the buttons on the bus');
$v_iButton_connect = new Voice_Cmd "[Connect,Disconnect] to the iButton bus";

sub usleep {
    my ($usec) = @_;

    #   print "sleep2 $usec\n";
    select undef, undef, undef, ( $usec / 10**6 );
}

# List all iButton devices
if ( said $v_iButton_list) {
    print_log "Reading iButton device list";
    my @ib_list = &iButton::scan;
    speak $#ib_list + 1 . " iButtons found";
    for my $ib (@ib_list) {
        print_log "Device type:"
          . $ib->family . "  ID:"
          . $ib->serial
          . "  CRC:"
          . $ib->crc, ": " . $ib->model();
    }
}

if ( $state = said $v_iButton_connect) {
    if ( $state eq 'Connect' ) {
        print_log &iButton::connect( $config_parms{iButton_port} );
    }
    else {
        print_log &iButton::disconnect;
    }
}

&tk_label( \$weather{Summary} );
&tk_label( \$weather{SummaryWind} );
&tk_label( \$weather{SummaryRain} );

# Pick how often to check the bus ... it takes about 6 ms per device.
#&iButton::monitor;
#&iButton::monitor if $New_Second;

$ib_wind_relay = new iButton '12000000139ce5';

$ib_wind_n  = new iButton '010000044a4b8a';
$ib_wind_ne = new iButton '010000044a4b8d';
$ib_wind_e  = new iButton '010000044a4b7e';
$ib_wind_se = new iButton '010000044a4b7b';
$ib_wind_s  = new iButton '010000044a4b78';
$ib_wind_sw = new iButton '010000044a4b75';
$ib_wind_w  = new iButton '010000044a4b81';
$ib_wind_nw = new iButton '010000044a4b87';

my %wind_dir = (
    '0000044a4b8a' => 0,
    '0000044a4b8d' => 1,
    '0000044a4b7e' => 2,
    '0000044a4b7b' => 3,
    '0000044a4b78' => 4,
    '0000044a4b75' => 5,
    '0000044a4b81' => 6,
    '0000044a4b87' => 7
);

$ib_wind_speed = new iButton '1d00000000fde0';
$ib_rain_gauge = new iButton '1d00000000f226';

my $wind_time2;
my $last_wind_count;
my $raintotal_prev;

if ( $Reload or $Startup ) {
    $raintotal_prev = '';
    $weather{IsRaining} = 0;
}

sub iButton_wind_read {

    #    $Hardware::iButton::Connection::debug = 1;
    #   print "read_counter\n";

    #wind speed

    my $wind_time1 = &get_tickcount;
    my $count =
      $ib_wind_speed->Hardware::iButton::Device::DS2423::read_counter();
    print "wind: $count\n";

    if ($wind_time2) {
        my $revolution_sec =
          ( ( $count - $last_wind_count ) * 1000 ) /
          ( $wind_time1 - $wind_time2 ) / 2.0;
        print "rev/sec:$revolution_sec speed:"
          . sprintf( "%3.2f", $revolution_sec * 2.453 ) . "\n"
          if $config_parms{debug} eq 'iButton';
        set $ib_wind_speed sprintf( "%3.2f", $revolution_sec * 2.453 );
    }

    $last_wind_count = $count;
    $wind_time2      = $wind_time1;

    #    $Hardware::iButton::Connection::debug = 0;

    #
    # wind direction
    #

    #    $Hardware::iButton::Connection::debug = 1;
    set $ib_wind_relay 'on';
    my $i = 0;
    while ( $ib_wind_relay->read_switch and $i++ < 15 ) {
        print "setting to on ($i)\n";
        set $ib_wind_relay 'on';
        usleep(10);
    }

    #print "switch  on: " . sprintf("%02x",$ib_wind_relay->read_switch) . "\n";
    my @ib_list = &iButton::scan('01');    # gets DS290/DS2401 devices
    set $ib_wind_relay 'off';

    $i = 0;
    while ( $ib_wind_relay->read_switch == 0 and $i++ < 15 ) {
        print "setting to off ($i)\n";
        set $ib_wind_relay 'off';
        usleep(10);
    }

    #print "switch off: " . sprintf("%02x",$ib_wind_relay->read_switch) . "\n";
    #    $Hardware::iButton::Connection::debug = 0;

    @ib_list = &iButton::scan('01') if $#ib_list < 0;            # try again
    print_log "wind direction not available" if $#ib_list < 0;

    my $dir = 0;
    for my $ib (@ib_list) {
        $dir += $wind_dir{ $ib->serial };
        print "Wind ID:"
          . $ib->serial() . " dir="
          . $wind_dir{ $ib->serial } . "\n";
    }
    $weather{wind_dir} = sprintf( "%3.1f", $dir / ( $#ib_list + 1 ) * 45 )
      if $#ib_list > -1;

    #
    # rain gauge
    #

    $count = $ib_rain_gauge->Hardware::iButton::Device::DS2423::read_counter();

    # Add check for $raintotal_prev, per note from Bill Richman
    if (    $raintotal_prev
        and $weather{RainTotal}
        and ( $count - $weather{RainTotal} * 100 > 10 ) )
    {
        print_log "bad rain gauge count: $count";
    }
    else {
        $weather{RainTotal} = sprintf( "%3.2f", $count * 0.01 );
    }
    $raintotal_prev = $weather{RainTotal} if $raintotal_prev eq '';
    $weather{RainRecent} =
      round( ( $weather{RainTotal} - $raintotal_prev ), 2 );
    print
      "raincount:$count, rt=$weather{RainTotal}, raintotal_prev:$raintotal_prev\n"
      if $config_parms{debug} eq 'iButton';

    if ( $weather{RainRecent} > 0 ) {
        speak "Notice, it just rained $weather{RainRecent} inches";
        $weather{IsRaining}++;
        $raintotal_prev = $weather{RainTotal};
    }
    elsif ( !( $Minute % 20 ) ) {    # Reset every 20 minutes
        $weather{IsRaining} = 0;
        $raintotal_prev = $weather{RainTotal};
    }

    $Save{WindGustMax} = 0 if $New_Day;

}

$ib_temp_outside = new iButton '10000000390236';
$ib_temp_inside  = new iButton '10000000429A12';
$ib_temp_freezer = new iButton '100000004297F7';

#my @iB_temps = ($ib_temp_inside, $ib_temp_outside, $ib_temp_freezer);
my @iB_temps = ($ib_temp_outside);

&read_iButton_temp(@iB_temps)
  if $New_Second and ( $Second == 45 or $Second == 15 );
&iButton_wind_read if ( $New_Second and !( $Second % 15 ) );

use vars '%weather';
my $delta_i;
my %delta;

if ( time_cron('* * * * *') ) {
    $weather{Temp_outside} = state $ib_temp_outside;
    $weather{Temp_inside}  = state $ib_temp_inside;
    $weather{Temp_freezer} = state $ib_temp_freezer;

    #$delta{inside}  += $weather{Temp_inside}  - $weather{temp_outside};
    #$delta{freezer} += $weather{Temp_freezer} - $weather{temp_outside};

    #print_log "outside: $weather{Temp_outside},  " .
    #          "inside: $weather{Temp_inside} " . sprintf("[%3.2f],  ", $delta{inside}/++$delta_i) .
    #          "freezer: $weather{Temp_freezer} " . sprintf("[%3.2f]", $delta{freezer}/$delta_i);

    $weather{Temp_inside} -= 0.60;
    logit(
        "$config_parms{data_dir}/logs/iButton_temps.log",
        "$weather{Temp_inside} $weather{Temp_outside} $weather{Temp_freezer} 0",
        12
    );

    $weather{WindSpeed}     = state $ib_wind_speed;
    $weather{WindGustSpeed} = $weather{WindSpeed}
      if $weather{WindSpeed} > $weather{WindGustSpeed};
    $weather{WindAvgSpeed} =
      ( $weather{WindSpeed} + $weather{WindGustSpeed} ) / 2;

    $weather{Summary} = sprintf( "In/out/freezer: %3.1f/%3.1f/%3.1f ",
        $weather{Temp_inside}, $weather{Temp_outside}, $weather{Temp_freezer} );
    $weather{SummaryWind} =
      sprintf( "WindSpeed/WindGustSpeed/WindAvgSpeed: %3.1f/%3.1f/%3.1f ",
        $weather{WindSpeed}, $weather{WindGustSpeed}, $weather{WindAvgSpeed} );
    $weather{SummaryRain} =
      sprintf( "RainTotal/RainRecent/IsRaining: %3.2f/%3.2f/%d ",
        $weather{RainTotal}, $weather{RainRecent}, $weather{IsRaining} );

    print_log
      "wind speed: $weather{WindSpeed} wind dir: $weather{wind_dir} rain:$weather{RainTotal}";
}

my %iButton_data_avg_data;

sub read_iButton_temp {
    my @ib_list = @_;
    for my $ib (@ib_list) {

        #print_log "ID:" . $ib->serial() ;
        my $temp = $ib->read_temperature_hires();

        next if $temp < -20 or $temp > 120;

        my $temp_c = sprintf( "%3.2f", $temp );
        my $temp_f = sprintf( "%3.2f", $temp * 9 / 5 + 32 );
        my $serial = $ib->serial();

        # Average the last 5 entries
        if ( defined @{ $iButton_data_avg_data{$serial} } ) {
            unshift( @{ $iButton_data_avg_data{$serial} }, $temp_f );
            pop( @{ $iButton_data_avg_data{$serial} } );
        }
        else {
            @{ $iButton_data_avg_data{$serial} } = ($temp_f) x 5;
        }

        my $iButton_data_avg = 0;
        grep( $iButton_data_avg += $_, @{ $iButton_data_avg_data{$serial} } );
        $iButton_data_avg /= 5;
        $ib->{state} = sprintf( "%3.1f", $iButton_data_avg );
        print "$iButton_data_avg\n" if $config_parms{debug} eq 'iButton';
    }
}

