# Category = Time

#@ This module is a significant update from 2.103, and has a few functions;
#@
#@ - iCal2vsDB syncronization control. Imports iCal files (Apple iCal, 
#@   Mozilla Sunbird) into MH as standard calendars, or holiday/vacation
#@   calendars.
#@ - Monitors the vsDB calendar and todo files and creates required events
#@   to process these items (creates organizer_*.pl files in the code dir)
#@ - Implements an Organizer_Events class for manipulating events, holidays
#@   and vacations.
#@ - Automatically updates vsDB 'databases' with the new required fields
#@
#@ Requires calendar.pl 1.5.7-4 and tasks.pl 1.4.8-4 (Misterhouse v2.104)

=begin comment

mh.ini parameters required

organizer_dir (mandatory).  Set to the location where your organizer data will be stored
organizer_email (optional).  Required if email notices are used.  The first entry will be
       considered the default for notices that don't map to assignments (e.g., to-do).
       Example: organizer_email = fred => fred@flintstone.net, wilma => wilma@flintstone.net
       Note requirement that keys be lowercase.
organizer_announce_day_times (optional) overides the default times when announcements occur
       on the day of a to-do or event.  Example: 
       organizer_announce_day_times = 8:00 am, 9:00 am
       Note case and space between number and "am".  
organizer_announce_priorday_times (optional) overides the default times when announcements
       occur prior to the day of a to-do or event.
ical_read_interval (optional). Defaults to 0 which will prevent periodic iCal reading.  
       Set to a value in minutes


Configuration file needs to be manually created, future updates may automate
this process. Currently the configuration file is {organizer_dir}/i2v.cfg

i2v.cfg is a tab delimited file containing ical paths and iCal2vsDB options:

#Required
ical	http://server/path/to/icalfile.ics	[Options]
ical	file://path/to/icalfile.ics	[Options]
ical    http://user@pass:server/file.ics	[Options]
sleep_time	0	#Important otherwise iCal2vsDB will not exit.

#Optional
days_before	10	#Numbers of days back in the past to import
days_after	30	#Numbers of days in the future to import

Options are
speak_cal 	to speak calendar entries
speak_todo 	to speak task entries
holiday		calendar entries should be treated as holiday time
vacation	calendar entries should be treated as vacation time
name=XXXX	set source name to XXX rather than parse it from inside the ical

iCal2vsDB uses iCal::Parser, which has several significant dependancies to operate correctly,
these have been included in lib/site

=cut



package Organizer_Events;

@Organizer_Events::ISA = ('Generic_Item');

sub new {
   my ($class) = @_;
   my $self={};
   bless $self,$class;
   @{$$self{_events}} = ();
   return $self;
}

sub add {
   my ($self, %data) = @_;
   push @{$$self{_events}}, \%data;
}

sub evaluate {
   my ($self) = @_;
   @{$$self{_active_events}} = ();
   foreach my $event (@{$$self{_events}}) {
      if (&main::time_greater_or_equal($$event{startdt}) && &main::time_less_or_equal($$event{enddt})) {
         push @{$$self{_active_events}}, $event;
      }
   }
   # TO-DO: need to distinguish between a new event which is making the state active again
   #        vs. the same (set of) event(s) causing the state to be active
   if (@{$$self{_active_events}}) {
      if ($self->state ne 'active') {
         $self->set('active');
         print "setting $$self{object_name} active\n";
      }
   } else {
      if ($self->state ne 'inactive') {
         $self->set('inactive');
         print "setting $$self{object_name} " . $self->state . "\n";
      }
   }
}

sub active_events {
   my ($self) = @_;
   return @{$$self{_active_events}};
}

sub is_active_today {
   my ($self) = @_;
   return $self->is_active_on_day(0);
}

sub is_active_tomorrow {
   my ($self) = @_;
   return $self->is_active_on_day(1);
}

sub is_active_on_day {
   my ($self, $day) = @_;
   my ($now_date) = $main::Time_Date =~ /(\S+)\s+\S+/;
   my $comparetime = &main::my_str2time("$now_date 12:00 am + " . ($day*24) . ":00");
   foreach my $event (@{$$self{_events}}) {
      my $eventtime = &main::my_str2time($$event{startdt});
      my $timediff = $eventtime - $comparetime;
      if ($timediff >= 0 and $timediff < (60*60*24)) {
         return 1;
      }
   }
   return 0;
}

package main;

use File::Copy;
use vsDB;

