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
from CPAN (the activestate version are too old as of 9/2001):  
  Net::Jabber
  XML::Stream


=cut


$v_jabber_test = new  Voice_Cmd 'Send an jabber test message';
$v_jabber_test-> set_info('Send a test message to the default Jabber address');

net_jabber_send(text => "Stock summary\n  $Save{stock_data1}\n  $Save{stock_data2}",
                subject => "Stock summary for $Time_Date") if said $v_jabber_test;

                                # Send email summary once a day at noon
#net_jabber_send(text => "Internet mail received at $Time_Now", 
#                file => "$config_parms{data_dir}/get_email2.txt") if time_cron '04 12 * * 1-5';



# Uncomment this to have all speech sent to jabber
#&Speak_pre_add_hook(\&speak_to_jabber) if $Reload;

sub speak_to_jabber {
    my %parms = @_;
    return if $parms{no_jabber};
    net_jabber_send(text => $parms{text});
}

