# Category=Garage Door

# Demo / Debugging aid for Stanley Garage Door Status hardware via MisterHouse CM11 interface.

##################################################################
#  Support for Stanley Garage Door Status Transmitter            #
#  (Available from smarthome.com)                                #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

use vars '$door1_old', '$door2_old', '$door3_old', '$warning_sent',
  '$door_moved';

$garage_doors =
  new X10_Garage_Door('D');   # CHANGE THIS to housecode of your RF Vehicle Link
$timer_garage_door = new Timer();
$timer_garage_annc = new Timer();

$Garage_Control = new Serial_Item( 'XD1DJ', 'GC1' );
$Garage_Control->add( 'XD1DK', 'GC2' );
$Garage_Control->add( 'XD2DJ', 'GC3' );
$Garage_Control->add( 'XD2DK', 'GC4' );
$Garage_Control->add( 'XD3DJ', 'GC5' );
$Garage_Control->add( 'XD3DK', 'GC6' );
$timer_garage_override = new Timer();

# Returned state is "bbbdccc"
# "bbb" is 1=door enrolled, 0=enrolled, indexed by door # (i.e. 123)
# "d" is door that caused transmission, numeric 1, 2, or 3
# "ccc" is C=Closed, O=Open, indexed by door #

# Transmission received from door(s)
if ( state_now $garage_doors) {
    my $state = state $garage_doors;
    my ( $en1, $en2, $en3, $which, $door1, $door2, $door3 ) =
      $state =~ /(\S)(\S)(\S)(\S)(\S)(\S)(\S)/;
    my %table_dcode = qw(O Open C Closed);

    my $debug = 1 if $config_parms{debug} eq 'garage';
    if ($debug) {
        print_log "\n\n   Garage Door Transmission Received\n";
        print_log "State=$state\n";
        print_log "Transmission from $which\n";
        print_log "Door 1 state is $table_dcode{$door1}\n" if $en1;
        print_log "Door 2 state is $table_dcode{$door2}\n" if $en2;
        print_log "Door 3 state is $table_dcode{$door3}\n" if $en3;
        print_log "\n";
    }

    if ( $which eq '1' ) {
        if ( $door1 eq $door1_old ) {
            print_log
              "Door 1 timer or retransmit update, door1 $table_dcode{$door1}\n"
              if $debug;
        }
        else {
            $door_moved = 1;
            print_log
              "Door 1 status change, old $table_dcode{$door1_old}, new $table_dcode{$door1}\n";
            &garage_speak("Door <emph>1</emph> is $table_dcode{$door1}");
        }
    }

    if ( $which eq '2' ) {
        if ( $door2 eq $door2_old ) {
            print_log
              "Door 2 timer or retransmit update, door2 $table_dcode{$door2}\n"
              if $debug;
        }
        else {
            $door_moved = 1;
            print_log
              "Door 2 status change, old $table_dcode{$door2_old}, new $table_dcode{$door2}\n";
            &garage_speak("Door <emph>2</emph> is $table_dcode{$door2}");
        }
    }

    if ( $which eq '3' ) {
        if ( $door3 eq $door3_old ) {
            print_log
              "Door 3 timer or retransmit update, door3 $table_dcode{$door3}\n"
              if $debug;
        }
        else {
            $door_moved = 1;
            print_log
              "Door 3 status change, old $table_dcode{$door3_old}, new $table_dcode{$door3}\n";
            &garage_speak("Door <emph>3<emph> is $table_dcode{$door3}");
        }
    }

    $door1_old = $door1;
    $door2_old = $door2;
    $door3_old = $door3;
}    # End of Transmission Received from Door

# If a door actually moved (as opposed to a re-transmit), set/check some timers.
if ($door_moved) {
    my $state = state $garage_doors;
    if ( substr( $state, 4, 3 ) eq "CCC" )
    {    # All Doors Closed, cancel any timers; undo any warnings.
        unset $timer_garage_door;
        unset $timer_garage_annc;
        if ($warning_sent) {
            &garage_notify("Cancel Warning: Garage doors all CLOSED");
            $warning_sent = 0;
        }
    }
    else {    # Start (or push out) a timer if anything is open
        set $timer_garage_door 60 * 5;
        set $timer_garage_annc 60 * 4;
    }
    $door_moved = 0;
}    # End of Door Moved

# Notify Danal if garage door left open, but allow manual overrides

