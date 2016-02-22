
=begin comment

speed logger v1.0
By Larry Roudebush

Ftp transfer program that takes a small program and transfers it to an ftp
account.  upon completion of the upload and download it logs how long it took
to get the program there After that, it does simple math and caculates your
transfer speed and logs it in to two seperate file so I can track it in excell
any questions just ask.  I have found that geocities is one of the few ftp
servers that offer standard ftp service for free.

=cut    

my $getspeedcheckfile = 'c:\mh\larry\data\ftp\ftptestfile.doc'
  ;    #these are just the name and location of the files
my $getremotespeedcheck = 'ftptestfile.doc'; #you want to get off the ftp server
my $putspeedcheckfile = 'c:\mh\larry\data\ftptestfile.doc'
  ;    #these are the name and location of the files
my $putremotespeedcheck = 'ftptestfile.doc';  #you want to put on the ftp server
my $speedcheckuser = '__userid__';    #this is your user id for the ftp server
my $speedcheckpassword =
  '__password__';                     #this is your password for the ftp server

# This is the download speed check
$getspeedcheck        = new Process_Item;
$v_downloadspeedcheck = new Voice_Cmd 'Checking internet download speed [get]';
if ( $state = said $v_downloadspeedcheck or time_cron '1 0,6,12,18 * * * ' ) {
    unlink $getspeedcheckfile;
    $Save{get_time_before_start} = $Time;
    print_log "checking internet download speed";
    set $getspeedcheck
      "net_ftp -file $getspeedcheckfile -file_remote $getremotespeedcheck "
      . "-command get -server ftp.geocities.com -user $speedcheckuser -password $speedcheckpassword";
    start $getspeedcheck;
}

if ( done_now $getspeedcheck) {
    $Save{get_time_after_start} = $Time;
    my $get_time_diff =
      $Save{get_time_after_start} - $Save{get_time_before_start};
    print_log "Ftp command done";
    my $getfilesize       = ( -s $putspeedcheckfile );
    my $get_speed_time    = $getfilesize / $get_time_diff;
    my $get_KB_speed_time = $get_speed_time / 1024;
    speak
      "Your download took $get_time_diff seconds with a speed of $get_KB_speed_time kilobytes per second";
    logit "$config_parms{data_dir}/logs/get_internet_speed.txt",
      "Your download took $get_time_diff seconds with a speed of $get_KB_speed_time";
}

# This is the upload  speed check
$putspeedcheck      = new Process_Item;
$deletespeedcheck   = new Process_Item;
$v_uploadspeedcheck = new Voice_Cmd 'Checking internet upload speed [put]';
if ( $state = said $v_uploadspeedcheck or time_cron '30 0,6,12,18 * * * ' ) {
    set $deletespeedcheck "net_ftp -file_remote $putremotespeedcheck "
      . "-command delete -server ftp.geocities.com -user $speedcheckuser -password $speedcheckpassword";
    start $deletespeedcheck;
}
if ( done_now $deletespeedcheck) {
    $Save{put_time_before_start} = $Time;
    print_log "checking internet upload speed";
    set $putspeedcheck
      "net_ftp -file $putspeedcheckfile -file_remote $putremotespeedcheck "
      . "-command put -server ftp.geocities.com -user $speedcheckuser -password $speedcheckpassword";
    start $putspeedcheck;
}

if ( done_now $putspeedcheck) {
    $Save{put_time_after_start} = $Time;
    my $put_time_diff =
      $Save{put_time_after_start} - $Save{put_time_before_start};
    print_log "Ftp command done";
    my $putfilesize       = ( -s $putspeedcheckfile );
    my $put_speed_time    = $putfilesize / $put_time_diff;
    my $put_KB_speed_time = $put_speed_time / 1024;
    speak
      "Your upload took $put_time_diff seconds with a speed of $put_KB_speed_time kilobytes per second";
    logit "$config_parms{data_dir}/logs/put_internet_speed.txt",
      "Your upload took $put_time_diff seconds with a speed of $put_KB_speed_time";
}
