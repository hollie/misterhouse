#!/usr/bin/perl -w

#use Strict;
use Time::Local;

my $debug = 0;

my @Month = (
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
);
my @Day = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" );
my @Date = localtime();
$Date[5] += 1900;

sub GetCstring {
    my ( $len, $x, $str );
    $str = "";
    read( CF, $len, 1 ) or die "unable to get cstring length: $!\n";
    $x = unpack "C", $len;
    if ( $x == 0xFF ) {
        read( CF, $x, 2 ) or die "unable to get long on Cstring: $!\n";
        $len .= $x;
        $x = unpack "s", $x;
    }

    read( CF, $str, $x )
      or die "unable to get Cstring contents: $!\n"
      unless ( $x == 0 );
    return ( $len, $str );
}

sub GetLong {
    my ( $long, $x );
    $x = "";
    read( CF, $long, 4 ) or die "unable to get long: $!\n";
    $x = unpack "l", $long;
    return ( $long, $x );
}

sub GetShort {
    my ( $short, $x );
    $x = "";
    read( CF, $short, 2 ) or die "unable to get short: $!\n";
    $x = unpack "s", $short;
    return ( $short, $x );
}

#########################################################################

my $idx = 0;

my ( $ctabPath, $dbpath, $dbuser );

$ctabPath = shift(@ARGV);

while (@ARGV) {
    $dbpath = shift(@ARGV);
    $dbuser = shift(@ARGV);
    &parseDatebook;
}

&writeOutCalendar;

exit;

# The following arrays hold the incoming records in discrete
# arrays for each field.

my @db_record_who = ();
my @db_record_ok  = ();

# The field types
my @db_ft1  = ();
my @db_ft2  = ();
my @db_ft3  = ();
my @db_ft4  = ();
my @db_ft5  = ();
my @db_ft6  = ();
my @db_ft7  = ();
my @db_ft8  = ();
my @db_ft9  = ();
my @db_ft10 = ();
my @db_ft11 = ();
my @db_ft12 = ();
my @db_ft13 = ();
my @db_ft14 = ();
my @db_ft15 = ();

# The fields
my @db_record_id         = ();
my @db_status            = ();
my @db_position          = ();
my @db_start_time        = ();
my @db_end_time          = ();
my @db_always_zero       = ();
my @db_description       = ();
my @db_duration          = ();
my @db_note              = ();
my @db_untimed           = ();
my @db_private           = ();
my @db_category          = ();
my @db_alarm_set         = ();
my @db_alarm_adv_time    = ();
my @db_alarm_adv_type    = ();
my @db_date_exception    = ();
my @db_date_except_table = ();

# Repeat Event Data , These fields vary depending upon the brand
# of the repeat

my @db_repeat_event = ();
my @db_re_c1        = ();
my @db_re_cll       = ();
my @db_re_class     = ();
my @db_re_length    = ();
my @db_re_string    = ();
my @db_re_brand     = ();
my @db_re_interval  = ();
my @db_re_enddate   = ();
my @db_re_firstdow  = ();
my @db_re_usecount  = ();
my @db_re_dayindex  = ();
my @db_re_daysmask  = ();
my @db_re_weekidx   = ();
my @db_re_daynum    = ();
my @db_re_monthidx  = ();

