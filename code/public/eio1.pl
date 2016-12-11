# Category=Other
# $Author$
# $Id$
# $Date$
# Revision$
#
# This routine interfaces the EIO board manufactured by Hugh Duff, VA3TO
# Paul Caccamo, VA3PC - 2010-Jan-12
# Comments to:   paul at ciinet dot org
# This routine assumes that you have initialized the board
# with an IP address and it works with the windows EIO software
# to do - modify the code with placeholders in case of more than one board
# this was working on a LAMP ClearOS server.  ymmv if you use windows

# initialize poll rate , looptimeout and hex byte relay control commands
# logfile required if you want the board relays to reload after a power bump.
my $eio1PollRate = 1;      # the poll rate (in seconds) that you want updates
my $loop1timeout = 150;    # the number of unresponsive code loops

#			where you consider the board not responding
#			on my P3-933 this is about 6 seconds
my @R1on = ( 0x0001, 0x0000 );    # this turns the relays on or off
my @R2on = ( 0x0002, 0x0000 );    # in vax style hex bytes
my @R3on = ( 0x0003, 0x0000 );
my @R4on = ( 0x0004, 0x0000 );
my @R1of = ( 0x00a1, 0x0000 );
my @R2of = ( 0x00a2, 0x0000 );
my @R3of = ( 0x00a3, 0x0000 );
my @R4of = ( 0x00a4, 0x0000 );

# modify the following items and code for more than one board in the system
# misterhouse is installed in /opt/misterhouse as suggested in faq's
my $eio1DataLog = '/opt/misterhouse/data/logs/eio1data';
my $client1_address = '192.168.36.61:5000';    # my EIO board address and port

# set up the output states for the socket port
$eio1 = new Socket_Item( "SEND INFORMATION NOW\n",
    "status", $client1_address, "EIO-1", 'udp', 'rawout' );
$eio1->add( pack( 'v*', @R1on ), "E1R1 on" );    # relay control commands
$eio1->add( pack( 'v*', @R2on ), "E1R2 on" );
$eio1->add( pack( 'v*', @R3on ), "E1R3 on" );
$eio1->add( pack( 'v*', @R4on ), "E1R4 on" );
$eio1->add( pack( 'v*', @R1of ), "E1R1 off" );
$eio1->add( pack( 'v*', @R2of ), "E1R2 off" );
$eio1->add( pack( 'v*', @R3of ), "E1R3 off" );
$eio1->add( pack( 'v*', @R4of ), "E1R4 off" );

# set up generic items for the inputs / outputs web page display
$eio1I1 = new Generic_Item;
$eio1I2 = new Generic_Item;
$eio1I3 = new Generic_Item;
$eio1I4 = new Generic_Item;
$eio1R1 = new Generic_Item;
$eio1R2 = new Generic_Item;
$eio1R3 = new Generic_Item;
$eio1R4 = new Generic_Item;

# set up control items for the voice commands
$v_eio1R1 = new Voice_Cmd("EIO1 Relay 1 [on,off]");
$v_eio1R2 = new Voice_Cmd("EIO1 Relay 2 [on,off]");
$v_eio1R3 = new Voice_Cmd("EIO1 Relay 3 [on,off]");
$v_eio1R4 = new Voice_Cmd("EIO1 Relay 4 [on,off]");

#  initialize temp variables.
use vars '$eio1last', '$loop1count';

# if the EIO board commus are not active, start the port
if ( $Startup || $Reload ) {
    start $eio1;
    print_log "Comms with EIO1 established";
    &reload_board1;
}

# poll the board for the current status at eioPollRate (secs)
if ( new_second $eio1PollRate ) {
    set $eio1 "status";
}

# increment the loop counter
$loop1count++;

