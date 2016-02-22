
=begin comment

From Craig Schaeffer on 03/2001

I was making quite a few changes to my home page (ISP not mh). This is the page
that is pushed by mh via internet_ip_update.pl  I decided that this script
needed to check for changes to the file and push it when detected. The original
script only pushed it if the IP address changed. I also added a new mh tag:
<$FileTime> that expands to the modified time of the file. Here are the
relevant bits:

=cut

$f_internet_ip_update =
  new File_Item("$config_parms{data_dir}/web/internet_ip_update.html");
set_watch $f_internet_ip_update if $Reload;
$v_send_ip_address1 = new Voice_Cmd('Send ip address to the web page');
if ( said $v_send_ip_address1) {

    if (net_connect_check) {

        unless ( $config_parms{net_www_server} ) {
            speak "No I P update info specified in mh.ini";
        }

        my $ip_address = get_derived_ip_address;
        $Save{ip_address_web} = ''
          if changed $f_internet_ip_update;    #force update if file changed

        if ( $Save{ip_address_web} eq $ip_address ) {
            print_log "IP web address current";
        }
        else {
            $Save{ip_address_web} = $ip_address;
            set_watch $f_internet_ip_update;

            if ( $config_parms{net_www_server} ) {

                my $file = name $f_internet_ip_update;

                if ( my $data = file_read($file) ) {

                    my $DateTime = time_date_stamp(2);
                    my $FileTime = time_date_stamp( 2, $file );
                    $data =~ s/<\$FileTime>/$FileTime/g;
                    $data =~ s/<\$DateTime>/$DateTime/g;
                    $data =~ s/NOT.ON.LINE.NOW/$ip_address/g;

                    file_write( "$file.ftped", $data );

                    print_log "Connecting to web server for ftp upload";
                    my $status = net_ftp(
                        command     => "put",
                        file        => "$file.ftped",
                        file_remote => "index.html"
                    );
                    print_log "IP upload $status";
                    $Save{ip_address_web} = '' unless $status =~ /success/;
                }
            }
        }
    }
    else {
        speak "Sorry, you are not logged onto the net";
    }
}

