# Category = Time

#@ This module monitors the file that stores calendar and todo events 
#@ for the web based organizer used in mh/web/organizer.  If changed, it
#@ will create events to speak an announcement when each event occurs.

use lib "$Pgm_Root/web/organizer";
use vsDB;

$organizer_cal  = new File_Item "$config_parms{organizer_dir}/calendar.tab";
$organizer_todo = new File_Item "$config_parms{organizer_dir}/tasks.tab";
set_watch $organizer_cal  if $Reload;
set_watch $organizer_todo if $Reload;

$organizer_check = new Voice_Cmd 'Check for new calender events';
$organizer_check ->set_info('Creates MisterHouse events based on organizer calender events');

if (said $organizer_check or ($New_Minute and changed $organizer_cal)) {
    print_log 'Reading updated organizer calendar file';
    set_watch $organizer_cal;  # Reset so changed function works
    my ($objDB) = new vsDB(file => $organizer_cal->name, delimiter => '\t');
    print $objDB->LastError unless $objDB->Open;
    my $mycode = "$config_parms{code_dir}/organizer_events.pl";
    open(MYCODE, ">$mycode") or print_log "Error in open on $mycode: $!\n";
    while (!$objDB->EOF) {
        my $date  = $objDB->FieldValue('DATE');
        my $time  = $objDB->FieldValue('TIME');
        my $event = $objDB->FieldValue('EVENT');
        $objDB->MoveNext;
        my @date  = split '\.', $date;
        next unless @date;
        $date = ($config_parms{date_format} =~ /ddmm/) ? "$date[2]/$date[1]" : "$date[1]/$date[2]";
        my $time_date = "$date/$date[0] $time";
        next if time_greater_than($time_date);  # Skip past events
        print MYCODE "if (time_now '$time_date - 00:15') {speak q~Calendar notice.  In 15 minutes, $event~};\n";
        print MYCODE "if (time_now '$time_date') {speak q~Calendar notice at $time: $event~};\n";
    }
    close MYCODE;
    $objDB->Close;
    display $mycode, 10, 'Organizer Calendar events', 'fixed';
    do_user_file $mycode;
}

if (said $organizer_check or ($New_Minute and changed $organizer_todo)) {
    print_log 'Reading updated organizer todo file';
    set_watch $organizer_todo;  # Reset so changed function works
    my ($objDB) = new vsDB(file => $organizer_todo->name, delimiter => '\t');
    print $objDB->LastError unless $objDB->Open;
    my $mycode = "$config_parms{code_dir}/organizer_tasks.pl";
    open(MYCODE, ">$mycode") or print_log "Error in open on $mycode: $!\n";
    while (!$objDB->EOF) {
        my $complete = $objDB->FieldValue('Complete');
        my $date     = $objDB->FieldValue('DueDate');
        my $text     = $objDB->FieldValue('AssignedTo') . ', ' . $objDB->FieldValue('Description') . '. ' . $objDB->FieldValue('Notes');
        $objDB->MoveNext;
        next unless time_less_than("$date 11:59 pm");  # Skip past and invalid events
        print MYCODE "if (time_now '$date  8 am') {speak q~Task notice.  $text~};\n";
        print MYCODE "if (time_now '$date 12 pm') {speak q~Task notice.  $text~};\n";
        print MYCODE "if (time_now '$date  7 pm') {speak q~Task notice.  $text~};\n";
    }
    close MYCODE;
    $objDB->Close;
    display $mycode, 10, 'Organizer Tasks events', 'fixed';
    do_user_file $mycode;
}

