# Category=Internet

# Note: to enable this code, fill in the net_mail parms in the mh.ini or mh.private.ini files

                                # Example on how to send an email command
                                # - This string can be in either the subject or the body of the email
                                #      Subject line is:  command:x y z  code:xyz
$v_send_email_test = new  Voice_Cmd('Send test e mail [1,2,3]', 'Ok, will do');
$v_send_email_test-> set_info('Send commands to test remote email commands');
if ($state = said $v_send_email_test) {
    if (&net_connect_check) {
                                # Use to => 'user@xyz.com', or default to your own address (from net_mail_user in mh.ini)
        &net_mail_send(subject => "test 1", text => "Test email 1 sent at $Time_Date") if $state == 1;

                                # Send a command in the subject
        &net_mail_send(subject => "command:What time is it  code:$config_parms{net_mail_command_code}",
                       text => "I have been running for " . &time_diff($Time_Startup_time, time)) if $state == 2;

                                # Send a command in the body
        &net_mail_send(subject => "test command in body of text",
                       text => "command:What is your up time?  code:$config_parms{net_mail_command_code}") if $state == 3;
        speak "Test message has been sent";
    }
    else {
        speak "Sorry, you are not currently logged on to the internet, so I can not send mail";
    }
}

                                # Check for recent email since last received by mail program
                                # Do it with a get_email process, so mh will not pause
#&tk_radiobutton('Check email', \$Save{email_check}, ['no', 'yes']);
$p_get_email = new Process_Item('get_email -quiet');
$v_recent_email = new  Voice_Cmd('{Check for,List new} e mail', 'Ok, hang on a second and I will check for new email');
$v_recent_email-> set_info('Download and summarize new email headers');
if (said $v_recent_email or ($Save{email_check} ne 'no' and !$Save{sleeping_parents} and
                             $New_Minute and !($Minute % 10) and &net_connect_check)) { 
    start $p_get_email;
}

# $new_mail_light= new X10_Item('O7');
if (done_now $p_get_email) {
    $Save{email_flag} = file_read "$config_parms{data_dir}/get_email.flag";

                                # Turn on an 'new mail indicator'
                                #  - could be modified for different lights for different accounts.
#   set $new_mail_light (($Save{email_flag} =~ /[1-9]/) ? ON : OFF);

                                # Once an hour, summarize all email, otherwise just new mail
    if ($Minute < 10) {
        &speak_unread_mail;
    }
    else {
        &speak_new_mail;
    }
    &scan_subjects("$config_parms{data_dir}/get_email.scan")
}
&tk_mlabel(\$Save{email_flag});

                                # List or read unread email
$v_unread_email = new  Voice_Cmd('[List,Read] unread e mail');
$v_unread_email-> set_info('Summarize unread email headers and optionally call Outlook to read the mail');
$read_email = new Serial_Item('XOD');
if ($state = said $v_unread_email or 
    state_now $read_email) {
#   time_cron('55 16,17,19,21 * * *')) { 
    &speak_unread_mail unless $Save{email_check} eq 'no';
    if ($state eq 'Read' or state_now $read_email) {
        if (my $window = &sendkeys_find_window('Outlook', 'D:\msOffice\Office\OUTLOOK.EXE')) {
#           my $keys = '\\alt+\\tss\\alt-\\';  # For Outlook Express
            my $keys = '\\alt\\te\\ret\\';     # For Outlook
            &SendKeys($window, $keys, 1, 500);
        }
    }
}

sub speak_new_mail {
    my $text = file_read "$config_parms{data_dir}/get_email.txt";
    chomp $text;
    speak "rooms=all $text" if $text;
}

sub speak_unread_mail {
    my $text = file_read "$config_parms{data_dir}/get_email2.txt";
    chomp $text;
    speak "rooms=all $text" if $text;
}

                                # Allow for email send commands, if the secret command code matches 
sub scan_subjects {
    my ($file) = @_;
    return unless -e $file;
    for my $line (file_read($file)) {
        my($from, $to, $subject_body) = $line =~ /From:(.+) To:(.+) Subject:(.*)/;
        if (my($command, $code) = $subject_body =~ /command:(.+) code:(\S+)/) {
            chomp $command;
            my $results;
             if ($config_parms{net_mail_command_code} and $config_parms{net_mail_command_code} eq $code) {
                speak "Running email command: $command";
                if (run_voice_cmd $command) {
                    $results = "Command was run: $command";
                }
                else {
                    speak "Command not found";
                    $results = "Command not found: $command";
                }
            }
            else {
                speak "An unauthorized email command received: $command";
                $results = "Command not authorized: $command  code:$code";
            }
            logit("$config_parms{data_dir}/logs/email_command.log", "From:$from  " . $results);
            &net_mail_send(to => $from, subject => $results);
        }
    }
    unlink $file;
}

