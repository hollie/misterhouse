
=begin comment

From Craig Schaeffer on 09/2002

Here is the function I use to calc how soon to turn up (heat) or down (cool) my
tx10 thermostat. Basically it takes about 8 minutes/degree to warm up and about
25/min to cool down. These values were determined by plotting temp at 1 minute
intervals and seeing how long it takes to heat/cool. It checks inside temp,
outside temp (extra time is added when it is hotter or cooler than normal) and
determines when to turn on before I wakeup or return home. This is done with
something like:

$Save{setback_off} = &time_add ("$Save{wakeup_time} - 0:" . calcSetbackDelta());

This does not handle heat pump or aux heating requirements though (I have a
standard gas furnace). In my system it is remarkably accurate. If I am set to
get up at 6:00am, the temp in the room is 68 degrees AT 6:00am. No more getting
up to a cold house. I had some concerns about using a thermostat controlled via
X10, but I have had no problems during the last 3 years. If I were to do it
over again, I would probably buy the serial version though. I used to have a
Honeywell "smart recovery" thermostat. Basically if I set it to be warm
by 6:00am, it would start about 4 hours early! So much for smart.

=cut

sub calcSetbackDelta {

    my $inside_temp  = convert_k2f( state $temp_inside/ 10 );
    my $outside_temp = convert_k2f( state $temp_outside/ 10 );
    my $minutes_per_degree = 8;     #default for heating
    my $delta              = 10;    #give it some kind of default

    if ( $TX10->{mode} eq 'Heat' ) {
        $minutes_per_degree++ if $outside_temp < 40;
        $minutes_per_degree++ if $outside_temp < 30;
        $delta = int( $minutes_per_degree * ( 68 - $inside_temp ) );
        $delta = 10 if $delta < 10;    #sanity checks
        $delta = 90 if $delta > 90;
    }
    elsif ( $TX10->{mode} eq 'Cool' ) {
        $minutes_per_degree = 25;      #takes a lot longer to cool than heat
        $minutes_per_degree += 2 if $outside_temp >;
        80;
        $minutes_per_degree += 3 if $outside_temp >;
        85;
        $delta = int( $minutes_per_degree * ( $inside_temp - 78 ) );
        $delta = 10  if $delta < 10;
        $delta = 120 if $delta > 120;   #never start earlier than 2 hours before
    }
    else {
        print_log "Thermostat mode is neither Heat nor Cool";
    }

    return $delta;
}
