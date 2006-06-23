
=begin comment 

#@ Monitors the cm11 automation controller

=cut

# Category = X10

$timer_x10_inactivity = new Timer();

#noloop=start
Serial_data_add_hook(\&cm11_unstick_hook); 
set $timer_x10_inactivity 1800, \&cm11_unstick;
#noloop=stop

sub cm11_unstick_hook {
    my $state = shift; 
    my $current_unit;
    return unless $state =~ /^X/;
    $current_unit = $1 if ($state =~ /^X([A-P][1-9A-G])/);
    print_log "Reset cm11 inactivity timer $current_unit $state" if $config_parms{x10_errata} >= 3;
    set $timer_x10_inactivity 1800, \&cm11_unstick; #every half hour without activity triggers a restart.  Otherwise cm11 remains lost in space."
}

sub cm11_unstick {
    speak "app=system Restarting automation controller after inactivity";
    run_voice_cmd "stop the Cm11 port";
    run_voice_cmd "start the Cm11 port";    
    set $timer_x10_inactivity 1800, \&cm11_unstick;
}
