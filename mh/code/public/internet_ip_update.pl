####################################################
#
# internet_ip_update.pl
#
# Author: Bruce Winter
#
# This file updates web pages and/or various dynamic
# ip address servers with your current IP address.
#
####################################################

# Category=Internet

                                # Example on how to update something on the internet with your dynamic ip address

                                # Periodically check to see if we are online.  If so, do auto-updates
if ($New_Minute and !($Minute % 5) and &net_connect_check) {
    run_voice_cmd 'Send ip address to the web page';
    run_voice_cmd 'Send ip address to the web servers';
}

$v_send_ip_address1 = new  Voice_Cmd('Send ip address to the web page');
if (said $v_send_ip_address1) {

    if (net_connect_check) {

        my $ip_address = get_ip_address;
        if ($Save{ip_address_web} eq $ip_address) {
            print_log "IP web address current";
        }
        else {
            $Save{ip_address_web} = $ip_address;
            my $file = "$config_parms{data_dir}/web/internet_ip_update.html";
            if (my $data = file_read($file)) {
                
                my $DateTime = time_date_stamp(2);
                $data =~ s/<\$DateTime>/$DateTime/g;
                $data =~ s/NOT.ON.LINE.NOW/$ip_address/g;
                
                file_write("$file.ftped", $data);
                
                print_log "Connecting to web server for ftp upload";
                my $status = net_ftp(file => "$file.ftped", file_remote => "online/Welcome.html");
                print_log "IP upload $status";
                
            }
        }
    }
    else {
        speak "Sorry, you are not logged onto the net";
    }

}

                                # Create/update a tk label that reflects the current address
&tk_label(\$Tk_objects{ip_address});
if ($New_Minute and %Tk_objects) {
#    unless ($Tk_objects{ip_address}) {
#        $Tk_objects{f2}->Label(-relief => 'sunken', -width => 22, -textvariable => \$Tk_objects{ip_address})->pack(-side => 'right'); 
#    }
    if (&net_connect_check) {
        $Tk_objects{ip_address} = "IP address: " . get_ip_address;
    }
    else {
        $Tk_objects{ip_address} = "Not Connected" ;
    }
}


$v_send_ip_address2 = new  Voice_Cmd('Send ip address to the web servers');
if (said $v_send_ip_address2) {

    if (net_connect_check) {

        unless ($config_parms{tzo_key} or $config_parms{dips_password}) {
            speak "No I P update info specified in mh.ini";
        }
        
        my $ip_address = get_ip_address;

        if ($Save{ip_address_server} eq $ip_address) {
            print_log "IP server address current";
        }
        else {
            $Save{ip_address_server} = $ip_address;

            if ($config_parms{dips_password}) {
                print_log "Updating DIPS with dynamic ip address of $ip_address";

                my $url = 'http://postmodem.com/dips-admin/update.cgi?';
                $url .= "pwd=$config_parms{dips_password}&ip=$ip_address&topic=Home_Automation";
                
                my $rc = get $url;
                if ($rc =~ /successfull/) {
#                   speak "DIPS updated";
                }
                elsif ($rc =~ /DIPSerror=(\S+)/) {
                    my $error = $1;
                    if ($error == 1) {
                        speak "Error, bad password";
                    }
                    elsif ($error == 2) {
                        speak "Topic too long";
                    }
                    elsif ($error == 3) {
                        speak "Invalid I P address";
                    }
                    else {
                        speak "Unknown error.  Returned data:\n$rc";
                    }
                }
                else {
                    speak "IP update failed to connect to DIPS";
                }
            }

            if ($config_parms{tzo_key}) {
                print_log "Updating tzo.com with dynamic ip address of $ip_address";

                my $url  = "http://cgi.tzo.com/webclient/signedon.html?";
                $url .= "TZOName=$config_parms{tzo_name}";
                $url .= "&Email=$config_parms{tzo_email}";
                $url .= "&TZOKey=$config_parms{tzo_key}&B1=Sign+On";
                
                my $rc = get $url;
                if ($rc =~ /successfull/) {
                    speak "T Z O updated" unless $Save{sleeping_parents};
                }
                elsif ($rc =~ /TZO Error/) {  #   TZO Error!  Invalid TZO Key
                    speak "Error, TZO key is in valid";
                }
                else {
                    speak "I P update failed to connect to tzo.com";
                }
            }
        }
    }

    else {
        speak "Sorry, you are not logged onto the net";
    }

}
