# Category=TV and Music

# On Windows, this calls a winamp control program called wactrl, by david_kindred@iname.com
# On linux,   this calls ???

$v_mp3_control = new  Voice_Cmd("Set mp3 player to [Play,Stop,Pause,Restart,Rewind,Forward," .
                                   "Next Song,Previous Song,Volume up,Volume down,ontop]");

                                # This translates from speakable commands to program commands
my %winamp_commands = ('Restart' => 'start', 'Rewind' => 'rew5s', 'Forward' => 'ffwd5s', 
                       'Next Song' => 'nextsong', 'Previous Song' => 'prevsong',
                       'Volume up' => 'volup', 'Volume down' => 'voldown');

if ($state = said $v_mp3_control) {
    if ($OS_win) {

                                # Start winamp, if it is not already running
        &sendkeys_find_window('winamp', $config_parms{mp3_program});

        $state = $winamp_commands{$state} if $winamp_commands{$state};
        print_log "Winamp set to $state";

                                # Volume only goes by 1.5%, so run it a bunch
        my $i = 1;
        $i = 22 if $state =~ /^vol/;
        for (1 .. $i) {
            run "wactrl $state";
        }
    }
    else {
        speak "Sorry, no mp3 client for this OS yet";
    }
}

                                # Allow for loading playlists
# noloop=start      This directive allows this code to be run on startup/reload
my $mp3playlist = &load_playlist($config_parms{mp3_dir}, $config_parms{mp3_extention});
my $mp3songs1   = &load_playlist('d:/winamp/Scour/good', 'mp3');
my $mp3songs2   = &load_playlist('d:/winamp/Scour/bad', 'mp3');
# noloop=stop

$v_play_music1 = new Voice_Cmd("Set mp3 player to playlist [$mp3playlist]");
$v_play_music2 = new Voice_Cmd("Set mp3 player to good song [$mp3songs1]");
$v_play_music3 = new Voice_Cmd("Set mp3 player to bad song [$mp3songs2]");

my $song;
$song = '';
$song = "$config_parms{mp3_dir}"      if $state = said $v_play_music1;
$song = "d:/winamp/Scour/good/$state" if $state = said $v_play_music2;
$song = "d:/winamp/Scour/bad/$state"  if $state = said $v_play_music3;

if ($song) {
    if ($OS_win) {
                                # Start winamp, if it is not already running
        &sendkeys_find_window('winamp', $config_parms{mp3_program});

        print_log "Loading mp3 song: $song";
        run "wactrl delete";
        run "wactrl $song";
        select undef, undef, undef, .3; # Give winamp a chance to load it
        run "wactrl play";
    }
    else {
        speak "Sorry, no mp3 client for this OS yet";
    }
}

sub load_playlist {
    my ($dir, $extention) = @_;
    my $mp3names;
    opendir(DIR, $dir) or print "Error in opening mp3_dir $dir: $!\n";
    print "Reading $dir for $extention files\n";
    for (readdir(DIR)) {
        next unless /(\S+)\.(\S+)/;
        next unless lc $2 eq lc $extention;
#       print "name=$1 ext=$2 match $extention\n";
        $mp3names .= $1 . ","; 
    }
    print "names=$mp3names\n";
    return $mp3names;
}


