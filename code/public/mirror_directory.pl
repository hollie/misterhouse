$do_mirror_directory   = new Process_Item;
$do_mirror_directory_v = new Voice_Cmd 'Run mirror directory';
$do_mirror_directory_v->set_info('Mirrors two seperate directories daily');

run_voice_cmd '$do_mirror_directory' if $New_Day;

if ( said $do_mirror_directory_v) {
    speak "Starting mirror directory";
    my $pgm = 'do_mirror_directory';
    set $do_mirror_directory $pgm
      . ' -directory //Mrlarry/quickenw/backup //bushserv/d/backup/larry/quicken';

    start $do_mirror_directory;
}

speak 'Mirror Directory Completed' if done_now $do_mirror_directory;
