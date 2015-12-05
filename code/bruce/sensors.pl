# Category=none

#@ Monitors analog weeder sensors

# Read analog sensors every minute
#  - avoid second = 0 ... lots of stuff happens on a new minute
#set $analog_request_a 'reset' if $New_Second and $Second == 20;
set $analog_request_a 'request' if $New_Second and $Second == 20;
&analog_read($temp) if $temp = state_now $analog_results;

#$temp_zack           = new  Serial_Item('AE1');
#$temp_living         = new  Serial_Item('AE2');
#$temp_outside        = new  Serial_Item('AE3');
#$temp_nick           = new  Serial_Item('AE4');
#$humidity_inside     = new  Serial_Item('AE5');
#$humidity_outside    = new  Serial_Item('AE6');
#$sun_sensor          = new  Serial_Item('AE7');
#$light_sensor        = new  Serial_Item('AE8');

# Make an ECS like log entry every 5 minutes
my %analog;

#if (time_cron('0,5,10,15,20,25,30,35,40,45,50,55 * * * *')) {
if ( time_cron '* * * * *' and defined state $temp_outside) {
    $analog{humidity_inside} =
      round( ( 57 / 81 ) * 100 * ( state $humidity_inside / 5000 ), 1 );
    $analog{humidity_outside} =
      round( ( 48 / 53 ) * 100 * ( state $humidity_outside / 5000 ), 1 );
    $analog{sun_sensor} =
      round( ( 100 / 60 ) * 100 * ( state $sun_sensor / 5000 ), 0 );
    $analog{temp_outside} = convert_k2f( state $temp_outside/ 10 );

    #   $analog{temp_bed}=     convert_k2f(state $temp_bed/10);
    $analog{temp_living} = convert_k2f( state $temp_living/ 10 );
    $analog{temp_nick}   = convert_k2f( state $temp_nick/ 10 );
    $analog{temp_zack}   = convert_k2f( state $temp_zack/ 10 );
    $Weather{sun_sensor} = $analog{sun_sensor};    # Used in weather_monitor.pl

    #   $Weather{TempSpare1} = $analog{sun_sensor}; # Used in weather_rrd_graph.pl
    #   $Weather{TempSpare1} = $analog{temp_living}; # Used in weather_rrd_graph.pl
    $Weather{TempSpare1} = $analog{temp_outside}; # Used in weather_rrd_graph.pl
    $Weather{TempSpare2} = $analog{temp_nick};    # Used in weather_rrd_graph.pl
    $Weather{TempSpare3} = $analog{temp_zack};    # Used in weather_rrd_graph.pl

    #    print_log "sun=$analog{sun_sensor} temp_in=$analog{temp_living} temp_out=$analog{temp_outside}";
    #    logit("e:/logs/DATAHI.log", "Humidity Downstairs $analog{humidity_inside}");
    #    logit("e:/logs/DATAHO.log", "Humidity Outside    $analog{humidity_outside}");
    #    logit("e:/logs/DATASS.log", "Sensor          $analog{sun_sensor}");
    #   logit("e:/logs/DATATB.log", "Temp Bedroom        $analog{temp_bed}");
    #    logit("e:/logs/DATATD.log", "Temp Living         $analog{temp_living}");
    #    logit("e:/logs/DATATO.log", "Temp Outside        $analog{temp_outside}");
    #    logit("e:/logs/DATATN.log", "Temp Nicks Room     $analog{temp_nick}");
    #    logit("e:/logs/DATATZ.log", "Time_Now Temp Zacks Room     $analog{temp_zack}");
}

my %analog_data_avg_data;

# Old boards look like this:   AE2954 2947 2616 2933 2749 1663 2183 1830
# New boards look like this:   A2954 2947 2616 2933 2749 1663 2183 1830

sub analog_read {
    my ($analog_data) = @_;
    my ( $analog_port, $temp ) = $analog_data =~ /^([A-Z]+)(.+)/;
    my @temp = split( ' ', $temp );

    # We can only deal with 8 bit speakings ... single bit readings do not say which bit is which
    if ( @temp == 8 ) {
        my $bit;
        for $bit ( 1 .. 8 ) {
            my $data = shift @temp;

            my $analog_port_bit = "$analog_port$bit";

            #	        print "db2 bit=$bit port=$analog_port_bit data=$data\n";
            my $ref;
            $ref = &Serial_Item::serial_item_by_id($analog_port_bit);
            my @refs = &Serial_Item::serial_items_by_id($analog_port_bit);
            next
              unless $ref = &Serial_Item::serial_item_by_id($analog_port_bit);
            $ref->{state_now} = $data;    # Don't care about unrefererenced bits

            # Average the last 5 entries
            if ( defined @{ $analog_data_avg_data{$analog_port_bit} } ) {
                unshift( @{ $analog_data_avg_data{$analog_port_bit} }, $data );
                pop( @{ $analog_data_avg_data{$analog_port_bit} } );
            }
            else {
                @{ $analog_data_avg_data{$analog_port_bit} } = ($data) x 5;
            }

            my $analog_data_avg = 0;
            grep( $analog_data_avg += $_,
                @{ $analog_data_avg_data{$analog_port_bit} } );
            $analog_data_avg /= 5;
            $ref->{state} = $analog_data_avg;

            #           print "db port=$analog_port_bit avg=$analog_data_avg data=$data d2=@{$analog_data_avg_data{$analog_port_bit}}\n";
        }
    }
}
