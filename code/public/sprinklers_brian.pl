# Category=Sprinklers

# This script manages the 3 sprinkler zones for the lawn,
# the drip line for the garden, cannes and nasturshum, and the
# soaker hose on the south side of the house.
#
# 9/22/2000 Brian Rudy (brudy@praecogito.com)
# Version 0.1   9/22/2000
# First functional version.

# To do:
# -Add rain level monitor via weather_aws.pl
# -Add skip-cycle to skip appropriate amount of time between
#  cycles after it rains (depends on amount rained and soil
#  permeability).
# -Add jog-cycle on extremely hot, dry days.
# -Moisture level sensors... HELLO, I buried the wires there for a reason...

# Variable declarations

# How long will the zone be watered?
my $sprinkler_zone1_timeout;
my $sprinkler_zone2_timeout;
my $sprinkler_zone3_timeout;
my $drip_line_timeout;
my $soaker_hose_timeout;

# On what days will the zone be watered?
my $lawn_watering_interval;
my $drip_watering_interval;
my $soaker_watering_interval;

# What hour should the cycle start (24 hour clock)
my $watering_time;

my $start_hour_sprinkler_zone2;
my $start_hour_sprinkler_zone3;
my $start_hour_drip_line;
my $start_hour_soaker_hose;

my $start_minute_sprinkler_zone2;
my $start_minute_sprinkler_zone3;
my $start_minute_drip_line;
my $start_minute_soaker_hose;

# Voice commands
$v_when_water = new Voice_Cmd('When is the next watering cycle');

# Timer definitions
$sprinkler_zone1_timer = new Timer();
$sprinkler_zone2_timer = new Timer();
$sprinkler_zone3_timer = new Timer();
$drip_line_timer       = new Timer();
$soaker_hose_timer     = new Timer();

# Spring
#
# Lots of water for lawn and garden.
# Check soil penetration if it rains!
# 3am every day for 30 minutes all zones
if ( $Season eq "Spring" ) {
    $sprinkler_zone1_timeout  = 30;
    $sprinkler_zone2_timeout  = 30;
    $sprinkler_zone3_timeout  = 30;
    $drip_line_timeout        = 30;
    $soaker_hose_timeout      = 30;
    $lawn_watering_interval   = '0,1,2,3,4,5,6';
    $drip_watering_interval   = '0,1,2,3,4,5,6';
    $soaker_watering_interval = '0,1,2,3,4,5,6';
    $watering_time            = 3;
}

# Summer
#
# Back off a little on the lawn, but keep the garden up.
if ( $Season eq "Summer" ) {
    $sprinkler_zone1_timeout  = 30;
    $sprinkler_zone2_timeout  = 30;
    $sprinkler_zone3_timeout  = 30;
    $drip_line_timeout        = 30;
    $soaker_hose_timeout      = 30;
    $lawn_watering_interval   = '0,2,4,5';
    $drip_watering_interval   = '0,1,2,3,4,5,6';
    $soaker_watering_interval = '0,1,2,3,4,5,6';
    $watering_time            = 3;
}

# Fall
#
# Back off a little more on the lawn, and a little on the garden.
if ( $Season eq "Fall" ) {
    $sprinkler_zone1_timeout  = 30;
    $sprinkler_zone2_timeout  = 30;
    $sprinkler_zone3_timeout  = 30;
    $drip_line_timeout        = 30;
    $soaker_hose_timeout      = 30;
    $lawn_watering_interval   = '0,3,6';
    $drip_watering_interval   = '0,2,3,4,6';
    $soaker_watering_interval = '0,2,3,4,6';
    $watering_time            = 3;
}

# Winter
#
# Lawn is hibernating, only plants in the garden by now are herbs.
# Keep watering to a minimum.
if ( $Season eq "Winter" ) {
    $sprinkler_zone1_timeout  = 30;
    $sprinkler_zone2_timeout  = 30;
    $sprinkler_zone3_timeout  = 30;
    $drip_line_timeout        = 30;
    $soaker_hose_timeout      = 30;
    $lawn_watering_interval   = '1,5';
    $drip_watering_interval   = '2,4,6';
    $soaker_watering_interval = '2,4,6';
    $watering_time            = 3;
}

# A little stuff to sequence each zone, and produce cron-friendly output.

$start_hour_sprinkler_zone2   = $watering_time;
$start_minute_sprinkler_zone2 = $sprinkler_zone1_timeout + 1;
while ( $start_minute_sprinkler_zone2 >= 60 ) {
    $start_hour_sprinkler_zone2++;
    $start_minute_sprinkler_zone2 = $start_minute_sprinkler_zone2 - 60;
}

