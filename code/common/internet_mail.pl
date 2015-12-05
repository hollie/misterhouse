# Category=Internet

# $Date$
# $Revision$

#@ This code will periodically scan and announce when you receive new email.
#@ Messages will not be deleted from the server.
#@ This code also has some test examples for sending email.

#@ <p>Point to your accounts with mh.ini net_mail_account* parms.
#@ You can customize the parms to have other accounts besides the
#@ _account_1_ settings.
#@ For example you can replace the '_account_1_' string with '_my_home_email_'.
#@ It's a way to get MH to announce 'my home email has 3 new messages from ...'
#@ rather than the generic 'account 1 has 3 new messages from ...'.

#@ <p>The config param net_mail_scan_timeout_cycles prevents the process item
#@ being killed if it didn't complete within a scan interval.

#@ <p><a href="/email">Check here</a> after you have enabled and configured
#@ this script to see your email messages.

# noloop=start

# Example on how to send an email command
# - This string can be in either the subject or the body of the email
#      Subject line is:  command:x y z  code:xyz
$v_send_email_test =
  new Voice_Cmd('Send test e mail [1,2,3,4,5,6,7,8,9,10,11,12]');
$v_send_email_test->set_info('Send commands to test remote email commands');

$v_cell_phone_test = new Voice_Cmd 'Send test e mail to the cell phone';
$v_cell_phone_test->set_info("Send a test message to the cell phone");

$p_get_email = new Process_Item;

$v_recent_email = new Voice_Cmd('[Check for,List new] e mail');
$v_recent_email->set_info('Download and summarize new email headers');

# List or read unread email
$v_unread_email = new Voice_Cmd('[List,Read] unread e mail');
$v_unread_email->set_info(
    'Summarize unread email headers and optionally call Outlook to read the mail'
);

my $get_email_scan_file      = "$config_parms{data_dir}/get_email.scan";
my $get_email_timeout_cycles = 0;
$get_email_timeout_cycles = $config_parms{net_mail_scan_timeout_cycles}
  if $config_parms{net_mail_scan_timeout_cycles};
my $get_email_timeout_current = 0;

#$email_flag = new Generic_Item;

#tk_mlabel($email_flag, 'email flag');   ... this quit working in 2.88.
# Tk does not like the Generic_Item Tie update

# noloop=stop

&tk_label_new( 3, \$Save{email_flag} );

if ( said $v_send_email_test) {
    my $state = $v_send_email_test->{state};
    if (&net_connect_check) {

        # Use to => 'user@xyz.com', or default to your own address
        # (from net_mail_account_address in mh.ini)
        &net_mail_send(
            subject => "test 1",
            text    => "Test email 1 sent at $Time_Date",
            debug   => 1
        ) if $state == 1;

        # Send a command in the subject
        &net_mail_send(
            subject => "command:What time is it  code:"
              . $config_parms{net_mail_command_code},
            text => "I have been running for "
              . &time_diff( $Time_Startup_time, time )
        ) if $state == 2;

        # Send a command in the body
        &net_mail_send(
            subject => "test command in body of text",
            text    => "command:get this weeks new dvds  \ncode:"
              . $config_parms{net_mail_command_code}
        ) if $state == 3;

        # Send attachements of different types
        #  - Note mime parm is optional if file ends with that extension
        &net_mail_send(
            subject => 'test an html attachement',
            baseref => "localhost:$config_parms{http_port}",
            file    => '../web/mh4/widgets.html',
            mime    => 'html'
        ) if $state == 4;

        &net_mail_send(
            subject => 'test a zip file attachement',
            file    => 'c:/temp/test1.zip'
        ) if $state == 5;

        &net_mail_send(
            subject => 'test a tar.gz file attachement',
            file    => 'c:/temp/test.tar.gz',
            mime    => 'bin'
        ) if $state == 6;

        &net_mail_send(
            subject => 'test a gif file attachement',
            file    => '../web/graphics/goofy.gif'
        ) if $state == 7;

        &net_mail_send(
            subject => 'test a txt file',
            file    => '../docs/faq.txt'
        ) if $state == 8;

        &net_mail_send(
            subject => 'test an html file',
            file    => '../docs/faq.html'
        ) if $state == 9;

        # Test a request file via email
        &net_mail_send(
            subject => "command:request $config_parms{caller_id_file}  code:"
              . $config_parms{net_mail_command_code} )
          if $state == 10;

        &net_mail_send(
            subject => "command:set \$camera_light TOGGLE code:
          $config_parms{net_mail_command_code}"
        ) if $state == 11;

        run 'send_mail -subject "test" -text "Test background send_mail"'
          if $state == 12;

        $v_send_email_test->respond("app=email Test message has been sent.");
    }
    else {
        $v_send_email_test->respond(
            "app=email I am not logged on to the internet, so can't send mail."
        );
    }
}

if ( said $v_cell_phone_test) {
    net_mail_send
      to      => $config_parms{cell_phone},
      subject => 'MisterHouse test',
      text    => "I sent this at $Time_Now";
    $v_cell_phone_test->respond("app=email Test email sent to cell phone");
}

# Check for recent email since last received by mail program
# Do it with a get_email process, so mh will not pause

#&tk_radiobutton('Check email', \$Save{email_check}, ['no', 'yes']);

# *** Should be a trigger instead of config parm

