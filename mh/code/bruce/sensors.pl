# Category=none

				# Read analog sensors every minute
				#  - avoid second = 0 ... lots of stuff happens on a new minute
set $analog_request_a if $New_Second and $Second == 20;
&analog_read($temp) if $temp = state_now $analog_results;

# Make an ECS like log entry every 5 minutes
my %analog;
#if (time_cron('0,5,10,15,20,25,30,35,40,45,50,55 * * * *')) {
if (time_cron('* * * * *') or $Startup) {
    $analog{humidity_inside} = round((57/81) * 100 * (state_now $humidity_inside / 5000), 1);
    $analog{humidity_outside}= round((48/53) * 100 * (state $humidity_outside / 5000), 1);
    $analog{sun_sensor}      = round((100/60)* 100 * (state $sun_sensor / 5000), 0);
    $analog{temp_outside}= convert_k2f(state $temp_outside/10);
#   $analog{temp_bed}=     convert_k2f(state $temp_bed/10);
    $analog{temp_living}=  convert_k2f(state $temp_living/10);
    $analog{temp_nick}=    convert_k2f(state $temp_nick/10);
    $analog{temp_zack}=    convert_k2f(state $temp_zack/10);
    logit("e:/logs/DATAHI.log", "Humidity Downstairs $analog{humidity_inside}");
    logit("e:/logs/DATAHO.log", "Humidity Outside    $analog{humidity_outside}");
    logit("e:/logs/DATASS.log", "Sensor          $analog{sun_sensor}");
#   logit("e:/logs/DATATB.log", "Temp Bedroom        $analog{temp_bed}");
    logit("e:/logs/DATATD.log", "Temp Living         $analog{temp_living}");
    logit("e:/logs/DATATO.log", "Temp Outside        $analog{temp_outside}");
    logit("e:/logs/DATATN.log", "Temp Nicks Room     $analog{temp_nick}");
    logit("e:/logs/DATATZ.log", "Time_Now Temp Zacks Room     $analog{temp_zack}");
}

my %analog_data_avg_data;
sub analog_read {
    my($analog_data) = @_;
    my $analog_port = substr($analog_data, 0, 2);
    my @temp = split(' ', substr($analog_data, 2));
				# We can only deal with 8 bit speakings ... single bit readings do not say which bit is which
    if (@temp == 8) {
	my $bit;
	for $bit (1 .. 8) { 
	    my $data = shift @temp;

	    my $analog_port_bit = "$analog_port$bit";
#	    print "db2 bit=$bit port=$analog_port_bit data=$data\n";
	    my $ref;
	    next unless $ref = &Serial_Item::serial_item_by_id($analog_port_bit);
	    $ref->{state_now} = $data; # Don't care about unrefererenced bits

				# Average the last 5 entries
	    if (defined @{$analog_data_avg_data{$analog_port_bit}}) {
		unshift(@{$analog_data_avg_data{$analog_port_bit}}, $data);
		pop(@{$analog_data_avg_data{$analog_port_bit}});
	    }
	    else {
		@{$analog_data_avg_data{$analog_port_bit}} = ($data) x 5;
	    }

	    my $analog_data_avg = 0;
	    grep($analog_data_avg += $_, @{$analog_data_avg_data{$analog_port_bit}});
	    $analog_data_avg /= 5;
	    $ref->{state} = $analog_data_avg;
#	    print "db port=$analog_port_bit avg=$analog_data_avg data=$data d2=@{$analog_data_avg_data{$analog_port_bit}}\n";
	}
    }
}
 



