# Category=Compool
# Some simple events to debug new Compool subroutines

$v_compool_test = new Voice_Cmd(
    'Test compool [status,set_time,set_temp,get_temp,get_temp_now,set_device,get_device]'
);

if (   &Compool::get_temp_now( $Serial_Ports{Compool}{object}, 'pool' )
    && &Compool::get_temp( $Serial_Ports{Compool}{object}, 'pool' ) < 100 )
{
    print "Compool temperature below 100, turning on heater\n";
}

#my $test = &Compool::get_device_now($Serial_Ports{Compool}{object},'pool');
#unless($test eq undef) {print "Setting is " . $test . "\n";};

if ( &Compool::get_device_now( $Serial_Ports{Compool}{object}, 'pool' ) ) {
    print "The pool is now "
      . &Compool::get_device( $Serial_Ports{Compool}{object}, 'pool' ) . "\n";
}

if ( &Compool::get_device_now( $Serial_Ports{Compool}{object}, 'aux1' ) ) {
    print "The aux1 is now "
      . &Compool::get_device( $Serial_Ports{Compool}{object}, 'aux1' ) . "\n";
}

if ( $state = said $v_compool_test) {
    my $port = $Serial_Ports{Compool}{object};
    print_log "Running Compool test $state on port object $port";

    if ( $state eq 'set_time' ) {
        if ( &Compool::set_time($port) != -1 ) {
            print "Compool time was set to $Time_Now\n";
        }
        else {
            print "Error in setting HomeBase time\n";
        }
    }
    elsif ( $state eq 'set_temp' ) {
        if ( &Compool::set_temp( $port, 'pool', 96 ) != -1 ) {
            print "Compool set temp ok\n";
        }
        else {
            print "Error in setting Compool temp\n";
        }
    }
    elsif ( $state eq 'get_temp' ) {
        print "Pool Temperature is "
          . &Compool::get_temp( $port, 'pool' )
          . " degrees\n";
    }
    elsif ( $state eq 'set_device' ) {
        if ( &Compool::set_device( $port, 'aux1', 'on' ) != -1 ) {
            print "Compool set_device ok\n";
        }
        else {
            print "Error in setting Compool set_device\n";
        }
    }
    elsif ( $state eq 'get_device' ) {
        print "Pool is: " . &Compool::get_device_now( $port, 'pool' ) . "\n";
    }
    elsif ( $state eq 'status' ) {

        # Basic temperature settings
        print "Pool Temperature is : "
          . &Compool::get_temp( $port, 'pool' )
          . " degrees\n";
        print "Spa Temperature is  : "
          . &Compool::get_temp( $port, 'spa' )
          . " degrees\n";
        print "Air Temperature is  : "
          . &Compool::get_temp( $port, 'air' )
          . " degrees\n";

        # Primary equipment
        print "The Spa is          : "
          . &Compool::get_device( $port, 'spa' ) . "\n";
        print "The Pool is         : "
          . &Compool::get_device( $port, 'pool' ) . "\n";
        print "The Aux1 is         : "
          . &Compool::get_device( $port, 'aux1' ) . "\n";
        print "The Aux2 is         : "
          . &Compool::get_device( $port, 'aux2' ) . "\n";
        print "The Aux3 is         : "
          . &Compool::get_device( $port, 'aux3' ) . "\n";
        print "The Aux4 is         : "
          . &Compool::get_device( $port, 'aux4' ) . "\n";
        print "The Aux5 is         : "
          . &Compool::get_device( $port, 'aux5' ) . "\n";
        print "The Aux6 is         : "
          . &Compool::get_device( $port, 'aux6' ) . "\n";

        # Secondary equipment
        print "The Service mode is : "
          . &Compool::get_device( $port, 'service' ) . "\n";
        print "The Heater is       : "
          . &Compool::get_device( $port, 'heater' ) . "\n";
        print "The Solar is        : "
          . &Compool::get_device( $port, 'solar' ) . "\n";
        print "The Remote is       : "
          . &Compool::get_device( $port, 'remote' ) . "\n";
        print "The Display is      : "
          . &Compool::get_device( $port, 'display' ) . "\n";
        print "Solar is available  : "
          . &Compool::get_device( $port, 'allowsolar' ) . "\n";
        print "The aux7 is         : "
          . &Compool::get_device( $port, 'aux7' ) . "\n";
        print "The Freeze mode is  : "
          . &Compool::get_device( $port, 'freeze' ) . "\n";
    }
    else {
        print "unknown request\n";
    }

}
