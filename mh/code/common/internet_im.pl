# Category=Internet

#@ This module allows MisterHouse to connect to AOL Instant Messenger,
#@ MSN Messenger, and/or Jabber. Once connected, you can type any
#@ normal mh commands.  You can also type
#@  find: xyz to search for command xyz, or
#@  log: xyz to start sending log data with filter xyz.
#@  Example filters are print, speak, play, speak|play, all, and stop (to stop).


=begin comment

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

Jabber is an open, XML based protocol for instant messaging.
You can get free IDs and client for various platforms at
  http://jabbercentral.com or http://www.jabber.com . 

Jabber requires perl 5.6+ (for Unicode support) and these modules from CPAN:
  Net::Jabber
  XML::Stream

If on Windows, you can get these from ActiveState with these commands:

 cd /perl/bin
 perl ppm.bat install Net-Jabber
 perl ppm.bat install XML-Stream

=cut

$v_im_test = new  Voice_Cmd 'Send a [AOL,MSN,jabber] test message';
$v_im_test-> set_info('Send a test message to the default AOL, MSN, or jabber address');

if ($state = said $v_im_test) {
    my $msg = "MisterHouse uptime: $Tk_objects{label_uptime_cpu}";
    net_im_send(text => $msg, pgm => $state);
}

$v_im_signon = new Voice_Cmd 'Connect to [AOL,MSN,jabber]';
$v_im_signon-> set_info('Disconnect, then re-Connect to the specified im servers');
if ($state = said $v_im_signon) {
    &net_im_signoff($state);
    &net_im_signon(undef, undef, $state);
}

$v_im_signoff = new Voice_Cmd 'Disconnect from [AOL,MSN,jabber]';
$v_im_signoff-> set_info('Disconnect from the specified im servers');
if ($state = said $v_im_signoff) {
    &net_im_signoff($state);
}


$v_im_logdata1 = new  Voice_Cmd 'Start sending log data to [AOL,MSN,jabber]';
$v_im_logdata1-> set_info('Start sending mh print_log and speak data to the default im address');
$v_im_logdata2 = new  Voice_Cmd  'Stop sending log data to [AOL,MSN,jabber]';

$log_to_im_list{"$state default"} = 'all' if $state = said $v_im_logdata1;
delete $log_to_im_list{"$state default"}  if $state = said $v_im_logdata2;


                                # Reload hooks and mh.ini parms on reload
my %im_data;
if ($Reload) {
    &AOLim_Message_add_hook  (\&im_message);
    &MSNim_Message_add_hook  (\&im_message);
    &Jabber_Message_add_hook (\&im_message);

    &AOLim_Status_add_hook   (\&im_status);
    &MSNim_Status_add_hook   (\&im_status);
    &Jabber_Presence_add_hook(\&im_status);

    &Log_add_hook(\&im_log);

    for my $user (split /[,]+/, $config_parms{password_allow_im}) {
        $user =~ s/^ +//; $user =~ s/ +$//;  # Drop leading/trailing blanks
        $im_data{password_allow}{$user}++;
        print "Setting im password_allow user: $user.\n" if $main::config_parms{debug} eq 'IM';
    }
}

                                # Code all the various code hooks
use vars '%log_to_im_list';
sub im_log {
    my ($log_source, $text, %parms) = @_;
    return if $parms{no_im} or !$text;
    $text = "$log_source: $text";
    while (my($to, $filter) = each %log_to_im_list) {
#       print "db im_log to=$to filter=$filter s=$log_source text=$text\n";
        next unless $filter eq 'all' or $text =~ /$filter/;
        my ($pgm, $user) = $to =~ /(\S+) ?(.*)/;
        net_im_send(text => $text, pgm => $pgm, to => $user);
    }
}

sub im_status {
    my ($user, $status, $status_old, $pgm) = @_;
    print_log "IM: pgm=$pgm status $user changed from $status_old to $status";
}

sub im_message {
    my ($from, $text, $pgm) = @_;

    my ($ref) = &Voice_Cmd::voice_item_by_text(lc($text));
    my $authority = $ref->get_authority if $ref;
    $authority = $Password_Allow{$text} unless $authority;

    print "IM: RUN a=$authority,$im_data{password_allow}{$from} from=$from text=$text\n"  if $main::config_parms{debug} eq 'IM';
    return if $text =~ /^i\'m away(.+)/i;

    my $msg;
    if ($authority or $im_data{password_allow}{$from}) {
        if ($text =~ /^help/) {
            $msg  = "Type any of the following:\n";
            $msg .= "  find: xyz  => finds commands that match xyz\n";
            $msg .= "  log:  xyz  => xyz is a filter of what to log.  Can print, speak, play, speak|play, all, and stop\n";
            $msg .= "  any valid MisterHouse voice command(e.g. What time is it)\n";
        }
        elsif ($text =~ /^find:(.+)/) {
            my @cmds = list_voice_cmds_match $1;
            $msg = "Found " . scalar(@cmds) . " commands that matched $1:\n  ";
            $msg .= join("\n  ", @cmds);
        }
        elsif ($text =~ /^log: (.+)$/i) {
            if (lc $1 eq 'stop') {
                delete $log_to_im_list{"$pgm $from"};
            }
            else {
                $log_to_im_list{"$pgm $from"} = lc $1;
            }
            print_log "IM: logging $1 to $pgm for $from";
        }
#       elsif (&run_voice_cmd($text, undef, 'msnim')) {
        elsif (&process_external_command($text, 1, 'im')) {
#           $msg = "Command was run";
            $im_data{loop_count} = $Loop_Count + 4; # Give us 2 passes to wait for any resulting speech
#           print "dbx1 lc=$Loop_Count\n";
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

    &net_im_send(pgm => $pgm, to => $from, text => $msg);
}

                                # Show the reponse the the previous command
if ($im_data{loop_count} and $im_data{loop_count} == $Loop_Count) {
    my $last_response = &last_response;
    $last_response = 'No response' unless $last_response;
    $last_response = substr $last_response, 0, 500; # im clients are wimpy
    &net_im_send(pgm => $im_data{pgm}, to => $im_data{from}, text => "$Last_Response: $last_response");
}
