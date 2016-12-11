# Category = Time

#@ Sets your computer's clock to an internet atomic clock once per
#@ day or as requested, using mh/bin/set_clock.

# Check clock against an internet atomic clock
$v_set_clock = new Voice_Cmd('Set the clock via the internet');
$v_set_clock->set_info(
    'Use an Internet connected atomic clock to set your pc clock time');
$v_set_clock->set_icon('time');
$p_set_clock =
  new Process_Item "set_clock -log $config_parms{data_dir}/logs/set_clock.log";

if (   said $v_set_clock
    or time_cron '7 6 * * * ' )
{
    print "Running set_clock to set clock via the internet ...";
    start $p_set_clock;

    #   run "$Pgm_Path/set_clock";
    #   @ARGV = (-log => "$config_parms{data_dir}/logs/set_clock.log");
    #   my $status = do "$Pgm_Path/set_clock";
}

if ( done_now $p_set_clock) {
    my $results = file_read "$config_parms{data_dir}/logs/set_clock.log.txt";
    print_log "set_clock results:  $results";
    respond $results;
}

my $f_set_clock_log = "$config_parms{data_dir}/logs/set_clock.log";
$v_view_clock_log = new Voice_Cmd('Display the clock adjustment log');
display $f_set_clock_log if said $v_view_clock_log;

