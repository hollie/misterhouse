
# This shows how to set up different X10 items

# A X10_Item allows for on,off, and various brightness states

$christmas_lights = new X10_Item('O6');

my $light_states = 'on,brighten,dim,off,-30,-50,-80,+30,+50,+80';
$v_christmas_lights = new Voice_Cmd("Christmas Lights [$light_states]");
set $christmas_lights_bed $state if $state = said $v_christmas_lights;

# An appliance item has only 'on' and 'off' states
$v_fountain = new Voice_Cmd('Fountain [on,off]');
set $fountain $state if $state = said $v_fountain;
set $fountain ON if $Season eq 'Summer' and time_cron '00 20 * * *';

# When X10_Item sees just one character, it sets up a
# 'ALL ON' and 'ALL OFF' item.
$all_bedroom_lights   = new X10_Item('P');
$v_bedroom_lights_all = new Voice_Cmd("All Bedroom lights [on,off]");
set $all_bedroom_lights $state if $state = said $v_bedroom_lights_all;

# X10_Items/appliances have a built in timer
$v_test1 = new Voice_Cmd "Outside lights off in [1,5,10,30,60] minutes";
set_with_timer $outside_lights ON, $state * 60 if $state = said $v_test1;

