# Category=Internet

$v_get_ceiva = new Voice_Cmd 'Check for new Ceiva photos';
$v_get_ceiva-> set_info('This will retreive and display new photos from Internet Ceiva.com folders');
$p_get_ceiva = new Process_Item 'get_ceiva';

if (said $v_get_ceiva) {
    start $p_get_ceiva;
    print_log 'Checking for new Ceiva photos';
}
                                # Display any new pictures from today
if (done_now $p_get_ceiva) {
    opendir DIR, $config_parms{ceiva_dir} or print_log "Error in opening $config_parms{ceiva_dir}";
    for my $file (readdir DIR){ 
        next unless $file =~ /f\.jpg$/i;
        $file = "$config_parms{ceiva_dir}/$file";
        my ($time_file) = (stat $file)[9];
        display $file, 0 if 60*5 > (time - $time_file);
#       display $file, 10;
    }
    close DIR;
}

