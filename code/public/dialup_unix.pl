#Category=Internet
#$Id$

=begin comment

From Gaetan linny Lord on 02/2002

Here is what I have to dial internet, 

First you need a way to get to it with a command line, I use wvdial, and you want to use ipppd.

To get this working, define in mh.ini

net_connect_if=ppp0    or whaterver ppp interface you're using
                       when connected use ifconfig -a to find out
net_connect_up=....    define the actual command line to start the network
                       in my case "nohup wvdial &"
net_connect_time=...   define how long you have to wait before we bailout
                       if there is a problem to initiate the call
net_connect_down=...   define the command line to stop the network


This script: 

 - Connect every morning to fetch some information, and then stop
the connection.

 - Define a new category named internet, where you could start
the network from the GUI. Especially useful if you whant to do stuff from
a remote machine like the Audrey. Then you could get weather etc on-demand.


=cut

if ( time_now "5:55" ) { &start_dialup; }
if ( time_now "5:57" ) { &GetWeather; }
if ( time_now "6:00" ) { &GetComics; }
if ( time_now "6:03" ) { &GetTv; }
if ( time_now "6:35" ) { &stop_dialup; }

$v_dialup = new Voice_Cmd '[Stop,Start,Status] Internet';
$v_dialup->set_info("Start or stop the internet connection");
$v_dialup->set_authority('anyone');

if ( said $v_dialup eq "Start" ) {
    if ( !&net_connect_check ) {
        print_log "dialup.pl: Attempting to start the network, please wait";
        speak "Attempting to start the network, please wait";
        if (&start_dialup) {
            print_log "dialup.pl: Network started";
            speak "Network started";
            return 1;
        }
        else {
            print_log "dialup.pl: Problem, network not started";
            speak "Unable to start the network";
            return 0;
        }
    }
    else {
        print_log "Network already started";
        speak "Network already started";
        return 1;
    }
}

if ( said $v_dialup eq "Stop" ) {
    if (&net_connect_check) {
        print_log "dialup.pl: Attempting to close the network, please wait";
        speak "Attempting to close the network, please wait";
        if (&stop_dialup) {
            print_log "dialup.pl: Network closed";
            speak "Network closed";
            return 1;
        }
        else {
            print_log "dialup.pl: Problem closing the network";
            speak "Problem closing the network";
            return 0;
        }
    }
    else {
        print_log "The network is already stop";
        speak "The network already stop";
        return 1;
    }

}

if ( said $v_dialup eq "Status" ) {
    if (&net_connect_check) {
        print_log "dialup.pl: The connection is up";
        speak "The network connection is up";
        return 1;
    }
    else {
        print_log "dialup.pl: The connection is down";
        speak "The network is down";
        return 1;
    }
}

#$Id$

sub net_inet_check {

    # Linux
    if ( $^O eq "linux" ) {
        my $if = lc( $main::config_parms{net_connect_if} );
        if ( $if eq "" ) {
            print_log "net_connect_if is not defined";
            return 0;
        }

        # this suppose ifconfig in /sbin directory (Redhat nad maybe other distro)
        open( PROC, "/sbin/ifconfig $config_parms{net_connect_if} |" )
          or return 0;
        while (<PROC>) {
            if ( $_ =~ /inet addr/ ) {
                my $IP;

                # inet addr:192.168.1.10  Bcast:192.168.1.255  Mask:255.255.255.0
                close PROC;
                s/\s*inet addr:(\S*)\s.*/$1/;
                return $_;
            }
        }
        close PROC;
        return 0;

        # windows
    }
    else {
        print_log "Function net_inet_check not defined for $^0";
        return 0;
    }
}

sub start_dialup {
    print_log "inst start_dialup";
    unless (&net_connect_check) {
        my $IFUP = "down";
        my $INET;
        my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
          localtime(time);
        $year += 1900;
        $mon  += 1;

        my $LogFile =
          join( ".", "\/tmp\/wvdial.error", $year, $mon, $mday, $hour, $min );
        print_log "Starting Internet connection";

        # we use nohup call to disconnect from the parent process, so if
        # we stop MH, then the connection will stay alive, if you want to
        # keep the connection attach to MH, just remove nohup
        # the "&" detach the process and put in background, so
        # we could get control back to MH
        system(
            "cd \/tmp ; $config_parms{net_connect_up} >$LogFile  2>$LogFile & "
        );
        my $count = 0;

        # we have to validate if the interface come up
        while ( $count++ < $config_parms{net_connect_time} ) {
            sleep 1;
            last if (&net_connect_check);
        }

        # we wait until we receive our IP address
        while ( $count++ < $config_parms{net_connect_time} ) {
            $IFUP = "up";
            sleep 1;
            if ( $INET = &net_inet_check ) {
                unlink $LogFile;
                print_log "$config_parms{net_connect_if}: $INET";
                return 1;
            }
        }
        print_log
          "Can't start Internet, $config_parms{net_connect_time} sec. exceeded";
        print_log
          "The status of the interface $config_parms{net_connect_if} was $IFUP";
        print_log "Log file can be found in $LogFile";
        print_log "Trying to stop internet";
        &stop_dialup;
        return 0;
    }
}

sub stop_dialup {
    system("$config_parms{net_connect_down};");
    if ( $? != 0 ) {
        print_log "Can't stop Internet";
        return 0;
    }
    print_log "Internet stopped";
    return 1;

}
