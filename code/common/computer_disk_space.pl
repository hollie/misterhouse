# Category = Misc

#@ Show available disk space on Windows computers
#@ Does nothing on Linux at the moment

# noloop=start
if ($OS_win) {
    my $disk_drives = '';
    $disk_drives = join( ',', Win32::DriveInfo::DrivesInUse() );
    $v_disk_space =
      new Voice_Cmd("How much disk space is available on [$disk_drives]");
    $v_disk_space->set_info('This works only on Windows platforms');
    $v_disk_space2 = new Voice_Cmd("Show disk space");
    $v_disk_space2->set_info('Shows disk space on all drives');
    $v_disk_space3 = new Voice_Cmd("Check disk space");
    $v_disk_space3->set_info('Check disk space requirements');
}

# noloop=stop

# Create trigger to check disk space requirements periodically

if ($Reload) {
    &trigger_set(
        "time_cron '0 18 * * 6'",
        "run_voice_cmd('Check disk space')",
        'NoExpire',
        'check disk space'
    ) unless &trigger_get('check disk space');
}

if ( said $v_disk_space3) {
    my $drive;

    if ( $Pgm_Path =~ /^([A-Z]):/i )
    {    # Need check for network shares (\\machine\share)

        my $msg       = '';
        my $important = 0;

        $drive = $1;
        my ( $total, $free ) = ( Win32::DriveInfo::DriveSpace($drive) )[ 5, 6 ];

        $free = int( $free / 10**6 );

        if ( $free < 1000 ) {
            $msg =
              ' That is cutting it close. Time to empty the recycle bin and clear temporary Internet files.';
            $important = 1;
        }

        $v_disk_space3->respond(
            "app=pc important=$important I am installed on drive $drive. There are $free megabytes free.$msg"
        );
    }
    else {
        $v_disk_space3->respond(
            "app=pc I cannot determine the drive space requirements");
    }

}

if ( said $v_disk_space) {
    my $state = $v_disk_space->{state};
    my ( $total, $free ) = ( Win32::DriveInfo::DriveSpace($state) )[ 5, 6 ];
    $v_disk_space->respond(
        sprintf(
            "app=pc There is %d out of %d megabytes of space available on drive $state",
            $free / 10**6,
            $total / 10**6
        )
    );
}

if ( said $v_disk_space2) {
    $v_disk_space2->respond("app=pc Checking disk space...");

    # Include remote drives on other computers
    my $report = "Disk drive space (free / total megabytes) sorted by drive:\n";
    my ( %total_by_drive, %free_by_drive );

    for my $drive ( Win32::DriveInfo::DrivesInUse() ) {
        next if $drive eq 'A';
        my ( $total, $free ) = ( Win32::DriveInfo::DriveSpace($drive) )[ 5, 6 ];
        $total /= 10**6;
        $free  /= 10**6;
        $total_by_drive{$drive} = $total;
        $free_by_drive{$drive}  = $free;
        $report .= sprintf( "%14s: %6.1f / %6.1f\n", $drive, $free, $total );
    }
    $report .=
      "\n\nDisk drive space (free / total megabytes) sorted by free space:\n";
    for my $drive (
        sort { $free_by_drive{$a} <=> $free_by_drive{$b} or $a cmp $b }
        keys %free_by_drive
      )
    {
        $report .= sprintf( "%14s: %6.1f / %6.1f\n",
            $drive, $free_by_drive{$drive}, $total_by_drive{$drive} );
    }
    display $report, 30, 'Disk use report', 'fixed';
    $v_disk_space2->respond("app=pc Here is the report on disk space.");

}
