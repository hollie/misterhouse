
#Category=News

#@ Check incoming email and announce big breaking news from CNN.
#@ Subscribe here:  <a href="http://www.cnn.com/EMAIL/">http://www.cnn.com/EMAIL/</a>.
#@ Requires internet_mail.pl in the Internet category.

# get_email_scan_file and $p_get_email are created by internet_mail.pl
if ( done_now $p_get_email and -e $get_email_scan_file ) {
    for my $line ( file_read $get_email_scan_file) {
        my ( $from, $to, $subject, $body ) =
          $line =~ /From:(.+?) To:(.+?) Subject:(.+?) Body:(.+)/;
        if ( $subject =~ /CNN breaking news/i or $subject =~ /News Alert/i ) {

            #           print "dbx1 s=$subject body=$body\nline=$line\n";
            $body =~ s/.+BREAKING NEWS from CNN.com//i;
            $body =~ s/For complete coverage.+//i;
            $body =~ s/Full story on .+//i;
            $body =~ s/Watch CNN .+//i;
            $body =~ s/Log on to .+//i;
            $body =~ s/\>\+.*//g;
            my $msg = "Notice, just received news item: $subject.\n  $body";
            display $msg, 0;
            speak rooms => 'all', text => substr $msg, 0, 200;
        }
    }
}

#  BREAKING NEWS from CNN.com CNN has confirmed that convicted spy Edmond Pope has been released from a Russian prison.  of this story visit: http:

=for comment

From:    BreakingNews@CNN.COM
Subject: CNN Breaking News
Body: 
-- CNN confirms Sen. Barack Obama has chosen Delaware Sen. Joe Biden to be his vice-presidential running mate.

>+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
CNN covers the conventions: the Democrats live from Denver starting
Monday and the Republicans live from Minneapolis-St. Paul starting
September 1 on CNN and CNN.com. http://www.cnnpolitics.com
>+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=



You have opted-in in to receive this e-mail from CNN.com.
To unsubscribe from Breaking News e-mail alerts, go to: http://cgi.cnn.com/m/clik?l=textbreakingnews.

One CNN Center Atlanta, GA 30303
(c) & (r) 2008 Cable News Network



CNN Interactive email id:138970049022650840

=cut
