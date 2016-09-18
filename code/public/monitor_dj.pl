# Monitor DJ sound card and toggle music off/on music whenever we speak to it
#run_voice_cmd 'Set the house mp3 player to pause' if state_now $mh_speakers;

my ($is_dj_speaking_flag);

if ($New_Msecond_250) {
    my $is_dj_speaking = &Voice_Text::is_speaking();
    if (   ( !$is_dj_speaking_flag and $is_dj_speaking )
        or ( $is_dj_speaking_flag and !$is_dj_speaking ) )
    {
        $is_dj_speaking_flag = !$is_dj_speaking_flag;

        #       my $cmd = ($is_dj_speaking) ? 'Pause' : 'Play';
        my $cmd   = ($is_dj_speaking) ? 'VOLUMEDOWN' : 'VOLUMEUP';
        my $count = ($is_dj_speaking) ? '35'         : '37';
        for ( 1 .. $count ) {
            get
              "http://localhost:4800/$cmd?p=$config_parms{mp3_program_password}";
        }
        print "db dj set to $cmd: $temp\n";

        #       $temp = filter_cr get "http://localhost:4800/$cmd?p=$config_parms{mp3_program_password}&a=50";
        #       run_voice_cmd 'Set the house mp3 player to pause', undef, undef, 0;
    }
}

$dj_tagline = new File_Item "$config_parms{data_dir}/remarks/1100tags.txt";
$dj_thought = new File_Item "$config_parms{data_dir}/remarks/deep_thoughts.txt";

if ( new_second 30 ) {

    #   speak voice => 'rich', text => 'The DJ says: ' . read_next $dj_tagline;
    #   speak voice => 'rich', text => 'The DJ says: ' . read_next $dj_tagline;
    # This computer is too slow to swtich between att voices :(
    #  speak voice => 'mary',    text => read_next $dj_tagline;

    # Read shorter taglines more often than long thoughts
    my $text =
      ( rand(10) > 4 ) ? ( read_next $dj_tagline) : ( read_next $dj_thought);

    speak
      volume => 200,
      voice  => 'mary',
      text   => "The DJ says: " . &Voice_Text::set_voice( 'Charles', $text );
}

# On startup, un-minimize winamp, so the shoutcast client starts ok

$winamp_prod = new Voice_Cmd 'Restore Winamp';

if ( said $winamp_prod) {
    if ( my $window =
        &sendkeys_find_window( 'winamp', $config_parms{mp3_program} ) )
    {
        # None of this works to resotr a window :(
        #       my $keys = '\\alt\\te\\ret\\';
        #       my $keys = '\\CTRLp';
        my $keys = '\\ALTa';
        &SendKeys( $window, $keys, 1, 500 );
        print_log "Restoring $window";
        SetFocus($window);
    }
}

