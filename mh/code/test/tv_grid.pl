# Category=TV

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

                                # Write out a new entry to triggers.new.  This will be processed
                                # into a self pruning triggers.pl file
    my $trigger_file = "$config_parms{data_dir}/triggers.new";
    print_log "Writing to tv programing to $trigger_file";
    open(TRIGGERS, ">>$trigger_file") or print_log "Error in writing to $trigger_file";

    print TRIGGERS<<eof;
time_now '$date $start - 00:02'
  speak "rooms=all \$Time_Now. VCR recording will be started in 2 minutes for $show_name";

time_now '$date $start'
  speak "VCR recording started";
  print_log "VCR recording on channel $channel for $show_name";
  set \$VCR "STOP,$channel,RECORD"; # Stop first, in case we were already finishing recording something else

time_now '$date $stop'
  speak "VCR recording stopped";
  set \$VCR "$channel,STOP";
# run('min', 'IR_cmd VCR,STOP');

eof

    close TRIGGERS;

}

                                # This is what downloads tv data.  This needs to be forked/detatched, as it can take a while
$v_get_tv_grid_data1 = new  Voice_Cmd('[Get,reget,redo] tv grid data for today');
$v_get_tv_grid_data7 = new  Voice_Cmd('[Get,reget,redo] tv grid data for the next week');
$v_get_tv_grid_data1-> set_info('Updates the TV database with.  reget will reget html, redo re-uses.  Get will only reget or redo if the data is old.');
if ($state = said  $v_get_tv_grid_data1 or $state = said  $v_get_tv_grid_data7) {
    if (&net_connect_check) {
        my $days = (said $v_get_tv_grid_data7) ? 7 : 1;
        $state = ($state eq 'Get') ? '' : "-$state";

                                # Call with -db sat to use sat_* parms instead of tv_* parms
        my $pgm = "get_tv_grid -db tv $state -days $days";

                                # Allow data to be stored wherever the alias points to
        my $tvdir = &html_alias('tv');
        $pgm .= qq[ -outdir "$tvdir"] if $tvdir;

                                # If we have set the net_mail_send_account, send default web page via email
        my $mail_account = $config_parms{net_mail_send_account};
        my $mail_server  = $main::config_parms{"net_mail_${mail_account}_server_send"};
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
                                # Check it a few minutes prior to the hour
#f (time_cron "0 $config_parms{tv_hours} * * *") {
if (time_cron "50 * * * *") {
    my ($hour, $mday) = (localtime(time + 600))[2,3];
    my $tvfile = sprintf "%02d_%02d.html", $mday, $hour;
    my $tvdir = "$config_parms{html_dir}/tv";
    $tvdir = &html_alias('tv') if &html_alias('tv');
    if ( -e  "$tvdir/$tvfile" ) {
        print_log "Updating TV index page for with $tvfile";
        copy "$tvdir/$tvfile", "$tvdir/index.html";
    }
}
