# Category=Internet

#@ This code will periodically scan and announce when you 
#@ receive new email.   Set the mh.ini net_mail_account* parms
#@ for the accounts to monitor.  This code also has some test 
#@ examples for sending email.

# Note: to enable this code, fill in the net_mail parms in the mh.ini or mh.private.ini files

                                # Example on how to send an email command
                                # - This string can be in either the subject or the body of the email
                                #      Subject line is:  command:x y z  code:xyz
$v_send_email_test = new  Voice_Cmd('Send test e mail [1,2,3,4,5,6,7,8,9,10,11]', 'Ok, will do');
$v_send_email_test-> set_info('Send commands to test remote email commands');
if ($state = $v_send_email_test->{said}) {
    if (&net_connect_check) {
                                # Use to => 'user@xyz.com', or default to your own address (from net_mail_user in mh.ini)
        &net_mail_send(subject => "test 1", text => "Test email 1 sent at $Time_Date", 
#                      to => 'bruce@misterhouse.net ; winter@chartermi.net',
                       debug => 1) if $state == 1;

                                # Send a command in the subject
        &net_mail_send(subject => "command:What time is it   code:$config_parms{net_mail_command_code}",
                       text => "I have been running for " . &time_diff($Time_Startup_time, time)) if $state == 2;

                                # Send a command in the body
        &net_mail_send(subject => "test command in body of text",
                       text => "command:What is your up time   \ncode:$config_parms{net_mail_command_code}") if $state == 3;

                                # Send attachements of different types
                                #  - Note mime parm is optional if file ends with that extention
        &net_mail_send(subject => 'test an html attachement',
                       baseref => 'localhost:8080',
                       file    => '../web/mh4/widgets.html', mime  => 'html') if $state == 4;

        &net_mail_send(subject => 'test a zip file attachement',
                       file    => 'c:/temp/test1.zip') if $state == 5;

        &net_mail_send(subject => 'test a tar.gz file attachement',
                       file    => 'c:/temp/test.tar.gz', mime => 'bin') if $state == 6;

        &net_mail_send(subject => 'test a gif file attachement',
                       file    => '../web/graphics/goofy.gif') if $state == 7;

        &net_mail_send(subject => 'test a txt file',
                       file    => '../docs/faq.txt') if $state == 8;

        &net_mail_send(subject => 'test an html file',
                       file    => '../docs/faq.html') if $state == 9;

                                # Test a request file via email
        &net_mail_send(subject => "command:request $config_parms{caller_id_file}  code:$config_parms{net_mail_command_code}") if $state == 10;
        &net_mail_send(subject => "command:set \$camera_light TOGGLE code:$config_parms{net_mail_command_code}") if $state == 11;

        speak "Test message has been sent";
    }
    else {
        speak "Sorry, you are not currently logged on to the internet, so I can not send mail";
    }
}


$cell_phone_test = new Voice_Cmd 'Send test e mail to the cell phone';
$cell_phone_test-> set_info("Send a test message to the cell phone");

if (said $cell_phone_test) {
    net_mail_send subject => 'Hi from MisterHouse: $Time_Now', to => $config_parms{cell_phone};
}

                                # Check for recent email since last received by mail program
                                # Do it with a get_email process, so mh will not pause
#&tk_radiobutton('Check email', \$Save{email_check}, ['no', 'yes']);
$p_get_email = new Process_Item('get_email -quiet');
$v_recent_email = new  Voice_Cmd('{Check for,List new} e mail', 'Ok, hang on a second and I will check for new email');
$v_recent_email-> set_info('Download and summarize new email headers');
if ($v_recent_email->{said} or ($Save{email_check} ne 'no' and !$Save{sleeping_parents} and
                             new_minute 10 and &net_connect_check)) { 
    start $p_get_email;
}

my $get_email_scan_file = "$config_parms{data_dir}/get_email.scan";
if ($p_get_email->{done_now}) {
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
    &scan_subjects($get_email_scan_file);
}
                                # Delete file after the done_now pass (gives other code
                                # like news_email_breaking.pl a changes to scan it)
elsif ($p_get_email->{done} and -e $get_email_scan_file) {
    unlink $get_email_scan_file;
}


&tk_mlabel(\$Save{email_flag});

                                # List or read unread email
$v_unread_email = new  Voice_Cmd('[List,Read] unread e mail');
$v_unread_email-> set_info('Summarize unread email headers and optionally call Outlook to read the mail');
if ($state = $v_unread_email->{said}) {
    &speak_unread_mail unless $Save{email_check} eq 'no';
    if ($state eq 'Read') {
        if (my $window = &sendkeys_find_window('Outlook', 'C:\Program Files\Microsoft Office\Office\OUTLOOK.EXE')) {
#       if (my $window = &sendkeys_find_window('Outlook', 'D:\msOffice\Office\OUTLOOK.EXE')) {
#           my $keys = '\\alt+\\tss\\alt-\\';  # For Outlook Express
            my $keys = '\\alt\\te\\ret\\';     # For Outlook
            &SendKeys($window, $keys, 1, 500);
        }
    }
}

sub speak_new_mail {
    my $text = file_read "$config_parms{data_dir}/get_email.txt";
    chomp $text;
    speak "voice=male rooms=all $text" if $text;
}

sub speak_unread_mail {
    my $text = file_read "$config_parms{data_dir}/get_email2.txt";
    chomp $text;
    speak "voice=male rooms=all $text" if $text;
}

                                # Allow for email send commands, IF the secret command code matches 
                                #  - someday we need to allow for better, more secure mail commands
sub scan_subjects {
    my ($file) = @_;
    return unless -e $file;
    for my $line (file_read $file) {
        my ($from, $to, $subject_body) = $line =~ /From:(.+) To:(.+) Subject:(.*)/;
        if (my($command, $code) = $subject_body =~ /command:(.+?)\s+code:(\S+)/i) {
            my $results;
             if ($config_parms{net_mail_command_code} and $config_parms{net_mail_command_code} eq $code) {
                 if (my ($file_request) = $command =~ /request_file\s(.+)/i) {
                     $file_request =~ s|\\|\/|g;
                     if (-e $file_request) {
                         speak "Sending email request file: $file_request";
                         $results = "Sending $file_request";
                         &net_mail_send(to => $from, subject => $results, file => $file_request, mime => 'bin');
                     }
                     else {
                         speak "Email requested file not found:$file_request";
                         $results = "$file_request not found";
                     }
                 }
                 else {
                     if (&process_external_command($command, 0 , 'email')) {
#                    if (run_voice_cmd $command) {
                         speak "Running email command: $command";
                         $results = "Command was run: $command";
                     }
                     else {
                         speak "Email command not found: $command";
                         $results = "Command not found: $command";
                     }
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
#   unlink $file;
}

