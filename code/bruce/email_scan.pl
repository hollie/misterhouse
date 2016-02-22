
# Category=MisterHouse

#@ Check incoming email for various mh related stuff

# get_email_scan_file and $p_get_email are created by internet_mail.pl
if ( done_now $p_get_email and -e $get_email_scan_file ) {
    for my $line ( file_read $get_email_scan_file) {
        my ( $from, $to, $subject, $body ) =
          $line =~ /From:(.+?) To:(.+?) Subject:(.+?) Body:(.+)/;

        # Detect mh http server port is down from NetWhistle mail
        #       display  text => "$Time_Date: $subject\n", time => 0, window_name => 'debug', append => 'top';
        if ( $subject =~ /MISTERHOUSE:8080 HTTP Error/i ) {
            socket_close 'http';

            #           &socket_restart('http');
            my $msg =
              "Notice, http server was detected down, so I just restarted it.  $subject\n  $body";
            display text => $msg, time => 0, font => 'fixed';
            speak rooms => 'all', text => 'HTTP server was just restarted';
        }
    }
}

$v_send_email_scan_test = new Voice_Cmd 'Send a test scan email';
if ( $state = said $v_send_email_scan_test) {
    net_mail_send
      subject => "MISTERHOUSE:8080 HTTP Error - TEST",
      text    => "I am a test ... delete me";
    run_voice_cmd 'check for e mail';
}

=for comment

Example of incoming mail from NetWhistle

Netwhistle.com - MISTERHOUSE:8080 HTTP Error!
Member Account: MISTERHOUSE
Name: BRUCEWINTER
Device Name: MISTERHOUSE:8080
Device Type: HTTP
Device Tested: misterhouse.net:8080
Alert Time: 01/28/2001 10:53:07 (Greenwich Mean Time)
Monitor Run Timestamp: 980679117
Monitor Error Msg: CONNECTION REFUSED - CONNECTION TO SITE WAS REFUSED.

Netwhistle.com - MISTERHOUSE:8080 HTTP Success!
Monitor Error Msg: TARGET IS BACK ONLINE AFTER A PREVIOUS FAILURE

=cut

