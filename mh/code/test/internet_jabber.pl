# Category=Internet

=begin comment

Send messages to a instant messaging Jabber client
Jabber is a new, open, XML based protocol for instant messaging.
You can get free IDs and client for various platforms at
http://jabbercentral.com or http://www.jabber.com . 
We can also code mh events to respond to incoming Jabber messages.  
Currently, it will simply pop up a tk display window.

Set these mh.ini parms:
  net_jabber_name=     
  net_jabber_password= 
  net_jabber_server=     (e.g. jabber.com)
  net_jabber_resource=   (optional)
  net_jabber_name_send=

This code requires perl 5.6+ (for Unicode support) and these modules 
from CPAN:
  Net::Jabber
  XML::Stream

If on Windows, you can get these from ActiveState with these commands:

 cd /perl/bin
 perl ppm.bat install Net-Jabber


=cut

return unless $config_parms{net_jabber_name};

$v_jabber_test = new  Voice_Cmd 'Send an jabber test message';
$v_jabber_test-> set_info('Send a test message to the default Jabber address');

net_jabber_send(text => "Stock summary\n  $Save{stock_data1}\n  $Save{stock_data2}",
                subject => "Stock summary for $Time_Date") if said $v_jabber_test;

                                # Send email summary once a day at noon
#net_jabber_send(text => "Internet mail received at $Time_Now", 
#                file => "$config_parms{data_dir}/get_email2.txt") if time_cron '04 12 * * 1-5';


$v_jabber_connect = new Voice_Cmd 'Connect to jabber';
$v_jabber_connect-> set_info('Connect to the configured jabber server');
&net_jabber_login if said $v_jabber_connect;

sub net_jabber_login
{
    my $from     = $main::config_parms{net_jabber_name};
    my $password = $main::config_parms{net_jabber_password};
    my $server   = $main::config_parms{net_jabber_server};
    my $resource = $main::config_parms{net_jabber_resource};

    &main::net_jabber_signon($from, $password, $server, $resource);
}


$v_jabber_signoff = new Voice_Cmd 'Disconnect from jabber';
$v_jabber_signoff-> set_info('Disconnect from the configured jabber server');
net_jabber_signoff() if said $v_jabber_signoff;


# Uncomment this to have all speech sent to jabber
#&Speak_pre_add_hook(\&speak_to_jabber) if $Reload;
#my $send_to_jabber = 1;
my $send_to_jabber = 0;

sub speak_to_jabber {
#   my %parms = @_;
    my ($from, $text, %parms) = @_;
    return if $parms{no_jabber};
#   net_jabber_send(text => $parms{text}, file => $parms{file});
    net_jabber_send(text => $text);
}


&Jabber_Presence_add_hook(\&handle_presence) if $Reload;
&Jabber_Message_add_hook(\&handle_message)   if $Reload;
&net_jabber_login if $Startup;

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
            &Log_drop_hook(\&speak_o_jabber);
            $send_to_jabber = 0;
        }
        else {
            if (!$send_to_jabber) {
                print "$from connected; adding speak_to_jabber hook\n";
                &Log_add_hook(\&speak_to_jabber);
                $send_to_jabber = 1;

        # call some interesting routines.
                &run_voice_cmd('what is your up time', undef, 'jabber');
#                &run_voice_cmd('read internet weather');
#                &run_voice_cmd('what favorite tv shows are on today');
            }
        }
    }
}


sub handle_message {
    my $sid = shift;
    my $message = shift;

    my $from     = $message->GetFrom();
    my $body     = $message->GetBody();

    my ($ref) = &Voice_Cmd::voice_item_by_text(lc($body));
    my $authority = $ref->get_authority if $ref;
    $authority = $Password_Allow{$body} unless $authority;

    print "jabber: RUN a=$Authorized,$authority body=$body\n" ; #if $main::config_parms{debug} eq 'jabber';

    if ($Authorized or $authority) {
        if (&run_voice_cmd($body, undef, 'jabber')) {
            print "ran voice command $body from jabber user $from\n";
        }
        else {
            my $msg = "command $body not found.";
            net_jabber_send(to => $from, text => $msg);
        }
    }
    else {
        my $msg = "unauthorized access.";
        net_jabber_send(to => $from, text => $msg);
    }
}