sub parseDatebook {

    my $i = 0;

    print STDERR "Opening datebook.dat file.. ";
    open( CF, "<${dbpath}/datebook/datebook.dat" )
      or die "Can't open datebook.dat : $!\n";
    print STDERR "OK\n";
    binmode(CF);

    my $buf = "";

    my $long_version = 1145176320;

    print STDERR "Reading version tag ..";
    read( CF, $tag, 4 ) or die "unable to get Tag: $!\n";
    $buf .= $tag;
    $x = &readLong($tag);
    if ( $x != $long_version ) {
        printf "expected $long_version, got %d", $x;
    }
    print STDERR "\n";

    print STDERR "Reading file name ..";
    ( $fn_l, $fn ) = GetCstring();
    $buf .= $fn_l . $fn;
    print STDERR "Got file name $fn" if $debug;
    print STDERR "\n";

    print STDERR "Reading table string..";
    ( $ts_l, $ts ) = GetCstring();
    $buf .= $ts_l . $ts;
    print STDERR "Got table string $ts" if $debug;
    print STDERR "\n";

    print STDERR "Reading next category id..";
    ( $cnextid, $x ) = GetLong();
    $buf .= $cnextid;
    print STDERR "Got Next Category ID $x" if $debug;
    if ( $x != 130 and $x != 128 ) {
        print STDERR "Unexpected value, wanted 128 or 130 but got $x";
    }
    print STDERR "\n";

    print STDERR "Reading category count..";
    ( $c_n, $x ) = GetLong();
    $buf .= $c_n;
    print STDERR "Got Category Count $x" if $debug;
    $c_n = &readLong($c_n);
    print STDERR "\n";

    # iterate thru the categories (if present)

    print STDERR "Reading $x categories.." unless $x == 0;
    $i = 0;
    while ( $i < $c_n ) {
        print STDERR "\n  Reading category $i index..";
        ( $ci[$i], $x ) = GetLong();
        $buf .= $ci[$i];
        print STDERR "	 Got Category Index $x\n" if $debug;
        print STDERR "	   Reading category $i ID..";
        ( $cid[$i], $x ) = GetLong();
        $buf .= $cid[$i];
        print STDERR "	 Got Category ID $x \n" if $debug;
        print STDERR "	   Reading category $i Dirty Flag..";
        ( $cname_dirty[$i], $x ) = GetLong();
        $buf .= $cname_dirty[$i];
        print STDERR "	 Got Category Dirty Flag $x \n" if $debug;

        if ( $x && $x != 1 ) {
            print STDERR "Unexpected result, got $x wanted 1 or 0\n";
        }
        print STDERR "	   Reading category $i long name..";
        ( $cl, $clong_name[$i] ) = GetCstring();
        $buf .= $cl;
        $buf .= $clong_name[$i];
        print STDERR "	 Got Category Long Name $clong_name[$i] \n" if $debug;
        print STDERR "	   Reading category $i short name..";
        ( $cs, $cshort_name[$i] ) = GetCstring();
        $buf .= $cs;
        $buf .= $cshort_name[$i];
        print STDERR "	 Got Category Short Name $cshort_name[$i] \n" if $debug;
        print STDERR "$cshort_name[$i]\n";
        $i++;
    }

    print STDERR "Reading resource ID..";

    ( $resid, $x ) = GetLong();
    $buf .= $resid;
    print STDERR "Got Resource ID $x \n" if $debug;
    if ( $x != 54 ) {
        print STDERR "Expected 54 got $x";
    }
    print STDERR "\n";

    print STDERR "Reading schema fields per row..";

    ( $fpr, $x ) = GetLong();
    $buf .= $fpr;
    print STDERR "Got Fields per row $x \n" if $debug;
    unless ( $x == 15 ) {
        print STDERR "Expected 15 got $x";
    }
    print STDERR "\n";

    print STDERR "Reading schema record ID position..";

    ( $recidpos, $x ) = GetLong();
    $buf .= $recidpos;
    print STDERR "Got Record ID Position $x \n" if $debug;
    unless ( $x == 1 ) {
        print STDERR "Expected 1 got $x";
    }
    print STDERR "\n";

    print STDERR "Reading schema record status position..";

    ( $recstpos, $x ) = GetLong();
    $buf .= $recstpos;
    print STDERR "Got Record Status Position $x \n" if $debug;
    unless ( $x == 2 ) {
        print STDERR "Expected 2 got $x";
    }
    print STDERR "\n";

    print STDERR "Reading schema record placement position..";

    ( $placepos, $x ) = GetLong();
    $buf .= $placepos;
    print STDERR "Got Placement Position $x \n" if $debug;
    unless ( $x == 3 ) {
        print STDERR "Expected 3 got $x";
    }
    print STDERR "\n";

    print STDERR "Reading schema field count..";

    ( $sfldcnt, $x ) = GetShort();
    $buf .= $sfldcnt;
    print STDERR "Got Schema Field Count $x \n" if $debug;
    $td_nf = $x;
    unless ( $x == 15 ) {
        print STDERR "Expected 15 got $x";
    }
    print STDERR "\n";

    $i = 0;
    @schema_tab = ( 1, 1, 1, 3, 1, 5, 1, 5, 6, 6, 1, 6, 1, 1, 8 );

    # iterate thru schema fields

    print STDERR "Reading schema fields...\n";

    while ( $i < $td_nf ) {
        print STDERR "  schema field $i..." if $debug;
        ( $schema_ft[$i], $x ) = GetShort();
        print STDERR "   schema_ft $i is $x: $!\n" if $debug;
        $buf .= $schema_ft[$i];
        unless ( $x == $schema_tab[$i] ) {
            print STDERR "expected $schema_tab[$i] got $x\n";
        }
        $i++;
    }

    #  $buf has all header entries pre-loaded to this point. We stop
    #  at entry_size in case we are going to add entries to the
    #  file.

    print STDERR "Reading entry size..";

    ( $entry_size, $x ) = GetLong();
    print STDERR "Got Entry Size $x \n" if $debug;
    $entry_size = $x;
    print STDERR "OK, got $entry_size" if $debug;
    $entries = $entry_size / 15;
    print STDERR "Number of entries is $entries" if $debug;
    print STDERR "\n";

    print STDERR "Completed reading header, starting on datebook records\n";

    print STDERR "Expecting $entries records on the file\n\n\n";

    my @repeat_event = qw ( norepeat daily weekly monthlybyday
      monthlybydate yearlybydate yearlybydate );

    $i = 0;
    while ( $i < $entries ) {

        $err = 0;

        # "Reading field type..";

        ( $db_ft1[$idx], $x ) = GetLong();
        print STDERR "** db_ft1 $i is $x	 ***\n" if $debug;
        unless ( $x == 1 ) {
            $err++;
            print STDERR "Expected 1 got $x\n";
        }

        # "Reading record id..";

        ( $db_record_id[$idx], $x ) = GetLong();
        print STDERR "   db_record_id $i is $x\n" if $debug;

        # "Reading field type..";

        ( $db_ft2[$idx], $x ) = GetLong();
        print STDERR "   db_ft2 $i is $x\n" if $debug;
        unless ( $x == 1 ) {
            $err++;
            print STDERR "Expected 1 got $x\n";
        }

        # "Reading record status..";

        ( $db_status[$idx], $x ) = GetLong();
        print STDERR "   db_status $i is $x\n" if $debug;
        if ( ( $x != 0 ) and $debug ) {
            print STDERR " PENDING" if ( $x & 0x08 );
            print STDERR " ADD"     if ( $x & 0x01 );
            print STDERR " UPDATE"  if ( $x & 0x02 );
            print STDERR " DELETE"  if ( $x & 0x04 );
            print STDERR " ARCHIVE" if ( $x & 0x80 );
            print STDERR "\n";
        }

        # "Reading field type..";

        ( $db_ft3[$idx], $x ) = GetLong();
        print STDERR "   db_ft3 $i is $x\n" if $debug;
        unless ( $x == 1 ) {
            $err++;
            print STDERR "Expected 1 got $x\n";
        }

        # "Reading record position..";

        ( $db_position[$idx], $x ) = GetLong();
        print STDERR "   db_position $i is $x\n" if $debug;

        # "Reading field type..";
        ( $db_ft4[$idx], $x ) = GetLong();
        print STDERR "   db_ft4 $i is $x\n" if $debug;
        unless ( $x == 3 ) {
            $err++;
            print STDERR "Expected 3 got $x\n";
        }

        # "Reading entry start time..";

        ( $db_start_time[$idx], $x ) = GetLong();
        print STDERR "   db_start_time $i is $x\n" if $debug;
        @Date = localtime( &readLong( $db_start_time[$idx] ) );
        $Date[5] += 1900;
        print STDERR "Date: $Day[$Date[6]], $Date[3] $Month[$Date[4]] $Date[5] "
          . sprintf( "%02d:%02d:%02d $tzval\n", $Date[2], $Date[1], $Date[0] )
          if $debug;

        #"Reading field type..";

        ( $db_ft5[$idx], $x ) = GetLong();
        print STDERR "   db_ft5 $i is $x\n" if $debug;
        unless ( $x == 1 ) {
            $err++;
            print STDERR "Expected 1 got $x\n";
        }

        # "Reading entry end time..";

        ( $db_end_time[$idx], $x ) = GetLong();
        print STDERR "   db_end_time $i is $x\n" if $debug;
        @Date = localtime( &readLong( $db_end_time[$idx] ) );
        $Date[5] += 1900;
        print STDERR "Date: $Day[$Date[6]], $Date[3] $Month[$Date[4]] $Date[5] "
          . sprintf( "%02d:%02d:%02d $tzval\n", $Date[2], $Date[1], $Date[0] )
          if $debug;

        # "Reading field type..";

        ( $db_ft6[$idx], $x ) = GetLong();
        print STDERR "   db_ft6 $i is $x\n" if $debug;
        unless ( $x == 5 ) {
            $err++;
            print STDERR "Expected 5 got $x\n";
        }

        # "Reading padding..";

        ( $db_always_zero[$idx], $x ) = GetLong();
        print STDERR "   db_always_zero $i is $x\n" if $debug;
        if ($x) {
            $err++;
            push @curbuf, "Expected 0 got $x\n";
        }

        # "Reading description..";

        ( $x, $db_description[$idx] ) = GetCstring();
        print STDERR "   db_description $i is $db_description[$idx]\n"
          if $debug;

        # "Reading field type..";

        ( $db_ft7[$idx], $x ) = GetLong();
        print STDERR "   db_ft7 $i is $x\n" if $debug;
        unless ( $x == 1 ) {
            $err++;
            print STDERR "Expected 1 got $x\n";
        }

        # "Reading duration..";

        ( $db_duration[$idx], $x ) = GetLong();
        print STDERR "   db_duration $i is $x\n" if $debug;

        # "Reading field type..";

        ( $db_ft8[$idx], $x ) = GetLong();
        print STDERR "   db_ft8 $i is $x\n" if $debug;
        unless ( $x == 5 ) {
            $err++;
            print STDERR "Expected 5 got $x\n";
        }

        # "Reading padding..";

        ( $db_always_zero[$idx], $x ) = GetLong();
        print STDERR "   db_always_zero $i is $x\n" if $debug;
        if ($x) {
            $err++;
            print STDERR "Expected 0 got $x\n";
        }

        # "Reading Note..";

        ( $x, $db_note[$idx] ) = GetCstring();
        print STDERR "   db_note $i is $db_note[$idx]\n" if $debug;

        # "Reading field type..";

        ( $db_ft9[$idx], $x ) = GetLong();
        print STDERR "   get db_ft9 $i is $x\n" if $debug;
        unless ( $x == 6 ) {
            $err++;
            push @curbuf, "Expected 6 got $x\n";
        }

        # "Reading untimed..";

        ( $db_untimed[$idx], $x ) = GetLong();
        print STDERR "   db_untimed $i is $x\n" if $debug;
        if ( $x && $x != 1 ) {
            $err++;
            print STDERR "Expected 0 or 1 got $x\n";
        }

        # "Reading field type..";

        ( $db_ft10[$idx], $x ) = GetLong();
        print STDERR "   db_ft10 $i is $x\n" if $debug;
        unless ( $x == 6 ) {
            $err++;
            print STDERR "Expected 6 got $x\n";
        }

        # "Reading private..";

        ( $db_private[$idx], $x ) = GetLong();
        print STDERR "   db_private $i is $x\n" if $debug;
        if ( $x && $x != 1 ) {
            $err++;
            print STDERR "Expected 0 or 1 got $x\n";
        }

        # "Reading field type..";

        ( $db_ft11[$idx], $x ) = GetLong();
        print STDERR "   db_ft11 $i is $x\n" if $debug;
        unless ( $x == 1 ) {
            $err++;
            print STDERR "Expected 1 got $x\n";
        }

        # "Reading category..";

        ( $db_category[$idx], $x ) = GetLong();
        print STDERR "   db_category $i is $x\n" if $debug;

        # "Reading field type..";

        ( $db_ft12[$idx], $x ) = GetLong();
        print STDERR "   db_ft12 $i is $x\n" if $debug;
        unless ( $x == 6 ) {
            $err++;
            print STDERR "Expected 6 got $x\n";
        }

        # "Reading alarm set..";

        ( $db_alarm_set[$idx], $x ) = GetLong();
        print STDERR "   db_alarm_set $i is $x\n" if $debug;
        if ( $x && $x != 1 ) {
            $err++;
            push @curbuf, "Expected 0 or 1 got $x\n";
        }

        # "Reading field type..";

        ( $db_ft13[$idx], $x ) = GetLong();
        print STDERR "   db_ft13 $i is $x\n" if $debug;
        unless ( $x == 1 ) {
            $err++;
            print STDERR "Expected 1 got $x\n";
        }

        # "Reading alarm advance time..";

        ( $db_alarm_adv_time[$idx], $x ) = GetLong();
        print STDERR "   db_alarm_adv_time $i is $x\n" if $debug;

        # "Reading field type..";

        ( $db_ft14[$idx], $x ) = GetLong();
        print STDERR "   db_ft14 $i is $x\n" if $debug;
        unless ( $x == 1 ) {
            $err++;
            print STDERR "Expected 1 got $x\n";
        }

        # "Reading alarm advance units..";

        ( $db_alarm_adv_type[$idx], $x ) = GetLong();
        print STDERR "   db_alarm_adv_type $i is $x\n" if $debug;
        if ( $x > 2 ) {
            $err++;
            print STDERR "Expected 0 or 1 or 2 got $x\n";
        }

        # "Reading field type..";

        ( $db_ft15[$idx], $x ) = GetLong();
        print STDERR "   db_ft15 $i is $x\n" if $debug;
        unless ( $x == 8 ) {
            $err++;
            print STDERR "Expected 8 got $x\n";
        }

        # "Reading REPEAT EVENT STRUCTURE\n";

        # "Reading REPEAT EVENT Date exceptions..\n";

        ( $db_date_exception[$idx], $x ) = GetShort();
        print STDERR "   db_date_exception $i is $x\n" if $debug;
        $de = $x;
        if ($de) {
            print STDERR "** Found date exceptions, index is $de\n" if $debug;
            while ($de) {
                ( $deitem, $x ) = GetLong();
                $db_date_except_table[$idx] .= $deitem;
                @Date = localtime( &readLong($deitem) );
                $Date[5] += 1900;
                $de--;
            }
        }

        # "Reading REPEAT EVENT flag..\n";

        ( $db_repeat_event[$idx], $re ) = GetShort();
        print STDERR "   db_repeat_event $i is $re\n" if $debug;

        if ($re) {
            if ( $re == -1 ) {
                ( $db_re_c1[$idx], $x ) = GetShort();
                print STDERR "	db_re_c1 $i is $x\n" if $debug;
                unless ( $x == 1 ) {
                    print STDERR "Expected 1 found $x\n";
                }

                ( $db_re_cll[$idx], $x ) = GetShort();
                print STDERR "	db_re_cll $i is $x\n" if $debug;

                read( CF, $db_re_class[$idx], $x )
                  or die "unable to get db_re_class $i: $!\n";
                print STDERR "	db_re_class $i is $db_re_class[$idx]\n"
                  if $debug;
            }

            SWITCH: {

                if ( $re == 0 ) {
                    last SWITCH;
                }

                # "	Getting RE Brand..";

                ( $db_re_brand[$idx], $x ) = GetLong();
                print STDERR "	db_re_brand $i is $x\n" if $debug;
                unless ( $x < 7 and $x > 0 ) {
                    $err++;
                    print STDERR "Expected 1 - 6 only, got $x\n";
                }

                $re = $x;

                # "	Getting RE interval..";

                ( $db_re_interval[$idx], $x ) = GetLong();
                print STDERR "	db_re_interval $i is $x\n" if $debug;

                # "	Getting RE end date..";

                ( $db_re_enddate[$idx], $x ) = GetLong();
                print STDERR "	db_re_enddate $i is $x\n" if $debug;
                @Date = localtime( &readLong( $db_re_enddate[$idx] ) );
                $Date[5] += 1900;

                # "	Getting RE first dow..";

                ( $db_re_firstdow[$idx], $x ) = GetLong();
                print STDERR "	db_re_firstdow $i is $x\n" if $debug;
                unless ( $x < 7 and $x >= 0 ) {
                    $err++;
                    print STDERR "Expected 0 - 6 only, got $x\n";
                }

                if ( $re == 1 ) {

                    # "	  Getting RE day index..";

                    ( $db_re_dayindex[$idx], $x ) = GetLong();
                    print STDERR "	  db_re_dayindex $i is $x\n" if $debug;
                    last SWITCH;
                }

                if ( $re == 2 ) {

                    # "	  Getting RE day index..";

                    ( $db_re_dayindex[$idx], $x ) = GetLong();
                    print STDERR "	  db_re_dayindex $i is $x\n" if $debug;

                    # "	  Getting RE days mask..";
                    read( CF, $db_re_daysmask[$idx], 1 )
                      or die "unable to get db_re_daysmask $i: $!\n";
                    $x = unpack "C", $db_re_daysmask[$idx];
                    print STDERR "	  db_re_daysmask $i is $x\n" if $debug;
                    last SWITCH;
                }

                if ( $re == 3 ) {

                    # "	  Getting RE day index..";

                    ( $db_re_dayindex[$idx], $x ) = GetLong();
                    print STDERR "	  db_re_dayindex $i is $x\n" if $debug;

                    # "	  Getting RE week index..";
                    ( $db_re_weekidx[$idx], $x ) = GetLong();
                    print STDERR "	  db_re_weekidx $i is $x\n" if $debug;

                    last SWITCH;
                }

                if ( $re == 4 ) {

                    # "	  Getting RE day number..";

                    ( $db_re_daynum[$idx], $x ) = GetLong();
                    print STDERR "	  db_re_daynum $i is $x\n" if $debug;

                    last SWITCH;
                }

                if ( $re == 5 ) {

                    # "	  Getting RE day number..";

                    ( $db_re_daynum[$idx], $x ) = GetLong();
                    print STDERR "	  db_re_daynum $i is $x\n" if $debug;

                    # "	  Getting RE month index..";
                    ( $db_re_monthidx[$idx], $x ) = GetLong();
                    print STDERR "	  db_re_monthidx $i is $x\n" if $debug;

                    last SWITCH;
                }

                if ( $re == 6 ) {
                    last SWITCH;
                }
            }

            # SWITCH
        }

        # end if RE

        $db_record_ok[$idx]  = $err;
        $db_record_who[$idx] = $dbuser;
        $i++;

        $idx++;

    }

    #end while

    close(CF);
}

