# Category = Audrey

#@ This module allows MisterHouse to capture and send all speech and played
#@ wav files to an Audrey internet appliance. See the detailed instructions
#@ in the script for Audrey set-up information.

=begin comment

audreyspeak.pl

 1.0 Original version by Tim Doyle <tim@greenscourt.com> - 9/10/2002

This script allows MisterHouse to capture and send speech and played
wav files to an Audrey unit. The original version was based upon Keith 
Webb's work outlined in his email of 12/23/01.

You must make certain modifications to your Audrey, as follows:

- Update the software and obtain root shell access capabilities (this
  should be available by using Bruce's CF card image or by following
  instructions available on the internet.)

- Open the Audrey's web server to outside http requests
  1) Start the "Root Shell"
  2) type: cd /config
  3) type: cp rm-apps rm-apps.copy
  4) type: vi rm-apps
     You'll be in the editor, editing the "rm-apps" file
     About the 14th line down is "rb,/kojak/kojak-slinger, -c -e -s -i 127.1"
     You need to delete the "-i 127.1" from the line.
     To do this, place the cursor under the space right after the "-s"
     Type the "x" key to start deleting from the line.
     The line should end up looking like this:
     "rb,/kojak/kojak-slinger, -c -e -s"
     If you need to start over type a colon to get to the vi command line
     At the colon prompt type "q!" and hit "enter" (this quits without saving)
     If it looks good then at the colon prompt type "wq" to save changes
     Now restart the Audrey by unplugging it, waiting 30 seconds and 
     plugging it back in.

- Install playsound_noph and it's DLL
  1) Grab the zip file from http://www.planetwebb.com/audrey/
  2) Place playsound_noph    on the Audrey in /nto/photon/bin/ 
  3) Place soundfile_noph.so on the Audrey in /nto/photon/dll/

- Install mhspeak.shtml on the Audrey
  1) Start the "Root Shell"
  2) type: cd /data/XML
  3) type: ftp blah.com mhspeak.shtml

     The MHSPEAK.SHTML file placed on the Audrey should contain the following:

     <html>
     <head>
     <title>Shell</title>
     </head>
     <body>
     <!--#config cmdecho="OFF" -->
     <!--#exec cmd="playsound_noph $QUERY_STRING &" -->
     </body>
     </html>

- Set your Audrey's IP address in mh.private.ini
   Audrey_IPs=Kitchen-192.168.1.89,Bedroom-192.168.1.99


=cut

#Tell MH to call our routine each time something is spoken
&Speak_post_add_hook(\&speak_to_Audrey) if $Reload;

#MH just said something. Generate the same thing to our file (which is monitored below)
sub speak_to_Audrey {
    my %parms = @_;
    $parms{"to_file"}="$config_parms{html_dir}/toAudrey.wav";
    print "Saving speech $parms{text} to $config_parms{html_dir}/toAudrey.wav\n";
    &Voice_Text::speak_text(%parms);
}

#Tell MH to call our routine each time a wav file is played
&Play_post_add_hook(\&play_to_audrey) if $Reload;

#MH just played a wav file. Copy it to our file (which is monitored below)
sub play_to_audrey {
    my %parms = @_;
    copy $parms{fileplayed}, "$config_parms{html_dir}/toAudrey.wav";
}

#Check our file. If it has changed, tell each Audrey to come and get it!
if (file_changed "$config_parms{html_dir}/toAudrey.wav") {
    my $MHWeb = get_ip_address . ":" . $config_parms{http_port};
    for my $ip (split ',', $config_parms{Audrey_IPs}) {
        $ip =~ s/\S+\-//;
        run "get_url -quiet http://$ip/mhspeak.shtml?http://$MHWeb/toAudrey.wav /dev/null";
    }
}

#if ($Reload) {
#    print "****************************************\n";
#    my $MHWeb = get_ip_address . ":" . $config_parms{http_port};
#    for my $ip (split ',', $config_parms{Audrey_IPs}) {
#        my $html = get "http://$ip/mhspeak.shtml?http://$MHWeb/dummy.wav";
#   run "get_url http://$ip/mhspeak.shtml?http://$MHWeb/dummy2.wav";
#my $html = '';
#        print "located from $ip $html";
#    }
#}
