# Category = Time

#@ This module monitors the file that stores calendar and todo events 
#@ for the web based organizer used in mh/web/organizer.  If changed, it
#@ will create events to speak an announcement when each event occurs.

#@ Requires calendar 1.5.7-3 and todo 1.4.8-2 (MisterHouse > 2.103)

use lib "$Pgm_Root/web/organizer";
use vsDB;

my $speak_tasks = 1;
$organizer_cal  = new File_Item "$config_parms{organizer_dir}/calendar.tab";
$organizer_todo = new File_Item "$config_parms{organizer_dir}/tasks.tab";
set_watch $organizer_cal  if $Reload;
set_watch $organizer_todo if $Reload;

$organizer_check = new Voice_Cmd 'Check for new calendar events';
$organizer_check ->set_info('Creates MisterHouse events based on organizer calendar events');

if ($Reload) {

   #Check to see if calendar and organizer databases need upgrade
   my $upd_ver = "v2103";
  
   my $cal_chk  = $organizer_cal->name . "." . $upd_ver;
   my $cal_skip = $organizer_cal->name . ".skip"; 
   my $tsk_chk = $organizer_todo->name . "." . $upd_ver;
   my $tsk_skip = $organizer_todo->name . ".skip";

   if (-e $cal_skip) {

	print_log "Organizer.pl: Skipping Calendar upgrade.";

   } elsif (! -e $cal_chk ) {

	print_log "Organizer.pl: Upgrading Calendar to version $upd_ver...";
	my $filename = $organizer_cal->name;
	my $filename_dest = $filename. ".upgrading";

	#v2103 adds two additional fields, ok_fields is the number of field to expect
	#hopefully avoids updating custom code
	my $upd_fields = "holiday,vacation";
	my $ok_fields = 6;

	my $results = &update_file($filename,$filename_dest,$upd_fields,$ok_fields);

	if ($results) {
		rename($filename, $cal_chk);
		rename($filename_dest, $filename);
		print_log "Organizer.pl: Calendar Upgrade complete.";
	} else {
		print_log "Organizer.pl: ERROR: Automatic Calendar Upgrade failed";
		rename($filename_dest, $cal_skip);
	}

   }

   if (-e $tsk_skip) {

	print_log "Organizer.pl: Skipping Todo list upgrade.";

   } elsif (! -e $tsk_chk ) {

	print_log "Organizer.pl: Upgrading Todo list to version $upd_ver...";
	my $filename = $organizer_todo->name;
	my $filename_dest = $filename. ".upgrading";

	#v2103 adds one additional field, ok_fields is the number of field to expect
	#hopefully avoids updating custom code
	my $upd_fields = "speak";
	my $ok_fields = 6;

	my $results = &update_file($filename,$filename_dest,$upd_fields,$ok_fields);

	if ($results) {
		rename($filename, $cal_chk);
		rename($filename_dest, $filename);
		print_log "Organizer.pl: Todo list Upgrade complete.";
	} else {
		print_log "Organizer.pl: ERROR: Todo list Automatic Upgrade failed";
		rename($filename_dest, $tsk_skip);
	}

   }

}

if (said $organizer_check or ($New_Minute and changed $organizer_cal)) {
    print_log 'Organizer.pl: Reading updated organizer calendar file';
    set_watch $organizer_cal;  # Reset so changed function works
    my ($objDB) = new vsDB(file => $organizer_cal->name, delimiter => '\t');
    print $objDB->LastError unless $objDB->Open;
    my $mycode = "$Code_Dirs[0]/organizer_events.pl";
    open(MYCODE, ">$mycode") or print_log "Organizer.pl: Error in open on $mycode: $!\n";
    print MYCODE "\n# Category = Time\n";
    print MYCODE "\n#@ Auto-generated from Organizer.pl\n\n";
    print MYCODE "if (\$New_Minute) {\n";
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
        print MYCODE "   if (time_now '$time_date - 00:15') {speak (rooms=> \"all\", text=>\"Calendar notice.  In 15 minutes, $event\")};\n";
        print MYCODE "   if (time_now '$time_date') {speak (rooms=> \"all\", text=>\"Calendar notice at $time: $event\")};\n";
    }
    print MYCODE "}\n";
    close MYCODE;
    $objDB->Close;
    display $mycode, 10, 'Organizer Calendar events', 'fixed';
    do_user_file $mycode;
}

