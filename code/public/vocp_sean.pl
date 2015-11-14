
=begin comment

> Greetings,
> Has anyone integrated VOCP (a sourceforge voice mail system which
> lives 
> on top of vgetty) with MH yet? If so, would you mind sharing some 
> pointers? If not, is anyone interested in helping to do this? I'm
> willing to 
> contribute anything that I can.
> Thanks,
> David Satterfield

Yup, been there. Done that. Install the software then take a look at the
attached. The convertvmail.sh just tells converts the output from the
card to something usable. This might need tweaked depending upon the
format your voice modem outputs. Then the voice.conf is my configuration
file for my voice modem. It is what calls convertvmail.sh. This will
need to be customized to your system.


It requires a lamp that you have created as Voicemail_Light that it will
turn on when you receive a voicemail. It also requires vmail_streamer.pl
for web browser playback, but I, um, can't find it. I guess I'll have to
rewrite it. All it does is dump the wav file out to the browser with the
proper headers, etc. I must have accidentally deleted it. Oops. It will
play the voicemail quite nicely through the standard "speak" method
without that. Enjoy.


=cut

# Category=Control
# Authority:admin
$v_newvoicemail = new Voice_Cmd('New voice mail');

if ( said $v_newvoicemail) {
    $Save{vmail_flag} = 1;
    set $Voicemail_Light "ON";
    print_log "Received new voicemail";
}

# Category=Misc

sub lockvoicemail {
    return '' unless $Authorized eq 'admin' or $Authorized eq 'family';
    &file_write( "/var/lock/nologin.ttyS3", "1" );

    #system "touch /var/lock/nologin.ttyS3";
    return
        "<HTML><BODY>"
      . &html_header("Turning off voicemail")
      . "<META HTTP-EQUIV=\"REFRESH\" CONTENT=\"2;/ia5/phone/voicemail.shtml\"></BODY></HTML>";
}

sub unlockvoicemail {
    return '' unless $Authorized eq 'admin' or $Authorized eq 'family';
    unlink "/var/lock/nologin.ttyS3";
    return
        "<HTML><BODY>"
      . &html_header("Turning on voicemail")
      . "<META HTTP-EQUIV=\"REFRESH\" CONTENT=\"2;/ia5/phone/voicemail.shtml\"></BODY></HTML>";
}

sub voicemails {
    return '' unless $Authorized eq 'admin' or $Authorized eq 'family';
    $Save{vmail_flag} = 0;
    set $Voicemail_Light "OFF";
    my (
        $FileName,       $PhoneName,   $PhoneNumber,
        $PhoneTimeStamp, $PhoneLength, $htmlcode
    );
    if ( opendir( DIRLIST, $config_parms{voicemail_dir} ) ) {
        $htmlcode =
          "<TABLE WIDTH=\"100%\" CELLSPACING=\"8\"><TR CLASS=\"wvtheader\"><TH></TH><TH>Date</TH><TH>Time</TH><TH>Size</TH></TR>\n";
        while ( $FileName = readdir(DIRLIST) ) {
            if (   ( -f $config_parms{voicemail_dir} . "/" . $FileName )
                && ( $FileName !~ /^\.nfs/ ) )
            {
                my ( $dt, $tm, $ext ) = split /\./, $FileName;
                my $size = -s $config_parms{voicemail_dir} . "/" . $FileName;
                $tm =~ s/-/:/g;
                $htmlcode .= "<TR CLASS=\"wvtrow\">";
                $htmlcode .=
                  "<TD WIDTH=\"70\"><A HREF=\"/bin/vmail_streamer.pl?$FileName\">";
                $htmlcode .=
                  "<IMG BORDER=\"0\" SRC=\"/graphics/icons/listen.png\"></A>";
                $htmlcode .= "&nbsp;&nbsp;&nbsp;";
                $htmlcode .=
                  "<A HREF='/misc/SUB?speak(\"rooms=all $config_parms{voicemail_dir}$FileName\")'>";
                $htmlcode .=
                  "<IMG BORDER=\"0\" SRC=\"/ia5/images/play.png\"></A></TD>";
                $htmlcode .= "<TD>$dt</TD><TD>$tm</TD<TD>$size</TD>";
                $htmlcode .= "</TR>\n";
            }
        }
        $htmlcode .= "</TABLE>";
        $htmlcode .= "<BR><BR>";
        if ( -e "/var/lock/nologin.ttyS3" ) {
            $htmlcode .=
              "<A HREF=\"/misc/SUB?unlockvoicemail\"><IMG BORDER=\"0\" SRC=\"/ia5/images/off.gif\"></A>";
        }
        else {
            $htmlcode .=
              "<A HREF=\"/misc/SUB?lockvoicemail\"><IMG BORDER=\"0\" SRC=\"/ia5/images/on.gif\"></A> ";
        }
        $htmlcode .= "<BR><BR>";
    }
    return $htmlcode;
}

sub clearmsgs {
    return '' unless $Authorized eq 'admin' or $Authorized eq 'family';
    return &html_header("Delete voicemail?")
      . "<H2><A HREF=\"/misc/SUB?deletemsgs\">Continue?</A></H2>";
}

sub deletemsgs {
    return '' unless $Authorized eq 'admin' or $Authorized eq 'family';
    if ( opendir( DIRLIST, $config_parms{voicemail_dir} ) ) {
        while ( my $FileName = readdir(DIRLIST) ) {
            if ( -f $config_parms{voicemail_dir} . "/" . $FileName ) {
                unlink $config_parms{voicemail_dir} . "/" . $FileName;
            }
        }
    }
}