# PUBLIC objects:

$organizer_holidays = new Organizer_Events('holiday');
$organizer_vacation = new Organizer_Events('vacation');
$organizer_events = new Organizer_Events('events');

$organizer_check = new Voice_Cmd 'Check for new calendar events';
$organizer_check ->set_info('Creates MisterHouse events based on organizer calendar events');

$p_ical2vsdb = new Process_Item();

$v_get_ical_data = new Voice_Cmd('[Retrieve,Force] iCal data');
$v_get_ical_data->set_info('Retrieve iCal calendar data from multiple sources');
$v_get_ical_data->set_authority('anyone');


my $speak_tasks = 1;


# PRIVATE data

$_organizer_cal  = new File_Item "$config_parms{organizer_dir}/calendar.tab";
$_organizer_todo = new File_Item "$config_parms{organizer_dir}/tasks.tab";
my %_upd_cal;
my %_upd_todo;
my %_organizer_emails;
my @_organizer_announce_day_times = ('8 am','12 pm','7 pm');
my @_organizer_announce_priorday_times = ('7 pm');

my $_ical2db_output_dir = "$config_parms{organizer_dir}";
my $_ical2db_config_path = "$_ical2db_output_dir/i2v.cfg";


if ($Reload) {
   set_watch $_organizer_cal;
   set_watch $_organizer_todo;

   $p_ical2vsdb->set("ical2vsdb $_ical2db_config_path $_ical2db_output_dir $main::config_parms{date_format}");

   &read_parm_hash(\%_organizer_emails,  $main::config_parms{organizer_email});

   # setup default announce times
   @_organizer_announce_day_times = split(/\s*,\s*/,$main::config_parms{organizer_announce_day_times}) 
       if $main::config_parms{organizer_announce_day_times};
   @_organizer_announce_priorday_times = split(/\s*,\s*/,$main::config_parms{organizer_announce_priorday_times}) 
       if $main::config_parms{organizer_announce_priorday_times};

   #Check to see if calendar and organizer databases need upgrade

   $_upd_cal{v2103} = "HOLIDAY,VACATION";
   $_upd_cal{v2104} = "SOURCE,REMINDER,ENDTIME";

   $_upd_todo{v2103} = "SPEAK";
   $_upd_todo{v2104} = "SOURCE,REMINDER,STARTDATE,CATEGORY";

   &update_vsdb(\%_upd_cal,$_organizer_cal->name,"Calendar");
   &update_vsdb(\%_upd_todo,$_organizer_todo->name,"Todo"); 

}

if (new_minute(1)) {
   $organizer_events->evaluate();
   $organizer_holidays->evaluate();
   $organizer_vacation->evaluate();
}

# default to 0 so that ical reading is not automatic unless enabled explicitely.
my $ical_read_interval = ($main::config_parms{ical_read_interval}) ? $main::config_parms{ical_read_interval} : 0;
if (said $v_get_ical_data or (($ical_read_interval) && new_minute($ical_read_interval))) {

   if (said $v_get_ical_data eq "Force") {
	print_log "Organizer.pl: Forcing calendar update";
        if (unlink("$config_parms{organizer_dir}/ical2vsdb.md5")) {
        #   $v_get_ical_data->respond("iCal force successful. Data retrieval will occur on next scheduled.");
        } else {
           $v_get_ical_data->respond("iCal force unsuccessful.  Please check permissions on $config_parms{organizer_dir}/ical2vsdb.md5");
        }
   }

   if ( -e $_ical2db_config_path) {
   	start $p_ical2vsdb;
   } else {
	print_log "Organizer.pl: Cannot find configuration file!"
   }
}