if (said $organizer_check or ($New_Minute and changed $organizer_todo)) {
    print_log 'Organizer.pl: Reading updated organizer todo file';
    set_watch $organizer_todo;  # Reset so changed function works
    my ($objDB) = new vsDB(file => $organizer_todo->name, delimiter => '\t');
    print $objDB->LastError unless $objDB->Open;
    my $mycode = "$Code_Dirs[0]/organizer_tasks.pl";
    open(MYCODE, ">$mycode") or print_log "Error in open on $mycode: $!\n";
    print MYCODE "\n# Category = Time\n";
    print MYCODE "\n#@ Auto-generated from Organizer.pl\n\n";
    print MYCODE "if (\$New_Minute) {\n";
    my %emails;
    &read_parm_hash(\%emails,  $main::config_parms{organizer_email});
    while (!$objDB->EOF) {
        my $complete = $objDB->FieldValue('Complete');
        my $date     = $objDB->FieldValue('DueDate');
        my $name     = $objDB->FieldValue('AssignedTo');
        my $subject  = $objDB->FieldValue('Description');
        my $notes    = $objDB->FieldValue('Notes');
        my $speak    = $objDB->FieldValue('Speak');
        my $text     = "$name, $subject. $notes";
        $notes .= ".  Sent: $Date_Now $Time_Now";
        $objDB->MoveNext;
	next unless $name or $subject;
        next if lc $complete eq 'yes';
        next unless time_less_than("$date + 23:59");  # Skip past and invalid events
        
        my $email = "net_mail_send to => '$emails{lc $name}', subject => q~$subject~, text => q~$notes~; " 
          if $emails{lc $name};

                                # Time already specified - speak (rooms=> "all", text=>"...")};
	if (($speak_tasks) and ($speak eq "on")) {
         if ($date =~ /\S+ +\S/) {
            print MYCODE "   if (time_now '$date') {speak (rooms=> \"all\", text=>\"Task notice.  $text\"); $email}; #speak=$speak\n";
         }
         else {
            print MYCODE "   if (time_now '$date  8 am') {speak (rooms=> \"all\", text=>\"Task notice.  $text\"); $email}; #speak=$speak\n";
            print MYCODE "   if (time_now '$date 12 pm') {speak (rooms=> \"all\", text=>\"Task notice.  $text\"); $email};\n";
            print MYCODE "   if (time_now '$date  7 pm') {speak (rooms=> \"all\", text=>\"Task notice.  $text\"); $email};\n";
         }
	}
    }
    print MYCODE "\n#@ Speak tasks administratively disabled\n\n" if (!$speak_tasks);
    print MYCODE "}\n";
    close MYCODE;
    $objDB->Close;
    display $mycode, 10, 'Organizer Tasks events', 'fixed';
    do_user_file $mycode;
}

sub update_file {

   my ($fn_src,$fn_dest,$fields,$std) = @_;
   my $date;
   my $time;
   my $found = 0;
   my $DB = 0;

   my $cats = "\t" . uc (join ("\t",split (/,/,$fields))) . "\n";
print "cats=$cats\n" if ($DB);

   open (ORIG, "$fn_src") || die "Organizer.pl: ERROR can't open source file";
   open (DEST, ">$fn_dest") || die "Organizer.pl: ERROR can't open dest file";


   foreach my $line (<ORIG>) {

# vsdb "schema" is the first line of the file
	  if (!$found) {
	     chomp $line;
	     my @test = split (/\t/,$line);
	     my $array_items = $#test + 1;
	     if ($array_items != $std) {
		   close (ORIG);
   		   close (DEST);
		   print_log "Organizer.pl: ERROR: Found customized vsdb file. Please upgrade manually";
		   return 0;
	     }
	     print DEST $line . $cats;
	     $found = 1;
	  } else {

	    print DEST $line;
          }
   }
   close (ORIG);
   close (DEST);

return $found;
}
