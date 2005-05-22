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

   The first portion of the audrey ip address, for example,
   Kitchen and Bedroom in the above, can be used as the "room"
   parameter in any speak or play command.  For example,

   speak (rooms=> "Bedroom", mode=> "unmuted", text=> "hello in the bedroom");
   speak (rooms=> "Kitchen", mode=> "unmuted", text=> "hello in the kitchen");
   speak (rooms=> "all", mode=> "unmuted", text=> "hello everywhere");

=cut

#Tell MH to call our routine each time something is spoken
&Speak_pre_add_hook(\&speak_to_Audrey) if $Reload;

my ($audreyWrIndex, $audreyRdIndex, $audreyMaxIndex, @speakRooms);

if ($Startup or $Reload) {
  $audreyWrIndex = 0;
  $audreyRdIndex = 0;
  $audreyMaxIndex = 10;
}

#Check our play file. If it has changed, tell each Audrey to come and get it!
if ($New_Second && ($audreyRdIndex != $audreyWrIndex)) {
#   my $MHWeb = get_ip_address . ":" . $config_parms{http_port};
#    my $MHWeb = $Info{IPAddress_local} . ":" . $config_parms{http_port};
    my $speakFile = "/speakToAudrey$audreyRdIndex.wav";
    my $MHWeb = hostname() . ":" . $config_parms{http_port};
    for my $audrey (split ',', $config_parms{Audrey_IPs}) {
        $audrey =~ /(\S+)\-(\S+)/;
        my $room = $1;
        my $ip = $2;
        my $rooms = @speakRooms[$audreyRdIndex];
        for my $index (@$rooms) {
          lc $index;
          lc $room;
          if ($index eq $room) {
            run "get_url -quiet http://$ip/mhspeak.shtml?http://$MHWeb$speakFile /dev/null";
          }
        }
    }
    $audreyRdIndex++;
    $audreyRdIndex = 0 if ($audreyRdIndex >= $audreyMaxIndex);
}

#MH just said something. Generate the same thing to our file (which is monitored above)
sub speak_to_Audrey {
    my %parms = @_;
    return if $Save{mode} and ($Save{mode} eq 'mute' or $Save{mode} eq 'offline') and $parms{mode} !~ /unmute/i;
    my @rooms = split ',', lc $parms{rooms};
    if (lc $parms{rooms} =~ /all/) {
      @rooms = ();
      for my $audrey (split ',', $config_parms{Audrey_IPs}) {
        $audrey =~ /(\S+)\-(\S+)/;
        my $room = $1;
        my $ip = $2;
        push @rooms, $room;
      }
    } else {
      my @audreyRooms = ();
      for my $speakRoom (@rooms) {
        for my $audrey (split ',', $config_parms{Audrey_IPs}) {
          $audrey =~ /(\S+)\-(\S+)/;
          my $room = $1;
          my $ip = $2;
          if ($speakRoom eq $room) {
            push @audreyRooms, $room;
          }
        }
      }
      @rooms = @audreyRooms;
    }

    $parms{"to_file"} = $config_parms{html_dir} . "/speakToAudrey" . $audreyWrIndex . ".wav";
    @speakRooms[$audreyWrIndex] = \@rooms;
    $parms{rooms} = @rooms;
    if (@rooms > 0) {
      &Voice_Text::speak_text(%parms);
      $audreyWrIndex++;
      $audreyWrIndex = 0 if ($audreyWrIndex >= $audreyMaxIndex);
    }
}

#Tell MH to call our routine each time a wav file is played
&Play_pre_add_hook(\&play_to_audrey) if $Reload;

#MH just played a wav file. Copy it to our file (which is monitored above)
sub play_to_audrey {
    my %parms = @_;
    return if $Save{mode} and ($Save{mode} eq 'mute' or $Save{mode} eq 'offline') and $parms{mode} !~ /unmute/i;
    my @rooms = split ',', lc $parms{rooms};
    my @files = split(/[, ]/, $parms{file});
    for my $file (@files) {

      if (-e $file) {
      }
                          # Use from common dir only if it is not in the user sound_dir
                          #  - Can not test for -e in user sound_dir if we have a *.wav spec
      elsif ( -e "$config_parms{sound_dir_common}/$file" and
             !-e "$config_parms{sound_dir}/$file") {
          $file = "$config_parms{sound_dir_common}/$file";
      }
      else {
          $file = "$config_parms{sound_dir}/$file";
      }

      # If wildcarded file, build an array of all files and pick one
      if (!-e $file and $file =~ /\*/) {
          my @files_to_pick = glob $file;
          my $file_cnt = @files_to_pick;
          if ($file_cnt > 1) {
              $file = @files_to_pick[int(rand $file_cnt)];
#              print "Play picked file $file\n";
          }
          else {
              $file = $files_to_pick[0];
          }
      }

      if (lc $parms{rooms} =~ /all/) {
        @rooms = ();
        for my $audrey (split ',', $config_parms{Audrey_IPs}) {
          $audrey =~ /(\S+)\-(\S+)/;
          my $room = $1;
          my $ip = $2;
          push @rooms, $room;
        }
      } else {
        my @audreyRooms = ();
        for my $speakRoom (@rooms) {
          for my $audrey (split ',', $config_parms{Audrey_IPs}) {
            $audrey =~ /(\S+)\-(\S+)/;
            my $room = $1;
            my $ip = $2;
            if ($speakRoom eq $room) {
              push @audreyRooms, $room;
            }
          }
        }
        @rooms = @audreyRooms;
      }
      if (@rooms > 0) {
        my $speakFile = $config_parms{html_dir} . "/speakToAudrey" . $audreyWrIndex . ".wav";
        @speakRooms[$audreyWrIndex] = \@rooms;
        copy $file, $speakFile;
        $audreyWrIndex++;
        $audreyWrIndex = 0 if ($audreyWrIndex >= $audreyMaxIndex);
      }
    }
}