# determine the current point status when the board replies
# compare it to the last known status and note any differences in the log file
# re-evaluate the data on each reply in order to set the flags on the web page.
# do this if the board hasn't timed out, if it has, reset the relays to last state
if ( my $eio1data = said $eio1) {    # first check to see if the board responds
    if ( $loop1count > $loop1timeout )
    {                                # the board previously timed out - its back
        &reload_board1;              # reload the last known state
    }
    elsif ( $eio1data ne $eio1last )
    {                                # (no timeout) new data since last response
        $eio1last = $eio1data;       # save the new data for next pass thru
        my $eio1out =
          substr( $eio1data, 0, -10 );    # parse the reply of extra characters
        logit( $eio1DataLog, $eio1out, 12 );    # append change to the logfile
              #	update the changed status icons on the web page
        if ( ( state $eio1I4 == OFF ) && ( substr( $eio1data, 1, 1 ) eq "0" ) )
        {
            set $eio1I4 ON;
        }
        elsif (( state $eio1I4 == ON )
            && ( substr( $eio1data, 1, 1 ) eq "1" ) )
        {
            set $eio1I4 OFF;
        }
        if ( ( state $eio1I3 == OFF ) && ( substr( $eio1data, 2, 1 ) eq "0" ) )
        {
            set $eio1I3 ON;
        }
        elsif (( state $eio1I3 == ON )
            && ( substr( $eio1data, 2, 1 ) eq "1" ) )
        {
            set $eio1I3 OFF;
        }
        if ( ( state $eio1I2 == OFF ) && ( substr( $eio1data, 3, 1 ) eq "0" ) )
        {
            set $eio1I2 ON;
        }
        elsif (( state $eio1I2 == ON )
            && ( substr( $eio1data, 3, 1 ) eq "1" ) )
        {
            set $eio1I2 OFF;
        }
        if ( ( state $eio1I1 == OFF ) && ( substr( $eio1data, 4, 1 ) eq "0" ) )
        {
            set $eio1I1 ON;
        }
        elsif (( state $eio1I1 == ON )
            && ( substr( $eio1data, 4, 1 ) eq "1" ) )
        {
            set $eio1I1 OFF;
        }
        if ( ( state $eio1R4 == OFF ) && ( substr( $eio1data, 6, 1 ) eq "1" ) )
        {
            set $eio1R4 ON;
        }
        elsif (( state $eio1R4 == ON )
            && ( substr( $eio1data, 6, 1 ) eq "0" ) )
        {
            set $eio1R4 OFF;
        }
        if ( ( state $eio1R3 == OFF ) && ( substr( $eio1data, 7, 1 ) eq "1" ) )
        {
            set $eio1R3 ON;
        }
        elsif (( state $eio1R3 == ON )
            && ( substr( $eio1data, 7, 1 ) eq "0" ) )
        {
            set $eio1R3 OFF;
        }
        if ( ( state $eio1R2 == OFF ) && ( substr( $eio1data, 8, 1 ) eq "1" ) )
        {
            set $eio1R2 ON;
        }
        elsif (( state $eio1R2 == ON )
            && ( substr( $eio1data, 8, 1 ) eq "0" ) )
        {
            set $eio1R2 OFF;
        }
        if ( ( state $eio1R1 == OFF ) && ( substr( $eio1data, 9, 1 ) eq "1" ) )
        {
            set $eio1R1 ON;
        }
        elsif (( state $eio1R1 == ON )
            && ( substr( $eio1data, 9, 1 ) eq "0" ) )
        {
            set $eio1R1 OFF;
        }
    }
    $loop1count = 0;    # reset the loop counter
}

# voice command the relays
if ( $state = said $v_eio1R1) {
    if ( $state eq ON ) {

        #	print_log "setting Relay 1 on\n";
        set $eio1 "E1R1 on";
    }
    elsif ( $state eq OFF ) {

        #	print_log "setting Relay 1 off\n";
        set $eio1 "E1R1 off";
    }
}

elsif ( $state = said $v_eio1R2) {
    if ( $state eq ON ) {

        #	print_log "setting Relay 2 on\n";
        set $eio1 "E1R2 on";
    }
    elsif ( $state eq OFF ) {

        #	print_log "setting Relay 2 off\n";
        set $eio1 "E1R2 off";
    }
}

elsif ( $state = said $v_eio1R3) {
    if ( $state eq ON ) {

        #	print_log "setting Relay 3 on\n";
        set $eio1 "E1R3 on";
    }
    elsif ( $state eq OFF ) {

        #	print_log "setting Relay 3 off\n";
        set $eio1 "E1R3 off";
    }
}

elsif ( $state = said $v_eio1R4) {
    if ( $state eq ON ) {

        #	print_log "setting Relay 4 on\n";
        set $eio1 "E1R4 on";
    }
    elsif ( $state eq OFF ) {

        #	print_log "setting Relay 4 off\n";
        set $eio1 "E1R4 off";
    }
}

sub reload_board1 {
    my $log1file =
      $eio1DataLog;    #determine the last used datafile (log rotation)
    if ( file_size($log1file) == 0 ) {
        $log1file .= ".1";
    }                                           #in case logs have rotated
    print_log "selected logfile: $log1file";    #diagnostic
    my $oldstate = file_tail( $log1file, 1 );   #get last line (previous state)
    print_log "EIO-1 reloaded - Oldstate: $oldstate";

    # set relays and input, output display variables for webpage
    if   ( substr( $oldstate, 21, 1 ) eq "0" ) { set $eio1I4 ON; }
    else                                       { set $eio1I4 OFF; }
    if   ( substr( $oldstate, 22, 1 ) eq "0" ) { set $eio1I3 ON; }
    else                                       { set $eio1I3 OFF; }
    if   ( substr( $oldstate, 23, 1 ) eq "0" ) { set $eio1I2 ON; }
    else                                       { set $eio1I2 OFF; }
    if   ( substr( $oldstate, 24, 1 ) eq "0" ) { set $eio1I1 ON; }
    else                                       { set $eio1I1 OFF; }

    if ( substr( $oldstate, 26, 1 ) eq "1" ) {
        set $eio1 "E1R4 on";
        set $eio1R4 ON;
    }
    else { set $eio1R4 OFF; }
    if ( substr( $oldstate, 27, 1 ) eq "1" ) {
        set $eio1 "E1R3 on";
        set $eio1R3 ON;
    }
    else { set $eio1R3 OFF; }
    if ( substr( $oldstate, 28, 1 ) eq "1" ) {
        set $eio1 "E1R2 on";
        set $eio1R2 ON;
    }
    else { set $eio1R2 OFF; }
    if ( substr( $oldstate, 29, 1 ) eq "1" ) {
        set $eio1 "E1R1 on";
        set $eio1R1 ON;
    }
    else { set $eio1R1 OFF; }
}
