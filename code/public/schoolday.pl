# Category = Time

#@
#@ These function will calculate if Today or Tomorrow are
#@ schooldays. Multiple schools are supported.
#@ A list of term dates and an optional list of mid-term
#@ holidays are required for each school.

# 2006-01-27 Andrew C Baker andrew@rekabuk.co.uk

#     shoolname => ["start0-end0, start1-end1, ...", "day0,day1"]
my %school_terms = (
    Churston => [ "1/1-28/01, 7/6-18/09, 21/10-21/12", "5/6,3/4,27/01" ],
    Chestnut => [ "1/1-27/02, 7/7-18/10, 21/11-21/12", "" ]
);

# Processed term dates
my %terms;

my $date_format = "ddmmyy";    #config_parms{date_format};

$v_is_school_day = new Voice_Cmd('Is today a school day [Churston,Chestnut]');
$v_is_school_night =
  new Voice_Cmd('Is tonight a school night [Churston,Chestnut]');

#---------------------------------------------
sub Convert_To_ISO8601_Date {
    my $date = shift;

    my ( $y,    $m,  $d );
    my ( $yyyy, $mm, $dd );

    if ( $date_format =~ /ddmm/ ) {
        ( $d, $m, $y ) = split( "/", $date );
    }
    else {
        ( $m, $d, $y ) = split( "/", $date );
    }

    if ( length($m) == 1 ) {
        $mm = "0" . $m;
    }
    else {
        $mm = $m;
    }

    if ( length($d) == 1 ) {
        $dd = "0" . $d;
    }
    else {
        $dd = $d;
    }

    if ( !defined $y ) {
        my $today = today();
        $yyyy = $Year;
    }
    else {
        $yyyy = $y        if length($y) == 4;
        $yyyy = "20" . $y if length($y) == 2;    # This will *only* work until
        2099.;
    }

    # 1 Hour into the day
    #print "Convert out = $dd/$mm/$yyyy\n";
    #Months are 0..11
    return timelocal( 0, 0, 1, $dd, $mm - 1, $yyyy );

}

#---------------------------------------------
sub LoadSchool {
    my $school       = shift;
    my $school_terms = shift;
    my $school_inset = shift;

    my $i;

    # Load Term dates
    $i = 0;
    my $term;
    foreach $term ( split( ",", $school_terms ) ) {
        my ( $start, $finish );
        my ( $d, $m, $y );

        ( $start, $finish ) = split( "-", $term );
        $start  = Convert_To_ISO8601_Date($start);
        $finish = Convert_To_ISO8601_Date($finish);

        $terms{$school}{terms}[$i][0] = $start;
        $terms{$school}{terms}[$i][1] = $finish;

        #print("School=$school, Term=$i, Start=$terms{$school}{terms}[$i][0], Finish=$terms{$school}{terms}[$i][1]\n");
        $i++;
    }

    # Load inset dates
    $i = 0;
    my $inset;
    foreach $inset ( split( ",", $school_inset ) ) {
        my $inset_day;
        $inset_day = Convert_To_ISO8601_Date($inset);

        $terms{$school}{insets}[$i] = $inset_day;

        #print("School=$school, Inset=$i, Date=$terms{$school}{insets}[$i]\n");

        $i++;
    }

}

#---------------------------------------------
if ($Reload) {
    my $school;

    for $school ( keys %school_terms ) {
        LoadSchool(
            $school,
            $school_terms{$school}[0],
            $school_terms{$school}[1]
        );
    }

}

#---------------------------------------------
# Is the supplied day a school day
sub IsSchoolDay {
    my $testdate = shift;
    my $school   = shift;

    # We can accept dd/mm/yy or an epoch number
    if ( $testdate =~ /\// ) {
        $testdate = Convert_To_ISO8601_Date($testdate);
    }

    #print "Test Date (Day) = $testdate\n";

    # No school at the weekend
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime($testdate);
    if ( ( $wday == 6 ) || ( $wday == 0 ) ) {
        return 0;
    }

    #Check term dates
    my ( $j, $k );
    print "$#{ $terms{$school}{terms}}\n";

    for $j ( 0 .. $#{ $terms{$school}{terms} } ) {
        print
          "$j $terms{$school}{terms}[$j][0]] $terms{$school}{terms}[$j][1]\n";
        if (    ( $testdate >= $terms{$school}{terms}[$j][0] )
            and ( $testdate <= $terms{$school}{terms}[$j][1] ) )
        {
            # Now check if it's an inset day
            for $k ( 0 .. $#{ $terms{$school}{insets} } ) {
                if ( $testdate == $terms{$school}{insets}[$k] ) {
                    print_log "Inset day $school";
                    return 0;
                }
            }

            #Need to check for holidays
            #for () {
            #  if Holiday {
            #     return 0
            #}
            #}
            return 1;
        }
    }

    return 0;
}

#---------------------------------------------
# Is the supplied day a school night
sub IsSchoolNight {
    my $testdate = shift;
    my $school   = shift;

    my $testdate_tomorrow;

    # We can accept dd/mm/yy or an epoch number
    if ( $testdate =~ /\// ) {
        $testdate = Convert_To_ISO8601_Date($testdate);
    }

    #Get tomorrows date
    $testdate += 86400;

    #print "Test Date (Night) = $testdate\n";

    # Is tomorrow a school_day?
    return IsSchoolDay( $school, $testdate );
}

#---------------------------------------------
# Is today a school day?
sub IsSchoolToday {
    my $school = shift;

    return 0 if ($Holiday);

    my $iso_date   = $Mday . "/" . $Month . "/" . $Year;
    my $epoch_date = Convert_To_ISO8601_Date($iso_date);

    return IsSchoolDay( $epoch_date, $school );
}

#---------------------------------------------
#Is tomorrow a school day?
sub IsSchoolTomorrow {
    my $school = shift;

    my $iso_date   = $Mday . "/" . $Month . "/" . $Year;
    my $epoch_date = Convert_To_ISO8601_Date($iso_date);

    return IsSchoolNight( $epoch_date, $school );
}

#---------------------------------------------
if ( $state = state_now $v_is_school_day) {

    if ( IsSchoolToday($state) ) {
        speak "Its a $state school day";
    }
    else {
        speak "Its not a $state school day";
    }
}

#---------------------------------------------
if ( $state = state_now $v_is_school_night) {

    if ( IsSchoolTomorrow($state) ) {
        speak "Its a $state school night";
    }
    else {
        speak "Its not a $state school night";
    }
}