$start_hour_sprinkler_zone3 = $start_hour_sprinkler_zone2;
$start_minute_sprinkler_zone3 =
  $start_minute_sprinkler_zone2 + $sprinkler_zone2_timeout + 1;
while ( $start_minute_sprinkler_zone3 >= 60 ) {
    $start_hour_sprinkler_zone3++;
    $start_minute_sprinkler_zone3 = $start_minute_sprinkler_zone3 - 60;
}

$start_hour_drip_line = $start_hour_sprinkler_zone3;
$start_minute_drip_line =
  $start_minute_sprinkler_zone3 + $sprinkler_zone3_timeout + 1;
while ( $start_minute_drip_line >= 60 ) {
    $start_hour_drip_line++;
    $start_minute_drip_line = $start_minute_drip_line - 60;
}

$start_hour_soaker_hose   = $start_hour_drip_line;
$start_minute_soaker_hose = $start_minute_drip_line + $drip_line_timeout + 1;
while ( $start_minute_soaker_hose >= 60 ) {
    $start_hour_soaker_hose++;
    $start_minute_soaker_hose = $start_minute_soaker_hose - 60;
}

# Lawn zone 1 loop
if ( time_cron("0 $watering_time * * $lawn_watering_interval") ) {
    print_log "Starting sprinklers in zone 1.";
    set $sprinkler_zone1_timer ( $sprinkler_zone1_timeout * 60 );
    set $sprinkler_zone1 ON;
}
if ( expired $sprinkler_zone1_timer) {
    print_log "Watering finished for lawn zone 1";
    set $sprinkler_zone1 OFF;
}

# Lawn zone 2 loop
if (
    time_cron(
        "$start_minute_sprinkler_zone2 $start_hour_sprinkler_zone2 * * $lawn_watering_interval"
    )
  )
{
    print_log "Starting sprinklers in zone 2.";
    set $sprinkler_zone2_timer ( $sprinkler_zone2_timeout * 60 );
    set $sprinkler_zone2 ON;
}
if ( expired $sprinkler_zone2_timer) {
    print_log "Watering finished for lawn zone 2";
    set $sprinkler_zone2 OFF;
}

# Lawn zone 3 loop
if (
    time_cron(
        "$start_minute_sprinkler_zone3 $start_hour_sprinkler_zone3 * * $lawn_watering_interval"
    )
  )
{
    print_log "Starting sprinklers in zone 3.";
    set $sprinkler_zone3_timer ( $sprinkler_zone3_timeout * 60 );
    set $sprinkler_zone3 ON;
}
if ( expired $sprinkler_zone3_timer) {
    print_log "Watering finished for lawn zone 3";
    set $sprinkler_zone3 OFF;
}

# Drip line loop
if (
    time_cron(
        "$start_minute_drip_line $start_hour_drip_line * * $drip_watering_interval"
    )
  )
{
    print_log "Starting drip line watering.";
    set $drip_line_timer ( $drip_line_timeout * 60 );
    set $drip_line ON;
}
if ( expired $drip_line_timer) {
    print_log "Drip line watering finished";
    set $drip_line OFF;
}

# Soaker loop
if (
    time_cron(
        "$start_minute_soaker_hose $start_hour_soaker_hose * * $soaker_watering_interval"
    )
  )
{
    print_log "Starting soaker hose watering.";
    set $soaker_hose_timer ( $soaker_hose_timeout * 60 );
    set $soaker_hose ON;
}
if ( expired $soaker_hose_timer) {
    print_log "Soaker hose watering finished";
    set $soaker_hose OFF;
}

# Voice command stuff
if ( said $v_when_water) {
    speak("Sprinkler zone 1 will start at $watering_time:00.");
    speak(
        'Sprinkler zone 2 will start at '
          . join( ':',
            $start_hour_sprinkler_zone2, $start_minute_sprinkler_zone2 )
          . '.'
    );
    speak(
        'Sprinkler zone 3 will start at '
          . join( ':',
            $start_hour_sprinkler_zone3, $start_minute_sprinkler_zone3 )
          . '.'
    );
    speak(  'Drip line will start at '
          . join( ':', $start_hour_drip_line, $start_minute_drip_line )
          . '.' );
    speak(  'Soaker hose will start at '
          . join( ':', $start_hour_soaker_hose, $start_minute_soaker_hose )
          . '.' );
}
