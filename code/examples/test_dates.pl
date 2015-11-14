
# Test functions from the Use the Date::Manip module.
# We don't load this by default, as it takes about 3 meg of memory.
# Documentation is in mh/lib/site/Date/Manip.txt

$test_dates = new Voice_Cmd 'Test date functions';

if ($Startup) {
    use Date::Manip;

    # Date::Manip needs it in ISO 8601 form: +-HHMM
    # ... hmmm, this messes up str2time from Date::Parse
    # used by net_mail_summary :(
    $ENV{TZ} = ( ( $config_parms{time_zone} < 0 ) ? '-' : '+' )
      . sprintf( "%02d00", abs $config_parms{time_zone} );
}

if ( said $test_dates) {
    print_log "Starting date test\n";
    print_log &ParseDate("today");
    print_log &ParseDate("1st thursday in June 1992");
    print_log &ParseDate("05/10/93");
    print_log &ParseDate("12:30 Dec 12th 1880");
    print_log &ParseDate("8:00pm december tenth");

    my ( $date1, $date2, $err, $delta );
    $date1 = &ParseDate('today');
    $date2 = &ParseDate('tomorrow');
    $delta = &Date_Cmp( $date1, $date2 );
    if ( $delta < 0 ) {
        print_log "Date2 is later";
    }
    elsif ( $delta == 0 ) {
        print_log "Dates are equal";
    }
    else {
        print_log "Date2 is earlier";
    }

    print_log &UnixDate( "today", "It is now %T on %b %e, %Y." );

    $date1 = &ParseDate('yesterday');
    $date2 = &ParseDate('tomorrow');
    print_log &DateCalc( $date1, $date2, \$err );

    #  => 0:0:WK:DD:HH:MM:SS   the weeks, days, hours, minutes,
    #                          and seconds between the two

    print_log &DateCalc( "today", "+ 3hours 12minutes 6 seconds", \$err );
    print_log &DateCalc( "12 hours ago", "12:30 6Jan90", \$err );
}