if ($Reload or said $organizer_check or ($New_Minute and changed $_organizer_cal)) {
    print_log 'Organizer.pl: Reading updated organizer calendar file now';
    set_watch $_organizer_cal;  # Reset so changed function works
    my ($objDB) = new vsDB(file => $_organizer_cal->name, delimiter => '\t');
    # set objDB to sort on DATE
    $objDB->Sort('DATE');
    print $objDB->LastError unless $objDB->Open;
    my $mycode = "$Code_Dirs[0]/organizer_events.pl";
    open(MYCODE, ">$mycode") or print_log "Organizer.pl: Error in open on $mycode: $!\n";
    print MYCODE "\n# Category = Time\n";
    print MYCODE "\n#@ Auto-generated from Organizer.pl\n\n";
    print MYCODE "if (\$New_Minute) {\n";
    while (!$objDB->EOF) {
        my (%data);
        $data{type}  = 'event';
        my @date  = split '\.', $objDB->FieldValue('DATE');
        $data{date} = ($config_parms{date_format} =~ /ddmm/) ? "$date[2]/$date[1]/$date[0]" 
             : "$date[1]/$date[2]/$date[0]";
        $data{time}  = $objDB->FieldValue('TIME');
        if ($data{time}) {
           # TO-DO: force time entry to be legitimate (i.e., no "24hr time"--only am/pm time)
        } else {
           $data{time} = "12:00 am";
        }
        $data{description} = $objDB->FieldValue('EVENT');
        $data{reminder} = $objDB->FieldValue('REMINDER');
        $data{category} = $objDB->FieldValue('CATEGORY');
        $data{endtime} = $objDB->FieldValue('ENDTIME');
        $data{endtime} = (!($data{endtime}) && $data{time}) ? $data{time} : $data{endtime};
        $data{allday} = ($data{time} eq $data{endtime}) ? 'Yes' : 'No';
        $data{notes} = $objDB->FieldValue('DETAILS');
        $data{startdt} = $data{date} . ' ' . (($data{time}) ? $data{time} : "12:00 am");
        $data{enddt} = $data{date} . ' ' 
            . (($data{endtime} && $data{endtime} !~ /12:00 am/i) ? $data{time} : "11:59 pm");
        foreach my $emailname (keys %_organizer_emails) {
           $data{name} = $emailname;
           last;
        }
        $objDB->MoveNext;

        if ($objDB->FieldValue('VACATION') =~ /on/i or $data{category} =~ /vacation/i) {
           $organizer_vacation->add(%data);
        } elsif ($objDB->FieldValue('HOLIDAY') =~ /on/i or $data{category} =~ /holiday/i) {
           $organizer_holidays->add(%data);
        } else {
           $organizer_events->add(%data);
        }

        my $fh = *MYCODE;
        &generate_code($fh, %data);
   }
    print MYCODE "}\n";
    close MYCODE;
    $objDB->Close;

    $organizer_vacation->evaluate();
    $organizer_holidays->evaluate();
    $organizer_events->evaluate();

    do_user_file $mycode;
}

if (said $organizer_check or ($New_Minute and changed $_organizer_todo)) {
    print_log 'Organizer.pl: Reading updated organizer todo file';
    set_watch $_organizer_todo;  # Reset so changed function works
    my ($objDB) = new vsDB(file => $_organizer_todo->name, delimiter => '\t');
    print $objDB->LastError unless $objDB->Open;
    my $mycode = "$Code_Dirs[0]/organizer_tasks.pl";
    open(MYCODE, ">$mycode") or print_log "Error in open on $mycode: $!\n";
    print MYCODE "\n# Category = Time\n";
    print MYCODE "\n#@ Auto-generated from Organizer.pl\n\n";
    print MYCODE "if (\$New_Minute) {\n";
    while (!$objDB->EOF) {
        my (%data);
        my $complete     = $objDB->FieldValue('Complete');
        my $duedate = $objDB->FieldValue('DueDate');
        my ($date,$time) = $duedate =~ /^(\S+)\s+(\S+\s+\S+)/;
        $date = $duedate unless $date;
        $data{type}         = 'task';
        $data{date}         = $date;
        $data{time}         = $time;
        $data{allday}       = 'Yes' if $data{time} and $data{time} =~ /12:00 am/i;
        $data{reminder}     = $objDB->FieldValue('REMINDER');
        $data{name}         = $objDB->FieldValue('AssignedTo');
        $data{description}  = $objDB->FieldValue('Description');
        $data{notes}        = $objDB->FieldValue('Notes');
        $data{speak}        = $objDB->FieldValue('SPEAK');
        $data{startdt}      = $objDB->FieldValue('STARTDATE');
        $data{category}     = $objDB->FieldValue('CATEGORY');
        $data{enddt}        = $data{date} . ' ' . $data{time};
        $objDB->MoveNext;
        next if lc $complete =~ /^y/i;
        next unless $data{name} or $data{description};
        next unless $data{date};
        my $evaldt = ($data{time}) ? $data{date} . ' ' . $data{time} : $data{date} . ' 12:00 am';
        next unless time_less_than("$evaldt + 23:59");  # Skip past and invalid events
        my $fh = *MYCODE;
        &generate_code($fh, %data);
    }
    print MYCODE "\n#@ Speak tasks administratively disabled\n\n" if (!$speak_tasks);
    print MYCODE "}\n";
    close MYCODE;
    $objDB->Close;
    do_user_file $mycode;
}

