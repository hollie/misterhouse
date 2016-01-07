# Category=Test

=begin comment

From Chris Witte <cwitte@xmlhq.com> on 12/2002

Attached is some code that I put together to talk to the RS232/485 
versions of the RCS thermostats.

It inherits from Serial_Item, and implements an interface similar to the 
omnistat interface.

The RS232 interface is tested/working.  Theoretically, the 485 unit will 
work with the same code.

=cut

$rcs0 = new RCSs('RCSs_1');
$rcs1 = new RCSs('RCSs_2');

# $rcs0->_poll();
warn "rcs init failed\n" unless $rcs1;
warn "rcs init failed\n" unless $rcs0;

my $rcs_temperatures = "55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72
,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96";

$v_rcs_fan = new Voice_Cmd('Set Thermostat fan [on,off,auto]');
if ( $state = said $v_rcs_fan) {
    $rcs0->fan($state);
}
$v_rcs_hold = new Voice_Cmd('Set Thermostat hold [on,off]');
if ( $state = said $v_rcs_hold) {
    $rcs0->hold($state);
}
$v_rcs_mode = new Voice_Cmd('Set Thermostat mode [off,heat,cool,auto]');
if ( $state = said $v_rcs_mode) {
    $rcs1->mode($state);
}

$v_rcs_cool = new Voice_Cmd("Set Thermostat to [$rcs_temperatures]");
if ( $state = said $v_rcs_cool) {
    $rcs0->cool_setpoint($state);
}

$v_rcs_heat =
  new Voice_Cmd("Set Thermostat heat setpoint to [$rcs_temperatures]");
if ( $state = said $v_rcs_heat) {
    $rcs0->heat_setpoint($state);
}

if ($New_Minute) {

    #        $rcs->mode("heat");
    #        $rcs->heat_setpoint(58);
    #        $rcs->fan("on");
    $rcs0->_poll();
    $rcs1->_poll();
}

##  Test settings for heat
my $night_temp = 60;
my $day_temp   = 67;
if (
    time_cron '30 21  * * *'    ## first try
    or time_cron '45 23 * * *'
  )
{                               ## and again in case someone jacked it up
    $rcs0->heat_setpoint($night_temp);
}

if (
    time_cron '40 05 * 10-12,1-4 1-5' or    ## weekdays
    time_cron '30 8 * 10-12,1-4 0,6'
  )
{                                           ## weekends
    $rcs0->heat_setpoint($day_temp);
}

if ( time_cron '* * * 10-12,1-4 1,3,5' ) {    ## m/w/f daytime setback
    if ( time_cron '30 09 * * *' ) {
        $rcs0->heat_setpoint($night_temp);
    }
    if ( time_cron '00 17 * * *' ) {
        $rcs0->heat_setpoint($day_temp);
    }
}
