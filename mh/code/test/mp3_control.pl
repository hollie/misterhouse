# Category=Music

# This uses either of these programs:
#  - wactrl, by david_kindred@iname.com  (windows only)
#  - httpq, a small/fast winamp plugin, available at:
#       http://karv.dyn.dhs.org/winamp or
#       http://winamp.com/customize/detail.jhtml?componentId=9936

# This just turns the player on,off,pause, etc.  mp3_playlist.pl controls 
# starting the mp3 player with a list of songs or a playlist


# noloop=start      This directive allows this code to be run on startup/reload
my (%winamp_commands, $mp3_states);
if ($config_parms{mp3_program_control} eq 'wactrl') {
    $mp3_states = "Play,Stop,Pause,Restart,Rewind,Forward," . 
                  "Next Song,Previous Song,Volume up,Volume down,ontop";
    %winamp_commands = ('Restart' => 'start', 'Rewind' => 'rew5s', 'Forward' => 'ffwd5s', 
                        'Next Song' => 'nextsong', 'Previous Song' => 'prevsong',
                        'Volume up' => 'volup', 'Volume down' => 'voldown');
}
else {
    $mp3_states = "Play,Stop,Pause,Next Song,Previous Song,Volume Up,Volume Down,Random Song,Toggle Shuffle,Toggle Repeat";
    %winamp_commands = ('Next Song' => 'next', 'Previous Song' => 'prev',
                        'Toggle Shuffle' => 'shuffle', 'Toggle Repeat' => 'repeat',
                        'Volume Up' => 'volumeup', 'Volume Down' => 'volumedown');
}
# noloop=stop

$v_mp3_control1 = new  Voice_Cmd("Set Nicks mp3 player to [$mp3_states]");
$v_mp3_control2 = new  Voice_Cmd("Set Zacks mp3 player to [$mp3_states]");
$v_mp3_control3 = new  Voice_Cmd("Set the house mp3 player to [$mp3_states]");
$v_mp3_control4 = new  Voice_Cmd("Set the shoutcast mp3 player to [$mp3_states]");
$v_mp3_control5 = new  Voice_Cmd("Set the phone mp3 player to [$mp3_states]");

&winamp_control($state, 'dm')    if $state = said $v_mp3_control1;
&winamp_control($state, 'z')     if $state = said $v_mp3_control2;
&winamp_control($state, 'house') if $state = said $v_mp3_control3;
&winamp_control($state, 'c2')    if $state = said $v_mp3_control4;
&winamp_control($state, 'p90')   if $state = said $v_mp3_control5;

                                # Control kid music
$v_mp3_control_boys  = new Voice_Cmd '{Turn, } {Boy,boys} music [on,off]';
$v_mp3_control_boys -> set_info('One stop shopping for loud music control :)');
$mp3_control_boys_off = new Serial_Item 'XPD', 'off';

if ($state = said $v_mp3_control_boys or
    $state = state_now $mp3_control_boys_off or 
    time_cron '45  6 * * 1-5' or
    time_cron '45 22 * * 1-5' or
    time_cron '45 23 * * 0,6') {
    $state = 'off' unless $state;
    $state = ($state eq 'on') ? 'PLAY' : 'STOP';
    print_log "Setting boy's mp3 players to $state";
    run_voice_cmd "Set Nicks mp3 player to $state";
    run_voice_cmd "Set Zacks mp3 player to $state";
}

 
                                # Allow for control with an X10 palmpad
$mp3_x10_control = new  Serial_Item('XM9MK', 'Play');
$mp3_x10_control ->add             ('XM9MJ', 'Stop');
$mp3_x10_control ->add             ('XMBMK', 'Next Song');
$mp3_x10_control ->add             ('XMBMJ', 'Previous Song');
$mp3_x10_control ->add             ('XMAMK', 'Volume up');
$mp3_x10_control ->add             ('XMAMJ', 'Volume down');
 
if($state = state_now $mp3_x10_control) {
    print_log "X10 input, setting mp3 to $state";
    run_voice_cmd "Set the house mp3 player to $state";
}

sub winamp_control {
    my ($command, $host) = @_;

                                # This translates from speakable commands to program commands
    $command = $winamp_commands{$command} if $winamp_commands{$command};
    
    $host = 'localhost' unless $host;
    print_log "Setting $host winamp to $command";

                                # Start winamp, if it is not already running (windows localhost only)
    &sendkeys_find_window('winamp', $config_parms{mp3_program}) if $OS_win and $host eq 'localhost';

    if ($config_parms{mp3_program_control} eq 'httpq') {
        my $url = "http://$host:$config_parms{mp3_program_port}";
        if($command eq 'Random Song'){
            my $mp3_num_tracks = get "$url/getlistlength?p=$config_parms{mp3_program_password}";
            my $song = int(rand($mp3_num_tracks));
            my $mp3_song_name  = get "$url/getplaylisttitle?p=$config_parms{mp3_program_password}&a=$song";
            $mp3_song_name =~ s/[\n\r]//g;
            print_log "Now Playing $mp3_song_name";
            get "$url/stop?p=$config_parms{mp3_program_password}";
            get "$url/setplaylistpos?p=$config_parms{mp3_program_password}&a=$song";
            print_log filter_cr get "$url/play?p=$config_parms{mp3_program_password}";
        }
       elsif($command =~ /volume/i){
           $temp = '';
                                # 10 passes is about 20 percent 
            for my $pass (1 .. 10) {
                $temp .= filter_cr get "$url/$command?p=$config_parms{mp3_program_password}";
            }
            print_log "Winamp (httpq $host) set to $command: $temp";
        }
        else {
            print_log "$url/$command?p=$config_parms{mp3_program_password}";
            $temp = filter_cr get "$url/$command?p=$config_parms{mp3_program_password}";
            print_log "Winamp (httpq $host) set to $command: $temp";
        }
    }
    else {
        print_log "Winamp (watrl) set to $command";
                                # Volume only goes by 1.5%, so run it a bunch
        my $i = 1;
        $i = 25 if $command =~ /^vol/;
        for (1 .. $i) {
            run "$config_parms{mp3_program_control} $command";
        }
    }
}
