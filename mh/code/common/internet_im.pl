# Category=Internet

#@ This module allows MisterHouse to connect to AOL Instant Messenger,
#@ MSN Messenger, and/or Jabber. Once connected, you can send commands
#@ and get responses, etc.


=begin comment

Send messages to a AOL, MSN, and Jabber Instant Messanger clients

Set these mh.ini parms:

   net_aim_name=     
   net_aim=password= 
   net_aim_name_send=

   net_msn_name=     
   net_msn_password= 
   net_msn_name_send=

   net_jabber_name=     
   net_jabber_password= 
   net_jabber_server=     (e.g. jabber.com)
   net_jabber_resource=   (optional)
   net_jabber_name_send=

The code libs for AOL and MSN are included in mh. 

Jabber requires perl 5.6+ (for Unicode support) and these modules from CPAN:
  Net::Jabber
  XML::Stream

If on Windows, you can get these from ActiveState with these commands:

 cd /perl/bin
 perl ppm.bat install Net-Jabber
 perl ppm.bat install XML-Stream

Jabber is an open, XML based protocol for instant messaging.
You can get free IDs and client for various platforms at
  http://jabbercentral.com or http://www.jabber.com . 

=cut

$v_im_test = new  Voice_Cmd 'Send an [AOL,MSN,jabber] test message';
$v_im_test-> set_info('Send a test message to the default AOL, MSN, or jabber address');

if ($state = said $v_im_test) {
    my $msg = "MisterHouse uptime: $Tk_objects{label_uptime_cpu}";
    net_im_send    (text => $msg) if $state eq 'AOL';
    net_msn_send   (text => $msg) if $state eq 'MSN';
    net_jabber_send(text => $msg) if $state eq 'jabber';
}

                                # Send email summary once a day at noon
net_msn_send(text => "Internet mail received at $Time_Now", 
            file => "$config_parms{data_dir}/get_email2.txt") if time_cron '05 12 * * 1-5';

                                # Connect and disconnect to various IM servers
$v_im_signon = new Voice_Cmd 'Connect to [AOL,MSN,jabber]';
$v_im_signon-> set_info('Connect to the AOL, MSN, or Jabber');
if ($state = said $v_im_signon) {
    &net_im_signoff       if $state eq 'AOL';
    &net_msn_signoff      if $state eq 'MSN';
    &net_jabber_signoff   if $state eq 'jabber';

    &net_im_signon        if $state eq 'AOL';
    &net_msn_signon       if $state eq 'MSN';
    &net_jabber_signon    if $state eq 'jabber';
}

$v_im_signoff = new Voice_Cmd 'Disconnect from [AOL,MSN,jabber]';
$v_im_signoff-> set_info('Disconnect from the configured jabber server');
if ($state = said $v_im_signoff) {
    &net_im_signoff       if $state eq 'AOL';
    &net_msn_signoff      if $state eq 'MSN';
    &net_jabber_signoff   if $state eq 'jabber';
}



sub im_status {
    my ($user, $status, $status_old, $pgm) = @_;
    print_log "IM: pgm=$pgm status $user changed from $status_old to $status";
}


my %im_data;

if ($Reload) {
    &AOLim_Message_add_hook  (\&im_message);
    &MSNim_Message_add_hook  (\&im_message);
    &Jabber_Message_add_hook (\&im_message);

    &AOLim_Status_add_hook   (\&im_status);
    &MSNim_Status_add_hook   (\&im_status);
    &Jabber_Presence_add_hook(\&im_status);

    for my $user (split /[,]+/, $config_parms{password_allow_im}) {
        $user =~ s/^ +//; $user =~ s/ +$//;  # Drop leading/trailing blanks
        $im_data{password_allow}{$user}++;
        print "Setting im password_allow user: $user.\n" if $main::config_parms{debug} eq 'IM';
    }
}

