
# Category=MisterHouse

my (@disable_members, $disable_member, $disable_member_time);

$disable_code = new Voice_Cmd 'Disable code test [.01,.1,.3,.6,1,10,60,300] minutes';
$disable_code-> set_info('Use this to debug problems by sequentially turning off code files');
$disable_code_timer = new Timer;

if ($state = said $disable_code) {
    @disable_members = sort keys %Run_Members;
    set $disable_code_timer .1;
    $disable_member_time = $state;
}

if (expired $disable_code_timer) {
    $Run_Members{$disable_member} = 1 if $disable_member;
    shift @disable_members if $disable_members[0] eq 'disable_code';
    if ($disable_member = shift @disable_members) {
        $Run_Members{$disable_member} = 0;
        set $disable_code_timer 60 * $disable_member_time;
        my $msg = "Disabling code member $disable_member";
        print "db $msg\n";
        print_log $msg;
        display text => "$Time_Date: $msg\n", time => 0,
                window_name => 'disable_code', append => 'top';
    }
    else {
        print_log 'Disable code test finished';
    }
}
        

# If you have a 24x7 internet connection, you can use this to 
# debug time loss problems (from internet_data.pl)

#run_voice_cmd 'Set the clock via the internet' if 
#    expired $disable_code_timer and $disable_member_time > .01;