if (
    said $v_recent_email
    or (    $Save{email_check} ne 'no'
        and new_minute $config_parms{net_mail_scan_interval}
        and &net_connect_check )
  )
{
    $v_recent_email->respond('Checking email...') if said $v_recent_email;
    set $p_get_email 'get_email -quiet';
    set $p_get_email 'get_email -debug' if $Debug{email};

    # New functionality added, if config_param exists, then wait x cycles
    # before blindly killing process
    if ( ( !($get_email_timeout_cycles) ) or ( done $p_get_email) ) {
        $get_email_timeout_current = 0;
        start $p_get_email;
    }
    else {
        if ( $get_email_timeout_cycles == $get_email_timeout_current ) {
            print_log
              "Internet_mail: Timeout expired getting email, killing process.";
            $get_email_timeout_current = 0;
            start $p_get_email;
        }
        else {
            $get_email_timeout_current++;
            my $cycles_left =
              $get_email_timeout_cycles - $get_email_timeout_current;
            print_log "Internet_mail: Request to check mail but process still"
              . " running. $cycles_left scan intervals remain";
        }
    }
}

if ( $p_get_email->{done_now} ) {
    my $text;
    my $data = file_read "$config_parms{data_dir}/get_email.flag";

    #    set $email_flag $data; # *** Missing?
    $Save{email_flag} = $data;    # Used in web/bin/status_line.pl

    # Turn on an 'new mail indicator'
    #  - could be modified for different lights for different accounts.
    #   set $new_mail_light ($data =~ /[1-9]/) ? ON : OFF);

    # Once an hour, summarize all email, otherwise just new mail
    if ( $Minute < 10 ) {
        $text = &unread_mail();
    }
    else {
        $text = &new_mail();
    }
    &scan_subjects($get_email_scan_file);

    # *** Change to respond once logic is untangled (needs trigger)
    # *** As of now, there is no telling what called this.

    speak "app=email $text" if $text;

}

# Delete file after the done_now pass (gives other code
# like news_email_breaking.pl a chance to scan it)
elsif ( $p_get_email->{done} and -e $get_email_scan_file ) {
    unlink $get_email_scan_file;
}

if ( $state = said $v_unread_email) {
    if ( $state eq 'Read' ) {
        $v_unread_email->respond("app=email Loading email client...");

        # *** Look up path in registry!  This is clearly Windows-only too...

        if (
            my $window = &sendkeys_find_window(
                'Outlook',
                'C:\Program Files\Microsoft Office\Office\OUTLOOK.EXE'
            )
          )
        {
            my $keys = '\\alt\\te\\ret\\';    # For Outlook
            &SendKeys( $window, $keys, 1, 500 );
        }
    }
    else {
        my $text = unread_mail();
        $v_unread_email->respond("app=email $text");
    }
}

sub new_mail {
    my $text = file_read "$config_parms{data_dir}/get_email.txt";
    chomp $text;
    return $text;
}

sub unread_mail {
    my $text = file_read "$config_parms{data_dir}/get_email2.txt";
    chomp $text;
    return $text;
}

# Allow for email send commands, IF the secret command code matches
#  - someday we need to allow for better, more secure mail commands
sub scan_subjects {
    my ($file) = @_;
    return unless -e $file;
    for my $line ( file_read $file) {
        my ( $from, $to, $subject_body ) =
          $line =~ /From: *(.+) To: *(.+) Subject: *(.*)/;
        if ( my ( $command, $code ) =
            $subject_body =~ /command:(.+?)\s+code:(\S+)/i )
        {
            my $results;
            if (    $config_parms{net_mail_command_code}
                and $config_parms{net_mail_command_code} eq $code )
            {
                if ( my ($file_request) = $command =~ /request_file\s(.+)/i ) {
                    $file_request =~ s|\\|\/|g;
                    if ( -e $file_request ) {
                        speak "Sending email request file: $file_request";
                        $results = "Sending $file_request";
                        &net_mail_send(
                            to      => $from,
                            subject => $results,
                            file    => $file_request,
                            mime    => 'bin'
                        );
                    }
                    else {
                        speak "Email requested file not found:$file_request";
                        $results = "$file_request not found";
                    }
                }
                else {
                    # The mh respond_email function will mail back the results
                    if (
                        &process_external_command(
                            $command,
                            1,
                            "email [$from]",
                            "email to='$from' subject='Results for: $command'"
                        )
                      )
                    {
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
                $results = "Command not authorized: $command code:$code";
            }
            logit( "$config_parms{data_dir}/logs/email_command.log",
                "From:$from  " . $results );
            &net_mail_send( to => $from, subject => $results );
        }
    }

    #   unlink $file;
}

sub email_message_window_closing {

}

sub email_message_window_saving {
    my $p_win = shift;

    my $msg = $$p_win{t1}->get( '0.0', 'end' );
    my $re = $$p_win{re}->get;
    chomp $msg;    # stupid tk entry widget appends a CR

    if ($msg) {
        &net_mail_send( text => $msg, subject => $re, to => undef );
        return 0;
    }
    else {
        display('app=email time=0 Enter a message to send.');
        return 1;
    }
}

# *** Change OK to Send and add "To" field

sub open_email_message_window {
    my %parms = @_;
    $parms{title}       = "Send Message";
    $parms{app}         = "email";
    $parms{text}        = "Dear,";
    $parms{window_name} = "message";
    $parms{buttons}     = 2;
    $parms{help} = 'Enter a message to send to the default email account.';
    my $w_window = &load_child_window(%parms);

    if ( defined $w_window ) {
        unless ( $w_window->{activated} ) {
            $w_window->{MW}{top_frame}->Label( -text => 'Re:' )
              ->pack(qw/-side left/);
            $w_window->{re} = $w_window->{MW}{top_frame}->Entry()
              ->pack(qw/-expand yes -fill both -side left/);
            $w_window->activate();
            $w_window->{re}->focus();
        }
        return $w_window;
    }
}

#&register_echo('email');
&register_custom_window( 'email', 'message', 1 ) if $Reload;