sub im_message {
    my ($from, $text, $pgm) = @_;

    my ($ref) = &Voice_Cmd::voice_item_by_text(lc($text));
    my $authority = $ref->get_authority if $ref;
    $authority = $Password_Allow{$text} unless $authority;

    print "IM: RUN a=$authority,$im_data{password_allow}{$from} from=$from text=$text\n"  if $main::config_parms{debug} eq 'IM';
    return if $text =~ /^i\'m away(.+)/i;

    my $pgm2 = lc $pgm;
    $pgm2 = 'aim' if $pgm2 eq 'aol';

    my $msg;
    if ($text =~ /^find:(.+)/) {
        my @cmds = list_voice_cmds_match $1;
        $msg = "Found " . scalar(@cmds) . " commands that matched $1:\n  ";
        $msg .= join("\n  ", @cmds);
    }
    elsif ($authority or $im_data{password_allow}{$from}) {
#       if (&run_voice_cmd($text, undef, 'msnim')) {
        if (&process_external_command($text, 1, 'im')) {
#           $msg = "Command was run";
            $im_data{loop_count} = $Loop_Count + 4; # Give us 2 passes to wait for any resulting speech
            print "dbx1 lc=$Loop_Count\n";
            $im_data{pgm}  = $pgm;
            $im_data{from} = $from;
            $Last_Response = '';
        }
        else {
            $msg = "Command not found";
        }
    }
    else {
        $msg = "Unauthorized access for command";
    }
    print_log "IM: pgm=$pgm, to=$from, text=$text, response=$msg";

    my $time = sprintf("%02d:%02d:%02d", $Hour, $Minute, $Second);
    display text => "$from ($time:$main::Second): $text\n", time => 0, title => $pgm, 
      window_name => $pgm, append => 'bottom';

    &send_im($pgm, $from, $msg);
}

sub send_im {
    my ($pgm, $to, $text) = @_;
    net_im_send    (text => $text, to => $to) if $pgm eq 'AOL';
    net_msn_send   (text => $text, to => $to) if $pgm eq 'MSN';
    net_jabber_send(text => $text, to => $to) if $pgm eq 'jabber';
}

                                # Show the reponse the the previous command
if ($im_data{loop_count} and $im_data{loop_count} == $Loop_Count) {
    my $last_response = &last_response;
    $last_response = 'No response' unless $last_response;
    $last_response = substr $last_response, 0, 500; # im clients are wimpy
    send_im($im_data{pgm}, $im_data{from}, "$Last_Response: $last_response");
}

# This code will enable speak and print_log data to be sent.

$v_im_logdata1 = new  Voice_Cmd 'Start sending log data to [AOL,MSN,jabber]';
$v_im_logdata2 = new  Voice_Cmd  'Stop sending log data to [AOL,MSN,jabber]';
$v_im_logdata1-> set_info('Send all speak and print_log data to the default AOL, MSN, or jabber address');

$state = said $v_im_logdata1;
&Log_add_hook(\&speak_to_aim, 1)                if $state eq 'AOL';
&Log_add_hook(\&speak_to_msn, 1)                if $state eq 'MSN';
&Jabber_Presence_add_hook(\&handle_presence, 1) if $state eq 'jabber';

$state = said $v_im_logdata2;
&Log_drop_hook(\&speak_to_aim)                if $state eq 'AOL';
&Log_drop_hook(\&speak_to_msn)                if $state eq 'MSN';
&Jabber_Presence_drop_hook(\&handle_presence) if $state eq 'jabber';
#&net_jabber_signon if $Startup;

sub speak_to_aim {
    my ($log_source, $text, %parms) = @_;
    return if $parms{no_im};
    net_im_send(text => "$log_source: $text");
}
sub speak_to_msn {
    my ($log_source, $text, %parms) = @_;
    return if $parms{no_im};
    net_msn_send(text => "$log_source: $text");
}
sub speak_to_jabber {
    my ($log_source, $text, %parms) = @_;
    return if $parms{no_im};
    net_jabber_send(text => "$log_source: $text");
}


# Be a bit smarter with Jabber and add the log hook only when presence detected

my $send_to_jabber = 0;
sub handle_presence {
    my $sid = shift;
    my $presence = shift;

    my $from   = $presence->GetFrom();
    my $type   = $presence->GetType();
    my $status = $presence->GetStatus();

    if ($from =~ /$main::config_parms{net_jabber_name_send}/) {
        print "got presence update for MH jabber target $from\n";
        
        if ($status eq "Disconnected") {
            print "$from disconnected; removing speak_to_jabber hook\n";
            &Log_drop_hook(\&speak_to_jabber);
            $send_to_jabber = 0;
        }
        else {
            if (!$send_to_jabber) {
                print "$from connected; adding speak_to_jabber hook\n";
                &Log_add_hook(\&speak_to_jabber, 'jabber');
                $send_to_jabber = 1;

        # call some interesting routines.
                &run_voice_cmd('what is your up time', undef, 'jabber');
#               &run_voice_cmd('read internet weather');
#               &run_voice_cmd('what favorite tv shows are on today');
            }
        }
    }
}
