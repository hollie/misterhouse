# Category=Internet

# Check clock against an internet atomic clock
$v_set_clock = new Voice_Cmd('Set the clock via the internet');
if (   said $v_set_clock
    or time_cron '7 6 * * * ' )
{
    print "Running set_clock to set clock via the internet ...";

    #   run "$Pgm_Path/set_clock";
    @ARGV = ( -log => "$config_parms{data_dir}/logs/set_clock.log" );
    my $status = do "$Pgm_Path/set_clock";
    print " set_clock was run\n";
    print_log "Clock set" . $status;
}

my $f_set_clock_log = "$config_parms{data_dir}/logs/set_clock.log";
$v_view_clock_log = new Voice_Cmd('Display the clock adjustment log');
display $f_set_clock_log if said $v_view_clock_log;

