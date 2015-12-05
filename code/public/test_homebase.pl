# Category=Test

# Some simple events to debug new HomeBase subroutines

$v_homebase_test = new Voice_Cmd(
    'Test homebase [read_time,set_time,read_log,clear_log,read_flags,read_variables]'
);

# Put your flag names here
my @hb_flag_names = (
    'Remote Access',
    'Daylight',
    'Daylight Master',
    'Rain Today',
    'Rain Yesterday',
    'House Timer',
    'Downstairs Occupancy',
    'Front Lights'
);
my %hb_flag_values;

# Put your variable names here
my @hb_var_names = (
    'Rain Lately',     'empty',    'Front Lamp Dim', 'HVAC MSB',
    'HVAC LSB',        'In_Temp',  'Out_Temp',       'Humidity',
    'Wind_Speed',      'Wind_Avg', 'Rain_Today',     'House Timer',
    'House Timer Set', 'Doorbell Press'
);
my %hb_var_values;

if ( $state = said $v_homebase_test) {

    my $port = $Serial_Ports{HomeBase}{object};
    print_log "Running HomeBase test $state on port object $port";

    if ( $state eq 'read_time' ) {
        my $time = &HomeBase::read_time($port);

        #my @time = &HomeBase::read_time($port);
        #print "HomeBase time 1: $time\n";
        #print "HomeBase time 2: @time\n";
        speak "Stargate time is set to $time";
    }
    elsif ( $state eq 'set_time' ) {
        if ( &HomeBase::set_time($port) ) {
            print "HomeBase time was set to $Time_Now\n";
        }
        else {
            print "Error in setting HomeBase time\n";
        }
    }
    elsif ( $state eq 'read_log' ) {
        my @log   = &HomeBase::read_log($port);
        my $count = @log;
        print "Homebase event log: $count records\n";
        for my $data (@log) {
            &logit( "$Pgm_Root/data/logs/HomeBase.$Year_Month_Now.log",
                $data . "\n", 2 );
        }
    }
    elsif ( $state eq 'clear_log' ) {
        if ( &HomeBase::clear_log($port) ) {
            print "HomeBase log was cleared\n";
        }
        else {
            print "Error in clearing HomeBase log\n";
        }
    }
    elsif ( $state eq 'read_flags' ) {
        my @flags = &HomeBase::read_flags($port);
        for my $i ( 0 .. $#flags ) {
            my $name = $hb_flag_names[$i];
            $name = 'flag_' . $i unless $name;
            $hb_flag_values{$name} = shift @flags;
            print "Flag:  $name=$hb_flag_values{$name}\n";
        }
    }
    elsif ( $state eq 'read_variables' ) {
        my @vars = &HomeBase::read_variables($port);
        for my $i ( 0 .. $#vars ) {
            my $name = $hb_var_names[$i];
            $name = 'var_' . ( $i + 1 ) unless $name;
            $hb_var_values{$name} = hex( shift @vars );
            print "Variable:  $name=$hb_var_values{$name}\n";
        }
    }
    else {
        print "unknown request\n";
    }

}

# set_time format??

# read_flags ??

# read log count right??
