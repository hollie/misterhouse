
# Send comic email once a day

if ( time_cron '2 5 * * *' ) {
    run_voice_cmd 'Email tempin weather chart';
    run_voice_cmd 'Email daily comics';

    #   my $file = sprintf "../../web/comics/Doonesbury-%4d.%02d.%02d.gif", $Year, $Month, $Mday;
    #   &net_mail_send(subject => "Doonesbury for " . time_date_stamp(),
    #		   file => $file, debug => 1);
}
