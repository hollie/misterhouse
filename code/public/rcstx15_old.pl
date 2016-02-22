# Category=HVAC

# Example of how to control an RCS TX15 X-10 Thermostat using the
# older, simpler "standard unit code decode tables".  I'm not sure
# which models support Table B (version 1.6) and which support
# Table B (version 1.5).  This uses Table P, but could easily
# be modified.
#
# Note: This has not be tested/debuged yet
# Note: This has not be tested/debuged yet
# Note: This has not be tested/debuged yet
# Note: This has not be tested/debuged yet
#
# Coded for J. B. on 9/98
#

# Set Item codes
my $TX15_hc = 'A';

my @TX15_table_p_on =
  qw(65 66 67 68 69 70 71 72 heat_on cool_on auto_on fan_on sb_on sb_6 sb_8 sb_10);
my @TX15_table_p_off =
  qw(73 74 75 76 77 78 79 80 heat_off cool_off auto_off fan_off sb_off sb_12 sb_14 sb_16);

my $thermostat = new Serial_Item( 'X' . $TX15_hc );

# The following 'for' iteration needs to be outside of the loop code, so flag it
# noloop=start
my $i = 0;
for my $device_code (qw(1 2 3 4 5 6 7 8 9 A B C D E F G)) {
    $thermostat->add( 'X' . $TX15_hc . $device_code . $TX15_hc . 'J',
        $TX15_table_p_on[$i] );
    $thermostat->add( 'X' . $TX15_hc . $device_code . $TX15_hc . 'K',
        $TX15_table_p_off[ $i++ ] );
}

# noloop=stop

my $state;

$v_thermostat_heat = new Voice_Cmd('Thermostat heating [on,off]');
set $thermostat 'heat_' . $state if $state = said $v_thermostat_heat;

$v_thermostat_cool = new Voice_Cmd('Thermostat cooling [on,off]');
set $thermostat 'cool_' . $state if $state = said $v_thermostat_cool;

$v_thermostat_setback = new Voice_Cmd('Thermostat setback [on,off]');
set $thermostat 'sb_' . $state if $state = said $v_thermostat_setback;

$v_thermostat_sp = new Voice_Cmd(
    'Set the thermostat to [65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80] degrees'
);
set $thermostat $state if $state = said $v_thermostat_sp;

$v_thermostat_sb =
  new Voice_Cmd('Set the thermostat setback to [6,8,10,12,14,16] degrees');
set $thermostat 'sb_' . $state if $state = said $v_thermostat_sb;

if ( $Month > 10 and $Month < 3 ) {

    # At 10:00 and 10:01 pm,  turn setback on.  At 6:00 and 6:01 am, turn it on
    if ( time_cron '0,1 22 * * *' ) {
        set $thermostat 'sb_on';
    }
    if ( time_cron '0,1 6 * * 1-5' ) {
        set $thermostat 'sb_off';
    }

    # On weekends, let the furnace sleep in :)
    if ( time_cron '0,1 8 * * 0,6' ) {
        set $thermostat 'sb_off';
    }
}

