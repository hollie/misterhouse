# Category=Test

# Some simple events to debug new HomeBase subroutines

$v_homebase_test = new  Voice_Cmd('Test homebase [read_time,set_time,read_log,clear_log,read_flags,read_variables,test_write]');

my @hb_flag_names = ('flag A', 'flag B', 'Input 3', 'Sensor 4');
my %hb_flag_values;

if ($state = said $v_homebase_test) {

    my $port = $Serial_Ports{HomeBase}{object};
    print_log "Running HomeBase test $state on port object $port";

    if ($state eq 'read_time') {
        my $time = &HomeBase::read_time($port);
        my @time = &HomeBase::read_time($port);
        print "HomeBase time 1: $time\n";
        print "HomeBase time 2: @time\n";
    }
    elsif ($state eq 'set_time') {
        if (&HomeBase::set_time($port)) {
            print "HomeBase time was set to $Time_Now\n";
        }
        else {
            print "Error in setting HomeBase time\n";
        }
    }
    elsif ($state eq 'test_write') {
# Try to emperically derive the correct set_time string.  Docs say:
# ##%05AAAALLLLTTSSYYMMDDRRHHMMCC
# AAAA Latitude
# LLLL Longitude
# TT   Timezone
# SS   Savings time
# YY   Year
# MM   Month
# DD   Date
# RR   Day of week (1-7)
# HH   Hour
# MM   Minute
# CC   Checksum
#  This string gave us  02:05:10 09/19/99
#0023004e05109909191282058
        # Should be 8:44pm 9/29/99
        my $temp1 = "##%050023004e051199092908204400";
        #my $temp1 = "##%050102030422338801020304058";
        $temp = $port->write($temp1 . "\r");
        print "HomeBase test write: results=$temp data=$temp1\n";

        my $time = &HomeBase::read_time($port);
        print "HomeBase time after test_write: $time\n";
    }

    elsif ($state eq 'read_log') {
        my @log = &HomeBase::read_log($port);
        my $count = @log;
        print "Homebase log 1: $count records\n";
        for my $data (@log) {
            &logit("$Pgm_Root/data/logs/HomeBase.$Year_Month_Now.log",  $data, 2);
        }
    }
    elsif ($state eq 'clear_log') {
        if (&HomeBase::clear_log($port)) {
            print "HomeBase log was cleared\n";
        }
        else {
            print "Error in clearing HomeBase log\n";
        }
    }
    elsif ($state eq 'read_flags') {
        my @flags = &HomeBase::read_flags($port);
        for my $i (0 .. $#flags) {
            my $name = $hb_flag_names[$i];
            $name = 'flag' . $i unless $name;
            $hb_flag_values{$name} = shift @flags;
            print "Flag:  $name=$hb_flag_values{$name}\n";
        }
    }
    elsif ($state eq 'read_variables') {
        my @vars = &HomeBase::read_variables($port);
        my $count = @vars;
        print "Homebase variables: $count records\n";
    }
    else {
        print "unknown request\n";
     }

}
#} # Added by Bob ??


# set_time format??

# read_flags ??

# read log count right??
