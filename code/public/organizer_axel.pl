# Category=Calendar

# This is a modified version of the script in your mh/code/bruce folder.
# It allows for variable ALARM times (not just 15 mins) and "no
# specified time" events. It also announces the owner of the event.
# Currently hard coded for Axel's family names

# This code will monitor the file that stores calendar events for the
# web based organizer used in mh/web/organizer.  If changed, it will
# create events to speak an announcement when each event occurs.

use lib "$Pgm_Root/web/organizer";
use vsDB;

$organizer_file = new File_Item "$config_parms{organizer_dir}/calendar.tab";
set_watch $organizer_file if $Reload;

$organizer_check = new Voice_Cmd 'Check for new calendar events';
$organizer_check->set_info(
    'Creates MisterHouse events based on organizer calendar events');

if ( said $organizer_check or ( $New_Minute and changed $organizer_file) ) {
    print_log 'Reading calendar file';
    speak 'Reading calendar file';

    set_watch $organizer_file;    # Reset so changed function works
    &updateOrganizer;

    print_log 'Organizer data created';
    speak 'Organizer data created';
}

sub updateOrganizer {
    my ($objDB) = new vsDB( file => $organizer_file->name, delimiter => '\t' );
    print $objDB->LastError unless $objDB->Open;
    my $mycode = "$config_parms{code_dir}/organizer_events.pl";
    open( MYCODE, ">$mycode" ) or print_log "Error in open on $mycode: $!\n";
    while ( !$objDB->EOF ) {
        my $date  = $objDB->FieldValue('DATE');
        my $time  = $objDB->FieldValue('TIME');
        my $event = $objDB->FieldValue('EVENT');
        my $alarm = $objDB->FieldValue('ALARM');
        my $who   = $objDB->FieldValue('WHO');
        $objDB->MoveNext;
        my @date = split '\.', $date;
        next unless @date;
        next unless ( $alarm or !$time );
        $date =
          ( $config_parms{date_format} =~ /ddmm/ )
          ? "$date[2]/$date[1]"
          : "$date[1]/$date[2]";

        #	$time ||= "00:00";
        my $time_date = "$date/$date[0]";
        next if time_greater_than( $time_date . " 00:00" );   # Skip past events
        $who = "for $who" if $who;
        $event = &make_event_speakable($event);
        $event =~ s/'/\\'/g;
        my $speakalarm;
        $speakalarm = &make_alarm_speakable($alarm) if $alarm;
        if ($time) {
            $time_date .= " $time";
            $time = "at " . time_to_ampm($time);
            print MYCODE
              "if (time_now '$time_date - $alarm') {speak 'rooms=all Calendar notice $who.  In $speakalarm, $event'}\n"
              if $alarm;
            print MYCODE
              "if (time_now '$time_date') {speak 'rooms=all Calendar notice $who $time: $event'}\n";
        }
        else {
            print MYCODE
              qq!if ((time_now "$time_date \$Save{wakeup_time} - $alarm") and \$Save{alarm_sounding}) {speak 'rooms=all In $speakalarm, $event'}\n!
              if $alarm;
            print MYCODE
              qq!if ((time_now "$time_date \$Save{wakeup_time} + 0:02") and \$Save{alarm_sounding}) {speak 'rooms=all Today $event'}\n!;
        }
    }
    close MYCODE;
    $objDB->Close;
    do_user_file $mycode;
}

my @calendarEvents;
my $calendarEvents_timer = new Timer;

