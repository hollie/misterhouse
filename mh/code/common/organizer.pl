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

$organizer_check = new Voice_Cmd 'Check for new calendar events';
$organizer_check ->set_info('Creates MisterHouse events based on organizer calendar events');

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
    print MYCODE "\n#@ Auto-generated from code/common/organizer.pl\n\n";
    my %emails;
    &read_parm_hash(\%emails,  $main::config_parms{organizer_email});
    while (!$objDB->EOF) {
        my $complete = $objDB->FieldValue('Complete');
        my $date     = $objDB->FieldValue('DueDate');
        my $name     = $objDB->FieldValue('AssignedTo');
        my $subject  = $objDB->FieldValue('Description');
        my $notes    = $objDB->FieldValue('Notes');
        my $text     = "$name, $subject. $notes";
        $notes .= ".  Sent: $Date_Now $Time_Now";
        $objDB->MoveNext;
	next unless $name or $subject;
        next if lc $complete eq 'yes';
        next unless time_less_than("$date + 23:59");  # Skip past and invalid events
        
        my $email = "net_mail_send to => '$emails{lc $name}', subject => q~$subject~, text => q~$notes~; " 
          if $emails{lc $name};

                                # Time already specified
        if ($date =~ /\S+ +\S/) {
            print MYCODE "if (time_now '$date') {speak q~Task notice.  $text~; $email};\n";
        }
        else {
            print MYCODE "if (time_now '$date  8 am') {speak q~Task notice.  $text~; $email};\n";
            print MYCODE "if (time_now '$date 12 pm') {speak q~Task notice.  $text~; $email};\n";
            print MYCODE "if (time_now '$date  7 pm') {speak q~Task notice.  $text~; $email};\n";
        }
    }
    close MYCODE;
    $objDB->Close;
    display $mycode, 10, 'Organizer Tasks events', 'fixed';
    do_user_file $mycode;
}

