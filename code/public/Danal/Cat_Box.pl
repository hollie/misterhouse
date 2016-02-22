# Category = Nag

#@ Nag to clean the cat box

##################################################################
#  Cat Box items & actions                                       #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$Cat_Box_Control = new Serial_Item( 'XC9CJ', 'Scoop' );
$Cat_Box_Control->add( 'XC9CK', 'Full' );

$Cat_Box_Reminder = new X10_Item('JG');

if ( state_now $Cat_Box_Control) {
    my $state = state $Cat_Box_Control;
    if ( $state eq 'Scoop' ) {
        print_log "Cat Box Button 4 pushed ON - Cat Box Scooped";
        set $Cat_Box_Reminder OFF;
    }
    if ( $state eq 'Full' ) {
        print_log "Cat Box Button 4 pushed OFF - Cat Box full change";
        set $Cat_Box_Reminder OFF;
    }
}

# Check timers for regular cat box.

if ( $New_Minute
    and time_cron '1,31 12,13,14,15,16,17,18,19,20,21,22,23 * * *' )
{
    # Any button on the console, so we can use first entry in state_log.
    my ( $date, $time, $state ) =
      ( state_log $Cat_Box_Control)[0] =~ /(\S+) (\S+) *(.*)/;
    use Time::ParseDate;
    my $tnow  = parsedate('now');
    my $tcat  = parsedate("$date $time");
    my $tdiff = $tnow - $tcat;
    my $days  = int 0.5 + ( $tdiff / ( 24 * 60 * 60 ) );
    print_log
      "Cat Box Timers: Last date/time $date $time, Seconds before now $tdiff, Days before now $days";

    if ( $days > 3 ) {
        print_log "Speaking Cat Box nag message";
        speak(
            volume => 30,
            text   => "Djeeni says: Meow, Scoop the regular cat box"
        );
        set $Cat_Box_Reminder ON if 'on' ne state $Cat_Box_Reminder;
    }
    if ( $days > 4 ) {
        speak( volume => 50, text => "Really! it has been $days days" );
    }
    if ( $days > 5 ) {
        speak( volume => 70, text => "Mau and Pixel say It Stinks!" );
    }
}

# Check timers for automated cat box.

if ( $New_Minute
    and time_cron '1,31 12,13,14,15,16,17,18,19,20,21,22,23 * * *' )
{
    # Search the state_log for state of 'Full'.
    my ( $date, $time, $sl );
    foreach $sl ( state_log $Cat_Box_Control) {
        ( $date, $time ) = $sl =~ /(\S+) (\S+)  Full/;
        last if $1;
    }

    use Time::ParseDate;
    my $tnow  = parsedate('now');
    my $tcat  = parsedate("$date $time");
    my $tdiff = $tnow - $tcat;
    my $days  = int $tdiff / ( 24 * 60 * 60 );

    if ( $tdiff > 9 * 24 * 60 * 60 ) {
        print_log
          "Automated Cat box last changed $days days ago; speaking nag message";
        speak
          "Djeeni says: Meeeoow, Change the automated cat box.  It has been $days days.";
    }

}