sub getCalendarEvents {
    my ( $state, $thisDate, $dayName ) = @_;

    if ( scalar @calendarEvents == 0 ) {

        my ($objDB) =
          new vsDB( file => $organizer_file->name, delimiter => '\t' );
        if ( $objDB->Open ) {

            $objDB->RemoveFilter;
            $objDB->Sort("TIME");
            $objDB->Filter( "WHO", "eq", $state ) if ( $state ne "we" );
            $objDB->Filter( "DATE", "eq", $thisDate );
            if ( $objDB->EOF ) {
                my $forwho = ( $state eq "we" ? "" : " for $state" );
                speak "Not a damn thing happening $dayName${forwho}! Party on!";
            }
            else {
                while ( !$objDB->EOF ) {
                    my $date  = $objDB->FieldValue('DATE');
                    my $time  = $objDB->FieldValue('TIME');
                    my $event = $objDB->FieldValue('EVENT');
                    my $alarm = $objDB->FieldValue('ALARM');
                    my $who   = $objDB->FieldValue('WHO');
                    $objDB->MoveNext;
                    my @date = split '\.', $date;
                    next unless @date;
                    $who = "for $who" if $who;
                    $event = &make_event_speakable($event);
                    $event =~ s/'/\\'/g;
                    my $speakalarm = &make_alarm_speakable($alarm);
                    $time = "at " . time_to_ampm($time) if $time;

                    if ($time) {
                        push( @calendarEvents, "Reminder $who $time, $event" );
                    }
                    else {
                        push( @calendarEvents, "$dayName $event" );
                    }
                }
                set $calendarEvents_timer 1 if ( scalar @calendarEvents );
            }
        }
        else {
            speak "Unable to read from calendar data file. "
              . $objDB->LastError;
        }
    }
}

$v_todaysevents =
  new Voice_Cmd( "What {are,is} [Debbie,Axel,we] doing today", "" );

if ( $state = said $v_todaysevents) {
    my $thisDate = "$Year.$Month.$Mday";
    getCalendarEvents( $state, $thisDate, "Today" );
}

$v_tomorrowsevents =
  new Voice_Cmd( "What {are,is} [Debbie,Axel,we] doing tomorrow", "" );
if ( $state = said $v_tomorrowsevents) {
    my $now = time + ( 60 * 60 * 24 );
    my @ndate = localtime($now);
    $ndate[5] += 1900;
    $ndate[4] += 1;
    my $thisDate = "$ndate[5].$ndate[4].$ndate[3]";
    getCalendarEvents( $state, $thisDate, "Tomorrow" );
}

if ( expired $calendarEvents_timer) {
    my $text = shift @calendarEvents;
    speak( rooms => 'all', text => $text );
    set $calendarEvents_timer 5 if (@calendarEvents);
}

sub make_alarm_speakable {
    my ($alarm) = @_;
    my $text;
    my ( $hours, $mins, $days );

    $days = 0;

    if ( $alarm =~ /^\d+ d/ ) {
        ($days) = $alarm =~ /^(\d+)/;
    }
    if ( $alarm =~ /\d+:\d\d$/ ) {
        ( $hours, $mins ) = $alarm =~ /(\d+):(\d\d)/;
        $hours =~ s/^0//;
        $mins =~ s/^0//;
        if ($hours) {
            while ( $hours >= 24 ) {
                $days++;
                $hours -= 24;
            }
        }
    }
    if ($days) {
        $text .= " " if $text;
        $text .= &plural( $days, "day" );
    }
    if ($hours) {
        $text .= " " if $text;
        $text .= &plural( $hours, "hour" );
    }
    if ($mins) {
        $text .= " " if $text;
        $text .= &plural( $mins, "minute" );
    }
    return $text;
}

sub make_event_speakable {
    my ($text) = @_;

    if ( $text =~ / \((H|A)\)/ ) {
        $text =~ s/\(H\)/at Anfield/;
        $text =~ s/\(A\)/away/;
        $text = "Liverpool play $text";
    }

    $text =~ s/\/ FSWD/on Fox Sports World/;
    $text =~ s/\/ ABC/on A B C/;
    $text =~ s/\/ CBS/on C B S/;
    $text =~ s/\/ NBC/on N B C/;
    $text =~ s/\/ FOX/on Fox/i;
    $text =~ s/\/ ESPN(2?)/on E S P N $1/;
    $text =~ s/\/ BBCA/on BBC America/;
    $text =~ s/\/ PPV/on Pay Per View/;
    $text =~ s/\/ NIK/on Nickelodeon/;

    $text =~ s/Man Utd/the Scum Bags/;

    $text =~ s/\/ ACL/in Austin City Limits/;

    if ( $text =~ /^(.*) - (Anniversary|Birthday) \((\d+) Years\)$/ ) {
        $text = "is $1's $3" . speakify_numbers($3) . " $2";
    }
    elsif ( $text =~ /^(.*) - Death \((\d+) Years\)$/ ) {
        $text = "$1 died $2 years ago";
    }
    elsif ( $text =~ /^(.*) - Event \((\d+) Years\)$/ ) {
        $text = "$1 happened $2 years ago";
    }

    return $text;
}
