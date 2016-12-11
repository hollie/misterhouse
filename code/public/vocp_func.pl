
=begin comment

From Dave Lounsberry  dbl@dittos.yi.org  on 11/2002:

The MH integration is workable although not finished. I attached my MH
code (still rough) that does the following:

- Monitors /var/log/vgetty.log.ttyS?? for various messages like RING,
Caller id, etc. *Need noise level or modified vgetty to see modem
responses*
- Monitor /var/log/vocp.log for voicemail message status, etc. 
- Voice_Cmds to listen, check and delete existing voice mails. It
currently treats all the messages the same (does not support different
boxes). 
- Converts rmd voice mails to wav files for misterhouse to play when
requested. 
- Some preliminary web_func for webpage. Not usable. 

I have replaced my answering machine with VOCP and so far it is working
quite well. 


=cut

#Category=Phone
$timer_rmdtowav   = new Timer();
$p_rmdtowav       = new Process_Item;
$voice_mail_count = new Generic_Item;

sub vocp_message_list {
    my $return_msg = "<table border=1><tr><td>Mailbox</td><td>Number</td></tr>";
    my $num        = 0;
    opendir( INDIR, "/var/spool/voice/incoming" )
      or print "Could not open directory /var/spool/voice/incoming $!\n";
    foreach ( readdir(INDIR) ) {
        next unless /.rmd$/;
        s/.rmd$//;
        my ( $box, $number ) = split( /\-/, $_ );
        $num++;
        $return_msg .= "<tr><td>$box</td><td>$number</td></tr>\n";
    }
    closedir(INDIR);
    $voice_mail_count = $num;
    $return_msg .= "Total messages: $num\n";
    return ("$return_msg </table>");
}

$v_vocp_voice_mail =
  new Voice_Cmd('[Count,Listen to,Delete] all voice mail messages');

if ( $state = said $v_vocp_voice_mail) {
    my $num            = 0;
    my $voice_spooldir = "/var/spool/voice/incoming";
    my @vmails;
    opendir( INDIR, "$voice_spooldir" )
      or print "Could not open directory $voice_spooldir $!\n";
    foreach ( readdir(INDIR) ) {
        next unless /.rmd$/;
        push( @vmails, $_ );
        $num++;
        $voice_mail_count = $num;
    }
    closedir(INDIR);
    if ( $state eq "Count" ) {
        if ($num) {
            my $msg = "You have " . &plural( $num, "voice mail message" );
            speak( text => "$msg" );
        }
    }
    elsif ( $state eq "Delete" ) {
        speak( text => "Deleting all voice mail messages." );
        foreach (@vmails) {
            unlink("$voice_spooldir/$_");
            unlink("$config_parms{data_dir}/$_.wav");
            unlink("$config_parms{data_dir}/$_.txt");
        }
    }
    elsif ( $state eq "Listen to" ) {
        if ( !$num ) {
            speak( text => "No voice mails in the system." );
        }
        else {
            my $msg = "You have " . &plural( $num, "voice mail message" );
            speak( text => "$msg" );
            my $curnum = 1;
            my $vfile;
            foreach $vfile (@vmails) {
                open( CALLER, "< $config_parms{data_dir}/$vfile.txt" );
                my ($caller) = <CALLER>;
                chomp $caller;
                close CALLER;
                my $msg =
                  "Voice mail message number " . $curnum++ . " from $caller";
                speak(
                    text_first => 1,
                    play       => "$config_parms{data_dir}/$vfile.wav",
                    text       => "$msg"
                );
            }
        }
    }
}

$f_vgetty_log = new File_Item("/var/log/vgetty.log.ttyS17");
$f_vocp_log   = new File_Item("/var/log/vocp.log");

my ( $vgetty_record, $vocp_record, $callerid_data );

if ( $state = said $f_vgetty_log) {
    $vgetty_record = $state;
    if ( $vgetty_record =~ /got: .*RING/ ) {
        speak( rooms => "garage", play => "phone_ring" );
        print_log "Phone ringing";
    }
    if ( $vgetty_record =~ /phone stopped ringing/ ) {
        print_log "Phone stopped ringing";
    }
    if ( $vgetty_record =~ /closing voice modem device/ ) {
        speak( text => "Hanging up phone." );
    }
    if (   $vgetty_record =~ /DATE =/
        or $vgetty_record =~ /TIME =/
        or $vgetty_record =~ /NMBR =/ )
    {
        $callerid_data .= ' ' . $vgetty_record;
    }
    if ( $vgetty_record =~ /NAME =/ ) {
        $callerid_data .= ' ' . $vgetty_record;
        my ( $caller, $cid_number, $cid_name, $cid_time ) =
          &Caller_ID::make_speakable( $callerid_data, 5 );
        $Save{last_caller} = $caller;
        speak(
            play => "none",
            text => "Call from $caller.  Phone call is from $caller."
        );
        print_log
          "callerid data: number=$cid_number name=$cid_name time=$cid_time";
        logit(
            "$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",
            "$cid_number $cid_name" );
        undef $callerid_data;
    }
}

if ( $state = said $f_vocp_log) {
    $vocp_record = $state;
    if ( $vocp_record =~ /HELLO VOICE PROGRAM/ ) {
        speak( text => "Answering phone. Talk to the man!" );
    }
    if ( $vocp_record =~ /Recording message/ ) {
        speak( text => "Caller leaving voice mail message." );
    }
    if ( $vocp_record =~ /Voice message recorded/ ) {
        speak( text => "Caller has left a voice mail message." );
    }
    if ( $vocp_record =~ /Got selection: 2/ ) {
        speak( text => "Caller is listening to alternative contacts numbers." );
    }
    if ( $vocp_record =~ /Sending to box .*\'(.*)\'/ ) {
        my $vmail_file = $1;
        my $vmail_base = basename($vmail_file);
        print_log "New voice mail file $vmail_file";
        set $p_rmdtowav
          qq[rmdtopvf $vmail_file | pvftowav > $config_parms{data_dir}/$vmail_base.wav];
        set $timer_rmdtowav 15;
        open( CALLER, ">>$config_parms{data_dir}/$vmail_base.txt" );
        print CALLER "$Save{last_caller}";
        close CALLER;
    }
}

if ( expired $timer_rmdtowav) {
    start $p_rmdtowav;
    run_voice_cmd 'Count all voice mail messages';
}

if ( time_cron '7,37 * * * *' and $voice_mail_count > 0 ) {
    run_voice_cmd 'Count all voice mail messages';
}
