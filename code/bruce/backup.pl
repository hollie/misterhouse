
# Category=MisterHouse

#@ Backup important computer files, using mh/bin/backup_data

$backup_process = new Process_Item;
$backup_process_v =
  new Voice_Cmd 'Run [daily,daily laptop,monthly,monthly laptop] backup';
$backup_process_v->set_info(
    'Daily backups store recently change files, monthly stores them all');

run_voice_cmd 'Run daily backup'   if $New_Day;
run_voice_cmd 'Run monthly backup' if $New_Month;

if ( $state = said $backup_process_v) {
    speak "Starting $state backup";
    my $pgm =
      ( $state =~ /daily/ ) ? 'backup_data -no_date -age 120' : 'backup_data';

    # Laptop is done seperatly, since it is not always connected
    if ( $state =~ /laptop/ ) {
        set $backup_process $pgm
          . ' -file /backup/laurie_laptop -size 5000 //acer/d/l';

        #       set $backup_process $pgm . ' -file /backup/laurie_laptop -size 5000 //tp/d/l';
    }
    else {
        set $backup_process
          $pgm . ' -file f:/backup/linux_bin //misterhouse.net/bin',
          $pgm
          . ' -file f:/backup/www -size 1000 -skip "(/eq$)|(/old$)" //misterhouse.net/www //misterhouse.net/public',

          #            $pgm . ' -file f:/backup/laurie -size 5000 /l',
          $pgm . ' -file f:/backup/mh_articles -size 100000 //nas/mh/articles',
          $pgm
          . ' -file f:/backup/mh -skip "(/upload$)|(/tv$)|(/compile/p2)|(/articles$)" //nas/mh /bin';

        #            $pgm . ' -file //misterhouse.net/i/backup/laurie -size 5000 /l',
        #            $pgm . ' -file //misterhouse.net/i/backup/mh_articles -size 100000 /misterhouse/articles',
        #            $pgm . ' -file //misterhouse.net/i/backup/mh -skip "(/upload$)|(/tv$)|(/compile/p2)|(/articles$)" /misterhouse /bin';
    }
    start $backup_process;
}

speak 'Backup is done' if done_now $backup_process;

$mirror_process = new Process_Item;
$mirror_cmd     = new Voice_Cmd 'Update Nick eq dir';

if ( said $mirror_cmd) {
    my $cmd = 'mirror_dir //warp/c/temp/eq //misterhouse.net/public/eq';
    print_log "Starting: $cmd";
    set $mirror_process $cmd;
    set_output $mirror_process "//warp/c/temp/mirror.log";
    start $mirror_process;
}

speak "rooms=nick Nick, your eq files are copied" if done_now $mirror_process;
