#Category=Thermostat

=begin comment

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


$omnistat=new Omnistat;

my $omnistat_temperatures="55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96";

#one time settings
if ($Reload or $Reread) {
	$omnistat->cooling_anticipator('10');
	$omnistat->heating_anticipator('10');
	$omnistat->cooling_cycle_time('8');
	$omnistat->heating_cycle_time('8');
}

if ($New_Day) {
	$omnistat->set_time;
}

$v_omnistat_fan=new Voice_Cmd('Set Thermostat fan [on,auto]');
if ($state = said $v_omnistat_fan) {
	$omnistat->fan($state);
}
$v_omnistat_hold=new Voice_Cmd('Set Thermostat hold [on,off]');
if ($state = said $v_omnistat_hold) {
	$omnistat->hold($state);
}
$v_omnistat_mode=new Voice_Cmd('Set Thermostat mode [off,heat,cool,auto]');
if ($state = said $v_omnistat_mode) {
	$omnistat->mode($state);
}
$v_omnistat_cool_sp=new Voice_Cmd("Set Thermostat cool setpoint to [$omnistat_temperatures]");
if ($state = said $v_omnistat_cool_sp) {
	$omnistat->cool_setpoint($state);
}

$v_omnistat_heat_sp=new Voice_Cmd("Set Thermostat heat setpoint to [$omnistat_temperatures]");
if ($state = said $v_omnistat_heat_sp) {
	$omnistat->heat_setpoint($state);
}