sub get_speak_code {
   my (%data) = @_;
   my $speak_code = '';
   if ($data{type} =~ /task/i) {
        $speak_code = "Task notice for $data{name}, $data{description}.";
        $speak_code .= $data{notes} if $data{notes};
   } else {
      if  ($data{allday} =~ /^y/i){
         if ($data{reminder_diff} = 1) {
            $speak_code = "Calendar notice.  Tomorrow: $data{description}.";
         } elsif ($data{reminder_diff} = 0) {
            $speak_code = "Calendar notice.  Today: $data{description}.";
         } else {
            $speak_code = "Calendar notice.  In $data{reminder_diff} days: $data{description}.";
         }
      } elsif ($data{reminder_diff}) {
         $speak_code = "Calendar Notice.  In $data{reminder_time} $data{reminder_units}"
           . (($data{reminder_time} > 1) ? 's' : '') . ", $data{description}.";
      } else {
        $speak_code = "Calendar notice at $data{time}: $data{description}";
      }
   }
   if ($speak_code) {
      $speak_code =~ s/'/\\'/g;
      $speak_code = "speak (\'app=organizer $speak_code\'); display (\'app=organizer $speak_code\');";
   }
   return $speak_code;
}

sub get_textmsg_code {
   my (%data) = @_;
   my $notes = '';
   my $subject = $data{description};
   if ($data{type} =~ /task/i) {
      $notes .= "$data{notes}. " if $data{notes};
      $notes .= "Due $data{date}" if $data{date};
      $notes .= " at $data{time}" if $data{time} and $data{time} !~ /12:00 am/i;
   } else {
      $notes .= "Occuring on $data{date}";
   }
   my $email = "net_mail_send to => '$_organizer_emails{lc $data{name}}', subject => q~$subject~, text => q~$notes~; ";
   return $email;
}

