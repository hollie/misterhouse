# Category=Internet

#@ This code will periodically scan and announce when you 
#@ receive new email. This code also has some test examples for sending email.

#@ Point to your accounts with mh.ini net_mail_account* parms.
#@ You can customize the parms to have other accounts besides the _account_1_ settings.
#@ For example you can replace the '_account_1_' string with '_my_home_email_'.
#@ It's a nice way to get MH to announce 'my home email has 3 new messages from ...'
#@ rather than the gerneric 'account 1 has 3 new messages from ...'

                                # Example on how to send an email command
                                # - This string can be in either the subject or the body of the email
                                #      Subject line is:  command:x y z  code:xyz
$v_send_email_test = new  Voice_Cmd('Send test e mail [1,2,3,4,5,6,7,8,9,10,11]', 'Ok, will do');
$v_send_email_test-> set_info('Send commands to test remote email commands');
if ($state = said $v_send_email_test) {
    if (&net_connect_check) {
                                # Use to => 'user@xyz.com', or default to your own address (from net_mail_account_address in mh.ini)
        &net_mail_send(subject => "test 1", text => "Test email 1 sent at $Time_Date", 
#                      to => 'bruce@misterhouse.net ; winter@chartermi.net',
                       debug => 1) if $state == 1;

                                # Send a command in the subject
        &net_mail_send(subject => "command:What time is it   code:$config_parms{net_mail_command_code}",
                       text => "I have been running for " . &time_diff($Time_Startup_time, time)) if $state == 2;

                                # Send a command in the body
        &net_mail_send(subject => "test command in body of text",
                       text => "command:get this weeks new dvds  \ncode:$config_parms{net_mail_command_code}") if $state == 3;

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

        run 'send_mail -subject "test" -text "Test background send_mail"' if $state == 11;

        speak "Test message has been sent";
    }
    else {
        speak "Sorry, you are not currently logged on to the internet, so I can not send mail";
    }
}


$cell_phone_test = new Voice_Cmd 'Send test e mail to the cell phone';
$cell_phone_test-> set_info("Send a test message to the cell phone");

if (said $cell_phone_test) {
    speak "Test email sent to cell phone";
    net_mail_send to => $config_parms{cell_phone},
      subject => 'MisterHouse test',
      text    => "I sent this at $Time_Now";
}

                                # Check for recent email since last received by mail program
                                # Do it with a get_email process, so mh will not pause
#&tk_radiobutton('Check email', \$Save{email_check}, ['no', 'yes']);
$p_get_email = new Process_Item;
$v_recent_email = new  Voice_Cmd('{Check for,List new} e mail', 'Ok, hang on a second and I will check for new email');
$v_recent_email-> set_info('Download and summarize new email headers');
if (said $v_recent_email or ($Save{email_check} ne 'no' and !$Save{sleeping_parents} and
                             new_minute $config_parms{net_mail_scan_interval} and &net_connect_check)) { 
    set $p_get_email 'get_email -quiet';
    set $p_get_email 'get_email -debug' if $Debug{email};
    start $p_get_email;
}

$email_flag = new Generic_Item;
&tk_mlabel($email_flag, 'email flag');

my $get_email_scan_file = "$config_parms{data_dir}/get_email.scan";
if ($p_get_email->{done_now}) {
    my $data = file_read "$config_parms{data_dir}/get_email.flag";
    set $email_flag  $data;
    $Save{email_flag} = $data;  # Used in web/bin/status_line.pl

                                # Turn on an 'new mail indicator'
                                #  - could be modified for different lights for different accounts.
#   set $new_mail_light ($data =~ /[1-9]/) ? ON : OFF);

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

                                # List or read unread email
$v_unread_email = new  Voice_Cmd('[List,Read] unread e mail');
$v_unread_email-> set_info('Summarize unread email headers and optionally call Outlook to read the mail');
if ($state = said $v_unread_email) {
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
    speak "app=email $text" if $text;
}

sub speak_unread_mail {
    my $text = file_read "$config_parms{data_dir}/get_email2.txt";
    chomp $text;
    speak "app=email $text" if $text;
}

                                # Allow for email send commands, IF the secret command code matches 
                                #  - someday we need to allow for better, more secure mail commands
sub scan_subjects {
    my ($file) = @_;
    return unless -e $file;
    for my $line (file_read $file) {
        my ($from, $to, $subject_body) = $line =~ /From: *(.+) To: *(.+) Subject: *(.*)/;
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
                                  # The mh respond_email function will mail back the results
                     if (&process_external_command($command, 1, 'email', "email to=$from subject='Results for: $command'")) {
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

