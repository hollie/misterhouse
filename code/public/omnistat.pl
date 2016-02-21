#Category=Thermostat

=begin comment

Joel Davidson  June 2004

I've updated Omnistat.pm and I think gotten everything working.
I added a couple of new functions (see below).  See mh/lib/Omnistat.pm
for more details.


From Kent Noonan on Jan 2002

I have another module for misterhouse. But it is not finished. This is a
module for controling HAI Omnistat Communicating thermostats. It was
specifically written against the RC80 but as far as I can tell it should
work with any of them. There is a problem with it. I am not finished with
it. I started working on it, then moved to a house with an older heater
that the thermostat doesn't work with. It's going to be a couple of years
before we can upgrade the heater, so I thought I'd send this incase
somebody else wanted to continue where I left off before I can get back to
it again.  Right now I can't even gaurantee that it works at all, but I
think it did.. 

=cut

$omnistat = new Omnistat;

#one time settings
if ( $Reload or $Reread ) {
    $omnistat->cooling_anticipator('10');
    $omnistat->heating_anticipator('10');
    $omnistat->cooling_cycle_time('8');
    $omnistat->heating_cycle_time('8');
}

if ($New_Day) {
    $omnistat->set_time;
}

$v_omnistat_fan = new Voice_Cmd('Set Thermostat fan [on,auto]');
if ( $state = said $v_omnistat_fan) {
    $omnistat->fan($state);
}
$v_omnistat_hold = new Voice_Cmd('Set Thermostat hold [on,off]');
if ( $state = said $v_omnistat_hold) {
    $omnistat->hold($state);
}
$v_omnistat_mode = new Voice_Cmd('Set Thermostat mode [off,heat,cool,auto]');
if ( $state = said $v_omnistat_mode) {
    $omnistat->mode($state);
}
$v_omnistat_cool_sp =
  new Voice_Cmd("Set Thermostat cool setpoint to [$omnistat_temperatures]");
if ( $state = said $v_omnistat_cool_sp) {
    $omnistat->cool_setpoint($state);
}

$v_omnistat_heat_sp =
  new Voice_Cmd("Set Thermostat heat setpoint to [$omnistat_temperatures]");
if ( $state = said $v_omnistat_heat_sp) {
    $omnistat->heat_setpoint($state);
}

# note that you have to turn hold mode off to change setpoints
if ( defined( $state = state_changed $mode) && $state eq 'away' ) {
    print_log "Setting thermostat to away mode";
    $omnistat->hold('off');
    $omnistat->cool_setpoint('83');
    $omnistat->heat_setpoint('65');
    $omnistat->hold('on');
}

# Read the 2 setpoint registers and translate the values to fahrenheit
my ( $reg3b, $reg3c ) = split ' ', $omnistat->read_reg( "0x3b", 2 );

# $omnistat->read_reg("0x3b"); will read just one register.
# translate_temp will translate from fahrenheit to 'omni' temperature
# or from a hex 'omni' value back to fahrenheit if the value has a 0x
# prefix.
$reg3b = &Omnistat::translate_temp($reg3b);
$reg3c = &Omnistat::translate_temp($reg3c);
print "hvac: cool setpoint=$reg3b, heat setpoint=$reg3c\n";

