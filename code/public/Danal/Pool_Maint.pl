# Category = Nag

##################################################################
#  Pool Maintenance items & actions                              #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

#$Pool_Maint_Control  = new Serial_Item('XC9CJ','Scoop');
#$Pool_Maint_Control -> add            ('XC9CK','Full');

#$Pool_Maint_Reminder = new X10_Item('JG');

$Pool_Maint_age = new Generic_Item;
$Pool_Maint_age->hidden(0);

if ( state_now $Pool_Maint_age) {
    my $state = state $Pool_Maint_age;
    speak(
        volume => 90,
        text =>
          "Djeeni says: Good Job swimmer, you maintained the pool and spa."
    );
    print_log "Pool Maint age object set to $state; nag timers start now";
}

# Check timers on weekend days

if ( time_cron '3,18,33,48 * * * 0,6' ) {
    my ( $date, $time, $state ) =
      ( state_log $Pool_Maint_age)[0] =~ /(\S+) (\S+) *(.*)/;
    use Time::ParseDate;
    my $tnow  = parsedate('now');
    my $tcat  = parsedate("$date $time");
    my $tdiff = $tnow - $tcat;
    my $days  = int 0.5 + ( $tdiff / ( 24 * 60 * 60 ) );
    print_log
      "Pool Maint age Timers: Last date/time $date $time, Seconds before now $tdiff, Days before now $days";

    if ( $days > 5 ) {
        print_log "Speaking Pool Maint nag message";
        my $state = state $Pool_Maint_age;
        speak(
            volume => 70,
            text =>
              "Djeeni says: Time to maintain the pool and spa, please shock the pool with $state."
        );

        #set $Pool_Maint_Reminder ON if 'on' ne state $Pool_Maint_Reminder;
    }
    if ( $days > 8 ) {
        speak( volume => 90, text => "Really! You skipped last weekend" );
    }
    if ( $days > 12 ) {
        speak( volume => 90, text => "Come on, it has been $days days." );
    }
}

# Check timers on week days

if ( time_cron '33 6,7,8,9,10 * * 1,2,3,4,5' ) {
    my ( $date, $time, $state ) =
      ( state_log $Pool_Maint_age)[0] =~ /(\S+) (\S+) *(.*)/;
    use Time::ParseDate;
    my $tnow  = parsedate('now');
    my $tcat  = parsedate("$date $time");
    my $tdiff = $tnow - $tcat;
    my $days  = int 0.5 + ( $tdiff / ( 24 * 60 * 60 ) );
    print_log
      "Pool Maint age Timers: Last date/time $date $time, Seconds before now $tdiff, Days before now $days";

    if ( $days > 8 ) {
        print_log "Speaking Pool Maint nag message";
        speak(
            volume => 50,
            text =>
              "Djeeni says: You skipped a weekend, Time to catch up on pool maintenance"
        );
        speak( volume => 50, text => "Please shock the pool with $state." );

        #set $Pool_Maint_Reminder ON if 'on' ne state $Pool_Maint_Reminder;
    }
    if ( $days > 14 ) {
        speak( volume => 90, text => "Really! You skipped last weekend" );
        speak( volume => 90, text => "Come on, it has been $days days." );
    }
}
