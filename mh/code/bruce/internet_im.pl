# Category=Internet
#
# Send messages to a AOL AIM client
# AIM info at:  http://www.aol.com/aim/faq/getstarted.html
#
# Set these mh.ini parms:
#   net_aim_name_send=
#   net_aim_name=     
#   net_aim_password= 



$v_aim_test = new  Voice_Cmd 'Send an AIM test message';
$v_aim_test-> set_info('Send a test message to the default AIM address');

net_im_send(text => "Stock summary\n  $Save{stock_data1}\n  $Save{stock_data2}") if said $v_aim_test;

                                # Send email summary once a day at noon
net_im_send(text => "Internet mail received at $Time_Now", 
            file => "$config_parms{data_dir}/get_email2.txt") if time_cron '05 12 * * 1-5';