if ( state_now $Garage_Control) {
    my $c_state = state $Garage_Control;
    if ( $c_state eq 'GC1' ) {
        print_log "Garage Door Override timer set to 15 minutes";
        &garage_speak("Garage command 15 acknowledged");
        set $timer_garage_override 15 * 60;
        set $timer_garage_annc 14 * 60;
    }
    if ( $c_state eq 'GC2' ) {
        print_log "Garage Door Override timer set to 30 minutes";
        &garage_speak("Garage command 30 acknowledged");
        set $timer_garage_override 30 * 60;
        set $timer_garage_annc 29 * 60;
    }
    if ( $c_state eq 'GC3' ) {
        print_log "Garage Door Override timer set to 1 hour";
        &garage_speak("Garage command 1 acknowledged");
        set $timer_garage_override 60 * 60;
        set $timer_garage_annc 59 * 60;
    }
    if ( $c_state eq 'GC4' ) {
        print_log "Garage Door Override timer set to 2 hours";
        &garage_speak("Garage command 2 acknowledged");
        set $timer_garage_override 120 * 60;
        set $timer_garage_annc 119 * 60;
    }
    if ( $c_state eq 'GC5' ) {
        print_log "Garage Door Override timer set to 8 hours";
        &garage_speak("Garage command 8 acknowledged");
        set $timer_garage_override 150 * 60;
        set $timer_garage_annc 149 * 60;
    }
    if ( $c_state eq 'GC6' ) {
        print_log "Garage Door Override timer cancelled";
        &garage_speak("Garage command cancel acknowledged");
        set $timer_garage_override 1
          ;    # Set to 1 second to force 'expired' check soon.
        unset $timer_garage_annc;
    }
}    # End of Garage Control button pushed

if ( expired $timer_garage_annc) {
    my $state = state $garage_doors;
    $state = substr( $state, 4, 3 );
    if ( $state ne "CCC" ) {
        speak(
            mode   => 'unmuted',
            volume => 100,
            rooms  => 'garage',
            text   => "Garage doors open; one minute to escalation"
        );
    }
}    # End of expired announcment timer

if ( ( expired $timer_garage_door) and ( inactive $timer_garage_override) ) {
    my $state = state $garage_doors;
    $state = substr( $state, 4, 3 );
    if ( $state ne "CCC" ) {
        if ( !$warning_sent ) {
            &garage_notify(
                "Warning, Garage doors open too long <spell>$state</spell>");
            $warning_sent = 1;
        }
        else {
            speak(
                mode   => 'unmuted',
                volume => 100,
                text   => "Garage Doors OPEN nag nag nag message"
            );
        }
        set $timer_garage_door 60 * 2;
    }
}    # End of expired door timer and no override

if ( expired $timer_garage_override) {
    my $state = state $garage_doors;
    $state = substr( $state, 4, 3 );
    if ( $state ne "CCC" ) {
        &garage_notify(
            "Warning, Garage override expired with doors <spell>$state</spell>"
        );
        $warning_sent = 1;
        set $timer_garage_door 60 * 2;
    }
}    # End of expired override

# Prove we can query garage door data asynchronously

$v_Garage_Query = new Voice_Cmd( 'Query Garage Door', 0 );
$v_Garage_Query->set_info('Print log of garage door status info');

if ( said $v_Garage_Query) {
    my $state = state $garage_doors;
    my ( $en1, $en2, $en3, $which, $door1, $door2, $door3 ) =
      $state =~ /(\S)(\S)(\S)(\S)(\S)(\S)(\S)/;
    my %table_dcode = qw(O Open C Closed);

    print_log "State=$state\n";
    print_log "Last transmission from $which\n";
    print_log "Door 1 state is $table_dcode{$door1}\n" if $en1;
    print_log "Door 2 state is $table_dcode{$door2}\n" if $en2;
    print_log "Door 3 state is $table_dcode{$door3}\n" if $en3;

    my $string = "";
    $string .= "Door 1 is $table_dcode{$door1}\n " if $en1;
    $string .= "Door 2 is $table_dcode{$door2}\n " if $en2;
    $string .= "Door 3 is $table_dcode{$door3}\n " if $en3;
    display $string;
}

# Test notification...

$v_Garage_Mail_Test = new Voice_Cmd( 'Garage Door Mail Test', 0 );

if ( said $v_Garage_Mail_Test) {
    my $state = state $garage_doors;
    $state = substr( $state, 4, 3 );
    &garage_notify("Warning, Garage doors test warning <spell>$state</spell>");
}

# Various maintenance / startup stuff
if (   ($Startup)
    or ($Reload) )
{
    $door1_old    = 'C';
    $door2_old    = 'C';
    $door3_old    = 'C';
    $warning_sent = 0;
    $door_moved   = 0;
}

# Subroutine to send a page / pcs message, etc.
sub garage_notify {
    my ($text) = @_;

    my $p1 = new Process_Item(
        "send_sprint_pcs -to danal -text \"$text $Date_Now $Time_Now\" ");
    start $p1;    # Run externally so as not to hang MH process
    my $p2 = new Process_Item(
        "alpha_page -pin 1488774 -message \"$text $Date_Now $Time_Now\" ");
    start $p2;    # Run externally so as not to hang MH process

    print_log "Garage notification sent, text = $text";
    &garage_speak("$text");
}

# Subroutine to speak in garage or whole house; depends on speak mode.
sub garage_speak {
    my ($text) = @_;
    if ( $Save{mode} eq 'normal' ) {
        speak( volume => 100, text => "Djeeni says: $text" );
    }
    else {
        speak(
            mode   => 'unmuted',
            volume => 100,
            rooms  => 'garage',
            text   => "Djeeni says: $text"
        );
    }
}