sub generate_code {
    my ($fh, %data) = @_;
    $data{time_date} = "$data{date} $data{time}";
    my $default_reminder = $main::config_parms{organizer_reminder};
    $default_reminder = '15m' unless $default_reminder;
    $data{reminder} = $default_reminder unless $data{reminder} or $data{allday} =~ /^y/i;
    my $task_flag = $main::config_parms{organizer_vc_category};
    if (($task_flag) && ($data{type} eq 'task') && 
       (($data{category} and ($data{category} =~ /^$task_flag/i)) or ($data{description} =~ /^$task_flag/i))) {
       my $cmd = $data{description};
       $task_flag .= ":";
       $cmd =~ s/$task_flag\s*//; # trim of the prefix/identifier if it exists
       my $vc = '';
       eval { $vc = &Voice_Cmd::voice_item_by_text("$cmd"); };
       if ($vc) {
          my $offcmd = $cmd;
          $offcmd =~ s/(\s+)on(\s*)/$1off$2/;
print "offcmd:$offcmd and enddt:$data{enddt}\n";
          if ($data{startdt}) {
             print MYCODE "   if (time_now '$data{startdt}') { &main::run_voice_cmd('$cmd'); };\n";
          }
          if ($data{enddt} and $offcmd) {
             print MYCODE "   if (time_now '$data{enddt}') { &main::run_voice_cmd('$offcmd'); };\n";
          }
       }
       return;
    }
    if ($data{reminder} and !(time_greater_than($data{time_date}) or $data{reminder} eq 'none')) {
       my @reminders = split(/,/,$data{reminder});
       for my $reminder_info (@reminders) {
          my ($reminder_time,$reminder_code) = $reminder_info =~ /^(\d+)(\S)/;
          if ($reminder_time) {
             my $reminder_diff = '00:00';
             my $reminder_units = 'minute';
             $reminder_code = 'm' unless $reminder_code;
             if ($reminder_code eq 'd') {
                $reminder_diff = (24*$reminder_time) . ':00';
                $reminder_units = 'day';
             } elsif ($reminder_code eq 'h') {
                $reminder_diff = "$reminder_time" . ':00';
                $reminder_units = 'hour';
             } elsif ($reminder_time > 0) {
                if ($reminder_time >= 60) {
                   my $hours = $reminder_time / 60;
                   my $minutes = $reminder_time % 60;
                   $reminder_diff = "$hours:" . (($minutes >= 10) ? $minutes : "0$minutes");
                } else {
                   $reminder_diff = '00:' . (($reminder_time >= 10) ? $reminder_time : "0$reminder_time");
                }
             }
             $data{reminder_diff} = $reminder_diff;
             $data{reminder_time} = $reminder_time;
             $data{reminder_units} = $reminder_units;
             print $fh "   if (time_now '$data{time_date} - $reminder_diff ') {" 
                   . &get_speak_code(%data) . "};\n";
          }   
       }
    }
    if ($data{type} =~ /task/i) {
        if (($speak_tasks) and ($data{speak} =~ /^y/i)) {
          if ($data{time} and ($data{time} !~ /12:00 am/i)) {
              print MYCODE "   if (time_now '$data{date} $data{time}') {" 
                    . &get_speak_code(%data) . "};\n";
           } else {
              foreach my $announce_time (@_organizer_announce_day_times) {
                 print MYCODE "   if (time_now '$data{date}  $announce_time') {" 
                   . &get_speak_code(%data) . "};\n";
              }
           }
        }
        if ($_organizer_emails{lc $data{name}}) {
           my $textmsg = &get_textmsg_code(%data);
           print MYCODE "   if (time_now '$data{date} 12 am') { $textmsg };\n";
        }

    } else {
        if ($data{allday} !~ /^y/i) {
          $data{reminder_diff} = 0; # reset so that the get_speak_code doesn't think that this is an advance alarm
           print $fh "   if (time_now '$data{time_date}') {" . &get_speak_code(%data) . "};\n";
        } else {
          $data{reminder_diff} = 0;
          $data{reminder_units} = 'day';
          my $alert_date = &get_offset_date(%data);
          foreach my $announce_time (@_organizer_announce_day_times) {
             print MYCODE "   if (time_now '$alert_date  $announce_time') {" . &get_speak_code(%data) . "};\n";
          }
          $data{reminder_diff} = 1;
          my $alert_date = &get_offset_date(%data);
          foreach my $announce_time (@_organizer_announce_priorday_times) {
             print MYCODE "   if (time_now '$alert_date  $announce_time') {" . &get_speak_code(%data) . "};\n";
          }
          # need to make the following adjustable
          if ($data{name} && ($data{description} =~ /birthday$/i or $data{description} =~ /anniversary$/i)) {
             $data{reminder_diff} = 5;
             $alert_date = &get_offset_date(%data);
             print $fh "   if (time_now '$alert_date 12 am') {" . &get_textmsg_code(%data) . "};\n";
          }
        }
    }

}

sub get_offset_date {
  my (%data) = @_;
  my $hoursoffset = $data{reminder_diff} * (($data{reminder_units} = 'day') ? 24 : 1);
  my @date = localtime(&main::my_str2time("$data{time_date} - $hoursoffset:00"));
  my $month = $date[4] + 1;
  my $year = $date[5] + 1900;
  my $offset_date = ($config_parms{date_format} =~ /ddmm/) ? "$date[3]/$month/$year" 
      : "$month/$date[3]/$year";
  return $offset_date;
}

sub update_vsdb {

   my %upd_data = %{$_[0]};
   my $filename = $_[1];
   my $db = $_[2];

   for  my $upgrade ( sort (keys(%upd_data))) {

      #print "u=$upd_data{$upgrade}\n";

      my $file_chk  = $filename. "." . $upgrade;
      my $file_skip  = $filename. "." . $upgrade . "skip";

      if (-e $file_skip) {

	print "Organizer.pl: Skipping $db $upgrade upgrade.\n";

      } elsif (! -e $file_chk ) {

	print "Organizer.pl: Upgrading $db to version $upgrade...\n";

	my @upd_fields = split(/,/,$upd_data{$upgrade});
	copy ($filename,$file_skip);
        my ($objDB) = new vsDB(file => $filename);
	
	$objDB->Open;
        my %fnames =();
	my @fields = $objDB->FieldNames;
	#@fields = map { lc } @fields;
	#@upd_fields = map { lc } @upd_fields;
	for (@fields) { $fnames{$_} = 1 }
	foreach my $field (@upd_fields) {
	   #print "field=$field\t a=$fnames{$field}\n";
	   $objDB->AddNewField($field) if !$fnames{$field};
	}
 
	$objDB->Commit;
	$objDB->Close; 
	rename ($file_skip, $file_chk); #should do some better error checking
      }
   }
}


