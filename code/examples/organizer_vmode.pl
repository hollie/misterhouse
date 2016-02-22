# Category = Time

#@ Additional code to set mode_occupied to vacation if a vacation day is set in the calendar
#@ This module monitors the file that stores calendar and todo events
#@ for the web based organizer used in mh/web/organizer.  If changed, it
#@ will create events to speak an announcement when each event occurs.
#@ Requires updated calendar schema and calendar.pl v1.5.7-3

use lib "$Pgm_Root/web/organizer";
use vsDB;

my $organizer_file = "$Code_Dirs[0]/organizer_events.pl";
my $organizer_vsdb = "$config_parms{organizer_dir}/calendar.tab";

$org_vacation_check = new Voice_Cmd 'Check for new vacation events';
$org_vacation_check->set_info(
    'Creates MisterHouse events based on organizer calendar VACATION categories'
);

if ( said $org_vacation_check
    or ( $New_Minute and file_changed $organizer_file) )
{
    print_log 'Reading updated organizer calendar file for vacation events';
    my ($objDB) = new vsDB( file => $organizer_vsdb, delimiter => '\t' );
    print $objDB->LastError unless $objDB->Open;
    my $mycode = "$Code_Dirs[0]/organizer_vacation.pl";
    open( MYCODE, ">$mycode" ) or print_log "Error in open on $mycode: $!\n";
    print MYCODE "\n# Category = Time\n";
    print MYCODE "\n#@ Auto-generated from Organizer_vmode.pl\n\n";
    print MYCODE
      " if ((\$New_Minute and (time_now(\"\$New_Day + 0:01\"))) or (\$Reload)) {\n";

    while ( !$objDB->EOF ) {
        my $date     = $objDB->FieldValue('DATE');
        my $time     = $objDB->FieldValue('TIME');
        my $category = $objDB->FieldValue('CATEGORY');
        my $event    = $objDB->FieldValue('EVENT');
        my $vacation = $objDB->FieldValue('VACATION');
        $objDB->MoveNext;
        my @date = split '\.', $date;
        next unless @date;
        $date =
          ( $config_parms{date_format} =~ /ddmm/ )
          ? "$date[2]/$date[1]"
          : "$date[1]/$date[2]";
        $time = "00:00" if ( not $time );
        my $time_date = "$date/$date[0] $time";
        my $calc_time = &time_date_stamp( 14, &my_str2time($time_date) );
        next if time_greater_than($calc_time);    # Skip past events $time_date

        my $vacation_time =
          &time_date_stamp( 14, ( &my_str2time($calc_time) + 60 ) );
        my ($vacation_start) =
          $vacation_time =~ /^(\S\S\S\s\d\d\/\d\d\/\d\d) \d\d:\d\d:\d\d/;
        my $vacation_end = $vacation_start . " 23:59:59";
        $vacation_start .= " 00:00:00";

        if ( $vacation eq "on" ) {

            #print "db:vmode ct=[$calc_time] vt=[$vacation_time] vd=[$vacation_start]\n";
            print MYCODE
              "   if (time_between \"$vacation_start\", \"$vacation_end\") {\n";
            print MYCODE
              "     print_log \"Today is a vacation, setting vacation mode\";\n";
            print MYCODE "     set \$mode_occupied 'vacation';\n";
            print MYCODE "   }; \# Vacation is $event\n\n";
        }
    }
    print MYCODE "}\n";
    close MYCODE;
    $objDB->Close;
    display $mycode, 10, 'Vacation Calendar events', 'fixed';
    do_user_file $mycode;
}

