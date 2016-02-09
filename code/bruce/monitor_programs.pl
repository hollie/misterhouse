# Category=Misc

#@ This code monitors programs running on other computers in the house.

=begin comment

Related code is in mh/code/bruce/monitor_router.pl, where we can
track packets going to and from the internet.

=cut

$monitor_programs = new Voice_Cmd
  'What programs are running on [localhost,C1,C2,WARP,Z,P90,House]';
$monitor_programs->set_info(
    'Uses Windows WMI to monitor programs on other computers in the house');

$active_programs = new Generic_Item;

my $monitor_program_results =
  "$config_parms{data_dir}/find_program_results.txt";
$monitor_programs_p = new Process_Item;
$monitor_programs_p->set_output($monitor_program_results);

if ( my $box = said $monitor_programs) {
    set $monitor_programs_p "find_programs $box";
    start $monitor_programs_p;
    $monitor_programs_p->{done_action} = 'display';
}
if ( done_now $monitor_programs_p) {
    my $results  = file_read $monitor_program_results, 1, 1;
    my $box      = state $monitor_programs;
    my $programs = $results;
    $programs =~ s/.+? Pgm:(\S+)/$1,/gs;
    $programs =~ s/, .+//;

    #Do not log House, as it gets run often.  Use localhost if you want a display/log
    if ( $box eq 'House' ) {
        set $active_programs $programs;
    }
    else {
        logit "$config_parms{data_dir}/logs/monitor_programs.log",
          "$box: $programs";
        display $results . "\nPrograms: $programs", 30,
          "Program Monitor results for $box", 'fixed'
          if $monitor_programs_p->{done_action} eq 'display';
    }

    my $eq_stats = $1 . $2 . $3 if $results =~ /(Pgm:)(eq|war3)(.+?)Date/;
    if ($eq_stats) {
        $Save{eq_time} += .1;
        $Save{eq_time} = round $Save{eq_time}, 1;
        $eq_stats = "Time: $Save{eq_time}, " . $eq_stats;
        logit "$config_parms{data_dir}/logs/eqtime.log", $eq_stats;
    }

}

# Run once a minute.  Not at New_Minute cause lots of stuff runs then
#run_voice_cmd 'What programs are running on House',undef,undef,1 if new_second 10;
run_voice_cmd 'What programs are running on House', undef, undef, 1
  if $New_Second and $Second == 40;

# Keep an eye on Nick the gamester
#if (new_minute 30 and time_greater_than '8 am') {
#    set   $monitor_programs_p "find_programs DM";
#    start $monitor_programs_p;
#}

=begin comment

The reset of this is not used.  This is the 'inline' way (same code used in find_programs), 
so mh would hang while waiting for a response.

if (my $box = said $monitor_programs) {
    my ($count, $results) = &wmi_processes($box);
    display "Total processes: $count\n$results", 30, "Processes running on $box", 'fixed';
}

sub wmi_processes {
    my ($box) = @_;
    my $list;
                                # Ignore common WIN98 and win2000 programs
    my @ignore_list = qw(DDHELP EXPLORE HPSJVXD .DLL MPREXE MSTASK
                         REXPROXY RPCSS RSRCMTR STIMON SYSTRAY TASKMON WINMGMT
                         cmd csrss 4nt explore lsass mstask mgsys services spool smss svchost svcjpst system
                         taskmgr winmgmt regsvc system winlogon
                         defwatch rtvscan stisvc vptray OSA msgsys mgabg pdesk);

    my $count = 0;
    if(my $WMI = Win32::OLE->GetObject("WinMgmts:{impersonationLevel=impersonate}!//$box")) {
        for my $process (Win32::OLE::in($WMI->InstancesOf('Win32_Process'))) {
            my $name = $process->{Name};
            $count++;
            next if grep $name =~ /$_/i, @ignore_list;
            $list .= sprintf "%5d %5d %-20s threads:%3s Mem:%5.2f MemPeak:%5.2f %s\n",
            $process->{ProcessID}, $process->{ParentProcessID}, $process->{Name}, $process->{ThreadCount}, 
            $process->{WorkingSetSize}/10**6, $process->{PeakWorkingSetSize}/10**6, $process->{CreationDate};
        }
    }
    else {
        print_log "WMI unable to connect to \\$box:" . Win32::OLE->LastError();
    }
    return($count, $list);
}

=cut

