
#Category=Weather
#This file scans all email on server and if an email is from NBC4Columbus.  If the email is from them it speaks the current
#weather announcement every 15 minutes and sends out a message to my pager.
#Larry Roudebush

my $person3email = $config_parms{person3email};
my $speakweathertimes =
  0;    # get_email_scan_file and $p_get_email are created by internet_mail.pl
if ( done_now $p_get_email and -e $get_email_scan_file ) {
    for my $line ( file_read $get_email_scan_file) {
        my ( $from, $to, $subject, $body ) =
          $line =~ /From:(.+?) To:(.+?) Subject:(.+?) Body:(.+)/;
        if ( $from =~ /NBC4Columbus/i ) {
            my $msg = "Notice, just received Weather Information: $subject.\n";
            display $msg, 120;
            logit( "$config_parms{data_dir}/logs/weatherwarning.txt", $msg );

            speak rooms => 'all', text => substr $msg, 0, 200;
            &net_mail_send(
                to      => '$person3email',
                subject => "Weather Alert",
                text    => "$subject",
                debug   => 1
            );
        }
    }
}

if ( time_cron '0,15,30,45 * * * *' ) {    #speaks every 15 minutes
    if ( -e "$config_parms{data_dir}/logs/weatherwarning.txt" ) {
        $speakweathertimes =
          $speakweathertimes + 1;          #remembers how many times it spoke
        open( weatherwariningfile,
            "$config_parms{data_dir}/logs/weatherwarning.txt" )
          or die "No Warnings available.\n";
        while (<weatherwariningfile>) {
            speak $_;
        }
        print_log "$speakweathertimes, close file";
        close(weatherwariningfile);
        if ( $speakweathertimes == '4' ) {
            $speakweathertimes = '0';
            unlink "$config_parms{data_dir}/logs/weatherwarning.txt"
              ;                            #deletes it after an hour
            print_log "Deleting weather warning file";
        }
    }
    else {
        #print_log "no weather warning info";
    }

}
