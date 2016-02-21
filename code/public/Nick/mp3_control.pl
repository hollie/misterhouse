# Category=TV and Music

# On Windows, this calls a winamp control program called wactrl, by david_kindred@iname.com
# On linux,   this calls ???

my $mp3_states =
  "Play,Stop,Pause,Next Song,Previous Song,Volume Up,Volume Down,Random Song,Toggle Shuffle,Toggle Repeat";
$v_mp3_control = new Voice_Cmd("Set mp3 player to [$mp3_states]");

# This translates from speakable commands to program commands
my %winamp_commands = (
    'Next Song'      => 'next',
    'Previous Song'  => 'prev',
    'Toggle Shuffle' => 'shuffle',
    'Toggle Repeat'  => 'repeat',
    'Volume Up'      => 'volumeup',
    'Volume Down'    => 'volumedown'
);

if ( $state = said $v_mp3_control) {

    my $command = $state;
    $command = $winamp_commands{$command} if $winamp_commands{$command};

    print_log "Setting winamp to $command";

    # Start winamp, if it is not already running (windows localhost only)
    &sendkeys_find_window( 'winamp', $config_parms{mp3_program} );

    if ( $config_parms{mp3_program_control} eq 'httpq' ) {
        my $url = "http://localhost:$config_parms{mp3_program_port}";
        if ( $command eq 'Random Song' ) {
            my $mp3_num_tracks =
              get "$url/getlistlength?p=$config_parms{mp3_program_password}";
            my $song          = int( rand($mp3_num_tracks) );
            my $mp3_song_name = get
              "$url/getplaylisttitle?p=$config_parms{mp3_program_password}&a=$song";
            $mp3_song_name =~ s/[\n\r]//g;
            print_log "Now Playing $mp3_song_name";
            get "$url/stop?p=$config_parms{mp3_program_password}";
            get
              "$url/setplaylistpos?p=$config_parms{mp3_program_password}&a=$song";
            print_log filter_cr get
              "$url/play?p=$config_parms{mp3_program_password}";
        }
        elsif ( $command =~ /volume/i ) {
            $temp = '';

            # 10 passes is about 20 percent
            for my $pass ( 1 .. 10 ) {
                $temp .= filter_cr get
                  "$url/$command?p=$config_parms{mp3_program_password}";
            }
            print_log "Winamp (httpq) set to $command: $temp";
        }
        else {
            print "$url/$command?p=$config_parms{mp3_program_password}\n";
            $temp = filter_cr get
              "$url/$command?p=$config_parms{mp3_program_password}";
            print_log "Winamp (httpq) set to $command: $temp";
        }
    }

}
