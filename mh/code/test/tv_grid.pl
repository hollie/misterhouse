# Category=TV

$VCR = new IR_Item 'VCR', '3digit';

                                # Note: This $tv_grid is a special name, used by the get_tv_grid program.  
                                #       Do not change it.
$tv_grid = new Generic_Item();

                                # This item will be set whenever someone clicks on the 'set the vcr' link on the tv web page
if (my $data = state_now $tv_grid) {

                                # http://house:8080/SET?$tv_grid?channel_2_from_7:00_to_8:00

    my($channel, $start, $stop, $date, $show_name) = $data =~ /(\d+) from (\S+) to (\S+) on (\S+) for (.*)/;

    unless ($start) {
        my $msg = "Bad tv_grid time: $data";
        speak $msg;
        print_log $msg;
        return;
    }

    my $msg = "Programing vcr for $show_name.  Channel $channel from $start to $stop on $date.";
    speak $msg;
    print_log $msg;

                                # Write out a new entry in the grid_programing.pl file
                                #  - we could/should prune out old code here.
    my $tv_grid_file = "$config_parms{code_dir}/tv_grid_programing.pl";
    print_log "Writing to $tv_grid_file";
    open(TVGRID, ">>$tv_grid_file") or print_log "Error in writing to $tv_grid_file";

    print TVGRID<<eof;

    if (time_now '$date $start - 00:02') {
        speak "rooms=all \$Time_Now. VCR recording will be started in 2 minutes for $show_name";
    }
    if (time_now '$date $start') {
        speak "VCR recording started";
        print_log "VCR recording on channel $channel for $show_name";
        set \$VCR "STOP,$channel,RECORD"; # Stop first, in case we were already finishing recording something else
#       run('min', 'IR_cmd VCR,$channel,RECORD');
    }
#   if (time_now '$date $stop - 00:01') {
    if (time_now '$date $stop') {
        speak "VCR recording stopped";
        set \$VCR "$channel,STOP";
#       run('min', 'IR_cmd VCR,STOP');
    }

eof

    close TVGRID;

    &do_user_file($tv_grid_file); # This will replace the old grid programing

}

                                # This is what downloads tv data.  This needs to be forked/detatched, as it can take a while
$v_get_tv_grid_data1 = new  Voice_Cmd('[Get,reget,redo] tv grid data for today');
$v_get_tv_grid_data7 = new  Voice_Cmd('[Get,reget,redo] tv grid data for the next week');
$v_get_tv_grid_data1-> set_info('Updates the TV database with.  reget will reget html, redo re-uses.  Get will only reget or redo if the data is old.');
if ($state = said  $v_get_tv_grid_data1 or $state = said  $v_get_tv_grid_data7) {
    if (&net_connect_check) {
        my $days = (said $v_get_tv_grid_data7) ? 7 : 1;
        $state = ($state eq 'Get') ? '' : "-$state";
        my $pgm = "get_tv_grid -userid $config_parms{clicktv_id} $state -days $days";
        $pgm .= qq[ -hour  "$config_parms{clicktv_hours}"] if $config_parms{clicktv_hours};
        $pgm .= qq[ -label "$config_parms{clicktv_label}"] if $config_parms{clicktv_label};

                                # Allow data to be stored wherever the alias points to
        $pgm .= qq[ -outdir "$1"] if $config_parms{html_alias_tv} =~ /\S+\s+(\S+)/;

                                # If we have set the net_mail_send_account, send default web page via email
        my $mail_account = $config_parms{net_mail_send_account};
        my $mail_server  = $main::config_parms{"net_mail_${mail_account}_server"};
        my $mail_to      = $main::config_parms{"net_mail_${mail_account}_address"};
        if ($mail_to and $mail_server) {
            $pgm .= " -mail_to $mail_to -mail_server $mail_server ";
            $pgm .= " -mail_baseref $config_parms{http_server}:$config_parms{http_port} ";
        }

        run $pgm;
        print_log "TV grid update started";
    }
    else {
	    speak "Sorry, you must be logged onto the net";
    }
}

                                # Set the default page to the current time
if (time_cron "0 $config_parms{clicktv_hours} * * *") {
    my $tvfile = sprintf "%02d_%02d.html", $Mday, $Hour;
    my $tvdir = "$config_parms{html_dir}/tv";
    if ( -e  "$tvdir/$tvfile" ) {
        copy "$tvdir/$tvfile", "$tvdir/index.html";
#       my $tvhtml = file_read "$tvdir/$tvfile";
#       file_write "$tvdir/index.html", $tvhtml;
    }
}
