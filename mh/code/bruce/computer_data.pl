# Category=Misc

my $disk_drives = '';
$disk_drives = join(',', Win32::DriveInfo::DrivesInUse()) if $OS_win;
$v_disk_space = new Voice_Cmd("How much disk space is available on [$disk_drives]");
$v_disk_space-> set_info('This currently only works on Windows');

if ($state = said $v_disk_space) {
    my ($total, $free) = (Win32::DriveInfo::DriveSpace($state))[5,6] if $OS_win;
    speak sprintf("There is %d out of %d megabytes of space available on drive $state",
		  $free/10**6, $total/10**6);
}

$v_disk_space2 = new Voice_Cmd("Show disk space", 'Ok');
$v_disk_space2-> set_info('Shows disk space onall drives (Windows only)');

if (said $v_disk_space2) {
				# Include remote drives on other computers
    my $report = "Disk drive space (free / total megabytes) sorted by drive:\n";
    my (%total_by_drive, %free_by_drive);
    if ($OS_win) {
        for my $drive (Win32::DriveInfo::DrivesInUse(),
                       '\\\dm\c', '\\\dm\d', '\\\dm\e', '\\\dm\f') {
            next if $drive eq 'A';
            my ($total, $free) = (Win32::DriveInfo::DriveSpace($drive))[5,6];
            $total /= 10**6;
            $free  /= 10**6;
            $total_by_drive{$drive} = $total;
            $free_by_drive{$drive} = $free;
            $report .= sprintf("%14s: %6.1f / %6.1f\n", $drive, $free, $total);
        }
        $report .=  "\n\nDisk drive space (free / total megabytes) sorted by free space:\n";
        for my $drive (sort {$free_by_drive{$a} <=> $free_by_drive{$b} or $a cmp $b} keys %free_by_drive) {
            $report .= sprintf("%14s: %6.1f / %6.1f\n", $drive, $free_by_drive{$drive}, $total_by_drive{$drive});
        }
        display $report, 30, 'Disk use report', 'fixed';
        speak "Here is the report on disk space";
    }
    else {
        speak "Sorry, function not available on unix yet";
    }
}
