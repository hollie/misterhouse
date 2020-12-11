
# Periodically ping Audrey to see if she is responding
$audrey_power_Kitchen = new X10_Appliance 'B2';

# $audrey_power_Piano   = new X10_Appliance 'C2';
# $audrey_power_Bedroom = new X10_Appliance 'C3';
#if (new_minute 10) {
if ( 0 and time_now '4 pm' ) {

    #   for my $audrey (split ',', 'Kitchen,Piano') {
    for my $audrey ( split ',', 'Kitchen' ) {

        #        if (!&net_ping(&audrey_ip($audrey))) {
        #           speak "$audrey Audrey not responding, resetting her power.";
        eval "set_with_timer \$audrey_power_$audrey OFF, 5";

        #        }
    }
}

$audrey_power_kitchen_v = new Voice_Cmd 'Turn Kitchen Audrey [on,off]';
$audrey_power_kitchen_v->tie_items($audrey_power_Kitchen);

# Reset periodically
#set_with_timer $audrey_power_Kitchen OFF, 5 if time_now '10:50 pm';

#get "http://kitchen/screen.shtml?1" if time_now  '6:50 am';
#get "http://kitchen/screen.shtml?0" if time_now '11:20 pm';

#get "http://piano/screen.shtml?1" if time_now  '6:40 am';
#get "http://piano/screen.shtml?0" if time_now '11:00 pm';