sub readLong {
    return unpack "l", shift;
}

sub readShort {
    return unpack "s", shift;
}

sub readByte {
    return unpack "C", shift;
}

sub writeOutCalendar {

    #ID	DATE	TIME	EVENT	CATEGORY	DETAILS
    #1	2001.10.2	10:20	Test Event	Test	This is a test event to make sure data entry is working.

    my @StartDate;
    my @NowDate;
    my $startDate;
    my $nowepoch;
    my $sinceepoch;
    my $alarm_set;

    #my $description;
    #my $note;

    my $re;
    my $reType;
    my $reInterval;
    my $reEnddate;
    my $reDOW;
    my $reDayIndex;
    my $reDayMask;
    my $reDayNum;
    my $reWeekIndex;

    if ( open( CTAB, ">$ctabPath" ) ) {

        print CTAB "ID\tDATE\tTIME\tEVENT\tCATEGORY\tDETAILS\tALARM\tWHO\n";

        my $i = 0;
        my $j = 0;
        @NowDate = localtime();
        $NowDate[5] += 1900;
        $nowepoch = timelocal(
            $NowDate[0], $NowDate[1], $NowDate[2],
            $NowDate[3], $NowDate[4], $NowDate[5]
        );

        for ( $i = 0; $i < $idx; $i++ ) {

            next if ( $db_record_ok[$i] != 0 );

            $sinceepoch = &readLong( $db_start_time[$i] );

            next unless ($sinceepoch);

            @StartDate = localtime($sinceepoch);
            $StartDate[5] += 1900;

            my $startTime =
              sprintf( "%02d:%02d", $StartDate[2], $StartDate[1] );

            if ( !$StartDate[2] && !$StartDate[1] ) {
                unless ( readLong( $db_duration[$i] ) ) {
                    $startTime = "";
                }
            }

            $db_description[$i] =~ s/\015?\012/<CR><LF>/gm;
            $db_note[$i] =~ s/\015?\012/<CR><LF>/gm;
            $alarm_set = &readLong( $db_alarm_set[$i] );
            if ($alarm_set) {
                my ($advtime) = &readLong( $db_alarm_adv_time[$i] );
                my ($advtype) = &readLong( $db_alarm_adv_type[$i] );
                if ( $advtype == 0 ) {
                    $alarm_set = sprintf( "0:%02d", $advtime );
                }
                elsif ( $advtype == 1 ) {
                    $alarm_set = sprintf( "%d:00", $advtime );
                }
                elsif ( $advtype == 2 ) {
                    $alarm_set = sprintf( "%d:00", $advtime * 24 );
                }
                else {
                    $alarm_set = "";
                }
            }

            if ( ( $re = &readShort( $db_repeat_event[$i] ) ) ) {

                next if $re == -1;
                $re &= ( 0x8000 - 1 );

                $reType     = &readLong( $db_re_brand[$i] );
                $reInterval = &readLong( $db_re_interval[$i] );
                $reEnddate  = &readLong( $db_re_enddate[$i] );
                $reDOW      = &readLong( $db_re_firstdow[$i] );

                next unless $reType < 7 and $reType > 0;
                next unless $reDOW < 7  and $reDOW > 0;
                next if ( $nowepoch > $reEnddate );

                if ( $reType == 1 ) {    # Daily
                    $reDayIndex = &readLong( $db_re_dayindex[$i] );
                }
                elsif ( $reType == 2 ) {    # Weekly
                    $reDayIndex = &readLong( $db_re_dayindex[$i] );
                    $reDayMask  = &readByte( $db_re_daysmask[$i] );
                }
                elsif ( $reType == 3 ) {    # Monthly By Day
                    $reDayIndex  = &readLong( $db_re_dayindex[$i] );
                    $reWeekIndex = &readLong( $db_re_weekidx[$i] );
                }
                elsif ( $reType == 4 ) {    # Monthly By Date
                    $reDayNum = &readLong( $db_re_daynum[$i] );
                }
                elsif ( $reType == 5 ) {    # Yearly By Date
                    $reDayNum     = &readLong( $db_re_daynum[$i] );
                    $reMonthIndex = &readLong( $db_re_monthidx[$i] );
                }
                elsif ( $reType == 6 ) {    # Yearly By Day
                }

                $reEnddate = $nowepoch + ( 60 * 60 * 24 * 365 )
                  unless $reEnddate;
                $reEnddate = $nowepoch + ( 60 * 60 * 24 * 365 )
                  if $reEnddate > ( $nowepoch + ( 60 * 60 * 24 * 365 ) );

                while ( $sinceepoch < $reEnddate ) {

                    @StartDate = localtime($sinceepoch);
                    $StartDate[5] += 1900;

                    if ( $sinceepoch >= $nowepoch ) {
                        $startDate = sprintf( "%d.%d.%d",
                            $StartDate[5], $StartDate[4] + 1,
                            $StartDate[3] );
                        print CTAB
                          "$j\t$startDate\t$startTime\t$db_description[$i]\t\t$db_note[$i]\t$alarm_set\t$db_record_who[$i]\n";
                        $j++;
                    }

                    if ( $reType == 1 ) {    # Daily
                        $sinceepoch += ( 60 * 60 * 24 ) * $reInterval;
                    }
                    elsif ( $reType == 2 ) {    # Weekly
                        $sinceepoch += ( 60 * 60 * 24 * 7 ) * $reInterval;
                    }
                    elsif ( $reType == 3 ) {    # Monthly By Date
                        $StartDate[4] += ( 1 * $reInterval );
                        if ( $StartDate[4] > 11 ) {
                            $StartDate[4] -= 12;
                            $StartDate[5]++;
                        }
                        $sinceepoch = timelocal(
                            $StartDate[0], $StartDate[1], $StartDate[2],
                            $StartDate[3], $StartDate[4], $StartDate[5]
                        );
                    }
                    elsif ( $reType == 4 ) {    # Monthly By Day
                        $StartDate[4] += ( 1 * $reInterval );
                        if ( $StartDate[4] > 11 ) {
                            $StartDate[4] -= 12;
                            $StartDate[5]++;
                        }
                        $sinceepoch = timelocal(
                            $StartDate[0], $StartDate[1], $StartDate[2],
                            $StartDate[3], $StartDate[4], $StartDate[5]
                        );
                    }
                    elsif ( $reType == 5 ) {    # Yearly By Date
                        $StartDate[5]++;
                        $sinceepoch = timelocal(
                            $StartDate[0], $StartDate[1], $StartDate[2],
                            $StartDate[3], $StartDate[4], $StartDate[5]
                        );
                    }
                    elsif ( $reType == 6 ) {    # Yearly By Day
                    }
                }
            }
            else {
                next if ( $NowDate[5] > $StartDate[5] );

                $startDate = sprintf( "%d.%d.%d",
                    $StartDate[5], $StartDate[4] + 1,
                    $StartDate[3] );
                print CTAB
                  "$j\t$startDate\t$startTime\t$db_description[$i]\t\t$db_note[$i]\t$alarm_set\t$db_record_who[$i]\n";
                $j++;
            }
        }
        close(CTAB);
    }
    else {
        print STDERR "Unable to open $ctabPath: $!\n";
    }
}
